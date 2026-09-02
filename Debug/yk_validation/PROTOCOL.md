# Possession-only YubiKey boot — hardware validation protocol

Status: **REQUIRED before trusting a `YK_FALLBACK=no` install.** The boot
unlock path is real-hardware UNPROVEN (AGENTS.md invariant 12,
`[YK-KEYSCRIPT-BAKE]`). Everything here is by-hand on a live medium; nothing
runs on the dev box.

Target: a fresh v3.3.0-beta14 (or later) install, `ENCRYPT=yes`,
`YK_MODE=hmac-sha1`, **`YK_FALLBACK=no`**, `BOOTLOADER=limine`.
(YubiKey is a USB NFC/security-key making the possession-only pairing; note a
possession-only + LUKS boot is only as strong as the boot medium itself.)

## Artifacts under test

- `/usr/local/sbin/void-reveal-yubikey-key` — unquoted heredoc, `set -u`,
  slot + 40-hex challenge baked at install.
- `/usr/lib/dracut/modules.d/99void-yubikey/{module-setup.sh,cryptroot-ask.sh}`
  — 99 > 90crypt so our `/sbin/cryptroot-ask` override wins; keyscripts are
  exec'd with an **empty environment**, hence the bake requirement.
- `/etc/dracut.conf.d/90-system.conf` — adds `crypt` and `99void-yubikey`.
- LUKS layout — slot 0 removed by design; the YubiKey OTP is the only key.

## Phase A — wired correctly (live CD, after install, before reboot)

Run via the installed system's root (chroot from the medium or the booted OS):

    sudo ./Debug/yk_validation/probe_possession_only_boot.sh

Every check must say PASS, and section 6 must show **exactly one enabled
slot** (the OTP slot). Two enabled slots => the slot-0 removal failed and it
is really a YK_FALLBACK=yes layout. If the initramfs section is the only
failure, regenerate and recheck:

    xbps-reconfigure -f linux$(uname -r | cut -d. -f1-1)   # i.e. the kernel pkg
    # or: xbps-reconfigure -f $(ls /var/db/xbps/ | grep '^linux' | head -1)

## Phase B — cold boots (the actual risk)

1. Reboot with the key **removed**. Boot must NOT reach the login prompt:
   dracut prompts for the passphrase, and because no typed-passphrase slot
   exists it can never succeed. A timeout/hang at the prompt is the expected
   and safe outcome; an auto-boot is a FAIL (slot 0 survived, or the override
   is not winning `/sbin/cryptroot-ask`).
2. Insert the key, cold boot again. Expect Limine submenu → kernel → dracut
   runs the keyscript (touch if `YK_TOUCH=yes`) → unlocks → login prompt.
3. Reboot once more with the key removed but **falling back deliberately**:
   with slot 0 absent this must again hang at the prompt (proves the slot is
   really gone, not merely unlisted).

Any phase-B deviation is a P0 blocker for possession-only; do not ship that
state.

## Phase C — snapshot rollback under possession-only

1. Create a snapshot in normal use.
2. Boot into it from the Limine `+Snapshots` submenu (enter `Void Linux/Void
   Linux (<kernel>)` submenu → `+Snapshots` → pick it). Confirm it unlocks
   with only the key and boots into the snapshotted root.
3. Confirm the snapshot-overlay initramfs (`95snapshot-overlay`) mounts the
   overlay read-only and a `btrfs subvolume list` shows the snapshot w/o
   touching the live subvol.
4. Delete a snapshot from the booted system and confirm the Limine menu
   re-emits without it (the `00-void-limine-snapper-sync` plugin firing).

## Phase D — post-hoc resilience

1. On the booted system, `xbps-reconfigure -f <kernel-pkg>` (kernel-hook
   regen) then rerun Phase A probe — the assert suite must stay all-PASS. This
   proves the 15-min cron removal didn't cost menu/initramfs freshness.
2. `btrfs scrub start -B /mnt/vol` + a `fstrim` (the fstrim cron) — broken
   invariants would surface here as failures.

## GRUB note

`YK_FALLBACK=no` is FORCED back to `yes` under `BOOTLOADER=grub` (GRUB
LUKS2/Argon2i cryptodisk unreliability). Possession-only is therefore only
reachable via Limine; test it as such. Do not "test" a direct GRUB
possession-only variant — it is off-design.

## Record the result

After the phases, log outcome + the probe's 6 sections into this file's git
history note or the CHANGELOG `[YUBIKEY]` entry. Until then, AGENTS.md
invariant 12 stands: possession-only is UNPROVEN.