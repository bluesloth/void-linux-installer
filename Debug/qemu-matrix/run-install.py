#!/usr/bin/env python3
"""
Unattended driver for one Void_Linux_Installer.sh test run inside a QEMU live
guest, speaking to QEMU's serial unix socket.

Phases (one persistent connection):
  1. boot        wait for the medium's overlay prompt, answer Enter
  2. login       root / voidlinux
  3. tools       xbps-install the live-medium tools the installer needs
  4. install     start the installer and reactively answer its prompts
  5. verify      after completion, probe the installed disk from the live OS

usage: run-install.py --sock S --log L --src DIR --bootloader limine|grub
                      --encrypt yes|no [--dry] [--max SECS]
"""
import argparse
import json
import os
import re
import socket
import subprocess
import sys
import threading
import time

ap = argparse.ArgumentParser()
ap.add_argument("--sock", required=True)
ap.add_argument("--log", required=True)
ap.add_argument("--src", required=True)
ap.add_argument("--bootloader", choices=("limine", "grub"), default="limine")
ap.add_argument("--encrypt", choices=("yes", "no"), default="no")
ap.add_argument("--dry", action="store_true")
ap.add_argument("--mode", choices=("bios", "uefi"), default="bios",
                help="firmware the case is run under: drives the dry-run plan assertions")
ap.add_argument("--max", type=float, default=6600.0)
ap.add_argument("--qmp", default="", help="QMP socket: enables stall screendumps")
args = ap.parse_args()

# Every progress line must reach the harness log immediately: when stdout is a
# redirected file it is block-buffered, and a stalled run would then show no
# driver activity at all while it is in fact answering prompts.
try:
    sys.stdout.reconfigure(line_buffering=True)
except AttributeError:
    pass

PASS = "testpass1"          # >=8 chars: read_password_twice's minimum
LIVE_PW = "voidlinux"
BOOT_INPUT = "1" if args.bootloader == "limine" else "2"
ENCRYPT_INPUT = "y" if args.encrypt == "yes" else "n"
TOOLS = "gptfdisk" + ("" if args.bootloader == "grub" else " limine")
INSTALL_ARGS = "--dry-run" if args.dry else ""

DONE_MARK = "PAUSED — R/Enter=reboot now"
DRYDONE_MARK = "Nothing was written to disk"
FAIL_MARKS = (r"FATAL[ :\[]", r"Traceback \(most recent call last\)")
# The live shell prompt reappearing inside THIS run's output means the
# installer process exited — with no completion marker that is a failure.
SHELL_RE = re.compile(r"(?:\[root@void-live [^\]]*\]|-bash-[\d.]+)# ")
# Real installs end in a reboot countdown the installer reads keys from
# /dev/tty; `S` aborts the reboot and drops back to the live shell.
STOP_MARK = "Reboot skipped — staying at the live shell"
REBOOT_MARK = re.compile(r"Reboot(?:ing)? in \d+ second")

VERIFY_CMD = (
    "echo ===VERIFY===; sgdisk -p /dev/vda 2>&1 | tail -14; echo ---ESP---; "
    "ls -la /mnt/boot/efi/ 2>/dev/null | head -14; "
    "ls -la /mnt/boot/ 2>/dev/null | head -8; echo ---MBR---; "
    "dd if=/dev/vda bs=512 count=2 2>/dev/null | strings | head -8; echo ---STAGE2---; "
    "for p in /dev/vda2 /dev/vda3; do echo \"## $p\"; dd if=$p bs=1M count=2 2>/dev/null "
    "| strings | grep -m2 -iE 'grub|limine'; done; echo ---CFG---; "
    "ls /mnt/boot/grub/i386-pc 2>/dev/null | head -3 || echo 'no grub i386-pc dir'; "
    "grep -E '^(BOOT_MODE|BOOTLOADER|LIMINE_NVRAM|ENCRYPT)=' /mnt/etc/void-installer/install-config 2>/dev/null; "
    "echo \"===ENDV$((6*2))===\"\n"
)
VERIFY_DONE = "===ENDV12==="   # arithmetic so the tty echo of the command cannot match it

# --- reactive rules for the installer prompts (specific before generic) -----
# Guest path of the optional package-cache 9p share (section 3b2). Empty when
# run-case.sh did not export VLI_CACHE — the cache rule below then answers the
# prompt with a bare Enter, exactly the pre-existing default.
CACHE_GUEST_PATH = "/mnt/vlicache" if os.environ.get("VLI_CACHE") else ""

