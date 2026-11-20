# Installer Interactive Prompts — Reference Guide

> **BEST-EFFORT CONVENIENCE GUIDE — NOT SOURCE OF TRUTH.**
> This document is a human-readable snapshot of the interactive prompts in
> `Void_Linux_Installer.sh` (current version: **Version-3.2.19**). It exists
> purely to make planning/QA easier. The script's own prompt code is the
> authoritative behavior — **this guide can drift out of sync and becomes
> stale if the script changes.**
> **Keep it in sync with every prompt change, or delete this file before
> final.**
>
> `[*]` marks a choice with no safe default (the script reprompts until a
> valid value is entered). Otherwise, pressing **Enter** accepts the shown
> default. `--yes` accepts every default and requires profile values for
> prompts that have no default. `--dry-run` walks the questionnaire and prints
> the plan without touching disks.

---

## 0. Boot mode detection (automatic, no prompt)

Before any question the installer detects firmware and sets `BOOT_MODE`:
- `/sys/firmware/efi` present → **UEFI**
- otherwise → **legacy BIOS**

BIOS mode uses the BIOS bootloader paths (GRUB i386-pc / Limine bios-install),
omits NVRAM registration prompts, and carves the required BIOS boot partition.
The detected mode is recorded in state, `install-config`, the dry-run plan,
and the final summary/review.

---

## 1. Install mode (pre-questionnaire)

- **Installation mode [1/2] (default 1: Express)** — (skipped if pre-set with
  `--express`, `--custom`, or `INSTALL_MODE=`)
  - `1` **Express (default)** — hardware-detected defaults; you answer accounts,
    disk encryption, desktop & session, target disk, and the final review.
    Optional software stays at its `DEFAULT_*` values.
  - `2` **Custom** — full questionnaire (locale/time/repos/storage, hardware &
    drivers, and optional software by depth).

**Step counts:** Express = 5 steps; Custom = 8 steps.
1. Accounts & identity
2. *(Custom)* Locale, time, repositories & storage
3. *(Custom)* Hardware & drivers
4. Encryption & disk layout
5. Desktop & session
6. *(Custom)* Optional software
7. Target disk
8. Review & confirm

---

## 2. Accounts & identity

### Express
- Account model and login shell use defaults (`DEFAULT_ACCOUNT_MODEL`, default
  Ubuntu-style; `DEFAULT_LOGIN_SHELL`, default bash) without prompting.

### Custom
- **User account model [1/2/3] (default `DEFAULT_ACCOUNT_MODEL`: 3 Ubuntu-style)** `[*]`
  - `1` Hybrid — root has a password AND the user gets full sudo access
  - `2` Debian-style — root has a password; user is NOT in sudo (`su -` only)
  - `3` Ubuntu-style — root is locked; user gets full sudo access (own password)
- **Login shell [1-4] (default `DEFAULT_LOGIN_SHELL`: 1 bash)** `[*]`
  - `1` bash, `2` zsh, `3` fish, `4` mksh

### Both modes (required identity)
- **Root password** — prompted/confirmed when the account model requires it
  (hybrid/debian); Ubuntu-style locks root.
- **`[*]` Username to create on the target system** — validated (POSIX login
  name). No default.
- **`[*]` Full name of user** (e.g. `John Doe`).
- **`[*]` Target system hostname** (e.g. `myhostname`).
- **Network domain name (optional)** — forms an FQDN (e.g. `example.com`);
  Enter to skip.
- **FQDN confirmation [Y/n]** — confirms `<hostname>` or `<hostname>.<domain>`.
- **User password** — prompted/confirmed for the created user as required by
  the chosen model.

---

## 3. Locale, time, repositories & storage (Custom only)

### Advanced storage & boot options (gate)
- **Enable advanced storage/boot options? [y/N by default, or current/default]**
  (honours `DEFAULT_ADVANCED_STORAGE`, default `no`; Express always leaves it
  off)
  - When **on**: enables later data-region carving (encryption/disk layout
    section) and the YubiKey hmac-sha1 unlock prompt. Expert options.
  - When **off** (or turned off in a review edit): advanced answers are reset
    to defaults so no carved partitions/YubiKey config remain.

### Locale
- **Locale choice [1-12] (default `DEFAULT_LOCALE`)** — presets for common
  UTF-8 locales plus `12` Custom (type a POSIX locale, e.g. `pl_PL.UTF-8`).

