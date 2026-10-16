# Installer Interactive Prompts — Reference Guide

> **BEST-EFFORT CONVENIENCE GUIDE — NOT SOURCE OF TRUTH.**
> This document is a human-readable snapshot of the interactive prompts in
> `Void_Linux_Installer.sh` (current version: **Beta-v2.9.95**). It exists
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

- **Resume the interrupted install using saved answers? [y/N]**
  Only shown if a saved state file exists. `y` skips the entire interactive
  configuration and resumes the interrupted run using saved answers.

---

## 2. Account & hostname

- **Account privilege model `[*] [1/2/3]`**
  - `1` Hybrid — root has a password AND your user gets full sudo access
  - `2` Debian-style — root has a password; your user is NOT in sudo (su - only)
  - `3` Ubuntu-style — root is locked; your user gets full sudo access (your own password)
- **Login shell [1-4, default 1]**
  - `1` bash (default; included in base-system)
  - `2` zsh
  - `3` fish
  - `4` mksh
- **`[*]` Enter the username to create on the target system**
- **Enter the full name of `<user>` (e.g., 'John Doe')** — optional, used for the account's display/GECOS name
- **`[*]` Enter target system hostname (e.g., myhostname)**
- **Enter network domain name (e.g., example.com) to form a FQDN (optional, press Enter to skip)**
- **This system's FQDN will be: `<hostname>.<domain>` — is this correct? [Y/n]**
- **Root password** — hidden input, min 8 chars, must match confirmation
- **`<user>` password** — hidden input, min 8 chars, must match confirmation

---

## 3. Locale, timezone & mirror

- **Locale [1-12, default 1]**
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
- **Timezone [1-15, default 1]**
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
- **Mirror [1-8, default 1]**
  - `1` Auto (region-based)
  - `2` Global Fastly CDN — `https://repo-fastly.voidlinux.org/current`
  - `3` Global default (tier-1) — `https://repo-default.voidlinux.org/current`
  - `4` North America — `https://mirrors.summithq.com/voidlinux/current`
  - `5` Europe — `https://repo-de.voidlinux.org/current`
  - `6` Asia (China) — `https://mirrors.tuna.tsinghua.edu.cn/voidlinux/current`
  - `7` Oceania (Australia) — `https://mirror.aarnet.edu.au/pub/voidlinux/current`
  - `8` South/Central America (Brazil) — `https://void.voidbr.org/voidlinux/current`
- **Use a local package cache? `[y/N or absolute path]`** — reuse already-downloaded XBPS
  packages instead of re-fetching from the mirror (Beta-v2.9.59 `[LOCAL-CACHE]`).
  - `y`/`yes` → use the auto-detected cache at
    `<mount>/xbps-cachedir-<arch>` under `/run/media` (newest-touched writable dir with real
    `.xbps` files wins).
  - A typed absolute path → same, for a cache that auto-detect misses.
  - `n`/Enter (default) → network-only baseline.
  - The cache dir must be writable (`-Sy` repodata writes into it). A read-only/unusable dir
    **degrades to network-only** — never aborts the install. Mirrors stay the per-package
    fallback. Also honored on `-r` resume (path re-validated/re-detected).

---

## 4. Swap, bootloader, kernel & device profile

- **Swap backend [1-4, default 1]**
  - `1` swapfile (default) — Btrfs swapfile at /var/swap, supports hibernation
  - `2` zram — compressed in-RAM swap, cannot hibernate
  - `3` swapfile + zram — both, for extra headroom
  - `4` none — no swap at all
- **Enable hibernation (suspend-to-disk)? [y/N]** — only if a disk swapfile is provisioned
- **Swapfile size [1-2, default 1]** — only if no hibernation
  - `1` 4G (default)
  - `2` 2G
