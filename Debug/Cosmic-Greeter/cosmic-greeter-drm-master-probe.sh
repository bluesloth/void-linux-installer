#!/bin/bash
#
# cosmic-greeter-drm-master-probe.sh
#
# AI (Big Pickle) — DRM-master probe for the cosmic-greeter grey-screen bug.
#
# elogind source shows: session controller is a D-Bus sender name, auto-dropped
# on disconnect (sd_bus_track). Our libseat-logind probe observed TakeControl
# returning EBUSY => session 7 ALREADY has a live controller (the greeter),
# so libseat's logind backend IS working. The remaining suspect is the KERNEL
# DRM master holder: if something occupies `/dev/dri/card0` masters, smithay's
# acquire_master_lock() fails and cosmic-comp drops to "unprivileged mode"
# (atomic commits then fail with EACCES => grey screen, cursor only).
#
# This probe, run as root, answers:
#   1. Who has /dev/dri/card0 open?
#   2. Current kernel fbcon (fb0) name/bind state.
#   3. Which VT is active? Its KD_GRAPHICS/KD_TEXT mode.
#   4. Can a root process become DRM master right now? (SET_MASTER after
#      GET_VERSION/GET_MAGIC, immediately DROP_MASTER)
#      SET_MASTER success => master slot FREE right now; the failure happens
#      on the greeter's own fd path (elogind phone-back), not a busy kernel.
#      EBUSY => something/someone holds master.
#
# Safe / read-only: master is dropped the moment it is acquired. No greeter
# is killed, restarted, or reconfigured.
#
# Usage: sudo bash cosmic-greeter-drm-master-probe.sh
# Output: /var/log/cosmic-greeter-drm-master-probe.txt  (0644)
#
LOG=/var/log/cosmic-greeter-drm-master-probe.txt
umask 022
exec > "$LOG" 2>&1

echo "===== DRM master probe: $(date) ====="
echo "host: $(hostname)   uname: $(uname -r)"
echo

echo "--- 0. who has /dev/dri/card0 open right now ---"
for p in /proc/[0-9]*; do
    pid=${p#/proc/}
    if ls -l "$p/fd" 2>/dev/null | grep -q 'dri/card0' ; then
        cmd=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)
        ppid=$(awk '/^PPid:/{print $2}' "$p/status" 2>/dev/null)
        cg=$(awk -F/ '{print $NF}' "$p/cgroup" 2>/dev/null)
        echo "pid=$pid ppid=$ppid cgroup=$cg cmd=$cmd"
        ls -l "$p/fd" 2>/dev/null | grep 'dri/card0' | sed 's/^/    /'
    fi
done
echo

echo "--- 1. kernel DRM device + fb0 state ---"
ls -l /dev/dri/ 2>/dev/null
echo "fb0 name:   $(cat /sys/class/graphics/fb0/name 2>/dev/null)"
echo "fb0 active: $(cat /sys/class/graphics/fb0/state 2>/dev/null)"
echo

echo "--- 2. VT state (which VT active, who owns it, console mode) ---"
echo "tty0 active: $(cat /sys/class/tty/tty0/active 2>/dev/null)"
for c in /sys/class/vtconsole/vtcon*; do
    echo "  $(basename $c): name=$(cat $c/name 2>/dev/null) bind=$(cat $c/bind 2>/dev/null)"
done
echo "fbcon owns the console if vtcon1(m)=bind=1 and active VT is tty1"
echo

echo "--- 3. DRM fd sanity + SET_MASTER/DROP_MASTER test (python3, no struct-passing) ---"
python3 - <<'PYEOF'
import fcntl, os, struct

CARD = "/dev/dri/card0"

# Exact libdrm ioctl numbers (base 'd' = 0x64):
DRM_IOCTL_GET_MAGIC   = 0x80046406  # _IOR ('d',0x06, struct drm_auth{__u32}) size=4
DRM_IOCTL_SET_MASTER  = 0x0000641E  # _IO  ('d',0x1e) - no args
DRM_IOCTL_DROP_MASTER = 0x0000641F  # _IO  ('d',0x1f) - no args

fd = os.open(CARD, os.O_RDWR | os.O_CLOEXEC)
print(f"opened {CARD} fd={fd}")
try:
    buf4 = bytearray(4)
    fcntl.ioctl(fd, DRM_IOCTL_GET_MAGIC, buf4)
    print(f"GET_MAGIC: ok (0x{struct.unpack_from('I', buf4, 0)[0]:08x}) -> valid DRM primary fd")

    try:
        fcntl.ioctl(fd, DRM_IOCTL_SET_MASTER)
        print("SET_MASTER: SUCCESS (master slot was FREE) -> dropping immediately")
        fcntl.ioctl(fd, DRM_IOCTL_DROP_MASTER)
        print("DROP_MASTER: ok")
    except OSError as e:
        print(f"SET_MASTER: FAILED {e.errno} {e.strerror}")
        print("  => something else holds the DRM master on card0 right now")
finally:
    os.close(fd)
PYEOF
echo

echo "--- 3b. kernel DRM master holder via debugfs (mount if needed) ---"
if [ ! -d /sys/kernel/debug/dri ] || [ ! -r /sys/kernel/debug/dri/0/state ]; then
    mount -t debugfs none /sys/kernel/debug 2>/dev/null && echo "debugfs mounted" || echo "debugfs mount failed"
fi
if [ -r /sys/kernel/debug/dri/0/state ]; then
    echo "--- /sys/kernel/debug/dri/0/state (master/clients relevant lines) ---"
    grep -aiE 'master|frame rate|atomic|encoder|connector|crtc.*active|fb 1|client' /sys/kernel/debug/dri/0/state 2>/dev/null | head -40
    echo "--- /sys/kernel/debug/dri/0/clients (who holds fds/master) ---"
    cat /sys/kernel/debug/dri/0/clients 2>/dev/null
else
    echo "debugfs dri state unavailable"
fi
echo

echo "--- 4. poll master holder candidates ---"
if command -v getfacl >/dev/null 2>&1; then
    echo "ACL:"
    echo "  card0:     $(getfacl -p /dev/dri/card0 2>/dev/null | tr '\n' ' ')"
    echo "  renderD128: $(getfacl -p /dev/dri/renderD128 2>/dev/null | tr '\n' ' ')"
else
    echo "(getfacl not available; acl pkg not installed)"
    ls -l /dev/dri/card0 /dev/dri/renderD128
fi
echo
echo "--- 5. elogind seat0 state (for the record) ---"
loginctl show-seat seat0 2>/dev/null | grep -E 'Id=|ActiveSession|Sessions|CanGraphical|CanTTY'
echo
echo "===== end DRM master probe $(date) ====="
chmod 0644 "$LOG" 2>/dev/null
echo "done -> $LOG"