### Timezone
- **Timezone choice [1-15] (default `DEFAULT_TIMEZONE`)** — common zones
  (incl. auto-derived suggestion) plus `15` Custom (type an IANA zone, e.g.
  `Australia/Sydney`, or `UTC`).

### Repository mirror
- **Mirror choice [1-8] (default 1: Auto)** — auto-derived from timezone with
  backup mirrors/failover options and region extras as applicable.

### Local package cache
- **Use a local package cache?** (`DEFAULT_LOCAL_CACHE`, default `auto`) or
  type an absolute path. Auto-detects a suitable local cache when available.

### Swap & hibernation
- **Swap choice [1-4] (default `DEFAULT_SWAP_BACKEND`: 3 swapfile + zram)**
  - `1` Swapfile only, `2` zram only, `3` Swapfile + zram (default), `4` None
- **Enable hibernation (suspend-to-disk)?** (default `DEFAULT_HIBERNATION`: on)
  - If hibernation with a swapfile is enabled: **Swapfile size [1/2] (default
    1: 4G)** (or sized for RAM + margin as offered by the script).

### Bootloader & kernels
- **Bootloader [1/2] (default `DEFAULT_BOOTLOADER`: 1 Limine)** — `1` Limine,
  `2` GRUB.
  - **Limine (UEFI only): Register Limine NVRAM entry?** (default
    `DEFAULT_LIMINE_NVRAM`, off). If yes: **UEFI boot entry label** (default
    `DEFAULT_LIMINE_NVRAM_LABEL`, `Void Linux (Limine)`).
  - **GRUB + encryption:** ESP sizing is finalized accordingly (larger ESP used
    when needed).
- **Also install linux-mainline?** (default `DEFAULT_KERNEL_MAINLINE`: on)
- **Also install linux-lts?** (default `DEFAULT_KERNEL_LTS`: on)
  - `linux` (stable) is installed; Limine defaults to the stable branch.

### Limine wallpaper (Limine only)
- **Express / `--yes` / profiles:** driven by defaults — wallpaper **enabled by
  default** (`DEFAULT_LIMINE_WALLPAPER=true`), style `centered`
  (`DEFAULT_LIMINE_WALLPAPER_STYLE`), bundled Void splash unless
  `DEFAULT_LIMINE_WALLPAPER_SRC` names a usable BMP/PNG/JPEG/QOI image.
- **Custom (interactive):**
  - **Add a wallpaper to the Limine boot menu?** (default from
    `DEFAULT_LIMINE_WALLPAPER`)
  - If yes and no valid profile source: **Use a different image than the
    bundled Void splash? [y/N]** — if yes, browse/pick an image (must be a
    usable BMP/PNG/JPEG/QOI); invalid/missing falls back to the bundled splash.
  - If a custom image is selected: **Wallpaper style [1=stretched/2=tiled/3=centered]**
    (default follows configured style).

---

## 4. Hardware & drivers (Custom only)

- **Device profile [1-5] (default `DEFAULT_DEVICE_PROFILE`: 1 Automatic)** —
  automatic detection or explicit profile (e.g. desktop/server with/without
  Bluetooth); detected profile can be kept or overridden.
- Hardware probe summary shown (GPU families, wireless presence).
- **NVIDIA:** if an NVIDIA GPU is detected, prompt to install the proprietary
  driver (default follows detection/policy).
- **Wi-Fi firmware:** for detected hardware requiring it (e.g. Broadcom),
  prompt to install appropriate firmware (e.g. `linux-firmware-broadcom`);
  declining warns the radio may not work.

(Express uses hardware-derived defaults without these prompts.)

---

## 5. Encryption & disk layout

### Full-disk encryption
- **Enable full-disk encryption (LUKS2)? [y/N]** — encrypts the root
  partition/container; ESP/bootloader remain unencrypted.
  - If enabled: **LUKS passphrase** (entered/confirmed as required by the
    script/profile flow).
  - **Mapper name [void-root]** (default `void-root`) when applicable.
- **Snapshot-boot audio:** **Allow audio (PipeWire) to autostart during
  read-only snapshot boots?** (default `DEFAULT_SNAPSHOT_AUDIO`: on).

### YubiKey hmac-sha1 unlock (only if encryption **and** Advanced storage are on)
- Note shown that it is offered because Advanced storage is on.
- **Set up YubiKey hmac-sha1 unlock? [y/N]**
  - **Which OTP slot to program [1/2] (default 1)**
  - **Require a physical touch on the YubiKey to unlock at boot? [Y/n]**
  - **Keep the typed-passphrase fallback (YubiKey OR passphrase)? [Y/n]**
