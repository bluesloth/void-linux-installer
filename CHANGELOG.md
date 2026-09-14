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

Current version: **Beta-v2.9.13** (`SCRIPT_VERSION` in the script).

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
| *excluded* | `OxAlpha` fork + failed `4.0.0-SUSE` nested build | — |

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

**Validation:** `bash -n` and `Debug/check-heredocs.sh` ALL CLEAN.

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
excluded from the probe. The drift-guard `Debug/check-pkg-preflight.sh` is
committed so future package additions can't silently outgrow the probe list.

**2. `[GAME-FLATPAK-GATE]` — Heroic/Bottles ship only via the Flatpak queue.**
`install_pkgs heroic` / `install_pkgs bottles` are FORBIDDEN (no official Void
package, crash #005 class). Both game launchers are delivered through the
first-boot Flatpak queue (`com.heroicgameslauncher.hgl` /
`com.usebottles.bottles`) gated on `INSTALL_FLATPAK`, with a Stage-2 WARNING
when Flatpak was declined. The `@game` subvolume mounts ONLY
`.local/share/Steam` + `.local/share/lutris`.

**Validation:** `bash -n`, `Debug/check-pkg-preflight.sh` (134-pkg collection,
ALL COVERED), `Debug/check-defaults.sh`, and `Debug/check-heredocs.sh` all
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

**Validation:** `bash -n` and `Debug/check-heredocs.sh` both ALL CLEAN (one
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

**Validation:** `bash -n`, `Debug/check-heredocs.sh` (ALL CLEAN), and
`Debug/check-defaults.sh` (ALL CONSISTENT) all pass.

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

**Validation:** `bash -n`, `Debug/check-heredocs.sh`, and
`Debug/check-defaults.sh` all pass.

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

**Validation:** `bash -n` passes; `Debug/check-heredocs.sh` and
`Debug/check-defaults.sh` re-run clean after the edits.

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

**Validation:** `bash -n` passes, and `Debug/check-defaults.sh` stays
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

**Validation:** `bash -n` passes; `Debug/check-heredocs.sh` ALL CLEAN (the
moved `INNER_EOF` greeter-config heredocs still extract and bash -n cleanly);
`Debug/check-defaults.sh` unchanged.

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
   The community repo (REDACTED/void-packages, the repo audited at
   `repo.REDACTED.de`) deploys the greeter the intended way, so the installer now
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

**Validation:** `bash -n` passes; `Debug/check-heredocs.sh` extracts
`/etc/greetd/cosmic-greeter.toml` + both new service run scripts and
`bash -n`s them clean; `Debug/check-defaults.sh` still ALL CONSISTENT.

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

**Validation:** `bash -n` passes; `Debug/check-heredocs.sh` extracts the two new
`log/run` bodies and `bash -n`s them clean; `Debug/check-defaults.sh`
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

**Validation:** `bash -n` passes; `Debug/check-heredocs.sh` extracts the new
`/usr/local/sbin/cosmic-polkit-guard` body and `bash -n`s it clean;
`Debug/check-defaults.sh` unchanged (no prompt surface touched).

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

**Validation:** `bash -n` passes; `Debug/check-heredocs.sh` extracts the new
`/etc/greetd/cosmic-greeter.start` body (bounded `INNER_EOF`) and `bash -n`s it
clean; `Debug/check-defaults.sh` unchanged (no prompt surface touched); a
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
(`PDBUS_EOF`) — `Debug/check-heredocs.sh` extracts it into the chroot tree and
classifies it correctly; `Debug/check-defaults.sh` unchanged (no prompt surface
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

**Validation:** `bash -n` passes; `Debug/check-defaults.sh` reports all 35
`DEFAULT_*` vars (including the two new `DEFAULT_KERNEL_MAINLINE` /
`DEFAULT_KERNEL_LTS`) declared and wired; `Debug/check-heredocs.sh` fully clean
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

**Validation:** `bash -n` passes; `Debug/check-defaults.sh` all 36 `DEFAULT_*`
vars declared and wired (including `DEFAULT_DEVICE_PROFILE`);
`Debug/check-heredocs.sh` fully clean (the new gating lines + booleans live in
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

**Validation.** `bash -n` passes; `Debug/check-defaults.sh` all consistent;
`Debug/check-heredocs.sh` shell bodies all `bash -n` clean (the pre-existing
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
interpolation is safe. `Debug/check-heredocs.sh` still classifies it as a
non-shell config (`#!/usr/sbin/nft` shebang), so it is skipped by its
bash -n/shellcheck pass.

### Validation

- `bash -n Void_Linux_Installer.sh` — clean.
- Rendered config for **both** `$INSTALL_VIRT=true` (four forward accepts
  present) and `false` (forward chain = policy drop, zero rules) passes
  `nft -c -f` as root.
- `Debug/check-heredocs.sh` — ALL CLEAN (60 heredocs: 30 shell-classified,
  30 non-shell config, `/etc/nftables.conf` skipped as non-shell).
- `Debug/check-defaults.sh` — ALL CONSISTENT (no `DEFAULT_*` surface touched).

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
- `Debug/check-heredocs.sh` — ALL CLEAN.
- `Debug/check-defaults.sh` — ALL CONSISTENT (no `DEFAULT_*` surface touched).

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
- `Debug/check-defaults.sh` — ALL CONSISTENT (no `DEFAULT_*` surface touched).
- `Debug/check-heredocs.sh` — ALL CLEAN.
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
- `Debug/check-heredocs.sh` — rc.local is `bash -n clean` + shellcheck clean;
  the only `FAILURES PRESENT` is the pre-existing accounts-daemon SC2093 note,
  present identically at HEAD before this change.
- `Debug/check-defaults.sh` — ALL CONSISTENT (no `DEFAULT_*` surface touched).

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
- `Debug/check-defaults.sh` — ALL CONSISTENT.
- `Debug/check-heredocs.sh` — only the pre-existing accounts-daemon note.
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
- `Debug/check-heredocs.sh` — this block is top-level script (not a heredoc
  body), so it is covered by the script's own `bash -n`; no new heredoc added.
- `Debug/check-defaults.sh` — no new prompt/default added.

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
- `Debug/check-heredocs.sh` / `Debug/check-defaults.sh` — clean.

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
- `Debug/check-defaults.sh` / `Debug/check-heredocs.sh` — unaffected (the
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
- `Debug/check-defaults.sh` — 44/44 defaults declared + wired, all consistent.
- `Debug/check-heredocs.sh` — 59 heredocs (30 shell, 29 non-shell), ALL CLEAN
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

- `bash -n` clean; `Debug/check-defaults.sh` (44 vars) untouched — no new
  prompts; `Debug/check-heredocs.sh` untouched — no scheme/heredoc change;
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

- `bash -n` clean; `Debug/check-defaults.sh` (45 vars) ALL CONSISTENT;
  `Debug/check-heredocs.sh` 60 bodies (the new `50-nvidia.conf` is one)
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

- `bash -n`, `Debug/check-defaults.sh` (now **46** vars) ALL CONSISTENT,
  `Debug/check-heredocs.sh` 60 bodies ALL CLEAN, shellcheck 0.
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
inner-GPT is UNPROVEN on real hardware (both got their boot-side proof across
2.9.43-2.9.46: `[INNER-PARTSCAN-BOOT]`, `[DRACUT-CONF-NAME]`,
`[INNER-PARTSCAN-DMPROBE]`).

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

The REDACTED/void-packages template ships `system_accounts="_cosmicgreeter"`,
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

**Validation:** `bash -n` passes; `Debug/check-heredocs.sh` — unchanged since
this release touches no heredoc body, only the useradd/toml text outside the
`INNER_EOF` blocks and comments, but rerun to be safe; `Debug/check-defaults.sh`
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
- **Validation:** `bash -n`, `Debug/check-defaults.sh` (ALL CONSISTENT), and
  `Debug/check-heredocs.sh` (48 heredocs, ALL CLEAN) all pass.

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
- **Validation:** `bash -n`, `Debug/check-defaults.sh` (ALL CONSISTENT — 42
  `DEFAULT_*`), and `Debug/check-heredocs.sh` (48 heredocs, ALL CLEAN) all pass.

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
- **Validation:** `bash -n`, `Debug/check-defaults.sh` (ALL CONSISTENT),
  and `Debug/check-heredocs.sh` (ALL CLEAN) all pass.

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
- **Validation:** `bash -n`, `Debug/check-defaults.sh` (37 defaults, ALL
  CONSISTENT), and `Debug/check-heredocs.sh` (48 heredocs, ALL CLEAN) all
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
- **Validation:** `bash -n`, `Debug/check-defaults.sh` (ALL CONSISTENT), and
  `Debug/check-heredocs.sh` (46 heredocs, ALL CLEAN) all pass; the `sed`
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
- **Validation:** `bash -n`, `Debug/check-defaults.sh` (ALL CONSISTENT), and
  `Debug/check-heredocs.sh` (46 heredocs, ALL CLEAN) all pass after the reorder.

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
- **Validation:** `bash -n`, `Debug/check-defaults.sh` (both new defaults declared +
  referenced), and `Debug/check-heredocs.sh` (46 heredocs) all pass.

---

## Beta-v2.7.3 — post-install subvolume tool (`void-subvol-tool.sh`, `[SUBVOL-TOOL]`)

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
- **Dev gate:** `Debug/check-defaults.sh` (committed) is a reproducible check
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
- **Validation:** static gates (`bash -n`, `Debug/check-heredocs.sh` 45/45,
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
- **Validation:** static gates (`bash -n`, `Debug/check-heredocs.sh` 41/41,
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
  `Debug/check-heredocs.sh`). The pre/post wrapper has not been exercised on
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