RULES = [
    (re.compile(r"Enter (?:root|user|\S+) password: "), PASS + "\n", None, "set password"),
    (re.compile(r"Confirm (?:\S+) password: "), PASS + "\n", None, "confirm password"),
    # Prompts with NO default — an empty read loops forever, so each must be
    # answered explicitly (checked against the `case`/regex that follows the
    # read in every one of these).
    (re.compile(r"Enter choice \[1/2/3\]: "), "1\n", 1, "account model = hybrid"),
    (re.compile(r"Enter the username to create on the target system: "), "tester\n", 1, "target user"),
    (re.compile(r"Enter target system hostname \(e\.g\., myhostname\): "), "voidtest\n", 1, "hostname"),
    # NOTE: the disk picker is handled by DISK_RE below — it must pick the real
    # target (/dev/vda), because QEMU's default `pc` machine exposes a floppy
    # controller and the installer lists every unmounted lsblk disk, so index 1
    # can be the 4 KiB /dev/fd0.
    (re.compile(r"type 'ERASE!'"), "ERASE!\n", 2, "wipe confirmation"),
    (re.compile(r"Enter choice \[1/2\] \(default \d+: "), BOOT_INPUT + "\n", 1, "bootloader choice"),
    (re.compile(r"Enable full-disk encryption \(LUKS2\)\? \[y/N\]: "), ENCRYPT_INPUT + "\n", 1, "encryption gate"),
    (re.compile(r"Enter a passphrase for the encrypted disk"), PASS + "\n", 1, "LUKS passphrase"),
    (re.compile(r"Enter the passphrase again to confirm"), PASS + "\n", 1, "LUKS passphrase confirm"),
    (re.compile(r"Enter choice \[1/2/3/4/5/6/7/8, default "), "8\n", 1, "desktop = none (fast console install)"),
    # Optional local package cache (only when run-case.sh exported VLI_CACHE):
    # type the guest path of the writable 9p share instead of taking the
    # [y/N] default (default = network-only). Without VLI_CACHE this rule
    # sends a bare Enter — byte-identical to the old fall-through default.
    (re.compile(r"Use a local package cache\? \[y/N\] or type an absolute path: "),
     (CACHE_GUEST_PATH + "\n") if CACHE_GUEST_PATH else "\n", 1,
     "local package cache = " + CACHE_GUEST_PATH if CACHE_GUEST_PATH else "local package cache (default: network-only)"),
]
hits = [0] * len(RULES)
DISK_RE = re.compile(r"Select disk to partition and install to \[\d-\d+\]: ")

s = socket.socket(socket.AF_UNIX)
s.connect(args.sock)
s.settimeout(0.4)
log = open(args.log, "ab", buffering=0)

seen = b""
scan = 0
answered_at = 0.0
last_rx = time.time()
stall_n = 0


def pump(seconds):
    """Receive for <seconds>, folding output into seen/log. Returns new bytes."""
    global seen, last_rx
    deadline = time.time() + seconds
    fresh = b""
    while time.time() < deadline:
        try:
            data = s.recv(8192)
        except socket.timeout:
            continue
        if not data:
            break
        log.write(data)
        seen += data
        fresh += data
        last_rx = time.time()
    return fresh


def send(text):
    global answered_at, scan
    s.sendall(text.encode())
    answered_at = time.time()
    scan = len(seen)
    log.write(("\n<<DRIVER: %r>>\n" % text).encode())


def wait_for(pat, timeout, tag):
    """Block until <pat> matches NEW output (after current scan position)."""
    global scan
    rx = re.compile(pat.encode())
    deadline = time.time() + timeout
    hb = 0
    while time.time() < deadline:
        m = rx.search(seen, scan)
        if m:
            scan = m.end()
            print("[%.0fs] %-28s matched %r" % (time.time() - T0, tag, pat[:50]), flush=True)
            return True
        now = time.time()
        if now - last_rx > 30 * (hb + 1):
            hb += 1
            print("[%.0fs] phase %-18s still waiting (idle %.0fs, %d bytes seen)"
                  % (now - T0, tag, now - last_rx, len(seen)), flush=True)
        pump(0.4)
    print("[%.0fs] TIMEOUT in phase %-22s waiting %r" % (time.time() - T0, tag, pat[:60]))
    print("       log tail: %r" % seen[-500:])
    return False


STALL_GIVEUP = 420    # dead serial for 7 min = fail the case loudly, don't hang


