# Installer Interactive Prompts — Reference Guide

> **BEST-EFFORT CONVENIENCE GUIDE — NOT SOURCE OF TRUTH.**
> This document is a human-readable snapshot of the interactive prompts in
> `Void_Linux_Installer.sh` (current version: **Beta-v2.9.12**). It exists
> purely to make planning/QA easier. The script's own prompt code is the
> authoritative behavior — **this guide can drift out of sync and becomes
> stale if the script changes.**
> **Keep it in sync with every prompt change, or delete this file before
> final.** A reviewer should not treat it as a spec.
>
> A `[*]` marks a required choice with no default (the script reprompts
> until a valid value is entered). Otherwise, pressing **Enter** accepts
> the default where shown.

---

## 1. Startup

- **`[*]` Resume the interrupted install using saved answers? [y/N]**
  Only shown if a saved state file exists. `y` skips the entire interactive
  configuration and resumes the interrupted run using saved answers.

---

## 2. Account & hostname

- **Account privilege model `[*] [1/2/3]`**
  - `1` Hybrid — root has a password AND your user gets full sudo access
  - `2` Debian-style — root has a password; your user is NOT in sudo (su - only)
  - `3` Ubuntu-style — root is locked; your user gets full sudo access (your own password)
- **Login shell `[*] [1-4, default 1]`**
  - `1` bash (default; included in base-system)
  - `2` zsh
  - `3` fish
  - `4` mksh
- **`[*]` Enter the username to create on the target system**
- **Enter the full name of `<user>` (e.g., 'John Doe')** — optional, used for the account's display/GECOS name
- **`[*]` Enter target system hostname (e.g., myhostname)**
- **Enter network domain name (e.g., example.com) to form a FQDN (optional, press Enter to skip)**
- **`[*]` This system's FQDN will be: `<hostname>.<domain>` — is this correct? [Y/n]**
- **Root password** — hidden input, min 8 chars, must match confirmation
- **`<user>` password** — hidden input, min 8 chars, must match confirmation

---

## 3. Locale, timezone & mirror

- **Locale `[*] [1-12, default 1]`**
  - `1` en_US.UTF-8 (English / US) — default
  - `2` en_GB.UTF-8 (English / UK)
  - `3` de_DE.UTF-8 (German / Germany)
  - `4` es_ES.UTF-8 (Spanish / Spain)
  - `5` fr_FR.UTF-8 (French / France)
  - `6` it_IT.UTF-8 (Italian / Italy)
  - `7` pt_PT.UTF-8 (Portuguese / Portugal)
  - `8` nl_NL.UTF-8 (Dutch / Netherlands)
  - `9` ru_RU.UTF-8 (Russian)
  - `10` ja_JP.UTF-8 (Japanese)
  - `11` zh_CN.UTF-8 (Chinese / Simplified)
  - `12` Custom — type a POSIX locale, e.g. `pl_PL.UTF-8`
- **Timezone `[*] [1-15, default 1]`**
  - `1` America/New_York — default
  - `2` America/Chicago
  - `3` America/Denver
  - `4` America/Los_Angeles
  - `5` America/Sao_Paulo
  - `6` Europe/London
  - `7` Europe/Paris
  - `8` Europe/Berlin
  - `9` Europe/Madrid
  - `10` Europe/Rome
  - `11` Europe/Moscow
  - `12` Asia/Tokyo
  - `13` Asia/Shanghai
  - `14` Asia/Kolkata
  - `15` Custom — type an IANA zone, e.g. `Australia/Sydney`
- **Mirror `[*] [1-8, default 1]`**
  - `1` Auto (region-based)
  - `2` Global Fastly CDN — `https://repo-fastly.voidlinux.org/current`
  - `3` Global default (tier-1) — `https://repo-default.voidlinux.org/current`
  - `4` North America — `https://mirrors.summithq.com/voidlinux/current`
  - `5` Europe — `https://repo-de.voidlinux.org/current`
  - `6` Asia (China) — `https://mirrors.tuna.tsinghua.edu.cn/voidlinux/current`
  - `7` Oceania (Australia) — `https://mirror.aarnet.edu.au/pub/voidlinux/current`
  - `8` South/Central America (Brazil) — `https://void.voidbr.org/voidlinux/current`

---

## 4. Swap, bootloader & wallpaper

