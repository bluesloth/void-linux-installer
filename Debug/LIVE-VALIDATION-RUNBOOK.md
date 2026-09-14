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
`bash -n Void_Linux_Installer.sh` + `Debug/check-defaults.sh` (67, ALL
CONSISTENT) + `Debug/check-heredocs.sh` (62, ALL CLEAN).

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
"region + subvol-in-region" combination.

- [ ] `/home/<user>/Games` mounts the games partition inside the ext4 home.
- [ ] `@game` is folded out; no fstab/mount/subvol-tool collision; games
      chown after useradd lands on the partition.
- [ ] Steam/Lutris/other launchers install into the partition, not @home.

## Scenario E — ENCRYPT=yes + regions (INNER GPT inside LUKS2) — UNPROVEN

`ENCRYPT=yes`, any carve. The region partitions live INSIDE the LUKS2
container as an inner GPT; this whole path was UNPROVEN at Beta-v2.9.38.

- [ ] Inner carve runs after `luksOpen`; mapper partscan is forced by
      close+re-open (see `[MULTI-FS-PARTSCAN-FORCE]` and the later
      `[INNER-PARTSCAN-BOOT]`/`[INNER-PARTSCAN-DMPROBE]` closures).
- [ ] `lsblk`: outer ESP + LUKS p2; inside the mapper: region parts 1..N,
      LINUX root LAST.
- [ ] Region devices resolve (`{CRYPT_DEV}pN`) and mkfs/mount/fstab all
      operate on them; Btrfs root uses mapper-p(NREG+1).
- [ ] Cold boot unlocks and reaches the desktop with the region partitions
      mounted. This is THE open validation of the era — log it explicitly.

---

## Batched pending items (carried with the target-medium run)

- ENCRYPT+regions from-scratch boot-to-desktop proof (Scenario E) — the
  remaining scope of the Beta-v2.9.45 `[INNER-PARTSCAN-DMPROBE]` closure.
- Fresh-install validation of the Beta-v2.9.37 `@game` derived multi-mount
  block (mounts + tool paths on a real Btrfs root).
- `browse_pick()` numeric-path browse hardening (review follow-up folded
  into the `[CRASH-USB-LOG]` commit 0a5bbfa) — verify a numeric-named entry
  and the `m`/`drives` jump both behave on /run/media.

---

## Verdicts
_(log one line per scenario + date here; NEVER close an UNPROVEN checkbox
from the dev box)_

| Scenario | Date | Result |
|----------|------|--------|
| A | | |
| B | | |
| C | | |
| D | | |
| E | | |