_LAST_FORCED_WAKE = [0.0]   # rate-limit the forced IRQ (see _qmp_status)


def _qmp_status(wake=False):
    """Guest status dict (or None if QMP was unreachable).

    wake=True fires system_wakeup unconditionally, rate-limited to one per
    minute: suspend-to-idle (s2idle) never touches the firmware, so QMP keeps
    answering {"status": "running"} while every task in the guest is frozen —
    the status check alone cannot see it, but a wakeup IRQ revives it and is a
    harmless no-op on a guest that was awake all along."""
    if not args.qmp:
        return None
    try:
        cs = socket.socket(socket.AF_UNIX)
        cs.settimeout(8)        # a silent QMP must not wedge the watchdog
        cs.connect(args.qmp)
        cf = cs.makefile("rw", encoding="utf-8")
        cf.readline()
        cf.write(json.dumps({"execute": "qmp_capabilities"}) + "\n")
        cf.flush()
        while True:
            if any(k in json.loads(cf.readline()) for k in ("return", "error")):
                break
        cf.write(json.dumps({"execute": "query-status"}) + "\n")
        cf.flush()
        out = None
        while True:
            obj = json.loads(cf.readline())
            if "return" in obj:
                out = obj["return"]
                break
            if "error" in obj:
                break
        want, why = False, None
        if out is not None and not out.get("running", True):
            # Hard ACPI S3: QMP knows about it, one command brings it back.
            want, why = True, ("guest was SUSPENDED (ACPI S3: %s) -> system_wakeup sent"
                               % out.get("status"))
        elif wake and time.time() - _LAST_FORCED_WAKE[0] > 60:
            _LAST_FORCED_WAKE[0] = time.time()
            want, why = True, ("forcing wakeup IRQ (suspend-to-idle is invisible "
                               "to QMP: status=running)")
        if want:
            cf.write(json.dumps({"execute": "system_wakeup"}) + "\n")
            cf.flush()
            while True:
                if any(k in json.loads(cf.readline()) for k in ("return", "error")):
                    break
            print("[%.0fs] %s" % (time.time() - T0, why), flush=True)
        note = out
        cf.close()              # release QMP: only one client may be active
        cs.close()
        return note
    except Exception as exc:
        print("       QMP probe failed: %s" % exc, flush=True)
        return None


def _watchdog():
    """On an output stall, capture where the guest actually is — and wake it.

    Two failure modes are handled here: a guest that suspended itself (above,
    rescued) and a serial link that is genuinely dead (after STALL_GIVEUP of
    continuous silence the case aborts with rc=7 instead of hanging until the
    outer timeout — the pre-3.1.00 watchdog stopped reporting after the 5th
    screenshot and then said nothing at all)."""
    global stall_n
    last_hb = 0.0
    while True:
        time.sleep(10)
        idle = time.time() - last_rx
        if idle > 45 and not done_evt.is_set():
            st = _qmp_status(wake=idle > 60)
            if st is not None and not st.get("running", True):
                continue        # just woke it — give the console time to flow
            if stall_n < 5:
                stall_n += 1
                ppm = "%s.stall%d.ppm" % (args.log, stall_n)
                print("[%.0fs] STALL: no output for %.0fs -> capturing %s"
                      % (time.time() - T0, idle, ppm), flush=True)
                if args.qmp:
                    try:
                        _here = os.path.dirname(os.path.abspath(__file__))
                        subprocess.run(["python3", os.path.join(_here, "qmp-dump.py"),
                                        args.qmp, ppm],
                                       capture_output=True, timeout=30)
                        subprocess.run(["python3", os.path.join(_here, "ppm2png.py"), ppm,
                                        ppm.replace(".ppm", ".png")],
                                       capture_output=True, timeout=60)
                        if os.path.exists(ppm):
                            os.unlink(ppm)
                    except Exception as exc:
                        print("       screendump failed: %s" % exc, flush=True)
                if st is not None:
                    print("       qemu guest status: %s" % st, flush=True)
            if time.time() - last_hb > 60:
                last_hb = time.time()
                print("[%.0fs] STALL heartbeat: %ds with no serial output"
                      % (time.time() - T0, int(idle)), flush=True)
            if idle > STALL_GIVEUP:
                print("FATAL: serial dead for %ds — aborting this case (rc=7)"
                      % int(idle), flush=True)
                os._exit(7)


T0 = time.time()
done_evt = threading.Event()
threading.Thread(target=_watchdog, daemon=True).start()
rc = 0

