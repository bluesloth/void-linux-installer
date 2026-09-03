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

Current version: **3.3.0-beta30** (`SCRIPT_VERSION` in the script).

---

## v3.3.0-beta30 — chown the Documents dir the install record lives in (`[DOCS-LOG-CHOWN]`)

A follow-up ownership bug to the `[DOCS-LOG]` quick record. The install record
is written to `~/Documents/VOID_INSTALL.txt`, and the `mkdir -p .../Documents`
runs as **root** in the chroot. The write path chowned the `VOID_INSTALL.txt`
file but **not its `Documents` parent** — so on first boot the user found
`~/Documents` owned `root:root` ("You are not the owner"), even though every
other xdg-user-dir folder (Downloads, etc.) came up owned by the user because
the desktop's `xdg-user-dirs-update` creates those as the login user.

- **`[DOCS-LOG-CHOWN]`** — the `[DOCS-LOG]` block now `chown`s the
  `/home/<user>/Documents` directory itself (not just the file) to
  `user:user` right after the `mkdir -p`. `Downloads` and the rest already
  arrive user-owned via `xdg-user-dirs-update`, so this restores parity and
  keeps the installed user able to chmod their own Documents.

> **Live-box recovery** (no reinstall):
> `sudo chown <user>:<user> /home/<user>/Documents`

---

## v3.3.0-beta29 — fix Slick greeter session name (`[LIGHTDM-GREETER-SESSION]`)

**Brings a broken first boot back.** On a fresh install with the **Slick**
greeter (`LIGHTDM_GREETER=slick`) the new machine booted to a black tty
instead of the greeter. Root cause: the installer wrote
`greeter-session=lightdm-slick-greeter` into `/etc/lightdm/lightdm.conf`, but
Void's `lightdm-slick-greeter` package installs only
`/usr/share/xgreeters/slick-greeter.desktop` — the greeter `.desktop` is named
after the *session* (`slick-greeter`), not the *package*. LightDM's error log
reported `Failed to find session configuration lightdm-slick-greeter` and, after
exhausting rapid restarts, `sv status lightdm` showed the crash-loop state
`down: lightdm: is normally up, want up`.

- **`[LIGHTDM-GREETER-SESSION]`** — `LIGHTDM_GREETER_SESSION` for the Slick
  branch is now `slick-greeter` (matching the installed `.desktop` filename).
  This value is what gets emitted as `greeter-session=` in the generated
  lightdm.conf, so the greeter is found on first boot.
- The display-name `case` blocks that keyed a friendly "Slick / WebKit2 / GTK"
  label (and the final confirmation text) off `LIGHTDM_GREETER_SESSION` now key
  off `LIGHTDM_GREETER_PKG` instead — `SESSION` is the `.desktop` name, `PKG`
  is the package name, and never conflating the two prevents this class of bug.
- GTK (`lightdm-gtk-greeter`) and WebKit2 (`lightdm-webkit2-greeter`) ship
  `.desktop` files that match their package names, so their `SESSION` values
  are unchanged.

> **Live-box recovery** (no reinstall): edit the generated
> `/etc/lightdm/lightdm.conf` so `greeter-session=slick-greeter`, then
> `sv start lightdm`.

---

## v3.3.0-beta28 — installed-package capture in the install record (`[PKG-LIST]`)

The post-install record now captures not just the installer version and
choices but the **full finished-system package inventory**, appended to the
existing `~/Documents/VOID_INSTALL.txt` quick record — size-it-up from the
box itself without booting rescue media.

