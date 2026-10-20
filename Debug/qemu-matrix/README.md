# QEMU validation matrix — `Version-3.1.00 [BIOS-BOOT]`

Runtime evidence for the legacy-BIOS support release: install the real
installer into a fresh disk image under **SeaBIOS (legacy)** and under
**OVMF (UEFI)**, then cold-boot what it wrote and screendump the bootloader
menu and login prompt. `checks/check-bios-boot.sh` covers the static side
(this is the dynamic half).

## Files

| file | role |
|------|------|
| `run-case.sh <case>` | one case end to end: fresh qcow2 → boot the live medium with a **serial console** → drive the installer → probe the result → (non-dry) cold-boot the installed disk and screendump |
| `run-install.py` | the expect-style driver: logs in, preinstalls `gptfdisk`/`limine` (the ISO ships neither), mounts this repo over 9p, answers every prompt (bare Enter = default; explicit answers for the no-default prompts and the disk picker), then runs the post-install probe. Watchdog captures `*.stallN.png` when serial output stops. |
| `serial-expect.py` | one-off expect sessions (probe work); directives take the rest of the line **verbatim — do not quote them** |
| `qmp-dump.py`, `qmp-sendkey.py` | QMP screendump and keystroke injection (the LUKS passphrase at the cold boot is typed this way — the installed system has no `console=ttyS0`) |
| `ppm2png.py` | PPM → PNG, stdlib only |

## Prerequisites

- `qemu-system-x86_64` with KVM, and OVMF (`/usr/share/edk2/x64/OVMF_{CODE,VARS}.fd`)
- `python3`, `7z` (p7zip), and ~3 GB RAM per VM — **two concurrent cases** is
  the practical maximum on a 16 GB host
- the Void live ISO (the `20261016-kde` build was used for 3.1.00)
- the live kernel/initrd extracted once:
  `mkdir -p live-extract && 7z e -olive-extract <ISO> boot/vmlinuz boot/initrd`
- run the harness state from a **local disk** if the repo tree sits on
  removable media: with `./artifacts/`, the 9p source and the ISO all on a
  USB-attached btrfs, two overnight waves froze mid-install at the xbps
  unpack stage (guest `btrfs-transaction` hung-task spam → serial silent →
  rc=7, QMP still answering) on a day the host itself logged USB disconnects
  and stuck btrfs writers on that same drive. `run-case.sh` now prints a
  warning when a hot path is on removable media; pointing `VLI_DATA`,
  `VLI_SRC`, `VLI_ISO` and `VLI_LIVE_EXTRACT` at internal storage ended it.

## Running

```sh
bash run-case.sh dryrun-bios-limine     # read-only plan walk (fast)
bash run-case.sh bios-limine-plain      # full install under SeaBIOS
bash run-case.sh bios-grub-encrypt      # ENCRYPT case (passphrase typed at boot)
bash run-case.sh uefi-grub-plain        # OVMF control: must show NO ef02 row
```

Cases: `dryrun-{bios,uefi}-{limine,grub}`, `bios-{limine,grub}-{plain,encrypt}`,
`uefi-{limine,grub}-plain`, and `iso-bios-media` — a media-path case that
ignores the installer entirely and boots the **real ISO under SeaBIOS with no
`-kernel`**, first as a CD (El Torito) and then as the isohybrid image
attached as a raw disk (what a flashed USB stick looks like to firmware).
Every install case hand-feeds QEMU the extracted kernel/initrd, so without
this case nothing in the matrix ever exercises the medium's own boot chain;
success is judged from the screendumps (the live console is VGA-only, so
serial stays silent by design) plus a count of distinct screens.

Nothing machine-specific is baked in (the project's sanitize deny-list blocks
local usernames, hostnames and the removable-media identifier): the medium
defaults to `./void-live.iso` — symlink it — and the per-case output (qcow2,
logs, PNGs) to `./artifacts/`, both gitignored. Override any of it with
`VLI_ISO`, `VLI_DATA`, `VLI_SRC` (the installer tree to 9p-mount),
`VLI_LIVE_EXTRACT`, `VLI_OVMF` and `VLI_SOCKDIR`. Optionally `VLI_CACHE`
(mklive-style `xbps-cachedir-<arch>` directory): it is shared into the
guest read-WRITE as `/mnt/vlicache` and the driver types that path at the
installer's "Use a local package cache?" prompt, so package fetches come
from local 9p instead of the network — unset means the bare-Enter
network-only default, exactly as before.

Two properties to know before touching this while a case runs:

- the serial/QMP sockets live in `VLI_SOCKDIR` (default `/tmp/vlio-sock`),
  deliberately **not** next to the artifacts: `AF_UNIX` paths stop at 108
  bytes and the repo tree is deep enough on removable media that an in-tree
  socket dir reached 172 chars and killed every case at startup;