- **Swap backend `[*] [1-4, default 1]`**
  - `1` swapfile (default) — Btrfs swapfile at /var/swap, supports hibernation
  - `2` zram — compressed in-RAM swap, cannot hibernate
  - `3` swapfile + zram — both, for extra headroom
  - `4` none — no swap at all
- **Enable hibernation (suspend-to-disk)? [y/N]** — only if a disk swapfile is provisioned
- **Swapfile size `[*] [1-2, default 1]`** — only if no hibernation
  - `1` 4G (default)
  - `2` 2G
- **Bootloader [1/2] (default 1: Limine)** — `[*]` no longer marks this;
  bare Enter selects the default.
  - `1` Limine — newer, simpler, no efibootmgr/NVRAM dependency (4GiB EFI). **Default.**
  - `2` GRUB — mature, battle-tested snapshot boot via grub-btrfs. ESP size: 1GiB
    plain, **4GiB when full-disk encryption is then enabled** (next prompt) — in that
    combo the ESP is mounted at `/boot`, so grub.cfg + kernels live unencrypted on the
    ESP and GRUB never has to unlock LUKS (one dracut passphrase prompt after handoff).
- Only if `BOOTLOADER=limine`:
  - **`[*]` Enable Limine wallpaper? [y/N]** — asked right after the bootloader choice.
  - If `y`:
    - **Wallpaper browser** (copied onto the ESP) — a numbered `ls` menu of
      directories and BMP/PNG/JPEG/QOI images starting at `/run/media`
      (USB stick) if present, else `/root`. Enter `..` to go up, a number
      to pick an image, or type an absolute/relative path as an escape
      hatch.
    - **`[*]` Wallpaper style [1=stretched/2=tiled/3=centered] [1]**

---

## 5. Encryption, YubiKey & audio

- **`[*]` Enable full-disk encryption (LUKS2)? [y/N]** — asked after the bootloader
  (and Limine wallpaper) choice, so the GRUB/limine + encryption sizing is final.
- Only if `ENCRYPT=yes` (in this order):
  - **`[*]` Set up YubiKey hmac-sha1 unlock? [y/N]**
  - If `y`:
    - **Which OTP slot to program (1 or 2)? [1]**
    - **Require a physical touch on the YubiKey to unlock at boot? [Y/n]**
    - **Keep the typed-passphrase fallback (YubiKey OR passphrase)? [Y/n]**
  - The key must be plugged in; slot programming happens later.
  - **Passphrase + confirm** (hidden, in-memory only) is asked after the YubiKey
    menu and the bootloader/YK clamp, once the fallback is final — labeled
    accordingly: provisioning-only if possession-only (throwaway), boot fallback
    if kept, or plain every-boot passphrase with no YubiKey.
  - **`[*]` LUKS mapper name [void-root]** (last encryption prompt)
- **Allow audio (PipeWire) to autostart during read-only snapshot boots? [y/N]**

---

## 6. Desktop & display manager

