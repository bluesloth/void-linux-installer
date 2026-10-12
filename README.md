# Void Linux Advanced Recovery Installer

A self-documenting, runit-based Void Linux installer that runs **exclusively on
the outer host terminal of a Void Linux Live CD** and produces a
recovery-first, snapshot-friendly system.

## Repository contents

| File | Description |
|------|-------------|
| `Void_Linux_Installer.sh` | Unified working installer (current version: **Beta-v2.9.91**). Run this. |
| `CHANGELOG.md` | Full lineage changelog using the `[VERSION-CARRY]` scheme: Alpha-v (manual step scripts), Beta-v (unified installer, current era). |

## Usage

Run from the outer terminal of a Void Linux Live CD:

```sh
./Void_Linux_Installer.sh                 # fresh interactive install
./Void_Linux_Installer.sh -r|--resume     # resume a previous interrupted install
./Void_Linux_Installer.sh -d|--dry-run    # walk config, print the plan, touch nothing
./Void_Linux_Installer.sh -h|--help       # show usage
```

The live USB session is ephemeral, but a crash leaves user answers in
`/tmp/void-installer-state.sh` for the rest of that booted session, so a
re-run can resume without re-typing anything. Only password **hashes** are
persisted (never live passwords), and the state file is removed only on a
fully successful install.

`-d|--dry-run` walks the whole interactive config and prints the complete
plan (target disk, partition/mkfs steps, bootloader, desktop, wallpaper, etc.)
then stops **before** touching any disk — a read-only preflight that modifies
neither the target nor the live medium.

## What it produces

- Single physical disk, GPT, **UEFI-only** (BIOS boot is not implemented).
- Partition 1 = ESP (FAT32); partition 2 = one BTRFS filesystem with a
  **flat** (non-nested) subvolume topology (`@`, `@home`, `@grub`, `@swap`,
  browser subvols) so each is independently snapshot-able/rollback-able.
- **runit** init — systemd-free, no systemctl/journalctl/loginctl logic.
- **Recovery**: Snapper timeline snapshots + a dracut overlay so snapshot
  boots are read-only with a writable RAM overlay.
- **Self-documenting** (Beta-v2.5.1): each install archives the exact
  configuration that built it to `/etc/void-installer/install-config` plus a
  copy of the installer itself (`Void_Linux_Installer.sh`), so the machine
  records both what was chosen and which revision built it.