- the harness re-executes itself from a private copy under `$TMPDIR`, so
  editing `run-case.sh` mid-run only ever affects the **next** case. bash
  reads a script as it executes, which is why an in-place edit once aborted a
  case mid-line (`VLI_SNAPSHOT=0` opts out).

## What a passing case looks like

- `*.driver.out`: every prompt answered once (no re-prompt loop), then
  `plan check …` (dry) or `phase verify … ===ENDV12===` (real)
- `*.log`: `==> Boot mode: …` banner, and for BIOS the plan/destructive line
  `ESP(+NG) + 1M ef02 BIOS boot + LINUX parts`
- verify block: `sgdisk -p` = p1 ESP / p2 `ef02 BIOSBOOT` / p3 `LINUX`,
  `/mnt/boot/efi` holding `EFI/BOOT/limine.conf` **plus** root `limine.conf`
  and `limine-bios.sys` (BIOS), `install-config` `BOOT_MODE=…`
- `*-boot{10,20,40,90,135}.png`: bootloader menu, then the login prompt

## Harness findings that shaped this matrix (test-side, product untouched)

1. **OVMF must be active in the LIVE session too** — `BOOT_MODE` is derived
   from `/sys/firmware/efi` on the machine that runs the installer; a live
   session booted by `-kernel` without OVMF correctly reports `bios` and turns
   a UEFI control case into a second BIOS case.
2. **Under OVMF the IDE CD is invisible to the kernel**: `ata_piix` probes both
   PIIX channels and finds no device (the same `-cdrom` + SeaBIOS boots and
   sees it), so dracut's `root=live:CDLABEL=` fails and the run drops to the
   emergency shell. Attaching the same ISO as a **second virtio disk** fixes it
   (label lookup is bus-independent); the target image is attached first so it
   keeps `/dev/vda`.
3. **Case names are matched as substrings** (`*uefi*`) — `uefi*)` silently
   classified `dryrun-uefi-*` as BIOS.
4. The driver sends **`S`** at the `REBOOT_DELAY` countdown (default 20 s!) so
   a finished install does not reboot away from the disk probe, and picks the
   disk by looking up `/dev/vda` in the menu (QEMU's PC machine exposes a
   floppy controller, so `1)` can be the 4 KiB `/dev/fd0` — see TODO.md).
5. **The live KDE session suspends the whole machine a few minutes in.** Two
   shapes were hit:
   - a hard **ACPI S3** — QMP answers `{"status": "suspended"}` (not
     `"paused"`, which would mean someone sent `stop`), and the guest resumes
     with `INFO: task … blocked for more than …` in the log;
   - **suspend-to-idle** — needs no firmware transition, so QMP keeps
     answering `{"status": "running"}` while every guest task is frozen, the
     serial link goes dead mid-`xbps-install`, and disk I/O drops to zero.
     Invisible to a status check, so it twice looked like a dead install.
   Layered fix: every QEMU launch carries
   `-global PIIX4_PM.disable_s3=1 -global PIIX4_PM.disable_s4=1` (kills the
   hard S3, which is the one that damages the guest on resume); the driver,
   right after login, runs a **no-sleep preamble** that stops the display
   managers (PowerDevil is the requester) and elogind, then bind-mounts
   `/dev/null` over `/sys/power/state` so any surviving sleep request is
   written into the void instead of freezing the guest; and the watchdog
   fires a `system_wakeup` IRQ on any stall regardless of the reported
   status (a no-op when awake, a revival when frozen). The watchdog also
   keeps a 60 s heartbeat after its 5th screenshot and aborts with rc=7 after
   7 min of genuinely dead serial — before this, it stopped reporting after
   the 5th screenshot and the case hung silently until the outer timeout.
   A third freeze (2026-10-20, `bios-limine-plain` + `uefi-limine-plain` in
   parallel, both rc=7 ~35 min in, mid-`xbps-install`) read as the preamble's
   layers losing silently: the stall screendump showed the live session's
   **lock-screen clock**, so `timeout 5 sv stop sddm` looked like it had
   expired mid-teardown under parallel-guest load, leaving sddm (hence
   PowerDevil) alive to request sleep. The preamble was hardened accordingly:
   force-kill the survivors by name (`sddm`, the bracket-patterned
   `sdd[m]-helper`, `Xorg`, `powerdevil5`), read the `/sys/power/state` bind
   back to verify it, and report every layer in the marker line itself —
   `NOSLEEP_OK_40 bind=yes dm=down x=down` — with a warning naming the exact
   layer that failed.
   The fourth freeze (the re-run of those same two cases) closed the
   investigation: **all three layers reported green, and both guests wedged
   again at the identical mid-unpack point** — so sleep was never the cause.
   The forensics said I/O: no `Freezing of…`/`PM:` lines anywhere in either
   guest log (suspend always announces itself on the console), only hung
   tasks blocked on `btrfs-transaction` waiting for writes, QMP still
   screendumping happily (QEMU itself alive), and the HOST log that same day
   showing USB disconnects plus its own btrfs writers stuck 245 s+ on an
   rw-semaphore — while every byte of harness state (the qcow2s, the 9p
   source, the ISO, kernel/initrd) sat on that USB-attached btrfs. The guests
   were I/O-wedged on a sick bus, not asleep; the "lock-screen clock" was
   merely the screensaver of an idle-locked live session. The fix is
   environmental and now ships with the harness: keep state on a local disk
   (Prerequisites — the internal-disk re-run sailed through the exact phase
   that froze twice), and `run-case.sh` warns whenever any hot path resolves
   to removable media. The sleep defenses stay in place — S3 was real and
   evidenced, they cost nothing, and the watchdog's rc=7 covers both death
   shapes.