- **`[*]` Desktop [1/7]`**
  - `1` KDE Plasma (default) — Wayland session, primary tested path
  - `2` Cinnamon (X11)
  - `3` GNOME — Wayland session, confirmed on Void
  - `4` Xfce (X11)
  - `5` MATE (X11)
  - `6` LXQt (X11)
  - `7` COSMIC (third-party repo)
- **Display manager `[*]` (default per DE)** — options depend on the chosen desktop
  - `1` SDDM — Qt-based (KDE/LXQt/COSMIC default)
  - `2` LightDM — GTK-family (Cinnamon/Xfce/MATE default)
  - `3` GDM — GNOME
  - `4` cosmic-greeter — COSMIC only (offered when COSMIC chosen; maintainer warns it's unreliable)
- Only if `DISPLAY_MANAGER=lightdm`:
  - **Greeter `[*] [1/2] (default 1: GTK)`**
    - `1` GTK
    - `2` Slick
    (WebKit2 greeter removed in Beta-v2.9.1 — abandoned upstream, black-
    screens against current webkit2gtk.)
- **Session/seat `[*] [1/2] (default 1: elogind)`**
  - `1` elogind
  - `2` turnstile

---

## 7. Apps & packages

- **`[*]` Install OctoXBPS (graphical package manager + update notifier)? [Y/n]**
- **`[*]` Install Flatpak (+ Flathub)? [Y/n]**
- **Install Thunderbird (email client)? [y/N]** → if `y`: package installed, `@thunderbird` per-user subvol provisioned
- **Install Steam (gaming client)? [y/N]** → if `y`: package installed (multilib), `@steam` per-user subvol provisioned
- **`[*]` Set up web browsers now? (choose each one next) [y/N]** → gate; if `no`, all
  browser install prompts are skipped (toggles forced off). If `yes`, the
  individual browser prompts run:
  - **`[*]` Install Firefox? [Y/n]**
  - **`[*]` Install Chromium? [Y/n]**
  - **Install Vivaldi (proprietary, nonfree repo)? [y/N]**
  - **Install Falkon (KDE's browser, works fine standalone too)? [y/N]**
  - **Install Brave? [y/N]**
- `@network` (`/var/lib/NetworkManager`) is always created — no prompt — and
  rolls back independently of `@`.
- **`[*]` Set up containers (Podman / Docker) now? (choose each backend next) [y/N]** →
  gate; defaults off. If `no`, the whole container section (all three backends,
  docker group-add, distrobox + track, container-manager) is skipped with all
  toggles forced off. If `yes`, the individual backends run:
  - **`[*]` Install Podman rootless? [y/N]** → if `y`: per-user `@containers-user`
    subvol offered via the master gates (`[PODMAN-ROOTLESS-SUBVOL]` Beta-v2.9.2)
  - **`[*]` Install Podman rootful capability? [y/N]**
  - **`[*]` Install Docker? [y/N]** → if `y`: "Add your user to the docker group ...? [y/N]"
- **`[*]` Also install distrobox? [y/N]** → if `y`:
  - **Distrobox release track `[*] [1/2/3]`**
    - `1` Stable — pinned 1.8.2.5 (legacy/bash)
    - `2` Current — always latest legacy-branch release
    - `3` Next — upstream v2 Go rewrite (built from source)
  - Only if both a Podman backend and Docker are installed: **Distrobox default engine `[*] [1/2]`**
    - `1` Podman (default)
    - `2` Docker
- **`[*]` Install virtualization (qemu/libvirt/virt-manager + br0 bridge)? [y/N]**
- **Master subvolume gates (`[SUBVOL-GATES]`, Beta-v2.9.0)** — asked once, after
  every install choice above is finalized:
  - **For software you ARE installing, give each its own isolated subvolume? [Y/n/i]**
    (`SUBVOL_ISOLATE_INSTALLED`; default `Y`). `i` → walks each installed app
    individually (each defaults to isolate `Y/n`).
  - **For software you did NOT install, pre-create an empty isolated subvolume for
    later manual use? [y/N/i]** (`SUBVOL_PRECREATE`; default `N`). `i` → walks
    each not-installed app individually (each defaults to pre-create `y/N`).
  - A table-driven resolver folds each app's install choice + the two gates into a
    single `PROVISION_*_SUBVOL` ("isolate?") flag that drives all subvolume
    create/mount/fstab/per-user-provision/teardown sites. Affected apps: browsers
    (Firefox/Chromium/Vivaldi/Falkon/Brave), Thunderbird, Steam, VirtualBox,
    Flatpak, Docker, Podman-rootful (`@containers`), Podman-rootless
    (`@containers-user`, `[PODMAN-ROOTLESS-SUBVOL]` Beta-v2.9.2),
    Virtualization (`@libvirt`). OctoXBPS is excluded — it has no data subvolume.
  - **NOTE (Beta-v2.9.2):** Podman rootless's per-user `~/.local/share/containers`
    is now a gate participant (default isolate for an install). Declining it
    leaves a plain, correctly-owned datadir in `@home`; the mandatory
    subuid/subgid + containers.conf setup still always runs so rootless podman
    keeps working either way.
- **`[*]` Press Enter once ready to continue** — br0 USB-Ethernet-port warning

---

## 8. Destructive confirmation

- **`[*]` Select disk to partition and install to [1-N]**
- Existing Void on target: **`[*]` Type 'ERASE <device>' (with the exact device path) to confirm, or anything else to abort**
- Fresh/normal disk: **`[*]` Confirm wiping <disk>: type 'ERASE!' (or anything else to abort)**

---

## 9. Final review

- **`[*]` Proceed with these settings? [Enter=continue, R=restart config]**
  A full summary of every choice is printed above. **Enter** proceeds to
  the destructive partitioning; **R** re-runs the entire configuration
  from the top (no disk has been touched yet).

---

## 10. YubiKey enrollment (later, only if `YK_MODE=hmac-sha1`)

- **`[*]` Program slot <N> now — confirm the key is plugged in? [y/N]**
  Happens after the live-CD sync, once `ykpers` is available.