- **`[PKG-LIST]`** — the `~/Documents/VOID_INSTALL.txt` write (in the chroot,
  where the target's own `/var/db/xbps` is live) appends an
  `INSTALLED PACKAGES (full xbps-query -l inventory)` section:
  every package on the finished system — base-system, its dependencies, and
  everything the installer added on top — one per line. Each line is the
  `xbps-query -l` output with `xbps`'s `[installed] ` status prefix stripped,
  so it reads as clean `pkgname-version`:path, sorted for scannability.
- **Secret-free**, matching `install-config` and the existing record: a package
  list contains no credentials. `SCRIPT_VERSION` is kept alongside (the
  existing version line already records which installer built the box; the
  package list now documents what it actually installed). If `xbps-query` is
  unavailable in the chroot, the record notes the inventory was omitted rather
  than failing the install.
- **Validation:** `bash -n`, `Debug/check-defaults.sh` (ALL CONSISTENT), and
  `Debug/check-heredocs.sh` (46 heredocs, ALL CLEAN) all pass; the `sed`
  normalization pipeline verified against a simulated `xbps-query -l` output.

---

## v3.3.0-beta27 — install-prompt flow reorder (`[FLOW-ORDER]`)

Reordered the stage-1 install-prompt cluster so the encryption and bootloader
decisions land in a more natural order without changing any semantic.

- **Disk encryption now asked AFTER the bootloader choice.** The LUKS2 gate
  (and, when enabled, the YubiKey menu, YubiKey-only clamp, typed-passphrase
  capture, and LUKS mapper name) moved out of its old slot before the
  bootloader. The GRUB help text now says "if you then enable full-disk
  encryption (next prompt)" instead of "selected above", and GRUB+ENCRYPT still
  grows the ESP to 4GiB (`[GRUB-ESP-BOOT]`).
- **Limine wallpaper is asked immediately after the bootloader choice**
  (still limine-only), so bootloader -> wallpaper -> encryption reads as one
  flow; the wallpaper block physically sits between the bootloader and the
  encryption gate.
- **Audio (PipeWire read-only-snapshot autostart) moved to the tail of this
  cluster** — after encryption/YubiKey/passphrase. Its default stays OFF
  (`DEFAULT_SNAPSHOT_AUDIO=false`), unchanged.
- Finally the new stage-1 order is:
  `swap -> bootloader -> Limine wallpaper (limine) -> encryption gate ->
  YubiKey -> YK clamp -> passphrase + mapper -> audio`.
- The `[ENCRYPT-ORDER]` invariant is preserved: the typed passphrase is still
  captured only after the YubiKey menu AND the bootloader + `YK_FALLBACK` clamp
  are final, so its on-screen label (provisioning-only / boot fallback / plain
  every-boot) remains truthful.
- **Validation:** `bash -n`, `Debug/check-defaults.sh` (ALL CONSISTENT), and
  `Debug/check-heredocs.sh` (46 heredocs, ALL CLEAN) all pass after the reorder.

---

## v3.3.0-beta26 — optional-software category gates (`[BROWSER-GROUP]` `[CONTAINER-GROUP]`)

Groups the install-time optional-software prompt flow the way the tool's
`--class` groups subvolumes, while keeping every item individually selectable.

- **Web-browser gate (`SETUP_WEB_BROWSERS`, `[BROWSER-GROUP]`):** a single
  "Set up web browsers now?" `[Y/n]` prompt gates the whole browser section
  (Firefox/Chromium/Vivaldi/Falkon/Brave installs **and** their per-browser
  profile-subvolume pre-create prompts). Bare-Enter reads `DEFAULT_WEB_BROWSERS`
  (defaults YES because Firefox/Chromium default on), so an uninterested run is
  byte-for-byte identical to before; only an explicit "no" skips all five browser
  prompts and forces every browser install toggle off. Saying yes still yields the
  per-browser individual prompts exactly as before.
- **Container gate (`SETUP_CONTAINERS`, `[CONTAINER-GROUP]`):** a single
  "Set up containers (Podman / Docker) now?" `[y/N]` gate. Defaults OFF (all
  three backends are default-off under `[OPT-DEFAULTS]`), so a bare-Enter run
  skips the whole container section exactly as before; and the gate forbids the
  section entirely (forcing Podman rootless/rootful, Docker, docker-group-add,
  distrobox + track, container-manager all off/exported) when you say no. Saying
  yes walks Podman rootless / Podman rootful / Docker **individually** (each stays
  an independent, separately-documented choice — rootless vs rootful vs docker
  have different security/trust/architecture profiles).
- **Resume/state correctness:** both gates read a declared `DEFAULT_*`
  (`DEFAULT_WEB_BROWSERS=true`, `DEFAULT_CONTAINERS=false`) wired through
  `[PROMPT-DEFAULTS]` and validated by `check-defaults.sh`; all forced-off toggles
  are `export`ed so downstream `SUBVOL_LIST` / `provision_browser_subvol` /
  Stage-2 gating stays correct on a gated-off section.
- **Validation:** `bash -n`, `Debug/check-defaults.sh` (both new defaults declared +
  referenced), and `Debug/check-heredocs.sh` (46 heredocs) all pass.

---

## v3.3.0-beta25 — post-install subvolume tool (`void-subvol-tool.sh`, `[SUBVOL-TOOL]`)

Adds a post-install Btrfs subvolume manager to `/root/tools`, letting an admin
add / inspect / detach / destroy an additional **flat** sibling subvolume at
runtime — the same topology the installer's stage-1 `SUBVOL_LIST`/mount/fstab
lock-step produces, but reached for later on a running box.

- **New tool:** `/root/tools/void-subvol-tool.sh`, rewritten as a quoted
  heredoc (so `Debug/check-heredocs.sh` extracts + `bash -n`/shellchecks it),
  chmod 0755, with a matching `README.md` section and the `/root/tools` summary
  echo updated.
- **Verbs:** `list`, `check <subvol>`, `add <subvol> <mountpoint> [source-dir]
  [--nodatacow]`, `detach <subvol>`, `destroy <subvol>`.
- **Purely structural — never installs software.** It creates the sibling
  subvolume for later manual use of an app (e.g. `@steam`, `@postgresql`,
  `@containers`, `@docker`) without pulling the owning package, mirroring the
  install-time `PROVISION_*` guarantee. The former `SUBVOL_PROFILE`
  "bulk-preset that auto-enables install toggles" design was explicitly
  **dropped** — it risked accidentally installing software as a side-effect of a
  subvolume-scope choice. This tool inverts that: subvolume creation and
  software installed are strictly decoupled — the tool only ever makes the
  isolated sibling, and you install the software yourself (the same ordering
  guarantee the pre-create paths give: the folder exists on the isolated
  subvolume before the software's data ever lands).
- **Flat-topology correctness (the important fix):** a flat sibling can ONLY be
  created from the top-level tree (`subvolid=5`) — running
  `btrfs subvolume create <mountpoint>` from inside the live `@` mount would
  make a NESTED subvolume inside `@`, silently dragging it into Snapper
  rollback scope. The tool therefore mounts `subvolid=5` (the same dance the
  installer's Stage 1 uses) to create/inspect/destroy siblings, then mounts the
  new subvol at its runtime path via fstab. `[NODATACOW]` is honored: nodatacow
  is applied only via fstab mount options, never `chattr +C`.
- **Device discovery:** resolves the running root's btrfs device path
  (`findmnt -no SOURCE /`) and filesystem UUID (`blkid`/`findmnt -no UUID`), so
  it stays correct under LUKS/mapper without a hardcoded device name.
- **Idempotent + safe:** refuses to double-create or double-mount; `destroy`
  requires typing `YES`; `detach` is the non-destructive undo (umount + drop
  fstab, subvol + data preserved); the migrate variant copies existing contents
  into the fresh sibling with ownership/perms preserved before mounting.
- **Bulk "create the common optional subvolumes" example** in the README: a
  short idempotent loop over `@libvirt` (nodatacow), `@flatpak`, `@docker`,
  `@containers`. Excludes the context-dependent siblings the tool can't infer
  (`@grub` GRUB-only, `@swap` swapfile-only, `@containers-user` needs the
  per-user path). The tool never installs/checks for the software, so these
  flat siblings can be created even on a lean system with none installed.
- **Per-user profiles without typing the whole path:** a `USER_PROFILE_PATH`
  map holds the known per-user subvolume names → relative path
  (`@mozilla`→`/.config/mozilla`, `@steam`→`/.local/share/Steam`,
  `@containers-user`→`/.local/share/containers`, `@usercache`→`/.cache`, the
  browser profiles, `@thunderbird`, ...). `add` now accepts `--user <name>` to
  derive the mountpoint as `/home/<name>/<rel>` (confirmed before running), or
  just the subvol name alone to **prompt** for the username. An explicit
  `<mountpoint>` still overrides/works as before. CRITICAL: this only resolves
  the *path* — the per-user parent chain must already exist and be owned by the
  target user (the installer's `provision_browser_subvol` / `[PERSONAL-DATA]`
  ownership invariant); the tool never chowns your home.
- **`--class` software-family grouping:** `add --class <name> [--user <name>]`
  creates every subvol for an optional-software family in one pass. Classes:
  `containers` (`@docker @containers @containers-user`), `databases`
  (`@postgresql @mariadb`, nodatacow), `web` (all browser profiles), `mail`
  (`@thunderbird`), `gaming` (`@steam`), `virtualization`
  (`@libvirt` + new `@virtualbox`, nodatacow + per-user `/home/<user>/VirtualBox
  VMs`), `flatpak`. Members resolve to system mountpoints via a `SYS_MOUNT` map
  or per-user paths via `USER_PROFILE_PATH`; `--user` seeds the username for all
  per-user members (prompts once if omitted and any member is per-user). The
  shared create/mount/fstab body was factored into `add_subvol()`, reused by
  both single-add and class-add. `@grub`/`@swap` stay excluded (context-dependent).
- **`@virtualbox` now also available at install time** (installer/`SUBVOL_LIST`
  parity with the tool): a new `PROVISION_VIRTUALBOX_SUBVOL` opt-in (`[y/N]`,
  default false) pre-creates the `@virtualbox` top-level sibling and, via
  `provision_browser_subvol "@virtualbox" "VirtualBox VMs"`, creates/chowns/mounts
  the per-user `~/VirtualBox VMs` folder — same per-user isolation model as
  Steam/Thunderbird/browsers. Two points distinct from every prior subvol:
  (1) the relative path `VirtualBox VMs` is a SINGLE segment (no nested parent
  chain), and (2) it is the FIRST mountpoint with a SPACE — fstab is
  whitespace-delimited, so both this helper (`provision_browser_subvol`) and
  the tool's `add_subvol` now write the fstab mountpoint field with spaces
  escaped as `\040` (the `mount` call keeps the literal path). Wired through
  the `DEFAULT_*` block, interactive prompt, resume-state persistence, and the
  `SUBVOL_LIST` gate. Keep the tool's `virtualization` `--class` entry and this
  install-time gate in agreement (as with every `SUBVOL_LIST` <-> 
  `provision_browser_subvol` pair).
- **Validation:** `bash -n`, `Debug/check-defaults.sh` (no new `DEFAULT_*`, still
  all consistent), and `Debug/check-heredocs.sh` (46 heredocs; the 403-line tool
  is `bash -n` clean + shellcheck-clean) all pass.

---

## v3.3.0-beta24 — editable default answers (`[PROMPT-DEFAULTS]`)

Adds a single, top-of-script **editable defaults block** right after
`SCRIPT_VERSION`, so the "just press ENTER" path across the interactive prompts
and yes/no toggles is controlled by one curated set of variables instead of
hardcoded defaults scattered through the prompt loops.

- **One block, before the resume-state branch** (defined before `[RESUME]`
  re-sources the saved state), so a resumed run keeps its original answers and
  these only affect a fresh run / empty input.
- **Every value is env-overridable**: export the same name beforehand and the
  `${VAR:-default}` assignment picks it up, e.g.
  `DEFAULT_DESKTOP=7 ./Void_Linux_Installer.sh`.
- **Primary numeric choices** wired to their menu index: `DEFAULT_LOGIN_SHELL`,
  `DEFAULT_DESKTOP`, `DEFAULT_SESSION_STACK`, `DEFAULT_BOOTLOADER` (the GRUB
  `EFI_PART_SIZE` 1G / GRUB+ENCRYPT→4G coupling is preserved),
  `DEFAULT_LOCALE`, `DEFAULT_TIMEZONE`, `DEFAULT_SWAP_BACKEND`. The prompts now
  echo the active default.
- **Yes/no toggles** wired per-toggle with literal `true`/`false` defaults that
  honor the existing `[Y/n]` / `[y/N]` explicit-input polarity on non-empty
  answers: `DEFAULT_HIBERNATION`, `DEFAULT_SNAPSHOT_AUDIO`, `DEFAULT_OCTOXBPS`,
  `DEFAULT_FLATPAK`, `DEFAULT_FIREFOX`, `DEFAULT_CHROMIUM`, `DEFAULT_VIVALDI`,
  `DEFAULT_FALKON`, `DEFAULT_BRAVE`, `DEFAULT_PODMAN_ROOTLESS`,
  `DEFAULT_PODMAN_ROOTFUL`, `DEFAULT_DOCKER`, `DEFAULT_DOCKER_GROUP_ADD`,
  `DEFAULT_VIRT`.
- **Distrobox** sub-prompts: `DEFAULT_DISTROBOX` (also install distrobox?
  `[y/N]`), `DEFAULT_DISTROBOX_TRACK` (1=stable 2=current 3=next — the track
  prompt previously had no empty default and re-prompted; a bare ENTER now
  yields the track default), `DEFAULT_DISTROBOX_ENGINE` (1=podman 2=docker,
  previously `""`→podman).
- **YubiKey** sub-prompts (`[Y/n]`): `DEFAULT_YK_TOUCH` (require physical touch
  to unlock), `DEFAULT_YK_FALLBACK` (keep typed-passphrase fallback) — both
  `yes` by default; the GRUB `[YUBIKEY]` clamp that forces fallback is
  unaffected.
- **Pre-create subvol** sub-prompts (`[y/N]`, all `false` by default):
  `DEFAULT_PROVISION_FIREFOX_SUBVOL`, `DEFAULT_PROVISION_CHROMIUM_SUBVOL`,
  `DEFAULT_PROVISION_VIVALDI_SUBVOL`, `DEFAULT_PROVISION_FALKON_SUBVOL`,
  `DEFAULT_PROVISION_BRAVE_SUBVOL`, `DEFAULT_PROVISION_THUNDERBIRD_SUBVOL`,
  `DEFAULT_PROVISION_STEAM_SUBVOL`, `DEFAULT_PROVISION_DB_SUBVOLS`.
- **Dev gate:** `Debug/check-defaults.sh` (committed) is a reproducible check
  that every declared `DEFAULT_*` is actually wired to a prompt and every
  referenced `DEFAULT_*` is declared — run it after touching the prompt/defaults
  surface (see AGENTS.md → Validation).

---

## v3.3.0-beta23 — configurable LUKS mapper name (`[CRYPT-NAME]`)

The decrypted volume was previously hardcoded as the mapper name `void-root`
(`CRYPT_DEV="/dev/mapper/void-root"` stamped into every `luksOpen`/`luksClose`,
crypttab, and `rd.luks.name=` kernel param). beta23 makes the name a real,
optional install-time prompt that **defaults to `void-root`** (pressing ENTER
keeps today's behavior exactly).

- **New prompt** (gated on `ENCRYPT=yes`, right after the passphrase confirm):
  "LUKS mapper name? [void-root]" — a bare ENTER yields `void-root`; any
  non-empty plain name (rejecting `/`) is accepted and stored in `CRYPT_NAME`.
- **`CRYPT_NAME` is threaded through every consumer** so a custom name still
  boots and still recovers, not just the `luksOpen` call:
  - the 6 `cryptsetup luksFormat`/`luksOpen`/`luksClose`/`luksAddKey` calls;
  - `/etc/crypttab` (both the plain and the YubiKey `keyscript=` variant);
  - `chroot_env.sh` (`export CRYPT_NAME=...`) so Stage-2 builders see it;
  - the resume-state file (a resumed run re-sources it, no re-prompt);
  - the GRUB and Limine `rd.luks.name=${LUKS_UUID}=${CRYPT_NAME}` kernel
    cmdlines;
  - persisting `CRYPT_NAME` into `/etc/void-installer/limine-env` so the
    persistent `void-limine-write-conf` re-emits the correct
    `rd.luks.name=` on every kernel/snapshot resync (`CRYPT_NAME` is loaded by
    the shared `load_limine_env()`);
  - the `install-config` as-built record and the `DOCS-LOG`
    `~/Documents/VOID_INSTALL.txt` (`LUKS_MAPPER=...`).
- **Secret-free:** the mapper name is a *public* value (it appears in
  `/dev/mapper/` and on the kernel cmdline), so it is persisted exactly like
  `LUKS_UUID` — never the passphrase. Booting with dracut flows through
  cryptroot-ask's `$luksname` argument (derived from `rd.luks.name=`), so a
  custom name requires no extra wiring in the initramfs.
- Default keeps full backward compatibility: `void-root` remains the value for
  anyone who just hits ENTER.

---

## v3.3.0-beta22 — encrypted unlock newline fix (`[ENCRYPT-NEWLINE]`)

Discovered from a fresh real-hardware install that unlocked with the installer
but **refused to unlock at boot or via a manual recovery** open ("No key
available with this passphrase"), even though the passphrase was a US-layout,
digits-only `<redacted-passphrase>`.

**Root cause (byte-level):** every LUKS call fed the passphrase through a
`<<<` here-string (or `echo`), e.g.
`cryptsetup luksOpen --key-file=- "$PART_SYS" void-root <<<"$ENCRYPT_PASSPHRASE"`.
`<<<` and `echo` append a **trailing newline byte**, so the LUKS keyslot stored
`passphrase\n` (11 bytes for `<redacted-passphrase>`). The beta21 `[ENCRYPT-VERIFY]`
close/re-open check *appeared* to pass only because it reused the same `<<<`
11-byte path — it never exercised the interactive path. A human typing at the
boot prompt (or a manual `cryptsetup open`) reads a line in terminal canonical
mode **without** the newline → 10 bytes → keyslot mismatch → lockout.

**Fix (`[ENCRYPT-NEWLINE]`):** all six LUKS passphrase-fed calls now pipe
`printf '%s' "$ENCRYPT_PASSPHRASE" | cryptsetup ... --key-file=-`, producing
**no** trailing newline. This makes format == verify == interactive boot typing
byte-identical — the exact bytes a person entering the passphrase at the
prompt generates. Newline-bearing here-string/echo paths are gone from every
cryptsetup `--key-file=-` use (the two remaining `<<<` in the file feed
`openssl passwd`, not LUKS, and are unrelated).

- Changed calls: `luksFormat` (fresh), `luksOpen` (fresh), the
  `[ENCRYPT-VERIFY]` close/re-open, `luksAddKey` (YubiKey binding), and the two
  resume-path `luksOpen` fallback/typed paths.
- A fresh install with beta22 stores an exact-byte passphrase, so boot,
  recovery, and reinstall resume all unlock with the plain typed passphrase.
- The *existing* beta21-installed volume (already on disk) still holds the
  11-byte newline-included key; unlocking it requires the matching newline
  until it is re-keyed (see the re-key note sent with this change).

---

## v3.3.0-beta21 — encrypted-boot hardening (`[ENCRYPT-KEYMAP]` + `[ENCRYPT-VERIFY]`)

Discovered from a real-hardware LUKS boot lockout: a short, simple passphrase
(`abc123def456`) refused to unlock at boot after a complex one had unlocked. The
installer's format/open were byte-consistent, so the failure pointed at the
console-keymap boundary between install and boot. beta21 hardens the encrypted
boot path in two ways.

- **`[ENCRYPT-KEYMAP]`** — the passphrase's byte value is tied to the console
  keymap it is typed under. On the live side the installer captures `KEYMAP_LIVE`
  from the live `/etc/rc.conf` (default `us`), passes it into the chroot, and:
  - writes `KEYMAP=` into the installed `/etc/rc.conf` (runit console, loaded by
    `/etc/runit/core-services/03-console-setup.sh`);
  - adds dracut's `i18n` module + `rd.vconsole.keymap=` to `90-system.conf` so the
    **early-boot initramfs passphrase prompt** (before the console is up) uses the
    same map.
  - The passphrase prompt now tells the user the passphrase is bound to the
    current console keymap.
- **`[ENCRYPT-VERIFY]`** — right after `luksFormat`+`luksOpen`, the installer now
  `luksClose` + re-`luksOpen`s with the same passphrase and **aborts loudly** if it
  fails, catching a key/typing mismatch at install time instead of shipping a disk
  that locks the user out at first boot. Runs before YubiKey slot binding, so it is
  valid even for possession-only installs. The two resume-path `luksOpen` calls
  also now abort on failure instead of silently continuing with a dead
  `/dev/mapper/void-root`.

---

## v3.3.0-beta20 — self-contained Limine rebuild kit (`[TOOLS-LIMINE-BACKUP]`)

beta18's `/root/tools` could re-trigger a Limine menu regen (`limine-sync.sh`)
and re-install the snapper trigger plugin (`re-provision-snapper.sh`), but it
could NOT rebuild the live `/usr/local/sbin/void-limine-*` menu engines if
those were lost — so the Limine+snapper snapshot-menu pipeline was only
reconstructible via a full reinstall. beta20 makes `/root/tools` a true
self-contained regeneration kit.

- **`[TOOLS-LIMINE-BACKUP]`** — `/root/tools` now also carries canonical,
  pristine backups of the three live Limine engine helpers:
  `void-limine-env.inc` (sourced by the generator), `void-limine-sync-kernels`
  and `void-limine-write-conf` (the two executables that drive the menu).
- **`limine-sync.sh` self-rebuild** — if a live Limine helper is missing from
  `/usr/local/sbin`, `limine-sync.sh` restores it from the folder-local backup
  before regenerating the menu. This makes the whole void-limine +
  limine-snapper-sync pipeline recoverable without reinstalling.
- **Not backed up** (deliberately): `void-reveal-yubikey-key` (a dracut
  keyscript-derived helper, not part of the menu generator) and
  `void-xbps-snap`'s YubiKey/other pieces — `void-xbps-snap` already has its
  own backup. Each backup is mode- and owner-preserved via `install -o root`.
- `limine-sync.sh`'s helper-absent check now runs *after* the auto-restore, so
  it only reports "not a Limine install" when a helper is truly gone with no
  backup to fall back on.

---

## v3.3.0-beta19 — self-healing xbps shadow (`[RESHADOW-BOOT]`)

The `[PKG-SNAPSHOT-AUTO]`/`[TOOLS-DIR]` work still left ONE manual step: if an
`xbps` self-update un-shadowed the wrapper, the admin had to run
`/root/tools/re-shadow-xbps.sh` by hand. beta19 closes that gap by running the
repair automatically on every boot.

- **`[RESHADOW-BOOT]`** — `/etc/rc.local` gains a boot-time call to
  `/root/tools/re-shadow-xbps.sh`, placed in the **every-boot** section (OUTSIDE
  the installer's firstboot.log guard). `/etc/runit/2` runs `/etc/rc.local`
  unconditionally on every boot, so the shadow is repaired before any later
  update can run unsnapshotted. Idempotent; logs to `/var/log/void-reshadow.log`.
- Delegates to the existing `/root/tools/re-shadow-xbps.sh`, so there is exactly
  one shadow-repair implementation (no duplicated logic).
- Chosen home: `/etc/rc.local`, not a new runit `sv/` service — it already runs
  every boot through runit stage 2, is where this installer does boot-time
  fixups, and avoids runit's one-shot restart semantics.

---

## v3.3.0-beta18 — persistent maintenance/tools folder (`[TOOLS-DIR]`)

The recovery stories added since beta16 had their recovery steps described in
comments and the NEXT STEPS summary, but nothing handed the *admin* a script to
actually run when a caveat hit. beta18 ships a persistent, self-contained
maintenance folder at **`/root/tools`**, written once at install time, that the
admin can run later on demand.

- **`[TOOLS-DIR]`** — `mkdir /root/tools` + a user-facing README and four files
  (all idempotent):
  - **`README.md`** — the discoverability layer: documents what each tool does,
    *when* to reach for it, and the exact `sudo` command to run. This is what
    survives on a fresh install (the repo-side CHANGELOG/README do not ship).
  - **`void-xbps-snap`** — canonical backup copy of the update-snapshot wrapper,
    the ultimate fallback if `/usr/local/sbin/void-xbps-snap` is ever lost.
  - **`re-shadow-xbps.sh`** — recovery for the `[PKG-SNAPSHOT-AUTO]` caveat: an
    `xbps` package self-update re-places a real ELF over the
    `/usr/bin/xbps-install` symlink. This self-heals: restores the wrapper from
    the backup, moves a real binary to `xbps-install.real` if needed, and
    re-links the shadow. Works on a `readlink` of the current `xbps-install`
    (already-linked / real-ELF / dangling) — idempotent.
  - **`limine-sync.sh`** — manual, on-demand Limine boot-menu resync (kernel
    sync + `void-limine-write-conf`). A clear no-op on a GRUB box.
  - **`re-provision-snapper.sh`** — *safe* snapper recovery: recreates a
    *missing* `root` config, re-applies the retention/timeline tuning and the
    runit filter, and re-installs the `00-void-limine-snapper-sync` plugin
    (Limine only). Deliberately does **NOT** run the destructive
    umount/rmdir/create-config reconciliation that would wipe existing
    snapshots — this script never touches existing snapshots.
- **Hosted in `/root` (admin home), not on PATH** — they are run-on-demand
  maintenance scripts (`re-shadow`, `limine-sync`, `re-provision-snapper`),
  not live helpers; the live helpers stay in `/usr/local/sbin`. Scripts use
  `BASH_SOURCE`-relative paths so the folder is relocatable.
- Surfaced in the header Recovery section and the NEXT STEPS summary (item 7,
  and item 6's re-shadow message now names the actual script).
- **Validation:** static gates (`bash -n`, `Debug/check-heredocs.sh` 45/45,
  all tools + README clean). Not yet exercised on real hardware —
  verify each wrapper one has its documented use-case on the target medium.

---

## v3.3.0-beta17 — automatic updates: shadow `xbps-install` (`[PKG-SNAPSHOT-AUTO]`)

beta16's `void-xbps-snap` wrapper required the user to *choose* to use it. beta17
removes the choice: `/usr/bin/xbps-install` is now **shadowed** so every
invocation — bare or via `sudo`, any shell — snapshots automatically, with zero
change to the user's normal update habit.

- **`[PKG-SNAPSHOT-AUTO]`** — in the chroot, after installing the wrapper, the
  real `/usr/bin/xbps-install` ELF is renamed to `/usr/bin/xbps-install.real`
  and a symlink `/usr/bin/xbps-install -> /usr/local/sbin/void-xbps-snap` is
  dropped in its place. Idempotent (`mv -n` never clobbers an existing `.real`;
  `ln -sf` re-points).
- **Wrapper hardened for shadowing:** it now resolves the real binary as
  `/usr/bin/xbps-install.real` first, else PATH — with a **self-recursion
  guard** (if it ever resolves to its own file, a broken shadow with no `.real`
  companion, it aborts loudly rather than looping). The same script still works
  standalone as `void-xbps-snap` for explicit use.
- **Installed under BOTH bootloaders** (unlike the Limine-only snapper plugin) —
  it is bootloader-independent.
- **Documented caveat (self-update):** `/usr/bin/xbps-install` belongs to the
  `xbps` package. A future `xbps` package reinstall re-places a real binary
  over the symlink, silently un-shadowing the wrapper. Recovery: re-run the
  shadow block (or the documented one-liner). The wrapper itself cannot wrap
  xbps's own reinstall (that would recurse), so this accepted tradeoff is
  documented in the header, the NEXT STEPS summary, and this entry.
- **Validation:** static gates (`bash -n`, `Debug/check-heredocs.sh` 41/41,
  wrapper shellcheck-clean) plus sandbox tests of both resolution modes and the
  recursion guard. Still apply the real-hardware note from beta16: verify a
  live `sudo xbps-install -Su` pair once (done on this box for the standalone
  path in beta16; the shadow path is the same script but validate a pair after
  an `xbps` self-update to confirm re-shadowing).

---

## v3.3.0-beta16 — pre/post snapshots around system updates (`[PKG-SNAPSHOT]`)

A recovery gap closed. Snapper already provides timeline snapshots, but a
timeline snapshot can be many minutes old when an update lands — there was no
guaranteed "undo THIS exact update" rollback point. Now a wrapper,
`/usr/local/sbin/void-xbps-snap`, encloses a mutating `xbps-install` in a
snapper **pre**/**post** snapshot pair:

- **`[PKG-SNAPSHOT]`** — installed in the chroot next to the other privileged
  helpers. It takes a pre snapshot (`--type pre`) before running the real
  `xbps-install`, then a post snapshot (`--type post`, paired via
  `--pre-number`) afterwards, with the update already applied (even on a
  partial failure) so the post is the "undo to here" restore point.
- **Drop-in:** every CLI arg passes through verbatim, so
  `sudo void-xbps-snap -Su` works exactly like `xbps-install -Su` but
  snapshotted. A `DESC=` env var can override the snapshot description
  (default is a dated "xbps system update").
- **Conservative by design:** snapshots only fire on mutating installs
  (`-S`/`-u`); dry-runs and queries (`-n`, `-s`, bare) pass straight through
  with no snapshot pair. Fires only on a **btrfs** root that has a snapper
  `root` config. Uses `--no-dbus` like the install-time calls.
- **Never blocks an update:** if the pre snapshot cannot be taken, the wrapper
  warns and runs `xbps-install` unsnapshotted rather than refusing.
- **No alias installed at install time** — it is an explicit, discoverable
  wrapper (surfaced in the NEXT STEPS summary). Adding a later automatic
  override is a one-line alias/symlink on top of this same self-contained
  script. *(Superseded by v3.3.0-beta17 `[PKG-SNAPSHOT-AUTO]`, which shadows
  `/usr/bin/xbps-install` so the automation is installed by default.)*
- Differs from the existing `00-void-limine-snapper-sync` plugin: that plugin
  regenerates the *boot menu* when a snapshot exists; this wrapper *creates*
  the pair of snapshots. Both coexist; a pair created via the wrapper is
  picked up by the menu regen like any other snapshot.
- **Validation status:** static gates only (`bash -n`,
  `Debug/check-heredocs.sh`). The pre/post wrapper has not been exercised on
  real hardware yet — verify on the target medium with a sample
  `sudo void-xbps-snap -Su` and confirm the pair appears in the snapshot boot
  menu.

---

## v3.3.0-beta15 — user full-name prompt (`[FULLNAME]`)

After the target username is chosen, the installer now also asks for the
user's full (display) name, e.g. `John Doe`. The name feeds the account's GECOS
field so logins and greeters show a friendly name instead of the bare username.

- **`[FULLNAME]`** — new permissive prompt right after the username, stored as
  `TARGET_FULL_NAME`. Free-form (any printable text accepted); blank is fine.
- Wired through every canonical site:
  - `useradd -c "${TARGET_FULL_NAME:-$TARGET_USER}"` — the GECOS/display name.
  - exported to `chroot_env.sh` for Stage 2.
  - shown in the pre-disk REVIEW summary and the `--dry-run` plan.
  - recorded in `/etc/void-installer/install-config` as `USER_FULL_NAME`
    (secret-free, like the rest of that file).
- No runtime/boot behavior changes — display-name only.

---

## v3.3.0-beta14 — GRUB+encryption now boots: public `/boot` on the ESP (`[GRUB-ESP-BOOT]`)

A real bootability gap removed. Under `BOOTLOADER=grub` + `ENCRYPT=yes` the
old layout kept `/boot/grub`, grub.cfg, and every kernel/initramfs inside the
LUKS volume — but GRUB was given **no** `cryptodisk`/`luks` driver
(`GRUB_ENABLE_CRYPTODISK` never set) and `grub-mkconfig` emits no
`cryptomount`, so the embedded core could not open `/boot/grub` **and** could
not `insmod luks` (that module was locked too). First boot always hit
`grub rescue>`. Now:

- **`[GRUB-ESP-BOOT]`** — when GRUB **and** full-disk encryption are both
  selected, the ESP is mounted **at `/boot`** instead of `/boot/efi`. The
  whole boot tree (grub.cfg, grub modules, every vmlinuz + initramfs) is
  written to the **unencrypted** ESP, so GRUB never touches LUKS — the
  documented-unreliable cryptodisk/Argon2 path is bypassed entirely, and
  dracut's `crypt` prompts exactly once, after handoff. Kernel installs land
  on the ESP automatically (`/boot` == ESP), so no kernel-copy hook exists in
  the GRUB branch (unlike Limine's `esp-copy`).
- Wiring follows the "no dead subvolume" rule at every canonical site:
  - `GRUB_ESP_BOOT` derived at one site (grub && encrypt), after the resume
    state-file load so a `-r` resume recomputes it correctly, then exported to
    chroot_env for Stage 2.
  - `@grub` is **not created/mounted/fstab'd** in the combo (SUBVOL_LIST,
    mkdir, mount, fstab, both teardown lists) — grub files live on the ESP.
  - ESP mountpoint is `/mnt/boot` (combo) vs `/mnt/boot/efi`; the vfat fstab
    line moves to `/boot` accordingly.
  - `EFI_PART_SIZE` grows to **4GiB** for the combo (kernels on the ESP);
    stays 1GiB for a plain GRUB install.
  - `grub-install --efi-directory=/boot` in the combo, `/boot/efi` otherwise.
- Messaging corrected: the old "GRUB cryptodisk must read the encrypted
  /boot via a typed passphrase" claims (header, YubiKey fallback prompt,
  bootloader prompt) described a capability the installer never wired up.
  They now describe the real model. The `[YUBIKEY]` clamp that forces
  `YK_FALLBACK=yes` under GRUB is **kept** — possession-only boot remains
  real-hardware UNPROVEN and Limine is the only exercised pairing — but its
  rationale note now reflects why (safety/unproven, not "cryptodisk needs a
  slot").
- **Validation status:** static gates pass (`bash -n`, `Debug/check-heredocs.sh`
  40/40). This combo has NOT been booted on real hardware yet — mandatory
  target-medium test, including: normal boot (single dracut prompt),
  hibernation resume (swapfile still inside LUKS), Snapper snapshot-boot menu
  from grub-btrfs (entries must resolve kernels on the ESP, not the
  snapshotted @).
- **`[DOCS-LOG]`** — the finished box now carries a quick, secret-free
  "which script built me" record at `~/Documents/VOID_INSTALL.txt` (installed
  user): `SCRIPT_VERSION`, install UTC, hostname/user, bootloader,
  ESP mountpoint (calls out the combo's `/boot`==ESP), encryption, YubiKey
  mode, session stack, desktop. Nothing cryptic in it — it routes to the two
  authoritative artifacts
  `/etc/void-installer/install-config` and
  `/etc/void-installer/Void_Linux_Installer.sh`. Written in the chroot after
  install-config; chown'd to the target user; `chmod 644`.

---

## v3.3.0-beta13 — extended subvolume topology (`[SUBVOLS]`)

- **`[SUBVOLS]`** — four new subvolume families, following the existing
  flat-topology rules (no dead subvols, mount/fstab-option `nodatacow`,
  browser-style per-user provisioning, resume-state persistence):

  - **`@network`** → `/var/lib/NetworkManager`, **unconditional** — NM is
    installed on every build (both `$SESSION_STACK` branches), so the
    subvol always mounts. The win: a Snapper rollback of `@` no longer
    rewinds NM's runtime state (leases, `NetworkManager.state`,
    last-known-connection). Note this isolates *runtime* state — per-profile
    connection secrets under `/etc/NetworkManager/system-connections` still
    roll back with `@`.
  - **`@thunderbird`** → `~/.thunderbird` (opt-in `PROVISION_THUNDERBIRD_SUBVOL`
    prompt) — the exact `provision_browser_subvol` treatment (nodatacow,
    `chmod 700`, user-owned) for Thunderbird's sqlite mail profile.
  - **`@steam`** → `~/.local/share/Steam` (opt-in `PROVISION_STEAM_SUBVOL`
    prompt) — churn isolation via the same helper; the helper's nested-parent
    chain re-creates and `chown`s `~/.local`/`~/.local/share`, avoiding the
    root-owned-`~/.local/share` bug class that broke podman-rootless.
  - **`@postgresql` / `@mariadb`** → `/var/lib/postgresql` / `/var/lib/mysql`
    (opt-in `PROVISION_DB_SUBVOLS` prompt) — mounted/fstab'd
    `nodatacow,compress=none`, and excluded from Snapper's `@` snapshots so a
    rollback can never rewind a live database behind newer code.

  Wiring parity for each at the six canonical sites: SUBVOL_LIST gate,
  Stage-1 mkdir, Stage-1 mount, fstab, failure-unwind list, and success-path
  teardown (per-user ones via the Stage-2 helper instead of mkdir/mount).
  All new `PROVISION_*` flags are persisted to the resume state file so a
  resumed run recreates the exact same layout (the interactive block is
  skipped on resume).

---

## v3.3.0-beta12 — Limine is the default bootloader (`[LIMINE-DEFAULT]`, `[ENCRYPT-ORDER]`)

- **`[LIMINE-DEFAULT]`** — the bootloader prompt now lists **Limine first**
  (option 1) and bare **Enter** selects it as the default; GRUB moves to
  option 2 and remains a fully supported, first-class choice. This flips the
  v3.1.0-beta1-era decision ("reverted to a real per-install CHOICE ... GRUB
  remains the mature path") — the menu order and the empty-input default are
  the only things that changed. Presentational only: every `$BOOTLOADER`-gated
  branch downstream is untouched, and the GRUB/Limine code paths remain two
  separate branches (mandatory invariant #5). Defaults carried by the choice
  are unchanged (Limine → 4GiB ESP, GRUB → 1GiB ESP), and the YubiKey-only
  clamp that forces `YK_FALLBACK=yes` under GRUB is likewise unchanged.

- **`[ENCRYPT-ORDER]`** — the typed LUKS2 passphrase is now captured *after*
  the YubiKey menu and after the bootloader choice + `YK_FALLBACK` clamp,
  instead of being asked the instant encryption is enabled. The order had to
  stay functionally the same (a LUKS2 container cannot be created without a
  typed key slot, and `luksAddKey` authenticates with it — so even a
  possession-only install types a passphrase once at install), but the prompt
  now knows — and *tells* the user — what that passphrase is actually for:
  YubiKey-only (`YK_FALLBACK=no`) labels it a **one-time provisioning
  secret** that will be removed from the container after enrollment (a
  throwaway value is fine); `YK_FALLBACK=yes` labels it the boot fallback;
  and no-YubiKey installs keep the plain "required at every boot" wording.
  Because the GRUB selection forcibly flips `YK_FALLBACK=no` back to `yes`
  (GRUB cryptodisk needs a passphrase slot), the passphrase is captured after
  that clamp so a passphrase the user typed as a throwaway can never later
  become a boot fallback they didn't remember. Security model unchanged: the
  value stays a plain in-process variable (never exported), is fed to
  `cryptsetup` only via `--key-file=-` stdin heredocs, and is `unset` right
  after `luksOpen`.

---

## v3.3.0-beta11 — drop the shadowed `@tmp` subvolume (`[DROP-@TMP]`)

- **`[DROP-@TMP]`** — the `@tmp` top-level Btrfs subvolume was provisioned
  (created in `SUBVOL_LIST`, mounted `nodatacow` at `/mnt/var/tmp` during the
  install) yet permanently shadowed at boot by the tmpfs `/var/tmp` fstab
  line — i.e. `@tmp` never mounted at runtime. It is now removed from the
  topology: gone from `SUBVOL_LIST`, the mount step, the failure-unwind list,
  and the success-path teardown. `/var/tmp` (and `/tmp`) remain tmpfs at
  runtime; during the chroot stage `/var/tmp` is a plain directory inside the
  `@` root subvolume. Runtime behavior is unchanged; the install no longer
  creates a dead-weight subvolume. Note: on an in-place reinstall of a
  pre-beta11 host, a stray top-level `@tmp` may survive the wipe (the cleanup
  removes only nested subvolumes) and should be deleted manually
  (`btrfs subvolume delete`).

---

## v3.3.0-beta10 — YubiKey keyscript value-bake fix (`[YK-KEYSCRIPT-BAKE]`)

- **`[YK-KEYSCRIPT-BAKE]`** — the boot keyscript
  `/usr/local/sbin/void-reveal-yubikey-key` was generated from a **quoted**
  heredoc (`<< 'INNER_EOF'`) while every other value-baking heredoc in the
  installer (notably `<etc/void-installer/limine-env`) is **unquoted**
  (`<< INNER_EOF`). As a result the installed keyscript carried literal
  unexpanded `YK_SLOT="${YK_SLOT}"` / `YK_CHALLENGE="${YK_CHALLENGE}"` tokens.
  Nothing feeds those variables into keyscripts at boot — the `99void-yubikey`
  cryptroot-ask override execs them with no environment — so under `set -u`
  the keyscript aborted on its first line and a possession-only (`YK_FALLBACK=no`)
  boot could never unlock (with `YK_FALLBACK=yes` the failure silently degraded
  to the typed-passphrase prompt, which is exactly why the flaw could hide
  behind an "unproven boot path" label). The heredoc is now unquoted, matching
  the limine-env pattern, so the public SLOT and CHALLENGE values bake into the
  file at install time; the HMAC response is still never stored. Only public
  values change — the `-${YK_SLOT} "$YK_CHALLENGE"` challenge invocation stays
  byte-identical to enroll/resume.

---

## v3.3.0-beta9 — first-boot virtualization wait fix (`[RCL-VIRT-WAIT]`)

- **`[RCL-VIRT-WAIT]`** — the first-boot `rc.local` block used to wait up to
  15 seconds for `/run/libvirt/libvirt-sock` **unconditionally**, then tear
  down libvirt's default NAT bridge, even on systems that never had
  virtualization installed (`INSTALL_VIRT=false`). On a non-virt install the
  socket never appears, so every first boot burned the full 15-second timeout
  sleeping through the loop before runit moved on. The wait and the `virsh
  net-destroy`/`net-autostart` teardown are now gated on
  `__INSTALL_VIRT__="true"` (baked in at generation time, alongside the other
  `__...__` placeholders). Non-virt installs boot first-time with no artificial
  delay; virt installs are unaffected.

---

## v3.3.0-beta8 — cron safety-net removal (`[SNPR-EV-NO-CRON]`)

- **`[SNPR-EV-NO-CRON]`** — the 15-min `/etc/cron.d/void-limine-sync`
  safety-net generator (introduced at v3.1.0-beta1 as `[LIMINE-SYNC-CRON]`,
  retained as a demoted safety net at v3.3.0-beta4) was **removed**. With the
  `00-void-limine-snapper-sync` plugin proven to fire reliably on real
  hardware (the `[SNPR-EV]` investigation), the cron's only remaining value
  was a theoretical guard against snapshot operations that bypass snapper's
  own plugin runner — at the ongoing cost of rewriting limine.conf to the ESP
  every 15 minutes forever (flash wear, disk wakeups, menu churn) for a
  fallback that never needed to fire. Limine's snapshot menu is now updated
  by exactly two real events: a kernel install/remove (the `[KERNEL-HOOK]`
  post-install/post-remove hook) and a snapper snapshot create/delete (the
  plugin). A snapshot created outside snapper (e.g. a raw
  `btrfs subvolume snapshot`) will not appear in the menu until one of those
  fires — accepted. The `/etc/cron.d` entry is gone; do not reintroduce it.
  GRUB is unaffected (it never had the cron).

- **`[FSTRIM-SCOPE]`** — renamed the weekly fstrim cron from the legacy
  `fstrim-nvme` to `fstrim-discard`. The old name dated back to when the
  target disk was hardcoded to `/dev/nvme0n1`; since disk selection became
  interactive (nvme / mmcblk / sdX), `fstrim -A -q` trims any mounted
  discard-capable filesystem regardless of bus, so the name should not claim
  to be NVMe-only. No behavior change.

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
    exactly like the wallpaper choice, so every kernel-hook/snapper-plugin
    resync re-emits it (the cron resync was later removed in v3.3.0-beta8
    `[SNPR-EV-NO-CRON]`).
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
    `YK_MODE=hmac-sha1`; the dracut `99void-yubikey` module (which `inst`s
    the keyscript + `ykchalresp` + libusb into the initramfs AND installs a
    `/sbin/cryptroot-ask` override) is only built and added to 90-system.conf
    then. The resume path re-challenges the key (falling back to the
    passphrase only when a fallback slot exists, else FATAL — possession-only).
  - **CRITICAL boot-unlock override** — upstream dracut/dracut-ng does NOT
    execute the Debian-style `keyscript=` crypttab option (it `cat`s the
    third-field `luksfile` as a static keyfile and ignores `keyscript=` in
    the options field), so the stock `/sbin/cryptroot-ask` would never run
    the keyscript — the boot would always prompt for a typed passphrase,
    making a possession-only (slot-0-removed) install UNBOOTABLE. The
    `99void-yubikey` module ships a faithful mirror of upstream
    `cryptroot-ask.sh` that ADDS a `keyscript=` exec branch (piping the
    keyscript's stdout to `cryptsetup luksOpen`, retrying briefly so a
    hot-plugged/slow-recognized YubiKey has time to appear, and falling
    through to the passphrase prompt on failure to preserve `YK_FALLBACK=yes`).
    The module is named `99void-` (> `90crypt`) so its override wins the
    `/sbin/cryptroot-ask` path. This boot path is real-hardware UNPROVEN —
    validate on the target medium before trusting a possession-only install.
  - **`[ZSHRC]`** (fix) — when zsh is the chosen login shell, a minimal
    `~/.zshrc` is pre-created for the primary user so the first interactive
    session doesn't land in zsh's `zsh-newuser-install` wizard. Void's zsh
    package ships NO `/etc/zsh/newuser.zshrc.recommended` and nothing into
    `/etc/skel/.zshrc`, and `useradd -m` leaves the home dir with no zsh
    startup files — so a fresh zsh login previously fired the wizard and
    dumped the user with the "instructions to touch ~/.zshrc" message (a
    "[SHELL]" regression: bash needs no rc file, so this only ever bit the
    zsh path). The mere presence of `~/.zshrc` suppresses it: the
    `zsh/newuser` module halts once any of `.zshenv`/`.zprofile`/`.zshrc`/
    `.zlogin` exists. Written with the user's ownership and gated on
    `USER_SHELL=/bin/zsh`. The same treatment now applies when the chosen
    shell is fish: a minimal `~/.config/fish/config.fish` is pre-created so
    the first login doesn't fire the `fish_config` wizard (fish's own
    first-run wizard, which also prints a notice that the config file will
    be created). bash/mksh are unaffected (bash ships `/etc/skel` dotfiles
    and a system `/etc/bash.bashrc`; mksh has no interactive-first-run
    wizard).
  - **`[LIMINE-SNAPDATE]`** (Limine-only) — the `/+Snapshots` boot submenu
    entries in `void-limine-write-conf` now show the snapshot's creation
    date, read from the `<date>` element snapper writes into each
    snapshot's `info.xml`, so timeline snapshots are distinguishable at a
    glance instead of all rendering as the redundant `//snapshot N (#N)`.
    The ISO `YYYY-MM-DD HH:MM:SS` date is reformatted to an abbreviated
    name date + time (e.g. `Dec 4, 2027 15:04`) via
    `date -d ... '+%b %-d, %Y %H:%M'`; if the
    date doesn't parse (an odd `info.xml`), it falls back to the raw ISO
    string so the menu never breaks. When a snapshot has a `<description>`
    (not the case for timeline snapshots) the entry renders
    `//<desc> · <date> (#N)`; date-less snapshots keep the old
    `//<desc> (#N)` fallback. The change is purely additive to the Limine
    menu. The sister GRUB path uses the third-party
    `grub-btrfs` `41_snapshots-btrfs` generator and is intentionally
    untouched.
  - **`[LIMINE-WALLPAPER-BROWSE]`** (Limine-only) — the wallpaper path
    prompt no longer forces you to type the full path from memory. A
    pure-bash numbered `ls` browser (`..` to go up, a number to pick, or a
    typed absolute/relative path as an escape hatch) lets you walk the
    live system to the image. It starts at `/run/media` (where a USB
    stick holding the image is typically mounted) if present, else
    `/root`. Only directories and BMP/PNG/JPEG/QOI images are listed, so
    the menu numbers are always contiguous and every entry is a real
    choice. Designed around the Void live CD's default tooling — it uses
    only `bash`/`find`/`sort`, with no fzf/dialog/whiptail dependency to
    add to the live-CD package sync.
  - **`[LIMINE-WALLPAPER-OPT-OUT]`** (Limine-only) — if the wallpaper is
    declined at install, `void-limine-write-conf` still emits a harmless
    commented `# wallpaper:` section in limine.conf documenting how to
    enable (via `LIMINE_WALLPAPER=yes` in limine-env + an image on the
    ESP). Because the generator re-emits it on every resync, it does NOT
    create a hand-uncommented enable path; the live-emit guard (only when
    the ESP image exists) is unchanged.

---

## v3.3.0-beta5 — monthly btrfs integrity scrub

- **`[SCRUB]`** — the physical-corruption half of the recovery story,
  complementing Snapper (which guards against logical/accidental damage).
  Snapper's timelined snapshots and the dracut overlay protect the system
  from bad changes a user *makes*; nothing previously protected it from a
  disk silently *losing* data to bitrot. A new
  `/etc/cron.monthly/btrfs-scrub` job (written inside the shared chroot
  tail, right after the existing `fstrim-discard` cron.weekly entry and using
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
  - The 15-min `/etc/cron.d/void-limine-sync` entry was **kept as a safety
    net** for any menu change the plugin path might miss, but demoted from the
    primary mechanism. The old v3.1.0-beta1 comment is preserved (striking its
    false "no hook" premise is a history edit) and explicitly marked SUPERSEDED
    for the record. **LATER REMOVED — v3.3.0-beta8 (`[SNPR-EV-NO-CRON]`):** once
    the plugin proved to fire reliably on real hardware, the cron fallback was
    deleted and the plugin became the sole snapshot-menu trigger.
  - Scope decision at the time (user-confirmed): keep the cron fallback rather
    than deleting it; the change was additive, off by default for GRUB, and
    self-contained — no vendored `limine-snapper-sync`, no new dependency.
    This decision was reversed in v3.3.0-beta8 (`[SNPR-EV-NO-CRON]`) when the
    fallback was removed.
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
  snapper-plugin event; the cron resync was later removed —
  `[SNPR-EV-NO-CRON]`), guarded on the ESP file actually existing, so a
  declined install or a
  user-removed image never breaks the menu. Declining keeps the plain default
  menu untouched. Because the generator resync rewrites `limine.conf` regularly,
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
  `[COSMETIC]`, `[SCRUB]`, `[SNPR-EV]`, `[SNPR-EV-NO-CRON]`, `[ENCRYPT]`,
  `[YUBIKEY]`, `[ZSHRC]`, `[LIMINE-DEFAULT]`, `[ENCRYPT-ORDER]`, `[SUBVOLS]`,
  `[GRUB-ESP-BOOT]`, `[DOCS-LOG]`, `[ENCRYPT-KEYMAP]`, `[ENCRYPT-VERIFY]`,
  `[ENCRYPT-NEWLINE]`, `[CRYPT-NAME]`, `[PROMPT-DEFAULTS]`, `[DRY-RUN]`, `[FULLNAME]`,
  `[PKG-SNAPSHOT]`, `[PKG-SNAPSHOT-AUTO]`, `[RESHADOW-BOOT]`, `[TOOLS-DIR]`,
  `[TOOLS-LIMINE-BACKUP]`, `[LIMINE-HDR]`, `[LIMINE-WALLPAPER-OPT-OUT]`.
- Action words: `ADDITION` (new feature), `CHANGE` (behavioral change),
  `FIX` (bug fix), `EXPANSION` (extended feature).