# ---------------------------------------------------------------- 1. boot
if not wait_for(r"Press \[Enter\] to continue", 300, "boot-overlay"):
    sys.exit(10)
send("\n")

# ---------------------------------------------------------------- 2. login
if not wait_for(r"void-live login:", 240, "login-prompt"):
    sys.exit(11)
send("root\n")
if not wait_for(r"Password:", 60, "login-password"):
    sys.exit(12)
send(LIVE_PW + "\n")
if not wait_for(r"(?:\[root@void-live [^\]]*\]|-bash-[\d.]+)# ", 90, "shell"):
    sys.exit(13)

# ---------------------------------------------------------------- 3. tools
# Harness accommodation (product untouched): QEMU user-mode networking has no
# outbound ICMP passthrough, so `ping xmirror.voidlinux.org` — the installer's
# reachability prereq — gets no reply even though TCP/DNS work fine (the live
# xbps-install above proves that). xmirror is used NOWHERE else in the script
# (the mirror menu is a static list), so the harness resolves it to the
# guest's own loopback, which always answers ICMP: the prereq then behaves
# exactly as it does on real hardware.
send("grep -q xmirror /etc/hosts || echo '127.0.0.1 xmirror.voidlinux.org' >> /etc/hosts; "
     "ping -c1 -W3 xmirror.voidlinux.org >/dev/null && echo \"PING_OK_$((100+1))\"\n")
if not wait_for(r"PING_OK_101", 60, "icmp-prereq"):
    print("could not satisfy the installer's ICMP reachability prereq")
    sys.exit(16)

send("xbps-install -S %s -y >/tmp/tools.log 2>&1; echo TOOLS_EXIT=$?; echo ===TOOLS===\n" % TOOLS)
if not wait_for(r"TOOLS_EXIT=\d", 900, "live-tools"):
    sys.exit(14)

# ------------------------------------------------- 3b. installer source (9p)
# NINEP_OK_$((1+1)) -> "NINEP_OK_2": the tty echo carries the arithmetic
# expression, only the command's OUTPUT carries the digit, so wait_for() cannot
# be satisfied by our own echoed command line.
send("mkdir -p /mnt/vlio; mount -t 9p -o trans=virtio,version=9p2000.L vlio "
     "/mnt/vlio && ls /mnt/vlio/Void_Linux_Installer.sh >/dev/null && echo \"NINEP_OK_$((1+1))\"\n")
if not wait_for(r"NINEP_OK_2", 60, "9p-script-mount"):
    print("could not mount the installer directory over 9p")
    sys.exit(15)

# ------------------------------------------ 3b2. package cache share (opt-in)
# VLI_CACHE (host dir, exported by run-case.sh when set) is exposed to the
# guest as the `vlicache` 9p tag — WRITABLE, because every consumer of the
# cache path checks -w (the prompt, the resume re-detect, and the bind-mount
# into the chroot at /mnt/tmp/xbps-cache). The installer then gets the guest
# path typed at the "Use a local package cache?" prompt (see RULES below).
# Unset = today's behavior exactly: no share, no rule, bare-Enter default.
if os.environ.get("VLI_CACHE"):
    send("mkdir -p /mnt/vlicache; mount -t 9p -o trans=virtio,version=9p2000.L vlicache "
         "/mnt/vlicache && ls /mnt/vlicache >/dev/null && echo \"VCACHE_OK_$((1000+1))\"\n")
    if not wait_for(r"VCACHE_OK_1001", 60, "9p-cache-mount"):
        print("could not mount the package cache over 9p")
        sys.exit(15)

