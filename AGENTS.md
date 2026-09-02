# AGENTS.md

Guidance for AI agents (and humans) working on this repository.

## What this is

`Void_Linux_Installer.sh` is a self-documenting Void Linux installer that runs
exclusively on the outer terminal of a Void Linux Live CD. It installs a
runit-based, recovery-first system (Snapper + dracut overlay), UEFI-only,
single-disk GPT with a flat BTRFS subvolume topology.

## Working model

- The installer is a **single unified file**. (The earlier
  `Void_Linux_Installer_3.1.0-beta1.sh` frozen-baseline snapshot is no longer
  shipped in this folder; history lives in `CHANGELOG.md`.) The temporary
  `Void_Linux_Installer_3.3.0-beta3_pre-install-config.sh` pre-`--dry-run` (#7)
  working checkpoint was removed once #7 concluded.
- Versioning is tracked via the `SCRIPT_VERSION=` variable and inline
  version-tagged comments (e.g. `[MIRROR]`, `[COSMIC]`, `[SWAP]`,
  `[LOCALIZE]`, `[RESUME]`, and `AI (Claude...)` / `AI (Big Pickle)` attribution
  markers). The `CHANGELOG.md` is a reconstruction derived from these inline markers.
- When adding a feature, tag it with a new version marker and update
  `CHANGELOG.md` and the header `ARCHITECTURE SUMMARY` block.
- **Version-bump ritual** — when bumping `SCRIPT_VERSION`, grep for every
  surviving reference to the version you are *leaving* so a bump never leaves
  a stale marker in a comment/README/CHANGELOG row that would mislabel the
  reconstructed history:
  ```sh
  grep -rn "3.3.0-beta2.1" --include="*.sh" --include="*.md" .
  ```
  Each remaining hit is either (a) updated to the new version, or (b) a
  deliberate historical reference (e.g. the old version's CHANGELOG section
  heading) that is intentionally kept. Historical inline markers keep the
  version in which they were introduced; only "current version" indicators
  change on a bump.
- `[INSTALL-CONFIG]` writes `/etc/void-installer/install-config` (choices) and
  archives the installer into the target. This file must stay **secret-free**
  (no password hashes) — it is an as-built, human-readable summary only;
  anything cryptographic lives in limine-env, the resume-state file, or the
  account provisioning already. In addition, `[DOCS-LOG]` (v3.3.0-beta14)
  writes a per-machine quick record at `~/Documents/VOID_INSTALL.txt`
  (installed user): `SCRIPT_VERSION`, install UTC, bootloader, ESP
  mountpoint (flags the GRUB+ENCRYPT `/boot`==ESP combo), encryption/YubiKey
  public flags, session/desktop — **equally secret-free**, and just a pointer
  to the two authoritative `/etc/void-installer` artifacts. Keep it a pointer;
  do not grow it into a full choices dump or add anything cryptographic.

## Mandatory invariants (do not break)

Search the script header for "CRITICAL" / "DO NOT" before touching anything.
Known regressions that have already broken a real install:

1. `[BOOTLOADER=grub]` The explicit `grub-mkconfig -o /boot/grub/grub.cfg`
   call right after `grub-install` is the ONLY thing that reliably generates
   grub.cfg on a fresh install. Leave it in place.
2. `xbps-trigger kernel-hooks` is **not** a real command. Use
   `xbps-reconfigure -f <kernel-pkg>`.
3. First-boot `rc.local` must link services into
   `/etc/runit/runsvdir/default/` directly — `/var/service/*` is a dangling
   symlink at that point in boot.
 4. `[BOOTLOADER=limine, KERNEL_MODE=esp-copy]` ESP kernel copies can silently
    go stale; keep the post-install kernel hook's `set -e` and the explicit
    post-reconfigure re-sync. `esp-copy` is now the ONLY Limine mode — the
    former `btrfs-direct` option was intentionally removed (`[LIMINE-ESP-ONLY]`;
    it read the kernel straight off Btrfs, which Limine's own docs do not
    support, so it never booted). Do not reintroduce a second KERNEL_MODE or a
    `btrfs-direct` branch; `KERNEL_MODE` is kept solely as a self-documenting
    value that is always `esp-copy` for limine / `n/a` for GRUB.
5. Do **not** merge or cross-wire the GRUB and Limine code paths — they are
   deliberately two separate `$BOOTLOADER` branches with no shared
   config-generation logic.
6. `[LIGHTDM-HW]` LightDM greeters (GTK/Slick/WebKit2) depend on
   `org.freedesktop.Accounts`, which Void ships with NO runit service. Keep
   the installer's supervised `/etc/sv/accounts-daemon` provisioning plus the
   first-boot rc.local link (gated on `DISPLAY_MANAGER=lightdm`) — do not
   "simplify" it back to D-Bus activation. Also keep the `@lightdm` chown and
   the WebKit2 `webkit-theme=void` config.
7. `[LIGHTDM-SWRAP]` The generated `/etc/lightdm/lightdm.conf` MUST keep the
   explicit `session-wrapper=/etc/lightdm/Xsession` line. Overwriting Void's
   package-default conf removes the wrapper that would otherwise be set, and
   LightDM then falls back to its compiled-in default `lightdm-session`, a
   binary Void does not ship — every login bounces back to the greeter with an
   empty `.xsession-errors`. Do not drop this line.
8. `[LIMINE-HDR]` In Limine, kernels are grouped inside a collapsible
   `/+Void Linux` submenu (each kernel a `//...` sub-entry — sub-entries MUST
   use more than one `/` prefix), mirroring `+Snapshots`. A bare
   `default_entry` index cannot descend into a submenu, so `default_entry`
   must be an entry **path**
   to the newest kernel (e.g. `Void Linux/Void Linux (<version>)`), not an
   index like `2`. Do not revert to a top-level flat kernel list, and do not
   set `default_entry` to a plain index.
9. `[LIMINE-WALLPAPER]` The boot-screen wallpaper is an opt-in persisted
   setting: the user's choice and style live in `/etc/void-installer/limine-env`
   (`LIMINE_WALLPAPER`, `LIMINE_WALLPAPER_STYLE`), and `void-limine-write-conf`
   re-emits `wallpaper:`/`wallpaper_style:` **only when** the ESP file
   `/boot/efi/limine-splash.<ext>` actually exists. The image is copied onto
   the ESP at install time from a stage path (`/mnt/tmp` → `/tmp` in the
   chroot). Keep this persisted/guarded design: do not hardcode a wallpaper
   path that bypasses limine-env, and do not drop the existence check (a
   missing image would otherwise leave a dangling `wallpaper:` line). Because
    the generator resync (kernel hook / snapper plugin) rewrites limine.conf
    regularly, there is deliberately NO
   hand-uncommented shortcut — the only way to enable a background is to set
   `LIMINE_WALLPAPER=yes` (+ style) in limine-env and place the image on the
   ESP; do not reintroduce a commented template that resyncs would wipe out.
   Limine `wallpaper:` works with Void's plain `BOOTX64.EFI` (not limine-gui-only).
   `[LIMINE-WALLPAPER-OPT-OUT]` (v3.3.0-beta7): when the user declines the
   wallpaper, `void-limine-write-conf` still emits a HARMLEESS commented
   `# wallpaper:` section documenting how to enable — because the generator
   itself re-emits it on every resync, it does NOT create a hand-uncommented
   enable shortcut and is consistent with the guarded design above.
 10. `[SNPR-EV]` Void's snapper **does** execute `/usr/lib/snapper/plugins`
     (empirically verified on target hardware — `Debug/snpr_ev/probe_void_snapper_plugin.sh`;
     this refutes the old v3.1.0-beta1 `[LIMINE-SYNC-CRON]` "no hook" premise).
     The installer writes a Void-native plugin
     `/usr/lib/snapper/plugins/00-void-limine-snapper-sync` (Limine branch only,
     never GRUB) that calls the shared `void-limine-write-conf` on
     `create-snapshot-post`/`delete-snapshot-post`. CRITICAL: the plugin
     filename MUST start with a digit — snapper silently ignores anything
     else (man snapper, PLUGINS: "The name has to start with a digit,
     execution order is alphabetical"). The very first `[SNPR-EV]` build named
     it `void-limine-snapper-sync` (letter-prefixed) and it NEVER fired on real
     hardware; the probe only "worked" because it used the digit-prefixed
     `00-void-probe`. Do NOT rename it without the `NN-` prefix. Do NOT delete
     the plugin "to simplify" — the `00-void-limine-snapper-sync` plugin is now
     the SOLE snapshot-menu trigger. The former 15-min
     `/etc/cron.d/void-limine-sync` fallback was REMOVED in v3.3.0-beta8
     (`[SNPR-EV-NO-CRON]`); do not reintroduce it. The kernel post-install hook
     and the plugin both fire the same single generator, so menu updates have
     exactly two real events: a kernel change or a snapshot change.
11. `[ENCRYPT]` Optional LUKS2 full-disk encryption is a **typed-passphrase-only**
    opt-in (`ENCRYPT=yes`). The passphrase is NEVER persisted — it lives in
    memory, is fed to `cryptsetup luksFormat`/`luksOpen` only via stdin
    (`--key-file=- <<<"..."; ` `read -s` twice + match check), and is `unset`
    right after `luksOpen`. Be careful with the two UUIDs: `BTRFS_UUID`
    (read from the mapper `$BTRFS_DEV`) is the Btrfs fs UUID that drives
    fstab/root/resume, while `LUKS_UUID` (read from partition `$PART_SYS`) is
    the ciphertext container UUID that drives crypttab and the
    `rd.luks.uuid=... rd.luks.name=...=void-root` kernel params. Do NOT
    conflate them, and do NOT persist any passphrase to install-config,
    limine-env, resume state, or chroot_env.
12. `[YUBIKEY]` Optional YubiKey hmac-sha1 unlock (`YK_MODE=hmac-sha1`) is a
    **typed-passphrase-with-optional-possession-only** feature layered on
    `[ENCRYPT]`. The HMAC RESPONSE (`YK_KEY`, fed to `luksAddKey`/`luksOpen`)
    is NEVER persisted — it lives in memory (or a 0600 /tmp tmpfs file that is
    shredded immediately after use) and is `unset` as soon as the slot is
    bound/opened. Only PUBLIC values survive: `YK_MODE`, `YK_SLOT`,
    `YK_CHALLENGE` (a 40-hex randomness string that is a challenge, not a
    credential), `YK_FALLBACK`, `YK_TOUCH` — persisted to the state file,
    chroot_env, and limine-env. Do NOT export/write `YK_KEY` to any of those,
    or to install-config. Keep `ykchalresp` invoked identically at enroll,
    resume, and in the boot keyscript (`-${YK_SLOT} "$YK_CHALLENGE"`, no
    `-x`/`-c`) so the response stays byte-identical. `YK_FALLBACK=no`
    (possession-only) is FORCED back to `yes` under `BOOTLOADER=grub` —
    GRUB's LUKS2/Argon2i `cryptodisk` path is unreliable, so a possession-only
    bootloader must be guaranteed to read the volume (Limine is the safe
    pairing). The dracut `99void-yubikey` module is only built and added to
    90-system.conf when `YK_MODE=hmac-sha1`. CRITICAL: the module MUST keep
    installing its `/sbin/cryptroot-ask` override — upstream dracut/dracut-ng
    does NOT execute the Debian-style `keyscript=` crypttab option (it treats
    the third-field `luksfile` as a static keyfile via `readkey`/`cat` and
    ignores `keyscript=`), so without the override the boot always prompts for
    the typed passphrase and a possession-only install (slot 0 removed) is
    UNBOOTABLE. Do not "simplify" the keyscript branch back to a plain crypttab
    `keyscript=` line or drop `inst_script ... /sbin/cryptroot-ask`. The module
    is named `99void-yubikey` (99 > 90crypt) specifically so its override wins
    the `/sbin/cryptroot-ask` path in the initramfs; do not renumber it below
    `90crypt`. CRITICAL (`[YK-KEYSCRIPT-BAKE]`, v3.3.0-beta10): the
    `void-reveal-yubikey-key` heredoc MUST stay UNQUOTED (`<< INNER_EOF`, like
    the limine-env heredoc) so its `${YK_SLOT}`/`${YK_CHALLENGE}` placeholders
    bake at install time — cryptroot-ask execs keyscripts with no environment,
    so a quoted heredoc leaves unbound vars under `set -u` and a possession-only
    boot can never unlock. This boot unlock path is real-hardware UNPROVEN —
    validate on the target medium before trusting a possession-only install.

## System/init constraints

- **runit only**, never systemd. Do not add systemctl/journalctl/loginctl or
  `.service`-unit logic. Enable services via
  `ln -s /etc/sv/X /etc/runit/runsvdir/default/...`.
- Session/seat is a real choice (`$SESSION_STACK`): elogind (default) or
  turnstile + seatd + acpid. Neither makes this a systemd system.

## Validation

- `bash -n Void_Linux_Installer.sh` must pass after any edit.
- Shellcheck (when available on the Void Live medium — not installed in this
  dev box, so it is an *additional* gate, not a CI blocker): run
  `shellcheck -f gcc Void_Linux_Installer.sh` as a triage pass. Treat the
  top-severity findings (SC2xxx/SC2xxx quoting and expansion, `set -u`,
  unused/typo'd vars) as must-fix before a real install; lower-severity
  findings that are intentional (deliberate word-splitting of `$KERNEL_ENTRIES`,
  dynamic constructs inside the `INNER_EOF` heredocs) get a per-SC-code
  `# shellcheck disable=` with a one-line rationale — never blanket-disable
  the whole file. If shellcheck is absent, `bash -n` plus a manual read of
  any changed pipeline is the fallback.
- The generated helper scripts under `/usr/local/sbin`
  (`void-limine-env.inc`, `void-limine-write-conf`, `void-limine-sync-kernels`)
  the snapper plugin under `/usr/lib/snapper/plugins`
  (`00-void-limine-snapper-sync`),
  the dracut YubiKey module under `/usr/lib/dracut/modules.d/99void-yubikey`
  (`module-setup.sh`, `cryptroot-ask.sh`),
  the snapshot-overlay module under
  `/usr/lib/dracut/modules.d/95snapshot-overlay`,
  `/etc/rc.local`, `/etc/sv/*/run`, and the rest of the installer's heredoc
  bodies ARE NOT parsed by the installer's own `bash -n` — they are written
  inside nested `<< 'INNER_EOF'` heredocs and raw heredoc text is consumed by
  the parent script, not syntax-checked. After changing any such heredoc, run
  `Debug/check-heredocs.sh` (committed, reproducible): it extracts every
  generated body (including the whole stage-2 `chroot ... << 'CHROOT_EOF'`
  block) into a temp tree, `bash -n`s every shell-classified body, and
  `shellcheck -f gcc -e SC1091`s the quoted generated-file heredocs. That
  script is the gate — never rely on /tmp scratch tooling again. SC1091 is
  excluded tool-side because extracted bodies source absolute system/dracut
  libs that never exist in the flat extraction tree; per-SC disables that the
  generated files themselves carry (SC2154 dracut globals, SC2050 rc.local
  sed placeholders, SC2034 greeter wait counter, SC2086/SC2012 deliberate
  word-splits) are intentional and must stay.
- Run the installer only on a real/modular Void Linux Live environment; do
  not execute it against the working tree or host. `-d|--dry-run` ([DRY-RUN])
  is the closest thing to a safe local preflight: it walks every prompt and
  prints the plan, aborting before any disk write or chroot and skipping the
  live-CD package sync — but the disk-picker still reads `/sys` and `lsblk`,
  so it should still be run on the target medium, not the dev box.

## Attribution policy

Historical work is attributed via `AI (Claude, Sonnet 5, Medium)` and
`AI (Big Pickle)` markers. The former `AI (OxAlpha)` label was intentionally
removed (that work was actually done by Claude). Do not reintroduce
"OxAlpha"/"Gemini"/"Alpha" attribution labels.