- **Hibernation** via a single physical BTRFS-native swapfile.
- Install-time **choices**:
  - Desktop: KDE Plasma (default), Cinnamon, GNOME, Xfce, MATE, LXQt, or
    COSMIC (community repo, third-party trust choice — use at own risk).
  - Display manager: SDDM, LightDM (GTK/Slick greeter), GDM, or
    cosmic-greeter (COSMIC default).
  - Bootloader: **grub** (mature, grub-btrfs menu) or **limine** (experimental,
    static config via `void-limine-write-conf`, synced by a Void-native
    snapper plugin — now the sole snapshot-menu trigger). Limine now uses a
    single `esp-copy` kernel mode (the former `btrfs-direct` option was
    removed — it read the kernel straight off Btrfs, which Limine does not
    support, so it could never boot). Limine is deployed **NVRAM-free**: the
    plain `BOOTX64.EFI` is placed at `/boot/efi/EFI/BOOT/` (UEFI
    removable/failsafe path), so no efibootmgr boot entries are written.
  - Beta-v2.5.1: optional **Limine boot-screen wallpaper** (opt-in drop-in;
    BMP/PNG/JPEG/QOI image copied onto the ESP, `stretched`/`tiled`/`centered`,
    guarded so a missing image never breaks the menu). Declining keeps the
    default look; enable later durably via `LIMINE_WALLPAPER=yes` in
    `/etc/void-installer/limine-env` + placing the image on the ESP.
    Beta-v2.5.4 (`[LIMINE-WALLPAPER-BROWSE]`): the path prompt is now a
    numbered `ls` browser (`..` to go up, pick by number, or type a path),
    starting at `/run/media` for a mounted USB stick — so you can walk to
    the image instead of typing the path from memory. Pure bash, no
    extra live-CD packages. Beta-v2.5.4 (`[LIMINE-WALLPAPER-OPT-OUT]`):
    declining keeps a commented `# wallpaper:` how-to-enable section in
    limine.conf (Limine ignores comments; safe), so the option stays
    discoverable.
  - Beta-v2.5.2: **event-driven Limine snapshot-menu sync** (`[SNPR-EV]`).
    Void's snapper provably fires `/usr/lib/snapper/plugins` (verified on real
    hardware), so a tiny `00-void-limine-snapper-sync` plugin (name must start
    with a digit — snapper ignores letter-prefixed plugins) regenerates the
    menu the instant a snapshot is created/deleted — the plugin is now the
    sole snapshot-menu trigger (Beta-v2.5.6 `[SNPR-EV-NO-CRON]` removed the
    15-min `/etc/cron.d/void-limine-sync` fallback that had been the primary
    mechanism in Beta-v2.3.0).
  - Beta-v2.5.4: **snapshot date in the Limine menu** (`[LIMINE-SNAPDATE]`).
    The `/+Snapshots` submenu entries show each snapshot's creation date
    + time from its `info.xml` `<date>`, reformatted to an abbreviated name
    (e.g. `Dec 4, 2027 15:04`), so timeline snapshots (which have no
    `<description>`) are distinguishable at a glance instead of all showing
    the redundant `//snapshot N (#N)`. Limine-only — the GRUB path uses
    grub-btrfs's own generator and is untouched.
    Also new in beta4: a real **login-shell choice** (`[SHELL]`) — the primary
    user is created with `-s` set to the chosen shell (bash default, or
    zsh/fish/mksh installed from the repos); the choice is persisted across
    resume and echoed in the dry-run plan and final summary. And a **post-ERASE
    review step** (`[CONFIRM]`) — right after the wipe confirmation the
    installer prints a complete summary of every choice and lets you press
    Enter to proceed or type `R` to re-run the configuration from the top
    before any disk is touched.
    Same release also carries four fixes: `[NODATACOW]` (the churn-heavy var
    subvols `@srv`/`@cache`/`@log`/`@spool` are now actually
    nodatacow+compress=none via mount/fstab, where the old pre-mount
    `chattr +C` was shadowed and did nothing), `[LIGHTDM-ATOMIC]`
    (`/etc/lightdm/lightdm.conf` written atomically via temp+rename so it
    cannot be truncated), `[NM-IFACE]` (the `interface-name=` in the
    `br0-slave` bridge connection is a literal — when the `enp*` detection
    fallback fires the key is now omitted so the slave matches by role instead
    of emitting an invalid glob), and two same-class resume fixes — `SWAPFILE_MODE`
    (persisted so a resumed run still builds `@swap`, the swapfile, and the
    fstab swap entries) and `TARGET_PASS_HASH` (persisted so a resumed run can
    re-apply the target user's password hash via `chpasswd` instead of aborting
    on the empty-metadata guard).
  - Beta-v2.5.3: **monthly btrfs integrity scrub** (`[SCRUB]`). A
    `/etc/cron.monthly/btrfs-scrub` job scrubs every Btrfs filesystem once
    a month — deduped by device (`/proc/self/mountinfo` major:minor) so
    subvolume mounts aren't scrubbed once each, never forced so a manual
    scrub is never raced, results date-stamped and logged to
    `/var/log/btrfs-scrub.log`. This is the physical-corruption complement
    to Snapper's logical-damage protection (bitrot detection + Btrfs
    repair).
  - Beta-v2.5.5: **optional LUKS2 full-disk encryption** (`[ENCRYPT]`).
    An opt-in toggle (`[y/N]`) wraps partition 2 in a LUKS2 container
    (`/dev/mapper/void-root`); the ESP/stay-bootloader unencrypted. The
    passphrase is typed at every boot (dracut `crypt` module). The Btrfs
    subvolume topology, swapfile/hibernation, Snapper, and scrub all run
    unchanged on the mapper. `BTRFS_UUID` (filesystem) and `LUKS_UUID`
    (container) are distinct — the former drives fstab/root/resume, the
    latter crypttab + `rd.luks.uuid=`/`rd.luks.name=` on both GRUB and
    Limine. `cryptsetup` + the dracut `crypt` module are only installed
    when encryption is on.
  - Beta-v2.5.4: **optional YubiKey hmac-sha1 unlock** (`[YUBIKEY]`), the
    deferred follow-up to `[ENCRYPT]`. Prompts to program an OTP slot with
    `ykpersonalize` (`-ochal-resp -ochal-hmac -ohmac-lt64`), binds
    HMAC-SHA1(slot_secret, random 40-hex challenge) as an *additional* LUKS
    key slot, and ships a dracut module (`99void-yubikey`) that installs a
    `/sbin/cryptroot-ask` override executing `void-reveal-yubikey-key` to
    re-challenge the YubiKey at boot and feed the response to luksOpen — no
    typed passphrase. (A bare crypttab `keyscript=` is NOT enough: dracut
    ignores it and treats the keyfile field as static.) With
    `YK_FALLBACK=yes` the typed
    passphrase slot is kept as a boot fallback; `YK_FALLBACK=no`
    (possession-only) removes it, but that tightens to Limine + YubiKey
    (GRUB's LUKS2/Argon2i cryptodisk path is unreliable). The HMAC response
    is memory-only — never persisted (challenge + slot are public; the
    YubiKey's possession is the credential). Requires `ykpers`
    (`yubikey-personalization`) on the live medium and in the target.
    NOTE: the boot-unlock path is real-hardware UNPROVEN — validate a
    possession-only install on the target medium before relying on it.
    Also new in beta7: `[ZSHRC]` — when zsh is the chosen login shell,
    a minimal `~/.zshrc` is pre-created for the primary user so the
    first login doesn't hit zsh's `zsh-newuser-install` wizard (Void's
    zsh package ships no recommended-rc, so it dumps you with the
    "instructions to touch ~/.zshrc" prompt; the mere presence of the
    file suppresses the wizard). The same applies to fish: a minimal
    `~/.config/fish/config.fish` is pre-created so the first login
    doesn't fire the `fish_config` wizard. bash/mksh are unaffected.
  - Localization, timezone, and session/seat stack (elogind vs. turnstile +
    seatd + acpid).
  - Repo mirror auto-derived from timezone with an override menu
    (Beta-v2.5.0): Fastly/repo-default backup mirrors retained for failover.
  - Beta-v2.5.0: LightDM hardening (accounts-daemon supervised service,
    `@lightdm` chown) for the greeter failures
    seen on real hardware; **`session-wrapper=/etc/lightdm/Xsession`** is now
    written into the generated lightdm.conf (without it, overwriting Void's
    default left LightDM using the nonexistent `lightdm-session`, so every
    login bounced back to the greeter with an empty `.xsession-errors`);
    Beta-v2.9.1 **removes the WebKit2 greeter option** (lightdm-webkit2-
    greeter is abandoned upstream and black-screens against current
    webkit2gtk), leaving GTK + Slick as the only LightDM greeters;
    Podman/Docker/virtualization prompts are now **default-off**; the
    end-of-install wait is a live countdown driven by `REBOOT_DELAY` with
    R/Enter=now, P=pause, C=continue, S=stop keys.
- Virtualization: QEMU/KVM + libvirt on a custom `br0` bridge (NOT the
  default NAT `virbr0`).

## Attribution & history

The long development history is recorded in `CHANGELOG.md`. Early (alpha →
3.0.x) work is an **educated reconstruction** from untagged legacy features
and the script's `[item N]` markers, since the original companion changelog
was lost.

## Safety notes

- READ the header of `Void_Linux_Installer.sh` before changing anything
  structural. It lists regressions that have already broken a real install
  and must not be "simplified" away (e.g. the `grub-mkconfig` call, the
  `xbps-reconfigure -f` for kernel hooks, ESP kernel-copy sync, and the
  deliberate GRUB/Limine code-path separation).