# ------------------------------------------------ 3c. no-sleep preamble
# The live KDE session suspends the whole machine a few minutes in, which
# froze this install mid-xbps-install three times (once as a hard ACPI S3 that
# hung a kworker after resume, twice as suspend-to-idle — the latter needs no
# firmware transition, so PIIX4_PM.disable_s3 does NOT stop it and QMP keeps
# reporting "running" while every task in the guest is frozen). Three layers,
# all test-side: a failure here must never abort an install, so the sequence
# always ends in a marker the driver waits for — but the marker now REPORTS
# each layer's state, and layers 1/2 got a hard backstop, because the third
# freeze (2026-10-20, bios-limine-plain + uefi-limine-plain in parallel, both
# rc=7 at ~35 min) left the live session's lock-screen clock on the VGA
# screendump: `timeout 5 sv stop sddm` had evidently given up mid-teardown
# under parallel-guest load, so sddm (hence PowerDevil) was still alive to
# ask for sleep.
#   1. stop the display managers — kills PowerDevil, the requester — then
#      KILL the survivors by name: a stop that expired mid-teardown leaves the
#      service running, and a live sddm/Xorg/powerdevil afterwards is a
#      FAILED layer (`dm=`/`x=` in the marker say so);
#   2. stop elogind — nothing left to answer a Suspend() call;
#   3. bind-mount /dev/null over /sys/power/state, so any sleep request that
#      survives the first two is written into the void instead of freezing
#      the guest — then READ the state back (only an intact bind makes `cat`
#      return nothing) and report `bind=yes|NO`.
# NOSLEEP_OK_$((20*2)) -> the echoed command line carries the arithmetic
# (convention), only the shell's OUTPUT carries the digit — and 20*2 is 40,
# so the pattern below is NOSLEEP_OK_40. (Waiting for "...400" made every run
# burn a pointless 60 s here and warn about an unconfirmed preamble that had
# in fact completed: the guest had been printing NOSLEEP_OK_40 all along.)
# Each sv stop is bounded by `timeout`: stopping a display manager can block
# for a long time on the session teardown, and a blocked preamble once cost us
# the whole wait window (the later layers then raced the installer launch).
# The -f pkill pattern is bracketed ("sdd[m]-helper"): this very command line
# contains the unbracketed text, and an unbracketed -f match would kill the
# session shell that is running the preamble.
send("for s in sddm greetd lightdm lxdm slim kdm gdm; do timeout 5 sv stop \"$s\" >/dev/null 2>&1; done; "
     "timeout 5 sv stop elogind >/dev/null 2>&1; "
     "pkill -9 -x sddm 2>/dev/null; pkill -9 -f 'sdd[m]-helper' 2>/dev/null; "
     "pkill -9 -x Xorg 2>/dev/null; pkill -9 -x powerdevil5 2>/dev/null; pkill -9 -x powerdevil 2>/dev/null; "
     "mount --bind /dev/null /sys/power/state 2>/dev/null; "
     "echo NOSLEEP_OK_$((20*2)) bind=$([ -z \"$(cat /sys/power/state 2>/dev/null)\" ] && echo yes || echo NO)"
     " dm=$(pgrep -x sddm >/dev/null && echo UP || echo down)"
     " x=$(pgrep -x Xorg >/dev/null && echo UP || echo down)\n")
if not wait_for(r"NOSLEEP_OK_40", 60, "no-sleep-preamble"):
    print("       WARNING: no-sleep preamble unconfirmed — falling back on the "
          "watchdog's QMP system_wakeup", flush=True)
for _layer in ("bind=NO", "dm=UP", "x=UP"):
    if _layer in seen[-400:].decode("utf-8", "replace"):
        print("       WARNING: no-sleep preamble layer FAILED (%s) — a guest "
              "suspend from here freezes the case to rc=7; only the "
              "watchdog's system_wakeup could revive it" % _layer, flush=True)

# ---------------------------------------------------------------- 4. install
send("clear; cd /mnt/vlio && bash Void_Linux_Installer.sh %s\n" % INSTALL_ARGS)
install_started = time.time()
inst_pos = len(seen)   # done/fail markers may only come from THIS run's output
tscan = len(seen.decode("utf-8", "replace"))   # char cursor for the rule scan
stop_sent = False