6. **`qmp-sendkey.py` had never typed a single key, in any run.** Two
   independent bugs, both invisible because every QMP error was swallowed and
   the caller discarded the script's exit status:
   - the HMP bridge argument is `command-line` (**hyphen**) — the script passed
     Python's `command_line`, so QMP answered `Parameter 'command-line' is
     missing` for every key and the guest received nothing at all;
   - bash single quotes hand `'testpass1\n'` over as a *literal* backslash-n,
     so even with the name fixed the string would have ended in `sendkey \`
     (unknown key name) and the password would have arrived without its Enter.
   The tell was forensic: the `boot135` screendump (taken 45 s after the
   unlock attempt) was **byte-identical** to `boot40`, and the log's
   `typed 11 chars` was counting the backslash and the `n`. Fixed by decoding
   the escapes in the script, passing `**{"command-line": …}`, and making
   every QMP error fatal and printed. The cold-boot step now *polls* for the
   screen to change after the unlock instead of sleeping blind — and the
   artifacts from that very bios-grub-encrypt run (rc=0, prompt still on the
   screen 40 s after "typing") showed a single-change poll is not enough:
   cryptsetup never echoes, so the first post-typing frame differed from the
   pre-typing one only by the prompt's cursor cell, and a dracut re-prompt
   after a WRONG passphrase counts as one change too. The poll is therefore
   two-stage — the frame must change within 90 s AND keep changing over the
   next 30 s (an unlocking boot floods the console, a re-prompted one goes
   static) — and a failed unlock now FAILS the case with rc=8 instead of
   warning past a green summary. The case was re-run to rc=0 under that
   stricter judge — `typed 10 chars`, both stages seeing the console keep
   moving, and the post-unlock frame booting from
   `registered: /dev/mapper/void-root`.

## What the matrix caught in the product (fixed in this release)

Both failure classes below were invisible to every static gate and to the
GRUB cases; only the full bootloader × firmware matrix surfaced them.

1. **`bios-limine-plain` rc=4 — the ef02 gate could never pass.** It compared
   `BIOSBOOT_PN` (`2`) against raw `lsblk -no PARTN` output, whose column is
   *right-aligned*: the captured value is `" 2"`, a leading space, so the
   strings never compare equal — the gate refused the very table the verify
   probe had just printed as p1 EF00 / p2 EF02 / p3 8300. (The earlier
   rootless proof masked the pad by stripping whitespace before comparing.)
   The gate now asks the kernel first —
   `/sys/class/block/<name>/partition` needs only the `/sys` rbind Stage 2
   mounts and emits a bare `2` — keeps a whitespace-stripped `lsblk` fallback,
   and refuses only on positive evidence, naming both sources in the FATAL so
   the log alone diagnoses the next miss. `check-bios-boot.sh` grew six checks
   pinning that shape (42 total).
2. **`uefi-limine-plain` rc=5 — a prose backtick in an unquoted heredoc.**
   `install-config` is written with `<< INNER_EOF` (deliberately unquoted so
   `${VAR}` bakes in), and the new 3.1.00 `BOOT_MODE` row's comment said
   "hence the `<unset>` fallback" — bash evaluated the backticks as a command
   substitution during heredoc expansion, `<unset>` tokenized as `< unset >`
   with a dangling `>`, and `set -eE` turned the failed `cat` into
   `Install failed (exit 2)` immediately after `install_pkgs limine`. The GRUB
   cases stayed green because the write sits **inside** the bootloader `else`
   (Limine) branch — that branch does not close until well below it, at the
   `# End of GRUB/Limine branch` `fi`, so GRUB runs never execute the write at
   all — which is exactly why the matrix needs both bootloaders. All prose
   backticks in that body are gone
   (two pre-existing ones also silently ran `xbps-query -X flatpak` /
   `virtualbox-ose` as real commands at write time), and `check-heredocs.sh`
   now fails any unquoted body that carries one.

## Not committed

None of the heavy state reaches git: `void-live.iso` (the symlink), the
≈260 MB `live-extract/` and the whole `artifacts/` tree (per-case qcow2,
logs, PNGs) are ignored — only the seven harness scripts above are tracked.
