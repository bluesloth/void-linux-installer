# Live-validation runbook — MULTI-FS (Beta-v2.9.38)

One-page checklist for proving the `[MULTI-FS]` data-region layout on the
target medium (a real/modular Void Linux Live environment — never the dev
box). Run in the order below. Every scenario that passes gets a one-line
verdict logged at the bottom; anything that fails gets captured BEFORE
rebooting: `# Void_Linux_Installer.sh --save-log` (mounts a USB stick first)
drops the crash post-mortem journal + `.info` to the stick, and a successful
install already archives `installer-run.log` to
`/etc/void-installer/installer-run.log` in the target for the same audit
lines.

Gates before and after, on every scenario:
`bash -n Void_Linux_Installer.sh` + `Debug/check-defaults.sh` (72, ALL
CONSISTENT) + `Debug/check-heredocs.sh` (65, ALL CLEAN).

---

## Scenario A — all-default, no carve (the 2.9.37 regression tripwire)

Take every default (bare Enter) → `REGION_PARTITIONED` empty, flat
all-Btrfs layout byte-identical to 2.9.37.

- [ ] Disk picker shows, install runs with NO region prompts beyond the
      six filesystem pickers (defaults accepted silently).
- [ ] `lsblk`: p1 ESP, p2 KEY root btrfs. NO extra region partitions.
- [ ] `/etc/fstab` has the @subvol rows (home/opt/srv/cache/var) exactly as
      a 2.9.37 install.
- [ ] Boot to desktop; `snapper ls` clean; no subvol/snapshot surprises.

## Scenario B — single ext4 `/home` carve

`REGION_HOME_FS=ext4` + a size. `/home` leaves the Btrfs tree entirely.

- [ ] `lsblk`: p1 ESP, p2 ext4 home region, p3 LINUX btrfs (LINUX LAST).
- [ ] `/mnt/home` mounts the region during install; chroot layout == boot
      layout.
- [ ] fstab has `UUID=… /home ext4 defaults,noatime 0 2` and NO @home/
      @usercache/browser/@game/@containers-user/@linuxbrew/@virtualbox rows.
- [ ] `void-subvol-tool.sh list` refuses to add an owned home subvol with
      the `MULTI-FS-GUARD` message and does not unmount/break the region.
- [ ] User login lands on the ext4 /home; browser/game isolation prompts
      correctly report "folded (home is a partition)".

## Scenario C — btrfs leaf carve (`/var` + `/var/cache` + `/srv`)

`REGION_VAR_FS=btrfs`, `REGION_CACHE_FS=btrfs`, `REGION_SRV_FS=btrfs`.

- [ ] `lsblk`: regions in FIXED order var, cache, then srv, then LINUX last.
- [ ] Mounts use `nodatacow,compress=none` for var-layer regions,
      `compress=zstd:1` for srv.
- [ ] fstab region rows btrfs `0 0` (no fsck); NO @log/@spool/@network/
      @sddm/@lightdm/@libvirt/@flatpak/@docker/@containers rows; NO @cache/
      @srv rows.
- [ ] `@swap` stays on the root Btrfs (swapfile works, hibernation resumes)
      even though `/var` is carved.

## Scenario D — games carve on top of a home carve

`REGION_HOME_FS=ext4` + `REGION_GAMES` (e.g. 40G). Proves the mixed
"region + subvol-in-region" combination. **PROVEN on <host> (2026-09-17,
Beta-v2.9.66 carved ENCRYPT).**

- [x] `/home/<user>/Games` mounts the games partition inside the ext4 home.
      (<host>: `void2` ext4 → `/home/<user>/Games`, `installer-run.log`
      `mkfs 'games' (ext4)` + mount + fstab row `531c6cb0… /home/<user>/Games`.)
- [x] `@game` is folded out; no fstab/mount/subvol-tool collision; games
      chown after useradd lands on the partition.
      (<host>: `PROVISION_GAME_SUBVOL=false`, no `@game` anywhere; the host-side
      subvol-tool probe confirms `region_fs` reads ext4 and the guard fires.)
- [x] Steam/Lutris/other launchers install into the partition, not @home.
      (<host>: steam installed; home is a partition, so the launcher datadir
      lives there — no `@game`/`@home` subvolume involved.)

## Scenario E — ENCRYPT=yes + regions (INNER GPT inside LUKS2) — PROVEN (<host> 2026-09-17, Beta-v2.9.66/67 carved ENCRYPT)