while time.time() - install_started < args.max - 400:
    pump(0.4)
    tail = seen.decode("utf-8", "replace")
    post = seen[inst_pos:].decode("utf-8", "replace")
    if DONE_MARK in post or DRYDONE_MARK in post:
        print("[%.0fs] installer finished" % (time.time() - T0))
        time.sleep(3)
        break
    # A real install ends in a REBOOT_DELAY countdown (default 20 s!) driven by
    # a read from /dev/tty: waiting for a "paused" prompt that nothing ever
    # pauses would let the guest reboot out from under the disk probe. `S`
    # (stop) makes it fall through to the live shell, which is where the
    # verification probe needs the target still mounted at /mnt.
    if STOP_MARK in post:
        print("[%.0fs] installer finished (reboot stopped)" % (time.time() - T0))
        time.sleep(3)
        break
    if not stop_sent and REBOOT_MARK.search(post):
        print("[%.0fs] pre-reboot countdown seen -> sending S (stay at live shell)"
              % (time.time() - T0))
        send("S")
        stop_sent = True
        answered_at = time.time()
        continue
    if time.time() - install_started > 20:
        for m in FAIL_MARKS:
            if re.search(m, post):
                print("[%.0fs] FAILURE marker in installer output: %s" % (time.time() - T0, m))
                rc = 4
                break
    if rc:
        break
    # Installer returned to the shell without ever reporting success.
    if time.time() - install_started > 25 and SHELL_RE.search(post):
        print("[%.0fs] installer exited without a completion marker" % (time.time() - T0))
        rc = 5
        break
    if time.time() - answered_at < 0.6:
        continue
    # Disk picker (special case): choose the REAL target. The installer lists
    # every unmounted `lsblk` disk and QEMU's default `pc` machine exposes a
    # floppy controller, so the menu can start with the 4 KiB /dev/fd0.
    _dk = DISK_RE.search(tail, tscan)
    if _dk:
        _vm = re.search(r"(\d+)\)\s+/dev/vda\b", tail)
        _pick = _vm.group(1) if _vm else "1"
        tscan = _dk.end()
        answered_at = time.time()
        print("[%.0fs] %-45s -> %r" % (time.time() - T0, "disk pick (target /dev/vda)", _pick))
        send(_pick + "\n")
        continue
    # Rules match UNCONSUMED output only (`scan` advances past every prompt we
    # answer): matching against the whole buffer would re-see an already
    # answered "Enter root password:" forever and answer every later prompt
    # with the password instead of falling through to the right rule.
    for idx, (pat, resp, mx, desc) in enumerate(RULES):
        if mx is not None and hits[idx] >= mx:
            continue
        m = pat.search(tail, tscan)
        if m:
            hits[idx] += 1
            tscan = m.end()
            print("[%.0fs] %-45s -> %r" % (time.time() - T0, desc, resp.strip()))
            send(resp)
            break
    else:
        # ask() prints "-- <label>" + a colour reset and NO newline, so the
        # prompt is the trailing partial line. Strip ANSI (the reset lands
        # AFTER the colon) and take the documented default with a bare Enter.
        last_line = tail.split("\r\n")[-1]
        plain = re.sub(r"\x1b\[[0-9;?]*[ -/]*[@-~]", "", last_line)
        plain = re.sub(r"\[[0-9;?]*[a-zA-Z]", "", plain)
        if re.match(r"\s*-- .*:\s$", plain):
            print("[%.0fs] default answer (Enter): %.70r" % (time.time() - T0, plain.rstrip()))
            send("\n")
else:
    print("[%.0fs] TIMEOUT driving the installer" % (time.time() - T0))
    rc = rc or 3

# ---------------------------------------------------------------- 5. verify
if args.dry:
    # A --dry-run writes nothing, so the target disk is still empty and a probe
    # would only report a blank table. The plan IS the artifact of this run:
    # assert the firmware mode it recorded, and that the BIOS-only ef02 step is
    # present exactly when the case runs under BIOS (and ABSENT under UEFI —
    # the negative check that proves the legacy path cannot leak).
    plan = seen[inst_pos:].decode("utf-8", "replace")
    if args.mode == "bios":
        checks = (("recorded boot mode", r"Boot mode\s*:\s*bios\b", True),
                  ("ef02 step in plan", r"ef02 BIOS boot", True))
    else:
        checks = (("recorded boot mode", r"Boot mode\s*:\s*uefi\b", True),
                  ("no ef02 step under UEFI", r"ef02 BIOS boot", False))
    for label, pat, want in checks:
        found = re.search(pat, plan) is not None
        print("[%.0fs] plan check %-26s -> %s" %
              (time.time() - T0, label, "yes" if found else "no"))
        if found != want:
            rc = rc or 6
    m = re.search(r"Destructive steps\s*:.*", plan)
    print("[%.0fs] plan check %-26s -> %s" %
          (time.time() - T0, "destructive line",
           m.group(0)[:100] if m else "NOT FOUND"))
    if not m:
        rc = rc or 6
else:
    pump(2)
    # VERIFY_CMD closes with `echo "===ENDV$((6*2))==="` (arithmetic, so our own
    # echoed command line can never satisfy the wait) -> ===ENDV12===
    send(VERIFY_CMD)
    if not wait_for(r"===ENDV12===", 180, "verify"):
        rc = rc or 5

log.close()
s.close()
done_evt.set()
print("[%.0fs] driver done rc=%d" % (time.time() - T0, rc))
sys.exit(rc)
