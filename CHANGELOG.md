# Changelog — Void Linux Unified Installer

> **Reconstruction note:** The original companion CHANGELOG for this
> project was lost. This file is a reconstruction, generated directly from
> the inline `AI (...)` feature markers embedded in `Void_Linux_Installer.sh`
> (which self-documents its history through `[TAG]` markers in comments) and
> incorporating the most recent work in this session. Inline documentation
> of changes began at **v3.1.0-beta1** and is authoritative from there onward.
> The **pre-3.1.0 history** (from the first Alpha concept to the 3.0.x "GC"
> era) was **recovered from the actual build artifacts archived under
> `Debug/Old Versions/`** and is presented below as a **continuous,
> version-numbered history from Alpha 1 through the current version** — real
> archived releases are documented as-is; gaps between them are `[reconstructed]`
> extrapolations (marked inline) assigned version numbers for narrative
> continuity, per the project's own recovery-and-self-documentation ethos.
> Section references (such as §3.19, §4.7, Open Items, etc.) that survive in
> the script's comments point at the original (now-lost) CHANGELOG and are
> preserved verbatim as historical cross-references.

Current version: **Beta-v2.9.98** (`SCRIPT_VERSION` in the script).

> **Numbering scheme (`[VERSION-CARRY]`).** The lineage is split into named
> eras, each carrying its own prefix:
> - **Alpha era** (`Alpha-v1.0.x`): the manual step scripts recovered from
>   `Debug/Old Versions/` (`Alpha Script1-3` through `Script4-4` /
>   `boot.efi Script1-4..4-4`). Reconstructed; four releases.
> - **Beta era** (`Beta-v1.x.x` → `Beta-v2.x.x`): the unified single-file
>   installer lineage. The pre-tracking artifacts (2.1–2.9.5C through
>   3.0.112GC) and the tracked `v3.1.0-beta1` … `v3.3.0-beta33` releases
>   are mapped into a continuous sequential Beta-v numbering per
>   `Debug/version-renumber-map.txt`. Every release within the Beta era
> gets a unique number, and the current release (`Beta-v2.9.13`) is always
>   the highest — preserving the monotonicity invariant.
> - The old `v3.x` labels are preserved inline (`was v3.x` in headings and
>   `version-renumber-map.txt`) for `[TAG]`-marker traceability, but the
>   `SCRIPT_VERSION` and all "current version" indicators carry the
>   `Alpha-v`/`Beta-v` form exclusively.

---

## Version index (Alpha 1 → current)

A quick map of the whole lineage; see the linked sections for detail.
Marked **`[reconstructed]`** where no surviving artifact anchors the release
(the version numbers there are assigned by this reconstruction).

| Version era | Summary | Section |
|---|---|---|
| **Alpha-v1.0.1** — Alpha 1 | Recovery-first foundation (swapfile hibernation, Snapper, dracut overlay, runit) | Pre-BP |
| **Alpha-v1.0.2** — Alpha 2 | Desktop + recovery maturity (GRUB, KDE Plasma, PipeWire, NM br0) | Pre-BP |
| **Alpha-v1.0.3** — Alpha 3 | Breadth (virt, optional-software menu, browser subvols, `[item N]`) | Pre-BP |
| **Alpha-v1.0.4** — Alpha 4 | Manual multi-script era (`Alpha`/`boot.efi ScriptN-N`) | Pre-BP |
| **Beta-v1.0.0–v1.9.5** | Unified single-file "Test it Out" drafts (2.1–2.9.5C, nftables) | Pre-BP |
| **Beta-v1.9.6–v1.9.9** | Formally versioned 2.9.x lineage | Pre-BP |
| **Beta-v2.0.1–v2.0.9** | GRUB-only 3.0.x "GC" line | Pre-BP |
| **Beta-v2.1.0–v2.2.8** | Feature-rich capstone carpet (snapshot-overlay, dynamic toggles) — renumbered from `3.0.9…3.0.112` | Pre-BP |
| **Beta-v2.3.0** | First tracked release — inline-marker era begins | Tracked |
| **Beta-v2.4.0** | DESKTOP_ENV, LOCALIZE, SWAP, COSMIC | Tracked |
| **Beta-v2.4.1** | MIRROR, LIMINE-WALLPAPER, DRY-RUN (Claude's last) | Tracked |
| **Beta-v2.5.0–v2.9.2** | Big Pickle era — features, hardening, encryption, YubiKey, dynamic subvols, master subvol gates, WebKit2 greeter removal, rootless-podman subvol parity | Beta-v2.5.0–v2.9.2 below |
| **Beta-v2.9.3** | `[SUBVOL-INSTALL]` — void-subvol-tool `--install` flag, OctoXBPS/Flatpak default off, `[LIGHTDM-GREETER-BG]`, `[XFC-AUTOMOUNT]` | Beta-v2.9.3 below |
| **Beta-v2.9.4** | `[SNAPPER-PRESENT]` — snapper-binary guard + unguarded `rmdir /.snapshots` abort fix; real-hardware install failure (network drop left snapper absent) | Beta-v2.9.4 below |
| **Beta-v2.9.5** | `[GREETER-BG-PIPEFAIL]` — lightdm/cinnamon wallpaper `find | head` command substitutions get `|| true`; pipefail aborted a MATE+lightdm install silently when `/usr/share/backgrounds` didn't exist yet | Beta-v2.9.5 below |
| **Beta-v2.9.6** | `[LUKS-UNLOCK-LEFT-OPEN]` — failure unwind now `luksClose`s the LUKS mapper (returns disk to LOCKED), resume reuses an already-open mapper instead of failing, and fresh-start closes a leftover mapper before reformat; fixes a `-r` resume that aborted at "decrypt partition" after a crashed run | Beta-v2.9.6 below |
| **Beta-v2.9.7** | `[BROWSER-GATE-NO]` — the "Set up web browsers now?" gate now defaults to **No** (`[y/N]`); a bare-Enter run skips the whole browser section (Firefox/Chromium still default ON *inside* the gate if you say yes) | Beta-v2.9.7 below |
| **Beta-v2.9.8** | `[GREETER-BG-TIMING]` — the lightdm greeter-background search ran before any desktop package existed, so every fresh MATE/Cinnamon/xfce+lightdm greeter booted to black; it now runs after the desktop install (with a gnome-backgrounds retry so it's never a bare black screen) | Beta-v2.9.8 below |
| **Beta-v2.9.9** | `[MATE-TERMINAL]`/`[MATE-AUDIO]`/`[XFC-VOLUME]`/`[LXQT-EDITOR]` — DE metapackage gap fixes: verified against Void's metapackage templates, `mate` bundles no terminal/editor/volume applet (→ `mate-terminal`+`pluma`+`mate-media`), `xfce4` no volume applet (→ `xfce4-pulseaudio-plugin`), `lxqt` no text editor (→ `FeatherPad`) | Beta-v2.9.9 below |
| **Beta-v2.9.10** | `[COSMIC-GREETER-DM]`/`[COSMIC-POLKIT]` — cosmic-greeter is provisioned as a greetd-hosted DM (it is a greetd frontend that runs inside `cosmic-comp`, not a standalone DM — a Beta-v2.9.9 COSMIC install that chose it booted to a bare terminal with no login screen); COSMIC desktop gets a `polkit-gnome` privilege agent with a baked autostart entry (the metapackage pulls none) | Beta-v2.9.10 below |
| **Beta-v2.9.11** | `[COSMIC-GREETER-LOG]` — svlogd `log/run` under both cosmic-greeter services (the log dirs existed but had no run script, so runsv spammed and no greeter output survived a reboot, hiding the live grey-screen evidence) | Beta-v2.9.11 below |
| **Beta-v2.9.12** | `[COSMIC-GREETER-USER]` — the greeter account is now EXACTLY `cosmic-greeter` (never `_cosmicgreeter`): the binary dispatches greeter-DM vs silent-locker from the current username, and the template's `_cosmicgreeter` account shipped the bug that produced the dead grey screen (live-verified with WAYLAND_DEBUG; fix upside down: `usermod -l`) | Beta-v2.9.12 below |
| **Beta-v2.9.13** | `[ACCTSVCS-ICON]` — the fresh user gets a real default avatar at `/var/lib/AccountsService/icons/<user>` (themed Adwaita `avatar-default`, Pop fallback, copied right after useradd), silencing greeter per-boot `failed to open icon ... NotFound`; `[COSMIC-POLKIT-GUARD]` — the COSMIC polkit agent's baked autostart now launches a session-ready guard (`/usr/local/sbin/cosmic-polkit-guard`) that waits for the compositor wl socket + reachable session bus then runs/respawns the agent, fixing the live `<host>` `<defunct>` zombie where the agent died before cosmic-comp/session-bus were up and no polkit dialog ever appeared | Beta-v2.9.13 below |
| **Beta-v2.9.14** | `[COSMIC-GREETER-SESSION-BUS]` — the cosmic-greeter greetd toml now execs the shipped `/etc/greetd/cosmic-greeter.start` wrapper (`dbus-run-session` around `cosmic-comp cosmic-greeter`, v5 as-built on `<host>`) instead of the bare binary string, and pre-creates a greeter-owned `/var/log/cosmic-greeter-session.log`: with the account fixed, a bare greetd spawn still rendered grey + cursor (no session bus → iced login panel never maps as a layer) | Beta-v2.9.14 below |
| **Beta-v2.9.15** | `[COSMIC-GREETER-DBUS-POLICY]` — re-emit `/etc/dbus-1/system.d/com.system76.CosmicGreeter.conf` granting the renamed `cosmic-greeter` group system-bus send/receive on `com.system76.CosmicGreeter`: the packaged file still grants the pre-rename `_cosmicgreeter` group, so after `[COSMIC-GREETER-USER]` the greeter's `GetUserData` to the (root) daemon was `AccessDenied` every start on a fresh install (live: `<host>` fresh Beta-v2.9.14 boot logged "failed to load user data from daemon: AccessDenied … GetUserData" + "Failed to apply user display config") — login unaffected, per-user display config/avatar lookups silently fail | Beta-v2.9.15 below |
| **Beta-v2.9.16** | `[KERNEL-SELECT]` — which kernels get installed is a real choice: Void base-system always pulls the main `linux` kernel, and a per-flavor toggle pair adds `linux-mainline` (newest, "experts only", opt-in) and/or `linux-lts` (default ON — bare Enter ships `linux` + `linux-lts`) on top. The resolved space-joined `$KERNEL_PKGS` threads through the base bootstrap, the post-install `xbps-reconfigure`, resume state, chroot_env, and install-config; orthogonal to `$KERNEL_MODE` (which only describes how Limine *reads* kernels from the ESP) | Beta-v2.9.16 below |
| **Beta-v2.9.17** | `[DEVICE-PROFILE]` — laptop vs desktop/server is now a real 5-way choice (Automatic/SMBIOS detection + four explicit profiles), resolved at pick time into a concrete `DEVICE_PROFILE` (`laptop-bt`/`laptop`/`desktop-bt`/`desktop`) plus derived `PROFILE_TLP`/`PROFILE_BT`/`PROFILE_PRELOAD` booleans. These gate the formerly unconditional `tlp`/`tlp-rdw`, `bluez`/`libspa-bluetooth`, and `preload` installs plus the `bluetoothd`/`tlp`/`preload` service links. preload (adaptive readahead) is desktop/server-only: its periodic pre-cache scans cost battery wakeups, so laptop profiles never get it. Bare-Enter = Automatic; an unresolvable chassis (VMs/unknown) falls back to the laptop+bluetooth baseline (historical package set, but tlp service now actually linked — an oversight fix) | Beta-v2.9.17 below |
| **Beta-v2.9.18** | `[MATE-METAPACKAGE-REGRESSION]` — restore the `mate` metapackage to the MATE desktop install: Beta-v2.9.9's `[MATE-TERMINAL]` change accidentally replaced `install_pkgs mate network-manager-applet` (dropping `mate`), so a MATE fresh install had no mate-session/panel and no `/usr/share/xsessions/mate.desktop` — with `user-session=mate` set, every login bounced straight back to the greeter (the "cannot login at the greeter" showstopper). Plus `[LIMINE-WALLPAPER-STAGE2]` — re-stage the Limine wallpaper into the target's `/tmp` after the `@` root mount, so the chroot ESP copy finds the image (a prompt-phase stage to `/mnt/tmp` was covered by the mount and never reached the ESP) | Beta-v2.9.18 below |
| **Beta-v2.9.19** | `[NFT-VIRT-GATE]` — the `/etc/nftables.conf` forward chain no longer hardcodes the `br0`/`virbr*` accepts unconditionally; those rules are a fragment emitted only when `$INSTALL_VIRT=true` (mirroring the existing gates on the virt package install, the user `kvm`/`libvirt` groups, the `br0` NM bridge, and the first-boot libvirtd teardown). On a non-virt build the forward rules no longer reference non-existent interfaces. Plus `[GREETER-BG-DEPTH]` — the lightdm greeter background's generic fallback `find` deepened to `-maxdepth 5` so it sees mate-backgrounds' depth-3 images, fixing the MATE + Slick black greeter. Plus `[DEVICE-PROFILE-CONFIRM]` — the Automatic device-profile option now shows the SMBIOS-detected profile and lets the user confirm or override it before continuing. Plus `[DEVICE-PROFILE-RCL]` — live-confirmed bug fix: the first-boot rc.local's tlp/bluetoothd/preload links used chroot-phase `$PROFILE_*` vars (never exported/persisted → always empty at boot), so those services never linked; converted to `__PROFILE_*__` placeholders added to the sed substitution pass. Plus `[LIMINE-WP-REGUARD]` — live-confirmed bug fix: the `[LIMINE-WALLPAPER-STAGE2]` re-stage guarded on the covered `/mnt/tmp` staged path so it never fired and the wallpaper never reached the ESP; re-guarded on the still-reachable live `WP_SRC` instead | Beta-v2.9.19 below |
| **Beta-v2.9.20** | `[LIMINE-WP-DRIVES]` — the Limine wallpaper picker can no longer strand the user inside a single USB drive's tree: `/run/media` is keyed by per-user subdirs (`/run/media/<user>/<label>`), so entering a drive left `..` only climbing to the per-user parent (whose siblings are just that one user's mounts) with no shortcut back to the "all mounted drives" view. The keywords `m`/`drives` now jump straight back to `/run/media`, and the browse hint names them and notes that `..` from the per-user dir reaches the drive list | Beta-v2.9.20 below |
| **Beta-v2.9.21** | `[GREETER-BG-EXPORT]` — the MATE/Slick black greeter's REAL root cause: the lightdm greeter-background block runs inside the single-quoted chroot heredoc, so its `case "$LIGHTDM_GREETER"` (gtk/slick) resolved an **empty** variable in-chroot and NEITHER greeter conf file was ever written. Only `_PKG`/`_SESSION` were exported to chroot_env.sh, never the bare choice. The earlier `-maxdepth 5` find fix (`[GREETER-BG-DEPTH]`) was necessary but not sufficient — it only supplied the image path; the missing export is what silently skips the `cat >` write. Live-confirmed on `<host>` (slick-greeter.conf stayed the pristine package default while lightdm.conf was written, and the block's gnome-backgrounds retry had fired). Fix: `export LIGHTDM_GREETER` added to chroot_env.sh | Beta-v2.9.21 below |
| **Beta-v2.9.22** | `[FALKON-QT-NOTICE]` — closes the Falkon gating discussion item. On a non-KDE desktop (`DESKTOP_ENV != kde`), the Falkon prompt now prints an inline NOTICE before the y/N: full "pulls in the Qt + QtWebEngine stack (no KDE desktop)" wording on GTK desktops, and a shorter "shares Qt5 but adds QtWebEngine" variant on LXQt. A warn-not-gate notice matching the existing Vivaldi/Brave notices, since Falkon remains a legitimate standalone browser on any DE; the heavy cost is QtWebEngine, not a full KDE desktop, and LXQt already shares the Qt5 base | Beta-v2.9.22 below |
| **Beta-v2.9.23** | `[SSH-SERVER]`+`[SSH-KEYS]` — closes the OpenSSH discussion item: default-OFF OpenSSH server install+enable toggle with a selectable port (default 22) threaded into BOTH sshd_config and the nftables input chain (policy-drop baseline) + prompted password/root access policies (defaults: ON / prohibit-password). Reuses the wallpaper picker (refactored to a shared `browse_pick` browser) to import an existing keypair from removable media into the target's `~/.ssh` (0700/0600/0644, owner TARGET_USER) and/or generate a fresh ed25519 pair with opt-in comment (default user@host) + opt-in passphrase (read -s type-or-paste, twice + match, in-memory; protects both the `~/.ssh` copy and any picked-dir backup). All staging under `/mnt/tmp/ssh-import/` shredded post-deposit and on failure; no key material ever reaches install-config/limine-env/resume state (only the public comment + protected flags do) | Beta-v2.9.23 below |
| **Beta-v2.9.24** | `[DEVICE-PROFILE-BT-DETECT]` — the Automatic device-profile option now scans the live CD for a Bluetooth controller (USB interface class `0xE0:0x01:0x01` = the Bluetooth Programming Interface, read from `/sys/bus/usb/devices/*/{,*/}modalias` as `icE0isc01ip01` — catches USB dongles AND M.2/PCIe WiFi+BT combo cards, and needs no lsusb/bluez) and ties `PROFILE_BT` to real hardware instead of assuming every box has bluetooth. Within each chassis class the probe picks laptop-bt↔laptop and desktop-bt↔desktop; an unresolvable chassis (VM/unknown) keeps the laptop baseline (tlp on) with bluetooth from the probe. The `[DEVICE-PROFILE-CONFIRM]` keep/override step still lets the user correct a misdetection. Maintainer-signed design decision: bare-Enter stays Automatic (a detected desktop drops tlp — pointless on a battery-less box now the service actually runs) | Beta-v2.9.24 below |
| **Beta-v2.9.25** | `[HARDWARE-REVIEW]`+`[NVIDIA-GATE]` — a live-box hardware probe (GPU families + wireless presence, pure sysfs like the BT probe) right after the device profile feeds a small drivers review, gating the ONE driver that can break a desktop installed blind: the NVIDIA proprietary driver, defaulting to `yes` only when an NVIDIA GPU is actually present. `nvidia` auto-pulls `nvidia-dkms`→`dkms` (gcc/make/linux-headers); the headers for every chosen kernel flavor are mapped from `KERNEL_PKGS` so dkms builds for all of them; nouveau is blacklisted. Probe results (`GPU_FAMILIES`/`WIFI_HW`/`HAS_*_GPU`) are exported + persisted + recorded in install-config for reuse by future work (Steam/Proton gaming deps, per-vendor firmware pruning) | Beta-v2.9.25 below |
| **Beta-v2.9.26** | `[WIFI-FW]`+`[WIFI-FW-VERIFY]` — the hardware review's wifi line becomes real chipset identification (live `phy*` device links, PCI or USB, plus a PCI class-`0x0280*` fallback) and a firmware-coverage note. Void's default chain covers every mainstream vendor wholesale — the reason a fresh Void needs no Debian-style mediatek-firmware download — and the probe finds the ONE vendor it skips (**Broadcom**, brcmfmac/b43 only in the non-default `linux-firmware-broadcom` split) and offers it with a `[Y/n]` prompt (`DEFAULT_WIFI_FW=auto`). Post-install, a verify proves the **target** (not the live CD) has both the driver module and the firmware for every detected radio, printing per-chip pass/warn. Broadcom gap factually confirmed against the repo (nothing pulls the split); probe + verify validated on the dev box's MT7922 → `verified: 0x14c3:0x0616` | Beta-v2.9.26 below |
| **Beta-v2.9.27** | `[CPU-DETECT]`+`[NIC-DETECT]` — the hardware review gains two probes, each on the fact-vs-decision side it belongs to. CPU microcode becomes a REPORTED, silently AUTO-INSTALLED fact (no prompt over the vendor-locked always-beneficial `intel-ucode`/`linux-firmware-amd` — microcode joins `linux-firmware`, unlike wifi's Broadcom-split prompt and NVIDIA's DKMS/nouveau tradeoff prompt; `DEFAULT_MICROCODE=no` is the only lever). `MICROCODE_DECIDED` marks "live review ran" so the chroot honors a decided empty (opt-out/unknown vendor) and re-derives only on a cross-version resume. The br0 wired-NIC pick moves INTO the review as `Keep this interface? [Y/n] or type another name:` (carrier-then-USB probe, `DEFAULT_NIC=<name>` pins a name and skips every prompt); a decline/nothing-found defers to the existing `INSTALL_VIRT`-gated re-probe whose "same USB port" notice still shows | Beta-v2.9.27 below |
| **Beta-v2.9.28** | `[SUBVOL-FLATPAK-TEXT]` — the subvolume-isolation preamble (Beta-v2.9.3) falsely documented Flatpak as "excluded" from per-app subvolume isolation; it was in the `[SUBVOL-GATES]` loop all along (Beta-v2.9.0), so `@flatpak` was already created/mounted/fstab'd on a yes. Text corrected to list Flatpak and document the `@flatpak` rationale (the GB-scale `/var/lib/flatpak` store stays out of `@` snapshots and survives a `@` rollback); OctoXBPS remains the sole documented exclusion. Plus `[APPIMAGE-FUSE]` — INSTALL_FLATPAK now also pulls `fuse` + `fuse3` (FUSE 2 for the AppImage runtime's historical `libfuse.so.2` dlopen, FUSE 3 for modern runtimes; they coexist on Void, and base-system pulls neither), so AppImages self-mount instead of falling back to extract-and-run. Gear Lever stays a manual Flathub add (no official Void package) and AppImages stay in `~/Applications` under `@home` — no AppImage subvolume. Plus `[BRAVE-FLATPAK-GATE]` — the Brave choice is only *offered* when Flatpak was selected (its sole installer route; the Flatpak prompt precedes the browser section), otherwise hidden with a one-line NOTICE and `INSTALL_BRAVE=false`; the Stage-2 WARNING is kept as a resume/export safety net. No gate or `DEFAULT_*` change | Beta-v2.9.28 below |
| **Beta-v2.9.29** | `[NFT-VIRT-PRINT]` — on a virtualization build (`INSTALL_VIRT=true`) the installer now echoes the just-written `/etc/nftables.conf` to the terminal so the operator can visually confirm the `br0`/`virbr*` forward accepts landed (those rules only reference interfaces that exist on a virt install — the whole point of `[NFT-VIRT-GATE]`); the printout doubles as an on-target live-validation artifact for that gate. Non-virt builds print nothing. No prompt, gate, or `DEFAULT_*` change | Beta-v2.9.29 below |
| **Beta-v2.9.30** | `[NFT-ICMPV6-RATELIMIT]` + `[NFT-RA-RATELIMIT]` + `[NFT-OPEN-PORT]` — three nftables refinements. IPv6 echo-request now gets the same `1/second burst 5` rate limit its IPv4 twin already had (the prior broad `meta l4proto ipv6-icmp accept` was unrate-limited, so IPv6 ping was both harder to log and abusable); `nd-router-advert` is capped at `6/minute` to blunt an RA-flood / SLAAC-hijack attack; and a new root helper `/usr/local/sbin/void-firewall-open-port` maintains an explicit-accept block inside the policy-drop input chain (marker-comment managed, `nft -c` parse-checked, runit reload on success, add/rm/list) so a future WAN-facing service is reachable without hand-editing the generated file. A "how to open a port" comment heads the config. No prompt or `DEFAULT_*` change | Beta-v2.9.30 below |
| **Beta-v2.9.31** | `[NFT-COUNTERS]` + `[NFT-RATELIMIT-KNOB]` — firewall observability and a control knob. The anti-spoof drops (`127.0.0.0/8`, `::1`), the `ct state invalid` drop, and the broad `ipv6-icmp` accept now carry `counter`; an explicit trailing `counter drop` rule at the end of both the input and forward chains makes the implicit policy-drop a countable rule, so `nft list ruleset` shows exactly why packets die. The two 2.9.30 hardening rules (IPv6 echo-request cap + `nd-router-advert` flood cap) are now gated by the env knob `DEFAULT_NFT_RATELIMIT` (no prompt, `DEFAULT_MICROCODE` style; default `yes` = tightened posture, `no` = plain broad-icmp config). Knob scope is the rate-limit rules only — the counters and the IPv4 echo cap stay unconditional, and the knob references no interfaces (no `[NFT-VIRT-GATE]` coupling). Also fixed: the generated config's header comment used `nft -c` in literal backticks inside an *unquoted* heredoc, which nft would have tried to execute at install; reworded to plain text | Beta-v2.9.31 below |
| **Beta-v2.9.32** | `[FW-AUDIT]` — closes the "per-vendor firmware pruning" discussion item. Verified against the void-packages templates: `linux-base` hard-depends on `alsa-firmware` `linux-firmware-network` `sof-firmware` and (x86_64) `linux-firmware-amd` `-intel` `-nvidia`; the network split itself hard-depends on `linux-firmware-broadcom`; XBPS has no recommends tier, so an installer-side prune is impossible (xbps-remove refuses: "dependency of installed 'linux-base'"). The ONE firmware Void leaves per-host is CPU microcode, already pruned to a single package by `[CPU-DETECT]`. So a report-only post-install audit now prints what *landed* vs what this box's probe *needs*, names the splits kept solely by the dependency wall (the irreducible wholesale tax), and confirms the Broadcom gap state. Nothing gated | Beta-v2.9.32 below |
| **Beta-v2.9.33** | `[FW-AUDIT-LOG]` — the `[FW-AUDIT]` accounting (Beta-v2.9.32, console-only) is now **persisted** into the installed machine's as-built record `~/Documents/Void_Install.txt`. The audit builds its text once, prints it to the console, and appends it as a `# -------- FIRMWARE ACCOUNTING ([FW-AUDIT], as-built) --------` section after the package inventory. The record file is written earlier in the chroot by the `[DOCS-LOG-CHOWN]` block; the root→user-owned append preserves ownership, and nothing is gated on it (missing file / empty `TARGET_USER` → silently skipped). The end-of-install NEXT-STEPS line now advertises the record "incl. firmware accounting". Report-only | Beta-v2.9.33 below |
| **Beta-v2.9.34** | `[SLICK-BG-QUOTES]`+`[SSH-DEPOSIT-LOG]`+`[FLATPAK-NM-DISPATCH]` — slick-greeter does NOT strip quotes from config values (a quoted `background="path"` is opened as `"/path"` and fails → black greeter), so the Slick background is now written UNQUOTED (GTK greeter keeps the quoted form); the ssh-key deposit guard's fragile `ls -A` subshell replaced with `find -quit` plus an explicit WARNING when the account is missing; the first-boot Flatpak queue moved from the old rc.local background subshell to a NetworkManager dispatcher script (`99-flatpak-firstboot`, fires on up/vpn-up with a default route — guaranteed DNS); sshd + vboxdrv rc.local links realigned (sshd early) | Beta-v2.9.34 below |
| **Beta-v2.9.35** | `[ESP-SIZE]` — the EFI ESP size becomes a real prompt-time decision via a shared `esp_size_choose()` menu (4 GiB default / 6 GiB / 8 GiB / Custom, 1 GiB floor, normalized to gdisk single-letter K/M/G): Limine calls it after the bootloader choice (esp-copy mirrors every kernel/snapshot onto the ESP), and the GRUB+ENCRYPT path mounts the ESP AT `/boot` so it shares the same menu. Plain GRUB never calls it (fixed 1G at /boot/efi). Fixes `[GRUB-ESP-SIZE-ORDER]` — the old in-loop check read ENCRYPT before its own prompt, so the wrong size applied | Beta-v2.9.35 below |
| **Beta-v2.9.36** | `[CHANNEL-GROUP]`+`[INSTALL-BREW]` — Flatpak and Homebrew are shown as one "THIRD-PARTY APP CHANNELS" umbrella but stay INDEPENDENT yes/no toggles (both default OFF — brew must not read as a sub-choice of Flatpak's sandbox). Homebrew/Linuxbrew is the unsandboxed, user-owned `~/.linuxbrew` CLI/dev channel: installs only the xbps runtime deps (git, curl, file, procps-ng), deliberately never pipes the vendor's `curl|bash` — the operator creates the prefix on first login. Isolation is a separate opt-in `@linuxbrew` per-user subvol (SUBVOL_ROWS row → `PROVISION_LINUXBREW_SUBVOL`, default OFF) + subvol-tool `dev` class | Beta-v2.9.36 below |
| **Beta-v2.9.37** | `[GAME-LAUNCHERS]`+`[GAME-SUBVOL]` — a "GAME LAUNCHERS & RUNTIMES" umbrella (after app channels, before Steam) with independent default-OFF toggles: Lutris (Void main, xbps), Heroic + Bottles (NO official Void package → Flatpak-only, offered only when `INSTALL_FLATPAK=true`), Wine (multilib runtime, never auto-pulled by a launcher), gamemode (Feral governor daemon). ONE shared `@game` per-user subvol (replaces `@steam`) mounted at the derived per-launcher set (`~/.local/share/Steam` + `~/.local/share/lutris`) via the subvol-tool multi-mount loop + `@steam`/gaming alias resolution + `@game` fstab-guard relaxation + detach/destroy BRE-paren sed fix | Beta-v2.9.37 below |
| **Beta-v2.9.38** | `[MULTI-FS]` — per-region data filesystems: each of `/home`, `/var`, `/var/cache`, `/srv`, `/opt` (+ optional `Games`) can be carved onto its OWN dedicated partition with an ext4/btrfs filesystem choice instead of a root-Btrfs subvolume. Fixed-order outer carve right after the ESP and BEFORE the single LINUX root partition (LINUX last, sized to the remainder), or as an INNER GPT inside the LUKS2 container when `[ENCRYPT]`; region subvols (`@home`/`@var`/…) are FOLDED out of the flat topology so no subvolume collides with a partition mountpoint; owned fstab rows skipped; subvol-tool `[MULTI-FS-GUARD]` prevents re-creating a carved region's subvolume; region mounts before chroot; games chown; DOCS-LOG `DATA_REGIONS`. Plus `[MULTI-FS-RUNLOG]` (journal audit lines + journal archived to `/etc/void-installer/installer-run.log` on success) and `[CRASH-USB-LOG]` (crash post-mortem — journal + `.info` sidecar — to the first mounted stick; `--save-log` parsed BEFORE the journal truncation / network gate / STAGE-1 banner so it works from a crashed, networkless live env). Default (bare Enter) = all-Btrfs flat layout, byte-identical to 2.9.37 | Beta-v2.9.38 below |
| **Beta-v2.9.39** | `[CRASH-USB-LOG-FATAL-EXIT]`+`[SUBVOL-ROWS-FIX]` — the crash post-mortem dump also fires on planned `exit 1` FATALs (EXIT-trap `_save_log_on_exit` + `_usb_dumped` double-write guard); SUBVOL_ROWS loop skips `#`-comment rows before the resolve eval + spurious duplicate INSTALL_BREW row removed | Beta-v2.9.39 below |
| **Beta-v2.9.40** | `[PKG-PREFLIGHT]`+`[GAME-FLATPAK-GATE]` — Stage-1 package-name gate resolves every chroot-installable package against the live union pool BEFORE `sgdisk -Z` (closed crash #005; 134-pkg superset candidate list + committed drift-guard; repo hiccups WARN+skip, never false FATAL); Heroic/Bottles are Flatpak-queue-only delivery (`@game` mounts only `~/.local/share/Steam`+`~/.local/share/lutris`) | Beta-v2.9.40 below |
| **Beta-v2.9.41** | (intermediate build) `98void-inner-partscan` dracut-module draft — module-setup.sh + udev rules + helper skeleton (crash #008: dracut crypttab `partscan` is unreliable on non-loopback LUKS2 at boot) | Beta-v2.9.41 below |
| **Beta-v2.9.42** | (intermediate build) FATAL initramfs-content gate + `parted` shipping into the target (crash #009: `partx -a` cannot BLKPG a dm mapper, so the module initially booted to the emergency shell) | Beta-v2.9.42 below |
| **Beta-v2.9.43** | `[INNER-PARTSCAN-BOOT]` — boot-time partscan dracut module (98void-inner-partscan): udev RUN fires on the opened mapper's DM_NAME, partprobe-primary / partx-fallback force-registers the inner GPT BEFORE dracut's settle resolves `root=UUID=<inner btrfs>`; gated on `ENCRYPT=yes` + carved `REGION_PARTITIONED` | Beta-v2.9.43 below |
| **Beta-v2.9.44** | `[DRACUT-CONF-NAME]` — the `add_dracutmodules` conf value MUST be the SHORT module name without the numeric prefix (`void-inner-partscan`, NOT `98void-...`); dracut-ng resolves conf names as `[0-9][0-9]<name>` so a prefixed name matches nothing and the regen dies | Beta-v2.9.44 below |
| **Beta-v2.9.45** | `[INNER-PARTSCAN-DMPROBE]` — partprobe-first inner-GPT rescan (libparted dm-linear submaps are the ONLY tool that can BLKPG a dm mapper; `partx -a` fallback only); named `_region_inner_partscan`/`_region_inner_dev` helpers; chroot FATAL initramfs gate + per-image guard in void-limine-sync-kernels; cleanup `partx -d` before luksClose | Beta-v2.9.45 below |
| **Beta-v2.9.46** | Five ENCRYPT+regions post-audit fixes from the first real boot on `<host>`: `[SUBVOL-TOOL-RESOLVEDEV]` (strip `[/@]` from findmnt SOURCE before subvolid=5 mount + `awk -v sub=`→`svpat` rename), `[INSTALL-CONFIG-FLATPAK]` (INSTALL_FLATPAK/INSTALL_BRAVE public rows), KERNEL_PKGS/PKG-PREFLIGHT verification, `[VBOX-SV-GUARD]` (vboxdrv link guarded on `/etc/sv/vboxdrv`), `[FLATPAK-NM-DISPATCH-STAMP]` (flatpak queue dispatch check) | Beta-v2.9.46 below |
| **Beta-v2.9.47** | `[TEE-BOOT-QUIET]`+`[TEE-BLACKLIST]` — two env-only PUBLIC limine-env knob rows (`DEFAULT_QUIET_BOOT`, `DEFAULT_TEE_BLACKLIST`, default no) thread a shared `TEE_QB_FRAG` (`quiet` + `modprobe.blacklist=tee`) through every GRUB/Limine BASE_CMD builder + the write-conf recompute; byte-identical at defaults | Beta-v2.9.47 below |
| **Beta-v2.9.48** | `[NO-DE]`/`[NO-DM]`/`[HEADLESS]`/`[HEADLESS-XORG-OPT]`/`[HEADLESS-AUDIO]`/`[DE-ORDER]`/`[DISK-BUDGET]` — headless/server install path (DESKTOP_ENV option 8 = none, DM `none` → `DM_SERVICE_NAME=none` + sed-guarded rc.local link, `HAS_GRAPHICAL` gates the xorg/wayland base chain + audio, INSTALL_XORG/INSTALL_AUDIO opt-ins only when headless) + pre-write partition fit check (`DISK_BYTES` captured at disk-pick and persisted; `_size_to_bytes` + `_disk_budget_check` refuse an over-provisioned layout before `sgdisk -Z` and fail dry-run; ENCRYPT via container=remainder identity) + the latent 2.9.38 `REGION_*_SIZE` uppercase-fold eval fix | Beta-v2.9.48 below |
| **Beta-v2.9.49** | `[VERIFY-FIXES]` — post-verification corrections proven against the live as-built machine (2026-09-14): `[WINE-RENAME]` (prompt var `INSTALL_GAME_WINE` → `INSTALL_WINE`, matching the as-built record + recovered prompt docs), `[FLATHUB-URL-FIX]` (both remote-add sites now use `https://flathub.org/repo/flathub.flatpakrepo` — the bare website URL 307s to `/en` and imports no GPG key, so queued flatpak installs failed with "public key not found", proven on hardware), `[DOCS-LOG-ASBUILT]` (`~/Documents/Void_Install.txt` header rewritten to the recovered as-built row set byte-format: SSH_SERVER/NVIDIA_DRIVER(wifi)/WIFI_HARDWARE/CPU/HOMEBREW/GAMING/DATA_REGIONS all-six ordered), `[FW-AUDIT-LOG-DROP]` (accounting stays console-only — the as-built record has no firmware section) | Beta-v2.9.49 below |
| **Beta-v2.9.50** | `[BROWSE-DIR-ACCEPT]` — `browse_pick` `dir` mode gains an explicit accept (`!`/`ok` confirms the CURRENT directory): a directory destination could previously never be confirmed (selecting a dir descended into it, bare Enter was a decline, only a FILE could exit the loop), so the `[SSH-KEYS]` keypair backup export (`export to removable media` → `_export_dst="$(browse_pick dir …)"`) ALWAYS ended "skipping export." and the keys never reached the USB stick — matching the real v2.9.43 build | Beta-v2.9.50 below |
| **Beta-v2.9.51** | `[BROWSE-CAP-FIX]` — `browse_pick` is called exclusively through command substitution, so every STDOUT menu/help/listing/prompt line was captured INTO the result value: the Limine wallpaper pick (`img` mode) returned the whole multi-line banner (stage `cp -f "$WP_SRC" …` FATALed → any Limine run answering the wallpaper prompt aborted), and the SSH-key export pick (`dir` mode) returned banner-prefixed text so `[ -d "$_export_dst" ]` always failed ("No destination chosen; skipping export.") — even a bare-Enter DECLINE left the banner as a non-empty selection. All browser UI now writes to STDERR (`>&2`, the `_subvol_ask` pattern); ONLY the final picked value goes to stdout so the capture returns exactly the path | Beta-v2.9.51 below |
| **Beta-v2.9.52** | `[PREREQ-DRY-RUN]` — a `--dry-run` plan run skips the live-CD package sync yet still ran the `[PREREQ]` outer-tool gate behind it, so on a medium without gptfdisk preinstalled it FATALed "required live-CD command not found: 'sgdisk'" at the confirmation boundary and never reached the plan printout. A plan run never partitions, so the gate (whose only job is to keep a REAL run from reaching destructive partitioning without its tools) is now skipped entirely under `DRY_RUN=1` | Beta-v2.9.52 below |
| **Beta-v2.9.53** | `[HEADLESS-PLAN-LABEL]` — the DRY-RUN plan's Desktop/DM line printed `headless=$HAS_GRAPHICAL` verbatim, i.e. `(headless=yes)` for a GRAPHICAL MATE/LightDM install — the label's meaning was inverted. The plan now prints `(graphical)` or `(headless)` honestly. Print-only cosmetic fix. | Beta-v2.9.53 below |
| **Beta-v2.9.54** | `[SSH-KEYGEN-STALE]` — on a live medium whose `/tmp` persists across runs, a stale `/tmp/ssh-keygen` makes the rerun's `ssh-keygen` prompt "Overwrite (y/n)?" and silently EATS the next answer-stream line (the keypair-backup export answer gets consumed as the overwrite reply, then the export is declined by the browse-path answer). Stale `id_ed25519{,.pub}` are removed before keygen so it stays non-interactive; the DRY-RUN exit path now also shreds the live SSH key stage like the failure/post-chroot cleanups do | Beta-v2.9.54 below |
| **Beta-v2.9.55** | `[INNER-DEV-NAME]` — the outer disk carve already checks `[[ "$DISK" =~ (nvme|mmcblk) ]]` to decide whether the base name needs a `p` separator before the partition number (`nvme0n1p1` vs `sda1`). The inner GPT carved inside a LUKS2 mapper hardcoded `${CRYPT_DEV}p${N}` → `/dev/mapper/void-rootp1`, but dm-linear children are named WITHOUT the `p` separator (`void-root1`, not `void-rootp1`) — the `p` is only for devices whose basename ends with a digit. The first real ENCRYPT+regions+MULTI-FS install crashed here immediately ("region device ... does not exist (partscan?)"). Now resolves region devices + the Btrfs root with the same separator decision the outer carve uses | Beta-v2.9.55 below |
| **Beta-v2.9.56** | `[INNER-PARTSCAN-KPARTX]` — the first real ENCRYPT+regions install booted to the dracut emergency shell REPRODUCIBLY: LUKS unlocked fine and the mapper showed `PTTYPE=gpt` in blkid, yet dracut looped "Scanning for all btrfs devices" and root=UUID (the inner btrfs) never resolved. Root cause: `partprobe` (the Beta-v2.9.45 PRIMARY BLKPG tool) silently failed to register the inner GPT on the OPENED LUKS2 mapper on this kernel/hardware — no child dm devices appeared, and `partx -a` is confirmed unable to BLKPG a dm target ("error adding partitions 1-2" live). The tool that works is `kpartx`: `kpartx -av /dev/dm-0` instantly created `void-root1`/`void-root2` (names derive from the mapper name, matching [INNER-DEV-NAME]). Fix: `kpartx -a` is now PRIMARY in the boot udev RUN helper, `_region_inner_partscan`, AND module-setup (`require_binaries kpartx` + `inst_binary kpartx`), with partprobe then partx -a kept as ordered fallbacks; the initramfs-content gates (ESP-sync guard + chroot FATAL) now also require `kpartx`; `kpartx` package added to PKG_PREFLIGHT + the module-gated `install_pkgs` line | Beta-v2.9.56 below |
| **Beta-v2.9.57** | `[INNER-PARTSCAN-UDEV-ATTR]` — v2.9.56's boot udev RUN rule STILL NEVER FIRED: even with `kpartx` in the image the box hit the SAME emergency shell on the fixed system's first boot. Root cause: the rule matched `ENV{DM_NAME}=="void-root"`, but the kernel's dm **add uevent carries NO `DM_NAME`** — libdevmapper writes that key into the udev db later, AFTER udev rules have already evaluated. An `ENV{DM_NAME}` predicate can therefore never match at rule time, which retroactively explains BOTH the 2.9.45 "partprobe silently did nothing" AND the 2.9.56 "kpartx still didn't help": the RUN helper had never run (captured live: the dm-0 add uevent carries only ACTION/DEVNAME/DEVPATH/DEVTYPE/DISKSEQ/MAJOR/MINOR/SEQNUM/SUBSYSTEM; `DM_NAME` appears only on the later UDEV-processed record). Fix: match `KERNEL=="dm-*", ATTR{dm/name}=="__CRYPT_NAME__"` — the device-mapper name IS exposed in sysfs (`/sys/block/dm-0/dm/name`) at add-time. Live-proof: a udev rule with that predicate fired the RUN helper and `kpartx` instantly mapped `void-root1`/`void-root2` on `luksOpen`. Rule line: `ACTION=="add", SUBSYSTEM=="block", KERNEL=="dm-*", ATTR{dm/name}=="__CRYPT_NAME__", RUN+="..."`. No other script logic changed (helper, module-setup, and content gates untouched); the 98 prefix and `add_dracutmodules` short-name convention are NOT implicated (module was present in every booted image) | Beta-v2.9.57 below |
| **Beta-v2.9.58** | `[HOME-SELF-CHOWN]` — account-provisioning fix, UNIVERSAL to every greeter/DM/DE: `useradd -m` creates `/home/$TARGET_USER` as root:root 755, and the installer's adopt-own chown pass covered only the home SUBdirectories — on a carved/adopted @home the HOME DIR ITSELF stayed root-owned, so the account could not write .Xauthority/.dmrc/.xsession-errors at greeter time → X auth failed → mate-session exited in ~0.02s (lightdm.log "Exited with return value 1") → LightDM/cosmic-greeter/SDDM bounced the CORRECT password as a grey "wrong password" loop (proven live on the NVMe box: the SAME test password that had been grey-bounced logged in successfully with ZERO greeter/session changes once the home tree was chown'd to uid 1000). Fix: `chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}"` immediately after useradd (mirrors the ~/Games + .cache/@containers-user adopt-own pattern). The separate `_cosmicgreeter` username-dispatch packaging bug is a DIFFERENT, greeter-only issue and stays out of this row | Beta-v2.9.57 below |
| **Beta-v2.9.59** | `[LOCAL-CACHE]` — optional reuse of a pre-seeded XBPS package cache on an attached medium (`xbps-cachedir-<arch>` under `/run/media`, e.g. the Void_Linux_Live build cache on the same USB stick) so the live sync / bootstrap / chroot installs fetch from disk instead of the mirror (mirror stays per-package fallback). Default OFF (`DEFAULT_LOCAL_CACHE=no`, network-only baseline matching `[BROWSER-GATE-NO]` posture); prompt auto-detects the newest-touched writable arch-matching dir with real `.xbps` files, or accepts a typed absolute path. `-c` threading: `${LOCAL_CA}` in the live sync + bootstrap; a bind mount of the media cache at `/mnt/tmp/xbps-cache` (= chroot `/tmp/xbps-cache` via chroot_env's REMAPPED `LOCAL_CACHE_DIR`) + the chroot-wide `${_xbps_cache[@]}` array into `install_pkgs()` AND `install_cosmic()`. Cache dir MUST be writable (the `-Sy` repodata write lands in the CHROOT's `/var/db/xbps/<url>` under xbps 0.60 — never in the cache dir; the cache absorbs PAYLOADS, and every mirror-fallback / COSMIC-sync download lands inside it, which is what the writability requirement really protects); any unusable/unwritable path degrades to network-only, never a FATAL. Resume: `LOCAL_CACHE_REUSE`/`LOCAL_CACHE_DIR` persist to the state file and the recorded path is re-validated/re-detected before re-sync. Release added to both the Stage-3 teardown and the failure unwind. PKG-PREFLIGHT gate untouched (stays mirror-truthful) | Beta-v2.9.58 below |
| **Beta-v2.9.60** | `[RESUME-GFX-FLAGS]` — the `[RESUME]` state-file persist list (stage-1 config block) omitted the three Beta-v2.9.48 `[HEADLESS]` flags `HAS_GRAPHICAL`/`INSTALL_XORG`/`INSTALL_AUDIO`, so every `-r` resume dropped into the chroot with them EMPTY. The in-chroot "defaults" the HEADLESS feature claimed (`HAS_GRAPHICAL=${HAS_GRAPHICAL:-yes}` etc.) live INSIDE the install-config heredoc — inscribed text, never executed — so the Stage-2 gate `[ "$HAS_GRAPHICAL" = "yes" ] || ...` fell through to the HEADLESS else-branch and a graphical KDE/SDDM install resumed as headless: the entire Xorg/Wayland base chain (`xorg`/xorg-server/mesa/xf86-*/xauth/xinit/wayland-protocols) was never installed → `/usr/bin/X` absent → SDDM "Failed to start display server process" → boot unlocked LUKS fine but never reached the greeter (proven live on <host>; audio alone survived because only ITS gate carries a real shell-side `:-true` default). Fix: (1) `HAS_GRAPHICAL`/`INSTALL_XORG`/`INSTALL_AUDIO` added to the resume-state persist list; (2) a REAL in-chroot recompute immediately before the base-chain gate — `HAS_GRAPHICAL` re-derived deterministically from the persisted `DESKTOP_ENV`/`DISPLAY_MANAGER` (both `none` ⇔ headless, else graphical), with `INSTALL_XORG`/`INSTALL_AUDIO` falling back to `false`/`true` — making resume safe even for state files written before this era | Beta-v2.9.59 below |
| **Beta-v2.9.61** | `[LOCAL-CACHE-ROOT]` — the `[LOCAL-CACHE]` detector globs only `/run/media/*/xbps-cachedir-*`; a `--persist` + `--seed-cache` Void_Linux_Live stick (`voidlive-build-persist.sh`) seeds the cache into the **root of its VOID_OVL overlay**, so on the booted live system it sits at `/xbps-cachedir-<arch>` — writable persistence layer, arch-matched, real `.xbps`, but nowhere near `/run/media` → never auto-detected. The detect glob list now also probes live-root `/xbps-cachedir-*` (a no-op on ordinary non-persistent boots; the seeded persist stick auto-detects and the prompt answer stays a plain `Y`) | Beta-v2.9.60 below |
| **Beta-v2.9.62** | `[LOCAL-CACHE-DEPTH]` — the `[LOCAL-CACHE]`/`[LOCAL-CACHE-ROOT]` `/run/media` glob probed only `/run/media/*/xbps-cachedir-*` (**one** level), but udisks mounts an unlabeled data stick at `/run/media/<user>/<uuid>` (**two** levels) — precisely the "cache on a separate data stick next to the VOID_LIVE stick" layout this feature was built to serve — so auto-detect silently missed it on every such box and the prompt fell back to typing the absolute path. The detect glob list now also probes `/run/media/*/*/xbps-cachedir-*`; depth-1, depth-2 and the live-root seed all share the same newest-touched, writable, arch-matching, real-`.xbps` first-wins rule. Proven against the <host> layout: `/run/media/<user>/<uuid>/xbps-cachedir-x86_64` now auto-detects as root | Beta-v2.9.61 below |
| **Beta-v2.9.63** | `[LOCAL-CACHE-ERR]` — the detector's process substitution `<(ls -1dt <globs> 2>/dev/null)` exits **2** whenever any glob matches nothing: the unmatched glob stays LITERAL, so `ls` reports it as a missing operand even when a sibling glob matched AND was listed — every real run (cache present or not) kills the install at the cache prompt. Under `set -eE` + `trap ERR` the non-zero status fires `cleanup_on_failure` **inside** the `$( _local_cache_detect || true )` subshell (the `|| true` guards only the call site), producing "!! Install failed (exit 2)" with `Failing command: ls ... xbps-cachedir-*` and a best-effort /mnt unwind although detect itself returned the cache path successfully. Reproduced live as root on both the target's desktop copy and the repo. Fix: `|| true` on the `ls` inside the process substitution — its status can no longer propagate — so the read loop just consumes whatever matched, exactly mirroring the `Void_Linux_Live` `_cache_detect()` form (that file already carried `|| true`, this was the lone divergence). `bash -n` clean; post-fix root run reaches the (now promptable) cache step | Beta-v2.9.62 below |
| **Beta-v2.9.64** | `[PARTSCAN-HOST-COPY]` — dracut's udev-rule program scan (`_inst_rule_programs`, dracut-functions.sh) resolves each `RUN=` path against the BUILD HOST root, never the module dir. The 98void-inner-partscan udev rule references `/usr/bin/void-inner-partscan.sh`, a path that at dracut time exists only as `$moddir/void-inner-partscan.sh`, so EVERY initramfs build logged `Skipping program /usr/bin/void-inner-partscan.sh using in udev rule 10-void-inner-partscan.rules as it cannot be found`. Purely cosmetic on the image (module-setup's `inst_script` embeds the helper regardless — lsinitrd proves all bits present) but noisy on every kernel install, and it recurs on the installed system's kernel updates too. Fix: the installer now also copies the helper to the target's `/usr/bin/void-inner-partscan.sh` (0755) as part of the module-write step, so the scan resolves it and embeds it via `inst_binary` — warning gone, plus a directly-inspectable copy lives on the installed system. The `$moddir` copy and `inst_script` are unchanged (the image's source of truth). Applied live to the running install's chroot (02:36) so its next kernel update is already quiet; the already-built initramfs images were left untouched (verified correct). `bash -n` clean | Beta-v2.9.63 below |
| **Beta-v2.9.65** | `[HOME-CACHE-CHOWN]` — on a carved-`/home` `[MULTI-FS]` install (`REGION_PARTITIONED` contains `home`) the ONLY `~/.cache` chown in the script lives inside the non-carved `@usercache` branch, so the **root**:root 0755 `~/.cache` created by the browser-subvol prep (`mkdir -p "/home/${TARGET_USER}/.cache"`) was left un-chowned on every carve-home install. A root-owned `~/.cache` silently breaks the whole graphical desktop on first boot: `ksycoca` cannot create/lock its DB (`Couldn't lock ".../ksycoca6_...=.lock"` → empty KDE app launcher + blank panel), the AppStream runner cache refuses to write, mesa shader cache (`.cache/mesa_shader_cache`) is disabled, and firefox dies on `~/.cache/mozilla` with "Permission denied" (the script's own browser-provision comment documents firefox's cache path there). Proven on real hardware (<host>, carved ENCRYPT `/home`, KDE/SDDM, SCRIPT_VERSION Beta-v2.9.13): the FIRST boot's `~/.local/share/sddm/wayland-session.log` was wall-to-wall `Permission denied`/`Couldn't lock` on `~/.cache` with the session otherwise fine. Fix: the carved-home branch now `chown`s `~/.cache` to `$TARGET_USER` and `chmod 700` — byte-matching the `@usercache` branch — applied live on the installed box (chown + chmod restored ksycoca and firefox with zero other changes, verified by a <user> chroot write probe). `bash -n` clean | Beta-v2.9.64 below |
| **Beta-v2.9.66** | `[MULTI-FS-FS-EVAL]` — the three mkfs/mount/fstab region loops resolved each carved region's filesystem with `eval "_rr_fs=\${REGION_${_rr}_FS:-btrfs}"` using the RAW lowercase `REGION_PARTITIONED` token, so `home` read the never-existent `REGION_home_FS` (bash variable names are case-sensitive) and **every** carved region silently fell back to `btrfs` — the v2.9.48 `[DISK-BUDGET]` `^^` fold fixed the SIZE evals but MISSED the three `_FS` evals. `games` broke even that contract: its choice lives in `REGION_GAMES` (no `_FS` suffix), so an uppercased `REGION_GAMES_FS` would still read empty. Proven live on <host> (carved ENCRYPT `/home` + `/home/<user>/Games`, both requested as ext4): the prompt + install-config recorded `home=ext4 games=ext4` while `installer-run.log` mkfs, `/etc/fstab`, and `blkid` all show **btrfs**. Fix: `_region_fs_of` helper (`_region_fs_of "$_rr"`, near `_region_carved`) uppercases the token and special-cases `games`, and feeds all three loops; the installed `void-subvol-tool.sh`'s runtime `region_fs()` gets the same fold + `games` special-case + quote-strip so its carved-region guard actually fires on a carved box. Also removed a `[DOCS-LOG]` stutter that double-printed the microcode package in the `CPU=` line (`...: linux-firmware-amd)linux-firmware-amd`). `bash -n` clean | Beta-v2.9.65 below |
| **Beta-v2.9.67** | `[KEYMAP-CMDLINE]` — the `[ENCRYPT]` branch baked the `[KEYMAP]` (Beta-v2.6.9) initrd parameter as a BARE `rd.vconsole.keymap=<k>` line appended to `/etc/dracut.conf.d/90-system.conf`, but dracut **sources** every conf file with bash — a dotted bare assignment is not valid shell, so bash EXECUTED the line as a command and every dracut run logged `rd.vconsole.keymap=us: command not found` (3× per install — one per kernel image — plus 3× on this observed install's `xbps-reconfigure` regen). Worse, the parameter was therefore NEVER baked into the initramfs, so the keymap feature silently did nothing and the early-boot LUKS passphrase prompt kept the kernel's built-in US map. Fix: emit `kernel_cmdline="rd.vconsole.keymap=<k>"` — the dracut-native form (`man dracut.conf`: "this command only sets initrd parameters"), shell-valid AND actually lands the parameter. Shared `90-system.conf` → covers both bootloaders. `bash -n` clean | Beta-v2.9.66 below |
| **Beta-v2.9.68** | `[PARTUUID-NODEPS]`/`[INSTALL-CONFIG-BACKENDS]`/`[INSTALL-CONFIG-SSHKEY]`/`[FLATPAK-DNS-LATE]` — four fixes from reviewing a fresh carved-ENCRYPT install against the script. (1) `lsblk -no PARTUUID "$dev"` **descends into children**, so with `ENCRYPT`+regions (`PART_SYS` = the LUKS container) `BTRFS_PARTUUID` captured the inner `void1/2/3` PARTUUIDs too and wrote a malformed multi-line `SYSPREFIX_BTRFS` into `limine-env`/`chroot_env` (`SYSPREFIX_ESP` stayed safe only because the ESP vfat partition has no children); `--nodeps` now pins the named partition. (2) `install-config` never recorded `INSTALL_STEAM`/`INSTALL_DOCKER`/`INSTALL_PODMAN_*` or the `PROVISION_*_SUBVOL` rows — a fresh box with steam + podman installed and `@containers` mounted had no config row to explain any of it. (3) `SSH_KEY_COMMENT`/`SSH_KEY_PROTECTED` were initialized to their prompt defaults and exported **unconditionally**, so `install-config` advertised key facts even when no key was imported/generated (observed: `~/.ssh` absent); now gated on the real deposit via `SSH_KEY_PRESENT` and the comment/protection rows are omitted when no key exists. (4) the flatpak NM dispatcher armed only on `up`/`vpn-up`; when the first `up` beat DNS (`Could not resolve hostname`) it left the queue unstamped with no retry, so it now also arms on `connectivity-change`. `bash -n` clean, `check-heredocs.sh` ALL CLEAN | Beta-v2.9.67 below |
| **Beta-v2.9.69** | `[FLATPAK-NM-DISPATCH-LOCK]` — the Beta-v2.9.68 premise that "`up` does not fire again on a stable link" is FALSE: on the SAME `<host>` box, five pre-lock dispatcher firings in ~30 minutes piled up five concurrent `flatpak install` processes racing the same OSTree repo (the observed live mess: Brave + Heroic + Bottles stranded, a fresh drain spawned on every `up`/DHCP renew, none completing on a ~120 KB/s shared link). Fix: the dispatcher wraps the drain in an exclusive flock (`exec 9>/var/lock/flatpak-firstboot.lock ; flock -n 9 || exit 0`) so a burst of `up`/`vpn-up`/`connectivity-change` collapses to ONE running drain; the losers bail and re-arm on the next network event, and a completed run still leaves the `.done` stamp (the lock auto-releases on exit, so a crashed drain never wedges it). The stranded queue was live-drained on `<host>` (Brave/Heroic/Bottles) and the running box's dispatcher was refreshed to the 2.9.68 form + a `.bak-20260917`. `bash -n` clean, `check-heredocs.sh` ALL CLEAN | Beta-v2.9.69 below |
| **Beta-v2.9.70** | `[ELOGIND-NO-STRAY-KILL]` — the cosmic-greeter `/etc/sv/cosmic-greeter/run` "stray elogind PID sweep" (kill any `pgrep`'d `elogind`/`elogind-daemon` whose pid differs from `supervise/pid`) killed the LIVE logind. Proven on <host> that Void's elogind runs as a single daemonized `elogind-daemon` reparented to PID 1 — `pgrep -x 'elogind'` matches NOTHING, `pgrep -x 'elogind-daemon'` returns exactly the serving daemon, and `supervise/pid` is the already-exited runsv child, so the guard's exception never matched and `kill` fired on the serving daemon → seat/session/run-user vanish → live desktop hang (the "you killed an elogind pid" incident). The sweep is REMOVED: elogind is single-instance by design (a duplicate cannot bind `org.freedesktop.login1`), so no killable stray exists and `sv check elogind` is the only gate the greeter run script needs (runit restarts a dead daemon itself). `bash -n` clean, `check-heredocs.sh` ALL CLEAN | Beta-v2.9.70 below |
| **Beta-v2.9.71** | `[STEAM-32BIT]` — Void's `steam` package is a client bootstrap with NO 32-bit runtime dependencies, so every fresh install that chose Steam hit "missing 32-Bit libraries libGL.so.1 & libdrm.so.2" on first launch (observed on the round-3 KDE box; `libglvnd-32bit`/`libdrm-32bit` were in the multilib repo but never installed). The `[INSTALL-APPS]` Steam branch now pulls the canonical Steam multilib runtime set (`libgcc/libstdc++/libglvnd/mesa-dri/libdrm` + the `libX*`/`libxcb`/`freetype`/`fontconfig`/`libpulseaudio`/`alsa-plugins-pulseaudio` `-32bit` libs) together with `steam`, gated STRICTLY on `INSTALL_STEAM=true` — no new prompt and nothing 32-bit ships unless the user opts into Steam at install time (`INSTALL_STEAM` stays lean-default OFF). The same names are added to `PKG_PREFLIGHT` (a stage-1 validation-only list that installs nothing by itself). `bash -n` clean, `check-pkg-preflight.sh` clean | Beta-v2.9.71 below |
| **Beta-v2.9.72** | `[GAME-VULKAN]` — the 2.9.71 fix cleared the 32-bit GL/GLX layer, but on the same round-3 KDE box Steam then still failed: the fresh install shipped only the virtual-GPU `virtio_icd` as its Vulkan ICD, so on the AMD APU every Vulkan probe returned `VK_ERROR_INCOMPATIBLE_DRIVER` (`-9`) — the Steam topology query and any 32-bit game that loads `libvulkan.so.1` had no radeonsi ICD to reach. The `[INSTALL-APPS]` block now installs the DETECTED GPU family's Mesa Vulkan driver (`mesa-vulkan-radeon`/`mesa-vulkan-intel`/`mesa-vulkan-nouveau`, each 64-bit + `-32bit`) whenever `INSTALL_ANY_GAME=true` (Steam ∨ Lutris ∨ Heroic ∨ Bottles, the existing compound gate), gated on the live-box probe (`HAS_AMD_GPU`/`HAS_INTEL_GPU`/`HAS_NVIDIA_GPU`) — the profiler carries no new prompt, installs that chose a launcher on an NVIDIA box that also accepted `INSTALL_NVIDIA` get the driver's own proprietary ICD (no nouveau), and hybrids multi-family. A no-game box still ships zero extra graphics payload. All six names added to `PKG_PREFLIGHT`. `bash -n` clean, `check-pkg-preflight.sh` clean | Beta-v2.9.72 below |
| **Beta-v2.9.73** | `[ELOGIND-RUN-SELFHEAL]` — Void's shipped elogind still self-daemonizes (double-fork, reparent to PID 1, write /run/elogind.pid), but the packaged `/etc/sv/elogind/run` `exec`s it without `-D`, so runsv's supervised child exits immediately and runsv respawns ~1x/sec forever — kernel ring buffer ~82% `elogind is already running as PID <n>` on a fresh elogind install (found 2026-10-04 on the fresh non-encrypted COSMIC <host>). The installer now ships `/root/tools/elogind.run.fixed` (wait-on-pidfile run script; never signals the live daemon) + `/root/tools/re-fix-elogind-run.sh`, applies the fix at install time when SESSION_STACK=elogind, and re-applies it from /etc/rc.local on every boot since elogind package upgrades overwrite the package-owned run script. Validated across a reboot: `sv status`=run, `sv check`=ok, spam frozen, one early-boot line only | Beta-v2.9.72 below |
| **Beta-v2.9.74** | `[USB-AUTOMOUNT]` — a COSMIC install had no removable-media automounter: udisks2 was installed (as a cosmic-files dependency) but its D-Bus-only activation unit meant udisksd was never reliably running on runit, and there was no udiskie/gvfs in the COSMIC path (gvfs automount only covers the GNOME/KDE/Cinnamon/MATE/Xfce/LXQt branches). The COSMIC DE branch now installs `udiskie` and autostarts it via a session-readiness guard (`/usr/local/sbin/udiskie-guard`, mirroring the polkit-agent guard), and the installer writes + first-boot-links a supervised `/etc/sv/udisksd` service. `udiskie`/`udisks2` added to PKG_PREFLIGHT | Beta-v2.9.73 below |
| **Beta-v2.9.75** | `[XKB-CONFIG-QUOTING]` — the `cosmic-desktop-full` xbps post-install hook corrupts `/usr/share/cosmic/com.system76.CosmicComp/v1/xkb_config` to `layout: ""us"",` because it derives the layout with `layout=$(grep 'KEYMAP=' /etc/rc.conf \| cut -d= -f2)` — which KEEPS the quotes from `KEYMAP="us"` — and then `sed -i "s/us/$layout/"` interpolates them back in. That is invalid RON, so cosmic-comp fails to load its config (`errors loading cosmic-comp config: [RonSpanned(... ExpectedComma ... line 4, col 11)]`) and `cosmic-greeter-daemon` crash-loops (`check_children: greeter exited without creating a session`, `Error trying to flush the wayland display: Broken pipe`) into a grey, blinking login screen with no working VT switch. Found on <host> 2026-10-05 (twice — the first diagnosis blamed `/var/lib/cosmic-greeter/.local/state/cosmic-comp/outputs.ron`, which was a byte-identical, VALID copy). The COSMIC DE branch now rewrites the file to the canonical cosmic-config form with the layout taken UNQUOTED from the chroot's `/etc/rc.conf` `KEYMAP`, and only when the existing file does not already carry that exact `layout:` line (no-op when the hook happened to be correct). The upstream hook itself is also fixed at the source (`void-packages*/srcpkgs/cosmic-desktop-full/INSTALL`, revision bumped to `_3`) so a fresh install never writes the broken form. `bash -n` clean | Beta-v2.9.74 below |
| **Beta-v2.9.76** | `[COSMIC-TRUST-ANCHOR]` — the COSMIC repo sync passed `-y`, which xbps documents as "assume yes to ALL questions", including the repository signing-key import. The third-party repo's trust anchor was therefore auto-accepted and no operator ever saw a fingerprint, so a substituted key would be trusted silently. `-y` is now absent from that sync (the `-y` on the later package install is unrelated and intentionally stays), the expected fingerprint is printed, and an unattended run refuses up front with an actionable message instead of hanging or auto-accepting. Prompting alone is not enforcement — an operator who types `Y` at a prompt showing a substituted key still trusts it — so the fingerprint is now **pinned in the installer** and verified machine-readably after the sync: the pinned key must be present in `/var/db/xbps/keys`, and no key outside `{pinned, two stock Void keys}` may be. That second rule is an allowlist rather than "nothing else allowed", because a provisioned Void system already trusts both stock keys and rejecting them would abort every legitimate install. The pin is deliberately **not** read from the repo being verified: a fingerprint taken from the served index only proves the index is self-consistent, and an attacker controlling the repo would serve their own key alongside it. Unreadable keyring entries now fail closed instead of being silently skipped, and the keyring *filename* is not trusted either — key content is what gets compared. Three fingerprint-computation traps are handled explicitly, each of which otherwise yields a wrong-but-plausible hash rather than an error: the keyring blob decodes to PEM text and must be re-encoded to DER; `openssl dgst` on an empty stream returns the SHA-256 of the empty string, so the key is parsed with `openssl rsa -pubin -noout` before hashing; and DER must be streamed into `dgst` rather than captured in a shell variable, which strips NUL bytes. **Known consequence:** until the repo is republished under the new key this check ABORTS, because the live index still serves the old one — fail-closed by design, and it resolves on upload. `bash -n` clean; 13-case accept/abort matrix in `xkb_config-fix-20261005/test-trust-anchor-cases.sh`, which re-extracts this check from the installer on every run so the suite cannot drift | Beta-v2.9.75 below |
| **Beta-v2.9.98** | `[BR0-NAT-ONESHOT]` + `[BR0-NAT-BACKGROUND]` — the rc.local libvirt `default` NAT teardown (Beta-v2.9.96) no longer costs boot time. `/etc/runit/2` runs `rc.local` **synchronously before `runsvdir`**, so the teardown's wait loop (`virsh net-info default` polled up to 30× `sleep 1`) sat directly on the path to the display manager and **always burned its full 30 s**: libvirtd is started by `runsvdir`, so it is never up when the loop begins and every probe failed (measured on the operator's box 2026-10-17: kernel→Xorg 38.4 s, of which 30 s was this block). Two changes: **(1)** a **verified** teardown (`torn_down=yes`) now stamps `/var/lib/void-installer/br0-nat-torn-down.done` and the stamp's presence skips the block on every later boot (an unverified teardown still retries the next boot); **(2)** the whole block runs as `{ …; } &`, so `rc.local` returns immediately and even the first unstamped run cannot block the desktop — and because the backgrounded loop keeps polling while `runsvdir` starts libvirtd, it now actually **succeeds** mid-boot (previously impossible), gets verified, and stamps. Teardown semantics, the wired-NIC presence gate, the log and the `virbr0` cleanup are unchanged; the same box boots to Xorg in ~8 s. `bash -n`, `check-heredocs.sh`, `check-defaults.sh`, `check-pkg-preflight.sh` ALL CLEAN | Beta-v2.9.97 below |
| **Beta-v2.9.97** | `[LIMINE-NVRAM]` — re-adds the optional Limine UEFI NVRAM registration that first landed on the public export line at Beta-v2.9.92 (commit `ae72d75`, "feat(limine): add optional NVRAM entry, default off") and was then clobbered there by the Release-v2.9.93 source sync (`Source-Ref`) before any release shipped it — it was never present on this canonical line. A new `DEFAULT_LIMINE_NVRAM` toggle (default `false`) drives a Limine-only prompt; on `yes` the Stage-2 Limine deploy `install_pkgs efibootmgr` and runs `efibootmgr --create` pointing at `BOOTX64.EFI` (ESP disk/partition derived via `findmnt` + `lsblk`), in addition to the always-present removable/fallback path; failure is non-fatal. Default/no keeps the deploy byte-identical to the historical NVRAM-free behavior. The prompt accepts `y`/`yes`/`true` and `n`/`no`/`false` (the `[HEADLESS-PROMPT-LOOP]` lesson) so a true/false default can never loop. Threaded through the DRY-RUN plan, `chroot_env`, `limine-env`, `install-config` and the NEXT-STEPS text. `efibootmgr` was already in `PKG_PREFLIGHT`. `bash -n`, `check-heredocs.sh`, `check-defaults.sh`, `check-pkg-preflight.sh` ALL CLEAN | Beta-v2.9.96 below |
| **Beta-v2.9.96** | `[BR0-NAT-TEARDOWN]` + `[HEADLESS-PROMPT-LOOP]` — two fixes. **(1)** the libvirt `default` NAT teardown left the one-shot first-boot guard for the **every-boot** section of `/etc/rc.local`: it now polls until `virsh net-info default` actually succeeds (the old code trusted libvirtd's socket, which appears *before* the net is defined, so `net-destroy`/`net-autostart --disable` no-op'd under `|| true` — finding **F1**), destroys+disables then **verifies**, logs to `/var/log/void-br0-nat-teardown.log`, removes the orphaned `virbr0`, and only tears down when a physical wired NIC is present (a NIC-absent boot keeps the NAT fallback, so a virt box is never left with zero VM networking). **(2)** the two headless `[y/N]` opt-in prompts now accept `y`/`yes`/`true` and `n`/`no`/`false` case-insensitively, so bare Enter (= the `false` default) no longer loops forever. No prompt/default/package surface changed. `bash -n`, `check-heredocs.sh`, `check-defaults.sh`, `check-pkg-preflight.sh` ALL CLEAN | Beta-v2.9.95 below |
| **Beta-v2.9.95** | `[SSH-DEFAULT-HARDEN]` — the two `[SSH-SERVER]` access sub-prompts now default to the **secure** posture: `DEFAULT_SSH_PASSWORD_AUTH` `yes` → `no` and `DEFAULT_SSH_ROOT_LOGIN` `prohibit-password` → `no`, with the prompt labels flipped `[Y/n]` → `[y/N]`. A bare Enter can therefore no longer write a password-reachable sshd (`PasswordAuthentication yes` + `PermitRootLogin prohibit-password`); a `y` answer still yields exactly the previous values (`yes` / `prohibit-password`, i.e. public-key-only root login), so no prompt was removed — only the Enter-default moved. Server toggle, port, key prompts, packages and the prompt set are unchanged. This re-applies in the canonical source the hardening that had landed only on the public export (2026-10-15) and was then clobbered there by the Release-v2.9.93 source sync. `bash -n`, `check-heredocs.sh`, `check-defaults.sh`, `check-pkg-preflight.sh` ALL CLEAN | Beta-v2.9.94 below |
| **Beta-v2.9.94** | `[BASELINE-SNAPSHOT-FIRSTBOOT]` — the baseline snapper snapshot ("Baseline Automated System Installation") is **no longer taken at the end of the chroot install**; it is now created at the **end of the one-shot first-boot provisioning** in `/etc/rc.local`, right after the service symlinks (display manager, dbus, NetworkManager, polkitd, ...) are linked and right before the `/var/log/firstboot.log` marker is written. Root cause: those symlinks are the only thing that starts the greeter/desktop and they are created at **first boot** (deferred from the install), so the install-time snapshot captured a console-only system — rolling back to it, or booting it from the GRUB/Limine snapshot menu, landed on a bare `agetty` instead of the greeter, and the rollback could not self-heal because `/var/log/firstboot.log` lives on the separate `@log` subvolume (never restored by an `@` snapshot), so `rc.local` skipped first-boot provisioning on the restored system. Snapshotting after provisioning makes the baseline a fully-functional, rollback-ready clean-system image. The existing `[ ! -f /var/log/firstboot.log ]` guard already makes this exactly-once, so **no self-deleting script/cron is needed**. The install-time `41_snapshots-btrfs` `chmod -x`/`+x` dance (which only existed to keep the just-created snapshot out of the initial `grub-mkconfig`) is removed; `grub-mkconfig` now runs normally and the first-boot snapshot is picked up afterwards by `grub-btrfsd` (GRUB) or the Limine snapper plugin. Install-success NEXT-STEPS text updated to state the baseline is taken on first boot. `bash -n`, `check-heredocs.sh`, `check-defaults.sh`, `check-pkg-preflight.sh` ALL CLEAN | Beta-v2.9.93 below |
| **Beta-v2.9.93** | `[OCTOXBPS-NOPASS-POLKIT]` — when `INSTALL_OCTOXBPS=true`, Stage 2 now also deposits a polkit **action + rules** pair (`/usr/share/polkit-1/actions/99-octoxbps-check-nopass.policy`, `/etc/polkit-1/rules.d/90-octoxbps-nopass.rules`) that allows **passwordless repository sync** (`xbps-install -Sy` / `-Syy`) for active, local users in `wheel`, suppressing the OctoXBPS notifier's startup / network-reconnect password prompt; installing and updating packages still requires normal authentication. *(Backfilled entry: the release commit bumped `SCRIPT_VERSION` to Beta-v2.9.93 but predated its changelog row.)* | Beta-v2.9.92 below |
| **Beta-v2.9.92** | `[COSMIC-TOUCHPAD-RCLICK]` — new **opt-in COSMIC-only** prompt: "Configure COSMIC touchpad right-click (two-finger tap + corner-click)? [y/N]", default OFF. cosmic-settings ships `input_touchpad` with `click_method:Some(Clickfinger)` which on real hardware (AMD Ryzen x360 laptop) yields no usable right-click; the proven daily-driver fix is a per-user override with `click_method:Some(ButtonAreas)` (bottom-corner right-click; two-finger tap preserved via the shipped `button_map:Some(LeftRightMiddle)`). Stage-2 deposits the override **derived** from the in-tree shipped default (`sed` of only the `click_method` token — never a stale hardcoded struct), per-user only (greeter untouched), with a fallback canonical write if the shipped file/token is absent. Guard + chown follow the dotfile-deposit pattern. `bash -n`, `check-heredocs.sh` ALL CLEAN, `check-defaults.sh` ALL CONSISTENT, `check-pkg-preflight.sh` ALL COVERED | Beta-v2.9.91 below |
| **Beta-v2.9.91** | `[COSMIC-GREETER-DEFAULT]` — cosmic-greeter becomes the **recommended/default DM for the COSMIC DE** (was SDDM). The old preference traced to a maintainer report that the greeter could not recognize elogind sessions; real hardware (COSMIC 1.10 + cosmic-greeter) sessions cleanly under elogind and is the daily driver, so `RECOMMENDED_DM="cosmic-greeter"` for COSMIC, the DM prompt's Debug caveat is removed, and the Enter-default now follows `RECOMMENDED_DM` exactly as it already does for KDE/GNOME/etc. No package/prompt-index/default changed; pairing text + header comment updated. `bash -n`, `check-heredocs.sh` ALL CLEAN, `check-defaults.sh` ALL CONSISTENT, `check-pkg-preflight.sh` ALL COVERED | Beta-v2.9.90 below |
| **Beta-v2.9.90** | `[COSMIC-PPD]` — COSMIC's `cosmic-settings` hard-depends on `power-profiles-daemon` (D-Bus `net.hadess.PowerProfiles`), yet nothing ever linked its runit service, so the DE's powermode picker showed **"Backend not found"** while tlp (laptop profile) ran alongside as the second power manager — a documented PPD+tlp conflict. The Stage-1 resolution now derives `POWER_PPD=true` for EVERY COSMIC build and suppresses tlp on COSMIC laptops (`PROFILE_TLP=false` for the install + first-boot link sites); COSMIC builds install `power-profiles-daemon` (added to `PKG_PREFLIGHT`) and first-boot-link `/etc/sv/power-profiles-daemon`. Scope is COSMIC-only — all other DEs keep the existing tlp laptop behavior. Proven on the reference install (AMD Ryzen laptop): PPD drives `quiet/balanced/performance` through `amd_pstate` + the firmware `platform_profile`; tlp/tlp-rdw removed. `bash -n`, `check-heredocs.sh` ALL CLEAN, `check-defaults.sh` ALL CONSISTENT, `check-pkg-preflight.sh` ALL COVERED | Beta-v2.9.89 below |
| **Beta-v2.9.89** | `[SMART-BASELINE]` — smartmontools now ships on EVERY install regardless of DE / greeter / profile (added to the unconditional roll-up line), so a S.M.A.R.T. health baseline (`smartctl -a`) exists on day one — found when the first post-install audit box's healthy 1 TB NVMe could only be verified because the operator had added the package by hand. The `smartd` monitoring daemon stays unenabled by default (operator choice). New package on the always-on surface; no prompt/default changed; `smartmontools` also added to the stage-1 validation-only `PKG_PREFLIGHT` superset per the `[PKG-PREFLIGHT]` drift-guard rule. `bash -n`, `check-heredocs.sh` ALL CLEAN, `check-defaults.sh` ALL CONSISTENT, `check-pkg-preflight.sh` ALL COVERED | Beta-v2.9.88 below |
| **Beta-v2.9.88** | `[SSH-IMPORT-VALIDATE]`+`[SSH-USABLE]`+`[SUBVOL-GATE-VALIDATE]`+`[BROWSE-ALIAS-ESC]` — an imported SSH key is now verified **before** it is trusted: `ssh-keygen -y` reads unencrypted keys and derives a matching `.pub` from the private key itself (the `${file}.pub` sibling is no longer required), a passphrase-protected key is unlocked with a one-shot in-memory passphrase prompt and verified with it, and anything `ssh-keygen` cannot read is rejected with an ERROR instead of being staged silently; the fingerprint is shown for confirmation. The deposited key is now actually usable: `~/.ssh/config` gains the `IdentityFile` (append-only, existing config preserved) and the imported public key is appended to `~/.ssh/authorized_keys`, so key login to the fresh box works from any client holding the private half. The two bulk `[Y/n/i]` subvolume gates no longer silently bulk-default on unrecognized answers — a stray keystroke (observed live: a lone period at the Gate-1 prompt) previously flipped every app's isolation decision — and a bare Enter now resolves to the documented yes/no default instead of leaking the boolean knob into a per-app walk; the per-app `_subvol_ask` prompts re-ask on junk too. `browse_pick` control words (`..`/`m`/`drives`/`!`/`ok`) now also accept shell-escaped spellings (`\..`, `\!`, `\ok`) — the observed "ok shown as \ok" was a typed `\ok` rejected as a bad path. No prompt/default/package surface changed. `bash -n`, `check-heredocs.sh` ALL CLEAN, `check-defaults.sh` ALL CONSISTENT, `check-pkg-preflight.sh` ALL COVERED | Beta-v2.9.87 below |
| **Beta-v2.9.87** | `[COSMIC-REPO-MOVE]` — the COSMIC artifact repository is now served from the unified `Void_Linux_Cosmic` project (packaging templates + signed binary repo together): `_cosmic_repo`/`_cosmic_repodata`/`_cosmic_audit` point at `https://bluesloth.github.io/void-linux-cosmic/` (audit `github.com/bluesloth/void-linux-cosmic`), which serves the signed index from its repository root. The **pinned signing key is unchanged** (`83ffd154…d2e7b`), so the machine-checked trust anchor is identical — only the served location moved. Text-only: every code path, prompt, default and package surface unchanged. `bash -n`, `check-heredocs.sh` ALL CLEAN, `check-defaults.sh` ALL CONSISTENT, `check-pkg-preflight.sh` ALL COVERED | Beta-v2.9.86 below |
| **Beta-v2.9.86** | `[BR0-SKIP]` — a virt install on a machine with **no physical wired NIC at all** (pure-Wi-Fi/WWAN) no longer writes a dead `br0` + free-roaming role-matched `br0-slave` and then force-kills virbr0 on first boot — that combination left the "bridged" build with **zero VM networking** while the slave sat ready to adopt whatever USB NIC / tethering phone appeared later (the round-10 topology: `BR0_NIC="<unset>"`, `enp*` placeholder, `br0` with no member). The skip trigger is a new `has_wired_nic_hw()` hardware-presence predicate (physical `device` link + no `wireless` dir + name skip list; carrier/USB irrelevant) rather than `detect_wired_nic()`'s result — a cable-unplugged built-in port therefore keeps the role-matched slave (plugging in later still works) while a wired-less box skips; an EMPTY `NET_INTERFACE_MATCH` is the explicit skip signal, already threaded through resume-state + chroot_env, and it gates the Stage-2 profile pair, qemu's `bridge.conf` allow, and a new `install-config` `VIRT_BR0` row (created / skipped / n/a); rc.local tears virbr0 down only when the `br0.nmconnection` file exists (disk-state check, no NM timing), so virbr0 stays **enabled** as the VM-networking fallback — `[NFT-VIRT-GATE]`'s `virbr*` forward accepts already cover it firewall-side. NOTICEs at the virt block, the re-probe and the write site; auto-skip, no new prompt/defaults/packages. `bash -n`, `check-heredocs.sh` ALL CLEAN, `check-defaults.sh` ALL CONSISTENT, `check-pkg-preflight.sh` ALL COVERED | Beta-v2.9.85 below |
| **Beta-v2.9.85** | `[NIC-DETECT-USB]` — the Stage-1 `[NIC-DETECT]` review's USB fallback globbed `/sys/devices/*/net/*` — bash `*` never crosses a `/`, so it only ever matched `/sys/devices/virtual/net/*` (lo/br0/docker0/virbr0), every one of which fails the usb-subsystem test: **dead code that could never detect real hardware** (a USB NIC's `net` dir sits ~6 levels deep, e.g. `…/usb2/2-1/2-1.1/2-1.1:1.0/net/<iface>`). A physically-present-but-unplugged USB ethernet adapter — the documented "cable optional" promise — therefore always read `(none detected …)` and was recorded `BR0_NIC="<unset>"`: live on the round-10 box (ASIX AX88179 present, `install-config` says `<unset>`). The INSTALL_VIRT late re-probe's fallback (`readlink -f device` ~ `*usb*`) was correct, so the `br0-slave` binding itself never suffered — but the two probe sites could disagree (and the review's carrier loop had no physical-device check at all). Both sites now call one shared `detect_wired_nic()` helper — carrier-active physical wired NIC first, then any physically-present USB device regardless of carrier — defined at unconditional top level above the resume guard (2.9.78's `_region_fs_of` lesson), with the protection sets merged (`device` link + no `wireless` dir + name skip list: the re-probe gains the name skip, so a Bluetooth-USB netdev can no longer qualify as a "USB NIC"). No prompt/defaults/package surface changed. `bash -n`, `check-heredocs.sh` ALL CLEAN, `check-defaults.sh` ALL CONSISTENT, `check-pkg-preflight.sh` ALL COVERED | Beta-v2.9.84 below |
| **Beta-v2.9.84** | `[COSMIC-STORE]`/`[FLATPAK-PULL-DETECT]` — `cosmic-store` (the bluesloth COSMIC app store) hard run-depends on `flatpak`, but the installer never installed it, so the prompt gate intentionally preconditioned `INSTALL_FLATPAK` — an opt-out of Flatpak had no store to drag it back in. Two layers: (1) a real opt-in prompt `INSTALL_COSMIC_STORE` (default NO), offered ONLY when `INSTALL_FLATPAK=true` (any desktop — the store is a Flathub GUI), threaded through resume-state/chroot_env/install-config, and installed DE-independently at the flatpak-gated deliveries site via `install_cosmic()` with a Stage-2 flatpak re-check mirroring the Brave rule — a stale resume state carrying store=yes && flatpak=no WARNs and skips, never pulling flatpak in; (2) a Stage-2 `[FLATPAK-PULL-DETECT]` safety net: if flatpak is DECLINED but shows up installed anyway (a future metapackage rev or a manual install), the install warns loudly and records `FLATPAK_PULLED_BY="<reverse deps>"` (from `xbps-query -X flatpak`) in `install-config` — the "never let the store pull flatpak past an explicit opt-out without surfacing it" rule, enforced even when no prompt was involved. `bash -n`, `check-heredocs.sh` ALL CLEAN, `check-defaults.sh` ALL CONSISTENT, `check-pkg-preflight.sh` ALL COVERED | Beta-v2.9.83 below |
| **Beta-v2.9.83** | `[COSMIC-REPO-ATTRIBUTION]` — the COSMIC disclosure named the wrong repo: the DE menu (option 7), the ARCHITECTURE SUMMARY and `install_cosmic()`'s own header comment all pointed the operator at a third-party packaging fork's repo (a git host and package host we do not control) as the source being trusted — but the URL the installer has actually added since Beta-v2.9.73 is `https://bluesloth.github.io/void-linux-cosmic/` (audit `github.com/bluesloth/void-linux-cosmic`), signed and published by the companion `Void_Linux_Cosmic` packager project from templates it builds from scratch. A third-party trust warning is only useful if the name and link in it are the ones you actually audit, so this mattered: it named a repo the installer never contacted, while two comments still carried claims that had since inverted or been superseded — "the documented old github.io URL is now stale — it serves a web page, not an xbps index" (github.io now serves a working `x86_64-repodata`; it is the upstream host that went unused) and "the repo's signing key is whatever the maintainer publishes with the repo" (superseded by the Beta-v2.9.76 pin). Menu + comments now carry the real repo URL, its audit link, its lineage and the pinned-key statement; CHANGELOG entries written before 2.9.73 stay as history. Text-only: `_cosmic_repo`, `_cosmic_audit`, `_cosmic_key_expected` and every code path unchanged. `bash -n`, `check-heredocs.sh` ALL CLEAN, `check-defaults.sh` ALL CONSISTENT, `check-pkg-preflight.sh` ALL COVERED | Beta-v2.9.82 below |
| **Beta-v2.9.82** | `[COSMIC-KEY-AUTOIMPORT]` — the COSMIC repo sync still stopped at `Do you want to import this public key? [Y/n]` even though the desktop menu already discloses COSMIC as a third-party repo ("a signing-trust choice made at your own risk — audit the repo before installing") and Beta-v2.9.76 already pins the key and machine-verifies it right after the sync. Re-verified 2026-10-07 on xbps 0.60.7 that `-y` never covered this question in the first place — bare `-S` and `-Sy` both stop at `[Y/n]` — so Beta-v2.9.76's "-y made the anchor auto-accepted" mechanism was wrong, and what 2.9.76/2.9.77 actually built was an interactive confirmation layered on top of a check that never needed one. The prompt is now answered by the installer itself on a **pipe of its own** (`printf 'y\n' \| xbps-install … -Sy`), which is neither the chroot's stdin (Stage 2 feeds the script via `chroot /mnt /bin/bash << 'CHROOT_EOF'`, so stdin IS the heredoc — 2.9.77's original abort) nor `/dev/tty` (unattended runs have none — 2.9.77's second abort, which refused every headless COSMIC install outright); that `/dev/tty` gate is removed with it, so unattended COSMIC installs now run. **Trust is unchanged:** the pinned-fingerprint + allowlist machine check below the sync still aborts unless the keyring holds exactly the pinned key plus at most the two stock Void keys, so a substituted key fails through the same code path — auto-answering removed friction, not enforcement, and an operator typing `Y` at a substituted-key prompt would have trusted the attacker anyway. Proven live 2026-10-07 against the real repo: fresh throwaway keyring, auto-answer imports the key non-interactively, and the shipped `cosmic_key_fingerprint()` reproduced the pinned `83ffd154…d2e7b` from what got imported. `printf 'y\n'` (not `yes`) is deliberate: one answer, then EOF fails loudly, and `yes` would fail the pipeline under `pipefail` via SIGPIPE even after a successful sync. `bash -n`, `check-heredocs.sh` ALL CLEAN, `check-defaults.sh` ALL CONSISTENT, `check-pkg-preflight.sh` ALL COVERED, packager-side 13-case trust-anchor suite re-extracted and green | Beta-v2.9.81 below |
| **Beta-v2.9.81** | `[SSH-KEYGEN-NONINTERACTIVE]` — the generate-key branch built `-N` as `${SSH_KEY_PASSPHRASE:+-N ...}`, so answering `n` at "Protect the key with a passphrase?" **omitted `-N` entirely** — and omitting `-N` means "prompt me", not "no passphrase". ssh-keygen therefore still asked `Enter passphrase for "…/id_ed25519" (empty for no passphrase)` (and fired `ksshaskpass` wherever `SSH_ASKPASS` is set) after the operator had already declined, and the read that answers it can swallow the next answer-stream line — the same desync class `[SSH-KEYGEN-STALE]` (2.9.54) fixed for the `Overwrite (y/n)?` prompt. `-N` is now ALWAYS passed, with `""` for the unprotected case (`-N ""` is ssh-keygen's documented "no passphrase, do not ask" form); the now-dead `SC2086` disable that justified the old zero-arg expansion was dropped with it. Reported live 2026-10-07. `bash -n`, `check-heredocs.sh` ALL CLEAN, `check-defaults.sh` ALL CONSISTENT, `check-pkg-preflight.sh` ALL COVERED | Beta-v2.9.80 below |
| **Beta-v2.9.80** | `[MIRROR-SKEW-GUARD]` — upstream Void mirror rotation desync: the index lists an old version whose pool files were just rotated away (`runc` 1.5.1_1→1.5.2_1, 2026-10-07); every official tier indexed 1.5.1_1 while the pool carried only 1.5.2_1, so the 3-mirror fallback failed identically and `install_pkgs podman` FATALed mid-transaction (404 on the `.sig`). Three-layer fix: (1) all three mirror rotations gain tertiary region fallbacks (`REPO_EXTRA1` repo-de / `REPO_EXTRA2` tuna) that rotate on their own schedule, threaded through state-file persist + `/mnt/tmp/chroot_env.sh`; (2) `install_pkgs()` captures its transcript and classifies the `failed to download <pkg> ' signature from <repo>: Not Found` error, retrying the full rotation with 15/30/45 s backoff (3 rounds) before FATAL — non-skew failures fail immediately exactly as before; (3) Stage-1 `[PKG-PREFLIGHT]` adds a per-mirror `-M` memory-sync consistency probe on the enabled container/bootstrap closure (base-system always; + runc/podman when `INSTALL_PODMAN`; + docker when `INSTALL_DOCKER`), promoting the first consistent mirror to `REPO_PRIMARY` pre-write and WARN+continuing when all are torn (never a pre-write FATAL for a transient; absent `curl` skips the probe, preserving `[PREREQ-CURL]`). `bash -n`, `check-heredocs.sh` (the `install_pkgs` edit is inside `CHROOT_EOF`), `check-defaults.sh`, `check-pkg-preflight.sh` ALL CLEAN | Beta-v2.9.79 below |
| **Beta-v2.9.79** | `[XKB-CONFIG-CREATE]` — the Beta-v2.9.75 repair was gated on `[ -f "$_xkb_conf" ]`, so it could only REPAIR a corrupt `xkb_config`, never CREATE a missing one. No package ships that file; only the `cosmic-desktop-full` post-install hook creates it, inside its `UPDATE="no"` arm, and on the <host> 2026-10-05 resumed install it did not complete (its other side effects are only partial: `10-wireplumber.conf` present, `20-wireplumber-pulse.conf` and `/etc/xdg/autostart/pipewire.desktop` absent). The file was therefore ABSENT — which is fatal, not cosmetic: cosmic-comp reports no xkb config → cosmic-greeter `UserData.xkb_config_opt` is `None` → `Common::update_user_data` (`src/common.rs:203-208`, vec initialised empty at `:118`) skips the entire `active_layouts` fill → the keyboard-layout button indexes an empty vec at `src/greeter.rs:590` and the greeter **PANICS** (`index out of bounds: the len is 0 but the index is 0`). greetd then loops `check_children: greeter exited without creating a session` every ~1.6 s: 25 panics over 24 min across three boots, `pam_authenticate: AUTHTOK_ERR`, empty `wtmp` (no login ever succeeded), no VT switch, and a 65 MB / 946,952-line `cosmic-greeter-session.log` from ~945,960 `cosmic-osk` "Broken pipe" lines. Stage 3 still reported `Install COMPLETED successfully`, and the archived script's sha256 matched repo HEAD — the installer was not at fault for reporting success, the failure is entirely at first boot. The COSMIC DE branch now ENSURES the file (`[ ! -f … ] ||` + `mkdir -p` + write) instead of depending on the packager's hook, keeping the `grep` guard so an already-correct file stays a no-op. `KEYMAP` extraction also accepts a **bare** `KEYMAP=de` (what `Void_Linux_Live` writes) as well as `KEYMAP="de"`, via the same quote-stripping sed the fixed hook uses — the old quoted-only pattern silently fell back to `us`, installing the wrong keyboard layout — plus a `case` token guard so no hostile `rc.conf` value can be interpolated into the RON string. `bash -n` clean, `check-heredocs.sh` ALL CLEAN, `check-defaults.sh` ALL CONSISTENT, `check-pkg-preflight.sh` ALL COVERED, plus an 8-case standalone exercise of the ensure-logic | Beta-v2.9.78 below |
| **Beta-v2.9.78** | `[MULTI-FS-RESUME-HELPER]` — a resumed (`-r`) install aborted in Stage 1 with `Failing command : _region_fs_of "$_rr"` and exit 127 (command not found). Root cause: `_region_fs_of()` and `_region_carved()` were defined at the top of the BETA-v2.9.66 `[SUBVOL-GATES]` resolver, which sits INSIDE the `if [ "$RESUME" != "1" ]` interactive-config block — a skipped block on a resumed run — while their call sites (region mount block at old-line ~6277, fstab loop at ~6410, mkfs loop at ~5831, subvol-list builders at ~5984/6013/6202+) are outside. Fresh installs never noticed because the definitions ran before any call site; resumed runs died the first time the region loop reached `_rr_fs="$(_region_fs_of "$_rr")"`. Definitions now sit at unconditional top level above the resume guard. `bash -n` clean, `check-heredocs.sh` ALL CLEAN, `check-defaults.sh` ALL CONSISTENT | Beta-v2.9.77 below |
| **Beta-v2.9.77** | `[COSMIC-TRUST-ANCHOR-TTY]` — the Beta-v2.9.76 trust-anchor gate aborted EVERY COSMIC install: it refused to run unless stdin was a tty (`[ ! -t 0 ]`), but Stage 2 feeds the chroot via `chroot /mnt /bin/bash << 'CHROOT_EOF'`, so stdin is always the heredoc text and the gate always fired ("session has no terminal" at the key-confirmation step, even on a fully interactive run). The gate now probes the real terminal (`[ -r /dev/tty ] && [ -w /dev/tty ]` — /dev is bind-mounted into the chroot and the chroot's controlling tty is the operator's terminal) and routes the key-import prompt to it (`xbps-install -Sy < /dev/tty`). Verified live 2026-10-05: the COSMIC repo now serves exactly the pinned key (DER SHA-256 `83ffd154…d2e7b` matches `_cosmic_key_expected`), so the anchor check passes once the operator confirms the prompt. `bash -n` clean, `check-heredocs.sh` ALL CLEAN, `check-defaults.sh` ALL CONSISTENT | Beta-v2.9.76 below |


---

## Beta-v2.9.39 — `[CRASH-USB-LOG-FATAL-EXIT]` + `[SUBVOL-ROWS-FIX]` (crash post-mortem also fires on planned FATALs; SUBVOL_ROWS parse fixes)

`SCRIPT_VERSION = Beta-v2.9.39`. The crash-dump plumbing tightened up and the
`SUBVOL_ROWS` table parser was hardened.

**1. `[CRASH-USB-LOG-FATAL-EXIT]` — the post-mortem USB dump now also fires on
planned `exit 1` aborts.** The ERR trap handles failures inside `set -eEo`
traps, but an explicit `exit 1` FATAL never trips ERR — so planned aborts
(disk validation, package preflight) silently skipped the USB snapshot. A
`_save_log_on_exit` EXIT trap (guarded by a `_usb_dumped` flag so an ERR-unwind
and the EXIT trap never double-write) now dumps the journal even on a fatal
exit. This also fixed the spurious crash-#005 reporting BMP (a FATAL that had
been classed as the signal exit path when it was actually a planned abort).

**2. `[SUBVOL-ROWS-FIX]` — comment rows and a duplicate row in the
`SUBVOL_ROWS` table.** The read loop now skips `#`-comment rows before the
resolve `eval` (a comment row previously hit bad-substitution and crashed under
the ERR trap). A spurious duplicate `INSTALL_BREW` SUBVOL_ROWS row was also
removed.

**Validation:** `bash -n` and `checks/check-heredocs.sh` ALL CLEAN.

---

## Beta-v2.9.40 — `[PKG-PREFLIGHT]` + `[GAME-FLATPAK-GATE]` (Stage-1 package-name gate; Heroic/Bottles now Flatpak-queue-only)

`SCRIPT_VERSION = Beta-v2.9.40`. Closes crash #005 permanently and ends the
heroic/bottles xbps dependency class.

**1. `[PKG-PREFLIGHT]` — Stage-1 package-name gate.** Every package name the
Stage-2 chroot can install is resolved against the live union pool **BEFORE
`sgdisk -Z`**, so a doomed install (a package that doesn't exist in the repos
or whose deps can't resolve) aborts pre-write with the disk untouched. The
`PKG_PREFLIGHT` candidate list is kept a superset of every `install_pkgs`
literal plus the base-bootstrap literals; the `void-repo-*` package
install + `xbps-install -Sy` repos refresh + `base-system` sanity probe are
best-effort and **degrade to WARN+skip (never a false FATAL)** so a repo or
network hiccup can't kill a good install. The COSMIC third-party repo is
excluded from the probe. The drift-guard `checks/check-pkg-preflight.sh` is
committed so future package additions can't silently outgrow the probe list.

**2. `[GAME-FLATPAK-GATE]` — Heroic/Bottles ship only via the Flatpak queue.**
`install_pkgs heroic` / `install_pkgs bottles` are FORBIDDEN (no official Void
package, crash #005 class). Both game launchers are delivered through the
first-boot Flatpak queue (`com.heroicgameslauncher.hgl` /
`com.usebottles.bottles`) gated on `INSTALL_FLATPAK`, with a Stage-2 WARNING
when Flatpak was declined. The `@game` subvolume mounts ONLY
`.local/share/Steam` + `.local/share/lutris`.

**Validation:** `bash -n`, `checks/check-pkg-preflight.sh` (134-pkg collection,
ALL COVERED), `checks/check-defaults.sh`, and `checks/check-heredocs.sh` all
green on the committed tree.

---

## Beta-v2.9.41 — (intermediate build) `98void-inner-partscan` module draft

`SCRIPT_VERSION = Beta-v2.9.41` (intermediate build). Drafted the boot-time
inner-GPT partscan dracut module (`98void-inner-partscan`): module-setup.sh +
udev rules + helper script skeleton. Crash #008 had proven dracut's crypttab
`partscan` option is NOT reliable on non-loopback LUKS2 at boot — the instance
unlocked (PTTYPE="gpt" on the mapper) but the inner partition
nodes/by-uuid symlinks never registered, so `root=UUID=<inner btrfs>` "does
not exist" stranded boot. This intermediate build carried no prompt/header
changes; it was folded into the released `[INNER-PARTSCAN-BOOT]`
(Beta-v2.9.43).

**Validation:** `bash -n` CLEAN.

---

## Beta-v2.9.42 — (intermediate build) FATAL initramfs gate + parted shipping

`SCRIPT_VERSION = Beta-v2.9.42` (intermediate build). Added the FATAL
initramfs-content gate (verify after `dracut --force` that every `/boot`
kernel image actually carries the partscan helper / cryptsetup / parted bits,
aborting before the ESP re-sync) and `parted` shipping into the target
whenever the module installs. Crash #009 showed `partx -a` cannot BLKPG a dm
mapper ("error adding partitions" on the opened LUKS2), so images built at
Beta-v2.9.41/42 booted to the emergency shell despite the module. Folded into
the released `[INNER-PARTSCAN-DMPROBE]` work (Beta-v2.9.45).

**Validation:** `bash -n` CLEAN.

---

## Beta-v2.9.43 — `[INNER-PARTSCAN-BOOT]` (boot-time partscan dracut module for the carved inner GPT)

`SCRIPT_VERSION = Beta-v2.9.43`. The boot-time mirror of the MULTI-FS + ENCRYPT
inner-GPT story: a LUKS2 container wraps an inner GPT, but dracut's crypttab
`partscan` is unreliable (crash #008), so the installer ships its own module.

**`98void-inner-partscan`** is written into the chroot ONLY when
`ENCRYPT=yes` AND a `REGION_PARTITIONED` carve exists. On boot, a udev RUN
fires the instant the opened LUKS2 mapper's `DM_NAME` appears, calling a
partprobe + `partx -a` helper to force-register the inner GPT **BEFORE
dracut's udev settle resolves `root=UUID=<inner btrfs>`**. `parted` is now
shipped into the target whenever the module installs, the `__CRYPT_NAME__`
token is baked in via sed, `add_dracutmodules` uses the short module name in
`90-system.conf`, and the module is placed BEFORE the final
`xbps-reconfigure` so the first boot already carries it. A plain (no-regions)
ENCRYPT layout does not enable the module.

**Validation:** fresh-install initramfs content verified in the chroot gate;
`bash -n`/`check-heredocs.sh` CLEAN.

---

## Beta-v2.9.44 — `[DRACUT-CONF-NAME]` (short module name in `add_dracutmodules`)

`SCRIPT_VERSION = Beta-v2.9.44`. Closed the crash #009 residual: the
`add_dracutmodules` conf value MUST be the **short module name WITHOUT the
numeric prefix** (`void-inner-partscan`, not `98void-inner-partscan`). dracut-ng
resolves conf names as `[0-9][0-9]<name>`, so a prefixed name matches nothing
and the regen died with "Module cannot be found". The same rule applies to
`99void-yubikey` → `void-yubikey`. The on-disk module keeps its `NN-` prefix;
only the `add_dracutmodules` conf string is unprefixed.

**Validation:** `bash -n` CLEAN.

---

## Beta-v2.9.45 — `[INNER-PARTSCAN-DMPROBE]` (partprobe-first inner-GPT rescan)

`SCRIPT_VERSION = Beta-v2.9.45`. Finalized the boot-time partscan: the helper
now runs **partprobe first** (it builds libparted dm-linear submaps — the ONLY
tool that can BLKPG a dm mapper), with `partx -a` as fallback only. The inline
blocks are replaced by named `_region_inner_partscan` + `_region_inner_dev`
functions, and the live + resume paths are rewired to call them. Added: the
chroot FATAL initramfs-content gate (after the `dracut --force` loop, before
the ESP re-sync), a per-image guard in `void-limine-sync-kernels` (a broken
initramfs can never overwrite the ESP's last-known-good copy), a `partx -d`
unwind in `cleanup_on_failure` before `luksClose`, and `parted` added to
`PKG_PREFLIGHT` whenever the module installs.

**Validation:** `Debug/LIVE-VALIDATION-RUNBOOK.md` updated; the
ENCRYPT+regions boot-to-desktop path is real-hardware proven.

---

## Beta-v2.9.46 — five post-audit fixes from the first real ENCRYPT+regions boot

`SCRIPT_VERSION = Beta-v2.9.46`. The first true ENCRYPT+regions install on
`<host>` produced five code-only fixes (`0a60f06`):

- **`[SUBVOL-TOOL-RESOLVEDEV]`** — `void-subvol-tool.sh` strips the `[/@]`
  suffix from `findmnt` SOURCE before mounting the `subvolid=5` root, and the
  shadowed `awk -v sub=` variable is renamed to `svpat`.
- **`[INSTALL-CONFIG-FLATPAK]`** — install-config gains the public
  `INSTALL_FLATPAK` / `INSTALL_BRAVE` rows.
- **KERNEL_PKGS / PKG-PREFLIGHT verification** — the installed kernel set and
  the preflight list stay consistent with what was actually installed.
- **`[VBOX-SV-GUARD]`** — the first-boot vboxdrv runsvdir link is guarded on
  `/etc/sv/vboxdrv` existing (a host without the service dir no longer gets a
  dangling link).
- **`[FLATPAK-NM-DISPATCH-STAMP]`** — the first-boot Flatpak queue dispatch is
  verified after the NetworkManager/D-Bus handoff instead of blindly firing.

**Validation:** `bash -n` + all committed Debug gates CLEAN.

---

## Beta-v2.9.47 — `[TEE-BOOT-QUIET]` + `[TEE-BLACKLIST]` (env-driven cmdline knobs, persisted)

`SCRIPT_VERSION = Beta-v2.9.47` (`47e7ad6`). Two env-only PUBLIC limine-env
knob rows (`DEFAULT_QUIET_BOOT`, `DEFAULT_TEE_BLACKLIST`, both default no)
thread into a shared `TEE_QB_FRAG` ("quiet" +
"modprobe.blacklist=tee") that is threaded through **every** GRUB/Limine
`BASE_CMD` builder AND the limine write-conf recompute (which runs on every
kernel update / snapper-plugin resync), so a hand-edited fragment can never
silently vanish on the next resync — the exact drift-class
`[LIMINE-WALLPAPER]` forbids. Output is byte-identical at defaults; existing
installs are untouched until the knobs are flipped.

**Validation:** `bash -n` + all committed Debug gates CLEAN.

---

## Beta-v2.9.48 — `[NO-DE]`/`[NO-DM]`/`[HEADLESS]`/`[HEADLESS-XORG-OPT]`/`[HEADLESS-AUDIO]`/`[DE-ORDER]`/`[DISK-BUDGET]` (headless/server install path + pre-write partition budget)

`SCRIPT_VERSION = Beta-v2.9.48` (`6a0e932`). The headless/server install path
and a pre-write disk-fit check.

**1. `[NO-DE]` / `[DE-ORDER]` — desktop options.** The DESKTOP_ENV menu is
reordered most→least popular (KDE, GNOME, Cinnamon, Xfce, MATE, LXQt, COSMIC)
with KDE staying option 1 and the bare-Enter default; option 8 is now `none`
(console-only / headless base). `RECOMMENDED_DM` gains `none) = "none"`. The
KDE catch-all `else` in the desktop-install chain becomes an explicit
`elif [ "$DESKTOP_ENV" = "kde" ]` so a `none` (or any non-KDE) selection
skips the metapackage. The Falkon Qt-WebEngine notice handles `DESKTOP_ENV=none`.

**2. `[NO-DM]` — display-manager `none`.** The DISPLAY_MANAGER menu gains
`none` (index 5 on the COSMIC branch / 4 otherwise so 1/2/3 stay stable).
`DM_SERVICE_NAME="none"` installs no DM package and creates no
`/etc/sv/none` symlink; the first-boot rc.local DM link is now guarded by
`[ "__DISPLAY_MANAGER__" != "none" ] && ln -sfn ...` (sed substitution
unchanged).

**3. `[HEADLESS]` — `HAS_GRAPHICAL`.** Computed after the DM prompt:
`DE != none AND DM != none`. When unset, the xorg/wayland base chain (and the
audio install) are skipped — a headless box gets only the session stack +
network layer. The chroot env threads `HAS_GRAPHICAL`/`INSTALL_XORG`/
`INSTALL_AUDIO` (in-chroot `set -u` defaults yes/false/true), and the chroot
`DESKTOP_ENV`/`DISPLAY_MANAGER` validations accept `none`.

**4. `[HEADLESS-XORG-OPT]` / `[HEADLESS-AUDIO]` — headless opt-ins.** On a
headless box, `INSTALL_XORG` (keeps the Xorg/Wayland base for a later startx /
VNC WITHOUT flipping HAS_GRAPHICAL) and `INSTALL_AUDIO` are explicit opt-in
prompts wired to the new `DEFAULT_XORG`/`DEFAULT_AUDIO` bare-Enter knobs.
Graphical installs keep audio unconditional; a declined headless audio gets no
dangling ALSA/jack/wireplumber/limits symlinks or rtprio file.

**5. `[DISK-BUDGET]` — pre-write partition fit check.** `DISK_BYTES` is
captured at disk-pick via `lsblk -bdn -o SIZE` and persisted for resumed runs
(fails open on unreadable). `_size_to_bytes()` converts human/sgdisk sizes
(KB/MB/GB/TB/KiB/MiB/GiB/TiB/PiB) to exact bytes; `_disk_budget_check()`
sums the ESP + every carved REGION_*_SIZE + a >= 1 GiB system headroom and
compares against the real disk. An over-provisioned layout is refused with a
CRITICAL breakdown **BEFORE `sgdisk -Z`**, and `--dry-run` also fails to
launch on an over-provision. ENCRYPT uses the same container=remainder identity
math.

**6. Latent 2.9.38 fix surfaced by the budget.** The 2.9.38 MULTI-FS carve
evals read `REGION_${_rr}_SIZE` with lowercase `REGION_PARTITIONED` tokens
while the size vars are stored UPPERCASE — now `${_rr^^}_SIZE` in all three
eval sites (outer carve, inner carve, `_region_sizes_sum`) so the budget and
the carve agree; without it any carved region FATALed ("size is unset") on a
real install.

**Validation:** gates on the committed tree `6e3e0c4` — `bash -n` OK;
`checks/check-defaults.sh` 71 ALL CONSISTENT (DEFAULT_XORG + DEFAULT_AUDIO
added); `checks/check-pkg-preflight.sh` 135 ALL COVERED (143 install_pkgs +
bootstrap literals); `checks/check-heredocs.sh` 65 ALL CLEAN.
`_size_to_bytes`/`_disk_budget_check` unit-tested standalone (fits / over /
ESP-only-1G / exactly-fit / unreadable).

---

## Beta-v2.9.49 — `[VERIFY-FIXES]` (post-verification corrections proven against the live as-built machine)

`SCRIPT_VERSION = Beta-v2.9.49`. Verification of the reconstructed 2.9.48
against the recovered as-built machine (`Recovered-Corpus-2026-09-13/` +
live `<host>`, 2026-09-14) surfaced six divergences; five are fixed here.

**1. `[WINE-RENAME]` — the wine prompt variable was `INSTALL_GAME_WINE`.**
The draft's wine prompt (top `[PROMPT-DEFAULTS]`: `DEFAULT_GAME_WINE`) and its
read branch exported `INSTALL_GAME_WINE`, but every other consumer — the
install-config writer, DRY_RUN plan, chroot_env.sh, the `install_pkgs wine`
gate, and the as-built record (`GAMING=… wine …`) + recovered prompt docs
(`INSTALL_WINE` at byte offset 49804 of `recovered_INSTALL_PROMPTS.md`) — uses
`INSTALL_WINE`. With mismatched names the chroot `install_pkgs wine` gate
silently read the wrong variable and never installed Wine even when the prompt
said yes. Renamed to `INSTALL_WINE`/`DEFAULT_WINE` everywhere (12 refs +
defaults); zero `GAME_WINE` remain and `bash -n` + `check-defaults` pass.

**2. `[FLATHUB-URL-FIX]` — remote-add shipped the bare website URL.**
Both flathub `remote-add` sites used `https://flathub.org`, which is the
*website* (its root 307-redirects to `/en/`) and — when added as a remote — a
location that carries no GPG keyring at all. A flatpak queue then always died
with `flathub: public key not found for correction … is not trusted`. Fix
(proven on the live box, 2026-09-14): use the canonical manifest file
`https://flathub.org/repo/flathub.flatpakrepo`, which carries BOTH the correct
base URL (`https://dl.flathub.org/repo/`) and the signing key. Applied to the
install-time add (`[FLATHUB-CHROOT]` stub + real chroot add) and the first-boot
rc.local fallback (`[FLATHUB-RCL]`), each with a `[FLATHUB-URL-FIX]
(Beta-v2.9.49)` note.

**3. `[DOCS-LOG-ASBUILT]` — the record header is now the as-built row set.**
The recovered real record (`Documents_Void_Install.txt` lines 8-25) lists —
in order — DESKTOP_ENV, SSH_SERVER (port + `policy:` pointer),
NVIDIA_DRIVER (`GPU:` + `wifi:`), WIFI_HARDWARE (`0xVVVV:0xDDDD` id),
CPU (vendor + microcode pkg), HOMEBREW (`deps: git/curl/file via xbps;
install the prefix yourself` + `isolation:`), GAMING (enabled-launcher list,
`heroic(flatpak)`-tagged, `@game isolation:`), DATA_REGIONS (ALL SIX locations
`name:fs,` fixed order, games only when `!=none`). The draft instead wrote
BR0_NIC/MICROCODE_PKG rows (not in the as-built) and a carved-regions-only
DATA_REGIONS. The writer now reproduces the as-built byte-format and drops the
two invented rows. The CPU row re-derives the vendor in-chroot from
`/proc/cpuinfo` (same hardware as the live probe) and prints the microcode pkg
verbatim. All vars consumed (`INSTALL_SSH_SERVER`/`SSH_PORT`,
`INSTALL_NVIDIA`/`GPU_FAMILIES`/`WIFI_HW`/`WIFI_IDS`, `MICROCODE_PKG`,
`INSTALL_BREW`/`PROVISION_LINUXBREW_SUBVOL`,
`INSTALL_STEAM`/`INSTALL_LUTRIS`/`INSTALL_HEROIC`/`INSTALL_BOTTLES`/`INSTALL_WINE`/
`INSTALL_GAMEMODE`/`PROVISION_GAME_SUBVOL`, `REGION_*_FS`/`REGION_GAMES`) are
exported into the chroot, so the header is complete and truthful.

**4. `[FW-AUDIT-LOG-DROP]` — the as-built record has no firmware section.**
Beta-v2.9.33's `[FW-AUDIT-LOG]` appends the firmware accounting into
`~/Documents/Void_Install.txt` after the package inventory. The recovered real
record (the authoritative as-built) ends at the package list (`zxing-cpp-3.1.1_1`)
with NO `# -------- FIRMWARE ACCOUNTING … --------` section — the append never
fired on the real build. To reproduce the proven machine, the record append is
dropped; the `[FW-AUDIT]` accounting itself remains and still prints to the
install log/console (report-only, unchanged).

**5. Divergence examined and left as-is:** the recreated script writes a `BR0_NIC`
legacy variable header it never populates on the 2.9.48-era path
(`SYSPREFIX_BTRFS` dead-data equivalent) — harmless, no behavior change.

**Validation:** gates on the fixed tree — `bash -n` OK;
`checks/check-defaults.sh` ALL CONSISTENT (DEFAULT_WINE rename ok);
`checks/check-pkg-preflight.sh` 135 ALL COVERED;
`checks/check-heredocs.sh` 65 ALL CLEAN. The flathub `.flatpakrepo` fix is
real-hardware proven (all three queued apps installed, stamp-on-success).

---

## Beta-v2.9.50 — `[BROWSE-DIR-ACCEPT]` (browse_pick dir-mode could never confirm a destination; the SSH keypair backup never reached the USB stick)

`SCRIPT_VERSION = Beta-v2.9.50`. Human review of the reconstruction against the
as-built machine (2026-09-14): the `[SSH-KEYS]` (Beta-v2.9.23) "Export a backup
copy of the SSH keypair to removable media" flow physically could not write to
the stick.

**Root cause — `browse_pick` `dir` mode had no accept action.** Selecting a
directory (number or typed path) descended INTO it (`_bp_start=…; continue`),
bare Enter was a DECLINE by design (empty input → "Declined." → return empty),
and the only exit that set `_bp_ok=1` required a FILE (`[ -f ]`). A directory
destination could therefore never be returned: `_export_dst="$(browse_pick
dir …)"` always came back empty → `"No destination chosen; skipping export."` →
`id_ed25519-backup{,.pub}` never reached the mounted stick. This matches the
real v2.9.43 build: the live machine's `~/.ssh/id_ed25519` exists (the chroot
deposit is a different, working code path), but no `id_ed25519-backup` exists
anywhere on disk or at the `/run/media/<user>` stick mount.

**Fix `[BROWSE-DIR-ACCEPT]`:** in `dir` mode, `!`/`ok` now confirms the CURRENT
directory and returns it (the help text advertises it). Bare Enter still
declines; number/path navigation is unchanged. The wallpaper (`img`) and
SSH-import (`file`) modes return a FILE and were never affected.

**Validation:** `bash -n` OK; `checks/check-defaults.sh` ALL CONSISTENT;
`checks/check-pkg-preflight.sh` ALL COVERED; `checks/check-heredocs.sh` ALL
CLEAN (no heredoc changed).

---

## Beta-v2.9.51 — `[BROWSE-CAP-FIX]` (browse_pick's menu UI was captured into its own return value; the wallpaper pick aborted every Limine run that answered the prompt)

`SCRIPT_VERSION = Beta-v2.9.51`. Found live during the first `--dry-run` of this
installation, 2026-09-15: the answer stream walked cleanly through every prompt
to the Limine wallpaper browser and then aborted — the run died not on a wrong
input but on the browser itself.

**Root cause — stdout is the return channel.** `browse_pick` is called
exclusively through command substitution: `WP_SRC="$(browse_pick img …)"` for
the wallpaper ([LIMINE-WALLPAPER-BROWSE], Beta-v2.5.4) and
`_export_dst="$(browse_pick dir …)"` for the SSH-keypair backup export
([SSH-KEYS], Beta-v2.9.23). Under `$( )`, bash captures **all** of the
subshell's stdout into the variable — and the browser printed its menu/help
text, its item listing, and its `-- Select` prompt to stdout. So:

- **Wallpaper (`img`):** `WP_SRC` came back as the whole multi-line banner
  ending in the chosen path, and the stage-copy `cp -f "$WP_SRC" "$WP_STAGED"`
  FATALed with `cp: cannot stat '<banner text>': No such file or directory`.
- **SSH export (`dir`):** `_export_dst` came back banner-prefixed, so the
  `[ -d "$_export_dst" ]` guard always failed → "No destination chosen;
  skipping export." — every time, regardless of what was browsed.
- **No answer could dodge it:** even a bare-Enter DECLINE breaks the loop with
  an empty selection, but the menu banner had already been written to stdout
  during that pass, so the captured "selection" was still the non-empty banner.
  In practice this meant **any Limine install that was so much as asked about
  the wallpaper aborted** (the Unix exit was swallowed by the crash/journal
  path, so it read as a generic fail), and the SSH keypair export was silently
  a no-op even after the [BROWSE-DIR-ACCEPT] `!` fix — the accept ran in the
  loop, but its result was still mangled by the captured banner above it.

The [BROWSE-DIR-ACCEPT] (Beta-v2.9.50) analysis was therefore only half the
story: it fixed the *navigation/accept* layer, but the *capture* layer it ran
under was broken all along. The SSH export "never reached the stick" on the
real v2.9.43 build fits both (this live machine's dry-run reproduced the exact
same "skipping export." symptom before the wallpaper crash pre-empted it).

**Fix `[BROWSE-CAP-FIX]`:** every menu/help/listing/prompt line inside
`browse_pick` now writes to **stderr** (`>&2` — the same pattern `_subvol_ask`
already uses so its prompt text survives `$( )`, per §3.23-era notes); only the
final `printf '%s' "$_bp_src"` stays on stdout. The `$( )` capture therefore
sees exactly the picked value: the wallpaper `cp` gets a real path, and the SSH
export `[ -d ]` check sees a real directory. The already-`>&2` error lines
("Declined.", "File not found", etc.) are unchanged.

**Validation:** `bash -n` OK; `checks/check-defaults.sh` ALL CONSISTENT;
`checks/check-pkg-preflight.sh` ALL COVERED; `checks/check-heredocs.sh` ALL
CLEAN (no heredoc changed). Unit repro of the capture before/after:
`WP_SRC="$(browse_pick img …)"` returned the banner before the fix and the bare
path after.

---

## Beta-v2.9.52 — `[PREREQ-DRY-RUN]` (a --dry-run plan run died on the [PREREQ] gate instead of printing the plan)

`SCRIPT_VERSION = Beta-v2.9.52`. Found during the first full `--dry-run` of
this installation, 2026-09-15: after the browse fix let the run reach the
confirmation boundary, this medium — a Void Live box without `gptfdisk`
preinstalled — produced:

```
==> [DRY-RUN] Skipping live-CD package sync (would install gptfdisk/parted/btrfs-progs/openssl into the live env).
FATAL: required live-CD command not found: 'sgdisk'.
```

**Root cause — the sync-skip and the prereq gate disagree.** Beta-v2.5.1
[DRY-RUN] makes a plan run skip the live-CD package sync (which in a real run
installs `gptfdisk`/`parted`/`btrfs-progs`/`openssl` into the live env) and
marks `LIVECD_SYNC_OK=1` so the flow continues. The Beta-v2.4.1 [PREREQ] gate
right behind it then checks that those exact outer-stage tools exist — but on a
minimal medium they were never installed, so the check FATALed:
"required live-CD command not found: 'sgdisk'". The dry-run therefore died at
the confirm-settings boundary, before the DRY-RUN plan printout that the whole
exercise exists to show.

**Fix `[PREREQ-DRY-RUN]`:** the gate is now skipped entirely when
`DRY_RUN=1`, with an explicit `==> [DRY-RUN] Skipping [PREREQ] outer-tool
check …` notice. The gate's only job is to keep a REAL run from reaching
destructive partitioning without the tools it relies on; a plan run never
partitions, so requiring the tools is wrong there. With the skip, the plan
run flows from the confirmation boundary straight into the DRY-RUN plan
printout and exits without touching the disk. A real (non-dry) run still runs
the sync AND the gate exactly as before.

**Validation:** `bash -n` OK; `checks/check-defaults.sh` ALL CONSISTENT;
`checks/check-pkg-preflight.sh` ALL COVERED; `checks/check-heredocs.sh` ALL
CLEAN (no heredoc changed). Full `--dry-run` re-run on the target medium now
reaches the plan printout and exits 0.

---

## Beta-v2.9.53 — `[HEADLESS-PLAN-LABEL]` (the DRY-RUN plan called a graphical box "headless=yes")

`SCRIPT_VERSION = Beta-v2.9.53`. Cosmetic print-only fix, 2026-09-15: reading
the very first full DRY-RUN PLAN (after the 2.9.51/2.9.52 fixes let it print)
showed the Desktop/DM line as `mate / lightdm (headless=yes)` — the plan was
echoing `headless=$HAS_GRAPHICAL` verbatim, but `HAS_GRAPHICAL=yes` means the
DE/DM combo is GRAPHICAL (it is only `no` when DE and DM are BOTH `none`).
The label therefore read "headless=yes" on a graphical install and
"headless=no" on a genuinely headless one — exactly inverted.

**Fix `[HEADLESS-PLAN-LABEL]`:** the plan now prints `(graphical)` when
`HAS_GRAPHICAL=yes` and `(headless)` otherwise. The value's real semantics
were always correct (the intro screen still showed `MATE / LightDM` and the
xorg/session gating is driven by `$HAS_GRAPHICAL`, not this string); only the
human-readable label in the dry-run printout was wrong.

**Validation:** `bash -n` OK; `checks/check-defaults.sh` ALL CONSISTENT;
`checks/check-pkg-preflight.sh` ALL COVERED; `checks/check-heredocs.sh` ALL
CLEAN (no heredoc changed). Dry-run plan on the target medium now reads
`(graphical)` for the MATE/LightDM setup.

---

## Beta-v2.9.54 — `[SSH-KEYGEN-STALE]` (a leftover /tmp/ssh-keygen made a re-run silently eat the export answer)

`SCRIPT_VERSION = Beta-v2.9.54`. Found 2026-09-15 while inspecting the
second full `--dry-run` transcript: the answer stream walked the SSH prompt
group, and the keypair line read

```
/tmp/ssh-keygen/id_ed25519 already exists.
Overwrite (y/n)?   Generated keypair → /tmp/ssh-keygen/id_ed25519{,.pub} (comment '<user>@<host>')
-- Export a backup copy of the SSH keypair to removable media? [y/N]:
```

The FIRST dry-run had generated a keypair into `/tmp/ssh-keygen` and exited
normally at the plan — a path neither the failure cleanup (line 1298) nor the
post-chroot shred (line 11667) runs on. `ssh-keygen -f` then hit its own
"Overwrite (y/n)?" prompt and consumed the NEXT answer-stream line — the
`y` meant for "Export a backup copy…". That export prompt next received the
browse *path*, which its `case` treated as a decline, so the keypair backup
was silently skipped (and the browse-path/`!`/disk answers shifted down, only
absorbed because the DRY-RUN still reached the plan).

**Root cause — two layers:** (1) stale stage state on a medium whose `/tmp`
outlives a run (tmpfs on a fresh boot clears it, so this only bites reruns,
resumes, and dry-runs on the same boot — exactly this box, which had run the
dry-run minutes before); (2) the generate branch never made `ssh-keygen`
non-interactive, so the overwrite prompt VOIDED the deterministic answer
stream on such media. On a real install (or dry-run) following a run on the
same boot, the [SSH-KEYS] backup export — the feature this whole browser
series restores — would have been declined by a misdirected answer with no
error and no trace.

**Fix `[SSH-KEYGEN-STALE]`:** (a) the generate branch now drops stale
`$SSH_KEYGEN_DIR/id_ed25519{,.pub}` (`rm -f … || true`) right before
`ssh-keygen`, so generating is always a fresh non-interactive keygen; (b) the
DRY-RUN exit path now shreds the live `/tmp/ssh-keygen`/`/tmp/ssh-import`
stage exactly like the failure and post-chroot cleanups do, so a plan run
never leaves key material behind either. The interactive-passphrase and
export flows are unchanged.

**Validation:** `bash -n` OK; `checks/check-defaults.sh` ALL CONSISTENT;
`checks/check-pkg-preflight.sh` ALL COVERED; `checks/check-heredocs.sh` ALL
CLEAN (no heredoc changed). Re-run of the full `--dry-run` shows no
"Overwrite (y/n)?" prompt, the export browse runs, and the live key stage is
shredded at plan-run exit.

---

## Beta-v2.9.55 — `[INNER-DEV-NAME]` (ENCRYPT+regions install crashed immediately: region device `void-rootp1` vs `void-root1`)

`SCRIPT_VERSION = Beta-v2.9.55`. Found on the FIRST REAL INSTALL of this
reconstruction, 2026-09-15 (<host>-env live box, nvme0n1): the run passed the
dry-run plan, wiped the disk, carved the outer ESP + LUKS container, opened
the LUKS2 mapper, carved the inner GPT inside it, verified the passphrase —
then died:

```
==> Carving inner GPT inside /dev/mapper/void-root (MULTI-FS + ENCRYPT)...
... (sgdisk warnings: "kernel is still using the old partition table") ...
mkfs.fat 4.2 (2021-01-31)
FATAL: region device /dev/mapper/void-rootp1 for 'games' does not exist (partscan?).
!! Crash post-mortem saved to /run/media/anon/void-installer-crash-*.log (+.info) — evidence for triage.
```

**Root cause — the `p` separator is device-name dependent, and the inner
carve hardcoded the wrong one.** The outer disk carve already knows this:
`[[ "$DISK" =~ (nvme|mmcblk) ]]` gets `nvme0n1p1` (the firmware/path name as
shown embeds a trailing digit, so the kernel inserts `p`), while `sda`,
`vda`, etc. get plain `sda1`. The inner GPT carved inside an OPENED LUKS2
mapper is partitioned on a **dm-linear device** `/dev/mapper/void-root`,
whose basename ends in `-root` (NOT a digit) — so the kernel names its
children `void-root1`, `void-root2`, WITHOUT the `p`. But `_region_inner_dev`
(Beta-v2.9.45, the [INNER-PARTSCAN-DMPROBE] helper) hardcoded
`${CRYPT_DEV}p${N}` → `/dev/mapper/void-rootp1`. The `_region_inner_partscan`
had faithfully registered the real nodes with the kernel (`partprobe` did its
job: `/dev/mapper/void-root1` and `void-root2` existed on the box at crash
time) — the FATAL was purely a WRONG DEVICE NAME, not a missing partscan. The
region fs-format step resolved `REGION_PART_games=/dev/mapper/void-rootp1`,
`[ -e ]` was false, and the run aborted. (The dry-run never saw this because
it stops before any partition/format; the partscan wiring only executes on the
real write path.)

**Fix `[INNER-DEV-NAME]`:** `_region_inner_dev` now makes the same separator
decision the outer carve makes — dm-linear basename ends with a digit gets
`p` (`void-rootp1`), otherwise no separator (`void-root1`). Both the per-region
`REGION_PART_*` devices and `BTRFS_DEV` (the mapper-p(NREG+1) Btrfs root)
follow the rule.

**Why the dry-run couldn't catch this:** DRY-RUN exits at the plan boundary,
before `sgdisk -Z`/partscan/format ever run, so the [PREREQ-DRY-RUN] and
[BROWSE-CAP-FIX] gates can't protect the ENCRYPT+regions write path. Only the
first REAL install exercises it — hence this session's ladder of 2.9.51→2.9.55.

**Validation:** `bash -n` OK; `checks/check-defaults.sh` ALL CONSISTENT;
`checks/check-pkg-preflight.sh` ALL COVERED; `checks/check-heredocs.sh` ALL
CLEAN (no heredoc changed). `_region_inner_dev` unit-checked against
`CRYPT_DEV=/dev/mapper/void-root` (→ `void-root1`/`void-root2`) and a
hypothetical digit-suffixed mapper (→ `p1/p2`). A full re-run of the real
install exercises the crash point on the live box (see Work State).

---

## Beta-v2.9.61 — `[LOCAL-CACHE-ROOT]` (a `--persist` live stick's seeded cache sits at live-root `/xbps-cachedir-<arch>` — outside the `[LOCAL-CACHE]` detector's `/run/media` glob — so the detect pass now also probes live-root)

`SCRIPT_VERSION` stays at the era checkpoint; era row added to the script header VERSION-HISTORY, index row added below the 2.9.60 index row, this section added as the newest section.

Beta-v2.9.59's `[LOCAL-CACHE]` auto-detector matches only `/run/media/*/xbps-cachedir-*` — the conventional mklive/void-live layout on an attached medium. A NEW deployment model is the `voidlive-build-persist.sh` `--persist` + `--seed-cache` stick from the `Void_Linux_Live` fork: the live ISO is built with `rd.overlay=LABEL=VOID_OVL`, the flashed stick carries an ext4 `VOID_OVL` partition, and `--seed-cache` copies the raw `.xbps` cache into the ROOT of that partition. On boot dracut mounts the `VOID_OVL` partition as the overlay upper layer, so the seeded cache is visible at `/xbps-cachedir-<arch>` in the live rootfs — writable (it IS the persistence layer), arch-matched, full of real `.xbps` files, but NOT under `/run/media`, so the 2.9.59 detector silently ignored the very cache the persist stick was designed to ship.

Fix: the detector's candidate glob list now also probes the live-root path:

```
done < <(ls -1dt /run/media/*/xbps-cachedir-* /xbps-cachedir-* 2>/dev/null)
```

- On an ordinary (non-persistent) boot the `/xbps-cachedir-*` term matches nothing, so the added glob is a no-op; only a `--persist` stick that seeded its overlay root produces a hit.
- All existing sanity checks still apply unchanged (writable, `xbps-cachedir-<arch>` suffix against `uname -m`, real `*.xbps` present), and the first match by newest dir mtime still wins — so a live session with the data stick ALSO attached prefers whichever cache was touched most recently.
- The cached dir is the live overlay upper layer, writable by the root installer; a later `install_pkgs` `-Sy` refresh updates the repodata in the overlay exactly as on any other medium, and the persistence layer carries it across reboots.

Recovered single-stick flow: flash the persist stick with `voidlive-build-persist.sh build --persist --seed-cache ... --cache /run/media/<user>/<uuid>/xbps-cachedir-x86_64` (absolute path to the populated cache), boot it anywhere, install with the installer — the "Local package cache" prompt now auto-detects `/xbps-cachedir-x86_64` from the overlay and the offline answer is a plain `Y`.

Validation: `bash -n` OK.

## Beta-v2.9.62 — `[LOCAL-CACHE-DEPTH]` (the `/run/media` auto-detection only probed ONE level deep, so a cache on an udisks-mounted `/<user>/<uuid>` data stick was never found)

`SCRIPT_VERSION` stays at the era checkpoint; era row added to the script header VERSION-HISTORY, index row added below the 2.9.61 index row, this section added as the newest section.

`[LOCAL-CACHE]` (v2.9.59) and `[LOCAL-CACHE-ROOT]` (v2.9.61) probed `/run/media/*/xbps-cachedir-*` — a glob with exactly **one** wildcard level between `/run/media` and the cache. But udisks mounts a storage stick at `/run/media/<user>/<label-or-uuid>` — TWO levels — and the unlabeled data stick holding this project's populated `xbps-cachedir-x86_64` mounts as `/run/media/<user>/<uuid>/xbps-cachedir-x86_64`. That is the exact "cache on a separate data stick next to the VOID_LIVE stick" layout the feature was built for; every such boot fell past detection to the typed-path prompt, making the recoverable offline flow a manual ordeal (it worked only because `installer-watch.sh` passed an explicit `--cache` path).

Fix: the candidate glob list now also probes the depth-2 layout:

```
done < <(ls -1dt /run/media/*/xbps-cachedir-* /run/media/*/*/xbps-cachedir-* /xbps-cachedir-* 2>/dev/null)
```

- Depth-1 (`/<mount>/xbps-cachedir-*`), depth-2 (`/<user>/<uuid>/xbps-cachedir-*`) and the live-root persist seed (`/xbps-cachedir-*`) all share the same existing first-wins rule: newest dir mtime, writable, `xbps-cachedir-<arch>` suffix against `uname -m`, real `*.xbps` files present.
- On a single-stick persist boot the depth-1/2 terms match nothing and only `/xbps-cachedir-*` fires; on a plain media boot only the depth-1/2 terms matter — each glob is a no-op where it does not apply.
- Mirrored fix in the `Void_Linux_Live` fork (`voidlive-build-persist.sh _cache_detect()`), so the build host auto-finds the same top-level cache when `--cache` is omitted.

Validation: `bash -n` OK; as root, `_local_cache_detect()` returns `/run/media/<user>/<uuid>/xbps-cachedir-x86_64` on the <host> layout (previously empty).

## Beta-v2.9.63 — `[LOCAL-CACHE-ERR]` (the cache detector's `ls` process substitution returned exit 2 on every real run and the ERR trap aborted the install at the cache prompt even when the cache was found)

`SCRIPT_VERSION` stays at the era checkpoint; era row added to the script header VERSION-HISTORY, index row added below the 2.9.62 index row, this section added as the newest section.

`[LOCAL-CACHE]`/`[LOCAL-CACHE-ROOT]`/`[LOCAL-CACHE-DEPTH]` feed the read loop from a process substitution:

```
done < <(ls -1dt /run/media/*/xbps-cachedir-* /run/media/*/*/xbps-cachedir-* /xbps-cachedir-* 2>/dev/null)
```

`ls` exits **2** on a missing operand. A glob that matches nothing stays **literal** (no `nullglob`), so whenever any of the three globs fails to match — which is the normal case on any given layout: e.g. `/xbps-cachedir-*` never exists except on a seeded persist stick — `ls` returns 2 even while successfully listing a sibling that DID match. The stderr was already silenced (`2>/dev/null`), which hid the message but not the status.

The shell's `set -eE` (line 549) arms an ERR trap (`trap cleanup_on_failure ERR`, line 1429); errtrace propagates that trap into the `$( ... )` command substitution at the call site:

```
AUTO_LOCAL_CACHE=$(_local_cache_detect || true)
```

The `|| true` guards the CALL — it cannot protect a failure that fires while `_local_cache_detect` is still running inside the subshell. So on every matching run the install printed the correctly detected cache path, then aborted at the cache prompt:

```
!! Install failed (exit 2). Failure trace logged to /tmp/void-installer-journal.log. Attempting best-effort unwind of /mnt...
  Auto-detected cache on an attached medium: /run/media/anon/<uuid>/xbps-cachedir-x86_64
-- Use a local package cache? [y/N] or type an absolute path: !! Unwind attempted. Re-check 'mount | grep /mnt' before re-running.
!! Crash post-mortem saved to /run/media/anon/void-installer-crash-...
```

with the journal's fatal line:

```
Exit code       : 2
Failing command : ls -1dt /run/media/*/xbps-cachedir-* /run/media/*/*/xbps-cachedir-* /xbps-cachedir-* 2> /dev/null
```

Fix: `|| true` on the `ls` itself so the process substitution can never carry a non-zero status; the read loop simply consumes whatever matched:

```
done < <(ls -1dt /run/media/*/xbps-cachedir-* /run/media/*/*/xbps-cachedir-* /xbps-cachedir-* 2>/dev/null || true)
```

This is exactly the form `Void_Linux_Live/voidlive-build-persist.sh _cache_detect()` already used (`... || true`) on both of its `ls` lines — the installer's detector was the lone divergence, so the fork stays in lockstep with no further change.

Validation: the crash was reproduced live as root against the repo script (identical result to the target's desktop copy: `rc=2`, same trace); after the `|| true` the root run sails past detection to the cache prompt and the install proceeds normally. `bash -n` clean.

## Beta-v2.9.64 — `[PARTSCAN-HOST-COPY]` (dracut resolves udev `RUN=` programs against the build HOST, so every initramfs build logged the cosmetic "Skipping program /usr/bin/void-inner-partscan.sh ... as it cannot be found")

`SCRIPT_VERSION` stays at the era checkpoint; era row added to the script header VERSION-HISTORY, index row added below the 2.9.63 index row, this section added as the newest section.

The `98void-inner-partscan` dracut module writes its udev rule (RUN reference) and helper into the module dir, and module-setup's `inst_script $moddir/void-inner-partscan.sh /usr/bin/void-inner-partscan.sh` embeds the helper into every initramfs. The image was always correct — but dracut's udev-rule post-processing (`_inst_rule_programs` in `dracut-functions.sh`) also tries to resolve each `RUN=` program:

```bash
elif ...; then
    _bin=$(find_binary "$_prog") || {
        dinfo "Skipping program $_prog using in udev rule ${1##*/} as it cannot be found"
        continue
    }
```

The resolution is against the build host root (`find_binary` on PATH/absolute path with `dracutsysrootdir`), never the module dir. At dracut time `/usr/bin/void-inner-partscan.sh` exists only as `$moddir/void-inner-partscan.sh`, so every build printed:

```
dracut[I]: Skipping program /usr/bin/void-inner-partscan.sh using in udev rule 10-void-inner-partscan.rules as it cannot be found
```

That log line accompanied the very first LT-PC install's initramfs generation. It is cosmetic (lsinitrd on the built images shows `usr/bin/void-inner-partscan.sh`, the udev rules, `kpartx`, `partprobe`, and `cryptsetup` all present), but it recurs on the installed system's own kernel updates — every dracut run scans the rule again.

Fix: the module-write step now also materializes the helper at the target's real `/usr/bin`:

```bash
cp -f /usr/lib/dracut/modules.d/98void-inner-partscan/void-inner-partscan.sh /usr/bin/void-inner-partscan.sh
chmod 0755 /usr/bin/void-inner-partscan.sh
```

The scan then resolves `/usr/bin/void-inner-partscan.sh` and embeds it via `inst_binary` — the dinfo disappears from all future initramfs builds, and the installed system gains a directly-inspectable copy for boot troubleshooting (same `install_items+=" /usr/bin/btrfs "` precedent already in `90-system.conf`). The `$moddir` copy and the `inst_script` line are unchanged and remain the image's source of truth.

Validation: applied live to the current install's chroot (`/mnt/usr/bin/void-inner-partscan.sh`, 02:36, 1795 bytes, 0755) so that box's next kernel update is already quiet; the already-built initramfs images were left untouched (verified correct). `bash -n` clean on the installer.

## Beta-v2.9.98 — `[BR0-NAT-ONESHOT]` + `[BR0-NAT-BACKGROUND]` (the rc.local libvirt NAT teardown moves off the boot critical path)

`SCRIPT_VERSION` bumped to Beta-v2.9.98.

### The problem

`/etc/runit/2` executes `/etc/rc.local` **synchronously before** `runsvdir`, so
everything in `rc.local` sits directly on the path to the display manager. The
Beta-v2.9.96 `[BR0-NAT-TEARDOWN]` block runs there on **every boot**, and its
wait loop —

```sh
while [ "$_vt_i" -lt 30 ]; do
    virsh --connect qemu:///system net-info default >/dev/null 2>&1 && … && break
    _vt_i=$((_vt_i + 1)); sleep 1
done
```

— could **never** succeed: libvirtd is itself started by `runsvdir`, which has
not run yet when `rc.local` does, so every `virsh` probe fails and the loop
always burns its full budget of 30 × `sleep 1`. Beta-v2.9.96's
`--connect qemu:///system` (commit `88f4b4d`) had already removed virsh's own
30 s socket-hunt, leaving this loop as the remaining cost.

measured on the operator's box (Beta-v2.9.96 install, 2026-10-17 12:47
boot): kernel start ≈ 12:47:46 → `rc.local`'s fast steps at 12:47:53 →
`[BR0-NAT] ready=no` at **12:48:23** (exactly the 30 s loop) → Xorg at 12:48:24
(`Xorg.0.log` kernel-uptime 38.36 s). Meanwhile NetworkManager activated `br0`
itself at 12:48:26 — 2 s *after* Xorg started — so br0/the bridge profile was
never the delay; the teardown block keyed off it was.

### The fix (two layers)

- **`[BR0-NAT-ONESHOT]`** — the teardown is a completed one-time migration, not
  a recurring chore. When it is **verified** (`torn_down=yes`, i.e. `default`
  inactive *and* not autostart) the block stamps
  `/var/lib/void-installer/br0-nat-torn-down.done`; the gate also tests the
  stamp's absence, so every later boot skips the block outright (a single
  `[ -f … ]`, zero cost). The stamp is written **only on a verified teardown**,
  so a half-done one still retries on the next boot.
- **`[BR0-NAT-BACKGROUND]`** — the whole block runs as `{ …; } &`, so `rc.local`
  returns immediately and `runsvdir` (and thus SDDM) starts without waiting.
  Belt-and-braces: even the **first**, unstamped run cannot block the desktop —
  and because the backgrounded loop keeps polling while `runsvdir` starts
  libvirtd seconds later, it now actually **succeeds** mid-boot (impossible
  before), gets verified, and stamps. From the second boot on, the block is the
  stamp check alone.

Unchanged: the teardown semantics (poll-until-defined, destroy + disable,
verify, log every outcome to `/var/log/void-br0-nat-teardown.log`, best-effort
`virbr0` removal), the physical-wired-NIC presence gate (a NIC-absent boot keeps
libvirt's `default` NAT as the VM-networking fallback), and all failure-tolerant
`|| true` / `|| :` handling.

Same box after the on-target patch: kernel→Xorg **~8 s** (was 38.4 s); the
remaining ~7 s is stage-1/root-mount/`vkpurge` work before `rc.local`, unrelated
to br0.

Gates: `bash -n`, `check-heredocs.sh`, `check-defaults.sh`,
`check-pkg-preflight.sh` ALL CLEAN.

## Beta-v2.9.97 — `[LIMINE-NVRAM]` (the optional Limine UEFI NVRAM registration is re-added to the canonical source, default off)

`SCRIPT_VERSION` bumped to Beta-v2.9.97.

### What was lost, and why re-apply instead of resurrect

The OPTIONAL Limine "register a UEFI NVRAM boot entry" feature was added on
**2026-10-15** as `ae72d75` *"feat(limine): add optional NVRAM entry, default
off"*, documented in `d5fc61e`/`f53bb9a`, and reordered ahead of the wallpaper
prompt in `a16db02`. All of those commits live on the **public export line** —
the independent history rooted at `126b67b` *"Initial public release:
void-linux-installer"* (tip `baa986b`). They are not ancestors of this canonical
line (root `52637c6`).

`cf95f80` *"Release v2.9.93"* carries `Source-Ref: ab95cb0` and **regenerated
`Void_Linux_Installer.sh` from this canonical private source**, which never had
the feature: `LIMINE_NVRAM` went from 14 references at `edd99ca` to **0** at
`cf95f80`, and the whole export line was later discarded from the public remote
(now a fresh single-commit snapshot `1d61390`). The feature therefore survives
only as orphaned git objects, unreachable from any ref.

Rather than cherry-pick dead objects, this re-applies the work cleanly on the
canonical line — exactly the treatment the sibling SSH-hardening from that same
export line received as Beta-v2.9.95 `[SSH-DEFAULT-HARDEN]`.

### Behaviour

- New `DEFAULT_LIMINE_NVRAM="${DEFAULT_LIMINE_NVRAM:-false}"` — a **yes/no
  toggle** in the project's literal-`true`/`false` default convention, default
  **off**.
- Limine-only prompt, asked **before** the wallpaper prompt (matching
  `a16db02`'s final order):

  ```text
  Limine NVRAM registration
    Register a UEFI NVRAM boot entry pointing at Limine's BOOTX64.EFI
    via efibootmgr? The default ('no') keeps the removable/fallback
    boot path only (current behaviour); 'yes' adds an explicit entry.
  Register Limine NVRAM entry? [y/N] (default N):
  ```

- The `case` accepts `y`/`yes`/`true` and `n`/`no`/`false` — the
  `[HEADLESS-PROMPT-LOOP]` lesson from Beta-v2.9.96 — so a bare Enter resolves
  against `DEFAULT_LIMINE_NVRAM` and a `true`/`false` default can never fall
  through and loop. The persisted value stays `yes`/`no`.
- On `yes`, the Stage-2 Limine deploy (right after the unconditional
  `BOOTX64.EFI` copy) runs:

  ```sh
  if [ "${LIMINE_NVRAM:-no}" = "yes" ]; then
      install_pkgs efibootmgr
      _esp_src="$(findmnt -no SOURCE /boot/efi 2>/dev/null)"
      _esp_disk="$(lsblk -no PKNAME "$_esp_src" 2>/dev/null | head -n1)"
      _esp_part="$(lsblk -no PARTN  "$_esp_src" 2>/dev/null | head -n1)"
      # ...
      efibootmgr --create --disk "/dev/$_esp_disk" --part "$_esp_part" \
          --loader '\EFI\BOOT\BOOTX64.EFI' --label "Void Linux (Limine)"
  fi
  ```

  `efibootmgr` was already a member of the `[PKG-PREFLIGHT]` superset, and the
  removable/fallback copy above is unconditional — so a failed `efibootmgr`
  only warns and the box still boots. Default/no is **byte-identical** to the
  historical NVRAM-free deploy.
- The choice is threaded through the DRY-RUN plan, the `chroot_env` export, the
  `limine-env` as-built record, the `install-config` dump and the NEXT-STEPS
  text (which now says "registered in NVRAM" vs. "no NVRAM entry needed").

Validation: `bash -n`, `check-heredocs.sh`, `check-defaults.sh`,
`check-pkg-preflight.sh` ALL CLEAN; the prompt `case` was unit-tested across all
14 default/input combinations (bare Enter, y/n, yes/no, true/false, mixed case,
and junk → re-ask).

## Beta-v2.9.96 — `[BR0-NAT-TEARDOWN]` + `[HEADLESS-PROMPT-LOOP]` (libvirt NAT teardown made race-proof and every-boot; headless opt-in prompts no longer loop)

`SCRIPT_VERSION` bumped to Beta-v2.9.96. Two fixes, both surfaced by the
2026-10-15 post-install audit and the 2026-10-16 headless installer gate.

### F1 — libvirt `default` NAT was not torn down (first-boot ordering race)

`/etc/rc.local`'s `[BR0-SKIP]` teardown lived **inside** the one-shot
`[ ! -f /var/log/firstboot.log ]` guard and waited only for libvirtd's
`/run/libvirt/libvirt-sock` to appear:

```sh
for i in $(seq 1 15); do [ -S /run/libvirt/libvirt-sock ] && break; sleep 1; done
virsh net-destroy default               >/dev/null 2>&1 || true
virsh net-autostart default --disable   >/dev/null 2>&1 || true
```

The socket is up **before** libvirtd has defined/activated its bundled
`default` network (`/etc/libvirt/qemu/networks/default.xml`), so both `virsh`
calls hit *"network not found"* and were swallowed by `|| true`. libvirtd then
autostarted `default` (it ships an autostart symlink) and the intended `br0`
migration never happened — the audit found `default active autostart=yes` with
the autostart symlink never removed.

The block **moved to the every-boot section** at the end of `/etc/rc.local`
(after the first-boot guard, so on first boot libvirtd has just been linked),
and is now idempotent and deterministic:

- it **polls** until `virsh net-info default` actually succeeds instead of
  trusting the socket, then destroys + disables and **verifies** the result
  (`net-list --name` for Active, `net-list --all --autostart --name` for
  Autostart), retrying a few times;
- it **logs** every outcome (ready/torn_down/active/autostart + the net list)
  to `/var/log/void-br0-nat-teardown.log` — no more silent swallow;
- on success it best-effort removes the orphaned `virbr0` bridge that
  `net-destroy` leaves behind (`ip link del virbr0`);
- it only tears down when a **physical wired NIC is present right now**
  (mirrors the installer's `has_wired_nic_hw()`: a `device` link, no
  `wireless` dir, and the non-wired name skip list), gated on the `br0`
  NM profile existing. On the 2026-10-15 topology the install-time USB NIC was
  absent at first boot, so a *successful* teardown would have left the box with
  **zero** VM networking (`br0` down + `virbr0` gone) — the guard keeps the NAT
  fallback in that case and re-checks next boot, so a NIC plugged in later
  migrates on a later boot.

Every step is failure-tolerant; first boot can never fail because of this, and
the block is a no-op once `default` is inactive.

### `[HEADLESS-PROMPT-LOOP]` — bare Enter on the headless opt-in prompts looped forever

On a fully-headless install (`DESKTOP_ENV=none` + `DISPLAY_MANAGER=none`) the
two opt-in prompts

```
Keep the Xorg/Wayland base for a later startx / remote-X? [y/N]:
Install the audio stack (PipeWire + ALSA) on this server? [y/N]:
```

matched only `y|yes` / `n|no`, while their bare-Enter fallback variables
`DEFAULT_XORG`/`DEFAULT_AUDIO` are `false`. An empty answer is rewritten by
`${_xg:-$DEFAULT_XORG}` to the literal string `false`, which matched **no**
arm and fell through to the re-prompt — an infinite loop on bare Enter (and
uppercase `Y`/`N` looped too). Each `case` now accepts `y`/`yes`/`true` and
`n`/`no`/`false` **case-insensitively**, so Enter = No exactly as the `[y/N]`
label promises. No prompt, `DEFAULT_*` or package surface changed
(`check-defaults.sh` ALL CONSISTENT).

### Validation

`bash -n`, `checks/check-heredocs.sh` (**ALL CLEAN** — the `/etc/rc.local` body
is extracted and checked), `checks/check-defaults.sh` (**ALL CONSISTENT**) and
`checks/check-pkg-preflight.sh` (**ALL COVERED**) all pass. Both fixes were
exercised functionally: the prompt block was driven headlessly (bare Enter →
`false`/`false`, `y`/`Y`/`yes`/`true` → `true`, `junk` re-prompts then accepts
Enter, no loop), and the rc.local teardown was run in a sandbox with stubbed
`virsh`/`ip`/`date`/`sleep`, a fake `/sys/class/net`, and a simulated
late-definition race (net defined after N probes), destroying a network that
was already torn down, an absent NIC, a missing `br0` profile, a
never-defined net (timeout), and a failing destroy — each branch behaved as
designed. **Not yet exercised through a full install flow** (same caveat as
the 2.9.84–2.9.86 backlog entries); the wired-*less* SKIP branch still needs a
machine with the USB NIC removed during a fresh install.

## Beta-v2.9.95 — `[SSH-DEFAULT-HARDEN]` (the SSH access defaults become secure: password auth and root login both default to no)

`SCRIPT_VERSION` bumped to Beta-v2.9.95.

### Symptom

The `[SSH-SERVER]` access sub-prompts defaulted to a **password-reachable**
sshd: `DEFAULT_SSH_PASSWORD_AUTH=yes` and
`DEFAULT_SSH_ROOT_LOGIN=prohibit-password`, with the prompts labelled `[Y/n]`.
An operator who chose to install the server and then pressed Enter through the
two access questions — the documented "reachable without key setup" path —
shipped a host accepting SSH password authentication from the network.

### Fix

The two `DEFAULT_*` answers are inverted to the secure posture:

- `DEFAULT_SSH_PASSWORD_AUTH` `yes` → `no`
- `DEFAULT_SSH_ROOT_LOGIN` `prohibit-password` → `no`
- prompt labels `[Y/n]` → `[y/N]`

So a bare Enter now yields `PasswordAuthentication no` and `PermitRootLogin no`
in `/etc/ssh/sshd_config.d/…`, while an explicit `y` still produces exactly the
old values — `yes` for password auth, `prohibit-password` (public-key-only root)
for root login. Nothing was removed from the prompt surface: both knobs remain
answerable, only their Enter-default moved. The server toggle (still default
OFF), the port prompt, the `[SSH-KEYS]` import/generate/backup prompts, the
package list and the prompt set are unchanged.

This also re-establishes the change in the **canonical** source. The same
hardening had already landed only on the public export (2026-10-15) and was then
clobbered there when the Release-v2.9.93 export sync rebuilt the script from the
private tree, which still carried the old defaults. Carrying it in the private
tree means no later export can revert it.

Validation: `bash -n` clean; `checks/check-heredocs.sh` ALL CLEAN;
`checks/check-defaults.sh` ALL CONSISTENT; `checks/check-pkg-preflight.sh` ALL
COVERED.

## Beta-v2.9.94 — `[BASELINE-SNAPSHOT-FIRSTBOOT]` (the baseline snapper snapshot is taken after first-boot provisioning, so it contains a working desktop instead of a bare console)

`SCRIPT_VERSION` bumped to Beta-v2.9.94.

### Symptom

Rolling back to the baseline snapper snapshot — or selecting it from the
GRUB/Limine snapshot menu — booted to a **bare `agetty` console** rather than the
display manager / greeter. The baseline was advertised as "a clean install", but
it did not actually start the desktop.

### Root cause

`/etc/runit/2` runs `/etc/rc.local` and **only afterwards** execs `runsvdir`.
The installer deliberately defers **every** runit service symlink (the display
manager, `dbus`, `NetworkManager`, `chronyd`, `cronie`, `snapperd`, `polkitd`,
`udisksd`, the gated profile/virt/session services, ...) into the first-boot
`rc.local` block, which is guarded by `[ ! -f /var/log/firstboot.log ]` and runs
before `runsvdir` starts — that ordering is exactly what makes a *normal* first
boot reach the greeter (the links exist by the time `runsvdir` reads them).

The baseline snapshot, however, was created at the **end of the chroot install**
— i.e. **before** that first boot ever ran. At that moment
`/etc/runit/runsvdir/default/` contained only the `agetty-tty*` links shipped by
the base packages, so the snapshot's `@` subvolume captured a **console-only**
system graph. Two further facts made this un-recoverable on rollback:

1. The service symlinks live in `@` (`/etc/runit/runsvdir/default/`), so the
   snapshot is the *only* place they would have been recorded.
2. The first-boot marker `/var/log/firstboot.log` lives on the **separate `@log`
   subvolume**, which is *not* part of an `@` snapshot and therefore **survives**
   a rollback. After restoring the baseline, `rc.local` sees the marker, skips
   first-boot provisioning, and the (missing) display-manager link is never
   recreated — the restored system can never self-heal to a greeter.

(Confirmation that this is a *content* problem and not a snapper-filter problem:
the man page states filters "do not exclude files or directories from being
snapshotted" — the `var/service/*` filter in `/etc/snapper/filters/void-runit.txt`
only affects `snapper diff`/`status` output, never what a snapshot contains.)

### Fix

Move the baseline creation to the **end of the one-shot first-boot provisioning
block** in `/etc/rc.local`, immediately after `update-desktop-database` and
immediately before the `touch /var/log/firstboot.log` marker is written. At that
point the service symlinks exist, so the baseline captures a fully-functional
clean-system image that boots to the greeter.

This reuses the **existing** `[ ! -f /var/log/firstboot.log ]` guard, which
already guarantees exactly one run, so — as the operator requested — **no
self-deleting script or cron timer is needed**: the same one-shot gate that
provisions the system also snapshots it, once. The snapshot step is guarded by
`command -v snapper && [ -f /etc/snapper/configs/root ]` and warns (without
aborting the boot) if it fails; the marker is written regardless so first-boot
provisioning stays one-shot.

The install-time snapshot line and its `41_snapshots-btrfs` `chmod -x`/`+x`
toggle (which only existed to keep the freshly-created snapshot out of the
initial `grub-mkconfig`) are removed. The installer now just runs
`grub-mkconfig` normally (GRUB) / `void-limine-write-conf` (Limine); the
first-boot snapshot is subsequently picked up by `grub-btrfsd` (GRUB) or the
`/usr/lib/snapper/plugins/00-void-limine-snapper-sync` plugin (Limine), both of
which are already installed and linked.

The NEXT-STEPS install-success text is updated from "A baseline snapper snapshot
has already been created" to state that it is taken on first boot, once the
desktop services are enabled.

Rationale for taking the snapshot at first boot rather than enabling the
services earlier (during the chroot): enabling them at install would duplicate
or relocate the ~30-line conditional symlink block, and the first boot's
provisioning tasks (`virsh` bridge teardown for the `br0` case, the Flatpak
remote add, `update-desktop-database`) are deliberately ordered after service
start-up, so a boot-time snapshot is both the minimal and the more faithful
"fully provisioned clean system" boundary.

Validation: `bash -n` clean; `checks/check-heredocs.sh` ALL CLEAN (the modified
`/etc/rc.local` heredoc still `bash -n`-checks clean); `checks/check-defaults.sh` ALL
CONSISTENT; `checks/check-pkg-preflight.sh` ALL COVERED.

## Beta-v2.9.93 — `[OCTOXBPS-NOPASS-POLKIT]` (OctoXBPS notifier startup/network-reconnect password prompt suppressed)

`SCRIPT_VERSION` bumped to Beta-v2.9.93.

When `INSTALL_OCTOXBPS=true`, Stage 2 now also deposits a **polkit action +
rules pair**:

- `/usr/share/polkit-1/actions/99-octoxbps-check-nopass.policy`
- `/etc/polkit-1/rules.d/90-octoxbps-nopass.rules`

The action defaults `allow_active` to `auth_self`; the rules file overrides it
to `polkit.Result.YES` **only** for active, local users in the `wheel` group and
**only** for repository-sync commands (`/usr/bin/xbps-install -Sy` and `-Syy`).
This suppresses the OctoXBPS notifier's password prompt at login / after a
network reconnect without weakening install/update authentication (installing
and updating packages still authenticates normally). Both files are `chmod 644`.

*(Backfilled entry: the Beta-v2.9.93 release commit bumped `SCRIPT_VERSION`
ahead of its changelog row, leaving a gap between Beta-v2.9.92 and this
version.)*

## Beta-v2.9.92 — `[COSMIC-TOUCHPAD-RCLICK]` (opt-in COSMIC touchpad right-click override)

`SCRIPT_VERSION` bumped to Beta-v2.9.92. Adds a new **opt-in prompt, COSMIC
builds only**, default OFF (lean posture — must be opted into, matching the
other app/feature toggles):

```
Configure COSMIC touchpad right-click (two-finger tap + corner-click)? [y/N]:
```

Background: `cosmic-settings` ships `/usr/share/cosmic/.../v1/input_touchpad`
with `click_method:Some(Clickfinger)` — verified via `xbps-query -o` that the
package owns the file. On the reference install (AMD Ryzen x360 laptop)
Clickfinger produced **no usable right-click**; the daily-driver fix is the
per-user override `click_method:Some(ButtonAreas)`, which restores
right-click via bottom-corner clicks while the two-finger-tap right-click is
preserved by the same shipped `button_map:Some(LeftRightMiddle)`. The override
is written **per-user** to
`~/.config/cosmic/com.system76.CosmicComp/v1/input_touchpad` (the greeter's own
touchpad behavior is intentionally out of scope — the tested fix was desktop
sessions only).

Stage-2 mechanics:
- `DEFAULT_COSMIC_TOUCHPAD_RCLICK="false"` in the defaults block;
  `INSTALL_COSMIC_TOUCHPAD_RCLICK` prompted only when `DESKTOP_ENV=cosmic`,
  then carried through `chroot_env.sh` next to `POWER_PPD`.
- The override is **derived** from the in-tree shipped default (`sed` replacing
  only the `click_method:Some(Clickfinger)` token) so it always mirrors the
  current schema — the `[XKB-CONFIG-CREATE]` lesson: never hardcode a struct
  the package owns. If the shipped file or the Clickfinger token is absent, a
  canonical known-good override is written instead (the same content proven on
  the reference box) so the toggle never silently installs a broken/empty
  config.
- Runs inside the cosmic branch after the account exists; same presence guard,
  `chmod 0644` + `chown TARGET_USER:TARGET_USER` as the dotfile deposits.
`bash -n`, `check-heredocs.sh` ALL CLEAN, `check-defaults.sh` ALL CONSISTENT,
`check-pkg-preflight.sh` ALL COVERED.

## Beta-v2.9.91 — `[COSMIC-GREETER-DEFAULT]` (cosmic-greeter becomes the recommended/default DM for the COSMIC DE)

`SCRIPT_VERSION` bumped to Beta-v2.9.91. Text-only change, no package surface
or prompted default shifted: the DM *pairing* for `DESKTOP_ENV=cosmic` flips
from SDDM to **cosmic-greeter**. The original caution traced to the COSMIC
maintainer's report that the greeter could not (reliably) recognize elogind
sessions. Real-hardware evidence reversed that guard: the reference install
(AMD Ryzen x360 laptop, COSMIC 1.10 + cosmic-greeter) sessions cleanly under
elogind and is its daily driver, so:
- `RECOMMENDED_DM="cosmic-greeter"` for the cosmic DE (was `sddm`).
- The DM prompt's `Debug caveat` paragraph is removed; option 4 now reads as
  "the recommended/default pairing for COSMIC, tested on real hardware."
- The Enter-default in the DM prompt already follows `RECOMMENDED_DM`, so a
  plain Enter on the COSMIC branch now selects cosmic-greeter exactly as it
  already does for KDE→SDDM, GNOME→GDM, etc.
- Top-of-file display-manager header comment updated to match.
`bash -n`, `check-heredocs.sh` ALL CLEAN (72 heredocs), `check-defaults.sh`
ALL CONSISTENT, `check-pkg-preflight.sh` ALL COVERED.

## Beta-v2.9.90 — `[COSMIC-PPD]` (COSMIC's powermode picker gets power-profiles-daemon and drops tlp — COSMIC-only, other DEs unchanged)

`SCRIPT_VERSION` bumped to Beta-v2.9.90. This is a code change (package +
service surface on one DE branch): COSMIC's `cosmic-settings` hard-depends on
`power-profiles-daemon` (D-Bus `net.hadess.PowerProfiles`), but nothing ever
linked its runit service, so the picker showed *"Backend not found install
System76-power or power-profiles-daemon"* while the laptop profile's tlp ran
concurrently — a documented conflict (both want CPU-scaling / platform-profile
knobs). The Stage-1 resolution (just before `chroot_env.sh` is written) now
derives `POWER_PPD="true"` for every COSMIC build and sets `PROFILE_TLP=false`
(no tlp package, no tlp service link) on COSMIC laptops; the tlp install site
is left tlp-gated as before (it simply resolves false), and a
`[ "$POWER_PPD" = "true" ] && install_pkgs power-profiles-daemon` line ships
PPD explicitly. On first boot, rc.local links
`/etc/sv/power-profiles-daemon` (new `__POWER_PPD__` sed placeholder next to
the `__PROFILE_*__` ones) so the D-Bus backend exists from the first run.
Scope is strictly COSMIC-only: every other DE keeps the existing tlp laptop
behavior unchanged. `POWER_PPD` is carried through `chroot_env.sh`, the
resume-state boolean loop and `install-config`. `power-profiles-daemon` added
to `PKG_PREFLIGHT` per the drift-guard rule. No prompt or default changed
(the laptop/desktop profile prompt and its `tlp=true` resolution are
overridden silently for COSMIC; a NOTICE prints the override). Proven on
the reference install (AMD Ryzen laptop): PPD publishes
`performance`/`balanced`/`power-saver` driven through `amd_pstate` + the
firmware `platform_profile` (exposed `quiet/balanced/performance`), and
tlp/tlp-rdw were removed from that box. `bash -n`, `check-heredocs.sh` ALL CLEAN,
`check-defaults.sh` ALL CONSISTENT, `check-pkg-preflight.sh` ALL COVERED.

## Beta-v2.9.89 — `[SMART-BASELINE]` (smartmontools now ships on every install regardless of DE / greeter / profile, so a S.M.A.R.T. health baseline exists on day one)

`SCRIPT_VERSION` bumped to Beta-v2.9.89. This is a code change: the
always-on package surface gains one name. The unconditional roll-up line
(`install_pkgs xdg-user-dirs … bridge-utils`) now also installs
`smartmontools`, so every box gets `smartctl` for S.M.A.R.T. health checks
from the moment it is installed — independent of which DE or greeter was
chosen. Health monitoring is a baseline concern, not a DE/greeter concern:
motivation was the first post-install audit box, whose 1 TB NVMe could only
be health-checked because the operator added the package by hand after
install (HEALTH PASSED, 0 media-integrity errors — but only a post-hoc
baseline). The `smartd` monitoring daemon is intentionally NOT enabled by
default; scheduling automatic checks stays an operator decision
(smartd needs alerting configuration, which is a site choice). No prompt or
default changed; `smartmontools` also joined the stage-1 validation-only
`PKG_PREFLIGHT` superset list per the `[PKG-PREFLIGHT]` drift-guard rule
(every `install_pkgs` literal must resolve against the live pool).
`bash -n`, `check-heredocs.sh` ALL CLEAN,
`check-defaults.sh` ALL CONSISTENT, `check-pkg-preflight.sh` ALL COVERED.

## Beta-v2.9.88 — `[SSH-IMPORT-VALIDATE]` + `[SSH-USABLE]` + `[SUBVOL-GATE-VALIDATE]` + `[BROWSE-ALIAS-ESC]` (imported SSH keys are verified and wired to be usable; the subvolume master gates reject junk instead of bulk-defaulting; the browse aliases accept escaped spellings)

`SCRIPT_VERSION` bumped to Beta-v2.9.88. This is a code change (not text-only):
the prompt *surface* is unchanged — no new top-level questions, defaults or
package names — but the input handling is stricter and the SSH-key import is
verified.

### 1. `[SUBVOL-GATE-VALIDATE]` — the `[Y/n/i]` / `[y/N/i]` master gates no longer swallow junk

A lone `.` typed at either gate (or any other unrecognized answer) previously
fell through the `case` `*` branch: Gate 1 silently isolated **all** installed
apps and Gate 2 silently pre-created **nothing**, with no warning — the exact
"silent coercion" a transcript review flagged. Each gate now validates its
answer: Enter (default) / `y` / `n` / `i` only, with a hint and a re-prompt on
anything else. Two consequences of the rewrite, both fixes rather than
regressions:

- the bare-Enter path no longer leaks the boolean `DEFAULT_SUBVOL_ISOLATE`
  (`true`) into `SUBVOL_ISOLATE_INSTALLED`, where `"true" != "yes"` used to
  silently divert a default run into the per-app `_subvol_ask` walk rather than
  the documented bulk default;
- `_subvol_ask` (the per-app walker) also re-prompts on unrecognized answers
  instead of treating any non-`y` input as an implicit decline.

### 2. `[SSH-IMPORT-VALIDATE]` — imports are verified before they are trusted

The picked file used to be `cp -f`'d into the stage blind: any file sailed
through as a "key", and the `.pub` was only staged if a literal `${file}.pub`
sibling existed at the source. The import flow now verifies with
`ssh-keygen -y` *before* trust:

- **unencrypted key** — `ssh-keygen -y -P ""` succeeds and a fresh `.pub` is
  derived from the private key itself (guaranteed to match, comment included);
  the source sibling is no longer the only way a public half exists;
- **passphrase-protected key** (header matches `-----BEGIN .*PRIVATE KEY-----`)
  — a one-shot `read -r -s` passphrase is accepted, used only to verify
  (`ssh-keygen -y -P "$pass"`), then discarded in-memory; never stored, never
  exported;
- **not a key / wrong passphrase** — an ERROR names the file, the staged copy
  is removed, and the import is skipped (`IMPORT_SSH_KEY=false`).

After a successful verify the fingerprint (`ssh-keygen -lf`) is printed for the
operator to compare against the source machine. The import is skipped with a
warning if `ssh-keygen` is unavailable on the live medium.

### 3. `[SSH-USABLE]` — a deposited key can now actually be used

Before this change a deposited key sat inert: an imported `~/.ssh/imported` has
a non-standard name with no `IdentityFile` anywhere, and the public half was
never trusted, so the "install my key" flow could not log into the fresh box
(or use the key as a client identity). The deposit step (inside the chroot,
against the target `~/.ssh`) now:

- writes `IdentityFile ~/.ssh/{key}` entries into `~/.ssh/config` for whichever
  key(s) landed (`id_ed25519` and/or `imported`) — append-only, a pre-existing
  config is preserved; perms 0600;
- appends the imported public key to `~/.ssh/authorized_keys` (perms 0600), so
  logging into the box with that key works from any client that holds its
  private half.

### 4. `[BROWSE-ALIAS-ESC]` — `\ok` is `ok`

A user who typed the accept-the-current-directory control `ok` as `\ok` (an
easy habit on the zsh live prompt, where `!` is a history-expansion
metacharacter and people escape) saw the input echoed as `\ok` and then
rejected with `File not found: \ok`. `browse_pick` now peels **one** leading
backslash for ALIAS matching only (`\..` / `\m` / `\drives` / `\!` / `\ok`);
absolute/relative paths and numbers are still matched exactly as typed.

### Validation

`bash -n`, `check-heredocs.sh` ALL CLEAN, `check-defaults.sh` ALL CONSISTENT,
`check-pkg-preflight.sh` ALL COVERED.

## Beta-v2.9.87 — `[COSMIC-REPO-MOVE]` (the COSMIC repo is now served from the unified Void_Linux_Cosmic project; the pinned key is unchanged)

`SCRIPT_VERSION` bumped to Beta-v2.9.87. The COSMIC third-party repository is
now served from the unified `Void_Linux_Cosmic` project (packaging templates +
signed binary repository in one place), which publishes its `<arch>-repodata`,
`.xbps` and `.sig2` at the repository root:

- `_cosmic_repo`      → `https://bluesloth.github.io/void-linux-cosmic/`
- `_cosmic_repodata`  → `https://bluesloth.github.io/void-linux-cosmic/x86_64-repodata`
- `_cosmic_audit`     → `https://github.com/bluesloth/void-linux-cosmic`

The **pinned signing key is unchanged** (`_cosmic_key_expected` =
`83ffd154…d2e7b`), so the machine-checked trust anchor and its allowlist behave
exactly as before — only the served location moved. Text-only change: every code
path, prompt, default and package surface is untouched, so INSTALL_PROMPTS.md
needs no update and both gates have no new inputs.

## Beta-v2.9.86 — `[BR0-SKIP]` (a virt install on a wired-less machine no longer builds a dead br0 and kills virbr0 — the bridge is skipped and virbr0 becomes the VM-networking fallback)

`SCRIPT_VERSION` bumped to `Beta-v2.9.86`; era row added to the script header
VERSION-HISTORY; index row added above; this section added as the newest
detail section. No prompt/defaults/package surface changed, so
INSTALL_PROMPTS.md is untouched and both prompt/package gates have no new
inputs.

### What was wrong

`INSTALL_VIRT` gated the bridged networking on itself and nothing else. The
Stage-2 block always wrote `br0.nmconnection` + `br0-slave.nmconnection`;
whenever detection fell back to the `enp*` placeholder the slave's
`interface-name=` was omitted (role-matched: "any free ethernet device");
and first-boot rc.local unconditionally ran `virsh net-destroy default` +
`virsh net-autostart default --disable`. On a machine with no wired NIC at
all — the round-10 box's topology, Wi-Fi only — that produced a specific
triple failure:

1. a bridge that could never have a member (DHCP loops, dead weight;
   `BR0_NIC="<unset>"`, `NET_INTERFACE_MATCH="enp*"` recorded);
2. a role-matched slave free to adopt ANY ethernet device that appeared
   later — a USB NIC bought for another purpose, a tethering phone — into
   `br0` behind the user's back;
3. and, because virbr0 was killed anyway, **zero VM networking at all**,
   while the as-built record claimed "bridged br0".

### The fix — hardware-presence trigger, explicit skip, virbr0 fallback

1. **`has_wired_nic_hw()`** — a new predicate at unconditional top level
   next to `detect_wired_nic()` (2.9.78 placement rule): physical `device`
   link + no `wireless` dir + the shared name-skip list, carrier and USB
   irrelevant. It answers "is there wired hardware"; `detect_wired_nic()`
   keeps answering "which NIC should we use".
2. **The late re-probe is now three-way.** Detected name → concrete
   binding (unchanged). Hardware present but no link → WARNING + the
   `enp*` role-matched fallback (unchanged — this is the cable-unplugged
   PCIe case the skip must NOT swallow). No hardware at all → an EMPTY
   `NET_INTERFACE_MATCH` as the explicit skip signal + a NOTICE. Empty
   needs no new state variable: it already round-trips through the
   resume-state persist list and `chroot_env.sh`.
3. **Stage-2** writes the pair only when `INSTALL_VIRT=true && -n
   NET_INTERFACE_MATCH`, with an else-NOTICE at the write site so a
   resumed run still records the outcome; qemu's `bridge.conf` `allow br0`
   gets the same gate.
4. **rc.local** tears virbr0 down only when
   `/etc/NetworkManager/system-connections/br0.nmconnection` exists. Skip
   → virbr0 stays enabled → VMs get NAT networking out of the box;
   `[NFT-VIRT-GATE]` already emits `virbr*` forward accepts whenever
   `INSTALL_VIRT=true`, so the fallback is firewall-clean with no nft
   change and no new forward rules on the br0 path.
5. **install-config** gains a `VIRT_BR0` row (`created` /
   `skipped (no wired NIC; virbr0 kept)` / `n/a`) computed with the same
   condition as the profile gate, so the as-built record always matches
   what was actually written.

### Why the design was chosen this way

- **Hardware presence, not "detection empty".** After 2.9.85 an empty
  `detect_wired_nic()` result means either "no wired hardware" or
  "built-in port, no cable" (pass 1 needs carrier; pass 2 needs a USB
  path). Skipping on the former is right; skipping on the latter would
  break the plug-a-cable-later path the role-matched slave exists for.
- **virbr0 as fallback, not victim.** The strict alternative — skip br0
  and still kill virbr0 — delivers a virt install with no networking at
  all. Keeping the default NAT network only where br0 is impossible
  preserves the "prefer br0" architecture stance everywhere it applies:
  machines WITH a wired NIC behave byte-identically to 2.9.85.
- **The skip signal is an empty value, not a new flag.** `NET_INTERFACE_MATCH`
  is already persisted and consumed by exactly the two things that should
  skip (the profile pair, the qemu allowlist), threading `-r` resumes with
  zero new state surface — verified by the gate matrix: empty → skip,
  `enp*` → role-matched write, concrete name → literal write, non-virt →
  skip.
- **Auto-skip, no prompt.** With no wired hardware there is one sensible
  outcome; the NOTICE sets expectations before the Enter pause and reports
  the result after. (A "create br0 anyway for a later NIC?" prompt was
  considered and rejected — it would add a `DEFAULT_*` knob for a case
  with one right answer; the manual path stays open post-install.)
- **rc.local checks the profile FILE, not the live link.** rc.local runs
  in runit stage 2 around/BEFORE NetworkManager brings bridges up, so an
  `ip link show br0` check would race NM: on a legitimate br0 install it
  could find no bridge yet and wrongly leave virbr0 enabled. The profile
  file is written at install time and never changes underneath rc.local —
  a pure disk-state decision with no timing dependency.

Validation: `bash -n` clean; `check-heredocs.sh` 72 heredocs ALL CLEAN
(STAGE-2-CHROOT 6173 lines, rc.local 192 lines); `check-defaults.sh` ALL
CONSISTENT (73 defaults, none added); `check-pkg-preflight.sh` ALL COVERED
(164 preflight packages). Live exercise on the round-10 box under `set -eE`
+ a stub ERR trap with the REAL extracted functions: the predicate trace
counts only `enp3s0f3u1u1` (physical, non-wireless) and excludes
`wlo1`/`lo`/`br0`/`docker0`/`virbr0`; `detect_wired_nic` → `enp3s0f3u1u1`
(branch 1); forced-empty detection + real predicate → branch 2 (role-matched
fallback) trap-free; not-found stubs → branch 3 with the NOTICE and
`NET_INTERFACE_MATCH=''` trap-free; the real predicate body's return-1
fall-through (empty-world glob) is trap-free in condition context; all four
Stage-2 gate combinations correct. Version-ritual grep: only deliberate
historical 2.9.85 references remain.

## Beta-v2.9.85 — `[NIC-DETECT-USB]` (the review's USB-ethernet fallback was dead code — both wired-NIC probes now share one helper)

`SCRIPT_VERSION` bumped to `Beta-v2.9.85`; era row added to the script header
VERSION-HISTORY; index row added above; this section added as the newest
detail section. No prompt/defaults/package surface changed, so
INSTALL_PROMPTS.md is untouched and both prompt/package gates have no new
inputs.

### What was wrong

Two places choose a wired NIC: the Stage-1 review's `[NIC-DETECT]`
(Beta-v2.9.27 → `BR0_NIC` record + the "Keep this interface?" prompt) and the
`INSTALL_VIRT` late re-probe (`NET_INTERFACE_MATCH` → the `br0-slave`
NetworkManager binding). Both promise the same thing — the Stage-1 notice
says it outright: *"a USB Ethernet adapter … physically present (cable
optional)"* — but only the re-probe implemented it. Its fallback
(`readlink -f …/device` matching `*usb*`) works at any sysfs depth; the
Stage-1 fallback globbed `/sys/devices/*/net/*`, and bash's `*` never
crosses a `/`. On real hardware that glob matches only
`/sys/devices/virtual/net/*` — lo/br0/docker0/virbr0 — and every one of those
fails the very usb-subsystem test the loop then applies. The loop could
never fire: dead code. A USB NIC's actual path is ~6 levels deep
(`/sys/devices/pci0000:00/…/usb2/2-1/2-1.1/2-1.1:1.0/net/enp3s0f3u1u1`).

Consequence, live on the round-10 box: with the adapter present but no cable,
the review printed `(none detected — late re-probe will decide …)` and
`install-config` records `BR0_NIC="<unset>"`. The carrier pass above it also
had no physical-device check (an up bridge/tun with carrier could in theory
win). The `br0-slave` binding was NOT affected — the re-probe's correct code
decides that — but `BR0_NIC` is a promised prompt + as-built record, and the
two sites could disagree.

### The fix — one shared helper

`detect_wired_nic()` now sits at unconditional top level, directly above the
resume guard (the 2.9.78 `_region_fs_of` lesson: both call sites live inside
RESUME-gated blocks, so a gated definition breaks resumed runs). Two passes,
semantics identical to the re-probe's proven behavior:

1. carrier-active physical wired NIC (cable plugged + link up);
2. otherwise any physically-PRESENT USB network device, carrier irrelevant —
   the documented "cable optional" promise, which also covers USB-tethered
   phones.

Protections merged from both old copies: `-e …/device` (physical only — the
Stage-1 carrier loop gains this), no `wireless` dir, and the name skip list
`lo|ww*|wl*|bn*|bt*|dm-*` (the re-probe gains it — a Bluetooth-USB netdev
whose sysfs path contains `usb` can no longer be chosen as the "USB NIC").
Both sites assign with `$(detect_wired_nic || true)`: Stage-1 runs under
`set -eE` + the ERR trap, and "nothing found" returns 1 (empty output is the
not-found signal either way).

### Why the design was chosen this way

- **One helper, not one patched glob.** 2.9.27 wrote the same detection twice
  and the copies DRIFTED — one correct, one dead. Fixing only the dead glob
  leaves two hand-rolled copies to drift again; a shared function makes the
  review and the binding agree by construction.
- **The re-probe's behavior is the baseline.** Pass-for-pass it is the proven
  logic; the only deltas are additions (name-skip list, `|| :` on the
  readlink so a dangling device symlink cannot trip the Stage-1 ERR trap —
  verified live: a bare readlink failure in a substitution DOES fire it under
  `-eE`) — nothing a working install depended on was relaxed.
- **`BR0_NIC` stays record-only.** The helper changes what gets RECORDED and
  offered at the prompt; `NET_INTERFACE_MATCH` still alone drives the
  `br0-slave` binding, so no installed system's networking changes
  retroactively — fresh installs bind exactly what they detected before,
  except the review can now see (and let you keep) an unplugged USB adapter.
- **No new knobs.** Same prompts, same defaults, same packages: this is a
  correctness fix inside existing behavior, so `check-defaults.sh` and
  `check-pkg-preflight.sh` inputs are untouched.

Validation: `bash -n`; `check-heredocs.sh` 72 heredocs ALL CLEAN;
`check-defaults.sh` ALL CONSISTENT; `check-pkg-preflight.sh` ALL COVERED;
live exercise of the helper on the round-10 box under `set -eE` + a stub ERR
trap — pass 2 returns `enp3s0f3u1u1` (ASIX AX88179, no cable) where the old
glob returned only `/sys/devices/virtual/net/*`, and both the not-found path
and every guard pattern run trap-free.

## Beta-v2.9.84 — `[COSMIC-STORE]`/`[FLATPAK-PULL-DETECT]` (cosmic-store becomes a real opt-in prompt that can never pull flatpak past a declined prompt — plus a safety net for the paths a toggle cannot govern)

`SCRIPT_VERSION` bumped to `Beta-v2.9.84`; era row added to the script header
VERSION-HISTORY; index row added above; this section added as the newest detail
section.

### What was wrong

`cosmic-store-1.9.0_1` in the bluesloth COSMIC repo has a **hard
`run_depends: flatpak`** — but the installer *never installed it*, so the Open
Item in `TODO.md` was a landmine, not a live bug: the "Flatpak" prompt
(`INSTALL_FLATPAK`) is an explicit on/off choice, and the moment anyone added
the store (an `install_cosmic` call, a future `cosmic-desktop-full` revision,
or a manual `xbps-install cosmic-store`) it would silently drag Flatpak back
onto a system whose operator had explicitly declined it. xbps has no
"explicit-only dependency" — a dep is a dep. The old line-ref in the TODO
("line 8415") was already wrong by 2.9.83; the real gate is the
`if [ "$INSTALL_FLATPAK" = "true" ]; then install_pkgs flatpak fuse fuse3`
block in the package phase.

### The fix — two layers

**1. `[COSMIC-STORE]` — a real opt-in toggle, Brave-consistent.** New prompt
`INSTALL_COSMIC_STORE` (default NO, `DEFAULT_COSMIC_STORE` wired into the
`[PROMPT-DEFAULTS]` top block), offered **only when `INSTALL_FLATPAK=true`** —
on ANY desktop, because the store is a Flathub GUI that runs under any DE, not
a cosmic-only component. It follows the exact `[BRAVE-FLATPAK-GATE]` pattern:
the Stage-1 prompt hides unless the Flatpak channel is on, and the Stage-2
install site (DE-independent, sitting next to the other flatpak-gated
deliveries) **re-checks `INSTALL_FLATPAK`** — a resume from an older state
file that carried `store=yes && flatpak=no` gets a loud WARNING and a SKIP,
never an xbps dependency pull past an explicit opt-out. The answer is threaded
through the resume-state save list, `chroot_env.sh` (so the chroot sees it),
the dry-run plan print, and the as-built `install-config` row; in-chroot the
store installs via `install_cosmic cosmic-store` — the bluesloth repo,
pinned-key trust-anchor verification, bare-`xbps-install` path (correctly
outside `PKG_PREFLIGHT`, which only walks `install_pkgs` literals).

**2. `[FLATPAK-PULL-DETECT]` — a Stage-2 safety net for the toggle's blind
spots.** The toggle can't stop a *future metapackage revision* or a *manual*
`xbps-install` from pulling flatpak into a run that declined it. So at the
end of the chroot (right before `install-config` is written): if
`INSTALL_FLATPAK != true` but flatpak is installed anyway, the install prints
a loud WARNING with the reverse dependencies (`xbps-query -X flatpak` — who
pulled it) and records `FLATPAK_PULLED_BY="<reverse deps>"` in the as-built
config. Never FATAL — the decline is a preference and the detection exists to
inform, not abort — which exactly matches the TODO Open Item's rule: *"Do NOT
let the store pull flatpak past an explicit opt-out without surfacing it."*

### Why the design was chosen this way

- **Store ⇒ flatpak, never the reverse.** Flatpak without the store is a
  perfectly good CLI channel (and this installer's first-boot Flatpak queue
  already depends on that). Store without flatpak is broken UX (its Flathub
  pages fail). So the coupling direction is one-way, enforced at the prompt
  AND re-checked at the install site (both gates mirroring Brave).
- **Why not doc-only:** the TODO's own failure mode was a *future* pull the
  docs couldn't see.
- **Why not install-time detection only:** detection catches surprises but
  doesn't *offer* the store; the whole point was making it an option.
- **`PKG_PREFLIGHT` deliberately unchanged:** the preflight and its drift-guard
  only walk `install_pkgs` literals; cosmic packages are excluded from the
  Stage-1 union-pool probe by design (third-party repo) and `install_cosmic`
  is its own verified path, so `cosmic-store` correctly lives outside the
  candidate list.

Validation: `bash -n`, `check-heredocs.sh` ALL CLEAN (`[FLATPAK-PULL-DETECT]`
lives inside `CHROOT_EOF`), `check-defaults.sh` ALL CONSISTENT
(`DEFAULT_COSMIC_STORE` declared + wired), `check-pkg-preflight.sh` ALL
COVERED.

## Beta-v2.9.83 — `[COSMIC-REPO-ATTRIBUTION]` (the third-party-repo warning told the operator to audit a different repo than the one the installer actually trusts)

`SCRIPT_VERSION` bumped to `Beta-v2.9.83`; era row added to the script header
VERSION-HISTORY; index row added above; this section added as the newest detail
section.

### What was wrong

COSMIC's disclosure — the red option-7 line in the desktop menu — said the
desktop comes from "a third-party community repo maintained by an upstream
packager, published from that packager's git host".
`install_cosmic()` has not touched that repo since **Beta-v2.9.73**
(commit `d46e157`, 2026-10-04); what it actually writes into
`/etc/xbps.d/59-cosmic.conf` is

```
repository=https://bluesloth.github.io/void-linux-cosmic/
audit   =https://github.com/bluesloth/void-linux-cosmic
```

i.e. the repo the companion `Void_Linux_Cosmic` packager project signs and
publishes (29+ COSMIC 1.9 packages, whose templates are built from scratch for
upstream COSMIC 1.2), whose key is the one pinned as `_cosmic_key_expected`.

Two stale claims rode along in `install_cosmic()`'s own header comment:

* *"the documented old github.io URL is now stale — it serves a web page, not
  an xbps index"* — exactly backwards today: github.io serves a working
  `x86_64-repodata` (verified 2026-10-07), and it is the upstream host that is
  no longer used;
* *"the repo's signing key is whatever the maintainer publishes with the repo
  (fetched/trusted by xbps on first sync)"* — superseded by Beta-v2.9.76,
  which pins the key in the installer and verifies it machine-readably.

A warning whose name and link don't match what's being trusted is worse than
no warning: it sends the audit to the wrong place. Corrected in three
user/doc-facing spots — the DE menu, the ARCHITECTURE SUMMARY bullet, and the
`install_cosmic()` header — plus the one PKG-PREFLIGHT comment that still said
the upstream host.

### What was deliberately NOT changed

Purely a naming/documentation fix: `_cosmic_repo`, `_cosmic_repodata`,
`_cosmic_audit`, `_cosmic_key_expected`, the sync command, the pin check and
every code path are byte-for-byte untouched, so behavior is identical to
Beta-v2.9.82. CHANGELOG entries written before 2.9.73 still describe the
upstream era and are left alone as history; the `third-party packaging fork`
mention at the `system_accounts="_cosmicgreeter"` note stays because that *is*
the template the account name came from.

Validation: `bash -n`, `check-heredocs.sh` ALL CLEAN, `check-defaults.sh`
ALL CONSISTENT, `check-pkg-preflight.sh` ALL COVERED.

## Beta-v2.9.82 — `[COSMIC-KEY-AUTOIMPORT]` (the COSMIC repo signing-key prompt is answered by the installer now — the pin check, not the prompt, was always the trust decision)

`SCRIPT_VERSION` bumped to `Beta-v2.9.82`; era row added to the script header
VERSION-HISTORY; index row added above; this section added as the newest detail
section.

### Context

Choosing COSMIC as the DE still stopped the flow with an interactive question:

```
==> Confirming the COSMIC repository signing key when prompted.
    Pinned fingerprint:
      SHA256 83ffd154d1dee504ea384a0c31b12e072d5884f7f75eb950e30ace852d7d2e7b
    Decline and abort if xbps shows anything different.
`https://bluesloth.github.io/void-linux-cosmic/' repository has been RSA signed by "bluesloth <bluesloth@users.noreply.github.com>"
Fingerprint: cc:ca:ec:11:69:c9:c9:00:65:1e:93:de:15:02:01:83
Do you want to import this public key? [Y/n]
```

Reported 2026-10-07: the desktop menu has already disclosed COSMIC as a
third-party repo — "a signing-trust choice made at your own risk — audit the
repo before installing" — and Beta-v2.9.76 already pins the key and verifies
it machine-readably, so the extra `Y/n` asks the operator to re-confirm
something that has been decided twice over.

### Why the prompt was never the thing doing the work

Beta-v2.9.76's premise was that `-y` ("assume yes to ALL questions")
auto-accepted the key import, so removing `-y` would put the fingerprint in
front of a human. Re-tested 2026-10-07 on xbps 0.60.7 with a throwaway
`xbps-install -r <root>`:

* without `-y` (`xbps-install -S …`) → `Do you want to import this public key? [Y/n]`
* with `-y` (`xbps-install -Sy …`) → **the same prompt**

`-y` never covered the question. The prompt shows up whenever stdin can answer
it, which is why 2.9.77's `/dev/tty` routing "fixed" the interactive case and
why, with `/dev/tty` gone (unattended / headless runs), the import instead
failed outright — that gate refused every headless COSMIC install rather than
degrading gracefully.

What 2.9.76 *did* build, and what actually decides trust, is the check below
the sync: the key's DER SHA-256 is pinned in the installer (not read from the
served index), and the install aborts unless the keyring contains exactly that
key plus at most the two stock Void keys. An operator typing `Y` at a prompt
showing a substituted key would have trusted the attacker anyway — so the
prompt was friction layered on top of the real enforcement.

### The change

The sync is now `printf 'y\n' | xbps-install "${_xbps_cache[@]}" -Sy`, and the
2.9.77 `/dev/tty` gate (and its "session has no terminal" FATAL) is gone with
it. Three details are deliberate:

* **a pipe of the installer's own**, never the chroot's stdin — Stage 2 runs
  this block inside `chroot /mnt /bin/bash << 'CHROOT_EOF'`, so stdin *is* the
  heredoc (the original 2.9.76 abort), and never `/dev/tty` either, which is
  what made unattended runs impossible;
* **`printf 'y\n'`, not `yes`** — one answer, then EOF: a second question fails
  loudly instead of being answered blindly, and `yes` would kill the pipeline
  with SIGPIPE after a successful sync, which `set -o pipefail` reports as
  failure;
* **the machine check is untouched** — auto-answering changes no outcome for a
  bad key (same abort path), it only removes a prompt nobody needed to be asked.

Consequence worth noting: unattended/headless COSMIC installs now work, which
2.9.77 explicitly prevented.

Validation: live against the real repo in a fresh throwaway keyring — the
auto-answer imports the key non-interactively (rc=0), and the *shipped*
`cosmic_key_fingerprint()` run on what was imported reproduces the pin
`83ffd154d1dee504ea384a0c31b12e072d5884f7f75eb950e30ace852d7d2e7b`. Gates:
`bash -n`, `check-heredocs.sh` ALL CLEAN, `check-defaults.sh` ALL CONSISTENT,
`check-pkg-preflight.sh` ALL COVERED. The packager-side suite that re-extracts
this check from the installer on every run (`Void_Linux_Cosmic/
xkb_config-fix-20261005/test-trust-anchor-cases.sh`, 13 accept/abort cases) was
updated to anchor on the check's own `_cosmic_fp_ok=0` line instead of the
prose comment it used to key on, and stays green.

## Beta-v2.9.81 — `[SSH-KEYGEN-NONINTERACTIVE]` (answering "n" at the passphrase prompt still made ssh-keygen ask for one — omitting `-N` means "prompt me", not "no passphrase")

`SCRIPT_VERSION` bumped to `Beta-v2.9.81`; era row added to the script header VERSION-HISTORY. The generate-key branch built the new-key passphrase flag as `${SSH_KEY_PASSPHRASE:+-N "$SSH_KEY_PASSPHRASE"}`, so the `SSH_KEY_PROTECTED=no` path (operator answers `n` at `Protect the key with a passphrase? [Y/n]`) expanded to **no `-N` at all**. ssh-keygen reads a missing `-N` as "prompt interactively", not as "no passphrase", so it still emitted `Enter passphrase for "/tmp/ssh-keygen/id_ed25519" (empty for no passphrase):` — after the operator had already said no — and on any box with `SSH_ASKPASS` set (ksshaskpass/ssh-askpass) the prompt is additionally routed to a GUI helper. The fix is one line: `-N` is now always passed, with `""` for the unprotected case, which is ssh-keygen's documented "no passphrase, do not ask" form. The stale `# shellcheck disable=SC2086` that existed to justify the old zero-arg expansion was dropped with it (there is no word-split left to suppress). Secondary benefit: the stray prompt was a live answer-stream hazard of exactly the class `[SSH-KEYGEN-STALE]` (2.9.54) fixed for the `Overwrite (y/n)?` prompt — the passphrase read consumes the next line of the answer stream, so the export-a-backup prompt that follows could be answered by whatever was typed for the passphrase. Reproduced on 2026-10-07 with OpenSSH 10.5p1: no `-N` → prompt (with the `SSH_ASKPASS` helper firing), `-N ""` → silent key generation, rc=0.

Validation: `bash -n`, `check-heredocs.sh` ALL CLEAN, `check-defaults.sh` ALL CONSISTENT, `check-pkg-preflight.sh` ALL COVERED, plus a live A/B of the two ssh-keygen invocations above.

## Beta-v2.9.80 — `[MIRROR-SKEW-GUARD]` (upstream Void mirror rotation desync: repodata index lists an old version whose pool files were just rotated away, taking the whole 3-mirror fallback down with it)

`SCRIPT_VERSION` bumped to `Beta-v2.9.80`; era row added to the script header VERSION-HISTORY; new `REPO_EXTRA1` (repo-de) / `REPO_EXTRA2` (tuna) tertiary fallbacks threaded through the state-file persist list and `/mnt/tmp/chroot_env.sh`, and added to all three mirror rotations (live sync, base bootstrap, `install_pkgs`). `install_pkgs()` now tees its transcript to a temp file; when every mirror fails it classifies the failure — the `failed to download <pkg> ' signature from <repo>: Not Found` class is the transient index-vs-pool rotation skew, so the full rotation is retried up to 3 more times with 15/30/45 s backoff before the existing FATAL; all other failure classes fail immediately exactly as before. Stage-1 PKG-PREFLIGHT gains a pre-write per-mirror consistency probe: per mirror it resolves the enabled container/bootstrap closure with `xbps-query -M -R --repository=<m> --property=pkgver` (memory-sync — live-verified the on-disk index returns stale versions even after `-Sy`), HTTP-HEADs each resolved `.x86_64.xbps.sig`, promotes the first all-200 mirror to `REPO_PRIMARY`, and WARN+continues when every mirror is torn (never a pre-write FATAL for a transient; `curl` absent on the live medium degrades the probe to a skip, preserving `[PREREQ-CURL]`).

Backstory: 2026-10-07 fresh install died at `install_pkgs podman` — Void rotated `runc` 1.5.1_1→1.5.2_1 at ~13:30 UTC while the repodata (13:28 UTC) still listed 1.5.1_1; the old files were already removed from the pool, so xbps 404'd the `.sig` and the whole transaction (and install) aborted. All three configured mirrors (summithq/fastly/default) serve the same upstream sync, so mirror fallback was useless; repo-de had already healed and tuna still carried the old-consistent state — exactly the fallbacks this era adds. Both crash post-mortems (`void-installer-crash-20261007-160826.log` and `-174126.log`) carry the identical transcript — two runs, one root cause. | Beta-v2.9.79 below |

## Beta-v2.9.79 — `[XKB-CONFIG-CREATE]` (the 2.9.75 repair was gated on `[ -f … ]`, so it could only fix a *corrupt* `xkb_config`, never create a *missing* one — and a missing one makes the greeter panic and the desktop unbootable)

`SCRIPT_VERSION` bumped to `Beta-v2.9.79`; era row added to the script header VERSION-HISTORY;
index row added above; this section added as the newest detail section.

### Context

This is the **third** layer of the cosmic-greeter saga, and the only one that is fatal rather than
merely ugly. The two documented predecessors were (1) the username dispatch (`_cosmicgreeter` vs
the magic `cosmic-greeter` string) making the binary take the `locker` branch and map no window,
and (2) the `cosmic-desktop-full` hook writing `layout: ""us"",` into `xkb_config`, which
Beta-v2.9.75 fixed. This layer is different in kind:

On the fresh <host> install of 2026-10-05 (installer run 20:09→22:16, `SCRIPT_VERSION` Beta-v2.9.78,
archived script sha256 `624e8d35…` == repo HEAD, so the target provably ran current source), Stage 3
reported `Install COMPLETED successfully`. The **first boot was unusable**:

- greetd logged `check_children: greeter exited without creating a session` every ~1.6 s for 24
  minutes (three boots: 22:56, 23:14, 23:20), with `pam_authenticate: AUTHTOK_ERR` on both later
  attempts and an **empty `wtmp`** — no login ever succeeded.
- `/var/log/cosmic-greeter-session.log` was **65 MB / 946,952 lines**, ~945,960 of them
  `Error trying to flush the wayland display: Broken pipe` from `cosmic-osk` hot-spinning after
  each corpse's display died — an unbounded `svlogd` flood amplifying the restart loop.
- 25 × `The application panicked (crashed). / Message: index out of bounds: the len is 0 but the
  index is 0 / Location: src/greeter.rs:590`.

Root cause chain (each link verified, not inferred):

1. **No package ships `xkb_config`.** It exists only because the `cosmic-desktop-full` xbps
   post-install hook creates it (`void-packages-1.9/srcpkgs/cosmic-desktop-full/INSTALL:64-72`).
   On the target, `/usr/share/cosmic/com.system76.CosmicComp/v1/` held **only `input_touchpad`** —
   `xkb_config` was absent entirely.
2. **The hook did not complete.** Its other side effects are only partial:
   `/etc/pipewire/pipewire.conf.d/10-wireplumber.conf` exists, but `20-wireplumber-pulse.conf` and
   `/etc/xdg/autostart/pipewire.desktop` do not. The xkb arm also sits inside the hook's
   `if [ "$UPDATE" = "no" ]` arm, which is skipped on any update/reinstall — this was a resumed
   install.
3. **Beta-v2.9.75 could not help.** Its repair was gated on `if [ -f "$_xkb_conf" ] && …`, so with
   the file missing the guard was false and the repair **silently no-op'd**. The fix for "corrupt"
   never covered "absent".
4. **Absent → empty layout list → panic.** With no `xkb_config`, cosmic-comp reports no xkb config,
   so cosmic-greeter's `UserData.xkb_config_opt` is `None`. `Common::update_user_data`
   (`src/common.rs:203-208`) only clears+refills `active_layouts` inside
   `if let Some(keyboard_layouts) = … && let Some(xkb_config) = …`, and the vec is initialised
   empty at `common.rs:118` — so it stays empty. The keyboard-layout button renders
   `self.common.active_layouts[self.common.current_keyboard_layout].name()` (`src/greeter.rs:590`;
   `:607` in the vendored 1.9 tree, and the same unguarded index exists at `src/locker.rs:424`),
   which is `[0]` into that empty vec.

So the greeter takes a **Rust panic on its first frame that draws the layout button** — which is
every frame, because the list is permanently empty. It is not a config warning; it is a hard abort
of the login UI on every restart.

Note the `Failed to apply user display config` warnings that precede each panic are **red herrings**:
they come from the `Randr` handler at `src/greeter.rs:1891`, which calls `exec_randr` and merely
warns when no saved layout list matches (exactly 2 per crash). Likewise the daemon's
`failed to read wallpaper "/var/cache/systemd/home/<user>/login-background"` is a systemd-homed path
that does not exist under runit — noisy, harmless.

A separate, **non-fatal** cosmetic defect was observed and deliberately NOT touched:
`/var/lib/cosmic-greeter/.local/state/cosmic-comp/outputs.ron` is byte-identical (sha256
`1c9da7a5…`) to the preserved `cosmic-greeter-incident-20261005/outputs.ron.bad` and is **invalid
RON** (`config: {` where RON requires `(`) — cosmic-comp 1.9 wrote a file it cannot itself re-read.
It only produces the benign `Randr` warning above, and deleting it just regenerates it.

> **CORRECTION (2026-10-08, upstream duplicate-search):** the claim in the paragraph above is
> **wrong** — `outputs.ron` is valid RON. `OutputsConfig.config` is a
> `HashMap<Vec<OutputInfo>, Vec<OutputConfig>>` (`cosmic-comp-config/src/output/comp.rs`), so
> `config: { […]: […] }` is correct *map* syntax, not a struct needing `(`; the file is written
> (`ron::ser::to_string_pretty`) and re-read (`ron::de::from_reader`) by the same cosmic-comp
> binary (ron 0.11/0.12 in both Cargo.locks), and the exact failure string
> `Failed to read output_config` has **zero** reports anywhere on GitHub. The round-6
> `RonSpanned ExpectedComma line 4 col 11` error the incident README attributed to outputs.ron
> came from `CosmicCompConfig::get_entry` reading the **`xkb_config`** cosmic-config file — the
> position matches the corrupted `layout: ""us""` on line 4 exactly (empty string ends col 10,
> stray `u` at col 11), i.e. the Beta-v2.9.75 bug, as that entry itself already stated ("a
> byte-identical, VALID copy"); `Debug/Cosmic-Greeter/triage10-wayland-debug.md` likewise records
> "outputs.ron well-formed". The benign `Randr` warning above is greeter-side `exec_randr`
> ("no saved layout list matches" — the user's outputs.ron did not exist yet at that moment),
> unrelated to parsing this file.

### Fix

- The COSMIC DE branch now **ENSURES** the file instead of repairing it:
  `if [ ! -f "$_xkb_conf" ] || ! grep -q …` → `mkdir -p` + write. It no longer depends on the
  packager's hook having run at all. The content is byte-for-byte what the (already fixed) hook
  intends to write, so writing it unconditionally cannot be wrong, and the `grep` guard still makes
  a correct file a no-op.
- `KEYMAP` extraction now accepts a **bare** `KEYMAP=de` as well as `KEYMAP="de"`, using the same
  quote-stripping + trailing-comment-tolerant sed the fixed packager hook uses. The old
  quoted-only pattern (`KEYMAP="\([^"]*\)"`) yielded empty on the bare form that
  `Void_Linux_Live` writes from two places (`installer.sh` and `dracut/vmklive/locale.sh`), so a
  non-US live-ISO install silently installed the **`us`** layout with no error anywhere — a latent
  wrong-keyboard-layout bug in its own right.
- A `case` token guard (`''|*[!a-zA-Z0-9_-]*)` → `us`) keeps any hostile or malformed `rc.conf`
  value from being interpolated into the RON string.

### Live on-box fix

The already-installed target was repaired in place from the live environment (btrfs `@` remounted
rw, file created, `sync`, remounted ro — btrfs `device stats` all zero beforehand):
`/usr/share/cosmic/com.system76.CosmicComp/v1/xkb_config`, 104 bytes, `layout: "us"`, derived from
the target's `KEYMAP="us"`. Awaiting the boot that proves it.

### Gates

`bash -n` clean; `checks/check-heredocs.sh` ALL CLEAN (72 heredocs); `checks/check-defaults.sh` ALL
CONSISTENT; `checks/check-pkg-preflight.sh` ALL COVERED (164 preflight packages, 170 literals). The
new ensure-logic was additionally exercised standalone over 8 cases — quoted/bare/commented-out/
hostile `KEYMAP`, missing file, corrupt file, and already-correct file (the last correctly a no-op).

## Beta-v2.9.78 — `[MULTI-FS-RESUME-HELPER]` (`_region_fs_of`/`_region_carved` were defined inside the skipped-on-resume config block, so a `-r` run hit `command not found` when the region-mount loop ran)

`SCRIPT_VERSION` bumped to `Beta-v2.9.78`; era row added to the script header VERSION-HISTORY;
index row added above; this section added as the newest detail section.

### Context

The helper pair `_region_carved()` and `_region_fs_of()` (Beta-v2.9.66) was defined at the top of
the `[SUBVOL-GATES]` resolver block, which is guarded by `if [ "$RESUME" != "1" ]` (the SKIPPED
interactive-config section). The functions were used elsewhere, unguarded, by:

- line ~5984: `if _region_carved "$_fldr"; then` in the subvol-list builder
- lines ~6013/6034/6035: `if ! _region_carved var; then` in SUBVOL_LIST assembly
- lines ~6202–6223 / LD...: `! _region_carved {home,opt,srv,var,cache}` etc.
- line ~5831: `_rr_fs="$(_region_fs_of "$_rr")"` in the fresh partition-carved format loop
- line ~6277/6410: the mount-region and fstab loops (unguarded — they run on resume)

On a fresh install the function definitions executed before any of these call sites, so the bug
was invisible; on a resumed (`-r`) run the entire interactive-config block is skipped, `_region*`
become undefined, and the first unguarded call dies with `command not found` (exit 127 inside
`$(...)`). This is exactly what happened on the resumed 2026-10-05 run: Stage 1 aborted at the
region mount block, `cleanup_on_failure`/`cleanup` removed /mnt, and the install no-op'd until
a fresh run is started.

### Fix

- `_region_carved()` and `_region_fs_of()` (and the explanatory Beta-v2.9.66 comment block) moved
  up to unconditional top-level scope — just above the `if [ "$RESUME" != "1" ]` guard.
- `_subvol_ask()` is NOT moved deliberately: it is only used at lines ~4432/4440, which are inside
  the same skipped block, so it is only needed exactly when that block runs.

### Gates

`bash -n` clean; `checks/check-heredocs.sh` ALL CLEAN (72 heredocs); `checks/check-defaults.sh` ALL
CONSISTENT.

## Beta-v2.9.77 — `[COSMIC-TRUST-ANCHOR-TTY]` (the 2.9.76 trust-anchor gate aborted every COSMIC install: it probed stdin, which is the Stage-2 chroot heredoc)

`SCRIPT_VERSION` bumped to `Beta-v2.9.77`; era row added to the script header VERSION-HISTORY
(`# Beta-v2.9.77   [COSMIC-TRUST-ANCHOR-TTY]`); index row added above; this section added as the
newest section.

### Context

Beta-v2.9.76 replaced the blind `-y` COSMIC repo sync with a deliberate, machine-verified trust
anchor. Its unattended-run guard was:

```bash
if [ ! -t 0 ]; then
    echo "FATAL: the COSMIC repo sync needs to confirm its signing key..."
    exit 1
fi
```

but `install_cosmic()` runs inside Stage 2, where the parent script feeds the chroot via
`chroot /mnt /bin/bash << 'CHROOT_EOF'` — so stdin is the heredoc text, never the operator's
terminal. `[ -t 0 ]` was therefore always false-friendly (i.e. always "not a tty"), the guard
fired, and every COSMIC install aborted at the key-confirmation step with
"session has no terminal" even on a fully interactive run.

### Fix

- The guard now probes the real terminal (`[ -r /dev/tty ] && [ -w /dev/tty ]`; /dev is
  bind-mounted into the chroot, and the chroot's controlling tty is the operator's terminal).
- The key-import prompt is fed from the real terminal: `xbps-install -Sy < /dev/tty`.

### Verification (2026-10-05, live)

- `bash -n Void_Linux_Installer.sh` clean; `checks/check-heredocs.sh` ALL CLEAN;
  `checks/check-defaults.sh` ALL CONSISTENT.
- Re-derived the served key's DER SHA-256 from the live index exactly as the anchor check does
  (base64 → `openssl rsa -pubin -outform DER` → `openssl dgst -sha256`): it now equals the pinned
  `_cosmic_key_expected` (`83ffd154...d2e7b`) — the repo has since been republished under the new
  key, so the anchor check will now PASS once the operator confirms the import prompt.

## Beta-v2.9.76 — `[COSMIC-TRUST-ANCHOR]` (the COSMIC repo sync auto-accepted the third-party signing key, so a substituted anchor was trusted silently)

`SCRIPT_VERSION` bumped to `Beta-v2.9.76`; era row added to the script header VERSION-HISTORY
(`# Beta-v2.9.76   [COSMIC-TRUST-ANCHOR]`); index row added above; this section added as the
newest section.

### Context

`install_cosmic()` synced the third-party repository with:

    xbps-install "${_xbps_cache[@]}" -Sy

`-y` is xbps's "assume yes to ALL questions". That includes the prompt that imports and trusts
a repository's signing key. The consequence is not a cosmetic one: the entire security property
of a pinned anchor is that the key is an *input the operator confirms*, not an *output the
served repo dictates*. With `-y`, whatever key the repo presented was accepted automatically,
and the operator never saw a fingerprint — so a substituted key, a hostile mirror, or a
hijacked CDN would have been trusted without a word.

### The fix

Two independent layers, because either alone is insufficient.

**Layer 1 — make the trust decision visible.** `-y` is removed from that sync, the expected
fingerprint is printed for comparison, and a `[ ! -t 0 ]` guard refuses an unattended run up
front with an actionable message rather than hanging on a prompt nobody can answer or silently
auto-accepting. (The `-y` on the later `xbps-install -y "$@"` that actually installs the COSMIC
packages is unrelated and deliberately unchanged.)

**Layer 2 — make it machine-checkable.** A prompt still trusts whatever a human reads, and a
human who types `Y` at a substituted key has trusted it. So the fingerprint is pinned as a
constant in the installer and checked after the sync:

1. the pinned key **must be present** in `/var/db/xbps/keys`, and
2. **no key outside** `{pinned, two stock Void keys}` may be present.

Both conditions are required. Condition 1 rejects a repo presenting a different key; condition 2
rejects a stale anchor from a previous repo or an injected third key. Condition 2 is an
*allowlist*, not "nothing else is allowed" — a provisioned Void system already trusts both stock
Void keys, so the stricter reading would abort every legitimate install. (That was not a
hypothetical: the first draft rejected everything unexpected and testing against a real Void
masterdir keyring showed exactly that failure.)

The pin is deliberately **not** read from the repository being verified. A fingerprint fetched
from the served index only proves the index is self-consistent — and an attacker who controls
the repo would serve their own key right alongside it. The pin lives in the installer, which is
the party actually making the trust decision.

### Implementation notes worth keeping

`cosmic_key_fingerprint()` extracts a key's real fingerprint from an xbps key plist. Three
things each produce a *wrong but plausible* hash instead of an error, so all three are handled:

- the plist's base64 blob decodes to **PEM text, not DER**; hashing the decoded bytes directly
  yields `777f5d17...`, which is not the fingerprint xbps means. Re-encode to DER first.
- `openssl dgst` on an **empty stream** returns `e3b0c442...` (the SHA-256 of the empty string),
  so a malformed blob otherwise reads as a genuine fingerprint. The key is parsed with
  `openssl rsa -pubin -noout` before it is hashed.
- capturing DER in a **shell variable strips its NUL bytes**, corrupting the bytes and yielding
  yet another bogus hash. Stream into `dgst` instead.

Unreadable keyring entries now fail **closed** rather than being skipped — a key we cannot parse
is a key we cannot vouch for. The keyring *filename* is likewise not trusted: a stock Void key
stored under the pinned fingerprint's filename is still rejected, because the comparison is on
key content.

On placement: the check reads `/var/db/xbps/keys` from inside the `chroot /mnt` block that
`install_cosmic()` is defined in, so it inspects the *target's* keyring — the one xbps will
actually verify these packages against. That is the keyring that matters, and it is not the same
as the live environment's: the installer copies the host keyring into the target at bootstrap
and the COSMIC key is imported into it during the sync.

### Known consequence

The third-party repository has not yet been republished under the new key, so the live index
still serves the superseded one. **Until that upload lands, `install_cosmic()` aborts** on the
pin check. This is fail-closed and intended — no wrong key is trusted — but the COSMIC install
cannot complete in the meantime.

---

## Beta-v2.9.75 — `[XKB-CONFIG-QUOTING]` (the `cosmic-desktop-full` post-install hook wrote invalid RON into cosmic-comp's `xkb_config`, crash-looping the cosmic-greeter into a grey, blinking login screen)

`SCRIPT_VERSION` bumped to `Beta-v2.9.75`; era row added to the script header VERSION-HISTORY (`# Beta-v2.9.75   [XKB-CONFIG-QUOTING]`), index row added above; this section added as the newest section.

### Context

After the `Beta-v2.9.70` SDDM/cosmic-greeter double-DM conflict was resolved (remove the `sddm` runsvdir link, `DISPLAY_MANAGER="cosmic-greeter"`), the next boot on <host> still showed a grey, blinking screen with `Ctrl+Alt+F2`..`F6` not reaching a login. The greeter stack was crash-looping:

- `cosmic-greeter-daemon/current`: `errors loading cosmic-comp config: [RonSpanned(... ExpectedComma ... line 4, col 11 ...)]` every ~2s, then `check_children: greeter exited without creating a session`.
- `cosmic-greeter-session.log`: `Error trying to flush the wayland display: Broken pipe` flood, `Unable to become drm master, assuming unprivileged mode`.

### The fix

Culprit: `/usr/share/cosmic/com.system76.CosmicComp/v1/xkb_config`, corrupted by the `cosmic-desktop-full` xbps post-install hook (`void-packages-1.2/srcpkgs/cosmic-desktop-full/INSTALL`):

```sh
layout=$(grep 'KEYMAP=' /etc/rc.conf | cut -d= -f2)   # -> "us"  (quotes kept)
cat >> .../xkb_config <<EOF
(
...
layout: "us",
...
)
EOF
sed -i "s/us/$layout/" .../xkb_config                 # -> layout: ""us"",
```

`layout: ""us"",` is not valid RON, which is exactly the `ExpectedComma @ line 4, col 11` the daemon reported. The hook runs only on a FRESH install (`UPDATE=no`), so a one-shot repair of the file is durable — but the bug still ships, so it is fixed in the installer too:

- The COSMIC DE branch now rewrites `xkb_config` to the canonical cosmic-config form after `install_cosmic cosmic-desktop-full`, taking the layout UNQUOTED from the chroot's `/etc/rc.conf` `KEYMAP` (already pinned to the live console keymap by `Beta-v2.6.9 [KEYMAP]`) and defaulting to `us`.
- The rewrite is skipped when the file already carries that exact `layout:` line, so a correct hook run stays a no-op. It is idempotent (single `cat >`, never an append).

The packaging source was fixed in the same pass (all three `void-packages*/srcpkgs/cosmic-desktop-full/INSTALL` trees: quotes stripped via `sed -n`, `us` fallback for any value that is not a plain layout token, layout interpolated into the heredoc instead of `sed`-substituted afterwards, `cat >` instead of `cat >>`); template `revision` bumped `_2` → `_3`.

### Validation

- Reproduction: the ORIGINAL hook, run against `KEYMAP="us"`, emits `layout: ""us"",` — byte-identical to the corruption preserved in `Projects/Void_Linux_Projects/xkb_config-corruption-20261005/xkb_config.corrupted-reconstruction`.
- The PATCHED hook passes 16/16 fixtures (`KEYMAP="us"`, `"de"`, `"gb"`, missing, unquoted, commented, empty, and a `KEYMAP="us", "ru"` injection attempt) under BOTH `bash` and `dash` — the packaged hook runs under `/bin/sh`, so POSIX-only constructs are used. Each case also asserts a single tuple block after two runs (the `cat >` idempotency).
- For `KEYMAP="us"` the produced file is byte-identical to the canonical form applied by hand on <host> 2026-10-05.
- Package rebuild: `cosmic-desktop-full-1.9.0_3` rebuilt with the chroot's `xbps-create` 0.60.7. The pipeline was validated by first rebuilding `1.9.0_2` from the UNPATCHED hook — `props.plist`, `INSTALL` and `files.plist` all came out byte-identical to the published signed package — then the fixed `_3` differs from it ONLY in the two version strings and the hook region, with no executable `sed -i "s/us/$layout/"` line left.
- Live on <host>: the greeter presented a login and `<user>` reached the COSMIC desktop; `cosmic-greeter-daemon/current` shows ZERO config errors for the post-fix boot (last error timestamp is the pre-fix boot).

### Note — template/published dependency drift (unrelated to this fix, not changed here)

The current `void-packages-1.9` template `depends=` lists two packages the published `cosmic-desktop-full-1.9.0_2` does NOT depend on: `cosmic-launcher` and `xdg-desktop-portal-cosmic`. The verification artifact above was deliberately built with the PUBLISHED `_2` dependency set so the revision bump isolates the hook fix; the next real `xbps-src` build from the template will additionally pull those two. Decided separately, not folded into this fix.

## Beta-v2.9.74 — `[USB-AUTOMOUNT]` (COSMIC installs had no removable-media automounter: no udisksd runit service, no udiskie — now shipped and autostarted)

`SCRIPT_VERSION` stays at the era checkpoint (Beta-v2.9.13); era row added to the script header VERSION-HISTORY (`# Beta-v2.9.74   [USB-AUTOMOUNT]`), index row added above; this section added as the newest section.

### Context

On the 2026-10-04 fresh non-encrypted COSMIC install (<host>), `udisks2-2.10.1_1` was present (pulled by cosmic-files) but `/etc/sv/udisksd` did not exist and `pgrep udisksd` was empty — Void's udisks2 package ships only the D-Bus activation unit, so on runit nothing supervised the disk service. `gvfs` was not installed, and the installer's COSMIC DE branch carried no automount provision (gvfs-based auto-mount is only wired for the GNOME/KDE/Cinnamon/MATE/Xfce/LXQt branches). Net effect: plugging in a USB stick did nothing unless the user manually mounted it from cosmic-files.

### The fix

- The COSMIC DE branch now `install_pkgs udiskie` and drops `/etc/xdg/autostart/udiskie.desktop`, which runs `/usr/local/sbin/udiskie-guard` — the same session-readiness guard pattern as the polkit agent (wait for the Wayland socket + reachable session bus, then run `udiskie`, respawn if it dies).
- The installer creates `/etc/sv/udisksd/{run,log/run}` (svlogd to /var/log/udisksd) and first-boot-links it into runsvdir/default, so udisksd is supervised on every boot.
- `udiskie` + `udisks2` added to the PKG_PREFLIGHT superset.

`bash -n` clean.

## Beta-v2.9.73 — `[ELOGIND-RUN-SELFHEAL]` (Void's elogind daemonizes itself, so the stock runit run script spawned a ~1x/sec respawn loop flooding the kernel log — fixed run script shipped, applied at install time, and restored from /etc/rc.local on every boot)

`SCRIPT_VERSION` stays at the era checkpoint (Beta-v2.9.13); era row added to the script header VERSION-HISTORY (`# Beta-v2.9.73   [ELOGIND-RUN-SELFHEAL]`), index row added above; this section added as the newest section.

### Context — the crash-loop defect on a fresh elogind install

On the 2026-10-04 fresh non-encrypted COSMIC install (<host>), verification found ONE real defect: the `elogind` runit service crash-looped. `sv status elogind` -> `down: elogind: 1s, normally up, want up`, `sv check` timed out, runsv respawned ~1x/sec, and ~82% of the kernel ring buffer was `elogind[PID]: elogind is already running as PID 2330` — yet the daemon itself (`elogind-daemon`, PID 2330, PPID 1) was healthy and loginctl/SDDM/COSMIC all worked.

Root cause (verified on-box): the VOID build of elogind still self-daemonizes (double-fork, writes `/run/elogind.pid`, reparents the serving `elogind-daemon` to PID 1), but the PACKAGED `/etc/sv/elogind/run` + wrapper `exec` it WITHOUT `-D`. runsv's supervised child therefore exits immediately, so runsv believes the service died and restarts it forever. Upstream Void packaging quirk, NOT an installer logic bug.

### The fix

- Ships `/root/tools/elogind.run.fixed`: a run script that, when `/run/elogind.pid` points at a live process, stays alive and sleep-waits for it to exit (so runsv has a live child and does not respawn); otherwise starts elogind the stock way. It never signals the live daemon (the daemon runs in its own session, so a runsv TERM to our process group cannot reach it).
- Ships `/root/tools/re-fix-elogind-run.sh`: idempotent restorer, called from `/etc/rc.local` every boot (same `[ELOGIND-RUN-SELFHEAL]` pattern as `re-shadow-xbps.sh`) — needed because the elogind package OWNS `/etc/sv/elogind/run` and any upgrade overwrites the fix.
- Applies the fix IMMEDIATELY at install time when `SESSION_STACK=elogind` (stock script kept at `/etc/sv/elogind/run.orig`).
- rc.local block is placeholder-guarded (`__SESSION_STACK__`, sed-substituted at generation like the other links) so turnstile installs never arm the self-heal.

### Validation

Applied live on <host> 2026-10-04 (no signal ever sent to the live daemon): `sv status` -> `run: (pid 27196)`, `sv check` -> `ok`, supervised PID stable >950s, kernel spam frozen, daemon PID 2330 unchanged, COSMIC session healthy. Self-heal restore path tested by overwriting the run script and re-running the restorer (restored byte-identically). Validated ACROSS A REBOOT: next boot's `sv status` = run, `sv check` = ok, sha256 of the run script = the fixed copy, exactly one historical `already running` line in dmesg (one runsv respawn before the rc.local self-heal ran), zero climb.

## Beta-v2.9.72 — `[GAME-VULKAN]` (a fresh install had no real Vulkan ICD for the detected GPU; now the game gate installs the right Mesa Vulkan driver, 64-bit + 32-bit)

`SCRIPT_VERSION` stays at the era checkpoint (Beta-v2.9.13); era row added to the script header VERSION-HISTORY (`# Beta-v2.9.72   [GAME-VULKAN]`), index row added above; this section added as the newest section.

### Context — the wrong Vulkan ICD on a fresh install

After the `[STEAM-32BIT]` fix (Beta-v2.9.71), relaunching Steam on the round-3 KDE box got further but still died: the client reached its graphics init and the Vulkan GPU-topology probe returned `-9` (`VK_ERROR_INCOMPATIBLE_DRIVER`). Probing the box showed why — `/usr/share/vulkan/icd.d/` contained only:

```sh
virtio_icd.i686.json      # virtual-GPU driver shipped by vulkan-loader /
virtio_icd.x86_64.json    # mesa's DRI+Gallium metapackage, NOT a real-GPU ICD
```

and `/usr/lib32/vulkan/icd.d/` was empty. The virtualization-only `virtio_icd` is the only ICD a stock install ships, because nothing in the base DE path depends on a vendor Vulkan driver: `mesa`/`mesa-dri` (64-bit) give OpenGL, and the vendor *Vulkan* drivers (`mesa-vulkan-radeon`, `mesa-vulkan-intel`, `mesa-vulkan-nouveau`) are separate packages Void does not install by default. So on any real AMD/Intel hardware the first Vulkan call from any game stack — Steam's topology query, a 32-bit game's `libvulkan.so.1`, DXVK/VKD3D under Proton/Wine — hit the virtual-GPU ICD, which cannot enumerate a real device, and failed `-9`. The box smoke-tested this: installing `mesa-vulkan-radeon mesa-vulkan-radeon-32bit` (plus the 32-bit Gallium/DRI stack) and relaunching Steam was clean (Steam launched, no assert, no crash upload).

### The fix

A new `[GAME-VULKAN]` block in `[INSTALL-APPS]` installs the **detected** GPU family's Mesa Vulkan driver (64-bit + `-32bit` each) whenever `INSTALL_ANY_GAME` is true:

```sh
# [GAME-VULKAN] (Beta-v2.9.72): a fresh install ships only virtio_icd, so any
# real GPU returns VK_ERROR_INCOMPATIBLE_DRIVER (-9) when a game stack probes
# Vulkan. Install the DETECTED family's Mesa Vulkan driver (64+32bit) whenever
# ANY game launcher is selected, gated on the live-box probe — no new prompt.
if [ "$INSTALL_ANY_GAME" = "true" ]; then
    [ "$HAS_AMD_GPU" = "yes" ] && install_pkgs mesa-vulkan-radeon mesa-vulkan-radeon-32bit
    [ "$HAS_INTEL_GPU" = "yes" ] && install_pkgs mesa-vulkan-intel mesa-vulkan-intel-32bit
    if [ "$HAS_NVIDIA_GPU" = "yes" ] && [ "$INSTALL_NVIDIA" != "true" ]; then
        install_pkgs mesa-vulkan-nouveau mesa-vulkan-nouveau-32bit
    fi
fi
```

### Gating — general game install ∨ GPU detection, no new prompt

- **Gate is `INSTALL_ANY_GAME`** (the existing compound flag: Steam ∨ Lutris ∨ Heroic ∨ Bottles, computed in Stage 1), **not** Steam alone. Vulkan is the shared rendering path for every launcher — Steam-native, Lutris/Wine, and the Flatpak-delivered Heroic/Bottles all call the same `libvulkan.so.1` — so a Lutris-only install needs the ICD exactly as much as a Steam-only one.
- **Which ICD is GPU-detection gated**, reusing the Stage-1 `[HARDWARE-REVIEW]` probe that already exports `HAS_AMD_GPU`/`HAS_INTEL_GPU`/`HAS_NVIDIA_GPU` into the chroot: AMD → `mesa-vulkan-radeon`(+`-32bit`), Intel → `mesa-vulkan-intel`(+`-32bit`), NVIDIA-with-proprietary (`INSTALL_NVIDIA=true`) → the driver ships its own ICD so nothing extra is pulled, NVIDIA-without → `mesa-vulkan-nouveau`(+`-32bit`). Installing radeon on Intel hardware would reproduce `-9` in reverse, which is why this is hardware-gated and not a standing list. A box with no detected GPU (headless/server) ships no Vulkan payload.
- **`mesa-dri-32bit` (the Steam GLX fix) stays Steam-gated** — it is the 32-bit *OpenGL* DRI the 32-bit Steam client UI needs via GLX; the game-install gate only adds the *Vulkan* ICDs. No new prompt, `INSTALL_ANY_GAME` users who picked a launcher get drivers; a no-game box gets nothing.
- The six names (`mesa-vulkan-radeon`, `mesa-vulkan-radeon-32bit`, `mesa-vulkan-intel`, `mesa-vulkan-intel-32bit`, `mesa-vulkan-nouveau`, `mesa-vulkan-nouveau-32bit`) are added to `PKG_PREFLIGHT` — stage-1 **validation only**, they never install anything by themselves.

`bash -n` clean; `checks/check-pkg-preflight.sh` clean.

## Beta-v2.9.71 — `[STEAM-32BIT]` (the Steam branch pulled the client bootstrap only; now it also installs the canonical 32-bit runtime set, gated strictly on the Steam choice)

`SCRIPT_VERSION` stays at the era checkpoint (Beta-v2.9.13); era row added to the script header VERSION-HISTORY (`# Beta-v2.9.71   [STEAM-32BIT]`), index row added above; this section added as the newest section.

### Context — why a fresh Steam install always missed `libGL.so.1`/`libdrm.so.2`

Void's `steam` package (nonfree) is a **client bootstrap** — its `run_depends` are downloader/display plumbing (zenity, curl, dbus, freetype, fontconfig, gdk-pixbuf, tar, bash…), **none** of the 32-bit OS libraries. The Steam client is a 32-bit binary, and the GL/DRI pair (`libGL.so.1`, `libdrm.so.2`) is deliberately taken from the **host** — so the very first launch on a fresh install always reported "You are missing the following 32-Bit libraries … libGL.so.1 & libdrm.so.2". Proven on the round-3 KDE box: `libglvnd-32bit`/`libdrm-32bit` existed in the multilib repo (which the installer enables at line 5471) but were never installed; installing them (which auto-pulled `libX11-32bit`/`libxcb-32bit`/`libXau-32bit`/`libXdmcp-32bit`/`libpciaccess-32bit`) cleared the error, and the packaged `steamdeps` checker then reported the runtime satisfied.

### The fix

The `[INSTALL-APPS]` Steam branch now installs the Steam multilib runtime set **together with** `steam` in one `install_pkgs` call:

```sh
[ "$INSTALL_STEAM" = "true" ] && install_pkgs steam libgcc-32bit libstdc++-32bit \
    libglvnd-32bit mesa-dri-32bit libdrm-32bit libX11-32bit libXext-32bit \
    libXfixes-32bit libXrandr-32bit libXcursor-32bit libXi-32bit libXrender-32bit \
    libXinerama-32bit libXxf86vm-32bit libxcb-32bit freetype-32bit \
    fontconfig-32bit libpulseaudio-32bit alsa-plugins-pulseaudio-32bit
```

### Gating — Steam install only, nothing explicit

- The set lives **only** inside the `[ "$INSTALL_STEAM" = "true" ]` branch. There is **no new prompt** and no unconditional install: `INSTALL_STEAM` stays lean-default OFF, so a box that never opts into Steam ships **zero** game 32-bit libraries.
- The `PKG_PREFLIGHT` additions (`alsa-plugins-pulseaudio-32bit`, `fontconfig-32bit`, `freetype-32bit`, `libdrm-32bit`, `libgcc-32bit`, `libglvnd-32bit`, `libpulseaudio-32bit`, `libstdc++-32bit`, `libX11-32bit`, `libxcb-32bit`, `libXcursor-32bit`, `libXext-32bit`, `libXfixes-32bit`, `libXi-32bit`, `libXinerama-32bit`, `libXrandr-32bit`, `libXrender-32bit`, `libXss-32bit`, `libXxf86vm-32bit`, `mesa-dri-32bit`) are stage-1 **validation** names — the 2.9.40 pre-flight resolves them against the live union pool but installs nothing by itself, so they can never pull the 32-bit stack on their own.

`bash -n` clean; `checks/check-pkg-preflight.sh` clean (every new `install_pkgs` literal now covered).

## Beta-v2.9.70 — `[ELOGIND-NO-STRAY-KILL]` (the cosmic-greeter "stray elogind PID sweep" killed the LIVE logind — removed, `sv check elogind` is the only gate)

`SCRIPT_VERSION` stays at the era checkpoint (Beta-v2.9.13); era row added to the script header VERSION-HISTORY (`# Beta-v2.9.70   [ELOGIND-NO-STRAY-KILL]`), index row added above; this section added as the newest section.

### Context — the sweep's premise, and how it killed the serving daemon

The cosmic-greeter `/etc/sv/cosmic-greeter/run` heredoc shipped a "stray elogind PID sweep" that was meant to clear a leftover `elogind` so `pam_elogind.so` would register a fresh session for greetd:

```sh
if [ -d /var/service/elogind ]; then
    sv check elogind >/dev/null
    elogind_pid=$(cat /var/service/elogind/supervise/pid 2>/dev/null)
    for pid in $(pgrep -x 'elogind'; pgrep -x 'elogind-daemon'); do
        [ "$pid" = "$elogind_pid" ] || kill "$pid"
    done
fi
sv check elogind >/dev/null || exit 1
```

The guard's exception pid (`supervise/pid`) is the pid runit spawned. On a live Void box elogind **daemonizes**: the serving process is a single `elogind-daemon` reparented to PID 1 — observed directly on `<host>`:

- `pgrep -x 'elogind'` → **no match** (`comm` is `elogind-daemon`, not `elogind`).
- `pgrep -x 'elogind-daemon'` → **exactly one pid** = the serving daemon (PID 2688, PPID 1, `argv0` literally `elogind-daemon` per `/proc/2688/cmdline`/`exe`).
- `runsv`'s live child set contained only the vlogger (`ps --ppid` of runsv showed one child), so `supervise/pid` by construction differs from the daemon pid.

Result: whenever the sweep ran on a box whose elogind had daemonized, the guard's `[ "$pid" = "$elogind_pid" ]` **never matched**, and the sweep `kill`ed the LIVE serving logind. Killing elogind while a graphical session holds it drops the seat/session registration, the `org.freedesktop.login1` name and the `/run/user/<uid>` tree — the session/desktop hangs immediately. That is exactly the observed "you killed an elogind pid" live-crash incident the user remembers, and the same kill block existed re-runnable in the era's `Debug/Cosmic-Greeter/fix-cosmic-greeter{2,5}.sh` on-box scripts. On the healthy KDE box the sweep is dormant (no cosmic-greeter service is installed there), which is why the reinstall boots clean.

A second latent failure made it strictly worse: if `supervise/pid` could not be read (first-boot `/var/service` dangling per the AGENTS invariant, permission, race), `elogind_pid` is empty and the guard fails open — every `pgrep`'d pid gets `kill`ed.

### Why the sweep can simply be removed (no behavior loss)

- elogind is **single-instance by design**: a duplicate daemon cannot bind `org.freedesktop.login1`/the elogind socket while the serving one holds it, so a "killable stray" effectively cannot exist.
- If the supervised elogind dies, **runit restarts it**; the greeter run script already exits the service via `sv check elogind >/dev/null || exit 1` while runsvdir is up.
- The `[ -d /var/service/elogind ]` guard wrapped ONLY the kill block; the unconditional `sv check elogind || exit 1` after it already defined the no-elogind behavior (greeter service exits) — so removing the whole `if` block is behavior-preserving on every box except that the live-daemon kill is gone.

The heredoc now ends the elogind handling at the single authoritative gate:

```sh
sv check elogind >/dev/null || exit 1
```

### Validation

`bash -n` clean; `checks/check-heredocs.sh` ALL CLEAN (the edited cosmic-greeter run-script heredoc included). Live re-proof on a real cosmic-greeter (COSMIC) install is pending — the current `<host>` box is KDE/SDDM and never exercised this heredoc; the change is deliberately conservative (removal of a kill, gate preserved). See the validation backlog.

## Beta-v2.9.69 — `[FLATPAK-NM-DISPATCH-LOCK]` (the 2.9.68 "up does not re-fire" premise was false — the dispatcher now serializes the drain with an exclusive flock)

`SCRIPT_VERSION` stays at the era checkpoint (Beta-v2.9.13); era row added to the script header VERSION-HISTORY (`# Beta-v2.9.69   [FLATPAK-NM-DISPATCH-LOCK]`), index row added above; this section added as the newest section.

### Context — the premise behind `[FLATPAK-DNS-LATE]` was wrong

Beta-v2.9.68's `[FLATPAK-DNS-LATE]` fix shipped with the assumption "`up` does not fire again on a stable link", which is why missing the early-DNS `up` stranded the queue with no retry. That premise is FALSE. On the very box the fix was written against (`<host>`), the pre-lock dispatcher fired **five** times in ~30 minutes (12:41 / 12:51 / 13:01 / 13:06 / 13:11): `up` re-fires on DHCP renewals and link flaps — and on this install's USB-ethernet-through-`br0` link it does so repeatedly. Each firing spawns a FRESH full queue-drain, so five concurrent `flatpak install` processes piled up, all racing the same OSTree repo and collectively starving on the box's ~120 KB/s uplink — effectively zero progress for ~50 minutes while the queue stayed unstamped. The `connectivity-change` arm from 2.9.68 is still a real improvement (it catches the DNS-resolved transition explicitly), but it also adds one more event that can arrive back-to-back with `up`.

### The fix — one drain at a time

The dispatcher now wraps the drain in an exclusive lock file:

```sh
exec 9>/var/lock/flatpak-firstboot.lock
flock -n 9 || exit 0
```

`flock -n` is atomic: the first firing in a burst wins the lock and runs the drain; every other firing exits 0 immediately (no work, no error), re-arming on whichever network event comes next. The lock is released automatically when the process exits — including on failure or kill — so a crashed drain never wedges the queue; a later event simply wins the lock and retries. `flock` ships in util-linux (part of `base-system`). A completed drain still leaves the `.done` stamp, so the whole design collapses bursts into one serialized attempt with zero wasted concurrency.

### Live validation (queue drain + box refresh)

The stranded queue on `<host>` was drained live: Brave `1.95.102`, Heroic `v2.22.3`, Bottles `67.3` all installed, `/var/log/flatpak-firstboot.done` stamped, and the queue file removed. The running box's dispatcher was refreshed to the 2.9.68 form with a `.bak-20260917`. The flock lines themselves are repo-pending real-hardware proof — this box's flagged `up` bursts are exactly the trigger they exist to collapse, and they ship on the next real install.

### Validation

`bash -n` clean; `checks/check-heredocs.sh` ALL CLEAN; `checks/check-defaults.sh` all consistent (no prompt surface touched).

## Beta-v2.9.68 — `[PARTUUID-NODEPS]` + `[INSTALL-CONFIG-BACKENDS]` + `[INSTALL-CONFIG-SSHKEY]` + `[FLATPAK-DNS-LATE]` (four fixes from reviewing a fresh carved-ENCRYPT install against the script)

`SCRIPT_VERSION` stays at the era checkpoint (Beta-v2.9.13); era row added to the script header VERSION-HISTORY (`# Beta-v2.9.68   [PARTUUID-NODEPS]/...`), index row added above; this section added as the newest section.

### Context

A fresh install was made with the corrected Beta-v2.9.66/2.9.67 script (carved ENCRYPT: `/home` ext4 + `/home/<user>/Games` ext4, KDE/SDDM, limine). The install was then reviewed against the script. The two target fixes from the prior era both verified good (`_region_fs_of` produced ext4 on `void1`/`void2` end-to-end — proving Runbook Scenario D — and the `kernel_cmdline="rd.vconsole.keymap=us"` parameter was present in `90-system.conf *and* baked into all three initramfs `etc/cmdline.d/`, alongside the `us.map` data). The review surfaced four smaller issues.

### 1. `[PARTUUID-NODEPS]` — `lsblk` descended into the LUKS container's children

`lsblk` descends into children by default, so `BTRFS_PARTUUID=$(lsblk -no PARTUUID "$PART_SYS")` — with `PART_SYS` being the LUKS container `/dev/nvme0n1p2`, whose device-mapper children are the inner GPT partitions `void1`/`void2`/`void3` — captured **four** PARTUUIDs (one per line) instead of one. `SYSPREFIX_BTRFS="guid(${BTRFS_PARTUUID})"` was therefore written into `/etc/void-installer/limine-env` and `chroot_env` as a malformed multi-line value:

```
SYSPREFIX_BTRFS="guid(
eee6788c-6e5d-4427-9d5b-1a77a88f195a
ea16b876-2732-41ce-9ba2-343f618d95c5
9d903153-9864-4d6c-8edb-8d52f662c74b
d96bc2bc-9e7a-44b7-bf6d-8f3236594d69)"
```

`SYSPREFIX_ESP` (the boot-critical value used by `void-limine-write-conf` for `kernel_path`/`module_path`) escaped only because the ESP vfat partition happens to have no children. `SYSPREFIX_BTRFS` is currently consumed nowhere (dead since the `btrfs-direct` kernel mode was removed), so the blast radius today was cosmetic — but it was one partition topology away from corrupting the boot path. Fix: `lsblk -no PARTUUID --nodeps` for both captures, pinning exactly the named partition.

### 2. `[INSTALL-CONFIG-BACKENDS]` — the as-built config omitted Steam and the container backends

The fresh box had `steam` + `podman` installed and `@containers` mounted, yet `install-config` contained no row explaining any of them (only the game-launcher umbrella `INSTALL_LUTRIS`/`INSTALL_HEROIC`/`INSTALL_BOTTLES`/`INSTALL_WINE`/`INSTALL_GAMEMODE`/`INSTALL_ANY_GAME` and `PROVISION_GAME_SUBVOL` were recorded). The `[DOCS-LOG]` record did list `steam` in its `GAMING=` row, but the machine-readable as-built file did not. Fix: emit `INSTALL_STEAM`, `INSTALL_DOCKER`, `INSTALL_PODMAN_ROOTLESS`, `INSTALL_PODMAN_ROOTFUL`, and the `PROVISION_DOCKER_SUBVOL`/`PROVISION_PODMAN_SUBVOL`/`PROVISION_PODMAN_ROOTLESS_SUBVOL` rows (the subvol flags that the `[SUBVOL-GATES]` resolver actually acts on).

### 3. `[INSTALL-CONFIG-SSHKEY]` — SSH rows advertised a key that did not exist

`SSH_KEY_COMMENT` and `SSH_KEY_PROTECTED` are set to their prompt defaults (`<user>@<hostname>` / `yes`) **before** the `[SSH-KEYS]` prompts and exported unconditionally, so `install-config` always wrote them — even on a run that imported and generated nothing. The reviewed install was exactly that: `~/.ssh` was absent, yet the config read `SSH_KEY_COMMENT="<user>@<host>" / SSH_KEY_PROTECTED="yes"`. Fix: derive `SSH_KEY_PRESENT` from the actual deposit (`~/.ssh/id_ed25519` or `~/.ssh/imported`) and emit the comment/protection rows only when present; otherwise a single truthful `SSH_KEY_PRESENT="no"` plus an explanatory comment.

### 4. `[FLATPAK-DNS-LATE]` — the first-boot flatpak queue could strand

The `[FLATPAK-NM-DISPATCH]` script armed only on `up`/`vpn-up`. On the reviewed box the first `up` fired before NetworkManager finished its connectivity check, so the run logged `Unable to load summary from remote flathub: ... Could not resolve hostname` and left no `.done` stamp — and because `up` does not fire again on a stable link, the queued apps (`com.brave.Browser`, `com.heroicgameslauncher.hgl`, `com.usebottles.bottles`) never installed. Fix: also arm on `connectivity-change`, which NM emits when connectivity transitions (e.g. `LIMITED`/`NONE` → `FULL` once DNS resolves); the existing `.done` guard keeps a successful first run idempotent.

### Validation

`bash -n` clean; `checks/check-heredocs.sh` 65 heredocs ALL CLEAN (the edited dispatcher heredoc included); `checks/check-defaults.sh` all consistent. The fixes are code/config-record changes with no new prompt surface, so they do not affect the `[PROMPT-DEFAULTS]` wiring. Runtime verification of (1)/(2)/(3) is pending the next real install (the running box was installed with Beta-v2.9.67 and is already correct for boot).

## Beta-v2.9.67 — `[KEYMAP-CMDLINE]` (every dracut run logged `rd.vconsole.keymap=us: command not found` — and the keymap param was never actually baked into the initramfs)

`SCRIPT_VERSION` stays at the era checkpoint (Beta-v2.9.13); era row added to the script header VERSION-HISTORY (`# Beta-v2.9.67   [KEYMAP-CMDLINE]`), index row added above; this section added as the newest section.

### The bug

Observed live on <host> during the install (2026-09-17), before each of the three kernel dracut runs:

```
/etc/dracut.conf.d/90-system.conf: line 6: rd.vconsole.keymap=us: command not found
```

The ENCRYPT branch (`if [ "$ENCRYPT" = "yes" ]`) appended the keymap as a BARE dotted line:

```sh
echo "rd.vconsole.keymap=${KEYMAP_LIVE:-us}" >> /etc/dracut.conf.d/90-system.conf
```

Dracut **sources** every file under `dracut.conf.d/` with bash, and `rd.vconsole.keymap=us` is not valid shell (variable names cannot contain dots), so bash treats the whole line as a command name and executes it → `command not found` on stdout, printed once per dracut invocation. The 3× repetition in one install corresponds to the three kernel images (6.12.109 / 6.18.52 / 7.2.6) rebuilt during the final reconfigure loop.

The silent second half of the bug: because the line was never a valid directive, dracut never applied the keymap parameter at all. The `[KEYMAP]` feature (Beta-v2.6.9) — whose whole point is that the early-boot LUKS passphrase prompt (before console/keymap daemons are up) maps keys like the install console — had been shipping without effect, so the prompt kept the kernel's built-in US map on non-US installs.

### The fix

```sh
echo "kernel_cmdline=\"rd.vconsole.keymap=${KEYMAP_LIVE:-us}\"" >> /etc/dracut.conf.d/90-system.conf
```

`kernel_cmdline="parameters"` is the dracut-native, shell-valid directive (per `man dracut.conf`: "Specify default kernel command line parameters. Despite its name, this command only sets initrd parameters." — with `rd.`-prefixed parameters landing at the exact pre-root stage dracut's `i18n` module needs). It is written through the same shared `90-system.conf`, so the fix covers the GRUB branch and the Limine branch identically.

### Applied / validation

- Repo: `Void_Linux_Installer.sh:11094` now emits the `kernel_cmdline=` form. `bash -n` + `checks/check-heredocs.sh` clean (this is an *append* against a live-generated file, not a quoted heredoc, so the heredoc gate is unaffected).
- Host <host> (optionally): `/etc/dracut.conf.d/90-system.conf` line 6 changed from the bare line to `kernel_cmdline="rd.vconsole.keymap=..."` using the keymap pinned in `/etc/rc.conf`; the three initramfs images regenerated with `dracut --force` so the parameter actually lands.
- The `command not found` noise disappears from the next dracut run (dracut now parses a valid directive instead of sourcing garbage).

## Beta-v2.9.66 — `[MULTI-FS-FS-EVAL]` (every carved region was mkfs'd as btrfs regardless of the chosen filesystem: the `_FS` evals missed the case-fold the `_SIZE` evals got in v2.9.48, and `games`' choice lives in `REGION_GAMES` with no `_FS` suffix)

`SCRIPT_VERSION` stays at the era checkpoint (Beta-v2.9.13); era row added to the script header VERSION-HISTORY (`# Beta-v2.9.66   [MULTI-FS-FS-EVAL]`), index row added above; this section added as the newest section.

### The bug

A carved-`[MULTI-FS]` install that chose a non-btrfs filesystem for a data region got btrfs silently on disk. Proven live on <host> (carved ENCRYPT `/home` + `/home/<user>/Games):

- the region prompt and `install-config` recorded the request: `REGION_HOME_FS="ext4"`, `REGION_GAMES="ext4"` (and the run-log prompt line `home=ext4 games=ext4`);
- but the actual layout landed as btrfs for **both** regions: `installer-run.log` `MULTI-FS-RUNLOG: mkfs 'home' (btrfs)` / `mkfs 'games' (btrfs)`, `/etc/fstab` maps both mountpoints to btrfs subvolume trees, and `blkid /dev/mapper/void{1,2,3}` reports `TYPE="btrfs"` on all three.

### Why it happened

The three region loops (mkfs, mount, fstab) resolved the filesystem with the raw, lowercase `REGION_PARTITIONED` token:

```sh
eval "_rr_fs=\${REGION_${_rr}_FS:-btrfs}"     # _rr=home -> REGION_home_FS
```

The config variables are uppercase (`REGION_HOME_FS`, set by the prompt FOLD), and bash variable names are case-sensitive — so `REGION_home_FS` never exists and the `:-btrfs` default swallowed the choice at all three sites. The v2.9.48 `[DISK-BUDGET]` fix that introduced the region-size/fs evals folded case with `${_rr^^}` for the `_SIZE` reads but left the three `_FS` reads unfixed. `games` is a second, independent failure: its filesystem choice is stored in `REGION_GAMES` (no `_FS` suffix at all), so even the corrected `${_rr^^}` fold would read the non-existent `REGION_GAMES_FS`.

The shipped `void-subvol-tool.sh` (`/root/tools`) had the same bug class: its runtime `region_fs()` sed'd `^REGION_${1}_FS=` with the lowercase token against `install-config` (which stores uppercase keys), so it returned `btrfs` on every carved box and its carved-region guard never fired.

### The fix

- New helper `_region_fs_of()`, placed right after `_region_carved()`: uppercases the token (`REGION_${1^^}_FS`) and special-cases `games` → `REGION_GAMES`.
- All three loops now use `_rr_fs="$(_region_fs_of "$_rr")"`.
- `void-subvol-tool.sh` `region_fs()`: same fold + `games` special-case + `tr -d '"'` on the config value (install-config writes `REGION_HOME_FS="ext4"` quoted).
- `[DOCS-LOG]` `CPU=` line: dropped the trailing `${MICROCODE_PKG:-}` that appended the microcode package name a second time (`CPU=AuthenticAMD (microcode: linux-firmware-amd)linux-firmware-amd` now reads `CPU=AuthenticAMD (microcode: linux-firmware-amd)`).

### Applied / validation

- The installed box was NOT corrected on disk — this era is a **script** fix for the next re-install (the installed layout is btrfs on btrfs: technically sane, just not what was chosen; a re-install with this fix yields the requested ext4 regions).
- Reproduced the failure mode pre-fix with `set -x`: `eval '_rr_fs=${REGION_home_FS:-btrfs}'` evaluates to `btrfs` while `REGION_HOME_FS=ext4` — and `eval '_rr_fs=${REGION_games_FS:-btrfs}'` also yields `btrfs` even though `REGION_GAMES=ext4`.
- Post-fix trace of the same lines resolves `ext4` for both `home` and `games`.
- `bash -n` clean on the installer; the edited `void-subvol-tool.sh` body validated with `checks/check-heredocs.sh`.

## Beta-v2.9.65 — `[HOME-CACHE-CHOWN]` (a carved-`/home` `[MULTI-FS]` install left `~/.cache` root-owned → ksycoca/firefox "Permission denied" → empty KDE panel on first boot)

`SCRIPT_VERSION` stays at the era checkpoint (Beta-v2.9.13); era row added to the script header VERSION-HISTORY (`# Beta-v2.9.65   [HOME-CACHE-CHOWN]`), index row added above; this section added as the newest section.

### The bug

First real boot of a KDE/SDDM install on <host> landed in a broken desktop: **empty panel, no app launcher, "no access to any apps"**, and `firefox` in a Konsole immediately printed a *permission* error. SDDM and the Wayland Plasma session themselves were fine (`sddm.log` shows `Session started true`, PAM auth of `<user>` successful), but `~/.local/share/sddm/wayland-session.log` was wall-to-wall with:

```
kf.service.sycoca: No ksycoca database available! Tried running kbuildsycoca6 ?
kf.service.sycoca: Couldn't lock "/home/<user>/.cache/ksycoca6_en_+rzsmuzUkovv9hYHxjKa8bZYZvY=.lock"
Could not find factory with id 1 in sycoca database, you must run kbuildsycoca first! Creating a fake stream to not crash.
Failed to create /home/<user>/.cache/mesa_shader_cache for shader cache (Permission denied)---disabling.
org.kde.plasma.runner.appstream: ... Cache location '/home/<user>/.cache/appstream' is not writable.
kde.plasmashell: requesting unexisting screen available rect -1
```

Every line traces to one fact: **`/home/<user>/.cache` was `root:root` 0755**. The desktop user could not create it (ksycoca DB → no launchable apps / empty launcher), the AppStream runner, the mesa shader cache, and (per the installer's own browser-provision comment, line ~5859 "and its CACHE under ~/.cache/mozilla/firefox") firefox's cache — hence the "Permission denied" on `firefox`.

### Why it happened

Two `[MULTI-FS]` (Beta-v2.9.38) branches diverge:

```sh
mkdir -p "/home/${TARGET_USER}/.cache"        # browser-subvol prep — runs as root

case " ${REGION_PARTITIONED:-} " in
    *" home "*)   # carved /home
        echo "MULTI-FS: home region carved — skipping @usercache fstab/mount (~/.cache lives on the home partition)."
        ;;        # <-- out of the way: ~/.cache STAYS root:root 0755
    *)
        echo "UUID=${BTRFS_UUID} ... subvol=@usercache ..." >> /etc/fstab
        chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.cache"
        mount "/home/${TARGET_USER}/.cache"
        chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.cache"
        chmod 700 "/home/${TARGET_USER}/.cache"
        ;;
esac
```

The **only** `~/.cache` chown in the script lives in the non-carved `@usercache` arm, so every carve-home install shipped a root-owned `~/.cache`. The `[HOME-SELF-CHOWN]` (Beta-v2.9.58) fix covered `/home/$TARGET_USER` itself, and the adopt-own pass covered `.cache`'s *subdirectory* pattern in the non-carved layout — but the carved branch had no matching chown for the top-level dir the browser prep created as root.

### The fix

The carved-home arm now chowns and hardens the directory exactly like the `@usercache` arm:

```sh
chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.cache"
chmod 700 "/home/${TARGET_USER}/.cache"
```

(no fstab/mount — `~/.cache` lives directly on the carved home partition). `chmod 700` matches the `@usercache` branch's security posture and the systemd-created default.

### Applied live / validation

- Installed box (<host>): `chown -R 1000:1000 /home/<user>/.cache && chmod 700 /home/<user>/.cache` — verified by a chroot probe as `<user>`: `mkdir -p ~/.cache/mozilla/firefox` now succeeds (the exact path firefox needs on first run).
- The empty `~/.cache/mozilla/firefox` created during that probe was left in place (harmless; firefox uses the tree).
- KDE re-login rebuilds ksycoca fresh (nothing was ever written to it, so there is no stale DB to clear).
- `bash -n` clean on the installer; script HEAD era is now Beta-v2.9.65.
- Secondary finding from the same box: `~/Documents/VOID_INSTALL.txt` (the `[DOCS-LOG]` Beta-v2.6.2 per-machine record) is ABSENT on this install even though `/etc/void-installer/install-config`, the archived installer, `limine-env`, and `installer-run.log` all exist. Unresolved in this era — recorded for the next session (`[DOCS-LOG-MISSING-RECORD]`).

## Beta-v2.9.59 — `[LOCAL-CACHE]` (optional reuse of a pre-seeded XBPS package cache on an attached medium — live sync, bootstrap, and every chroot install fetch from disk with the mirror as fallback)

`SCRIPT_VERSION` stays at the era checkpoint; era row added to the script header VERSION-HISTORY, index row added above the 2.9.58 index row, this section added as the newest section.

Separate from the compatibility/session fixes of the last era, this feature targets a pure efficiency pain point: with the `Void_Linux_Live` fork building its own KDE ISO (`void-live-x86_64-20260916-kde.iso`) and holding a `xbps-cachedir-x86_64` of ~2.0 GB of raw `.xbps`/`.sig2` packages, every install re-downloaded that same package set from the mirror. The cache is directly consumable by `xbps-install -c <dir>` (signature-verified; the dir must be writable because every mirror-fallback package payload and the COSMIC-sync downloads land in it — the `-S`/`-Sy`/`-Syu` REPODATA write, by contrast, goes into the invoking root's `/var/db/xbps/<url>`, verified empirically in the Beta-v2.9.65 era, never the cache dir), so the installer now offers to reuse it end-to-end.

Behavior:

- **Default OFF.** `DEFAULT_LOCAL_CACHE=no` keeps the network-only baseline as the lean, mirror-truthful default (same posture as `[BROWSER-GATE-NO]`).
- **Prompt** (`[Y/n]` or a typed absolute path): auto-detects the newest-touched writable `xbps-cachedir-<arch>` under `/run/media/*/` (arch matched via `uname -m`, must actually contain `*.xbps` files). A typed path counts as "yes" if usable; a `y`/`yes` uses the auto-detected dir. Anything unusable (read-only medium, nonexistent dir, no matching cache) degrades to network-only — never a FATAL.
- **`-c` threading** at every xbps entry point:
  - Live-side `${LOCAL_CA}` (derived `-c $LOCAL_CACHE_DIR`, empty when off) added to the live-CD sync loop AND the base bootstrap (scoped `# shellcheck disable=SC2086`).
  - Chroot-side: the media cache is **bind-mounted** at `/mnt/tmp/xbps-cache` (guarded; on a bind failure the install continues network-only); `chroot_env.sh` REMAPS `LOCAL_CACHE_DIR="/tmp/xbps-cache"`, and a chroot-wide `_xbps_cache=(-c "$LOCAL_CACHE_DIR")` array is threaded into `install_pkgs()` (both the `-Suy` install and the `-Sy` reconcile) and `install_cosmic()` (both the `-Sy` trust/sync and the `-y` install).
- **The PKG-PREFLIGHT gate is deliberately untouched** — it keeps resolving against real mirrors so the preinstall capability check stays truthful regardless of cache state.
- **Resume** — a `-r` resume re-runs the sync/bootstrap/installs, so `LOCAL_CACHE_REUSE` and `LOCAL_CACHE_DIR` are added to the state-file persist list and re-validated on resume: if the recorded path is gone or unmounted (a stick can remount at a different `/run/media/<user>/<label>`), it is re-detected, else the resume falls back to network-only.
- **Release/teardown** — the bind mount is released in BOTH the Stage-3 teardown (before the final `umount /mnt`) and `cleanup_on_failure` (before `umount -fl /mnt`), so the media cache is never left mounted and a nested mount never blocks the unmount.
- **install-config** records the flag only (`LOCAL_CACHE_REUSE`); the PATH is deliberately omitted — it is media-scoped and meaningless after the install (mirrors remain the installed system's package source).

## Beta-v2.9.60 — `[RESUME-GFX-FLAGS]` (a `-r` resume lost the graphics flags and re-ran Stage 2 as headless → no X server → SDDM could never reach the greeter)

Observed live on the first real KDE/SDDM install on <host>: the box booted, LUKS unlocked cleanly (initramfs, limine, cryptsetup all fine), but no greeter ever appeared. `/var/log/sddm.log` showed the exact failure:

```
Running: /usr/bin/X -nolisten tcp -background none -seat seat0 vt7 ...
(EE) DAEMON: Failed to start display server process.
```

The cause was not the network churn. `xorg-server` (and its whole dependency tree: `mesa`, `xorg-apps`, `xorg-input-drivers`, `xorg-video-drivers`, `xorg-fonts`, `xauth`, `xinit`, `wayland-protocols`, …) was **never installed** — every one of those `.xbps` files sat in the USB cache, downloaded but unused, while the adjacent `pipewire`/`wireplumber` audio stack WAS installed.

Root cause chain:

1. **Resume drops the graphics flags.** The `[RESUME]` state-file persist list (Stage-1 config block) persisted every answered variable EXCEPT the three Beta-v2.9.48 `[HEADLESS]` flags: `HAS_GRAPHICAL`, `INSTALL_XORG`, `INSTALL_AUDIO`. On a fresh run those are computed/assigned in the (skipped-on-resume) interactive block and exported to `chroot_env.sh` — `HAS_GRAPHICAL=yes` for any DE/DM combo → the Stage-2 base-chain gate installs `wayland wayland-protocols NetworkManager dbus elogind xorg`. On a `-r` resume they are EMPTY in the driving shell, so `chroot_env.sh` was written with `export HAS_GRAPHICAL=""` etc.
2. **The claimed in-chroot defaults are inert text.** The HEADLESS feature's comment promised in-chroot defaults (`HAS_GRAPHICAL="${HAS_GRAPHICAL:-yes}"` / `INSTALL_XORG:-false` / `INSTALL_AUDIO:-true`) so the gating would be safe even when `chroot_env.sh` predates or omits them. But those three lines sit **inside the `cat > /etc/void-installer/install-config << INNER_EOF` heredoc** — they only print into the config file and are never evaluated as shell assignments (nothing in the chroot ever assigns the variables). At the gate, `[ "" = "yes" ]` is false and `[ "false" = "true" ]` is false → the **headless else-branch** ran: `install_pkgs NetworkManager dbus elogind` only. No `xorg`.
3. **Audio alone survived because only ITS gate has a real default.** `install_pkgs alsa-utils ... pipewire wireplumber` is gated on `[ "${INSTALL_AUDIO:-true}" = "true" ]` — a genuine shell-side default — so the empty flag fell through to `true` and PipeWire got installed. That asymmetry is the fingerprint that separates this bug from a plain "the network lost it": the missing set is exactly the graphical-X base chain.

Fix (this era):

- `HAS_GRAPHICAL`, `INSTALL_XORG`, `INSTALL_AUDIO` added to the resume-state persist list (Stage-1 config block), so they ride `-r` like every other choice.
- A **real in-chroot recompute immediately before the base-chain gate**: `HAS_GRAPHICAL` is re-derived deterministically from the persisted `DESKTOP_ENV`/`DISPLAY_MANAGER` (both `none` ⇔ headless, any other combination ⇔ graphical), then `INSTALL_XORG="${INSTALL_XORG:-false}"` and `INSTALL_AUDIO="${INSTALL_AUDIO:-true}"` apply the defaults the config-print only claimed. This makes resume correct even for state files written by pre-2.9.60 scripts.
- The install-config heredoc comment was corrected to state it is a RECORD-ONLY copy and that the runtime defaults now live at the gate.

Recovery note for an already-bitten box (as-built <host>): the cure offline, from the nearest cache, is `xbps-install -Sy xorg` (pulls xorg-server + mesa + drivers + apps/fonts); `wayland-protocols` comes with the chain. No re-flash of the install disk is needed.

## Beta-v2.9.58 — `[HOME-SELF-CHOWN]` (account-provisioning fix — the installer chown'd home SUBdirectories but NEVER `/home/$TARGET_USER` itself, so on a carved/adopted `@home` every greeter bounced the CORRECT password as a grey "wrong password" loop)

`SCRIPT_VERSION` stays at the era checkpoint; era row added to the script header VERSION-HISTORY, index row added below the 2.9.57 index row, this section added as the newest section.

The v2.9.57 boot fix finally cleared the emergency shell and reached the LightDM greeter — only to reveal a SECOND, completely independent break: EVERY login was bounced as "Incorrect password", even though the typed password was hash-verified correct every single time (and the greeter never even showed a wrong-password toast on the active console — the greeter just grey-reset). The failure signature in lightdm.log was `Error getting user list from org.freedesktop.Accounts` followed by the greeter relaunching; the underlying crash (uncovered once the greeter actually got a session request) was `mate-session: Gtk-WARNING: cannot open display` with an exit in ~0.02s.

Root cause — and this is the part that makes the fix UNIVERSAL, not MATE/LightDM-specific:

- `useradd -m` (the script's account stage) creates `/home/$TARGET_USER` itself as `root:root` mode 755.
- The script's adopt-own chown pass (`[HOME-ADOPT]` era) chowns the home's SUBdirectories — `~/Games`, `~/.config`, `~/.local`, `~/.cache`, `~/Documents`, and so on — but NEVER the home directory ITSELF.
- On this installer's recovered build the home lives on a carved/adopted `@home` subvolume, so the stale `root:root` home dir survives provisioning unchanged.
- The greeter (LightDM, SDDM, greetd/cosmic-greeter, GDM — any of them) and the DE session (MATE, COSMIC, KDE — any of them) universally need to write `~/.Xauthority`, `~/.dmrc`, and `~/.xsession-errors` at login time. With a root-owned mode-755 home dir, those writes fail; X auth then fails; the DE session exits immediately; and the greeter reads that instant exit as an authentication failure.

So the fix is an ACCOUNT-PROVISIONING chown, not a greeter change: immediately after `useradd`, the installer now runs

```sh
chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}"
```

(the home dir itself adopts own-ownership, mirroring the existing `~/Games` + `@containers-user` adopt-own pattern). Proven on the live box (2026-09-15): once the home tree was chown'd to numeric uid 1000 (`find -xdev`), the SAME test password that had been grey-bounced for days logged straight in, with ZERO greeter/config/session changes.

Do NOT add anything greeter-specific to this fix — the only greeter-related quirk in this lineage is the separate `[COSMIC-GREETER]` `_cosmicgreeter`-vs-`cosmic-greeter` username-dispatch packaging bug, which stays a distinct, greeter-only concern. This chown is the universal account-layer fix.

## Beta-v2.9.57 — `[INNER-PARTSCAN-UDEV-ATTR]` (the v2.9.56 "fix" still stranded boot: the udev rule's `ENV{DM_NAME}` predicate NEVER matches — sysfs `ATTR{dm/name}` is the key that actually fires the RUN)

`SCRIPT_VERSION = Beta-v2.9.57`. Found 2026-09-15 on the SECOND boot attempt of
the same box: the v2.9.56-fixed installed system (kpartx in the image, dracut
--force rebuilt initramfs, ESP re-synced — the previous session's whole
checklist) STILL died the SAME way after the reboot: dracut emergency shell,
~217s of "Scanning for all btrfs devices", `dracut Warning: Cancelling resume
operation`, and `/proc/partitions` showing only `dm-0` (no `void-root1/2`).
This was decisive: the fix content WAS in the booted image, so the tool choice
was never wrong — the udev **trigger** was. The rule in the booted image:

```
ACTION=="add", SUBSYSTEM=="block", ENV{DM_NAME}=="void-root", RUN+="/usr/bin/void-inner-partscan.sh"
```

**Root cause — `ENV{DM_NAME}` can never match a udev rule.** Captured live on
the NVMe box with `udevadm monitor` while `cryptsetup luksOpen` re-opened the
container: the kernel first emits an **add** uevent for `/dev/dm-0` whose
environment carries only `ACTION/DEVNAME/DEVPATH/DEVTYPE/DISKSEQ/MAJOR/MINOR/SEQNUM/SUBSYSTEM`
— **no `DM_NAME` at all** (the udev-processed record that follows shows
`DM_UDEV_DISABLE_DISK_RULES_FLAG=1` / `DM_UDEV_DISABLE_OTHER_RULES_FLAG=1`
and a `DM_COOKIE`, still no `DM_NAME`). In this eudev/libdevmapper stack,
`DM_NAME` is written into the udev database by libdevmapper **itself, after**
rules have already evaluated the uevent — so no rule evaluated on the kernel
event can ever see it. The initramfs's `11-dm.rules` (142 bytes, guards only +
`OPTIONS+="db_persist"`) does not set it either. Consequences worth
internalizing: this ALSO retroactively rewrites both prior chapters — the
2.9.45 "partprobe silently did nothing" and the 2.9.56 "kpartx still didn't
help" were the SAME bug: the RUN helper never executed at boot. (The earlier
chapters' tool-level conclusions remain valid — partprobe's BLKPG genuinely
does not register a dm-crypt mapper and `partx -a` demonstrably cannot
("error adding partitions 1-2"); those were proven by DIRECT running of the
tools, not by the boot trigger.)

**The match key that works:** the device-mapper name IS exposed at add-time as
a sysfs attribute — `/sys/block/dm-0/dm/name` reads `void-root`
(`dm/uuid` reads `CRYPT-LUKS2-<luksuid>-void-root`). A rule using
`ATTR{dm/name}=="void-root"` was written to the live box and reloaded, and on
the next `luksOpen` the RUN **fired** (`HELPER dev=/dev/dm-0 DEVNAME=/dev/dm-0`)
and the helper's `kpartx -a /dev/dm-0` **created both submaps** —
`void-root1` + `void-root2` in `/dev/mapper/` — i.e. the exact boot-time
sequence, end to end, proven on the target hardware.

**Fix `[INNER-PARTSCAN-UDEV-ATTR]`:**

1. **udev rule** (`10-void-inner-partscan.rules`): predicate is now
   `ACTION=="add", SUBSYSTEM=="block", KERNEL=="dm-*", ATTR{dm/name}=="__CRYPT_NAME__",
   RUN+="/usr/bin/void-inner-partscan.sh"` (token still sed-baked to the
   mapper name). `KERNEL=="dm-*"` keeps the RUN scoped to device-mapper nodes;
   the kpartx-created children (`void-root1/2`, dm-1/dm-2) carry different
   `dm/name` values so there is no re-trigger loop.
2. **Everything else is untouched**: helper (its `$1 → $DEVNAME → /dev/mapper/<name>`
   fallback chain held up exactly as designed — argv is empty under this eudev,
   `DEVNAME=/dev/dm-0` did the work), module-setup, content gates, package
   lines, `98` module prefix, and the `add_dracutmodules` short-name conf.
3. **Boot chain now reads**: LUKS unlock (90crypt) → dm-0 add uevent →
   `ATTR{dm/name}` matches `void-root` → RUN helper → `kpartx -a` builds
   `void-root1/void-root2` → dracut settle resolves `root=UUID=<inner btrfs>`
   from the READY child devices → root mounts → init proceeds.

**Applied to the installed system 2026-09-15:** installed rules replaced under
`/mnt/root/usr/lib/dracut/modules.d/98void-inner-partscan/`, dracut --force
rebuilt all three images (7.2.6_1, 6.18.52_1, 6.12.109_1 — junk
`initramfs-.img` from a first quoting-mangled attempt removed), `lsinitrd`
confirms the `ATTR{dm/name}` rule + helper + kpartx in every image,
`void-limine-sync-kernels` re-synced the ESP (content gate passed), and md5
parity `/boot` ↔ ESP verified for all kernels. The dracut-module discovery
question (the `98` prefix / `add_dracutmodules` short name) was audited
against `dracut(8)` source — scanning is `modules.d/[0-9][0-9]*`, name lookup
is `modules.d/??<name>`, so the number is mandatory and was always resolving;
it is NOT implicated.

**Validation:** `bash -n` OK; heredoc bodies unchanged apart from the rules
file that was recheck-exercised by the live end-to-end proof above;
`checks/check-heredocs.sh` re-run recommended before the next real install. A
reboot of this (now fixed) system is the end-to-end confirmation.

---

## Beta-v2.9.56 — `[INNER-PARTSCAN-KPARTX]` (the first real ENCRYPT+regions boot died in emergency shell: `kpartx`, not `partprobe`, is the tool that registers an opened LUKS2 mapper's inner GPT)

`SCRIPT_VERSION = Beta-v2.9.56`. Found on the FIRST REAL ENCRYPT+regions+MULTI-FS
install (nvme0n1, the same live box as 2.9.55), 2026-09-15: the install
COMPLETED (post-2.9.55-verify run; LUKS2 argon2id, outer nvme0n1p1=ESP 6G
FAT + nvme0n1p2=LUKS2 948G, inner GPT in the mapper with part1=games 200G btrfs
+ part2=LINUX btrfs root, Limine on the ESP, snapper baseline, SSH keypair
exported to the stick), but the FIRST BOOT reproducibly landed at the **dracut
emergency shell** → reboot → no unlock password prompt → rescue menu. NOT a
password problem: `rd.luks.uuid=7559af9f...` canonical, live
`cryptsetup luksOpen` + `kpartx` mapped the container; the real story is in
the boot log (`rdsosreport.txt` captured on the stick):

```
dracut: luksOpen <LUKS uid> none luks
...
dracut: Scanning for all btrfs devices
dracut: Scanning for all btrfs devices
dracut: Scanning for all btrfs devices
dracut: Scanning for all btrfs devices
... (loops ~3 min, then)
dracut: Switching root
dracut: Warning: Can't process initqueue; breaking to emergency shell
```

LUKS **did** unlock at boot (initramfs holds the `crypt` module + carrier), the
LUKS2 mapper node appeared with the inner GPT READABLE (`blkid` shows
`PTTYPE=gpt`), but **no `/dev/mapper/void-root1/2` child devices ever
appeared** — the on-disk inner partition table was never registered, so
`root=UUID=e43914d9-...` had nothing to resolve, the btrfs component to scan
was invisible → the 3-minute btrfs scan loop → emergency shell. This is EXACTLY the
crash #009 residual the 2.9.43–2.9.45 partscan module was built to prevent —
it just used the wrong tool.

**Root cause — partprobe is not the registration tool for a dm-crypt mapper
on this kernel/hardware.** The Beta-v2.9.45 premise that partprobe builds
"libparted dm-linear submaps ... the ONLY tool that can BLKPG a device-mapper
target" was derived from <host> (an unencrypted, plain-disk install where
partprobe on the OUTER disk genuinely works). On the OPENED LUKS2 mapper it
silently produced NOTHING — no dm children, no udev events, exit 0 (the
helper redirected stderr, so the failure was invisible). The
hands-on verification on the live box (documented in this session's
recovery notes):

- `partx -a /dev/mapper/void-root` → `partx: /dev/mapper/void-root: error adding
  partitions 1-2` (as 2.9.45 documented, partx cannot BLKPG a dm target).
- `partprobe` is **not even installed** on this live medium; in the installed
  initramfs it IS present but the boot log proved it changed nothing.
- `kpartx -av /dev/dm-0` (devname the udev RUN helper actually receives)
  → **instantly created both submaps**: `add map void-root1 (254:1): 0
  419430400 linear 254:0 2048` and `add map void-root2 (254:2): 0
  1568359022 linear 254:0 419432448` — i.e. real, working dm-linear child
  devices with the btrfs filesystems directly readable (`blkid` → LABEL
  VOID-games / VOID; the exact `void-root1/2` names WITHOUT the `p`
  separator, matching 2.9.55 [INNER-DEV-NAME]).

kpartx is the tool that reads the partition table of a runtime block device
(the OPENED mapper) and CREATES the dm-linear submaps via dmsetup — exactly
the "BLKPG/register" job that libparted's partprobe attempts against an
accessible device and fails against a device-mapper target.

**Fix `[INNER-PARTSCAN-KPARTX]`:**

1. **Boot helper** `void-inner-partscan.sh`: `kpartx -a` is now PRIMARY, with
   `partprobe` then `partx -a` as ordered fallbacks (kept for environments
   where partprobe's BLKPG does register). Best-effort exit-0 contract
   unchanged.
2. **_region_inner_partscan** (live install/resume path): same kpartx-first
   order, same `sleep 2`, replaces the partprobe-primary version so a resumed
   install re-registers with the tool that actually works.
3. **module-setup.sh**: `check()` now `require_binaries kpartx` AND
   `require_binaries partprobe`; `install()` `inst_binary kpartx` FIRST, then
   partprobe + partx.
4. **Package provisioning**: the module-gated `install_pkgs parted` line now
   installs `kpartx parted` together (kpartx for the PRIMARY tool, parted for
   the partprobe fallback); `kpartx` added to `PKG_PREFLIGHT` (alphabetical).
5. **Content gates**: the ESP-sync per-image guard in `void-limine-sync-kernels`
   and the chroot FATAL initramfs-content gate both now require `kpartx` in
   every image (plus cryptsetup/partprobe/helper/rules as before) — an image
   carrying only partprobe is exactly the broken one this fixed.
6. Docs: VERSION-HISTORY row (header), ARCHITECTURE SUMMARY [INNER-PARTSCAN]
   block, module gate comments, helper header — all updated from
   partprobe-primary to kpartx-primary narrative.

Boot tool chain for a future ENCRYPT+regions install therefore reads: LUKS
unlock (90crypt) → DM_NAME=void-root udev RUN → kpartx builds
void-root1/void-root2 → dracut settle resolves root=UUID=<inner btrfs> from
the READY child devices → root mounts → init proceeds.

**Validation:** `bash -n` OK. `checks/check-defaults.sh` ALL CONSISTENT (no
prompt surface touched). `checks/check-pkg-preflight.sh` needs re-run after the
`kpartx` PKG_PREFLIGHT addition. `checks/check-heredocs.sh` re-run (heredocs
changed). `kpartx` proven live (the 254:1/254:2 maps above); `partprobe`
fallback path unchanged from 2.9.45. A reboot of the fixed installed system
(dracut --force rebuild + ESP re-sync, then KERNEL boot) is the end-to-end
confirmation.

---

## Beta-v2.9.3 — `[SUBVOL-INSTALL]` + `[LIGHTDM-GREETER-BG]` + `[XFC-AUTOMOUNT]` (subvol-tool `--install`, optional-software defaults, greeter background, Xfce gvfs)

`SCRIPT_VERSION = Beta-v2.9.3`. Five changes: `--install` on the subvol tool,
a new data-safety guard, the OctoXBPS/Flatpak default flip with prompt text
alignment, a LightDM greeter background on fresh installs, and gvfs for Xfce
automount parity.

**1. `void-subvol-tool.sh` can now install the software it creates a subvolume
for.** Previously the tool was purely structural — it built/mounted flat
siblings but never touched packages. Now `add <subvol> ... --install` (and
`add --class <name> --install`) runs `xbps-install -Sy` for the owning
package(s) (a new `PKG_MAP` table in the tool body) **after** the sibling is
mounted at its runtime path, so the software's data lands on the isolated
subvolume from the very first run — mirroring the installer's own provisioning.
It is still structural by default: without `--install`, the tool never pulls a
package.

Subvols with no xbps mapping (postgres/mariadb manual targets, `@usercache`,
`@mozilla-cache`, and `@brave` which is Flatpak-only) are still created and
isolated, but print a NOTE that nothing was installed rather than failing.

**2. OctoXBPS and Flatpak now default to `no`.** Their bare-Enter defaults
(`DEFAULT_OCTOXBPS`, `DEFAULT_FLATPAK`) flipped from `true` to `false`, and the
subvolume-isolation prompt wording now reads "all of the optional software you
selected above **with the exception of OctoXBPS and Flatpak**" (Flatpak's
system store lives under `/var/lib/flatpak` as part of `@`, and OctoXBPS has no
isolatable data dir) — so neither is presumed on a lean default run. The prompt
display text is also aligned: `[Y/n]` → `[y/N]` so the capitalized letter
matches the actual default.

**3. `[LIGHTDM-GREETER-BG]` — greeter background on fresh installs.** The GTK
and Slick greeters now get a `background=<path>` written into their respective
config files (`lightdm-gtk-greeter.conf` / `slick-greeter.conf`) during
provisioning so the login screen shows a real image instead of solid black on a
fresh install. The search prefers the GNOME adwaita-l stripe (`.jpg`/`.jxl`/`.png`/`.svg`),
then falls back to any image under `/usr/share/backgrounds`. If no image is found
(no backgrounds package installed), the greeter is left at its compiled-in
default — no error, no hang.

**4. `[XFC-AUTOMOUNT]` — gvfs for Xfce/LXQt automount parity.** `gvfs` is now
installed alongside `xfce4` and `lxqt` so Thunar/pcmanfm-qt get the full
userspace virtual filesystem backends (MTP phone access, SMB/NFS network shares,
Google Drive, trash-can-mount). GNOME, Cinnamon, and MATE already receive `gvfs`
transitively via their file managers (`gnome-core→gvfs`, `nemo→gvfs`,
`caja→gvfs`); Xfce's Thunar and LXQt's pcmanfm-qt can use gvfs but don't
depend on it. Without it, basic USB automounting works via `udisks2` but
network/cloud/phone backends are missing. `udisks2` is pulled in as a `gvfs`
dependency, so no separate install is needed. COSMIC is deferred to real-hardware
testing — its file manager is a third-party package with unverifiable
dependencies.

**Why this matters.** The practical payoff of building a subvolume for an app is
that the app's data sits outside Snapper rollback scope. Before, that required
two manual steps on a box where the app wasn't installed yet: build the subvol,
then install the app. `--install` collapses that into one command and keeps the
isolation-first guarantee intact (`set -euo pipefail`, fail-loud on a bad
package). Flipping OctoXBPS/Flatpak off aligns a bare-Enter run with the
recovery-first, lean motif of the rest of the installer's optional software.

**Tool changes:**
- `PKG_MAP` — subvol → owning package(s): `@docker`→docker;
  `@containers`/`@containers-user`→podman rootless stack; `@libvirt`→qemu +
  libvirt + virt-manager; `@virtualbox`→virtualbox-ose + dkms; browsers,
  `@steam`, `@thunderbird`, `@flatpak`.
- `install_packages()` helper runs `xbps-install -Sy` and dies loudly on error.
- `class_packages()` dedups packages across a class so metadata is synced once.
- `add_subvol`/`cmd_add`/`cmd_add_class` all gained an `--install` path.
- `[SUBVOL-DATA-GUARD]`: `add` now **refuses a non-empty, unmigrated target
  mountpoint**, forcing the source-dir migrate form (`add <sv> <mnt> <mnt>`),
  so pre-existing data inside `@` is never silently hidden behind a fresh empty
  mount. (Previously the tool would mount over a populated directory, stranding
  the old data inside `@`.)
- Usage header + README updated with `--install` examples and the no-mapping
  subvol list.

**Validation:** `bash -n` and `checks/check-heredocs.sh` both ALL CLEAN (one
SC2086 is the deliberate `$pkgs` word-split, disabled with a one-line
rationale).

---

## Beta-v2.9.4 — `[SNAPPER-PRESENT]` (snapper-binary guard + rmdir abort hardening)

`SCRIPT_VERSION = Beta-v2.9.4`. Turned a real-hardware install failure into a
clear, actionable error.

**Background of the failure.** A fresh MATE/lightdm/limine install on
`/dev/nvme0n1` (LUKS2) aborted in Stage 2 with the whole chroot heredoc as the
failing command (exit 1) — the inner failing line was not named. A probe on the
target showed `snapper: command not found` and an empty (unmounted)
`/.snapshots` — i.e., snapper never got installed and the abort predated the
snapper config dance. Cinnamon and XFCE installs on the same hardware had
succeeded previously, so the first-time MATE package sync (a large metapackage
pull) is the prime suspect: a mid-sync network drop makes `xbps-install
-Suy -R ...` exhaust all three mirrors, `install_pkgs` prints `FATAL: ... failed
against all configured repositories for: <pkgs>` and `exit 1`s, leaving the
target with no snapper and a dangling empty `/.snapshots` mountpoint.

**Changes:**
1. `install_pkgs` hard-exits on total mirror failure, so the snapper install
   step itself was the likely abort point. The config block therefore now
   guards the binary before touching the `/.snapshots` dance:
   ```sh
   if ! command -v snapper >/dev/null 2>&1; then ...
       exit 1
   fi
   ```
   so a repeat failure stops with an explicit "snapper is not installed in the
   target … likely a mid-transaction network drop" message instead of a cryptic
   `rmdir` abort three lines later.
2. Hardened the existing `rmdir /.snapshots` (unguarded, after
   `snapper create-config`) to `rmdir /.snapshots || true` — defense-in-depth
   in case a future snapper behavior change leaves the directory absent.

Recovery for an affected install: re-run the installer on a stable network
connection (the failing run kept its resume record, so `-r` resumes the
remaining steps).

**Validation:** `bash -n`, `checks/check-heredocs.sh` (ALL CLEAN), and
`checks/check-defaults.sh` (ALL CONSISTENT) all pass.

---

## Beta-v2.9.5 — `[GREETER-BG-PIPEFAIL]` (wallpaper `find | head` pipefail guard)

`SCRIPT_VERSION = Beta-v2.9.5`. Fixed a silent, zero-output abort in the
lightdm/cinnamon greeter-wallpaper search under the chroot's `set -eEo pipefail`.

**Background of the failure.** A second fresh MATE/lightdm/limine install on
`/dev/nvme0n1` aborted in Stage 2. This time the package sync was clean — the
48-package lightdm transaction installed and configured successfully — and the
abort came immediately after, with **no** error text on screen. The new
`[SNAPPER-PRESENT]` guard from Beta-v2.9.4 never fired (snapper was present),
ruling out the network-drop theory for this run.

**Root cause.** On the lightdm branch (Beta-v2.9.3 `[LIGHTDM-GREETER-BG]`), the
greeter-background search does:

```sh
_greeter_bg_candidate="$(find /usr/share/backgrounds -maxdepth 2 -type f \
    -name "$_greeter_bg_name" 2>/dev/null | head -1)"
```

Under `set -eEo pipefail` this is unsafe when `/usr/share/backgrounds` does not
exist: `find` exits 1, `pipefail` turns the pipeline nonzero, the command
substitution/assignment fails, and `set -e` kills the chroot. The `2>/dev/null`
hides the error text but **not** the exit code — hence the zero-output abort.
The directory legitimately doesn't exist yet on the lightdm path because the
block runs before any backgrounds package is installed (`gnome-backgrounds` and
the MATE wallpaper collection arrive only with the desktop-metapackage/xdg-user-dirs
installs that come *later* in the chroot). Prior successful Cinnamon/XFCE installs
used SDDM, so this lightdm-specific code path had never executed on real
hardware until the MATE+lightdm attempt.

**Changes:**
1. All four greeter/wallpaper `find ... | head -1` command substitutions
   (greeter loop, greeter fallback, Cinnamon ladder, Cinnamon fallback) get
   `|| true`, so a missing/empty backgrounds directory simply leaves the
   wallpaper unset (the correct lean pre-existing behavior) instead of
   aborting the install.

**Validation:** `bash -n`, `checks/check-heredocs.sh`, and
`checks/check-defaults.sh` all pass.

---

## Beta-v2.9.6 — `[LUKS-UNLOCK-LEFT-OPEN]` (failure unwind closes the LUKS mapper; resume reuses an open one)

`SCRIPT_VERSION = Beta-v2.9.6`. Closed a three-way trap around a LUKS mapper
left open by a crashed install.

**Background of the failure.** A third attempt on `/dev/nvme0n1` was run with
`-r` (resume). It failed at "decrypt the partition". The drive appeared
unlocked, and the operator wondered what a resume did when asked to open a
drive that was already open. Both observations were right.

**Root cause — the unwind never closed the mapper.** `cleanup_on_failure`
(lines 611-682) unmounted every `/mnt` path but **never ran
`cryptsetup luksClose`**. So after any crash, `/dev/mapper/void-root` stayed
active — "the drive is not locked". Resume then *assumes* the mapper is closed
(the Beta-v2.5.5 comment at the resume-open site), calls `luksOpen` anyway,
and cryptsetup refuses a second mapping of an active device ("device already
exists") — the `!`-guarded `luksOpen` (Beta-v2.6.9 `[ENCRYPT-VERIFY]`) turned
that into a misleading "FATAL: could not unlock ... with the passphrase given",
killing the `-r`. A plain fresh re-run was similarly stuck: `luksFormat` /
`mkfs.btrfs` on a busy partition.

**Changes:**
1. **Failure unwind now closes the mapper.** `cleanup_on_failure` runs
   `cryptsetup luksClose "${CRYPT_NAME:-void-root}"` (guarded, `|| true`) and
   prints a "disk is now LOCKED" note when encryption was enabled — so a
   failure returns the disk to a locked, clean state, matching what the resume
   path already assumed.
2. **Resume reuses an already-open mapper.** The resume ENCRYPT branch first
   checks `[ -e "$CRYPT_DEV" ]`; if the exact mapper is already active it
   verifies with `cryptsetup status "$CRYPT_NAME"` that it maps the expected
   container partition (`grep -q "device:.*${PART_SYS}"`) and reuses it —
   skipping the passphrase/YubiKey prompt entirely. A mismatch (active mapper
   belonging to a *different* partition) is a loud FATAL telling the user to
   `cryptsetup luksClose` it first.
3. **Fresh-start closes a leftover mapper before reformat.** The
   `RESUME != 1` ENCRYPT branch `luksClose`s `$CRYPT_DEV` (if it exists) before
   `luksFormat`, so a plain (non-`-r`) re-run also survives a leftover-open
   mapper instead of dying on a busy device.

**Operator note from the diagnosis.** The `CRYPT_NAME=void-root` in
`/tmp/void-installer-state.sh` is *not* a mismatch: journal2 line 3 shows the
second run itself created and opened `/dev/mapper/void-root` (the Beta-v2.7.1
prompt default). The earlier `void` (run 1) is a different run's choice. The
resume failure was the open mapper, not the name.

**Validation:** `bash -n` passes; `checks/check-heredocs.sh` and
`checks/check-defaults.sh` re-run clean after the edits.

---

## Beta-v2.9.7 — `[BROWSER-GATE-NO]` ("Set up web browsers now?" defaults to No)

`SCRIPT_VERSION = Beta-v2.9.7`. Flipped the `[BROWSER-GROUP]` (Beta-v2.7.4)
category gate's default so a bare-Enter run no longer installs any browsers.

**Behavior change.** Previously `DEFAULT_WEB_BROWSERS` was `true` — the OR of
the component defaults (Firefox, Chromium) — so a default/uninterested run
silently installed Firefox + Chromium. Now the gate is `false` (`[y/N]`), so a
bare-Enter run skips the entire browser section (all five toggles forced off).
Behavior inside the gate is untouched: saying `y` to the gate still walks the
same per-browser prompts, with Firefox/Chromium still individual-default ON.

**Changes:**
- `DEFAULT_WEB_BROWSERS="${DEFAULT_WEB_BROWSERS:-false}"` + updated `[y/N]`
  indicator and explanation in the `[PROMPT-DEFAULTS]` block.
- Prompt text at the gate now reads `[y/N]` instead of `[Y/n]`; the inline
  comment reflecting the old OR-of-defaults rationale updated.

**Validation:** `bash -n` passes, and `checks/check-defaults.sh` stays
consistent (the flip only changed a value, not a wiring).

---

## Beta-v2.9.8 — `[GREETER-BG-TIMING]` (lightdm greeter background ran too early)

`SCRIPT_VERSION = Beta-v2.9.8`. The `[LIGHTDM-GREETER-BG]` (Beta-v2.9.3)
greeter-background block was structurally unable to ever set a wallpaper, on
every desktop — proven by a real-hardware report: a Beta-v2.9.6 MATE+lightdm
install booted to a working desktop, but the GTK greeter showed a black/missing
background.

**Root cause — ordering.** The greeter-background search lived inside the
lightdm setup branch, which runs **before** any desktop metapackage is
installed (MATE at the `mate` install, Cinnamon's `gnome-backgrounds` still
to come). At that point `/usr/share/backgrounds` does not even exist, so the
`find` (Beta-v2.9.5 `|| true`'d into a no-op after the pipefail fix) found
nothing, no `lightdm-gtk-greeter.conf` / `slick-greeter.conf` was written, and
the greeter fell back to its compiled-in black default. The Beta-v2.9.3
feature had effectively never worked — prior successful Cinnamon/XFCE installs
used SDDM, so the lightdm code path had never executed on real hardware until
the MATE+lightdm run.

**Changes:**
1. **Moved the greeter-background search to AFTER the desktop metapackage
   install** (end of the DESKTOP_ENV chain, just before the polkit block),
   gated on `DISPLAY_MANAGER=lightdm`. Now `/usr/share/backgrounds` really
   holds the desktop's wallpaper set: MATE via the `mate` metapackage,
   Cinnamon via its `gnome-backgrounds`, Xfce/others via whatever they ship.
2. **gnome-backgrounds retry fallback.** If the search still comes up empty
   (a desktop that ships no wallpapers), the block installs `gnome-backgrounds`
   and re-runs the search — so a lightdm greeter is never left at its black
   default in any combination.
3. The v2.9.5 `[GREETER-BG-PIPEFAIL]` `|| true` guards and their rationale
   moved with the block (and still protect the fallback search).

**Validation:** `bash -n` passes; `checks/check-heredocs.sh` ALL CLEAN (the
moved `INNER_EOF` greeter-config heredocs still extract and bash -n cleanly);
`checks/check-defaults.sh` unchanged.

---

## Beta-v2.9.10 — `[COSMIC-GREETER-DM]`+`[COSMIC-POLKIT]` (cosmic-greeter greetd-hosted DM provisioning; COSMIC polkit agent)

`SCRIPT_VERSION = Beta-v2.9.10`. Two COSMIC gaps closed, found by inspecting a
fresh Beta-v2.9.9 COSMIC install (cosmic-greeter DM, /home/<user>,
`VOID_INSTALL.txt` inventory + the running system):

1. **`[COSMIC-GREETER-DM]` — the `DISPLAY_MANAGER=cosmic-greeter` path never
   reached a login screen.** The machine booted to a bare TTY login instead of
   the greeter. Root cause: cosmic-greeter is **not** a standalone DM — its own
   binary self-describes as *"a libcosmic frontend for greetd which can be run
   inside of cosmic-comp"*. The old Beta-v2.4.0 bespoke service just
   `exec /usr/bin/cosmic-greeter`, so on boot the greeter found neither greetd
   nor a `com.system76.CosmicComp` session nor AccountsService and aborted
   instantly, dropping tty1 to agetty. Verified live: `runsv cosmic-greeter`
   was up but had **no child process**, greetd was installed but **never
   enabled**, and no `_cosmicgreeter` user existed (only the group).
   The community repo (whose COSMIC templates are built from scratch) deploys
   the greeter the intended way, so the installer now
   bakes the same stack deterministically (never depending on which repos-rev
   ships):
   - `/etc/greetd/cosmic-greeter.toml` — greetd config launching
     `cosmic-comp cosmic-greeter` as the `_cosmicgreeter` user on VT 1
   - `/etc/sv/cosmic-greeter/run` → `greetd -c …` (maintainer's run logic:
     dbus → cosmic-greeter-daemon → elogind checks, plus the
     /var/service/elogind stray-PID sweep)
   - `/etc/sv/cosmic-greeter-daemon/run` → `cosmic-greeter-daemon`, owning
     `/run/cosmic-greeter` (0755 `_cosmicgreeter:_cosmicgreeter`)
   - `_cosmicgreeter` system user provisioned idempotently (newer package revs
     create it via `system_accounts`; older ones only shipped the group — home
     `/var/lib/cosmic-greeter`, shell nologin, groups video,input)
   - `greetd` named explicitly in `install_pkgs` (it was only a transitive dep)
   - supervised `accounts-daemon` provisioned exactly as the lightdm branch
     does ([LIGHTDM-HW] pattern — the greeter lists users/icons through
     `org.freedesktop.Accounts`, which Void ships with NO runit service)
   - rc.local first-boot links BOTH `cosmic-greeter` and
     `cosmic-greeter-daemon`, links accounts-daemon for cosmic-greeter too, and
     removes `agetty-tty1` (the greeter's VT, per greetd's README.voidlinux
     "disable the agetty for the tty set in config.toml")
2. **`[COSMIC-POLKIT]` — same gap class as the Beta-v2.9.9 DE fixes: the
   desktop session has no privilege agent.** `cosmic-desktop-full`'s
   `run_depends` (verified in the community repo) pull **no polkit agent** —
   unlike kde-plasma (`polkit-kde-agent`) or the `gnome` metapackage (built-in
   Shell agent). Without one, GUI privilege prompts (mounting, admin changes,
   package-manager auth) hang. Fix: `install_pkgs polkit-gnome` for
   `DESKTOP_ENV=cosmic`, plus an installer-baked
   `/etc/xdg/autostart/polkit-gnome-authentication-agent-1.desktop` — Void's
   polkit-gnome ships its desktop file to `/usr/share/applications` gated by
   `OnlyShowIn=GNOME`, so without the baked entry no COSMIC session would ever
   start it (cosmic-session honors XDG autostart — verified in the session
   binary: "looking for autostart folders" / Desktop Entry parsing).

**Validation:** `bash -n` passes; `checks/check-heredocs.sh` extracts
`/etc/greetd/cosmic-greeter.toml` + both new service run scripts and
`bash -n`s them clean; `checks/check-defaults.sh` still ALL CONSISTENT.

---

## Beta-v2.9.11 — `[COSMIC-GREETER-LOG]` (svlogd logging for the cosmic-greeter greetd DM stack)

`SCRIPT_VERSION = Beta-v2.9.11`. Found during the live 2026-09-05 validity run
of the Beta-v2.9.10 `[COSMIC-GREETER-DM]` recipe (applied via
`~/fix-cosmic-greeter.sh` on a real Beta-v2.9.9 COSMIC box):

- The greetd-hosted stack now **launches cleanly** — greetd session-worker 11,
  `cosmic-comp cosmic-greeter`, Xwayland :0 and the `cosmic-greeter` app all
  alive as `_cosmicgreeter` on VT 1 — but tty1 renders only a **grey
  wallpaper + cursor, NO login UI**; the greeter app runs but never draws its
  user list / login panel. That render bug is still open (see TODO.md); this
  release adds the logging needed to debug it.
- **`[COSMIC-GREETER-LOG]` — the logger gap.** The installer created
  `/etc/sv/cosmic-greeter/log` and `/etc/sv/cosmic-greeter-daemon/log`
  (`mkdir -p`) but wrote **no `log/run`**, so runsv spammed
  `fatal: unable to start log/./run: file does not exist` and **no svlogd
  output survived a reboot** — no `cosmic-greeter`/`cosmic-comp` evidence for
  the grey-screen investigation. Each service now gets a standard Void svlogd
  logger (`log/run` → `exec svlogd -tt /var/log/<svc>`, root-owned `0750` log
  dir; both services exec as root). The box-side `~/fix-cosmic-greeter.sh`
  still needs the same two `log/run` bodies so its output survives too.

**Remaining open items (tracked in TODO.md):** with the logger runs in place,
re-test on the box and, with the greeter up, capture the logs to decide whether
the missing element is accountsservice UI population (accounts-daemon is
linked) or the greeter theme/wallpaper only; confirm logins start a session and
the `[COSMIC-POLKIT]` agent dialog appears. Only patch code if conf + image +
service state are confirmed correct but the greeter still renders grey.

**Validation:** `bash -n` passes; `checks/check-heredocs.sh` extracts the two new
`log/run` bodies and `bash -n`s them clean; `checks/check-defaults.sh`
unchanged.

---

## Beta-v2.9.13 — `[ACCTSVCS-ICON]` + `[COSMIC-POLKIT-GUARD]` (default AccountsService avatar; session-ready COSMIC polkit agent)

`SCRIPT_VERSION = Beta-v2.9.13`. Two live `<host>` follow-ups to the Beta-v2.9.12
login, both post-fix verification findings.

**`[COSMIC-POLKIT-GUARD]` (polkit agent died at autostart → no dialogs).** With
the greeter fixed and a real user session running on `<host>`, the reserved
`[COSMIC-POLKIT]` verification finding surfaced: the polkit-gnome agent was a
`<defunct>` **zombie** under cosmic-session — cosmic-session fired the baked
autostart entry before the COSMIC compositor/session-bus was up, the agent
exited instantly, and the session never respawned it, so GUI privilege prompts
would hang with nothing to present. (Confirmed by test-running the identical
binary with the live display-session env: it runs clean indefinitely — the
autostart timing, not the agent, is the fault.) The installer now writes
`/usr/local/sbin/cosmic-polkit-guard` (waits for the compositor-backed session:
`$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY` socket + a `dbus-send` that answers on the
session bus, then runs the real agent; respawns it on exit with a 2s settle so
a late fire/crash self-heals) and points the baked COSMIC autostart entry at it.

**`[ACCTSVCS-ICON]` (greeter logs `failed to open icon ... NotFound`).** The
greeters — including cosmic-greeter-daemon on `<host>` — read the user's avatar
from `/var/lib/AccountsService/icons/<username>`; a clean `useradd` never
writes it and accounts-daemon does not synthesize one, so every boot logged an
unhandled icon-open error for the current user. The installer now copies the
themed `avatar-default` graphic (Adwaita's `scalable/status/avatar-default.svg`
first, Pop's `avatar-default-symbolic.svg` as fallback — the same graphics the
greeters already render for users with no icon) to
`/var/lib/AccountsService/icons/<user>` right after `useradd`, before
accountsservice's D-Bus write; best-effort (guarded on the icon file existing
in the target, so a desktop whose icon set lacks it simply skips).

**Residual (documented, unfixable from the installer):** the daemon's
`errors loading cosmic-comp config: ... RonSpanned(ExpectedComma line 4)` is a
parse failure inside the binary's **embedded default** config — no `config.ron`
exists anywhere under the greeter home, `/root`, or the user's config
(verified by `find / -name config.ron`), so provisioning a file cannot fix it.
It repeats per start but is benign (this was already the recorded dead lead in
TODO.md).

**Validation:** `bash -n` passes; `checks/check-heredocs.sh` extracts the new
`/usr/local/sbin/cosmic-polkit-guard` body and `bash -n`s it clean;
`checks/check-defaults.sh` unchanged (no prompt surface touched).

---



## Beta-v2.9.14 — `[COSMIC-GREETER-SESSION-BUS]` (session D-Bus wrapper for the cosmic-greeter DM)

`SCRIPT_VERSION = Beta-v2.9.14`. Discovered while archiving the `<host>` as-built
state into the Cosmic-Void project (`docs/installer-gap-session-bus.md`): the
proven-good greeter on `<host>` was NOT running the config the installer wrote.

**`[COSMIC-GREETER-SESSION-BUS]` (bare spawn maps no login panel).** After the
Beta-v2.9.12 account fix, the as-built `/etc/greetd/cosmic-greeter.toml` on the
working box still differed from the installer's heredoc: it exec'd
`/etc/greetd/cosmic-greeter.start`, a wrapper that runs
`dbus-run-session -- cosmic-comp cosmic-greeter` and appends to
`/var/log/cosmic-greeter-session.log`. The wrapper's own comment documents
why it exists: cosmic-greeter is built to run *inside* a COSMIC session that
provides `DBUS_SESSION_BUS_ADDRESS`; a bare greetd spawn has no session bus,
cosmic-comp cannot init its session D-Bus or update the activation environment,
and the iced login panel never maps as a layer — grey + cursor only (the same
symptom the Beta-v2.9.12 account bug produced, hence the `<host>` debugging
initially attributing the working state to the account rename alone). The live
wrapper (`v5`, dated well after the installer's heredoc) plus the captured
`cosmic-greeter.toml` are in the Cosmic-Void as-built evidence.

The installer's cosmic-greeter branch now ships the wrapper explicitly:

- `/etc/greetd/cosmic-greeter.start` is written (the byte-identical `v5`
  `dbus-run-session` wrapper from the proven-good `<host>` box) and chmodded
  `0755`.
- `/var/log/cosmic-greeter-session.log` is **pre-created** as
  `cosmic-greeter:cosmic-greeter 0644`: the wrapper's `>>` redirect runs as
  the greeter user (greetd drop-privileges before exec'ing `default_session`)
  and `/var/log` is root-only, so on a fresh install the redirect would
  otherwise fail before the compositor starts.
- The toml's `[default_session] command` is now
  `command = "/etc/greetd/cosmic-greeter.start"` (not the bare
  `cosmic-comp cosmic-greeter` the installer previously wrote).

The account fix (Beta-v2.9.12) and this session-bus fix (Beta-v2.9.14) are
**both** required for a working greeter: exact `cosmic-greeter` username for
the greeter-vs-locker dispatch, session D-Bus for the panel to map as a layer.
The parent installer is now aligned with the proven-good machine.

**Validation:** `bash -n` passes; `checks/check-heredocs.sh` extracts the new
`/etc/greetd/cosmic-greeter.start` body (bounded `INNER_EOF`) and `bash -n`s it
clean; `checks/check-defaults.sh` unchanged (no prompt surface touched); a
`grep -rn "Beta-v2.9.13"` walk confirmed the only surviving references are
historical feature markers.

---

---

## Beta-v2.9.15 — `[COSMIC-GREETER-DBUS-POLICY]` (system-bus policy re-emit for the renamed greeter group)

`SCRIPT_VERSION = Beta-v2.9.15`. Found on the **first fresh Beta-v2.9.14
install** (`<host>`, 2026-09-07, `VOID_INSTALL.txt`: `DESKTOP_ENV=cosmic`,
`DISPLAY_MANAGER=cosmic-greeter`): the greeter branch ran (`greeter` target, not
`locker`), the login panel mapped, and a full COSMIC session started — so the
Beta-v2.9.12 + Beta-v2.9.14 fix chain is confirmed **end-to-end on a from-scratch
install**. But the session log showed a real, reproducible gap every start:

```
cosmic_greeter::greeter: failed to load user data from daemon:
org.freedesktop.DBus.Error.AccessDenied: Rejected send message, 1 matched rules
... interface="com.system76.CosmicGreeter" member="GetUserData"
destination="com.system76.CosmicGreeter" (uid=0 ... cosmic-greeter-daemon)
cosmic_greeter::greeter: Failed to apply user display config
```

**Root cause.** The packaged `/usr/share/dbus-1/system.d/com.system76.CosmicGreeter.conf`
ships bus grants for `group="_cosmicgreeter"` (the package's historical account
name) and `user="root"`. The Beta-v2.9.12 `[COSMIC-GREETER-USER]` fix creates the
account as exactly `cosmic-greeter` (group `cosmic-greeter`, gid 992 on `<host>`),
so the greeter's `GetUserData` method call to the root daemon matched no allow
rule and dbus-daemon rejected it. Login is unaffected — the user list comes from
`org.freedesktop.Accounts` (the supervised accounts-daemon), not from the greeter
daemon — but per-user display config (background/avatar/scale lookups via the
daemon) silently fails, leaving `Failed to apply user display config` on every
boot. The `_cosmicgreeter` group (gid 993) lingered on `<host>` but the greeter
belongs to `cosmic-greeter` (gid 992), so the stale grant matched nothing.

**Fix.** The installer's cosmic-greeter branch now re-emits the policy to
`/etc/dbus-1/system.d/com.system76.CosmicGreeter.conf` (a real dbus-daemon
`includedir`, read *after* the packaged `/usr/share/dbus-1/system.d`; both are
merged, so re-emitting the whole file with the renamed group supersedes the stale
grant, and a leftover `_cosmicgreeter` group harmless matches nothing — D-Bus
policy is additive per-allow):

```xml
<policy group="cosmic-greeter">
    <allow send_destination="com.system76.CosmicGreeter"/>
    <allow receive_sender="com.system76.CosmicGreeter"/>
</policy>
<policy user="root">
    <allow own="com.system76.CosmicGreeter"/>
    <allow send_destination="com.system76.CosmicGreeter"/>
    <allow receive_sender="com.system76.CosmicGreeter"/>
</policy>
```

Written idempotently in the same Stage-2 chroot pass that provisions the account,
adjacent to the accounts-daemon block, chmod `0644`.

**Validation:** `bash -n` passes; the new body is a bounded-quoted-heredoc
(`PDBUS_EOF`) — `checks/check-heredocs.sh` extracts it into the chroot tree and
classifies it correctly; `checks/check-defaults.sh` unchanged (no prompt surface
touched). **Verified live on `<host>` post-reboot (2026-09-07):** the policy file
written by hand before reboot, then after the 15:23-local boot the greeter's
`GetUserData` AccessDenied and `Failed to apply user display config` lines both
disappear from `/var/log/cosmic-greeter-session.log`, the greeter still runs the
`greeter` target (not `locker`), and a full COSMIC session starts from the
greeter (loginctl session 2 = <user>, wayland, seat0/tty1, Active) — the live
confirmation plus the installer change close the chain without a further fresh
install (see TODO.md).

---

---

## Beta-v2.9.16 — `[KERNEL-SELECT]` (kernel package choice: linux + mainline/LTS toggles)

`SCRIPT_VERSION = Beta-v2.9.16`. The kernel the installer deploys was
previously hardcoded to `linux-mainline` in exactly two spots: the base-system
bootstrap (`xbps-install ... base-system btrfs-progs linux-mainline
glibc-locales`, Stage 1) and the post-install `xbps-reconfigure -f
linux-mainline` (Stage 2, the call that fires the `/etc/kernel.d` hooks +
dracut). It is now a real Stage-1 choice, asked immediately after the
bootloader selection and before the Limine wallpaper / encryption prompts.

## Kernel toggles

Void's current x86_64 repo ships exactly three kernel flavors, and the base
`linux` (the main rolling kernel) is **always** installed — Void's
`base-system` meta-package depends on it (verified on `<host>`:
`base-system` run_depends includes `linux>=0`). So the prompt is a
per-flavor toggle pair for the two extras on top of the guaranteed `linux`:

1. **linux-mainline** — newest features, shortest support window; Void marks it
   "for experts only". **Default OFF** (opt-in): it was the hardcoded/tested
   kernel of earlier releases, but is now the adventurous choice.
2. **linux-lts** — Long Term Support; most conservative, longest support
   window; best for servers or stable/older hardware. **Default ON** — bare
   Enter ships `linux` + `linux-lts`. (Flipped 2026-09-07 per maintainer
   request: mainline was the original default back when the whole path was
   hardcoded to it; with the toggles the conservative LTS is now the safe
   default, mainline is opt-in.)

To get all three flavors (base `linux` + mainline + LTS), answer `y` to both
toggles — the resolved set becomes `linux linux-mainline linux-lts`. Bare
Enter defaults to `linux linux-lts`; answering `y` only to mainline gives
`linux linux-mainline`.

## Threading

The resolved set (`$KERNEL_PKGS`, space-joined, always starting with `linux`)
is orthogonal to `$KERNEL_MODE` — KERNEL_PKGS only changes *which* kernels are
installed, KERNEL_MODE only describes how Limine *reads* the kernel files from
the ESP (always `esp-copy`). The variable is:

- wired to `DEFAULT_KERNEL_MAINLINE` (false) / `DEFAULT_KERNEL_LTS` (true) in
  the `[PROMPT-DEFAULTS]` block — two extra boolean defaults, replacing this
  feature's earlier single menu-index default,
- persisted in the resume-state file (`_sv` list), so a resumed run
  reconstitutes the exact kernel set the interrupted run chose,
- exported into chroot_env.sh and hard-validated inside the chroot (the set is
  checked non-empty and every element must be `linux`, `linux-lts`, or
  `linux-mainline`; anything else aborts rather than silently reconfiguring
  whatever the last xbps run touched),
- used (deliberately word-split, per-SC `SC2086` disables at both sites) in the
  Stage-1 bootstrap (`xbps-install ... base-system btrfs-progs $KERNEL_PKGS
  glibc-locales`) and the Stage-2 `xbps-reconfigure -f $KERNEL_PKGS` — the
  existing `/lib/modules` dracut-regen loop and the Limine/grub-btrfs kernel
  scans already cover *every* installed kernel, so menus and initramfs stay
  correct for any combination,
- recorded in `/etc/void-installer/install-config` as `KERNEL_PKGS`
  (secret-free, human-readable as-built summary, matching the file's purpose).

**Validation:** `bash -n` passes; `checks/check-defaults.sh` reports all 35
`DEFAULT_*` vars (including the two new `DEFAULT_KERNEL_MAINLINE` /
`DEFAULT_KERNEL_LTS`) declared and wired; `checks/check-heredocs.sh` fully clean
(the new in-chroot `KERNEL_PKGS` element validation lives inside the CHROOT
heredoc and is bash-n'd by the extractor). **NOT yet verified on a real
install** — a fresh install answering `y` to both toggles (or per-flavor) is
the remaining live confirmation (see TODO.md); note the defaults flipped to
lts-conservative on 2026-09-07, so a bare-Enter run (`linux linux-lts`) is
NOT the historical mainline baseline and must be boot-tested.

---

---

## Beta-v2.9.17 — `[DEVICE-PROFILE]` (laptop vs desktop/server: tlp + bluetooth gates)

`SCRIPT_VERSION = Beta-v2.9.17`. Whether the box is a laptop or a
desktop/server is now a real Stage-1 choice, asked immediately after the
kernel packages and before the Limine wallpaper / encryption prompts.

## Profile menu

A 5-way numbered menu (same idiom as bootloader/desktop):

1. **Automatic** (default) — probes `/sys/class/dmi/id/chassis_type` on the
   live CD. Portable classes (8/9/10/11/14/30/31/32) → laptop-with-bluetooth;
   desktop classes (3/4/5/6/7/13/15) → desktop-with-bluetooth (bluetooth is
   kept because presence is not detectable; tlp, which is meaningless on a
   desktop, is dropped). An unresolvable chassis (VMs, some boards) silently
   falls back to **laptop + Bluetooth** — the exact baseline every prior
   release shipped — so bare-Enter installs the same package set every
   historical install shipped (with the one deliberate difference that the tlp
   service is now *running*, an oversight fix — it was installed-but-inert
   before). An explicit profile (2–5) overrides detection entirely.
2. **Laptop with Bluetooth** — tlp (battery/power) + full bluetooth.
3. **Laptop, no Bluetooth** — tlp only.
4. **Desktop/server with Bluetooth** — bluetooth only, no tlp.
5. **Desktop/server, no Bluetooth** — minimal; neither runs.

## Resolution and threading

The moment a profile is picked it is resolved into a **concrete**
`DEVICE_PROFILE` (`laptop-bt` / `laptop` / `desktop-bt` / `desktop` — never
"auto") plus the two derived booleans that actually drive the install:

- `PROFILE_TLP` / `PROFILE_BT` gate the sites that were previously
  unconditional in the Stage-2 chroot body:
  - `tlp tlp-rdw` (battery power management, meaningless on a desktop/server)
    — removed from the big everyday-utilities `install_pkgs` line, now gated,
    AND on a laptop profile the `/etc/sv/tlp` runit service is linked into
    runsvdir so tlp actually runs from first boot (historically it was
    installed-but-never-linked, i.e. inert dead weight — linking was the
    maintainer's intent, treat as an oversight fix),
  - `bluez` (same line) and `libspa-bluetooth` (the always-pulled PipeWire
    audio line) — gated together: a "no bluetooth" profile ships NO bluetooth
    packages (a later USB dongle just installs `bluez` by hand),
  - the `/etc/sv/bluetoothd` → runsvdir link — gated (no bluetooth, no
    daemon). Note: nothing here changes elogind-based ACPI/lid handling;
    `acpid` was already gated to the turnstile session stack.
  - `preload` (adaptive readahead cache) — removed from the unconditional
    everyday-utilities line and gated **desktop/server-only**: its periodic
    pre-cache scans cause extra CPU/IO wakeups that work against battery, so
    laptop profiles never install it, and on the desktop/server profiles it is
    installed AND linked (`/etc/sv/preload` → runsvdir) so it actually runs.
- The concrete profile + both booleans are wired to
  `DEFAULT_DEVICE_PROFILE` (1) in `[PROMPT-DEFAULTS]` (bare-Enter = Automatic),
  persisted in the resume-state file (`_sv` list), exported into chroot_env.sh,
  hard-validated inside the chroot (profile ∈ the four concrete values, each
  boolean ∈ {true,false}; anything else aborts rather than silently pushing a
  desktop through tlp or dropping bluetooth on a laptop), and recorded in
  `/etc/void-installer/install-config` as `DEVICE_PROFILE` / `PROFILE_TLP` /
  `PROFILE_BT` / `PROFILE_PRELOAD` (secret-free).

**Design decision flagged for the maintainer:** bare-Enter = Automatic — on a
genuinely detected desktop this *drops* tlp, which is the intended fix but is
a real behavior change vs every prior release; un-resolvable hardware keeps
the full historical baseline. (The tlp-inertness question is resolved in the
opposite direction: linking `/etc/sv/tlp` was an oversight, now fixed — laptop
profiles get a *running* tlp.)

**Validation:** `bash -n` passes; `checks/check-defaults.sh` all 36 `DEFAULT_*`
vars declared and wired (including `DEFAULT_DEVICE_PROFILE`);
`checks/check-heredocs.sh` fully clean (the new gating lines + booleans live in
the CHROOT heredoc and are bash-n'd by the extractor). `[DEVICE-PROFILE]` is
**NOT yet verified on a real install** — and it stacks on the still-unverified
`[KERNEL-SELECT]`, so the next fresh install must exercise BOTH (see TODO.md).

---

---

## Beta-v2.9.18 — `[MATE-METAPACKAGE-REGRESSION]` (restore `mate` — fixes the "cannot login at the greeter" showstopper) + `[LIMINE-WALLPAPER-STAGE2]` (staging into the target)

`SCRIPT_VERSION = Beta-v2.9.18`. Two install-breaking defects found on the
current-script fresh install (Limine + mainline/LTS kernels + MATE +
LightDM/Slick + swap+zram+hibernate):

### 1. MATE login showstopper — the `mate` metapackage was accidentally dropped

`Beta-v2.9.9`'s `[MATE-TERMINAL]` change **replaced**
`install_pkgs mate network-manager-applet` with
`install_pkgs mate-terminal pluma mate-media network-manager-applet`,
silently removing the `mate` metapackage. Every other DE installs its core
metapackage (`cinnamon-all` / `gnome` / `xfce4`), but MATE no longer did — a
fresh MATE install therefore had **no `mate-session`, no panel/settings
daemon, and no `/usr/share/xsessions/mate.desktop`**.

Because the installer also writes `user-session=mate` into the generated
`lightdm.conf` (`[LIGHTDM-*]`), the Slick/GTK greeter selected a MATE session
that did not exist. After the password authenticated, the wrapper had nothing
to exec, so the session died instantly and LightDM bounced back to the
greeter with an empty `.xsession-errors` — exactly the reported showstopper
("cannot login at the greeter prompt"). The GTK-vs-Slick greeter choice was a
**red herring**: the same failure hits either greeter because there is no
MATE desktop to start. (Cinnamon "worked" because `cinnamon-all` was still
installed correctly.)

**Fix.** Restore the `mate` metapackage alongside the explicitly-installed
helpers: `install_pkgs mate mate-terminal pluma mate-media
network-manager-applet`. `mate` pulls `mate-base`/`mate-session-manager` →
`/usr/share/xsessions/mate.desktop`, so `user-session=mate` now launches a
real session. xbps dedups the overlapping helper deps.

### 2. Limine wallpaper never reached the ESP — prompt-phase staging was covered by the root mount

HANDOFF.md documented this latent bug; it recurs on every opt-in wallpaper
install. The wallpaper was staged to `/mnt/tmp/limine-splash.<ext>` at
**prompt** phase, when `/mnt` was still the live root's plain directory. Later
the installer mounts the target `@` subvolume **over `/mnt`** (line ~3607),
covering the live-root `/mnt/tmp`. `chroot_env.sh` survives because it is
written *after* that mount (into the target's real `/tmp`); the wallpaper did
not, so the chroot's `/tmp/limine-splash.*` loop found nothing and the ESP
copy never ran — `limine-env` stayed `yes`/`stretched` but no
`/boot/efi/limine-splash.<ext>` ever existed, and the guarded generator
(`[LIMINE-WALLPAPER]` invariant #9) correctly stayed quiet.

**Fix.** Re-stage the image into the mounted target right after the `@` root
mount: if `LIMINE_WALLPAPER=yes` and the prompt-phase `WP_SRC` (still
reachable on the live medium/USB) is a real file, copy it to
`/mnt/tmp/limine-splash.<ext>` (the target's `/tmp`) so the existing chroot
ESP copy finds it. A missing/declined source leaves the guarded "no wallpaper"
default.

**Validation.** `bash -n` passes; `checks/check-defaults.sh` all consistent;
`checks/check-heredocs.sh` shell bodies all `bash -n` clean (the pre-existing
accounts-daemon `shellcheck` note is unchanged). `[MATE-METAPACKAGE-REGRESSION]`
restores the historical (pre-Beta-v2.9.9) behavior and still needs one live
fresh MATE install to confirm the greeter now reaches the desktop;
`[LIMINE-WALLPAPER-STAGE2]` needs one opt-in wallpaper install to confirm the
image lands on the ESP/limine.conf.

---

---

## Beta-v2.9.19 — `[NFT-VIRT-GATE]` (nftables forward rules gate on `$INSTALL_VIRT`) + `[GREETER-BG-DEPTH]` (lightdm greeter sees depth-3 wallpapers)

`SCRIPT_VERSION = Beta-v2.9.19`. Two fixes:
1. The `/etc/nftables.conf` forward chain no longer hardcodes the `br0` /
   `virbr*` accepts unconditionally.
2. The lightdm greeter background search is no longer blind to depth-3
   wallpapers (fixes the MATE + Slick black greeter).

### Why

The firewall heredoc used to ship a `forward` chain that always accepted
`iifname/oifname "br0"` and `"virbr*"`, regardless of whether virtualization
was chosen. Both interfaces exist only when QEMU/libvirt is installed:
- `br0` is the installer's custom KVM bridge — its NetworkManager profiles
  (`br0.nmconnection` / `br0-slave.nmconnection`, `[NM-BR0]`) are only written
  when `$INSTALL_VIRT=true`;
- `virbr*` is libvirt's default NAT bridge, present only with libvirt.

On a non-virt build those forward rules referenced interfaces that never
exist. Harmless (the rules simply match nothing), but dead cruft relative to
the actual software selection, and inconsistent with how the rest of the
script already gates virt-specific behavior on `$INSTALL_VIRT`.

### Fix

The `br0`/`virbr*` forward accepts are now a fragment (`NFT_FWD_RULES`, built
from a nested heredoc) emitted into the `forward` chain **only when
`$INSTALL_VIRT=true`**. `$INSTALL_VIRT` is already exported into the chroot via
`chroot_env.sh` (line ~3933) and referenced throughout the chroot, so it is
live where the firewall is written. The nftables heredoc changed from quoted
(`<< 'INNER_EOF'`) to unquoted (`<< INNER_EOF`) so `${NFT_FWD_RULES}` expands;
the rest of the body is pure nft syntax with no `$`/backticks, so the
interpolation is safe. `checks/check-heredocs.sh` still classifies it as a
non-shell config (`#!/usr/sbin/nft` shebang), so it is skipped by its
bash -n/shellcheck pass.

### Validation

- `bash -n Void_Linux_Installer.sh` — clean.
- Rendered config for **both** `$INSTALL_VIRT=true` (four forward accepts
  present) and `false` (forward chain = policy drop, zero rules) passes
  `nft -c -f` as root.
- `checks/check-heredocs.sh` — ALL CLEAN (60 heredocs: 30 shell-classified,
  30 non-shell config, `/etc/nftables.conf` skipped as non-shell).
- `checks/check-defaults.sh` — ALL CONSISTENT (no `DEFAULT_*` surface touched).

No live-install confirmation required: this is a config-generation refinement,
and both branches are syntactically validated with `nft -c`.

---

---

## Beta-v2.9.19b — `[GREETER-BG-DEPTH]` (lightdm greeter background search deepened to see mate-backgrounds)

### Why

Fresh MATE + Slick installs reproduced a black greeter. On-disk evidence from
`<host>`:
- `/etc/lightdm/slick-greeter.conf` was the pristine package default (mtime =
  package build date), never written by the installer.
- `mate` (incl. `mate-backgrounds`) is installed before the greeter-bg block,
  so a wallpaper should have been found — but the `find` used `-maxdepth 2`,
  and `mate-backgrounds` places images at **depth 3**:
  `/usr/share/backgrounds/mate/<category>/<file>.jpg`.
- On this box only 48 of 78 wallpaper files are at depth ≤ 2; the remaining 30
  (all the depth-3 mate images) were invisible to every `-maxdepth 2` search.

So a MATE install that had no `adwaita-l.*` and no depth-2 genesis file found
nothing in the generic fallback, `_greeter_bg` stayed empty, and the
`background=<path>` line was never written → the greeter stayed on its black
default.

### Fix

The two generic wildcard fallback `find`s in the lightdm greeter-bg block went
from `-maxdepth 2` to `-maxdepth 5`, so they can descend into
`mate/<category>/` (and beyond). The `adwaita-l.*` specific-name passes stay at
`-maxdepth 2` (adwaita files are top-level; harmless either way). No other
behavior changes.

### Validation

- `bash -n Void_Linux_Installer.sh` — clean.
- On `<host>` the deepened generic fallback now resolves a depth-3 mate image
  (`/usr/share/backgrounds/mate/nature/*.jpg`), confirming the previously-missed
  path is found.
- `checks/check-heredocs.sh` — ALL CLEAN.
- `checks/check-defaults.sh` — ALL CONSISTENT (no `DEFAULT_*` surface touched).

 **Live confirmation still required:** one fresh MATE + LightDM (Slick or GTK)
install must reach a non-black desktop. This is scheduled as part of the next
batch reinstall on `<host>`.

---

---

## Beta-v2.9.19c — `[DEVICE-PROFILE-CONFIRM]` (Automatic shows the detected profile and lets you confirm or override)

### Why

When the user picked **Automatic** (`1`) on the device-profile menu, the
installer silently accepted whatever SMBIOS resolved (or the unresolvable
fallback) and continued. There was no feedback about which profile had been
detected and no way to correct a wrong guess before the tlp/bluez/preload
package gates committed. The user requested a confirm/override step.

### Fix

After `1) Automatic` resolves `DEVICE_PROFILE` + the `PROFILE_TLP`/`PROFILE_BT`/
`PROFILE_PRELOAD` booleans from the SMBIOS chassis, the installer now prints the
detected profile with its human description and asks:
`Keep this? [Y/n] or pick 2-5 to override`.
- Bare Enter / `y` / `yes` confirms the detected profile (no change).
- `2`/`3`/`4`/`5` re-resolves to the corresponding explicit profile and prints
  the new value.
- An unresolvable chassis still falls back to `laptop-bt` but the user is told
  so and gets the same confirm/override chance.
- The menu help text for option `1` now notes the confirm/override step.

Because `--dry-run` also walks every prompt interactively, the dry-run plan
already prints the concrete `DEVICE_PROFILE` + booleans (line ~3320), so this
also directly satisfies the TODO's "confirm REVIEW/dry-run shows the concrete
profile + booleans" check on its own.

### Validation

- `bash -n Void_Linux_Installer.sh` — clean.
- `checks/check-defaults.sh` — ALL CONSISTENT (no `DEFAULT_*` surface touched).
- `checks/check-heredocs.sh` — ALL CLEAN.
- Logic harness tested for chassis 31 (laptop: detects laptop-bt; override to
  5 → desktop-no-bt), chassis 3 (classic desktop: desktop-bt, tlp dropped;
  bare Enter confirms), and unresolvable chassis (falls back laptop-bt with an
  override chance). All branches re-resolve the profile + booleans correctly.

 **Live confirmation (this install):** picking Automatic on the HP Envy x360
(chassis 31) should detect `laptop-bt` and prompt, and the plan/install-config
should show `laptop-bt` tlp=true bt=true preload=false.

---

---

## Beta-v2.9.19d — `[DEVICE-PROFILE-RCL]` (first-boot rc.local tlp/bluetoothd/preload service links never fired)

### Why (live-confirmed bug)

On the Beta-v2.9.18 install of `<host>`, `install-config` recorded
`DEVICE_PROFILE="laptop-bt"`, `PROFILE_TLP="true"`, `PROFILE_BT="true"` — but
neither `/etc/sv/tlp` nor `/etc/sv/bluetoothd` was linked into
`/etc/runit/runsvdir/default/`, and neither daemon ran (`sv status tlp` →
"file does not exist"). The laptop profile's promised battery/bluetooth
services were installed-but-inert.

Root cause: the first-boot `/etc/rc.local` heredoc is **single-quoted**
(`<< 'INNER_EOF'`), so nothing inside is expanded by the installer — the
`__BOOTLOADER__`/`__INSTALL_VIRT__`/... tokens are sed-substituted to real
values afterwards (lines 8519+). But the `[DEVICE-PROFILE]` service links that
this release added used **plain `$PROFILE_BT`/`$PROFILE_TLP`/
`$PROFILE_PRELOAD`** — chroot-phase variables that are never exported or
persisted anywhere, so at first-boot runtime they were **always empty**. The
`[ "$PROFILE_TLP" = "true" ]` test failed on every fresh boot and the link was
never created. This is the same bug class the existing comment at lines
8501-8518 already documented for `$BOOTLOADER`/`$INSTALL_VIRT`/`$INSTALL_DOCKER`
and fixed — the DEVICE-PROFILE additions introduced it again.

### Fix

Converted the three links in the rc.local heredoc to `__PROFILE_BT__`,
`__PROFILE_TLP__`, `__PROFILE_PRELOAD__` placeholders and added the matching
`sed -e "s/__PROFILE_*__/${PROFILE_*}/g"` lines to the substitution pass, so
the chosen profile's services actually link on first boot.

### Validation

- `bash -n Void_Linux_Installer.sh` — clean.
- End-to-end sed simulation with this laptop's `laptop-bt` values: the links
  render as `[ "true" = "true" ]` for bluetoothd + tlp (linked), and
  `[ "false" = "true" ]` for preload (not linked) — correct for a laptop.
  The substituted rc.local passes `bash -n`.
- `checks/check-heredocs.sh` — rc.local is `bash -n clean` + shellcheck clean;
  the only `FAILURES PRESENT` is the pre-existing accounts-daemon SC2093 note,
  present identically at HEAD before this change.
- `checks/check-defaults.sh` — ALL CONSISTENT (no `DEFAULT_*` surface touched).

**Live confirmation (this install):** on the fresh MATE install, `/etc/sv/tlp`
and `/etc/sv/bluetoothd` must now be linked into runsvdir/default and both
daemons must appear running on first boot (preload remains absent for a laptop).

---

---

## Beta-v2.9.19e — `[LIMINE-WP-REGUARD]` (the wallpaper re-stage guard checked a covered path, so the image never reached the ESP)

### Why (live-confirmed bug)

On the Beta-v2.9.18 install of `<host>`, `LIMINE_WALLPAPER=yes` was chosen, but
after install there was **no `/boot/efi/limine-splash.*`** on the ESP and **no
`wallpaper:` line in limine.conf** — the wallpaper never landed, and the boot
menu stayed plain.

The `[LIMINE-WALLPAPER-STAGE2]` fix (2.9.18) added a re-stage step after the
target root mounts over `/mnt`. But its guard was:

```sh
if [ "$LIMINE_WALLPAPER" = "yes" ] && [ -f "${WP_STAGED:-}" ]; then
```

`WP_STAGED` points at live `/mnt/tmp/limine-splash.<ext>` — the path that the
*previous* (prompt-phase) stage wrote. Mounting the target `@` subvolume over
`/mnt` then **covers** that path: `/mnt/tmp/...` now resolves into the
**target's** `/tmp`, where the file does not (yet) exist. So `[ -f "$WP_STAGED" ]`
was **false exactly when this block was needed**, the re-stage was skipped, the
chroot's `/tmp/limine-splash.*` loop found nothing, and the generator's
existence-guarded wallpaper section stayed quiet.

### Fix

Drop the check on the covered `/mnt/tmp` staged path and guard on the
**live** source instead:

```sh
if [ "$LIMINE_WALLPAPER" = "yes" ] && [ -f "${WP_SRC:-}" ]; then
```

`$WP_SRC` is the image the user picked — it lives on the live medium
(`/run/media/...`, `/home`, etc.), **not** under `/mnt`, so it is still
reachable at re-stage time. Guarding on it correctly re-stages the image into
the target's `/tmp`, which the chroot ESP-copy loop then moves onto the ESP.

### Validation

- `bash -n Void_Linux_Installer.sh` — clean.
- Guard logic simulated: with the covered `WP_STAGED` the old guard returns
  "skipped" (the bug); with a reachable `WP_SRC` the new guard fires and
  copies; with a missing source it is safely skipped.
- `checks/check-defaults.sh` — ALL CONSISTENT.
- `checks/check-heredocs.sh` — only the pre-existing accounts-daemon note.
- `set -e` (not `set -u`) governs the re-stage block, so `${WP_SRC:-}` is
  belt-and-suspenders; the `LIMINE_WALLPAPER != yes` path short-circuits before
  touching `$WP_SRC` anyway.

**Live confirmation (this install):** chooing the wallpaper opt-in must now
produce `/boot/efi/limine-splash.<ext>` + a `wallpaper:` line in limine.conf,
and the image must show at the Limine boot menu.

---

---

## Beta-v2.9.20 — `[LIMINE-WP-DRIVES]` (wallpaper picker can jump back to the mounted-drive list)

### Why (UX gap, user-reported)

The `[LIMINE-WALLPAPER-BROWSE]` browser starts at `/run/media`, which is keyed
by per-user subdirs (`/run/media/<user>/<label>`). Once the user enters a
mounted USB drive they could move up/down freely *within that drive's tree*,
but pressing `..` (`WP_DIR="$(dirname "$WP_DIR")"`) only climbed to the
per-user parent (`/run/media/<user>`), whose siblings are just that one user's
mounts — not the "every mounted drive" view. When drives mount under different
username parents (e.g. `/run/media/root/...` vs `/run/media/<user>/...`), the
entered drive is the only sibling visible and there was **no on-screen
shortcut or feedback** that another `..` (to `/run/media`) would list every
drive. The user resorted to Ctrl-C + restart.

### Fix

- Add explicit jump keywords **`m`** and **`drives`** that set `WP_DIR` directly
  back to `/run/media` (the drive-list root). If `/run/media` is absent (e.g.
  `-d` on a box with no mounted media) it says so and stays in place rather
  than silently jumping to a nonexistent root.
- Update the browse hint to name the keywords and note that `..` from the
  per-user dir reaches the drive list.

### Validation

- `bash -n Void_Linux_Installer.sh` — clean.
- Keyword handler is a pure-bash `[ "$WP_SRC" = m ] || [ "$WP_SRC" = drives ]`
  branch inserted before the path-exists check, so it cannot collide with a
  file/dir named literally `m` or `drives` being *selected by number* (numbers
  are expanded to full paths earlier).
- `checks/check-heredocs.sh` — this block is top-level script (not a heredoc
  body), so it is covered by the script's own `bash -n`; no new heredoc added.
- `checks/check-defaults.sh` — no new prompt/default added.

---

---

## Beta-v2.9.21 — `[GREETER-BG-EXPORT]` (lightdm greeter background's real root cause: missing chroot export)

`SCRIPT_VERSION = Beta-v2.9.21`.

### Why (live-confirmed on `<host>`)

The `[GREETER-BG-DEPTH]` fix (2.9.19) deepened the greeter-background find to
`-maxdepth 5` so it can see mate-backgrounds' depth-3 files. Testing on `<host>`
proved that was **necessary but not sufficient**:

- `gnome-backgrounds` was installed at `06:32` — that is the greeter-bg block's
  retry firing, so the block **did** execute on the fresh install.
- After that retry, `adwaita-l.jpg` existed at depth 2
  (`/usr/share/backgrounds/gnome/adwaita-l.jpg`) — so even the **old** depth-2
  search would have found an image at write time.
- Yet `slick-greeter.conf` came out **pristine** (mtime = pkg build date, never
  touched) while `lightdm.conf` was correctly written by the installer.

The only thing that can skip the `cat >` write is the gate:

```sh
case "$LIGHTDM_GREETER" in
    gtk)   ... ;;
    slick) ... ;;
esac
```

The greeter-bg block runs inside the **single-quoted** chroot heredoc
(`chroot /mnt /bin/bash << 'CHROOT_EOF'`), so `$LIGHTDM_GREETER` is NOT
expanded at stage-1 write time — it must resolve **in-chroot** at runtime.
But only `LIGHTDM_GREETER_PKG` and `LIGHTDM_GREETER_SESSION` were written to
`chroot_env.sh` (used by the lightdm.conf block); the bare `gtk`/`slick`
choice was never threaded in. In the chroot `case "$LIGHTDM_GREETER"` matched
**neither** branch → **no greeter conf was ever written**, so the login screen
stayed black (or the package default) for any desktop.

### Fix

Thread the bare choice into the chroot alongside the two derived values:

```sh
# chroot_env.sh dump block
echo "export LIGHTDM_GREETER=\"$LIGHTDM_GREETER\"" >> /mnt/tmp/chroot_env.sh
```

This is the same bug family as `[DEVICE-PROFILE-RCL]` (2.9.19): a chroot-phase
variable used inside the single-quoted heredoc likely needs to reach the chroot
explicitly. The depth fix is retained (it makes a mate-only install's search
resolve), but the export is what actually lets the `case` write the conf.

### Validation

- `bash -n Void_Linux_Installer.sh` — clean.
- Simulated the in-chroot gate on `<host>`: with `LIGHTDM_GREETER` unset the
  `case` prints `[NONE!]` (nothing written); with `slick` it resolves the
  intended `/usr/share/backgrounds/mate/nature/YellowFlower.jpg`.
- `checks/check-heredocs.sh` / `checks/check-defaults.sh` — clean.

**Pending:** one fresh MATE + LightDM install to confirm `slick-greeter.conf`
now carries a real `background=` line and the greeter no longer boots black.

---

---

## Beta-v2.9.22 — `[FALKON-QT-NOTICE]` (Falkon Qt-WebEngine notice on non-KDE desktops)

`SCRIPT_VERSION = Beta-v2.9.22`.

### Why

Closes the long-standing "Falkon browser gating / KDE-dependency awareness"
discussion item (`TODO.md`). The original framing that Falkon "pulls KDE
dependencies" was overstated: on Void, `falkon`'s real package dependencies are
essentially `qt5-webengine qt5-x11extras qt5-svg` — it pulls the Qt +
QtWebEngine stack but does **not** install a KDE desktop. The genuine cost on a
non-KDE DE is the heavyweight QtWebEngine web-engine set, which is redundant
only when KDE is already the chosen desktop.

### Design decision (warn-not-gate)

Rather than block Falkon on non-KDE DEs (it is a legitimate standalone browser
on any desktop), the choice follows the existing Vivaldi/Brave notice pattern:
a short inline **NOTICE** line is printed before the `[y/N]` prompt, **only**
when `DESKTOP_ENV != kde`. No separate confirmation gate is added, and the
prompt text itself is unchanged.

### Change

In the web-browser selection block, before the Falkon prompt:

```sh
if [ "$DESKTOP_ENV" != "kde" ]; then
    if [ "$DESKTOP_ENV" = "lxqt" ]; then
        echo "NOTICE: Falkon shares LXQt's Qt5 but still pulls in the Qt"
        echo "WebEngine stack on top (it does not install KDE)."
    else
        echo "NOTICE: Falkon runs standalone but pulls in the Qt + QtWebEngine"
        echo "stack on top of your ${DESKTOP_ENV} desktop (it does not install KDE)."
    fi
fi
ask "Install Falkon (KDE's browser, works fine standalone too)? [y/N]: "
```

`DESKTOP_ENV` is already in scope at this point in Stage 1 (set by the desktop
choice earlier), so no new export or plumbing is needed.

**LXQt nuance:** LXQt is a Qt5 desktop but not KDE, so it *does* get the notice
— though its text differs: LXQt already shares the Qt5 base, so only the
QtWebEngine set is newly pulled in. GTK-based desktops (GNOME/Xfce/MATE/
Cinnamon/COSMIC) get the full "Qt + QtWebEngine" wording. KDE alone is
suppressed.

### Validation

- `bash -n Void_Linux_Installer.sh` — clean.
- Branch exercised: shows the notice under `gnome`/`xfce`/`mate`/`cosmic`/etc.,
  suppressed under `kde`.
- `checks/check-defaults.sh` / `checks/check-heredocs.sh` — unaffected (the
  notice is pure Stage-1 prompt text, no new heredoc or default).

---

---

## Beta-v2.9.23 — `[SSH-SERVER]` + `[SSH-KEYS]` (OpenSSH server toggle + key import/backup, closing the OpenSSH discussion item)

`SCRIPT_VERSION = Beta-v2.9.23`. Closes the "OpenSSH server toggle + SSH-key
import/backup" TODO discussion item with all three planned pieces, plus the
shared-picker refactor that makes the wallpaper browser a reusable utility.

### Why

The `<host>` as-built had OpenSSH **never** installed (it is not in the default
`install_pkgs` list) and `/etc/sv/sshd` never linked, so SSH administration out
of the box meant a post-install `xbps-install openssh`, hand-edited
`sshd_config`, and a `nftables.conf` edit — the input chain is `policy drop`,
so merely installing sshd leaves it unreachable. The discussion also asked for
a way to import an existing keypair into the target from removable media and to
generate + back up a keypair, all of which the script lacked.

### 1. `[SSH-SERVER]` — default-OFF install + enable toggle

- New prompt after the virtualization install choice, before the subvolume
  gates: **Install and enable the OpenSSH server (sshd)? [y/N]** (default OFF).
- When enabled: a validated **SSH port** loop (1–65535, default 22) that
  threads into **both** the `sshd_config` drop-in (`Port`) and the
  `/etc/nftables.conf` input chain (a `${SSH_PORT_RULE}` fragment mirroring the
  `${NFT_FWD_RULES}` placeholder pattern — empty/blank on a no-sshd build, so
  the policy-drop chain stays closed).
- Two access-policy sub-prompts (deliberately prompted, not preshipped):
  **Allow password authentication over SSH? [Y/n]** (default ON — a bare-Enter
  box stays reachable without key setup) and **Allow root to log in over SSH
  (public-key only)? [Y/n]** (default `prohibit-password`, Void's stock; `no`
  hard-blocks root SSH).
- Chroot: `install_pkgs openssh`; config via a drop-in
  `/etc/ssh/sshd_config.d/10-void-installer.conf` when the upstream
  `Include /etc/ssh/sshd_config.d/*.conf` line is present, else an append
  fallback (sshd honors the first value and upstream keeps these keys
  commented). Service linked first-boot via the direct runsvdir rule (invariant
  #3): `[ "__INSTALL_SSH_SERVER__" = "true" ] && ln -sfn /etc/sv/sshd ...`,
  with the placeholder added to the rc.local sed pass. Void's `/etc/sv/sshd`
  generates host keys on first start, so no keygen is needed at install time.
- Public facts only ride chroot_env/install-config/`Void_Install.txt`:
  `INSTALL_SSH_SERVER`, `SSH_PORT`, `SSH_PASSWORD_AUTH`, `SSH_ROOT_LOGIN`.
  No key material, no passphrase — the `[SSH-KEYS]` copies live only in
  `~/.ssh` and the user's backup medium.

### 2. `[SSH-KEYS]` — import existing key / generate fresh key

- **Import:** reuses a new shared `browse_pick <mode> <title>` file browser
  (refactored from the `[LIMINE-WALLPAPER-BROWSE]` picker, behavior
  unchanged — the wallpaper prompt is now just the `img`-mode caller). Pops an
  absolute/relative-path-vs-menu prompt or the numbered browser starting at
  `/run/media` (else `/root`). Picking a private key stages it (plus its
  `<name>.pub` sibling when present) to `/mnt/tmp/ssh-import/imported/`;
  picking a `.pub` file prints a warn-not-gate "that looks like a public key"
  notice.
- **Generate:** `ssh-keygen -q -t ed25519` on the **live env** (guaranteed
  present; the target's openssh only exists when `[SSH-SERVER]` is on). Two
  opt-in options are offered first — a **comment** (default
  `${TARGET_USER}@${TARGET_HOSTNAME}`, a public string that sits inside the
  `.pub` regardless; typed to override, Enter keeps the default) and a
  **passphrase** (`[Y/n]`, default **on**). A protected key is typed/pasted
  (`read -s` accepts both) twice + match, held in memory ONLY, and `unset`
  right after ssh-keygen burns it in — so the `~/.ssh` copy AND any exported
  backup are equally encrypted at rest. Exporting (a `browse_pick dir`
  destination → `id_ed25519-backup{,.pub}`, private chmod 600) just copies the
  already-protected-or-not key; whether protection is on is a public fact (it
  is in the key's own header), the passphrase itself is not.
- **Deposit:** the chroot copies `/tmp/ssh-import/*` (the `/mnt/tmp` → `/tmp`
  mapping) into `~/.ssh` with 0700/0600/0644 perms — dir 0700, private keys
  0600, `.pub` 0644, owner `TARGET_USER` — guarded on the account existing.
- **Shred:** every staging copy is `shred -u`'d right after the chroot deposit
  AND inside the failure unwind (`cleanup_on_failure`), so an aborted run never
  leaves key material on the live USB. Explicitly **not** persisted to
  install-config / limine-env / resume state / chroot_env (only the public
  generated-key facts `SSH_KEY_COMMENT` / `SSH_KEY_PROTECTED` go to
  install-config).

### `[PROMPT-DEFAULTS]` additions

`DEFAULT_INSTALL_SSH_SERVER=false`, `DEFAULT_SSH_PORT=22`,
`DEFAULT_SSH_PASSWORD_AUTH=yes`, `DEFAULT_SSH_ROOT_LOGIN=prohibit-password`,
`DEFAULT_IMPORT_SSH_KEY=false`, `DEFAULT_GENERATE_SSH_KEY=false`,
`DEFAULT_SSH_KEY_PROTECTED=yes`, `DEFAULT_EXPORT_SSH_KEY=false`.

### Validation

- `bash -n Void_Linux_Installer.sh` — clean.
- `checks/check-defaults.sh` — 44/44 defaults declared + wired, all consistent.
- `checks/check-heredocs.sh` — 59 heredocs (30 shell, 29 non-shell), ALL CLEAN
  (the rc.local SSH link is a baked `__INSTALL_SSH_SERVER__` placeholder under
  the existing SC2050 carve-out).

**Pending:** one fresh install to confirm an enabled server is reachable on the
chosen port from a second box (nftables rule present, `sshd_config.d` drop-in
accepted, `/etc/sv/sshd` linked on first boot) and that an import produces a
log-in-able `~/.ssh`; the `sshd_config` `Include` fallback could not be
verified against the `<host>` archive (it has no `/etc/` snapshot).

---

---

## Beta-v2.9.24 — `[DEVICE-PROFILE-BT-DETECT]` (bluetooth hardware probe feeds Automatic device-profile detection)

`SCRIPT_VERSION = Beta-v2.9.24`. The Automatic device-profile option (1) now
scans the live CD for a Bluetooth controller and ties `PROFILE_BT` to the real
hardware, instead of assuming every box has bluetooth.

### Why

Within `[DEVICE-PROFILE]` (Beta-v2.9.17), Automatic only looked at the SMBIOS
chassis type and then shipped **bluetooth unconditionally** on every resolved
profile (`laptop-bt` or `desktop-bt` — there was never an automatic path to the
non-BT variants). A desktop with no radio therefore got `bluez` +
`libspa-bluetooth` + a linked `bluetoothd` for nothing. Since the tlp/bluetoothd
service links now actually run (the `[DEVICE-PROFILE-RCL]` fix), that phantom
`bluetoothd` would churn from first boot on machines that can never talk to a
radio. The probe makes `PROFILE_BT` descriptive of the box.

### 1. The detection

All modern x86 Bluetooth controllers — USB dongles AND M.2/PCIe WiFi+BT combo
cards (Intel, MediaTek, Realtek, Broadcom…) — expose a USB interface of the
**Bluetooth Programming Interface** class `0xE0:0x01:0x01`. The USB core
enumerates those interfaces and writes their modalias (`icE0isc01ip01`, i.e.
`icE0` `isc01` `ip01`) into
`/sys/bus/usb/devices/<dev>/<iface>/modalias` **even when no BT driver/module is
bound**, so the check needs no `lsusb`, no bluez, no kernel module loaded on the
live CD. The dev box itself (MediaTek combo, `0E8D:223C`) matches.

```
_bt_hw="no"
for _m in /sys/bus/usb/devices/*/modalias /sys/bus/usb/devices/*/*/modalias; do
    [ -r "$_m" ] || continue
    if grep -qi 'icE0isc01ip01' "$_m"; then _bt_hw="yes"; break; fi
done
```

### 2. How it feeds the profile

Within each chassis class the probe picks the BT vs no-BT variant:

- laptop chassis (`8/9/10/11/14/30/31/32`): BT detected → `laptop-bt`, else
  `laptop` (tlp stays on either way).
- desktop/server chassis (`3/4/5/6/7/13/15`): BT detected → `desktop-bt`, else
  `desktop` (preload stays desktop-only either way).
- unresolvable chassis (VM/unknown): keeps the **laptop baseline (tlp on)** —
  the historical behavior — with bluetooth now also from the probe (a VM with
  no BT no longer ships bluez).

Two echo lines tell the user what the probe found, and the existing
`[DEVICE-PROFILE-CONFIRM]` keep/override step still lets them correct a
misdetection (`n`/`2-5`) before anything is committed. tlp behavior is
unchanged by this release — the bare-Enter = Automatic sign-off (maintainer,
2026-09-08) continues to hold: a detected desktop still drops tlp.

### 3. Validation / gates

- `bash -n` clean; `checks/check-defaults.sh` (44 vars) untouched — no new
  prompts; `checks/check-heredocs.sh` untouched — no scheme/heredoc change;
  shellcheck 0 findings.
- Probe validated on the dev box (built-in MediaTek combo detected; PCI-check
  option deliberately not added — combo cards already show as USB, and a PCI
  `0x0d11` heuristic risks false positives on legacy wireless controllers).
- **Pending live validation** (next fresh install): Automatic on a box with
  no BT must resolve `laptop`/`desktop` (no bluez, no bluetoothd link), a BT
  box keeps `laptop-bt`/`desktop-bt`, and REVIEW/dry-run/install-config show
  the concrete booleans.

---

---

## Beta-v2.9.25 — `[HARDWARE-REVIEW]` + `[NVIDIA-GATE]` (live-box GPU/wireless probe + NVIDIA-driver gate)

`SCRIPT_VERSION = Beta-v2.9.25`. Right after the device profile, the installer
probes the live box for GPU families and wireless presence, then gates the ONE
driver worth gating on that probe: the NVIDIA proprietary driver.

### Why

The BT probe added in Beta-v2.9.24 proved the pattern (sysfs-only, no extra
live-CD tooling, live hardware == target hardware). Extending it, the driver
discussion item wanted "auto-detected drivers". The honest analysis: most of
Void's driver story is in-kernel + in-mesa (nothing to install or prune), and
the only driver that can actively break a desktop if installed blind is the
NVIDIA proprietary driver (X.Org/PRIME/DKMS weight, conflicting-module risk).
So instead of a dozen auto-detect prompts, this release ships one
probe-and-recommend review that gates exactly that one decision — and exposes
the probe results for future reuse (the Steam/gaming TODO can consume
`GPU_FAMILIES` instead of re-probing).

### 1. The probe (pure sysfs, no pciutils/lspci)

- **GPU families:** scan `/sys/bus/pci/devices/*/class` for display controllers
  (`0x03*`), read each `vendor` file, map to `NVIDIA` (0x10de) / `AMD`
  (0x1002) / `Intel` (0x8086) / `ASPEED (BMC)` (0x1a03) / `VMware` (0x15ad) /
  `QEMU` (0x1234) / `Other`, dedupe into `GPU_FAMILIES`. Dedicated booleans
  `HAS_NVIDIA_GPU`/`HAS_AMD_GPU`/`HAS_INTEL_GPU` are derived.
- **Wireless:** `WIFI_HW=yes` if `/sys/class/ieee80211/` has any phy.

### 2. `[NVIDIA-GATE]` — the single hardware-gated driver

- Prompt: **Install the NVIDIA proprietary driver?** — `[Y/n]` when an NVIDIA
  GPU was detected, `[y/N]` otherwise. `DEFAULT_INSTALL_NVIDIA=auto` follows
  the probe; exporting `DEFAULT_INSTALL_NVIDIA=yes|no` pins it regardless.
- Chroot gate: `install_pkgs nvidia` only when `INSTALL_NVIDIA=true`. `nvidia`
  (nonfree, already enabled) auto-pulls `nvidia-dkms` → `dkms` →
  gcc/make/`linux-headers`; the headers for each installed kernel flavor
  (`linux-headers`/`linux-lts-headers`/`linux-mainline-headers`) are mapped
  from `KERNEL_PKGS` so dkms can build the module for all of them.
- `/etc/modprobe.d/50-nvidia.conf` blacklists `nouveau` so the open driver
  cannot bind the device ahead of the proprietary module.
- A warning is printed if the user opts in without NVIDIA hardware.

### 3. Threading

- Exported + persisted on resume: `INSTALL_NVIDIA`, `GPU_FAMILIES`, `WIFI_HW`,
  `HAS_*_GPU`; carried into chroot_env.
- Recorded in `/etc/void-installer/install-config` (hardware facts are public)
  and a pointer line (`NVIDIA_DRIVER=... (GPU: ...)`) in `Void_Install.txt`.
- REVIEW and the `--dry-run` plan both print a Hardware + NVIDIA line.
- `[PROMPT-DEFAULTS]` count grows to 45 (`DEFAULT_INSTALL_NVIDIA=auto`).

### 4. Validation / gates

- `bash -n` clean; `checks/check-defaults.sh` (45 vars) ALL CONSISTENT;
  `checks/check-heredocs.sh` 60 bodies (the new `50-nvidia.conf` is one)
  ALL CLEAN; shellcheck 0 findings.
- Probe validated on the dev box: AMD iGPU (`0x1002:0x1900`) detected as the
  single GPU family, `WIFI_HW=yes` (phy0 present) — and it correctly resolves
  the NVIDIA prompt to `[y/N]` (no NVIDIA hardware).
- Verified against the live Void repo (xbps on the dev box): `nvidia` =
  `nvidia-595.91.07_1` in `current/nonfree`, pulls `nvidia-dkms` → `dkms`
  (whose own deps include gcc/make/`linux-headers`); all three
  `linux[-lts|-mainline]-headers` metas exist.
- **Pending live validation** (next fresh install): NVIDIA box → `[Y/n]`
  default, driver + headers land, dkms build succeeds for every installed
  kernel, nouveau blacklisted, glxinfo/nvidia-smi work; non-NVIDIA box →
  `[y/N]` default stays off.

---

---

## Beta-v2.9.26 — `[WIFI-FW]` + `[WIFI-FW-VERIFY]` (real wifi chipset detection + firmware-gap closer + post-install proof)

`SCRIPT_VERSION = Beta-v2.9.26`. The hardware review's wifi line stops being a
yes/no and becomes: *name the actual radios*, state which firmware covers
them, close the single gap Void leaves by default, and prove the finished
system actually has driver + firmware.

### Why (the user's Debian pain, made generic)

On Debian the user had to download `firmware-mediatek` (or similar) by hand for
their MediaTek WLAN — but **not on Void**. The reason, verified against the
live repo:

- Void's kernel chain (`linux` → `linux-base`) pulls `linux-firmware-network`
  (+ `-intel`/`-amd`/`-nvidia` splits), and `linux-firmware` itself depends on
  `-network` + `-amd`. Between them they ship **every mainstream vendor**:
  MediaTek mt76 (e.g. `WIFI_MT7922`/`MT7961` blobs), Realtek rtw88/rtw89/rtl*,
  Qualcomm/Atheros ath9k/10k/11k + qca, Intel iwlwifi (in the base blob).
  `base-system` additionally pulls `wifi-firmware` → legacy ipw2100/ipw2200/
  zd1211. So a fresh Void install has NO wireless-firmware gap for any of these.
- The **one genuine gap**: Broadcom. `brcmfmac`/`b43` blobs live ONLY in the
  `linux-firmware-broadcom` split, and **nothing pulls it** (confirmed:
  `linux-firmware` run_depends = `-amd` + `-network`; `linux-base` run_depends
  lacks it; `wifi-firmware` = ipw/zd1211 only). A Broadcom box on a fresh Void
  would hit exactly the user's Debian-class surprise.

### 1. `[WIFI-FW]` — chipset identification + gap closure

- **Probe**: enumerate the live `phy*` wireless devices (`/sys/class/ieee80211/
  phy*/device` symlink — works for PCI and USB radios), reading PCI
  `vendor`/`device` or USB `idVendor`/`idProduct`; a PCI class-`0x0280*`
  fallback catches radios the live kernel won't bind (driver not in-kernel —
  firmware alone can't fix those; the verify warns instead of pretending).
  Dedupes into `WIFI_IDS` (e.g. `0x14c3:0x0616`) + human `WIFI_CHIPS`.
- **Coverage print**: every detected vendor maps to the package that covers it
  (`MediTek (mt76) → linux-firmware(-network)`, `Broadcom → linux-firmware-
  broadcom [NOT in Void defaults]`, etc.), so an installer sees *why* no extra
  download is needed — the exact question the user asked.
- **Gap prompt**: only when a Broadcom chip was detected —
  `Install linux-firmware-broadcom (firmware for the detected Broadcom radio)? [Y/n]`
  — default `auto` (yes) via `DEFAULT_WIFI_FW`, export a fixed `yes`/`no` to
  pin it. Declining prints a warning naming the consequence. Non-Broadcom
  hardware gets no prompt at all.
- Chroot installs `${WIFI_FW_PKG}` when `INSTALL_WIFI_FW=true`.
- Threading: `INSTALL_WIFI_FW WIFI_IDS WIFI_CHIPS WIFI_FW_PKG` persisted on
  resume, exported to chroot_env, and recorded in install-config + a
  `WIFI_HARDWARE` pointer line in `Void_Install.txt`; REVIEW + `--dry-run`
  plan print them.

### 2. `[WIFI-FW-VERIFY]` — proof on the target

After the kernels are reconfigured/dracut rebuilt, the verify iterates every
detected radio and checks, **inside the chrooted target**:
- firmware present (`/usr/lib/firmware/mediatek`, `iwlwifi`, `rtw88|rtw89|
  rtl*`, `ath*|qca`, `brcm`, marvell dirs), and
- driver module present via `modules.dep` **and** `modules.builtin` (so
  built-in drivers don't false-flag) for the newest installed kernel.

Per chip it prints `[wifi] verified: 0x14c3:0x0616 — driver + firmware present
in target (kernel …)` or a WARNING with the actionable hint (missing
`linux-firmware-*` split → install it; module absent → dkms/out-of-tree driver,
firmware can't fix it). Purely informational; nothing is gated on it.

### 3. Validation / gates

- `bash -n`, `checks/check-defaults.sh` (now **46** vars) ALL CONSISTENT,
  `checks/check-heredocs.sh` 60 bodies ALL CLEAN, shellcheck 0.
- Probe exercised against the dev box's own hardware: the MediaTek combo is
  identified exactly — `WIFI_IDS=0x14c3:0x0616`, `WIFI_CHIPS=MediaTek (mt76)`,
  `WIFI_FW_PKG=<none>` (correctly *no* gap → no prompt, firmware is default).
- Verify exercised against the dev box's installed modules+firmware:
  `[wifi] verified: 0x14c3:0x0616 — driver + firmware present in target
  (kernel 7.2.3_1)`. The Broadcom branch (`0x14e4:*` → `WIFI_FW_PKG=linux-
  firmware-broadcom` → `[Y/n]` prompt path) was logic-tested.

### 4. Pending live validation

- A fresh install on **Broadcom** hardware → prompt appears, `[Y/n]` default,
  split installs, verify passes (`brcm`, `brcmfmac`).
- A fresh install on the **dev box (MediaTek)** → no extra-firmware prompt,
  `[wifi] verified: 0x14c3:0x0616` line in the install log.

---

---

## Beta-v2.9.27 — `[CPU-DETECT]` + `[NIC-DETECT]` (microcode becomes a report-only auto-install; the br0 NIC moves into the hardware review)

`SCRIPT_VERSION = Beta-v2.9.27`. Two more hardware facts move into the
`[HARDWARE-REVIEW]` block, each placed on the fact-vs-decision side it belongs
to — matching the principle established by `[HARDWARE-REVIEW]`/`[NVIDIA-GATE]`
(Beta-v2.9.25) and `[WIFI-FW]` (Beta-v2.9.26): drivers/firmware PROMPT only when
there is a genuine install decision; otherwise they are reported (GPU line, now
the CPU line) or silently auto-installed (linux-firmware, now microcode).

### Why no prompt for microcode

- The CPU vendor is a read-only hardware fact (read from `/proc/cpuinfo` in the
  live review). A microcode prompt has one correct answer — you cannot
  usefully install the wrong vendor's blob — so prompting is friction without a
  decision. This is the same reasoning that keeps the GPU line report-only
  (Linux drives every GPU in-kernel, so there is nothing to install).
- Microcode carries no tradeoff-class consequence (the NVIDIA driver does: DKMS
  builds per kernel flavor + nouveau blacklist = why it still prompts; the
  Broadcom firmware does: non-default package split = why wifi still prompts).
  It is a tiny, always-beneficial blob — the same category as `linux-firmware`
  itself, which the installer already installs silently.
- On AMD the mapping is `linux-firmware-amd`, which is ALREADY pulled by Void's
  default chain (`linux-firmware` depends on `-network` + `-amd`); `intel-ucode`
  is the only real addition, so the "choice" is genuinely only meaningful for
  Intel and even there it is non-optional-in-practice.

### What `[CPU-DETECT]` does now

- Review line, report-only:
  `Detected CPU : GenuineIntel — microcode: intel-ucode (auto-installed)` —
  or `SKIPPED (DEFAULT_MICROCODE=no)` on the opt-out, or
  `no vendor microcode package (in-kernel defaults)` for unknown vendors.
- `MICROCODE_PKG` (`intel-ucode` | `linux-firmware-amd` | empty) is decided
  live, exported through chroot_env into the chroot, and installed word-split
  with the base toolchain set (`install_pkgs ${MICROCODE_PKG} linux-firmware
  dracut ...` — empty drops the arg, intentional).
- `MICROCODE_DECIDED=yes` records that the live review ran. The chroot honors a
  decided EMPTY package verbatim (opt-out, unknown vendor) and only re-derives
  from its own `/proc/cpuinfo` when the flag is absent — a resumed run whose
  state file predates this detection, so interrupt-upgrade never silently loses
  microcode that an older version would have installed.
- Opt-out: `DEFAULT_MICROCODE=no` (`[y/N]` in the top block). `auto` (default)
  installs the detected package.

### What `[NIC-DETECT]` does

- The wired-NIC pick for the bridged br0 VM network used to live silently in the
  virt phase, gated on `INSTALL_VIRT`. It now appears in the review as a
  detect-and-confirm hardware fact:
  `Detected wired NIC : eth0 (feeds the bridged VM network if you choose
  virtualization)` then `Keep this interface? [Y/n] or type another name:`.
- Probe order: a carrier-active wired port first, then USB-ethernet adapters
  (bridging can work cable-less with a USB-tethered phone); wireless and
  non-physical devices excluded. Nothing found → the value stays empty so the
  existing `INSTALL_VIRT`-gated late re-probe (whose "plug in a USB ethernet
  adapter in the SAME USB port" notice) still runs untouched.
- Prompt semantics: `y`/Enter accepts the detected interface; `n` defers
  (empty → late re-probe re-decides); typing anything else pins that literal
  interface name. `DEFAULT_NIC=<name>` pins a name and skips both the review
  prompt and the late probe.
- Recorded in install-config and the docs-log alongside the other review facts.

---

## Beta-v2.9.28 — `[SUBVOL-FLATPAK-TEXT]` + `[APPIMAGE-FUSE]` + `[BRAVE-FLATPAK-GATE]` (subvolume preamble text corrected; INSTALL_FLATPAK now gates FUSE for AppImages; Brave only offered when Flatpak is on)

`SCRIPT_VERSION = Beta-v2.9.28`. Three changes: a prompt-text correction, a
gated package addition, and a browser-availability gate — no `DEFAULT_*`
surface changed.

- The per-app subvolume preamble (Beta-v2.9.3, `2645639`) claimed "OctoXBPS
  and Flatpak are excluded" from subvolume isolation. That was false on
  arrival: `[SUBVOL-GATES]` (Beta-v2.9.0, `604f682`) already carried a
  Flatpak row (`INSTALL_FLATPAK|PROVISION_FLATPAK_SUBVOL`), so the loop has
  always resolved a `PROVISION_FLATPAK_SUBVOL` decision and `@flatpak` was
  created, mounted at `/var/lib/flatpak`, and written to fstab whenever a
  master gate (or the bare-Enter default `SUBVOL_ISOLATE_INSTALLED=yes`)
  decided yes. The prose contradicted its own code for five versions.
- The preamble now lists Flatpak among the isolable apps and documents the
  real `@flatpak` rationale: the GB-scale `/var/lib/flatpak` store stays out
  of `@` snapshots, and a `@` rollback preserves installed Flatpak apps —
  the same survive-rollback logic as `@srv`/`@network`.
- OctoXBPS remains the sole documented exclusion (a lightweight GUI
  package-manager frontend with no dedicated data directory to isolate) —
  the only app whose exclusion was ever accurate.

### `[APPIMAGE-FUSE]` — Flatpak also brings FUSE for AppImages

Installing Flatpak now also installs `fuse` (FUSE 2, `libfuse.so.2`) and
`fuse3` (FUSE 3). The AppImage runtime self-mounts its squashfs payload via
a libfuse dlopen that the AppImage ecosystem has historically tied to FUSE 2
(AppImageKit's own wiki: "AppImages require FUSE version 2 to run"; most
wild AppImages ship that runtime), while recent static-behaviour runtimes
speak FUSE 3. On Void the two coexist cleanly (no Debian-style
`fuse`↔`fuse3` conflict), and base-system pulls neither — so this gate is
the only AppImage readiness the installer grants, closing the gap a fresh
`flatpak`-only install would otherwise leave (a later Gear Lever / AppImage
user would land on the slow `--appimage-extract-and-run` fallback).

Gear Lever itself is deliberately NOT installed or prompted: it has no
official Void package (verified against `void-packages` srcpkgs), so it
cannot be an xbps opt-in; Flathub's `it.mijorus.gearlever` stays a
one-command add for the user. AppImage storage needs no subvolume — the
binaries live in `~/Applications` under `@home` (a subvol mount there would
silently lapse whenever the configurable folder changes), and per-app
AppImage config is ordinary XDG `~/.config`/`~/.local/share` data, exactly
like a natively installed app, so it belongs in the `@home` snapshot scope.

### `[BRAVE-FLATPAK-GATE]` — Brave is only offered when Flatpak is on

Brave has no official Void package, so its only installer route is the
Flatpak first-boot queue. Because the Flatpak prompt already precedes the
web-browser section, `INSTALL_FLATPAK` is resolved before Brave would be
offered. Previously Brave was always offered (with an inline notice) and was
therefore pickable-then-skipped: selecting Brave without Flatpak produced a
Stage-2 WARNING and nothing installed. Now the prompt is hidden unless
`INSTALL_FLATPAK=true`; when hidden, `INSTALL_BRAVE` is forced to `false`
and a one-line NOTICE explains why the option is absent. The Stage-2 WARNING
survives as defense-in-depth for the manual-export/resume path (a state file
from an older version can carry `INSTALL_BRAVE=true` alongside
`INSTALL_FLATPAK=false`) — that path still gets a loud warning instead of
silence.

---

---

## Beta-v2.9.29 — `[NFT-VIRT-PRINT]` (virt builds echo the generated nftables.conf)

`SCRIPT_VERSION = Beta-v2.9.29`. One change, chroot-phase only — a visibility
improvement that also serves as an on-target test artifact. No prompt, no new
gate, no `DEFAULT_*` surface.

### `[NFT-VIRT-PRINT]` — the written firewall is shown on a virt build

`[NFT-VIRT-GATE]` (Beta-v2.9.19) made the `/etc/nftables.conf` forward chain
conditional: the `br0`/`virbr*` accepts are a fragment emitted only when
`INSTALL_VIRT=true`, because those interfaces exist only when virtualization
was selected (both the custom KVM bridge and libvirt's default NAT bridge).
That left the operator with no easy way to confirm the right rules went into
the file at install time — the gate could be "working" while unnoticed.

Now, right after the config is generated in the chroot, a virt build prints it
to the terminal:

```text
--- /etc/nftables.conf (virtualization build: br0/virbr* forwards present) ---
…full file…
--- end nftables.conf ---
```

Non-virt builds stay silent (they have nothing runtime-specific to review —
the forward chain is just the drop rule). The printout doubles as a
live-validation artifact: on a real virt install, seeing the `br0`/`virbr*`
accepts in the output confirms both `[NFT-VIRT-GATE]` and the
`INSTALL_VIRT`-export path (`chroot_env.sh`) worked end-to-end, closing the
last un-validated corner of that feature.

---

---

## Beta-v2.9.30 — `[NFT-ICMPV6-RATELIMIT]` + `[NFT-RA-RATELIMIT]` + `[NFT-OPEN-PORT]` (IPv6 ping rate limit, RA-flood cap, firewall port helper)

`SCRIPT_VERSION = Beta-v2.9.30`. Three /etc/nftables.conf-era refinements —
two config parity/hardening rules and one operator helper, all chroot-phase.
No prompt, no new gate, no `DEFAULT_*` surface.

### `[NFT-ICMPV6-RATELIMIT]` — IPv6 ping gets the same cap as IPv4

The config already rate-limited IPv4 echo-request (`limit rate 1/second burst
5 packets`), but the IPv6 path was a blanket `meta l4proto ipv6-icmp accept`
with no limit — every IPv6 ping, unbounded. The rate-limited rule now mirrors
IPv4, still sitting *before* the broad `ipv6-icmp accept` (first-match wins,
so everything else ICMPv6 — ND, RA, MLD — keeps its unconstrained flow):

```text
        ip protocol icmp icmp type echo-request counter limit rate 1/second burst 5 packets accept
        meta l4proto ipv6-icmp icmpv6 type echo-request counter limit rate 1/second burst 5 packets accept
        meta l4proto ipv6-icmp icmpv6 type nd-router-advert counter limit rate 6/minute accept
        meta l4proto ipv6-icmp accept
```

### `[NFT-RA-RATELIMIT]` — router advertisements are capped

Neighbor-Discovery Router Advertisements are accepted broadly (required for
SLAAC), but a hostile actor on the LAN can flood RAs to hijack default-routing
/ DNS, or just spam. `nd-router-advert` is now capped at `limit rate
6/minute` — far above normal router cadence (RA frequency is minutes apart in
steady state), generous enough never to break a real router, tight enough to
blunt a flood. Same insertion-order reasoning as the ping rule.

### `[NFT-OPEN-PORT]` — `void-firewall-open-port` helper + config doc

The input chain's `policy drop` makes any future WAN-facing service silently
unreachable — there was no sanctioned way to open a port except editing the
generated file. A new root helper, installed for **all** builds (a
non-virt / non-sshd box can still grow services later):

- `void-firewall-open-port add tcp:8080` / `rm` / `list`
- Rules are kept between two `# void-firewall-open-port: managed rules start/end`
  marker comments inside `chain input`.
- Every `add`/`rm` is **idempotent** and **parse-checked first**: the edit is
  written to `/etc/nftables.conf.new`, validated with `nft -c -f`, and only on
  success moved over the live file and the runit `nftables` service restarted
  (`sv restart nftables`). A failed parse or a missing marker leaves the live
  config untouched. `rm` refuses to touch a matching rule that lives *outside*
  the managed block (e.g. the installer's own `tcp dport 22` sshd line).
- The fixed `sh`d/`tcp dport 22 accept` line and the `br0`/`virbr*` forwards
  are not affected by the helper's scope.

A short comment at the top of `/etc/nftables.conf` documents the default-drop
rule and points at the helper, so the generated file is self-explaining.

---

---

## Beta-v2.9.31 — `[NFT-COUNTERS]` + `[NFT-RATELIMIT-KNOB]` (firewall drop observability; hardening-rate-limit control knob)

`SCRIPT_VERSION = Beta-v2.9.31`. Two of the three improvement ideas the user
selected for the generated nftables.conf: **a counters / observability pass**
and **a control knob** for the hardening rate-limit rules. No new prompt and
no new interface coupling. Also fixes a real install-time bug inherited from
v2.9.30.

### `[NFT-COUNTERS]` — every silent drop becomes a countable rule

`/etc/nftables.conf` was policy-DROP with three bare explicit drops, none of
which carried a `counter`, so `nft list ruleset` could not answer "why did my
packet die?". Now:

- `iif != "lo" ip daddr 127.0.0.0/8 drop` → adds `counter`
- `iif != "lo" ip6 daddr ::1 drop` → adds `counter`
- `ct state invalid drop` → adds `counter`
- `meta l4proto ipv6-icmp accept` (broad accept) → adds `counter`
- a trailing **`counter drop`** rule at the end of `chain input` AND `chain
  forward` makes the implicit policy-drop explicit: every filtered packet now
  lands on a countable rule, and `nft list ruleset` shows the exact counter
  of each drop reason. Same rule count semantics as the accept rules — pure
  observability, zero packet-path cost beyond the counter itself.

Counters are **unconditional** — they are not part of the knob below.

### `[NFT-RATELIMIT-KNOB]` — `DEFAULT_NFT_RATELIMIT` (env-only, no prompt)

The two hardening rules added in v2.9.30 (IPv6 echo-request cap and the
`nd-router-advert` 6/minute flood cap) are now gated by a boolean env knob,
`DEFAULT_NFT_RATELIMIT`:

- Default **`yes`** = the 2.9.30 tightened posture (both caps active).
- `export DEFAULT_NFT_RATELIMIT=no` before running = the plain pre-2.9.30
  posture: broad `ipv6-icmp accept` alone, no rate-limit rules.

Design, per the earlier session discussion:

- **No prompt.** Like `DEFAULT_MICROCODE`, the knob is an environment-level
  config lever, not an install-prompt question. Declared in the `DEFAULT_*`
  block, resolved to `NFT_RATELIMIT` in stage 1, exported into the chroot via
  chroot_env.sh, and consumed by the in-chroot nftables heredoc (empty
  fragment ⇒ blank line that nft ignores — the `SSH_PORT_RULE` /
  `NFT_FWD_RULES` pattern).
- **Narrow scope.** The knob switches only the two rate-limit rules. The
  counters and the IPv4 echo-request cap stay unconditional, because turning
  off ping rate-limiting while keeping drop-by-default is a defensible
  firewall posture (an honest sysadmin might want no limiter logging), but
  anti-spoof/invalid drops and IPv4 echo caps were never in dispute.
- **No interface coupling.** The knob references no interface names — the
  `[NFT-VIRT-GATE]` lesson (rules must not reference interfaces that might
  not exist) extends to knob tiers: the failed "STRICT/moderate/hardened"
  idea would have coupled rules to `eth0`/`wlan0` existence; this knob only
  emits/omits the two ICMPv6 rules and is host-agnostic.
- As-built value is recorded in **install-config** (`NFT_RATELIMIT`, line
  tells the operator whether the tightened posture was generated).

### Unconditional backtick fix (inherited v2.9.30 bug)

The header comment of the generated config is written by an **unquoted**
heredoc (`<< INNER_EOF`), whose contract is *pure nft syntax, no `${}` /
backticks* — but the 2.9.30 "how to open a port" comment contained `` `nft -c` `` in
literal backticks. Unquoted heredocs run backticks, so nft would have
executed `nft -c` (→ "nft: command not found") *on the live install*. Reworded
to plain text, matching the unquoted-heredoc contract documented next to the
`cat`.

### Files / wiring touched

- `Void_Linux_Installer.sh`: `DEFAULT_NFT_RATELIMIT` declaration (DEFAULT
  block), stage-1 `NFT_RATELIMIT` resolution + chroot_env.sh export, the
  `NFT_ICMP_RULES` fragment between `SSH_PORT_RULE` and the heredoc insert,
  the hardened heredoc body (counters + placeholder + terminal `counter drop`
  rules), the `unset` list, and the install-config as-built line. All three
  gates pass (`bash -n`, `check-defaults`, `check-heredocs`; 61 heredocs
  extracted, all clean), and the exact rendered `/etc/nftables.conf` was
  verified for virt/knob-on, non-virt/knob-off, and sshd-on combinations via
  the `/tmp` render harness.

---

## Beta-v2.9.32 — `[FW-AUDIT]` (report-only firmware accounting closes the per-vendor pruning discussion)

`SCRIPT_VERSION = Beta-v2.9.32`. The "per-vendor firmware pruning" TODO
discussion is resolved, and the resolution is a *report*, not a prune:
Void's wholesale firmware set is a hard dependency wall, so the honest
installer contribution is accurate accounting of what ships vs what the box
needs.

### Why pruning is impossible from the installer (verified against void-packages)

The `linux-base` template (2026.03.23) `depends` on:

```
dracut alsa-firmware linux-firmware-network sof-firmware
# x86_64/i686 additionally:
linux-firmware-intel linux-firmware-nvidia linux-firmware-amd
```

and `linux-firmware-network` itself `depends` on `linux-firmware-broadcom`.
All five firmware splits arrive as *required* dependencies of the
kernel-adjacent `linux-base`, and XBPS has **no recommends/optional tier** (an
apt concept Void deliberately omits). `xbps-remove linux-firmware-nvidia`
therefore refuses with *"cannot remove ... it's a dependency of installed
'linux-base'"*; forcing it leaves the pkgdb inconsistent and the next
`xbps-install -u` flags a broken system. Nothing in the installer can change
that — it acts *after* the dependency contract, not before it.

The **one** firmware decision Void genuinely leaves per-host is **CPU
microcode** (`intel-ucode` vs `linux-firmware-amd`), and `[CPU-DETECT]`
already prunes it to exactly one package (and `linux-firmware-amd` doubles as
the amdgpu/radeon blob, which is why it is not dropped on an AMD-GPU box even
under the wall).

### The audit block (chroot post-install, report-only)

After `[WIFI-FW-VERIFY]`, a `[fw] Firmware accounting (report-only):` block
queries the *target* pkgdb (`xbps-query -l`) and prints, per split:

- **present + "matches this box's probe (GPU/CPU)"** for `-amd`/`-intel`/
  `-nvidia` when the live-box hardware review detected matching hardware;
- **present + "kept ONLY by the linux-base dependency wall"** when the box
  does not need it — the irreducible wholesale tax (typically at least one of
  the three on any single-vendor build);
- `linux-firmware-network` as the always-kept bulk (every LAN/WLAN/Bluetooth
  vendor wholesale; never prunable);
- `linux-firmware-broadcom` as the one *closed gap* (installed for a detected
  Broadcom radio) or flagged absent when the install was declined;
- microcode line showing the one genuinely pruned package (`[CPU-DETECT]`);
- audio line when `sof-firmware`/`alsa-firmware` are present.

Nothing is gated and no prompt appears — same report-don't-decide ethos as
`[WIFI-FW-VERIFY]`. Validation: `bash -n`, check-defaults (no `DEFAULT_*`
change), check-heredocs all green; the block's output was exercised against
stubbed target pkgdb across five hardware scenarios (AMD/Intel/NVIDIA,
Broadcom-on/off, microcode-opt-out).

---

## Beta-v2.9.33 — `[FW-AUDIT-LOG]` (firmware accounting persisted into the as-built record)

`SCRIPT_VERSION = Beta-v2.9.33`. The Beta-v2.9.32 audit existed only on the
console; it now lives in the installed machine's own record file,
`~/Documents/Void_Install.txt`.

### Why Appendix Two, not a separate file

The as-built record (`[DOCS-LOG-CHOWN]` block, written mid-chroot) already
carries the pointer-style hardware facts (`WIFI_HARDWARE`, `CPU`/microcode,
`NVIDIA_DRIVER`) plus the full `xbps-query -l` inventory. The firmware
accounting is the same kind of fact, so it belongs in that single record as a
dedicated section — one greppable place for everything an operator or support
person needs to know about what a particular machine was built with. Persisting
it to a separate file would fragment the as-built story.

### What changed

- The `[FW-AUDIT]` block now builds its output into one `FW_AUDIT_TEXT`
  buffer instead of echoing directly: it prints exactly what it always did to
  the console, then appends the identical lines under a
  `# -------- FIRMWARE ACCOUNTING ([FW-AUDIT], as-built) --------` header to
  `~/Documents/Void_Install.txt` (after the package inventory).
- The record write precedes the audit in the chroot, so the append lands
  after the existing content; the root→user-owned append preserves the file's
  ownership (no `chown` needed again).
- Guarded: empty `TARGET_USER` or a missing/unwritable record file → the
  append is silently skipped; nothing about the install is gated on it.
- The end-of-install quick-reference line now reads "…(installed user, incl.
  firmware accounting)".

Validation: gates green (`bash -n`, check-defaults, check-heredocs 61 clean);
the console-print + append behavior was exercised against a sandboxed record
file (path rewritten to `/tmp`) across the firmware scenarios — appended
section matches the console verbatim.

---

## Beta-v2.9.34 — `[SLICK-BG-QUOTES]` + `[SSH-DEPOSIT-LOG]` + `[FLATPAK-NM-DISPATCH]` (slick greeter background quotes; robust ssh-key deposit detection; Flatpak first-boot queue moves to an NM dispatcher)

> Reconstructed from the header VERSION-HISTORY row, the inline `AI (Big
> Pickle)` markers, the gitlog (`5dfd880b` "feat: multi-filesystem data
> regions; Beta-v2.9.34->Beta-v2.9.38" region), and the `recovered_HANDOFF.md`
> live-validation list. No recovered original CHANGELOG text exists for this
> version (2.9.34–2.9.38 were folded into a single multi-filesystem feat
> commit); this entry fills that documentation gap.

`SCRIPT_VERSION = Beta-v2.9.34`. Three fixes shipped in this build:

**1. `[SLICK-BG-QUOTES]` — slick-greeter does NOT strip quotes.** The two
greeters differ: lightdm-gtk-greeter strips quotes from config values, but
slick-greeter opens a quoted `background="path"` as the literal `"/path"`
(quotes in the filename), fails, and falls back to `#000000` — a black
greeter. The slick branch now writes `background=${_greeter_bg}` UNQUOTED
(only the GTK branch keeps the quoted form).

**2. `[SSH-DEPOSIT-LOG]` — replace the fragile `ls -A` presence guard.** The
ssh-key deposit check (`[ -d /tmp/ssh-import ] && [ -n "$(ls -A ...)" ]`)
used an `ls -A` subshell that was fragile under `set -eEo pipefail` and gave
ZERO diagnostics when the deposit was silently skipped. Detection now uses
`find -quit` (no subshell, no pipefail hazard), and a missing account logs an
explicit WARNING. (The deposit semantics from `[SSH-KEYS]`, Beta-v2.9.23,
are unchanged.)

**3. `[FLATPAK-NM-DISPATCH]` — first-boot Flatpak queue moved out of the
rc.local background subshell.** Queued Flatpak apps (Brave etc.) install on
first login via a NetworkManager dispatcher script,
`/etc/NetworkManager/dispatcher.d/99-flatpak-firstboot` (the `__TARGET_USER__`
placeholder sed-substituted at generation time like rc.local). It fires on
`up`/`vpn-up` when the interface has a default route — guaranteed DNS — and
stamps `/var/log/flatpak-firstboot.done` only when EVERY queued app succeeds,
so a partial failure leaves the queue live for the next up event
(`[FLATPAK-NM-DISPATCH-STAMP]`, Beta-v2.9.46). Also realigned in this build:
the sshd + vboxdrv rc.local service links (sshd now linked first, so its
host-key generation isn't starved behind the vboxdrv module load).

---

## Beta-v2.9.35 — `[ESP-SIZE]` (shared EFI ESP-size menu; GRUB+ENCRYPT mounts the ESP at /boot)

> Reconstructed from the header VERSION-HISTORY row, the inline `esp_size_choose()`
> markers (`[ESP-SIZE]`), and the gitlog era commit. No recovered original
> CHANGELOG text exists for this version; this entry fills the documentation gap.

`SCRIPT_VERSION = Beta-v2.9.35`. The EFI ESP size becomes a real prompt-time
decision, served by ONE shared menu:

**`[ESP-SIZE]` — a shared `esp_size_choose()` menu (4 GiB default / 6 GiB /
8 GiB / Custom, 1 GiB floor).** Two bootloader paths need a real ESP, and
each now calls the same menu: Limine (right after the bootloader choice —
`esp-copy` mirrors every kernel/initramfs/snapshot onto the ESP) and the
GRUB+ENCRYPT path (which mounts the ESP AT `/boot`, so it shares the same
menu). Custom sizes are uppercased, validated with the 1 GiB floor, matched
against the gdisk single-letter forms, and normalized to K/M/G before being
stored in `$EFI_PART_SIZE` (threaded unchanged into sgdisk, the dry-run plan,
and resume state). Plain GRUB never calls it — its ESP at `/boot/efi` holds
only the bootloader and stays a fixed 1G.

**`[GRUB-ESP-SIZE-ORDER]` — real bug fixed.** The old GRUB+ENCRYPT in-loop
`[ "$ENCRYPT" = "yes" ] && EFI_PART_SIZE="4G"` read ENCRYPT BEFORE the ENCRYPT
prompt had settled it, so a GRUB+ENCRYPT fresh run always shipped a 1G ESP.
The size decision now happens AFTER the encryption choice, so the value is
correct.

---

## Beta-v2.9.36 — `[CHANNEL-GROUP]` + `[INSTALL-BREW]` (third-party app channels umbrella; opt-in Homebrew/Linuxbrew CLI/dev channel)

> Reconstructed from the header VERSION-HISTORY row and the inline
> `[CHANNEL-GROUP]`/`[INSTALL-BREW]` markers. No recovered original CHANGELOG
> text exists for this version; this entry fills the documentation gap.

`SCRIPT_VERSION = Beta-v2.9.36`. Third-party app channels get an umbrella and
a second channel:

**1. `[CHANNEL-GROUP]` — Flatpak and Homebrew shown as one umbrella, each an
INDEPENDENT toggle (both default OFF).** The banner reads "THIRD-PARTY APP
CHANNELS — Flatpak (sandboxed GUI apps) and Homebrew / Linuxbrew (unsandboxed
CLI & dev tools) are independent choices — enable either, both, or neither."
brew must not read as a sub-choice of Flatpak's sandbox; brew-only and
flatpak-only are both expressible. Complement, not replacement.

**2. `[INSTALL-BREW]` — Homebrew (classic Linuxbrew) opt-in.** The unsandboxed,
user-owned `~/.linuxbrew` CLI/dev channel. Installs ONLY the xbps runtime deps
(linuxbrew pulls the rest at prefix creation: `git curl file procps-ng`); the
installer deliberately does NOT pipe the vendor's `curl|bash` — the operator
creates the prefix on first login (NEWS step). Isolation is a separate opt-in
`@linuxbrew` per-user subvol (SUBVOL_ROWS row → `PROVISION_LINUXBREW_SUBVOL`,
default OFF — a correctly-owned plain `~/.linuxbrew` in `@home` already
survives a `@` rollback and isn't snapshotted), plus the subvol-tool `dev`
class.

---

## Beta-v2.9.37 — `[GAME-LAUNCHERS]` + `[GAME-SUBVOL]` (game launchers & runtimes umbrella; ONE shared `@game` subvol replaces `@steam`)

> Reconstructed from the header VERSION-HISTORY row and the inline
> `[GAME-LAUNCHERS]`/`[GAME-SUBVOL]` markers (lines 713/3208/3295/3964/5530/
> 8028 in the reconstructed installer). No recovered original CHANGELOG text
> exists for this version; this entry fills the documentation gap.

`SCRIPT_VERSION = Beta-v2.9.37`. A gaming umbrella and a consolidated subvolume:

**1. `[GAME-LAUNCHERS]` — "GAME LAUNCHERS & RUNTIMES", a default-OFF umbrella
after app channels / before Steam.** Delivery model: Lutris is Void main
(xbps); Heroic + Bottles have NO official Void package so they are Flatpak-only
and only offered when `INSTALL_FLAPTAK=true` (formalized as `[GAME-FLATPAK-GATE]`,
Beta-v2.9.40). Wine (system, multilib) is a separate runtime toggle a launcher
NEVER auto-pulls; gamemode (Feral governor daemon + 32-bit libs) likewise.
The banner keys an advisory line off the `[HARDWARE-REVIEW]` GPU probe
(`GPU_FAMILIES`) — advisory only, never a gate. Not in scope: Wine-GE /
Proton-FS (not in Void repos), ProtonUp-Qt.

**2. `[GAME-SUBVOL]` — ONE shared `@game` per-user subvol replaces the former
`@steam`-only subvol.** Gated on `INSTALL_ANY_GAME` (Steam ∨ Lutris ∨ Heroic ∨
Bottles, computed AFTER all launcher prompts; Wine/gamemode deliberately
excluded — no isolated data datadir) and the resolved `PROVISION_GAME_SUBVOL`
(Gate 1/Gate 2). Stage-2 derives the per-launcher mount set from `@game`
(`~/.local/share/Steam` + `~/.local/share/lutris`) via the subvol-tool
multi-mount loop + `@steam`/gaming alias resolution + `@game` fstab-guard
relaxation + the detach/destroy BRE-paren sed fix.

---

## Beta-v2.9.38 — `[MULTI-FS]` per-region data filesystems; `[MULTI-FS-RUNLOG]`; `[CRASH-USB-LOG]` (carved data regions; journal archiving; crash post-mortem to USB)

> Reconstructed from the header VERSION-HISTORY rows (lines 628-632), the
> ARCHITECTURE SUMMARY + inline `[MULTI-FS]` markers, the gitlog
> (`5dfd880b` "feat: multi-filesystem data regions; Beta-v2.9.34->Beta-v2.9.38",
> `1d03546e` `[MULTI-FS-RUNLOG]`, `0a5bbfae` `[CRASH-USB-LOG]` +
> numeric-path browse hardening), and the `recovered_HANDOFF.md` validation
> list. No recovered original CHANGELOG text exists for this version; this
> entry fills the documentation gap.

`SCRIPT_VERSION = Beta-v2.9.38`. The era's big feature — and the reason this
whole 2.9.34→2.9.38 batch shipped in ONE feat commit:

**1. `[MULTI-FS]` — per-region data filesystems.** Each of `/home`, `/var`,
`/var/cache`, `/srv`, `/opt` (+ the optional `Games` region) can either stay a
root-Btrfs subvolume (default) or be carved onto its OWN dedicated partition
with a per-region fs choice (**ext4 or btrfs**). The root fs (`/`,
`/.snapshots`, `/boot`, `@swap`) is ALWAYS Btrfs. Key invariants:
- **Fixed-order outer carve** right after the ESP and BEFORE the single LINUX
  root partition (order: home, var, cache, srv, opt, games; LINUX last, sized
  to the remainder). With `[ENCRYPT]`, the carved regions become an INNER GPT
  inside the single LUKS2 container.
- **Region subvols are FOLDED out of the flat topology** (`[MULTI-FS-FOLD]`):
  `@home`/`@var`/`@cache`/`@srv`/`@opt` and their owners are removed so no
  subvolume collides with a partition mountpoint.
- **Owned fstab rows skipped** for carved regions (the mounter owns them), and
  the owned `void-subvol-tool` entries are guarded against re-creating a
  carved region's subvolume (`[MULTI-FS-GUARD]`).
- **Region mounts happen before the chroot**; the `Games` region gets its
  `chown`; DOCS-LOG records `DATA_REGIONS`.
- **Rollback-exempt** (not Snapper-managed), never inside `@root`.
- Bare Enter on EVERY region line = all-Btrfs flat layout, byte-identical to
  2.9.37 (no extra partitions, no size prompts).

**2. `[MULTI-FS-RUNLOG]` — journal audit lines.** The region carve and its
mounters are audit-logged to the journal, and on success the journal is
archived to `/etc/void-installer/installer-run.log`.

**3. `[CRASH-USB-LOG]` — crash post-mortem to USB.** On a crash, the journal +
a `.info` sidecar are dumped to the FIRST mounted removable stick. The
`--save-log` CLI flag is parsed BEFORE the journal truncation / network gate
/ STAGE-1 banner, so it works from a crashed, networkless live env. (The
planned-`exit 1` FATAL coverage arrived in Beta-v2.9.39
`[CRASH-USB-LOG-FATAL-EXIT]`.)

**Known limits (documented at the time):** a carved region's roundtrip is
UNPROVEN beyond the bureau-targeting fallback behavior, and the ENCRYPT+region
inner-GPT BROKE boot decryption — ENCRYPT/DECRYPT had worked cleanly before
this release — because dracut could not resolve the partitions inside the
opened LUKS2 container. The decryption fix came AFTER ext4 (the inner-GPT's
introduction), across 2.9.43-2.9.46: `[INNER-PARTSCAN-BOOT]`,
`[DRACUT-CONF-NAME]`, `[INNER-PARTSCAN-DMPROBE]`, and the 2.9.46 post-audit
batch — which together restored boot-time unlock and gave the ENCRYPT+region
layout its real-hardware proof.

---

## Beta-v2.9.12 — `[COSMIC-GREETER-USER]` (greeter account is exactly `cosmic-greeter`; fixes the dead grey screen)

`SCRIPT_VERSION = Beta-v2.9.12`. Root cause of the Beta-v2.9.10/11 open item
("grey wallpaper + cursor, NO login UI") found and **fixed live** on `<host>`
(2026-09-06), then propagated into the installer.

**Root cause.** cosmic-greeter's `src/main.rs` dispatches on the **current
username**:

```rust
"cosmic-greeter" => greeter::main(),   // greetd DM: user list, layer surfaces, greetd IPC
_                  => locker::main(),  // NO main window; waits for an ext-session-lock event, maps nothing
```

The earlier community template shipped `system_accounts="_cosmicgreeter"`,
and the Beta-v2.9.10 `[COSMIC-GREETER-DM]` recipe copied it — so greetd launched
`cosmic-comp cosmic-greeter` under a user that is *not* `cosmic-greeter`, and
the binary silently took the **locker** branch: no windows, no user list, just
the compositor's grey wallpaper + cursor. Every prior theory (AccountsService
population, D-Bus session, XDG_SESSION_TYPE, wayland globals) was a red herring.

**Evidence** (live box, documented in
`Debug/Cosmic-Greeter/triage10-wayland-debug.md`, uncommitted until this
release): `WAYLAND_DEBUG=1` showed the greeter client binding
`xdg_wm_base`/`zwlr_layer_shell_v1`/`ext_session_lock_manager_v1` and creating
**exactly one `wl_surface` that never got a role** (no `get_xdg_surface`, no
`get_layer_surface`, no `get_lock`, no attach, no commit). The session log
carried the `cosmic_greeter::locker` tracing target and the process never
connected to the `GREETD_SOCK` — both fingerprints of the locker branch. The
`cosmic_greeter::common: []` DEBUG line earlier read as "empty user list" was
actually the *keyboard layouts* log (`active_layouts`); real user data DID
arrive via daemon `GetUserData` (the wallpaper update ran) — consistent with a
client that had given up on ever mapping a window.

**Fix.** Renamed the account to exactly `cosmic-greeter`:
`usermod -l cosmic-greeter _cosmicgreeter -d /var/lib/cosmic-greeter` (home
already matched) + group rename + `usermod -aG video,input cosmic-greeter`,
then `sv up` the greetd host stack. The session log switched from
`cosmic_greeter::locker` to `cosmic_greeter::greeter`, Xwayland/the greeter
started drawing its panels, the greeter connected to the greetd socket
(`/run/greetd-*.sock` ESTAB), and the **COSMIC login panel appeared on tty1**.
Greeter-side residual noise (`Failed to apply user display config`, session
directory warnings for absent flatpak/xsession paths, UPower absent) is benign.

**Installer change** (`[COSMIC-GREETER-USER]`): provision the account as
`cosmic-greeter` (not `_cosmicgreeter`) — `useradd ... cosmic-greeter`,
`user = "cosmic-greeter"` in `/etc/greetd/cosmic-greeter.toml`, and
`install -d -o cosmic-greeter -g cosmic-greeter /run/cosmic-greeter` in the
daemon run script; comments updated to document the username dispatch and warn
against reintroducing the underscore variant (the package's `_cosmicgreeter`
system_accounts is the bug, not the answer).

**Validation:** `bash -n` passes; `checks/check-heredocs.sh` — unchanged since
this release touches no heredoc body, only the useradd/toml text outside the
`INNER_EOF` blocks and comments, but rerun to be safe; `checks/check-defaults.sh`
unchanged.

---

## Beta-v2.9.9 — `[MATE-TERMINAL]`+`[MATE-AUDIO]`+`[XFC-VOLUME]`+`[LXQT-EDITOR]` (DE metapackage gaps: terminal, text editor, volume applet)

`SCRIPT_VERSION = Beta-v2.9.9`. Closes the real-hardware gap: a Beta-v2.9.6
MATE install booted to a working desktop but had **no way to open a terminal**
(only a TTY), and no GUI text editor/log reader.

**Root cause.** The MATE branch relied on the claim (in the old comment) that
Void's `mate` metapackage "bundles mate-terminal". An audit of void-packages'
metapackage templates against the common desktop basics (terminal, text
editor, panel volume applet) found three guilty packages:

- `srcpkgs/mate/template`: **no terminal, no text editor, no volume applet**
  (mate-themes / user-guide / backgrounds / icon-theme / menus /
  notification-daemon / polkit / desktop / settings-daemon / session-manager /
  control-center / panel, mate-netbook, caja, marco, elogind, zenity) — the
  same gap class as Cinnamon's missing gnome-terminal/gedit (Beta-v2.9.3-era
  fix), and exactly what TODO/Open Item #1 flagged. A real Beta-v2.9.6 MATE
  install had no way to open a terminal from the desktop.
- `srcpkgs/xfce4/template`: bundles `xfce4-terminal` + `mousepad` (editor) but
  **no panel volume applet** — `xfce4-panel` is built without a pulseaudio
  backend, so a fresh Xfce install has sound but no speaker icon.
- `srcpkgs/lxqt/template`: bundles `qterminal` (and lxqt-panel has a native
  volume plugin) but **no text editor**.

KDE (konsole+kate via kde-baseapps, plasma-pa), GNOME (gnome-console +
gnome-text-editor, in-shell volume), and Cinnamon (already gap-patched) are
clean.

**Changes:**
1. **MATE** now installs `mate-terminal` (terminal), `pluma` (editor, doubles
   as a GUI log reader via File > Open on `/var/log`), and `mate-media` (the
   "Volume Control" panel applet / speaker icon, `[MATE-AUDIO]`).
2. **Xfce** now installs `xfce4-pulseaudio-plugin` (panel volume applet,
   `[XFC-VOLUME]`; pulls `pavucontrol`) alongside `xfce4 network-manager-applet
   gvfs`.
3. **LXQt** now installs `FeatherPad` (Qt6 plain-text editor, `[LXQT-EDITOR]` —
   note the tiled-case package name) alongside `lxqt gvfs`.
4. All additions verified present in Void's official repos (`srcpkgs/mate-terminal`
   1.28.1, `srcpkgs/pluma` 1.28.1, `srcpkgs/mate-media` 1.28.1,
   `srcpkgs/xfce4-pulseaudio-plugin` 0.5.1, `srcpkgs/FeatherPad` 1.6.4).
5. The stale "bundles mate-terminal" comment is corrected to the verified
   dependency reality.

**Validation:** `bash -n` passes.

---

## Beta-v2.9.2 — `[PODMAN-ROOTLESS-SUBVOL]` (rootless podman subvolume parity + gate wording)

`SCRIPT_VERSION = Beta-v2.9.2`. Podman rootless gets the same Gate 1 / Gate 2
subvolume treatment as the browsers — a `PROVISION_PODMAN_ROOTLESS_SUBVOL`
flag now controls whether `@containers-user` (per-user `~/.local/share/containers`)
is isolated on an isolated Btrfs subvolume or left inside `@home`.

**Why this matters.** Prior to this change, rootless podman's per-user datadir
was **always** mounted on `@containers-user` whenever rootless podman was
installed — there was no way to turn it off. This is inconsistent with every
other optional item's subvolume isolation (which is a user choice via Gate 1
for installed software, or Gate 2 for not-yet-installed software). A user
who wanted a lean Btrfs layout without per-app subvols could not decline.

**Installer changes:**
- A new `PROVISION_PODMAN_ROOTLESS_SUBVOL` flag appears in the per-app
  subvolume table (the `SUBVOL_ROWS` loop at the end of the optional-software
  section). It follows the identical 3×3 gate rule as every other row.
- The `@containers-user` line in `SUBVOL_LIST` (Stage 1) is now gated on
  this flag instead of the bare `INSTALL_PODMAN_ROOTLESS`.
- In Stage 2, the essential rootless-podman setup — `~/.local/share`
  ownership fix, subuid/subgid entries, and `containers.conf` — stays
  **unconditional** on `INSTALL_PODMAN_ROOTLESS`, so declining the subvolume
  cannot break rootless podman operation. Only the `@containers-user` fstab
  mount and mountpoint permission are gated on the new flag.
- The flag is exported to both the resume-state file and `chroot_env.sh`,
  so a resumed install and Stage 2 see the same decision.
- The Gate 1 / Gate 2 introductory wording is rephrased to "all of the
  optional software you selected above" (enumerating browsers, mail, Steam,
  VirtualBox, Flatpak, Docker, Podman rootful/rootless, virtualization),
  with a one-line note that OctoXBPS — a lightweight GUI package-manager
  frontend with no dedicated data directory — is not among them. This makes
  the bulk/per-app gates self-consistent: the only optional items lacking a
  subvolume are thinly-scoped ones (OctoXBPS), and the wording no longer
  overpromises that every optional choice gets isolated.

---

## Beta-v2.9.1 — `[GREETER-NO-WEBKIT2]` (remove abandoned WebKit2 greeter option)

`SCRIPT_VERSION = Beta-v2.9.1`. The WebKit2 greeter option
(`lightdm-webkit2-greeter`) is **dropped from the LightDM greeter chooser**
after real-hardware validation confirmed the greeter's failure mode: it
renders a **black screen with blinking cursor** on AMD (and also NVIDIA) with
current `webkit2gtk`, while GTK and Slick greeters boot to desktop on the
same install. Root cause: `lightdm-webkit2-greeter` is an **abandoned upstream
project** (Antergos/web-greeter repo is archived, README marked archived, no
upstream patches since 2021). Newer webkit2gtk versions broke the greeter's
IPC layer (WebKit extensions changed file-descriptor inheritance, per
WebKit/WebKit#4868); `WEBKIT_DISABLE_DMABUF_RENDERER=1` is a known
NVIDIA-only partial workaround, but the core abandoned-IPC breakage is
vendor-independent and has no upstream fix.

The maintained WebKit-based successors (`web-greeter`, `nody-greeter`,
`sea-greeter` by JezerM) are actively developed but are **NOT packaged in
Void's official repositories** — they require third-party templates and
`xbps-src` builds, which is not suitable for a stock-Void installer. GTK and
Slick are the only LightDM greeters that ship reliably in Void's repos.

**Installer changes:**
- LightDM greeter chooser is now `[1/2]` (GTK / Slick); WebKit2 is no longer
  offered (`LIGHTDM_GREETER` can only be `gtk` or `slick`; the `webkit2`
  branch is deleted).
- `lightdm-webkit2-greeter.conf` generation (the `webkit-theme=void` fix) is
  removed — [LIGHTDM-HW] item #2 is annotated as `[GREETER-NO-WEBKIT2] MOOT`.
- The revision echo, greeter-friendly name-case, and all downstream code paths
  that previously matched `lightdm-webkit2-greeter` are cleaned up.
- Header, README, INSTALL_PROMPTS, and AGENTS.md are updated to reflect the
  removal.

The two `[LIGHTDM-HW]` failures (greeter accounts-daemon service, `@lightdm`
chown) remain fully in place — they were real-hardware fixes that apply to
GTK and Slick.

**Investigation documented:** This finding is logged in `Debug/REVIEW.md`
as Entry #2, with the root cause (abandoned upstream IPC) and the
vendor-independent failure (AMD: confirmed; NVIDIA: also affected per
Arch FS#79783).

---

## Beta-v2.9.0 — `[SUBVOL-GATES]` (two master subvolume gates replace scattered prompts)

`SCRIPT_VERSION = Beta-v2.9.0`. The optional-software subvolume pre-provision
surface is re-architected from a pile of per-app prompts behind a `SETUP_APPS`
gate into two **master `y/n/i` gates** asked once, after every `INSTALL_*`
choice is finalized:

- **Gate 1 — `SUBVOL_ISOLATE_INSTALLED`:** for software you ARE installing, give
  each one its own isolated subvolume? Default **YES** (`[Y/n/i]`) — matches the
  previous always-on isolation of installed apps. `i` = walk per-app.
- **Gate 2 — `SUBVOL_PRECREATE`:** for software you did NOT install, pre-create an
  empty isolated subvolume for later manual use? Default **NO** (`[y/N/i]`) —
  matches the old lean `SETUP_APPS` default. `i` = walk per-app.

A **table-driven resolver** then folds each app's `INSTALL_*` choice against the
two gates into a single resolved `PROVISION_*_SUBVOL` flag ("isolate?" =
`true`/`false`). Because installed-app isolation is now a choice, the two gates
remain meaningful (they no longer collapse). **All** downstream sites — the
Stage-1 `SUBVOL_LIST`, `mkdir`/`mount`/`fstab`, the Stage-2 per-user
`provision_browser_subvol` calls (Firefox/Chromium/Vivaldi/Falkon/Brave/
Thunderbird/Steam/VirtualBox), and the teardown umounts for the system datadirs
(Flatpak/Docker/Podman-rootful/Virtualization) — now read **only** the resolved
`PROVISION_*_SUBVOL` flag, never `INSTALL_*` directly, so the two gates are the
single source of truth driving every stage.

- **Removed:** `SETUP_APPS` gate + its per-app pre-create prompts (browsers,
  Thunderbird/Steam/VirtualBox, Flatpak), the mid-flow Docker/Podman/Virtualization
  pre-create prompts, and the now-obsolete `DEFAULT_SETUP_APPS` /
  `DEFAULT_PROVISION_*_SUBVOL` defaults (`[APPS-GROUP]` / `[SUBVOL-PRE-SYS]`
  subsumed). Each `PROVISION_*_SUBVOL` is computed by the resolver.
- **Implementation notes (hard-won):** the resolver table uses a **pipe
  (`|`) separator** parsed with `IFS='|'` so a label may contain a space
  (`Podman (rootful)`) without `read` field-splitting corrupting the row; and
  `_subvol_ask` emits its prompt to **stderr** (`ask ... >&2`) so the prompt text
  is not captured by the `$( _subvol_ask ... )` command substitution that holds
  the resolved value. Both verified against the 3×3 gate×install matrix in a
  `Debug/`-style offline harness.
- The two gate vars are wired into the resume-state export list and
  `chroot_env.sh`; `bash -n`, `check-defaults.sh`, and `check-heredocs.sh` all
  pass.

---

## Beta-v2.8.3 — `[INSTALL-APPS]` (Thunderbird/Steam installable) + PostgreSQL/MariaDB removed

`SCRIPT_VERSION = Beta-v2.8.3`. Two changes to the optional-software surface:

- **`[INSTALL-APPS]` — Thunderbird & Steam become real install-time choices.**
  Previously these existed only as pre-create-only `PROVISION_*` subvolume
  toggles (the installer never installed them). Now, choosing to install each
  one adds the package (`thunderbird` / `steam`), and its per-user isolated
  subvol (`@thunderbird` at `~/.thunderbird`, `@steam` at
  `~/.local/share/Steam`) is created/mounted in the same browser-install style.
  Both are lean-default OFF (`[OPT-DEFAULTS]` — bare-Enter declines), matching
  containers/virtualization. The Stage-1 `SUBVOL_LIST` and Stage-2
  `provision_browser_subvol` gating now fire on `INSTALL_*` **or** the
  `PROVISION_*` pre-create flag, so an installed app and a pre-created
  subvolume are never double-counted and a pre-created-empty dir still gets
  the isolation when the app is added manually later.
- **PostgreSQL & MariaDB removed from the installer entirely.** Their install
  prompts (never shipped), the `PROVISION_DB_SUBVOLS` pre-create toggle +
  prompt, and all @postgresql/@mariadb Stage-1/Stage-2 wiring (SUBVOL_LIST,
  mkdir, mount, fstab, teardown umounts) are gone. The installer no longer
  provisions, mounts, or fstabs those datadirs. The shipped post-install
  maintenance tool (`/root/tools/void-subvol-tool.sh`, with its `databases`
  class) is **deliberately left intact** so a user can still build those
  subvolumes manually — removal is installer-scope only.
- **New defaults wired into `[PROMPT-DEFAULTS]`:** `DEFAULT_THUNDERBIRD`,
  `DEFAULT_STEAM` (both `false`); the obsolete `DEFAULT_PROVISION_DB_SUBVOLS`
  is removed.
- **Validation:** `bash -n`, `checks/check-defaults.sh` (ALL CONSISTENT), and
  `checks/check-heredocs.sh` (48 heredocs, ALL CLEAN) all pass.

---

## Beta-v2.8.2 — `[APPS-GROUP]` / `[SUBVOL-PRE-SYS]` (optional-software subvol pre-provisioning)

First post-re-base functional release (`SCRIPT_VERSION = Beta-v2.8.2`). Improves
the optional-software subvolume pre-provisioning:

- **`[APPS-GROUP]` (Fix 1a)** — the app subvolume prompts (Thunderbird / Steam /
  VirtualBox / PostgreSQL-MariaDB) are now wrapped behind a single
  `SETUP_APPS` category gate, mirroring the existing `[BROWSER-GROUP]` /
  `[CONTAINER-GROUP]` gates. All component defaults are OFF, so `SETUP_APPS`
  defaults OFF (`[OPT-DEFAULTS]` lean posture) — a bare-Enter run skips the
  whole section instead of walking every app prompt. Selecting "no" forces all
  contained `PROVISION_*` toggles off (exported, so `SUBVOL_LIST` /
  Stage-1 / Stage-2 gating stays correct); selecting "yes" walks the individual
  prompts as before.
- **`[SUBVOL-PRE-SYS]` (Fix 3)** — extends the same pre-provision pattern to
  the system-level `@datadir` subvolumes, but ONLY when that software is NOT
  being installed (the installed case already creates/mounts/fstabs them via
  its `INSTALL_*` branch):
  - `PROVISION_FLATPAK_SUBVOL` → `@flatpak` (`/var/lib/flatpak`)
  - `PROVISION_DOCKER_SUBVOL` → `@docker` (`/var/lib/docker`)
  - `PROVISION_PODMAN_SUBVOL` → `@containers` (`/var/lib/containers`)
  - `PROVISION_VIRT_SUBVOL` → `@libvirt` (`/var/lib/libvirt`, nodatacow)
  
  This lets a lean base system later adopt Flatpak / Docker / Podman-rootful /
  libvirt without that software's churn/state ever mixing back into `@`.
  These follow the `[PROVISION_DB_SUBVOLS]` pattern (Stage-1 `SUBVOL_LIST` +
  mkdir/mount/fstab at system paths, plus teardown umounts), not the per-user
  `provision_browser_subvol` helper, because they live under `/var/lib`.
  Prompt ordering: Flatpak is asked inside the `SETUP_APPS` block (its
  `INSTALL_FLATPAK` is already finalized), while the Docker / Podman-rootful /
  Virtualization prompts appear right after their own `INSTALL_*` prompts so
  the `!= "true"` guard compares against the user's real container/virt
  choice instead of an empty var (avoiding a spurious double-ask).
- **New defaults wired into `[PROMPT-DEFAULTS]`** for every new toggle:
  `DEFAULT_SETUP_APPS`, `DEFAULT_PROVISION_FLATPAK_SUBVOL`,
  `DEFAULT_PROVISION_DOCKER_SUBVOL`, `DEFAULT_PROVISION_PODMAN_SUBVOL`,
  `DEFAULT_PROVISION_VIRT_SUBVOL`.
- **ARCHITECTURE SUMMARY** header note updated; version-history table gains a
  `Beta-v2.8.2` row.
- **Validation:** `bash -n`, `checks/check-defaults.sh` (ALL CONSISTENT — 42
  `DEFAULT_*`), and `checks/check-heredocs.sh` (48 heredocs, ALL CLEAN) all pass.

---

## Beta-v2.8.2 — Alpha-v/Beta-v era re-basing (`[VERSION-CARRY]`)

Numbering-scheme release (documentation + `SCRIPT_VERSION` change; no
behavior change). The full project lineage is now expressed as named eras
under the `[VERSION-CARRY]` scheme:
- **Alpha era** (`Alpha-v1.0.1–v1.0.4`): reconstructed from the manual step
  scripts in `Debug/Old Versions/`.
- **Beta era** (`Beta-v1.0.0` → `Beta-v2.8.2`): the unified installer lineage,
  pre-tracking artifacts mapped into `Beta-v1.x`/`Beta-v2.x` per the
  author's mapping (`Debug/version-renumber-map.txt`), and tracked releases
  (`v3.1.0-beta1` … `v3.3.0-beta33`) renumbered as `Beta-v2.3.0` …
  `Beta-v2.8.1`. Every release within
  the Beta era gets a unique number, and the current release is always the
  highest — preserving the monotonicity invariant.

- **`[VERSION-CARRY]`** — `SCRIPT_VERSION` changes from `3.3.0-beta33` to
  `Beta-v2.8.1` (this entry, `Beta-v2.8.2`, represents the re-base event
  itself). README / INSTALL_PROMPTS / changelog "Current version" line all
  updated. The header `[VERSION-HISTORY]` table is fully rewritten in the
  new era scheme.
- **Tracked-era history renumbered** — all `v3.x` changelog headings retitled
  to `Beta-v2.x` with the old label preserved as a cross-ref
  (e.g. `## Beta-v2.8.1`). The full mapping lives in
  `Debug/version-renumber-map.txt` and in the script's `[VERSION-HISTORY]`
  table. Pre-Big-Pickle carry-rule renumberings (e.g. `3.0.98→3.9.8`,
  `3.0.112→3.11.2`) are preserved in the pre-BP section notes for reference.
- **Exclusions honored:** `OxAlpha` fork + failed `4.0.0-SUSE` nested build
  remain documented dead ends, not part of the installed lineage.
- **Validation:** `bash -n`, `checks/check-defaults.sh` (ALL CONSISTENT),
  and `checks/check-heredocs.sh` (ALL CLEAN) all pass.

---

## Beta-v2.8.1 — recovered lineage documentation (`[VERSION-HISTORY]`)

Documentation/source-trace release. The earlier `"Pre-3.1.0 heritage
(alpha) — RECONSTRUCTED (educated estimate)"` section was **replaced with a
detailed lineage recovered from the actual build artifacts under
`Debug/Old Versions/`**, so the full history from the first Alpha concept to
v3.1.0-beta1 is now sourced from real files (their filenames + inline
`AI CHANGE TRACKING:` comments) instead of an estimate. The recovered
pre-3.1.0 era is presented as a **continuous, version-numbered history from
Alpha 1 through the current version** — real archived releases are documented
as-is; gaps between them are `[reconstructed]` extrapolations (marked inline)
assigned version numbers for narrative continuity.

- **`[VERSION-HISTORY]`** — the installer header now carries a canonical
  version-history table immediately after `SCRIPT_VERSION` (git-visible and
  self-documenting), mapping every pre-3.1.0 filename-versioned release AND
  every v3.1.0+ inline-marker release. The script's *behavior* is unchanged —
  this is entirely a documentation addition — but both the recovered lineage
  and the future bump ritual now have one in-file reference.
- **Changelog rewrite** of the pre-3.1.0 section as a continuous versioned
  series (version-numbered rather than "phases"):
  - **v0.1.0 — Alpha 1** (recovery-first foundation: swapfile hibernation,
    Snapper timeline + dracut overlay, runit, flat topology).
  - **v0.2.0 — Alpha 2** (desktop + recovery maturity: GRUB + grub-btrfs, KDE
    Plasma, PipeWire/WirePlumber, NetworkManager `br0`, `@grub`/var subvols).
  - **v0.3.0 — Alpha 3** (breadth: QEMU/KVM/libvirt on `br0`, optional-software
    menu, browser subvols, the `[item N]` work-item system).
  - **v0.4.0 — Alpha 4** (the manual `Alpha`/`boot.efi ScriptN-N` multi-script
    era; `Script4-4`'s systemd Path/Monitor is a documented dead end the
    runit-only mandate dropped).
  - **v1.0.0–v1.9.5** (unified single-file "Test it Out" drafts: 2.1–2.9.5C,
    first consolidation + nftables firewall).
  - **v2.9.7C → v2.9.8GC → v2.9.9GC → v2.9.9.1GC** (formally versioned
    single file: nftables interface pinning, repo fallback, interactive config
    loop, QEMU setuid, NM connection blueprints).
  - **v3.0.0 → v3.0.8GC** (GRUB-only; tmpfs snapshot-runtime, FQDN/domain
    prompt, `@usercache` chown-before-mount + noauto gate, `/tmp` tmpfs, SDDM
    conf-sourced delay).
  - **v3.0.9GC → v3.0.112GC** (per `.../Latest/Notes.txt`: `3.0.9GC` base,
    `3.0.95/96/97GC` Claude attempts, `3.1.0-FLAT-INTERCEPT` + failed
    `4.0.0-SUSE`; then the clean `3.0.98→3.0.112GC` feature surface: custom
    `95snapshot-overlay` dracut module, sequential repo fallback,
    baseline-snapshot ordering, chown-before-mount, `@chromium`,
    PipeWire snapshot-autostart, sysfs NIC detection, Flatpak/Docker/Podman/
    `/root` subvol isolation, account privilege model, dynamic subvol/group
    lists, distrobox + OctoXBPS). `[reconstructed]` bridge releases are marked.
- **Continuous framing** — a **Version index (Alpha 1 → current)** table at the
  top of this file now maps the whole lineage at a glance, so the changelog
  reads as one continuous history instead of separate "tracked" and
  "heritage" halves. Everything from v3.1.0-beta1 onward remains authoritative
  and unchanged.
- **Exclusions honored:** the mangled **`OxAlpha`** fork (the
  `.../Latest/Latest/OxAlpha/` copies, e.g. `3.0.112GC`/`3.1.0-beta1`
  OxAlpha snapshots and `3.0.114.sh`) is **excluded** — it was a corrupted/dead
  fork of no bearing on the current script. Only the clean pre-OxAlpha
  versions (the standalone `Latest/.../*.sh` files, which carry no `OxAlpha`
  reference) are used. The openSUSE-nested `4.0.0-SUSE` build (which Notes.txt
  records as "Failed to boot") is likewise documented as a dead end, not part
  of the current flat layout.
- **Validation:** `bash -n`, `checks/check-defaults.sh` (37 defaults, ALL
  CONSISTENT), and `checks/check-heredocs.sh` (48 heredocs, ALL CLEAN) all
  pass; no runtime behavior changed.

---

## Beta-v2.8.0 — Cinnamon default wallpaper + portable nftables (`[CINNAMON-WALLPAPER]`, `[NFT-TTL-REMOVED]`)

A fresh Cinnamon install booted to a solid black screen with no wallpaper.
Cinnamon ships no wallpaper images of its own (Mint's `mint-backgrounds-*`
doesn't exist on Void), and while the installer already installed
`gnome-backgrounds` so images exist in the picker, it never programmatically
set a default — Cinnamon's compiled-in `picture-uri` pointed to a
non-existent Mint path.

- **`[CINNAMON-WALLPAPER]`** — after installing `gnome-backgrounds`, the
  installer now prefers `adwaita-l` (the GNOME default light image) and
  writes it into the system-wide dconf database (`/etc/dconf/db/local.d/`) as
  `picture-uri` with `picture-options='zoom'`, falling back to the first
  available image only if `adwaita-l` is absent. Every new user boots to a
  visible wallpaper instead of black; the user can still change it via
  Settings > Background. (`adwaita-l` is preferred over "first available"
  because filesystem-order first-match turned out to be `vnc-l.png` — the
  near-empty "plain color for remote access" image.)

- **`[NFT-TTL-REMOVED]`** — removed the two `table ip mangle` /
  `table ip6 mangle` blocks that `/etc/nftables.conf` used to write. They
  carried a per-machine TTL/hoplimit workaround tied to specific interface
  names — non-portable cruft that matched nothing on any other target. The
  drop-by-default filter firewall (loopback, established/related,
  rate-limited ping, and `br0`/`virbr*` KVM forwards) is kept.

---

## Beta-v2.7.9 — guard Limine tools backup for GRUB installs (`[TOOLS-LIMINE-GUARD]`)

A GRUB install with encryption + LightDM/Slick failed at the very end of
Stage 2 because the `/root/tools` backup block unconditionally tried to
`cp` the three Limine engine helpers (`void-limine-env.inc`,
`void-limine-sync-kernels`, `void-limine-write-conf`) from
`/usr/local/sbin/` — which are only created inside the Limine `else`
branch. On a GRUB box those files never exist, so the `cp` (under the
chroot's `set -e`) hit `ENOENT` and killed the install.

- **`[TOOLS-LIMINE-GUARD]`** — the three `cp` + `chmod` calls that back
  up the Limine engine helpers into `/root/tools/` are now wrapped in
  `if [ "$BOOTLOADER" = "limine" ]`. GRUB installs skip the block
  cleanly; the `/root/tools` directory still gets the xbps-snap backup,
  `re-shadow-xbps.sh`, `limine-sync.sh` (which self-detects GRUB and
  exits early), and `re-provision-snapper.sh`.

The `systemctl enable --now snapper-timeline.timer` warning visible in
the boot log is snapper's own post-install script (not the installer)
attempting a systemd command on a runit host — non-fatal, cosmetic, and
already present before this fix.

---

## Beta-v2.7.8 — chown the Documents dir the install record lives in (`[DOCS-LOG-CHOWN]`)

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

## Beta-v2.7.7 — fix Slick greeter session name (`[LIGHTDM-GREETER-SESSION]`)

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

## Beta-v2.7.6 — installed-package capture in the install record (`[PKG-LIST]`)

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
- **Validation:** `bash -n`, `checks/check-defaults.sh` (ALL CONSISTENT), and
  `checks/check-heredocs.sh` (46 heredocs, ALL CLEAN) all pass; the `sed`
  normalization pipeline verified against a simulated `xbps-query -l` output.

---

## Beta-v2.7.5 — install-prompt flow reorder (`[FLOW-ORDER]`)

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
- **Validation:** `bash -n`, `checks/check-defaults.sh` (ALL CONSISTENT), and
  `checks/check-heredocs.sh` (46 heredocs, ALL CLEAN) all pass after the reorder.

---

## Beta-v2.7.4 — optional-software category gates (`[BROWSER-GROUP]` `[CONTAINER-GROUP]`)

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
- **Validation:** `bash -n`, `checks/check-defaults.sh` (both new defaults declared +
  referenced), and `checks/check-heredocs.sh` (46 heredocs) all pass.

---

## Beta-v2.7.3 — post-install subvolume tool (`void-subvol-tool.sh`, `[SUBVOL-TOOL]`)

Adds a post-install Btrfs subvolume manager to `/root/tools`, letting an admin
add / inspect / detach / destroy an additional **flat** sibling subvolume at
runtime — the same topology the installer's stage-1 `SUBVOL_LIST`/mount/fstab
lock-step produces, but reached for later on a running box.

- **New tool:** `/root/tools/void-subvol-tool.sh`, rewritten as a quoted
  heredoc (so `checks/check-heredocs.sh` extracts + `bash -n`/shellchecks it),
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
- **Validation:** `bash -n`, `checks/check-defaults.sh` (no new `DEFAULT_*`, still
  all consistent), and `checks/check-heredocs.sh` (46 heredocs; the 403-line tool
  is `bash -n` clean + shellcheck-clean) all pass.

---

## Beta-v2.7.2 — editable default answers (`[PROMPT-DEFAULTS]`)

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
- **Dev gate:** `checks/check-defaults.sh` (committed) is a reproducible check
  that every declared `DEFAULT_*` is actually wired to a prompt and every
  referenced `DEFAULT_*` is declared — run it after touching the prompt/defaults
  surface (see AGENTS.md → Validation).

---

## Beta-v2.7.1 — configurable LUKS mapper name (`[CRYPT-NAME]`)

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

## Beta-v2.7.0 — encrypted unlock newline fix (`[ENCRYPT-NEWLINE]`)

Discovered from a fresh real-hardware install that unlocked with the installer
but **refused to unlock at boot or via a manual recovery** open ("No key
available with this passphrase"), even though the passphrase was a US-layout,
digits-only numeric passphrase.

**Root cause (byte-level):** every LUKS call fed the passphrase through a
`<<<` here-string (or `echo`), e.g.
`cryptsetup luksOpen --key-file=- "$PART_SYS" void-root <<<"$ENCRYPT_PASSPHRASE"`.
`<<<` and `echo` append a **trailing newline byte**, so the LUKS keyslot stored
`passphrase\n` (11 bytes for a 10-digit numeric passphrase). The beta21 `[ENCRYPT-VERIFY]`
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

## Beta-v2.6.9 — encrypted-boot hardening (`[ENCRYPT-KEYMAP]` + `[ENCRYPT-VERIFY]`)

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

## Beta-v2.6.8 — self-contained Limine rebuild kit (`[TOOLS-LIMINE-BACKUP]`)

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

## Beta-v2.6.7 — self-healing xbps shadow (`[RESHADOW-BOOT]`)

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

## Beta-v2.6.6 — persistent maintenance/tools folder (`[TOOLS-DIR]`)

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
- **Validation:** static gates (`bash -n`, `checks/check-heredocs.sh` 45/45,
  all tools + README clean). Not yet exercised on real hardware —
  verify each wrapper one has its documented use-case on the target medium.

---

## Beta-v2.6.5 — automatic updates: shadow `xbps-install` (`[PKG-SNAPSHOT-AUTO]`)

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
- **Validation:** static gates (`bash -n`, `checks/check-heredocs.sh` 41/41,
  wrapper shellcheck-clean) plus sandbox tests of both resolution modes and the
  recursion guard. Still apply the real-hardware note from beta16: verify a
  live `sudo xbps-install -Su` pair once (done on this box for the standalone
  path in beta16; the shadow path is the same script but validate a pair after
  an `xbps` self-update to confirm re-shadowing).

---

## Beta-v2.6.4 — pre/post snapshots around system updates (`[PKG-SNAPSHOT]`)

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
  `checks/check-heredocs.sh`). The pre/post wrapper has not been exercised on
  real hardware yet — verify on the target medium with a sample
  `sudo void-xbps-snap -Su` and confirm the pair appears in the snapshot boot
  menu.

---

## Beta-v2.6.3 — user full-name prompt (`[FULLNAME]`)

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

## Beta-v2.6.2 — GRUB+encryption now boots: public `/boot` on the ESP (`[GRUB-ESP-BOOT]`)

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
- **Validation status:** static gates pass (`bash -n`, `checks/check-heredocs.sh`
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

## Beta-v2.6.1 — extended subvolume topology (`[SUBVOLS]`)

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

## Beta-v2.6.0 — Limine is the default bootloader (`[LIMINE-DEFAULT]`, `[ENCRYPT-ORDER]`)

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

## Beta-v2.5.9 — drop the shadowed `@tmp` subvolume (`[DROP-@TMP]`)

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

## Beta-v2.5.8 — YubiKey keyscript value-bake fix (`[YK-KEYSCRIPT-BAKE]`)

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

## Beta-v2.5.7 — first-boot virtualization wait fix (`[RCL-VIRT-WAIT]`)

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

## Beta-v2.5.6 — cron safety-net removal (`[SNPR-EV-NO-CRON]`)

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

## Beta-v2.5.5 — optional LUKS2 full-disk encryption

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

## Beta-v2.5.4 — optional YubiKey hmac-sha1 unlock

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

## Beta-v2.5.3 — monthly btrfs integrity scrub

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

## Beta-v2.5.2 — event-driven Limine snapshot-menu sync

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

## Beta-v2.5.1 — bug-fix point release on top of 3.3.0-beta2

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

## Beta-v2.5.0 — LightDM greeter fixes from a real-hardware install

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

## Beta-v2.4.1 — Regional official repo mirror selection

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

## Beta-v2.4.0 — Localization, swap/zram/hibernation, COSMIC, session/seat

### Real install-time choice: Desktop Environments (`DESKTOP_ENV`)
- KDE Plasma (default, primary tested path), Cinnamon, GNOME, Xfce, MATE,
  LXQt, and **COSMIC**.
- COSMIC is NOT in the official Void repos:
  - `[COSMIC]` — installed from a third-party community repo maintained by an
    upstream packager, pinned to that
    upstream host.
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

## Beta-v2.3.0

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

## Pre-Big-Pickle heritage — CONTINUOUS versioned history (Alpha 1 → Beta-v2.2.8)

> The inline `AI (...)` markers and the current header architecture summary
> document changes from **v3.1.0-beta1** onward, where this changelog's
> tracking is authoritative. Everything below v3.1.0-beta1 is a **continuous,
> version-numbered reconstruction** of the project's early life, recovered and
> extrapolated from the actual build artifacts archived under
> `Debug/Old Versions/` (the `Alpha ScriptN-N.sh` manual step files, the
> `boot.efi .../` tree, and the `Claude/` folder). Their filenames and inline
> `AI CHANGE TRACKING:` comments are the anchors; any release between two real
> artifacts that has no surviving file is **extrapolated** (clearly marked
> `[reconstructed]`) to make the history read continuously. Version numbers
> for the pre-tracking era are assigned by this reconstruction for narrative
> continuity and do not necessarily match an archived filename.
>
> Where the current script still cites lost companions (§3.19, §3.24, §4.7,
> §4.8, §4.9, §4.10, §4.13, §4.15, Open Items #1/#2/#5d/#6/#7), those
> references are preserved verbatim.
>
> **Excluded lineage:** the mangled `OxAlpha` snapshots (the
> `boot.efi .../2.9.7C/Latest/Latest/Latest/Latest/OxAlpha/` subtree, e.g. the
> `3.0.112GC`/`3.1.0-beta1` OxAlpha copies and their `3.0.114.sh`). Those were
> a corrupted/dead fork of no bearing on the current script; nothing below
> draws on them. The openSUSE-nested `4.0.0-SUSE` build (which `Notes.txt`
> records as "Failed to boot") is likewise a documented dead end, not part of
> the current flat layout.
>
> **Renumbering note (`[VERSION-CARRY]`):** the surviving pre-Big-Pickle
> artifacts carry their **real archived filenames** (e.g. `3.0.98GC`,
> `3.0.112GC`) throughout this section. Under the carry rule those map to the
> renumbered forms documented in the version index and the
> `v3.12.0` entry (`3.0.98GC→3.9.8`, `3.0.112GC→3.11.2`, etc.) so the history
> reads monotonic with the re-based Big-Pickle era.

### v0.1.0 — Alpha 1: the recovery-first foundation (`[reconstructed]`)
The project's origin: a single-disk, GPT, UEFI-only Void Linux installer that
runs wholly from the Live CD outer terminal. The core thesis was **recovery**,
not just install:
- Hibernation via a single physical BTRFS-native swapfile (resume offset
  computed with `btrfs inspect-internal map-swapfile -r`), injected into the
  kernel command line plus dracut's resume module.
- **Snapper** timeline snapshots + a **dracut overlay** so a snapshot boot is
  read-only with a writable RAM overlay (never mutates the snapshot).
- Flat Btrfs topology (top-level sibling subvolumes, not nested) so each is
  independently snapshot-able/rollback-able; `runit` (systemd-free).
- Interactive disk selection, account/password hashing, hostname in-chroot.
- First-boot `rc.local` provisioning.

### v0.2.0 — Alpha 2: desktop & recovery maturity
- **GRUB** bootloader with a grub-btrfs snapshot boot menu (dynamic, kernel
  hook regenerated; 1 GiB ESP) — the mature path that would carry through 3.0.x.
- KDE Plasma desktop (the original primary desktop path) via SDDM.
- PipeWire + WirePlumber audio with robust XDG rules; NetworkManager with a
  custom `br0` bridge profile.
- The first `@grub` / `/boot/grub` and var/lib subvolume/fstab refinements.

### v0.3.0 — Alpha 3: breadth
- QEMU/KVM + libvirt virtualization on `br0` (virbr0 NAT explicitly disabled).
- Optional-stack menu: Firefox, Chromium, Vivaldi, Falkon, Brave, Flatpak,
  Docker, Podman (rootless/rootful), Distrobox, octoxbps, virt.
- Browser profile/cache subvols (`@mozilla`, `@mozilla-cache`, `@chromium`, …)
  with a collector; per-subvol `nodatacow`/`compress=none`.
- The numbered `[item N]` work-item system (the §3.x/§4.x reference scheme
  still cited in the current script).

### v0.4.0 — Alpha 4: the manual multi-script era (`Alpha` + `boot.efi ScriptN-N`)
Before any unified installer, the workflow was split into standalone,
copy-paste step scripts run by hand. They still use `systemctl`/`systemd`
units, so only their *concepts* carry forward — never the systemd mechanics:
- **`Script1-3.sh`** — the foundational GPT + Btrfs layout: `sgdisk` wipe +
  GPT, an **ESP (1 GiB, FAT32)** and a single **Btrfs root**, with a set of
  top-level subvolumes (`@`, `@root`, `@home`, `@opt`, `@srv`, `@xbps`,
  `@sddm`, `@plasmalogin`, `@libvirt`, `@log`, `@spool`, `@tmp`, `@swap`) and
  a noatime + `compress=zstd:1` mount recipe — the origin of the
  flat-topology + per-subvol `nodatacow` discipline.
- **`Script2-3.sh`** — base-system configuration: hostname + `/etc/hosts`,
  timezone symlink, locales, root/user accounts (`useradd -m -G wheel,adm`),
  nonfree/multilib repos, firmware/ucode, KDE Plasma 6 + SDDM +
  NetworkManager, runit service symlinks.
- **`Script3-4.sh`** — recovery maturity: a `~/.mozilla` subvolume (seed of
  the browser-isolation model), Snapper timeline configs for `@`/`@home`, and
  GRUB-Btrfs snapshot-menu plumbing via a post-transaction xbps core-hook and
  `/etc/snapper/snapper-hook.sh` — the direct ancestor of today's
  `00-void-limine-snapper-sync` trigger (then systemd/update-driven).
- **`Script4-4.sh`** — a pure **systemd** `grub-btrfs.path`/`.service` path
  monitor (watching `/.snapshots`). Deliberately **dropped** when the project
  went runit-only; survives only as context for why later 3.0.x builds had to
  hand-roll boot-menu regeneration instead of a systemd path unit.

### v1.0.0 → v1.9.5 — the unified single-file "Test it Out" drafts
The "Test it Out" tree and `corrected nftables/Testing` folder hold the first
lean, single-file installers (2.1, 2.2, … 2.7, 2_7.xC, 2.8C, 2_9C, 2_9.5C),
still labeled `UNIFIED VOID LINUX ADVANCED RECOVERY INSTALLER`. They
consolidate the multi-script steps into one installer and add the
**nftables no-default-drop firewall** (an "8GCfix-nftables" iteration lives
beside them). `[reconstructed]` detail built from the surviving drafts:
- **v1.0.0 (`2.1`)** — first consolidation: GPT/Btrfs layout + chroot steps + a
  br0 bridge + zram-less swapfile, runit links.
- **v1.2.0 (`2.3`)** — modularizing the base-system + desktop install; adding
  the nonfree/multilib repo set and firmware.
- **v1.5.0 (`2.7`)** — the split into multi-part staged drafts
  ("BOX 1 OF 3") so each phase could be run and debugged independently.
- **v1.7.0 (`2_7.xC`)** — nftables firewall rules appear; encryption of network
  rules per host.
- **v1.9.0 (`2_9C` / `2_9.5C`)** — the `2.9` baseline consolidates the staged
  boxes back toward a single versioned installer, carrying the nftables rules
  and the browser/cache subvol ideas forward.

### v2.9.7C → v2.9.9.1GC — the formally versioned 2.9.x lineage
The installer becomes a strictly versioned, self-documenting single file
(`SECTION 1 OF …` / `BOX 1 OF …`).
- **`2.9.7C`** — first compact versioned build. Notable content: the 8GC-fix
  **nftables** rules with an interface-TTL/hoplimit workaround keyed to the
  NIC (`oifname "usb*"/"*u*"` etc.), the browser/`@usercache`-isolation idea,
  and a hardcoded `/dev/nvme0n1` target.
- **`2.9.8GC`** — the nftables TTL/hoplimit rules are pinned to **two
  concrete interface globs** (`enp5s0f*` and `enx*`) instead of the broad USB
  catch-all — the first step toward the later `[NFT-TTL-REMOVED]` rework that
  finally dropped these per-machine rules.
- **`2.9.9GC`** — the repo fallback swap (PRIMARY/BACKUP1/BACKUP2 from
  `mirrors.summithq.com`/`repo-fastly`/`repo-default`), switches the PipeWire
  pulse-compat symlink to the **wireplumber** example path, and adds a
  grub-btrfs `41_snapshots-btrfs` fallback-hook recovery in failure cleanup.
- **`2.9.9.1GC`** — the transition to a **dynamic configuration pass**: an
  interactive variables loop for NIC/hostname detection, TARGET_HOSTNAME now
  drives the host-generation nodes, QEMU bridge-helper **setuid** hardening,
  the unquoted `kde-wayland.conf` **autologin heredoc dropped** (secure SDDM
  prompt), and NetworkManager **connection-profile blueprints** replace the
  race-prone rc.local bridge scripting.

### v3.0.0 → v3.0.8 — the mature GRUB-only 3.0.x "GC" line
Repartitioned into the mature GRUB-only form; point releases refine the surface.
- **`3.0.0GC` → `3.0.2GC`** — the bootloader/`@grub` subvolume decision, the
  display-manager + volatile-runtime **tmpfs** re-routing ("mimic openSUSE":
  write-heavy runtime zones live on rapid tmpfs so a read-only snapshot boot
  isn't blocked), QEMU setuid hardening, the SDDM autologin drop, the
  NetworkManager br0 blueprints + `br0-slave` profile, and a fix making the
  swapfile `TARGET_OFFSET` computation a proper `if/fi` (it was a mangled
  single line in 3.0.0GC). 3.0.2 adds the "configuration drop-in delay" for the
  runit SDDM service and the gated `/usr/libexec/qemu-bridge-helper`.
- **`3.0.4GC`** — interactive **domain-name prompt** right after the hostname
  (proper FQDN), the **br0 slave glob no longer prompted** (hardcoded `enp*`),
  the gated @usercache mount, and a corrected SDDM delay location.
- **`3.0.5GC`** — an FQDN **confirmation step**, a per-boot @usercache gate,
  and the "Real every-boot counterpart to the fstab `noauto` entry" rc.local
  conditional mount (foundational — the seed of today's `[PERSONAL-DATA]`
  ownership invariant).
- **`3.0.6GC`** — structurally near-identical to 3.0.5; a tweak release.
- **`3.0.7GC`** — **sequential repo fallback** replaces the broken single
  combined `-R -R -R` call (one full bootstrap attempt per repo, advancing
  only on a nonzero exit — the ancestor of today's mirror-failover).
- **`3.0.8GC`** — snapshot-boot performance/correctness: the nested `@sddm`
  double-tmpfs mount **collapsed into one line** (the old second entry crashed
  mount -a), **`/tmp` given its own tmpfs** (a read-only snapshot root had
  broken Xorg's `.X1-lock`), the Dracut-overlay audio fallback corrected to a
  `/proc/cmdline` wrapper, the fstab `@usercache` `noauto` + real rc.local gate
  (fstab cannot hold shell conditionals), and the SDDM drop-in delay written to
  a plain **`conf` file the stock run script actually sources** (a prior
  `conf.d/` location was silent dead code).

### v3.0.9 → v3.0.112 — the feature-rich capstone carpet
The runtime notes (`.../Latest/Latest/Notes.txt`) record: **3.0.9GC** is the
**base file**, **3.0.95/96/97GC** are the "base + Claude attempt" builds
(96 "failed to boot", 97 "untested"), and **3.1.0GC** (tagged
`3.1.0-FLAT-INTERCEPT`) and the `4.0.0/4.0.1-SUSE` builds are the flat +
Dracut-intercept vs the openSUSE-nested experiments. The clean
`3.0.98GC → 3.0.112GC` series is the capstone; each carries `SCRIPT_VERSION` +
`AI CHANGE TRACKING`. (`3.0.9GC` base and the `3.0.95–3.0.97GC` attempts are
real archived artifacts; the intermediate gaps between 3.0.9 and 3.0.98 are
`[reconstructed]` as continuous point releases.)
- **`3.0.9GC`** — the base file: the full GRUB flat layout with the 2.9.x-era
  NIC/nftables + br0 wiring consolidated and SCRIPT_VERSION introduced.
- **`3.0.95GC`–`3.0.97GC`** — the "base + Claude attempt" rebuilds; 96 failed
  to boot, 97 untested. `[reconstructed]` — these reflect a parallel attempt
  to rewrite the install pipeline that was not carried forward intact.
- **`3.0.98GC`** — the big architecture release: the **custom
  `95snapshot-overlay` dracut module** replaces stock `overlayfs` (which hooks
  at pre-mount before the installed root is populated — producing the exact
  `Cannot find init!` crash; the custom module hooks at **pre-pivot** after the
  read-only snapshot is genuinely mounted and builds a writable tmpfs top).
  Also: sequential repo fallback **factored into a reusable function** for
  every chroot `xbps-install`, the `/tmp` + SDDM tmpfs fixes, the audio
  `/proc/cmdline` wrapper, and the `@usercache` chown/`noauto` + rc.local gate.
- **`3.0.99GC`** — the **baseline snapshot moved** to run after the dracut
  regen loop so the initramfs frozen into it already has the snapshot-overlay
  module (grub-btrfs's `41_snapshots-btrfs` hook is disabled/re-enabled around
  the create to avoid a scan-of-nothing race).
- **`3.0.100GC`** — **chown the bare placeholder directory BEFORE the
  `@usercache` mount** (the old mount-then-chown left a root-owned placeholder
  exposed on snapshot boots — Firefox/Mesa hit `Permission denied` on
  `~/.cache`). The canonical form of the chown-before-mount ordering that
  still governs every `provision_*_subvol`.
- **`3.0.101GC`** — **Chromium gets `@chromium`** — the same isolated-subvolume
  treatment as Firefox (profile isolation, `nodatacow` sqlite churn,
  chown-before-mount).
- **`3.0.102GC`** — **PipeWire snapshot-autostart is now a real install-time
  choice** (`[y/N]`, default off) — the seed of today's
  `DEFAULT_SNAPSHOT_AUDIO`/`[SNAPSHOT-AUDIO]`.
- **`3.0.103GC`** — **tiered NIC detection**: tier 1 = a wired `en*`/`eth*`
  port (excluding `enx*`/`usb0`) with an active link, tier 2 = USB ethernet /
  USB-tethered phone.
- **`3.0.104GC`** — NIC detection rewritten to read **real sysfs signals**
  (a `enp3s0f3u1u1` USB adapter had defeated the `enx*`/`usb0` assumption).
- **`3.0.105GC`** — minor point release (polish on 3.0.104).
- **`3.0.106GC`** — isolates **Flatpak app data, rootful Docker/Podman
  container storage, and `/root`** onto their own subvolumes (so a Flatpak
  install or container pull is never frozen into / rolled back by an unrelated
  snapshot), plus **rootless podman/distrobox storage isolation**
  (`@containers-user`-style, ready for later adoption).
- **`3.0.107GC` / `3.0.108GC`** — `[reconstructed]` bridge releases between
  3.0.106 and 3.0.109, tightening the dynamic-optional-software groundwork and
  the container/rootless memory-of-record; no surviving artifact, graded
  purely to keep the numbering continuous.
- **`3.0.109GC`** — the **account privilege model becomes a real choice**
  (Hybrid / Debian / Ubuntu) — the ancestor of today's account-model gate —
  and rootless podman setup is fleshed out with its wheel/`/etc/subuid`/subgid
  requirements.
- **`3.0.110GC`** — **dynamic optional-software toggles**: the subvolume list,
  the `useradd` **group list** (wheel depends on account model; kvm/libvirt on
  INSTALL_VIRT; docker handled post-install), and optional-software gating are
  built from install-time choices instead of a fixed heredoc; the br0 detection
  block is skipped when virtualization is declined.
- **`3.0.111GC`** — **distrobox** (no xbps package on Void — installed from
  upstream GitHub via a `DISTROBOX_TRACK` stable/current pin) and **OctoXBPS**
  becoming install-time optional; the distrobox trust model is gated behind its
  own warned prompt.
- **`3.0.112GC`** — the 3.0.x capstone: the OctoXBPS prompt and br0 NIC NOTICE
  moved to final positions, and the distrobox stable pin fixed to `1.8.2.5`
  (the exact version carried into `v3.1.0-beta1`).

> **Lineage summary:** Alpha 1 recovery-first (v0.1.0) → desktop/recovery
> (v0.2.0) → breadth (v0.3.0) → manual multi-script era (v0.4.0) → unified
> single-file drafts (v1.x / 2.x "Test it Out") → formally versioned
> 2.9.7C…2.9.9.1GC (v2.9.x) → GRUB-only 3.0.0…3.0.8GC → feature-rich
> 3.0.98…3.0.112GC → **`v3.1.0-beta1`** (inline `AI (...)` markers; the frozen
> baseline snapshot of which survives in `Debug/Old Versions/Claude/`). The
> nested `4.0.0-SUSE` and the `OxAlpha` fork are dead ends excluded from the
> current lineage.

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
  `[TOOLS-LIMINE-BACKUP]`, `[LIMINE-HDR]`, `[LIMINE-WALLPAPER-OPT-OUT]`,
  `[VERSION-HISTORY]`, `[VERSION-CARRY]`.
- Action words: `ADDITION` (new feature), `CHANGE` (behavioral change),
  `FIX` (bug fix), `EXPANSION` (extended feature).
