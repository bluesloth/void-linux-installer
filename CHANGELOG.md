# Changelog — Void Linux Unified Installer

> **Reconstruction note:** The original companion CHANGELOG for this
> project was lost. This file is a reconstruction, generated directly from
> the inline `AI (...)` feature markers embedded in `Void_Linux_Installer.sh`
> (which self-documents its history through `[TAG]` markers in comments) and
> incorporating the most recent work in this session. Inline documentation
> of changes began at **v3.1.0-beta1**; pre-3.1.0 history (the section
> references such as §3.19, §4.7, Open Items, etc. that survive in the
> script's comments) is only partially recoverable and is noted where it
> applies.

Current version: **3.3.0-beta7** (`SCRIPT_VERSION` in the script).

---

## v3.3.0-beta6 — optional LUKS2 full-disk encryption

- **`[ENCRYPT]`** — an opt-in, prompt-gated full-disk encryption toggle
  (`[y/N]`, default off), marking the biggest capability gap in the
  recovery-first design: Snapper and `btrfs scrub` protect against damage a
  user *makes* (logical/accidental and bitrot respectively), but nothing
  previously protected the system from a *stolen disk*. With encryption on,
  partition 2 (the Btrfs filesystem) becomes a LUKS2 container (`cryptsetup
  luksFormat --type luks2`), and the entire machine is rebuilt inside the
  opened mapper device `/dev/mapper/void-root`:
  - **Passphrase-driven, typed at every boot** — the user sets a passphrase
    (typed twice, hidden via `read -s`, matching-checked) during install.
    It is fed to `luksFormat`/`luksOpen` via stdin (`--key-file=-`), so it
    never appears on the command line or in the process list, and is unset
    from memory as soon as the volume is open. At boot, dracut's `crypt`
    module prompts for it before root is mounted. YubiKey/key-based unlock
    is a **deliberately deferred** follow-up; today the only method is the
    typed passphrase.
  - **One cross-cutting rule, three careful placements** — `BTRFS_UUID`
    (the Btrfs filesystem's UUID, read from the mapper `$BTRFS_DEV`) and
    `LUKS_UUID` (the ciphertext container's UUID, read from `$PART_SYS`)
    are different: `BTRFS_UUID` drives fstab, `root=`/`resume=`, and the
    swapfile; `LUKS_UUID` drives `/etc/crypttab`
    (`void-root UUID=$LUKS_UUID none luks`) and the `rd.luks.uuid=` /
    `rd.luks.name=` kernel params. The swapfile and its resume offset live
    inside the LUKS volume, so hibernation resumes after the passphrase
    unlocks it (`resume=` stays on the Btrfs filesystem UUID).
  - **Bootloader parity** — both GRUB (`/etc/default/grub` `GRUB_CMD`) and
    Limine (`void-limine-write-conf` `BASE_CMD`) bake in `rd.luks.uuid=` +
    `rd.luks.name=` when encrypted. The GRUB snapshot entries inherit the
    rd.luks params because grub-btrfs copies the main boot entry's cmdline;
    the Limine snapshot sub-entries inherit them from `BASE_CMD`. The
    `[ENCRYPT]` knowledge is persisted to limine-env (`ENCRYPT`, `LUKS_UUID`)
    exactly like the wallpaper choice, so every cron/kernel-hook resync
    re-emits it.
  - **Resume-aware** — the `ENCRYPT=yes` flag is persisted in the resume
    state file, but the passphrase is NOT (it is in-memory only). A crashed-
    then-resumed run restores `ENCRYPT` from state, finds the mapper closed,
    and re-prompts for the passphrase before mounting.
  - **Package/dracut gating** — `cryptsetup` is installed into the target
    and the dracut `crypt` module is appended to 90-system.conf ONLY when
    `ENCRYPT=yes`; an unencrypted install gets neither. Confirmed in the
    CONFIRM step, dry-run plan, and post-install summary as `Encryption:
    LUKS2 full-disk (passphrase required at boot)` / `none`.

---

## v3.3.0-beta7 — optional YubiKey hmac-sha1 unlock

- **`[YUBIKEY]`** — the deferred follow-up to `[ENCRYPT]` is now a real
  feature: optional YubiKey-based unlock of the LUKS2 volume, eliminating
  the typed-passphrase-at-every-boot requirement when `ENCRYPT=yes` and a
  compatible YubiKey is present.
  - **hmac-sha1 challenge-response** — the installer (when `ENCRYPT=yes`)
    prompts to program an OTP slot with `ykpersonalize -ochal-resp -ochal-hmac
    -ohmac-lt64` (slot 1/2, optional `-ochal-btn-trig` touch), binds
    `HMAC-SHA1(slot_secret, challenge)` as an *additional* LUKS key slot via
    `cryptsetup luksAddKey`, and writes a dracut `keyscript=`
    (`/usr/local/sbin/void-reveal-yubikey-key`) into crypttab
    `void-root UUID=$LUKS_UUID none luks,keyscript=...`. At boot dracut's
    cryptroot-ask runs the keyscript, which re-challenges the YubiKey with
    `ykchalresp` and feeds the response to `luksOpen` — no typed passphrase.
  - **Boot-time fallback (`YK_FALLBACK`)** — `yes` (default) keeps the typed
    passphrase slot (slot 0) as a boot fallback: if the YubiKey is
    absent/wrong, dracut's cryptroot-ask falls back to the passphrase prompt
    automatically. `no` (possession-only) removes slot 0 with
    `cryptsetup luksRemoveKey` so the YubiKey is the *only* way in; that
    tighter mode is forced back to `yes` under `BOOTLOADER=grub` (GRUB's
    LUKS2/Argon2i `cryptodisk` path is unreliable, so a possession-only
    bootloader absolutely must be guaranteed to read the encrypted volume —
    Limine booting dracut is the safe pairing).
  - **Memory-only credential** — the HMAC response (`YK_KEY`) is computed
    during enrollment, used to `luksAddKey`, and `unset`/shredded — never
    written to the state file, limine-env, chroot_env, or install-config.
    Only public values (`YK_MODE`, `YK_SLOT`, `YK_CHALLENGE`, `YK_FALLBACK`,
    `YK_TOUCH`) are persisted (the challenge is not itself a credential; the
    response is). Same secret-free rule as the passphrase.
  - **Package/dracut gating** — `ykpers` (`yubikey-personalization`) is
    installed on the live medium and into the target ONLY when
    `YK_MODE=hmac-sha1`; the dracut `60void-yubikey` module (which `inst`s
    the keyscript + `ykchalresp` + libusb into the initramfs) is only built
    and added to 90-system.conf then. The resume path re-challenges the
    key (falling back to the passphrase only when a fallback slot exists,
    else FATAL — possession-only).

---

## v3.3.0-beta5 — monthly btrfs integrity scrub

- **`[SCRUB]`** — the physical-corruption half of the recovery story,
  complementing Snapper (which guards against logical/accidental damage).
  Snapper's timelined snapshots and the dracut overlay protect the system
  from bad changes a user *makes*; nothing previously protected it from a
  disk silently *losing* data to bitrot. A new
  `/etc/cron.monthly/btrfs-scrub` job (written inside the shared chroot
  tail, right after the existing `fstrim-nvme` cron.weekly entry and using
  the same cronie-provided mechanism) runs `btrfs scrub start -B -d` and
  appends a date-stamped, per-filesystem record to
  `/var/log/btrfs-scrub.log`:
  - **One scrub per filesystem, not per subvol mount** — every subvolume
    mount of a Btrfs filesystem shares the same underlying `major:minor`, so
    the mount list is read from `/proc/self/mountinfo`, deduped on field 3
    with `sort -k1,1 -u`, and scrubbed once per unique device. A second
    scrub of the same fs would otherwise be refused by Btrfs anyway; this
    just makes the run clean instead of logging a needless failure.
  - **Never forced (`-f` deliberately omitted)** — if a manual scrub is
    already in flight, `btrfs scrub start` fails fast and the exit code is
    logged, so the monthly pass never races a running scrub onto the same
    volume.
  - **Guarded & self-limiting** — bails out cleanly (exit 0, no log noise)
    if no Btrfs filesystem is mounted, and refuses to run if the `btrfs`
    binary is missing (exit 1 to stderr, the cron-mail failure path).
  - This is a provisioning-only addition: the job is installed
    unconditionally inside the shared chroot tail (both bootloaders, every
    desktop option), needs no prompt, no state-file entry, and has nothing
    to echo in the dry-run plan or final summary.

---

## v3.3.0-beta4 — event-driven Limine snapshot-menu sync

- **`[CONFIRM]`** — a post-ERASE, pre-partition final review. Immediately after
  the wipe confirmation, the installer prints a complete summary of every
  install-time choice (target disk, hostname, primary user + login shell,
  desktop/DM, session stack, bootloader + kernel access + wallpaper, locale/
  timezone, mirror, swap/hibernation, account model), then asks whether to
  proceed. Pressing **Enter** continues to the destructive partitioning;
  typing **R** re-runs the entire configuration from the top (removing any
  stale state file first so the re-run starts clean instead of offering a
  resume) — nothing has been written to disk yet, so backing out is free. The
  step lives inside the skipped-on-resume block, since a resumed run already
  had its config reviewed before the interrupted run. This gives a second,
  information-dense confirmation after the ERASE gate and before any disk I/O.
- **`[ERASE-CONFIRM]`** — the fresh/normal-disk wipe confirmation no longer
  requires typing the exact device path. It is now the single word `ERASE!`
  (all caps with the exclamation mark); the chosen disk is still displayed
  prominently right above the prompt. The **already-installed-Void re-run
  path keeps the stricter `ERASE <device>` exact-path bar** (that is the
  scenario with the most to lose, so the fat-finger device round-trip is
  retained there). The two confirmation paths remain distinct and
  device-independent confirmation is now purely the `ERASE!` word.
- **`[SHELL]`** — real login-shell choice. The primary user account is no
  longer hardcoded to `/bin/bash`; the prompts offer bash (default, bundled in
  base-system so it needs no package), zsh, fish, or mksh. The chosen shell
  binary is stored as `USER_SHELL` with its providing package in
  `USER_SHELL_PKG` (empty for bash). The chroot installs `$USER_SHELL_PKG`
  (if any) before `useradd`, then creates the account with `-s "$USER_SHELL"`
  instead of the hardcoded bash. Both variables are carried into `chroot_env`
  with a hard in-chroot validation (a missing shell aborts rather than
  creating a bogus `-s` path), persisted in the resume state file so a resumed
  run restores the choice, recorded in `install-config`, and echoed in both
  the `--dry-run` plan and the post-install summary. Only bash/zsh/fish/mksh
  are offered (no dash/busybox ash) — these are the shells verified against
  Void packaging.
- **`[SNPR-EV]`** — Limine's snapshot boot menu now updates the moment a
  snapshot is created/deleted, instead of waiting up to 15 minutes for the
  cron job. This is a *correction* of an earlier empirical assumption:
  - The v3.1.0-beta1 `[LIMINE-SYNC-CRON]` design rationale claimed Void's
    snapper "ships no general pre/post-snapshot hook mechanism," which is why
    it fell back to a `/etc/cron.d` entry (the menu could be minutes stale).
  - That premise was **refuted on target hardware**: a diagnostic probe
    (`Debug/snpr_ev/probe_void_snapper_plugin.sh`) dropped a temporary plugin into
    `/usr/lib/snapper/plugins`, created/deleted one throwaway snapshot, and
    observed `create-snapshot-pre`, `create-snapshot-post`, and the whole
    `delete-snapshot-pre/post` family firing. Void's snapper DOES execute its
    plugin directory (matches snapper(8): "plugins have to be placed in
    /usr/lib/snapper/plugins").
  - So the installer now writes a **Void-native snapper plugin**,
    `/usr/lib/snapper/plugins/00-void-limine-snapper-sync`, inside the Limine
    branch only (GRUB gets nothing — the two bootloader paths stay fully
    separate, invariant #5). snapper invokes it as
    `ACTION SUBVOL FSTYPE SNAPNO`; it acts only on `create-snapshot-post` and
    `delete-snapshot-post` (one menu regen per snapshot CREATE/DELETE, not the
    pre/post/in-progress threesome) and calls the same shared
    `/usr/local/sbin/void-limine-write-conf` the kernel hook and cron use — so
    there is still exactly one copy of the menu-generation logic. It runs as
    root (snapperd is runit-supervised), regenerating the menu for free.
    **Naming caveat (found & fixed during validation):** snapper requires the
    plugin name to START WITH A DIGIT (man snapper, PLUGINS: "The name has to
    start with a digit, execution order is alphabetical") — a letter-prefixed
    plugin is silently ignored. This entry therefore uses the `00-` prefix;
    the initial build named it `void-limine-snapper-sync` and it never fired
    on the target box (the probe "worked" only because it was `00-void-probe`).
    See `Debug/snpr_ev/SNPR_EV_findings.md` for the full investigation.
  - The 15-min `/etc/cron.d/void-limine-sync` entry is **kept as a safety net**
    for any menu change the plugin path might miss, but is demoted from the
    primary mechanism. The old v3.1.0-beta1 comment is preserved (striking its
    false "no hook" premise is a history edit) and explicitly marked SUPERSEDED
    for the record.
  - Scope decision (user-confirmed): keep the cron fallback rather than
    deleting it; the change is additive, off by default for GRUB, and
    self-contained — no vendored `limine-snapper-sync`, no new dependency.
- **`[NODATACOW]`** (fix) — the churn-heavy var subvolumes
  `@srv`/`@cache`/`@log`/`@spool`/`@tmp` are now actually made
  `nodatacow,compress=none`. Previously the installer relied on a pre-mount
  `chattr +C` on the mountpoint dirs, which is shadowed the instant the
  subvolume mounts over them — so the documented "deliberately nodatacow for
  churn-heavy var subvols" intent was silently not achieved (they got plain
  COW + zstd:1). Now applied via the subvolume mount options and the matching
  fstab entries, matching the existing `@swap`/`@libvirt` pattern.
  Follow-up cleanup (same release): every remaining `chattr +C` call was
  removed as ineffective — `@swap` (mounted `nodatacow,compress=none` already,
  plus `btrfs filesystem mkswapfile` sets nodatacow on the file itself) and the
  browser subvols (their fstab mount options already carry `nodatacow`). A
  post-mount `chattr +C` touches the covered mountpoint inode, not the
  subvolume, so none of them could take effect; the mount/fstab options remain
  the single source of nodatacow.
- **`[PIPEFAIL]`** (hardening) — extends the top-level `set -o pipefail`
  (documented at v3.3.0-beta3) so it actually reaches the chroot boundary and
  the generated-helper shebangs, which previously only had bare `set -e`. The
  `CHROOT_EOF` transaction block now opens with `set -eEo pipefail`, and every
  scripted helper declares its full option set instead of bare `set -e`:
  `set -eEo pipefail` for the `/bin/bash` helpers
  (`void-limine-write-conf`, `void-limine-sync-kernels`,
  `00-void-limine-snapper-sync`) and `set -eu` for the POSIX `/bin/sh` helper
  (`/etc/kernel.d/post-install/50-sync-limine-kernels.sh`, dash has no
  `pipefail`). Previously a masked mid-pipeline failure in a boot-affecting
  step could silently continue.
- **`[INSTALL-PKGS]`** (hardening) — `install_pkgs()` now refreshes the index
  (`xbps-install -Sy`) and reconciles the package db (`xbps-pkgdb -a`) between
  mirror retries. A mid-transaction failure can leave the xbps db marked
  dirty/locked; previously all three mirrors could fail for the same stale
  root cause. Both recovery steps are best-effort (`|| true`) so they can't
  mask a genuine install failure.
- **`[PREREQ]`** (hardening) — two fail-fast guards. (1) The installer requires
  root from step one (it partitions/formats real disks): an early
  `id -u` check aborts with a clear message instead of a cryptic
  "permission denied" from the first `mount`/`sgdisk`. (2) After the live-CD
  package sync, a dependency gate verifies every tool the OUTER (live-medium)
  stage invokes directly — `sgdisk mkfs.fat mkfs.btrfs btrfs parted openssl
  mount umount chroot lsblk blkid xbps-install` — aborting before the
  destructive partitioning step if any is missing. Tools used only INSIDE the
  chroot are deliberately excluded (they are installed INTO the target via
  xbps, not the live env), so this can't false-positive on a correct live
  medium.
- **`[PREREQ-CURL]`** (fix) — `curl` was mistakenly listed in the OUTER
  `[PREREQ]` dependency gate, but no inner/live-CD sync step installs it and
  every `curl` call in the script happens INSIDE the chroot (the COSMIC repo
  reachability probe and the distrobox install). The Void live medium does not
  always ship `curl`, so on such a system the gate aborted with
  `FATAL: required Live-CD command not found: 'curl'` even though the live-CD
  package sync itself succeeded. `curl` is removed from the outer gate (it was
  never an outer-stage tool), and — to close the same hole silently lurking in
  the chroot — `curl` is now installed early into the target as part of the
  base package set (before the COSMIC/distrobox steps that call it), instead of
  only in the much-later package list.
- **`[FLATHUB-CHROOT]` / `[FLATHUB-RCL]`** (fix) — Flatpak's first-boot hook
  hung the boot with a "Flathub idx / Failed to fetch summary" error whenever
  Flatpak was selected. Root cause: the flathub remote was added
  synchronously in first-boot `/etc/rc.local`, which runs in runit stage 2
  BEFORE NetworkManager has a connection up. `flatpak remote-add --if-not-exists
  flathub https://flathub.org` is a BLOCKING network fetch (it downloads
  `flathub.flatpakrepo` + `summary.idx`), so with no route to flathub it spun
  on DNS/connection retries and blocked the whole boot. Two-part fix:
  `[FLATHUB-CHROOT]` adds the flathub remote NOW, inside the chroot at install
  time, where the live-CD's network is already up (the package sync just used
  it) — so the metadata fetch happens before first-ever boot instead of
  racing it; `[FLATHUB-RCL]` rewrites the rc.local flatpak block to (a) treat
  the remote-add/modify as guarded idempotent no-ops, (b) wait (bounded) for
  `flathub.org` to resolve, and (c) launch any queued app install in a
  BACKGROUND subshell — so rc.local can never block boot on the network or
  on flatpak. Only affects installs that selected Flatpak; GTK/Slick are
  otherwise unaffected (the Slick "hang" was this same network-blocked
  rc.local, not the greeter).
- **`[LIGHTDM-ATOMIC]`** (fix) — `/etc/lightdm/lightdm.conf` is now written
  to a temp file and renamed into place, instead of a direct `>` redirect.
  This config carries the mandatory `session-wrapper` (see `[LIGHTDM-SWRAP]`),
  so a mid-write interruption could previously have truncated it; the atomic
  write prevents a torn/partial config.
- **`[NM-IFACE]`** (fix) — NetworkManager's `[connection] interface-name=` is a
  LITERAL device name, not a glob (only `[match]` globs). The NIC-detection
  fallback `NET_INTERFACE_MATCH="enp*"` was being written verbatim as
  `interface-name=enp*` into the `br0-slave.nmconnection`, which can never bind
  to a real device. When only the wildcard placeholder is present (no concrete
  NIC auto-detected), the `interface-name=` key is now omitted entirely so the
  bridge-slave is matched by role (any free ethernet device) — the intended
  fallback. The normal detected-NIC path (a concrete name) is unchanged.
- **`SWAPFILE_MODE` resume fix** — `SWAPFILE_MODE` (derived from `SWAP_BACKEND`)
  drives `@swap` subvolume creation, the swapfile mount, mkswapfile, and the
  fstab swap entries, but was NOT in the persisted state-file list. On a
  resumed run the prompt block that sets it is skipped, so it came back empty and
  all those swap steps were silently skipped — a broken-hibernation resume
  defect. `SWAPFILE_MODE` is now persisted in the state file so it is restored
  on resume.
- **`TARGET_PASS_HASH` resume fix** — same class of defect as the `SWAPFILE_MODE`
  one above. `TARGET_PASS_HASH` was exported into `chroot_env.sh` (where
  `chpasswd -e` consumes it) but was MISSING from the persisted state-file
  list, even though the hashing block that produces it is skipped on a resumed
  run (both hashes are supposed to come back from the state file, per the
  inline `[RESUME]` comment). On a resume, `TARGET_PASS_HASH` therefore came
  back empty: the chroot's metadata guard aborted with
  "CRITICAL: Essential target account metadata parameters are empty", so a
  resumed install could never complete account setup. `TARGET_PASS_HASH` is
  now persisted alongside `ROOT_PASS_HASH` so both account hashes survive a
  resume.

## v3.3.0-beta3 — feature release on top of 3.3.0-beta2.1

- **`[LIMINE-WALLPAPER]`** — optional Limine boot-screen background image.
  Void's `limine` package ships the plain (non-`gui`) `BOOTX64.EFI`, which
  this installer deploys; Limine's `wallpaper:` directive (BMP/PNG/JPEG/QOI)
  works fine with it and is NOT a limine-gui-only feature. It is an opt-in
  drop-in: the prompt asks whether to enable it, and if so takes the path to
  an image on the live system (e.g. copied off a USB stick) plus a fit style
  (`stretched`/`tiled`/`centered`, stretched default). The installer stages
  the image (`/mnt/tmp` → `/tmp` in the chroot), copies it onto the ESP at the
  fixed name `/boot/efi/limine-splash.<ext>` (`boot():/limine-splash.<ext>`),
  and records the choice in `/etc/void-installer/limine-env`. `void-limine-write-conf`
  re-emits `wallpaper:`/`wallpaper_style:` on every resync (kernel update +
  cron), guarded on the ESP file actually existing, so a declined install or a
  user-removed image never breaks the menu. Declining keeps the plain default
  menu untouched. Because the cron resync rewrites `limine.conf` regularly,
  there is deliberately NO hand-uncommented shortcut in the generated file —
  the only durable way to enable a background afterward is to set
  `LIMINE_WALLPAPER=yes` (+ style) in `/etc/void-installer/limine-env` and
  place the image on the ESP, which the generator re-emits every resync.
- **`[PIPEFAIL]`** — added `set -o pipefail` alongside the existing `set -eE`
  so a failing middle stage of a pipeline (e.g. a failed `sed`/`grep` extractor
  followed by a `head` that returns 0) can no longer be silently masked. Guarded
  pipelines already using `|| true` / `|| echo 0` are unaffected.
- **`[LIMINE-ENV-LOAD]`** — the two Limine helper scripts
  (`void-limine-write-conf`, `void-limine-sync-kernels`) both load
  `/etc/void-installer/limine-env`; that identical existence-check-and-source
  guard was duplicated across two heredocs. Factored into a single shared,
  source-only `/usr/local/sbin/void-limine-env.inc` exposing a
  `load_limine_env()` function both helpers now call, so the load-bearing guard
  ("was this system installed with BOOTLOADER=limine?") lives in one place.
- **`[SHELLCHECK-GATE]`** — Validation documented in AGENTS.md: shellcheck is a
  triage gate (top-severity SC2xxx findings must-fix, intentional lower-severity
  ones get a per-SC-code `disable` with rationale, never a blanket disable),
  and a rule that generated `/usr/local/sbin` helper heredocs be extracted and
  `bash -n`'d directly since the installer's own `bash -n` does not parse them.
- **`[INSTALL-CONFIG]`** — the target install is now self-documenting. The
  chroot phase writes a human-readable `/etc/void-installer/install-config`
  recording every install-time choice (script version, hostname, user, desktop,
  DM, bootloader, kernel mode, session stack, locale, timezone, repo, swap/
  hibernation, Limine wallpaper) — deliberately NO secrets (no password
  hashes). The outer phase additionally archives an exact copy of the installer
  that built the machine to `/etc/void-installer/Void_Linux_Installer.sh`, so
  both WHAT was chosen and WHICH revision built it are recoverable from the
  box itself (recovery-first). `SCRIPT_VERSION` is now carried into the chroot.
- **`[DRY-RUN]`** — `-d`/`--dry-run`/`-n` mode. Walks the full interactive
  config (all prompts, no disk touched), skips the live-CD `xbps-install`
  package sync (so the running medium is not modified), and prints a complete
  as-planned summary — target disk + destructive `sgdisk`/`mkfs`/subvolume
  steps, bootloader, kernel mode, wallpaper resolution, desktop/DM, session
  stack, locale/timezone, repo, swap/hibernation, account model — then stops
  at the partition boundary with exit 0, removing the state file it collected
  so a later real run isn't offered a pointless resume. Non-dry-run behavior
  is unchanged. This gives a cheap, read-only preflight before the destructive
  commit (useful for both operator confidence and developer iteration).
- **`[LIMINE-ESP-ONLY]`** — the Limine `btrfs-direct` kernel-access option was
  **removed**. It read the kernel/initramfs FILE directly off the Btrfs `@`
  subvolume via Limine's own Btrfs driver, against Limine's explicit
  documentation ("the kernel and initramfs must reside on the ESP FAT32 or on
  another dedicated FAT partition"), so it could never boot. `esp-copy` is now
  the only Limine mode: the earlier two-way prompt is gone and `KERNEL_MODE` is
  auto-set to `esp-copy` for `BOOTLOADER=limine` (still `n/a` for GRUB). The
  variable and its downstream consumers (`void-limine-write-conf`'s kernel/
  module path + enumeration, the `void-limine-sync-kernels` guard, chroot_env,
  install-config, plan output) are simplified to the single esp-copy path, and
  the `KERNEL_MODE != esp-copy → exit 0` early-return is dropped. NVRAM
  behavior is unchanged: Limine is still deployed NVRAM-free via
  `/boot/efi/EFI/BOOT/BOOTX64.EFI` (UEFI removable-media path), and this
  removal does not touch that. A kept-why narrative now lives in the installer
  where the old option was.

## v3.3.0-beta2.1 — bug-fix point release on top of 3.3.0-beta2

- **`[LIGHTDM-SWRAP]`** — real-hardware Linux Mint-lightdm login loop
  diagnosed: every session (Cinnamon X11, Software Rendering, Wayland)
  flashed black and returned to the greeter with an empty `.xsession-errors`.
  Root cause: the LightDM branch overwrote Void's package-default
  `/etc/lightdm/lightdm.conf` without setting `session-wrapper=`, so LightDM
  1.32 fell back to its compiled-in default wrapper `lightdm-session` — a
  binary Void does not ship (Void's `lightdm` package provides
  `/etc/lightdm/Xsession`). The generated conf now explicitly writes
  `session-wrapper=/etc/lightdm/Xsession`. Verified on real hardware: login
  works, and `xsession-trace(post-fix).log` shows a fully-running Cinnamon
  session. Applies to all LightDM greeters (GTK/Slick/WebKit2) — it is a
  seat-level setting, not greeter-specific.
- **`[WSDD]` / `[WSDD-ABSENT]`** — Cinnamon's desktop-gap packages now include
  `wsdd`. Nemo auto-spawns `wsdd` for Windows name-service/network discovery;
  without it every boot logged `Failed to spawn the wsdd daemon ... 'wsdd' (No
  such file or directory)` plus a broken "Windows Network" sidebar entry.
  **CORRECTION (v3.3.0-beta4 `[WSDD-ABSENT]`):** Void does NOT ship `wsdd` (nor
  `wsdd2`) in any official repo — only a long-open package request
  (void-packages#28216). Listing it made the whole Cinnamon desktop-gap
  `xbps-install` abort real hardware installs with
  `'wsdd' not found in repository pool`. `wsdd` is removed from the install
  list; Nemo's Windows-discovery warning remains but no longer breaks the
  install.
- **`[GDM-WAY]`** (fix) — `gdm-wayland-session` does not exist as a Void
  package. Only `gdm` is in the repo (verified against the `current` binary
  index); listing it as a second package made the whole GDM install abort.
  `gdm` alone is now the only package installed for the GDM choice.
- **`[FISH-SHELL]`** (fix) — the shell installer prompt mapped the fish
  choice to `USER_SHELL_PKG="fish"`, but Void's package name is
  `fish-shell` (`fish` does not exist in the repo). A user choosing fish
  as their login shell would hit the `install_pkgs` abort mid-install.
  Corrected to `fish-shell`; the binary path `/usr/bin/fish` is unchanged.
- Docs: AGENTS.md gained a new mandatory invariant (#7) guarding the
  `session-wrapper` line; README/ARCHITECTURE SUMMARY updated; stale Debug
  notes corrected.
- **`[LIMINE-HDR]`** — Limine boot-screen structure. The kernels are now
  grouped inside a collapsible `/+Void Linux` submenu (one `//Void Linux
  (kernel)` sub-entry per installed kernel), mirroring the existing
  `+Snapshots` collapsed submenu for a consistent, closed-by-default top
  level. The earlier static `# Void Linux` comment banner is retired — the
  submenu heading now provides the title. Because a bare `default_entry`
  index can't descend into a submenu, `default_entry` is now an entry **path**
  to the newest kernel (`Void Linux/Void Linux (<version>)`, falling back to
  `1` if no kernel is detected); `remember_last_entry=yes` still takes over
  after first boot.

## v3.3.0-beta2 — LightDM greeter fixes from a real-hardware install

- **`[LIGHTDM-HW]`** — three LightDM greeter failures observed on a physical
  Cinnamon install (KDE + SDDM + the same swap/zram/hibernation config works,
  so the failing variable is LightDM, not zram):
  - **Slick greeter hangs** (screen shows `zramen#info: Attempting to find
    zram module - not part of kernel`). That line is benign first-boot INFO
    (the kernel zram module is simply not loaded at that instant; zramen
    then modprobes it in a loop, and once loaded proceeds — proven working by
    the KDE+SDDM wing of the same machine). The hang is
    `org.freedesktop.Accounts`: Void's `accountsservice` package ships **no
    runit service**, only a D-Bus activation that races lightdm on first boot
    and times out (known Void bug, void-packages#59538).
  - **GTK greeter refuses the correct password** with the right user shown:
    the AccountsService/polkit D-Bus-activation churn produces an unstable
    auth proxy early in boot (same class of bug as the Slick hang).
  - **WebKit2 greeter logs in but neither primary nor fallback theme works**:
    Void's `lightdm-webkit2-greeter` package renames its bundled theme
    `antergos` → `void` (depends on `void-artwork`), but the package default
    config still references names that don't exist. A config now writes
    `webkit-theme=void` (+ ltr/rtl fallbacks).
  - **Fixes applied:**
    1. LightDM branch now explicitly installs `accountsservice` and bakes a
       real runit service `/etc/sv/accounts-daemon/run` (resolved binary,
       `sv check dbus` guard, sed-baked `__ACCD_BIN__`); first-boot rc.local
       links it into `/etc/runit/runsvdir/default/` when
       `DISPLAY_MANAGER=lightdm`.
    2. rc.local also links `elogind` (only under
       `SESSION_STACK=elogind`) and `polkitd` — matching Void's own mklive
       known-good service set (`dbus elogind lightdm NetworkManager polkitd`)
       and the Void handbook's warning that D-Bus activation "can lead to
       issues".
    3. The `@lightdm` subvolume is chowned `lightdm:lightdm` after package
       install (a fresh btrfs subvolume is root-owned, silently defeating the
       package's `make_dirs` ownership once mounted over `/var/lib/lightdm`).
    4. WebKit2 gets `/etc/lightdm/lightdm-webkit2-greeter.conf` with
       `webkit-theme=void`.
  - Existing installs already affected (won't be re-run through the
    installer): apply the equivalent by hand —
    `chown lightdm:lightdm /var/lib/lightdm`,
    create+link `/etc/sv/accounts-daemon` (run script as above), and enable
    `elogind`/`polkitd` the same way rc.local now does.

### LightDM greeter shown in the end summary (v3.3.0-beta2)
- **`[LIGHTDM-HW]`** — when `DISPLAY_MANAGER=lightdm`, the final summary now
  echoes the exact greeter selected (Slick / WebKit2 / GTK), so there's no
  ambiguity about which greeter first boot will start.

### Missed `session-wrapper` for LightDM (v3.3.0-beta2)
- **`[LIGHTDM-SWRAP]`** — every LightDM login flashed black and returned to
  the greeter, with a completely empty `.xsession-errors`, regardless of which
  session the greeter offered (Cinnamon X11, Software Rendering, and Wayland
  all failed identically).
  - **Root cause:** the LightDM branch overwrote Void's package-default
    `/etc/lightdm/lightdm.conf`, and the replacement only wrote `[Seat:*]`,
    `greeter-session=`, and `user-session=`. It never wrote
    `session-wrapper=`, so LightDM 1.32 fell back to its compiled-in default
    wrapper name `lightdm-session` — a binary Void does **not** ship (Void's
    `lightdm` package provides `/etc/lightdm/Xsession` instead). With the
    wrapper missing, every user session failed to exec instantly: no trace, no
    `.xsession-errors` content, straight back to the greeter. (Cinnamon ran
    fine from a TTY because the broken wrapper is only involved under LightDM.)
  - **Fix:** the generated conf now explicitly writes
    `session-wrapper=/etc/lightdm/Xsession`.
  - **Real-hardware evidence:** `xbps-query -f lightdm` lists
    `/etc/lightdm/Xsession` (not `lightdm-session`) as the provided wrapper;
    `find / -name lightdm-session` returns nothing.
  - Existing installs already affected: add `session-wrapper=/etc/lightdm/Xsession`
    to `/etc/lightdm/lightdm.conf`.

### Container/virtualization default-OFF (v3.3.0-beta2)
- **`[OPT-DEFAULTS]`** — Podman rootless, Podman rootful, Docker, and
  virtualization are now **default No**. A bare "press Enter" run installs a
  lean base system; the container/VMM stack must be explicitly opted in per
  prompt (consistent with the existing default-off docker-group and distrobox
  prompts). The prompts flipped from `[Y/n]` to `[y/N]` with matching case
  logic.

### Pre-reboot countdown with keyboard control (v3.3.0-beta2)
- **`[REBOOT-COUNTDOWN]`** — the end-of-install wait is no longer a fixed
  `sleep 20` + canned "Rebooting in a few seconds...". A `REBOOT_DELAY`
  configurable (default `20`, env-overridable) drives both the summary text
  and a live per-second countdown. During the countdown the installer's
  terminal accepts keys: **R**/Enter = reboot now, **P** = pause,
  **C** = continue, **S** = stop and stay at the live shell (no reboot).
  On a terminal without `/dev/tty` the keys are ignored and the delay just
  elapses.

---

## v3.3.0-beta — Regional official repo mirror selection

- **`[MIRROR]`** — Official Void repository mirror is now a real install-time
  choice, auto-derived from the selected timezone and backed by an override
  menu (regional selection from the authoritative registry at
  `xmirror.voidlinux.org`):
  - `$REPO_PRIMARY` set to the chosen mirror; `$REPO_BACKUP1` (Fastly CDN)
    and `$REPO_BACKUP2` (tier-1 load-balanced default) retained for global
    failover.
  - All baked-in mirror URLs were live-verified (HTTP 200 + valid
    `x86_64-repodata`) before being added.
  - The community COSMIC repo is unaffected (pinned separately).
  - Resolved-via-timezone region mapping (America / Europe / Asia / Oceania /
    South-America / global).
  - Exported into `chroot_env` and the resume state file so the choice
    persists and a resumed run keeps the selected mirror.

### Open Item #7 decided (v3.3.0)
- **`@grub` is kept** as a dedicated top-level subvolume for `BOOTLOADER=grub`
  (gated at the `SUBVOL_LIST` / `mkdir` / mount / fstab / teardown-umount
  sites). Rationale: bootloader state is recovery-critical, so isolating
  `/boot/grub` on its own subvolume makes it immune to Snapper rollbacks of
  the `@` root. Under `BOOTLOADER=limine` no `@grub` subvolume is created at
  all.
- The stale "pending a removal decision" note at the `SUBVOL_LIST` was
  replaced with this decision. Former Open Item #7 is now closed — no removal
  is planned.

### Pre-hardware review fixes (v3.3.0)
- **`[NETCHECK]`** — the early "is networking up" pre-check no longer pings
  the hardcoded global default (`repo-default.voidlinux.org`). It now probes
  the authoritative mirror **registry** (`xmirror.voidlinux.org`) instead, so
  a regional mirror that differs from the global default is no longer blocked
  by an unrelated reachability gate. Actual per-mirror reachability is left to
  the existing install/bootstrap retry loops (primary + both backups).
- **`[MIRROR]` marker hygiene** — inline version tags on the mirror blocks
  corrected from v3.2.0 to v3.3.0 (matching `SCRIPT_VERSION` and the header).
- **NEXT STEPS fallback link** — the "if no graphical login" hint now points at
  `/etc/runit/runsvdir/default/` (functional even on first boot) instead of the
  dangling-symlink path `/var/service/`.


---

## v3.2.0 / v3.2.0-beta1 — Localization, swap/zram/hibernation, COSMIC, session/seat

### Real install-time choice: Desktop Environments (`DESKTOP_ENV`)
- KDE Plasma (default, primary tested path), Cinnamon, GNOME, Xfce, MATE,
  LXQt, and **COSMIC**.
- COSMIC is NOT in the official Void repos:
  - `[COSMIC]` — installed from a community repo maintained by **REDACTED
    REDACTED** (GitHub `REDACTED` / Codeberg `REDACTED`), pinned to the
    current domain `https://repo.REDACTED.de/repo/x86_64`.
  - Third-party signing-trust choice; runtime repo verification with a
    graceful abort + audit link if unavailable.
  - `install_cosmic()` helper deliberately bypasses `install_pkgs()` (which
    overrides `-R` with only the three official mirrors) and installs
    `cosmic-desktop-full` directly.
  - `RECOMMENDED_DM` maps `cosmic` → `sddm` (per the maintainer's
    recommendation).

### Real install-time choice: Display Manager (`DISPLAY_MANAGER`)
- Independent choice: SDDM (KDE/LXQt/COSMIC), LightDM (Cinnamon/Xfce/MATE,
  with a GTK/Slick/WebKit2 greeter choice), GDM (GNOME), or **cosmic-greeter**
  — offered only when COSMIC is chosen, carrying the maintainer's warning that
  it does not work reliably.
- `[COSMIC]` — cosmic-greeter runit service (`/etc/sv/cosmic-greeter/run`)
  provisioned when selected; prevented dangling `rc.local` symlink.

### Real install-time choice: Bootloader (`BOOTLOADER`) — **v3.2.0-beta1**
- GRUB (mature, grub-btrfs snapshot menu, 1 GiB ESP) or Limine
  (portable single-file UEFI binary, static snapshot menu, 4 GiB ESP),
  mutually exclusive UEFI-only paths. `[LIMINE-1]`.

### Real install-time choice: Localization — `[LOCALIZE]`
- System language/locale and timezone are real install-time choices.
- Chosen locale generated (`/etc/default/libc-locales` + `glibc-locales`),
  set as active `LANG` in `/etc/locale.conf`; `/etc/localtime` symlinked to
  the chosen IANA zone.
- Curated locale/zone menus plus a Custom option; carried into the chroot
  and echoed in the post-install summary.

### Real install-time choice: Swap / ZRAM / Hibernation — `[SWAP]`
- Swap no longer a fixed 16.64 GB always-on swapfile; real `SWAP_BACKEND`
  choice: swapfile / zram / both / none.
- Disk swapfile size from `SWAPFILE_SIZE`; hibernation (`ENABLE_HIBERNATION`)
  only when swapfile chosen; autosize `ceil(RAM × 1.25)` (lowercase `g`) when
  hibernation on, 2G/4G otherwise.
- `@swap` subvolume, mount (`nodatacow`), fstab entries, `swapon`, and
  resume-from-disk kernel params all gated on the backend.
- zram provisioned via Void `zramen` runit service with a generated
  config (`zstd`, priority 100, 50% RAM, bare-int `ZRAM_SIZE=50`).
- Swap/zram/hibernation choices echoed in the post-install summary.

### Session / seat management — `[item 9]`
- runit (not systemd); real `SESSION_STACK` choice: `elogind` (default) or the
  lighter `turnstile + seatd + acpid` stack.
- Hard validation added so a missing/invalid SESSION_STACK aborts cleanly; no
  `systemctl`/`journalctl`/`.service` logic anywhere (services via
  `/etc/sv/X` links into `/etc/runit/runsvdir/default/`).

### Coarse-phase resume & robustness — `[RESUME]` / `[FAILURE-JOURNAL]`
- `[RESUME]` — coarse phase resume: interactive config, NIC/disk detection,
  disk selection, already-installed guard, ERASE confirmation, and password
  hashing all skipped on a resumed run (`-r/--resume`); target disk/NIC and
  all answers restored from the state file (`/tmp/void-installer-state.sh`).
  Only password *hashes* persisted, never passwords.
- `[RESUME]` — subvolume reset, destructive-partition guard, and install
  completion marker behavior.
- `[FAILURE-JOURNAL]` — failure trace / install journal with the `jl()`
  helper and `STAGE_CONTEXT` milestones.

### Distrobox / container tooling — `[item 7]`, `[item 10]`
- `[item 7]` — re-run / already-installed guard.
- `[item 10]` — post-install "NEXT STEPS" summary (echoes locale, timezone,
  swap backend, and hibernation state).

### Other v3.2.0 changes
- `[COSMETIC]` — ANSI color + formatting helpers.
- `[item 2]` — Xfce via `xfce4`, MATE via `mate`, LXQt via `lxqt`, and polkit
  authentication handling.
- `[item 3]` — `var/lib/lightdm` subvolume, mount of the display manager's
  runtime, and a lightdm umount alongside cleanup.
- `[item 4]` — Firefox-specific helper; `[item 5]` — `@grub` and `/boot/grub`
  fstab handling; `[item 6]` — display-manager subvolume/mount.
- Various FIX markers confirmed against real installs (see script comments).

### Cinnamon desktop-gap package: `wsdd` (v3.3.0-beta2)
- **`[WSDD]`** — Cinnamon's desktop-gap install now includes `wsdd`. Nemo
  (Cinnamon's file manager) auto-spawns the `wsdd` daemon for Windows
  name-service/network discovery; without it every boot after the LightDM fix
  logged (`xsession-trace(post-fix).log`):
  `Failed to spawn the wsdd daemon: ... process 'wsdd' (No such file or
  directory)` plus `Couldn't create directory monitor on wsdd:///` and a broken
  "Windows Network" entry in Nemo's sidebar. Installing `wsdd` removes the
  warning and makes Nemo's network discovery usable.

---

## v3.1.0-beta1

### Bootloader
- `[LIMINE-1]` — Limine bootloader path (single-file portable UEFI binary).
- `[KERNEL-MODE]` — Limine reads the kernel/initramfs either from an `esp-copy`
  (copied onto the ESP) or `btrfs-direct` from the `@` subvolume.
- `[LIMINE-MULTI-KERNEL]` — multi-kernel snapshot boot menu.
- `[LIMINE-SYNC-CRON]` — `limine-snapper-sync` via a `/etc/cron.d` entry
  (every 15 min) since Void has no grub-btrfs equivalent; `[KERNEL-HOOK]`
  follow-up re-sync after kernel reconfigure.
- Both bootloader paths now coexist; GRUB/Limine replaced GRUB install
  workflow. `[KERNEL-HOOK]` §4.10 — kernel hook now re-syncs. Note: `v3.1.0`
  briefly made Limine the ONLY bootloader before user choice was restored in
  3.2.0-beta1.

### Distrobox
- `[DISTROBOX-3]` — third release-track option; `[DISTROBOX-2]`/`[DISTROBOX-3]`/
  `[CLONE-RETRY]` — podman image pulls and clone-retry behavior (§4.13).

### Fixes (confirmed against real installs)
- `FIX` markers for gnome-terminal, SDDM defaulting, LightDM/Slick greeter,
  invalid Limine URI syntax (`# generated before v3.1.0-beta1`), and other
  evidence-based corrections (see script comments at the marked lines).

> **Note:** Earlier history (3.0.x and before) is referenced in the original
> (now-lost) companion CHANGELOG, which partially survives only as section
> references embedded in the script's comments (§3.19, §3.24, §4.7, §4.8,
> §4.15, Open Items, etc.). Where such references appear in the current
> script, they are preserved verbatim as historical cross-references to that
> reconstructed lineage.

---

## Pre-3.1.0 heritage (alpha) — RECONSTRUCTED (educated estimate)

> The inline `AI (...)` markers and the current header architecture summary
> document changes from **v3.1.0-beta1** onward. The original companion
> CHANGELOG that recorded the earlier (alpha → 3.0.x) history was lost, so the
> following is an **educated reconstruction** inferred from which core
> features exist in the script but carry **no** v3.1.0+ marker (those untagged
> capabilities are the legacy foundation) and from the numbered `[item N]`
> work-items still referenced in comments. Treat the exact alpha phase
> numbering as an estimate; the feature set below is evidence-based.

### Base foundation (the first usable alpha)
A single-disk, GPT, UEFI-only Void Linux installer that:
- Runs wholly from the Void Linux Live CD outer terminal.
- Interactive disk selection via an lsblk-based numbered picker, filters out
  the live medium and any already-mounted disks, and requires typing `ERASE`
  to confirm.
- Partitions disk into: 1 = ESP (FAT32), 2 = one BTRFS filesystem with a
  **flat** (non-nested) subvolume topology — `@`, `@home`, `@grub`, `@swap`
  and the browser subvols as top-level siblings so each is independently
  snapshot-able/rollback-able.
- Uses **runit** (systemd-free); services enabled via
  `ln -s /etc/sv/X /etc/runit/runsvdir/default/` links, never
  systemctl/loginctl.
- Per-option `nodatacow` + `compress=none` on `@swap`, `@libvirt`, and the
  browser profile/cache subvols.
- `xbps`-based package bootstrapping with a fixed/recovery repo config.

### Alpha 1 — recovery-first installer
- Hibernation via a single physical BTRFS-native swapfile (resume offset
  computed with `btrfs inspect-internal map-swapfile -r`), injected into the
  kernel command line plus dracut's resume module.
- **Snapper** timeline snapshots + a **dracut overlay** so snapshot boots are
  read-only with a writable RAM overlay (does not mutate the snapshot).
- Account model / password hashing, hostname + domain set up inside the
  chroot.
- First-boot `rc.local` provisioning.

### Alpha 2 — desktop & recovery maturity
- **GRUB** bootloader with a grub-btrfs snapshot boot menu (dynamic, kernel
  hook regenerated; 1 GiB ESP) — the mature path later carried into 3.0.x.
- KDE Plasma desktop (the original primary desktop path).
- PipeWire + WirePlumber audio with robust XDG rules.
- NetworkManager with a custom `br0` bridge profile.
- Hibernation + snapshot-dracut overlay recovery for Plasma.

### Alpha 3 → early beta — breadth
- QEMU/KVM + libvirt virtualization on `br0` (virbr0 NAT explicitly disabled).
- Optional-stack menu: Firefox, Chromium, Vivaldi, Falkon, Brave, Flatpak,
  Docker, Podman (rootless/rootful), Distrobox, octoxbps, virt.
- Browser profile/cache subvols (`@mozilla`, `@mozilla-cache`, `@chromium`,
  `@vivaldi`, `@falkon`, `@brave`) with collector to move them into their own
  subvols.
- The numbered `[item N]` work-item system (items 1–10) — internal work-item
  tracking that persists into 3.2.0 markers.

### 3.0.x (final alpha-era releases before inline markers)
- GRUB-only install path, mature and "real-hardware-tested" (per the 3.2.0
  header note); the foundation carried forward and later joined by Limine in
  v3.1.0-beta1.
- `[item 3]` var/lib/lightdm, `[item 5]` @grub and `/boot/grub` fstab, and
  related structural subvolume/fstab refinements first appear here.
- Pre-3.1.0 work references (surviving in comments): the original CHANGELOG
  sections §3.19, §3.24, §4.7, §4.8, §4.9, §4.10, §4.13, §4.15 and Open
  Items #1/#2/#5d/#6/#7.

---


## Marker legend

Inline markers used throughout the script (and mirrored here):

- `AI (Big Pickle)` — current-session work (latest features).
- `AI (Claude, Sonnet 5, Medium)` — legacy prior work (v3.1.0–v3.2.0 and
  earlier work, authoritatively attributed to Claude).
- Feature tags: `[LOCALIZE]`, `[MIRROR]`, `[SWAP]`, `[COSMIC]`, `[RESUME]`,
  `[LIMINE-1/2]`, `[LIMINE-MULTI-KERNEL]`, `[LIMINE-SYNC-CRON]`, `[KERNEL-MODE]`,
  `[KERNEL-HOOK]`, `[DISTROBOX-2/3]`, `[CLONE-RETRY]`, `[FAILURE-JOURNAL]`,
  `[COSMETIC]`, `[SCRUB]`, `[ENCRYPT]`, `[YUBIKEY]`.
- Action words: `ADDITION` (new feature), `CHANGE` (behavioral change),
  `FIX` (bug fix), `EXPANSION` (extended feature).