`ENCRYPT=yes`, any carve. The region partitions live INSIDE the LUKS2
container as an inner GPT. The era's THE open validation is now CLOSED by a
full boot-to-desktop on `<host>` (installed with the corrected Beta-v2.9.66/67
script; KDE/SDDM, limine, `CRYPT_NAME=void`).

- [x] Inner carve runs after `luksOpen`; mapper partscan is forced by
      close+re-open (see `[MULTI-FS-PARTSCAN-FORCE]` and the later
      `[INNER-PARTSCAN-BOOT]`/`[INNER-PARTSCAN-DMPROBE]` closures).
      (<host> run log: `LUKS2 container created+opened for /dev/nvme0n1p2 ->
      /dev/mapper/void3`, inner carve after open; the box boots with the
      `98void-inner-partscan` runtime partscan proving the boot path.)
- [x] `lsblk`: outer ESP + LUKS p2; inside the mapper: region parts 1..N,
      LINUX root LAST.
      (<host> live: `nvme0n1p1` vfat ESP, `nvme0n1p2` crypto_LUKS; inside
      `void`: `void1` ext4 200G, `void2` ext4 400G, `void3` btrfs 345.9G
      LINUX root LAST.)
- [x] Region devices resolve (`{CRYPT_DEV}pN`) and mkfs/mount/fstab all
      operate on them; Btrfs root uses mapper-p(NREG+1).
      (<host>: resolved `/dev/mapper/void1..3` — CRYPT_NAME `void`, no `p`
      separator per `[INNER-DEV-NAME]`; fstab rows reference both region
      UUIDs and the btrfs root UUID `e6c29937…`.)
- [x] Cold boot unlocks and reaches the desktop with the region partitions
      mounted. (<host>: standing system — LUKS unlock, regions at
      `/home` + `/home/<user>/Games`, KDE/SDDM, keymap baked.)

---

## Batched pending items (carried with the target-medium run)

- Scenario C (btrfs leaf carve: `/var` + `/var/cache` + `/srv`) — unproven.
- Scenario B standalone (single ext4 `/home` without games) — the home-carve
  elements are proven as part of D/E on `<host>`; a clean single-carve run is
  still open.
- `browse_pick()` numeric-path browse hardening (review follow-up folded
  into the `[CRASH-USB-LOG]` commit 0a5bbfa) — verify a numeric-named entry
  and the `m`/`drives` jump both behave on /run/media.
- Beta-v2.9.47 TEE knobs (`DEFAULT_QUIET_BOOT`/`DEFAULT_TEE_BLACKLIST`) on
  real hardware — `<host>` runs both at the default `no`, so the `quiet` +
  `modprobe.blacklist=tee` fragment has never been exercised on a box.
- Headless boot-to-console (`DESKTOP_ENV=none`, DM none) + no dangling
  `/etc/sv/none`.

---

## Verdicts
_(log one line per scenario + date here; NEVER close an UNPROVEN checkbox
from the dev box)_

| Scenario | Date | Result |
|----------|------|--------|
| A | 2026-10-16 | **PROVEN** — fresh real-hardware install (<host>, <user>) of Beta-v2.9.96 via the Void-Linux-Live USB: all-default no-carve (REGION defaults, carved=<none>, all-Btrfs; nvme0n1p1 ESP + nvme0n1p2 btrfs, no extra region partitions), install COMPLETED, first boot reached an active KDE/SDDM graphical desktop |
| B | — | home-carve elements proven via D (<host>); standalone B not run (open) |
| C | — | not run (open) |
| D | 2026-09-17 | **PROVEN** — <host> carved ENCRYPT: `void1` ext4 → `/home`, `void2` ext4 → `/home/<user>/Games` (mkfs/mount/fstab + `_region_fs_of` end-to-end) |
| E | 2026-09-17 | **PROVEN** — <host> ENCRYPT+regions boot-to-desktop (inner GPT via `98void-inner-partscan`, regions mounted, keymap baked) |
| [FLATPAK-NM-DISPATCH-LOCK] flock | 2026-09-17 | **PROVEN** — fresh <host> first boot: exactly ONE `flatpak install` drain holding `fd 9` on `/var/lock/flatpak-firstboot.lock` (`lsof`); no burst pile-up (fluxed: 14:57 live), `.done` stamps when brave/heroic/bottles all succeed |