- Programming is performed later (see §11). Boot-unlock path should be
  validated on target hardware before relying on possession-only unlock.

### Data regions / partitioning layout
- **Advanced storage off (default, and always in Express):** all-Btrfs layout
  derived automatically (`home/var/cache/srv/opt` as Btrfs subvolumes, games
  none).
- **Advanced storage on (Custom):** prompts to carve regions as btrfs subvol or
  separate partitions as offered:
  - **/home** — btrfs (subvol) or ext4 (own partition)? `[b/e]` (default b)
  - **/var** — btrfs (subvols) or ext4 (own partition)? `[b/e]` (default b)
  - **/var/cache** — btrfs (`@cache`) or ext4 (own partition)? `[b/e]` (default b)
  - **/srv** — btrfs (`@srv`) or ext4 (own partition)? `[b/e]` (default b)
  - **/opt** — btrfs (`@opt`) or ext4 (own partition)? `[b/e]` (default b)
  - **~/<user>/Games** — none, ext4 partition, or btrfs partition? `[n/e/b]`
    (default n)
  - Sizes requested for carved partitions as applicable.

### ESP size (when choosing/confirming layout context)
- **EFI/ESP partition size [1-4/Custom] (default `DEFAULT_EFI_ESP_SIZE`: 4 GiB)**
  - `1` 4 GiB, `2` 6 GiB, `3` 8 GiB, `4` Custom (e.g. `512M`, `3G`, `10GiB`;
    validated, 1 GiB floor). (GRUB+encryption may require a larger ESP; the
    installer adjusts as needed.)

---

## 6. Desktop & session

- **Desktop environment [1-8] (default `DEFAULT_DESKTOP`: 1 KDE Plasma)** —
  KDE Plasma, Cinnamon, GNOME, Xfce, MATE, LXQt, COSMIC, or headless/none (as
  listed by the script). Store auto-selection depends on DE (GNOME→GNOME
  Software, KDE→KDE Discover, COSMIC→Cosmic Store).
- **Display manager** — chosen/recommended per desktop (e.g. SDDM, LightDM,
  GDM, or cosmic-greeter for COSMIC) with the script’s presented options;
  Express uses the recommended DM.
- **Headless/server options (as applicable):** keep Xorg/Wayland base for later
  `startx`/remote-X? `[y/N]`; install audio stack (PipeWire + ALSA)? `[y/N]`.
- **LightDM greeter** (when relevant): choice as offered (e.g. GTK).
- **Session/seat stack [1/2] (default `DEFAULT_SESSION_STACK`: elogind)** —
  elogind (default) or turnstile+seatd+acpid (as offered).

---

## 7. Optional software (Custom only)

Selections are seeded from `DEFAULT_*`. Groups **above** the chosen depth keep
defaults; Express, `--yes`, and depth **None** share the same default path.
Dependent answers are re-derived (e.g. Flatpak-only apps dropped if Flatpak is
off).

### Depth menu
- **Optional software depth [1-4] (default `DEFAULT_OPTIONAL_TIER`: 2 Common)**
  - `1` **Essentials** — Flatpak, app store, browsers, Thunderbird
  - `2` **Common (default)** — Essentials + Homebrew, games, VirtualBox,
    containers, SSH
  - `3` **Advanced** — Common + per-app Btrfs subvolume isolation
  - `4` **None** — skip these questions and keep `DEFAULT_*` values

### Essentials (tiers 1–3)
- **Install Flatpak (+ Flathub)? [Y/n]** (`DEFAULT_FLATPAK`, on). Flatpak is
  optional and independent of xbps stores.
- **App store / package manager** (non-store DEs: Cinnamon/Xfce/MATE/LXQt):
  **choice [1-5] (default 1: None)** — None, OctoXBPS, GNOME Software, KDE
  Discover, Cosmic Store. Stores manage native xbps packages; Flatpak apps
  appear once Flatpak is installed (GNOME Software/KDE Discover are the
  installer-pinned xbps-capable builds). GNOME/KDE/COSMIC desktops get their
  native store automatically.
- **Set up web browsers now?** (`DEFAULT_WEB_BROWSERS`, on). If yes, choose
  each independently:
  - Firefox `[Y/n]` (`DEFAULT_FIREFOX`)
  - Chromium `[Y/n]` (`DEFAULT_CHROMIUM`)
  - Vivaldi (proprietary, nonfree repo) `[y/N]` (`DEFAULT_VIVALDI`)
  - Falkon `[y/N]` (`DEFAULT_FALKON`)
  - Brave `[y/N]` (`DEFAULT_BRAVE`) — **Flatpak-only** delivery; skipped if
    Flatpak not selected