- **Bootloader [1/2] (default 1: Limine)**
  - `1` Limine — newer, simpler, no efibootmgr/NVRAM dependency (4GiB EFI). **Default.**
  - `2` GRUB — mature, battle-tested snapshot boot via grub-btrfs. ESP size: 1GiB
    plain, **4GiB when full-disk encryption is then enabled** (next sections) — in that
    combo the ESP is mounted at `/boot`, so grub.cfg + kernels live unencrypted on the
    ESP and GRUB never has to unlock LUKS (one dracut passphrase prompt after handoff).
- **EFI/ESP partition size [1-4/Custom, default 4 GiB]** — called once the bootloader
  path needs a real ESP: right after the bootloader choice for Limine, and right after
  the full-disk-encryption choice for GRUB+ENCRYPT (plain GRUB keeps its fixed 1G).
  - `1` 4 GiB (default) — ArchWiki's recommendation for bootable snapshots
  - `2` 6 GiB — headroom for many kernel flavors + snapshots
  - `3` 8 GiB — generous; large initramfses + many snapshots
  - `4` Custom — **Custom ESP size (e.g. 512M, 3G, 10GiB)**; uppercased, validated with a
    1 GiB floor, normalized to gdisk K/M/G (malformed entries are rejected and the
    menu loops).
- **Kernel packages** — the base rolling `linux` is always installed (base-system
  depends on it); these are the two extra flavors:
  - **Also install linux-mainline? [y/N]** — newest features, shortest support window
  - **Also install linux-lts? [Y/n]** — Long Term Support, most conservative; default yes
- **Device profile [1/2/3/4/5, default 1: Automatic]** — what kind of machine this is;
  gates tlp (battery power management), the Bluetooth stack, and preload (adaptive
  readahead). Options `2`-`5` are chosen directly:
  - `1` Automatic (default) — probe chassis + Bluetooth hardware, then confirm/override
  - `2` Laptop with Bluetooth
  - `3` Laptop, no Bluetooth
  - `4` Desktop/server with Bluetooth
  - `5` Desktop/server, no Bluetooth
  - Only when Automatic is chosen: **Keep this profile? [Y/n] or pick 2-5 to override**
    — prints the detected profile + description, then accepts `y`/Enter, `n` (forces an
    explicit pick), or a direct 2-5 override.
- Only if `BOOTLOADER=limine`:
  - **Enable Limine wallpaper? [y/N]** — asked right after the bootloader choice.
  - If `y`:
    - **Wallpaper browser** (copied onto the ESP) — a numbered `ls` menu of
      directories and BMP/PNG/JPEG/QOI images starting at `/run/media`
      (USB stick) if present, else `/root`. Enter `..` to go up, a number
      to pick an image, or type an absolute/relative path as an escape
      hatch.
    - **Wallpaper style [1=stretched/2=tiled/3=centered] [1]**

---

## 5. Encryption, YubiKey & audio

- **Enable full-disk encryption (LUKS2)? [y/N]** — asked after the bootloader
  (and Limine wallpaper) choice, so the GRUB/limine + encryption sizing is final.
- Only if `ENCRYPT=yes` (in this order):
  - **Set up YubiKey hmac-sha1 unlock? [y/N]**
  - If `y`:
    - **Which OTP slot to program (1 or 2)? [1]**
    - **Require a physical touch on the YubiKey to unlock at boot? [Y/n]**
    - **Keep the typed-passphrase fallback (YubiKey OR passphrase)? [Y/n]**
  - The key must be plugged in; slot programming happens later.
  - **Passphrase + confirm** (hidden, in-memory only) is asked after the YubiKey
    menu and the bootloader/YK clamp, once the fallback is final — labeled
    accordingly: provisioning-only if possession-only (throwaway), boot fallback
    if kept, or plain every-boot passphrase with no YubiKey.
  - **LUKS mapper name [void-root]** (last encryption prompt)
- **Allow audio (PipeWire) to autostart during read-only snapshot boots? [y/N]**
- **Hardware probes (advisory; only when the hardware is detected):**
  - **Install the NVIDIA proprietary driver? [`y`/`n`, default from config]** — only
    when an NVIDIA GPU is present; the prompt suffix shows the effective default.
  - **Keep this interface? [Y/n] or type another name** — only when a wired NIC was
    detected; `n` clears it, typing replaces it (feeds the bridged-VM NIC).
  - **Install linux-firmware-broadcom (firmware for the detected Broadcom radio)?**
    — only when a Broadcom (ID `0x14e4`) device is present; prompt suffix shows the
    effective default.

---

## 6. Desktop & display manager

- **Desktop [1-8, default 1]** — bare Enter selects option 1.
  - `1` KDE Plasma (default) — Wayland session, primary tested path
  - `2` Cinnamon (X11)
  - `3` GNOME — Wayland session, confirmed on Void
  - `4` Xfce (X11)
  - `5` MATE (X11)
  - `6` LXQt (X11)
  - `7` COSMIC (third-party repo)
  - `8` none — console login only; headless/server base. Pairs with the DM `none`
    option below; the Xorg/Wayland base and the audio stack become explicit opt-ins.
- **Display manager (default per DE)** — options depend on the chosen desktop.
  - `1` SDDM — Qt-based (KDE/LXQt default)
  - `2` LightDM — GTK-family (Cinnamon/Xfce/MATE default)
  - `3` GDM — GNOME
  - `4` cosmic-greeter — COSMIC only (COSMIC default since Beta-v2.9.91)
  - `5` none — no display manager; boot straight to a console login. **Only on the
    COSMIC branch does the menu run 1-5; every other DE runs 1-4** (`none` is index 5
    there, giving `4` its own slot — see Beta-v2.9.48 `[NO-DM]`).
- Only if `DISPLAY_MANAGER=lightdm`:
  - **Greeter [1/2] (default 1: GTK)**
    - `1` GTK
    - `2` Slick
    (WebKit2 greeter removed in Beta-v2.9.1 — abandoned upstream, black-
    screens against current webkit2gtk.)
- Only if `DESKTOP_ENV=none` and `DISPLAY_MANAGER=none` (headless server):
  - **Keep the Xorg/Wayland base for a later startx / remote-X? [y/N]**
  - **Install the audio stack (PipeWire + ALSA) on this server? [y/N]**
  (Graphical installs get these unconditionally and never see the prompts.)
- **Session/seat [1/2] (default 1: elogind)**
  - `1` elogind
  - `2` turnstile

---

## 7. Apps & packages

- **Install OctoXBPS (graphical package manager + update notifier)? [y/N]**
- **Install Flatpak (+ Flathub)? [y/N]**
- **Install Homebrew (Linuxbrew CLI/dev channel, opt-in; ~/.linuxbrew)? [y/N]** —
  independent of Flatpak; either, both, or neither.