- **Install Thunderbird (email client)?** (`DEFAULT_THUNDERBIRD`, on)

### Common (tiers 2–3) — THIRD-PARTY APP CHANNELS / apps / services
Header notes Flatpak was answered under Essentials (independent channel).
- **Install Homebrew (Linuxbrew, ~/.linuxbrew)? [y/N]** (`DEFAULT_BREW`)
- **Games/runtimes:** Lutris `[y/N]`, Heroic & Bottles (Epic/GOG + Wine
  prefix launchers, **Flatpak**) `[y/N]` (offered/skipped based on Flatpak),
  Wine (system, multilib) `[y/N]`, gamemode `[y/N]`, Steam `[y/N]`
- **Install VirtualBox? [y/N]** (`DEFAULT_VIRTUALBOX`)
- **Containers:** set up containers now? `[y/N]`; if yes: Podman rootless
  `[y/N]`, Podman rootful `[y/N]`, Docker `[y/N]` (and if Docker, add user to
  docker group `[y/N]`), distrobox `[y/N]` with track/engine choices as offered
- **Install and enable OpenSSH server (sshd)? [y/N]**; if yes: port (default
  `DEFAULT_SSH_PORT`), allow password auth `[y/N]`, allow root login
  (public-key only) `[y/N]`, import existing key from removable media `[y/N]`,
  generate ed25519 keypair `[y/N]` (passphrase `[Y/n]`), export backup to
  removable media `[y/N]`

### Advanced (tier 3) — per-app Btrfs subvolume isolation
- Master choices: **isolate data for software you ARE installing? [Y/n/i]** and
  **pre-create empty isolated subvolumes for software NOT installed? [y/N/i]**
  (`i` = decide per app). Applies to eligible selected apps (browsers, mail,
  game/VM/container/brew data as applicable); OctoXBPS and Flatpak
  system-wide store are excluded per script notes. Tiers 1/2/4 and Express use
  `DEFAULT_SUBVOL_*` without prompting.

---

## 8. Target disk

- **`[*]` Select disk to partition and install to [1-N] (no default)** — lists
  available disks; the chosen disk will be erased (after confirmation).

---

## 9. Review & confirm

- Full summary printed (install mode/optional depth/advanced storage, target
  disk, boot mode/bootloader/wallpaper/NVRAM as applicable, desktop/DM/session,
  accounts, locale/time/repo, encryption, data regions, swap/hibernation,
  kernels, hardware, app channels/store/browsers/mail/games/virtualization/
  containers/SSH, subvolume isolation flags, etc.).
- **Proceed [Enter], edit [1-M], or restart [R]**
  - **Enter:** continue to destructive confirmation.
  - **Section number:** re-run that section (Express: 1 Accounts, 2 Encryption &
    disk layout, 3 Desktop & session, 4 Target disk; Custom: 1–7 as listed),
    then redraw summary.
  - **R:** restart configuration from the top (nothing written to disk yet).

---

## 10. Destructive confirmation (ERASE)

- **If target already contains a Void install:** `[*]` **Type `ERASE <device>`**
  (exact device path) to confirm, or anything else to abort.
- **Otherwise:** `[*]` **Confirm wiping <disk>: type `ERASE!`** (or anything
  else to abort).

No disk changes occur before this confirmation (and `--dry-run` never writes).

---

## 11. YubiKey programming (post-wipe, conditional)

Only when `YK_MODE=hmac-sha1` (encryption + Advanced storage + YubiKey
selected):
- **Program slot <N> now — confirm the key is plugged in? [y/N]** (after
  required tools are available). Follow on-screen instructions; the installer
  binds the challenge-response key slot as configured (with or without
  passphrase fallback).

---

## Notes

- `--resume` / `-r` reloads saved answers from `/tmp/void-installer-state.sh`
  and continues (skipping re-asked config as applicable).
- `--save-log` copies the crash journal to a mounted USB stick.
- Profiles (`--profile FILE`) are sourced as root before defaults resolve and
  may pre-answer prompts; `--yes` takes defaults and requires profile values
  for prompts without defaults.
- Exact wording, ordering, and conditional branches are defined by
  `Void_Linux_Installer.sh` and may differ in edge cases; defer to the script.