- **Install cosmic-store (COSMIC app store; Flatpak-only)? [y/N]** → only offered
  when Flatpak was accepted (`INSTALL_FLATPAK=true`), on any desktop — the store
  hard run-depends on `flatpak`, and the Stage-2 install re-checks the flag
  (a stale resume state can't drag flatpak in past an opt-out). Default NO.
  (Beta-v2.9.84 `[COSMIC-STORE]`.)
- **Configure COSMIC touchpad right-click (two-finger tap + corner-click)? [y/N]**
  → only offered on COSMIC builds, default OFF (Beta-v2.9.92
  `[COSMIC-TOUCHPAD-RCLICK]`). cosmic-settings ships `click_method:Some(Clickfinger)`
  which yields no usable right-click on real hardware; if `y`, a per-user
  override with `click_method:Some(ButtonAreas)` (bottom-corner right-click,
  two-finger-tap preserved) is written to
  `~/.config/cosmic/com.system76.CosmicComp/v1/input_touchpad`, derived from
  the in-tree shipped default (only the `click_method` token changes). The
  greeter's own touchpad is not touched.
- **Install Thunderbird (email client)? [y/N]** → if `y`: package installed, `@thunderbird` per-user subvol provisioned
- **Game launchers & runtimes** — each independent, all default OFF; a launcher never
  auto-pulls Wine (each launcher self-manages its own Wine):
  - **Install Lutris (game library/installer for Wine + native games)? [y/N]** — xbps
  - **Install Heroic (Epic/GOG launcher; Flatpak)? [y/N]** — only offered when Flatpak is on
  - **Install Bottles (per-game Wine prefix manager; Flatpak)? [y/N]** — only offered when Flatpak is on
  - **Install Wine (system, multilib)? [y/N]** — runtime toggle, independent of launchers
  - **Install gamemode (+ libgamemode-32bit)? [y/N]**
- **Install Steam (gaming client)? [y/N]** → if `y`: package installed (multilib), `@steam` per-user subvol provisioned
- **Install VirtualBox (full virtualizer, QEMU/KVM alternative)? [y/N]** → if `y`:
  `@virtualbox` per-user subvol provisioned (a virtualization/libvirt alternative, not a replacement)
- **Set up web browsers now? (choose each one next) [y/N]** → gate; if `no`, all
  browser install prompts are skipped (toggles forced off). If `yes`, the
  individual browser prompts run:
  - **Install Firefox? [Y/n]**
  - **Install Chromium? [Y/n]**
  - **Install Vivaldi (proprietary, nonfree repo)? [y/N]**
  - **Install Falkon (KDE's browser, works fine standalone too)? [y/N]**
  - **Install Brave? [y/N]**
- `@network` (`/var/lib/NetworkManager`) is always created — no prompt — and
  rolls back independently of `@`.
- **Set up containers (Podman / Docker) now? (choose each backend next) [y/N]** →
  gate; defaults off. If `no`, the whole container section (all three backends,
  docker group-add, distrobox + track, container-manager) is skipped with all
  toggles forced off. If `yes`, the individual backends run:
  - **Install Podman rootless? [y/N]** → if `y`: per-user `@containers-user`
    subvol offered via the master gates (`[PODMAN-ROOTLESS-SUBVOL]` Beta-v2.9.2)
  - **Install Podman rootful capability? [y/N]**
  - **Install Docker? [y/N]** → if `y`: **Add your user to the docker group (root-equivalent
    access, run docker without sudo)? [y/N]**
- **Also install distrobox? [y/N]** → if `y`:
  - **Distrobox release track [1/2/3, default 1]**
    - `1` Stable — pinned 1.8.2.5 (legacy/bash)
    - `2` Current — always latest legacy-branch release
    - `3` Next — upstream v2 Go rewrite (built from source)
  - Only if both a Podman backend and Docker are installed: **Distrobox default engine [1/2, default 1]**
    - `1` Podman (default)
    - `2` Docker
- **Install virtualization (qemu/libvirt/virt-manager + br0 bridge)? [y/N]**
- **Install and enable the OpenSSH server (sshd)? [y/N]** (`[SSH-SERVER]`,
  Beta-v2.9.23) — default OFF (no network-facing daemons by default). If `y`,
  the following are asked:
  - **OpenSSH server port (default 22)** — must be an integer 1-65535, reprompts
    until valid
  - **Allow password authentication over SSH? [y/N]** — default `n`
  - **Allow root to log in over SSH (public-key only)? [y/N]** — default `n`
    (a `y` answer sets `PermitRootLogin prohibit-password`, i.e. public-key-only
    root login); `n` → `no`
- **SSH keys** (`[SSH-KEYS]`, Beta-v2.9.23) — three independently-toggleable
  steps, each default `n`:
  - **Import an existing SSH private key from removable media? [y/N]** → if `y`,
    browse for the PRIVATE key file (a `.pub` file is rejected with a notice).
    The import is verified with `ssh-keygen -y` before it is trusted
    (`[SSH-IMPORT-VALIDATE]` Beta-v2.9.88): an unencrypted key has its `.pub`
    derived from the private key itself; a passphrase-protected key is unlocked
    with a one-shot hidden passphrase (in-memory only, never stored) and
    verified with it; anything `ssh-keygen` cannot read is rejected, and the
    fingerprint is printed for comparison. On the target, the deposited key is
    wired to be usable (`[SSH-USABLE]` Beta-v2.9.88): `~/.ssh/config` gains the
    `IdentityFile` (append-only) and the imported public key is added to
    `~/.ssh/authorized_keys`.
  - **Generate a fresh ed25519 SSH keypair? [y/N]** → if `y`:
    - **SSH key comment** (default `<user>@<hostname>`) — Enter to keep
    - **Protect the key with a passphrase? [Y/n]** — if `y`, passphrase entered
      twice hidden, must be non-empty and match
  - **Export a backup copy of the SSH keypair to removable media? [y/N]** → if
    `y` and a key exists (imported or generated), browse for a destination
    directory and writes `id_ed25519-backup{, .pub}` (0600). Declining
    import+generate means there is no key to export.
  - No key material is ever persisted to install-config / limine-env / resume
    state / chroot_env — only public facts (flattening `Beta-v2.9.54
    [SSH-KEYGEN-STALE]`: keygen always clears any stale stage key first so the
    prompt stream stays aligned).
- **Master subvolume gates (`[SUBVOL-GATES]`, Beta-v2.9.0)** — asked once, after
  every install choice above is finalized:
  - **For software you ARE installing, give each its own isolated subvolume? [Y/n/i]**
    (`SUBVOL_ISOLATE_INSTALLED`; default `Y`). `i` → walks each installed app
    individually (each defaults to isolate `Y/n`). Answers are validated
    (`[SUBVOL-GATE-VALIDATE]` Beta-v2.9.88): anything other than Enter / `y` /
    `n` / `i` is re-prompted — never silently bulk-defaulted.
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

## 8. Data regions (filesystem layout)

Only reached after the encryption/YubiKey pass. The root filesystem is ALWAYS
Btrfs; these choices only slice DATA regions. Each `[b/e]` prompt accepts
`b`/`btrfs` or `e`/`ext4`; **bare Enter on every line = all-Btrfs default**
(no extra partitions, no size prompts).

- **`/home` region — btrfs (subvol) or ext4 (own partition)? [b/e]** — default `btrfs`
- **`/var` region — btrfs (subvols) or ext4 (own partition)? [b/e]**
- **`/var/cache` region — btrfs (subvol @cache) or ext4 (own partition)? [b/e]**
- **`/srv` region — btrfs (subvol @srv) or ext4 (own partition)? [b/e]**
- **`/opt` region — btrfs (subvol @opt) or ext4 (own partition)? [b/e]**
- **`~/<user>/Games` — none, ext4 partition, or btrfs partition? [n/e/b]** — default `none`
- For each region chosen `ext4`, a size prompt follows (in the fixed carve order),
  defaulting to the region's `DEFAULT_REGION_*_SIZE`:
  - **`/home` partition size [`<default>`]**
  - **`/var` partition size [`<default>`]**
  - **`/var/cache` partition size [`<default>`]**
  - **`/srv` partition size [`<default>`]**
  - **`/opt` partition size [`<default>`]**
  - **Games partition size [`<default>`]**
  The Btrfs root always gets the remainder, so it never asks for a size.

---

## 9. Destructive confirmation

- **`[*]` Select disk to partition and install to [1-N]**
- Existing Void on target: **`[*]` Type 'ERASE <device>' (with the exact device path) to confirm, or anything else to abort**
- Fresh/normal disk: **`[*]` Confirm wiping <disk>: type 'ERASE!' (or anything else to abort)**

---

## 10. Final review

- **Proceed with these settings? [Enter=continue, R=restart config]**
  A full summary of every choice is printed above. **Enter** proceeds to
  the destructive partitioning; **R** re-runs the entire configuration
  from the top (no disk has been touched yet).

---

## 11. YubiKey enrollment (later, only if `YK_MODE=hmac-sha1`)

- **Program slot <N> now — confirm the key is plugged in? [y/N]**
  Happens after the live-CD sync, once `ykpers` is available.