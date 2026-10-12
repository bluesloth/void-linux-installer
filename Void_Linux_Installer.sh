#!/usr/bin/env bash
# =============================================================================
# UNIFIED VOID LINUX ADVANCED RECOVERY INSTALLER (SECTION 1 OF 6)
# Target: Run exclusively on the outer host terminal of a Void Linux Live CD
# =============================================================================
#
# CLI flags:
#   (no args)        fresh interactive install
#   -r | --resume    resume a previous interrupted install (restores saved answers)
#   -d | --dry-run
#   -n               walk the full interactive config, print the as-planned
#                    summary (disk, partition/mkfs steps, bootloader, desktop,
#                    wallpaper, ...), then STOP at the destructive partition
#                    boundary — touches neither the target disk nor the live
#                    medium, and skips the live-CD package sync. See [DRY-RUN].
#   -h | --help      show usage
# =============================================================================
#
# ARCHITECTURE SUMMARY (read this before changing anything structural):
#   - Fail-fast guards [PREREQ]: the installer must run as root (early
#     `id -u` check) and, after the live-CD package sync, every tool the
#     OUTER (live-medium) stage invokes is verified present before the
#     destructive partitioning step (sgdisk/mkfs/btrfs/openssl/etc.). Tools
#     used only inside the chroot are installed INTO the target via xbps and
#     are deliberately excluded from that gate.
#     AI (Big Pickle) ADDITION — Beta-v2.9.40 [PKG-PREFLIGHT]: before the
#     destructive partitioning step, EVERY package name the Stage-2 chroot can
#     install is ALSO resolved against the live union pool (post -Sy) and the
#     install aborts pre-write if any name is unresolvable — closing crash #005
#     (a doomed install previously wrote the disk and then died in the chroot).
#     The PKG_PREFLIGHT candidate list is kept a SUPERSET of every install_pkgs
#     literal + the base-bootstrap literals by the committed drift-guard
#     Debug/check-pkg-preflight.sh. Repository/network hiccups DEGRADE the gate
#     to a WARN+skip, never a false FATAL. This block sits after --dry-run and
#     before the RESUME/partition boundary — it must never move.
#   - Single physical disk, GPT, UEFI boot — the disk is chosen
#     interactively at install time (numbered lsblk-based picker, live
#     medium and any already-mounted disks filtered out, requires typing
#     ERASE to confirm) rather than hardcoded to a specific device or bus
#     type. Partition 1 = ESP (FAT32), partition
#     2 = one BTRFS filesystem holding everything else as a FLAT subvolume
#     topology (every subvolume — @, @home, @grub [grub only], @swap, etc.
#     — is a top-level sibling, none nested inside another). Flat, not
#     nested, so
#     each one can be snapshotted/rolled back independently.
#     AI (Big Pickle) ADDITION — Beta-v2.5.5 [ENCRYPT]: optionally, partition
#     2 (the Btrfs filesystem) sits inside a LUKS2 container instead of being
#     a raw partition. The ESP (partition 1) stays unencrypted (bootloaders
#     and their configs read it before any passphrase exists). When enabled,
#     `cryptsetup luksFormat`/`luksOpen` create a mapper device
#     (`/dev/mapper/void-root`), and the ENTIRE machine below — mkfs.btrfs,
#     the flat subvolume topology, fstab, swapfile/hibernation, Snapper,
#     fstrim, scrub — operates on the mapper device exactly as it does on a
#     raw partition today, so the rest of the pipeline needs no rework. The
#     one cross-cutting rule is that BTRFS_UUID (the `blkid` of the Btrfs
#     filesystem) MUST be read from the opened mapper device, never from the
#     LUKS container partition (whose UUID is the ciphertext container's, not
#     the filesystem's), or every boot path below would use the wrong UUID.
#     The passphrase is typed at boot by dracut's `crypt` module after
#     `rd.luks.uuid=` on the kernel cmdline (both bootloaders). The swapfile
#     and its resume offset live inside the LUKS volume, so hibernation
#     resumes after the passphrase unlocks the volume. The passphrase is held
#     in memory during the chroot phase only, never persisted. The ESP is
#     ALWAYS off-volume; what is encrypted is the Btrfs filesystem tree
#     (including most of /boot, whose kernels are mirrored onto the ESP for
#     Limine's esp-copy). Beta-v2.6.2 [GRUB-ESP-BOOT] widens that: under
#     GRUB+ENCRYPT the whole ESP is mounted AT /boot, so grub.cfg, kernels,
#     and initramfses are all unencrypted and GRUB needs no cryptodisk.
#     AI (Big Pickle) ADDITION — Beta-v2.5.4 [YUBIKEY]: optionally, a
#     YubiKey hmac-sha1 challenge-response slot can take over boot unlock
#     instead of / in addition to the typed passphrase. Enrollment programs
#     an OTP slot with a random secret and binds HMAC-SHA1(slot_secret,
#     CHALLENGE) as a LUKS key slot; a dracut `keyscript=` in crypttab
#     challenges the YubiKey at boot and prints that same response as the
#     key. YK_FALLBACK=yes keeps the typed-passphrase slot too (YubiKey
#     fails → dracut prompts), YK_FALLBACK=no removes it (YubiKey-only
#     unlock — possession-required, nothing to type). YubiKey-only is only
#     ever proven with BOOTLOADER=limine; with GRUB the fallback slot is
#     forced on. AI (Big Pickle) CHANGE — Beta-v2.6.2 [GRUB-ESP-BOOT]: for
#     GRUB+ENCRYPT the ESP is mounted AT /boot, so grub.cfg + kernels live
#     unencrypted on the ESP and GRUB never needs LUKS cryptodisk at all
#     (just one dracut passphrase prompt after handoff). The
#     CHALLENGE (public, in the keyscript/limine-env) is not itself a
#     credential — the response only exists on the YubiKey, so nothing
#     that unlocks is ever persisted; the passphrase and the HMAC key are
#     memory-only.
#     AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS]: each of /home,
#     /var, /var/cache, /srv, /opt (and the optional /home/<user>/Games)
#     can be carved onto its OWN dedicated partition with a per-region
#     filesystem choice (ext4 or btrfs) instead of living in a Btrfs
#     subvolume. Region partitions are sliced in FIXED order (home, var,
#     cache, srv, opt, games) right after the ESP and BEFORE the single
#     LINUX root partition (or, with [ENCRYPT], as an INNER GPT inside the
#     LUKS2 container with the Btrfs root LAST on the mapper). Region
#     subvolumes (@home/@var/@cache/@srv/@opt and their owners) are FOLDED
#     out of the flat topology so no subvolume collides with a partition
#     mountpoint, the owned fstab rows are skipped, the owned
#     /root/tools/void-subvol-tool.sh entries are guarded against re-creating
#     a carved region's subvolume, and the region and its mounters are
#     audit-logged to the journal ([MULTI-FS-RUNLOG]). Region partitions
#     are rollback-exempt (not Snapper-managed) and never inside @root.
#     A carved region's roundtrip is UNPROVEN beyond the bureau-targeting
#     fallback behavior; ENCRYPT+region inner-GPT is UNPROVEN on real
#     hardware. Default (bare Enter everywhere) = all-Btrfs flat layout,
#     byte-identical to 2.9.37.
#     AI (Big Pickle) ADDITION — Beta-v2.9.43 [INNER-PARTSCAN-BOOT]: the
#     boot-time partscan dracut module (98void-inner-partscan), written into
#     the chroot ONLY when ENCRYPT=yes + carved REGION_PARTITIONED. A udev
#     RUN fires as the opened LUKS2 mapper node appears (matched via the
#     sysfs ATTR{dm/name} == mapper name since Beta-v2.9.57 — v2.9.43/2.9.56
#     matched ENV{DM_NAME}, which the kernel's dm add-uevent NEVER carries; see
#     [INNER-PARTSCAN-UDEV-ATTR] below), calling a kpartx-primary /
#     partprobe-fallback / partx-a-last helper to REGISTER the on-disk inner
#     GPT + build its dm-linear submaps BEFORE dracut's udev settle resolves
#     root=UUID=<inner btrfs> — an unregistered inner GPT strands boot at the
#     emergency shell (crash #008 residual; proven on the first real
#     ENCRYPT+regions install — Beta-v2.9.56 [INNER-PARTSCAN-KPARTX], where
#     partprobe's BLKPG silently produced nothing and `kpartx -av` fixed it).
#     Beta-v2.9.44 [DRACUT-CONF-NAME]:
#     the add_dracutmodules conf value MUST be the SHORT module name (no
#     numeric prefix); dracut-ng resolves conf names as [0-9][0-9]<name> so
#     a prefixed name matches nothing and the regen dies. Beta-v2.9.45
#     [INNER-PARTSCAN-DMPROBE]: the partprobe-primary helper (libparted
#     dm-linear submaps — the ONLY tool that can BLKPG a dm mapper;
#     partx -a is fallback only) replaces the old inline partscan in both
#     the fresh and the resume paths; Beta-v2.9.56 [INNER-PARTSCAN-KPARTX]
#     promotes kpartx (-a) to PRIMARY (the hardware-proven registration tool
#     for an opened dm-crypt mapper), keeping partprobe + partx -a as ordered
#     fallbacks; _region_inner_partscan +
#     _region_inner_dev are named functions; cleanup_on_failure partx-d
#     unwinds before luksClose; a chroot FATAL initramfs-content gate runs
#     after the dracut --force loop (abort before ESP re-sync if any image
#     lacks cryptsetup/kpartx/partprobe/helper bits); the void-limine-sync-kernels
#     per-image guard (same lsinitrd checks) prevents ever copying a broken
#     initramfs onto the ESP on a future kernel update. kpartx + Parted are
#     shipped into the target and added to PKG_PREFLIGHT whenever the module
#     installs. The __CRYPT_NAME__ token is baked via sed with &\/\ escape;
#     do NOT simplify back to partx-primary or partprobe-primary alone, do
#     NOT drop inst_binary kpartx/partprobe, do NOT udevadm-settle inside the
#     helper (deadlocks udevd),
#     and do NOT rework to an initqueue hook (dracut resolves root through
#     the same settle — too late).
#     AI (Big Pickle) ADDITION — Beta-v2.9.47 [TEE-BOOT-QUIET]+
#     [TEE-BLACKLIST]: two env-only PUBLIC limine-env knob rows
#     (DEFAULT_QUIET_BOOT, DEFAULT_TEE_BLACKLIST, both default "no") thread
#     a shared TEE_QB_FRAG ("quiet" + "modprobe.blacklist=tee") through
#     every GRUB/Limine BASE_CMD builder (live AND the limine write-conf
#     embedded recompute that runs on every kernel update / snapper-plugin
#     resync), so a hand-edited cmdline fragment can never silently vanish.
#     Byte-identical output at defaults; existing installs untouched.
#   - Headless / server path (Beta-v2.9.48 [NO-DE]/[NO-DM]/[HEADLESS]): the
#     desktop menu gains option 8 = `none` (console login, no DE); the DM menu
#     gains a `none` option (DM_SERVICE_NAME="none", rc.local link guarded so
#     no dangling /etc/sv/none symlink is created). DESKTOP_ENV=none AND
#     DISPLAY_MANAGER=none together compute HAS_GRAPHICAL=no — this single
#     flag gates the xorg/wayland base chain and the audio install. On a
#     headless box two explicit opt-ins appear: INSTALL_XORG (preserves the
#     Xorg/Wayland base without flipping HAS_GRAPHICAL — useful for a later
#     startx / remote-X) and INSTALL_AUDIO (PipeWire/ALSA). Graphical installs
#     get audio unconditionally. The desktop menu is reordered most→least
#     popular (KDE stays option 1 / bare-Enter default) and the catch-all
#     KDE else is converted to an explicit elif so a headless DE cleanly skips
#     the metapackage.
#   - Pre-write disk budget (Beta-v2.9.48 [DISK-BUDGET]): DISK_BYTES is
#     captured at disk-pick via lsblk -bdn -o SIZE (fails open when
#     unreadable) and persisted for resumed runs. A _size_to_bytes() helper
#     converts any human-size or sgdisk suffix (40G, 500GB, 10GiB, etc.) to
#     exact bytes, and _disk_budget_check() sums the ESP, every carved
#     region, and a >=1 GiB system-floor against the real disk size. An
#     over-provisioned layout is refused BEFORE sgdisk -Z on a fresh run, and
#     the --dry-run plan also fails to launch when it does not fit. ENCRYPT
#     uses the same container=remainder identity. This release also fixes the
#     latent Beta-v2.9.38 REGION_*_SIZE uppercase-fold eval bug —
#     REGION_PARTITIONED carries lowercase tokens but the size vars are stored
#     UPPERCASE (REGION_HOME_SIZE), so the outer and inner carve evals must
#     use ${_rr^^}_SIZE to read them.
#   - Most subvolumes use noatime+zstd:1 compression. Several are
#     deliberately nodatacow+compress=none instead: @swap (COW + compression
#     both break swapfiles), @libvirt (COW hurts qcow2/raw VM disk
#     performance and defeats their own internal COW), the churn-heavy var
#     subvols @srv/@cache/@log/@spool (server/cache/log/queue churn
#     constantly — COW is pure write amplification), the browser
#     profile/cache subvols @mozilla, @mozilla-cache, @chromium, @vivaldi
#     (profile sqlite/cache churn constantly — COW there is pure write
#     amplification), and the opt-in per-user app subvols @thunderbird (sqlite
#     mail profile) and @steam (game churn). @network backs /var/lib/NetworkManager runtime
#     state (leases, NetworkManager.state) with normal compression so a
#     rollback of @ does not rewind known-network/lease state.
#     AI (Big Pickle) FIX — Beta-v2.5.2 [NODATACOW]: the var
#     subvols are made nodatacow via their MOUNT OPTIONS (and fstab), not the
#     pre-mount `chattr +C` — chattr on a mountpoint dir inode is shadowed the
#     moment a subvolume mounts over it, so it never took effect before.
#   - Hibernation: one physical BTRFS-native swapfile (not swap partition),
#     resume offset computed via `btrfs inspect-internal map-swapfile -r`
#     and injected into the kernel command line (Limine's kernel_cmdline)
#     plus dracut's resume module.
#     AI (Big Pickle) FIX — Beta-v2.5.2: `SWAPFILE_MODE` (derived from
#     `SWAP_BACKEND`, drives @swap subvol creation, the swapfile mount, mkswapfile,
#     and the fstab swap entries) was missing from the persisted state-file list,
#     so a resumed run skipped all swap setup silently. It is now persisted
#     (single source stays the prompt-block derivation from `SWAP_BACKEND`).
#   - Init: runit, not systemd. Session/seat management (Beta-v2.4.0) is a real
#     choice, $SESSION_STACK: elogind (default, the standalone systemd-logind
#     fork satisfying the org.freedesktop.login1 D-Bus interface that
#     SDDM/polkit/NetworkManager expect) OR the lighter turnstile + seatd +
#     acpid stack. Neither makes this a systemd system. Never add
#     systemctl/journalctl/loginctl/.service-unit logic anywhere in this
#     script; services are enabled via `ln -s /etc/sv/X /etc/runit/...`.
#   - Prompt defaults (Beta-v2.7.2 [PROMPT-DEFAULTS]): every interactive
#     choice and yes/no toggle falls back to a DEFAULT_* variable in the
#     editable top block (right after SCRIPT_VERSION) on bare Enter instead of
#     a hardcoded value, and each is env-overridable via `${VAR:-default}`.
#     The block sits BEFORE the [RESUME] state re-source so a resumed run keeps
#     its saved answers. Numeric-choice defaults use the menu index shown in
#     the prompt; toggle defaults are literal true/false.
#   - Virtualization: QEMU/KVM + libvirt on a custom `br0` bridge (built natively
#     via NetworkManager connection profile tracking configurations at boot),
#     NOT libvirt's default NAT `virbr0` (disabled on first boot whenever the
#     br0 NM profile was written — see rc.local; Beta-v2.9.86 [BR0-SKIP] keeps
#     virbr0 ENABLED as the VM-networking fallback on machines with no wired
#     NIC at all, where the whole br0 pair is skipped).
#     AI (Big Pickle) FIX — Beta-v2.5.2 [NM-IFACE]: NM's `[connection]
#     interface-name=` is a LITERAL device name, not a glob (only `[match]`
#     globs). The NIC-detection fallback `NET_INTERFACE_MATCH="enp*"` is therefore
#     NOT emitted as `interface-name=` in br0-slave (it can never bind); the key is
#     omitted so the slave matches by role on any free ethernet device. A concrete
#     auto-detected NIC still emits the literal name, unchanged.
#   - Login shell (Beta-v2.5.2 [SHELL]): a real install-time choice,
#     $USER_SHELL — bash (default, bundled in base-system, no package) or
#     zsh/fish/mksh (installed from the official repos and set as the primary
#     user's login shell via useradd -s). The binary path and its providing
#     package are carried through chroot_env and the resume state file so a
#     resumed run restores the choice. (Beta-v2.5.4 [ZSHRC]: when the choice
#     is zsh, a minimal ~/.zshrc is pre-created for the primary user so the
#     first login doesn't hit zsh's zsh-newuser-install wizard; likewise a
#     minimal ~/.config/fish/config.fish for fish so the first login doesn't
#     hit the fish_config wizard.)
#   - Desktop (Beta-v2.4.0): a real install-time choice, $DESKTOP_ENV — KDE
#     Plasma (default, primary tested path), Cinnamon via cinnamon-all,
#     GNOME via the full `gnome` metapackage, Xfce via `xfce4`, MATE via
#     `mate`, LXQt via `lxqt`, or COSMIC — which is NOT in the official
#     repos and is installed from the community repo
#     https://bluesloth.github.io/void-linux-cosmic/ (audit:
#     https://github.com/bluesloth/void-linux-cosmic), a third-party
#     signing-trust choice made at the user's own risk with a signing key
#     PINNED in the installer, runtime repo verification and a graceful abort
#     if it is unavailable. VERIFIED against Void's docs and real user reports: Void
#     lists Wayland sessions for GNOME/KDE Plasma only — the GTK/Qt desktops
#     (Cinnamon/Xfce/MATE/LXQt) are X11 on Void today.
#     AI (Big Pickle) FIX — Beta-v2.9.9 [MATE-TERMINAL]/[MATE-AUDIO]/
#     [XFC-VOLUME]/[LXQT-EDITOR]: several DE metapackages omit desktop
#     basics that the user expects on a fresh install (verified against
#     void-packages' templates): Void's `mate` metapackage bundles NO
#     terminal, text editor, or volume applet (mate-terminal/pluma/mate-media
#     now installed); `xfce4` ships terminal+editor but no panel volume
#     applet (xfce4-pulseaudio-plugin now installed); `lxqt` ships a terminal
#     but no text editor (FeatherPad now installed). A real Beta-v2.9.6 MATE
#     install had no way to open a terminal from the desktop.
#     AI (Big Pickle) FIX — Beta-v2.9.10 [COSMIC-POLKIT]: the `cosmic-desktop-full`
#     metapackage pulls NO polkit privilege agent (verified against its
#     run_depends in the third-party COSMIC repo), so on a fresh COSMIC
#     install GUI privilege prompts (mounting, admin changes, package-manager
#     auth) can hang with nothing to present the dialog — the same gap class as
#     the MATE/Xfce/LXQt metapackage omissions above. `polkit-gnome` (GTK3 agent,
#     Void official repo) is now installed explicitly for DESKTOP_ENV=cosmic,
#     with an installer-baked /etc/xdg/autostart entry (Void's polkit-gnome
#     ships its desktop file with OnlyShowIn=GNOME and installs it to
#     /usr/share/applications, so without the baked entry COSMIC would never
#     start it — cosmic-session honors XDG autostart, verified via the session
#     binary's "looking for autostart folders" / Desktop Entry parsing).
#     Beta-v2.9.13 [COSMIC-POLKIT-GUARD]: that baked entry now launches a
#     /usr/local/sbin/cosmic-polkit-guard wrapper that waits for a
#     compositor-backed session (WAYLAND wl socket + reachable session bus)
#     then runs the agent, and respawns it on exit — on `<host>` the raw binary
#     died instantly at autostart (launched before cosmic-comp/session-bus
#     were up), leaving a <defunct> zombie and NO polkit dialog.
#     Beta-v2.9.13 [ACCTSVCS-ICON]: the fresh user also gets a default avatar
#     copied to /var/lib/AccountsService/icons/<user> (the themed Adwaita
#     `avatar-default`, Pop fallback — the same graphics greeters already
#     render by default) right after useradd, silencing the greeter's per-boot
#     `failed to open icon ... NotFound` error and giving greeters a real
#     avatar instead of an empty placeholder.
#     `wayland`/`wayland-protocols` are still installed unconditionally
#     for all options (cheap, harmless, future-proofing).
#     Display manager (Beta-v2.4.0) is an independent choice, $DISPLAY_MANAGER:
#     SDDM (default for KDE/LXQt/COSMIC), LightDM (Cinnamon/Xfce/MATE), GDM
#     (GNOME), or cosmic-greeter (COSMIC's own greeter, offered only when
#     COSMIC is chosen). Beta-v2.9.10 [COSMIC-GREETER-DM]: cosmic-greeter is
#     NOT a standalone DM — its binary self-describes as "a libcosmic frontend
#     for greetd which can be run inside of cosmic-comp", so the DM path now
#     provisions it the way the community repo actually builds it: the
#     `cosmic-greeter` system user, a greetd invocation (`cosmic-comp
#     cosmic-greeter` under that user via /etc/greetd/cosmic-greeter.toml),
#     the supervised `cosmic-greeter-daemon`, and a supervised accounts-daemon
#     (the greeter reads AccountsService; same D-Bus-activation race as
#     [LIGHTDM-HW]). A Beta-v2.9.9 COSMIC install that chose this DM booted to
#     a bare terminal login with no login screen because the former bespoke
#     service exec'd /usr/bin/cosmic-greeter directly.
#     LightDM additionally asks for a greeter (GTK [default] / Slick).
#     Beta-v2.5.0 [LIGHTDM-HW] hardens the LightDM path
#     against the greeter failures observed on real hardware: accounts-daemon
#     (org.freedesktop.Accounts) is granted a real runit service + first-boot
#     link instead of racy on-demand D-Bus activation (fixes Slick-greeter
#     hang / GTK-greeter auth flakiness — void-packages#59538), and the
#     @lightdm subvolume is chowned to lightdm:lightdm.
#     Beta-v2.9.1 [GREETER-NO-WEBKIT2]: the WebKit2 greeter option
#     (lightdm-webkit2-greeter) was REMOVED — it is abandoned upstream and
#     renders a black screen / blinking cursor against current webkit2gtk on
#     real hardware (all other greeters work; the maintained WebKit-based
#     successors web-greeter/nody-greeter/sea-greeter are NOT in Void's
#     official repos, so a stock-Void installer only offers GTK + Slick).
#     [LIGHTDM-SWRAP] also writes `session-wrapper=/etc/lightdm/Xsession`
#     into the generated lightdm.conf — mandatory, since overwriting Void's
#     package-default conf would otherwise leave LightDM using its
#     compiled-in default wrapper `lightdm-session`, which Void does not ship
#     (this made every session bounce back to the greeter with an empty
#     .xsession-errors).
#     [LIGHTDM-GREETER-BG] (Beta-v2.9.3) also writes a `background=<path>`
#     into the chosen greeter's config (lightdm-gtk-greeter.conf or
#     slick-greeter.conf) so the login screen shows a real image rather
#     than solid black on a fresh install. Prefers the GNOME adwaita-l
#     stripe, falls back to any image under /usr/share/backgrounds.
#     PipeWire
#     audio (with WirePlumber as session
#     manager — auto-managed via robust XDG rules).
#   - Recovery: Snapper (timeline snapshots) + a dracut overlay so a
#     snapshot boot is read-only with a writable RAM overlay rather than
#     mutating the snapshot itself. Snapshot-boot MENU generation depends
#     on which bootloader was chosen (next bullet).
#     AI (Big Pickle) ADDITION — Beta-v2.5.3 [SCRUB]: the physical half of
#     that same recovery story — a monthly /etc/cron.monthly/btrfs-scrub
#     job catches silent checksum failures (bitrot) and lets Btrfs repair
#     them, complementing Snapper (logical/accidental damage). It scrubs
#     once per btrfs FILESYSTEM (the mount list is deduped by major:minor
#     since every subvolume mount is a view of the same fs) and logs to
#     /var/log/btrfs-scrub.log. Never forced: a manually-running scrub
#     makes the monthly pass fail fast and record why instead of racing it.
#     AI (Big Pickle) ADDITION — Beta-v2.6.4 [PKG-SNAPSHOT]: a third piece of
#     the recovery trio — an explicit per-update rollback pair. The timeline
#     snapshots can be minutes old when an update lands, so
#     /usr/local/sbin/void-xbps-snap wraps a mutating xbps-install to take a
#     snapper "pre" snapshot before it runs and a paired "post" afterwards,
#     guaranteeing an exact "undo THIS update" pair. Drop-in for
#     xbps-install (all args pass through), --no-dbus, only fires on mutating
#     installs against a btrfs root, and never blocks an update if the pre
#     snapshot fails. Beta-v2.6.5 [PKG-SNAPSHOT-AUTO] goes further: it
#     SHADOWS /usr/bin/xbps-install (real binary renamed to
#     /usr/bin/xbps-install.real, symlink placed in its place) so EVERY
#     xbps-install — bare or via sudo, any shell — snapshots automatically
#     with zero behavior change. Caveat: an `xbps` package self-update
#     re-places a real binary over the symlink (un-shadowing it).
#     AI (Big Pickle) ADDITION — Beta-v2.6.6 [TOOLS-DIR]: maintenance/recovery
#     scripts ship in /root/tools (persistent, installed once, run later on
#     demand) so the documented recovery steps are never hand-rewritten:
#     re-shadow-xbps.sh (xbps self-update recovery), limine-sync.sh (manual
#     boot-menu regen), re-provision-snapper.sh (safe snapper restore, plugin
#     re-install), plus a canonical copy of void-xbps-snap. Idempotent, not on
#     PATH (run-on-demand tools, not live helpers).
#     AI (Big Pickle) ADDITION — Beta-v2.7.3 [SUBVOL-TOOL]: /root/tools also
#     ships void-subvol-tool.sh, a post-install subvolume manager (list/check/
#     add/detach/destroy) for the flat Btrfs topology. Purely structural — it
#     creates additional FLAT siblings (via the subvolid=5 top-level-tree mount,
#     never nested inside @, so they stay outside Snapper rollback scope) without
#     installing the software that would normally own them. nodatacow is applied
#     via fstab mount options, never chattr (matches [NODATACOW]).
#     AI (Big Pickle) CHANGE — Beta-v2.9.3 [SUBVOL-INSTALL]: void-subvol-tool
#     gained `add ... --install` / `add --class ... --install`, which xbps-install
#     the owning package(s) (PKG_MAP) AFTER the sibling is mounted, so data lands
#     on the isolated subvolume from the first run. Still structural by default.
#     [SUBVOL-DATA-GUARD]: `add` also refuses a non-empty, unmigrated target
#     mountpoint, forcing the source-dir migrate form so pre-existing data inside
#     @ is never silently hidden behind the fresh mount.
#     AI (Big Pickle) ADDITION — Beta-v2.7.6 [PKG-LIST]: the post-install
#     ~/Documents/Void_Install.txt record now appends the FULL finished-system
#     package inventory (xbps-query -l, status prefix stripped, sorted, one per
#     line) so a box records not just the installer version + choices but exactly
#     WHAT was installed. Written in the chroot against the target's /var/db/xbps;
#     secret-free like install-config; SCRIPT_VERSION kept alongside. Missing
#     xbps-query degrades gracefully (omitted, install never fails).
#     AI (Big Pickle) CHANGE — Beta-v2.7.5 [FLOW-ORDER]: reordered the stage-1
#     prompt cluster so the bootloader is decided first, the Limine wallpaper is
#     asked immediately after it (limine only), disk encryption (+ YubiKey,
#     clamp, passphrase, mapper) follows, and audio (PipeWire read-only-snapshot
#     autostart) moves to the tail. Final order: swap -> bootloader -> wallpaper
#     (limine) -> encryption gate -> YubiKey -> YK clamp -> passphrase -> audio.
#     [ENCRYPT-ORDER] semantics preserved (passphrase captured only after
#     bootloader + clamp final); GRUB+ENCRYPT still sizes the ESP to 4GiB.
#     AI (Big Pickle) ADDITION — Beta-v2.7.4 [BROWSER-GROUP] / [CONTAINER-GROUP]:
#     the interactive optional-software prompts are grouped behind category gates
#     (SETUP_WEB_BROWSERS, SETUP_CONTAINERS) mirroring the tool's --class groups,
#     while each browser / container backend stays individually selectable. Gates
#     default to the aggregate of their component defaults (web=YES, containers=NO)
#     so a bare-Enter run is unchanged; a "no" skips the whole section and forces
#     every contained toggle off (exported, so SUBVOL_LIST/provision gating stays
#     correct). Both gates wired to DEFAULT_* per [PROMPT-DEFAULTS].
#     AI (Big Pickle) ADDITION — Beta-v2.8.2 [APPS-GROUP]: a third category gate
#     (SETUP_APPS) wrapped the extra-app / extra-data subvolume pre-provision
#     prompts — per-user (Thunderbird/Steam/VirtualBox) plus, new here
#     [SUBVOL-PRE-SYS], the system-level
#     "for later manual use" subvols (Flatpak/Docker/Podman-rootful/
#     Virtualization) that otherwise only exist when the software is installed.
#     All component defaults were OFF, so SETUP_APPS defaulted OFF ([OPT-DEFAULTS]
#     lean posture).
#     AI (Big Pickle) ADDITION — Beta-v2.9.0 [SUBVOL-GATES]: SETUP_APPS and its
#     scattered per-app pre-provision prompts were REMOVED and replaced by two
#     master y/n/i gates asked once, after every INSTALL_* is finalized:
#       Gate 1  SUBVOL_ISOLATE_INSTALLED — isolate each app you ARE installing?
#       Gate 2  SUBVOL_PRECREATE         — pre-create empty subvols for software
#                                          you did NOT install (for later manual
#                                          use)?
#     A table-driven resolver then folds each app's
#     INSTALL_* choice against the two gates into its single resolved
#     PROVISION_*_SUBVOL flag ("isolate?"=true/false). ALL downstream sites
#     (SUBVOL_LIST, Stage-1 mkdir/mount/fstab, provision_browser_subvol
#     per-user sites, teardown umounts) read ONLY the resolved PROVISION_*_SUBVOL
#     flag — never INSTALL_* directly — so the two gates are the single source of
#     truth driving every stage. Defaults: Gate1=YES (matches the old
#     always-isolate), Gate2=NO (matches the old lean posture) ([OPT-DEFAULTS]).
#     AI (Big Pickle) ADDITION — Beta-v2.6.7 [RESHADOW-BOOT]: the xbps
#     self-update caveat is now SELF-HEALING. /etc/rc.local (executed every
#     boot by runit stage 2, OUTSIDE the installer's firstboot.log guard) calls
#     /root/tools/re-shadow-xbps.sh on each boot, so if an `xbps` self-update
#     un-shadows the wrapper, the next boot repairs it before any later update
#     can run unsnapshotted. Manual recovery is no longer required.
#     AI (Big Pickle) ADDITION — Beta-v2.6.8 [TOOLS-LIMINE-BACKUP]: /root/tools
#     now also carries canonical backups of the three LIVE Limine menu engines
#     (/usr/local/sbin/void-limine-env.inc, void-limine-sync-kernels,
#     void-limine-write-conf). Previously /root/tools could re-trigger a menu
#     regen and re-install the snapper plugin but could NOT rebuild a wiped
#     /usr/local/sbin Limine stack; limine-sync.sh now self-restores these from
#     backup first, so /root/tools is a self-contained regeneration kit for the
#     whole void-limine + limine-snapper-sync pipeline (no full reinstall needed).
#     AI (Big Pickle) ADDITION — Beta-v2.6.9 [ENCRYPT-KEYMAP] + [ENCRYPT-VERIFY]:
#     two encrypted-boot hardening steps discovered from a real-hardware lockout
#     (a short simple passphrase failed at boot after a complex one unlocked):
#     (1) [KEYMAP] capture the LIVE console keymap into the installed /etc/rc.conf
#     (runit console) AND dracut's early-boot initramfs prompt (i18n module +
#     rd.vconsole.keymap=), so the passphrase typed under the install console maps
#     to the same bytes at boot — a keymap mismatch was the suspected root cause of
#     "complex unlocks, simple short one does not". (2) [ENCRYPT-VERIFY] right after
#     luksFormat+luksOpen, the installer now luksClose + re-luksOpen with the SAME
#     passphrase and aborts LOUDLY on failure, catching a bad volume before any
#     reboot locks the user out; resume-path luksOpen also aborts on failure instead
#     of silently continuing with a dead mapper.
#   - Bootloader (Beta-v2.4.0; default flipped to Limine in Beta-v2.6.0
#     [LIMINE-DEFAULT]): a real per-install CHOICE, $BOOTLOADER, between two
#     fully separate code paths in Stage 2:
#       * limine — (DEFAULT since Beta-v2.6.0) newer, simpler, single-file
#         portable UEFI binary deployed directly onto the ESP
#         (EFI/BOOT/BOOTX64.EFI) — no efibootmgr, no NVRAM entries. Snapshot
#         boot menu is a static config written by
#         /usr/local/sbin/void-limine-write-conf, a standalone script shared
#         by the kernel hook AND a snapper plugin
#         (/usr/lib/snapper/plugins/00-void-limine-snapper-sync) that fires the
#         moment a snapshot is created/deleted — no grub-btrfs equivalent
#         exists on Void, and Void's snapper DOES execute its plugin dir
#         (empirically verified; see [SNPR-EV] and
#         Debug/snpr_ev/probe_void_snapper_plugin.sh). 4GiB ESP. Treat as
#         experimental — see §1/§3.19-§3.26 of the companion CHANGELOG.
#         Beta-v2.5.1 [LIMINE-WALLPAPER] optionally adds a boot-screen
#         wallpaper: an opt-in prompt takes an image from the live system,
#         copies it onto the ESP at boot():/limine-splash.<ext>, and records
#         the choice in limine-env so void-limine-write-conf re-emits
#         wallpaper:/wallpaper_style (guarded on the file existing). Void's
#         limine package ships the plain BOOTX64.EFI — wallpaper works with
#         it, it is not a limine-gui-only feature.
#       * grub   — mature, real-hardware-tested path carried from 3.0.x.
#         Snapshot boot menu via grub-btrfs (dynamic, auto-regenerated by
#         a kernel hook). 1GiB ESP. Choice 2 in the prompt.
#         Beta-v2.6.2 [GRUB-ESP-BOOT]: with ENCRYPT=yes the ESP is mounted
#         AT /boot instead, giving GRUB a fully unencrypted boot tree (no
#         LUKS cryptodisk needed — one dracut passphrase prompt) and growing
#         the ESP to 4GiB to hold every kernel/initramfs.
#     Both paths are UEFI-only; BIOS boot is not implemented for either.
#   - Repo mirror (Beta-v2.4.1): the official Void repository mirror is a real
#     install-time choice auto-derived from the selected timezone (regional
#     selection from the authoritative registry at xmirror.voidlinux.org),
#     with an override menu. $REPO_PRIMARY is set to the chosen mirror while
#     $REPO_BACKUP1 (Fastly CDN) and $REPO_BACKUP2 (tier-1 load-balanced
#     default) are retained for global failover. All baked-in mirror URLs were
#     live-verified (HTTP 200 + valid x86_64-repodata). The community COSMIC
#     repo is unaffected.
#   - Local package cache (Beta-v2.9.59 [LOCAL-CACHE]): OPTIONAL reuse of a
#     pre-seeded XBPS cache on an attached medium (<mount>/xbps-cachedir-<arch>,
#     the mklive/void-live layout used by the Void_Linux_Live fork) so the live
#     sync, base bootstrap, and every chroot install take present packages from
#     disk and fall back to the mirrors per missing package. Default OFF
#     (DEFAULT_LOCAL_CACHE=no — network-only baseline); the prompt auto-detects
#     the newest-touched writable arch-matching dir or accepts a typed absolute
#     path. Threading: `${LOCAL_CA}` (-c <dir>, empty when off) in the live CD
#     sync + bootstrap; chroot installs reach the cache through a bind mount of
#     the media dir at /mnt/tmp/xbps-cache (= /tmp/xbps-cache in the chroot,
#     chroot_env.sh REMAPS LOCAL_CACHE_DIR) plus a chroot-wide
#     ${_xbps_cache[@]} array into install_pkgs()/install_cosmic(). The cache
#     dir MUST be writable (-Sy repodata + COSMIC index write into it); unusable
#     → degrade to network-only, never a FATAL. State-file persisted for resume
#     (path re-validated/re-detected); released in the Stage-3 teardown and the
#     failure unwind; PKG-PREFLIGHT gate deliberately untouched (stays mirror-
#     truthful).
#
# REGRESSIONS THAT HAVE ALREADY HAPPENED ONCE — search this file for
# "CRITICAL" / "DO NOT" comments before removing anything that looks
# redundant. Several specific things have already broken a real install
# after looking safe to simplify:
#   1. [BOOTLOADER=grub only] The explicit `grub-mkconfig -o
#      /boot/grub/grub.cfg` call right after grub-install is the ONLY thing
#      that reliably generates grub.cfg on a fresh install — the
#      99-grub-btrfs kernel hook does NOT reliably fire during the initial
#      install itself (confirmed by a real broken install that booted
#      straight to a "grub>" rescue shell). Leave both in place.
#      [BOOTLOADER=limine only] There is no generator to forget to re-run
#      in the first place — limine.conf is written directly by
#      /usr/local/sbin/void-limine-write-conf whenever it's invoked (kernel
#      hook or snapper plugin — see [LIMINE-SYNC-CRON]).
#   2. `xbps-trigger kernel-hooks` is NOT a real command — it doesn't exist
#      in xbps at all. Use `xbps-reconfigure -f <kernel-pkg>` instead.
#   3. `/var/service/*` symlinks fail during first-boot rc.local because
#      /var/service is a dangling symlink at that point in boot (search
#      "dangling symlink"). Link into /etc/runit/runsvdir/default/ directly.
#   4. [BOOTLOADER=limine, KERNEL_MODE=esp-copy only] ESP kernel copies can
#      go silently stale if the post-install kernel hook fails to fire or
#      errors out — the ESP keeps the previous kernel+initramfs pair while
#      /usr/lib/modules on root advances underneath it, producing a
#      kernel/module mismatch that only surfaces at next boot. The hook
#      runs under `set -e` so a failed copy aborts the xbps transaction
#      loudly instead of silently succeeding with stale files — do not
#      remove that, and do not remove the explicit post-reconfigure re-sync
#      call either (search "KERNEL-HOOK follow-up").
#   5. Do not merge or cross-wire the GRUB and Limine code paths — they are
#      deliberately two separate branches (search "$BOOTLOADER") with no
#      shared config-generation logic. grub-btrfs/41_snapshots-btrfs only
#      applies under BOOTLOADER=grub; void-limine-write-conf and its snapper
#      plugin only apply under BOOTLOADER=limine. Neither should leak into
#      the other's branch.
#   6. [BOOTLOADER=limine, LIMINE-WALLPAPER] The Limine wallpaper is a
#      persisted opt-in: choice + style live in /etc/void-installer/limine-env,
#      the image lives on the ESP as boot():/limine-splash.<ext>, and
#      void-limine-write-conf re-emits wallpaper:/wallpaper_style ONLY when
#      that ESP file exists. Do not hardcode a wallpaper path, do not drop the
#      existence guard (a missing image must not leave a dangling wallpaper
#      line), do not forget it works with Void's plain BOOTX64.EFI, and do NOT
#      reintroduce a commented wallpaper template in limine.conf — the
#      generator resync (kernel hook / snapper plugin) rewrites the file, so
#      the only durable enable path
#      is LIMINE_WALLPAPER=yes in limine-env + an image on the ESP.
#   7. [CRASH-USB-LOG] The CLI-flag loop (--save-log/-r/-d/-h) and the
#      RESUME state vars MUST stay at the very top, BEFORE the
#      `: > "$JOURNAL"` truncation, the `ping xmirror` network gate, and the
#      STAGE-1 banner. A --save-log that parses later (after the network
#      gate, as it did before Beta-v2.9.38) is useless from a crashed,
#      networkless live env — the very situation it exists for. Do not "move
#      it back down" next to the other setup; the placement is the feature.
# =============================================================================
set -eE
# errtrace (-E) makes the ERR trap below fire inside functions/subshells too,
# not just at the top level.
set -o pipefail
# AI (Big Pickle) ADDITION — Beta-v2.5.1 [PIPEFAIL]: pipefail closes the
# silent-failure gap that `set -e` alone misses: without it a pipeline whose
# LAST command succeeds masks an earlier failing stage (e.g. a failed
# `sed`/`grep` extract followed by a `head` that returns 0 would look
# healthy). Guarded extractor pipelines that already use `|| true` /
# `|| echo 0` are unaffected.

# AI (Claude, Sonnet 5, Medium) ADDITION: Bump SCRIPT_VERSION on every revision so the running
# terminal always shows which file/revision is actually executing — matches
# the filename this script is currently distributed under.
SCRIPT_VERSION="Beta-v2.9.90"

# [VERSION-CARRY] (Beta-v2.8.2): versions self-normalize under the carry rule —
# the patch field holds 0-9 and carries into the (multi-digit) minor on
# overflow; the minor never carries into the major unless the author makes an
# explicit major bump. The lineage is split into named eras carrying their
# own prefix (Alpha-v1.x, then Beta-v1.x/Beta-v2.x), so each era reads
# monotonic and the current release (Beta-v2.9.74) always carries the highest
# numbering. See Debug/version-renumber-map.txt for the authoritative
# OLD->NEW mapping recovered from the Debug/Old Versions/ artifacts.

# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.8.1 [VERSION-HISTORY]: where this
# SCRIPT_VERSION sits in the full lineage. The [VERSION-CARRY] scheme maps the
# whole history into named eras (Alpha-v, Beta-v) per
# Debug/version-renumber-map.txt. The mangled OxAlpha fork and the failed
# openSUSE-nested 4.0.0-SUSE build are dead ends and NOT part of the
# installed lineage.
#
#   ALPHA ERA (reconstructed, Debug/Old Versions/):
#     Alpha-v1.0.1   GPT + flat Btrfs subvols
#     Alpha-v1.0.2   base system, KDE, NM, runit
#     Alpha-v1.0.3   Snapper, GRUB-Btrfs, ~/.mozilla
#     Alpha-v1.0.4   systemd path monitor (dropped)
#
#   BETA ERA — PRE-TRACKING (reconstructed from artifact filenames):
#     Beta-v1.0.0–v1.9.5   unified "Test it Out" drafts, nftables
#     Beta-v1.9.6          first versioned build, nftables rules
#     Beta-v1.9.7          nftables interface pinning
#     Beta-v1.9.8          repo fallback, wireplumber
#     Beta-v1.9.9          dynamic config loop, NM blueprints
#     Beta-v2.0.1–v2.0.9   GRUB-only, tmpfs snapshot runtime,
#                          chown-before-mount, /tmp, SDDM conf
#     Beta-v2.1.0          base file for capstone carpet
#     Beta-v2.1.1–v2.1.5   Claude attempts (96=failed boot)
#     Beta-v2.1.6–v2.2.8   snapshot-overlay dracut, dynamic subvols,
#                          account model, distrobox
#
#   BETA ERA — TRACKED (inline AI(...) markers, TAG-bound):
#     Beta-v2.3.0    first inline-marker release
#     Beta-v2.4.0    DESKTOP_ENV, LOCALIZE, SWAP, COSMIC
#     Beta-v2.4.1    MIRROR, LIMINE-WALLPAPER, DRY-RUN (Claude's last)
#     Beta-v2.5.0    [LIGHTDM-HW]; [REBOOT-COUNTDOWN]; [WSDD]
#     Beta-v2.5.1    [LIGHTDM-SWRAP]; [GDM-WAY]; [LIMINE-HDR]
#     Beta-v2.5.2    [SHELL]; [SNPR-EV]; [NODATACOW]; [INSTALL-PKGS]
#     Beta-v2.5.3    [SCRUB]
#     Beta-v2.5.4    [YUBIKEY]; [ZSHRC]; [LIMINE-SNAPDATE]
#     Beta-v2.5.5    [ENCRYPT]
#     Beta-v2.5.6    [SNPR-EV-NO-CRON]; [FSTRIM-SCOPE]
#     Beta-v2.5.7    [RCL-VIRT-WAIT]
#     Beta-v2.5.8    [YK-KEYSCRIPT-BAKE]
#     Beta-v2.5.9    [DROP-@TMP]
#     Beta-v2.6.0    [LIMINE-DEFAULT]; [ENCRYPT-ORDER]
#     Beta-v2.6.1    [SUBVOLS]
#     Beta-v2.6.2    [GRUB-ESP-BOOT]; [DOCS-LOG]
#     Beta-v2.6.3    [FULLNAME]
#     Beta-v2.6.4    [PKG-SNAPSHOT]
#     Beta-v2.6.5    [PKG-SNAPSHOT-AUTO]
#     Beta-v2.6.6    [TOOLS-DIR]
#     Beta-v2.6.7    [RESHADOW-BOOT]
#     Beta-v2.6.8    [TOOLS-LIMINE-BACKUP]
#     Beta-v2.6.9    [ENCRYPT-KEYMAP]; [ENCRYPT-VERIFY]
#     Beta-v2.7.0    [ENCRYPT-NEWLINE]
#     Beta-v2.7.1    [CRYPT-NAME]
#     Beta-v2.7.2    [PROMPT-DEFAULTS]
#     Beta-v2.7.3    [SUBVOL-TOOL]
#     Beta-v2.7.4    [BROWSER-GROUP]; [CONTAINER-GROUP]
#     Beta-v2.7.5    [FLOW-ORDER]
#     Beta-v2.7.6    [PKG-LIST]
#     Beta-v2.7.7    [LIGHTDM-GREETER-SESSION]
#     Beta-v2.7.8    [DOCS-LOG-CHOWN]
#     Beta-v2.7.9    [TOOLS-LIMINE-GUARD]
#     Beta-v2.8.0    [CINNAMON-WALLPAPER]; [NFT-TTL-REMOVED]
#     Beta-v2.8.1    [VERSION-HISTORY]; [VERSION-CARRY]  (this table)
#     Beta-v2.8.2    [APPS-GROUP]; [SUBVOL-PRE-SYS]
#     Beta-v2.8.3    [INSTALL-APPS]; PostgreSQL/MariaDB removed
#     Beta-v2.9.0    [SUBVOL-GATES]; resolved PROVISION_*_SUBVOL
#     Beta-v2.9.1    [GREETER-NO-WEBKIT2]; WebKit2 greeter removed
#     Beta-v2.9.2    [PODMAN-ROOTLESS-SUBVOL]; rootless podman subvol gates
#     Beta-v2.9.3    [SUBVOL-INSTALL]; [LIGHTDM-GREETER-BG]; [XFC-AUTOMOUNT]
#     Beta-v2.9.4    [SNAPPER-PRESENT]; snapper rmdir abort guard
#     Beta-v2.9.5    [GREETER-BG-PIPEFAIL]; wallpaper find pipefail guard
#     Beta-v2.9.6    [LUKS-UNLOCK-LEFT-OPEN]; unwind closes LUKS mapper; resume reuses an open one
#     Beta-v2.9.7    [BROWSER-GATE-NO]; "Set up web browsers now?" now defaults to No
#     Beta-v2.9.8    [GREETER-BG-TIMING]; lightdm greeter-bg search moved after the desktop install
#     Beta-v2.9.9    [MATE-TERMINAL];[MATE-AUDIO];[XFC-VOLUME];[LXQT-EDITOR] — DE metapackage gap fixes
#     Beta-v2.9.10   [COSMIC-GREETER-DM];[COSMIC-POLKIT] — cosmic-greeter greetd-hosted DM provisioning; COSMIC polkit agent
#     Beta-v2.9.11   [COSMIC-GREETER-LOG] — svlogd log/run for the cosmic-greeter greetd-DM stack
#     Beta-v2.9.12   [COSMIC-GREETER-USER] — greeter account is exactly `cosmic-greeter` (never `_cosmicgreeter`);
#                     the binary picks greeter-DM vs silent locker from the current username
#     Beta-v2.9.13   [ACCTSVCS-ICON];[COSMIC-POLKIT-GUARD] — default AccountsService avatar provisioned for the
#                     fresh user; the COSMIC polkit agent is launched through a session-ready guard  (current)
#     Beta-v2.9.34   [SLICK-BG-QUOTES];[SSH-DEPOSIT-LOG];[FLATPAK-NM-DISPATCH] — slick greeter quotes; ssh-key deposit via find -quit; flatpak first-boot queue moved to an NM dispatcher script; sshd + vboxdrv rc.local links realigned (sshd early)
#     Beta-v2.9.35   [ESP-SIZE] — shared ESP-size menu (4G default/6G/8G/Custom, 1GiB floor); GRUB+ENCRYPT mounts ESP AT /boot so shares it; fixed [GRUB-ESP-SIZE-ORDER] (old in-loop read ENCRYPT before its prompt)
#     Beta-v2.9.36   [CHANNEL-GROUP];[INSTALL-BREW] — third-party app channels umbrella; Homebrew (Linuxbrew) opt-in CLI/dev channel (runtime xbps deps only, never curl|bash); @linuxbrew per-user subvol row + subvol-tool `dev` class
#     Beta-v2.9.37   [GAME-LAUNCHERS];[GAME-SUBVOL] — game launchers & runtimes umbrella (Lutris/Heroic/Bottles/Wine/gamemode; Steam was earlier); Heroic+Bottles are Flatpak-only (xbps install pkg list actually NEVER contained them — they ship via the first-boot flatpak queue, gated on INSTALL_FLATPAK); the OLD `install_pkgs heroic` name never existed as a shipped line (crash #005 was a mis-labeled earlier build); ONE shared @game per-user subvol (replaces @steam) mounted at the derived per-launcher set (.local/share/Steam + .local/share/lutris) via subvol-tool multi-mount loop + @steam/gaming alias resolution + @game fstab-guard relaxation + detach/destroy BRE-paren sed fix
#     Beta-v2.9.38   [MULTI-FS] — per-region data filesystems (/home /var /var/cache /srv /opt + optional Games) carved onto their own partition with an ext4/btrfs filesystem choice; fixed-order outer carve 2..1+NREG (LINUX last), INNER GPT for ENCRYPT; region subvols folded out of the flat topology; owned fstab rows skipped; subvol-tool MULTI-FS-GUARD; region mounts before chroot; games chown; DOCS-LOG DATA_REGIONS. Plus [MULTI-FS-RUNLOG] (journal audit lines + journal archived to /etc/void-installer/installer-run.log on success) and [CRASH-USB-LOG] (crash post-mortem — journal + .info sidecar — to the first mounted stick; --save-log CLI flag parsed BEFORE the journal truncation / network gate / STAGE-1 banner so it works from a crashed, networkless live env)
#     Beta-v2.9.39   [CRASH-USB-LOG-FATAL-EXIT] — the ERR trap handles failures inside set -eEo traps, but an explicit `exit 1` FATAL never trips ERR; planned aborts (disk validation, preflight) silently skipped the USB snapshot. Keep an EXIT-trap `_save_log_on_exit` guarded by a `_usb_dumped` flag (ERR-unwind and EXIT never double-write), so a fatal exit dumps the journal too. Also fixes crash #005-reporting spurious BMP. Plus [SUBVOL-ROWS-FIX] — SUBVOL_ROWS read loop skips `#`-comment rows before the resolve eval (bad-substitution ERR-trap crash) and the spurious duplicate INSTALL_BREW SUBVOL_ROWS row is removed.
#     Beta-v2.9.40   [PKG-PREFLIGHT];[GAME-FLATPAK-GATE] — Stage-1 package-name gate (closed crash #005): every package name the Stage-2 chroot can install is resolved against the live union pool BEFORE sgdisk -Z; doomed installs abort pre-write. PKG_PREFLIGHT candidate list is a superset of every install_pkgs literal + base-bootstrap literals; live void-repo-* install + -Sy refresh + base-system sanity probe degrade to WARN+skip (never false FATAL); COSMIC third-party repo excluded; drift-guard Debug/check-pkg-preflight.sh committed. [GAME-FLATPAK-GATE]: `install_pkgs heroic`/`install_pkgs bottles` must never come back — Heroic/Bottles ship only via the first-boot Flatpak queue (com.heroicgameslauncher.hgl / com.usebottles.bottles) gated on INSTALL_FLATPAK, with a Stage-2 WARNING when INSTALL_FLATPAK=false; @game mounts ONLY .local/share/Steam + .local/share/lutris.
#     Beta-v2.9.41   (intermediate build — 98void-inner-partscan module draft; module-setup.sh + udev rules + helper script skeleton; crash #008 revealed dracut `partscan` crypttab option is NOT reliable on non-loopback LUKS2 at boot)
#     Beta-v2.9.42   (intermediate build — FATAL initramfs gate + parted shipping into the target; crash #009 showed partx -a cannot BLKPG a dm mapper, so module initially booted to emergency shell)
#     Beta-v2.9.43   [INNER-PARTSCAN-BOOT] — the boot-time partscan dracut module (98void-inner-partscan): udev RUN fires as the opened LUKS2 mapper node appears (sysfs ATTR{dm/name} match; v2.9.43/2.9.56 used ENV{DM_NAME}, which the kernel add-uevent never carries — see [INNER-PARTSCAN-UDEV-ATTR]), calling kpartx-primary / partprobe-fallback / partx-a-last helper to register the inner GPT BEFORE dracut's udev settle resolves root=UUID=<inner btrfs>; module gated on ENCRYPT=yes + carved REGION_PARTITIONED; parted shipped into the target when module installs; __CRYPT_NAME__ token baked via sed; add_dracutmodules short name in 90-system.conf; module placed BEFORE the final xbps-reconfigure
#     Beta-v2.9.44   [DRACUT-CONF-NAME] — the add_dracutmodules conf value MUST be the SHORT module name WITHOUT the numeric prefix (void-inner-partscan, NOT 98void-inner-partscan); dracut-ng resolves conf names as [0-9][0-9]<name> so a prefixed name matches nothing; same for 99void-yubikey → void-yubikey; closed crash #009 residual
#     Beta-v2.9.45   [INNER-PARTSCAN-DMPROBE] — partprobe-first inner-GPT rescan (partprobe builds libparted dm-linear submaps — the ONLY tool that can BLKPG a dm mapper; partx -a fallback only); _region_inner_partscan + _region_inner_dev named functions replace inline blocks; chroot FATAL initramfs-content gate after dracut --force loop + before ESP re-sync; per-image guard in void-limine-sync-kernels; partx -d unwind in cleanup_on_failure before luksClose; parted added to PKG_PREFLIGHT; live + resume partscan paths rewired to call the new helpers
#     Beta-v2.9.46   (post-audit from first real ENCRYPT+regions boot on <host>: [SUBVOL-TOOL-RESOLVEDEV] strip [/@] suffix from findmnt SOURCE before subvolid=5 mount + rename shadowed awk -v sub= → svpat; [INSTALL-CONFIG-FLATPAK] install-config gains INSTALL_FLATPAK/INSTALL_BRAVE public rows; KERNEL_PKGS/PKG-PREFLIGHT verification; [VBOX-SV-GUARD] first-boot vboxdrv link guarded on /etc/sv/vboxdrv dir; [FLATPAK-NM-DISPATCH-STAMP] flatpak queue dispatch check)
#     Beta-v2.9.47   [TEE-BOOT-QUIET]+[TEE-BLACKLIST] — two env-only PUBLIC limine-env knob rows (DEFAULT_QUIET_BOOT, DEFAULT_TEE_BLACKLIST, both default no) thread into a shared TEE_QB_FRAG ("quiet" + "modprobe.blacklist=tee") threaded through every GRUB/Limine BASE_CMD builder + the limine write-conf recompute; byte-identical output at defaults; existing installs untouched
#     Beta-v2.9.48   [NO-DE]/[DE-ORDER] — desktop menu reordered most-to-least popular (KDE stays option 1/defaults); option 8 = "none" (console-only / headless base). [NO-DM] — display-manager gains "none"; DM_SERVICE_NAME="none" branch + rc.local DM link guarded (no /etc/sv/none symlink). [HEADLESS] — HAS_GRAPHICAL computed from DE!=none OR DM!=none; gates the xorg/wayland base chain + audio install. [HEADLESS-XORG-OPT]/[HEADLESS-AUDIO] — on a headless box, INSTALL_XORG and INSTALL_AUDIO are explicit opt-in prompts; graphically unconditional. [DISK-BUDGET] — pre-write fit check: DISK_BYTES captured at disk-pick (lsblk, persisted for resume, fails open when unreadable); human/sgdisk size → byte conversion; sum ESP + carved regions + >=1 GiB system headroom = required; over-provisioned layout refuses before sgdisk -Z; --dry-run also fails to launch on an over-provision; ENCRYPT container=remainder identity (same math); also fixes the latent 2.9.38 REGION_*_SIZE uppercase-fold eval bug (region tokens in REGION_PARTITIONED are lowercase; without the ^^ fold the outer/inner carve read the nonexistent REGION_home_SIZE and FATAL); the KDE else branch is converted to an explicit elif so headless DE skips the metapackage.
#     Beta-v2.9.49   [VERIFY-FIXES] — post-verification corrections proven against the live as-built machine (2026-09-14): [WINE-RENAME] the game-wine prompt variable was INSTALL_GAME_WINE in the draft but INSTALL_WINE everywhere else (as-built record + recovered prompt docs) — renamed so the chroot package gate actually honors the prompt; [FLATHUB-URL-FIX] both remote-add sites (chroot install-time + first-boot rc.local fallback) now use the .flatpakrepo file (https://flathub.org/repo/flathub.flatpakrepo) instead of the bare website URL — the website 307-redirects to /en and imports no GPG key, so every queued flatpak install failed with "public key not found" (proven on real hardware); [DOCS-LOG-ASBUILT] the ~/Documents/Void_Install.txt header now reproduces the recovered real build's row set byte-format: SSH_SERVER (port + policy pointer), NVIDIA_DRIVER (GPU + wifi flag), WIFI_HARDWARE (0xVVVV:0xDDDD id), CPU (vendor + microcode pkg), HOMEBREW (deps + prefix + isolation), GAMING (enabled-launcher list, flatpak-delivered tagged, @game isolation), DATA_REGIONS (ALL SIX locations fixed-order name:fs, games only when !=none); BR0_NIC/MICROCODE_PKG rows removed to match the as-built; [FW-AUDIT-LOG-DROP] the [FW-AUDIT] accounting stays console/install-log-only — the recovered as-built record file ends at the package inventory with NO "FIRMWARE ACCOUNTING" section, so the record append was dropped to reproduce the proven build.
#     Beta-v2.9.50   [BROWSE-DIR-ACCEPT] — the browse_pick `dir` mode had NO accept action: selecting a directory (number or typed path) DESCENDED into it and bare Enter was a DECLINE, so a destination directory could never be confirmed — the Beta-v2.9.23 [SSH-KEYS] "export the keypair backup to removable media" flow ALWAYS ended "No destination chosen; skipping export." and the keys never reached the USB stick (matches the real v2.9.43 build). `!`/`ok` now accepts the CURRENT directory (returns it); bare Enter still declines; number/path navigation unchanged. `img` (wallpaper) + `file` (SSH import) modes return a FILE and are unaffected.
#     Beta-v2.9.51   [BROWSE-CAP-FIX] — the browser is called exclusively via command substitution, so its STDOUT menu/prompt lines were captured into the result value: the wallpaper pick (`img` mode) came back as the whole multi-line banner (stage `cp -f "$WP_SRC" …` FATALed), and the SSH-key export pick (`dir` mode) came back banner-prefixed so `[ -d "$_export_dst" ]` always failed ("No destination chosen; skipping export."). Even a bare-Enter DECLINE left the captured banner as a non-empty selection, so every Limine run answering the wallpaper prompt aborted. Fix: every menu/help/listing/prompt line now writes to STDERR (`>&2`); ONLY the final picked value is printed to stdout, so the `$( )` capture returns exactly the path.
#     Beta-v2.9.52   [PREREQ-DRY-RUN] — a `--dry-run` plan run skips the live-CD package sync (Beta-v2.5.1) yet still ran the [PREREQ] outer-tool gate behind it, so a minimal medium (gptfdisk not preinstalled) FATALed "required live-CD command not found: 'sgdisk'" right at the confirmation boundary, never reaching the plan printout. A plan run never partitions, so the gate — whose only job is to keep a REAL run from reaching destructive partitioning without its tools — is now skipped entirely under DRY_RUN=1.
#     Beta-v2.9.53   [HEADLESS-PLAN-LABEL] — the DRY-RUN plan's Desktop/DM line printed "headless=$HAS_GRAPHICAL" verbatim, i.e. "(headless=yes)" for a GRAPHICAL MATE/LightDM install — the label's meaning was inverted. The plan now prints "(graphical)" or "(headless)" honestly. Print-only cosmetic fix.
#     Beta-v2.9.54   [SSH-KEYGEN-STALE] — on a live medium whose /tmp persists across runs (tmpfs clears on fresh boot, but a re-run, resume, or a dry-run that exited before the stage shred leaves /tmp/ssh-keygen behind), ssh-keygen -f on the existing key prompts "Overwrite (y/n)?" and silently EATS the next answer-stream line: the keypair-backup export answer is consumed as the overwrite reply, then the export is declined by the browse-path answer. Generating means FRESH: stale id_ed25519{,.pub} are removed before keygen so it stays non-interactive. The DRY-RUN exit path now also shreds the live SSH key stage exactly like the failure/post-chroot cleanups do.
#     Beta-v2.9.55   [INNER-DEV-NAME] — the outer disk carve already checks `[[ "$DISK" =~ (nvme|mmcblk) ]]` to decide whether the base name needs a `p` separator before the partition number (nvme0n1p1 vs sda1). The inner GPT carved inside a LUKS2 mapper hardcoded `${CRYPT_DEV}p${N}` → `/dev/mapper/void-rootp1`, but dm-linear children are named without the `p` separator (void-root1, not void-rootp1) — the `p` is only for devices whose basename ends with a digit. First real install of an ENCRYPT+regions+MULTI-FS layout crashed here immediately.
#     Beta-v2.9.56   [INNER-PARTSCAN-KPARTX] — the first real ENCRYPT+regions install booted only to the dracut emergency shell REPRODUCIBLY: LUKS unlocked fine and the mapper showed PTTYPE=gpt in blkid, yet dracut looped "Scanning for all btrfs devices" and root=UUID=<inner btrfs> never resolved. Root cause: partprobe (the Beta-v2.9.45 PRIMARY BLKPG tool) silently failed to register the inner GPT on the OPENED LUKS2 mapper on this kernel/hardware — no child dm devices appeared; partx -a is confirmed unable to BLKPG a dm target ("error adding partitions 1-2" live). The only tool that works is kpartx: `kpartx -av /dev/dm-0` instantly created void-root1/void-root2 (names derive from the mapper name, matching [INNER-DEV-NAME]). Fix: kpartx -a is now PRIMARY in the boot udev RUN helper, _region_inner_partscan, AND module-setup (`require_binaries kpartx` + `inst_binary kpartx`), with partprobe then partx -a kept as ordered fallbacks for sanity; the initramfs-content gates (ESP sync guard + chroot FATAL) now also require `kpartx`; `kpartx` package added to PKG_PREFLIGHT + the module-gated install_pkgs line.
#     Beta-v2.9.57   [INNER-PARTSCAN-UDEV-ATTR] — v2.9.56's boot udev RUN rule still NEVER fired, so the box hit the same emergency shell even with kpartx in the image: the rule matched ENV{DM_NAME}=="void-root", but the kernel's dm add-uevent carries NO DM_NAME (libdevmapper writes that key into the udev db later, AFTER udev rules have already evaluated) — an ENV{DM_NAME} predicate can never match at rule time, which explains BOTH the 2.9.45 "partprobe silently did nothing" AND the 2.9.56 "kpartx still didn't help": the RUN helper never ran. Empirically proven on the NVMe box (udevadm monitor: add uevent for dm-0 has only ACTION/DEVNAME/DEVPATH/DEVTYPE/DISKSEQ/MAJOR/MINOR/SEQNUM/SUBSYSTEM; DM_NAME appears only on the later UDEV-processed record). Fix: match `KERNEL=="dm-*", ATTR{dm/name}=="__CRYPT_NAME__"` — the device-mapper name IS exposed in sysfs (/sys/block/dm-0/dm/name) at add-time. Live-proof: a udev rule with that predicate fired the RUN helper and kpartx instantly mapped void-root1/void-root2 on luksOpen. Rule line now: ACTION=="add", SUBSYSTEM=="block", KERNEL=="dm-*", ATTR{dm/name}=="__CRYPT_NAME__", RUN+="/path". No other script logic changes (helper + module-setup + gates untouched).
#     Beta-v2.9.58   [HOME-SELF-CHOWN] — the v2.9.57 boot udev fix got the box past the dracut emergency shell and INTO the LightDM greeter — and the greeter then REPRODUCIBLY bounced EVERY login (the correct password hash-verified, yet the greeter grey-bounced "Incorrect password" every time) because the account HOME DIRECTORY ITSELF was left root-owned. `useradd -m` creates /home/$TARGET_USER as root:root mode 755, and the installer's adopt-own chown pass covered ONLY the home SUBdirectories (~/Games, ~/.config, ~/.local, ~/.cache, ~/Documents, ...) — NEVER /home/$TARGET_USER itself. On a carved/adopted @home the home dir stays root-owned, so the fresh MATE/COSMIC/KDE account cannot write .Xauthority/.dmrc/.xsession-errors at greeter time → X auth fails → mate-session "Cannot open display" exits in ~0.02s (lightdm.log "Exited with return value 1") → the greeter bounces the CORRECT password back as a grey "wrong password" loop. Root cause is UNIVERSAL to every greeter (LightDM GTK/Slick, greetd/cosmic-greeter, SDDM, GDM) and every DE (MATE, COSMIC, KDE): the auth/session path needs a WRITABLE HOME DIR, not just writable subdirs — so the fix belongs in ACCOUNT PROVISIONING, not any greeter: `chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}"` is now executed IMMEDIATELY after useradd (mirroring the existing ~/Games + .cache/@containers-user adopt-own pattern). Proven on the live box (<host>): chowning the home tree to numeric uid 1000 made the SAME test password (previously grey-bounced) MATE login succeed with ZERO greeter/session/config changes. The separate cosmic-greeter `_cosmicgreeter`-vs-`cosmic-greeter` username-dispatch packaging bug is a DIFFERENT, greeter-specific issue — do NOT fold this fix into [COSMIC-GREETER] logic; the account-provisioning chown is universal and must stay in the account stage.
#     Beta-v2.9.59   [LOCAL-CACHE] — optional reuse of a pre-seeded XBPS package cache on an
#                     attached medium (mklive/void-live layout <mount>/xbps-cachedir-<arch>, e.g. the
#                     Void_Linux_Live build cache on the same USB stick) so the live-CD sync, base
#                     bootstrap, and every chroot install take packages from disk instead of the mirror
#                     (mirrors remain the per-package fallback). DEFAULT_LOCAL_CACHE=no (network-only
#                     baseline, mirroring [BROWSER-GATE-NO] posture); auto-detect newest-touched writable
#                     arch-matching dir with real .xbps files, or accept a typed absolute path. -c is
#                     threaded via $LOCAL_CA into the live sync + bootstrap and — through a bind mount of
#                     the media cache at /mnt/tmp/xbps-cache (= /tmp/xbps-cache in the chroot, via
#                     chroot_env.sh's REMAPPED LOCAL_CACHE_DIR) + the chroot-wide ${_xbps_cache[@]} array —
#                     into install_pkgs() and install_cosmic(). Cache dir MUST be writable (-Sy repodata +
#                     COSMIC index write into it); read-only/undetected degrades to network-only, never a
#                     FATAL. Resume: LOCAL_CACHE_REUSE/LOCAL_CACHE_DIR persist to the state file and the
#                     recorded path is re-validated (re-detected if the stick remounted elsewhere) before
#                     the sync; install-config records the flag only (the path is media-scoped, meaningless
#                     post-install). Untouched by this feature: the PKG-PREFLIGHT gate (stays mirror-truthful).
#     Beta-v2.9.61   [LOCAL-CACHE-ROOT] — the [LOCAL-CACHE] detector globs only /run/media/*/xbps-cachedir-*;
#                     a --persist + --seed-cache Void_Linux_Live stick (voidlive-build-persist.sh) puts the
#                     seeded cache at the ROOT of its VOID_OVL overlay, so on the booted live system it sits
#                     at /xbps-cachedir-<arch> (writable persistence layer, arch-matched, real .xbps) — nowhere
#                     near /run/media, hence never auto-detected. The detect glob list now also probes
#                     /xbps-cachedir-* (a no-op on ordinary non-persistent boots; seeded persist sticks
#                     auto-detect and the prompt answer stays a plain Y).
#     Beta-v2.9.62   [LOCAL-CACHE-DEPTH] — the [LOCAL-CACHE] detector's /run/media glob matched only
#                     /run/media/*/xbps-cachedir-* (ONE level), but udisks mounts a labeled/unlabeled data
#                     stick at /run/media/<user>/<uuid> (TWO levels), so the very layout this feature was
#                     built for escaped auto-detection and fell back to the typed-path prompt. The glob list
#                     now also probes /run/media/*/*/xbps-cachedir-* — the real-world udisks "-<uuid>" mount
#                     — alongside the one-level layout and the live-root seed; depth-1+2 write into system
#                     dirs in orders of the token newest-touched = first wins rule remains.
#     Beta-v2.9.63   [LOCAL-CACHE-ERR] — the detect pipe fed by <(ls -1dt <globs> 2>/dev/null) can exit 2: when
#                     ANY of the three globs matches nothing it is left LITERAL and ls reports it as a
#                     missing operand, so a detecting run that still FOUND the cache returns 2 anyway. Under
#                     the script's set -eE + trap ERR, that status fired cleanup_on_failure INSIDE the
#                     $( _local_cache_detect || true ) subshell and crashed every run at the cache prompt
#                     ("Install failed (exit 2)" / failing command: the ls glob), even though the cache was
#                     found and printed. Add `|| true` inside the process substitution so a no-match glob can
#                     never propagate a non-zero status (matches the Void_Linux_Live _cache_detect form).
#     Beta-v2.9.64   [PARTSCAN-HOST-COPY] — dracut's udev-rule scan resolves RUN= programs against the BUILD
#                     HOST root, not $moddir; the partscan rule points at /usr/bin/void-inner-partscan.sh, a
#                     path that only exists inside the module at build time, so every initramfs build logged
#                     "Skipping program /usr/bin/void-inner-partscan.sh ... as it cannot be found" (cosmetic —
#                     inst_script embeds it regardless). The installer now also materializes the helper at
#                     the target's /usr/bin so the scan resolves it, the dinfo disappears on kernel updates,
#                     and a debuggable copy stays on the installed system.
#     Beta-v2.9.65   [HOME-CACHE-CHOWN] — on a carved-home [MULTI-FS] install the browser-subvol prep's
#                     `mkdir -p ~/.cache` (root :root 0755) was never chowned, because the ONLY ~/.cache
#                     chown in the script lives in the @usercache branch; a root-owned ~/.cache silently
#                     blanked the graphical desktop on first boot — ksycoca/AppStream/mesa all hit
#                     "Permission denied" on ~/.cache (empty KDE app launcher + panel) and firefox died on
#                     ~/.cache/mozilla. The carved branch now chowns ~/.cache to $TARGET_USER + chmod 700,
#                     byte-matching the @usercache branch. Proven on <host> (carved ENCRYPT /home, KDE,
#                     Beta-v2.9.13); the fix was applied live to the installed box (chown -R 1000:1000 +
#                     chmod 700 restored ksycoca + firefox with no other changes).
#     Beta-v2.9.66   [MULTI-FS-FS-EVAL] — the three mkfs/mount/fstab region loops resolved each carved
#                     region's filesystem with `eval "_rr_fs=\${REGION_${_rr}_FS:-btrfs}"` using the RAW
#                     lowercase REGION_PARTITIONED token, so `home` read the never-existent `REGION_home_FS`
#                     (bash vars are case-sensitive) and EVERY carved region silently fell back to btrfs —
#                     the v2.9.48 [DISK-BUDGET] `^^` fold fixed the SIZE evals but MISSED the _FS evals.
#                     `games` broke even that contract: its choice lives in `REGION_GAMES` (no `_FS`).
#                     Proven live (<host>, carved ENCRYPT /home + /home/<user>/Games): the prompt + install-config
#                     recorded home=ext4 games=ext4 while the run-log mkfs, /etc/fstab and blkid all show
#                     btrfs. Fix: `_region_fs_of` helper (uppercases the token, special-cases `games`;
#                     near `_region_carved`) feeds all three loops; the installed void-subvol-tool's runtime
#                     `region_fs()` gets the same fold + games case + quote-strip so the carved-region guard
#                     actually fires. Also removed a stutter that double-printed the microcode pkg in the
#                     [DOCS-LOG] CPU= line.
#     Beta-v2.9.67   [KEYMAP-CMDLINE] — the ENCRYPT branch baked the [KEYMAP] initrd parameter as a BARE
#                     `rd.vconsole.keymap=<k>` line appended to /etc/dracut.conf.d/90-system.conf, but dracut
#                     SOURCES every conf file with bash — a dotted bare assignment is not valid shell, so bash
#                     executed the line as a command and EVERY dracut run logged `rd.vconsole.keymap=us:
#                     command not found` (3x per install, once per kernel image). Worse, the parameter was
#                     therefore NEVER baked into the initramfs: the [KEYMAP] feature (Beta-v2.6.9) silently
#                     did nothing and the early LUKS passphrase prompt kept the kernel's built-in US map.
#                     Fix: emit `kernel_cmdline="rd.vconsole.keymap=<k>"` — the dracut-native form
#                     (man dracut.conf: "only sets initrd parameters"), which is shell-valid AND actually
#                     lands the parameter (covers both bootloaders via the shared 90-system.conf).
#     Beta-v2.9.68   [PARTUUID-NODEPS]/[INSTALL-CONFIG-BACKENDS]/[INSTALL-CONFIG-SSHKEY]/[FLATPAK-DNS-LATE]
#                     — four post-install-review fixes. (1) `lsblk -no PARTUUID "$dev"` DESCENDS into
#                     children, so under ENCRYPT+regions (PART_SYS = the LUKS container) it captured the
#                     inner void1/2/3 PARTUUIDs too and wrote a malformed multi-line SYSPREFIX_BTRFS into
#                     limine-env/chroot_env (`--nodeps` now pins the named partition). (2) install-config
#                     never recorded INSTALL_STEAM/DOCKER/PODMAN_* or the PROVISION_*_SUBVOL rows, so a
#                     box with steam+podman installed and @containers mounted had no config row to
#                     explain it. (3) SSH_KEY_COMMENT/SSH_KEY_PROTECTED were exported from their prompt
#                     defaults unconditionally, so install-config advertised a key even when none was
#                     imported/generated — now gated on the real ~/.ssh deposit (SSH_KEY_PRESENT). (4)
#                     the flatpak NM dispatcher armed only on up/vpn-up; when the first `up` beat DNS it
#                     left the queue unstamped with no retry, so it now also arms on connectivity-change.
#     Beta-v2.9.69   [FLATPAK-NM-DISPATCH-LOCK] — the Beta-v2.9.68 premise that "`up` does not fire
#                     again on a stable link" is FALSE (observed live on <host>: five pre-lock
#                     dispatcher firings in ~30 min piled five concurrent `flatpak install` processes
#                     racing the same OSTree repo, none completing on a ~120KB/s link). The dispatcher
#                     now serializes the drain behind an exclusive flock
#                     (`exec 9>/var/lock/flatpak-firstboot.lock ; flock -n 9 || exit 0`): burst events
#                     (up/vpn-up/connectivity-change back-to-back) collapse to one running drain, the
#                     losers bail and re-arm on the next network event, and a completed run still
#                     leaves the .done stamp (flock is released automatically on exit).
#     Beta-v2.9.70   [ELOGIND-NO-STRAY-KILL] — the cosmic-greeter /etc/sv/cosmic-greeter/run
#                     "stray elogind PID sweep" (kill any pgrep'd elogind/elogind-daemon whose
#                     pid differs from /var/service/elogind/supervise/pid) is REMOVED. Proven on
#                     <host> that on a live box Void's elogind is a single daemonized
#                     `elogind-daemon` reparented to PID 1 (pgrep -x 'elogind' matches nothing;
#                     pgrep -x 'elogind-daemon' returns exactly the serving daemon), so the
#                     supervise/pid exception never equals it and the sweep killed the LIVE
#                     logind — seat/session/run-user vanish -> desktop hang (the observed
#                     "you killed an elogind pid" incident). elogind is single-instance by
#                     design (a duplicate cannot bind org.freedesktop.login1), so no killable
#                     stray exists; `sv check elogind` is the only gate the greeter run script
#                     needs (runit restarts a dead one itself).
#     Beta-v2.9.71   [STEAM-32BIT] — a fresh Steam install only saw the client bootstrap and
#                     hit "missing 32-Bit libraries libGL.so.1 & libdrm.so.2" on first launch,
#                     because Void's `steam` package ships NO 32-bit runtime deps and the
#                     installer's `install_pkgs steam` alone left the multilib GL stack absent.
#                     The Steam branch now also installs the canonical 32-bit runtime set
#                     (libgcc/libstdc++/libglvnd/mesa-dri/libdrm plus the X11/xcb/fontconfig/
#                     pulseaudio -32bit libs), gated STRICTLY on INSTALL_STEAM=true — no new
#                     prompt, nothing 32-bit ships unless the user opts into Steam at install
#                     time. All new names added to PKG_PREFLIGHT (a validation-only list that
#                     installs nothing by itself).
#     Beta-v2.9.72   [GAME-VULKAN] — a fresh install ships only virtio_icd-ish Vulkan ICDs,
#                     so every real GPU returns VK_ERROR_INCOMPATIBLE_DRIVER (-9) when a game
#                     stack probes Vulkan (proven live: right after the [STEAM-32BIT] GLX fix,
#                     Steam's Vulkan topology probe still failed -9 and 32-bit game libs had
#                     no radeonsi ICD). The [INSTALL-APPS] block now installs the DETECTED GPU
#                     family's Mesa Vulkan driver (mesa-vulkan-radeon|intel|nouveau, 64-bit +
#                     -32bit each) whenever INSTALL_ANY_GAME=true (Steam ∨ Lutris ∨ Heroic ∨
#                     Bottles) — gated on the live-box probe (HAS_AMD_GPU / HAS_INTEL_GPU /
#                     HAS_NVIDIA_GPU), no new prompt; NVIDIA's proprietary driver ships its
#                     own ICD, so nouveau is only pulled when the user declined INSTALL_NVIDIA.
#                     All six names added to PKG_PREFLIGHT.
#     Beta-v2.9.74   [USB-AUTOMOUNT] — COSMIC selection previously shipped
#                     no removable-media automounter: no udisksd service was
#                     linked (Void's udisks2 ships only a D-Bus activation
#                     unit) and udiskie was absent. The COSMIC DE branch now
#                     installs udiskie and autostarts it through a session-
#                     readiness guard; /etc/sv/udisksd is created and linked
#                     at first boot like any base service.
#     Beta-v2.9.75   [XKB-CONFIG-QUOTING] — the cosmic-desktop-full xbps
#                     post-install hook corrupts
#                     /usr/share/cosmic/com.system76.CosmicComp/v1/xkb_config
#                     to `layout: ""us"",` (quotes kept from KEYMAP="us"
#                     via cut+sed), invalid RON -> cosmic-comp config parse
#                     fails -> cosmic-greeter-daemon crash-loop -> grey
#                     blinking login screen. The COSMIC DE branch now
#                     rewrites the file to the canonical cosmic-config form
#                     with the layout taken UNQUOTED from the chroot's
#                     /etc/rc.conf KEYMAP.
#     Beta-v2.9.83   [COSMIC-REPO-ATTRIBUTION] — the DE menu (option 7), the
#                     ARCHITECTURE SUMMARY and install_cosmic()'s own header
#                     comment all named a third-party packaging fork
#                     (its own git host / its own package host)
#                     as the COSMIC source, but the URL this installer has
#                     actually added since Beta-v2.9.73 is
#                     https://bluesloth.github.io/void-linux-cosmic/ (audit:
#                     github.com/bluesloth/void-linux-cosmic) — signed and
#                     published by the companion Void_Linux_Cosmic packager
#                     project, whose COSMIC templates are built from scratch.
#                     So the warning told the operator to audit a DIFFERENT
#                     repo than the one being trusted, one comment still
#                     claimed github.io "serves a web page, not an xbps
#                     index" (the reverse of what is true today), and another
#                     still called the key "whatever the maintainer publishes"
#                     (superseded by 2.9.76's pin). Menu + comments now name
#                     the real repo, its audit link, its lineage and the pin;
#                     pre-2.9.73 CHANGELOG entries stay as history. Text-only:
#                     `_cosmic_repo`, `_cosmic_audit`, the pin and every code
#                     path are untouched.
#                     SCRIPT_VERSION bumped Beta-v2.9.82 -> Beta-v2.9.83.
#     Beta-v2.9.84   [COSMIC-STORE];[FLATPAK-PULL-DETECT] — cosmic-store
#                     (the COSMIC app store, bluesloth repo) hard run-depends
#                     on flatpak, but the installer never installed it and the
#                     prompt gate INTENTIONALLY preconditioned INSTALL_FLATPAK
#                     — an opt-out of Flatpak had no store to drag it back in.
#                     Two layers, matching the decided design:
#                     (1) [COSMIC-STORE] a real opt-in prompt
#                     INSTALL_COSMIC_STORE (default NO), offered ONLY when
#                     INSTALL_FLATPAK=true (any desktop — the store is a
#                     Flathub GUI, not cosmic-only), resolved into a boolean,
#                     threaded through resume-state, chroot_env and
#                     install-config, and installed DE-independently at the
#                     flatpak-gated deliveries site via install_cosmic()
#                     (bluesloth repo, pinned-key path) with a Stage-2
#                     flatpak re-check mirroring the Brave rule — store
#                     implies flatpak is therefore structural; a stale resume
#                     state carrying store=yes && flatpak=no WARNs and skips
#                     instead of pulling flatpak in.
#                     (2) [FLATPAK-PULL-DETECT] a Stage-2 safety net for the
#                     paths the toggle cannot govern: if flatpak is DECLINED
#                     but shows up installed anyway (a future metapackage rev
#                     pulling it, or a manual install), the install warns
#                     loudly and records FLATPAK_PULLED_BY="<reverse deps>"
#                     (xbps-query -X flatpak) in install-config — the note's
#                     "never let the store pull flatpak past an explicit
#                     opt-out without surfacing it" rule, enforced even when
#                     nobody's prompt was involved.
#     Beta-v2.9.85   [NIC-DETECT-USB] — the Stage-1 [NIC-DETECT] review's
#                     USB fallback globbed /sys/devices/*/net/* — bash `*`
#                     never crosses a `/`, so it only ever matched
#                     /sys/devices/virtual/net/* (lo/br0/docker0/virbr0),
#                     all of which fail the usb-subsystem test: dead code
#                     that could never find a real USB network device (whose
#                     net dir sits ~6 levels deep, e.g.
#                     .../usb2/2-1/2-1.1/2-1.1:1.0/net/<iface>). A
#                     physically-present-but-unplugged USB ethernet adapter
#                     (the documented "cable optional" promise) was therefore
#                     always reported "(none detected)" and recorded
#                     BR0_NIC=<unset> — live on the round-10 box (ASIX
#                     AX88179 in the machine, install-config says <unset>).
#                     The INSTALL_VIRT late re-probe's fallback
#                     (readlink -f device ~ *usb*) was correct, so the
#                     br0-slave binding never suffered — but the two probe
#                     sites could disagree. Both now call one shared
#                     detect_wired_nic() helper (carrier-active physical
#                     wired NIC first, then any physically-present USB
#                     device, cable irrelevant), defined at unconditional
#                     top level above the resume guard — 2.9.78's
#                     _region_fs_of lesson. Protection sets merged: physical
#                     `device` link + no `wireless` dir + name skip list
#                     (the old carrier loop had NO physical check; the
#                     re-probe gains the name skip, so a Bluetooth-USB netdev
#                     can no longer qualify as a "USB NIC"). No prompt,
#                     defaults or package surface changed.
#                     SCRIPT_VERSION bumped Beta-v2.9.84 -> Beta-v2.9.85.
#     Beta-v2.9.86   [BR0-SKIP] — skip the whole br0 bridge when the machine
#                     has NO physical wired NIC at all (pure-Wi-Fi/WWAN box).
#                     INSTALL_VIRT used to write br0 + a role-matched
#                     br0-slave unconditionally: on a wired-less machine the
#                     bridge could never have a member (DHCP loop, dead
#                     weight), the free-roaming slave would adopt whatever
#                     USB NIC / tethering phone appeared later, and rc.local
#                     STILL force-killed virbr0 on first boot — so the
#                     "bridged" virt build landed with ZERO VM networking
#                     (the round-10 topology: BR0_NIC=<unset>, enp*
#                     placeholder, br0 with no member). The skip trigger is a
#                     new has_wired_nic_hw() hardware-presence predicate
#                     (physical `device` link + no `wireless` dir + name skip
#                     list; carrier/USB irrelevant), NOT detect_wired_nic()'s
#                     result — an unplugged built-in PCIe port still keeps
#                     the role-matched slave, so a cable plugged in later
#                     just works (2.9.85's helper stays the selector). An
#                     EMPTY NET_INTERFACE_MATCH is the explicit skip signal,
#                     already threaded through resume state + chroot_env: it
#                     gates the Stage-2 profile pair, qemu's bridge.conf
#                     allow, and a new install-config VIRT_BR0 row (created /
#                     skipped / n/a). rc.local now tears down virbr0 only
#                     when the br0 profile file exists (disk-state check, no
#                     NM timing) — virbr0 stays ENABLED as the VM-networking
#                     fallback, and [NFT-VIRT-GATE]'s virbr* forward accepts
#                     already cover it firewall-side. NOTICEs at the virt
#                     block, the re-probe and the write site announce the
#                     outcome (auto-skip, no new prompt). No prompt,
#                     DEFAULT_* or package surface changed.
#                     SCRIPT_VERSION bumped Beta-v2.9.85 -> Beta-v2.9.86.
#     Beta-v2.9.89   [SMART-BASELINE] — smartmontools now ships on EVERY
#                     install regardless of DE / greeter / profile: the
#                     unconditional roll-up line gains it, so a SMART health
#                     baseline (`smartctl -a`) exists on day one and later
#                     checks always have a known-good reference. Health
#                     monitoring is baseline-concern, not a DE/greeter concern
#                     (found: the audit box's 1 TB NVMe reported HEALTH
#                     PASSED with 0 media-integrity errors only because the
#                     operator had installed the package by hand). The smartd
#                     daemon stays unenabled by default — an operator choice.
#                     This ADDS a package to the always-on surface (code
#                     change, not text-only): smartmontools also joins
#                     PKG_PREFLIGHT (the stage-1 validation-only superset
#                     list) per the [PKG-PREFLIGHT] drift-guard rule.
#                     SCRIPT_VERSION bumped Beta-v2.9.88 -> Beta-v2.9.89.
#     Beta-v2.9.90   [COSMIC-PPD] — COSMIC's cosmic-settings hard-depends on
#                     power-profiles-daemon (D-Bus net.hadess.PowerProfiles),
#                     but the daemon never ran because nothing linked its
#                     runit service, so the DE's powermode picker showed
#                     "Backend not found" while tlp (laptop profile) managed
#                     power behind its back — two competing power managers
#                     is a documented conflict. The Stage-1 resolution now
#                     derives POWER_PPD=true for EVERY COSMIC build and
#                     suppresses tlp on COSMIC laptops (PROFILE_TLP=false);
#                     cosmic builds install + first-boot-link PPD. Scope is
#                     COSMIC-only — all other DEs keep the existing tlp
#                     laptop behavior. Proven on the reference install (AMD
#                     Ryzen laptop): PPD drives quiet/balanced/performance
#                     through amd_pstate + the firmware platform_profile;
#                     tlp removed.
#                     SCRIPT_VERSION bumped Beta-v2.9.89 -> Beta-v2.9.90.
#     Beta-v2.9.87   [COSMIC-REPO-MOVE] — the COSMIC artifact repository is
#                     now served from the unified Void_Linux_Cosmic project
#                     (packaging templates + signed binary repo in one place):
#                     _cosmic_repo/_cosmic_repodata/_cosmic_audit point at
#                     https://bluesloth.github.io/void-linux-cosmic/ (audit:
#                     https://github.com/bluesloth/void-linux-cosmic), served
#                     from the repository root. The PINNED signing key
#                     (_cosmic_key_expected = 83ffd154…) is UNCHANGED, so the
#                     machine-checked trust anchor and its allowlist behave
#                     exactly as before — only the served location moved.
#                     Text-only: no code path, prompt, DEFAULT_* or package
#                     surface changed.
#                     SCRIPT_VERSION bumped Beta-v2.9.86 -> Beta-v2.9.87.
#     Beta-v2.9.82   [COSMIC-KEY-AUTOIMPORT] — the COSMIC repo sync still
#                     stopped at "Do you want to import this public key?
#                     [Y/n]" even though the desktop menu already discloses
#                     COSMIC as a third-party repo ("a signing-trust choice
#                     made at your own risk") and Beta-v2.9.76 already PINNED
#                     the key and machine-verifies it immediately after the
#                     sync. Re-verified 2026-10-07 on xbps 0.60.7 that -y
#                     never covered this question (-S and -Sy both stop at
#                     [Y/n]), so the prompt is now answered by the installer
#                     on a PIPE of its own (`printf 'y\n' | xbps-install ...
#                     -Sy`), and 2.9.77's /dev/tty gate — which existed only
#                     to feed that answer and refused every unattended /
#                     headless COSMIC install — is gone. Trust is unchanged:
#                     the pinned-fingerprint + allowlist check below still
#                     aborts on any key that is not ours, prompt or no prompt.
#                     SCRIPT_VERSION bumped Beta-v2.9.81 -> Beta-v2.9.82.
#     Beta-v2.9.81   [SSH-KEYGEN-NONINTERACTIVE] — the generate-key branch
#                     built the -N flag as ${SSH_KEY_PASSPHRASE:+-N ...}, so
#                     answering "n" at "Protect the key with a passphrase?"
#                     omitted -N ENTIRELY. Omitting -N does not mean "no
#                     passphrase", it means "prompt me" — so ssh-keygen still
#                     asked "Enter passphrase for "…/id_ed25519" (empty for no
#                     passphrase)" (and fired ksshaskpass wherever SSH_ASKPASS
#                     is set) after the operator had already said no. That
#                     stray read is also a stream hazard of the 2.9.54
#                     [SSH-KEYGEN-STALE] class: the next answer-stream line is
#                     consumed as the passphrase, desyncing the export prompt.
#                     -N is now ALWAYS passed, with "" for the unprotected
#                     case — `-N ""` is ssh-keygen's documented "no
#                     passphrase, do not ask" form. SCRIPT_VERSION bumped
#                     Beta-v2.9.80 -> Beta-v2.9.81.
#     Beta-v2.9.80   [MIRROR-SKEW-GUARD] — upstream Void mirror rotation can
#                     transiently desync: the repodata index still lists an
#                     OLD package version whose files the pool has just
#                     rotated away (2026-10-07: `runc` 1.5.1_1 -> 1.5.2_1;
#                     every official tier indexed 1.5.1_1 while the pool
#                     carried only 1.5.2_1, so the 3-mirror fallback failed
#                     identically — xbps resolved 1.5.1_1 and 404'd its
#                     .sig mid-transaction -> FATAL podman). Fix, 3 layers:
#                     (1) all three mirror rotations gain tertiary region
#                     fallbacks (repo-de, tuna) that rotate on their own
#                     schedule; (2) install_pkgs() detects the "failed to
#                     download <pkg> signature ... Not Found" class and
#                     retries the full rotation with 15/30/45s backoff
#                     before FATAL (non-skew failures still FAIL fast);
#                     (3) Stage-1 PKG-PREFLIGHT gains a per-mirror -M
#                     memory-sync consistency probe that promotes the first
#                     consistent mirror to REPO_PRIMARY pre-write, and
#                     WARN+continues when all are torn (never a pre-write
#                     FATAL for a transient). SCRIPT_VERSION bumped
#                     Beta-v2.9.79 -> Beta-v2.9.80.
#     Beta-v2.9.79   [XKB-CONFIG-CREATE] — the 2.9.75 [XKB-CONFIG-QUOTING]
#                     repair was gated on `[ -f "$_xkb_conf" ]`, so it could
#                     only REPAIR a corrupt xkb_config, never CREATE a missing
#                     one. No package ships that file; only the
#                     cosmic-desktop-full post-install hook creates it, and on
#                     the <host> 2026-10-05 resumed install it did not complete,
#                     so the file was ABSENT. That is fatal: cosmic-comp then
#                     reports no xkb config -> cosmic-greeter
#                     UserData.xkb_config_opt is None -> Common::update_user_data
#                     skips the whole active_layouts fill (common.rs:203-208)
#                     -> the keyboard-layout button indexes an empty vec at
#                     greeter.rs:590 and the greeter PANICS ("index out of
#                     bounds: the len is 0 but the index is 0") -> greetd loops
#                     "greeter exited without creating a session" every ~1.6s
#                     -> unbootable desktop, no login, no VT switch, plus a
#                     65 MB cosmic-osk "Broken pipe" svlogd flood per boot.
#                     The COSMIC DE branch now ENSURES the file (create when
#                     missing, rewrite when the layout differs) instead of
#                     depending on the packager's hook, and extracts KEYMAP
#                     unquoted-or-quoted so a bare `KEYMAP=de` from the live
#                     ISO no longer silently falls back to "us".
#                     SCRIPT_VERSION bumped Beta-v2.9.78 -> Beta-v2.9.79.
#     Beta-v2.9.78   [MULTI-FS-RESUME-HELPER] — `_region_fs_of()` and
#                     `_region_carved()` were defined INSIDE the
#                     "skipped-on-resume interactive configuration" block
#                     (the `if [ "$RESUME" != "1" ]` section around
#                     old line ~4377-4522), but the region-mount / fstab
#                     loops that call them do NOT run inside that block —
#                     they run on every path including resume. On a `-r`
#                     resume the helpers were therefore undefined and the
#                     mount loop died with `_region_fs_of`: command not
#                     found (exit 127 from the `$(...)`). Definitions moved
#                     to unconditional top-level scope (above the RESUME
#                     guard). `bash -n` clean, check-heredocs ALL CLEAN,
#                     check-defaults ALL CONSISTENT.
#     Beta-v2.9.77   [COSMIC-TRUST-ANCHOR-TTY] — the 2.9.76 trust-anchor
#                     gate probed stdin with [ ! -t 0 ], but Stage 2 chroots
#                     feed the script via `chroot /mnt /bin/bash << 'CHROOT_EOF'`,
#                     so stdin is always the heredoc and the gate aborted EVERY
#                     COSMIC install before xbps could prompt. The gate now
#                     probes the real terminal (/dev/tty, bind-mounted with /dev)
#                     and xbps-install's key-import prompt reads from /dev/tty.
#                     Verified live: the COSMIC repo now serves exactly the
#                     pinned key (DER SHA-256 matches _cosmic_key_expected), so
#                     the anchor check passes once the operator confirms.
#     Beta-v2.9.76   [COSMIC-TRUST-ANCHOR] — the COSMIC repo sync passed -y,
#                     which xbps documents as "assume yes to ALL questions",
#                     including the repo signing-key import. The trust anchor
#                     was auto-accepted and no operator ever saw a
#                     fingerprint, so a substituted key was trusted silently.
#                     -y is now absent from that sync (the -y on the later
#                     package install is unrelated and stays), the expected
#                     fingerprint is printed, and an unattended run refuses up
#                     front instead of hanging or auto-accepting.
#                     Prompting alone is not enforcement — an operator who
#                     types 'Y' at a prompt showing a substituted key still
#                     trusts it — so the fingerprint is now PINNED IN THIS
#                     SCRIPT and verified machine-readably after the sync:
#                     the pinned key must be present in /var/db/xbps/keys, and
#                     no key outside {pinned, two stock Void keys} may be.
#                     That second rule is an allowlist, not "nothing else":
#                     a provisioned Void system already trusts both stock keys,
#                     so rejecting them would abort every legitimate install.
#                     The pin is deliberately not read from the repo being
#                     verified — a fingerprint taken from the served index only
#                     proves the index is self-consistent. Unreadable keyring
#                     entries now fail closed instead of being skipped.
#                     CONSEQUENCE: until the repo is republished under the new
#                     key this check ABORTS, because the live index still
#                     serves the old one. Fail-closed by design.
#     Beta-v2.9.73   [ELOGIND-RUN-SELFHEAL] — Void's elogind daemonizes
#                     itself, so the stock /etc/sv/elogind/run `exec`s a child
#                     that exits immediately and runsv respawns ~1x/sec forever
#                     (kernel-log flood of "elogind is already running").
#                     Ships /root/tools/elogind.run.fixed (wait-on-pidfile run
#                     script) + /root/tools/re-fix-elogind-run.sh, applies the
#                     fix at install time (SESSION_STACK=elogind), and calls the
#                     restorer from /etc/rc.local every boot (same pattern as
#                     re-shadow-xbps.sh) since the elogind package owns the run
#                     script and upgrades overwrite it.
#
# When bumping SCRIPT_VERSION, add a row to this table (and a CHANGELOG.md
# entry) so the reconstruction stays complete for the next reader.
# =============================================================================

# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.7.2 [PROMPT-DEFAULTS]: EDITABLE DEFAULT
# ANSWERS. The interactive prompts below fall back to these values on a bare
# Enter instead of hardcoded defaults, so you can change what a "just press
# Enter" run picks without hunting through the prompt loops. Override any of
# them at runtime by exporting the same name before running the script
# (e.g. DEFAULT_DESKTOP=7 ./Void_Linux_Installer.sh). A resumed run re-sources
# the saved state file AFTER this block, so an interrupted install keeps its
# original answers — these only affect a fresh run (or an empty input).
#
# Numeric-choice defaults use the menu's 1-based index shown in the prompt.
# Yes/no toggle defaults are literal true/false (the prompt hints only show
# which is today's built-in polarity; the actual default is this value).
# =============================================================================
DEFAULT_LOGIN_SHELL="${DEFAULT_LOGIN_SHELL:-1}"       # 1=bash 2=zsh 3=fish 4=mksh
# AI (Big Pickle) ADDITION — Beta-v2.9.48 [NO-DE]/[DE-ORDER]: the desktop menu
# is reordered most->least popular (KDE stays option 1 / the bare-Enter
# default) and gains option 8 = `none` (console-only / headless base). A
# headless choice is a *graphics* decision, not a seat one — the DM and the
# xorg/audio opt-ins below still let a server box keep its X/Wayland base.
# The menu index 8 is only offered when the DM `none` option is also there,
# so DEFAULT_DESKTOP stays a plain 1-based menu index.
DEFAULT_DESKTOP="${DEFAULT_DESKTOP:-1}"               # 1=kde 2=gnome 3=cinnamon 4=xfce 5=mate 6=lxqt 7=cosmic 8=none
# AI (Big Pickle) ADDITION — Beta-v2.9.48 [HEADLESS]: two opt-in toggles shown
# ONLY when the fully-headless combination was chosen (DESKTOP_ENV=none AND
# DISPLAY_MANAGER=none → HAS_GRAPHICAL=no). They let a server keep the
# Xorg/Wayland base for a later startx / remote-X (INSTALL_XORG) or install
# the PipeWire audio stack (INSTALL_AUDIO) without flipping HAS_GRAPHICAL —
# the xorg/wayland base chain stays gated on the flag so a `none` answer
# still yields a lean, dependency-light server.
DEFAULT_XORG="${DEFAULT_XORG:-false}"                 # keep Xorg/Wayland base on a headless box? [y/N]
DEFAULT_AUDIO="${DEFAULT_AUDIO:-false}"               # audio stack on a headless box? [y/N]
DEFAULT_SESSION_STACK="${DEFAULT_SESSION_STACK:-1}"   # 1=elogind 2=turnstile
DEFAULT_BOOTLOADER="${DEFAULT_BOOTLOADER:-1}"         # 1=limine 2=grub
# AI (Big Pickle) ADDITION — Beta-v2.9.35 [ESP-SIZE]: the EFI ESP size is a
# prompt-time decision (Limine esp-copy mirrors every kernel/snapshot onto the
# ESP; GRUB+ENCRYPT mounts the ESP AT /boot). Menu index 1-4, default 1=4G;
# plain GRUB never shows it (fixed 1G at /boot/efi).
DEFAULT_EFI_ESP_SIZE="${DEFAULT_EFI_ESP_SIZE:-1}"     # 1=4G 2=6G 3=8G 4=custom
# AI (Big Pickle) ADDITION — Beta-v2.9.16 [KERNEL-SELECT]: the kernel the
# installer deploys is now a real Stage-1 choice. The base `linux` (rolling)
# kernel is ALWAYS installed — Void's base-system meta-package depends on it,
# so this is a per-flavor toggle pair for the two extras on top.
DEFAULT_KERNEL_MAINLINE="${DEFAULT_KERNEL_MAINLINE:-false}"  # linux-mainline (experts) [y/N]
DEFAULT_KERNEL_LTS="${DEFAULT_KERNEL_LTS:-true}"             # linux-lts (conservative) [Y/n]
DEFAULT_LOCALE="${DEFAULT_LOCALE:-1}"                 # 1=en_US.UTF-8 (menu index)
DEFAULT_TIMEZONE="${DEFAULT_TIMEZONE:-1}"             # 1=America/New_York (menu index)
# AI (Big Pickle) ADDITION — Beta-v2.9.59 [LOCAL-CACHE]: reuse a pre-seeded XBPS
# package cache (mklive-style xbps-cachedir-<arch> on an attached medium) so the
# live sync / bootstrap / chroot installs take packages from disk instead of the
# mirror. Default off — mirrors stay the baseline path, matching the lean
# [BROWSER-GATE-NO] posture. A typed absolute path also counts as "yes".
DEFAULT_LOCAL_CACHE="${DEFAULT_LOCAL_CACHE:-no}"
DEFAULT_SWAP_BACKEND="${DEFAULT_SWAP_BACKEND:-1}"     # 1=swapfile 2=zram 3=both 4=none
DEFAULT_HIBERNATION="${DEFAULT_HIBERNATION:-false}"   # enable suspend-to-disk? [y/N]
DEFAULT_SNAPSHOT_AUDIO="${DEFAULT_SNAPSHOT_AUDIO:-false}"  # audio on snapshot boots? [y/N]
DEFAULT_OCTOXBPS="${DEFAULT_OCTOXBPS:-false}"         # OctoXBPS GUI pkg mgr? [y/N]
DEFAULT_FLATPAK="${DEFAULT_FLATPAK:-false}"           # Flatpak + Flathub? [y/N]
DEFAULT_COSMIC_STORE="${DEFAULT_COSMIC_STORE:-false}"      # COSMIC app store (needs Flatpak)? [y/N]
# AI (Big Pickle) ADDITION — Beta-v2.9.36 [INSTALL-BREW]: opt-in complement to
# Flatpak — Homebrew (classic Linuxbrew) is the unsandboxed, user-owned
# ~/.linuxbrew CLI/dev channel. Installs only the xbps runtime deps (git curl
# file procps-ng); the installer deliberately does NOT pipe the vendor's
# curl|bash — the operator creates the prefix on first login (NEWS step).
# Isolation is a separate opt-in @linuxbrew per-user subvol (SUBVOL_ROWS row →
# PROVISION_LINUXBREW_SUBVOL, default OFF — a correctly-owned plain ~/.linuxbrew
# in @home already survives a @ rollback and isn't snapshotted).
DEFAULT_BREW="${DEFAULT_BREW:-false}"                 # Homebrew (Linuxbrew) CLI/dev channel? [y/N]
DEFAULT_FIREFOX="${DEFAULT_FIREFOX:-true}"            # [Y/n]
DEFAULT_CHROMIUM="${DEFAULT_CHROMIUM:-true}"          # [Y/n]
DEFAULT_THUNDERBIRD="${DEFAULT_THUNDERBIRD:-false}"   # Thunderbird email client? [y/N]
DEFAULT_STEAM="${DEFAULT_STEAM:-false}"               # Steam gaming client? [y/N]
# AI (Big Pickle) ADDITION — Beta-v2.9.37 [GAME-LAUNCHERS]: independent
# default-OFF toggles in a "GAME LAUNCHERS & RUNTIMES" umbrella. Lutris is in
# Void main (xbps); Heroic + Bottles have NO official Void package so they are
# Flatpak-only, offered only when INSTALL_FLATPAK=true. Wine (system,
# multilib) and gamemode (Feral governor daemon + 32-bit libs) are separate
# runtime toggles that a launcher NEVER auto-pulls.
DEFAULT_LUTRIS="${DEFAULT_LUTRIS:-false}"             # Lutris game library/installer? [y/N]
DEFAULT_HEROIC="${DEFAULT_HEROIC:-false}"             # Heroic Epic/GOG launcher (Flatpak-only)? [y/N]
DEFAULT_BOTTLES="${DEFAULT_BOTTLES:-false}"           # Bottles per-game Wine prefixes (Flatpak-only)? [y/N]
DEFAULT_WINE="${DEFAULT_WINE:-false}"       # system Wine (multilib)? [y/N]
DEFAULT_GAMEMODE="${DEFAULT_GAMEMODE:-false}"         # gamemode + libgamemode-32bit? [y/N]
DEFAULT_VIRTUALBOX="${DEFAULT_VIRTUALBOX:-false}"     # VirtualBox full virtualizer? [y/N]
# AI (Big Pickle) ADDITION — Beta-v2.9.0 [SUBVOL-GATES]: the two master
# subvolume gates. DEFAULT_SUBVOL_ISOLATE (Gate 1) defaults YES — installed
# optional software gets its isolated subvol (matches the always-isolated
# behavior). DEFAULT_SUBVOL_PRECREATE (Gate 2) defaults NO — a bare-Enter run
# pre-creates no empty subvols for not-installed software (matches the old
# lean SETUP_APPS default). Each generates a `_INPUT` read with y/n/i.
DEFAULT_SUBVOL_ISOLATE="${DEFAULT_SUBVOL_ISOLATE:-true}"    # Gate 1 [Y/n/i]
DEFAULT_SUBVOL_PRECREATE="${DEFAULT_SUBVOL_PRECREATE:-false}" # Gate 2 [y/N/i]
DEFAULT_VIVALDI="${DEFAULT_VIVALDI:-false}"           # [y/N]
DEFAULT_FALKON="${DEFAULT_FALKON:-false}"             # [y/N]
DEFAULT_BRAVE="${DEFAULT_BRAVE:-false}"               # [y/N]
# [BROWSER-GROUP] web-browser category gate: whether to even walk the browser
# section. Defaults to OFF, so a bare-Enter run now skips the browser section
# entirely (the [BROWSER-GATE-NO] default flip, Beta-v2.9.7) — previously it
# OR'ed the component defaults (Firefox/Chromium on) so a bare-Enter run
# installed both. Anyone who says yes to the gate still gets the per-browser
# picks (Firefox/Chromium still individual-default ON inside).
DEFAULT_WEB_BROWSERS="${DEFAULT_WEB_BROWSERS:-false}"  # [y/N]
DEFAULT_PODMAN_ROOTLESS="${DEFAULT_PODMAN_ROOTLESS:-false}"  # [y/N]
DEFAULT_PODMAN_ROOTFUL="${DEFAULT_PODMAN_ROOTFUL:-false}"    # [y/N]
DEFAULT_DOCKER="${DEFAULT_DOCKER:-false}"             # [y/N]
DEFAULT_DOCKER_GROUP_ADD="${DEFAULT_DOCKER_GROUP_ADD:-false}"  # add to docker group? [y/N]
# [CONTAINER-GROUP] container-category gate. Defaults OFF (all three backends
# default OFF under [OPT-DEFAULTS]), so a bare-Enter run skips the whole
# container section exactly as before; only an explicit "yes" walks the
# individual Podman/Docker prompts.
DEFAULT_CONTAINERS="${DEFAULT_CONTAINERS:-false}"     # [y/N]
DEFAULT_VIRT="${DEFAULT_VIRT:-false}"                 # virtualization qemu/libvirt? [y/N]
DEFAULT_DISTROBOX="${DEFAULT_DISTROBOX:-false}"       # also install distrobox? [y/N]
DEFAULT_DISTROBOX_TRACK="${DEFAULT_DISTROBOX_TRACK:-1}"       # 1=stable 2=current 3=next
DEFAULT_DISTROBOX_ENGINE="${DEFAULT_DISTROBOX_ENGINE:-1}"     # 1=podman 2=docker
# AI (Big Pickle) ADDITION — Beta-v2.9.17 [DEVICE-PROFILE]: laptop vs
# desktop/server (tlp + bluetooth gates). 1=Automatic (default) 2=laptop+BT
# 3=laptop no-BT 4=desktop/server+BT 5=desktop/server no-BT.
DEFAULT_DEVICE_PROFILE="${DEFAULT_DEVICE_PROFILE:-1}"
DEFAULT_YK_TOUCH="${DEFAULT_YK_TOUCH:-yes}"           # require touch to unlock? [Y/n]
DEFAULT_YK_FALLBACK="${DEFAULT_YK_FALLBACK:-yes}"     # keep typed-passphrase fallback? [Y/n]
# AI (Big Pickle) ADDITION — Beta-v2.9.23 [SSH-SERVER]/[SSH-KEYS]: OpenSSH
# server toggle + port + access policy, plus SSH key import/generate/backup.
# Server default-OFF (matches the post-Beta-v2.1 [OPT-DEFAULTS] posture of
# NOT shipping network-facing daemons by default); access sub-prompts default
# to reachable-without-key-setup (password auth via bare-Enter stays on) and
# Void's stock root posture (prohibit-password).
DEFAULT_INSTALL_SSH_SERVER="${DEFAULT_INSTALL_SSH_SERVER:-false}"  # install+enable sshd? [y/N]
DEFAULT_SSH_PORT="${DEFAULT_SSH_PORT:-22}"                        # sshd port [1-65535]
DEFAULT_SSH_PASSWORD_AUTH="${DEFAULT_SSH_PASSWORD_AUTH:-yes}"     # allow password auth? [Y/n]
DEFAULT_SSH_ROOT_LOGIN="${DEFAULT_SSH_ROOT_LOGIN:-prohibit-password}"  # root over SSH? [Y/n]
DEFAULT_IMPORT_SSH_KEY="${DEFAULT_IMPORT_SSH_KEY:-false}"         # import existing key? [y/N]
DEFAULT_GENERATE_SSH_KEY="${DEFAULT_GENERATE_SSH_KEY:-false}"     # generate fresh key? [y/N]
DEFAULT_SSH_KEY_PROTECTED="${DEFAULT_SSH_KEY_PROTECTED:-yes}"     # passphrase-protect key? [Y/n]
DEFAULT_EXPORT_SSH_KEY="${DEFAULT_EXPORT_SSH_KEY:-false}"         # export/backup key? [y/N]
# AI (Big Pickle) ADDITION — Beta-v2.9.25 [NVIDIA-GATE]: the ONE probe-gated
# driver. "auto" follows the live-box probe: [Y/n] when an NVIDIA GPU was
# detected (proprietary driver recommended), [y/N] otherwise (nouveau covers
# it). Export DEFAULT_INSTALL_NVIDIA=yes|no to pin it regardless of probe.
DEFAULT_INSTALL_NVIDIA="${DEFAULT_INSTALL_NVIDIA:-auto}"          # install nvidia driver? [Y/n]/[y/N]
# AI (Big Pickle) ADDITION — Beta-v2.9.26 [WIFI-FW]: real wifi chipset →
# firmware-gap closer. "auto" = yes when a Broadcom radio is detected (the
# ONLY vendor not covered by Void's default linux-firmware split), no/absent
# for everything else; export DEFAULT_WIFI_FW=yes|no to pin.
DEFAULT_WIFI_FW="${DEFAULT_WIFI_FW:-auto}"                         # install linux-firmware-broadcom? [Y/n]
# AI (Big Pickle) ADDITION — Beta-v2.9.27 [CPU-DETECT]: microcode is a
# report-only auto-install — the CPU vendor is read-only hardware, there is
# one correct package per vendor, and prompting is friction without a decision.
# auto (default) installs intel-ucode / linux-firmware-amd per the detected
# vendor; no skips it; the chroot re-derives only when MICROCODE_DECIDED is
# absent (resume from a pre-2.9.27 state file).
DEFAULT_MICROCODE="${DEFAULT_MICROCODE:-auto}"                      # auto-install CPU microcode? [y/N]
# AI (Big Pickle) ADDITION — Beta-v2.9.27 [NIC-DETECT]: the wired NIC that
# feeds the bridged br0 VM network (when INSTALL_VIRT) is now a detect-and-
# confirm hardware fact in the review instead of a silent virt-phase pick.
# DEFAULT_NIC=<name> pins it and skips both the review prompt and the late
# INSTALL_VIRT-gated re-probe. Empty = not detected / not pinned.
DEFAULT_NIC="${DEFAULT_NIC:-}"                                     # pin the bridged-VM wired NIC name
# AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS]: data-region filesystem
# choices. Each region stays a root-Btrfs subvolume (btrfs, default) or is
# carved onto its own dedicated partition (ext4); the games region is none
# (default, plain ~/Games directory) / ext4 / btrfs. Size prompts only appear
# for carved partitions, sized by these defaults when the region is carved.
# Pressing Enter on every line yields the all-Btrfs layout (no extra
# partitions, no size prompts) — matching pre-2.9.38 behavior exactly.
DEFAULT_REGION_HOME_FS="${DEFAULT_REGION_HOME_FS:-btrfs}"  # /home: btrfs (subvol) or ext4 (partition)?
DEFAULT_REGION_VAR_FS="${DEFAULT_REGION_VAR_FS:-btrfs}"    # /var: btrfs (subvols) or ext4 (partition)?
DEFAULT_REGION_CACHE_FS="${DEFAULT_REGION_CACHE_FS:-btrfs}" # /var/cache: btrfs (@cache) or ext4 (partition)?
DEFAULT_REGION_SRV_FS="${DEFAULT_REGION_SRV_FS:-btrfs}"    # /srv: btrfs (@srv) or ext4 (partition)?
DEFAULT_REGION_OPT_FS="${DEFAULT_REGION_OPT_FS:-btrfs}"    # /opt: btrfs (@opt) or ext4 (partition)?
DEFAULT_REGION_GAMES="${DEFAULT_REGION_GAMES:-none}"       # ~/<user>/Games: none, ext4, or btrfs partition
DEFAULT_REGION_HOME_SIZE="${DEFAULT_REGION_HOME_SIZE:-40G}"    # /home partition size
DEFAULT_REGION_VAR_SIZE="${DEFAULT_REGION_VAR_SIZE:-20G}"    # /var partition size
DEFAULT_REGION_CACHE_SIZE="${DEFAULT_REGION_CACHE_SIZE:-4G}"  # /var/cache partition size
DEFAULT_REGION_SRV_SIZE="${DEFAULT_REGION_SRV_SIZE:-4G}"    # /srv partition size
DEFAULT_REGION_OPT_SIZE="${DEFAULT_REGION_OPT_SIZE:-4G}"    # /opt partition size
DEFAULT_REGION_GAMES_SIZE="${DEFAULT_REGION_GAMES_SIZE:-60G}"  # Games partition size
# AI (Big Pickle) ADDITION — Beta-v2.9.47 [TEE-BOOT-QUIET]/[TEE-BLACKLIST]:
# env-only PUBLIC boot-cmdline knobs (no prompt reads them — set by exporting
# the name before a run, or by editing limine-env after install). Threaded into
# the shared TEE_QB_FRAG ("quiet" + "modprobe.blacklist=tee") that the
# limine-env generator re-derives on every kernel/snapshot resync, and baked
# into GRUB_CMDLINE_LINUX_DEFAULT at install time for the GRUB branch.
DEFAULT_QUIET_BOOT="${DEFAULT_QUIET_BOOT:-no}"          # append "quiet"? (boot-cmdline knob)
DEFAULT_TEE_BLACKLIST="${DEFAULT_TEE_BLACKLIST:-no}"    # append "modprobe.blacklist=tee"? (boot-cmdline knob)


# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.4.0 [FAILURE-JOURNAL]: FAILURE TRACE / INSTALL
# JOURNAL. A persistent (same-live-session) log of install milestones plus,
# on any failure, a diagnostic trace: exit code, the exact failing command,
# and the function-call stack. It lives in /tmp alongside the resume state
# file so a crash both leaves a resumable record AND a debuggable trace. The
# `jl` helper appends timestamped milestone lines. Defined before the ERR
# trap so it is always available when an error fires.
# =============================================================================
JOURNAL="/tmp/void-installer-journal.log"
jl() { echo "[$(date +%H:%M:%S)] $*" >> "$JOURNAL" 2>/dev/null; }
# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.9.38 [CRASH-USB-LOG]: crash post-mortem to
# USB. save_log_to_usb() copies the journal + a public-facts .info sidecar to
# the FIRST mounted+writable stick under /run/media, so a crashed live session
# that loses its /tmp journal on reboot still leaves a debuggable artifact.
# SECRET-FREE (matches the journal invariant): it is the journal (never any
# passphrase/keys by construction) plus public env facts; the .info header
# records resume-record PRESENCE only — never hashes, install-config,
# limine-env, or YubiKey/SSH secrets. NEVER writes to a mount backed by $DISK
# (the disk under install). Fully guarded (|| true) so a missing/locked stick
# can never abort a crash unwind. Also invocable standalone via --save-log,
# which MUST be handled BEFORE the `: > "$JOURNAL"` truncation, the `ping
# xmirror` gate, and the STAGE-1 banner — that placement is what makes it
# usable from a crashed, networkless live env (invariant #16).
# =============================================================================
save_log_to_usb() {
    {
        _usb_stamp="$(date +%Y%m%d-%H%M%S 2>/dev/null)"
        _usb_target=""
        for _usb_m in /run/media/* /media/*; do
            [ -d "$_usb_m" ] || continue
            [ -w "$_usb_m" ]  || continue
            _usb_dev="$(findmnt -no SOURCE --target "$_usb_m" 2>/dev/null)"
            # Never write to the disk under install (or its partitions).
            if [ -n "${DISK:-}" ]; then
                case "${_usb_dev:-}" in
                    "$DISK"*) continue ;;
                esac
            fi
            # Never the live medium's loop backing itself.
            case "${_usb_dev:-}" in
                /dev/loop*) continue ;;
            esac
            _usb_target="$_usb_m"
            break
        done
        [ -n "$_usb_target" ] || { unset _usb_stamp _usb_target _usb_m _usb_dev; return 0; }
        _usb_base="${_usb_target}/void-installer-crash-${_usb_stamp}"
        {
            echo "SCRIPT_VERSION=${SCRIPT_VERSION:-<unset>}"
            echo "STAGE_CONTEXT=${STAGE_CONTEXT:-<pre-stage>}"
            echo "TARGET_DISK=${DISK:-<not yet selected>}"
            echo "BOOTLOADER=${BOOTLOADER:-<n/a>}"
            echo "DESKTOP_ENV=${DESKTOP_ENV:-<n/a>}"
            echo "DISPLAY_MANAGER=${DISPLAY_MANAGER:-<n/a>}"
            echo "ENCRYPT=${ENCRYPT:-no} (public flag only; no passphrase ever)"
            echo "RESUME_RECORD=$([ -f "$STATE_FILE" ] && echo PRESENT || echo absent)"
            echo "JOURNAL_LINES=$(wc -l < "$JOURNAL" 2>/dev/null || echo 0)"
        } > "${_usb_base}.info" 2>/dev/null
        cp -f "$JOURNAL" "${_usb_base}.log" 2>/dev/null || { unset _usb_stamp _usb_target _usb_m _usb_dev _usb_base; return 0; }
        jl "CRASH-USB-LOG: post-mortem saved to ${_usb_base}.log (+.info)"
        echo "!! Crash post-mortem saved to ${_usb_base}.log (+.info) — evidence for triage." >&2
    } || true
    unset _usb_stamp _usb_target _usb_m _usb_dev _usb_base
}

# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.9.39 [CRASH-USB-LOG-FATAL-EXIT]: the ERR
# trap (cleanup_on_failure) only fires on a REAL command failure under set -e.
# A DELIBERATE `exit 1` — bad LUKS passphrase, failed luksOpen, unresolvable
# inner-GPT, an aborted bootstrap — never trips it, so those planned aborts
# silently skipped the USB snapshot. This EXIT-trap safety net catches EVERY
# fatal exit (deliberate or not) and drops the journal too. _usb_dumped guards
# against the double-write: when the ERR-unwind already saved, the EXIT trap
# that fires right after (set -e makes the failing status exit the shell) must
# not write a second copy. NOTE: the `--save-log` CLI flag does NOT set the
# flag — it snapshots the PRE-truncation journal; a later real fatal still
# deserves its own fresh post-mortem. The exit code is captured FIRST because
# any command (including the save itself) would clobber `$?`.
# =============================================================================
_usb_dumped=0
_save_log_on_exit() {
    local _ec=$?
    [ "$_ec" -eq 0 ] && return 0
    [ "$_usb_dumped" = "1" ] && return 0
    _usb_dumped=1
    save_log_to_usb
    return 0
}
trap _save_log_on_exit EXIT

# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.4.0 [RESUME]: COARSE PHASE RESUME / SUBVOL RESET
# =============================================================================
# The live USB session is ephemeral but a crash leaves the script's config in
# /tmp/void-installer-state.sh, which persists for the rest of this same booted
# live session. If the user re-runs the script after a crash (without rebooting)
# this block offers to resume: it restores every previously-entered answer (so
# nothing has to be re-typed), skips re-partitioning, resets the target's Btrfs
# contents to a clean slate, and re-runs the (non-idempotent) Stage 2 chroot
# from scratch — always ending in a clean, consistent install.
#   - Only plaintext password *hashes* are persisted; live passwords are never
#     written, and they are cleared from memory right after hashing regardless.
#   - Triggered by a present state file + `-r/--resume` flag, or an explicit
#     interactive prompt (defaults to NO = fresh install).
#   - The state file is removed only on a fully successful install, so a
#     another crash is still resumable.
# =============================================================================
RESUME=0
AUTO_RESUME=0
STATE_FILE="/tmp/void-installer-state.sh"
DRY_RUN=0
# CLI flags are parsed HERE — before the journal truncation, the `ping xmirror`
# network gate, and the STAGE-1 banner — so --save-log is usable from a
# crashed, networkless live env (Beta-v2.9.38 [CRASH-USB-LOG] invariants).
for _arg in "$@"; do
    case "$_arg" in
        -r|--resume) AUTO_RESUME=1 ;;
        -d|--dry-run|--dryrun|-n)
            # AI (Big Pickle) ADDITION — Beta-v2.5.1 [DRY-RUN]: see header —
            # walk the full interactive config, print the complete plan of what
            # would be done, and stop at the destructive partition boundary
            # WITHOUT touching any disk, running the chroot, or installing
            # anything into the live environment.
            DRY_RUN=1 ;;
        --save-log)
            # Beta-v2.9.38 [CRASH-USB-LOG]: dump the current journal (+.info)
            # to the first mounted stick and continue. Runs before the
            # truncation below, so after a crash the evidence already on the
            # USB persists even though the fresh-run journal starts empty.
            save_log_to_usb ;;
        -h|--help)
            echo "Usage: $0 [-r|--resume]          (resume a previous interrupted install)" >&2
            echo "       $0 [-d|--dry-run] [args]   (walk config, print the plan, touch nothing)" >&2
            echo "       $0 [--save-log]            (dump crash journal to a mounted USB stick, then continue)" >&2
            echo "       $0                         (fresh interactive install)" >&2
            exit 0 ;;
        *)
            echo "Unknown option: $_arg" >&2
            exit 2 ;;
    esac
done
unset _arg

: > "$JOURNAL"
# =============================================================================
# AI (Big Pickle) CHANGE — Beta-v2.5.0 [REBOOT-COUNTDOWN]: how long the
# completed-install summary waits before auto-rebooting. The end summary
# prints this actual value and then a live per-second countdown, so changing
# this one variable changes both the summary text and the wait. Overridable
# from the environment (REBOOT_DELAY=10 ...) for scripting/resume runs.
REBOOT_DELAY="${REBOOT_DELAY:-20}"
# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.4.0 [COSMETIC]: ANSI color + formatting helpers
# used throughout the interactive prompts so the installer's output is easier
# to read at a glance and high-stakes prompts (disk ERASE in particular)
# stand out. These are plain text escapes — safe on any POSIX terminal; use
# `tput`-free constants so the file stays self-contained. Color output is
# auto-disabled when stdout is not a TTY (piped/redirected logs stay clean).
# =============================================================================
if [ -t 1 ]; then
    C_RED=$'\033[1;31m'
    C_GRN=$'\033[1;32m'
    C_YLW=$'\033[1;33m'
    C_BLU=$'\033[1;34m'
    C_MAG=$'\033[1;35m'
    C_CYN=$'\033[1;36m'
    C_BOLD=$'\033[1m'
    C_RST=$'\033[0m'
else
    C_RED=""; C_GRN=""; C_YLW=""; C_BLU=""; C_MAG=""; C_CYN=""; C_BOLD=""; C_RST=""
fi

# Print a visually distinct section banner, e.g. sec_banner "STAGE 1" "DISK MANAGEMENT".
sec_banner() {
    echo ""
    echo "${C_CYN}==============================================================================${C_RST}"
    echo "${C_CYN}# ${C_BOLD}$1${C_RST}${C_CYN}${2:+: $2}${C_RST}"
    echo "${C_CYN}==============================================================================${C_RST}"
}

# Print a label-then-question pair with an accent color on the label.
ask() { # ask "label text" "default-suffix-message?"
    printf '%s' "${C_BOLD}${C_YLW}-- ${1}${C_RST}"
}

# Non-fatal note / progress line helper.
note() { echo "${C_GRN}==>${C_RST} $*"; }
warn() { echo "${C_YLW}!! ${C_RST}$*" >&2; }
critical() { echo "${C_RED}!!!! CRITICAL:${C_RST} $*" >&2; }

# AI (Big Pickle) ADDITION — Beta-v2.9.35 [ESP-SIZE]: shared EFI ESP-size menu.
# Serves the ONE prompt-time decision point where the chosen bootloader path
# needs a real ESP:
#   * Limine        — right after the bootloader choice (esp-copy mirrors every
#                     kernel/initramfs/snapshot onto the ESP).
#   * GRUB+ENCRYPT  — right after the full-disk-encryption choice (the ESP is
#                     mounted AT /boot and holds the whole boot tree).
# Plain GRUB never calls it (its ESP at /boot/efi holds only the bootloader and
# stays fixed 1G — see [GRUB-ESP-SIZE-ORDER] for why the old in-loop check was
# wrong). Bare Enter selects the default via DEFAULT_EFI_ESP_SIZE (a menu index
# 1-4, default 1=4G); the menu header shows the resolved default name. Custom
# sizes are uppercased, validated with a 1 GiB floor, matched, and normalized to
# gdisk's native single-letter K/M/G before being stored in $EFI_PART_SIZE
# (which threads unchanged into sgdisk, the dry-run plan, and resume state).
esp_size_choose() {
    _esp_default_idx="${DEFAULT_EFI_ESP_SIZE}"
    [ -z "$_esp_default_idx" ] && _esp_default_idx=1
    case "$_esp_default_idx" in
        1) _esp_default_name="4 GiB" ;;
        2) _esp_default_name="6 GiB" ;;
        3) _esp_default_name="8 GiB" ;;
        4) _esp_default_name="Custom" ;;
        *) _esp_default_name="4 GiB"; _esp_default_idx=1 ;;
    esac
    echo ""
    echo "${C_BOLD}${C_BLU}EFI ESP partition size${C_RST}  (default: ${_esp_default_name})"
    echo "  The ESP is the partition whose size caps how many kernels + snapshots"
    echo "  coexist on it (Limine mirrors every kernel/snapshot; GRUB+ENCRYPT mounts"
    echo "  the ESP AT /boot). Larger = more headroom."
    echo "  ${C_BOLD}1)${C_RST} 4 GiB (default) — ArchWiki's recommendation for bootable snapshots"
    echo "  ${C_BOLD}2)${C_RST} 6 GiB — headroom for many kernel flavors + snapshots"
    echo "  ${C_BOLD}3)${C_RST} 8 GiB — generous; large initramfses + many snapshots"
    echo "  ${C_BOLD}4)${C_RST} Custom — type any sgdisk size (512M, 3G, 10GiB, ...); enforced to a 1 GiB floor"
    while true; do
        ask "Enter choice [1-4/Custom] (default ${DEFAULT_EFI_ESP_SIZE}: ${_esp_default_name}): "
        read -r ESP_SIZE_INPUT
        case "${ESP_SIZE_INPUT:-$_esp_default_idx}" in
            1) EFI_PART_SIZE="4G"; break ;;
            2) EFI_PART_SIZE="6G"; break ;;
            3) EFI_PART_SIZE="8G"; break ;;
            4|custom) 
                ask "Custom ESP size (e.g. 512M, 3G, 10GiB): "
                read -r ESP_SIZE_CUSTOM
                _esp_custom="${ESP_SIZE_CUSTOM^^}"
                # 1 GiB floor (a below-floor or malformed entry is rejected with
                # an explanation and the menu loops).
                case "$_esp_custom" in
                    *[!0-9a-gKMG]*|"") echo "Please enter a size like 512M, 3G, or 1024M." >&2 ;;
                    *)
                        _esp_num="${_esp_custom%[KMG]}"
                        _esp_units="${_esp_custom##*[0-9]}"
                        _esp_bytes=0
                        case "$_esp_units" in
                            G) _esp_bytes=$(( _esp_num * 1024 )) ;;
                            M) _esp_bytes=$_esp_num ;;
                            K) _esp_bytes=$(( _esp_num / 1024 )) ;;
                        esac
                        if [ "$_esp_bytes" -lt 1024 ]; then
                            echo "  ESP too small — floor is 1 GiB (1024M). Try again." >&2
                        else
                            # Normalize to gdisk's native single-letter K/M/G.
                            case "$_esp_units" in
                                G) EFI_PART_SIZE="${_esp_custom}"; EFI_PART_SIZE="${_esp_num}G" ;;
                                M|K)
                                    _esp_gb=$(( _esp_bytes / 1024 ))
                                    if [ $(( _esp_bytes % 1024 )) -eq 0 ]; then
                                        EFI_PART_SIZE="${_esp_gb}G"
                                    else
                                        EFI_PART_SIZE="${_esp_num}${_esp_units}"
                                    fi
                                    ;;
                            esac
                            break
                        fi
                        ;;
                esac
                ;;
            *) echo "Please enter 1, 2, 3, or 4." >&2 ;;
        esac
    done
    unset _esp_default_idx _esp_default_name _esp_custom _esp_num _esp_units _esp_bytes _esp_gb
    echo "  Resolved ESP size: ${EFI_PART_SIZE}"
}

# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.9.23 [SSH-KEYS] browse_pick(): a reusable
# pure-bash numbered file/dir browser (extracted from the original
# [LIMINE-WALLPAPER-BROWSE] picker; the wallpaper prompt is now just the
# img-mode caller). Modes:
#   img  — list subdirectories + image files (bmp/png/jpg/jpeg/qoi); returns a
#          selected image path, or empty on a declined/absent selection.
#   file — list subdirectories + ANY file; returns the selected path.
#   dir  — list subdirectories only; returns the selected directory.
# Start in /run/media (mounted USB stick) if present, else /root. `..` goes up
# a level; `m` or `drives` jumps back to the /run/media drive list; a path
# (absolute or relative) is accepted as an escape hatch; numbers select an item.
# Prints the chosen path on stdout (nothing on a declined empty selection).
# AI (Big Pickle) FIX — Beta-v2.9.50 [BROWSE-DIR-ACCEPT]: in `dir` mode the
# browser had NO accept action — selecting a directory (number or typed path)
# descended into it and bare Enter was a DECLINE, so a destination directory
# could never be confirmed: the Beta-v2.9.23 [SSH-KEYS] "export the keypair
# backup to removable media" flow ALWAYS ended "No destination chosen; skipping
# export." and the keys never reached the USB stick (matches the real v2.9.43
# build). `!`/`ok` now accepts the CURRENT directory; bare Enter still
# declines; number/path navigation is unchanged. `img`/`file` modes were never
# affected — they return a FILE.
# =============================================================================
# AI (Big Pickle) FIX — Beta-v2.9.51 [BROWSE-CAP-FIX]: every caller uses
# command substitution (`WP_SRC="$(browse_pick img …)"` /
# `_export_dst="$(browse_pick dir …)"`), so each menu echo/printf written to
# STDOUT was captured INTO the result value — the wallpaper pick came back as
# the whole multi-line menu banner (the stage-copy `cp -f "$WP_SRC" …` then
# FATALed "cannot stat <banner>"), and the SSH-key export dir came back
# banner-prefixed so `[ -d "$_export_dst" ]` was always false ("No destination
# chosen; skipping export."). No keyboard answer could dodge it — even a
# bare-Enter DECLINE still left the captured banner as a non-empty "selection",
# aborting a Limine run that answered the wallpaper prompt either way. All
# menu/prompt output now goes to STDERR (the same `>&2` pattern `_subvol_ask`
# uses); ONLY the final picked value is printed to stdout, so the `$( )`
# capture sees the path and nothing else. The error lines were already `>&2`.
# =============================================================================
browse_pick() { # browse_pick <mode> <what-label>
    local _bp_mode="${1:-file}" _bp_label="${2:-file}"
    local _bp_start _bp_ok=0 _bp_src="" _bp_ext="" _bp_i _bp_alias=""
    local -a _bp_items=()
    if [ -d /run/media ]; then
        _bp_start="/run/media"
    else
        _bp_start="/root"
    fi
    while [ "$_bp_ok" -eq 0 ]; do
        # A fresh menu pass carries the copyright-free note that Ctrl-C aborts.
        echo "" >&2
        echo "  Browse for ${_bp_label}: ${C_BOLD}${C_CYN}/${_bp_start#/}${C_RST}" >&2
        echo "  Enter ${C_BOLD}..${C_RST} to go up a level, an absolute/relative path to jump there," >&2
        echo "  ${C_BOLD}m${C_RST}/${C_BOLD}drives${C_RST} to jump back to the mounted-drive list at /run/media," >&2
        if [ "$_bp_mode" = "img" ]; then
            echo "  or the number of an image below. ${C_BOLD}Enter alone${C_RST} declines (no image)." >&2
        elif [ "$_bp_mode" = "dir" ]; then
            echo "  or the number of a directory below. ${C_BOLD}Enter alone${C_RST} declines;" >&2
            echo "  ${C_BOLD}!${C_RST}/${C_BOLD}ok${C_RST} accepts the CURRENT directory." >&2
        else
            echo "  or the number of an entry below. ${C_BOLD}Enter alone${C_RST} declines." >&2
        fi
        _bp_items=()
        if [ "$_bp_start" != "/" ]; then
            _bp_items+=( ".." )
        fi
        while IFS= read -r _bp_ent; do
            if [ "$_bp_mode" = "dir" ] && [ -d "$_bp_ent" ]; then
                _bp_items+=( "$_bp_ent" )
            elif [ "$_bp_mode" != "dir" ] && { [ -d "$_bp_ent" ] || \
                    { [ "$_bp_mode" = "file" ] || [[ "$_bp_ent" =~ \.(bmp|png|jpg|jpeg|qoi)$ ]]; }; }; then
                _bp_items+=( "$_bp_ent" )
            fi
        done < <(find "$_bp_start" -maxdepth 1 -mindepth 1 -printf '%p\n' 2>/dev/null | sort)
        if [ "${#_bp_items[@]}" -le 1 ]; then
            echo "  (nothing matching here)" >&2
        fi
        for _bp_i in "${!_bp_items[@]}"; do
            _bp_ent="${_bp_items[$_bp_i]}"
            if [ -d "$_bp_ent" ]; then
                echo "  ${C_BLU}${C_BOLD}$((_bp_i + 1))${C_RST}) ${_bp_ent##*/}/" >&2
            else
                echo "  ${C_BOLD}$((_bp_i + 1))${C_RST}) ${C_GRN}${_bp_ent##*/}${C_RST}" >&2
            fi
        done
        printf '\n%s' "${C_BOLD}${C_YLW}-- Select [dir | number | path ( .. = up, m = drives)]${C_RST} " >&2
        read -r _bp_src
        if [ -z "$_bp_src" ]; then
            echo "  Declined." >&2
            _bp_src=""
            break
        fi
        # AI (Big Pickle) FIX — Beta-v2.9.88 [BROWSE-ALIAS-ESC]: the browser's
        # control words (`..`, `m`, `drives`, `!`, `ok`) are shell-metacharacter-
        # shaped, and on the zsh live-prompt a user may type them escaped
        # (`\..`, `\!`, `\ok` — observed live as "ok displayed as \ok", which
        # was then rejected as a bad file). Peel ONE leading backslash for
        # ALIAS matching only; absolute/relative/number paths are still taken
        # exactly as typed, so no real path can be mangled.
        _bp_alias="${_bp_src#\\}"
        if [ "$_bp_alias" = ".." ]; then
            _bp_start="$(dirname "$_bp_start")"
            continue
        fi
        if [ "$_bp_alias" = "m" ] || [ "$_bp_alias" = "drives" ]; then
            if [ -d /run/media ]; then
                _bp_start="/run/media"
            else
                echo "  No /run/media on this live env — staying in ${_bp_start}." >&2
            fi
            continue
        fi
        # Beta-v2.9.50 [BROWSE-DIR-ACCEPT]: in dir mode, `!`/`ok` confirms the
        # CURRENT directory (the only way a destination dir could be returned).
        if [ "$_bp_mode" = "dir" ] && { [ "$_bp_alias" = "!" ] || [ "$_bp_alias" = "ok" ]; }; then
            _bp_src="$_bp_start"
            _bp_ok=1
            continue
        fi
        if [[ "$_bp_src" =~ ^[0-9]+$ ]]; then
            _bp_i=$((_bp_src - 1))
            if [ "$_bp_i" -lt 0 ] || [ "$_bp_i" -ge "${#_bp_items[@]}" ]; then
                echo "  '$_bp_src' is not a valid choice." >&2
                continue
            fi
            _bp_src="${_bp_items[$_bp_i]}"
        fi
        if [ -d "$_bp_src" ]; then
            _bp_start="$_bp_src"
            continue
        fi
        if [ ! -f "$_bp_src" ]; then
            echo "  File not found: ${_bp_src:-<empty>}" >&2
            continue
        fi
        if [ "$_bp_mode" = "img" ]; then
            _bp_ext="${_bp_src##*.}"
            case "${_bp_ext,,}" in
                bmp|png|jpg|jpeg|qoi) ;;
                *) echo "  Unsupported extension '${_bp_ext}'. Use BMP/PNG/JPEG/QOI." >&2; continue ;;
            esac
        fi
        _bp_ok=1
    done
    printf '%s' "$_bp_src"
}

echo "=============================================================================="
echo " ${C_BOLD}${C_CYN}Void Linux Unified Installer${C_RST} — version ${C_BOLD}${SCRIPT_VERSION}${C_RST}"
echo " Bootloader: choose GRUB or Limine below — UEFI only, BIOS unsupported"
echo "=============================================================================="

# Best-effort unwind of whatever got mounted, run ONLY on an actual command
# failure under set -e (trap ... ERR), not on a Ctrl-C or a deliberate exit.
cleanup_on_failure() {
    ec=$?

    # =========================================================================
    # AI (Big Pickle) ADDITION — Beta-v2.4.0 [FAILURE-JOURNAL]: write the failure
    # trace to the journal while the shell's error context is still intact.
    # Everything here is guarded (|| true) so the unwind below still runs even
    # if the journal write itself fails.
    # =========================================================================
    # shellcheck disable=SC2094  # journaled failure trace mirrors the journal's own recent history
    {
        echo "############################################################"
        echo "# Void Linux Installer — FAILURE TRACE — $(date)"
        echo "############################################################"
        echo "Exit code       : ${ec}"
        echo "Failing command : ${BASH_COMMAND:-<unknown>}"
        echo "Stage context   : ${STAGE_CONTEXT:-<pre-stage>}"
        echo "Target disk     : ${DISK:-<not yet selected>}"
        echo "Partitions      : EFI=${PART_EFI:-<n/a>}  SYS=${PART_SYS:-<n/a>}"
        echo "Bootloader      : ${BOOTLOADER:-<n/a>}"
        echo "Desktop / DM    : ${DESKTOP_ENV:-<n/a>} / ${DISPLAY_MANAGER:-<n/a>}"
        echo "Resume record   : $([ -f "$STATE_FILE" ] && echo "PRESENT — resume with '-r'" || echo "absent (fresh install or pre-persist)")"
        echo "--- call stack (most recent first) ---"
        local _bs_i=0
        for ((_bs_i=0; _bs_i<${#FUNCNAME[@]}; _bs_i++)); do
            [ -n "${FUNCNAME[$_bs_i]-}" ] || continue
            printf '   %-28s at %s:%s\n' "${FUNCNAME[$_bs_i]}" "${BASH_SOURCE[$_bs_i]}" "${BASH_LINENO[$_bs_i]:-?}"
        done
        unset _bs_i
        echo "--- install timeline (most recent 30 entries) ---"
        tail -n 30 "$JOURNAL" 2>/dev/null || true
        echo "############################################################"
    } >> "$JOURNAL" 2>&1 || true
    echo "!! Install failed (exit $ec). Failure trace logged to ${JOURNAL}. Attempting best-effort unwind of /mnt..." >&2

    # Only relevant when BOOTLOADER=grub; harmless no-op otherwise since
    # the file never exists on a Limine install.
    [ -f /mnt/etc/grub.d/41_snapshots-btrfs ] && chmod +x /mnt/etc/grub.d/41_snapshots-btrfs || true

    swapoff /mnt/var/swap/swapfile 2>/dev/null || true
    rm -f /mnt/tmp/chroot_env.sh 2>/dev/null || true
    # AI (Big Pickle) ADDITION — Beta-v2.9.23 [SSH-KEYS]: an aborted run must
    # never leave staged SSH key material on the live USB. Shred the LIVE
    # /tmp stage (prompt-phase originals) — the target /tmp copies die with the
    # mount teardown below, but these are on the live runtime itself.
    shred -u /tmp/ssh-keygen/* /tmp/ssh-import/* 2>/dev/null || true
    rm -rf /tmp/ssh-keygen /tmp/ssh-import 2>/dev/null || true
    # Beta-v2.6.2 [GRUB-ESP-BOOT]: in the GRUB+ENCRYPT combo the ESP
    # mountpoint is /mnt/boot itself (no /mnt/boot/efi, no /mnt/boot/grub).
    # All || true so unwinding a non-combo /mnt/boot btrfs dir is a no-op.
    [ "$GRUB_ESP_BOOT" = "true" ] && umount -fl /mnt/boot 2>/dev/null || true
    umount -fl /mnt/boot/efi 2>/dev/null || true
    umount -fl /mnt/boot/grub 2>/dev/null || true
    umount -fl /mnt/dev 2>/dev/null || true
    umount -fl /mnt/proc 2>/dev/null || true
    umount -fl /mnt/sys 2>/dev/null || true
    umount -fl /mnt/run 2>/dev/null || true
    # AI (Big Pickle) CHANGE — Beta-v2.4.0 [item 3]: var/lib/lightdm added to the
    # unwind list to mirror the new @lightdm subvolume (only ever mounted
    # when DISPLAY_MANAGER=lightdm; the umount is safe/no-op otherwise).
    for m in var/swap var/spool var/log var/lib/libvirt var/lib/sddm var/lib/lightdm \
             var/lib/NetworkManager \
             var/cache srv opt .snapshots home; do
        umount -fl "/mnt/${m}" 2>/dev/null || true
    done
    # AI (Big Pickle) ADDITION — Beta-v2.9.59 [LOCAL-CACHE]: release the media
    # cache bind mount on a crash too — same release-before-/mnt rule as the
    # Stage-3 teardown. No-op safe when never bound.
    umount -fl /mnt/tmp/xbps-cache 2>/dev/null || true
    umount -fl /mnt 2>/dev/null || true
    # AI (Big Pickle) FIX — Beta-v2.9.6 [LUKS-UNLOCK-LEFT-OPEN]: the unwind
    # previously unmounted everything but never closed an open LUKS mapper, so
    # a crash left the drive UNLOCKED (/dev/mapper/<name> still active). A
    # following '-r' resume then hit luksOpen on an already-open device
    # (cryptsetup refuses: "device already exists") and aborted, and a fresh
    # re-run choked on luksFormat/mkfs of a busy partition. Close the mapper we
    # opened so a failure returns the disk to a locked, clean state. CRYPT_NAME
    # may be unset if the crash pre-dates the prompt; default guards that.
    # Beta-v2.9.45 [INNER-PARTSCAN-DMPROBE]: if a carve had registered inner
    # partitions on the mapper via partx -a, unregister them BEFORE the close —
    # otherwise luksClose refuses a busy dm node and the "disk is now LOCKED"
    # promise breaks exactly like the first inner-GPT failures. partx -d is a
    # safe no-op when partprobe (BLKPG) had registered or nothing was open yet;
    # guard on ENCRYPT + carved REGION_PARTITIONED only.
    # Beta-v2.9.56 [INNER-PARTSCAN-KPARTX]: kpartx -a is what actually creates
    # the void-root1/void-root2 dm-linear submaps now, and ONLY kpartx -d can
    # tear them down — partx -d cannot (it cannot BLKPG a dm target at all).
    # Try kpartx -d first, then partx -d as the fallback.
    if [ "$ENCRYPT" = "yes" ] && [ -n "${REGION_PARTITIONED:-}" ]; then
        if command -v kpartx > /dev/null 2>&1; then
            kpartx -d "${CRYPT_DEV:-/dev/mapper/${CRYPT_NAME:-void-root}}" 2>/dev/null || partx -d "${CRYPT_DEV:-/dev/mapper/${CRYPT_NAME:-void-root}}" 2>/dev/null || true
        else
            partx -d "${CRYPT_DEV:-/dev/mapper/${CRYPT_NAME:-void-root}}" 2>/dev/null || true
        fi
    fi
    cryptsetup luksClose "${CRYPT_NAME:-void-root}" 2>/dev/null || true
    [ "$ENCRYPT" = "yes" ] && echo "!! Note: the LUKS mapper has been closed — the disk is now LOCKED." >&2
    echo "!! Unwind attempted. Re-check 'mount | grep /mnt' before re-running." >&2
    # AI (Big Pickle) ADDITION — Beta-v2.9.38 [CRASH-USB-LOG]: after the unwind,
    # drop the post-mortem (journal + .info) onto the first mounted stick. Runs
    # here because the /tmp journal dies with the live reboot; the USB copy is
    # the durable evidence. Fully guarded inside save_log_to_usb() so a
    # missing/locked stick can never abort this failure path. Beta-v2.9.39
    # [CRASH-USB-LOG-FATAL-EXIT]: mark _usb_dumped so the EXIT trap that fires
    # right after this ERR-unwind does not write a duplicate copy.
    save_log_to_usb
    _usb_dumped=1
}
trap cleanup_on_failure ERR

sec_banner "STAGE 1" "Disk management and OS bootstrapping (outside chroot)"
STAGE_CONTEXT="STAGE1:setup"
jl "Begin Stage 1"

# Fail fast with a clear message if the Live CD hasn't got a network yet,
# rather than letting the first xbps-install die on a cryptic repo error.
# AI (Big Pickle) CHANGE — Beta-v2.4.1: this check probes the authoritative mirror
# REGISTRY (xmirror.voidlinux.org — the same registry the regional-mirror
# selection block below is derived from) rather than hardcoding a single
# mirror (previously repo-default.voidlinux.org). The regional mirror selected
# later can legitimately differ from the global default (and may be the only
# one reachable in a given region), so a general "is networking up at all"
# check must not depend on any one specific mirror being reachable; the actual
# per-mirror reachability is handled by the install/bootstrap retry loops.
if ! ping -c1 -W3 xmirror.voidlinux.org >/dev/null 2>&1; then
    echo "FATAL: No network reachability (could not reach xmirror.voidlinux.org)." >&2
    echo "       Bring up networking (wpa_cli, dhcpcd, etc.) before running this script." >&2
    exit 1
fi

# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.4.0 [RESUME]: COARSE PHASE RESUME / SUBVOL RESET
# =============================================================================
# (The RESUME state vars and CLI-flag loop were MOVED UP to the journal block
# at the top of the script in Beta-v2.9.38 so `--save-log` runs before the
# journal truncation, the network gate, and the STAGE-1 banner. The state-file
# detection and resume prompting itself live below, unchanged.)

# AI (Big Pickle) ADDITION — Beta-v2.9.59 [LOCAL-CACHE]: find a pre-seeded XBPS
# package cache on an attached medium so the install can reuse already-downloaded
# packages instead of re-fetching them from the mirror. mklive/void-live and the
# Void_Linux_Live fork all keep the raw package cache as <mount>/xbps-cachedir-<arch>;
# the SAME raw .xbps cache is directly consumable by xbps-install -c on the live
# medium AND (bind-mounted) inside the target chroot. Prints the FIRST matching
# absolute path (newest-touched wins), or nothing when no usable cache exists.
# AI (Big Pickle) ADDITION — Beta-v2.9.61 [LOCAL-CACHE-ROOT]: a persistent
# (--persist) Void_Linux_Live stick seeds the cache into the root of its
# VOID_OVL overlay, so on the booted live system it sits at /xbps-cachedir-<arch>
# rather than under /run/media. The glob list below also probes that live-root
# path; on ordinary (non-persistent) boots the second glob matches nothing and
# is a no-op, while the seeded persist stick auto-detects like any other medium.
# AI (Big Pickle) ADDITION — Beta-v2.9.62 [LOCAL-CACHE-DEPTH]: the /run/media
# glob probed only /run/media/*/xbps-cachedir-* — ONE level deep — but udisks
# mounts an unlabeled data stick at /run/media/<user>/<uuid> (TWO levels), the
# exact layout this feature was built to serve (e.g. the populated cache on the
# SEPARATE data stick next to the VOID_LIVE stick), so auto-detect silently
# missed it and fell back to the typed-path prompt. The glob list now also
# probes /run/media/*/*/xbps-cachedir-*; depth-1, depth-2 and the live-root
# seed share the same "newest-touched, writable, arch-matching, real .xbps"
# first-wins rule.
# AI (Big Pickle) FIX — Beta-v2.9.63 [LOCAL-CACHE-ERR]: the process substitution
# <(ls -1dt <globs> 2>/dev/null) fed to the read loop can return exit 2 — an
# unmatched glob stays LITERAL, so ls reports "cannot access ...: No such file
# or directory" even when a sibling glob matched and was listed. Under
# set -eE (errtrace) the ERR trap fires on that status INSIDE the
# $( _local_cache_detect || true ) command substitution, running cleanup_on_failure
# mid-detection: the install aborts at the cache prompt with "Install failed
# (exit 2) / failing command: ls ...xbps-cachedir-*" although the cache was
# found. `|| true` on the ls keeps its status 0 — the while-read loop consumes
# whatever matched, exactly like the Void_Linux_Live _cache_detect() twin.
_local_cache_detect() {
    _lc_arch="$(uname -m)"
    while IFS= read -r _lc_dir; do
        [ -n "$_lc_dir" ] || continue
        [ -d "$_lc_dir" ] || continue
        case "$_lc_dir" in
            *"xbps-cachedir-${_lc_arch}") : ;;
            *) continue ;;
        esac
        [ -w "$_lc_dir" ] || continue
        [ -n "$(find "$_lc_dir" -maxdepth 1 -name '*.xbps' -print -quit 2>/dev/null)" ] || continue
        printf '%s\n' "$_lc_dir"
        return 0
    done < <(ls -1dt /run/media/*/xbps-cachedir-* /run/media/*/*/xbps-cachedir-* /xbps-cachedir-* 2>/dev/null || true)
    return 1
}
unset _lc_arch _lc_dir 2>/dev/null || true

# AI (Big Pickle) ADDITION — Beta-v2.4.1 [PREREQ]: this installer mounts, partitions
# and formats real disks, so it must run as root. Placed AFTER option parsing so
# `--help` still works for a non-root user, but before any disk operation. Fail
# fast with a clear message instead of letting the first mount/sgdisk die on a
# cryptic "permission denied".
if [ "$(id -u)" -ne 0 ]; then
    echo "${C_RED}!!!! CRITICAL:${C_RST} This script must be run as root (it partitions and formats a disk)." >&2
    echo "       Re-run it with sudo, or as the root user." >&2
    exit 1
fi

if [ -f "$STATE_FILE" ]; then
    echo ""
    echo "${C_YLW}!! An interrupted install was detected (state file present):${C_RST}"
    echo "   ${STATE_FILE}"
    _do_resume=0
    if [ "$AUTO_RESUME" = "1" ]; then
        _do_resume=1
    else
        ask "Resume the interrupted install using saved answers? [y/N]: "
        read -r _resume_ans
        case "$_resume_ans" in
            y|Y|yes|YES) _do_resume=1 ;;
        esac
    fi
    if [ "$_do_resume" = "1" ]; then
        # shellcheck disable=SC1090
        . "$STATE_FILE"
        RESUME=1
        echo "==> Resuming install with saved configuration (skipping prompts & re-partition)."
    else
        echo "==> Starting a fresh install; removing the stale state file."
        rm -f "$STATE_FILE"
        RESUME=0
    fi
fi
unset _do_resume _resume_ans

# AI (Big Pickle) ADDITION — Beta-v2.9.59 [LOCAL-CACHE]: a resumed install
# re-runs the live sync + base bootstrap + chroot package installs, so the
# cache decision must survive the restart. The recorded path can go stale
# (the stick may remount at a different /run/media/<user>/<label>); when the
# recorded dir is unusable, re-detect — and if nothing is found, fall back to
# the network-only baseline rather than failing the resume.
if [ "${LOCAL_CACHE_REUSE:-no}" = "yes" ]; then
    if [ -n "${LOCAL_CACHE_DIR:-}" ] && [ -d "$LOCAL_CACHE_DIR" ] && [ -w "$LOCAL_CACHE_DIR" ]; then
        : # recorded path still valid
    else
        _lc_redetect=$(_local_cache_detect || true)
        if [ -n "$_lc_redetect" ]; then
            echo "==> Local package cache re-detected on resume: ${_lc_redetect}"
            LOCAL_CACHE_DIR="$_lc_redetect"
        else
            echo "!! Recorded local package cache is gone (or moved/mounted elsewhere);" >&2
            echo "   continuing with a network-only install." >&2
            LOCAL_CACHE_REUSE="no"
            LOCAL_CACHE_DIR=""
        fi
        unset _lc_redetect
    fi
fi
LOCAL_CA=""
[ "${LOCAL_CACHE_REUSE:-no}" = "yes" ] && [ -n "${LOCAL_CACHE_DIR:-}" ] && LOCAL_CA="-c $LOCAL_CACHE_DIR"
export LOCAL_CA

# Prompt for root's password first, then the target username, then that
# user's own password right after — groups the new-account info together
read_password_twice() {
    local prompt_label="$1"
    local __resultvar="$2"
    local pw1 pw2
    while true; do
        read -rsp "Enter ${prompt_label} password: " pw1; echo
        if [ "${#pw1}" -lt 8 ]; then
            echo "Password too short (minimum 8 characters)." >&2
            continue
        fi
        read -rsp "Confirm ${prompt_label} password: " pw2; echo
        if [ "$pw1" != "$pw2" ]; then
            echo "Passwords did not match, try again." >&2
            continue
        fi
        break
    done
    printf -v "$__resultvar" '%s' "$pw1"
    pw1=""; pw2=""
}

# AI (Claude, Sonnet 5, Medium) ADDITION: Account privilege model is now a real install-time
# choice instead of one fixed behavior. Three real, different models:
#   1. Hybrid    — root has an active password AND the new user gets full
#                  sudo (wheel) access. Both `su -` (root's password) and
#                  `sudo` (your own password) work. This was the original,
#                  only behavior.
#   2. Debian    — root has an active password; the new user is NOT put in
#                  wheel/sudo at all. Privileged commands require `su -`
#                  and root's own separate password — Debian's classic
#                  default model. Two independent secrets; compromising the
#                  regular user's password alone doesn't grant root.
#   3. Ubuntu    — root is locked (no usable password at all); the new
#                  user gets full sudo (wheel) access using their OWN
#                  password. One credential total — simpler, but that one
#                  password is all that stands between a compromise and
#                  root. Root's password prompt is skipped entirely for
#                  this option since it's never going to be used.
_region_carved() { # $1=region name; returns 0 when carved onto its own partition
    case " ${REGION_PARTITIONED:-} " in
        *" $1 "*) return 0 ;;
        *)        return 1 ;;
    esac
}
# AI (Big Pickle) FIX — Beta-v2.9.66 [MULTI-FS-FS-EVAL]: resolve a carved
# region's filesystem from its LOWERCASE REGION_PARTITIONED token. The three
# mkfs/mount/fstab sites all used `eval "_rr_fs=\${REGION_${_rr}_FS:-btrfs}"`
# with the raw token, so `home` read the never-existent `REGION_home_FS`
# (bash variable names are case-sensitive) and EVERY carved region silently
# fell back to `btrfs` — the v2.9.48 [DISK-BUDGET] `^^` fold fixed the SIZE
# evals but missed the _FS evals. `games` additionally stores its choice in
# `REGION_GAMES` (no `_FS` suffix), so even a uppercased `REGION_GAMES_FS`
# would still be empty — the one region whose variable name breaks the
# REGION_<NAME>_FS contract. Observed live (2026-09-17, carved ENCRYPT
# /home + /home/<user>/Games): prompt/install-config recorded home=ext4
# games=ext4 while the run-log mkfs + fstab + blkid all show btrfs.
_region_fs_of() { # $1 = lowercase region token (home|var|cache|srv|opt|games)
    local _rfv
    if [ "$1" = "games" ]; then
        _rfv="REGION_GAMES"
    else
        _rfv="REGION_${1^^}_FS"
    fi
    printf '%s' "${!_rfv:-btrfs}"
}

# AI (Big Pickle) FIX — Beta-v2.9.85 [NIC-DETECT-USB]: the ONE wired-NIC
# probe both selection sites now share — the Stage-1 review's [NIC-DETECT]
# (BR0_NIC record + the "Keep this interface?" prompt) and the INSTALL_VIRT
# late re-probe (NET_INTERFACE_MATCH -> the br0-slave NM binding). The old
# Stage-1 USB fallback globbed /sys/devices/*/net/* — bash `*` never crosses
# a `/`, so it only ever matched /sys/devices/virtual/net/* (lo/br0/docker0/
# virbr0), every one of which fails the usb-subsystem test: dead code that
# could NEVER find hardware (a USB NIC's net dir sits ~6 levels deep, e.g.
# /sys/devices/pci0000:00/.../usb2/2-1/2-1.1/2-1.1:1.0/net/<iface>). So a
# present-but-unplugged USB adapter (the documented "cable optional"
# promise) always read "(none detected)" + BR0_NIC=<unset> — the round-10
# box shows exactly that with an ASIX AX88179 sitting in it. The re-probe's
# fallback was the correct logic; it is pass 2 below, so the two sites can
# never disagree again. Defined at unconditional top level above the resume
# guard on purpose — 2.9.78's `_region_fs_of` lesson (both call sites live
# inside RESUME-gated blocks). Callers MUST assign with
# `$(detect_wired_nic || true)`: Stage-1 runs under set -eE + the ERR trap
# and "nothing found" returns 1 (empty output is the not-found signal either
# way).
detect_wired_nic() {
    local _dn_if _dn_name
    # Pass 1 — a wired NIC with an ACTIVE LINK (physical, non-wireless only).
    for _dn_if in /sys/class/net/*; do
        [ -e "$_dn_if/device" ] || continue          # physical only — drops lo/br0/docker0/veth/...
        [ -d "$_dn_if/wireless" ] && continue         # never a radio
        _dn_name="${_dn_if##*/}"
        case "$_dn_name" in
            lo|ww*|wl*|bn*|bt*|dm-*) continue ;;      # non-wired by name (wwan/Bluetooth-net/dm-...)
        esac
        if [ "$(cat "$_dn_if/carrier" 2>/dev/null || echo 0)" = "1" ]; then
            printf '%s\n' "$_dn_name"
            return 0
        fi
    done
    # Pass 2 — no link anywhere: accept a physically-PRESENT USB network
    # device regardless of carrier (cable optional — the documented
    # USB-ethernet / USB-tethered-phone promise). `|| :` keeps a dangling
    # device symlink from tripping the Stage-1 ERR trap (verified live:
    # a bare readlink failure in a substitution DOES fire it under -eE).
    for _dn_if in /sys/class/net/*; do
        [ -e "$_dn_if/device" ] || continue
        [ -d "$_dn_if/wireless" ] && continue
        _dn_name="${_dn_if##*/}"
        case "$_dn_name" in
            lo|ww*|wl*|bn*|bt*|dm-*) continue ;;
        esac
        case "$(readlink -f "$_dn_if/device" 2>/dev/null || :)" in
            *usb*) printf '%s\n' "$_dn_name"; return 0 ;;
        esac
    done
    return 1
}

# AI (Big Pickle) ADDITION — Beta-v2.9.86 [BR0-SKIP]: the hardware-presence
# predicate behind the br0-skip decision — answers "is there ANY physical
# wired netdev on this machine", carrier and USB irrelevant. detect_wired_nic
# answers a different question ("which NIC should we USE right now": active
# link first, then a present USB device); an unplugged built-in PCIe port
# returns empty from it even though the hardware exists, so its result alone
# must NOT drive the skip — that would kill the bridge on a cable-unplugged
# desktop a later plug-in would fix via the role-matched br0-slave.
# Protection set mirrors the helper's passes (physical `device` link, no
# `wireless` dir, name skip list) minus the carrier/USB requirements.
# CONDITION-ONLY under set -eE: returns 1 when absent — call from if/elif
# only, never bare (the 2.9.85 ERR-trap rule).
has_wired_nic_hw() {
    local _hw_if _hw_name
    for _hw_if in /sys/class/net/*; do
        [ -e "$_hw_if/device" ] || continue          # physical only — drops lo/br0/docker0/veth/...
        [ -d "$_hw_if/wireless" ] && continue         # never a radio
        _hw_name="${_hw_if##*/}"
        case "$_hw_name" in
            lo|ww*|wl*|bn*|bt*|dm-*) continue ;;      # non-wired by name (same list as detect_wired_nic)
        esac
        return 0
    done
    return 1
}

# =============================================================================
# AI (Big Pickle) CHANGE — Beta-v2.4.0 [RESUME]: The entire interactive
# configuration block below is skipped on a resumed run (RESUME=1); all
# answers are restored from the state file instead of being re-prompted.
# On a fresh run (RESUME=0) this block behaves exactly as before.
# =============================================================================
if [ "$RESUME" != "1" ]; then
echo ""
echo "${C_BOLD}${C_BLU}Account privilege model${C_RST}"
echo "  ${C_BOLD}1)${C_RST} Hybrid — root has a password AND your user gets full sudo access"
echo "  ${C_BOLD}2)${C_RST} Debian-style — root has a password; your user is NOT in sudo (su - only)"
echo "  ${C_BOLD}3)${C_RST} Ubuntu-style — root is locked; your user gets full sudo access (your own password)"
while true; do
    ask "Enter choice [1/2/3]: "
    read -r ACCOUNT_MODEL_INPUT
    case "$ACCOUNT_MODEL_INPUT" in
        1) ACCOUNT_MODEL="hybrid"; break ;;
        2) ACCOUNT_MODEL="debian"; break ;;
        3) ACCOUNT_MODEL="ubuntu"; break ;;
        *) echo "Please enter 1, 2, or 3." >&2 ;;
    esac
done
export ACCOUNT_MODEL

# AI (Big Pickle) ADDITION — Beta-v2.5.2 [SHELL]: real login-shell choice.
# bash is the Void default (present in base-system), so it needs no package.
# zsh/fish/mksh are installed from the official repos when selected. Stored as
# the shell binary path (USER_SHELL) plus the xbps package providing it
# (USER_SHELL_PKG, empty for the bundled bash) so the chroot can install and
# wire it up without hardcoding a package lookup.
echo ""
echo "${C_BOLD}${C_BLU}Login shell${C_RST}"
echo "  ${C_BOLD}1)${C_RST} bash  (default; included in base-system)"
echo "  ${C_BOLD}2)${C_RST} zsh"
echo "  ${C_BOLD}3)${C_RST} fish"
echo "  ${C_BOLD}4)${C_RST} mksh"
while true; do
    ask "Enter choice [1-4, default ${DEFAULT_LOGIN_SHELL}]: "
    read -r USER_SHELL_INPUT
    USER_SHELL_INPUT="${USER_SHELL_INPUT:-$DEFAULT_LOGIN_SHELL}"
    case "$USER_SHELL_INPUT" in
        ""|1) USER_SHELL="/bin/bash";  USER_SHELL_PKG="";       break ;;
        2)    USER_SHELL="/bin/zsh";   USER_SHELL_PKG="zsh";    break ;;
        3)    USER_SHELL="/usr/bin/fish"; USER_SHELL_PKG="fish-shell"; break ;;
        4)    USER_SHELL="/bin/mksh";  USER_SHELL_PKG="mksh";   break ;;
        *) echo "Please enter 1, 2, 3, or 4." >&2 ;;
    esac
done
export USER_SHELL USER_SHELL_PKG

if [ "$ACCOUNT_MODEL" != "ubuntu" ]; then
    read_password_twice "root" ROOT_PASSWORD
else
    ROOT_PASSWORD=""
fi

# Prompt for the target account name
echo ""
echo "${C_BOLD}${C_BLU}System identity${C_RST}"
while true; do
    ask "Enter the username to create on the target system: "
    read -r TARGET_USER
    if [[ "$TARGET_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        break
    fi
    echo "Invalid username. Use lowercase letters, digits, '_' or '-', starting with a letter or '_'." >&2
done
export TARGET_USER

# AI (Big Pickle) ADDITION — Beta-v2.6.3 [FULLNAME]: prompt for the user's
# real (display) name, e.g. "John Doe", used for the account GECOS field so logins
# (and greeters/`finger`) show a friendly name instead of the bare username.
# Deliberately permissive — any printable text is accepted (a name is free-form);
# only the trailing-newline from `read -r` is stripped.
echo ""
ask "Enter the full name of $TARGET_USER (e.g., 'John Doe'): "
read -r TARGET_FULL_NAME
export TARGET_FULL_NAME

read_password_twice "${TARGET_USER}" TARGET_USER_PASSWORD

while true; do
    ask "Enter target system hostname (e.g., myhostname): "
    read -r TARGET_HOSTNAME
    if [[ "$TARGET_HOSTNAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]$ ]]; then
        break
    fi
    echo "Invalid hostname. Use letters, digits, or '-' characters only." >&2
done
export TARGET_HOSTNAME

# AI (Claude, Sonnet 5, Medium) ADDITION: Added a domain-name prompt right after the hostname
# prompt so the two can be combined into a proper FQDN (hostname.domain).
# Optional — leave blank to keep TARGET_HOSTNAME as-is with no domain suffix.
# A confirmation step shows the resulting FQDN and loops back to re-enter
# the domain if it isn't what the user intended.
while true; do
    while true; do
        ask "Enter network domain name (e.g., example.com) to form a FQDN (optional, press Enter to skip): "
        read -r TARGET_DOMAIN
        if [ -z "$TARGET_DOMAIN" ] || [[ "$TARGET_DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$ ]]; then
            break
        fi
        echo "Invalid domain. Use dot-separated labels of letters, digits, or '-' (e.g., example.com)." >&2
    done

    if [ -n "$TARGET_DOMAIN" ]; then
        TARGET_FQDN="${TARGET_HOSTNAME}.${TARGET_DOMAIN}"
    else
        TARGET_FQDN="${TARGET_HOSTNAME}"
    fi

    ask "This system's FQDN will be: ${C_BOLD}${C_CYN}${TARGET_FQDN}${C_RST} — is this correct? [Y/n]: "
    read -r FQDN_CONFIRM
    case "$FQDN_CONFIRM" in
        [nN]*) continue ;;
        *) break ;;
    esac
done
export TARGET_DOMAIN
export TARGET_FQDN

# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.4.0 [LOCALIZE]: REAL LOCALIZATION.
# System language/locale and timezone are now real install-time choices. On
# the installed system the chosen locale is generated (via
# /etc/default/libc-locales + glibc-locales), set as the active system
# language (LANG in /etc/locale.conf), and /etc/localtime is symlinked to the
# chosen IANA zone. A curated set of common locales/zones is offered, plus a
# custom entry for anything else.
# =============================================================================
echo ""
echo "${C_BOLD}${C_BLU}Language / locale${C_RST} (system language; default en_US.UTF-8)"
echo "  ${C_BOLD}1)${C_RST} ${C_GRN}en_US.UTF-8 (English / US) — default${C_RST}"
echo "  ${C_BOLD}2)${C_RST} en_GB.UTF-8 (English / UK)"
echo "  ${C_BOLD}3)${C_RST} de_DE.UTF-8 (German / Germany)"
echo "  ${C_BOLD}4)${C_RST} es_ES.UTF-8 (Spanish / Spain)"
echo "  ${C_BOLD}5)${C_RST} fr_FR.UTF-8 (French / France)"
echo "  ${C_BOLD}6)${C_RST} it_IT.UTF-8 (Italian / Italy)"
echo "  ${C_BOLD}7)${C_RST} pt_PT.UTF-8 (Portuguese / Portugal)"
echo "  ${C_BOLD}8)${C_RST} nl_NL.UTF-8 (Dutch / Netherlands)"
echo "  ${C_BOLD}9)${C_RST} ru_RU.UTF-8 (Russian)"
echo "  ${C_BOLD}10)${C_RST} ja_JP.UTF-8 (Japanese)"
echo "  ${C_BOLD}11)${C_RST} zh_CN.UTF-8 (Chinese / Simplified)"
echo "  ${C_BOLD}12)${C_RST} Custom (type a POSIX locale, e.g. pl_PL.UTF-8)"
while true; do
    ask "Enter locale choice [1-12, default ${DEFAULT_LOCALE}]: "
    read -r LOCALE_INPUT
    case "${LOCALE_INPUT:-$DEFAULT_LOCALE}" in
        1)  LOCALE="en_US.UTF-8"; LOCALE_CODESET="UTF-8"; break ;;
        2)  LOCALE="en_GB.UTF-8"; LOCALE_CODESET="UTF-8"; break ;;
        3)  LOCALE="de_DE.UTF-8"; LOCALE_CODESET="UTF-8"; break ;;
        4)  LOCALE="es_ES.UTF-8"; LOCALE_CODESET="UTF-8"; break ;;
        5)  LOCALE="fr_FR.UTF-8"; LOCALE_CODESET="UTF-8"; break ;;
        6)  LOCALE="it_IT.UTF-8"; LOCALE_CODESET="UTF-8"; break ;;
        7)  LOCALE="pt_PT.UTF-8"; LOCALE_CODESET="UTF-8"; break ;;
        8)  LOCALE="nl_NL.UTF-8"; LOCALE_CODESET="UTF-8"; break ;;
        9)  LOCALE="ru_RU.UTF-8"; LOCALE_CODESET="UTF-8"; break ;;
        10) LOCALE="ja_JP.UTF-8"; LOCALE_CODESET="UTF-8"; break ;;
        11) LOCALE="zh_CN.UTF-8"; LOCALE_CODESET="UTF-8"; break ;;
        12)
            ask "Type the locale (e.g. pl_PL.UTF-8): "
            read -r LOCALE
            if [ -z "$LOCALE" ] || ! [[ "$LOCALE" =~ ^[a-z]{2,3}_[A-Z]{2}([.@][A-Za-z0-9-]+)?$ ]]; then
                echo "Invalid locale; falling back to en_US.UTF-8." >&2
                LOCALE="en_US.UTF-8"
            fi
            case "$LOCALE" in
                *.UTF-8)        LOCALE_CODESET="UTF-8" ;;
                *ISO-8859-1)    LOCALE_CODESET="ISO-8859-1" ;;
                *)              LOCALE_CODESET="UTF-8" ;;
            esac
            break ;;
        *) echo "Please enter a number 1-12." >&2 ;;
    esac
done
export LOCALE LOCALE_CODESET

echo ""
echo "${C_BOLD}${C_BLU}Timezone${C_RST} (system time zone; default America/New_York)"
echo "  ${C_BOLD}1)${C_RST} ${C_GRN}America/New_York — default${C_RST}"
echo "  ${C_BOLD}2)${C_RST} America/Chicago"
echo "  ${C_BOLD}3)${C_RST} America/Denver"
echo "  ${C_BOLD}4)${C_RST} America/Los_Angeles"
echo "  ${C_BOLD}5)${C_RST} America/Sao_Paulo"
echo "  ${C_BOLD}6)${C_RST} Europe/London"
echo "  ${C_BOLD}7)${C_RST} Europe/Paris"
echo "  ${C_BOLD}8)${C_RST} Europe/Berlin"
echo "  ${C_BOLD}9)${C_RST} Europe/Madrid"
echo "  ${C_BOLD}10)${C_RST} Europe/Rome"
echo "  ${C_BOLD}11)${C_RST} Europe/Moscow"
echo "  ${C_BOLD}12)${C_RST} Asia/Tokyo"
echo "  ${C_BOLD}13)${C_RST} Asia/Shanghai"
echo "  ${C_BOLD}14)${C_RST} Asia/Kolkata"
echo "  ${C_BOLD}15)${C_RST} Custom (type an IANA zone, e.g. Australia/Sydney)"
while true; do
    ask "Enter timezone choice [1-15, default ${DEFAULT_TIMEZONE}]: "
    read -r TZ_INPUT
    case "${TZ_INPUT:-$DEFAULT_TIMEZONE}" in
        1)  TIMEZONE="America/New_York"; break ;;
        2)  TIMEZONE="America/Chicago"; break ;;
        3)  TIMEZONE="America/Denver"; break ;;
        4)  TIMEZONE="America/Los_Angeles"; break ;;
        5)  TIMEZONE="America/Sao_Paulo"; break ;;
        6)  TIMEZONE="Europe/London"; break ;;
        7)  TIMEZONE="Europe/Paris"; break ;;
        8)  TIMEZONE="Europe/Berlin"; break ;;
        9)  TIMEZONE="Europe/Madrid"; break ;;
        10) TIMEZONE="Europe/Rome"; break ;;
        11) TIMEZONE="Europe/Moscow"; break ;;
        12) TIMEZONE="Asia/Tokyo"; break ;;
        13) TIMEZONE="Asia/Shanghai"; break ;;
        14) TIMEZONE="Asia/Kolkata"; break ;;
        15)
            ask "Type timezone (e.g. Australia/Sydney, or UTC): "
            read -r TIMEZONE
            # Accept Area/City form, or a bare valid single token (e.g. UTC/GMT).
            # Final validity is enforced against the target's tzdata in the
            # chroot, which falls back to UTC if the zone is absent.
            if [ -z "$TIMEZONE" ] || ! [[ "$TIMEZONE" =~ ^[A-Za-z_]+(/[A-Za-z_/+-]+)?$ ]]; then
                echo "Invalid timezone; falling back to America/New_York." >&2
                TIMEZONE="America/New_York"
            fi
            break ;;
        *) echo "Please enter a number 1-15." >&2 ;;
    esac
done
export TIMEZONE

# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.4.1 [MIRROR]: REGIONAL OFFICIAL MIRROR SELECTION.
# xmirror.voidlinux.org is Void's authoritative mirror registry. To give the
# installer better global reach, we auto-derive a region-appropriate official
# mirror from the timezone chosen above, then let the user override it.
#
# All URLs below were live-verified (HTTP 200 + valid x86_64-repodata) against
# the registry at xmirror.voidlinux.org before being baked in. Only the OFFICIAL
# Void repos are affected here; the community COSMIC repo is pinned separately
# and stays untouched.
# =============================================================================
# Derive a default region/mirror from the selected timezone (its continent).
case "$TIMEZONE" in
    America/Sao_Paulo|America/Argentina/*|America/La_Paz|America/Bogota|America/Lima|America/Caracas|America/Santiago|America/Buenos_Aires|America/Mexico_City)
        MIRROR_REGION="south-america"; MIRROR_AUTO="https://void.voidbr.org/voidlinux/current" ;;
    America/*|Canada/*)
        MIRROR_REGION="north-america"; MIRROR_AUTO="https://mirrors.summithq.com/voidlinux/current" ;;
    Europe/*)
        MIRROR_REGION="europe"; MIRROR_AUTO="https://repo-de.voidlinux.org/current" ;;
    Asia/*|Indian/*)
        MIRROR_REGION="asia"; MIRROR_AUTO="https://mirrors.tuna.tsinghua.edu.cn/voidlinux/current" ;;
    Australia/*|Pacific/*)
        MIRROR_REGION="oceania"; MIRROR_AUTO="https://mirror.aarnet.edu.au/pub/voidlinux/current" ;;
    *)
        MIRROR_REGION="global"; MIRROR_AUTO="https://repo-default.voidlinux.org/current" ;;
esac
export MIRROR_REGION

echo ""
echo "${C_BOLD}${C_BLU}Official repo mirror${C_RST} (regional selection from xmirror.voidlinux.org)"
echo "  Auto-selected region for timezone '${TIMEZONE}': ${C_BOLD}${MIRROR_REGION}${C_RST}"
echo "  ${C_BOLD}1)${C_RST} ${C_GRN}Auto (region-based) — ${MIRROR_AUTO}${C_RST}"
echo "  ${C_BOLD}2)${C_RST} Global Fastly CDN — https://repo-fastly.voidlinux.org/current"
echo "  ${C_BOLD}3)${C_RST} Global default (tier-1) — https://repo-default.voidlinux.org/current"
echo "  ${C_BOLD}4)${C_RST} North America — https://mirrors.summithq.com/voidlinux/current"
echo "  ${C_BOLD}5)${C_RST} Europe (Germany) — https://repo-de.voidlinux.org/current"
echo "  ${C_BOLD}6)${C_RST} Asia (China) — https://mirrors.tuna.tsinghua.edu.cn/voidlinux/current"
echo "  ${C_BOLD}7)${C_RST} Oceania (Australia) — https://mirror.aarnet.edu.au/pub/voidlinux/current"
echo "  ${C_BOLD}8)${C_RST} South/Central America (Brazil) — https://void.voidbr.org/voidlinux/current"
while true; do
    ask "Enter mirror choice [1-8, default 1]: "
    read -r MIRROR_INPUT
    case "${MIRROR_INPUT:-1}" in
        1)  REPO_PRIMARY="$MIRROR_AUTO"; break ;;
        2)  REPO_PRIMARY="https://repo-fastly.voidlinux.org/current"; break ;;
        3)  REPO_PRIMARY="https://repo-default.voidlinux.org/current"; break ;;
        4)  REPO_PRIMARY="https://mirrors.summithq.com/voidlinux/current"; break ;;
        5)  REPO_PRIMARY="https://repo-de.voidlinux.org/current"; break ;;
        6)  REPO_PRIMARY="https://mirrors.tuna.tsinghua.edu.cn/voidlinux/current"; break ;;
        7)  REPO_PRIMARY="https://mirror.aarnet.edu.au/pub/voidlinux/current"; break ;;
        8)  REPO_PRIMARY="https://void.voidbr.org/voidlinux/current"; break ;;
        *) echo "Please enter a number 1-8." >&2 ;;
    esac
done
export REPO_PRIMARY
# Backups stay on the resilient global tiers regardless of the chosen primary —
# Fastly CDN first, then the load-balanced tier-1 default — for wide failover.
REPO_BACKUP1="https://repo-fastly.voidlinux.org/current"
REPO_BACKUP2="https://repo-default.voidlinux.org/current"
export REPO_BACKUP1 REPO_BACKUP2

# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.9.59 [LOCAL-CACHE]: OPTIONAL REUSE OF A
# PRE-SEEDED XBPS PACKAGE CACHE. The installer always mirrored its downloads;
# with the Void_Linux_Live fork building its own KDE ISO+package cache, the raw
# xbps cache on the SAME USB stick can feed this install too. A yes points every
# xbps-install -c (live sync, base bootstrap, and — via a bind mount — the
# chroot installs) at the cache, still falling back to the mirrors per package
# the cache lacks. The cache dir MUST be writable (the -Sy/-Syu repodata
# refresh + COSMIC repo sync write into it) — a read-only medium refuses here
# rather than failing mid-install.
# =============================================================================
AUTO_LOCAL_CACHE=$(_local_cache_detect || true)
LOCAL_CACHE_REUSE="${LOCAL_CACHE_REUSE:-no}"
LOCAL_CACHE_DIR="${LOCAL_CACHE_DIR:-}"
echo ""
echo "${C_BOLD}${C_BLU}Local package cache${C_RST} — reuse already-downloaded XBPS packages instead of re-fetching."
if [ -n "$AUTO_LOCAL_CACHE" ]; then
    echo "  Auto-detected cache on an attached medium: ${C_GRN}${AUTO_LOCAL_CACHE}${C_RST}"
else
    echo "  No mklive-style xbps-cachedir-<arch> cache detected under /run/media."
    echo "  (Place one at <mount>/xbps-cachedir-$(uname -m), or type its absolute path below.)"
fi
ask "Use a local package cache? [y/N] or type an absolute path: "
read -r LOCAL_CACHE_INPUT
case "${LOCAL_CACHE_INPUT:-$DEFAULT_LOCAL_CACHE}" in
    /* )
        if [ -d "$LOCAL_CACHE_INPUT" ] && [ -w "$LOCAL_CACHE_INPUT" ]; then
            LOCAL_CACHE_REUSE="yes"
            LOCAL_CACHE_DIR="$LOCAL_CACHE_INPUT"
        else
            echo "  Path not usable (not a directory, or not writable): ${LOCAL_CACHE_INPUT}" >&2
            LOCAL_CACHE_REUSE="no"
            LOCAL_CACHE_DIR=""
        fi
        ;;
    y|Y|yes|YES)
        LOCAL_CACHE_REUSE="yes"
        if [ -n "$AUTO_LOCAL_CACHE" ] && [ -d "$AUTO_LOCAL_CACHE" ]; then
            LOCAL_CACHE_DIR="$AUTO_LOCAL_CACHE"
        else
            echo "  No cache auto-detected. Place one at <mount>/xbps-cachedir-$(uname -m) on the" >&2
            echo "  medium, or answer with its absolute path instead." >&2
            LOCAL_CACHE_DIR=""
        fi
        ;;
    *)
        LOCAL_CACHE_REUSE="no"
        LOCAL_CACHE_DIR=""
        ;;
esac
if [ "$LOCAL_CACHE_REUSE" = "yes" ] && { [ -z "$LOCAL_CACHE_DIR" ] || [ ! -d "$LOCAL_CACHE_DIR" ] || [ ! -w "$LOCAL_CACHE_DIR" ]; }; then
    echo "!! Local package cache unusable; falling back to a network-only install." >&2
    LOCAL_CACHE_REUSE="no"
    LOCAL_CACHE_DIR=""
fi
if [ "$LOCAL_CACHE_REUSE" = "yes" ]; then
    echo "==> Package cache enabled: ${LOCAL_CACHE_DIR} (mirror fallback stays armed)."
fi
export LOCAL_CACHE_REUSE LOCAL_CACHE_DIR
LOCAL_CA=""
[ "$LOCAL_CACHE_REUSE" = "yes" ] && [ -n "$LOCAL_CACHE_DIR" ] && LOCAL_CA="-c $LOCAL_CACHE_DIR"
export LOCAL_CA
unset LOCAL_CACHE_INPUT AUTO_LOCAL_CACHE

# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.4.0 [SWAP]: REAL SWAP / ZRAM / HIBERNATION
# CHOICE. Swap is no longer a fixed 16.64 GB always-on swapfile. The user now
# picks a backend (disk-backed Btrfs swapfile, compressed-RAM zram, both, or
# none) and — where a disk-backed swapfile exists — whether to enable
# hibernate-to-disk (resume from swap). Hibernation requires the swapfile to
# hold RAM, so when enabled the swapfile is auto-sized to cover it.
# =============================================================================
echo ""
echo "${C_BOLD}${C_BLU}Swap configuration${C_RST} (swap backend; default swapfile)"
echo "  ${C_BOLD}1)${C_RST} ${C_GRN}swapfile (default)${C_RST} — Btrfs swapfile at /var/swap (4G basic, or RAM+25% if hibernation), supports hibernation."
echo "  ${C_BOLD}2)${C_RST} zram — compressed in-RAM swap (module zram, no disk footprint; cannot hibernate)."
echo "  ${C_BOLD}3)${C_RST} swapfile + zram — both, for extra headroom."
echo "  ${C_BOLD}4)${C_RST} none — no swap at all."
while true; do
    ask "Enter swap choice [1-4, default ${DEFAULT_SWAP_BACKEND}]: "
    read -r SWAP_INPUT
    case "${SWAP_INPUT:-$DEFAULT_SWAP_BACKEND}" in
        1) SWAP_BACKEND="swapfile"; break ;;
        2) SWAP_BACKEND="zram"; break ;;
        3) SWAP_BACKEND="both"; break ;;
        4) SWAP_BACKEND="none"; break ;;
        *) echo "Please enter a number 1-4." >&2 ;;
    esac
done
export SWAP_BACKEND
# A reusable helper: does the chosen backend provision a disk swapfile?
if [ "$SWAP_BACKEND" = "swapfile" ] || [ "$SWAP_BACKEND" = "both" ]; then
    SWAPFILE_MODE="true"
else
    SWAPFILE_MODE="false"
fi

# Hibernation is only possible with a disk swapfile large enough to hold RAM;
# it is meaningless (and thus never offered) for zram-only or no-swap.
if [ "$SWAPFILE_MODE" = "true" ]; then
    echo ""
    echo "${C_BOLD}${C_BLU}Hibernation${C_RST} (resume-from-disk; needs the swapfile to hold RAM; default No)"
    ask "Enable hibernation (suspend-to-disk)? [y/N]: "
    read -r HIB_INPUT
    case "$HIB_INPUT" in
        "")     ENABLE_HIBERNATION="$DEFAULT_HIBERNATION" ;;
        [yY]*) ENABLE_HIBERNATION="true" ;;
        *)     ENABLE_HIBERNATION="false" ;;
    esac
else
    ENABLE_HIBERNATION="false"
fi
export ENABLE_HIBERNATION

# AI (Big Pickle) CHANGE — Beta-v2.4.0 [SWAP]: the disk swapfile's size comes from
# the choice below, never a fixed 16.64 GB default.
#  * Hibernation ON  -> the swapfile must hold the RAM image, so it is
#    auto-sized to RAM + 25%, rounded UP to a whole-gigabyte boundary (the
#    current best-practice headroom for a reliable resume): 8 GB -> 10 GB,
#    16 GB -> 20 GB, 32 GB -> 40 GB.
#  * Hibernation OFF -> a flat 2G or 4G swapfile (smaller-than-RAM is fine
#    here because there is no RAM image to hold).
# Size values carry a lowercase "g" suffix: that is the (case) btrfs
# mkswapfile documents for --size, so we don't rely on its parser accepting
# an uppercase variant.
if [ "$ENABLE_HIBERNATION" = "true" ]; then
    _RAM_MB=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
    # Defensive baseline: if RAM can't be read (or reads as 0/non-numeric),
    # assume 8 GiB so the size never degenerates to a 0-sized swapfile.
    _RAM_MB=${_RAM_MB:-8192}
    if [ "${_RAM_MB}" -le 0 ] 2>/dev/null || ! [[ "${_RAM_MB}" =~ ^[0-9]+$ ]]; then
        _RAM_MB=8192
    fi
    _RAM_GB=$(( (_RAM_MB + 1023) / 1024 ))   # whole GiB of RAM, rounded up
    _SWAP_GB=$(( (_RAM_GB * 5 + 3) / 4 ))    # ceil(RAM_GB * 1.25)
    SWAPFILE_SIZE="${_SWAP_GB}g"
    unset _RAM_MB _RAM_GB _SWAP_GB
elif [ "$SWAPFILE_MODE" = "true" ]; then
    echo ""
    echo "${C_BOLD}${C_BLU}Swapfile size${C_RST} (no hibernation; default 4G)"
    echo "  ${C_BOLD}1)${C_RST} ${C_GRN}4G (default)${C_RST}"
    echo "  ${C_BOLD}2)${C_RST} 2G"
    while true; do
        ask "Enter swapfile size choice [1-2, default 1]: "
        read -r SZ_INPUT
        case "${SZ_INPUT:-1}" in
            1) SWAPFILE_SIZE="4g"; break ;;
            2) SWAPFILE_SIZE="2g"; break ;;
            *) echo "Please enter 1 or 2." >&2 ;;
        esac
    done
else
    SWAPFILE_SIZE=""
fi
export SWAPFILE_SIZE

# =============================================================================
# BOOTLOADER CHOICE: GRUB or LIMINE (Beta-v2.4.0) — [LIMINE-1]
# =============================================================================
# AI (Big Pickle) CHANGE — Beta-v2.7.5 [FLOW-ORDER]: reordered this install-
# prompt flow so disk-encryption is decided AFTER the bootloader, and the Limine
# wallpaper is asked immediately after the bootloader choice. Final prompt order
# (swap was already above) is now: bootloader -> Limine wallpaper (limine only)
# -> encryption gate -> YubiKey -> YK clamp -> passphrase/mapper -> audio
# (PipeWire snapshot-autostart). The bootloader then decides the ESP size that
# encryption augments (GRUB+ENCRYPT 4GiB /boot), and the passphrase capture still
# runs only after the bootloader + YK_FALLBACK clamp are final (unchanged
# semantic from [ENCRYPT-ORDER]); the audio choice moved to the tail of this
# cluster. YubiKey still must be decided under ENCRYPT=yes before the clamp.
# AI (Claude, Sonnet 5, Medium) CHANGE — Beta-v2.3.0: Limine was briefly made the ONLY
# bootloader in an earlier pass of this beta (see CHANGELOG §3.19/§4.7 for
# the original GRUB→Limine rationale — smaller trusted codebase, single-
# file portable UEFI deployment with no efibootmgr/NVRAM coupling, a
# plain-text config this script writes directly instead of generating, and
# it retires the whole grub-btrfs chmod-dance failure class). Reverted to a
# real per-install CHOICE at the maintainer's request: GRUB remains the
# mature, extensively real-hardware-tested path from 3.0.112GC (snapshot
# boot via grub-btrfs, confirmed working); Limine is offered alongside it
# as the newer, simpler, but still-experimental alternative from this beta
# line. Both paths coexist in Stage 2 below, gated on $BOOTLOADER.
# AI (Big Pickle) CHANGE — Beta-v2.6.0 [LIMINE-DEFAULT]: the maintainer
# has since switched the default. Limine is now listed FIRST in the menu
# and bare Enter selects it (the mature GRUB path stays as choice 2).
#
# BIOS boot is NOT supported by either path in this script — both GRUB
# (grub-install --target=x86_64-efi) and Limine are installed UEFI-only, so
# the UEFI check applies regardless of which bootloader is chosen.
if [ ! -d /sys/firmware/efi ]; then
    echo "FATAL: this machine does not appear to be booted in UEFI mode." >&2
    echo "       This installer only supports UEFI boot (GRUB and Limine" >&2
    echo "       are both installed via their UEFI paths) — BIOS is not" >&2
    echo "       implemented." >&2
    exit 1
fi

# AI (Big Pickle) CHANGE — Beta-v2.6.0 [LIMINE-DEFAULT]: Limine is now
# listed FIRST and is the DEFAULT bootloader (bare Enter selects it). GRUB
# remains a fully supported, first-class choice at option 2. The reordering
# is presentational only — all $BOOTLOADER-gated logic downstream is
# unchanged (GRUB and Limine remain two separate code paths, per DO NOT #5).
 echo ""
 echo "${C_BOLD}${C_BLU}Choose bootloader${C_RST}  (default: Limine)"
 echo "  ${C_BOLD}1)${C_RST} ${C_GRN}Limine${C_RST} — newer, simpler, single-file UEFI bootloader with no"
 echo "     efibootmgr/NVRAM dependency. Snapshot-boot menu support is a"
 echo "     static config this script writes itself (with the snapper plugin"
 echo "     auto-regenerating it on every snapshot create/delete). Requires"
 echo "     a 4GiB+ EFI partition (ArchWiki's own recommendation for"
 echo "     bootable snapshots, kernel versions, and large early-boot"
 echo "     modules)."
echo "  ${C_BOLD}2)${C_RST} ${C_YLW}GRUB${C_RST} — mature, battle-tested snapshot-boot support via"
  echo "     grub-btrfs. Extensively real-hardware tested on this script's"
  echo "     3.0.x line, including snapshot boot. 1GiB EFI partition."
  echo "     ${C_RED}NOTE: if you then enable full-disk encryption (next prompt), GRUB's"
 echo "     LUKS cryptodisk is bypassed entirely — the ESP is mounted AT /boot so"
 echo "     grub.cfg + kernels stay unencrypted and GRUB never unlocks the disk"
 echo "     (dracut prompts once, after handoff). The ESP grows to 4GiB in that"
 echo "     combo to hold every kernel/initramfs. YubiKey-only unlock still"
 echo "     clamps to passphrase-fallback on GRUB per [YUBIKEY].${C_RST}"
 while true; do
     _boot_default="Limine"
     [ "$DEFAULT_BOOTLOADER" = "2" ] && _boot_default="GRUB"
     ask "Enter choice [1/2] (default ${DEFAULT_BOOTLOADER}: ${_boot_default}): "
     read -r BOOTLOADER_INPUT
     case "${BOOTLOADER_INPUT:-$DEFAULT_BOOTLOADER}" in
         1) BOOTLOADER="limine"
            # AI (Big Pickle) ADDITION — Beta-v2.9.35 [ESP-SIZE]: Limine's
            # esp-copy mirrors kernels + snapshots onto the ESP, so its size is
            # a real prompt-time decision (default 4G via DEFAULT_EFI_ESP_SIZE).
            esp_size_choose
            break ;;
         2) BOOTLOADER="grub"
            # Plain GRUB's ESP holds only the bootloader at /boot/efi and stays
            # fixed 1G — NO size menu here. [GRUB-ESP-SIZE-ORDER] (Beta-v2.9.35):
            # the old in-loop `[ "$ENCRYPT" = "yes" ] && EFI_PART_SIZE="4G"`
            # read ENCRYPT BEFORE the ENCRYPT prompt settled it, so GRUB+ENCRYPT
            # fresh runs always shipped a 1G ESP. The GRUB+ENCRYPT sizing decision
            # now happens AFTER the encryption choice (see the [ENCRYPT] block).
            EFI_PART_SIZE="1G"
            break ;;
         *) echo "Please enter 1 or 2." >&2 ;;
     esac
 done
export BOOTLOADER
export EFI_PART_SIZE

# AI (Big Pickle) ADDITION — Beta-v2.9.16 [KERNEL-SELECT]: real Stage-1 kernel
# choice. Void's x86_64 repo ships exactly three flavors; the base `linux`
# (rolling) is ALWAYS installed (base-system depends on it), so this is a
# toggle pair for the two extras. Bare Enter ships linux + linux-lts (the
# conservative default flipped 2026-09-07 per maintainer request); `y` to both
# gives linux + linux-mainline + linux-lts.
INSTALL_KERNEL_MAINLINE="${DEFAULT_KERNEL_MAINLINE}"
INSTALL_KERNEL_LTS="${DEFAULT_KERNEL_LTS}"
echo ""
echo "${C_BOLD}${C_BLU}Kernel packages${C_RST}"
echo "  The base rolling kernel (linux) is always installed. You can add:"
echo "  ${C_BOLD}linux-mainline${C_RST} — newest features, shortest support window (Void: \"for experts only\")."
echo "  ${C_BOLD}linux-lts${C_RST}      — Long Term Support; most conservative, longest window; best for servers."
while true; do
    ask "${C_GRN}Also install linux-mainline?${C_RST} [y/N]: "
    read -r K_MAINLINE
    case "${K_MAINLINE,,}" in
        y|yes) INSTALL_KERNEL_MAINLINE=true; break ;;
        ""|n|no) INSTALL_KERNEL_MAINLINE=false; break ;;
        *) echo "Please enter y or n." >&2 ;;
    esac
done
while true; do
    ask "${C_GRN}Also install linux-lts?${C_RST} [Y/n]: "
    read -r K_LTS
    case "${K_LTS,,}" in
        ""|y|yes) INSTALL_KERNEL_LTS=true; break ;;
        n|no) INSTALL_KERNEL_LTS=false; break ;;
        *) echo "Please enter y or n." >&2 ;;
    esac
done
KERNEL_PKGS="linux"
[ "$INSTALL_KERNEL_MAINLINE" = "true" ] && KERNEL_PKGS="$KERNEL_PKGS linux-mainline"
[ "$INSTALL_KERNEL_LTS" = "true" ] && KERNEL_PKGS="$KERNEL_PKGS linux-lts"
export INSTALL_KERNEL_MAINLINE INSTALL_KERNEL_LTS KERNEL_PKGS
echo "  Resolved kernel set: ${KERNEL_PKGS}"

# AI (Big Pickle) ADDITION — Beta-v2.9.17 [DEVICE-PROFILE]: laptop vs
# desktop/server — a real Stage-1 choice gating tlp (battery power), the
# bluetooth stack, and preload. Resolved to a CONCRETE profile
# (laptop-bt/laptop/desktop-bt/desktop, never "auto") plus the three booleans
# that actually drive the install.
DEVICE_PROFILE=""
PROFILE_TLP="false"
PROFILE_BT="false"
PROFILE_PRELOAD="false"
echo ""
echo "${C_BOLD}${C_BLU}Device profile${C_RST}"
echo "  What kind of machine is this? Gates tlp (battery power management),"
echo "  the bluetooth stack, and preload (adaptive readahead cache):"
echo "  ${C_BOLD}1)${C_RST} Automatic (default) — probe chassis + bluetooth hardware, then confirm/override"
echo "  ${C_BOLD}2)${C_RST} Laptop with Bluetooth"
echo "  ${C_BOLD}3)${C_RST} Laptop, no Bluetooth"
echo "  ${C_BOLD}4)${C_RST} Desktop/server with Bluetooth"
echo "  ${C_BOLD}5)${C_RST} Desktop/server, no Bluetooth"
_bt_hw="no"
for _m in /sys/bus/usb/devices/*/modalias /sys/bus/usb/devices/*/*/modalias; do
    [ -r "$_m" ] || continue
    if grep -qi 'icE0isc01ip01' "$_m"; then _bt_hw="yes"; break; fi
done
# AI (Big Pickle) ADDITION — Beta-v2.9.24 [DEVICE-PROFILE-BT-DETECT]: tell the
# user what the hardware probe actually found (current revision of the auto
# path below already feeds $PROFILE_BT from it — these lines make the probe
# visible instead of silently deciding the bluetooth stack).
if [ "$_bt_hw" = "yes" ]; then
    echo "  Bluetooth hardware probe: controller detected"
else
    echo "  Bluetooth hardware probe: no Bluetooth controller found"
fi
_cc="$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || true)"
_auto_device_profile="" # resolved inside the loop below per Auto path
while true; do
    ask "Enter choice [1/2/3/4/5] (default ${DEFAULT_DEVICE_PROFILE}: Automatic): "
    read -r DP_INPUT
    case "${DP_INPUT:-$DEFAULT_DEVICE_PROFILE}" in
        1)
            case "$_cc" in
                8|9|10|11|14|30|31|32) DEVICE_PROFILE="laptop-bt" ;;
                3|4|5|6|7|13|15) DEVICE_PROFILE="desktop-bt" ;;
                *) DEVICE_PROFILE="laptop-bt" ;;  # unresolvable → historical laptop baseline
            esac
            [ "$_bt_hw" = "yes" ] && case "$DEVICE_PROFILE" in
                desktop*) DEVICE_PROFILE="desktop-bt" ;;
                *) DEVICE_PROFILE="laptop-bt" ;;
            esac
            case "$_bt_hw" in
                no) case "$DEVICE_PROFILE" in
                        desktop*) DEVICE_PROFILE="desktop" ;;
                        *) DEVICE_PROFILE="laptop" ;;
                    esac ;;
            esac
            # AI (Big Pickle) ADDITION — Beta-v2.9.19c [DEVICE-PROFILE-CONFIRM]:
            # Automatic used to silently accept whatever SMBIOS resolved (or the
            # unresolvable fallback) with no feedback and no way to correct a
            # wrong guess before the tlp/bluez/preload gates committed. Now the
            # detected profile is shown and the user can confirm it (bare
            # Enter / y / yes) or override to 2-5. An unresolvable chassis still
            # falls back to laptop-bt but the user is told so and gets the same
            # confirm/override chance.
            show_profile() {
                case "$DEVICE_PROFILE" in
                    laptop-bt)  _dp_desc="Laptop with Bluetooth" ;;
                    laptop)     _dp_desc="Laptop, no Bluetooth" ;;
                    desktop-bt) _dp_desc="Desktop/server with Bluetooth" ;;
                    desktop)    _dp_desc="Desktop/server, no Bluetooth" ;;
                esac
                echo "  Detected profile: ${DEVICE_PROFILE} (${_dp_desc})"
            }
            show_profile
            while true; do
                ask "   Keep this profile? [Y/n] or pick 2-5 to override: "
                read -r DP_CONFIRM
                case "${DP_CONFIRM:-y}" in
                    y|Y|yes|YES) break ;;
                    n|N|no|NO)
                        echo "  Overriding — pick an explicit profile from the menu (2-5)." >&2 ;;
                    2) DEVICE_PROFILE="laptop-bt"; show_profile; break ;;
                    3) DEVICE_PROFILE="laptop"; show_profile; break ;;
                    4) DEVICE_PROFILE="desktop-bt"; show_profile; break ;;
                    5) DEVICE_PROFILE="desktop"; show_profile; break ;;
                    *) echo "  Please enter y to keep, or 2-5 to override." >&2 ;;
                esac
            done
            unset DP_CONFIRM _dp_desc
            unset -f show_profile
            break ;;
        2) DEVICE_PROFILE="laptop-bt"; break ;;
        3) DEVICE_PROFILE="laptop"; break ;;
        4) DEVICE_PROFILE="desktop-bt"; break ;;
        5) DEVICE_PROFILE="desktop"; break ;;
        *) echo "Please enter 1-5." >&2 ;;
    esac
done
case "$DEVICE_PROFILE" in
    laptop-bt) PROFILE_TLP=true;  PROFILE_BT=true;  PROFILE_PRELOAD=false ;;
    laptop)    PROFILE_TLP=true;  PROFILE_BT=false; PROFILE_PRELOAD=false ;;
    desktop-bt)PROFILE_TLP=false; PROFILE_BT=true;  PROFILE_PRELOAD=true ;;
    desktop)   PROFILE_TLP=false; PROFILE_BT=false; PROFILE_PRELOAD=true ;;
esac
unset _bt_hw _cc
export DEVICE_PROFILE PROFILE_TLP PROFILE_BT PROFILE_PRELOAD
echo "  Resolved profile: ${DEVICE_PROFILE} (tlp=${PROFILE_TLP} bluetooth=${PROFILE_BT} preload=${PROFILE_PRELOAD})"

# AI (Big Pickle) ADDITION — Beta-v2.9.25 [HARDWARE-REVIEW]: probe the live
# box for GPU families + wireless presence. Pure sysfs (live hardware ==
# target hardware), no pciutils/lspci on the live CD needed. Results are
# exported + persisted for reuse (the Steam/gaming TODO consumes GPU_FAMILIES
# instead of re-probing). [NVIDIA-GATE] below uses them to gate the one driver
# worth gating: the proprietary NVIDIA driver.
GPU_FAMILIES=""
HAS_NVIDIA_GPU="no"
HAS_AMD_GPU="no"
HAS_INTEL_GPU="no"
for _pci in /sys/bus/pci/devices/*/class; do
    [ -r "$_pci" ] || continue
    _class="$(cat "$_pci" 2>/dev/null || true)"
    case "$_class" in
        0x03*) ;;
        *) continue ;;  # not a display controller
    esac
    _dev="${_pci%/class}"
    _vid="$(cat "$_dev/vendor" 2>/dev/null || true)"
    case "$_vid" in
        0x10de) _fam="NVIDIA" ;;
        0x1002) _fam="AMD" ;;
        0x8086) _fam="Intel" ;;
        0x1a03) _fam="ASPEED (BMC)" ;;
        0x15ad) _fam="VMware" ;;
        0x1234) _fam="QEMU" ;;
        *) _fam="Other" ;;
    esac
    case " $GPU_FAMILIES " in
        *" $_fam "*) : ;;
        *) GPU_FAMILIES="${GPU_FAMILIES:+${GPU_FAMILIES} }${_fam}" ;;
    esac
    case "$_vid" in
        0x10de) HAS_NVIDIA_GPU="yes" ;;
        0x1002) HAS_AMD_GPU="yes" ;;
        0x8086) HAS_INTEL_GPU="yes" ;;
    esac
done
unset _pci _class _dev _vid _fam
WIFI_HW="no"
if ls /sys/class/ieee80211/ >/dev/null 2>&1 && [ -n "$(ls -A /sys/class/ieee80211/ 2>/dev/null)" ]; then
    WIFI_HW="yes"
fi
echo "  Hardware probe: GPU='${GPU_FAMILIES:-<none detected>}'  wireless=${WIFI_HW}"

# AI (Big Pickle) ADDITION — Beta-v2.9.25 [NVIDIA-GATE]: the single
# hardware-gated driver. NVIDIA present → [Y/n] (proprietary driver
# recommended, nouveau is a poor match); absent → [y/N] (nouveau covers most
# use). DEFAULT_INSTALL_NVIDIA=auto follows the probe; exporting yes|no pins.
if [ "$DEFAULT_INSTALL_NVIDIA" = "auto" ]; then
    if [ "$HAS_NVIDIA_GPU" = "yes" ]; then
        _nvidia_default="y"
        _nvidia_prompt="[Y/n]"
    else
        _nvidia_default="n"
        _nvidia_prompt="[y/N]"
    fi
else
    _nvidia_default="$(printf '%s' "$DEFAULT_INSTALL_NVIDIA" | tr '[:upper:]' '[:lower:]')"
    _nvidia_prompt="[${_nvidia_default}?]"
fi
INSTALL_NVIDIA="false"
while true; do
    ask "Install the NVIDIA proprietary driver? ${_nvidia_prompt}: "
    read -r INSTALL_NVIDIA_INPUT
    case "${INSTALL_NVIDIA_INPUT:-$_nvidia_default}" in
        y|Y|yes|YES) INSTALL_NVIDIA="true"; break ;;
        n|N|no|NO) INSTALL_NVIDIA="false"; break ;;
        *) echo "Please answer y or n." >&2 ;;
    esac
done
unset _nvidia_default _nvidia_prompt INSTALL_NVIDIA_INPUT
if [ "$INSTALL_NVIDIA" = "true" ] && [ "$HAS_NVIDIA_GPU" != "yes" ]; then
    echo "  WARNING: no NVIDIA GPU detected on this machine — the proprietary"
    echo "  driver will be installed anyway (ignored by the Intel/AMD GPU)." >&2
fi
echo "  NVIDIA driver: ${INSTALL_NVIDIA} (GPU: ${GPU_FAMILIES:-<none detected>})"
export INSTALL_NVIDIA GPU_FAMILIES HAS_NVIDIA_GPU HAS_AMD_GPU HAS_INTEL_GPU WIFI_HW

# AI (Big Pickle) ADDITION — Beta-v2.9.27 [CPU-DETECT]: read the CPU vendor
# from /proc/cpuinfo on the live box and decide the microcode package
# word-split into the base toolchain install line. intel-ucode for GenuineIntel,
# linux-firmware-amd for AuthenticAMD (already pulled by the default
# linux-firmware dependency wall on AMD); empty for unknown vendors — the
# chroot honors a decided EMPTY verbatim (opt-out / unknown) and only re-derives
# from its own /proc/cpuinfo when MICROCODE_DECIDED is absent.
# auto (default) installs the detected package; no skips it.
MICROCODE_PKG=""
MICROCODE_DECIDED="yes"
if [ "$DEFAULT_MICROCODE" = "no" ]; then
    _cpu_line="SKIPPED (DEFAULT_MICROCODE=no)"
else
    _cpu_vendor="$(awk -F: '/^vendor_id/ {print $2; exit}' /proc/cpuinfo 2>/dev/null | tr -d '[:space:]' || true)"
    case "$_cpu_vendor" in
        GenuineIntel)
            MICROCODE_PKG="intel-ucode"
            _cpu_line="GenuineIntel"
            ;;
        AuthenticAMD)
            MICROCODE_PKG="linux-firmware-amd"
            _cpu_line="AuthenticAMD"
            ;;
        *)
            _cpu_line="$_cpu_vendor"
            ;;
    esac
    unset _cpu_vendor
    if [ -n "$MICROCODE_PKG" ]; then
        _cpu_line="$_cpu_line — microcode: ${MICROCODE_PKG} (auto-installed)"
    else
        if [ -n "$_cpu_line" ]; then
            _cpu_line="$_cpu_line — no vendor microcode package (in-kernel defaults)"
        else
            _cpu_line="<vendor unreadable> — no vendor microcode package (in-kernel defaults)"
        fi
    fi
fi
echo "  Detected CPU : ${_cpu_line}"
unset _cpu_line

# AI (Big Pickle) ADDITION — Beta-v2.9.27 [NIC-DETECT]: detect a carrier-
# active wired NIC (and USB-ethernet adapters) for the bridged VM network,
# confirm or override it here in the review instead of silently in the virt
# phase. Wireless and non-physical devices are excluded. Nothing found → empty
# → the existing INSTALL_VIRT-gated late re-probe (plug in a USB ethernet
# adapter in the SAME USB port) runs untouched. DEFAULT_NIC=<name> pins it and
# skips both this prompt and the late probe.
_NIC_NAME=""
if [ -n "$DEFAULT_NIC" ]; then
    _NIC_NAME="$DEFAULT_NIC"
else
    # AI (Big Pickle) FIX — Beta-v2.9.85 [NIC-DETECT-USB]: was two inline
    # loops — the carrier loop had no physical-device check, and the USB
    # fallback's /sys/devices/*/net/* glob could never match real hardware
    # (see detect_wired_nic above). One shared helper now, identical in
    # behavior to the late re-probe's, so this review and the br0-slave
    # binding can never disagree.
    _NIC_NAME="$(detect_wired_nic || true)"
fi
if [ -n "$_NIC_NAME" ]; then
    echo "  Detected wired NIC : $_NIC_NAME (feeds the bridged VM network if you choose virtualization)"
    while true; do
        ask "Keep this interface? [Y/n] or type another name: "
        read -r _nic_input
        case "${_nic_input:-y}" in
            y|Y|yes|YES) break ;;
            n|N|no|NO) _NIC_NAME=""; break ;;
            *) _NIC_NAME="$_nic_input"; break ;;
        esac
    done
else
    echo "  Detected wired NIC : (none detected — late re-probe will decide if you choose virtualization)"
fi
BR0_NIC="$_NIC_NAME"
unset _NIC_NAME _nic_input
echo "  Bridged-VM NIC : ${BR0_NIC:-<not set>}"
export BR0_NIC

# AI (Big Pickle) ADDITION — Beta-v2.9.26 [WIFI-FW]: name the actual radios,
# map each vendor to the firmware package that covers it (so an installer sees
# WHY no extra download is needed), and close the single gap Void leaves by
# default — Broadcom.  More detail in the # comment block above the prompt.
# The verify (post-kernel-reconfigure, inside the target) is [WIFI-FW-VERIFY].
# Pure sysfs: enumerate phy* → device symlink (works for PCI and USB radios);
# a PCI class-0x0280* fallback catches radios the live kernel won't bind
# (firmware alone can't fix those — the verify warns instead of pretending).
WIFI_IDS=""
WIFI_CHIPS=""
WIFI_FW_PKG=""
INSTALL_WIFI_FW="false"
for _phy in /sys/class/ieee80211/phy*/device; do
    [ -e "$_phy" ] || continue
    _vendor="$(cat "$_phy/vendor" 2>/dev/null || cat "$_phy/../../idVendor" 2>/dev/null || true)"
    _device="$(cat "$_phy/device" 2>/dev/null || cat "$_phy/../../idProduct" 2>/dev/null || true)"
    _wid="${_vendor:-??}:${_device:-??}"
    case " $WIFI_IDS " in
        *" $_wid "*) : ;;
        *) WIFI_IDS="${WIFI_IDS:+${WIFI_IDS} }${_wid}" ;;
    esac
    case "$_vendor" in
        0x14c3) _chip="MediaTek (mt76)" ;;
        0x10ec) _chip="Realtek (rtw88/rtw89)" ;;
        0x8086) _chip="Intel (iwlwifi)" ;;
        0x168c) _chip="Qualcomm/Atheros (ath9k/10k/11k)" ;;
        0x14e4) _chip="Broadcom (brcmfmac/b43)" ;;
        0x17cb) _chip="Qualcomm (qca)" ;;
        0x1a3b) _chip="NVIDIA (uefi wifi — driverless)" ;;
        *) _chip="unknown vendor (${_vendor:-??})" ;;
    esac
    case " $WIFI_CHIPS " in
        *" $_chip "*) : ;;
        *) WIFI_CHIPS="${WIFI_CHIPS:+${WIFI_CHIPS} }${_chip}" ;;
    esac
done
# PCI class-0x0280* fallback: a radio the live kernel cannot bind has no phy*
# but still shows as a 0x0280 PCI network device. Identify it as best we can
# and mark coverage as unverifiable (firmware alone can't bind a driverless
# out-of-tree radio anyway).
if [ -z "$WIFI_IDS" ]; then
    for _pci in /sys/bus/pci/devices/*/class; do
        [ -r "$_pci" ] || continue
        case "$(cat "$_pci" 2>/dev/null || true)" in
            0x0280*) ;;
            *) continue ;;
        esac
        _dev="${_pci%/class}"
        _vendor="$(cat "$_dev/vendor" 2>/dev/null || true)"
        _device="$(cat "$_dev/device" 2>/dev/null || true)"
        _wid="${_vendor:-??}:${_device:-??}"
        case " $WIFI_IDS " in
            *" $_wid "*) : ;;
            *) WIFI_IDS="${WIFI_IDS:+${WIFI_IDS} }${_wid}" ;;
        esac
        _chip="unbound PCI wireless (vendor ${_vendor:-??})"
        case " $WIFI_CHIPS " in
            *" $_chip "*) : ;;
            *) WIFI_CHIPS="${WIFI_CHIPS:+${WIFI_CHIPS} }${_chip}" ;;
        esac
    done
fi
unset _phy _vendor _device _wid _chip _pci _dev

# Coverage print — every mainstream vendor is default-covered by Void:
# linux-firmware-network/-amd/-intel (+ base linux-firmware); wifi-firmware
# (via base-system) covers legacy ipw2100/ipw2200/zd1211. Broadcom is NOT
# pulled by anything → the one genuine gap → the prompt below.
if [ -n "$WIFI_IDS" ]; then
    echo "  WiFi: ${WIFI_IDS} (${WIFI_CHIPS})"
    case "$WIFI_IDS" in
        *0x14e4:*) echo "  Firmware coverage: Broadcom radio detected — NOT covered by Void defaults (linux-firmware-broadcom split)." ;;
        *) echo "  Firmware coverage: covered by default linux-firmware (+ wifi-firmware) — no extra download needed." ;;
    esac
else
    echo "  WiFi: no wireless radio detected (${WIFI_HW:-none})"
fi

# Gap prompt — ONLY on a Broadcom radio. DEFAULT_WIFI_FW=auto → yes; exporting
# yes|no pins it. Non-Broadcom hardware never sees this prompt.
case "$WIFI_IDS" in
    *0x14e4:*)
        if [ "$DEFAULT_WIFI_FW" = "auto" ]; then
            _wifi_fw_default="y"
            _wifi_fw_prompt="[Y/n]"
        else
            _wifi_fw_default="$(printf '%s' "$DEFAULT_WIFI_FW" | tr '[:upper:]' '[:lower:]')"
            _wifi_fw_prompt="[${_wifi_fw_default}?]"
        fi
        while true; do
            ask "Install linux-firmware-broadcom (firmware for the detected Broadcom radio)? ${_wifi_fw_prompt}: "
            read -r INSTALL_WIFI_FW_INPUT
            case "${INSTALL_WIFI_FW_INPUT:-$_wifi_fw_default}" in
                y|Y|yes|YES) INSTALL_WIFI_FW="true"; WIFI_FW_PKG="linux-firmware-broadcom"; break ;;
                n|N|no|NO)
                    INSTALL_WIFI_FW="false"; WIFI_FW_PKG=""
                    echo "  WARNING: declining Broadcom firmware — the detected radio will NOT work."
                    echo "  Reinstall with linux-firmware-broadcom, or xbps-install it post-install." >&2
                    break ;;
                *) echo "Please answer y or n." >&2 ;;
            esac
        done
        unset _wifi_fw_default _wifi_fw_prompt INSTALL_WIFI_FW_INPUT ;;
esac
[ -n "$WIFI_IDS" ] && echo "  Broadcom firmware decision: ${INSTALL_WIFI_FW}${WIFI_FW_PKG:+ (${WIFI_FW_PKG})}"
export INSTALL_WIFI_FW WIFI_IDS WIFI_CHIPS WIFI_FW_PKG

# AI (Big Pickle) ADDITION — Beta-v2.5.1 [LIMINE-WALLPAPER]: optional boot-
# screen background image for Limine. Void's limine package ships the plain
# (non-"gui") binary — this script deploys exactly that BOOTX64.EFI — and
# Limine's `wallpaper:` directive (BMP/PNG/JPEG/QOI) works fine with it,
# it is NOT a limine-gui-only feature. A wallpaper image is not something
# this installer can invent, so it is an opt-in drop-in: if the user points
# the prompt here at an image file on the live system (e.g. copied off a USB
# stick) and picks a fit style, the installer stages it, copies it onto the
# ESP at a fixed path (/boot/efi/limine-splash.<ext> → boot():/limine-splash.<ext>)
# and records the choice in limine-env so the menu generator re-emits
# wallpaper:/wallpaper_style on every resync. If the user declines, or the
# staged/ESP file is missing later, no wallpaper lines are emitted and the
# menu is untouched (safe default).
LIMINE_WALLPAPER="none"
LIMINE_WALLPAPER_STYLE="stretched"
if [ "$BOOTLOADER" = "limine" ]; then
    echo ""
    echo "${C_BOLD}${C_BLU}Limine boot-screen background${C_RST}"
    echo "  Add a wallpaper to the Limine boot menu? (BMP/PNG/JPEG/QOI)"
    echo "  Decline for the plain default look. If enabled, point the next"
    echo "  prompt at an image file on this live system (e.g. copied onto"
    echo "  the mounted USB stick) — the installer copies it onto the ESP."
    while true; do
        ask "${C_GRN}Enable Limine wallpaper?${C_RST} [y/N]: "
        read -r WP_YN
        case "${WP_YN,,}" in
            y|yes)
                LIMINE_WALLPAPER="yes"
                break ;;
            ""|n|no)
                LIMINE_WALLPAPER="none"
                break ;;
            *) echo "Please enter y or n." >&2 ;;
        esac
    done
    if [ "$LIMINE_WALLPAPER" = "yes" ]; then
        # AI (Big Pickle) CHANGE — Beta-v2.5.4 [LIMINE-WALLPAPER-BROWSE]: instead of
        # only a typed-path prompt, the installer can now BROWSE to the image with a
        # pure-bash numbered `ls` menu (no fzf/dialog — the Void live CD ships
        # neither). Start in /run/media (where a USB stick holding the image is
        # typically mounted) if present, else /root. `..` goes up a level; typing a
        # path (absolute or relative) is still accepted as an escape hatch.
        # AI (Big Pickle) CHANGE — Beta-v2.9.20 [LIMINE-WP-DRIVES]: `..` from inside
        # a mounted drive only climbs to the per-user parent (/run/media/<user>),
        # whose siblings are just that one user's mounts — so drives mounted under a
        # different username parent are invisible and there was no on-screen way back
        # to the "every drive" list. Added explicit jump keywords `m` / `drives` that
        # set WP_DIR back to /run/media (the drive-list root); if /run/media is
        # absent it says so and stays in place instead of jumping to nothing. The
        # keyword check runs BEFORE the path-exists test, so a literal file/dir named
        # `m` or `drives` cannot collide (numbers are expanded to full paths earlier).
        # AI (Big Pickle) CHANGE — Beta-v2.9.23 [SSH-KEYS]: the browser below was
        # refactored into a shared browse_pick() (modes: img = image files,
        # file = any file, dir = directories only) so the SSH key import/export
        # prompts reuse it. The wallpaper prompt is now just the img-mode caller;
        # behavior is unchanged.
        WP_SRC="$(browse_pick img "wallpaper image (BMP/PNG/JPEG/QOI)")" || WP_SRC=""
        if [ -n "$WP_SRC" ]; then
            WP_EXT="${WP_SRC##*.}"
        fi
        echo "  Selected wallpaper: ${WP_SRC:-<none>}"
        if [ -z "$WP_SRC" ]; then
            LIMINE_WALLPAPER="none"
            echo "  No image selected — proceeding without a wallpaper." >&2
        else
        # Style; stretched is Limine's default and the safest with an image
        # that may not match screen aspect — tiled and centered exist too.
        while true; do
            ask "Wallpaper style [1=stretched/2=tiled/3=centered] [1]: "
            read -r WP_STYLE_INPUT
            case "${WP_STYLE_INPUT:-1}" in
                1) LIMINE_WALLPAPER_STYLE="stretched"; break ;;
                2) LIMINE_WALLPAPER_STYLE="tiled"; break ;;
                3) LIMINE_WALLPAPER_STYLE="centered"; break ;;
                *) echo "Please enter 1, 2, or 3." >&2 ;;
            esac
        done
        # Stage the image for the chroot phase: /mnt/tmp inside the live env
        # is /tmp inside the chroot (same path /mnt/tmp/chroot_env.sh uses),
        # so the ESP copy can happen later from a path the chroot can see.
        WP_STAGED="/mnt/tmp/limine-splash.${WP_EXT,,}"
        mkdir -p /mnt/tmp
        cp -f "$WP_SRC" "$WP_STAGED"
        echo "  Wallpaper staged → ${WP_STAGED}"
        fi
    fi
fi
export LIMINE_WALLPAPER
export LIMINE_WALLPAPER_STYLE

# AI (Big Pickle) ADDITION — Beta-v2.5.5 [ENCRYPT]: optional LUKS2 full-disk
# encryption of partition 2 (the Btrfs filesystem). The ESP stays
# unencrypted. When enabled, the user types a passphrase (twice, hiding it)
# so it never lands on screen. Since Beta-v2.5.4 this passphrase can be
# supplemented or replaced by YubiKey hmac-sha1 unlock ([YUBIKEY]);
# AI (Big Pickle) CHANGE — Beta-v2.6.0 [ENCRYPT-ORDER]: the actual typed
# passphrase is now captured AFTER this yes/no gate — specifically after the
# YubiKey menu AND the bootloader choice + YK_FALLBACK clamp — so the capture
# prompt can tell the user truthfully whether this passphrase is (a) a
# YubiKey-only one-time provisioning secret that will be removed
# (YK_FALLBACK=no), (b) the boot fallback alongside the YubiKey
# (YK_FALLBACK=yes), or (c) the plain every-boot passphrase. The ordering was
# forced: luksFormat still NEEDS a typed passphrase at creation time (a LUKS2
# container cannot be created key-slot-less, and luksAddKey authenticates
# with it), so even possession-only installs type one — it just never survives
# past enrollment.  Ask-early semantics are preserved because the capture
# happens well before luksFormat, and the passphrase still lives only in
# this process's memory.
# ENCRYPT (yes/no) is persisted in the resume state file; the passphrase is
# NOT — it lives only in this process's memory until luksFormat/luksOpen (and
# is unset right after), so a crashed-then-resumed run re-prompts for it at
# luksOpen time instead (see the RESUME branch, NOT here).
ENCRYPT="no"
ENCRYPT_PASSPHRASE=""
echo ""
echo "${C_BOLD}${C_BLU}Encrypt disk?${C_RST}"
echo ""
echo "  Encrypt partition 2 (the root filesystem) with LUKS2. Every subvolume"
echo "  (root, home, snapshots, swap, ...) lives inside the encrypted volume."
echo "  Unlock is with a passphrase and/or an optional YubiKey (asked later);"
echo "  the ESP/bootloader stays unencrypted so it can find the system before"
echo "  the volume is unlocked."
echo ""
ask "Enable full-disk encryption (LUKS2)? [y/N]: "
read -r ENCRYPT_INPUT
case "$ENCRYPT_INPUT" in
    [yY]*) ENCRYPT="yes" ;;
    *)     ENCRYPT="no" ;;
esac
# AI (Big Pickle) FIX — Beta-v2.9.35 [GRUB-ESP-SIZE-ORDER]: GRUB+ENCRYPT now
# sizes the ESP HERE, right after the ENCRYPT choice actually settles — the
# old in-loop `[ "$ENCRYPT" = "yes" ] && EFI_PART_SIZE="4G"` inside the
# bootloader case ran BEFORE this prompt and read the pre-prompt default "no",
# so GRUB+ENCRYPT fresh runs always shipped a 1G ESP. The ESP is mounted AT
# /boot in that combo (grub.cfg + kernels live unencrypted on it), so its size
# now gets the same shared esp_size_choose menu (default 4G, growable).
if [ "$BOOTLOADER" = "grub" ] && [ "$ENCRYPT" = "yes" ]; then
    echo "  GRUB + full-disk encryption: the ESP is mounted AT /boot and will hold"
    echo "  the whole boot tree (grub + every kernel/initramfs) — pick a size."
    esp_size_choose
fi
export ENCRYPT

# AI (Big Pickle) ADDITION — Beta-v2.5.4 [YUBIKEY]: optional YubiKey
# hmac-sha1 challenge-response unlock, offered only when encryption was
# enabled. The YubiKey is REQUIRED to be present at install time — enrollment
# programs a real OTP slot and binds the HMAC response as a LUKS key slot, so
# it cannot be done later without the key. These prompt-time answers are
# persisted (state + chroot_env + limine-env); only the CHALLENGE+SLOT+mode
# are stored — the actual HMAC key and the passphrase are never written.
# YK_MODE is in {off,hmac-sha1}; YK_FALLBACK in {yes,no}
# (yes = keep a typed-passphrase slot too; no = YubiKey-only);
# YK_SLOT in {1,2} (default 1); YK_TOUCH in {yes,no} (require a physical
# touch on the YubiKey to unlock at boot — default yes for stronger
# possession confirm). The actual slot programming + key computation happen
# LATER (after the live-CD sync, once ykpers is available) — see the
# ADDITION block before CHROOT_START.
YK_MODE="off"
YK_FALLBACK="yes"
YK_SLOT="1"
YK_TOUCH="no"
if [ "$ENCRYPT" = "yes" ]; then
    echo ""
    echo "${C_BOLD}${C_BLU}YubiKey hmac-sha1 unlock?${C_RST}"
    echo ""
    echo "  Optionally bind a YubiKey hmac-sha1 challenge-response slot so the disk"
    echo "  unlocks by tapping the key at boot instead of (or in addition to) typing"
    echo "  the passphrase. The YubiKey MUST be plugged in now: enrollment programs"
    echo "  a real slot and stamps the HMAC response as a LUKS key slot. Slot 1 is"
    echo "  used by default (also the OTP default); use slot 2 if slot 1 is in use."
    echo "  ${C_YLW}Note:${C_RST} this boot-unlock path has ${C_BOLD}not been verified on real"
    echo "  hardware${C_RST} by the author — validate on the target medium before"
    echo "  trusting a possession-only install (see [YK-KEYSCRIPT-BAKE])."
    echo ""
    ask "Set up YubiKey hmac-sha1 unlock? [y/N]: "
    read -r YK_INPUT
    case "$YK_INPUT" in
        [yY]*)
            YK_MODE="hmac-sha1"
            while :; do
                ask "Which OTP slot to program (1 or 2)? [1]: "
                read -r YK_SLOT_INPUT
                case "${YK_SLOT_INPUT:-1}" in
                    1|2) YK_SLOT="$YK_SLOT_INPUT"; break ;;
                    *) echo "Please enter 1 or 2." >&2 ;;
                esac
            done
            ask "Require a physical touch on the YubiKey to unlock at boot? [Y/n]: "
            read -r YK_TOUCH_INPUT
            case "$YK_TOUCH_INPUT" in
                "")     YK_TOUCH="$DEFAULT_YK_TOUCH" ;;
                [nN]*) YK_TOUCH="no" ;;
                *)     YK_TOUCH="yes" ;;
            esac
            echo ""
            echo "  Passphrase fallback: with 'yes' (default) the typed passphrase slot is"
            echo "  kept too, so YubiKey absent/wrong still boots by typing the passphrase."
            echo "  With 'no' the passphrase slot is removed and the YubiKey is the ONLY"
            echo "  unlock — possession-required, nothing to type. NOTE: YubiKey-only is"
            echo "  only ever proven with the Limine bootloader — with GRUB the fallback"
            echo "  is kept regardless ([YUBIKEY] clamp)."
            ask "Keep the typed-passphrase fallback (YubiKey OR passphrase)? [Y/n]: "
            read -r YK_FALLBACK_INPUT
            case "$YK_FALLBACK_INPUT" in
                "")     YK_FALLBACK="$DEFAULT_YK_FALLBACK" ;;
                [nN]*) YK_FALLBACK="no" ;;
                *)     YK_FALLBACK="yes" ;;
            esac
            ;;
    esac
fi
export YK_MODE YK_FALLBACK YK_SLOT YK_TOUCH
unset YK_INPUT YK_SLOT_INPUT YK_TOUCH_INPUT YK_FALLBACK_INPUT

# AI (Big Pickle) CHANGE — Beta-v2.5.4 [YUBIKEY] + Beta-v2.6.2
# [GRUB-ESP-BOOT]: YubiKey possession-only (YK_FALLBACK=no, no typed
# passphrase slot at all) is deliberately still clamped back on under GRUB,
# even though [GRUB-ESP-BOOT] now keeps /boot public on the ESP so GRUB never
# reads LUKS. Two reasons: (a) this beta line's YubiKey boot path is
# real-hardware UNPROVEN (Limine is the only combination ever exercised),
# and (b) the typed fallback slot is strictly the safer default. If the user
# picked GRUB after asking for YubiKey-only, CLAMP the fallback back on here,
# after the bootloader prompt, so the constraint is reflected in persisted
# state and in every summary/dry-run below. This is the single canonical
# place the dependency is resolved (mirrored by the same enforced fact in
# void-limine-write-conf / crypttab generation later).
if [ "$BOOTLOADER" = "grub" ] && [ "$YK_MODE" = "hmac-sha1" ] && [ "$YK_FALLBACK" = "no" ]; then
    echo "==> [YUBIKEY] YubiKey-only unlock is only ever proven on Limine — keeping the"
    echo "       typed-passphrase fallback slot (YK_FALLBACK=yes) for this GRUB install."
    YK_FALLBACK="yes"
fi

# AI (Big Pickle) CHANGE — Beta-v2.6.0 [ENCRYPT-ORDER]: typed-passphrase
# capture, moved here. $YK_MODE/$YK_FALLBACK/$BOOTLOADER are now all final
# (the GRUB clamp above has run), so this prompt labels the passphrase's
# destiny truthfully:
#   * YK_MODE=off        -> plain every-boot passphrase.
#   * YK_FALLBACK=yes    -> boot fallback alongside the YubiKey.
#   * YK_FALLBACK=no     -> ONE-TIME provisioning secret only: it authorizes
#                           luksFormat + the luksAddKey enrollment and is then
#                           rendered useless by the luksRemoveKey of slot 0
#                           (nothing at boot will ever accept it again). Typing
#                           a throwaway value is fine — the YubiKey becomes the
#                           only unlock. Void's Mandatory invariant [ENCRYPT]:
#                           the value is fed to cryptsetup only via stdin and
#                           unset right after; never persisted.
if [ "$ENCRYPT" = "yes" ]; then
    while :; do
        echo ""
        if [ "$YK_MODE" = "hmac-sha1" ] && [ "$YK_FALLBACK" = "no" ]; then
            echo "  YubiKey-only unlock selected — this passphrase is a ONE-TIME provisioning"
            echo "  secret: it creates the LUKS2 container and is used to bind the YubiKey"
            echo "  slot, then the passphrase slot is removed. It will NOT unlock at boot;"
            echo "  you do not need to remember it (a throwaway value is fine)."
        elif [ "$YK_MODE" = "hmac-sha1" ]; then
            echo "  Passphrase fallback selected — this passphrase unlocks at boot when the"
            echo "  YubiKey is absent or fails, and seats the container at install."
        else
            echo "  This passphrase is required at every boot to unlock the disk."
        fi
        echo "Enter a passphrase for the encrypted disk (hidden input):"
        # AI (Big Pickle) ADDITION — Beta-v2.6.9 [KEYMAP]: tell the user that
        # the passphrase bytes are tied to the CURRENT console keymap, which
        # will be baked into the installed system + initramfs. This avoids the
        # "locks at boot" surprise when the boot console would otherwise map
        # keys differently.
        echo "  (type it under the CURRENT console keymap; it is what boot will expect)"
        read -r -s ENCRYPT_PASSPHRASE
        echo
        if [ -z "$ENCRYPT_PASSPHRASE" ]; then
            echo "Passphrase cannot be empty. Try again." >&2
            continue
        fi
        echo "Enter the passphrase again to confirm:"
        read -r -s ENCRYPT_PASSPHRASE_CONFIRM
        echo
        if [ "$ENCRYPT_PASSPHRASE" != "$ENCRYPT_PASSPHRASE_CONFIRM" ]; then
            echo "Passphrases do not match. Try again." >&2
            continue
        fi
        break
    done
    unset ENCRYPT_PASSPHRASE_CONFIRM
    # AI (Big Pickle) ADDITION — Beta-v2.7.1 [CRYPT-NAME]: optional LUKS
    # mapper name. Defaults to `void-root` (the historical/AGENTS name that all
    # the generated crypttab, rd.luks.name= kernel params, limine resync, and
    # the YubiKey keyscript path are built around). Prompting lets a user pick
    # a custom name, which is then threaded through EVERY consumer below so a
    # custom name still boots. Only validated for non-empty/no-slashes — it is
    # a device-mapper name, not a filesystem label.
    printf '%s\n' ""
    printf '%s\n' "${C_BOLD}${C_BLU}LUKS mapper name?${C_RST}"
    printf '%s\n' ""
    printf '%s\n' "  Name of the decrypted device that appears under /dev/mapper/."
    printf '%s\n' "  Press ENTER for the default: void-root"
    ask "Mapper name [void-root]: "
    read -r CRYPT_NAME
    [ -n "$CRYPT_NAME" ] || CRYPT_NAME="void-root"
    case "$CRYPT_NAME" in
        */*) echo "${C_RED}!! Mapper name must be a plain name (no '/'). Using default 'void-root'.${C_RST}" >&2
             CRYPT_NAME="void-root" ;;
    esac
    export CRYPT_NAME
fi

# The passphrase is deliberately NOT exported — it stays a plain variable in
# this process so no child process can inherit it via the environment; it is
# fed to cryptsetup only through `--key-file=-` on stdin via `printf '%s' |
# cryptsetup` (NO trailing newline — see [ENCRYPT-NEWLINE]), so
# it never appears in argv or in any persisted file (see Mandatory [ENCRYPT]).

# AI (Claude, Sonnet 5, Medium) ADDITION: Whether PipeWire autostarts during a read-only
# snapshot/overlay boot is now a real install-time choice instead of an
# unconditional skip. Default stays "off" (skip audio on snapshot boots)
# since that's the behavior actually tested; opting in trades that caution
# for working audio on snapshot boots.
# [OPEN ITEM #1, carried from CHANGELOG §6] — this toggle drives the
# live-overlay-skip wrapper further down in Stage 2; if a future edit ever
# drops that wrapper, restore it, this export alone does nothing on its own.
ask "Allow audio (PipeWire) to autostart during read-only snapshot boots? [y/N]: "
read -r ENABLE_SNAPSHOT_AUDIO_INPUT
case "$ENABLE_SNAPSHOT_AUDIO_INPUT" in
    "") ENABLE_SNAPSHOT_AUDIO="$DEFAULT_SNAPSHOT_AUDIO" ;;
    [yY]*) ENABLE_SNAPSHOT_AUDIO="true" ;;
    *) ENABLE_SNAPSHOT_AUDIO="false" ;;
esac
export ENABLE_SNAPSHOT_AUDIO

# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS]: DATA REGION FILESYSTEMS.
# The root filesystem (/, /.snapshots, /boot, @swap) is ALWAYS Btrfs — this
# grouped screen (right after the encryption section, before the Desktop/DM
# menu) lets each DATA region either stay a root-Btrfs subvolume (default) or
# be carved onto its own dedicated partition. Pressing Enter on EVERY line
# yields the all-Btrfs layout: no extra partitions, no size prompts — exactly
# the pre-2.9.38 behavior. Partition order is fixed: home, var, cache, srv,
# opt, games, then the Btrfs root LAST (sized to the remainder). With
# encryption the carved regions become an inner GPT inside the single LUKS2
# container. Region partitions are rollback-exempt (a root-@ snapshot
# rollback leaves them alone) but are NOT Snapper-snapshotted, matching their
# non-rollback-exempt-but-unsnapshotted subvol counterparts.
# =============================================================================
if [ "$RESUME" != "1" ]; then
    echo ""
    echo "${C_BOLD}${C_BLU}Data region filesystems${C_RST}"
    echo "  ${C_GRN}btrfs${C_RST}=stays a root-Btrfs subvolume   ${C_GRN}ext4${C_RST}=own dedicated partition"
    echo "  The root filesystem is ALWAYS Btrfs; these choices only slice DATA regions."
    echo "  (Enter on every line = all-Btrfs default: no extra partitions, no size prompts.)"
    ask "/home region — btrfs (subvol) or ext4 (own partition)? [b/e]: "
    read -r _rh
    if [ -z "$_rh" ]; then REGION_HOME_FS="$DEFAULT_REGION_HOME_FS"
    elif [[ "$_rh" =~ ^[eE](xt4)?$ ]]; then REGION_HOME_FS="ext4"
    elif [[ "$_rh" =~ ^[bB](trfs)?$ ]]; then REGION_HOME_FS="btrfs"
    else echo "  (default) btrfs"; REGION_HOME_FS="$DEFAULT_REGION_HOME_FS"; fi
    ask "/var region — btrfs (subvols) or ext4 (own partition)? [b/e]: "
    read -r _rh
    if [ -z "$_rh" ]; then REGION_VAR_FS="$DEFAULT_REGION_VAR_FS"
    elif [[ "$_rh" =~ ^[eE](xt4)?$ ]]; then REGION_VAR_FS="ext4"
    elif [[ "$_rh" =~ ^[bB](trfs)?$ ]]; then REGION_VAR_FS="btrfs"
    else echo "  (default) btrfs"; REGION_VAR_FS="$DEFAULT_REGION_VAR_FS"; fi
    ask "/var/cache region — btrfs (subvol @cache) or ext4 (own partition)? [b/e]: "
    read -r _rh
    if [ -z "$_rh" ]; then REGION_CACHE_FS="$DEFAULT_REGION_CACHE_FS"
    elif [[ "$_rh" =~ ^[eE](xt4)?$ ]]; then REGION_CACHE_FS="ext4"
    elif [[ "$_rh" =~ ^[bB](trfs)?$ ]]; then REGION_CACHE_FS="btrfs"
    else echo "  (default) btrfs"; REGION_CACHE_FS="$DEFAULT_REGION_CACHE_FS"; fi
    ask "/srv region — btrfs (subvol @srv) or ext4 (own partition)? [b/e]: "
    read -r _rh
    if [ -z "$_rh" ]; then REGION_SRV_FS="$DEFAULT_REGION_SRV_FS"
    elif [[ "$_rh" =~ ^[eE](xt4)?$ ]]; then REGION_SRV_FS="ext4"
    elif [[ "$_rh" =~ ^[bB](trfs)?$ ]]; then REGION_SRV_FS="btrfs"
    else echo "  (default) btrfs"; REGION_SRV_FS="$DEFAULT_REGION_SRV_FS"; fi
    ask "/opt region — btrfs (subvol @opt) or ext4 (own partition)? [b/e]: "
    read -r _rh
    if [ -z "$_rh" ]; then REGION_OPT_FS="$DEFAULT_REGION_OPT_FS"
    elif [[ "$_rh" =~ ^[eE](xt4)?$ ]]; then REGION_OPT_FS="ext4"
    elif [[ "$_rh" =~ ^[bB](trfs)?$ ]]; then REGION_OPT_FS="btrfs"
    else echo "  (default) btrfs"; REGION_OPT_FS="$DEFAULT_REGION_OPT_FS"; fi
    ask "~/<user>/Games — none, ext4 partition, or btrfs partition? [n/e/b]: "
    read -r _rh
    if [ -z "$_rh" ]; then REGION_GAMES="$DEFAULT_REGION_GAMES"
    elif [[ "$_rh" =~ ^[eE](xt4)?$ ]]; then REGION_GAMES="ext4"
    elif [[ "$_rh" =~ ^[bB](trfs)?$ ]]; then REGION_GAMES="btrfs"
    else echo "  (default) none"; REGION_GAMES="$DEFAULT_REGION_GAMES"; fi
    unset _rh
    # Carved regions ask a size prompt (in the fixed carve order); the Btrfs
    # root always gets the remainder, so it never asks.
    echo "  Carved region size prompts:"
    if [ "$REGION_HOME_FS" = "ext4" ]; then
        ask "  /home partition size [$DEFAULT_REGION_HOME_SIZE]: "
        read -r _rs
        [ -z "$_rs" ] && _rs="$DEFAULT_REGION_HOME_SIZE"
        REGION_HOME_SIZE="$_rs"
    fi
    if [ "$REGION_VAR_FS" = "ext4" ]; then
        ask "  /var partition size [$DEFAULT_REGION_VAR_SIZE]: "
        read -r _rs
        [ -z "$_rs" ] && _rs="$DEFAULT_REGION_VAR_SIZE"
        REGION_VAR_SIZE="$_rs"
    fi
    if [ "$REGION_CACHE_FS" = "ext4" ]; then
        ask "  /var/cache partition size [$DEFAULT_REGION_CACHE_SIZE]: "
        read -r _rs
        [ -z "$_rs" ] && _rs="$DEFAULT_REGION_CACHE_SIZE"
        REGION_CACHE_SIZE="$_rs"
    fi
    if [ "$REGION_SRV_FS" = "ext4" ]; then
        ask "  /srv partition size [$DEFAULT_REGION_SRV_SIZE]: "
        read -r _rs
        [ -z "$_rs" ] && _rs="$DEFAULT_REGION_SRV_SIZE"
        REGION_SRV_SIZE="$_rs"
    fi
    if [ "$REGION_OPT_FS" = "ext4" ]; then
        ask "  /opt partition size [$DEFAULT_REGION_OPT_SIZE]: "
        read -r _rs
        [ -z "$_rs" ] && _rs="$DEFAULT_REGION_OPT_SIZE"
        REGION_OPT_SIZE="$_rs"
    fi
    if [ "$REGION_GAMES" != "none" ]; then
        ask "  Games partition size [$DEFAULT_REGION_GAMES_SIZE]: "
        read -r _rs
        [ -z "$_rs" ] && _rs="$DEFAULT_REGION_GAMES_SIZE"
        REGION_GAMES_SIZE="$_rs"
    fi
    unset _rs
    # Derive the carves in the FIXED partition order (home, var, cache, srv,
    # opt, games). The leading space is deliberate — every carved region
    # appends "<space>name" so the value is a plain word list on which a
    # `for r in $REGION_PARTITIONED` loop iterates; empty = no carve.
    REGION_PARTITIONED=""
    [ "$REGION_HOME_FS"  = "ext4" ]  && REGION_PARTITIONED="$REGION_PARTITIONED home"
    [ "$REGION_VAR_FS"   = "ext4" ]  && REGION_PARTITIONED="$REGION_PARTITIONED var"
    [ "$REGION_CACHE_FS" = "ext4" ]  && REGION_PARTITIONED="$REGION_PARTITIONED cache"
    [ "$REGION_SRV_FS"   = "ext4" ]  && REGION_PARTITIONED="$REGION_PARTITIONED srv"
    [ "$REGION_OPT_FS"   = "ext4" ]  && REGION_PARTITIONED="$REGION_PARTITIONED opt"
    [ "$REGION_GAMES"    != "none" ] && REGION_PARTITIONED="$REGION_PARTITIONED games"
    # Unset the size vars of regions that are NOT carved so downstream logic
    # (install-config, DBG plan) only sees meaningful values.
    [ "$REGION_HOME_FS"  != "ext4" ]  && unset REGION_HOME_SIZE
    [ "$REGION_VAR_FS"   != "ext4" ]  && unset REGION_VAR_SIZE
    [ "$REGION_CACHE_FS" != "ext4" ]  && unset REGION_CACHE_SIZE
    [ "$REGION_SRV_FS"   != "ext4" ]  && unset REGION_SRV_SIZE
    [ "$REGION_OPT_FS"   != "ext4" ]  && unset REGION_OPT_SIZE
    [ "$REGION_GAMES"    = "none" ]  && unset REGION_GAMES_SIZE
    [ -n "$REGION_PARTITIONED" ] && echo "  → Carved partitions:${REGION_PARTITIONED}"
    jl "MULTI-FS: carved=${REGION_PARTITIONED:-<none>} home=${REGION_HOME_FS} var=${REGION_VAR_FS} cache=${REGION_CACHE_FS} srv=${REGION_SRV_FS} opt=${REGION_OPT_FS} games=${REGION_GAMES}"
else
    # Resume: REGION_* are restored from the state file (persisted below), so
    # the carve geometry is identical — nothing to re-ask.
    :
fi
export REGION_HOME_FS REGION_VAR_FS REGION_CACHE_FS REGION_SRV_FS REGION_OPT_FS REGION_GAMES
export REGION_HOME_SIZE REGION_VAR_SIZE REGION_CACHE_SIZE REGION_SRV_SIZE REGION_OPT_SIZE REGION_GAMES_SIZE
export REGION_PARTITIONED

# AI (Claude, Sonnet 5, Medium) ADDITION — Beta-v2.3.0 [KERNEL-MODE]: Where Limine reads the
# kernel/initramfs from is a real install-time choice, asked only when
# Limine itself was chosen above — this has no meaning for GRUB, which
# always reads /boot off the @ subvolume the normal way. See CHANGELOG
# §3.20/§3.21/§4.8 for the full rationale; short version:
#   1. esp-copy (the ONLY mode now) — kernel + initramfs for EVERY
#      currently-installed kernel version are copied to the ESP under
#      versioned names (vmlinuz-<version> / initramfs-<version>.img,
#      matching GRUB's own multi-kernel boot menu — see
#      [LIMINE-MULTI-KERNEL]) by a post-install kernel hook, and Limine
#      reads them straight off the ESP. Rollback-safe: rolling @ back via
#      a snapshot does NOT touch the ESP, so a rolled-back root always
#      boots against the CURRENT kernel/modules generation, never a stale
#      mismatched one. Worst-case failure mode if the hook ever misses a
#      kernel update is a stale-but-bootable old kernel (visible,
#      recoverable) — see DO NOT #4 above.
# AI (Big Pickle) ADDITION — Beta-v2.5.1 [LIMINE-ESP-ONLY]: the former
# btrfs-direct option was REMOVED. Limine's own documentation states plainly
# that "the kernel and initramfs must reside on the ESP FAT32 or on another
# dedicated FAT partition, while the system root can be on Btrfs" — i.e.
# reading the kernel FILE directly off a btrfs partition is not how Limine
# is designed to work, so that mode could never boot (the kernel could not
# be found on the btrfs filesystem). esp-copy is the only supported mode for
# BOOTLOADER=limine now; the earlier two-way prompt is gone. KERNEL_MODE is
# still exported (always "esp-copy" for limine, "n/a" for GRUB) and still
# persisted in install-config/chroot_env, so downstream logic remains
# compatible and self-documenting — but it can no longer hold btrfs-direct.
if [ "$BOOTLOADER" = "limine" ]; then
    echo ""
    echo "${C_BOLD}${C_BLU}Limine kernel access${C_RST}"
    echo "  ${C_GRN}esp-copy${C_RST} (the only mode) — kernel/initramfs for every installed"
    echo "     kernel are copied onto the ESP by a post-install kernel hook; Limine"
    echo "     reads them straight off the FAT32 ESP, as Limine's own docs require."
    echo "     (The former btrfs-direct mode was removed — it read the kernel direct"
    echo "     off Btrfs, which Limine does not support, so it could never boot.)"
    KERNEL_MODE="esp-copy"
else
    KERNEL_MODE="n/a"
fi
export KERNEL_MODE

# =============================================================================
# DESKTOP ENVIRONMENT CHOICE: KDE Plasma, Cinnamon, or GNOME
# =============================================================================
# AI (Claude, Sonnet 5, Medium) ADDITION: Desktop environment is now a real
# install-time choice instead of KDE Plasma being hardcoded. The display
# manager (SDDM/LightDM, chosen separately below) works with any of the
# three — nothing about the runit-service wiring or the earlier
# live-overlay-skip/autostart logic needs to change based on this choice.
#   1. KDE Plasma (default) — Wayland session via the chosen display
#      manager, the path this script's whole install has actually been
#      tested against.
#   2. Cinnamon (via cinnamon-all) — VERIFIED against Void's own docs and
#      real user reports: Void currently ships an X11-only Cinnamon
#      session (no /usr/share/wayland-sessions/cinnamon.desktop) even
#      though upstream Cinnamon is moving toward Wayland support of its
#      own. `wayland`/`wayland-protocols` are still installed
#      unconditionally for all three DE choices anyway (see the base
#      package line below) — cheap, harmless, and future-proofs the
#      install for whenever Void's cinnamon package does add a Wayland
#      session, rather than this script hardcoding an assumption that
#      would need revisiting either way. `xorg` covers the session
#      Cinnamon actually offers today. A handful of KDE-only companion
#      packages (kde-baseapps, ark, kio-admin, plasma-pa) are still
#      skipped entirely for this option since they have no meaning
#      outside Plasma — Cinnamon's own session already bundles
#      equivalents (Nemo for file management, its own volume applet via
#      cinnamon-settings-daemon).
#   3. GNOME (via the full `gnome` metapackage, not the minimal
#      `gnome-core`) — VERIFIED against void-packages' own gnome/
#      gnome-core templates: unlike cinnamon-all, the full `gnome`
#      package already bundles a terminal (gnome-console), text editor
#      (gnome-text-editor), wallpapers (gnome-backgrounds, a gnome-core
#      dependency), a secrets keyring (gnome-keyring), and Bluetooth
#      integration (gnome-bluetooth) — deliberately chosen over
#      gnome-core specifically to avoid repeating the "missing basics"
#      pattern real testing found with Cinnamon. GNOME Shell has its own
#      built-in polkit agent and top-bar Quick Settings for network/
#      Bluetooth (no classic systray-applet model the way Cinnamon/X11
#      desktops use), so none of the Cinnamon-specific additions
#      (dbus-run-session wrapping, blueman, network-manager-applet) are
#      applied here — there's no evidence GNOME needs them, and its
#      architecture makes most of them inapplicable by design rather than
#      just unnecessary. GNOME has a real, working Wayland session on
#      Void (confirmed via Void's own Wayland handbook page, unlike
#      Cinnamon's experimental one) so no default-session override is
#      needed either. Note: gnome-core depends on gdm (GNOME's own
#      display manager) — it gets installed as a package dependency but
#      is never linked as a runit service unless DISPLAY_MANAGER chose
#      it, same as kde-plasma already pulling in sddm without this script
#      needing to do anything special about it.
# AI (Claude, Sonnet 5, Medium) EXPANSION — Beta-v2.4.0: desktop environment is
# now a choice among a curated mainstream set of DEs that all ship as
# official Void packages (no third-party repos required): KDE Plasma,
# GNOME, Cinnamon, plus new additions Xfce, MATE, and LXQt. Each is gated
# on $DESKTOP_ENV in Stage 2. Wayland-session availability varies: KDE &
# GNOME have confirmed working Wayland sessions on Void today; Cinnamon,
# Xfce, MATE, and LXQt are (at time of writing) X11-only via Void's own
# docs — so this script installs `xorg` unconditionally for all of them
# (see the wayland/xorg note below) and only KDE/GNOME get a Wayland-
# session default in the DM. The display manager is chosen independently
# below; any DM listed can drive any DE, but each DE's conventional DM is
# recommended to pair with it. Budgie support was considered and
# intentionally left OUT of this curated set — it is packaged for Void but
# its Wayland/X11 session state is less settled and it's the least-testable
# of the candidates for this installer's automated-post-install path.
echo ""
echo "${C_BOLD}${C_BLU}Choose desktop environment${C_RST}"
echo "  ${C_BOLD}1)${C_RST} ${C_GRN}KDE Plasma (default)${C_RST} — Wayland session, this script's"
echo "     primary tested path."
echo "  ${C_BOLD}2)${C_RST} GNOME — Wayland session, confirmed available on Void."
echo "  ${C_BOLD}3)${C_RST} Cinnamon (X11) — Wayland session not yet packaged by Void."
echo "  ${C_BOLD}4)${C_RST} Xfce (X11) — lightweight GTK desktop, ships as Void's default"
echo "     graphical live-medium flavor."
echo "  ${C_BOLD}5)${C_RST} MATE (X11) — classic GNOME 2-style GTK desktop."
echo "  ${C_BOLD}6)${C_RST} LXQt (X11) — lightweight Qt desktop."
echo "  ${C_BOLD}7)${C_RST} ${C_RED}COSMIC (third-party repo)${C_RST} — the System76 desktop. NOT in the"
echo "     official Void repositories: installed from the community repo at"
echo "     https://bluesloth.github.io/void-linux-cosmic/ (audit:"
echo "     https://github.com/bluesloth/void-linux-cosmic), whose COSMIC 1.10"
echo "     templates are built from scratch, tracking System76 / Pop!_OS COSMIC."
echo "     Its signing key is PINNED in this installer"
echo "     and machine-verified after every sync. It is a third-party"
echo "     signing-trust choice made at your own risk — audit the repo before"
echo "     installing. The repo URL is verified reachable at runtime; if it is"
echo "     unavailable the install aborts cleanly rather than failing mid-way."
echo "  ${C_BOLD}8)${C_RST} ${C_GRN}none (console login only)${C_RST} — no desktop environment; a headless/"
echo "     server base that boots to a console. Pairs naturally with the"
echo "     display-manager '${C_BOLD}none${C_RST}' option below; the Xorg/Wayland base and"
echo "     the audio stack then become explicit opt-ins."
# AI (Big Pickle) CHANGE — Beta-v2.9.48 [DE-ORDER]: the menu is ordered
# most->least popular (KDE, GNOME, Cinnamon, Xfce, MATE, LXQt, COSMIC) with
# KDE still option 1 / the bare-Enter default, so the default regression is
# byte-identical. Option 8 (none) is the [NO-DE] headless entry.
while true; do
    ask "Enter choice [1/2/3/4/5/6/7/8, default ${DEFAULT_DESKTOP}]: "
    read -r DESKTOP_ENV_INPUT
    DESKTOP_ENV_INPUT="${DESKTOP_ENV_INPUT:-$DEFAULT_DESKTOP}"
    case "$DESKTOP_ENV_INPUT" in
        ""|1) DESKTOP_ENV="kde"; break ;;
        2) DESKTOP_ENV="gnome"; break ;;
        3) DESKTOP_ENV="cinnamon"; break ;;
        4) DESKTOP_ENV="xfce"; break ;;
        5) DESKTOP_ENV="mate"; break ;;
        6) DESKTOP_ENV="lxqt"; break ;;
        7) DESKTOP_ENV="cosmic"; break ;;
        8) DESKTOP_ENV="none"; break ;;
        *) echo "Please enter 1, 2, 3, 4, 5, 6, 7, or 8." >&2 ;;
    esac
done
export DESKTOP_ENV

# AI (Claude, Sonnet 5, Medium) ADDITION — Beta-v2.4.0: store the display manager
# typically paired with the just-chosen DE so the DM prompt below can offer
# that as its recommended/default entry, while still allowing any other DM.
case "$DESKTOP_ENV" in
    kde|lxqt) RECOMMENDED_DM="sddm" ;;
    gnome)    RECOMMENDED_DM="gdm" ;;
    cinnamon|mate) RECOMMENDED_DM="lightdm" ;;
    xfce)     RECOMMENDED_DM="lightdm" ;;
    cosmic)   RECOMMENDED_DM="sddm" ;;  # COSMIC's maintainer recommends SDDM; cosmic-greeter is offered as a DM option below when COSMIC is chosen, but the author reports it does not work reliably (see the greeter/DM prompts).
    none)     RECOMMENDED_DM="none" ;;  # AI (Big Pickle) ADDITION — Beta-v2.9.48 [NO-DE]: a console-only box recommends the 'none' DM below; the user may still pick a DM to add a graphical login without a DE (e.g. to hand off to startx).
    *)        RECOMMENDED_DM="sddm" ;;
esac

# =============================================================================
# DISPLAY MANAGER CHOICE: SDDM or LightDM
# =============================================================================
# AI (Claude, Sonnet 5, Medium) ADDITION: display manager is now a real,
# independent choice from desktop environment — either DM works with
# either DE, this just picks which is typically associated with which so
# the choice is informed rather than a coin flip.
# AI (Big Pickle) NOTE — Beta-v2.9.3 [DM-UNTESTED]: only the recommended DM for
# each DE (the RECOMMENDED_DM pairing) has been exercised on real hardware.
# Choosing a non-default DM for the selected DE (e.g. LightDM on KDE) is
# functional but UNTESTED — such cross-pairings are offered for flexibility,
# not verified. See the human-readable note printed in the prompt below.
echo ""
echo "${C_BOLD}${C_BLU}Choose display manager${C_RST} (works with any desktop environment — this"
echo "just picks which is typically paired with which; the recommended pairing"
echo "for your selected DE (${C_BOLD}${DESKTOP_ENV}${C_RST}) is ${C_GRN}${RECOMMENDED_DM}${C_RST}):"
echo "  ${C_YLW}Note:${C_RST} the recommended pairing for your DE is tested on real hardware;"
echo "     choosing a different (non-default) DM for it has ${C_BOLD}not been tested${C_RST}."
echo "  ${C_BOLD}1)${C_RST} SDDM — Qt-based; typically paired with KDE Plasma and LXQt; this"
echo "     script's primary tested login manager."
echo "  ${C_BOLD}2)${C_RST} LightDM — lightweight, greeter-based; typically paired with"
echo "     Cinnamon/Xfce/MATE/GTK desktops."
echo "  ${C_BOLD}3)${C_RST} GDM — GNOME Display Manager; typically paired with GNOME."
if [ "$DESKTOP_ENV" = "cosmic" ]; then
    echo "  ${C_BOLD}4)${C_RST} cosmic-greeter — COSMIC's own greeter (from the third-party COSMIC repo)."
    echo "     ${C_RED}Debug caveat:${C_RST} the COSMIC maintainer reports this greeter does NOT"
    echo "     currently work reliably (elogind doesn't recognize its session) and recommends"
    echo "     SDDM instead. Selecting it is at your own risk and may need manual fixing."
fi
# AI (Big Pickle) ADDITION — Beta-v2.9.48 [NO-DM]: the 'none' option installs
# NO display manager at all — a console-login box. It is listed last (its own
# menu index, 5 on the COSMIC branch / 4 otherwise) so the renumbering never
# shifts the existing 1/2/3 defaults, and it is the recommended entry for
# DESKTOP_ENV=none. Internally DISPLAY_MANAGER="none" maps to
# DM_SERVICE_NAME="none", and the first-boot rc.local link is sed-guarded so
# no dangling /etc/sv/none symlink is ever created.
echo "  ${C_BOLD}$([ "$DESKTOP_ENV" = "cosmic" ] && echo 5 || echo 4)${C_RST} ${C_GRN}none${C_RST} — no display manager; boot straight to a console login."
while true; do
    if [ "$DESKTOP_ENV" = "cosmic" ]; then
        ask "Enter choice [1/2/3/4/5] (default: ${RECOMMENDED_DM}): "
        read -r DISPLAY_MANAGER_INPUT
        case "$DISPLAY_MANAGER_INPUT" in
            "")  note "Using recommended display manager: ${C_BOLD}${RECOMMENDED_DM}${C_RST}"; DISPLAY_MANAGER="$RECOMMENDED_DM"; break ;;
            1) DISPLAY_MANAGER="sddm"; break ;;
            2) DISPLAY_MANAGER="lightdm"; break ;;
            3) DISPLAY_MANAGER="gdm"; break ;;
            4) DISPLAY_MANAGER="cosmic-greeter"; break ;;
            5) DISPLAY_MANAGER="none"; break ;;
            *) echo "Please enter 1, 2, 3, 4, or 5." >&2 ;;
        esac
    else
        ask "Enter choice [1/2/3/4] (default: ${RECOMMENDED_DM}): "
        read -r DISPLAY_MANAGER_INPUT
        case "$DISPLAY_MANAGER_INPUT" in
            "")  note "Using recommended display manager: ${C_BOLD}${RECOMMENDED_DM}${C_RST}"; DISPLAY_MANAGER="$RECOMMENDED_DM"; break ;;
            1) DISPLAY_MANAGER="sddm"; break ;;
            2) DISPLAY_MANAGER="lightdm"; break ;;
            3) DISPLAY_MANAGER="gdm"; break ;;
            4) DISPLAY_MANAGER="none"; break ;;
            *) echo "Please enter 1, 2, 3, or 4." >&2 ;;
        esac
    fi
done
export DISPLAY_MANAGER

# AI (Big Pickle) ADDITION — Beta-v2.9.48 [HEADLESS]: the single flag that
# tells every downstream gate whether this install has ANY graphical path.
# HAS_GRAPHICAL=no means a fully-headless server/console box — DESKTOP_ENV=none
# AND DISPLAY_MANAGER=none — so the Xorg/Wayland base chain is gated off and
# the xorg/audio stacks become explicit opt-ins that do NOT flip the flag.
# Every other combination (a chosen DE, or a DM without a DE) is graphical.
if [ "$DESKTOP_ENV" = "none" ] && [ "$DISPLAY_MANAGER" = "none" ]; then
    HAS_GRAPHICAL="no"
else
    HAS_GRAPHICAL="yes"
fi
export HAS_GRAPHICAL

# AI (Big Pickle) ADDITION — Beta-v2.9.48 [HEADLESS-XORG-OPT]/[HEADLESS-AUDIO]:
# on a fully-headless (console-only) box the Xorg/Wayland base and the audio
# stack are NOT installed by default. These two explicit toggles let a server
# keep them anyway — INSTALL_XORG=yes preserves the base for a later startx /
# remote-X session (it does NOT flip HAS_GRAPHICAL: the DM/DE links stay
# absent, and a later startx is a manual console action), and INSTALL_AUDIO=yes
# ships the PipeWire/ALSA stack for a media/voip server. Graphical installs
# (HAS_GRAPHICAL=yes) get AUCH unconditionally and never see these prompts.
if [ "$HAS_GRAPHICAL" = "no" ]; then
    echo ""
    echo "${C_BOLD}${C_BLU}Headless options${C_RST} (DESKTOP_ENV=none + DISPLAY_MANAGER=none)"
    while true; do
        ask "Keep the Xorg/Wayland base for a later startx / remote-X? [y/N]: "
        read -r _xg
        case "${_xg:-$DEFAULT_XORG}" in
            y|yes) INSTALL_XORG="true"; break ;;
            n|no) INSTALL_XORG="false"; break ;;
            *) echo "Please enter y or n." >&2 ;;
        esac
    done
    unset _xg
    echo ""
    while true; do
        ask "Install the audio stack (PipeWire + ALSA) on this server? [y/N]: "
        read -r _au
        case "${_au:-$DEFAULT_AUDIO}" in
            y|yes) INSTALL_AUDIO="true"; break ;;
            n|no) INSTALL_AUDIO="false"; break ;;
            *) echo "Please enter y or n." >&2 ;;
        esac
    done
    unset _au
else
    INSTALL_XORG="false"
    INSTALL_AUDIO="true"
fi
export INSTALL_XORG INSTALL_AUDIO

# AI (Claude, Sonnet 5, Medium) ADDITION — Beta-v2.4.0: LightDM needs an explicit
# greeter. Previously the script hard-attempted the Slick greeter and fell
# back to GTK with a fragile loop that could fail an install under `set -e`.
# Now it is an explicit install-time choice, offered only when LightDM was
# selected. The greeters below ship as official Void packages, so no
# fallback dance is required — the choice is honored directly.
# Beta-v2.9.1 [GREETER-NO-WEBKIT2]: the WebKit2 greeter option was dropped —
# lightdm-webkit2-greeter is abandoned upstream and black-screens against
# current webkit2gtk, and no maintained WebKit-based greeter is in Void's
# repos, so GTK + Slick are the only offered options.
if [ "$DISPLAY_MANAGER" = "lightdm" ]; then
    echo ""
    echo "${C_BOLD}${C_BLU}Choose a LightDM greeter${C_RST}"
    echo "  ${C_BOLD}1)${C_RST} ${C_GRN}GTK Greeter (lightdm-gtk-greeter)${C_RST} — the default, plain and"
    echo "     reliable, minimal dependencies."
    echo "  ${C_BOLD}2)${C_RST} Slick Greeter (lightdm-slick-greeter) — Linux Mint style,"
    echo "     more polished appearance (GTK-based)."
    while true; do
        ask "Enter choice [1/2] (default 1: GTK): "
        read -r LIGHTDM_GREETER_INPUT
        case "$LIGHTDM_GREETER_INPUT" in
            ""|1) LIGHTDM_GREETER="gtk"; break ;;
            2) LIGHTDM_GREETER="slick"; break ;;
            *) echo "Please enter 1 or 2." >&2 ;;
        esac
    done
    if [ "$LIGHTDM_GREETER" = "slick" ]; then
        LIGHTDM_GREETER_PKG="lightdm-slick-greeter"
        # Slick installs its greeter .desktop as slick-greeter.desktop, not
        # lightdm-slick-greeter.desktop, so greeter-session must name that file.
        # [LIGHTDM-GREETER-SESSION] Beta-v2.7.7: was wrongly "lightdm-slick-greeter".
        LIGHTDM_GREETER_SESSION="slick-greeter"
    else
        LIGHTDM_GREETER_PKG="lightdm-gtk-greeter"
        LIGHTDM_GREETER_SESSION="lightdm-gtk-greeter"
    fi
    export LIGHTDM_GREETER_PKG
    export LIGHTDM_GREETER_SESSION
fi

# =============================================================================
# SESSION / SEAT MANAGEMENT (logind) CHOICE [item 9]
# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.4.0 [item 9]: Void does not run systemd,
# so login/seat management comes from one of two standalone stacks:
#   - elogind (the fork of systemd-logind) + a logind-compatible service —
#     the default. The same daemon that satisfies polkit/GNOME/KDE and a
#     broad range of software that expects logind; most widely compatible.
#   - turnstile + seatd + acpid — the leaner, newer "no-elogind" route
#     (turnstile is a lightweight reimplementation, seatd for seat/graphical
#     sessions, acpid for ACPI/power events like lid close and power button).
# This is an explicit choice with elogind kept as the default, since it is
# the safest/most-tested baseline; turnstile+seatd+acpid is the alternative
# for anyone who prefers avoiding the logind-is-a-fork-of-systemd runtime.
# AI (Big Pickle) NOTE — Beta-v2.9.3 [SESSION-UNTESTED]: only elogind has been
# exercised on real hardware. The turnstile + seatd + acpid stack is
# functional but UNTESTED — it is offered for leaner no-elogind installs, not
# verified. See the human-readable note printed in the prompt below.
echo ""
echo "${C_BOLD}${C_BLU}Choose session/seat management (logind)${C_RST}"
echo "  ${C_YLW}Note:${C_RST} ${C_GRN}elogind${C_RST} is the only option tested on real hardware;"
echo "     turnstile + seatd + acpid has ${C_BOLD}not been tested${C_RST} and may need"
echo "     manual fixes for some software."
echo "  ${C_BOLD}1)${C_RST} ${C_GRN}elogind (Default)${C_RST} — the well-tested fork of systemd-logind;"
echo "     broadly required/compatible with GNOME, KDE, polkit auth."
echo "  ${C_BOLD}2)${C_RST} turnstile + seatd + acpid — the leaner alternative: turnstile for"
echo "     user sessions, seatd for graphical seat/input, acpid for ACPI"
echo "     power events. Avoids the logind runtime entirely; some software"
echo "     that hard-requires logind may not work."
while true; do
    _session_default="elogind"
    [ "$DEFAULT_SESSION_STACK" = "2" ] && _session_default="turnstile"
    ask "Enter choice [1/2] (default ${DEFAULT_SESSION_STACK}: ${_session_default}): "
    read -r LOGIND_INPUT
    LOGIND_INPUT="${LOGIND_INPUT:-$DEFAULT_SESSION_STACK}"
    case "$LOGIND_INPUT" in
        ""|1) SESSION_STACK="elogind"; break ;;
        2) SESSION_STACK="turnstile"; break ;;
        *) echo "Please enter 1 or 2." >&2 ;;
    esac
done
export SESSION_STACK

# =============================================================================
# OPTIONAL SOFTWARE — a series of independent yes/no toggles
# =============================================================================
# AI (Claude, Sonnet 5, Medium) ADDITION [item 9]: every prompt from here down
# through the virtualization toggle is answered independently — saying yes
# or no to one has no bearing on any other, and you can enable any
# combination of them (including all of them, or none). Nothing here is
# an either/or choice unless a prompt says so explicitly. If you're not
# sure yet whether you'll want, say, Docker AND Podman, that's fine — the
# next several prompts ask about each container backend (Podman rootless,
# Podman rootful, Docker) one at a time, so you'll see all of them before
# you're done, not just the first one.
echo ""
echo "The following are independent yes/no choices — answer each on its own,"
echo "any combination is fine."

# AI (Claude, Sonnet 5, Medium) ADDITION: OctoXBPS (graphical xbps package manager/update
# notifier) is now a real install-time choice — not everyone wants a
# graphical package manager or its update-notifier autostarting. Default
# No ([y/N]).
ask "Install OctoXBPS (graphical package manager + update notifier)? [y/N]: "
read -r INSTALL_OCTOXBPS_INPUT
case "$INSTALL_OCTOXBPS_INPUT" in
    "") INSTALL_OCTOXBPS="$DEFAULT_OCTOXBPS" ;;
    [nN]*) INSTALL_OCTOXBPS="false" ;;
    *) INSTALL_OCTOXBPS="true" ;;
esac
export INSTALL_OCTOXBPS

ask "Install Flatpak (+ Flathub)? [y/N]: "
read -r INSTALL_FLATPAK_INPUT
case "$INSTALL_FLATPAK_INPUT" in
    "") INSTALL_FLATPAK="$DEFAULT_FLATPAK" ;;
    [nN]*) INSTALL_FLATPAK="false" ;;
    *) INSTALL_FLATPAK="true" ;;
esac
export INSTALL_FLATPAK

# AI (Big Pickle) ADDITION — Beta-v2.9.36 [CHANNEL-GROUP]: Flatpak and Homebrew
# are shown as one third-party-app-channels umbrella, but each is an INDEPENDENT
# yes/no toggle (both default NO) — brew must not read as a sub-choice of
# Flatpak's sandbox; brew-only and flatpak-only are both expressible. Flatpak
# = sandboxed GUI apps; Homebrew = unsandboxed CLI/dev tools. Complement, not
# replacement.
echo ""
echo "${C_BOLD}${C_BLU}THIRD-PARTY APP CHANNELS${C_RST} — Flatpak (sandboxed GUI apps) and"
echo "  Homebrew / Linuxbrew (unsandboxed CLI & dev tools) are independent"
echo "  choices — enable either, both, or neither."
ask "Install Homebrew (Linuxbrew CLI/dev channel, opt-in; ~/.linuxbrew)? [y/N]: "
read -r INSTALL_BREW_INPUT
case "$INSTALL_BREW_INPUT" in
    "") INSTALL_BREW="$DEFAULT_BREW" ;;
    [yY]*) INSTALL_BREW="true" ;;
    *) INSTALL_BREW="false" ;;
esac
export INSTALL_BREW

# AI (Big Pickle) ADDITION — Beta-v2.9.84 [COSMIC-STORE]: opt-in COSMIC app
# store. cosmic-store (bluesloth repo) hard run-depends on flatpak, so it
# follows the SAME gate rule as Brave ([BRAVE-FLATPAK-GATE]): the prompt is
# only shown when the Flatpak channel is on, and the Stage-2 install site
# re-checks INSTALL_FLATPAK and refuses to install if a stale resume state
# ever carried store=yes alongside flatpak=no — never a silent flatpak pull
# past an explicit opt-out. Offered on ANY desktop, not just COSMIC (the store
# is a Flathub GUI; it runs under any DE). Default NO.
INSTALL_COSMIC_STORE="false"
if [ "$INSTALL_FLATPAK" = "true" ]; then
    ask "Install cosmic-store (COSMIC app store; Flatpak-only)? [y/N]: "
    read -r INSTALL_COSMIC_STORE_INPUT
    case "$INSTALL_COSMIC_STORE_INPUT" in
        "") INSTALL_COSMIC_STORE="$DEFAULT_COSMIC_STORE" ;;
        [yY]*) INSTALL_COSMIC_STORE="true" ;;
        *) INSTALL_COSMIC_STORE="false" ;;
    esac
fi
export INSTALL_COSMIC_STORE

# AI (Big Pickle) ADDITION — Beta-v2.8.3 [INSTALL-APPS]: Thunderbird and Steam
# become real install-time choices. Previously these only existed as
# pre-create-only subvolume toggles (the installer never installed them). Both
# are GUI clients with no daemon and follow the browser-install model (package
# + isolated subvol). Both default OFF (lean posture — must be opted into,
# matching containers/virt).
ask "Install Thunderbird (email client)? [y/N]: "
read -r INSTALL_THUNDERBIRD_INPUT
case "$INSTALL_THUNDERBIRD_INPUT" in
    "") INSTALL_THUNDERBIRD="$DEFAULT_THUNDERBIRD" ;;
    [yY]*) INSTALL_THUNDERBIRD="true" ;;
    *) INSTALL_THUNDERBIRD="false" ;;
esac
export INSTALL_THUNDERBIRD

# AI (Big Pickle) ADDITION — Beta-v2.9.37 [GAME-LAUNCHERS]: a gaming umbrella
# right after the app channels / Thunderbird, before Steam. Each item is an
# independent yes/no toggle, default OFF (mirrors [CHANNEL-GROUP]). The banner
# keys an advisory line off the [HARDWARE-REVIEW] probe (GPU_FAMILIES), which
# ran back in the device-profile phase — advisory only, never a gate.
# Delivery model: Lutris is in Void main (xbps); Heroic + Bottles have NO
# official Void package ([GAME-FLATPAK-GATE], Beta-v2.9.40) so they are
# Flatpak-only and only offered when INSTALL_FLATPAK=true. Wine (system,
# multilib) is a separate runtime toggle — a launcher toggle NEVER auto-pulls
# it (Lutris/Heroic/Bottles each self-manage their own Wine). Not in scope:
# Wine-GE / Proton-FS (not in Void repos), ProtonUp-Qt (a Steam utility).
echo ""
echo "${C_BOLD}${C_BLU}GAME LAUNCHERS & RUNTIMES${C_RST}"
if [ -n "${GPU_FAMILIES}" ]; then
    echo "  Detected graphics: ${GPU_FAMILIES} (advisory only)"
else
    echo "  Detected graphics: none (headless / no discrete GPU seen)"
fi
echo "  Each item below is independent and off by default; a launcher never"
echo "  auto-pulls Wine — configure each launcher's own Wine as needed."

ask "Install Lutris (game library/installer for Wine + native games)? [y/N]: "
read -r INSTALL_LUTRIS_INPUT
case "$INSTALL_LUTRIS_INPUT" in
    "") INSTALL_LUTRIS="$DEFAULT_LUTRIS" ;;
    [yY]*) INSTALL_LUTRIS="true" ;;
    *) INSTALL_LUTRIS="false" ;;
esac
export INSTALL_LUTRIS

if [ "$INSTALL_FLATPAK" = "true" ]; then
    ask "Install Heroic (Epic/GOG launcher; Flatpak)? [y/N]: "
    read -r INSTALL_HEROIC_INPUT
    case "$INSTALL_HEROIC_INPUT" in
        "") INSTALL_HEROIC="$DEFAULT_HEROIC" ;;
        [yY]*) INSTALL_HEROIC="true" ;;
        *) INSTALL_HEROIC="false" ;;
    esac
    export INSTALL_HEROIC
    ask "Install Bottles (per-game Wine prefix manager; Flatpak)? [y/N]: "
    read -r INSTALL_BOTTLES_INPUT
    case "$INSTALL_BOTTLES_INPUT" in
        "") INSTALL_BOTTLES="$DEFAULT_BOTTLES" ;;
        [yY]*) INSTALL_BOTTLES="true" ;;
        *) INSTALL_BOTTLES="false" ;;
    esac
    export INSTALL_BOTTLES
else
    # [GAME-FLATPAK-GATE] Beta-v2.9.40: no official Void package for Heroic or
    # Bottles; a Flatpak-only delivery means these prompts are only offered when
    # Flatpak is on. When Flatpak is off, skip them with a one-line NOTICE and
    # force the toggles off (never silently carry an INSTALL=false state).
    INSTALL_HEROIC="false"
    INSTALL_BOTTLES="false"
    export INSTALL_HEROIC INSTALL_BOTTLES
    echo "NOTICE: Heroic and Bottles are only offered when Flatpak is selected"
    echo "(no official Void package — Flatpak-only delivery). Flatpak was not"
    echo "selected — Heroic and Bottles skipped."
fi

ask "Install Wine (system, multilib)? [y/N]: "
read -r INSTALL_WINE_INPUT
case "$INSTALL_WINE_INPUT" in
    "") INSTALL_WINE="$DEFAULT_WINE" ;;
    [yY]*) INSTALL_WINE="true" ;;
    *) INSTALL_WINE="false" ;;
esac
export INSTALL_WINE

ask "Install gamemode (+ libgamemode-32bit)? [y/N]: "
read -r INSTALL_GAMEMODE_INPUT
case "$INSTALL_GAMEMODE_INPUT" in
    "") INSTALL_GAMEMODE="$DEFAULT_GAMEMODE" ;;
    [yY]*) INSTALL_GAMEMODE="true" ;;
    *) INSTALL_GAMEMODE="false" ;;
esac
export INSTALL_GAMEMODE

ask "Install Steam (gaming client)? [y/N]: "
read -r INSTALL_STEAM_INPUT
case "$INSTALL_STEAM_INPUT" in
    "") INSTALL_STEAM="$DEFAULT_STEAM" ;;
    [yY]*) INSTALL_STEAM="true" ;;
    *) INSTALL_STEAM="false" ;;
esac
export INSTALL_STEAM

# AI (Big Pickle) ADDITION — Beta-v2.9.37 [GAME-SUBVOL]: INSTALL_ANY_GAME is
# the shared Gate flag for the ONE per-user @game subvol — Steam ∨ Lutris ∨
# Heroic ∨ Bottles (computed after ALL launcher prompts, including Steam).
# Wine/gamemode are deliberately EXCLUDED (they have no isolated data datadir
# to own). Used by the SUBVOL_ROWS gate display and the derived @game
# multi-mount block in Stage 2.
if [ "$INSTALL_STEAM" = "true" ] || [ "$INSTALL_LUTRIS" = "true" ] || \
   [ "$INSTALL_HEROIC" = "true" ] || [ "$INSTALL_BOTTLES" = "true" ]; then
    INSTALL_ANY_GAME="true"
else
    INSTALL_ANY_GAME="false"
fi
export INSTALL_ANY_GAME

ask "Install VirtualBox (full virtualizer, QEMU/KVM alternative)? [y/N]: "
read -r INSTALL_VIRTUALBOX_INPUT
case "$INSTALL_VIRTUALBOX_INPUT" in
    "") INSTALL_VIRTUALBOX="$DEFAULT_VIRTUALBOX" ;;
    [yY]*) INSTALL_VIRTUALBOX="true" ;;
    *) INSTALL_VIRTUALBOX="false" ;;
esac
export INSTALL_VIRTUALBOX

# =============================================================================
# WEB BROWSER SELECTION
# =============================================================================
# AI (Claude, Sonnet 5, Medium) ADDITION: browsers are now real, individually
# selectable install-time choices instead of Firefox+Chromium being
# unconditionally installed. Firefox and Chromium default to Yes (matches
# the prior always-installed behavior — pressing Enter through both keeps
# the same outcome as before this was added); Vivaldi/Falkon/Brave default
# to No since they're new, opt-in additions.
#
# Package availability, verified against real void-packages source
# templates rather than assumed:
#   - Firefox, Chromium: official Void packages (unchanged from before).
#   - Vivaldi: official Void package, but lives in the nonfree repo
#     (proprietary) — void-repo-nonfree is already enabled unconditionally
#     earlier in this script, so no extra repo work needed here.
#   - Falkon: official Void package (KDE's own browser, Qt WebEngine
#     based) — free repo, works fine standalone regardless of DESKTOP_ENV.
#   - Brave: has NO official Void package at all — confirmed directly
#     against void-packages' own srcpkgs tree, not assumed. The only
#     routes are an unofficial community srcpkgs fork (a different,
#     unverified trust model this script doesn't use anywhere else),
#     Flatpak, or manually converting Brave's upstream .deb. Handled
#     below via Flatpak ONLY when Flatpak was also selected — if not,
#     Brave is skipped with a clear explanation rather than silently
#     doing nothing or reaching for an unofficial repo.
# AI (Big Pickle) ADDITION — Beta-v2.7.4 [BROWSER-GROUP]: gate the whole
# web-browser install section behind one yes/no so a person who wants NO
# browser can skip past all five prompts at once; anyone who does want
# browsers then picks each one individually below (same per-browser defaults
# as before). Bare-Enter => gate reads default (defaults to NO since
# Beta-v2.9.7 [BROWSER-GATE-NO], so an uninterested/default run skips the
# whole browser section).
echo ""
ask "Set up web browsers now? (choose each one next) [y/N]: "
read -r _setup_web_input
case "$_setup_web_input" in
    "")    SETUP_WEB_BROWSERS="$DEFAULT_WEB_BROWSERS" ;;
    [nN]*) SETUP_WEB_BROWSERS="false" ;;
    *)     SETUP_WEB_BROWSERS="true" ;;
esac
export SETUP_WEB_BROWSERS

if [ "$SETUP_WEB_BROWSERS" = "true" ]; then
    echo "Choose web browsers to install (each is independent — pick any"
    echo "combination, or none at all):"
    ask "Install Firefox? [Y/n]: "
    read -r INSTALL_FIREFOX_INPUT
    case "$INSTALL_FIREFOX_INPUT" in
        "") INSTALL_FIREFOX="$DEFAULT_FIREFOX" ;;
        [nN]*) INSTALL_FIREFOX="false" ;;
        *) INSTALL_FIREFOX="true" ;;
    esac
    export INSTALL_FIREFOX

    ask "Install Chromium? [Y/n]: "
    read -r INSTALL_CHROMIUM_INPUT
    case "$INSTALL_CHROMIUM_INPUT" in
        "") INSTALL_CHROMIUM="$DEFAULT_CHROMIUM" ;;
        [nN]*) INSTALL_CHROMIUM="false" ;;
        *) INSTALL_CHROMIUM="true" ;;
    esac
    export INSTALL_CHROMIUM

    ask "Install Vivaldi (proprietary, nonfree repo)? [y/N]: "
    read -r INSTALL_VIVALDI_INPUT
    case "$INSTALL_VIVALDI_INPUT" in
        "") INSTALL_VIVALDI="$DEFAULT_VIVALDI" ;;
        [yY]*) INSTALL_VIVALDI="true" ;;
        *) INSTALL_VIVALDI="false" ;;
    esac
    export INSTALL_VIVALDI

    # AI (Big Pickle) ADDITION — Beta-v2.9.22 [FALKON-QT-NOTICE]: closes the
    # long-standing "Falkon KDE-dependency awareness" discussion. On Void,
    # falkon's real dependencies are qt5-webengine + qt5-x11extras + qt5-svg —
    # it pulls the Qt + QtWebEngine stack but does NOT install a KDE desktop.
    # Warn-not-gate (matches the Vivaldi/Brave notice pattern): inline notice
    # before the [y/N] prompt, only when the desktop isn't KDE. LXQt already
    # shares the Qt5 base so only the WebEngine set is new there; GTK/session
    # desktops get the full wording. No extra confirm gate, prompt unchanged.
    if [ "$DESKTOP_ENV" != "kde" ]; then
        if [ "$DESKTOP_ENV" = "lxqt" ]; then
            echo "NOTICE: Falkon shares LXQt's Qt5 but still pulls in the Qt"
            echo "WebEngine stack on top (it does not install KDE)."
        elif [ "$DESKTOP_ENV" = "none" ]; then
            # AI (Big Pickle) ADDITION — Beta-v2.9.48 [NO-DE]: a console-only box
            # has no desktop whose base Falkon could reuse; keep the notice true.
            echo "NOTICE: Falkon runs standalone but pulls in the Qt + QtWebEngine"
            echo "stack onto your console-only base (it does not install a desktop)."
        else
            echo "NOTICE: Falkon runs standalone but pulls in the Qt + QtWebEngine"
            echo "stack on top of your ${DESKTOP_ENV} desktop (it does not install KDE)."
        fi
    fi
    ask "Install Falkon (KDE's browser, works fine standalone too)? [y/N]: "
    read -r INSTALL_FALKON_INPUT
    case "$INSTALL_FALKON_INPUT" in
        "") INSTALL_FALKON="$DEFAULT_FALKON" ;;
        [yY]*) INSTALL_FALKON="true" ;;
        *) INSTALL_FALKON="false" ;;
    esac
    export INSTALL_FALKON

    # AI (Big Pickle) ADDITION — Beta-v2.9.28 [BRAVE-FLATPAK-GATE]: Brave has
    # no official Void package, so its only installer route is the Flatpak
    # first-boot queue. The Flatpak prompt already ran above, so INSTALL_FLATPAK
    # is resolved here. Hide the Brave prompt unless Flatpak is on; when hidden,
    # force INSTALL_BRAVE=false and explain why. The Stage-2 WARNING (below)
    # survives as defense-in-depth for a resume from an older state file that
    # could carry INSTALL_BRAVE=true alongside INSTALL_FLATPAK=false.
    if [ "$INSTALL_FLATPAK" != "true" ]; then
        INSTALL_BRAVE="false"
        echo "NOTICE: Brave is only offered when Flatpak is selected (it has no"
        echo "official Void package). Flatpak was not selected — Brave skipped."
    else
        echo "NOTICE: Brave has no official Void package. If selected, it will only"
        echo "be installed via Flatpak — and only if Flatpak was selected above. If"
        echo "Flatpak wasn't selected, Brave will be skipped rather than reaching"
        echo "for an unofficial third-party package repository."
        ask "Install Brave? [y/N]: "
        read -r INSTALL_BRAVE_INPUT
        case "$INSTALL_BRAVE_INPUT" in
            "") INSTALL_BRAVE="$DEFAULT_BRAVE" ;;
            [yY]*) INSTALL_BRAVE="true" ;;
            *) INSTALL_BRAVE="false" ;;
        esac
        export INSTALL_BRAVE
    fi
else
    # No web browsers wanted: force every browser install toggle off so
    # downstream SUBVOL_LIST / provision_browser_subvol gating stays correct.
    INSTALL_FIREFOX="false"
    INSTALL_CHROMIUM="false"
    INSTALL_VIVALDI="false"
    INSTALL_FALKON="false"
    INSTALL_BRAVE="false"
    export INSTALL_FIREFOX INSTALL_CHROMIUM INSTALL_VIVALDI INSTALL_FALKON INSTALL_BRAVE
fi

# (Browser pre-create of isolated profile subvolumes is now handled
# uniformly by the [SUBVOL-GATES] resolver below — Beta-v2.9.0 — not here.)

# AI (Big Pickle) ADDITION — Beta-v2.6.1 [SUBVOLS]: the "pre-create the
# isolated subvolume for later manual use" pattern, extended beyond web
# browsers to other per-user apps (Thunderbird mail profile, Steam). Each is
# asked individually and only
# provisioned when the subvolume gate in SUBVOL_LIST (Stage 1) AND the
# matching Stage-2 call agree. Thunderbird's profile (~/.thunderbird) gets
#     the exact browser treatment (nodatacow sqlite mail DB). Steam
# (~/.local/share/Steam) isolates its churn from snapshots.
# (The former [APPS-GROUP] SETUP_APPS gate and its per-app pre-create prompts
# were removed in Beta-v2.9.0 — pre-create is now governed uniformly by the
# [SUBVOL-GATES] Gate 2 resolver below.)

# AI (Claude, Sonnet 5, Medium) ADDITION [item 9]: this is the exact case that
# prompted the retrofit — Podman rootless, Podman rootful, and Docker are
# three SEPARATE, independent container-backend choices, each asked one
# at a time below. You are not choosing between them; you can say yes to
# any combination (all three, any two, one, or none). If you only need
# one backend, it's fine to say no to the other two when they're asked.
# AI (Big Pickle) ADDITION — Beta-v2.7.4 [CONTAINER-GROUP]: gate the whole
# container section behind one yes/no. All three backends default OFF, so the
# gate defaults OFF too — a bare-Enter run skips the section exactly as it did
# before (lean posture, [OPT-DEFAULTS]). Say "yes" to walk Podman rootless /
# Podman rootful / Docker individually below; each remains a separate,
# independent choice (rootless vs rootful vs docker have genuinely different
# security/trust/architecture profiles).
echo ""
ask "Set up containers (Podman / Docker) now? (choose each backend next) [y/N]: "
read -r _setup_containers_input
case "$_setup_containers_input" in
    "")    SETUP_CONTAINERS="$DEFAULT_CONTAINERS" ;;
    [yY]*) SETUP_CONTAINERS="true" ;;
    *)     SETUP_CONTAINERS="false" ;;
esac
export SETUP_CONTAINERS

if [ "$SETUP_CONTAINERS" = "true" ]; then
    echo "Container backends — Podman rootless, Podman rootful, and Docker are"
    echo "three independent choices below (any combination is fine, including"
    echo "all three or none)."
    # AI (Big Pickle) CHANGE — Beta-v2.5.0 [OPT-DEFAULTS]: Podman rootless,
    # Podman rootful, Docker, and virtualization are now all default-OFF.
    # A bare "just press Enter" run therefore installs a lean base system —
    # the container/virtualization stack must be explicitly opted into per
    # prompt. This matches the "assume no background daemons unless asked
    # for" posture already applied to the docker-group and distrobox prompts.
    ask "Install Podman rootless? [y/N]: "
    read -r INSTALL_PODMAN_ROOTLESS_INPUT
    case "$INSTALL_PODMAN_ROOTLESS_INPUT" in
        "") INSTALL_PODMAN_ROOTLESS="$DEFAULT_PODMAN_ROOTLESS" ;;
        [yY]*) INSTALL_PODMAN_ROOTLESS="true" ;;
        *) INSTALL_PODMAN_ROOTLESS="false" ;;
    esac
    export INSTALL_PODMAN_ROOTLESS

    ask "Install Podman rootful capability? [y/N]: "
    read -r INSTALL_PODMAN_ROOTFUL_INPUT
    case "$INSTALL_PODMAN_ROOTFUL_INPUT" in
        "") INSTALL_PODMAN_ROOTFUL="$DEFAULT_PODMAN_ROOTFUL" ;;
        [yY]*) INSTALL_PODMAN_ROOTFUL="true" ;;
        *) INSTALL_PODMAN_ROOTFUL="false" ;;
    esac
    export INSTALL_PODMAN_ROOTFUL

    if [ "$INSTALL_PODMAN_ROOTLESS" = "true" ] || [ "$INSTALL_PODMAN_ROOTFUL" = "true" ]; then
        INSTALL_PODMAN="true"
    else
        INSTALL_PODMAN="false"
    fi
    export INSTALL_PODMAN

# AI (Claude, Sonnet 5, Medium) ADDITION: Docker's default architecture runs a persistent
# root-owned background daemon — membership in the "docker" group is
# effectively root-equivalent access to the host even without ever typing
# sudo (e.g. mounting / into a container and chrooting into it), unlike
# podman rootful which requires an explicit sudo/--root each time. That's
# why this gets its own separate, default-off prompt rather than being
# folded into the main Docker toggle.
ask "Install Docker? [y/N]: "
read -r INSTALL_DOCKER_INPUT
case "$INSTALL_DOCKER_INPUT" in
    "") INSTALL_DOCKER="$DEFAULT_DOCKER" ;;
    [yY]*) INSTALL_DOCKER="true" ;;
    *) INSTALL_DOCKER="false" ;;
esac
if [ "$INSTALL_DOCKER" = "true" ]; then
    ask "Add your user to the docker group (root-equivalent access, run docker without sudo)? [y/N]: "
    read -r DOCKER_GROUP_ADD_INPUT
    case "$DOCKER_GROUP_ADD_INPUT" in
        "") DOCKER_GROUP_ADD="$DEFAULT_DOCKER_GROUP_ADD" ;;
        [yY]*) DOCKER_GROUP_ADD="true" ;;
        *) DOCKER_GROUP_ADD="false" ;;
    esac
else
    DOCKER_GROUP_ADD="false"
fi
export INSTALL_DOCKER
export DOCKER_GROUP_ADD

# AI (Claude, Sonnet 5, Medium) ADDITION: distrobox is NOT an installable xbps package on Void
# — confirmed both by a real failed install (xbps-install errored out
# specifically on distrobox, succeeded once it was removed) and by
# checking upstream: void-packages has only an open package request
# (#36341) and an unmerged proposal PR (#47347), neither of which resulted
# in a real package in the repos. Offered if ANY of the three backends
# distrobox actually supports were selected — rootless (default), rootful
# (via distrobox's own --root flag, confirmed against upstream docs), or
# Docker. With an explicit warning, since installing it means running
# upstream's official install script (curl | sh) rather than a package
# from a verified repo index — a real, different trust model, not just a
# detail.
if [ "$INSTALL_PODMAN_ROOTLESS" = "true" ] || [ "$INSTALL_PODMAN_ROOTFUL" = "true" ] || [ "$INSTALL_DOCKER" = "true" ]; then
    echo "NOTICE: distrobox has no xbps package on Void. If installed, it will be"
    echo "built from upstream's official install script (fetched and run directly"
    echo "from GitHub), not a package from a verified repository index."
    ask "Also install distrobox? [y/N]: "
    read -r INSTALL_DISTROBOX_INPUT
    case "$INSTALL_DISTROBOX_INPUT" in
        "") INSTALL_DISTROBOX="$DEFAULT_DISTROBOX" ;;
        [yY]*) INSTALL_DISTROBOX="true" ;;
        *) INSTALL_DISTROBOX="false" ;;
    esac
else
    INSTALL_DISTROBOX="false"
fi
export INSTALL_DISTROBOX

# AI (Claude, Sonnet 5, Medium) CHANGE — Beta-v2.3.0 [DISTROBOX-3]: Third release-track option
# added — "next" (the upstream v2 Go rewrite, still upstream's own
# release-candidate branch, not a tagged release). CHANGELOG §3.24: offered
# only after the maintainer validated next-branch behavior empirically
# against this exact machine (see BETA-TEST-LOG raw output) — real, known
# issues exist and are surfaced here up front rather than discovered cold:
#   - `distrobox stop` / `distrobox rm` can hang waiting on SIGTERM and
#     report "given PID did not die within timeout" even though the
#     container does eventually stop; workaround is `podman kill <id>` (or
#     `podman rm -f <id>` once killed) rather than distrobox's own
#     stop/rm — no reboot needed, this is a distrobox-level UI/timeout
#     issue, not a stuck container.
#   - An interrupted `distrobox enter` (e.g. Ctrl-C mid "Installing basic
#     packages...") can leave a container that fails to re-enter with
#     "OCI runtime error: crun: ptsname: Inappropriate ioctl for device" —
#     recoverable by removing and recreating that one container via
#     `podman rm -f`, not a system-wide problem.
#   - Needs `/etc/containers/registries.conf` to contain an
#     unqualified-search-registries line before its first image pull will
#     resolve a bare name like "alpine:latest" — this script provisions
#     that automatically below (idempotently) whenever podman is installed,
#     regardless of which distrobox track is chosen.
#   - Building it requires golang (fetched automatically by this script,
#     ~200MB) since there is no prebuilt binary for the next branch.
# Default remains "stable" (the pinned 1.8.2.5 legacy release) if the
# person doesn't want any of that; "current" (§3.13 in the 3.0.x line, still
# the pinned-legacy-vs-latest-legacy choice) sits in between.
if [ "$INSTALL_DISTROBOX" = "true" ]; then
    echo "Which distrobox release track do you want?"
    echo "  1) Stable  — pinned to version 1.8.2.5 (legacy/bash codebase)"
    echo "  2) Current — always fetches the latest legacy-branch release"
    echo "  3) Next    — upstream's v2 Go rewrite (release-candidate branch,"
    echo "     built from source, ~200MB of golang fetched to build it)."
    echo "     Known rough edges: stop/rm can report a false timeout (use"
    echo "     'podman kill'/'podman rm -f' as a workaround), an interrupted"
    echo "     'enter' can require recreating that one container, and image"
    echo "     pulls need an unqualified-search-registries entry (handled"
    echo "     automatically by this script)."
    while true; do
        ask "Enter choice [1/2/3, default ${DEFAULT_DISTROBOX_TRACK}]: "
        read -r DISTROBOX_TRACK_INPUT
        case "${DISTROBOX_TRACK_INPUT:-$DEFAULT_DISTROBOX_TRACK}" in
            1) DISTROBOX_TRACK="stable"; break ;;
            2) DISTROBOX_TRACK="current"; break ;;
            3) DISTROBOX_TRACK="next"; break ;;
            *) echo "Please enter 1, 2, or 3." >&2 ;;
        esac
    done
else
    DISTROBOX_TRACK="stable"
fi
export DISTROBOX_TRACK

# AI (Claude, Sonnet 5, Medium) ADDITION: distrobox's own config
# (~/.config/distrobox/distrobox.conf, key `container_manager=`) picks
# which backend it uses when more than one is available — this applies
# identically across all three release tracks above (confirmed against
# distrobox's own docs/discussions, not track-specific). Only meaningful,
# and only asked, when distrobox is actually being installed AND both a
# podman-family backend (rootless and/or rootful — distrobox's config
# doesn't distinguish between the two the way this script's own toggles
# do, it's just "podman" either way) AND docker are both present — with
# only one backend installed there's nothing to choose between, and
# distrobox just uses whichever one exists.
if [ "$INSTALL_DISTROBOX" = "true" ] && [ "$INSTALL_PODMAN" = "true" ] && [ "$INSTALL_DOCKER" = "true" ]; then
    echo ""
    echo "Both a Podman backend and Docker are being installed, and so is"
    echo "distrobox. Which should distrobox use by default when creating new"
    echo "containers? (You can still override this per-container later with"
    echo "the DBX_CONTAINER_MANAGER environment variable.)"
    echo "  1) Podman (default) — distrobox's own upstream default"
    echo "  2) Docker"
    while true; do
        ask "Enter choice [1/2] (default ${DEFAULT_DISTROBOX_ENGINE}): "
        read -r DISTROBOX_ENGINE_INPUT
        case "${DISTROBOX_ENGINE_INPUT:-$DEFAULT_DISTROBOX_ENGINE}" in
            ""|1) DISTROBOX_DEFAULT_ENGINE="podman"; break ;;
            2) DISTROBOX_DEFAULT_ENGINE="docker"; break ;;
            *) echo "Please enter 1 or 2." >&2 ;;
        esac
    done
else
    DISTROBOX_DEFAULT_ENGINE=""
fi
export DISTROBOX_DEFAULT_ENGINE

else
    # No containers wanted: force every container toggle off so all the
    # conditional sub-prompts (docker group-add, distrobox + track,
    # container-manager) evaluate against false and are skipped, and the
    # downstream SUBVOL_LIST / Stage-2 gating stays correct.
    INSTALL_PODMAN_ROOTLESS="false"
    INSTALL_PODMAN_ROOTFUL="false"
    INSTALL_PODMAN="false"
    INSTALL_DOCKER="false"
    DOCKER_GROUP_ADD="false"
    INSTALL_DISTROBOX="false"
    DISTROBOX_TRACK="stable"
    DISTROBOX_DEFAULT_ENGINE=""
    export INSTALL_PODMAN_ROOTLESS INSTALL_PODMAN_ROOTFUL INSTALL_PODMAN \
           INSTALL_DOCKER DOCKER_GROUP_ADD INSTALL_DISTROBOX DISTROBOX_TRACK \
           DISTROBOX_DEFAULT_ENGINE
fi

ask "Install virtualization (qemu/libvirt/virt-manager + br0 bridge)? [y/N]: "
read -r INSTALL_VIRT_INPUT
case "$INSTALL_VIRT_INPUT" in
    "") INSTALL_VIRT="$DEFAULT_VIRT" ;;
    [yY]*) INSTALL_VIRT="true" ;;
    *) INSTALL_VIRT="false" ;;
esac
export INSTALL_VIRT

# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.9.23 [SSH-SERVER]: optional OpenSSH server.
# =============================================================================
# The <host> as-built proved SSH is NOT in the default package set and /etc/sv/sshd
# is not linked out of the box, so administering a fresh box over SSH meant a
# post-install xbps-install, a hand-edited sshd_config, AND an nftables.conf edit
# (the input chain is policy drop — simply installing sshd leaves it unreachable).
# This prompt makes the whole setup a first-class choice, default-OFF to match
# the "no network-facing daemons by default" post-Beta-v2.1 [OPT-DEFAULTS] posture.
INSTALL_SSH_SERVER="false"
SSH_PORT="22"
SSH_PASSWORD_AUTH="yes"
SSH_ROOT_LOGIN="prohibit-password"
ask "Install and enable the OpenSSH server (sshd)? [y/N]: "
read -r INSTALL_SSH_SERVER_INPUT
case "$INSTALL_SSH_SERVER_INPUT" in
    "") INSTALL_SSH_SERVER="$DEFAULT_INSTALL_SSH_SERVER" ;;
    [yY]*) INSTALL_SSH_SERVER="true" ;;
    *) INSTALL_SSH_SERVER="false" ;;
esac
if [ "$INSTALL_SSH_SERVER" = "true" ]; then
    while true; do
        ask "OpenSSH server port (default ${DEFAULT_SSH_PORT}): "
        read -r SSH_PORT_INPUT
        SSH_PORT="${SSH_PORT_INPUT:-$DEFAULT_SSH_PORT}"
        if [[ "$SSH_PORT" =~ ^[0-9]+$ ]] && [ "$SSH_PORT" -ge 1 ] && [ "$SSH_PORT" -le 65535 ]; then
            break
        fi
        echo "  Please enter a valid port number (1-65535)." >&2
    done
    ask "Allow password authentication over SSH? [Y/n]: "
    read -r SSH_PASSWORD_AUTH_INPUT
    case "${SSH_PASSWORD_AUTH_INPUT:-$DEFAULT_SSH_PASSWORD_AUTH}" in
        ""|"$DEFAULT_SSH_PASSWORD_AUTH") SSH_PASSWORD_AUTH="$DEFAULT_SSH_PASSWORD_AUTH" ;;
        [yY]*) SSH_PASSWORD_AUTH="yes" ;;
        *) SSH_PASSWORD_AUTH="no" ;;
    esac
    ask "Allow root to log in over SSH (public-key only)? [Y/n]: "
    read -r SSH_ROOT_LOGIN_INPUT
    case "${SSH_ROOT_LOGIN_INPUT:-$DEFAULT_SSH_ROOT_LOGIN}" in
        ""|"$DEFAULT_SSH_ROOT_LOGIN") SSH_ROOT_LOGIN="$DEFAULT_SSH_ROOT_LOGIN" ;;
        [yY]*) SSH_ROOT_LOGIN="prohibit-password" ;;
        *) SSH_ROOT_LOGIN="no" ;;
    esac
fi
export INSTALL_SSH_SERVER SSH_PORT SSH_PASSWORD_AUTH SSH_ROOT_LOGIN

# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.9.23 [SSH-KEYS]: import existing key /
# generate fresh key / back up the keypair. Uses the shared browse_pick browser
# (refactored below from the wallpaper picker).
# =============================================================================
# Two independent toggles (import an existing keypair from removable media /
# generate a fresh ed25519 keypair). Whatever is NOT imported is generated only
# when asked; a bare-Enter run skips both (DEFAULT_* false), leaving ~/.ssh
# untouched exactly as before. No key material is ever persisted to
# install-config / limine-env / resume state / chroot_env — only public facts.
#
# Covered-path note (AI (Big Pickle) — Beta-v2.9.23 [SSH-KEYS]): staging
# happens in THIS prompt phase, long before the target @ subvolume is mounted
# over /mnt (line ~3830) — so a /mnt/tmp staging dir would get covered by the
# mount and the keys would vanish (the same bug [LIMINE-WALLPAPER-STAGE2]
# v2.9.18/2.9.19e had to fix for the wallpaper). Keys are therefore staged on
# the LIVE env's own /tmp (tmpfs, never covered) and transplanted into the
# TARGET's /mnt/tmp right after the mount, where the chroot then sees them at
# /tmp/ssh-* (SPEC's "/mnt/tmp → /tmp mapping"). Export reads back from the
# live stage during this phase, so it needs no transplant.
IMPORT_SSH_KEY="false"
GENERATE_SSH_KEY="false"
EXPORT_SSH_KEY="false"
SSH_KEY_COMMENT="${TARGET_USER}@${TARGET_HOSTNAME}"
SSH_KEY_PROTECTED="yes"
SSH_IMPORT_DIR="/tmp/ssh-import"
SSH_KEYGEN_DIR="/tmp/ssh-keygen"
ask "Import an existing SSH private key from removable media? [y/N]: "
read -r IMPORT_SSH_KEY_INPUT
case "$IMPORT_SSH_KEY_INPUT" in
    "") IMPORT_SSH_KEY="$DEFAULT_IMPORT_SSH_KEY" ;;
    [yY]*) IMPORT_SSH_KEY="true" ;;
    *) IMPORT_SSH_KEY="false" ;;
esac
if [ "$IMPORT_SSH_KEY" = "true" ]; then
    mkdir -p "$SSH_IMPORT_DIR"
    _imported_key="$(browse_pick "file" "private key to import")"
    if [ -n "$_imported_key" ]; then
        if [[ "$_imported_key" =~ \.pub$ ]]; then
            echo "  NOTICE: '${_imported_key##*/}' looks like a PUBLIC key (.pub)."
            echo "  Skipping import — feed me the private key file instead." >&2
            IMPORT_SSH_KEY="false"
        else
            # AI (Big Pickle) FIX — Beta-v2.9.88 [SSH-IMPORT-VALIDATE]: a picked
            # file was previously copied blind (any file, valid key or not) and
            # its .pub was only staged if a literal `${file}.pub` sibling existed
            # next to it. The import is now verified with `ssh-keygen -y` BEFORE
            # it is trusted:
            #   * an UNENCRYPTED key is read and a fresh .pub derived from the
            #     private key itself (guaranteed to match, comment included) —
            #     the sibling file is no longer the only source;
            #   * a PASSPHRASE-protected key asks for the passphrase once
            #     (in-memory only, never stored) and is verified with it;
            #   * anything `ssh-keygen` cannot read is rejected outright ("not a
            #     usable SSH private key") instead of being staged silently.
            # The fingerprint is printed for confirmation. No key material ever
            # reaches install-config / limine-env / resume state (unchanged).
            if ! command -v ssh-keygen >/dev/null 2>&1; then
                echo "  WARNING: ssh-keygen is unavailable on this live medium — an imported key" >&2
                echo "  can only be accepted when it can be verified. Skipping import." >&2
                IMPORT_SSH_KEY="false"
            else
                cp -f "$_imported_key" "${SSH_IMPORT_DIR}/imported"
                chmod 0600 "${SSH_IMPORT_DIR}/imported"
                _imported_key_ok="no"
                if ssh-keygen -y -P "" -f "${SSH_IMPORT_DIR}/imported" \
                        > "${SSH_IMPORT_DIR}/imported.pub" 2>/dev/null; then
                    # Unencrypted and valid — the derived .pub is authoritative.
                    _imported_key_ok="yes"
                else
                    # Not readable with an empty passphrase: either passphrase-
                    # protected, or not a key at all.
                    if grep -q -- "-----BEGIN .*PRIVATE KEY-----" "${SSH_IMPORT_DIR}/imported"; then
                        _imp_key_pass=""
                        read -r -s -p "  Enter the passphrase for this imported key: " _imp_key_pass
                        echo "" >&2
                        if [ -n "$_imp_key_pass" ] && ssh-keygen -y -P "$_imp_key_pass" -f "${SSH_IMPORT_DIR}/imported" \
                                > "${SSH_IMPORT_DIR}/imported.pub" 2>/dev/null; then
                            _imported_key_ok="yes"
                            echo "  (this key is passphrase-protected; it was verified with the passphrase you" >&2
                            echo "   just entered — SSH will still prompt for it on first use, and the passphrase" >&2
                            echo "   is never stored.)" >&2
                        else
                            echo "  ERROR: could not unlock '${_imported_key##*/}' with that passphrase — import skipped." >&2
                        fi
                    else
                        echo "  ERROR: '${_imported_key##*/}' is not a usable SSH private key (ssh-keygen could not read it) — import skipped." >&2
                    fi
                    _imp_key_pass=""
                fi
                if [ "$_imported_key_ok" = "yes" ]; then
                    chmod 0644 "${SSH_IMPORT_DIR}/imported.pub"
                    echo "  Imported private key staged → ${SSH_IMPORT_DIR}/imported"
                    echo "  Imported public key derived → ${SSH_IMPORT_DIR}/imported.pub"
                    _imp_fp="$(ssh-keygen -lf "${SSH_IMPORT_DIR}/imported.pub" 2>/dev/null | sed 's/^[[:space:]]*//' || true)"
                    echo "  Fingerprint: ${_imp_fp:-<unavailable>}"
                    echo "  (compare with 'ssh-keygen -lf' on the source machine to confirm this is your key)"
                else
                    rm -f "${SSH_IMPORT_DIR}/imported" "${SSH_IMPORT_DIR}/imported.pub"
                    IMPORT_SSH_KEY="false"
                fi
                unset _imported_key_ok _imp_fp
            fi
        fi
    else
        IMPORT_SSH_KEY="false"
    fi
fi
ask "Generate a fresh ed25519 SSH keypair? [y/N]: "
read -r GENERATE_SSH_KEY_INPUT
case "$GENERATE_SSH_KEY_INPUT" in
    "") GENERATE_SSH_KEY="$DEFAULT_GENERATE_SSH_KEY" ;;
    [yY]*) GENERATE_SSH_KEY="true" ;;
    *) GENERATE_SSH_KEY="false" ;;
esac
if [ "$GENERATE_SSH_KEY" = "true" ]; then
    echo "${C_BOLD}SSH key comment${C_RST} (a public identifier embedded in the .pub;"
    echo "  default ${C_BOLD}${SSH_KEY_COMMENT}${C_RST} — Enter to keep, type to override):"
    read -r SSH_KEY_COMMENT_INPUT
    [ -n "$SSH_KEY_COMMENT_INPUT" ] && SSH_KEY_COMMENT="$SSH_KEY_COMMENT_INPUT"
    ask "Protect the key with a passphrase? [Y/n]: "
    read -r SSH_KEY_PROTECTED_INPUT
    case "${SSH_KEY_PROTECTED_INPUT:-$DEFAULT_SSH_KEY_PROTECTED}" in
        ""|"$DEFAULT_SSH_KEY_PROTECTED") SSH_KEY_PROTECTED="$DEFAULT_SSH_KEY_PROTECTED" ;;
        [yY]*) SSH_KEY_PROTECTED="yes" ;;
        *) SSH_KEY_PROTECTED="no" ;;
    esac
    mkdir -p "$SSH_KEYGEN_DIR"
    # AI (Big Pickle) FIX — Beta-v2.9.54 [SSH-KEYGEN-STALE]: on a live medium
    # whose /tmp persists across runs (tmpfs on a fresh boot clears it, but a
    # re-run, a resume, or a dry-run that exited before the stage shred leaves
    # /tmp/ssh-keygen behind), ssh-keygen -f on the existing key prompts
    # "Overwrite (y/n)?" and silently EATS the next answer-stream line —
    # the keypair-backup export answer gets consumed as the overwrite reply
    # and the export is then declined by the stream's browse-path answer.
    # Generating means generating FRESH: drop any stale keypair first so the
    # keygen is non-interactive and the prompt stream stays aligned.
    rm -f "$SSH_KEYGEN_DIR"/id_ed25519 "$SSH_KEYGEN_DIR"/id_ed25519.pub 2>/dev/null || true
    if [ "$SSH_KEY_PROTECTED" = "yes" ]; then
        while true; do
            read -r -s -p "  Enter passphrase for the new key: " _ssh_key_pass_1; echo ""
            read -r -s -p "  Re-enter passphrase: " _ssh_key_pass_2; echo ""
            if [ -n "$_ssh_key_pass_1" ] && [ "$_ssh_key_pass_1" = "$_ssh_key_pass_2" ]; then
                break
            fi
            echo "  Passphrases empty or do not match — try again." >&2
        done
        SSH_KEY_PASSPHRASE="$_ssh_key_pass_1"
    else
        SSH_KEY_PASSPHRASE=""
    fi
    unset _ssh_key_pass_1 _ssh_key_pass_2
    # AI (Big Pickle) FIX — Beta-v2.9.81 [SSH-KEYGEN-NONINTERACTIVE]: -N is now
    # ALWAYS passed. The former ${SSH_KEY_PASSPHRASE:+-N ...} expansion omitted
    # -N when the operator answered "n" at "Protect the key with a passphrase?"
    # — but omitting -N means "prompt me", NOT "no passphrase", so ssh-keygen
    # still asked for one (and fired ksshaskpass wherever SSH_ASKPASS is set)
    # after the operator had already said no. That stray read is the same
    # answer-stream hazard 2.9.54 fixed for the overwrite prompt: whatever the
    # operator types next is swallowed as the passphrase and the export prompt
    # desyncs. `-N ""` is ssh-keygen's documented "no passphrase, do not ask".
    ssh-keygen -q -t ed25519 -C "$SSH_KEY_COMMENT" -N "${SSH_KEY_PASSPHRASE}" \
        -f "$SSH_KEYGEN_DIR/id_ed25519"
    SSH_KEY_PASSPHRASE=""
    unset SSH_KEY_PASSPHRASE _ssh_key_input
    echo "  Generated keypair → ${SSH_KEYGEN_DIR}/id_ed25519{,.pub} (comment '${SSH_KEY_COMMENT}')"
fi
ask "Export a backup copy of the SSH keypair to removable media? [y/N]: "
read -r EXPORT_SSH_KEY_INPUT
case "$EXPORT_SSH_KEY_INPUT" in
    "") EXPORT_SSH_KEY="$DEFAULT_EXPORT_SSH_KEY" ;;
    [yY]*) EXPORT_SSH_KEY="true" ;;
    *) EXPORT_SSH_KEY="false" ;;
esac
if [ "$EXPORT_SSH_KEY" = "true" ]; then
    _export_src=""
    [ -f "$SSH_KEYGEN_DIR/id_ed25519" ] && _export_src="$SSH_KEYGEN_DIR/id_ed25519"
    # shellcheck disable=SC2012  # single newest/most-relevant import copy is intended
    [ -z "$_export_src" ] && [ -f "$SSH_IMPORT_DIR/imported" ] && _export_src="$SSH_IMPORT_DIR/imported"
    if [ -z "$_export_src" ]; then
        echo "  No key present to export (import+generate were both declined)." >&2
        EXPORT_SSH_KEY="false"
    else
        _export_dst="$(browse_pick "dir" "backup destination directory")"
        if [ -d "$_export_dst" ]; then
            cp -f "$_export_src" "${_export_dst}/id_ed25519-backup"
            cp -f "${_export_src}.pub" "${_export_dst}/id_ed25519-backup.pub" 2>/dev/null || true
            chmod 600 "${_export_dst}/id_ed25519-backup"
            echo "  Key exported → ${_export_dst}/id_ed25519-backup{,.pub}"
        else
            echo "  No destination chosen; skipping export." >&2
            EXPORT_SSH_KEY="false"
        fi
    fi
fi
unset _imported_key _export_src _export_dst _imp_key_pass
export IMPORT_SSH_KEY GENERATE_SSH_KEY EXPORT_SSH_KEY SSH_KEY_COMMENT SSH_KEY_PROTECTED

# (The Docker / Podman-rootful / Virtualization system-datadir pre-create
# prompts are now governed by the [SUBVOL-GATES] Gate 2 resolver below —
# Beta-v2.9.0 — not per-app here.)

# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.9.0 [SUBVOL-GATES]: MASTER SUBVOLUME GATES.
# =============================================================================
# Two y/n/i master gates replace the old scattered per-app "pre-create"
# prompts (browsers, SETUP_APPS per-user apps, container/virt system datadirs).
# They are asked here, after every INSTALL_* choice is finalized, because each
# gate's answer must be resolved against the user's real install decisions.
#
#   Gate 1  SUBVOL_ISOLATE_INSTALLED  — software you ARE installing:
#           should each one get an isolated subvol (so a Snapshot rollback of
#           @/@home can't rewind its data)? y = all, n = none, i = per-app.
#   Gate 2  SUBVOL_PRECREATE          — software you did NOT install:
#           pre-create an EMPTY isolated subvol now, in case you install it
#           manually later (its data stays isolated from day one)?
#           y = all, n = none, i = per-app.
#
# After both gates, every PROVISION_*_SUBVOL is RESOLVED to that app's final
# "isolate?" decision (true = an isolated subvol is created/mounted for it)
# and re-exported. All downstream sites (SUBVOL_LIST, mkdir, mount, fstab,
# provision_browser_subvol, teardown) now read ONLY the resolved
# PROVISION_*_SUBVOL flag — never INSTALL_* directly — so a single source of
# truth drives every stage. [PROMPT-DEFAULTS]: bare-Enter on each gate falls
# back to DEFAULT_SUBVOL_ISOLATE (true) / DEFAULT_SUBVOL_PRECREATE (false).
echo ""
echo "Subvolume isolation: all of the optional software you selected above"
echo "with the exception of OctoXBPS and Flatpak (browsers, mail, Steam,"
echo "VirtualBox, Homebrew, Docker, Podman rootful/rootless, virtualization) can be"
echo "given its own isolated Btrfs subvolume, so a Snapper rollback of @"
echo "or @home does not rewind that software's data. OctoXBPS and Flatpak"
echo "are excluded — OctoXBPS is a lightweight GUI package-manager frontend"
echo "with no dedicated data directory to isolate; Flatpak's system-wide"
echo "store lives under /var/lib/flatpak which is part of the @ root"
echo ""
echo "Two master choices follow:"
echo "  1) Software you ARE installing now — isolate its data subvolume?"
echo "  2) Software you did NOT install — pre-create an EMPTY isolated subvolume"
echo "     now, so that if you install it manually later, its data lands on the"
echo "     isolated subvolume from day one (no mixing back into @ / @home, and"
echo "     no migration needed)."
echo "  Answer 'i' to decide per app instead of one bulk answer."
# AI (Big Pickle) FIX — Beta-v2.9.88 [SUBVOL-GATE-VALIDATE]: the two master
# gates used to map ANY unrecognized answer to the bulk default (Gate 1:
# junk -> isolate ALL; Gate 2: junk -> precreate NONE), so one stray keystroke
# (observed live: a lone period typed at the Gate-1 prompt) silently flipped
# the isolation decision for every installed app. Answers are now validated:
# blank (default) / y / n / i only — anything else is shown with a hint and
# re-prompted. `i` still walks each app individually via _subvol_ask below.
# This also normalizes the bare-Enter path: the DEFAULT_* knobs are booleans
# (true/false), which Gate 1 previously stored verbatim into
# SUBVOL_ISOLATE_INSTALLED ("true" != "yes"), silently diverting a default run
# into the per-app walk; the helper now maps them to yes/no as documented.
_subvol_master() { # $1 = prompt text, $2 = boolean default ("true"/"false")
    local _a _def_out
    case "$2" in
        true|yes) _def_out="yes" ;;
        *)        _def_out="no" ;;
    esac
    while true; do
        ask "$1" >&2
        read -r _a
        case "$_a" in
            "") echo "$_def_out"; return ;;
            [yY]) echo "yes"; return ;;
            [nN]) echo "no"; return ;;
            [iI]) echo "individual"; return ;;
            *) echo "  Unrecognized answer '${_a}' — Enter for the default, y/n = all/none, i = per-app." >&2 ;;
        esac
    done
}
SUBVOL_ISOLATE_INSTALLED="$(_subvol_master "For software you ARE installing, give each its own isolated subvolume? [Y/n/i]: " "$DEFAULT_SUBVOL_ISOLATE")"
export SUBVOL_ISOLATE_INSTALLED

SUBVOL_PRECREATE="$(_subvol_master "For software you did NOT install, pre-create an empty isolated subvolume for later manual use? [y/N/i]: " "$DEFAULT_SUBVOL_PRECREATE")"
export SUBVOL_PRECREATE

# --- Resolve each app's final "isolate?" decision into PROVISION_*_SUBVOL ---
# Every app follows the same 3x3 rule from the two gates:
#   Installed app:  Gate1 yes -> isolate; no -> not; individual -> ask (def yes)
#   Not-installed:  Gate2 yes -> pre-create; no -> not; individual -> ask (def no)
# This is table-driven: each row is "INSTALL_VAR|PROVISION_VAR|label" (a pipe
# separator so a label may contain spaces). The loop reads the row, checks the
# INSTALL_* var, and writes the resolved PROVISION_VAR. Rows whose software has
_subvol_ask() { # $1=full prompt text, $2=default("true"/"false")
    local _a
    while true; do
        ask "$1" >&2
        read -r _a
        case "$_a" in
            [yY]*) echo "true"; return ;;
            "")    echo "$2"; return ;;
            [nN]*) echo "false"; return ;;
            *)     echo "  Unrecognized answer — Enter for the default, y = yes, n = no." >&2 ;;
        esac
    done
}

# shellcheck disable=SC2016 # deliberate table of unexpanded var names
SUBVOL_ROWS="
INSTALL_FIREFOX|PROVISION_FIREFOX_SUBVOL|Firefox
INSTALL_CHROMIUM|PROVISION_CHROMIUM_SUBVOL|Chromium
INSTALL_VIVALDI|PROVISION_VIVALDI_SUBVOL|Vivaldi
INSTALL_FALKON|PROVISION_FALKON_SUBVOL|Falkon
INSTALL_BRAVE|PROVISION_BRAVE_SUBVOL|Brave
INSTALL_THUNDERBIRD|PROVISION_THUNDERBIRD_SUBVOL|Thunderbird
# AI (Big Pickle) ADDITION — Beta-v2.9.37 [GAME-SUBVOL]: ONE row for the shared
# @game subvol, gated on INSTALL_ANY_GAME (Steam ∨ Lutris ∨ Heroic ∨ Bottles)
# instead of one row per launcher. Wine/gamemode stay out of the gate — they
# have no isolated data datadir.
INSTALL_ANY_GAME|PROVISION_GAME_SUBVOL|Game data
INSTALL_VIRTUALBOX|PROVISION_VIRTUALBOX_SUBVOL|VirtualBox
INSTALL_FLATPAK|PROVISION_FLATPAK_SUBVOL|Flatpak
INSTALL_BREW|PROVISION_LINUXBREW_SUBVOL|Homebrew (Linuxbrew)
INSTALL_DOCKER|PROVISION_DOCKER_SUBVOL|Docker
INSTALL_PODMAN_ROOTFUL|PROVISION_PODMAN_SUBVOL|Podman (rootful)
INSTALL_PODMAN_ROOTLESS|PROVISION_PODMAN_ROOTLESS_SUBVOL|Podman (rootless)
INSTALL_VIRT|PROVISION_VIRT_SUBVOL|Virtualization
"

echo ""
echo "Subvolume isolation per app:"
# [SUBVOL-ROWS-FIX] (Beta-v2.9.39): the table is allowed to carry `#`-comment
# rows (e.g. the [GAME-SUBVOL] explanatory block above). The reader originally
# only skipped EMPTY rows, so a quote-bearing comment line fell through to the
# `eval "INSTALL_X=\${...}"` and produced a ``bad substitution'' — which under
# this script's `set -eEo pipefail` fired the ERR trap and aborted a fresh
# install at the subvolume prompts. Skip any row whose first non-space char is
# `#` before touching eval; this is also what keeps future comment lines with
# quotes/backslashes safe.
while IFS='|' read -r _iv _pv _label; do
    [ -z "$_iv" ] && continue
    case "$_iv" in
        \#*) continue ;;
    esac
    eval "INSTALL_X=\${${_iv}:-false}"
    if [ "$INSTALL_X" = "true" ]; then
        if   [ "$SUBVOL_ISOLATE_INSTALLED" = "yes" ]; then
            _dec="true"
        elif [ "$SUBVOL_ISOLATE_INSTALLED" = "no" ]; then
            _dec="false"
        else
            _dec="$(_subvol_ask "  $_label — Isolate this installed app? [Y/n]: " true)"
        fi
    else
        if   [ "$SUBVOL_PRECREATE" = "yes" ]; then
            _dec="true"
        elif [ "$SUBVOL_PRECREATE" = "no" ]; then
            _dec="false"
        else
            _dec="$(_subvol_ask "  $_label — Pre-create empty subvol for later? [y/N]: " false)"
        fi
    fi
    eval "${_pv}=\$_dec"
    # shellcheck disable=SC2163 # _pv is a dynamically-computed PROVISION_*_SUBVOL name; export deliberately uses the variable name
    export "$_pv"
    echo "  -> ${_pv}=$_dec"
done <<EOF
$SUBVOL_ROWS
EOF

# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS] / [MULTI-FS-FOLD].
# When a region was carved onto its own partition, every subvolume that region
# owns becomes impossible: a top-level Btrfs subvol cannot span a separate
# partition. Each carved region FORCES the owned PROVISION_*_SUBVOL flags off
# here (single site, right after the [SUBVOL-GATES] resolver), so SUBVOL_LIST,
# the mount loop, fstab, and Stage 2 all agree through the folded flag alone.
# Ownership map (region -> owned subvol names, per the spec):
#   home  -> @home @usercache @mozilla @mozilla-cache @chromium @vivaldi
#            @falkon @brave @thunderbird @game @containers-user @linuxbrew
#            @virtualbox
#   var   -> @log @spool @network @libvirt @flatpak @docker @containers
#            (+ @sddm / @lightdm only when that DM was chosen)
#   cache -> @cache ;  srv -> @srv ;  opt -> @opt
# @snapshots, @root, and @ (the Snapper / dracut-overlay / Limine invariants)
# are NEVER folded — root is always a single Btrfs even when /var is ext4.
# The games region owns NO subvol here: ~/Games is a plain dir on @home (or on
# the carved home region); the @game per-launcher subvol lives under @home and
# folds with the home region itself.
# =============================================================================
if [ -n "${REGION_PARTITIONED:-}" ]; then
    for _rg in $REGION_PARTITIONED; do
        case "$_rg" in
            home )
                PROVISION_FIREFOX_SUBVOL=false;       PROVISION_CHROMIUM_SUBVOL=false
                PROVISION_VIVALDI_SUBVOL=false;       PROVISION_FALKON_SUBVOL=false
                PROVISION_BRAVE_SUBVOL=false;         PROVISION_THUNDERBIRD_SUBVOL=false
                PROVISION_GAME_SUBVOL=false;          PROVISION_PODMAN_ROOTLESS_SUBVOL=false
                PROVISION_LINUXBREW_SUBVOL=false;     PROVISION_VIRTUALBOX_SUBVOL=false
                jl "MULTI-FS-FOLD: home region carved — home-owned subvol flags forced off (browsers/thunderbird/game/containers-user/linuxbrew/virtualbox)"
                ;;
            var )
                PROVISION_VIRT_SUBVOL=false;          PROVISION_FLATPAK_SUBVOL=false
                PROVISION_DOCKER_SUBVOL=false;        PROVISION_PODMAN_SUBVOL=false
                jl "MULTI-FS-FOLD: var region carved — var-owned subvol flags forced off (libvirt/flatpak/docker/containers)"
                ;;
            cache ) jl "MULTI-FS-FOLD: cache region carved (@cache stays on the region partition)" ;;
            srv )   jl "MULTI-FS-FOLD: srv region carved (@srv stays on the region partition)" ;;
            opt )   jl "MULTI-FS-FOLD: opt region carved (@opt stays on the region partition)" ;;
            games ) jl "MULTI-FS-FOLD: games region carved (~/Games on its own partition; @home/@game unaffected)" ;;
            * ) echo "FATAL: unknown region '$_rg'." >&2; exit 1 ;;
        esac
    done
    unset _rg
fi

# AI (Claude, Sonnet 5, Medium) CHANGE: This whole detection block only matters for the br0
# bridge (VM networking), so it's skipped entirely when virtualization
# isn't being installed — no reason to probe hardware or set
# NET_INTERFACE_MATCH for something that won't be used.
if [ "$INSTALL_VIRT" = "true" ]; then

echo ""
echo "NOTICE: br0 bridge networking needs a real, dedicated network"
echo "interface. This installer looks for one automatically:"
echo "  1) A wired Ethernet port with an active cable connected — used"
echo "     if found."
echo "  2) If no wired port has an active link, a USB Ethernet adapter or"
echo "     USB-tethered phone that's physically present (cable optional)."
echo ""
echo "If this machine has no built-in wired Ethernet port, make sure a USB"
echo "Ethernet adapter is plugged in now before continuing."
echo ""
echo "IMPORTANT: whichever USB Ethernet device gets detected needs to stay"
echo "in the SAME USB port going forward. Many USB Ethernet adapters are"
echo "named based on which physical USB port they're plugged into (not"
echo "just the device itself) — moving it to a different port later can"
echo "change its detected name, and the bridge configuration written by"
echo "this installer won't automatically follow that change."
echo ""
echo "If NO wired interface is found at all, the br0 bridge will be"
echo "skipped entirely and libvirt's default NAT network (virbr0) left"
echo "enabled instead — so your VMs still get working networking."
echo ""
echo "${C_YLW}${C_BOLD}  When ready, press Enter to continue.${C_RST}"
read -r -p "Press Enter once ready to continue: " _
# End of the skipped-on-resume interactive configuration block.
fi

# =============================================================================
# AI (Big Pickle) CHANGE — Beta-v2.4.0 [RESUME]: NIC detection, disk enumeration,
# disk selection, the already-installed guard, and the ERASE confirmation are
# all skipped on a resumed run — the target disk and NIC were already chosen
# in the interrupted run and are restored from the state file.
# =============================================================================
if [ "$RESUME" != "1" ]; then
# AI (Big Pickle) FIX — Beta-v2.9.85 [NIC-DETECT-USB]: was two inline loops
# (already-correct logic; the helper adds only the name-skip list, so a
# Bluetooth-USB netdev can no longer qualify as a "USB NIC") — both probe
# sites now run detect_wired_nic(), so the review's BR0_NIC and this
# NET_INTERFACE_MATCH answer can never disagree.
DETECTED_NIC="$(detect_wired_nic || true)"

if [ -n "$DETECTED_NIC" ]; then
    export NET_INTERFACE_MATCH="$DETECTED_NIC"
elif has_wired_nic_hw; then
    # AI (Big Pickle) CHANGE — Beta-v2.9.86 [BR0-SKIP]: a wired port EXISTS
    # but has no active link right now (built-in PCIe, cable unplugged — not
    # USB, or pass 2 would have found it). Keep the role-matched fallback
    # slave exactly as before so plugging the cable in later still binds the
    # bridge: this is the case the skip must NOT swallow.
    echo "WARNING: a wired ethernet port is present but has no active link — falling back to role-matched 'enp*' so plugging a cable in later still binds the br0 slave." >&2
    export NET_INTERFACE_MATCH="enp*"
else
    # AI (Big Pickle) CHANGE — Beta-v2.9.86 [BR0-SKIP]: NO wired hardware at
    # all (pure-Wi-Fi / WWAN-only box). An EMPTY NET_INTERFACE_MATCH is the
    # explicit skip signal — it is already persisted to resume state and
    # chroot_env, and Stage-2 writes neither br0 profile on it, while
    # rc.local keeps virbr0 enabled as the VM-networking fallback.
    export NET_INTERFACE_MATCH=""
    if [ "$INSTALL_VIRT" = "true" ]; then
        echo "NOTICE: no wired network interface found on this machine."
        echo "        The br0 bridge will be SKIPPED; libvirt's default NAT"
        echo "        network (virbr0) stays enabled so your VMs still get"
        echo "        working networking out of the box."
    fi
fi

fi


# =============================================================================
# DISK SELECTION — interactive, replaces the old hardcoded /dev/nvme0n1
# =============================================================================
# AI (Claude, Sonnet 5, Medium) ADDITION: the target disk is now chosen
# interactively instead of assumed. Two safety layers, both requested
# explicitly rather than left implicit:
#   1. Any disk that's currently mounted anywhere — including, critically,
#      the live install medium itself (USB stick/ISO this script is
#      running from) — is filtered OUT of the numbered list entirely. This
#      is the same generic heuristic other distro installers use (if a
#      disk or any of its partitions has a live mountpoint, it's "in use"
#      and not offered as a wipe target) — not Void-specific, so it should
#      still be spot-checked on the very first real run in case Void's
#      live-ISO mount layout does something unusual.
#   2. Before anything touches the disk, the person must type the literal
#      word ERASE — not a [y/N] prompt — to confirm. A destructive wipe
#      against an installer-picked, previously-hardcoded disk is one
#      thing; a destructive wipe against a disk the person just chose from
#      a list is a much easier place to fat-finger the wrong number, so
#      the confirmation bar is intentionally higher here than elsewhere in
#      this script.
echo ""
echo "${C_BOLD}${C_CYN}DISK SELECTION${C_RST}"
note "Scanning for available disks..."
mapfile -t DISK_CANDIDATE_NAMES < <(lsblk -d -n -o NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1}')

if [ "${#DISK_CANDIDATE_NAMES[@]}" -eq 0 ]; then
    echo "FATAL: lsblk found no block devices of type 'disk' at all." >&2
    exit 1
fi

DISK_LIST=()
for _cand in "${DISK_CANDIDATE_NAMES[@]}"; do
    _dev="/dev/${_cand}"
    # Exclude anything currently mounted anywhere (the disk itself or any
    # partition/child of it) — this is what filters out the live medium.
    if lsblk -n -o MOUNTPOINT "$_dev" 2>/dev/null | grep -q '[^[:space:]]'; then
        continue
    fi
    DISK_LIST+=("$_dev")
done

if [ "${#DISK_LIST[@]}" -eq 0 ]; then
    echo "FATAL: no unmounted physical disks found to install onto (the live" >&2
    echo "       medium and/or any other mounted disks were filtered out)." >&2
    exit 1
fi

echo ""
echo "${C_BOLD}Available disks${C_RST} (the live install medium and any currently-mounted"
echo "disks are hidden from this list; ${C_YLW}red${C_RST} = data present, ${C_GRN}green${C_RST} = empty):"
echo ""
declare -A DISK_BY_INDEX
declare -A DISK_PART_COUNT
_i=1
for _dev in "${DISK_LIST[@]}"; do
    _size="$(lsblk -dn -o SIZE "$_dev" 2>/dev/null)"
    _model="$(lsblk -dn -o MODEL "$_dev" 2>/dev/null | sed -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//')"
    _tran="$(lsblk -dn -o TRAN "$_dev" 2>/dev/null)"
    [ -z "$_model" ] && _model="(unknown model)"
    [ -z "$_tran" ] && _tran="?"
    # AI (Claude, Sonnet 5, Medium) FIX: `grep -c` exits 1 (not 0) when the
    # count is zero — under this script's `set -e`, an empty-partition disk
    # would kill the whole installer right here with no error message,
    # caught by testing this block standalone with a mocked lsblk before
    # it ever ran for real. `|| true` keeps the (correct) "0" count without
    # tripping set -e.
    _part_count="$(lsblk -n -o TYPE "$_dev" 2>/dev/null | grep -c '^part$' || true)"
    if [ "$_part_count" -gt 0 ]; then
        _status="${C_RED}HAS EXISTING PARTITIONS/DATA${C_RST}"
    else
        _status="${C_GRN}appears empty${C_RST}"
    fi
    printf "  %d) %-14s %8s  %-9s %-28s [%s]\n" "$_i" "$_dev" "$_size" "($_tran)" "$_model" "$_status"
    DISK_BY_INDEX[$_i]="$_dev"
    DISK_PART_COUNT[$_i]="$_part_count"
    _i=$((_i + 1))
done
_disk_count=$((_i - 1))

echo ""
while true; do
    ask "Select disk to partition and install to [1-${_disk_count}]: "
    read -r DISK_CHOICE
    if [[ "$DISK_CHOICE" =~ ^[0-9]+$ ]] && [ "$DISK_CHOICE" -ge 1 ] && [ "$DISK_CHOICE" -le "$_disk_count" ]; then
        break
    fi
    echo "Please enter a number between 1 and ${_disk_count}." >&2
done
export DISK="${DISK_BY_INDEX[$DISK_CHOICE]}"

# AI (Big Pickle) ADDITION — Beta-v2.9.48 [DISK-BUDGET]: capture the raw
# byte-size of the selected disk while the picker is live. This feeds the
# pre-write fit check that refuses an over-provisioned layout before any
# partition touch; the value is also persisted in the state file so a
# resumed run can still do the check without re-picking. Fails open when
# unreadable (lsblk rare edge case) — the check is skipped, never fatal.
DISK_BYTES="$(lsblk -bdn -o SIZE "$DISK" 2>/dev/null | tr -d '[:space:]' || true)"

# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.4.0 [item 7]: RE-RUN / ALREADY-INSTALLED GUARD
# =============================================================================
# The live USB environment is ephemeral but the SELECTED target disk is NOT.
# Re-running this installer (e.g. the user boots the live USB again, or a
# crashed run is restarted) over a target that ALREADY has a working Void
# install would silently destroy it the moment partitioning begins. Detect
# that high-consequence case with a conservative, read-only probe BEFORE any
# destructive operation, and if found, raise the confirmation bar.
#   - Conservative by design: only flags on strong Void-specific signals
#     (Void OS-release + the script's Btrfs subvolume layout), so a clean
#     disk, a non-Void OS, or an "appears empty" target gets ZERO added
#     friction (fresh-install path is unchanged).
#   - Pure read-only: mounts the target's Btrfs subtree read-only, inspects,
#     then unmounts. Never mutates the disk.
#   - Runs under set -eE, so every probing step is guarded (|| true) — a
#     probe failure must never abort the install or trigger the unwind trap;
#     it simply means "not detected", which is the safe default.
disk_has_void_install() {
    local _tgt="$1"
    local _probe_dir="" _dev _fstype _found=0 _kid
    # Read the target's child partition names (list excludes the parent row).
    while IFS= read -r _kid; do
        [ -n "$_kid" ] || continue
        _dev="/dev/${_kid}"
        _fstype=$(lsblk -rno FSTYPE "$_dev" 2>/dev/null || true)
        [ "$_fstype" = "btrfs" ] || continue
        _probe_dir="$(mktemp -d /tmp/void-probe.XXXXXX 2>/dev/null || true)"
        [ -n "$_probe_dir" ] || continue
        if mount -o ro,nosuid,nodev "$_dev" "$_probe_dir" 2>/dev/null; then
            # Strong Void markers only. os-release ID=void is the definitive
            # signal; the script's Btrfs subvol layout (@/@root/@home) and
            # the /etc/void-installer sentinel are corroborating ones.
            if [ -f "$_probe_dir/etc/os-release" ] && grep -qiE '^(ID|ID_LIKE)=["'\'']?void' "$_probe_dir/etc/os-release"; then
                _found=1
            elif { [ -d "$_probe_dir/@" ] || [ -d "$_probe_dir/@root" ] || [ -d "$_probe_dir/@home" ]; } \
                 && [ -e "$_probe_dir/etc/void-installer/limine-env" ]; then
                _found=1
            fi
            umount -l "$_probe_dir" 2>/dev/null || true
        fi
        rmdir "$_probe_dir" 2>/dev/null || true
        [ "$_found" -eq 1 ] && break
    done < <(lsblk -rno NAME "$_tgt" 2>/dev/null | tail -n +2)
    [ "$_found" -eq 1 ]
}

_TARGET_HAS_VOID="false"
if disk_has_void_install "$DISK"; then
    _TARGET_HAS_VOID="true"
fi

echo ""
echo "${C_RED}==============================================================================${C_RST}"
echo "${C_RED}${C_BOLD}  WARNING — DESTRUCTIVE OPERATION${C_RST}"
echo "${C_RED}==============================================================================${C_RST}"
echo "${C_BOLD}  You selected: ${C_RED}${DISK}${C_RST}"
echo ""
echo "${C_RED}${C_BOLD}  This installer will COMPLETELY WIPE this disk. Every partition and every${C_RST}"
echo "${C_RED}${C_BOLD}  byte of existing data on it will be PERMANENTLY DESTROYED, with no way to${C_RST}"
echo "${C_RED}${C_BOLD}  undo it once partitioning begins.${C_RST}"
if [ "${DISK_PART_COUNT[$DISK_CHOICE]}" -gt 0 ]; then
    echo ""
    echo "${C_YLW}${C_BOLD}  NOTE: this disk currently HAS existing partitions/data on it.${C_RST}"
fi
if [ "$_TARGET_HAS_VOID" = "true" ]; then
    echo ""
    echo "${C_YLW}${C_BOLD}  NOTE: this disk appears to ALREADY contain a Void Linux installation.${C_RST}"
    echo "${C_YLW}${C_BOLD}  Re-running will permanently destroy it with no way to recover.${C_RST}"
fi
echo "${C_RED}==============================================================================${C_RST}"
echo ""
if [ "$_TARGET_HAS_VOID" = "true" ]; then
    # Elevated bar for the already-installed case: must type ERASE <device>.
    echo "${C_RED}${C_BOLD}  >>> This appears to be an existing Void install. To proceed, type:${C_RST}"
    echo "${C_RED}${C_BOLD}          ERASE ${DISK}${C_RST}"
    echo ""
    ask "Type 'ERASE ${DISK}' (with the exact device path) to confirm, or anything else to abort: "
    read -r ERASE_CONFIRM
    if [ "$ERASE_CONFIRM" != "ERASE ${DISK}" ]; then
        echo "${C_RED}!! Confirmation with exact device path not received — aborting before touching any disk.${C_RST}" >&2
        exit 1
    fi
else
    # Normal (fresh / non-Void / empty) path — keep prior confirmation flow,
    # but require the literal word ERASE! to confirm. The exact-device
    # round-trip ("ERASE /dev/xxx") used to be required here too, matching the
    # elevated already-installed path above, but that was dropped (AI (Big
    # Pickle) Beta-v2.5.2): the chosen disk is displayed prominently right
    # above, and the stricter typed-device bar is retained only for the
    # already-installed-Void re-run path, the scenario with the most to lose.
    echo "${C_RED}${C_BOLD}  >>> To proceed, type ERASE! below (all caps, with the exclamation mark). <<<${C_RST}"
    echo ""
    ask "Confirm wiping ${DISK}: type 'ERASE!' (or anything else to abort): "
    read -r ERASE_CONFIRM
    if [ "$ERASE_CONFIRM" != "ERASE!" ]; then
        echo "${C_RED}!! Confirmation 'ERASE!' not received — aborting before touching any disk.${C_RST}" >&2
        exit 1
    fi
fi

# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.5.2 [CONFIRM]: post-ERASE, pre-partition
# final review. Every install-time choice is now captured, so print a complete
# summary of what is about to be installed and give the user one last chance to
# back out BEFORE any disk is touched. Pressing Enter proceeds to the
# destructive partitioning; typing R re-runs the entire configuration from the
# top (nothing has been written to disk yet — the ERASE confirmation only
# confirmed intent, it did not write anything). This lives inside the
# skipped-on-resume block because a resumed run already had its config
# reviewed before the interrupted run.
# =============================================================================
_rev_de=$(case "$DESKTOP_ENV" in kde) echo KDE Plasma;; cinnamon) echo Cinnamon;; gnome) echo GNOME;; xfce) echo Xfce;; mate) echo MATE;; lxqt) echo LXQt;; cosmic) echo COSMIC;; *) echo "$DESKTOP_ENV";; esac)
_rev_dm="$DISPLAY_MANAGER"
if [ "$DISPLAY_MANAGER" = "lightdm" ]; then
    case "$LIGHTDM_GREETER_PKG" in
        lightdm-slick-greeter) _rev_dm="LightDM (Slick greeter)" ;;
        lightdm-gtk-greeter)   _rev_dm="LightDM (GTK greeter)" ;;
    esac
fi
_rev_shell="$USER_SHELL"
_rev_swapfmt="$SWAPFILE_SIZE"
_rev_swap="none"
case "$SWAP_BACKEND" in
    swapfile) _rev_swap="swapfile (${_rev_swapfmt})" ;;
    zram)     _rev_swap="zram" ;;
    both)     _rev_swap="swapfile (${_rev_swapfmt}) + zram" ;;
esac
echo ""
echo "${C_CYN}==============================================================================${C_RST}"
echo "${C_CYN}${C_BOLD}  REVIEW — please confirm these settings BEFORE anything is written to disk${C_RST}"
echo "${C_CYN}==============================================================================${C_RST}"
echo "${C_BOLD}  Target disk      :${C_RST} ${DISK}"
echo "${C_BOLD}  Hostname         :${C_RST} ${TARGET_FQDN:-$TARGET_HOSTNAME}"
echo "${C_BOLD}  Primary user     :${C_RST} ${TARGET_USER}${TARGET_FULL_NAME:+  (${TARGET_FULL_NAME})}  (login shell: ${_rev_shell})"
echo "${C_BOLD}  Desktop / DM     :${C_RST} ${_rev_de} / ${_rev_dm}"
echo "${C_BOLD}  Session stack    :${C_RST} ${SESSION_STACK}"
echo "${C_BOLD}  Bootloader       :${C_RST} ${BOOTLOADER}"
if [ "$BOOTLOADER" = "limine" ]; then
    echo "${C_BOLD}  Kernel access    :${C_RST} ${KERNEL_MODE} (Limine)"
    if [ "$LIMINE_WALLPAPER" = "yes" ]; then
        echo "${C_BOLD}  Boot wallpaper   :${C_RST} enabled (${LIMINE_WALLPAPER_STYLE})"
    fi
fi
echo "${C_BOLD}  Locale / Zone    :${C_RST} ${LOCALE} / ${TIMEZONE}"
echo "${C_BOLD}  Repo (primary)   :${C_RST} ${REPO_PRIMARY}"
echo "${C_BOLD}  Swap             :${C_RST} ${_rev_swap}${ENABLE_HIBERNATION:+  (hibernation: ${ENABLE_HIBERNATION})}"
echo "${C_BOLD}  Encryption       :${C_RST} $([ "$ENCRYPT" = "yes" ] && { [ "$YK_MODE" = "hmac-sha1" ] && echo "LUKS2 full-disk + YubiKey hmac-sha1 (fallback: $YK_FALLBACK)" || echo "LUKS2 full-disk (passphrase at boot)"; } || echo "none")"
if [ "$ACCOUNT_MODEL" = "hybrid" ]; then
    _rev_acct="hybrid (root password + user sudo)"
elif [ "$ACCOUNT_MODEL" = "debian" ]; then
    _rev_acct="debian (root password, user has no sudo)"
else
    _rev_acct="$ACCOUNT_MODEL (root locked, user sudo)"
fi
echo "${C_BOLD}  Account model    :${C_RST} ${_rev_acct}"
if [ -n "${GPU_FAMILIES:-}" ]; then
    echo "${C_BOLD}  Hardware         :${C_RST} GPU=${GPU_FAMILIES}  wireless=${WIFI_HW:-unknown}"
    echo "${C_BOLD}  NVIDIA driver    :${C_RST} ${INSTALL_NVIDIA}"
fi
echo "${C_CYN}==============================================================================${C_RST}"
echo ""
echo "  ${C_GRN}Press Enter${C_RST} to proceed with the install, or ${C_YLW}type R${C_RST} to re-run the entire"
echo "  configuration from the top and revise your choices (no disk has been touched yet)."
ask "Proceed with these settings? [Enter=continue, R=restart config]: "
read -r _rev_ans
case "$_rev_ans" in
    [rR])
        echo ""
        echo "!! Configuration review declined — restarting the installer so you can revise your choices." >&2
        # Nothing destructive has happened; a fresh re-run re-prompts everything.
        # Remove any (possibly stale) state file so the re-run starts clean instead
        # of offering to resume, then re-exec with the same args from the top.
        rm -f "$STATE_FILE" 2>/dev/null || true
        exec "$0" "$@"
        ;;
    *)
        echo "==> Settings confirmed — proceeding to partition ${DISK}."
        ;;
esac
unset _rev_de _rev_dm _rev_shell _rev_swapfmt _rev_swap _rev_acct _rev_ans
# End of the skipped-on-resume NIC/disk/ERASE block.
fi

# AI (Claude, Sonnet 5, Medium) CHANGE: broadened beyond just nvme* — now that
# the disk is picked interactively rather than hardcoded to a known NVMe
# device, an eMMC target (/dev/mmcblkN) is just as reachable as NVMe, and
# it uses the same "pN" partition-suffix convention nvme does (unlike
# sdX/vdX, which just append the number directly).
if [[ "$DISK" =~ (nvme|mmcblk) ]]; then
    export PART_EFI="${DISK}p1"
    export PART_SYS="${DISK}p2"
else
    export PART_EFI="${DISK}1"
    export PART_SYS="${DISK}2"
fi

# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS]: PARTITION GEOMETRY.
# When data regions were carved (REGION_PARTITIONED non-empty) WITHOUT
# encryption, the fixed order home,var,cache,srv,opt,games is sliced FIRST on
# the disk and the Btrfs LINUX root goes LAST, sized to the remainder — so the
# system partition is no longer p2: PART_SYS = p(2+nreg). WITH encryption the
# disk keeps ESP p1 + one LUKS container taking the whole remainder, and the
# carved regions become an inner GPT inside the opened mapper (region N is
# mapper-pN, the Btrfs root is mapper-p(NREG+1), partscan forced by
# close/reopen — UNPROVEN, [MULTI-FS-PARTSCAN-FORCE] / [INNER-PARTSCAN-BOOT]
# harden it later). Computed here (single site) so the resume-state file, the
# dry-run plan, $BTRFS_DEV, fstab, and the sgdisk carve below all agree.
# Partition 1 stays the ESP in every layout.
# =============================================================================
for _rr in $REGION_PARTITIONED; do
    case "$_rr" in
        home|var|cache|srv|opt|games) ;;
        *) echo "FATAL: unknown carved region '$_rr' in REGION_PARTITIONED." >&2; exit 1 ;;
    esac
done
NREG=0
for _rr in $REGION_PARTITIONED; do NREG=$((NREG + 1)); done
unset _rr
if [ -n "${REGION_PARTITIONED:-}" ] && [ "$ENCRYPT" != "yes" ]; then
    # Outer-disk carve: regions 2..1+nreg, LINUX last (remainder).
    if [[ "$DISK" =~ (nvme|mmcblk) ]]; then
        export PART_SYS="${DISK}p$((NREG + 2))"
    else
        export PART_SYS="${DISK}$((NREG + 2))"
    fi
    # Per-region partition device, in carve order.
    _rr_i=1
    for _rr in $REGION_PARTITIONED; do
        _rr_pn=$((_rr_i + 1))
        if [[ "$DISK" =~ (nvme|mmcblk) ]]; then
            eval "REGION_PART_${_rr}=\"\${DISK}p\${_rr_pn}\""
        else
            eval "REGION_PART_${_rr}=\"\${DISK}\${_rr_pn}\""
        fi
        _rr_i=$((_rr_i + 1))
    done
    unset _rr_i _rr_pn _rr
    jl "MULTI-FS geometry: nreg=${NREG} carved='${REGION_PARTITIONED}' PART_SYS=${PART_SYS} (outer carve)"
elif [ "${REGION_PARTITIONED:-}" = "" ]; then
    jl "MULTI-FS: no carved regions (all-Btrfs layout; PART_SYS=${PART_SYS})"
else
    # ENCRYPT+regions: outer disk is ESP + single LUKS container (PART_SYS
    # stays p2); the inner GPT on the mapper is carved after luksOpen with
    # region i at mapper-pi and the Btrfs root at mapper-p(NREG+1).
    jl "MULTI-FS geometry: ENCRYPT+regions nreg=${NREG} carved='${REGION_PARTITIONED}' LUKS container=${PART_SYS} (inner GPT on mapper)"
fi
export NREG

# AI (Big Pickle) ADDITION — Beta-v2.9.45 [INNER-PARTSCAN-DMPROBE]: force the
# kernel to REGISTER the on-disk inner GPT of an OPENED LUKS2 mapper via BLKPG.
# partprobe is PRIMARY (it builds libparted dm-linear submaps — the ONLY tool
# able to BLKPG a device-mapper target); partx -a is the FALLBACK ONLY (it
# cannot probe a dm target: "partx: /dev/mapper/<name>: error adding partitions
# 1-N"). MUST be called AFTER every open of a container hosting the inner GPT
# and BEFORE _region_inner_dev re-resolves the region devices — never before
# the close: probing the device while a stale open holds it breaks the
# luksClose cycle (and with it the "disk is now LOCKED" promise). Best-effort:
# returns 0 no matter what, mirroring the boot-time udev RUN helper.
# AI (Big Pickle) FIX — Beta-v2.9.56 [INNER-PARTSCAN-KPARTX]: kpartx is now
# PRIMARY — it reads the on-disk GPT off the opened LUKS2 mapper and creates
# real dm-linear submaps (void-root1/void-root2...) via dmsetup, which is what
# the boot path actually needs. The old partprobe-first order FAILED on the
# first real ENCRYPT+regions hardware: the boot log showed luksopen fine, the
# mapper reading its inner GPT (PTTYPE=gpt in blkid), yet dracut looped
# "Scanning for all btrfs devices" until root=UUID dead — partprobe's BLKPG did
# not produce the child dm devices, and partx -a cannot BLKPG a dm target at
# all ("error adding partitions 1-2" on a dm-crypt device, confirmed live).
# Live fix on that box: `kpartx -av /dev/dm-0` instantly created both submaps.
# Order is now kpartx -a -> partprobe -> partx -a (all best-effort, exit 0).
_region_inner_partscan() {
    local _ps_dev="${1:-$CRYPT_DEV}"
    if command -v kpartx > /dev/null 2>&1; then
        kpartx -a "$_ps_dev" 2> /dev/null || partprobe "$_ps_dev" 2> /dev/null || partx -a "$_ps_dev" 2> /dev/null || true
    elif command -v partprobe > /dev/null 2>&1; then
        partprobe "$_ps_dev" 2> /dev/null || partx -a "$_ps_dev" 2> /dev/null || true
    else
        partx -a "$_ps_dev" 2> /dev/null || true
    fi
    sleep 2
}

# AI (Big Pickle) ADDITION — Beta-v2.9.45 [INNER-PARTSCAN-DMPROBE]: re-resolve
# the region devices + the Btrfs LINUX root off the OPENED mapper, in fixed
# carve order (region i at mapper-pi, Btrfs root at mapper-p(NREG+1)). Only
# valid AFTER _region_inner_partscan has registered the inner GPT — without it
# the pN nodes don't exist yet (fresh carve) or still point at the stale layout
# (resume). Formerly inlined in both the fresh and the resume partscan blocks.
# AI (Big Pickle) FIX — Beta-v2.9.55 [INNER-DEV-NAME]: when partitioning the
# outer disk, the code already checks `[[ "$DISK" =~ (nvme|mmcblk) ]]` to
# decide whether the base name needs a `p` separator before the partition
# number (nvme0n1p1 vs sda1). The inner GPT carved inside a LUKS2 mapper
# had the same problem but no fix: `_region_inner_dev` hardcoded
# `${CRYPT_DEV}p${N}` → `/dev/mapper/void-rootp1` for region p1. On a
# dm-linear device the kernel names children without the `p` separator
# (void-root1, void-root2); the `p` is only for devices whose basename ends
# with a digit. The region format FATALed immediately and the installer
# never got past partitioning on an ENCRYPT+regions+MULTI-FS run.
# Now: check the mapper basename for a trailing digit, add `p` only if needed.
_region_inner_dev() {
    local _sep=""
    case "${CRYPT_DEV##*/}" in *[0-9]) _sep="p";; esac
    _rr_i=1
    for _rr in $REGION_PARTITIONED; do
        eval "REGION_PART_${_rr}=\"\${CRYPT_DEV}${_sep}\${_rr_i}\""
        _rr_i=$((_rr_i + 1))
    done
    unset _rr_i _rr
    BTRFS_DEV="${CRYPT_DEV}${_sep}$((NREG + 1))"
}

# AI (Big Pickle) ADDITION — Beta-v2.9.48 [DISK-BUDGET]: minimum HEADROOM that
# must remain for the LINUX / LUKS-container system partition once the ESP and
# every carved region are accounted for. 1 GiB guarantees a bootable root
# (>= grub-core + kernel + initramfs on GRUB+ENCRYPT where /boot IS the ESP's
# sibling is not the case — this is the plain system volume floor, generous by
# design so a small carve mistake surfaces as a refusal instead of a later
# out-of-space panic).
DISK_BUDGET_MIN_SYS=$((1024 * 1024 * 1024))

# AI (Big Pickle) ADDITION — Beta-v2.9.48 [DISK-BUDGET]: translate a partition
# size as stored in EFI_PART_SIZE / REGION_*_SIZE (either gdisk's single-letter
# suffix — "40G" means binary 40*1024^3 — or an explicit "500GB"/"1TiB" a user
# typed at a prompt) into exact integer bytes on stdout. Empty on parse failure
# so callers can fail open (skip the check) rather than blow up on an exotic
# suffix.
_size_to_bytes() {
    local _sz="${1:-}" _num _unit _mult
    _sz="${_sz//[[:space:]]/}"
    [ -z "$_sz" ] && return 1
    _sz="${_sz#+}"
    if [[ "$_sz" =~ ^([0-9]+)([KMGTP]i?B)$ ]]; then
        _num="${BASH_REMATCH[1]}"
        _unit="${BASH_REMATCH[2]}"
        case "$_unit" in
            KB)  _mult=$((1000)) ;;
            KiB) _mult=$((1024)) ;;
            MB)  _mult=$((1000 ** 2)) ;;
            MiB) _mult=$((1024 ** 2)) ;;
            GB)  _mult=$((1000 ** 3)) ;;
            GiB) _mult=$((1024 ** 3)) ;;
            TB)  _mult=$((1000 ** 4)) ;;
            TiB) _mult=$((1024 ** 4)) ;;
            PB)  _mult=$((1000 ** 5)) ;;
            PiB) _mult=$((1024 ** 5)) ;;
            *)   _mult=1 ;;
        esac
    elif [[ "$_sz" =~ ^([0-9]+)([KMGTPB])$ ]]; then
        # gdisk single-letter suffix — binary multiples (G=2^30), which is how
        # sgdisk interprets "40G" / "+4G" in the carve commands.
        _num="${BASH_REMATCH[1]}"
        _unit="${BASH_REMATCH[2]}"
        case "$_unit" in
            K) _mult=$((1024)) ;;
            M) _mult=$((1024 ** 2)) ;;
            G) _mult=$((1024 ** 3)) ;;
            T) _mult=$((1024 ** 4)) ;;
            P) _mult=$((1024 ** 5)) ;;
            B) _mult=$((1)) ;;
        esac
    elif [[ "$_sz" =~ ^[0-9]+$ ]]; then
        _num="$_sz"
        _mult=1
    else
        return 1
    fi
    printf '%s' "$(( _num * _mult ))"
}

# AI (Big Pickle) ADDITION — Beta-v2.9.48 [DISK-BUDGET]: total bytes consumed by
# every carved region (REGION_*_SIZE). Mirrors the carve loop's eval-based
# access so the budget math uses exactly the same values sgdisk will slice.
_region_sizes_sum() {
    local _sum=0 _rv _rvs _rb
    for _rv in $REGION_PARTITIONED; do
        # AI (Big Pickle) FIX — Beta-v2.9.48 [DISK-BUDGET]: REGION_*_SIZE vars
        # are stored UPPERCASE (REGION_HOME_SIZE) while REGION_PARTITIONED
        # carries lowercase tokens; the eval MUST uppercase-fold the token or
        # it reads the nonexistent REGION_home_SIZE and sums nothing. Same
        # accessor convention as the carve loops (they carry the same fix).
        eval "_rvs=\${REGION_${_rv^^}_SIZE:-}"
        [ -z "$_rvs" ] && continue
        _rb="$(_size_to_bytes "$_rvs")" || continue
        _sum=$(( _sum + _rb ))
    done
    unset _rv _rvs _rb
    printf '%s' "$_sum"
}

# AI (Big Pickle) ADDITION — Beta-v2.9.48 [DISK-BUDGET]: the pre-write fit check.
# Sums the ESP size + every carved region, subtracts from the disk's raw bytes
# (captured at pick-time via lsblk -bdn -o SIZE and persisted for resumed
# runs), and requires the LINUX/LUKS-container remainder to be >= 1 GiB. Saves
# a user from an over-provisioned layout that sgdisk would happily write and
# then refuse to fit — the failure point is BEFORE sgdisk -Z (and, on a
# --dry-run, before the plan even prints). Fails OPEN (returns 0, logs a
# skip) only when the disk size is unreadable; any parse failure of a size we
# DO understand is a hard 1 so an obviously-wrong value can't silently pass.
_disk_budget_check() {
    local _disk_b="${DISK_BYTES:-}" _esp_b _reg_b _need _lin_b
    if [ -z "$_disk_b" ] || ! [[ "$_disk_b" =~ ^[0-9]+$ ]]; then
        echo "WARN [DISK-BUDGET]: disk size for ${DISK:-<unset>} unreadable — skipping pre-write fit check."
        return 0
    fi
    _esp_b="$(_size_to_bytes "${EFI_PART_SIZE:-}")"
    if [ -z "$_esp_b" ]; then
        echo "FATAL [DISK-BUDGET]: could not parse ESP size '${EFI_PART_SIZE:-<unset>}' for the fit check." >&2
        return 1
    fi
    _reg_b="$(_region_sizes_sum)"
    _need=$(( _esp_b + _reg_b + DISK_BUDGET_MIN_SYS ))
    _lin_b=$(( _disk_b - _need ))
    if [ "$_lin_b" -lt 0 ]; then
        echo "${C_RED}!! FATAL [DISK-BUDGET]: layout does NOT fit on ${DISK} (${_disk_b} bytes)." >&2
        echo "     ESP(+${EFI_PART_SIZE}) + carved regions (${_reg_b} bytes) + >=1 GiB system" >&2
        echo "     remainder would need ${_need} bytes total — ${_lin_b} bytes short. Nothing" >&2
        echo "     was written. Reduce the ESP and/or carved-region sizes and re-run.${C_RST}" >&2
        return 1
    fi
    echo "OK [DISK-BUDGET]: ESP(+${EFI_PART_SIZE}) + regions (${_reg_b} B) + LINUX remainder (${_lin_b} B >= 1 GiB) fit inside ${_disk_b} B."
    return 0
}

# AI (Big Pickle) ADDITION — Beta-v2.4.1 [MIRROR]: these defaults are only applied
# when no mirror was chosen in the earlier prompt step (e.g. on a resumed run
# that skipped it); otherwise the user's regional selection is preserved.
REPO_PRIMARY="${REPO_PRIMARY:-https://mirrors.summithq.com/voidlinux/current}"
REPO_BACKUP1="${REPO_BACKUP1:-https://repo-fastly.voidlinux.org/current}"
REPO_BACKUP2="${REPO_BACKUP2:-https://repo-default.voidlinux.org/current}"
# AI (Big Pickle) ADDITION — Beta-v2.9.80 [MIRROR-SKEW-GUARD]: tertiary
# fallbacks beyond the two global backups. The global tiers all ride the same
# upstream repodata, so an index-vs-pool rotation desync (signature 404 — see
# runc 1.5.1_1 -> 1.5.2_1, 2026-10-07) fails all three identically; region
# mirrors rotate on their own schedule and usually stay consistent through it.
# Only touched on the failure path — a healthy install never contacts them.
REPO_EXTRA1="${REPO_EXTRA1:-https://repo-de.voidlinux.org/current}"
REPO_EXTRA2="${REPO_EXTRA2:-https://mirrors.tuna.tsinghua.edu.cn/voidlinux/current}"

LIVECD_SYNC_OK=0
# AI (Big Pickle) ADDITION — Beta-v2.5.4 [YUBIKEY]: when YubiKey hmac-sha1
# unlock was requested, the live medium also needs the ykpers C tools
# (ykpersonalize + ykchalresp) to program the slot and compute the HMAC key.
# They are added to the sync (and to the prereq list below) only in that case.
YK_LIVE_PKGS=""
[ "$YK_MODE" = "hmac-sha1" ] && YK_LIVE_PKGS=" ykpers"
if [ "$DRY_RUN" = "1" ]; then
    # AI (Big Pickle) ADDITION — Beta-v2.5.1 [DRY-RUN]: a plan run must not
    # modify the live environment (xbps-install -Syu would sync/upgrade and
    # install gptfdisk/parted/kpartx/btrfs-progs/openssl into the running
    # medium).
    # Pretend success so the flow reaches the plan printout at the partition
    # boundary; the packages are not actually installed.
    echo "==> [DRY-RUN] Skipping live-CD package sync (would install gptfdisk/parted/kpartx/btrfs-progs/openssl${YK_LIVE_PKGS} into the live env)."
    LIVECD_SYNC_OK=1
else
for REPO_ATTEMPT in "$REPO_PRIMARY" "$REPO_BACKUP1" "$REPO_BACKUP2" "$REPO_EXTRA1" "$REPO_EXTRA2"; do
    echo "==> Attempting live-CD package sync against repository: ${REPO_ATTEMPT}"
    # AI (Big Pickle) ADDITION — Beta-v2.9.59 [LOCAL-CACHE]: point the live sync
    # at the local cache when enabled; the -Syu repodata refresh + any missing
    # package still fall through to the mirror, so a partial cache is safe.
    # shellcheck disable=SC2086  # $YK_LIVE_PKGS is a space-separated package list, split on purpose
    if xbps-install -Syu -R "$REPO_ATTEMPT" ${LOCAL_CA} xbps -y && xbps-install -R "$REPO_ATTEMPT" ${LOCAL_CA} gptfdisk parted kpartx btrfs-progs openssl${YK_LIVE_PKGS} -y; then
        LIVECD_SYNC_OK=1
        echo "==> Live-CD package sync succeeded using: ${REPO_ATTEMPT}"
        break
    fi
    echo "==> Live-CD package sync attempt against ${REPO_ATTEMPT} failed — trying next repository, if any." >&2
done
fi

if [ "$LIVECD_SYNC_OK" -ne 1 ]; then
    echo "FATAL: live-CD package sync failed against all configured repositories (primary + both backups + region extras)." >&2
    exit 1
fi

# AI (Big Pickle) ADDITION — Beta-v2.4.1 [PREREQ], AI (Big Pickle) CORRECTION —
# Beta-v2.5.2 [PREREQ-CURL]: after the live sync the tools this installer's
# OUTER (live-CD) stage invokes directly must actually exist on the medium —
# the sync just installed gptfdisk/btrfs-progs/openssl, so the next step
# (destructive partitioning) should not be reached without them. Tools that
# are only used INSIDE the chroot are deliberately excluded from this list
# (they get installed INTO the target via xbps, not the live env). NOTE the
# deliberate exclusion here: `curl` is NOT an outer-stage tool — every curl
# use is inside the chroot, and the live-CD sync never installs curl into the
# medium, so a Void Live ISO that ships without curl (as some do) made this
# prereq FATAL even though the sync "succeeded". It is removed below.
# AI (Big Pickle) CORRECTION — Beta-v2.9.52 [PREREQ-DRY-RUN]: a `--dry-run`
# plan run never partitions, chroots, or invokes ANY of these outer tools —
# and it SKIPS the live-CD package sync that installs most of them (Beta-v2.5.1
# [DRY-RUN]), so on a minimal medium the check below FATALed "required live-CD
# command not found: 'sgdisk'" and the run died right at the confirmation
# boundary, never reaching the plan printout. The prereq gate exists to keep a
# REAL run from reaching destructive partitioning without its tools; a plan run
# touches nothing, so the gate is skipped and the flow continues to the plan.
if [ "$DRY_RUN" = "1" ]; then
    echo "==> [DRY-RUN] Skipping [PREREQ] outer-tool check (a plan run never partitions; sgdisk/parted/btrfs are not required on the medium)."
else
for _prereq in sgdisk mkfs.fat mkfs.btrfs btrfs parted openssl mount umount \
               chroot lsblk blkid xbps-install${YK_LIVE_PKGS:+ ykpersonalize ykchalresp}; do
    if ! command -v "$_prereq" >/dev/null 2>&1; then
        echo "FATAL: required live-CD command not found: '${_prereq}'." >&2
        echo "       The live-CD package sync reported success, but this tool is missing." >&2
        exit 1
    fi
done
unset _prereq
fi

# AI (Big Pickle) ADDITION — Beta-v2.5.4 [YUBIKEY]: YubiKey hmac-sha1
# enrollment. Only reached for a fresh (non-resumed) run when YK_MODE=hmac-sha1.
# Programming a slot is DESTRUCTIVE, so it happens here (after the live-CD sync
# installed ykpers) with an explicit final confirmation naming the slot. The
# slot secret is generated on the fly by ykpersonalize; we then bind
# HMAC-SHA1(slot_secret, CHALLENGE) as a NEW LUKS key slot. The CHALLENGE
# (40-hex, from 20 random bytes) is public — it is persisted so boot-time
# keyscript/limine-env can re-issue it — but the HMAC response (YK_KEY) is
# the actual LUKS credential and is kept ONLY in this process's memory: it is
# used to luksAddKey the slot during partitioning and then unset. It is
# NEVER written to the state file, limine-env, chroot_env, or install-config.
if [ "$RESUME" != "1" ] && [ "$YK_MODE" = "hmac-sha1" ]; then
    echo ""
    echo "${C_BOLD}${C_BLU}YubiKey hmac-sha1 enrollment${C_RST}"
    echo ""
    echo "  The installer is about to PROGRAM OTP slot ${YK_SLOT} on the attached"
    echo "  YubiKey with a freshly generated random secret. This OVERWRITES whatever"
    echo "  currently lives in that slot (e.g. any OTP/static-password config)."
    echo "  The unlocked volume will expect HMAC-SHA1(slot_secret, challenge) as a"
    echo "  LUKS key at every boot."
    echo ""
    ask "Program slot ${YK_SLOT} now — confirm the key is plugged in? [y/N]: "
    read -r YK_ENROLL_CONFIRM
    if ! { [ "$YK_ENROLL_CONFIRM" = "y" ] || [ "$YK_ENROLL_CONFIRM" = "Y" ]; }; then
        echo ">>> YubiKey enrollment aborted; installing without YubiKey unlock (passphrase only)." >&2
        YK_MODE="off"
        YK_FALLBACK="yes"
        YK_SLOT="1"
        YK_TOUCH="no"
        YK_LIVE_PKGS=""
    else
        YK_TOUCH_OPT=""
        [ "$YK_TOUCH" = "yes" ] && YK_TOUCH_OPT=" -ochal-btn-trig"
        # shellcheck disable=SC2086  # deliberate split of space-prefixed $YK_TOUCH_OPT into a flag
        if ! ykpersonalize "-${YK_SLOT}" -ochal-resp -ochal-hmac -ohmac-lt64 -oserial-api-visible${YK_TOUCH_OPT} -y 2>&1; then
            echo "FATAL: ykpersonalize failed to program slot ${YK_SLOT}. Check the YubiKey is plugged in (no hub pass-through) and not read-only." >&2
            exit 1
        fi
        YK_CHALLENGE=$(head -c 20 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 40)
        [ -z "$YK_CHALLENGE" ] && { echo "FATAL: could not generate the 40-hex YubiKey challenge." >&2; exit 1; }
        YK_KEY=$(ykchalresp "-${YK_SLOT}" "$YK_CHALLENGE" 2>&1)
        [ -z "$YK_KEY" ] && { echo "FATAL: ykchalresp failed to compute the HMAC response. Enrollment incomplete." >&2; exit 1; }
        echo "==> Slot ${YK_SLOT} programmed and LUKS key envelope computed (key held in memory only)."
        unset YK_TOUCH_OPT YK_ENROLL_CONFIRM
    fi
fi

# AI (Big Pickle) CHANGE — Beta-v2.4.0 [RESUME]: Password hashing is skipped on a
# resumed run — the hashes are already restored from the state file, and the
# live passwords are intentionally never re-entered or re-derived.
if [ "$RESUME" != "1" ]; then
    if [ "$ACCOUNT_MODEL" != "ubuntu" ]; then
        ROOT_PASS_HASH=$(openssl passwd -6 -stdin <<< "$ROOT_PASSWORD")
    else
        ROOT_PASS_HASH=""
    fi
    TARGET_PASS_HASH=$(openssl passwd -6 -stdin <<< "$TARGET_USER_PASSWORD")
    ROOT_PASSWORD=""
    TARGET_USER_PASSWORD=""
    unset ROOT_PASSWORD TARGET_USER_PASSWORD
fi

# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.4.0 [RESUME]: PERSIST CONFIGURATION STATE.
# Every answer required to re-run the (non-idempotent) Stage 2 is written to
# the state file so a resumed run can skip re-prompting. Only plaintext
# password *hashes* are persisted — never the passwords themselves. Written
# here (after hashing, before partitioning) so even a crash during
# partitioning still leaves a fully resumable record.
# =============================================================================
{
    printf 'export RESUME_TYPE="coarse"\n'
    for _sv in ACCOUNT_MODEL ROOT_PASS_HASH TARGET_PASS_HASH TARGET_USER TARGET_HOSTNAME \
               TARGET_DOMAIN TARGET_FQDN NET_INTERFACE_MATCH BOOTLOADER \
               EFI_PART_SIZE KERNEL_MODE DESKTOP_ENV DISPLAY_MANAGER \
               HAS_GRAPHICAL INSTALL_XORG INSTALL_AUDIO \
               USER_SHELL USER_SHELL_PKG \
               LIGHTDM_GREETER LIGHTDM_GREETER_PKG LIGHTDM_GREETER_SESSION \
               LIMINE_WALLPAPER LIMINE_WALLPAPER_STYLE \
               SESSION_STACK ENABLE_SNAPSHOT_AUDIO \
               LOCALE LOCALE_CODESET TIMEZONE SWAP_BACKEND SWAPFILE_MODE ENABLE_HIBERNATION SWAPFILE_SIZE \
               INSTALL_KERNEL_MAINLINE INSTALL_KERNEL_LTS KERNEL_PKGS \
DEVICE_PROFILE PROFILE_TLP PROFILE_BT PROFILE_PRELOAD \
                INSTALL_SSH_SERVER SSH_PORT SSH_PASSWORD_AUTH SSH_ROOT_LOGIN \
                IMPORT_SSH_KEY GENERATE_SSH_KEY EXPORT_SSH_KEY \
                INSTALL_NVIDIA GPU_FAMILIES HAS_NVIDIA_GPU HAS_AMD_GPU HAS_INTEL_GPU WIFI_HW \
                ENCRYPT \
               CRYPT_NAME \
               YK_MODE YK_FALLBACK YK_SLOT YK_CHALLENGE YK_TOUCH \
               REGION_HOME_FS REGION_VAR_FS REGION_CACHE_FS REGION_SRV_FS REGION_OPT_FS REGION_GAMES \
               REGION_HOME_SIZE REGION_VAR_SIZE REGION_CACHE_SIZE REGION_SRV_SIZE REGION_OPT_SIZE REGION_GAMES_SIZE \
               REGION_PARTITIONED \
               REPO_PRIMARY REPO_BACKUP1 REPO_BACKUP2 REPO_EXTRA1 REPO_EXTRA2 \
               LOCAL_CACHE_REUSE LOCAL_CACHE_DIR \
DISTROBOX_TRACK DISTROBOX_DEFAULT_ENGINE INSTALL_OCTOXBPS \
INSTALL_FLATPAK INSTALL_COSMIC_STORE INSTALL_BREW INSTALL_FIREFOX INSTALL_CHROMIUM \
                 INSTALL_VIVALDI INSTALL_FALKON INSTALL_BRAVE \
                 INSTALL_THUNDERBIRD INSTALL_STEAM INSTALL_VIRTUALBOX \
                 INSTALL_LUTRIS INSTALL_HEROIC INSTALL_BOTTLES INSTALL_WINE INSTALL_GAMEMODE INSTALL_ANY_GAME \
                SETUP_WEB_BROWSERS SETUP_CONTAINERS \
                 SUBVOL_ISOLATE_INSTALLED SUBVOL_PRECREATE \
                INSTALL_PODMAN INSTALL_PODMAN_ROOTLESS INSTALL_PODMAN_ROOTFUL \
               INSTALL_PODMAN INSTALL_PODMAN_ROOTLESS INSTALL_PODMAN_ROOTFUL \
               INSTALL_DOCKER DOCKER_GROUP_ADD INSTALL_DISTROBOX INSTALL_VIRT \
               PROVISION_FIREFOX_SUBVOL PROVISION_CHROMIUM_SUBVOL \
               PROVISION_VIVALDI_SUBVOL PROVISION_FALKON_SUBVOL \
               PROVISION_BRAVE_SUBVOL \
                PROVISION_THUNDERBIRD_SUBVOL PROVISION_GAME_SUBVOL \
                PROVISION_VIRTUALBOX_SUBVOL PROVISION_LINUXBREW_SUBVOL \
                 PROVISION_FLATPAK_SUBVOL PROVISION_DOCKER_SUBVOL \
                 PROVISION_PODMAN_SUBVOL PROVISION_PODMAN_ROOTLESS_SUBVOL \
                 PROVISION_VIRT_SUBVOL \
                DISK PART_EFI PART_SYS DISK_BYTES; do
        printf 'export %s=%q\n' "$_sv" "${!_sv}"
    done
} > "$STATE_FILE"
chmod 600 "$STATE_FILE"
echo "==> Install state saved to ${STATE_FILE} (resumable later with '$0 -r')."
STAGE_CONTEXT="STAGE1:partition"
jl "Config persisted to $STATE_FILE (DISK=${DISK}, bootloader=${BOOTLOADER})"
unset _sv

# AI (Big Pickle) ADDITION — Beta-v2.5.1 [DRY-RUN]: if --dry-run/-d/-n was
# given, everything above has run interactively (all prompts, no disk touched,
# no live-env package sync, no chroot). Print the complete as-planned summary
# of what a real run WOULD do — destination disk/partitions, bootloader,
# desktop/DM, session stack, kernel mode, wallpaper resolution — then stop at
# the destructive partition boundary with exit 0. Nothing on disk is modified.
if [ "$DRY_RUN" = "1" ]; then
    # AI (Big Pickle) ADDITION — Beta-v2.9.48 [DISK-BUDGET]: a dry-run is the
    # cheapest place to refuse. The pre-write fit check runs HERE (before the
    # plan prints) and, with no disk touched, exits 1 so an over-provisioned
    # layout can never even look launchable. On success we print the remaining
    # LINUX system-partition size in the plan.
    if ! _disk_budget_check; then
        echo "  Dry-run aborted by the pre-write fit check (above)." >&2
        exit 1
    fi
    echo ""
    echo "${C_MAG}========================= DRY-RUN PLAN =========================${C_RST}"
    echo "  Mode                  : --dry-run — no disk changes performed."
    echo "  Target disk           : ${DISK:-<not selected>} (${DISK_BYTES:-<size unreadable>} bytes)"
    echo "  Destructive steps     : sgdisk -Z + -og, ESP(+${EFI_PART_SIZE}) + LINUX parts,"
    echo "                          mkfs.fat -F32 EFI, mkfs.btrfs -f, subvolume layout."
    echo "  Headroom              : >= 1 GiB LINUX system remainder required (DISK-BUDGET pass)"
    echo "  Bootloader            : ${BOOTLOADER:-<unset>}"
    if [ "$BOOTLOADER" = "limine" ]; then
        echo "  Kernel access         : ${KERNEL_MODE:-<unset>} (Limine)"
        echo "  Wallpaper             : ${LIMINE_WALLPAPER:-none}${LIMINE_WALLPAPER_STYLE:+ (style=${LIMINE_WALLPAPER_STYLE})}"
    fi
    # AI (Big Pickle) FIX — Beta-v2.9.53 [HEADLESS-PLAN-LABEL]: the plan used to
    # print "headless=$HAS_GRAPHICAL", i.e. "(headless=yes)" for a GRAPHICAL
    # MATE/LightDM install — the label's meaning was inverted. Now prints
    # "(graphical)" or "(headless)" honestly.
    if [ "$HAS_GRAPHICAL" = "yes" ]; then
        echo "  Desktop / DM          : ${DESKTOP_ENV:-<unset>} / ${DISPLAY_MANAGER:-<unset>} (graphical)"
    else
        echo "  Desktop / DM          : ${DESKTOP_ENV:-<unset>} / ${DISPLAY_MANAGER:-<unset>} (headless)"
    fi
    echo "  Session stack         : ${SESSION_STACK:-<unset>}"
    echo "  Login shell           : ${USER_SHELL:-<unset>}"
    echo "  User / full name      : ${TARGET_USER:-<unset>}${TARGET_FULL_NAME:+ (${TARGET_FULL_NAME})}"
    echo "  Locale / Timezone     : ${LOCALE:-<unset>} / ${TIMEZONE:-<unset>}"
    echo "  Repo (primary)        : ${REPO_PRIMARY:-<unset>}"
    echo "  Swap / Hibernation    : ${SWAP_BACKEND:-<unset>} / ${ENABLE_HIBERNATION:-<unset>}"
    echo "  Encryption            : ${ENCRYPT:-no}${ENCRYPT:+$([ "$ENCRYPT" = "yes" ] && { [ "$YK_MODE" = "hmac-sha1" ] && echo " (LUKS2 full-disk + YubiKey hmac-sha1, fallback=$YK_FALLBACK)" || echo " (LUKS2 full-disk, passphrase at boot)"; } || true)}"
    echo "  Data regions (MULTI-FS): carved=['${REGION_PARTITIONED:-}'] home=${REGION_HOME_FS:-btrfs} var=${REGION_VAR_FS:-btrfs} cache=${REGION_CACHE_FS:-btrfs} srv=${REGION_SRV_FS:-btrfs} opt=${REGION_OPT_FS:-btrfs} games=${REGION_GAMES:-none}"
    echo "  Accounts model        : ${ACCOUNT_MODEL:-<unset>}"
    echo "  App channels          : Flatpak=${INSTALL_FLATPAK:-no} cosmic-store=${INSTALL_COSMIC_STORE:-no} Homebrew=${INSTALL_BREW:-no}"
    echo "  Game launchers        : steam=${INSTALL_STEAM:-no} lutris=${INSTALL_LUTRIS:-no} heroic=${INSTALL_HEROIC:-no} bottles=${INSTALL_BOTTLES:-no} wine=${INSTALL_WINE:-no} gamemode=${INSTALL_GAMEMODE:-no}"
    echo "  Hardware              : GPU=${GPU_FAMILIES:-<none detected>} wireless=${WIFI_HW:-unknown}"
    echo "  NVIDIA driver         : ${INSTALL_NVIDIA:-auto}"
    echo "=============================================================="
    echo "  Nothing was written to disk. Re-run WITHOUT --dry-run to install for real."
    echo ""
    # A dry-run persists a state file earlier (so the plan data was collected);
    # remove it so a later real run isn't offered a pointless "resume".
    rm -f "$STATE_FILE" 2>/dev/null || true
    # AI (Big Pickle) FIX — Beta-v2.9.54 [SSH-KEYGEN-STALE]: the plan run may
    # have generated an SSH keypair ([[SSH-KEYS]] prompts run before the plan);
    # this exit path is neither the failure cleanup nor the post-chroot shred,
    # so without this the key material would persist on a /tmp-that-persists
    # medium and silently desync the next run's answer stream at ssh-keygen's
    # "Overwrite (y/n)?" prompt. Shred here exactly like those two paths do.
    if [ -d /tmp/ssh-keygen ] || [ -d /tmp/ssh-import ]; then
        shred -u /tmp/ssh-keygen/* /tmp/ssh-import/* 2>/dev/null || true
        rm -rf /tmp/ssh-keygen /tmp/ssh-import 2>/dev/null || true
        echo "  SSH key stage shredded from live environment (dry-run exit)."
    fi
    exit 0
fi

# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.9.40 [PKG-PREFLIGHT]: Stage-1 package-name
# gate that closed crash #005. The old Stage-2 chroot attempted to install
# every selected package name directly (install_pkgs ...); when a name did not
# exist in the official pool (the historical `install_pkgs heroic` — Heroic is
# Flatpak-only, [GAME-FLATPAK-GATE]), xbps-install died mid-transaction AFTER
# the disk had already been partitioned/written, leaving a doomed install that
# still had to unwind. This gate resolves EVERY package name the Stage-2 chroot
# can possibly request against the LIVE union pool NOW — before sgdisk -Z — and
# aborts pre-write if any name is unresolvable. Candidate list (PKG_PREFLIGHT)
# is a deliberate SUPERSET of every literal `install_pkgs` argument in the
# chroot plus the raw base-bootstrap literals; Debug/check-pkg-preflight.sh is
# the committed drift-guard that fails when a literal is added without being
# covered here. Repository/network hiccups DEGRADE to a WARN + skip (never a
# false FATAL): a live -Sy refresh failure says nothing about whether a name
# exists, so it must not abort the install. COSMIC third-party packages
# (bluesloth.github.io / install_cosmic) are deliberately NOT probed here — they
# resolve from the third-party repo, not the official union pool. Placed
# AFTER the --dry-run exit block and BEFORE the destructive partition boundary,
# per invariant #17: the block must never move after sgdisk.
# =============================================================================
# shellcheck disable=SC2034  # PKG_PREFLIGHT is consumed by the gate loop below
# and by the drift-guard Debug/check-pkg-preflight.sh — the variable itself is
# never referenced via ${...} expansion.
PKG_PREFLIGHT="
accountsservice
acpid
alsa-pipewire
alsa-plugins-pulseaudio-32bit
alsa-ucm-conf
alsa-utils
ark
base-system
bash
bash-completion
binutils
blueman
bluez
bridge-utils
btrfs-progs
catatonit
chromium
chrony
cinnamon-all
cronie
crun
cryptsetup
curl
dbus
docker
dracut
efibootmgr
elogind
falkon
fastfetch
FeatherPad
file
firefox
fish-shell
flatpak
fontconfig-32bit
freetype-32bit
fuse
fuse3
fuse-overlayfs
gamemode
gdm
gedit
git
glibc-locales
gnome
gnome-backgrounds
gnome-terminal
go
greetd
grub-btrfs
grub-btrfs-runit
grub-x86_64-efi
udiskie
udisks2
gvfs
inotify-tools
intel-ucode
iptables
kde-baseapps
kde-plasma
kio-admin
kpartx
libdrm-32bit
libgamemode-32bit
libgcc-32bit
libglvnd-32bit
libjack-pipewire
libpulseaudio-32bit
libspa-bluetooth
libstdc++-32bit
libvirt
libX11-32bit
libxcb-32bit
libXcursor-32bit
libXext-32bit
libXfixes-32bit
libXi-32bit
libXinerama-32bit
libXrandr-32bit
libXrender-32bit
libXss-32bit
libXxf86vm-32bit
lightdm
lightdm-gtk-greeter
lightdm-slick-greeter
limine
linux
linux-firmware
linux-firmware-amd
linux-firmware-broadcom
linux-headers
linux-lts
linux-lts-headers
linux-mainline
linux-mainline-headers
lutris
lxqt
lxqt-policykit
make
mesa-dri-32bit
mesa-vulkan-intel
mesa-vulkan-intel-32bit
mesa-vulkan-nouveau
mesa-vulkan-nouveau-32bit
mesa-vulkan-radeon
mesa-vulkan-radeon-32bit
mate
mate-media
mate-terminal
mksh
nano
NetworkManager
network-manager-applet
nftables
nvidia
octoxbps
openssh
parted
pipewire
plasma-pa
pluma
podman
polkit
polkit-gnome
power-profiles-daemon
preload
procps-ng
qemu
rsync
runit-nftables
sddm
seatd
slirp4netns
smartmontools
snapper
sof-firmware
steam
sudo
thunderbird
tlp
tlp-rdw
turnstile
vim
virt-manager
virtualbox-ose
virtualbox-ose-dkms
vivaldi
void-repo-multilib
void-repo-multilib-nonfree
void-repo-nonfree
wayland
wayland-protocols
wget
wine
wireplumber
xbps
xdg-user-dirs
xdg-utils
xfce4
xfce4-pulseaudio-plugin
xorg
xtools
ykpers
zramen
zsh
"
echo ""
echo "Stage-1 package preflight [PKG-PREFLIGHT]: verifying package names against the live union pool..."
jl "PKG-PREFLIGHT: begin — checking $(echo "$PKG_PREFLIGHT" | grep -c .) candidate packages"

# 1. Ensure the union pool includes nonfree + multilib repos (needed by e.g.
#    nvidia, virtualbox-ose, linux-firmware-broadcom, libgamemode-32bit).
#    Best-effort: if a repo is already present or missing, that is harmless.
xbps-install -y void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree >/dev/null 2>&1 || true

# 2. Refresh the live package index so queries reflect the current repo state.
if ! xbps-install -Sy >/dev/null 2>&1; then
    echo "  WARN: live -Sy refresh failed (network/repo hiccup); preflight DEGRADED — skipping package-name gate." >&2
    jl "PKG-PREFLIGHT: DEGRADED — xbps-install -Sy failed (network/repo hiccup); gate skipped"
else
    # 3. Sanity probe: base-system MUST resolve. If it doesn't after a
    #    successful -Sy, something is seriously wrong with the repo config;
    #    skip the gate with a WARN to avoid a false FATAL.
    if ! xbps-query -Rs "^base-system$" >/dev/null 2>&1; then
        echo "  WARN: base-system is not resolvable after -Sy — repo config issue; preflight DEGRADED — skipping." >&2
        jl "PKG-PREFLIGHT: DEGRADED — base-system not in pool; gate skipped"
    else
        # 4. Check every candidate against the union pool. xbps-query -Rs with
        #    an anchored regex does an exact-name search in the cached remote
        #    index (populated by the -Sy above).
        _pre_missing=""
        _pre_total=0
        # shellcheck disable=SC2086  # $PKG_PREFLIGHT is deliberately word-split
        for _pre_pkg in $PKG_PREFLIGHT; do
            _pre_total=$((_pre_total + 1))
            if ! xbps-query -Rs "^${_pre_pkg}$" >/dev/null 2>&1; then
                _pre_missing="${_pre_missing:+${_pre_missing} }${_pre_pkg}"
            fi
        done
        if [ -n "$_pre_missing" ]; then
            echo "" >&2
            echo "${C_RED}==============================================================================${C_RST}" >&2
            echo "${C_RED}  FATAL: [PKG-PREFLIGHT] — the following packages are NOT resolvable in the${C_RST}" >&2
            echo "${C_RED}  official Void Linux union pool:${C_RST}" >&2
            echo "" >&2
            for _pre_pkg in $_pre_missing; do
                echo "    - ${_pre_pkg}" >&2
            done
            echo "" >&2
            echo "  This is crash #005 (a doomed install would write the disk, then die" >&2
            echo "  in the chroot when xbps-install fails). The disk is still untouched." >&2
            echo "  Add the package(s) to Void's official repos or remove the option." >&2
            echo "${C_RED}==============================================================================${C_RST}" >&2
            echo "" >&2
            jl "PKG-PREFLIGHT: ABORT — unresolvable packages: ${_pre_missing}"
            # Beta-v2.9.39 [CRASH-USB-LOG-FATAL-EXIT]: this explicit exit 1
            # does NOT trip the ERR trap but the EXIT trap now saves the
            # journal to USB, so the post-mortem is never lost.
            exit 1
        fi
        echo "  ALL ${_pre_total} preflight packages resolve in the live union pool."
        jl "PKG-PREFLIGHT: ALL COVERED (${_pre_total} packages)"
    fi
fi

# AI (Big Pickle) ADDITION — Beta-v2.9.80 [MIRROR-SKEW-PREFLIGHT]: per-mirror
# index-vs-pool consistency probe. PKG-PREFLIGHT above proves the NAMES exist
# in the union pool; it cannot see that a mirror's repodata still resolves an
# OLD version whose files the pool just rotated away (runc 1.5.1_1 -> 1.5.2_1,
# 2026-10-07: index listed 1.5.1_1 while the pool only carried 1.5.2_1 -> xbps
# 404'd the .sig mid-transaction). Probe the enabled container/bootstrap
# closure per mirror with a FRESH memory-sync resolution (-M — never the stale
# on-disk repodata; live-verified disk queries return the old version even
# after -Sy), then HTTP-HEAD the resolved package's .sig file. A 404 while the
# name resolves = torn; the first consistent mirror is promoted to REPO_PRIMARY
# so Stage 2's install_pkgs starts on a healthy mirror. If every mirror is torn
# the install CONTINUES with a WARN — never a pre-write FATAL for a transient
# (the mirror heals; install_pkgs' bounded retry rides it out). curl is
# deliberately optional (Void Live ISOs may lack it, see [PREREQ-CURL]):
# absent curl degrades the probe to a skip, exactly like the -Sy degradation.
if command -v curl >/dev/null 2>&1; then
    _pre_probe="base-system"
    [ "$INSTALL_PODMAN" = "true" ] && _pre_probe="$_pre_probe runc podman"
    [ "$INSTALL_DOCKER" = "true" ] && _pre_probe="$_pre_probe docker"
    _pre_pick=""
    for _pre_m in "$REPO_PRIMARY" "$REPO_BACKUP1" "$REPO_BACKUP2" "$REPO_EXTRA1" "$REPO_EXTRA2"; do
        case " $_pre_pick " in *" $_pre_m "*) continue ;; esac   # dedupe repeats
        _pre_torn=""
        for _pre_p in $_pre_probe; do
            _pre_v=$(xbps-query -M -R --repository="$_pre_m" --property=pkgver "$_pre_p" 2>/dev/null | tail -1)
            if [ -z "$_pre_v" ]; then
                _pre_torn="${_pre_torn}${_pre_torn:+ }unresolvable:$_pre_p"
                continue
            fi
            _pre_code=$(curl -sIL -o /dev/null -w '%{http_code}' --max-time 15 "$_pre_m/${_pre_v}.x86_64.xbps.sig")
            if [ "$_pre_code" != "200" ]; then
                _pre_torn="${_pre_torn}${_pre_torn:+ }${_pre_p}(sig ${_pre_code})"
            fi
        done
        if [ -z "$_pre_torn" ]; then
            _pre_pick="$_pre_m"
            break
        fi
        echo "  WARN [MIRROR-SKEW-PREFLIGHT]: mirror ${_pre_m} is mid-rotation for: ${_pre_torn} — skipping it." >&2
        jl "MIRROR-SKEW-PREFLIGHT: torn mirror: ${_pre_m} (${_pre_torn})"
    done
    if [ -n "$_pre_pick" ] && [ "$_pre_pick" != "$REPO_PRIMARY" ]; then
        echo "==> [MIRROR-SKEW-PREFLIGHT] promoting consistent mirror to REPO_PRIMARY: ${_pre_pick}"
        REPO_PRIMARY="$_pre_pick"
        jl "MIRROR-SKEW-PREFLIGHT: promoted REPO_PRIMARY -> ${_pre_pick}"
    elif [ -z "$_pre_pick" ]; then
        echo "  WARN [MIRROR-SKEW-PREFLIGHT]: every configured mirror is torn for probe set '${_pre_probe}' — continuing; the bounded skew-retry will ride out the rotation inside install_pkgs." >&2
        jl "MIRROR-SKEW-PREFLIGHT: all mirrors torn (probe: ${_pre_probe}); continuing"
    fi
    unset _pre_probe _pre_pick _pre_m _pre_torn _pre_p _pre_v _pre_code
fi

# AI (Big Pickle) CHANGE — Beta-v2.4.0 [RESUME]: The destructive partitioning and
# filesystem creation below run ONLY on a fresh install. A resumed run reuses
# the existing partition table and filesystems (the installer's own, from the
# interrupted run) — the target's *contents* are reset separately further on.
#
# AI (Big Pickle) ADDITION — Beta-v2.5.5 [ENCRYPT]: when encryption is
# enabled, partition 2 ($PART_SYS) holds a LUKS2 container. Everything the
# installer acts on is the opened MAPPER device ($BTRFS_DEV), never the raw
# container. On a fresh install the container is created (luksFormat) then
# opened (luksOpen). On a resumed run the container already exists but the
# mapper is closed (it was never opened / was torn down by the crash), so it
# is re-opened with a fresh passphrase prompt — the passphrase was never
# persisted, so the user re-types it. In both cases $BTRFS_DEV points at
# /dev/mapper/void-root when encrypted, else at the raw $PART_SYS — and every
# mkfs/mount below uses $BTRFS_DEV, so the encrypted and unencrypted paths
# are structurally identical from here on.
BTRFS_DEV="$PART_SYS"
# CRYPT_NAME is the decrypted mapper name (default void-root). It is set from
# the prompt above when ENCRYPT=yes, but must be defined for every path (even
# ENCRYPT=no, where it is unused) so derived strings never reference an empty var.
CRYPT_NAME="${CRYPT_NAME:-void-root}"
CRYPT_DEV="/dev/mapper/${CRYPT_NAME}"

if [ "$RESUME" != "1" ]; then
    # AI (Big Pickle) ADDITION — Beta-v2.9.48 [DISK-BUDGET]: the last gate
    # before anything touches the disk. The ESP/region budget is checked
    # against the disk's real byte size (fails open only if unreadable); an
    # over-provisioned layout aborts cleanly here — nothing was written.
    _disk_budget_check || exit 1
    # Clear disk maps and slice target partitions
    sgdisk -Z "$DISK" && sgdisk -og "$DISK"
    sgdisk -n "1::+${EFI_PART_SIZE}" -t 1:ef00 -c 1:'ESP' "$DISK"
    if [ -n "${REGION_PARTITIONED:-}" ] && [ "$ENCRYPT" != "yes" ]; then
        # AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS]: outer carve.
        # Regions are sliced 2..1+NREG in the fixed order home,var,cache,srv,
        # opt,games, each sized from its REGION_<NAME>_SIZE; LINUX goes LAST.
        _rr_pn=2
        for _rr in $REGION_PARTITIONED; do
            # AI (Big Pickle) FIX — Beta-v2.9.48 [DISK-BUDGET]: REGION_*_SIZE
            # vars are stored UPPERCASE but REGION_PARTITIONED tokens are
            # lowercase; without the ^^ fold this eval reads the nonexistent
            # REGION_home_SIZE and a carved layout FATALs "size is unset" on
            # every real MULTI-FS install. The budget check in 2.9.48 sums the
            # SAME folded accessor, so the fit math and the carve now agree.
            eval "_rr_n=\${REGION_${_rr^^}_SIZE:-}"
            if [ -z "$_rr_n" ]; then
                echo "FATAL: region '$_rr' carved but REGION_${_rr^^}_SIZE is unset." >&2
                exit 1
            fi
            # Sizes like "40G" need the '+' prefix stripped to be literal:
            # sgdisk's "+40G" is relative-to-start, but a bare "40G" (no '+')
            # from a fixed endpoint also means up-to that size. Force the
            # explicit absolute interpretation exactly like the ESP carve.
            _rr_posn="${_rr_n#+}"
            sgdisk -n "${_rr_pn}::+${_rr_posn}" -t "${_rr_pn}":8300 -c "${_rr_pn}":"LINUX-${_rr}" "$DISK"
            _rr_pn=$((_rr_pn + 1))
        done
        sgdisk -n "${_rr_pn}::" -t "${_rr_pn}":8300 -c "${_rr_pn}":'LINUX' "$DISK"
        unset _rr_pn _rr_posn _rr _rr_n
    else
        sgdisk -n 2:: -t 2:8300 -c 2:'LINUX' "$DISK"
    fi
    # AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS-RUNLOG]: line the journal
    # with the carve summary so a crash (or the installer-run.log archive below)
    # shows exactly what partition geometry was written. REGION_PARTITIONED is
    # space-separated by construction, so the fs summary below is word-split
    # deliberately (SC2086 ignored — same pattern as the KERNEL_ENTRIES walk).
    jl "MULTI-FS-RUNLOG: outer carve on ${DISK} complete (regions: ${REGION_PARTITIONED:-none})"
    partprobe "$DISK"
    sleep 2

    if [ "$ENCRYPT" = "yes" ]; then
        # AI (Big Pickle) FIX — Beta-v2.9.6 [LUKS-UNLOCK-LEFT-OPEN]: a crashed
        # earlier run can still hold the mapper open (pre-v2.9.6 unwinds never
        # closed it). Close a leftover mapper BEFORE wiping/formatting so
        # luksFormat does not refuse a busy device on a plain re-run.
        if [ -e "$CRYPT_DEV" ]; then
            echo "==> Closing leftover open mapper ${CRYPT_DEV} from an interrupted run"
            cryptsetup luksClose "$CRYPT_NAME" 2>/dev/null || true
        fi
        # Fresh: create the LUKS2 container from the typed passphrase. Fed
        # via stdin so it never appears on the command line or in the
        # process list. The ESP is formatted after this.
        echo ""
        echo "==> Formatting partition 2 as a LUKS2 container (cryptsetup)"
        # AI (Big Pickle) FIX — Beta-v2.7.0 [ENCRYPT-NEWLINE]: feed the passphrase
        # with `printf '%s'` (NO trailing newline) instead of a `<<<` here-string
        # or `echo`. A here-string/echo appends a newline byte, so the LUKS keyslot
        # stored passphrase+\n. An interactive `cryptsetup open` prompt (terminal
        # canonical mode) reads the typed line WITHOUT that newline, so boot and a
        # manual recovery unlock both produced N-1 bytes and failed with "No key
        # available with this passphrase". The installer's own beta21 verify passed
        # only because it reused the same `<<<` 11-byte path — it never tested the
        # 10-byte interactive path. Using printf '%s' makes format==open==interactive
        # byte-identical, which is what a human typing at a prompt produces.
        printf '%s' "$ENCRYPT_PASSPHRASE" | cryptsetup luksFormat --type luks2 -q --key-file=- "$PART_SYS"
        echo "==> Opening LUKS2 container ${PART_SYS} -> ${CRYPT_DEV}"
        printf '%s' "$ENCRYPT_PASSPHRASE" | cryptsetup luksOpen --key-file=- "$PART_SYS" "$CRYPT_NAME"
        # AI (Big Pickle) ADDITION — Beta-v2.6.9 [ENCRYPT-VERIFY]: prove the
        # typed passphrase actually unlocks the volume BEFORE any reboot. The
        # passphrase is the ONLY way into a LUKS2 container (no key file), and
        # a mismatch here has historically caused a boot that prompts and then
        # refuses — the user is locked out with no install-side error. Closing
        # and re-opening with the SAME byte-identical passphrase (printf '%s', no
        # trailing newline — the exact bytes a human typing at the boot prompt
        # produces) verifies the keyslot round-trips; any failure means luksFormat wrote
        # a key that does not match what will be typed at boot, so abort NOW
        # with a loud, actionable error instead of shipping a dead disk. Note:
        # this check runs BEFORE the YubiKey slot binding below, so the typed
        # slot-0 key still exists even for possession-only installs — it is
        # always a valid proof of the typed passphrase at this point.
        echo "==> Verifying the passphrase can re-unlock ${PART_SYS} (close + re-open)..."
        cryptsetup luksClose "$CRYPT_NAME"
        if ! printf '%s' "$ENCRYPT_PASSPHRASE" | cryptsetup luksOpen --key-file=- "$PART_SYS" "$CRYPT_NAME"; then
            echo "${C_RED}!! FATAL: the passphrase that created the container does not PARSE as"
            echo "     the passphrase needed to unlock it. The disk would be UNBOOTABLE.${C_RST}" >&2
            echo "     This is a keymap/typing mismatch between the two entries (or a cryptsetup" >&2
            echo "     keyfile/stdin quirk). Power-cycle, re-run with a simpler passphrase, and" >&2
            echo "     if it recurs, capture this screen for the installer maintainers." >&2
            exit 1
        fi
        echo "   OK: passphrase verified (luksFormat key == unlock key)."
        BTRFS_DEV="$CRYPT_DEV"
        # AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS] + ENCRYPT: the
        # carved regions become an INNER GPT inside the single LUKS2 container.
        # The ESC p1 stays on the outer disk; this mapper, once opened, is the
        # inner "disk": region partitions 1..NREG in fixed order, then the
        # Btrfs LINUX root LAST (mapper-p(NREG+1), sized to the remainder).
        # Partscan is forced by closing + re-opening the mapper so the kernel
        # re-reads the freshly-written inner GPT (the [MULTI-FS-PARTSCAN-FORCE]
        # fix — Beta-v2.9.39 — was the follow-up that made this reliable).
        if [ -n "${REGION_PARTITIONED:-}" ]; then
            echo "==> Carving inner GPT inside ${BTRFS_DEV} (MULTI-FS + ENCRYPT)..."
            sgdisk -Z "$BTRFS_DEV" && sgdisk -og "$BTRFS_DEV"
            _rr_pn=1
            for _rr in $REGION_PARTITIONED; do
                eval "_rr_n=\${REGION_${_rr^^}_SIZE:-}"
                [ -n "$_rr_n" ] || { echo "FATAL: region '$_rr' carved but REGION_${_rr^^}_SIZE unset." >&2; exit 1; }
                _rr_posn="${_rr_n#+}"
                sgdisk -n "${_rr_pn}::+${_rr_posn}" -t "${_rr_pn}":8300 -c "${_rr_pn}":"LINUX-${_rr}" "$BTRFS_DEV"
                _rr_pn=$((_rr_pn + 1))
            done
            sgdisk -n "${_rr_pn}::" -t "${_rr_pn}":8300 -c "${_rr_pn}":'LINUX' "$BTRFS_DEV"
            unset _rr_pn _rr_posn _rr
            # Force partscan: close + re-open the mapper (fresh passphrase is
            # still in memory at this point), then REGISTER the fresh inner GPT
            # with the kernel + build its dm-linear submaps (kpartx-primary,
            # partprobe + partx -a fallbacks, [INNER-PARTSCAN-KPARTX] /
            # [INNER-PARTSCAN-DMPROBE]) BEFORE _region_inner_dev re-resolves the
            # region devices. The old inline partprobe only worked because the
            # whole install used the SAME freshly-carved node; the hardened
            # version closes/reopens then re-probes (and the boot-time
            # 98void-inner-partscan module does the same at next boot).
            cryptsetup luksClose "$CRYPT_NAME"
            printf '%s' "$ENCRYPT_PASSPHRASE" | cryptsetup luksOpen --key-file=- "$PART_SYS" "$CRYPT_NAME"
            _region_inner_partscan
            _region_inner_dev
            jl "MULTI-FS inner GPT carved inside LUKS2; BTRFS_DEV=${BTRFS_DEV} PART_SYS=${PART_SYS}"
        fi
        # AI (Big Pickle) ADDITION — Beta-v2.5.4 [YUBIKEY]: bind the YubiKey
        # HMAC response as an ADDITIONAL LUKS key slot while the passphrase
        # (which authenticated luksFormat) is still in memory. YK_KEY was
        # computed during enrollment and lives only in this process's memory;
        # it is written to a 0600 file in /tmp (tmpfs RAM on the live USB)
        # so luksAddKey can take it via --new-keyfile, then shredded. YK_FALLBACK=no
        # additionally removes the typed-passphrase slot (slot 0, the one
        # luksFormat created) for possession-only unlock.
        if [ "$YK_MODE" = "hmac-sha1" ]; then
            YK_KEY_FILE="/tmp/void-yubikey-key"
            printf '%s' "$YK_KEY" > "$YK_KEY_FILE"
            chmod 600 "$YK_KEY_FILE"
            echo "==> Binding YubiKey hmac-sha1 response as a LUKS key slot"
            printf '%s' "$ENCRYPT_PASSPHRASE" | cryptsetup luksAddKey "$PART_SYS" --key-file=- --new-keyfile="$YK_KEY_FILE"
            if [ "$YK_FALLBACK" = "no" ]; then
                echo "==> Removing the typed-passphrase slot (YubiKey-only unlock)"
                cryptsetup luksRemoveKey "$PART_SYS" --key-file="$YK_KEY_FILE" --key-slot 0 || true
            fi
            shred -u "$YK_KEY_FILE" 2>/dev/null || rm -f "$YK_KEY_FILE"
            unset YK_KEY YK_KEY_FILE
            echo "   YubiKey unlock enabled; passphrase fallback=${YK_FALLBACK}."
        fi
        # The passphrase has served its purpose (luksFormat+luksOpen). Drop
        # it from memory now so it cannot linger through the chroot phase.
        unset ENCRYPT_PASSPHRASE
        jl "LUKS2 container created+opened for $PART_SYS -> $BTRFS_DEV"
    fi

    # Apply filesystems
    mkfs.fat -F32 -n EFI "$PART_EFI"
    # AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS]: format each carved
    # region partition (ext4 or btrfs) BEFORE the LINUX Btrfs root so a region
    # mkfs failure aborts the install before the root is ever formatted.
    # Region devices were resolved either from the outer GPT carve (plain) or
    # the inner LUKS GPT above (ENCRYPT); REGION_<NAME>_FS says the filesystem.
    if [ -n "${REGION_PARTITIONED:-}" ]; then
        for _rr in $REGION_PARTITIONED; do
            eval "_rr_dev=\${REGION_PART_${_rr}:-}"
            _rr_fs="$(_region_fs_of "$_rr")"
            [ -n "$_rr_dev" ] || { echo "FATAL: REGION_PART_${_rr} unset — region device was never resolved." >&2; exit 1; }
            [ -e "$_rr_dev" ] || { echo "FATAL: region device ${_rr_dev} for '${_rr}' does not exist (partscan?)." >&2; exit 1; }
            echo "==> Formatting region '${_rr}' (${_rr_fs}) on ${_rr_dev}"
            # AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS-RUNLOG]: journal
            # each region's mkfs so a late failure shows which filesystem landed
            # on which device — this is the audit trail for the installer-run.log.
            jl "MULTI-FS-RUNLOG: mkfs '${_rr}' (${_rr_fs}) on ${_rr_dev}"
            case "$_rr_fs" in
                ext4) mkfs.ext4 -F -L "VOID-${_rr}" "$_rr_dev" ;;
                btrfs) mkfs.btrfs -f -L "VOID-${_rr}" "$_rr_dev" ;;
                *) echo "FATAL: unsupported region filesystem '$_rr_fs' for '$_rr'." >&2; exit 1 ;;
            esac
        done
        unset _rr _rr_dev _rr_fs
    fi
    mkfs.btrfs -f -L VOID "$BTRFS_DEV"
    mount -v "$BTRFS_DEV" /mnt
else
    # Resume: defensively clear any leftover mount on /mnt (e.g. from a crash
    # that never ran the cleanup trap), then mount the top-level Btrfs tree
    # (subvolid=5 — explicitly NOT the default subvolume) so the subvolumes
    # can be deleted/recreated below.
    umount -l /mnt 2>/dev/null || true

    if [ "$ENCRYPT" = "yes" ]; then
        # AI (Big Pickle) FIX — Beta-v2.9.6 [LUKS-UNLOCK-LEFT-OPEN]: a crash
        # can leave the mapper OPEN (pre-v2.9.6 unwinds never closed it). If
        # the exact mapper we need is already active and maps the expected
        # container partition, reuse it — cryptsetup refuses a second luksOpen
        # of an active device ("device already exists"), which previously
        # aborted the whole resume with a misleading passphrase FATAL.
        if [ -e "$CRYPT_DEV" ]; then
            echo "==> ${CRYPT_DEV} is already active — checking it maps ${PART_SYS}"
            if cryptsetup status "$CRYPT_NAME" 2>/dev/null | grep -q "device:.*${PART_SYS}"; then
                echo "   OK: reusing existing mapper (no re-unlock needed)."
                BTRFS_DEV="$CRYPT_DEV"
                jl "LUKS2 mapper already open on resume: $PART_SYS -> $BTRFS_DEV"
            else
                echo "${C_RED}!! FATAL: ${CRYPT_DEV} is active but does NOT map ${PART_SYS}.${C_RST}" >&2
                echo "     Close it first, e.g. 'cryptsetup luksClose ${CRYPT_NAME}', then re-run." >&2
                exit 1
            fi
        else
            # Resume: the container exists but the mapper is closed. With YubiKey
            # unlock enabled, prefer unlocking via the hmac-sha1 response (the
            # YubiKey is still at hand on the live medium); only a genuine YubiKey
            # failure falls back to the typed passphrase, and only when a fallback
            # slot exists. With YK_FALLBACK=no (possession-only) the YubiKey is the
            # only way in.
            if [ "$YK_MODE" = "hmac-sha1" ]; then
                YK_KEY_FILE="/tmp/void-yubikey-key"
                YK_KEY=$(ykchalresp "-${YK_SLOT}" "$YK_CHALLENGE" 2>&1)
                [ -n "$YK_KEY" ] || { echo "FATAL: YubiKey unlock failed (ykchalresp did not return a response)." >&2; exit 1; }
                printf '%s' "$YK_KEY" > "$YK_KEY_FILE"
                chmod 600 "$YK_KEY_FILE"
                echo "==> Opening LUKS2 container ${PART_SYS} -> ${CRYPT_DEV} (YubiKey)"
                if ! cryptsetup luksOpen --key-file="$YK_KEY_FILE" "$PART_SYS" "$CRYPT_NAME"; then
                    shred -u "$YK_KEY_FILE" 2>/dev/null || rm -f "$YK_KEY_FILE"
                    unset YK_KEY YK_KEY_FILE
                    if [ "$YK_FALLBACK" = "yes" ]; then
                        echo "   YubiKey unlock failed (absent/wrong?). Falling back to typed passphrase." >&2
                        echo ""
                        echo "Enter the passphrase to unlock ${PART_SYS} (LUKS2):"
                        read -r -s ENCRYPT_PASSPHRASE
                        echo
                        [ -n "$ENCRYPT_PASSPHRASE" ] || { echo "FATAL: empty passphrase." >&2; exit 1; }
                        echo "==> Opening LUKS2 container ${PART_SYS} -> ${CRYPT_DEV} (passphrase fallback)"
                        # AI (Big Pickle) ADDITION — Beta-v2.6.9 [ENCRYPT-VERIFY]: a
                        # failed luksOpen on resume must abort, not silently continue
                        # with a bogus $BTRFS_DEV (which would then mount nothing and
                        # leave the user assuming the passphrase "worked").
                        if ! printf '%s' "$ENCRYPT_PASSPHRASE" | cryptsetup luksOpen --key-file=- "$PART_SYS" "$CRYPT_NAME"; then
                            echo "${C_RED}!! FATAL: could not unlock ${PART_SYS} with the passphrase given." >&2
                            echo "     The volume exists but the passphrase does not open it.${C_RST}" >&2
                            exit 1
                        fi
                        unset ENCRYPT_PASSPHRASE
                    else
                        echo "FATAL: YubiKey unlock failed and no passphrase fallback exists (possession-only)." >&2
                        exit 1
                    fi
                else
                    shred -u "$YK_KEY_FILE" 2>/dev/null || rm -f "$YK_KEY_FILE"
                    unset YK_KEY YK_KEY_FILE
                fi
            else
                echo ""
                echo "Enter the passphrase to unlock ${PART_SYS} (LUKS2):"
                read -r -s ENCRYPT_PASSPHRASE
                echo
                [ -n "$ENCRYPT_PASSPHRASE" ] || { echo "FATAL: empty passphrase." >&2; exit 1; }
                echo "==> Opening LUKS2 container ${PART_SYS} -> ${CRYPT_DEV}"
                # AI (Big Pickle) ADDITION — Beta-v2.6.9 [ENCRYPT-VERIFY]: abort on
                # a failed resume unlock rather than continuing with a dead $BTRFS_DEV.
                if ! printf '%s' "$ENCRYPT_PASSPHRASE" | cryptsetup luksOpen --key-file=- "$PART_SYS" "$CRYPT_NAME"; then
                    echo "${C_RED}!! FATAL: could not unlock ${PART_SYS} with the passphrase given." >&2
                    echo "     The volume exists but the passphrase does not open it.${C_RST}" >&2
                    exit 1
                fi
                unset ENCRYPT_PASSPHRASE
            fi
            BTRFS_DEV="$CRYPT_DEV"
            jl "LUKS2 mapper re-opened for resume: $PART_SYS -> $BTRFS_DEV"
        fi
    fi

    # AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS] + ENCRYPT (resume):
    # the inner GPT already lives inside the LUKS container from the previous
    # run; resolve the region devices from the (just opened) mapper the same
    # way the fresh path does, and point BTRFS_DEV at the LAST inner partition
    # (the LINUX Btrfs root). Partscan is forced here too — Beta-v2.9.45
    # [INNER-PARTSCAN-DMPROBE] / Beta-v2.9.56 [INNER-PARTSCAN-KPARTX] runs
    # _region_inner_partscan (kpartx-primary, partprobe + partx -a fallbacks)
    # AFTER this open and BEFORE _region_inner_dev re-resolves
    # the region devices; the stale 2.9.38 partprobe-only after-open inline
    # (which could race the reopen already in flight) is what the helpers replace.
    if [ "$ENCRYPT" = "yes" ] && [ -n "${REGION_PARTITIONED:-}" ]; then
        _region_inner_partscan
        _region_inner_dev
        jl "MULTI-FS resume: inner region devices resolved; BTRFS_DEV=${BTRFS_DEV}"
    fi

    mount -v -o subvolid=5 "$BTRFS_DEV" /mnt
fi
# AI (Big Pickle) NOTE — Open Item #7 DECIDED (Beta-v2.4.1): @grub is KEPT as a
# dedicated top-level subvolume/mountpoint for BOOTLOADER=grub only (gated at
# the SUBVOL_LIST, mkdir, mount, fstab, and teardown-umount sites). Rationale:
# bootloader state is recovery-critical, so isolating /boot/grub on its own
# subvolume makes it immune to Snapper rollbacks of the @ root. Limine
# consumes nothing from it and under BOOTLOADER=limine no @grub subvolume is
# created at all. Beta-v2.6.2 [GRUB-ESP-BOOT]: the sole exception — a
# GRUB+ENCRYPT install also never creates @grub, because the ESP itself is
# mounted at /boot and carries all grub files (see the GRUB_ESP_BOOT
# derivation below). This closes former CHANGELOG Open Item #7 — no removal is
# planned.
BASE_LAYOUT="@ @home @opt @srv @snapshots @cache @log @spool @usercache @root"
# AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS-FOLD]: a carved region
# REPLACES the owned subvols it would otherwise provide (a top-level Btrfs
# subvol cannot span a separate partition). Entries owned by any carved region
# are pruned from BASE_LAYOUT here (the single pruning site) so SUBVOL_LIST,
# the create-loop, mounts, and fstab below all agree. @snapshots/@root/@ are
# never candidates. The @network addition below and the DM/provisioned
# additions are folded upstream by [MULTI-FS-FOLD] forcing their flags off.
for _fld in @home @opt @srv @cache @log @spool @usercache; do
    case "$_fld" in
        @home)      _fldr="home" ;;
        @opt)       _fldr="opt" ;;
        @srv)       _fldr="srv" ;;
        @cache)     _fldr="cache" ;;
        @log|@spool)    _fldr="var" ;;
        @usercache) _fldr="home" ;;
    esac
    if _region_carved "$_fldr"; then
        BASE_LAYOUT="${BASE_LAYOUT/ $_fld / }"
        jl "MULTI-FS-FOLD: pruned ${_fld} from BASE_LAYOUT (${_fldr} region carved)"
    fi
done
unset _fld _fldr
# AI (Big Pickle) ADDITION — Beta-v2.6.2 [GRUB-ESP-BOOT]: with
# BOOTLOADER=grub AND full-disk encryption, the ESP is mounted AT /boot (not
# /boot/efi) so the ENTIRE boot tree — grub.cfg, grub modules, every kernel
# and initramfs — lives OUTSIDE the LUKS volume. GRUB therefore never has to
# unlock the disk (its LUKS2/Argon2i cryptodisk path is the documented
# unreliable one), and dracut's `crypt` prompts once, after handoff. Kernel
# installs land on the ESP automatically (/boot==ESP), so no kernel-copy
# hook is needed in this branch. GRUB_ESP_BOOT is derived here (single site,
# runs after the resume state-file load, so it is recomputed correctly even
# on a -r resume where the bootloader prompt was skipped) and exported to
# chroot_env for Stage 2. Everything in the GRUB branch gates on it; the
# Limine branch is untouched (DO NOT #5).
GRUB_ESP_BOOT="false"
[ "$BOOTLOADER" = "grub" ] && [ "$ENCRYPT" = "yes" ] && GRUB_ESP_BOOT="true"
export GRUB_ESP_BOOT
SUBVOL_LIST="$BASE_LAYOUT"
# AI (Big Pickle) ADDITION — Beta-v2.6.1 [SUBVOLS]: @network backs
# /var/lib/NetworkManager runtime state (leases, NetworkManager.state) so a
# Snapper rollback of @ does not rewind it. Unconditional because
# NetworkManager is installed on every build (both $SESSION_STACK branches).
# Beta-v2.9.38 [MULTI-FS]: when the var region is carved, /var lives on its
# own partition and @network (a root-Btrfs subvol) would never be mounted —
# skip it so the create-loop does not leave a dead subvolume behind.
if ! _region_carved var; then
    SUBVOL_LIST="$SUBVOL_LIST @network"
fi
[ "$PROVISION_VIRT_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @libvirt"
[ "$PROVISION_FLATPAK_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @flatpak"
[ "$PROVISION_DOCKER_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @docker"
[ "$PROVISION_PODMAN_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @containers"
# AI (Big Pickle) ADDITION — Beta-v2.9.2 [PODMAN-ROOTLESS-SUBVOL]: @containers-user
# (per-user ~/.local/share/containers) is now gated on the resolved
# PROVISION_PODMAN_ROOTLESS_SUBVOL flag instead of the bare INSTALL_PODMAN_ROOTLESS,
# so Gate 1 / Gate 2 (per-app or bulk) decide it like the browsers. Default Gate 1
# (yes) preserves the prior always-isolated behavior for a rootless install.
[ "$PROVISION_PODMAN_ROOTLESS_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @containers-user"
# AI (Claude, Sonnet 5, Medium) CHANGE — Beta-v2.4.0: the display-manager state
# subvolume is now created conditionally, matching whichever DM was actually
# chosen, instead of @sddm being unconditional. @sddm exists only when
# DISPLAY_MANAGER=sddm (its per-user runtime dir), and @lightdm exists only
# when DISPLAY_MANAGER=lightdm (persists LightDM's per-user state/history
# across logins; gated the same way). The fstab then mounts the matching
# one; the unselected DM's subvolume is never created at all, so no dead
# subvolume is left behind on the partition.
[ "$DISPLAY_MANAGER" = "sddm" ] && ! _region_carved var && SUBVOL_LIST="$SUBVOL_LIST @sddm"
[ "$DISPLAY_MANAGER" = "lightdm" ] && ! _region_carved var && SUBVOL_LIST="$SUBVOL_LIST @lightdm"
# AI (Big Pickle) CHANGE — Beta-v2.4.0 [item 5]: @grub exists only
# for BOOTLOADER=grub. The old script created and mounted a dedicated @grub
# subvolume at /boot/grub regardless of bootloader; under BOOTLOADER=limine
# nothing ever reads /boot/grub (Limine reads everything straight off the
# ESP), so a Limine install would carry a dead, empty /boot/grub mount.
# Gated now so a Limine install leaves no grub directory at all.
# AI (Big Pickle) CHANGE — Beta-v2.6.2 [GRUB-ESP-BOOT]: additionally, under
# GRUB+ENCRYPT the ESP covers /boot entirely, so @grub is skipped there too —
# grub files live on the ESP (vfat), never inside the LUKS volume.
[ "$BOOTLOADER" = "grub" ] && [ "$GRUB_ESP_BOOT" != "true" ] && SUBVOL_LIST="$SUBVOL_LIST @grub"
# AI (Big Pickle) ADDITION — Beta-v2.4.0 [SWAP]: @swap subvolume only exists when a
# disk-backed swapfile backend was chosen (swapfile or both); zram-only and
# no-swap installs leave no @swap subvolume at all.
[ "$SWAPFILE_MODE" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @swap"
# AI (Claude, Sonnet 5, Medium) CHANGE: @mozilla/@chromium moved out of the
# unconditional base list — browsers are real toggles now (see WEB BROWSER
# SELECTION in Stage 1). Each subvolume is created if that browser is
# being installed OR if its subvolume was explicitly pre-provisioned
# anyway for later manual installation.
# Beta-v2.4.0 (Firefox layout fix): modern Firefox stores its PROFILE under
# ~/.config/mozilla/firefox and its CACHE under ~/.cache/mozilla/firefox
# (XDG base-dir layout), NOT ~/.mozilla. @mozilla now backs
# ~/.config/mozilla (nodatacow profile+sqlite) and the new @mozilla-cache
# backs ~/.cache/mozilla (nodatacow cache). Both created whenever Firefox
# is installed OR explicitly pre-provisioned for later manual install.
if [ "$PROVISION_FIREFOX_SUBVOL" = "true" ]; then
    SUBVOL_LIST="$SUBVOL_LIST @mozilla @mozilla-cache"
fi
[ "$PROVISION_CHROMIUM_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @chromium"
[ "$PROVISION_VIVALDI_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @vivaldi"
[ "$PROVISION_FALKON_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @falkon"
[ "$PROVISION_BRAVE_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @brave"

# AI (Big Pickle) ADDITION — Beta-v2.6.1 [SUBVOLS]: per-user app profile
# subvolumes (Thunderbird mail profile, Steam data dir) mirror the
# browser-provision model exactly. Since Beta-v2.9.0 [SUBVOL-GATES] the
# PROVISION_*_SUBVOL flag is RESOLVED (folded from the app's install choice +
# the two master gates) and is the single source of truth here — never
# INSTALL_* directly — and must agree with the Stage-2 provision_browser_subvol
# call sites + fstab.
[ "$PROVISION_THUNDERBIRD_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @thunderbird"
# AI (Big Pickle) ADDITION — Beta-v2.9.37 [GAME-SUBVOL]: ONE shared @game
# subvol (replaces the former @steam-only subvol) gated on the resolved
# PROVISION_GAME_SUBVOL (Gate 1/Gate 2) rather than the bare INSTALL_STEAM.
# Wine/gamemode are deliberately excluded — they have no isolated data
# datadir. Stage-2 derives the per-launcher mount set from @game.
[ "$PROVISION_GAME_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @game"
[ "$PROVISION_VIRTUALBOX_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @virtualbox"
# AI (Big Pickle) ADDITION — Beta-v2.9.36 [INSTALL-BREW]: @linuxbrew is the
# Homebrew (~/.linuxbrew) per-user datadir, gated on the resolved
# PROVISION_LINUXBREW_SUBVOL (Gate 1/Gate 2 — default OFF). Declined isolation
# leaves a correctly-owned plain ~/.linuxbrew inside @home, which already
# survives a @ rollback and isn't snapshotted, so rootless-brew operation can
# never break from declining the subvolume.
[ "$PROVISION_LINUXBREW_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @linuxbrew"

# AI (Big Pickle) ADDITION — Beta-v2.4.0 [RESUME]: SUBVOLUME RESET.
# Stage 2 (chroot provisioning) is deliberately NOT idempotent, so a resumed
# run cannot just re-run it over whatever the interrupted run left behind
# (partial package DBs, pre-existing users, dirty configs would collide).
# Instead, on resume we first delete every existing Btrfs subvolume so the
# common create-loop below and the subsequent Stage 2 always start from a
# truly empty, clean tree. We are mounted on the top-level tree (subvolid=5),
# so these first-level subvolumes are safe to delete.
if [ "$RESUME" = "1" ]; then
    echo "==> Resuming: resetting target Btrfs contents to a clean slate..."
    while IFS= read -r _svc; do
        [ -n "$_svc" ] || continue
        btrfs subvolume delete "/mnt/$_svc" >/dev/null 2>&1 || true
    done < <(btrfs subvolume list -o "/mnt" 2>/dev/null | sed -n 's/.*path \([^ ]*\)$/\1/p')
    unset _svc
    echo "==> Clean slate ready; recreating subvolume layout."
fi

for subv in $SUBVOL_LIST; do
    btrfs subvolume create /mnt/"$subv"
done
umount -v /mnt

BTRFS_OPTS="noatime,compress=zstd:1"
mount -vo $BTRFS_OPTS,subvol=@ "$BTRFS_DEV" /mnt

# AI (Big Pickle) FIX — Beta-v2.9.18 [LIMINE-WALLPAPER-STAGE2] (+ v2.9.19e
# [LIMINE-WP-REGUARD]): re-stage the picked wallpaper into the target right
# AFTER the @ root mount. The prompt-phase copy went to /mnt/tmp/limine-splash.*
# while /mnt was still the live root's plain dir; mounting the target @ here
# COVERS that path, so the chroot's /tmp/limine-splash.* loop would find
# nothing and the ESP copy never ran. Guard on $WP_SRC (live on the USB/media,
# still reachable) — NOT the now-covered $WP_STAGED path, which tests false
# exactly when this block is needed. A missing/declined source leaves the
# guarded "no wallpaper" default.
if [ "$LIMINE_WALLPAPER" = "yes" ] && [ -f "${WP_SRC:-}" ]; then
    mkdir -p /mnt/tmp
    cp -f "$WP_SRC" "/mnt/tmp/limine-splash.${WP_EXT,,}"
    echo "  Wallpaper re-staged into target → /mnt/tmp/limine-splash.${WP_EXT,,}"
fi

# AI (Big Pickle) FIX — Beta-v2.9.23 [SSH-KEYS]: transplant the SSH key
# material staged on the LIVE /tmp during the prompt phase into the target's
# /mnt/tmp right after the @ root mount — same covered-path rationale as the
# wallpaper re-stage above. The chroot deposit below then sees the keys at
# /tmp/ssh-* (the /mnt/tmp → /tmp mapping). Nothing to do when no keys were
# staged.
if [ -d /tmp/ssh-keygen ] || [ -d /tmp/ssh-import ]; then
    mkdir -p /mnt/tmp/ssh-keygen /mnt/tmp/ssh-import
    cp -f /tmp/ssh-keygen/* /mnt/tmp/ssh-keygen/ 2>/dev/null || true
    cp -f /tmp/ssh-import/* /mnt/tmp/ssh-import/ 2>/dev/null || true
    chmod -R go-rwx /mnt/tmp/ssh-keygen /mnt/tmp/ssh-import 2>/dev/null || true
fi

# AI (Big Pickle) ADDITION — Beta-v2.9.59 [LOCAL-CACHE]: when enabled, bind-mount
# the media package cache into the target at /mnt/tmp/xbps-cache. Inside the
# chroot that path reads as /tmp/xbps-cache (the /mnt/tmp → /tmp mapping of the
# @ root), so install_pkgs()/install_cosmic() hand xbps -c at it WITHOUT copying
# the multi-GB cache across — the media stays the package source, mirrors stay
# the per-package fallback. Released again in the Stage-3 teardown + the failure
# unwind, so a successful install leaves the media cache untouched.
if [ "${LOCAL_CACHE_REUSE:-no}" = "yes" ] && [ -n "${LOCAL_CACHE_DIR:-}" ] && [ -d "$LOCAL_CACHE_DIR" ]; then
    mkdir -p /mnt/tmp/xbps-cache
    if ! mount -v --bind "$LOCAL_CACHE_DIR" /mnt/tmp/xbps-cache; then
        echo "!! Cache bind mount failed; continuing with a network-only install." >&2
        LOCAL_CACHE_REUSE="no"
        LOCAL_CACHE_DIR=""
    else
        echo "==> Media package cache bind-mounted → /mnt/tmp/xbps-cache (=/tmp/xbps-cache in the chroot)."
    fi
fi

mkdir -vp /mnt/home /mnt/.snapshots /mnt/opt /mnt/srv
# AI (Big Pickle) CHANGE — Beta-v2.6.2 [GRUB-ESP-BOOT]: in the GRUB+ENCRYPT
# combo the ESP mounts AT /boot, so the mountpoint is /mnt/boot (no nested
# /mnt/boot/efi, no @grub dir). Outside the combo the classic layout stands.
if [ "$GRUB_ESP_BOOT" = "true" ]; then
    mkdir -vp /mnt/boot
else
    [ "$BOOTLOADER" = "grub" ] && mkdir -vp /mnt/boot/grub
    mkdir -vp /mnt/boot/efi
fi
mkdir -vp /mnt/var/cache /mnt/var/log /mnt/var/spool /mnt/var/tmp
# AI (Big Pickle) CHANGE — Beta-v2.4.0 [SWAP]: /var/swap only created when a disk
# swapfile backend was chosen (swapfile or both).
[ "$SWAPFILE_MODE" = "true" ] && mkdir -vp /mnt/var/swap
[ "$DISPLAY_MANAGER" = "sddm" ] && mkdir -vp /mnt/var/lib/sddm
[ "$DISPLAY_MANAGER" = "lightdm" ] && mkdir -vp /mnt/var/lib/lightdm
mkdir -vp /mnt/root
[ "$PROVISION_VIRT_SUBVOL" = "true" ] && mkdir -vp /mnt/var/lib/libvirt
[ "$PROVISION_FLATPAK_SUBVOL" = "true" ] && mkdir -vp /mnt/var/lib/flatpak
[ "$PROVISION_DOCKER_SUBVOL" = "true" ] && mkdir -vp /mnt/var/lib/docker
[ "$PROVISION_PODMAN_SUBVOL" = "true" ] && mkdir -vp /mnt/var/lib/containers
# AI (Big Pickle) ADDITION — Beta-v2.6.1 [SUBVOLS]: @network mountpoint.
mkdir -vp /mnt/var/lib/NetworkManager

# AI (Big Pickle) FIX — Beta-v2.5.2 [NODATACOW]: the churn-heavy var
# subvols are made nodatacow via their MOUNT OPTIONS (below) + fstab. A
# `chattr +C` is deliberately NOT used here: whether run pre-mount (shadowed
# the instant the subvolume mounts over its mountpoint dir) or post-mount (it
# would touch the covered mountpoint inode, not the subvolume), it cannot take
# effect on a Btrfs subvolume root. The mount/fstab `nodatacow,compress=none`
# options for @srv/@cache/@log/@spool/@libvirt are the real mechanism.

# AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS]: every mount here that
# would provide what a carved region owns is gated on that region NOT being
# carved (the subvol was pruned from BASE_LAYOUT/SUBVOL_LIST above, so the
# mount would otherwise fail with "no such subvolume"); the carved regions
# themselves are mounted from their own partitions right after.

if ! _region_carved home; then
    mount -vo $BTRFS_OPTS,subvol=@home "$BTRFS_DEV" /mnt/home
fi
if ! _region_carved opt; then
    mount -vo $BTRFS_OPTS,subvol=@opt "$BTRFS_DEV" /mnt/opt
fi
if ! _region_carved srv; then
    mount -vo noatime,nodatacow,compress=none,subvol=@srv "$BTRFS_DEV" /mnt/srv
fi
mount -vo $BTRFS_OPTS,subvol=@snapshots "$BTRFS_DEV" /mnt/.snapshots
if ! _region_carved cache; then
    mount -vo noatime,nodatacow,compress=none,subvol=@cache "$BTRFS_DEV" /mnt/var/cache
fi
if [ "$DISPLAY_MANAGER" = "sddm" ] && ! _region_carved var; then
    mount -vo $BTRFS_OPTS,subvol=@sddm "$BTRFS_DEV" /mnt/var/lib/sddm
elif [ "$DISPLAY_MANAGER" = "lightdm" ] && ! _region_carved var; then
    mount -vo $BTRFS_OPTS,subvol=@lightdm "$BTRFS_DEV" /mnt/var/lib/lightdm
fi
if [ "$PROVISION_VIRT_SUBVOL" = "true" ]; then
    mount -vo noatime,nodatacow,compress=none,subvol=@libvirt "$BTRFS_DEV" /mnt/var/lib/libvirt
fi
if ! _region_carved var; then
    mount -vo noatime,nodatacow,compress=none,subvol=@log "$BTRFS_DEV" /mnt/var/log
    mount -vo noatime,nodatacow,compress=none,subvol=@spool "$BTRFS_DEV" /mnt/var/spool
fi
# AI (Big Pickle) REMOVED — Beta-v2.5.9 [DROP-@TMP]: the @tmp subvolume is
# gone. It was provisioned, mounted here, then permanently shadowed at boot by
# the tmpfs /var/tmp fstab line — a top-level subvolume that never mounted at
# runtime (dead weight and a redundant chroot-stage space consumer). /var/tmp
# is now a plain dir inside @ (mkdir'd above); /var/tmp and /tmp are both tmpfs
# at runtime. On an in-place reinstall of a pre-beta11 system, a stray
# top-level @tmp may survive the wipe (top-level siblings are not removed by
# the nested `btrfs subvolume delete -o` cleanup) — delete it manually if found.
[ "$BOOTLOADER" = "grub" ] && [ "$GRUB_ESP_BOOT" != "true" ] && mount -vo $BTRFS_OPTS,subvol=@grub "$BTRFS_DEV" /mnt/boot/grub

[ "$PROVISION_FLATPAK_SUBVOL" = "true" ] && mount -vo $BTRFS_OPTS,subvol=@flatpak "$BTRFS_DEV" /mnt/var/lib/flatpak
[ "$PROVISION_DOCKER_SUBVOL" = "true" ] && mount -vo $BTRFS_OPTS,subvol=@docker "$BTRFS_DEV" /mnt/var/lib/docker
[ "$PROVISION_PODMAN_SUBVOL" = "true" ] && mount -vo $BTRFS_OPTS,subvol=@containers "$BTRFS_DEV" /mnt/var/lib/containers
# AI (Big Pickle) ADDITION — Beta-v2.6.1 [SUBVOLS]: @network holds NM's
# runtime state (leases, NetworkManager.state). Beta-v2.9.38 [MULTI-FS]:
# skipped when the var region is carved (NM state lives on the region
# partition's /mnt/var/lib/NetworkManager instead).
if ! _region_carved var; then
    mount -vo $BTRFS_OPTS,subvol=@network "$BTRFS_DEV" /mnt/var/lib/NetworkManager
fi
mount -vo $BTRFS_OPTS,subvol=@root "$BTRFS_DEV" /mnt/root

# AI (Big Pickle) CHANGE — Beta-v2.4.0 [SWAP]: @swap mounted + made nodatacow only
# when a disk swapfile backend (swapfile or both) was chosen. The mount is
# nodatacow,compress=none (a swapfile cannot live on a COW/compressed
# subtree), and `btrfs filesystem mkswapfile` later sets nodatacow on the
# swapfile itself — no `chattr +C` is needed or effective here.
if [ "$SWAPFILE_MODE" = "true" ]; then
    mount -vo defaults,noatime,nodatacow,compress=none,subvol=@swap "$BTRFS_DEV" /mnt/var/swap
fi
if [ "$GRUB_ESP_BOOT" = "true" ]; then
    mount -v "$PART_EFI" /mnt/boot
else
    mount -v "$PART_EFI" /mnt/boot/efi
fi

# =============================================================================
# AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS]: MOUNT THE CARVED REGIONS.
# Each carved region's own partition is mounted over its mountpoint AFTER the
# Btrfs subvol layout (so mountpoints exist) and BEFORE the chroot. Owned
# subvolumes were folded out above, so nothing collides. Mountpoints:
#   home=/home  var=/var  cache=/var/cache  srv=/srv  opt=/opt
#   games=/home/<TARGET_USER>/Games  (only meaningful when @home is real)
# Region partitions are rollback-exempt but not snapshotted (Snapper only
# handles the root Btrfs). A mountpoint collision (e.g. @home mount left) is
# impossible because the mounts above are gated on the region NOT being carved.
# =============================================================================
if [ -n "${REGION_PARTITIONED:-}" ]; then
    for _rr in $REGION_PARTITIONED; do
        eval "_rr_dev=\${REGION_PART_${_rr}:-}"
        _rr_fs="$(_region_fs_of "$_rr")"
        [ -n "$_rr_dev" ] || { echo "FATAL: REGION_PART_${_rr} unset at region-mount time." >&2; exit 1; }
        case "$_rr" in
            home)  _rr_mp="/mnt/home" ; _rr_leaf="home" ;;
            var)   _rr_mp="/mnt/var" ; _rr_leaf="var" ;;
            cache) _rr_mp="/mnt/var/cache" ; _rr_leaf="var" ;;
            srv)   _rr_mp="/mnt/srv" ; _rr_leaf="srv" ;;
            opt)   _rr_mp="/mnt/opt" ; _rr_leaf="opt" ;;
            games) _rr_mp="/mnt/home/${TARGET_USER}/Games" ; _rr_leaf="home" ;;
            *) echo "FATAL: unknown region '$_rr'." >&2; exit 1 ;;
        esac
        mkdir -vp "$_rr_mp"
        # Mount source options match the fstab row written below (see [MULTI-FS]
        # fstab block) so the live chroot layout == boot layout.
        if [ "$_rr_fs" = "ext4" ]; then
            mount -vo defaults,noatime "$_rr_dev" "$_rr_mp"
        else
            if [ "$_rr_leaf" = "var" ] || [ "$_rr_leaf" = "srv" ]; then
                mount -vo defaults,noatime,nodatacow,compress=none "$_rr_dev" "$_rr_mp"
            else
                mount -vo defaults,noatime,compress=zstd:1 "$_rr_dev" "$_rr_mp"
            fi
        fi
        echo "  Region '${_rr}' mounted ($_rr_fs) → ${_rr_mp}"
        # AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS-RUNLOG]: the mount
        # audit line (device, fs, mountpoint) mirrors the fstab row content so
        # live-layout == boot-layout is checkable from the journal alone.
        jl "MULTI-FS-RUNLOG: region '${_rr}' mounted (${_rr_fs}) ${_rr_dev} -> ${_rr_mp}"
    done
    unset _rr _rr_dev _rr_fs _rr_mp _rr_leaf
fi

ARCH="x86_64"

mkdir -p /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/

BOOTSTRAP_OK=0
for REPO_ATTEMPT in "$REPO_PRIMARY" "$REPO_BACKUP1" "$REPO_BACKUP2" "$REPO_EXTRA1" "$REPO_EXTRA2"; do
    echo "==> Attempting base-system bootstrap against repository: ${REPO_ATTEMPT}"
    # AI (Big Pickle) ADDITION — Beta-v2.9.59 [LOCAL-CACHE]: same -c threading
    # into the base bootstrap; an empty ${LOCAL_CA} is the plain network path.
    # shellcheck disable=SC2086  # $LOCAL_CA word-split into -c <dir>; empty = network-only
    if XBPS_ARCH=$ARCH xbps-install -Suv -R "$REPO_ATTEMPT" -r /mnt ${LOCAL_CA} base-system btrfs-progs $KERNEL_PKGS glibc-locales -y; then
        BOOTSTRAP_OK=1
        echo "==> Bootstrap succeeded using: ${REPO_ATTEMPT}"
        break
    fi
    echo "==> Bootstrap attempt against ${REPO_ATTEMPT} failed — trying next repository, if any." >&2
done

if [ "$BOOTSTRAP_OK" -ne 1 ]; then
    echo "FATAL: base-system bootstrap failed against all configured repositories (primary + both backups + region extras)." >&2
    exit 1
fi

for dir in dev proc sys run; do
    mount -v --rbind "/${dir}" "/mnt/${dir}"
    mount -v --make-rslave "/mnt/${dir}"
done
mount -v -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars
cp /etc/resolv.conf /mnt/etc/

BTRFS_UUID=$(blkid -s UUID -o value "$BTRFS_DEV")
EFI_UUID=$(blkid -s UUID -o value "$PART_EFI")

    # Beta-v2.3.0 corrective addition, confirmed against a real
    # failed boot (Limine PANIC: "Failed to open kernel with path
    # 'hdd(1):<GUID>:/boot/vmlinuz-...'. Is the path correct?") and Limine's
    # own documented URI scheme (limine-bootloader/limine wiki: valid forms are
    # `hdd(N)` / `hdd(N:M)` — disk/partition INDEX addressing, no GUID — or
    # `guid(<GUID>)` — GUID addressing, no disk index. `hdd(1):<GUID>` as
    # previously written here is neither: it splices disk-index syntax and
    # GUID syntax into one invalid URI, which is exactly why BOTH kernel modes
    # failed identically on real hardware — this bug was never about btrfs
# subvolume resolution at all, it never got that far. Switched to
# `guid(<GUID>)`, which needs no disk-enumeration-order assumption at all
# (Open Item #5d is now moot for this reason, not just resolved).
# AI (Big Pickle) FIX — Beta-v2.9.68 [PARTUUID-NODEPS]: `lsblk` DESCENDS into
# children by default, so with ENCRYPT+regions (PART_SYS = the LUKS container
# /dev/nvme0n1p2, whose dm children are the inner GPT partitions void1/2/3)
# `lsblk -no PARTUUID "$PART_SYS"` captured FOUR PARTUUIDs — one per line — and
# SYSPREFIX_BTRFS became a malformed multi-line `guid(\n...\n)` value in
# limine-env + chroot_env. SYSPREFIX_ESP happened to stay single-valued only
# because the ESP vfat partition has no children, so the boot-critical value was
# safe by luck. `--nodeps` makes both capture exactly the named partition.
ESP_PARTUUID=$(lsblk -no PARTUUID --nodeps "$PART_EFI")
BTRFS_PARTUUID=$(lsblk -no PARTUUID --nodeps "$PART_SYS")
SYSPREFIX_ESP="guid(${ESP_PARTUUID})"
SYSPREFIX_BTRFS="guid(${BTRFS_PARTUUID})"

# AI (Big Pickle) CHANGE — Beta-v2.4.0 [SWAP]: the Btrfs-native swapfile is created
# only for a disk swapfile backend; its size honors the Stage 1 choice.
if [ "$SWAPFILE_MODE" = "true" ]; then
    rm -f /mnt/var/swap/swapfile
    btrfs filesystem mkswapfile --size "${SWAPFILE_SIZE}" /mnt/var/swap/swapfile
    mkswap -L SWAP /mnt/var/swap/swapfile
fi

cat > /mnt/etc/fstab << EOF
UUID=$BTRFS_UUID /                btrfs noatime,compress=zstd:1,subvol=@ 0 0
UUID=$BTRFS_UUID /.snapshots      btrfs noatime,compress=zstd:1,subvol=@snapshots 0 0
tmpfs            /tmp             tmpfs defaults,noatime,mode=1777 0 0
tmpfs            /var/tmp         tmpfs defaults,noatime,mode=1777 0 0
EOF

# AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS]: region-owned rows are
# written as separate fstab entries (not in the heredoc) because each one is
# either a folded subvol row (region NOT carved — Btrfs root) or a region
# partition row (region carved — its own UUID). The gating mirrors the
# Stage-1 mounts exactly so the chroot layout == the boot layout.
if ! _region_carved home; then
    echo "UUID=$BTRFS_UUID /home            btrfs noatime,compress=zstd:1,subvol=@home 0 0" >> /mnt/etc/fstab
fi
if ! _region_carved opt; then
    echo "UUID=$BTRFS_UUID /opt             btrfs noatime,compress=zstd:1,subvol=@opt 0 0" >> /mnt/etc/fstab
fi
if ! _region_carved srv; then
    echo "UUID=$BTRFS_UUID /srv             btrfs noatime,nodatacow,compress=none,subvol=@srv 0 0" >> /mnt/etc/fstab
fi
if ! _region_carved cache; then
    echo "UUID=$BTRFS_UUID /var/cache       btrfs noatime,nodatacow,compress=none,subvol=@cache 0 0" >> /mnt/etc/fstab
fi
if ! _region_carved var; then
    echo "UUID=$BTRFS_UUID /var/log         btrfs noatime,nodatacow,compress=none,subvol=@log 0 0" >> /mnt/etc/fstab
    echo "UUID=$BTRFS_UUID /var/spool       btrfs noatime,nodatacow,compress=none,subvol=@spool 0 0" >> /mnt/etc/fstab
fi

# Region partition rows: source is the region device's own fs UUID; the
# mountpoint/options repeat the Stage-1 region mount block above.
if [ -n "${REGION_PARTITIONED:-}" ]; then
    for _rr in $REGION_PARTITIONED; do
        eval "_rr_dev=\${REGION_PART_${_rr}:-}"
        _rr_fs="$(_region_fs_of "$_rr")"
        eval "_rr_uuid=\${REGION_UUID_${_rr}:-}"
        if [ -z "$_rr_uuid" ]; then
            _rr_uuid=$(blkid -s UUID -o value "$_rr_dev")
            eval "REGION_UUID_${_rr}=\"\${_rr_uuid}\""
        fi
        [ -n "$_rr_uuid" ] || { echo "FATAL: could not read UUID for region '$_rr' device $_rr_dev." >&2; exit 1; }
        case "$_rr" in
            home)  _rr_mp="/home" ; _rr_leaf="home" ;;
            var)   _rr_mp="/var" ; _rr_leaf="var" ;;
            cache) _rr_mp="/var/cache" ; _rr_leaf="var" ;;
            srv)   _rr_mp="/srv" ; _rr_leaf="srv" ;;
            opt)   _rr_mp="/opt" ; _rr_leaf="opt" ;;
            games) _rr_mp="/home/${TARGET_USER}/Games" ; _rr_leaf="home" ;;
            *) echo "FATAL: unknown region '$_rr'." >&2; exit 1 ;;
        esac
        # fstab totals: ext4=0 2 (fsck), btrfs=0 0 (no fsck / needs Btrfs first).
        if [ "$_rr_fs" = "ext4" ]; then
            echo "UUID=$_rr_uuid $_rr_mp ext4 defaults,noatime 0 2" >> /mnt/etc/fstab
        elif [ "$_rr_leaf" = "var" ] || [ "$_rr_leaf" = "srv" ]; then
            echo "UUID=$_rr_uuid $_rr_mp btrfs defaults,noatime,nodatacow,compress=none 0 0" >> /mnt/etc/fstab
        else
            echo "UUID=$_rr_uuid $_rr_mp btrfs defaults,noatime,compress=zstd:1 0 0" >> /mnt/etc/fstab
        fi
        # AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS-RUNLOG]: log the row
        # actually emitted (not just the mount) so the journal records the fstab
        # as built — the checkable companion to the boot-time layout.
        jl "MULTI-FS-RUNLOG: fstab row UUID=$_rr_uuid $_rr_mp $_rr_fs"
    done
    unset _rr _rr_dev _rr_fs _rr_uuid _rr_mp _rr_leaf
fi

# AI (Big Pickle) CHANGE — Beta-v2.6.2 [GRUB-ESP-BOOT]: the ESP mountpoint
# is /boot in the GRUB+ENCRYPT combo (it covers the whole boot tree so GRUB
# never touches the LUKS volume), else /boot/efi as before. Appended after
# the heredoc because the target path differs per combo.
if [ "$GRUB_ESP_BOOT" = "true" ]; then
    echo "UUID=$EFI_UUID /boot vfat defaults,noatime 0 2" >> /mnt/etc/fstab
else
    echo "UUID=$EFI_UUID /boot/efi vfat defaults,noatime 0 2" >> /mnt/etc/fstab
fi

# AI (Big Pickle) ADDITION — Beta-v2.5.5 [ENCRYPT]: /etc/crypttab tells
# dracut's `crypt` module how to unlock the container at boot. It maps the
# plaintext mapper name (void-root) to the LUKS header by the container
# partition's filesystem UUID (from `blkid` on $PART_SYS — the ciphertext
# container's own UUID, NOT the Btrfs filesystem UUID inside the mapper,
# which is $BTRFS_UUID and differs). `none` = no keyfile, so dracut prompts
# for the passphrase at boot; `luks` = LUKS-based keyslot unlocking. Only
# written when encryption is enabled.
if [ "$ENCRYPT" = "yes" ]; then
    LUKS_UUID=$(blkid -s UUID -o value "$PART_SYS")
    if [ "$YK_MODE" = "hmac-sha1" ]; then
        # AI (Big Pickle) ADDITION — Beta-v2.5.4 [YUBIKEY]: with YubiKey
        # unlock, crypttab points at a boot-time keyscript instead of
        # prompting for a passphrase. dracut runs
        # /usr/local/sbin/void-reveal-yubikey-key, which challenges the
        # YubiKey (slot $YK_SLOT, challenge $YK_CHALLENGE) and prints the
        # HMAC response as the LUKS key; cryptroot-ask feeds it to luksOpen.
        # With YK_FALLBACK=yes, if the YubiKey is absent/wrong the luksOpen
        # fails and dracut's cryptroot-ask falls back to the typed passphrase
        # prompt automatically — that is the boot-time fallback path. With
        # YK_FALLBACK=no there is no fallback slot, so only the YubiKey opens
        # the volume (possession-only).
        echo "${CRYPT_NAME} UUID=$LUKS_UUID none luks,keyscript=/usr/local/sbin/void-reveal-yubikey-key" > /mnt/etc/crypttab
    else
        echo "${CRYPT_NAME} UUID=$LUKS_UUID none luks" > /mnt/etc/crypttab
    fi
fi

# AI (Big Pickle) CHANGE — Beta-v2.4.0 [SWAP]: fstab swap entries now appear only
# when a disk swapfile backend (swapfile or both) was chosen.
if [ "$SWAPFILE_MODE" = "true" ]; then
    echo "UUID=$BTRFS_UUID /var/swap        btrfs noatime,nodatacow,subvol=@swap 0 0" >> /mnt/etc/fstab
    echo "/var/swap/swapfile               none  swap  defaults                  0 0" >> /mnt/etc/fstab
fi

if [ "$PROVISION_VIRT_SUBVOL" = "true" ]; then
    echo "UUID=$BTRFS_UUID /var/lib/libvirt btrfs noatime,nodatacow,subvol=@libvirt 0 0" >> /mnt/etc/fstab
fi
if [ "$PROVISION_FLATPAK_SUBVOL" = "true" ]; then
    echo "UUID=$BTRFS_UUID /var/lib/flatpak    btrfs noatime,compress=zstd:1,subvol=@flatpak 0 0" >> /mnt/etc/fstab
fi
if [ "$PROVISION_DOCKER_SUBVOL" = "true" ]; then
    echo "UUID=$BTRFS_UUID /var/lib/docker     btrfs noatime,compress=zstd:1,subvol=@docker 0 0" >> /mnt/etc/fstab
fi
if [ "$PROVISION_PODMAN_SUBVOL" = "true" ]; then
    echo "UUID=$BTRFS_UUID /var/lib/containers btrfs noatime,compress=zstd:1,subvol=@containers 0 0" >> /mnt/etc/fstab
fi
# AI (Big Pickle) ADDITION — Beta-v2.6.1 [SUBVOLS]: @network fstab entry
# (unconditional in prior versions because NM is always installed).
# Beta-v2.9.38 [MULTI-FS]: skipped when the var region is carved (NM state
# lives on the region partition's /var/lib/NetworkManager instead).
if ! _region_carved var; then
    echo "UUID=$BTRFS_UUID /var/lib/NetworkManager btrfs noatime,compress=zstd:1,subvol=@network 0 0" >> /mnt/etc/fstab
fi
# AI (Claude, Sonnet 5, Medium) CHANGE — Beta-v2.4.0: mount the display manager's
# runtime/state subvolume, matching the one created in Stage 1. @sddm is
# mounted (via tmpfs in older revisions) for SDDM; when LightDM is chosen, a
# dedicated @lightdm btrfs subvolume persists its per-user state instead.
# Beta-v2.9.38 [MULTI-FS]: both DM subvols are var-owned, so they are also
# skipped when the var region is carved.
if [ "$DISPLAY_MANAGER" = "sddm" ] && ! _region_carved var; then
    echo "UUID=$BTRFS_UUID /var/lib/sddm btrfs noatime,compress=zstd:1,subvol=@sddm 0 0" >> /mnt/etc/fstab
elif [ "$DISPLAY_MANAGER" = "lightdm" ] && ! _region_carved var; then
    echo "UUID=$BTRFS_UUID /var/lib/lightdm btrfs noatime,compress=zstd:1,subvol=@lightdm 0 0" >> /mnt/etc/fstab
fi
# AI (Big Pickle) CHANGE — Beta-v2.4.0 [item 5]: /boot/grub fstab
# entry now exists only for BOOTLOADER=grub (the @grub subvolume is likewise
# gated in Stage 1). Under Limine nothing is mounted at /boot/grub.
# Beta-v2.6.2 [GRUB-ESP-BOOT]: also never written in the GRUB+ENCRYPT
# combo, where grub files live on the ESP (/boot) below instead.
[ "$BOOTLOADER" = "grub" ] && \
    [ "$GRUB_ESP_BOOT" != "true" ] && \
    echo "UUID=$BTRFS_UUID /boot/grub       btrfs noatime,compress=zstd:1,subvol=@grub 0 0" >> /mnt/etc/fstab
echo "UUID=$BTRFS_UUID /root               btrfs noatime,compress=zstd:1,subvol=@root 0 0" >> /mnt/etc/fstab

: > /mnt/tmp/chroot_env.sh
chmod 600 /mnt/tmp/chroot_env.sh
# AI (Big Pickle) ADDITION — Beta-v2.6.9 [KEYMAP]: capture the console keymap
# the user is typing the LUKS passphrase under, so the installed system (and its
# early-boot initramfs prompt) uses the SAME keymap. A mismatch here is the
# classic cause of "complex passphrase unlocks but a short simple one does not":
# the install console and the boot console mapped keys to different bytes.
# Read the LIVE medium's /etc/rc.conf KEYMAP (what Void's 03-console-setup.sh
# used to set up the console we're on), defaulting to 'us'. This runs on the
# live side, BEFORE the chroot, so it reads the live file, not the target's.
# shellcheck disable=SC1090
KEYMAP_LIVE=$(sed -n 's/^[[:space:]]*KEYMAP="\([^"]*\)".*/\1/p' /etc/rc.conf 2>/dev/null | tail -1)
[ -z "${KEYMAP_LIVE:-}" ] && KEYMAP_LIVE="us"
export KEYMAP_LIVE
# AI (Big Pickle) ADDITION — Beta-v2.9.90 [COSMIC-PPD]: COSMIC's
# cosmic-settings hard-depends on power-profiles-daemon (D-Bus
# net.hadess.PowerProfiles), and running tlp + PPD together is a documented
# conflict (both want CPU-scaling / platform-profile knobs). So on EVERY
# COSMIC build the power backend is PPD instead of tlp — the powermode
# picker gets its backend from day one and the box never fights itself.
# Scope: COSMIC-only; every other DE keeps the existing tlp behavior.
POWER_PPD="false"
if [ "$DESKTOP_ENV" = "cosmic" ]; then
    POWER_PPD="true"
    [ "$PROFILE_TLP" = "true" ] && PROFILE_TLP="false"
fi
export POWER_PPD
[ "$POWER_PPD" = "true" ] && echo "  NOTE: COSMIC uses power-profiles-daemon; tlp skipped (PPD+tlp conflict)."
# shellcheck disable=SC2129  # per-line appends, grouped for readability
echo "export BTRFS_UUID=\"$BTRFS_UUID\"" >> /mnt/tmp/chroot_env.sh
echo "export KERNEL_PKGS=\"$KERNEL_PKGS\"" >> /mnt/tmp/chroot_env.sh
echo "export DEVICE_PROFILE=\"$DEVICE_PROFILE\"" >> /mnt/tmp/chroot_env.sh
echo "export PROFILE_TLP=\"$PROFILE_TLP\"" >> /mnt/tmp/chroot_env.sh
echo "export PROFILE_BT=\"$PROFILE_BT\"" >> /mnt/tmp/chroot_env.sh
echo "export PROFILE_PRELOAD=\"$PROFILE_PRELOAD\"" >> /mnt/tmp/chroot_env.sh
echo "export POWER_PPD=\"$POWER_PPD\"" >> /mnt/tmp/chroot_env.sh
echo "export TARGET_USER=\"$TARGET_USER\"" >> /mnt/tmp/chroot_env.sh
echo "export TARGET_FULL_NAME=\"$TARGET_FULL_NAME\"" >> /mnt/tmp/chroot_env.sh
echo "export TARGET_HOSTNAME=\"$TARGET_HOSTNAME\"" >> /mnt/tmp/chroot_env.sh
echo "export TARGET_DOMAIN=\"$TARGET_DOMAIN\"" >> /mnt/tmp/chroot_env.sh
echo "export TARGET_FQDN=\"$TARGET_FQDN\"" >> /mnt/tmp/chroot_env.sh
echo "export NET_INTERFACE_MATCH=\"$NET_INTERFACE_MATCH\"" >> /mnt/tmp/chroot_env.sh
echo "export REPO_PRIMARY=\"$REPO_PRIMARY\"" >> /mnt/tmp/chroot_env.sh
echo "export KEYMAP_LIVE=\"$KEYMAP_LIVE\"" >> /mnt/tmp/chroot_env.sh
echo "export REPO_BACKUP1=\"$REPO_BACKUP1\"" >> /mnt/tmp/chroot_env.sh
echo "export REPO_BACKUP2=\"$REPO_BACKUP2\"" >> /mnt/tmp/chroot_env.sh
echo "export REPO_EXTRA1=\"$REPO_EXTRA1\"" >> /mnt/tmp/chroot_env.sh
echo "export REPO_EXTRA2=\"$REPO_EXTRA2\"" >> /mnt/tmp/chroot_env.sh
# AI (Big Pickle) ADDITION — Beta-v2.9.59 [LOCAL-CACHE]: thread the cache choice
# into the chroot. LOCAL_CACHE_DIR is REMAPPED here — /tmp/xbps-cache, the
# /mnt/tmp/xbps-cache bind mount — so install_pkgs()/install_cosmic() hand xbps
# -c at exactly the mounted media cache and never at a live-side path that does
# not exist inside the chroot.
echo "export LOCAL_CACHE_REUSE=\"${LOCAL_CACHE_REUSE:-no}\"" >> /mnt/tmp/chroot_env.sh
if [ "${LOCAL_CACHE_REUSE:-no}" = "yes" ]; then
    echo "export LOCAL_CACHE_DIR=\"/tmp/xbps-cache\"" >> /mnt/tmp/chroot_env.sh
fi
echo "export ENABLE_SNAPSHOT_AUDIO=\"$ENABLE_SNAPSHOT_AUDIO\"" >> /mnt/tmp/chroot_env.sh
echo "export ACCOUNT_MODEL=\"$ACCOUNT_MODEL\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_FLATPAK=\"$INSTALL_FLATPAK\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_COSMIC_STORE=\"$INSTALL_COSMIC_STORE\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_BREW=\"$INSTALL_BREW\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_FIREFOX=\"$INSTALL_FIREFOX\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_CHROMIUM=\"$INSTALL_CHROMIUM\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_VIVALDI=\"$INSTALL_VIVALDI\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_FALKON=\"$INSTALL_FALKON\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_BRAVE=\"$INSTALL_BRAVE\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_THUNDERBIRD=\"$INSTALL_THUNDERBIRD\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_STEAM=\"$INSTALL_STEAM\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_LUTRIS=\"$INSTALL_LUTRIS\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_HEROIC=\"$INSTALL_HEROIC\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_BOTTLES=\"$INSTALL_BOTTLES\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_WINE=\"$INSTALL_WINE\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_GAMEMODE=\"$INSTALL_GAMEMODE\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_ANY_GAME=\"$INSTALL_ANY_GAME\"" >> /mnt/tmp/chroot_env.sh
 echo "export INSTALL_VIRTUALBOX=\"$INSTALL_VIRTUALBOX\"" >> /mnt/tmp/chroot_env.sh
 echo "export SUBVOL_ISOLATE_INSTALLED=\"$SUBVOL_ISOLATE_INSTALLED\"" >> /mnt/tmp/chroot_env.sh
 echo "export SUBVOL_PRECREATE=\"$SUBVOL_PRECREATE\"" >> /mnt/tmp/chroot_env.sh
 echo "export PROVISION_FIREFOX_SUBVOL=\"$PROVISION_FIREFOX_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export PROVISION_CHROMIUM_SUBVOL=\"$PROVISION_CHROMIUM_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export PROVISION_VIVALDI_SUBVOL=\"$PROVISION_VIVALDI_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export PROVISION_FALKON_SUBVOL=\"$PROVISION_FALKON_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export PROVISION_BRAVE_SUBVOL=\"$PROVISION_BRAVE_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export PROVISION_THUNDERBIRD_SUBVOL=\"$PROVISION_THUNDERBIRD_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export PROVISION_GAME_SUBVOL=\"$PROVISION_GAME_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export PROVISION_VIRTUALBOX_SUBVOL=\"$PROVISION_VIRTUALBOX_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
# AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS]: thread the region choices
# into Stage 2 so the chroot's games/@usercache/profile flows can gate on
# whether a region was carved (e.g. ~/Games is a plain dir on the region
# partition vs a subvolume tree, and @usercache/fstab rows must agree with the
# folded mount layout). The purpose is purely informational in the chroot —
# the actual mounts/fstab already happened on the ROOT side.
echo "export REGION_PARTITIONED=\"$REGION_PARTITIONED\"" >> /mnt/tmp/chroot_env.sh
echo "export REGION_HOME_FS=\"$REGION_HOME_FS\"" >> /mnt/tmp/chroot_env.sh
echo "export REGION_VAR_FS=\"$REGION_VAR_FS\"" >> /mnt/tmp/chroot_env.sh
echo "export REGION_CACHE_FS=\"$REGION_CACHE_FS\"" >> /mnt/tmp/chroot_env.sh
echo "export REGION_SRV_FS=\"$REGION_SRV_FS\"" >> /mnt/tmp/chroot_env.sh
echo "export REGION_OPT_FS=\"$REGION_OPT_FS\"" >> /mnt/tmp/chroot_env.sh
echo "export REGION_GAMES=\"$REGION_GAMES\"" >> /mnt/tmp/chroot_env.sh
echo "export PROVISION_LINUXBREW_SUBVOL=\"$PROVISION_LINUXBREW_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_PODMAN_ROOTLESS=\"$INSTALL_PODMAN_ROOTLESS\"" >> /mnt/tmp/chroot_env.sh
echo "export PROVISION_PODMAN_ROOTLESS_SUBVOL=\"$PROVISION_PODMAN_ROOTLESS_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_DISTROBOX=\"$INSTALL_DISTROBOX\"" >> /mnt/tmp/chroot_env.sh
echo "export DISTROBOX_TRACK=\"$DISTROBOX_TRACK\"" >> /mnt/tmp/chroot_env.sh
echo "export DISTROBOX_DEFAULT_ENGINE=\"$DISTROBOX_DEFAULT_ENGINE\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_PODMAN_ROOTFUL=\"$INSTALL_PODMAN_ROOTFUL\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_PODMAN=\"$INSTALL_PODMAN\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_DOCKER=\"$INSTALL_DOCKER\"" >> /mnt/tmp/chroot_env.sh
echo "export DOCKER_GROUP_ADD=\"$DOCKER_GROUP_ADD\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_VIRT=\"$INSTALL_VIRT\"" >> /mnt/tmp/chroot_env.sh
echo "export DESKTOP_ENV=\"$DESKTOP_ENV\"" >> /mnt/tmp/chroot_env.sh
echo "export DISPLAY_MANAGER=\"$DISPLAY_MANAGER\"" >> /mnt/tmp/chroot_env.sh
# AI (Big Pickle) ADDITION — Beta-v2.9.48 [HEADLESS]: the xorg/wayland base
# chain, the audio gate, and the rc.local DM link all resolve IN-CHROOT, so
# the resolved flags must thread over with DESKTOP_ENV/DISPLAY_MANAGER.
echo "export HAS_GRAPHICAL=\"$HAS_GRAPHICAL\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_XORG=\"$INSTALL_XORG\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_AUDIO=\"$INSTALL_AUDIO\"" >> /mnt/tmp/chroot_env.sh
echo "export LIGHTDM_GREETER_PKG=\"$LIGHTDM_GREETER_PKG\"" >> /mnt/tmp/chroot_env.sh
echo "export LIGHTDM_GREETER_SESSION=\"$LIGHTDM_GREETER_SESSION\"" >> /mnt/tmp/chroot_env.sh
# AI (Big Pickle) ADDITION — Beta-v2.9.21 [GREETER-BG-EXPORT]: the greeter-bg
# block lives inside the single-quoted chroot heredoc, so its
# `case "$LIGHTDM_GREETER"` must resolve IN-CHROOT at runtime — only the
# derived _PKG / _SESSION were threaded in before, leaving the bare gtk/slick
# choice unset in the chroot, so the case matched neither branch and NO greeter
# conf was ever written (black login screen). Same bug family as
# [DEVICE-PROFILE-RCL] (2.9.19).
echo "export LIGHTDM_GREETER=\"$LIGHTDM_GREETER\"" >> /mnt/tmp/chroot_env.sh
# AI (Big Pickle) ADDITION — Beta-v2.9.23 [SSH-SERVER]: carry the OpenSSH
# server decision into the chroot so Stage 2 can install openssh, write the
# sshd_config.d drop-in, and emit the input-chain fragment. Public facts only.
echo "export INSTALL_SSH_SERVER=\"$INSTALL_SSH_SERVER\"" >> /mnt/tmp/chroot_env.sh
echo "export SSH_PORT=\"$SSH_PORT\"" >> /mnt/tmp/chroot_env.sh
echo "export SSH_PASSWORD_AUTH=\"$SSH_PASSWORD_AUTH\"" >> /mnt/tmp/chroot_env.sh
echo "export SSH_ROOT_LOGIN=\"$SSH_ROOT_LOGIN\"" >> /mnt/tmp/chroot_env.sh
# AI (Big Pickle) ADDITION — Beta-v2.9.25 [NVIDIA-GATE]: hardware facts +
# the driver decision ride into the chroot (the nvidia install gate + the
# header mapping above consume them). Public facts only.
echo "export INSTALL_NVIDIA=\"$INSTALL_NVIDIA\"" >> /mnt/tmp/chroot_env.sh
echo "export GPU_FAMILIES=\"$GPU_FAMILIES\"" >> /mnt/tmp/chroot_env.sh
echo "export HAS_NVIDIA_GPU=\"$HAS_NVIDIA_GPU\"" >> /mnt/tmp/chroot_env.sh
echo "export HAS_AMD_GPU=\"$HAS_AMD_GPU\"" >> /mnt/tmp/chroot_env.sh
echo "export HAS_INTEL_GPU=\"$HAS_INTEL_GPU\"" >> /mnt/tmp/chroot_env.sh
echo "export WIFI_HW=\"$WIFI_HW\"" >> /mnt/tmp/chroot_env.sh
# AI (Big Pickle) ADDITION — Beta-v2.9.26 follow-up [WIFI-FW-CHROOT]: carry the
# wifi probe + firmware decision across the chroot boundary. chroot_env.sh is
# the ONLY variable path into /mnt (a bare live `export` never crosses it), and
# the in-chroot base-install line gates its install_pkgs on INSTALL_WIFI_FW +
# WIFI_FW_PKG while [WIFI-FW-VERIFY] iterates WIFI_IDS — without these they were
# empty in the chroot, so the Broadcom gap-close silently no-oped and the verify
# loop never ran. [RECONSTRUCTED]: both the local 2.9.26 WIP and Solar Pro 4's
# byte-identical draft exported these live-only and missed the chroot_env path.
echo "export INSTALL_WIFI_FW=\"$INSTALL_WIFI_FW\"" >> /mnt/tmp/chroot_env.sh
echo "export WIFI_IDS=\"$WIFI_IDS\"" >> /mnt/tmp/chroot_env.sh
echo "export WIFI_CHIPS=\"$WIFI_CHIPS\"" >> /mnt/tmp/chroot_env.sh
echo "export WIFI_FW_PKG=\"$WIFI_FW_PKG\"" >> /mnt/tmp/chroot_env.sh
# AI (Big Pickle) ADDITION — Beta-v2.9.27 [CPU-DETECT]/[NIC-DETECT]: the CPU
# microcode decision and the bridged-VM NIC name ride into the chroot so Stage 2
# can word-split MICROCODE_PKG into the base toolchain install line and so the
# NM br0 profile (when INSTALL_VIRT) picks the right interface. MICROCODE_
# DECIDED tells the chroot whether to trust the live value or re-derive from its
# own /proc/cpuinfo (resume from a pre-2.9.27 state file).
echo "export MICROCODE_PKG=\"$MICROCODE_PKG\"" >> /mnt/tmp/chroot_env.sh
echo "export MICROCODE_DECIDED=\"$MICROCODE_DECIDED\"" >> /mnt/tmp/chroot_env.sh
echo "export BR0_NIC=\"$BR0_NIC\"" >> /mnt/tmp/chroot_env.sh
# AI (Big Pickle) ADDITION — Beta-v2.4.0 [LOCALIZE]: carry the chosen locale/timezone
# into the chroot so Stage 2 can generate+activate the locale and set the zone.
echo "export LOCALE=\"$LOCALE\"" >> /mnt/tmp/chroot_env.sh
echo "export LOCALE_CODESET=\"$LOCALE_CODESET\"" >> /mnt/tmp/chroot_env.sh
echo "export TIMEZONE=\"$TIMEZONE\"" >> /mnt/tmp/chroot_env.sh
# AI (Big Pickle) ADDITION — Beta-v2.4.0 [SWAP]: carry swap/zram/hibernation choices
# into the chroot so Stage 2 can provision the right backend(s).
echo "export SWAP_BACKEND=\"$SWAP_BACKEND\"" >> /mnt/tmp/chroot_env.sh
echo "export ENABLE_HIBERNATION=\"$ENABLE_HIBERNATION\"" >> /mnt/tmp/chroot_env.sh
echo "export SWAPFILE_SIZE=\"$SWAPFILE_SIZE\"" >> /mnt/tmp/chroot_env.sh
# AI (Big Pickle) ADDITION — Beta-v2.5.5 [ENCRYPT]: the yes/no flag is
# carried into the chroot so Stage 2 writes crypttab (and dracut/GRUB/Limine
# provision the crypt path). Deliberately NOT the passphrase — chroot_env.sh
# must stay secret-free (same rule as the pass hashes below), and the
# passphrase was already unset after luksOpen anyway.
echo "export ENCRYPT=\"$ENCRYPT\"" >> /mnt/tmp/chroot_env.sh
# AI (Big Pickle) ADDITION — Beta-v2.7.1 [CRYPT-NAME]: the mapper name is a
# public, non-secret value (it appears in /dev/mapper and on the kernel
# cmdline), so it is safe to carry into the chroot for the GRUB/Limine
# rd.luks.name= builders and crypttab. Defaults to void-root.
echo "export CRYPT_NAME=\"${CRYPT_NAME:-void-root}\"" >> /mnt/tmp/chroot_env.sh
# The LUKS container UUID is public (it is stamped in the on-disk header and
# appears in rd.luks.uuid= on the kernel cmdline) so it is safe to persist
# into the chroot for the GRUB/Limine cmdline builders — unlike the
# passphrase. Computed at fstab/crypttab-write time when encrypted.
if [ "$ENCRYPT" = "yes" ]; then
    echo "export LUKS_UUID=\"$LUKS_UUID\"" >> /mnt/tmp/chroot_env.sh
fi
# AI (Big Pickle) ADDITION — Beta-v2.5.4 [YUBIKEY]: carry the YubiKey unlock
# choices into the chroot so Stage 2 can write the keyscript-invoking crypttab
# and the dracut module. Persisted values are PUBLIC (mode, slot, challenge) —
# the challenge is not itself a credential; the HMAC response (YK_KEY) is
# never exported to chroot_env (secret-free rule, same as the passphrase).
if [ "$YK_MODE" = "hmac-sha1" ]; then
    # shellcheck disable=SC2129  # per-line appends, grouped for readability
    echo "export YK_MODE=\"$YK_MODE\"" >> /mnt/tmp/chroot_env.sh
    echo "export YK_SLOT=\"$YK_SLOT\"" >> /mnt/tmp/chroot_env.sh
    echo "export YK_CHALLENGE=\"$YK_CHALLENGE\"" >> /mnt/tmp/chroot_env.sh
    echo "export YK_FALLBACK=\"$YK_FALLBACK\"" >> /mnt/tmp/chroot_env.sh
    echo "export YK_TOUCH=\"$YK_TOUCH\"" >> /mnt/tmp/chroot_env.sh
fi
# AI (Big Pickle) ADDITION — Beta-v2.4.0 [item 9]: SESSION_STACK carried into the
# chroot so Stage 2 can branch elogind vs turnstile+seatd+acpid and validate.
# shellcheck disable=SC2129  # per-line appends, grouped for readability
echo "export SESSION_STACK=\"$SESSION_STACK\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_OCTOXBPS=\"$INSTALL_OCTOXBPS\"" >> /mnt/tmp/chroot_env.sh
echo "export BOOTLOADER=\"$BOOTLOADER\"" >> /mnt/tmp/chroot_env.sh
# Beta-v2.6.2 [GRUB-ESP-BOOT]: derived flag (grub && encrypt) carried into
# the chroot so Stage 2 picks the right grub-install --efi-directory.
echo "export GRUB_ESP_BOOT=\"$GRUB_ESP_BOOT\"" >> /mnt/tmp/chroot_env.sh
echo "export KERNEL_MODE=\"$KERNEL_MODE\"" >> /mnt/tmp/chroot_env.sh
echo "export LIMINE_WALLPAPER=\"$LIMINE_WALLPAPER\"" >> /mnt/tmp/chroot_env.sh
echo "export LIMINE_WALLPAPER_STYLE=\"$LIMINE_WALLPAPER_STYLE\"" >> /mnt/tmp/chroot_env.sh
# AI (Big Pickle) ADDITION — Beta-v2.9.47 [TEE-BOOT-QUIET]/[TEE-BLACKLIST]:
# env-only boot-cmdline knobs carried into the chroot so Stage 2 can bake the
# GRUB branch (GRUB_CMDLINE_LINUX_DEFAULT) and persist the PUBLIC limine-env
# rows the generator re-derives from.
echo "export DEFAULT_QUIET_BOOT=\"$DEFAULT_QUIET_BOOT\"" >> /mnt/tmp/chroot_env.sh
echo "export DEFAULT_TEE_BLACKLIST=\"$DEFAULT_TEE_BLACKLIST\"" >> /mnt/tmp/chroot_env.sh
echo "export SCRIPT_VERSION=\"$SCRIPT_VERSION\"" >> /mnt/tmp/chroot_env.sh
# AI (Big Pickle) ADDITION — Beta-v2.5.2 [SHELL]: carry the chosen login shell
# into the chroot so Stage 2 can install its package and set it as -s.
echo "export USER_SHELL=\"$USER_SHELL\"" >> /mnt/tmp/chroot_env.sh
echo "export USER_SHELL_PKG=\"$USER_SHELL_PKG\"" >> /mnt/tmp/chroot_env.sh
echo "export SYSPREFIX_ESP=\"$SYSPREFIX_ESP\"" >> /mnt/tmp/chroot_env.sh
echo "export SYSPREFIX_BTRFS=\"$SYSPREFIX_BTRFS\"" >> /mnt/tmp/chroot_env.sh
echo "export ROOT_PASS_HASH='$ROOT_PASS_HASH'" >> /mnt/tmp/chroot_env.sh
echo "export TARGET_PASS_HASH='$TARGET_PASS_HASH'" >> /mnt/tmp/chroot_env.sh
ROOT_PASS_HASH=""
TARGET_PASS_HASH=""
unset ROOT_PASS_HASH TARGET_PASS_HASH

# =============================================================================
# STAGE 2: INTERNAL TARGET SYSTEM PROVISIONING VIA CHROOT WRAPPER (SECTION 2 OF 6)
# =============================================================================
echo ""
echo "${C_CYN}==============================================================================${C_RST}"
echo "${C_CYN}${C_BOLD} STAGE 2: Internal target-system provisioning (inside chroot)${C_RST}"
STAGE_CONTEXT="STAGE2:chroot"
jl "Begin Stage 2 (chroot provisioning)"
echo "${C_CYN}==============================================================================${C_RST}"
echo "Crossing the chroot boundary envelope..."

chroot /mnt /bin/bash << 'CHROOT_EOF'
source /etc/profile
set -eEo pipefail
if [ -f /tmp/chroot_env.sh ]; then
    source /tmp/chroot_env.sh
    rm -f /tmp/chroot_env.sh
else
    echo "CRITICAL: BTRFS_UUID/TARGET_USER/password-hash parameters missing inside target environment. Aborting."
    exit 1
fi
# AI (Big Pickle) ADDITION — Beta-v2.9.59 [LOCAL-CACHE]: the chroot-wide cache
# arg set. An empty array = the plain network-only path (cache disabled or the
# /tmp/xbps-cache bind mount missing); install_pkgs()/install_cosmic() below are
# the ONLY two xbps entry points in the chroot, so threading -c here keeps every
# package install consistent.
_xbps_cache=()
if [ "${LOCAL_CACHE_REUSE:-no}" = "yes" ] && [ -n "${LOCAL_CACHE_DIR:-}" ] && [ -d "$LOCAL_CACHE_DIR" ]; then
    _xbps_cache=(-c "$LOCAL_CACHE_DIR")
fi
if [ -z "${TARGET_USER:-}" ] || [ -z "${TARGET_PASS_HASH:-}" ] || [ -z "${TARGET_HOSTNAME:-}" ] || [ -z "${ACCOUNT_MODEL:-}" ]; then
    echo "CRITICAL: Essential target account metadata parameters are empty. Aborting." >&2
    exit 1
fi
if [ "$ACCOUNT_MODEL" != "ubuntu" ] && [ -z "${ROOT_PASS_HASH:-}" ]; then
    echo "CRITICAL: Essential target account metadata parameters are empty. Aborting." >&2
    exit 1
fi
# AI (Claude, Sonnet 5, Medium) ADDITION: BOOTLOADER/DESKTOP_ENV/KERNEL_MODE
# previously had no hard validation here — a malformed or missing
# chroot_env.sh would silently fall through to their code's own
# defaults (Limine's "else" branch, KDE's "else" branch) rather than
# failing loudly. Since those are real per-install choices now (not
# fixed behavior), a missing value means something upstream in Stage 1
# genuinely broke, and that should stop the install rather than quietly
# substitute an assumption the person never actually chose.
if [ -z "${BOOTLOADER:-}" ] || { [ "$BOOTLOADER" != "grub" ] && [ "$BOOTLOADER" != "limine" ]; }; then
    echo "CRITICAL: BOOTLOADER is missing or invalid ('${BOOTLOADER:-<unset>}') inside target environment. Aborting." >&2
    exit 1
fi
# AI (Big Pickle) ADDITION — Beta-v2.9.48 [NO-DE]/[NO-DM]: both DESKTOP_ENV and
# DISPLAY_MANAGER now accept "none" (console-only / headless); the xorg/wayland
# base chain and the DM rc.local link are gated downstream so "none" is a
# valid in-chroot value with no dangling dependencies.
if [ -z "${DESKTOP_ENV:-}" ] || { [ "$DESKTOP_ENV" != "kde" ] && [ "$DESKTOP_ENV" != "cinnamon" ] && [ "$DESKTOP_ENV" != "gnome" ] && [ "$DESKTOP_ENV" != "xfce" ] && [ "$DESKTOP_ENV" != "mate" ] && [ "$DESKTOP_ENV" != "lxqt" ] && [ "$DESKTOP_ENV" != "cosmic" ] && [ "$DESKTOP_ENV" != "none" ]; }; then
    echo "CRITICAL: DESKTOP_ENV is missing or invalid ('${DESKTOP_ENV:-<unset>}') inside target environment. Aborting." >&2
    exit 1
fi
if [ -z "${DISPLAY_MANAGER:-}" ] || { [ "$DISPLAY_MANAGER" != "sddm" ] && [ "$DISPLAY_MANAGER" != "lightdm" ] && [ "$DISPLAY_MANAGER" != "gdm" ] && [ "$DISPLAY_MANAGER" != "cosmic-greeter" ] && [ "$DISPLAY_MANAGER" != "none" ]; }; then
    echo "CRITICAL: DISPLAY_MANAGER is missing or invalid ('${DISPLAY_MANAGER:-<unset>}') inside target environment. Aborting." >&2
    exit 1
fi
if [ "$DISPLAY_MANAGER" = "lightdm" ]; then
    if [ -z "${LIGHTDM_GREETER_PKG:-}" ] || [ -z "${LIGHTDM_GREETER_SESSION:-}" ]; then
        echo "CRITICAL: LIGHTDM greeter choice missing inside target environment for DISPLAY_MANAGER=lightdm. Aborting." >&2
        exit 1
    fi
fi
# AI (Big Pickle) ADDITION — Beta-v2.4.0 [item 9]: hard validation so a missing or
# mangled SESSION_STACK aborts in-chroot instead of silently falling through
# to whatever the default install line happens to be.
if [ -z "${SESSION_STACK:-}" ] || { [ "$SESSION_STACK" != "elogind" ] && [ "$SESSION_STACK" != "turnstile" ]; }; then
    echo "CRITICAL: SESSION_STACK is missing or invalid ('${SESSION_STACK:-<unset>}') inside target environment. Aborting." >&2
    exit 1
fi
if [ "$BOOTLOADER" = "limine" ]; then
    if [ "$KERNEL_MODE" != "esp-copy" ]; then
        echo "CRITICAL: KERNEL_MODE must be 'esp-copy' ('${KERNEL_MODE:-<unset>}') for BOOTLOADER=limine inside target environment. Aborting." >&2
        exit 1
    fi
fi
# AI (Big Pickle) ADDITION — Beta-v2.9.16 [KERNEL-SELECT]: hard-validate the
# resolved kernel set inside the chroot. It must be non-empty and every
# element must be a real Void flavor; anything else aborts rather than
# silently reconfiguring whatever the last xbps run touched.
if [ -z "${KERNEL_PKGS:-}" ]; then
    echo "CRITICAL: KERNEL_PKGS is empty ('${KERNEL_PKGS:-<unset>}') inside target environment. Aborting." >&2
    exit 1
fi
for _kp in $KERNEL_PKGS; do
    case "$_kp" in
        linux|linux-lts|linux-mainline) : ;;
        *)
            echo "CRITICAL: KERNEL_PKGS contains unknown flavor '$_kp' inside target environment. Aborting." >&2
            exit 1 ;;
    esac
done
unset _kp
# AI (Big Pickle) ADDITION — Beta-v2.9.17 [DEVICE-PROFILE]: hard-validate the
# concrete device profile + booleans; anything else would silently push a
# desktop through tlp or drop bluetooth on a laptop.
case "$DEVICE_PROFILE" in
    laptop-bt|laptop|desktop-bt|desktop) : ;;
    *)
        echo "CRITICAL: DEVICE_PROFILE is missing or invalid ('${DEVICE_PROFILE:-<unset>}') inside target environment. Aborting." >&2
        exit 1 ;;
esac
for _dpb in PROFILE_TLP PROFILE_BT PROFILE_PRELOAD POWER_PPD; do
    v="${!_dpb:-}"
    [ "$v" = "true" ] || [ "$v" = "false" ] || {
        echo "CRITICAL: ${_dpb} is missing or invalid ('${v:-<unset>}') inside target environment. Aborting." >&2
        exit 1
    }
done
unset _dpb
# AI (Big Pickle) ADDITION — Beta-v2.5.2 [SHELL]: a missing/mangled
# USER_SHELL aborts in-chroot rather than creating the account with a bogus
# -s path (the chroot consumes it directly in useradd, so it must be real).
if [ -z "${USER_SHELL:-}" ]; then
    echo "CRITICAL: USER_SHELL is missing ('${USER_SHELL:-<unset>}') inside target environment. Aborting." >&2
    exit 1
fi

# AI (Big Pickle) ADDITION — Beta-v2.4.1 [INSTALL-PKGS]: install from the first
# mirror that succeeds, retrying the live-CD package sync across the primary +
# both backup repositories (+ the Beta-v2.9.80 tertiary region fallbacks).
# Beta-v2.9.80 [MIRROR-SKEW-GUARD]: every attempt's transcript is captured to a
# temp file; when ALL mirrors fail, the failure is classified. The
# "failed to download <pkg> ' signature from <repo>: Not Found" class is the
# index-vs-pool rotation desync — transient, the mirror heals itself — so the
# full rotation is retried up to 3 more times with 15/30/45s backoff before
# FATAL. Any OTHER class (DNS/HTTP/repokey/never-exists) FAILS IMMEDIATELY —
# retrying those adds latency without value.
install_pkgs() {
    _ipkgs_ok=0
    _ipkgs_err=$(mktemp /tmp/ipkgs-transcript.XXXXXX)
    _ipkgs_skew_round=0
    while [ "$_ipkgs_ok" -ne 1 ] && [ "$_ipkgs_skew_round" -le 3 ]; do
    for _ipkgs_repo in "$REPO_PRIMARY" "$REPO_BACKUP1" "$REPO_BACKUP2" "$REPO_EXTRA1" "$REPO_EXTRA2"; do
        # AI (Big Pickle) ADDITION — Beta-v2.9.59 [LOCAL-CACHE]: ${_xbps_cache[@]}
        # is empty on a network-only run; when a /tmp/xbps-cache bind mount is
        # live, xbps takes present packages from it and falls back to the mirror.
        if xbps-install -Suy -R "$_ipkgs_repo" "${_xbps_cache[@]}" "$@" 2>&1 | tee "$_ipkgs_err"; then
            _ipkgs_ok=1
            break
        fi
        echo "==> Package install attempt against ${_ipkgs_repo} failed for: $* — trying next repository, if any." >&2
        # AI (Big Pickle) CHANGE — Beta-v2.4.1 [INSTALL-PKGS]: a mid-transaction
        # failure can leave xbps's package db marked dirty/
        # locked; refresh the index and let xbps reconcile the db before the
        # next mirror attempt, rather than replaying the same stale state and
        # failing all three mirrors for the same root cause.
        xbps-install -Sy -R "$_ipkgs_repo" "${_xbps_cache[@]}" >/dev/null 2>&1 || true
        xbps-pkgdb -a >/dev/null 2>&1 || true
    done
    if [ "$_ipkgs_ok" -eq 1 ]; then
        break
    fi
    if grep -q "failed to download .*' signature from" "$_ipkgs_err"; then
        _ipkgs_skew_round=$((_ipkgs_skew_round + 1))
        if [ "$_ipkgs_skew_round" -le 3 ]; then
            echo "==> [MIRROR-SKEW-GUARD] index-vs-pool rotation desync (signature 404 while the index resolves a version) — waiting $((_ipkgs_skew_round * 15))s for the mirror to heal, then retrying the full rotation (round ${_ipkgs_skew_round}/3)." >&2
            sleep $((_ipkgs_skew_round * 15))
        fi
    else
        break   # non-skew failure — do not retry; FATAL below
    fi
    done
    rm -f "$_ipkgs_err"
    unset _ipkgs_err _ipkgs_skew_round
    if [ "$_ipkgs_ok" -ne 1 ]; then
        echo "FATAL: package install failed against all configured repositories for: $*" >&2
        exit 1
    fi
}

# AI (Big Pickle) ADDITION — Beta-v2.4.0 [COSMIC]: COSMIC is NOT in the official
# Void repositories. It installs from the community repo at
# https://bluesloth.github.io/void-linux-cosmic/ (audit:
# https://github.com/bluesloth/void-linux-cosmic) — a repo this project signs
# and publishes itself; its COSMIC 1.10 templates are built from scratch,
# tracking upstream System76 / Pop!_OS COSMIC sources.
# The older attribution this comment used to carry applied until
# Beta-v2.9.73 [ELOGIND-RUN-SELFHEAL] repointed the URL; CHANGELOG entries
# written before that still describe the earlier era
# and are historical. Because this is a third-party signing-trust choice, this
# helper deliberately NEVER goes through install_pkgs() (which overrides -R
# with only the three official mirrors and would silently fail to reach the
# COSMIC repo). Instead it:
#   1. verifies the COSMIC repo is actually reachable at runtime, aborting
#      gracefully with install instructions + the audit link rather than
#      failing mid-install;
#   2. drops the repo config into /etc/xbps.d/;
#   3. syncs it and installs the requested COSMIC package(s) via a dedicated
#      xbps-install — answering xbps's signing-key question itself
#      (Beta-v2.9.82 [COSMIC-KEY-AUTOIMPORT]).
# The signing key is never taken on trust from that sync: Beta-v2.9.76
# [COSMIC-TRUST-ANCHOR] pins it IN this installer (DER SHA-256
# _cosmic_key_expected, not read from the served index) and the machine check
# below aborts unless the keyring holds exactly that key plus the two stock
# Void keys.
# Read a key's real fingerprint out of an xbps key plist and echo it.
# The blob decodes to PEM TEXT (not DER) -- hashing the base64-decoded bytes
# directly yields 777f5d17..., which is NOT the fingerprint xbps means. Always
# re-encode to DER first. These plists also put the blob and </data> on one
# line, so the closing tag must be substituted away; deleting that line instead
# silently drops the whole key.
cosmic_key_fingerprint() {
    local _b
    _b=$(sed -n '/<key>public-key<\/key>/,/<\/data>/p' "$1" 2>/dev/null \
         | tail -n +2 \
         | sed -e 's/.*<data>//' -e 's|</data>||' -e 's/[[:space:]]//g')
    [ -n "$_b" ] || return 1
    # Validate that this really IS an RSA public key BEFORE hashing it. Two traps
    # here, both of which silently produce a wrong-but-plausible fingerprint:
    #   * a malformed blob makes `openssl rsa` fail and emit nothing, while
    #     `openssl dgst` still reports e3b0c442... (SHA-256 of the empty string);
    #   * capturing the DER in a shell variable strips its NULL bytes, which
    #     corrupts the bytes and yields yet another bogus hash.
    # So parse with -noout first, then stream straight into dgst.
    printf '%s' "$_b" | base64 -d 2>/dev/null | openssl rsa -pubin -noout 2>/dev/null || return 1
    printf '%s' "$_b" | base64 -d 2>/dev/null \
        | openssl rsa -pubin -outform DER 2>/dev/null \
        | openssl dgst -sha256 2>/dev/null | sed 's/.*= *//'
}

install_cosmic() {
    _cosmic_repo="https://bluesloth.github.io/void-linux-cosmic/"
    _cosmic_repodata="https://bluesloth.github.io/void-linux-cosmic/x86_64-repodata"
    _cosmic_audit="https://github.com/bluesloth/void-linux-cosmic"
    # The trust anchor is PINNED here, in the installer, and is deliberately not
    # read from the repo being verified. A fingerprint fetched from the served
    # index only proves the index is self-consistent -- an attacker controlling
    # the repo would serve their own key alongside it, which is precisely the
    # substitution this constant exists to reject.
    _cosmic_keyring="/var/db/xbps/keys"
    _cosmic_key_expected="83ffd154d1dee504ea384a0c31b12e072d5884f7f75eb950e30ace852d7d2e7b"
    # Stock Void keys that legitimately occupy this keyring on a real install.
    # Extracted from a real Void masterdir, not from void-packages/common/repo-keys
    # alone. Without this allowlist the check below aborts every legitimate
    # install, because a provisioned system already trusts these two.
    _cosmic_key_stock="05473705de6456ebfdda5bd4f18155cba80bd83fca1b120cf41099693c69187b
f0da25a2877ccd5cba89e27fc744867914fd26031368a88f746f0f8096450d4d"

    if ! curl -fsSL --max-time 30 -o /dev/null "$_cosmic_repodata" 2>/dev/null; then
        echo "FATAL: the third-party COSMIC repository (${_cosmic_repo}) is not reachable right now." >&2
        echo "       Install aborted cleanly because COSMIC is a third-party repo and cannot be" >&2
        echo "       installed without it. You can still install the other desktops, or add the" >&2
        echo "       repo manually later and run:  xbps-install -S cosmic-desktop-full" >&2
        echo "       Repo docs / audit: ${_cosmic_audit}" >&2
        exit 1
    fi

    mkdir -p /etc/xbps.d
    if ! grep -q 'bluesloth.github.io' /etc/xbps.d/59-cosmic.conf 2>/dev/null; then
        echo "repository=${_cosmic_repo}" > /etc/xbps.d/59-cosmic.conf
    fi

    # Sync the (freshly added) COSMIC repo index. This is the step that imports
    # the repo's signing key.
    #
    # TRUST ANCHOR — AI (Big Pickle) CHANGE — Beta-v2.9.82
    # [COSMIC-KEY-AUTOIMPORT]: the "Do you want to import this public key?"
    # question is answered by the installer now, not by the operator.
    #
    # Why it ever reached the operator: Beta-v2.9.76 dropped -y from this sync
    # so xbps would print the fingerprint and wait for a human. Re-verified
    # 2026-10-07 on xbps 0.60.7 that -y never covered this question to begin
    # with — bare `-S` and `-Sy` both stop at [Y/n] — so the flag was never
    # what enforced anything, and Beta-v2.9.77's /dev/tty gate existed only to
    # feed that answer (its side effect: every unattended / headless COSMIC
    # install refused to run at all).
    #
    # What enforces the anchor is the MACHINE check below: the key is PINNED
    # here (DER SHA-256, deliberately not read from the served index) and the
    # sync only proceeds if the keyring holds exactly that key plus at most the
    # two stock Void keys. An operator who typed Y at a prompt showing a
    # substituted key would have trusted the attacker anyway — the prompt was
    # friction, not security. Auto-answering changes no outcome: a key that is
    # not ours still aborts through the same code path, prompt or no prompt.
    #
    # Informed consent is taken at the desktop-selection warning instead
    # (COSMIC is disclosed there as a third-party repo, "a signing-trust choice
    # made at your own risk — audit the repo before installing"), and the
    # expected fingerprint is still printed here for the log:
    #   SHA256 83ffd154d1dee504ea384a0c31b12e072d5884f7f75eb950e30ace852d7d2e7b
    # If xbps reports anything else, that is not our key — see the check below.
    #
    # AI (Big Pickle) ADDITION — Beta-v2.9.59 [LOCAL-CACHE]: the COSMIC sync also
    # honors the cache, so the third-party packages reuse it exactly like the
    # main-line ones. (Correction, verified empirically in the Beta-v2.9.65 era:
    # under xbps 0.60 the -Sy index write lands in the chroot's /var/db/xbps/<url>,
    # never in the -c cache dir — the cache contributes PAYLOAD reuse; it must
    # stay writable so mirror-fallback downloads land in it.)
    #
    # The answer is fed on a PIPE belonging to this command, never on the
    # chroot's own stdin (Stage 2 feeds this script through
    # `chroot /mnt /bin/bash << 'CHROOT_EOF'`, so stdin IS the heredoc — that
    # is what Beta-v2.9.77's `[ -t 0 ]` gate was working around) and never on
    # /dev/tty (unattended runs have none, which is why the 2.9.77 gate
    # refused them). One `printf 'y\n'` and done: a second question would then
    # see EOF and fail loudly, and `yes` would fail this pipeline under
    # `pipefail` (SIGPIPE) even after a successful sync.
    echo "==> Importing the COSMIC repository signing key (auto-answered; verified against the pin right after)."
    echo "    Expected fingerprint:"
    echo "      SHA256 ${_cosmic_key_expected}"
    if ! printf 'y\n' | xbps-install "${_xbps_cache[@]}" -Sy; then
        echo "FATAL: could not sync/trust the third-party COSMIC repository (${_cosmic_repo})." >&2
        echo "       xbps refused the repository signing key, so the install aborted" >&2
        echo "       cleanly and nothing was changed." >&2
        echo "       Repo docs / audit: ${_cosmic_audit}" >&2
        exit 1
    fi

    # Answering that question does NOT establish trust — it only removes a
    # prompt nobody needed to be asked. An operator who types 'Y' at a prompt
    # showing a substituted key still trusts the attacker, so confirm the
    # anchor MACHINE-CHECKABLY here, after the sync.
    #
    # Two conditions, both required:
    #   1. the pinned COSMIC key IS present, and
    #   2. no key outside {pinned, two stock Void keys} is present.
    # Condition 2 is an allowlist, NOT "nothing else allowed": a provisioned Void
    # system already trusts the two stock keys, so rejecting them would abort
    # every legitimate install. Condition 2 exists to catch a stale anchor from a
    # previous repo or an injected third key -- neither of which belongs here.
    _cosmic_fp_ok=0
    _cosmic_fp_bad=""
    _cosmic_fp_seen=""
    if [ -d "$_cosmic_keyring" ]; then
        for _cosmic_k in "$_cosmic_keyring"/*.plist; do
            [ -e "$_cosmic_k" ] || continue
            _cosmic_fp="$(cosmic_key_fingerprint "$_cosmic_k")"
            if [ -z "$_cosmic_fp" ]; then
                # Fail CLOSED. A keyring entry we cannot parse is a key we cannot
                # vouch for, and silently skipping it would let an attacker hide a
                # malformed key here undetected. Note libxbps only supports RSA
                # public keys, so "unparseable" means genuinely not-an-RSA-key.
                _cosmic_fp_bad="${_cosmic_fp_bad} UNREADABLE(${_cosmic_k##*/})"
                _cosmic_fp_seen="${_cosmic_fp_seen} UNREADABLE(${_cosmic_k##*/})"
                continue
            fi
            if [ "$_cosmic_fp" = "$_cosmic_key_expected" ]; then
                _cosmic_fp_ok=1
                _cosmic_fp_seen="${_cosmic_fp_seen} ${_cosmic_fp}(pinned)"
            elif printf '%s\n' "$_cosmic_key_stock" | grep -qx "$_cosmic_fp"; then
                _cosmic_fp_seen="${_cosmic_fp_seen} ${_cosmic_fp}(stock-void)"
            else
                _cosmic_fp_bad="${_cosmic_fp_bad} ${_cosmic_fp}"
                _cosmic_fp_seen="${_cosmic_fp_seen} ${_cosmic_fp}(UNEXPECTED)"
            fi
        done
    fi

    if [ "$_cosmic_fp_ok" -ne 1 ] || [ -n "$_cosmic_fp_bad" ]; then
        echo "FATAL: COSMIC repository trust anchor does not match this installer." >&2
        if [ "$_cosmic_fp_ok" -ne 1 ]; then
            echo "       Pinned key ABSENT from ${_cosmic_keyring}:" >&2
            echo "         expected SHA256 ${_cosmic_key_expected}" >&2
            echo "       Either the sync did not import it, or the repo is presenting a" >&2
            echo "       DIFFERENT key. If you are offline or mid-key-rotation, say so" >&2
            echo "       before overriding this." >&2
        fi
        if [ -n "$_cosmic_fp_bad" ]; then
            echo "       UNEXPECTED key(s) present in ${_cosmic_keyring}:" >&2
            for _cosmic_b in $_cosmic_fp_bad; do
                echo "         ${_cosmic_b}" >&2
            done
            echo "       Refusing to continue: a key you did not expect is trusted for" >&2
            echo "       these packages. Remove it and re-run, or investigate before" >&2
            echo "       trusting anything from this repo." >&2
        fi
        echo "       Keys seen:${_cosmic_fp_seen:- (none)}" >&2
        echo "       Repo docs / audit: ${_cosmic_audit}" >&2
        exit 1
    fi
    echo "==> COSMIC trust anchor verified: SHA256 ${_cosmic_key_expected}"

    if ! xbps-install "${_xbps_cache[@]}" -y "$@"; then
        echo "FATAL: xbps-install failed for COSMIC package(s): $*" >&2
        echo "       Repo docs / audit: ${_cosmic_audit}" >&2
        exit 1
    fi
}

install_pkgs xbps
update-ca-certificates --fresh
install_pkgs void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree
install_pkgs

install_pkgs nftables runit-nftables iptables polkit

# [NFT-TTL-REMOVED] (Beta-v2.8.0) — the old config wrote two per-host
# "table ip mangle" / "table ip6 mangle" blocks that hardcoded a per-machine
# TTL/hoplimit workaround tied to specific interface names that only exist on
# one developer's test machine/ISP. They match nothing on any other target and
# were non-portable cruft. Removed so this config is host-agnostic; the
# drop-by-default filter firewall (with loopback / established+related /
# rate-limited ping, and br0 / virbr* KVM forwards) is kept.
# [NFT-VIRT-GATE] (AI (Big Pickle), Beta-v2.9.19) — the br0 / virbr* KVM
# forward accepts are now a fragment emitted into the forward chain ONLY when
# virtualization was chosen ($INSTALL_VIRT=true). Both interfaces exist only
# when QEMU/libvirt is installed; on a non-virt build the unconditional
# accepts matched interfaces that never exist (dead cruft inconsistent with
# the rest of the script's $INSTALL_VIRT gating). $INSTALL_VIRT is live in the
# chroot (exported via chroot_env.sh), so the nested heredoc gates it here.
# The nftables heredoc below is UNQUOTED so ${NFT_FWD_RULES} expands.
NFT_FWD_RULES=""
if [ "$INSTALL_VIRT" = "true" ]; then
    NFT_FWD_RULES=$(cat << 'NFT_FWD_EOF'
        iifname "br0" accept
        oifname "br0" accept
        iifname "virbr*" accept
        oifname "virbr*" accept
NFT_FWD_EOF
    )
fi
# AI (Big Pickle) ADDITION — Beta-v2.9.23 [SSH-SERVER]: the sshd port accept
# is a fragment emitted into the INPUT chain ONLY when the OpenSSH server is
# enabled. The input chain is policy-drop, so merely installing sshd leaves
# it unreachable without this rule; on a no-sshd build the fragment stays
# empty and the chain stays closed (exactly the [NFT-VIRT-GATE] pattern).
# $INSTALL_SSH_SERVER / $SSH_PORT are live in the chroot (chroot_env.sh).
# Unlike NFT_FWD_RULES (pure literals, quote-tolerant), this fragment carries
# ${SSH_PORT}, so its inner heredoc is UNQUOTED — a quoted terminator would
# bake a literal "${SSH_PORT}" into nftables.conf and kill the input accept.
SSH_PORT_RULE=""
if [ "$INSTALL_SSH_SERVER" = "true" ]; then
    SSH_PORT_RULE=$(cat << SSH_PORT_EOF
        tcp dport "${SSH_PORT}" ct state new accept
SSH_PORT_EOF
    )
fi
cat > /etc/nftables.conf << INNER_EOF
#!/usr/sbin/nft -f
flush ruleset

table inet filter {
    chain input {
        type filter hook input priority filter; policy drop;
        iif "lo" accept
        iif != "lo" ip daddr 127.0.0.0/8 drop
        iif != "lo" ip6 daddr ::1 drop
        ct state established,related accept
        ct state invalid drop
        ip protocol icmp icmp type echo-request counter limit rate 1/second burst 5 packets accept
        meta l4proto ipv6-icmp accept
${SSH_PORT_RULE}
    }
    chain forward {
        type filter hook forward priority filter; policy drop;
${NFT_FWD_RULES}
    }
    chain output {
        type filter hook output priority filter; policy accept;
    }
}
INNER_EOF

# AI (Big Pickle) ADDITION — Beta-v2.9.29 [NFT-VIRT-PRINT]: on a virtualization
# build, print the generated /etc/nftables.conf to the terminal right after it is
# written, so the operator can confirm the br0/virbr* forward accepts landed (and
# that the INSTALL_VIRT export path through chroot_env.sh worked end-to-end). A
# non-virt build stays silent — the forward chain is just the drop rule, nothing
# runtime-specific to review. Doubles as a live-validation artifact.
if [ "$INSTALL_VIRT" = "true" ]; then
    echo ""
    echo "--- /etc/nftables.conf (virtualization build: br0/virbr* forwards present) ---"
    cat /etc/nftables.conf
    echo "--- end nftables.conf ---"
fi

# AI (Big Pickle) ADDITION — Beta-v2.9.23 [SSH-SERVER]: optional OpenSSH
# server install + config. The input chain above already carries the
# ${SSH_PORT_RULE} accept when INSTALL_SSH_SERVER=true; here we install
# openssh and write a drop-in with the chosen port + access policy. Void's
# /etc/sv/sshd generates host keys on first start, so no keygen needed.
if [ "$INSTALL_SSH_SERVER" = "true" ]; then
    install_pkgs openssh
    SSH_DROP="/etc/ssh/sshd_config.d/10-void-installer.conf"
    mkdir -p /etc/ssh/sshd_config.d
    if ! grep -q '^Include /etc/ssh/sshd_config.d/\*.conf' /etc/ssh/sshd_config 2>/dev/null; then
        echo "" >> /etc/ssh/sshd_config
        echo "Include /etc/ssh/sshd_config.d/*.conf" >> /etc/ssh/sshd_config
    fi
    cat > "$SSH_DROP" << INNER_EOF
# Void_Linux_Installer.sh v${SCRIPT_VERSION} [SSH-SERVER] (Beta-v2.9.23)
Port ${SSH_PORT}
PasswordAuthentication ${SSH_PASSWORD_AUTH}
PermitRootLogin ${SSH_ROOT_LOGIN}
INNER_EOF
    chmod 0644 "$SSH_DROP"
    echo "==> OpenSSH configured (port ${SSH_PORT}) → ${SSH_DROP}"
fi

# AI (Big Pickle) ADDITION — Beta-v2.9.23 [SSH-KEYS]: deposit any staged SSH
# key material into the target user's ~/.ssh with correct perms, then shred
# the TARGET staging copies (in the chroot, /tmp == the target's /mnt/tmp —
# the transplanted copies; the LIVE /tmp original stage is shredded by the
# parent script after the chroot exits, and by cleanup_on_failure on abort).
# Guarded on the account existing (created earlier).
# AI (Big Pickle) FIX — Beta-v2.9.34 [SSH-DEPOSIT-LOG]: the old presence guard
# (`[ -d /tmp/ssh-import ] && [ -n "$(ls -A /tmp/ssh-import 2>/dev/null)" ]`)
# used a `ls -A` subshell that was fragile under `set -eEo pipefail` and gave
# ZERO diagnostic output when the deposit was silently skipped. Detection now
# uses `find -quit` (no subshell, no pipefail hazard) and a missing account
# logs an explicit WARNING.
if [ -n "$(find /tmp/ssh-keygen -maxdepth 1 -type f 2>/dev/null -print -quit)" ] || \
   [ -n "$(find /tmp/ssh-import -maxdepth 1 -type f 2>/dev/null -print -quit)" ]; then
    if [ -n "$TARGET_USER" ] && id -u "$TARGET_USER" >/dev/null 2>&1; then
        _ssh_dir="/home/${TARGET_USER}/.ssh"
        mkdir -p "$_ssh_dir"
        chmod 0700 "$_ssh_dir"
        if [ -f /tmp/ssh-keygen/id_ed25519 ]; then
            cp -f /tmp/ssh-keygen/id_ed25519 "$_ssh_dir/id_ed25519"
            cp -f /tmp/ssh-keygen/id_ed25519.pub "$_ssh_dir/id_ed25519.pub"
            chmod 0600 "$_ssh_dir/id_ed25519"
            chmod 0644 "$_ssh_dir/id_ed25519.pub"
            echo "==> Generated key deposited → ${TARGET_USER}/.ssh/id_ed25519"
        fi
        if [ -f /tmp/ssh-import/imported ]; then
            cp -f /tmp/ssh-import/imported "$_ssh_dir/imported"
            chmod 0600 "$_ssh_dir/imported"
            [ -f /tmp/ssh-import/imported.pub ] && cp -f /tmp/ssh-import/imported.pub "$_ssh_dir/imported.pub" && chmod 0644 "$_ssh_dir/imported.pub"
            echo "==> Imported key deposited → ${TARGET_USER}/.ssh/imported"
        fi
        # AI (Big Pickle) FIX — Beta-v2.9.88 [SSH-USABLE]: a deposited key used
        # to sit inert in ~/.ssh: ssh never picked up "imported" (non-standard
        # name, no IdentityFile) and the public half was never trusted anywhere,
        # so the "install my key" flow could not actually log into the fresh box.
        # Two wiring steps make the installed key usable out of the box:
        #   1. IdentityFile entries in ~/.ssh/config for whichever keys landed,
        #      so ssh uses them without -i (append-only; a pre-existing config
        #      is preserved);
        #   2. the imported public key appended to ~/.ssh/authorized_keys, so
        #      logging INTO this box with that key works from any client that
        #      holds its private half.
        _ssh_cfg_written="no"
        if [ -f "$_ssh_dir/id_ed25519" ] || [ -f "$_ssh_dir/imported" ]; then
            [ -f "$_ssh_dir/config" ] || : > "$_ssh_dir/config"
            chmod 0600 "$_ssh_dir/config"
            for _kname in id_ed25519 imported; do
                [ -f "$_ssh_dir/$_kname" ] || continue
                if ! grep -qE "^[[:space:]]*IdentityFile[[:space:]]+.*${_kname}([[:space:]]|$)" "$_ssh_dir/config"; then
                    printf 'IdentityFile ~/.ssh/%s\n' "$_kname" >> "$_ssh_dir/config"
                    _ssh_cfg_written="yes"
                fi
            done
        fi
        [ "$_ssh_cfg_written" = "yes" ] && echo "==> ~/.ssh/config IdentityFile(s) written for the installed key(s)"
        if [ -f "$_ssh_dir/imported.pub" ]; then
            touch "$_ssh_dir/authorized_keys"
            chmod 0600 "$_ssh_dir/authorized_keys" 2>/dev/null || true
            _imp_ak_line="$(cat "$_ssh_dir/imported.pub")"
            if ! grep -qF -- "$_imp_ak_line" "$_ssh_dir/authorized_keys"; then
                printf '%s\n' "$_imp_ak_line" >> "$_ssh_dir/authorized_keys"
                echo "==> Imported public key added to ${TARGET_USER}/.ssh/authorized_keys (key login enabled)"
            fi
            unset _imp_ak_line
        fi
        chown -R "${TARGET_USER}:${TARGET_USER}" "$_ssh_dir"
        unset _ssh_cfg_written _kname
    else
        echo "WARNING: SSH keys staged but target account '${TARGET_USER:-<unset>}' missing — keys NOT deposited." >&2
    fi
    # Shred the target staging copies (/tmp inside the chroot).
    shred -u /tmp/ssh-keygen/id_ed25519* /tmp/ssh-import/imported* 2>/dev/null || true
    rm -rf /tmp/ssh-keygen /tmp/ssh-import
fi

echo "${TARGET_HOSTNAME}" > /etc/hostname

if [ "$TARGET_FQDN" != "$TARGET_HOSTNAME" ]; then
    HOSTS_LINE="127.0.1.1       ${TARGET_FQDN} ${TARGET_HOSTNAME}"
else
    HOSTS_LINE="127.0.1.1       ${TARGET_HOSTNAME}"
fi

cat > /etc/hosts << INNER_EOF
127.0.0.1       localhost
${HOSTS_LINE}
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
INNER_EOF

# AI (Big Pickle) CHANGE — Beta-v2.4.0 [LOCALIZE]: real localization. The chosen
# timezone is symlinked (falling back to UTC if the zone is absent from tzdata),
# and the chosen locale is generated + activated as the system language.
if [ -e "/usr/share/zoneinfo/${TIMEZONE}" ]; then
    ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
else
    echo "WARNING: timezone '${TIMEZONE}' not found in tzdata; leaving /etc/localtime unset (UTC)." >&2
fi
# Enable the chosen locale in Void's generation list. Delete any stale entry
# (commented or active) for this locale, then append the active line, so the
# generation is both idempotent and correct for any selected locale.
LOCALE_ENTRY="${LOCALE} ${LOCALE_CODESET}"
LOCALE_ESC="$(printf '%s' "${LOCALE}" | sed 's/[.[\*^$]/\\&/g')"
sed -i "/^[#[:space:]]*${LOCALE_ESC}[[:space:]]/d" /etc/default/libc-locales 2>/dev/null || true
echo "${LOCALE_ENTRY}" >> /etc/default/libc-locales
xbps-reconfigure -f glibc-locales
# Activate the chosen language as the system's default LANG.
echo "LANG=${LOCALE}" > /etc/locale.conf
# AI (Big Pickle) ADDITION — Beta-v2.6.9 [KEYMAP]: pin the installed system's
# console keymap to the live console's, so the boot passphrase prompt (and the
# regular console) map keys identically to how the LUKS passphrase was entered
# at install. Void (runit) drives this from /etc/rc.conf KEYMAP (loaded by
# /etc/runit/core-services/03-console-setup.sh via loadkeys). Written here on
# the chroot side from KEYMAP_LIVE captured live.
[ -n "${KEYMAP_LIVE:-}" ] || KEYMAP_LIVE="us"
sed -i "s/^[[:space:]]*#\?[[:space:]]*KEYMAP=.*/KEYMAP=\"${KEYMAP_LIVE}\"/" /etc/rc.conf 2>/dev/null || true
if ! grep -q '^KEYMAP=' /etc/rc.conf 2>/dev/null; then
    printf 'KEYMAP="%s"\n' "${KEYMAP_LIVE}" >> /etc/rc.conf
fi

[ "$INSTALL_VIRT" = "true" ] && install_pkgs qemu libvirt virt-manager

# AI (Big Pickle) ADDITION — Beta-v2.5.2 [SHELL]: install the chosen login
# shell's package if any (empty USER_SHELL_PKG = the bundled bash, nothing to
# install), before useradd so the selected shell binary already exists in the
# target when the account is created.
[ -n "$USER_SHELL_PKG" ] && install_pkgs "$USER_SHELL_PKG"

USER_GROUPS="adm,video,audio"
[ "$ACCOUNT_MODEL" != "debian" ] && USER_GROUPS="wheel,${USER_GROUPS}"
[ "$INSTALL_VIRT" = "true" ] && USER_GROUPS="${USER_GROUPS},kvm,libvirt"
useradd -m -G "$USER_GROUPS" -s "$USER_SHELL" -c "${TARGET_FULL_NAME:-$TARGET_USER}" "$TARGET_USER"

# AI (Big Pickle) ADDITION — Beta-v2.9.58 [HOME-SELF-CHOWN]: useradd -m creates
# /home/$TARGET_USER itself as root:root mode 755, and this script's adopt-own
# chowns only touch the home's SUBDIRECTORIES (~/Games, ~/.config, ~/.local,
# ~/Documents, …). On a carved @home subvol the home dir ITSELF therefore
# stays root-owned after Stage-1 — which on `<host>` (Beta-v2.9.57 era) made the
# account unable to write .Xauthority/.dmrc/.xsession-errors → X auth failed →
# every mate-session login exited 1 in ~0.02s (lightdm.log "Exited with return
# value 1"), and the greeter looked like a "wrong password" bug. The password
# was never wrong. FIX: chown the home dir itself here right after useradd
# (mirrors the ~/Games + .cache/@containers-user adopt-own pattern). This is
# the installer-side fix; the equivalent live-chown (find -xdev, numeric uid
# 1000) is what was proven on the box.
chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}"

# AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS]: when the games region is
# carved, ~/Games is a freshly-mkfs'd partition mounted plain — it is
# root-owned after Stage-1, so adopt-own it here right after useradd (mirrors
# the .cache/@containers-user chown pattern). Non-carved installs have a plain
# ~/Games dir already owned via @home's chown, so nothing to do.
case " ${REGION_PARTITIONED:-} " in
    *" games "*)
        mkdir -p "/home/${TARGET_USER}/Games"
        chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/Games"
        ;;
esac

# AI (Big Pickle) ADDITION — Beta-v2.9.13 [ACCTSVCS-ICON]: give the user's
# org.freedesktop.Accounts entry a real default avatar. The COSMIC greeter
# (and the LightDM Slick/GTK greeters) read the user's icon from
# /var/lib/AccountsService/icons/<username>; a clean useradd never writes it,
# and accounts-daemon does not synthesize one, so on `<host>` the greeter logged
# `failed to open icon ".../icons/<user>": NotFound` at every startup. No
# first-boot rc.local path runs before the greeter, so the icon is provisioned
# here, right after useradd. The source is the themed `avatar-default` graphic
# from the desktop's fallback icon set — Adwaita first (present wherever GTK
# is, and what light/dark greeters already render by default), then Pop
# (COSMIC's Pop theme, which overrides Adwaita). Absent both, the copy is
# simply skipped and the greeter falls back to its own drawn placeholder.
if [ -n "${TARGET_USER:-}" ]; then
    _acct_icon_src="/usr/share/icons/Adwaita/scalable/status/avatar-default.svg"
    [ -f "$_acct_icon_src" ] || _acct_icon_src="/usr/share/icons/Pop/scalable/status/avatar-default-symbolic.svg"
    if [ -f "$_acct_icon_src" ]; then
        mkdir -p /var/lib/AccountsService/icons 2>/dev/null || true
        cp "$_acct_icon_src" "/var/lib/AccountsService/icons/${TARGET_USER}"
        chmod 0644 "/var/lib/AccountsService/icons/${TARGET_USER}"
    fi
    unset _acct_icon_src
fi

# AI (Big Pickle) ADDITION — Beta-v2.5.4 [ZSHRC]: when zsh is the login
# shell, pre-create a minimal ~/.zshrc so the user's first interactive
# session doesn't dump them into zsh's zsh-newuser-install wizard. Void's
# zsh package ships NO /etc/zsh/newuser.zshrc.recommended (a user then picks
# "create blank .zshrc", "recommended by admin", or "quit + touch ~/.zshrc"
# — the "instructions to touch ~/.zshrc" message), and useradd -m leaves the
# home dir with no zsh startup files — so every fresh zsh login previously
# fired the wizard. The mere presence of ~/.zshrc suppresses it (the
# zsh/newuser module halts once any of .zshenv/.zprofile/.zshrc/.zlogin
# exists). Written with the user's ownership to match useradd -m. Only
# created when zsh is the chosen shell.
if [ "$USER_SHELL" = "/bin/zsh" ]; then
    cat > "/home/${TARGET_USER}/.zshrc" << INNER_EOF
# Minimal default ~/.zshrc — created by Void_Linux_Installer so the
# zsh-newuser-install wizard doesn't fire on first login. Edit freely.
# History.
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
# Completion.
autoload -Uz compinit
compinit
# Aliases.
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -lh'
INNER_EOF
    chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.zshrc"
fi
# AI (Big Pickle) ADDITION — Beta-v2.5.4 [ZSHRC]: fish also ships a
# first-run config wizard (fish_config) that fires on first interactive
# start when ~/.config/fish/config.fish is absent, plus fish prints a
# notice that the file will be created. The mere presence of
# ~/.config/fish/config.fish suppresses both — so when fish is the chosen
# shell, pre-create a minimal one with the user's ownership to match
# useradd -m. bash/mksh are unaffected (bash ships /etc/skel dotfiles and
# a system /etc/bash.bashrc; mksh has no interactive-first-run wizard).
if [ "$USER_SHELL" = "/usr/bin/fish" ]; then
    mkdir -p "/home/${TARGET_USER}/.config/fish"
    cat > "/home/${TARGET_USER}/.config/fish/config.fish" << INNER_EOF
# Minimal default ~/.config/fish/config.fish — created by
# Void_Linux_Installer so the fish_config wizard doesn't fire on first
# login. Edit freely.
set fish_greeting
abbr -a ll 'ls -lah'
abbr -a la 'ls -A'
abbr -a l 'ls -lh'
INNER_EOF
    chown -R "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.config/fish"
fi

if [ "$ACCOUNT_MODEL" = "ubuntu" ]; then
    passwd -l root
else
    echo "root:${ROOT_PASS_HASH}" | chpasswd -e
fi
echo "${TARGET_USER}:${TARGET_PASS_HASH}" | chpasswd -e
ROOT_PASS_HASH=""
TARGET_PASS_HASH=""
unset ROOT_PASS_HASH TARGET_PASS_HASH

if [ "$ACCOUNT_MODEL" != "debian" ]; then
    mkdir -p /etc/sudoers.d
    echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
    chmod 440 /etc/sudoers.d/wheel
fi

# AI (Big Pickle) CHANGE — Beta-v2.9.86 [BR0-SKIP]: no br0 profile on a skip
# → no allowlist entry for a bridge that will never exist (harmless either
# way, but the artifacts should tell one consistent story).
if [ "$INSTALL_VIRT" = "true" ] && [ -n "${NET_INTERFACE_MATCH:-}" ]; then
mkdir -p /etc/qemu
cat > /etc/qemu/bridge.conf << 'INNER_EOF'
allow br0
INNER_EOF
chmod 0640 /etc/qemu/bridge.conf
[ -f /usr/libexec/qemu-bridge-helper ] && chmod 4755 /usr/libexec/qemu-bridge-helper
fi


if [ "$INSTALL_VIRT" = "true" ]; then
mkdir -p /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/50-libvirt.rules << 'INNER_EOF'
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.libvirt.unix.manage") === 0 &&
        subject.isInGroup("libvirt")) {
        return polkit.Result.YES;
    }
});
INNER_EOF
chmod 644 /etc/polkit-1/rules.d/50-libvirt.rules
fi

# AI (Big Pickle) ADDITION — Beta-v2.9.27 [CPU-DETECT]: honor the live-box
# microcode decision verbatim (including a decided-empty opt-out) unless this
# is a resume from a pre-2.9.27 state file that never recorded MICROCODE_DECIDED
# — then re-derive from the target's own /proc/cpuinfo. [RECONSTRUCTED]: Solar
# Pro 4's 2.9.27 draft exported MICROCODE_DECIDED but never consumed it here,
# so the chroot unconditionally re-derived (an opt-out was silently overruled);
# this guard is the documented behavior restored.
if [ -z "${MICROCODE_DECIDED:-}" ]; then
    CPU_VENDOR=$(grep -m1 vendor_id /proc/cpuinfo | awk '{print $3}')
    case "$CPU_VENDOR" in
        GenuineIntel) MICROCODE_PKG="intel-ucode" ;;
        AuthenticAMD) MICROCODE_PKG="linux-firmware-amd" ;;
        *) echo "WARNING: unrecognized CPU vendor '${CPU_VENDOR}', skipping microcode package." >&2
           MICROCODE_PKG="" ;;
    esac
fi
install_pkgs ${MICROCODE_PKG} linux-firmware dracut sudo vim nano bash bash-completion curl
# AI (Big Pickle) ADDITION — Beta-v2.5.5 [ENCRYPT]: install the userspace
# cryptsetup/LUKS tooling into the target only when encryption was enabled
# (the dracut `crypt` module needs the cryptsetup binary + udev rules to
# unlock the volume at boot). Not installed for the unencrypted default.
[ "$ENCRYPT" = "yes" ] && install_pkgs cryptsetup
# AI (Big Pickle) ADDITION — Beta-v2.9.43 [INNER-PARTSCAN-BOOT]: when the inner
# GPT (MULTI-FS + ENCRYPT) needs a boot-time partscan, parted must ship IN THE
# TARGET so the 98void-inner-partscan dracut module's module-setup.sh can
# `inst_binary partprobe` and `inst_binary kpartx` (Beta-v2.9.56: kpartx is the
# PRIMARY inner-partition registration tool — it builds dm-linear submaps from
# the on-disk GPT off the opened mapper via dmsetup; partprobe's BLKPG and
# `partx -a` alone cannot probe a dm mapper). Gate exactly like the module:
# ENCRYPT + carved REGION_PARTITIONED.
[ "$ENCRYPT" = "yes" ] && [ -n "${REGION_PARTITIONED:-}" ] && install_pkgs kpartx parted
# AI (Big Pickle) ADDITION — Beta-v2.5.4 [YUBIKEY]: install the C-only
# `yubikey-personalization` (ykpers) tools (ykpersonalize for enrolling already
# ran on the live medium; ykchalresp is what the initramfs keyscript calls at
# boot). C + libusb only, so it fits cleanly in the dracut initramfs — the same
# tool is used at both enroll and boot to keep hmac-lt64 consistent.
[ "$YK_MODE" = "hmac-sha1" ] && install_pkgs ykpers

# AI (Big Pickle) ADDITION — Beta-v2.9.25 [NVIDIA-GATE]: the one probe-gated
# driver. `nvidia` (nonfree) auto-pulls nvidia-dkms → dkms (gcc/make/
# linux-headers). The headers for every installed kernel flavor are mapped
# from $KERNEL_PKGS so dkms can build at install time for all of them.
if [ "$INSTALL_NVIDIA" = "true" ]; then
    install_pkgs nvidia
    case "$KERNEL_PKGS" in
        *linux-mainline*) install_pkgs linux-mainline-headers ;;
        *linux-lts*) install_pkgs linux-lts-headers ;;
        *linux*) install_pkgs linux-headers ;;
    esac
    # Blacklist nouveau so the open driver cannot bind the device ahead of
    # the proprietary module (nvidia-dkms installs the udev rules + binary
    # that prefers the nvidia module once loaded).
    cat > /etc/modprobe.d/50-nvidia.conf << 'INNER_EOF'
# Void_Linux_Installer.sh — [NVIDIA-GATE] Beta-v2.9.25
# Proprietary driver chosen at install time; keep nouveau from binding first.
blacklist nouveau
options nouveau modeset=0
INNER_EOF
    chmod 0644 /etc/modprobe.d/50-nvidia.conf
fi

# AI (Big Pickle) ADDITION — Beta-v2.9.26 [WIFI-FW]: close the Broadcom
# firmware gap (the ONE vendor void's default linux-firmware split doesn't
# cover). ${WIFI_FW_PKG} is empty on every non-Broadcom build, so this is
# exactly the "found Broadcom + accepted" case.
[ "$INSTALL_WIFI_FW" = "true" ] && [ -n "$WIFI_FW_PKG" ] && install_pkgs "$WIFI_FW_PKG"

# AI (Claude, Sonnet 5, Medium) ADDITION: sddm/NetworkManager/dbus/elogind
# are DE-agnostic base bits both options need. wayland/wayland-protocols
# AND xorg are both installed unconditionally too, deliberately NOT gated
# to KDE. VERIFIED against Void's own Wayland handbook page and real user
# reports: Void currently packages Cinnamon as X11-only (no Wayland
# session shipped yet, even though upstream Cinnamon itself is moving
# that direction) — so today, xorg is what Cinnamon's session actually
# needs. wayland/wayland-protocols stay installed anyway rather than
# gated: it costs nothing and means this script doesn't need revisiting
# the day Void's cinnamon package does add a Wayland session. The actual
# desktop metapackage and KDE-only companions (kde-baseapps, ark,
# kio-admin — Dolphin/archive/polkit-KIO integration with no meaning
# outside Plasma) are gated on $DESKTOP_ENV.
# Cinnamon has no equivalent companion packages to add here — cinnamon-all
# (installed below) already pulls in Nemo, cinnamon-settings-daemon,
# muffin, etc. as dependencies.
# AI (Big Pickle) CHANGE — Beta-v2.4.0 [item 9]: session/seat
# management is now a real choice. Default (elogind) installs the
# logind-fork as before. The alternative installs turnstile (user-session
# supervisor), seatd (graphical seat/input), and acpid (ACPI/power events)
# and omits elogind entirely. The two stacks are mutually exclusive — never
# both, they'd double-manage sessions and the seat.
# AI (Big Pickle) CHANGE — Beta-v2.9.48 [HEADLESS]/[HEADLESS-XORG-OPT]: the
# Xorg/Wayland base chain is gated on HAS_GRAPHICAL=yes OR the INSTALL_XORG
# opt-in flag on a headless box. A fully-headless box (DESKTOP_ENV=none AND
# DISPLAY_MANAGER=none) with both flags OFF skips wayland/xorg entirely and
# installs only the session stack (elogind or turnstile+seatd+acpid) plus the
# network layer — a lean, dependency-light server.
# AI (Big Pickle) FIX — Beta-v2.9.60 [RESUME-GFX-FLAGS]: on a resumed (-r)
# install, HAS_GRAPHICAL/INSTALL_XORG/INSTALL_AUDIO are NOT in the resume state
# file, so after `source /tmp/chroot_env.sh` they can be empty (chroot_env was
# written empty on the resume path). Nothing actually defaults them — the
# "in-chroot defaults" the HEADLESS feature claimed to add (the :-fallbacks in
# the install-config heredoc below) live INSIDE that heredoc, so they only
# print to the config file and are never executed as shell assignments. A
# resumed graphical install therefore silently took the headless else-branch
# and skipped the Xorg/Wayland base chain (xorg-server/mesa never installed →
# SDDM "Failed to start display server process" → no greeter on an otherwise
# good LUKS boot). Recompute HAS_GRAPHICAL deterministically from
# DESKTOP_ENV/DISPLAY_MANAGER (both ARE persisted), then apply the same
# fallbacks the config-print claims.
if [ -z "${HAS_GRAPHICAL:-}" ]; then
    if { [ "${DESKTOP_ENV:-none}" = "none" ] && [ "${DISPLAY_MANAGER:-none}" = "none" ]; }; then
        HAS_GRAPHICAL="no"
    else
        HAS_GRAPHICAL="yes"
    fi
fi
INSTALL_XORG="${INSTALL_XORG:-false}"
INSTALL_AUDIO="${INSTALL_AUDIO:-true}"
export HAS_GRAPHICAL INSTALL_XORG INSTALL_AUDIO
if [ "$HAS_GRAPHICAL" = "yes" ] || [ "${INSTALL_XORG:-false}" = "true" ]; then
    if [ "$SESSION_STACK" = "elogind" ]; then
        install_pkgs wayland wayland-protocols NetworkManager dbus elogind xorg
    else
        install_pkgs wayland wayland-protocols NetworkManager dbus turnstile seatd acpid xorg
    fi
else
    # Headless, no Xorg opt-in: install only the session stack and network layer.
    if [ "$SESSION_STACK" = "elogind" ]; then
        install_pkgs NetworkManager dbus elogind
    else
        install_pkgs NetworkManager dbus turnstile seatd acpid
    fi
fi

# AI (Big Pickle) ADDITION — Beta-v2.4.0 [items 1 & 6]: the display manager is a
# real choice ($DISPLAY_MANAGER, Stage 1) with three options now (sddm,
# lightdm, gdm). Each branch installs exactly its chosen DM and populates
# DM_SERVICE_NAME, used later in rc.local to link exactly ONE display
# manager's runit service — they must never both be linked, or they'd fight
# over the same VT/seat.
#
# Beta-v2.4.0 fixes: the LightDM branch previously hard-attempted the Slick
# greeter with a three-repo install loop under `set -e` and a fallback — a
# fragile construction that could fail an install and, when it succeeded,
# silently ignored the fallback path. The greeter is now chosen explicitly
# in Stage 1 (LIGHTDM_GREETER_PKG / LIGHTDM_GREETER_SESSION) and installed
# directly through install_pkgs — no loop, no silent fallback, honoring the
# user's choice exactly.
if [ "$DISPLAY_MANAGER" = "lightdm" ]; then
    # accountsservice is a hard dependency of lightdm, but is named
    # explicitly here too so the accounts-daemon service provisioning below
    # never races a transitive-pull that a future lightdm template change
    # could drop.
    install_pkgs lightdm accountsservice "$LIGHTDM_GREETER_PKG"

    # AI (Big Pickle) NOTE: LightDM's own default-session
    # mechanism (the `user-session=` key below) is more limited than
    # SDDM's per-user state.conf approach used elsewhere in this script —
    # it sets one global default for the seat, not a specific user. Set to
    # each DE's plain session when one is the chosen desktop; left unset
    # (LightDM's own default) for KDE, since this script's LightDM path is
    # not the primary tested one for Plasma.
    mkdir -p /etc/lightdm
    case "$DESKTOP_ENV" in
        cinnamon) _lightdm_user_session="cinnamon" ;;
        gnome)    _lightdm_user_session="gnome" ;;
        xfce)     _lightdm_user_session="xfce" ;;
        mate)     _lightdm_user_session="mate" ;;
        lxqt)     _lightdm_user_session="lxqt" ;;
        *)        _lightdm_user_session="" ;;
    esac
    {
        echo "[Seat:*]"
        echo "greeter-session=${LIGHTDM_GREETER_SESSION}"
        [ -n "$_lightdm_user_session" ] && echo "user-session=${_lightdm_user_session}"
        # AI (Big Pickle) FIX — Beta-v2.5.0 [LIGHTDM-SWRAP]: the generated
        # conf above OVERWRITES Void's package-default lightdm.conf, which is
        # what normally carries `session-wrapper=/etc/lightdm/Xsession`.
        # Without an explicit session-wrapper, LightDM 1.32 falls back to its
        # compiled-in default wrapper name `lightdm-session` — a binary Void
        # does NOT ship (Void's lightdm package provides /etc/lightdm/Xsession
        # instead). Missing wrapper => every user session (Cinnamon X11,
        # software-rendering, and wayland alike) fails to exec instantly:
        # black flash, back to the greeter, entirely empty .xsession-errors.
        # Setting the wrapper explicitly to the file Void actually provides is
        # required for any LightDM login to start a desktop at all.
        echo "session-wrapper=/etc/lightdm/Xsession"
    } > /etc/lightdm/lightdm.conf.tmp
    # AI (Big Pickle) FIX — Beta-v2.5.2 [LIGHTDM-ATOMIC]: atomic write. The
    # direct `>` redirect could truncate this load-bearing config (it carries
    # the mandatory session-wrapper from [LIGHTDM-SWRAP]) on a mid-write
    # interruption; write to a temp file then rename into place.
    mv -f /etc/lightdm/lightdm.conf.tmp /etc/lightdm/lightdm.conf
    # AI (Big Pickle) CHANGE — Beta-v2.5.0 [LIGHTDM-HW]: three real-hardware
    # LightDM greeter failures on a Cinnamon install, as-is /var/lib/lightdm
    # ownership would have been root-owned here:
    #   1. /var/lib/lightdm is the freshly-created @lightdm btrfs subvolume,
    #      which is root-owned by default — the lightdm:lightdm mkdir/chown
    #      the void lightdm package records in make_dirs is applied at
    #      unpack time to the empty dir on the @ root, NOT to the subvolume
    #      mounted over it at boot. An unwritable lightdm homedir breaks
    #      greeter session/Xauthority handling and shows up as greeter
    #      failures (including login refused for the correct password).
    #      Fix: bake correct ownership into the subvolume now.
    #   2. WebKit2 greeter theme errors ("neither primary nor fallback
    #      work"): Void's lightdm-webkit2-greeter ships its theme renamed
    #      antergos -> void (see its srcpkgs template post_extract), but the
    #      package's default conf still references a theme name that does
    #      not exist under that name. Fix: write a conf that points
    #      webkit-theme at the actually-installed void theme.
    #      [GREETER-NO-WEBKIT2] Beta-v2.9.1: this whole item is now MOOT —
    #      the WebKit2 greeter was removed from the installer (abandoned
    #      upstream, black-screens against current webkit2gtk), so no
    #      webkit-theme conf is generated anymore.
    #   3. Slick greeter hang AND GTK greeter auth flakiness: both depend on
    #      org.freedesktop.Accounts, which Void ships with NO runit service
    #      — only a D-Bus activation file, so the greeter's very first
    #      Accounts request D-Bus-activates accounts-daemon at the instant
    #      the system bus is still coming up, and that activation times out
    #      (known Void bug, void-packages#59538 — black screen then hang, or
    #      25s-delayed login UI). The visible "zramen#info: Attempting to
    #      find zram module - not part of kernel" line on a hung greeter
    #      screen is unrelated first-boot console INFO from zramen (the
    #      module is simply not yet loaded at that instant; zramen then
    #      modprobes it in a loop and, once loaded, proceeds normally — the
    #      KDE+SDDM+zram wing of this same machine proves zram works). Fix:
    #      provision a real runit service for accounts-daemon below so it is
    #      supervised up-front on first boot instead of D-Bus-activated on
    #      demand (linked by rc.local, see [LIGHTDM-HW] there).
    chown lightdm:lightdm /var/lib/lightdm 2>/dev/null || \
        echo "WARNING: could not chown /var/lib/lightdm to lightdm:lightdm — greeter may misbehave." >&2

    _accd_bin=""
    for _accd_cand in /usr/libexec/accounts-daemon /usr/lib/accounts-daemon; do
        [ -x "$_accd_cand" ] && { _accd_bin="$_accd_cand"; break; }
    done
    if [ -n "$_accd_bin" ]; then
        mkdir -p /etc/sv/accounts-daemon
        cat > /etc/sv/accounts-daemon/run << 'ACCD_EOF'
#!/bin/sh
exec 2>&1
sv check dbus >/dev/null || exit 1
exec __ACCD_BIN__
ACCD_EOF
        sed -i "s|__ACCD_BIN__|${_accd_bin}|" /etc/sv/accounts-daemon/run
        chmod 0755 /etc/sv/accounts-daemon/run
    else
        echo "WARNING: accounts-daemon binary not found — LightDM greeters will rely on D-Bus activation (boot race may resurface)." >&2
    fi
    unset _accd_bin _accd_cand
    DM_SERVICE_NAME="lightdm"
elif [ "$DISPLAY_MANAGER" = "gdm" ]; then
    # AI (Big Pickle) CORRECTION — Beta-v2.5.2 [GDM-WAY]: gdm-wayland-session
    # does NOT exist as a Void package (only `gdm` is in the repo, verified
    # against the current binary index). Listing it aborted the whole DM
    # install for a GDM choice. `gdm` alone is what Void ships.
    install_pkgs gdm
    DM_SERVICE_NAME="gdm"
elif [ "$DISPLAY_MANAGER" = "cosmic-greeter" ]; then
    # AI (Big Pickle) ADDITION — Beta-v2.4.0 [COSMIC]: cosmic-greeter is COSMIC's
    # own greeter, available only from the third-party COSMIC repo (NOT the
    # official mirrors, so it cannot go through install_pkgs). The honored
    # DISPLAY_MANAGER value matches the package name. install_cosmic also
    # handles repo add/verify/trust + graceful abort.
    install_cosmic cosmic-greeter
    # greetd is a hard dependency of cosmic-greeter (it IS the session manager
    # that hosts the greeter), but it is named explicitly here — mirroring the
    # accountsservice-belt-and-suspenders reasoning in the lightdm branch — so
    # the greetd runit service below never races a transitive pull.
    install_pkgs greetd
    # AI (Big Pickle) FIX — Beta-v2.9.12 [COSMIC-GREETER-USER]: the greeter
    # account MUST be named EXACTLY `cosmic-greeter` (as upstream ships it).
    # cosmic-greeter's src/main.rs dispatches on the current username:
    # `"cosmic-greeter" => greeter::main()` (the greetd DM: user list, layer
    # surfaces, greetd IPC) vs `_ => locker::main()` (a locker that waits for
    # an ext-session-lock event and maps nothing — the dead grey screen).
    # The earlier community template shipped `system_accounts=
    # "_cosmicgreeter"`, which is WRONG: it silently forces the locker branch
    # (verified live 2026-09-06 on `<host>` via WAYLAND_DEBUG: the client bound
    # xdg_wm_base/layer-shell/lock globals, created one wl_surface, then sat
    # idle with no role — the login panel only appeared after `usermod -l
    # cosmic-greeter _cosmicgreeter`). The old Beta-v2.9.10 comment claiming
    # `_cosmicgreeter` "matches the repo" documented the bug, not the fix.
    # The community repo also deploys it as: greetd -c
    # /etc/greetd/cosmic-greeter.toml (which launches the
    # /etc/greetd/cosmic-greeter.start dbus-run-session wrapper — see
    # Beta-v2.9.14 [COSMIC-GREETER-SESSION-BUS] — as the cosmic-greeter user)
    # PLUS a supervised
    # cosmic-greeter-daemon (/run/cosmic-greeter owner). The cosmic-greeter user
    # is created by the package's system_accounts (as `_cosmicgreeter`) only in
    # recent revisions (1.5.0+; the 1.2.0 era shipped the group but not the
    # user), so it is provisioned here idempotently to never depend on upstream
    # revision luck — and now with the DM-correct account name.
    if ! grep -q '^cosmic-greeter:' /etc/passwd 2>/dev/null; then
        _cg_group_opt=""
        grep -q '^cosmic-greeter:' /etc/group 2>/dev/null && _cg_group_opt="-g cosmic-greeter -G video,input"
        # shellcheck disable=SC2086  # _cg_group_opt is empty or a fixed flat flag string; deliberate
        useradd -r -M -s /sbin/nologin -d /var/lib/cosmic-greeter -c 'Cosmic Greeter Account' $_cg_group_opt cosmic-greeter 2>/dev/null || \
            echo "WARNING: could not create the cosmic-greeter system user — the greeter may not start." >&2
        unset _cg_group_opt
    fi
    mkdir -p /var/lib/cosmic-greeter
    chown -f cosmic-greeter:cosmic-greeter /var/lib/cosmic-greeter 2>/dev/null || true
    # The greeter lists users/icons through org.freedesktop.Accounts; same
    # D-Bus-activation boot race as [LIGHTDM-HW] (Void ships accountsservice
    # with NO runit service), so a supervised accounts-daemon is provisioned
    # here exactly as the lightdm branch does, and linked on first boot by
    # rc.local. Without it the greeter's first Accounts request can time out.
    _accd_bin=""
    for _accd_cand in /usr/libexec/accounts-daemon /usr/lib/accounts-daemon; do
        [ -x "$_accd_cand" ] && { _accd_bin="$_accd_cand"; break; }
    done
    if [ -n "$_accd_bin" ]; then
        mkdir -p /etc/sv/accounts-daemon
        cat > /etc/sv/accounts-daemon/run << 'ACCD_EOF'
#!/bin/sh
exec 2>&1
sv check dbus >/dev/null || exit 1
exec __ACCD_BIN__
ACCD_EOF
        sed -i "s|__ACCD_BIN__|${_accd_bin}|" /etc/sv/accounts-daemon/run
        chmod 0755 /etc/sv/accounts-daemon/run
    else
        echo "WARNING: accounts-daemon binary not found — the greeter will rely on D-Bus activation (boot race may resurface)." >&2
    fi
    unset _accd_bin _accd_cand
    # AI (Big Pickle) FIX — Beta-v2.9.15 [COSMIC-GREETER-DBUS-POLICY]: the
    # packaged /usr/share/dbus-1/system.d/com.system76.CosmicGreeter.conf ships
    # bus grants for group="_cosmicgreeter" (the package's historical account
    # name), but [COSMIC-GREETER-USER] creates the account as exactly
    # `cosmic-greeter`, so the greeter's GetUserData call to the root
    # cosmic-greeter-daemon matched no allow rule and dbus-daemon rejected it
    # ("AccessDenied" + "Failed to apply user display config" every start).
    # Re-emit the policy to /etc/dbus-1/system.d (a real includedir read AFTER
    # the packaged tree; D-Bus policy is additive per-allow, so this supersedes
    # the stale grant) with the renamed group. A leftover `_cosmicgreeter` group
    # then matches nothing — harmless.
    mkdir -p /etc/dbus-1/system.d
    cat > /etc/dbus-1/system.d/com.system76.CosmicGreeter.conf << 'PDBUS_EOF'
<?xml version="1.0"?>
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <policy group="cosmic-greeter">
    <allow send_destination="com.system76.CosmicGreeter"/>
    <allow receive_sender="com.system76.CosmicGreeter"/>
  </policy>
  <policy user="root">
    <allow own="com.system76.CosmicGreeter"/>
    <allow send_destination="com.system76.CosmicGreeter"/>
    <allow receive_sender="com.system76.CosmicGreeter"/>
  </policy>
</busconfig>
PDBUS_EOF
    chmod 0644 /etc/dbus-1/system.d/com.system76.CosmicGreeter.conf
    DM_SERVICE_NAME="cosmic-greeter"
elif [ "$DISPLAY_MANAGER" = "none" ]; then
    # AI (Big Pickle) ADDITION — Beta-v2.9.48 [NO-DM]: a console-only / headless
    # install installs NO display manager; the first-boot rc.local link is
    # guarded so no dangling /etc/sv/none symlink is ever created.
    DM_SERVICE_NAME="none"
else
    install_pkgs sddm
    DM_SERVICE_NAME="sddm"
fi

if [ "$DESKTOP_ENV" = "cinnamon" ]; then
    # AI (Claude, Sonnet 5, Medium) CHANGE: cinnamon-all (not bare cinnamon)
    # — confirmed against a real working Void+Cinnamon install report that
    # bare `cinnamon` alone left out pieces (no display manager dependency,
    # incomplete applet/session-editor set); cinnamon-all is Void's
    # intended full-metapackage route. sddm itself is still installed
    # separately above regardless, since cinnamon-all doesn't declare a
    # display-manager dependency either.
    install_pkgs cinnamon-all

    # Cinnamon's terminal requirement (confirmed by real install testing):
    # cinnamon-all does NOT bundle a terminal emulator at
    # all (no xterm, no gnome-terminal, nothing) — a real install ended up
    # with no way to open a terminal from the desktop, only reachable by
    # dropping to a TTY. KDE Plasma doesn't have this gap since Konsole
    # comes bundled via kde-plasma/kde-baseapps. gnome-terminal chosen to
    # match Cinnamon's own GNOME-lineage stack (it already pulls in vte/
    # gsettings-adjacent dependencies as part of cinnamon-all) and because
    # it's the terminal confirmed working on the real test machine.
    install_pkgs gnome-terminal

    # Cinnamon's remaining desktop-gap packages (confirmed by real install
    # feedback across several gaps found on a working Cinnamon install):
    # install:
    #   - gedit: no GUI text editor was installed at all (same class of
    #     gap as the missing terminal above).
    #   - gnome-backgrounds: Cinnamon ships no wallpaper images of its own
    #     (a well-documented, common Cinnamon-on-non-Mint issue — Mint's
    #     own Cinnamon relies on its own mint-backgrounds-* packages,
    #     which don't exist on Void) — without it the desktop loads to a
    #     solid black background with nothing to choose from even after
    #     install.
    #   - blueman: bluez (the backend daemon) was already being installed
    #     and enabled unconditionally, but nothing provided a GUI/tray
    #     applet for Cinnamon specifically (unlike KDE, which gets one via
    #     kde-plasma). Gated to Cinnamon only — KDE already has its own
    #     (bluedevil) and doesn't need a second, competing one.
    #   - network-manager-applet: Void's own NetworkManager docs describe
    #     this as what "provides the agent necessary for securely storing
    #     secrets" (i.e. WiFi passwords) for non-GNOME/non-KDE desktops.
    #     Real testing showed WPA2/WPA3 connections failing immediately
    #     from Cinnamon's own network menu, with the only working
    #     workaround being to enter the password directly via
    #     NetworkManager's own connection editor rather than the normal
    #     connect flow — consistent with no secret agent being registered.
    #     Cinnamon does have its own native network applet, so this may
    #     not be the definitive fix, but it's cheap, harmless to have
    #     alongside it, and it's the component Void's own docs point to —
    #     worth confirming on the next real test whether this resolves it.
    #   - wsdd: Nemo (Cinnamon's file manager) auto-spawns the `wsdd`
    #     daemon for Windows name-service/network discovery (the comment notes
    #     a real boot logged "Failed to spawn the wsdd daemon"). HOWEVER —
    #     AI (Big Pickle) CORRECTION — Beta-v2.5.2 [WSDD-ABSENT]: Void does
    #     NOT ship `wsdd` (nor `wsdd2`) in any official repo (verified against
    #     void-packages master; the package has only ever been a long-open
    #     request, void-packages#28216). Listing it made `xbps-install` abort
    #     the ENTIRE desktop-gap transaction with
    #     "'wsdd' not found in repository pool" on real hardware. It is
    #     deliberately NOT installed. Nemo's "Windows Network" entry will log
    #     the missing-daemon warning (harmless), but the install must not fail
    #     over an absent package.
    install_pkgs gedit gnome-backgrounds blueman network-manager-applet

    # [CINNAMON-WALLPAPER] Set a default wallpaper for Cinnamon so a fresh
    # install doesn't boot to a solid black screen. gnome-backgrounds is
    # installed above (Cinnamon ships no wallpapers of its own — Mint's
    # mint-backgrounds-* doesn't exist on Void), but without explicitly
    # setting picture-uri, Cinnamon's compiled-in default points to a
    # non-existent Mint path. Prefer the GNOME default (adwaita-l —
    # the light adwaita stripe image) and write it into the system-wide dconf
    # database so every new user gets a visible wallpaper on first login.
    # The user can still change it via Settings > Background.
    # - adwaita-l is preferred over the generic "first available" because the
    #   filesystem-order first match on a real Void install turned out to be
    #   vnc-l.png — the near-empty "plain color for remote access" image —
    #   which is effectively another blank screen.
    _cinnamon_wallpaper="$(find /usr/share/backgrounds -maxdepth 2 -type f \
        \( -name 'adwaita-l.jpg' -o -name 'adwaita-l.jxl' \
           -o -name 'adwaita-l.png' -o -name 'adwaita-l.svg' \) \
        2>/dev/null | head -1)" || true
    if [[ -z "$_cinnamon_wallpaper" ]]; then
        _cinnamon_wallpaper="$(find /usr/share/backgrounds -maxdepth 2 -type f \
            \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \
               -o -name '*.svg' -o -name '*.jxl' -o -name '*.webp' \) \
            2>/dev/null | head -1)" || true
    fi
    if [[ -n "$_cinnamon_wallpaper" ]]; then
        mkdir -p /etc/dconf/profile
        cat > /etc/dconf/profile/user << 'INNER_EOF'
user-db:user
system-db:local
INNER_EOF
        mkdir -p /etc/dconf/db/local.d
        cat > /etc/dconf/db/local.d/01-cinnamon-wallpaper << INNER_EOF
[org/cinnamon/desktop/background]
picture-uri='file://${_cinnamon_wallpaper}'
picture-options='zoom'
INNER_EOF
        dconf update
    fi
    unset _cinnamon_wallpaper

    # gnome-terminal default font: whatever GTK/Pango resolves as the system
    # default was reported to render with very wide letter/number spacing —
    # confirmed fixed by manually switching the profile to "Monospace 12". Since
    # gnome-terminal profiles are relocatable-schema instances keyed by a
    # randomly generated UUID that doesn't exist until the terminal is
    # first launched, there's no single fixed dconf path to preset here —
    # instead this overrides the SCHEMA's own default via a
    # .gschema.override file, which GSettings applies to any
    # not-yet-user-customized instance of that schema. Requires
    # glib-compile-schemas to actually take effect; a stale/missing
    # gschemas.compiled would silently make this a no-op.
    mkdir -p /usr/share/glib-2.0/schemas
    cat > /usr/share/glib-2.0/schemas/zz-void-installer-cinnamon.gschema.override << 'INNER_EOF'
[org.gnome.Terminal.Legacy.Profile]
font='Monospace 12'
use-system-font=false
INNER_EOF
glib-compile-schemas /usr/share/glib-2.0/schemas/

    # Cinnamon X11 dbus-run-session handling, evidence-based: a real
    # Void bug report (void-packages#21766, "KDE X11 should be started with
    # dbus-run-session") documents this exact failure class for Plasma's
    # X11 session — Void's own .desktop session files didn't reliably wire
    # up DBUS_SESSION_BUS_ADDRESS, and the confirmed upstream fix was
    # prepending `dbus-run-session --` to the session's Exec= line. This
    # matches the reported symptom for Cinnamon closely (X11: black screen,
    # cursor moves, nothing else starts; Wayland: hangs at a terminal-like
    # screen) — Cinnamon depends on D-Bus even more heavily than Plasma
    # does (Nemo, cinnamon-settings-daemon, muffin IPC, applets, the
    # screensaver all talk over the session bus), so a missing session bus
    # producing a dead-but-running X server lines up well. Applied
    # defensively to every session file cinnamon-all ships (both
    # xsessions and wayland-sessions — the SDDM greeter offering a
    # "wayland experimental" Cinnamon entry means Void's current
    # cinnamon-all package does ship one, contrary to what Void's own
    # Wayland docs page said at the time this script was last checked
    # against it — real hardware evidence wins over stale docs here) —
    # skipped if a line already starts with dbus-run-session, so a future
    # Void package fixing this upstream doesn't get double-wrapped.
    for _sess_file in /usr/share/xsessions/*.desktop /usr/share/wayland-sessions/*.desktop; do
        [ -f "$_sess_file" ] || continue
        case "$(basename "$_sess_file")" in
            *cinnamon*)
                if grep -q '^Exec=' "$_sess_file" && ! grep -q '^Exec=dbus-run-session' "$_sess_file"; then
                    sed -i -E 's|^Exec=(.*)|Exec=dbus-run-session -- \1|' "$_sess_file"
                fi
                ;;
        esac
    done

    # SDDM default session: SDDM was defaulting to
    # (and pre-highlighting) "Cinnamon on Wayland (Experimental)" at the
    # greeter — confirmed not fully working yet, which is expected given
    # its own "Experimental" label, but it shouldn't be what a fresh
    # install lands on by default. Pre-seed SDDM's own state file with the
    # X11 Cinnamon session as the one to highlight/select by default.
    # Deliberately scoped entirely inside the DESKTOP_ENV=cinnamon branch —
    # never touches Plasma's default in any way. ALSO gated on
    # DISPLAY_MANAGER=sddm now that LightDM is a real option too — this
    # file/mechanism is SDDM-specific; LightDM's own default-session
    # handling is set separately, above, via lightdm.conf's user-session=.
    #
    # The exact xsessions filename isn't hardcoded/guessed — it's detected
    # dynamically by scanning for a *cinnamon* xsessions entry that ISN'T
    # the software-rendering fallback variant (matched by "2d"/"software"
    # in the filename, e.g. Cinnamon's well-known "cinnamon2d" naming for
    # that fallback session) — this way it adapts automatically if Void
    # ever renames the file, rather than silently doing nothing.
    if [ "$DISPLAY_MANAGER" = "sddm" ]; then
        _cinnamon_x11_session=""
        for _cs_file in /usr/share/xsessions/*cinnamon*.desktop; do
            [ -f "$_cs_file" ] || continue
            case "$(basename "$_cs_file")" in
                *2d*|*software*|*Software*) continue ;;
                *) _cinnamon_x11_session="$(basename "$_cs_file" .desktop)"; break ;;
            esac
        done
        if [ -n "$_cinnamon_x11_session" ]; then
            mkdir -p /var/lib/sddm
            cat > /var/lib/sddm/state.conf << INNER_EOF
[Last]
Session=${_cinnamon_x11_session}.desktop
User=${TARGET_USER}
INNER_EOF
        else
            echo "WARNING: could not detect a plain-X11 Cinnamon xsessions file — SDDM's default session was left unchanged (still whatever Void's package set as default, likely the Wayland experimental one)." >&2
        fi
    fi
elif [ "$DESKTOP_ENV" = "gnome" ]; then
    # AI (Claude, Sonnet 5, Medium) ADDITION: full `gnome` metapackage, not
    # gnome-core — see the long rationale in the Stage 1 prompt comment
    # above (DESKTOP ENVIRONMENT CHOICE). No dbus-run-session wrapping, no
    # blueman/network-manager-applet, no SDDM default-session override —
    # none of Cinnamon's reactive fixes apply here: GNOME Shell handles
    # D-Bus session setup, polkit, network, and Bluetooth integration
    # itself, and its Wayland session is confirmed working on Void
    # (unlike Cinnamon's experimental one), so there's nothing broken here
    # to work around.
    install_pkgs gnome
elif [ "$DESKTOP_ENV" = "xfce" ]; then
    # AI (Big Pickle) ADDITION — Beta-v2.4.0 [item 2]: Xfce via the `xfce4`
    # metapackage, Void's own documented route (also the DE shipped on
    # Void's graphical live images). xfce4 pulls in its terminal
    # (xfce4-terminal), panel (xfce4-panel), settings daemon, power
    # manager, etc., so unlike Cinnamon no supplementary basics are needed.
    # The network-manager-applet secret agent is still useful for
    # X11/GTK desktops where a native tray applet is present, matching the
    # Cinnamon rationale — added here too.
    # [XFC-AUTOMOUNT]: gvfs provides the userspace virtual filesystem
    # backends (MTP phone access, SMB/NFS network shares, Google Drive,
    # trash-can-mount) that Thunar uses for full automount. GNOME,
    # Cinnamon, and MATE already get gvfs via their own file managers
    # (gnome-core→gvfs, nemo→gvfs, caja→gvfs); Xfce's Thunar can use
    # gvfs but doesn't depend on it — without it, Thunar mounts removable
    # media via thunar-volman/udisks2 but loses network/cloud/phone
    # backends. udisks2 is pulled in as a gvfs dependency, so no
    # separate install is needed.
    # AI (Big Pickle) FIX — Beta-v2.9.9 [XFC-VOLUME]: the `xfce4` metapackage
    # bundles a terminal (xfce4-terminal) and text editor (mousepad), but NOT
    # a panel volume applet — xfce4-panel is compiled without a pulseaudio
    # backend (verified against void-packages' xfce4/xfce4-panel templates), so
    # a fresh Xfce install has sound but no speaker icon (same gap as MATE's
    # missing mate-media). xfce4-pulseaudio-plugin (srcpkgs 0.5.1, pulls
    # pavucontrol) is now installed explicitly.
    install_pkgs xfce4 network-manager-applet gvfs xfce4-pulseaudio-plugin
elif [ "$DESKTOP_ENV" = "mate" ]; then
    # AI (Big Pickle) ADDITION — Beta-v2.4.0 [item 2]: MATE via the `mate`
    # metapackage (Void's full-MATE route, analogous to cinnamon-all). The
    # metapackage bundles the panel, settings daemon, control center, Caja,
    # Marco, etc.
    # AI (Big Pickle) FIX — Beta-v2.9.9 [MATE-TERMINAL]: the older claim that
    # the metapackage "bundles mate-terminal" was WRONG — verified against
    # void-packages' `mate` template that its dependency list carries no
    # terminal and no text editor, and a real Beta-v2.9.6 MATE install ended
    # up with no way to open a terminal from the desktop (only a TTY) — the
    # same gap class as Cinnamon's missing gnome-terminal/gedit above.
    # mate-terminal and pluma (MATE's gedit-equivalent, which also serves as
    # a GUI log reader) are now installed explicitly; both are confirmed in
    # Void's official repos (srcpkgs/mate-terminal 1.28.1, srcpkgs/pluma
    # 1.28.1).
    # AI (Big Pickle) FIX — Beta-v2.9.9 [MATE-AUDIO]: the `mate` metapackage
    # also does NOT bundle `mate-media`, which provides the panel's "Volume
    # Control" applet (the speaker/tray icon) — confirmed against void-packages'
    # mate template (no mate-media in its depends). Without it audio works but
    # there is no panel volume control. mate-media (srcpkgs/mate-media 1.28.1)
    # is now installed explicitly; it controls volume through the installer's
    # pipewire-pulse layer.
    # network-manager-applet added for the same X11/GTK secret-agent
    # rationale as Cinnamon/Xfce.
    # AI (Big Pickle) FIX — Beta-v2.9.18 [MATE-METAPACKAGE-REGRESSION]: restore
    # the `mate` metapackage. Beta-v2.9.9's [MATE-TERMINAL] change replaced
    # `install_pkgs mate network-manager-applet` with the explicit-helpers line
    # below, silently dropping `mate` itself — so a fresh MATE install had no
    # mate-session/panel/settings-daemon and NO /usr/share/xsessions/mate.desktop.
    # The installer writes user-session=mate into lightdm.conf, so the greeter
    # selected a session that did not exist: post-password the wrapper had nothing
    # to exec, the session died, and LightDM bounced back to the greeter — the
    # "cannot login at the greeter" showstopper. `mate` pulls mate-base /
    # mate-session-manager → /usr/share/xsessions/mate.desktop; xbps dedups the
    # overlapping helper deps.
    install_pkgs mate mate-terminal pluma mate-media network-manager-applet
elif [ "$DESKTOP_ENV" = "lxqt" ]; then
    # AI (Big Pickle) ADDITION — Beta-v2.4.0 [item 2]: LXQt via the `lxqt`
    # metapackage (Qt-based, light). LXQt's conventional display manager
    # is SDDM, but the DM is chosen independently above. lxqt bundles its
    # own session/panel/file-manager stack.
    # [XFC-AUTOMOUNT]: same rationale as Xfce — pcmanfm-qt's underlying
    # libfm uses GIO's volume monitor but doesn't depend on gvfs. Without
    # it, basic USB automounting works via udisks2 but network/cloud/phone
    # backends are missing. GNOME, Cinnamon, and MATE already get gvfs
    # via their file managers.
    # AI (Big Pickle) FIX — Beta-v2.9.9 [LXQT-EDITOR]: the `lxqt` metapackage
    # bundles a terminal (qterminal) and lxqt-panel has a native volume
    # plugin, but it carries NO text editor — verified against void-packages'
    # lxqt template (no featherpad/editor in its depends). FeatherPad
    # (srcpkgs/FeatherPad 1.6.4, Qt6 — note the tiled-case package name) is
    # now installed explicitly.
    install_pkgs lxqt gvfs FeatherPad
elif [ "$DESKTOP_ENV" = "cosmic" ]; then
    # AI (Big Pickle) ADDITION — Beta-v2.4.0 [COSMIC]: COSMIC installed from the
    # third-party community repo (never the official mirrors), so it uses the
    # dedicated install_cosmic() helper instead of install_pkgs(). The
    # maintainer's metapackage is cosmic-desktop-full (all components). The
    # maintainer recommends also installing SDDM + Firefox with it; SDDM is
    # handled by the independent DISPLAY_MANAGER choice above, and Firefox by
    # the independent browser toggles — both may be selected separately, so
    # only the metapackage is installed here.
    # (cosmic-store is installed at its own DE-independent site next to the
    # Brave/flatpak-gated deliveries — Beta-v2.9.84 [COSMIC-STORE] — so it is
    # not bundled into this call.)
    install_cosmic cosmic-desktop-full
    # AI (Big Pickle) FIX — Beta-v2.9.75 [XKB-CONFIG-QUOTING]: the
    # cosmic-desktop-full xbps post-install hook (srcpkgs/cosmic-desktop-full/INSTALL)
    # does `layout=$(grep KEYMAP= /etc/rc.conf | cut -d= -f2)` — which keeps
    # the value's surrounding quotes (`"us"`) — then `sed -i "s/us/$layout/"`
    # on /usr/share/cosmic/com.system76.CosmicComp/v1/xkb_config, producing
    # `layout: ""us"",`. That is invalid RON, so cosmic-comp config load fails
    # with ExpectedComma @ line 4 col 11 -> cosmic-greeter-daemon/compositor
    # crash-loop -> grey blinking login screen (proven on <host> 2026-10-05).
    # Rewrite the file to the canonical form cosmic-config expects, with the
    # layout taken UNQUOTED from the chroot's /etc/rc.conf (already pinned to
    # the live console keymap by Beta-v2.6.9 [KEYMAP]). Overwriting is always
    # safe: this is exactly the content the hook intended to write.
    #
    # AI (Big Pickle) FIX — Beta-v2.9.79 [XKB-CONFIG-CREATE]: the 2.9.75 repair
    # was gated on `[ -f "$_xkb_conf" ]`, so it could only ever REPAIR a corrupt
    # file — never CREATE a missing one. On the <host> 2026-10-05 install this
    # file was ABSENT entirely, and that is fatal, not cosmetic: NO package ships
    # it, only the cosmic-desktop-full post-install hook creates it, and that
    # hook sits in the hook's `UPDATE="no"` arm and did not complete on that
    # resumed install (witness: its other side effects were only partial —
    # /etc/pipewire/pipewire.conf.d/10-wireplumber.conf present but
    # 20-wireplumber-pulse.conf and /etc/xdg/autostart/pipewire.desktop absent).
    # With the file missing, cosmic-comp reports no xkb config, so cosmic-
    # greeter's UserData.xkb_config_opt is None and Common::update_user_data
    # skips the ENTIRE active_layouts fill (cosmic-greeter src/common.rs:203-208,
    # the vec is initialised empty at common.rs:118 and only ever cleared+filled
    # inside that block). The keyboard-layout button then renders
    # `self.common.active_layouts[self.common.current_keyboard_layout].name()`
    # (src/greeter.rs:590) against that empty vec and the greeter PANICS:
    #   index out of bounds: the len is 0 but the index is 0
    # greetd then loops `check_children: greeter exited without creating a
    # session` every ~1.6s forever: no login, no VT switch, and each corpse
    # leaves cosmic-osk hot-spinning "Error trying to flush the wayland display:
    # Broken pipe" (a 65 MB svlogd log in ~24 min on the affected boot). Proven
    # on <host> 2026-10-05 (25 panics, 0 successful logins, wtmp empty).
    #
    # The repair therefore ENSURES the file: create it when missing, rewrite it
    # when the layout differs, so it no longer depends on the packager's hook
    # having run at all. The content is byte-for-byte what the (fixed) hook
    # intends to write, so writing it unconditionally cannot be wrong.
    #
    # Also accept a BARE `KEYMAP=us`, not just the quoted `KEYMAP="us"`: the
    # Void_Linux_Live builder writes rc.conf unquoted from two places, so a
    # live-ISO install with a non-US keymap has `KEYMAP=de`. The old
    # quoted-only sed silently yielded empty and fell back to "us" — installing
    # the WRONG keyboard layout with no error anywhere. The extraction below is
    # now the same quote-stripping + token-validation sed the fixed packager
    # hook uses, and the `case` guard keeps a hostile/odd rc.conf value from
    # ever being interpolated into the RON string.
    _xkb_layout="$(sed -n 's/^[[:space:]]*KEYMAP=["]*\([^"[:space:]]*\)["]*[[:space:]]*\(#.*\)\{0,1\}$/\1/p' /etc/rc.conf 2>/dev/null | tail -1)"
    case "${_xkb_layout:-}" in
        ''|*[!a-zA-Z0-9_-]*) _xkb_layout="us" ;;
    esac
    _xkb_conf="/usr/share/cosmic/com.system76.CosmicComp/v1/xkb_config"
    if [ ! -f "$_xkb_conf" ] || ! grep -q "^layout: \"${_xkb_layout}\",\$" "$_xkb_conf" 2>/dev/null; then
        echo "==> Ensuring cosmic xkb_config (layout: ${_xkb_layout})"
        mkdir -p "$(dirname "$_xkb_conf")"
        cat > "$_xkb_conf" << XKB_EOF
(
rules: "",
model: "",
layout: "${_xkb_layout}",
variant: "",
options: None,
repeat_delay: 600,
repeat_rate: 25,
)
XKB_EOF
    fi
    unset _xkb_layout _xkb_conf
elif [ "$DESKTOP_ENV" = "kde" ]; then
    install_pkgs kde-plasma kde-baseapps ark kio-admin
fi

# [LIGHTDM-GREETER-BG] Set the greeter background so a fresh install doesn't
# show a solid black login screen. Runs AFTER the desktop metapackage install
# (Beta-v2.9.8 [GREETER-BG-TIMING]) — the original placement inside the lightdm
# branch ran before ANY desktop package existed, so /usr/share/backgrounds was
# absent and every fresh MATE/Cinnamon/xfce + lightdm greeter silently booted
# to black (real-hardware report, Beta-v2.9.6 MATE install). Reuses the same
# system background image search as the Cinnamon wallpaper code: prefer the
# GNOME adwaita-l stripe, fall back to any image in /usr/share/backgrounds
# (MATE ships its own wallpaper set via the mate metapackage, and Cinnamon's
# gnome-backgrounds was installed by its desktop block above).
# GTK greeter reads lightdm-gtk-greeter.conf; Slick greeter reads
# slick-greeter.conf — both accept a background=<path> directive.
# AI (Big Pickle) FIX — Beta-v2.9.5 [GREETER-BG-PIPEFAIL]: the two
# `find /usr/share/backgrounds ... | head -1` command substitutions are UNSAFE
# under the chroot's `set -eEo pipefail` when the directory does not exist yet
# (e.g. a desktop that ships no wallpapers) — `find` exits 1, `pipefail`
# turns the pipeline nonzero, the substitution + assignment fail, and `set -e`
# kills the chroot with ZERO output. `2>/dev/null` hides the error text but
# NOT the exit code. The `|| true` guards make a missing/empty backgrounds
# dir simply leave the bg unset (no wallpaper); the gnome-backgrounds retry
# below then guarantees the greeter is never a bare black screen.
if [ "$DISPLAY_MANAGER" = "lightdm" ]; then
    _greeter_bg=""
    for _greeter_bg_name in adwaita-l.jpg adwaita-l.jxl adwaita-l.png adwaita-l.svg; do
        _greeter_bg_candidate="$(find /usr/share/backgrounds -maxdepth 2 -type f \
            -name "$_greeter_bg_name" 2>/dev/null | head -1)" || true
        if [[ -n "$_greeter_bg_candidate" ]]; then
            _greeter_bg="$_greeter_bg_candidate"
            break
        fi
    done
    if [[ -z "$_greeter_bg" ]]; then
        # AI (Big Pickle) FIX — Beta-v2.9.19b [GREETER-BG-DEPTH]: the generic
        # wildcard fallback must descend to depth 3 (and beyond) — mate-backgrounds
        # puts images at /usr/share/backgrounds/mate/<category>/<file> (depth 3),
        # invisible to every -maxdepth 2 search on a MATE-only install. The
        # adwaita-l.* specific-name passes stay at -maxdepth 2 (adwaita files are
        # top-level; harmless either way).
        _greeter_bg="$(find /usr/share/backgrounds -maxdepth 5 -type f \
            \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \
               -o -name '*.svg' -o -name '*.jxl' -o -name '*.webp' \) \
            2>/dev/null | head -1)" || true
    fi
    if [[ -z "$_greeter_bg" ]]; then
        # No wallpapers on disk at all (e.g. a desktop that ships none). Pull
        # the smallest standard set — gnome-backgrounds, the same source the
        # Cinnamon block uses — and re-run the search, so a lightdm greeter is
        # never left with its black default screen.
        echo "==> No wallpapers found; installing gnome-backgrounds for the greeter"
        install_pkgs gnome-backgrounds
        for _greeter_bg_name in adwaita-l.jpg adwaita-l.jxl adwaita-l.png adwaita-l.svg; do
            _greeter_bg_candidate="$(find /usr/share/backgrounds -maxdepth 2 -type f \
                -name "$_greeter_bg_name" 2>/dev/null | head -1)" || true
            [[ -n "$_greeter_bg_candidate" ]] && { _greeter_bg="$_greeter_bg_candidate"; break; }
        done
        if [[ -z "$_greeter_bg" ]]; then
            _greeter_bg="$(find /usr/share/backgrounds -maxdepth 5 -type f \
                \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \
                   -o -name '*.svg' -o -name '*.jxl' -o -name '*.webp' \) \
                2>/dev/null | head -1)" || true
        fi
    fi
    if [[ -n "$_greeter_bg" ]]; then
        case "$LIGHTDM_GREETER" in
            gtk)
                cat > /etc/lightdm/lightdm-gtk-greeter.conf << INNER_EOF
[greeter]
background="${_greeter_bg}"
INNER_EOF
                ;;
            slick)
                # AI (Big Pickle) FIX — Beta-v2.9.34 [SLICK-BG-QUOTES]: slick-greeter
                # does NOT strip quotes from config values — a quoted
                # background="path" is opened as "/path" (literal quotes in the
                # filename), fails, and falls back to #000000. Write the path
                # UNQUOTED. (lightdm-gtk-greeter strips quotes, so it keeps the
                # quoted form above.)
                cat > /etc/lightdm/slick-greeter.conf << INNER_EOF
[Greeter]
background=${_greeter_bg}
INNER_EOF
                ;;
        esac
    fi
    unset _greeter_bg _greeter_bg_candidate _greeter_bg_name
fi

# AI (Big Pickle) ADDITION — Beta-v2.4.0 [item 2]: polkit authentication
# agent. The kde-plasma metapackage ships its own (polkit-kde-agent), and
# GNOME has a built-in agent, but the GTK-family desktops added here
# (Cinnamon, Xfce, MATE — and LXQt) have no guarantee of one. Without a
# polkit agent, GUI privilege prompts (NetworkManager, blueman mounting,
# package managers) can hang with nothing to present the auth dialog.
# Installed for exactly those desktop environments.
# AI (Big Pickle) FIX — Beta-v2.9.10 [COSMIC-POLKIT]: COSMIC is in the same
# gap — `cosmic-desktop-full` pulls NO polkit agent (verified against the
# community repo's run_depends), unlike kde-plasma (polkit-kde-agent) and the
# `gnome` metapackage (built-in Shell agent). polkit-gnome (GTK3, Void
# official repo) is installed for DESKTOP_ENV=cosmic, and an
# /etc/xdg/autostart entry is baked because Void's polkit-gnome installs its
# desktop file to /usr/share/applications with OnlyShowIn=GNOME — meaningless
# to a COSMIC session — and cosmic-session DOES honor XDG autostart
# (verified: the session binary parses autostart folders / Desktop Entries).
case "$DESKTOP_ENV" in
    cinnamon|xfce|mate|lxqt)
        install_pkgs lxqt-policykit
        ;;
    cosmic)
        install_pkgs polkit-gnome
        _pg_auth_bin=""
        for _pg_cand in /usr/libexec/polkit-gnome-authentication-agent-1 /usr/lib/polkit-gnome-authentication-agent-1; do
            [ -x "$_pg_cand" ] && { _pg_auth_bin="$_pg_cand"; break; }
        done
        if [ -n "$_pg_auth_bin" ]; then
            mkdir -p /usr/local/sbin /etc/xdg/autostart
            # AI (Big Pickle) FIX — Beta-v2.9.13 [COSMIC-POLKIT-GUARD]: on
            # `<host>`, cosmic-session fired this autostart entry before the
            # COSMIC compositor/session-bus was up — the agent died instantly
            # and the session never respawned it, leaving polkit auth (a
            # <defunct> zombie under cosmic-session) with no dialog. The body
            # is launched through a guard that waits for a compositor-backed
            # session (WAYLAND_DISPLAY socket + reachable session bus) before
            # running the real agent, and respawns it if it dies, so a
            # late-fire or a crash self-heals instead of dying once.
            cat > /usr/local/sbin/cosmic-polkit-guard << 'GUARD_EOF'
#!/bin/sh
set -u
# AI (Big Pickle) — Beta-v2.9.13 [COSMIC-POLKIT-GUARD]
_agent="__PG_AUTH_BIN__"
_wl_sock="${XDG_RUNTIME_DIR:-/run/user/0}/${WAYLAND_DISPLAY:-wayland-1}"
_ready=0
while [ "$_ready" -eq 0 ]; do
    [ -S "$_wl_sock" ] || { sleep 1; continue; }
    dbus-send --session --dest=org.freedesktop.DBus --type=method_call \
        --print-reply / org.freedesktop.DBus.ListNames >/dev/null 2>&1 || \
        { sleep 1; continue; }
    _ready=1
done
while :; do
    "$_agent" || { sleep 2; continue; }
    sleep 2
done
GUARD_EOF
            sed -i "s|__PG_AUTH_BIN__|${_pg_auth_bin}|" /usr/local/sbin/cosmic-polkit-guard
            chmod 0755 /usr/local/sbin/cosmic-polkit-guard
            cat > /etc/xdg/autostart/polkit-gnome-authentication-agent-1.desktop << 'INNER_EOF'
[Desktop Entry]
Name=PolicyKit Authentication Agent
Comment=PolicyKit Authentication Agent
Exec=/usr/local/sbin/cosmic-polkit-guard
Terminal=false
Type=Application
Categories=
NoDisplay=true
INNER_EOF
        else
            echo "WARNING: polkit-gnome agent binary not found — COSMIC privilege prompts will hang." >&2
        fi
        unset _pg_auth_bin _pg_cand
        # AI (Big Pickle) ADDITION — Beta-v2.9.74 [USB-AUTOMOUNT]: COSMIC has
        # no built-in removable-media automounter and this installer's other
        # DE branches get one via gvfs (Xfce/LXQt) or the FM itself
        # (GNOME/KDE/Cinnamon/MATE). Install udiskie (udisks2 front-end that
        # mounts/unmounts removable media on plug/unplug) and autostart it
        # with the session, behind a readiness guard mirroring the polkit
        # agent's: cosmic-session honors XDG autostart but launches entries
        # before the Wayland socket + session bus are stable, so a bare
        # `Exec=udiskie` can die on the first fire and never respawn.
        install_pkgs udiskie
        cat > /usr/local/sbin/udiskie-guard << 'UDG_EOF'
#!/bin/sh
set -u
# [USB-AUTOMOUNT] wait for a compositor-backed session before udiskie starts
_wl_sock="${XDG_RUNTIME_DIR:-/run/user/0}/${WAYLAND_DISPLAY:-wayland-1}"
_ready=0
while [ "$_ready" -eq 0 ]; do
    [ -S "$_wl_sock" ] || { sleep 1; continue; }
    dbus-send --session --dest=org.freedesktop.DBus --type=method_call \
        --print-reply / org.freedesktop.DBus.ListNames >/dev/null 2>&1 || \
        { sleep 1; continue; }
    _ready=1
done
while :; do
    udiskie || { sleep 2; continue; }
    sleep 2
done
UDG_EOF
        chmod 0755 /usr/local/sbin/udiskie-guard
        cat > /etc/xdg/autostart/udiskie.desktop << 'INNER_EOF'
[Desktop Entry]
Name=udiskie
Comment=Removable media automounter
Exec=/usr/local/sbin/udiskie-guard
Terminal=false
Type=Application
Categories=
NoDisplay=true
INNER_EOF
        ;;
esac
# AI (Big Pickle) CHANGE — Beta-v2.9.17 [DEVICE-PROFILE]: the everyday
# roll-up line no longer ships tlp + bluez + preload unconditionally. Profile
# booleans gate each: tlp (battery) only on laptop profiles, bluez only with
# bluetooth, preload (adaptive readahead, CPU/IO wakeups) desktop/server-only.
# AI (Big Pickle) ADDITION — Beta-v2.9.89 [SMART-BASELINE]: smartmontools
# ships on EVERY install regardless of DE / greeter / profile so a SMART
# health baseline (smartctl -a) exists on day one — health monitoring is a
# baseline concern, not a DE/greeter concern (motivation: the first audit
# box's 1 TB NVMe, HEALTH PASSED / 0 media-integrity errors, was recorded
# only because the operator added the package by hand after install).
# smartd stays unenabled by default; enabling it remains an operator choice.
install_pkgs xdg-user-dirs xdg-utils xtools rsync git curl wget make binutils inotify-tools fastfetch chrony cronie bridge-utils smartmontools
# AI (Big Pickle) ADDITION — Beta-v2.9.90 [COSMIC-PPD]: COSMIC builds skip
# tlp (PPD replaces it there — the Stage-1 [COSMIC-PPD] gate) and ship
# power-profiles-daemon instead so cosmic-settings' powermode picker has its
# net.hadess.PowerProfiles backend from day one.
[ "$PROFILE_TLP" = "true" ] && install_pkgs tlp tlp-rdw
[ "$POWER_PPD" = "true" ] && install_pkgs power-profiles-daemon
[ "$PROFILE_BT" = "true" ] && install_pkgs bluez
[ "$PROFILE_PRELOAD" = "true" ] && install_pkgs preload
[ "$INSTALL_OCTOXBPS" = "true" ] && install_pkgs octoxbps

if [ "$INSTALL_FLATPAK" = "true" ]; then
    install_pkgs flatpak fuse fuse3
    # AI (Big Pickle) ADDITION — Beta-v2.9.28 [APPIMAGE-FUSE]: installing
    # Flatpak now also brings FUSE 2 (libfuse.so.2) and FUSE 3 so the AppImage
    # runtime can self-mount its squashfs payload (most wild AppImages ship the
    # FUSE 2 dlopen; recent static runtimes speak FUSE 3). On Void the two
    # coexist cleanly and base-system pulls neither, so this is the only
    # AppImage readiness the installer grants — a flatpak-only install that
    # never adds an AppImage would leave the user on the slow
    # --appimage-extract-and-run fallback otherwise.
    # AI (Big Pickle) ADDITION — Beta-v2.5.2 [FLATHUB-CHROOT]: add the
    # flathub remote NOW, inside the chroot, instead of at first boot in
    # rc.local. This stage runs with the live-CD's network already up (the
    # package sync above just used it), so `flatpak remote-add` can fetch
    # flathub's repo metadata (the `.flatpakrepo` + `summary.idx`) without
    # racing the network at boot. Deferring it to first-boot rc.local (runit
    # stage 2, which runs BEFORE NetworkManager comes up) made flatpak's
    # blocking fetch hang the whole boot with a "Flathub idx / Failed to
    # fetch summary" error whenever Flatpak was selected (see [FLATHUB-RCL]).
    # remote-add here targets the system installation (/var/lib/flatpak,
    # mounted from the @flatpak subvolume) and persists into the target.
    # [FLATHUB-URL-FIX] (Beta-v2.9.49, verified on real hardware 2026-09-14):
    # the old `https://flathub.org` is the WEBSITE (307 -> /en), not the repo,
    # and remote-add from a bare web URL imports NO GPG keyring — a flatpak
    # queue then always failed with "public key not found". Use the canonical
    # .flatpakrepo file (carries both the correct repo base URL and the
    # signing key), proven to make queued installs succeed.
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || \
        echo "WARNING: could not add flathub remote at install time. It will be re-attempted, non-blocking, at first boot (see [FLATHUB-RCL])." >&2
fi

# AI (Big Pickle) ADDITION — Beta-v2.9.36 [INSTALL-BREW]: Homebrew (classic
# Linuxbrew) as an opt-in complement to Flatpak — the unsandboxed, user-owned
# ~/.linuxbrew CLI/dev prefix. This installs ONLY brew's xbps runtime deps
# (git curl file procps-ng); the installer deliberately does NOT pipe the
# vendor's curl|bash (supply-chain; unsupported-upstream on Void; the whole
# prefix is user-owned). The operator creates the prefix on first login via
# Homebrew's official installer — NEWS step + HOMEBREW=yes pointer in
# ~/Documents/Void_Install.txt.
if [ "$INSTALL_BREW" = "true" ]; then
    install_pkgs git curl file procps-ng
    echo "==> Homebrew runtime deps installed (git curl file procps-ng) — the ~/.linuxbrew prefix is created on first login via Homebrew's official installer (see NEWS step / HOMEBREW=yes in ~/Documents/Void_Install.txt)."
fi

# AI (Claude, Sonnet 5, Medium) ADDITION: browsers are real per-install
# toggles now (see WEB BROWSER SELECTION, Stage 1) — Firefox/Chromium
# moved out of the always-installed base package line above into their
# own conditionals here, alongside the three new options. Brave has no
# official Void package (verified against void-packages' own srcpkgs
# tree) — installed via Flatpak only if Flatpak itself was also selected;
# otherwise skipped with an explicit message rather than silently doing
# nothing or reaching for an unofficial third-party repo. Flatpak install
# (above) and the chroot-time flathub remote-add ([FLATHUB-CHROOT]) both
# happen before this so the Brave install command itself can succeed. The
# queued app is installed at first boot (after the network is up), not while
# the boot network is still down — see [FLATHUB-RCL] in rc.local.
[ "$INSTALL_FIREFOX" = "true" ] && install_pkgs firefox
[ "$INSTALL_CHROMIUM" = "true" ] && install_pkgs chromium
[ "$INSTALL_VIVALDI" = "true" ] && install_pkgs vivaldi
[ "$INSTALL_FALKON" = "true" ] && install_pkgs falkon
# AI (Big Pickle) ADDITION — Beta-v2.8.3 [INSTALL-APPS]: Thunderbird and Steam
# are now real installable options (previously pre-create-only toggles). Steam
# needs the multilib/nonfree repos already added above; thunderbird is a
# plain GUI client. Both are lean-default OFF.
# AI (Big Pickle) ADDITION — Beta-v2.9.71 [STEAM-32BIT]: Void's `steam` package
# is a client bootstrap with NO 32-bit runtime dependencies, so a fresh
# install that only ran `install_pkgs steam` always hit "missing 32-Bit
# libraries libGL.so.1 & libdrm.so.2" on first launch. Pull the canonical
# Steam multilib runtime set (libgcc/libstdc++/libglvnd/mesa-dri/libdrm plus
# the X11/xcb/fontconfig/pulseaudio -32bit libs) together with steam, STRICTLY
# under the INSTALL_STEAM gate only — no new prompt, and nothing 32-bit ships
# unless the user actually opts into Steam at install time (INSTALL_STEAM
# stays lean-default OFF).
[ "$INSTALL_THUNDERBIRD" = "true" ] && install_pkgs thunderbird
[ "$INSTALL_STEAM" = "true" ] && install_pkgs steam libgcc-32bit libstdc++-32bit libglvnd-32bit mesa-dri-32bit libdrm-32bit libX11-32bit libXext-32bit libXfixes-32bit libXrandr-32bit libXcursor-32bit libXi-32bit libXrender-32bit libXinerama-32bit libXxf86vm-32bit libxcb-32bit freetype-32bit fontconfig-32bit libpulseaudio-32bit alsa-plugins-pulseaudio-32bit
# AI (Big Pickle) ADDITION — Beta-v2.9.37 [GAME-LAUNCHERS]: game-launcher
# installs mirroring the umbrella prompts. Lutris is in Void main (xbps);
# Wine (system, multilib) is the raw-CLI/shared-runtime toggle a launcher
# never auto-pulls; gamemode is Feral's CPU/GPU governor daemon + its 32-bit
# libs. Heroic and Bottles have NO official Void package — they are delivered
# via the first-boot Flatpak queue below ([GAME-FLATPAK-GATE], Beta-v2.9.40),
# only when Flatpak is also selected.
[ "$INSTALL_LUTRIS" = "true" ] && install_pkgs lutris
[ "$INSTALL_WINE" = "true" ] && install_pkgs wine
[ "$INSTALL_GAMEMODE" = "true" ] && install_pkgs gamemode libgamemode-32bit
# AI (Big Pickle) ADDITION — Beta-v2.9.72 [GAME-VULKAN]: a fresh install ships
# only the virtual-GPU virtio_icd as its Vulkan ICD, so any real AMD/Intel
# hardware returns VK_ERROR_INCOMPATIBLE_DRIVER (-9) when Steam/Lutris/Wine
# probe the GPU — immediately after the [STEAM-32BIT] GLX fix, the same class
# of "32-bit game can't start" (proven live: Steam's Vulkan topology query
# failed with -9 and 32-bit game libs had no radeonsi ICD to load). Install
# the DETECTED GPU family's Mesa Vulkan driver (64-bit + 32-bit) whenever ANY
# game launcher is selected (INSTALL_ANY_GAME = Steam ∨ Lutris ∨ Heroic ∨
# Bottles) — gated on the live-box hardware probe (HAS_AMD_GPU / HAS_INTEL_GPU
# / HAS_NVIDIA_GPU, Stage-1 [HARDWARE-REVIEW]), NOT on a new prompt, and only
# for the family actually present (installing radeon on Intel hardware
# reproduces -9 in reverse). NVIDIA: the proprietary driver (INSTALL_NVIDIA)
# ships its own ICD, so mesa-vulkan-nouveau is only pulled when the user
# declined it.
if [ "$INSTALL_ANY_GAME" = "true" ]; then
    [ "$HAS_AMD_GPU" = "yes" ] && install_pkgs mesa-vulkan-radeon mesa-vulkan-radeon-32bit
    [ "$HAS_INTEL_GPU" = "yes" ] && install_pkgs mesa-vulkan-intel mesa-vulkan-intel-32bit
    if [ "$HAS_NVIDIA_GPU" = "yes" ] && [ "$INSTALL_NVIDIA" != "true" ]; then
        install_pkgs mesa-vulkan-nouveau mesa-vulkan-nouveau-32bit
    fi
fi
# AI (Big Pickle) ADDITION — Beta-v2.8.4 [INSTALL-VBOX]: VirtualBox is now a
# real installable option (previously pre-create-only). The -ose package is
# in the nonfree repo (already added above); -ose-dkms builds the kernel
# module for the running kernel. The user is added to the vboxusers group and
# the vboxdrv runit service is enabled (module load at boot). A kernel module
# build needs the build toolchain, which is installed for dkms.
if [ "$INSTALL_VIRTUALBOX" = "true" ]; then
    install_pkgs virtualbox-ose virtualbox-ose-dkms
    usermod -aG vboxusers "$TARGET_USER"
fi
if [ "$INSTALL_BRAVE" = "true" ]; then
    if [ "$INSTALL_FLATPAK" = "true" ]; then
        echo "==> Brave has no official Void package — will be installed via Flatpak on first boot (flathub remote added at install time; the app itself installs after first-boot network is up)."
        mkdir -p "/home/${TARGET_USER}/.config/void-installer"
        echo "com.brave.Browser" >> "/home/${TARGET_USER}/.config/void-installer/flatpak-install-on-first-boot.txt"
        chown -R "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.config/void-installer"
    else
        echo "WARNING: Brave was selected but Flatpak was not — Brave has no official Void package, so it will NOT be installed. Install Flatpak later and run 'flatpak install flathub com.brave.Browser', or use another method of your choosing." >&2
    fi
fi

# AI (Big Pickle) ADDITION — Beta-v2.9.84 [COSMIC-STORE]: the store install
# site. Lives HERE — DE-independent, next to the other flatpak-gated
# deliveries — because cosmic-store is a flatpak-ecosystem GUI that runs under
# any desktop, not just COSMIC. install_cosmic() (bluesloth repo, pinned-key
# verification, bare `xbps-install` path excluded from PKG_PREFLIGHT) installs
# it on ANY desktop when opted in. The flatpak re-check mirrors the Brave rule
# exactly: the Stage-1 prompt only offers the store when INSTALL_FLATPAK=true,
# so this second check is defense-in-depth for a resume from an older state
# file that could carry store=yes alongside flatpak=no — then we WARN and
# SKIP, never let xbps pull flatpak in past an explicit opt-out.
if [ "$INSTALL_COSMIC_STORE" = "true" ]; then
    if [ "$INSTALL_FLATPAK" = "true" ]; then
        echo "==> cosmic-store has no official Void package — installed from the bluesloth COSMIC repo (Flatpak is already on per the channel choice)."
        install_cosmic cosmic-store
    else
        echo "WARNING: cosmic-store was selected but Flatpak was not — the store hard run-depends on flatpak, so it will NOT be installed." >&2
    fi
fi

# AI (Big Pickle) ADDITION — Beta-v2.9.37 [GAME-LAUNCHERS] / Beta-v2.9.40
# [GAME-FLATPAK-GATE]: Heroic and Bottles have NO official Void package, so
# they are Flatpak-delivered. The prompts already gated them on
# INSTALL_FLATPAK=true; here they are appended to the same first-boot queue the
# dispatcher drains, only when Flatpak is on (never a bare xbps install — the
# pre-2.9.40 `install_pkgs heroic` crashed #005 on missing package).
if [ "$INSTALL_HEROIC" = "true" ] && [ "$INSTALL_FLATPAK" = "true" ]; then
    mkdir -p "/home/${TARGET_USER}/.config/void-installer"
    echo "com.heroicgameslauncher.hgl" >> "/home/${TARGET_USER}/.config/void-installer/flatpak-install-on-first-boot.txt"
    chown -R "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.config/void-installer"
fi
if [ "$INSTALL_BOTTLES" = "true" ] && [ "$INSTALL_FLATPAK" = "true" ]; then
    mkdir -p "/home/${TARGET_USER}/.config/void-installer"
    echo "com.usebottles.bottles" >> "/home/${TARGET_USER}/.config/void-installer/flatpak-install-on-first-boot.txt"
    chown -R "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.config/void-installer"
fi

# AI (Big Pickle) ADDITION — Beta-v2.9.34 [FLATPAK-NM-DISPATCH]: the NetworkManager
# dispatcher script that replaces the old rc.local background subshell for
# first-boot Flatpak app installs. Fires on up/vpn-up when the interface gets a
# default route (guaranteed DNS), stamps completion only when EVERY queued app
# installs successfully ([FLATPAK-NM-DISPATCH-STAMP], Beta-v2.9.46). __TARGET_USER__
# is sed-substituted at generation time (same pattern as /etc/rc.local).
if [ "$INSTALL_FLATPAK" = "true" ]; then
    mkdir -p /etc/NetworkManager/dispatcher.d
    cat > /etc/NetworkManager/dispatcher.d/99-flatpak-firstboot << 'DIS_EOF'
#!/bin/sh
# AI (Big Pickle) ADDITION — Beta-v2.9.34 [FLATPAK-NM-DISPATCH] +
# [FLATPAK-NM-DISPATCH-STAMP] (Beta-v2.9.46)
# NetworkManager dispatcher: on a network-state event with a default route,
# install every Flatpak app queued at install time (one app ID per line in
# the queue file). The stamp file prevents re-runs; the stamp is written ONLY
# when ALL queued installs succeed, so a transient failure leaves the queue
# live for the next event.
# AI (Big Pickle) FIX — Beta-v2.9.68 [FLATPAK-DNS-LATE]: the `up` event can fire
# BEFORE NM finishes its connectivity check / DNS is resolvable (observed live:
# the first `up` at boot logged "Could not resolve hostname" for summary.idx).
# Also arm on `connectivity-change`, which NM emits when connectivity
# transitions (e.g. LIMITED/NONE -> FULL once DNS works).
# AI (Big Pickle) FIX — Beta-v2.9.69 [FLATPAK-NM-DISPATCH-LOCK]: the events
# above can arrive back-to-back AND `up` re-fires on DHCP renews / link flaps
# (observed live on <host>: five pre-lock firings in ~30 min piled five
# concurrent `flatpak install` processes racing the same OSTree repo, none
# completing). The exclusive flock below serializes the drain: the first
# firing wins the lock and runs; the rest bail out and re-arm on whichever
# network event comes next (a completed run leaves the .done stamp anyway;
# flock releases automatically on exit, so a crashed drain never wedges it).
case "$2" in
    up|vpn-up|connectivity-change) ;;
    *) exit 0 ;;
esac
command -v flatpak >/dev/null 2>&1 || exit 0
[ -f /var/log/flatpak-firstboot.done ] && exit 0
exec 9>/var/lock/flatpak-firstboot.lock
flock -n 9 || exit 0
# Need a default route (internet reachable) for flathub to resolve
ip route show default >/dev/null 2>&1 || exit 0
_fp_queue="/home/__TARGET_USER__/.config/void-installer/flatpak-install-on-first-boot.txt"
[ -f "$_fp_queue" ] || exit 0
echo "=== flatpak-firstboot: $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
: > /var/log/flatpak-firstboot.log
_fp_fail=0
while IFS= read -r _fp_app_id; do
    [ -n "$_fp_app_id" ] || continue
    echo "==> Installing queued Flatpak app: ${_fp_app_id}"
    if ! flatpak install -y --noninteractive flathub "$_fp_app_id" >> /var/log/flatpak-firstboot.log 2>&1; then
        echo "WARNING: failed to install queued Flatpak app '${_fp_app_id}' — will retry on next up event." >&2
        _fp_fail=1
    fi
done < "$_fp_queue"
# [FLATPAK-NM-DISPATCH-STAMP] (Beta-v2.9.46): stamp only when every install
# succeeded, so a partial failure leaves the queue live for the next event.
if [ "$_fp_fail" -eq 0 ]; then
    touch /var/log/flatpak-firstboot.done
else
    echo "WARNING: one or more queued Flatpak installs failed — queue is still live." >&2
fi
DIS_EOF
    chmod 0755 /etc/NetworkManager/dispatcher.d/99-flatpak-firstboot
    sed -i "s/__TARGET_USER__/${TARGET_USER}/g" /etc/NetworkManager/dispatcher.d/99-flatpak-firstboot
    echo "==> NetworkManager flatpak-firstboot dispatcher installed → /etc/NetworkManager/dispatcher.d/99-flatpak-firstboot"
fi

[ "$INSTALL_PODMAN" = "true" ] && install_pkgs podman
[ "$INSTALL_PODMAN_ROOTLESS" = "true" ] && install_pkgs fuse-overlayfs slirp4netns crun catatonit
[ "$INSTALL_DOCKER" = "true" ] && install_pkgs docker
if [ "$INSTALL_DOCKER" = "true" ] && [ "$DOCKER_GROUP_ADD" = "true" ]; then
    usermod -aG docker "$TARGET_USER"
fi

# AI (Claude, Sonnet 5, Medium) ADDITION — Beta-v2.3.0 [DISTROBOX-3] §4.13: podman image pulls
# by short name (e.g. "alpine:latest") fail outright with "no unqualified-
# search-registries are defined" until this file has at least one entry —
# confirmed directly against this exact error text on this exact machine.
# Provisioned any time podman itself is installed (not just for distrobox —
# any bare `podman pull alpine` needs it too), and grep-guarded so re-runs
# / repeated installs never duplicate the line.
if [ "$INSTALL_PODMAN" = "true" ]; then
    mkdir -p /etc/containers
    if ! grep -q '^unqualified-search-registries' /etc/containers/registries.conf 2>/dev/null; then
        echo 'unqualified-search-registries = ["docker.io", "registry.fedoraproject.org"]' >> /etc/containers/registries.conf
    fi
fi

# AI (Claude, Sonnet 5, Medium) ADDITION: distrobox has no xbps package on Void — see the long
# comment where INSTALL_DISTROBOX is prompted for, in Stage 1, for how this
# was confirmed. This runs upstream's official install script directly
# (fetched from GitHub, not from any xbps repo index) — a different trust
# model than everything else this script installs, which is why it's kept
# separate from install_pkgs and gated behind its own explicit prompt with
# a warning.
#
# AI (Claude, Sonnet 5, Medium) CHANGE — Beta-v2.3.0 [DISTROBOX-2]/[DISTROBOX-3]/[CLONE-RETRY]:
#   - "next" track builds the upstream v2 Go rewrite from source instead of
#     running the legacy install script: installs golang (only if the
#     "next" track is actually chosen, so stable/current installs never pay
#     that ~200MB cost), clones the repo with a 3-attempt/5-second-backoff
#     retry loop (§3.25/§4.14 — transient DNS flakiness on live-ISO installs
#     was observed as a real failure source, not hypothetical), checks out
#     the `next` branch, and runs `make build` then `make install
#     PREFIX=/usr/local`.
#   - Wrapper-cleanup ordering fixed (§3.24/§4.12): any old distrobox
#     wrapper binaries under /usr/local/bin are removed ONLY after `make
#     install` has already succeeded, never before. The old ordering
#     (clean first, install second) could strand a system with no
#     distrobox at all if the build failed partway through.
DISTROBOX_VERSION="1.8.2.5"
if [ "$INSTALL_DISTROBOX" = "true" ]; then
    if [ "$DISTROBOX_TRACK" = "next" ]; then
        if command -v curl >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
            install_pkgs go
            DBX_CLONE_DIR="/tmp/distrobox-next-build"
            rm -rf "$DBX_CLONE_DIR"
            DBX_CLONE_OK=0
            for _dbx_attempt in 1 2 3; do
                echo "==> Cloning distrobox (next track), attempt ${_dbx_attempt}/3..."
                if git clone --quiet https://github.com/89luca89/distrobox.git "$DBX_CLONE_DIR"; then
                    DBX_CLONE_OK=1
                    break
                fi
                echo "==> distrobox clone attempt ${_dbx_attempt} failed, retrying in 5s..." >&2
                sleep 5
            done
            if [ "$DBX_CLONE_OK" -ne 1 ]; then
                echo "WARNING: distrobox 'next' track clone failed after 3 attempts — skipping distrobox install." >&2
            else
                (
                    cd "$DBX_CLONE_DIR"
                    git checkout --quiet next
                    make build
                    make install PREFIX=/usr/local
                )
                # Cleanup runs ONLY after the subshell above has exited
                # successfully (set -e propagates its failure up and skips
                # this line entirely) — see [DISTROBOX-2] above.
                rm -f /usr/local/bin/distrobox-legacy-wrapper 2>/dev/null || true
            fi
        else
            echo "WARNING: curl/git not found — skipping distrobox 'next' track install." >&2
        fi
    else
        if command -v curl >/dev/null 2>&1; then
            if [ "$DISTROBOX_TRACK" = "current" ]; then
                curl -fsSL "https://raw.githubusercontent.com/89luca89/distrobox/legacy/install" | sh
            else
                curl -fsSL "https://raw.githubusercontent.com/89luca89/distrobox/legacy/install" \
                    | sh -s -- --version "$DISTROBOX_VERSION"
            fi
        else
            echo "WARNING: curl not found — skipping distrobox install." >&2
        fi
    fi

    # AI (Claude, Sonnet 5, Medium) ADDITION: only written when a real choice
    # was actually made in Stage 1 (both podman-family and docker present);
    # DISTROBOX_DEFAULT_ENGINE is empty otherwise, in which case distrobox
    # is left to its own upstream default (prefers podman if available).
    if [ -n "$DISTROBOX_DEFAULT_ENGINE" ]; then
        mkdir -p "/home/${TARGET_USER}/.config/distrobox"
        cat > "/home/${TARGET_USER}/.config/distrobox/distrobox.conf" << INNER_EOF
container_manager="${DISTROBOX_DEFAULT_ENGINE}"
INNER_EOF
        chown -R "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.config/distrobox"
    fi
fi

mkdir -p /etc/profile.d
cat > /etc/profile.d/flatpak-xdg-fix.sh << 'INNER_EOF'
#!/bin/sh
FLATPAK_SYSTEM_DIR="/var/lib/flatpak/exports/share"
FLATPAK_USER_DIR="${HOME}/.local/share/flatpak/exports/share"
if [ -z "${XDG_DATA_DIRS}" ]; then
    XDG_DATA_DIRS="/usr/local/share:/usr/share"
fi
case ":${XDG_DATA_DIRS}:" in
    *:"${FLATPAK_SYSTEM_DIR}":*) ;;
    *) XDG_DATA_DIRS="${FLATPAK_SYSTEM_DIR}:${XDG_DATA_DIRS}" ;;
esac
case ":${XDG_DATA_DIRS}:" in
    *:"${FLATPAK_USER_DIR}":*) ;;
    *) XDG_DATA_DIRS="${FLATPAK_USER_DIR}:${XDG_DATA_DIRS}" ;;
esac
export XDG_DATA_DIRS
INNER_EOF
chmod +x /etc/profile.d/flatpak-xdg-fix.sh

mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/30-mac-randomization.conf << 'INNER_EOF'
[device-mac-randomization]
wifi.scan-rand-mac-address=yes
[connection-mac-randomization]
ethernet.cloned-mac-address=stable
wifi.cloned-mac-address=stable
connection.stable-id=${CONNECTION}/${BOOT}
ipv4.dhcp-client-id=mac
ipv4.dhcp-iaid=mac
ipv6.dhcp-duid=ll
INNER_EOF

# AI (Big Pickle) CHANGE — Beta-v2.9.86 [BR0-SKIP]: write the bridged pair
# ONLY when the re-probe left a real answer. An EMPTY NET_INTERFACE_MATCH is
# the explicit "no wired hardware at all — skip br0" signal (previously an
# unconditional WARNING + "enp*" placeholder wrote a bridge that could never
# have a member on a Wi-Fi-only box, while rc.local still killed virbr0 —
# leaving virt with NO VM networking — and the role-matched slave stayed free
# to adopt whatever USB NIC showed up later). The value round-trips through
# resume state + chroot_env, so a resumed run keeps the same decision.
if [ "$INSTALL_VIRT" = "true" ] && [ -n "${NET_INTERFACE_MATCH:-}" ]; then
mkdir -p /etc/NetworkManager/system-connections

cat > /etc/NetworkManager/system-connections/br0.nmconnection << 'INNER_EOF'
[connection]
id=br0
uuid=a6b8c9d0-1234-4567-abcd-ef0123456789
type=bridge
interface-name=br0

[bridge]
stp=false

[ipv4]
method=auto

[ipv6]
method=auto
INNER_EOF
chmod 600 /etc/NetworkManager/system-connections/br0.nmconnection

# AI (Big Pickle) FIX — Beta-v2.5.2 [NM-IFACE]: NetworkManager's `[connection]
# interface-name=` is a LITERAL device name, not a glob (only `[match]` globs).
# So the detection fallback NET_INTERFACE_MATCH="enp*" must NOT be emitted as an
# `interface-name=` line — it would never match a real device and the slave would
# never bind. When we only have the wildcard placeholder (no specific NIC found),
# omit the key entirely so the bridge-slave is matched by role (any free ethernet
# device), which is exactly the intended fallback. The normal detected-NIC path
# (a concrete name like enp3s0) still emits a literal interface-name=.
if case "$NET_INTERFACE_MATCH" in *"*"*) true ;; *) false ;; esac; then
    _SLV_IFACE_LINE=""    # glob placeholder (no concrete NIC) -> role-matched slave
else
    _SLV_IFACE_LINE="interface-name=${NET_INTERFACE_MATCH}"
fi
cat > /etc/NetworkManager/system-connections/br0-slave.nmconnection << INNER_EOF
[connection]
id=br0-slave
uuid=b7c9d0e1-5678-9012-bcde-f0123456789a
type=ethernet
${_SLV_IFACE_LINE}
master=br0
slave-type=bridge
INNER_EOF
unset _SLV_IFACE_LINE
chmod 600 /etc/NetworkManager/system-connections/br0-slave.nmconnection
elif [ "$INSTALL_VIRT" = "true" ]; then
    # AI (Big Pickle) ADDITION — Beta-v2.9.86 [BR0-SKIP]: announce the skip at
    # the actual write site too — a RESUMED run (whose re-probe NOTICE already
    # printed in the interrupted run) still records the outcome in this log.
    echo "NOTICE: [BR0-SKIP] no wired NIC — br0/br0-slave profiles skipped; virbr0 stays enabled as the VM-networking fallback."
fi

mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/99-kvm-routing.conf << 'INNER_EOF'
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
INNER_EOF

# =============================================================================
# AUDIO AND HYPERVISOR SERVICE ORCHESTRATION LAYER
# =============================================================================

# AI (Big Pickle) ADDITION — Beta-v2.9.48 [HEADLESS-AUDIO]: on a fully-headless
# (console-only) box the audio stack is gated on INSTALL_AUDIO, which is set
# by the [HEADLESS-AUDIO] prompt in Stage 1 (explicit [y/N] when
# HAS_GRAPHICAL=no, unconditional true when HAS_GRAPHICAL=yes).
if [ "${INSTALL_AUDIO:-true}" = "true" ]; then
    install_pkgs alsa-utils alsa-ucm-conf alsa-pipewire pipewire wireplumber sof-firmware libjack-pipewire
    [ "$PROFILE_BT" = "true" ] && install_pkgs libspa-bluetooth
    # plasma-pa (the Plasma systray volume applet) only means anything under
    # KDE — Cinnamon's own cinnamon-settings-daemon already provides a volume
    # applet, no separate package needed.
    [ "$DESKTOP_ENV" = "kde" ] && install_pkgs plasma-pa
fi

# AI (Big Pickle) ADDITION — Beta-v2.9.48 [HEADLESS-AUDIO]: the ALSA/JACK
# config wiring (pipewire conf.d symlinks, the realtime limits, the alsa
# bridge) is part of the audio stack, so it rides the same INSTALL_AUDIO
# gate — a headless box that declined audio must not collect dangling
# symlinks or an rtprio limits file for a stack it doesn't ship.
if [ "${INSTALL_AUDIO:-true}" = "true" ]; then
    mkdir -p /etc/alsa/conf.d
    ln -sf /usr/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d/
    ln -sf /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/

    echo "/usr/lib/pipewire-0.3/jack" > /etc/ld.so.conf.d/pipewire-jack.conf
    ldconfig

    mkdir -p /etc/security/limits.d
    cat > /etc/security/limits.d/95-pipewire-realtime.conf << 'INNER_EOF'
@audio   -   rtprio   95
@audio   -   memlock  unlimited
INNER_EOF

    mkdir -p /etc/pipewire/pipewire.conf.d
    [ -f /usr/share/examples/wireplumber/10-wireplumber.conf ] && \
        ln -sf /usr/share/examples/wireplumber/10-wireplumber.conf /etc/pipewire/pipewire.conf.d/
    [ -f /usr/share/examples/wireplumber/20-pipewire-pulse.conf ] && \
        ln -sf /usr/share/examples/wireplumber/20-pipewire-pulse.conf /etc/pipewire/pipewire.conf.d/
fi

# AI (Claude, Sonnet 5, Medium) — the wrapper script and its rationale carry forward
# unchanged from 3.0.x: checks /proc/cmdline directly for the overlay flag
# and either execs the real command or exits quietly, rather than relying
# on a KDE autostart-condition key (confirmed broken — wrong casing, wrong
# value format, and a file that's never created — see the long comment
# this replaced in earlier revisions of this script).
mkdir -p /usr/local/bin
cat > /usr/local/bin/live-overlay-skip << 'INNER_EOF'
#!/bin/sh
# Exits quietly without running the wrapped command when booting from a
# read-only dracut overlay snapshot, to avoid PipeWire's real-time thread
# setup fighting the volatile RAM overlay and freezing the session. On a
# normal boot it execs the real command unchanged.
if grep -q 'rd.live.overlay.overlayfs=1' /proc/cmdline 2>/dev/null; then
    exit 0
fi
exec "$@"
INNER_EOF
chmod +x /usr/local/bin/live-overlay-skip

mkdir -p "/home/${TARGET_USER}/.config/autostart"
# AI (Claude, Sonnet 5, Medium) ADDITION: strip any OnlyShowIn=/NotShowIn=
# key from the copied .desktop files. These are vendor-shipped (octoxbps
# is Qt-based, the pipewire ones may or may not carry a restriction — not
# verifiable without network access in this environment) and now that
# $DESKTOP_ENV can be Cinnamon (XDG_CURRENT_DESKTOP=X-Cinnamon) as well as
# KDE (XDG_CURRENT_DESKTOP=KDE), an unnoticed "OnlyShowIn=KDE;" would
# silently kill autostart under Cinnamon with no error at all — it just
# never runs. Our own live-overlay-skip wrapper is the only gate these
# should be subject to, independent of which DE shipped the file or which
# DE is actually running.
strip_desktop_restrictions() {
    sed -i -E '/^(OnlyShowIn|NotShowIn)=/d' "$1"
}

[ -f /usr/share/applications/octoxbps-notifier.desktop ] && \
    cp -f /usr/share/applications/octoxbps-notifier.desktop "/home/${TARGET_USER}/.config/autostart/"
[ -f "/home/${TARGET_USER}/.config/autostart/octoxbps-notifier.desktop" ] && \
    strip_desktop_restrictions "/home/${TARGET_USER}/.config/autostart/octoxbps-notifier.desktop"

for pw_desktop in pipewire pipewire-pulse; do
    if [ -f "/usr/share/applications/${pw_desktop}.desktop" ]; then
        cp -f "/usr/share/applications/${pw_desktop}.desktop" "/home/${TARGET_USER}/.config/autostart/"
        strip_desktop_restrictions "/home/${TARGET_USER}/.config/autostart/${pw_desktop}.desktop"
        if [ "${ENABLE_SNAPSHOT_AUDIO}" != "true" ]; then
            sed -i -E "s|^Exec=(.*)|Exec=/usr/local/bin/live-overlay-skip \1|" \
                "/home/${TARGET_USER}/.config/autostart/${pw_desktop}.desktop"
        fi
    fi
done
chown -R "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.config"

# AI (Claude, Sonnet 5, Medium) NOTE — related but separate from the
# autostart question: Cinnamon has no equivalent to Plasma's bundled
# polkit-kde-agent (part of the kde-plasma metapackage), so GUI privilege
# prompts (NetworkManager, blueman, etc.) may have no agent to talk to
# under DESKTOP_ENV=cinnamon. Void's `cinnamon` metapackage's own
# dependency chain was not verified against network access in this
# environment — confirm on first Cinnamon test boot whether a polkit agent
# is already pulled in, and if not, add one (e.g. lxqt-policykit or
# polkit-gnome) gated on DESKTOP_ENV=cinnamon.

mkdir -p "/home/${TARGET_USER}/.cache"

# AI (Claude, Sonnet 5, Medium) ADDITION: shared, unit-tested helper for
# every per-browser isolated-profile subvolume — replaces the old
# hardcoded .mozilla/.config/chromium-only block. Handles arbitrary
# nesting depth correctly (walks and chowns EVERY intermediate parent
# directory under $HOME before touching the leaf), which matters here
# specifically because Brave's real profile path
# (.config/BraveSoftware/Brave-Browser) is two levels deep and
# .config/BraveSoftware doesn't exist yet at this point — this is the
# exact bug class already found and fixed once for
# ~/.local/share/containers (podman-rootless): mkdir -p silently creating
# root-owned intermediate directories that only the LEAF gets chowned,
# leaving a parent unwritable by the target user. Verified in isolation
# (not just reasoned about) across all three real nesting depths this
# script uses — 1 parent segment (.config/mozilla, .cache/mozilla,
# .config/vivaldi) and 2 (.config/BraveSoftware/Brave-Browser) — including
# an actual write test
# as a second, non-root user, before this went anywhere near the script.
provision_browser_subvol() {
    _pbs_subvol="$1"
    _pbs_relpath="$2"
    _pbs_fullpath="/home/${TARGET_USER}/${_pbs_relpath}"

    case "$_pbs_relpath" in
        */*)
            _pbs_walk="/home/${TARGET_USER}"
            _pbs_parent_chain="${_pbs_relpath%/*}"
            _pbs_old_ifs="$IFS"
            IFS='/'
            for _pbs_seg in $_pbs_parent_chain; do
                _pbs_walk="${_pbs_walk}/${_pbs_seg}"
                mkdir -p "$_pbs_walk"
                chown "${TARGET_USER}:${TARGET_USER}" "$_pbs_walk"
            done
            IFS="$_pbs_old_ifs"
            ;;
    esac

    mkdir -p "$_pbs_fullpath"
    chown "${TARGET_USER}:${TARGET_USER}" "$_pbs_fullpath"
    # The browser subvol is made nodatacow by this fstab mount option; no
    # `chattr +C` — a post-mount chattr would touch the covered mountpoint
    # inode, not the subvolume, so it cannot take effect.
    # fstab is whitespace-delimited, so any space in the mountpoint path must be
    # escaped as `\040` for the entry to parse as a single field (e.g. VirtualBox's
    # "VirtualBox VMs"). The shell var $FSTAB_MOUNT holds the escaped path.
    local _pbs_fstab="/home/${TARGET_USER}/${_pbs_relpath// /\\040}"
    echo "UUID=${BTRFS_UUID} ${_pbs_fstab} btrfs noatime,nodatacow,subvol=${_pbs_subvol} 0 0" >> /etc/fstab
    mount "$_pbs_fullpath"
    chown "${TARGET_USER}:${TARGET_USER}" "$_pbs_fullpath"
    chmod 700 "$_pbs_fullpath"
}

# AI (Big Pickle) ADDITION — Beta-v2.4.0 [item 4]: Firefox-specific helper.
# Modern Firefox uses the XDG base-dir layout (NOT the legacy ~/.mozilla):
#   - profile + sqlite DBs  -> ~/.config/mozilla            (@mozilla)
#   - cache                 -> ~/.cache/mozilla             (@mozilla-cache)
# Both are isolated nodatacow subvolumes (profile for the same churn/COW
# reason as before; cache because Firefox's disk cache is pure write churn).
# Two calls reuse the parent-safety logic of provision_browser_subvol, but a
# Firefox install requires BOTH, so it is wrapped here and gated once.
provision_firefox_subvols() {
    provision_browser_subvol "@mozilla" ".config/mozilla"
    provision_browser_subvol "@mozilla-cache" ".cache/mozilla"
}

# AI (Claude, Sonnet 5, Medium) ADDITION: a subvolume gets provisioned if the
# browser is being installed OR was explicitly pre-provisioned anyway
# (mirrors the SUBVOL_LIST conditions from Stage 1 — both need to agree,
# since the subvolume itself only exists on disk if Stage 1 created it).
[ "$PROVISION_FIREFOX_SUBVOL" = "true" ] && provision_firefox_subvols
[ "$PROVISION_CHROMIUM_SUBVOL" = "true" ] && provision_browser_subvol "@chromium" ".config/chromium"
[ "$PROVISION_VIVALDI_SUBVOL" = "true" ] && provision_browser_subvol "@vivaldi" ".config/vivaldi"
[ "$PROVISION_FALKON_SUBVOL" = "true" ] && provision_browser_subvol "@falkon" ".config/falkon"
[ "$PROVISION_BRAVE_SUBVOL" = "true" ] && provision_browser_subvol "@brave" ".config/BraveSoftware/Brave-Browser"
# AI (Big Pickle) ADDITION — Beta-v2.6.1 [SUBVOLS]: Thunderbird and Steam
# get the same per-user isolation. Thunderbird's profile dir is exactly the
# sqlite-heavy case the browser subvols exist for; Steam sits under
# ~/.local/share/Steam (the helper's nested-parent chain chowns each level,
# avoiding the old root-owned ~/.local/share bug class). Fires on the RESOLVED
# PROVISION_*_SUBVOL flag (Beta-v2.9.0 [SUBVOL-GATES]: folded from the app's
# install choice + the two master gates) — the single source of truth.
[ "$PROVISION_THUNDERBIRD_SUBVOL" = "true" ] && provision_browser_subvol "@thunderbird" ".thunderbird"
# AI (Big Pickle) ADDITION — Beta-v2.9.37 [GAME-SUBVOL]: ONE per-user @game
# subvol mounted at EACH adopted launcher's standard data dir (a btrfs
# subvolume may mount at several paths). The mount set is DERIVED from the
# launchers actually selected — Steam-only installs yield only the Steam
# mount; lutris selected → its ~/.local/share/lutris path too. Heroic/Bottles
# are deliberately NOT in the set: they install via Flatpak ([GAME-FLATPAK-GATE]
# Beta-v2.9.40), so their data lives under @home at ~/.var/app/... Deliberately
# NOT mounted: ~/Games (default install dir, @home is already rollback-exempt)
# and ~/.wine (Bottles/Lutris manage their own prefixes). Fired on the RESOLVED
# PROVISION_GAME_SUBVOL flag — the single source of truth (Gate 1/Gate 2).
# Beta-v2.9.38 [MULTI-FS]: when the games region is carved, ~/Games is a plain
# dir on the games partition (mounted in Stage 1 by [MULTI-FS] region mounts);
# the @game subvol isolation is unaffected — both can coexist.
if [ "$PROVISION_GAME_SUBVOL" = "true" ]; then
    [ "$INSTALL_STEAM"  = "true" ] && provision_browser_subvol "@game" ".local/share/Steam"
    [ "$INSTALL_LUTRIS" = "true" ] && provision_browser_subvol "@game" ".local/share/lutris"
fi
# AI (Big Pickle) ADDITION — [VIRTUALBOX]: VirtualBox keeps its VM library
# under ~/VirtualBox VMs by default. Same per-user isolation model as the
# browser/Steam/Thunderbird subvols: Stage-1 creates the @virtualbox top-level
# sibling, this call creates/chowns/mounts the per-user VM folder. Singular
# relative path (no nested chain), so the helper's mkdir+chown runs directly.
[ "$PROVISION_VIRTUALBOX_SUBVOL" = "true" ] && provision_browser_subvol "@virtualbox" "VirtualBox VMs"
# AI (Big Pickle) ADDITION — Beta-v2.9.36 [INSTALL-BREW]: Homebrew's
# ~/.linuxbrew user-owned prefix. Same per-user isolation model; fired on the
# RESOLVED PROVISION_LINUXBREW_SUBVOL (Gate 1/Gate 2, default OFF). Declining
# leaves a correctly-owned plain ~/.linuxbrew in @home (survives @ rollback,
# not snapshotted) so declining the subvolume can never break rootless brew.
[ "$PROVISION_LINUXBREW_SUBVOL" = "true" ] && provision_browser_subvol "@linuxbrew" ".linuxbrew"

if [ "$INSTALL_PODMAN_ROOTLESS" = "true" ]; then
    # Profile-data ownership for podman-rootless, confirmed via real
    # hardware bisection (works with everything except podman enabled; breaks
    # the instant podman-rootless is added, with virtualization/flatpak/
    # octoxbps all cleared independently). Root cause: this was the ONLY place
    # in the entire script that ever touches ~/.local or ~/.local/share —
    # neither exists in Void's /etc/skel, so `mkdir -p .../containers` was
    # silently creating BOTH parent directories too, as root, and the chown
    # below only ever fixed the leaf (`containers`) — never its parents. Left
# `~/.local/share` itself root-owned and unwritable by the target user,
# which is where a huge share of a Cinnamon/GTK session's runtime data
# lives (~/.local/share/cinnamon, gvfs-metadata, per-user Xorg logs,
# D-Bus session-activated services, dconf, keyring...) — all of it failing
# to write silently at session start is a very plausible match for "X
# server starts fine, cursor works, desktop never actually loads." Same
# bug CLASS already fixed once elsewhere in this script for ~/.cache
# (chown-the-placeholder-before-mount) — that fix didn't cover this case
# since the problem here is mkdir -p's intermediate parents, not a mount.
# Fixed with an explicit, ownership-first creation of the whole .local
# chain, then a recursive chown as a second safety net in case anything
# upstream (a future package's postinstall, for instance) ever creates
# part of that chain as root again before this point.
mkdir -p "/home/${TARGET_USER}/.local" "/home/${TARGET_USER}/.local/share"
chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.local" "/home/${TARGET_USER}/.local/share"
mkdir -p "/home/${TARGET_USER}/.local/share/containers"
chown -R "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.local"
# AI (Big Pickle) ADDITION — Beta-v2.9.2 [PODMAN-ROOTLESS-SUBVOL]: the
# @containers-user ISOLATION (fstab mount over the placeholder above) is gated
# on the resolved PROVISION_PODMAN_ROOTLESS_SUBVOL flag — Gate 1/Gate 2 decide
# it, exactly like the browser subvols. The mkdir/chown above stay
# unconditional so a declined isolation still leaves a correctly-owned plain
# ~/.local/share/containers for rootless podman (its data lands in @home).
# The subuid/subgid + containers.conf below are MANDATORY for rootless podman
# to work at all, so they also stay unconditional — declining the subvolume
# must never break rootless operation.
if [ "$PROVISION_PODMAN_ROOTLESS_SUBVOL" = "true" ]; then
    echo "UUID=${BTRFS_UUID} /home/${TARGET_USER}/.local/share/containers btrfs noatime,compress=zstd:1,subvol=@containers-user 0 0" >> /etc/fstab
    mount "/home/${TARGET_USER}/.local/share/containers"
    chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.local/share/containers"
    chmod 700 "/home/${TARGET_USER}/.local/share/containers"
fi

if ! grep -q "^${TARGET_USER}:" /etc/subuid 2>/dev/null; then
    echo "${TARGET_USER}:100000:65536" >> /etc/subuid
fi
if ! grep -q "^${TARGET_USER}:" /etc/subgid 2>/dev/null; then
    echo "${TARGET_USER}:100000:65536" >> /etc/subgid
fi

mkdir -p "/home/${TARGET_USER}/.config/containers"
cat > "/home/${TARGET_USER}/.config/containers/containers.conf" << INNER_EOF
[engine]
cgroup_manager = "cgroupfs"
INNER_EOF
chown -R "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.config/containers"
fi

# AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS]: when the home region is
# carved onto its own partition, @usercache has been folded out of the root
# layout and ~/.cache lives directly on the home region partition — creating/
# mounting @usercache here would shadow it. Threaded via chroot_env.
case " ${REGION_PARTITIONED:-} " in
    *" home "*)
        echo "MULTI-FS: home region carved — skipping @usercache fstab/mount (~/.cache lives on the home partition)."
        # AI (Big Pickle) FIX — Beta-v2.9.65 [HOME-CACHE-CHOWN]: the ONLY ~/.cache
        # chown in the script lives in the @usercache branch right below, so on a
        # carved-home install the root-created ~/.cache from the browser-subvol
        # prep (mkdir -p "/home/${TARGET_USER}/.cache" above) stayed root:root
        # 0755 forever. A root-owned ~/.cache silently breaks the whole graphical
        # desktop on first boot: ksycoca cannot create/lock its DB (empty KDE app
        # launcher, blank panel), the AppStream runner cache refuses to write,
        # mesa shader cache is disabled, and firefox dies on ~/.cache/mozilla with
        # "Permission denied". Proven on real hardware (<host>, carved ENCRYPT
        # /home, KDE, Beta-v2.9.13) — chowning the dir + chmod 700 (the exact
        # @usercache branch line) restored ksycoca + firefox with zero other
        # changes.
        chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.cache"
        chmod 700 "/home/${TARGET_USER}/.cache"
        ;;
    *)
        echo "UUID=${BTRFS_UUID} /home/${TARGET_USER}/.cache btrfs noatime,compress=zstd:1,subvol=@usercache,noauto 0 0" >> /etc/fstab
        chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.cache"
        mount "/home/${TARGET_USER}/.cache"
        chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.cache"
        chmod 700 "/home/${TARGET_USER}/.cache"
        ;;
esac

# AI (Big Pickle) CHANGE — Beta-v2.4.0 [SWAP]: activate the disk swapfile only when
# a disk swapfile backend was chosen (swapfile or both).
if [ "$SWAP_BACKEND" = "swapfile" ] || [ "$SWAP_BACKEND" = "both" ]; then
    swapon /var/swap/swapfile
fi
# AI (Big Pickle) ADDITION — Beta-v2.4.0 [SWAP]: provision zram (compressed-RAM
# swap) when the backend is zram or both. zramen installs the runit service and
# loads the zram module; we write a sane config here and enable the service for
# first boot in the rc.local block. (See the __SWAP_BACKEND__ placeholder in
# /etc/rc.local provisioning.)
if [ "$SWAP_BACKEND" = "zram" ] || [ "$SWAP_BACKEND" = "both" ]; then
    install_pkgs zramen
    cat > /etc/sv/zramen/conf << 'ZRAM_CONF'
# AI (Big Pickle) generated zramen config — Beta-v2.4.0 [SWAP]
export ZRAM_COMP_ALGORITHM=zstd
export ZRAM_PRIORITY=100
export ZRAM_SIZE=50
ZRAM_CONF
fi

install_pkgs snapper

# =============================================================================
# BOOTLOADER: GRUB or LIMINE, per $BOOTLOADER  [LIMINE-1] [LIMINE-2]
# =============================================================================
# AI (Claude, Sonnet 5, Medium) CHANGE — Beta-v2.3.0: both bootloader paths now coexist,
# gated on the choice made in Stage 1. GRUB's branch below is carried
# forward essentially unchanged from 3.0.112GC (grub-btrfs dynamic
# snapshot menu, confirmed real-hardware working including snapshot boot).
# Limine's branch is the new, still-experimental path from this beta line
# (CHANGELOG §4.7/§4.9) — static config this script writes itself, no
# grub-mkconfig-style generator.
if [ "$BOOTLOADER" = "grub" ]; then

install_pkgs grub-x86_64-efi efibootmgr
# AI (Big Pickle) CHANGE — Beta-v2.6.2 [GRUB-ESP-BOOT]: under GRUB+ENCRYPT
# the ESP IS /boot (vfat covering the whole boot tree), so grub-install must
# point --efi-directory at /boot — GRUB's prefix, modules, and grub.cfg all
# land on the unencrypted ESP; GRUB never opens the LUKS volume.
if [ "$GRUB_ESP_BOOT" = "true" ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id="Void_GRUB" --recheck
else
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Void_GRUB" --recheck
fi

# AI (Big Pickle) CHANGE — Beta-v2.4.0 [SWAP]: resume-from-disk kernel params are
# only added when hibernation was enabled at install time (and a disk swapfile
# actually exists). Otherwise GRUB gets a plain cmdline with no resume= params.
# AI (Big Pickle) ADDITION — Beta-v2.5.5 [ENCRYPT]: when encryption is
# enabled, the LUKS container UUID is injected via rd.luks.uuid= + a fixed
# rd.luks.name= so dracut's `crypt` module opens void-root before root is
# mounted. `resume=` keeps the Btrfs filesystem UUID — the swapfile lives
# inside the LUKS volume, so hibernation resumes after the volume is
# unlocked.
if [ "$ENCRYPT" = "yes" ]; then
    LUKS_RD="rd.luks.uuid=${LUKS_UUID} rd.luks.name=${LUKS_UUID}=${CRYPT_NAME:-void-root}"
else
    LUKS_RD=""
fi
if [ "$ENABLE_HIBERNATION" = "true" ] && [ -f /var/swap/swapfile ]; then
    TARGET_OFFSET=$(btrfs inspect-internal map-swapfile -r /var/swap/swapfile)
    GRUB_CMD="loglevel=3 ${LUKS_RD} resume=UUID=${BTRFS_UUID} resume_offset=${TARGET_OFFSET}"
else
    GRUB_CMD="loglevel=3 ${LUKS_RD}"
fi
# AI (Big Pickle) ADDITION — Beta-v2.9.47 [TEE-BOOT-QUIET]/[TEE-BLACKLIST]:
# thread the shared TEE_QB_FRAG ("quiet" + "modprobe.blacklist=tee") into the
# GRUB cmdline. For GRUB the fragment is baked once here into
# GRUB_CMDLINE_LINUX_DEFAULT (no limine-env generator exists on the GRUB
# branch); the limine branch re-derives the identical fragment from its
# persisted PUBLIC rows on every resync.
TEE_QB_FRAG=""
if [ "${DEFAULT_QUIET_BOOT:-no}" = "yes" ]; then
    TEE_QB_FRAG=" quiet"
fi
if [ "${DEFAULT_TEE_BLACKLIST:-no}" = "yes" ]; then
    TEE_QB_FRAG="${TEE_QB_FRAG} modprobe.blacklist=tee"
fi
GRUB_CMD="${GRUB_CMD}${TEE_QB_FRAG}"
unset TEE_QB_FRAG
sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/d' /etc/default/grub
echo "GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_CMD\"" >> /etc/default/grub

install_pkgs grub-btrfs grub-btrfs-runit
mkdir -p /etc/default/grub-btrfs
if [ -f /usr/share/doc/grub-btrfs/examples/config ]; then
    cp /usr/share/doc/grub-btrfs/examples/config /etc/default/grub-btrfs/config
fi
echo 'GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS="rd.live.overlay.overlayfs=1"' >> /etc/default/grub-btrfs/config

# CRITICAL — DO NOT REMOVE, DO NOT ASSUME REDUNDANT: this explicit
# grub-mkconfig call is the ONLY thing that reliably generates
# /boot/grub/grub.cfg on a fresh install — see the long-form version of
# this warning at the top of this file (DO NOT #1) and in the 3.0.x
# script history. The kernel-hook copy (99-grub-btrfs, installed below)
# keeps grub.cfg current on every SUBSEQUENT kernel install/remove; it
# does not reliably fire during the initial install itself. Leave both.
grub-mkconfig -o /boot/grub/grub.cfg

mkdir -p /etc/kernel.d/post-install /etc/kernel.d/post-remove
cat > /etc/kernel.d/post-install/99-grub-btrfs << 'INNER_EOF'
#!/bin/sh
export PATH="/usr/bin:/usr/sbin:/bin:/sbin"

# A balance or resize can relocate the swapfile's physical extents even
# though it's nodatacow, which silently invalidates the baked-in
# resume_offset. Recompute it on every kernel hook run (install/remove both
# trigger this file) so hibernation resume never boots against a stale value.
if [ -f /var/swap/swapfile ]; then
    echo "==> Recomputing hibernation resume_offset..."
    NEW_OFFSET=$(btrfs inspect-internal map-swapfile -r /var/swap/swapfile 2>/dev/null || echo "")
    if [ -n "$NEW_OFFSET" ]; then
        sed -i -E "s/resume_offset=[0-9]+/resume_offset=${NEW_OFFSET}/" /etc/default/grub
    else
        echo "WARNING: could not recompute resume_offset; leaving existing value in /etc/default/grub." >&2
    fi
fi

echo "==> XBPS Trigger: Regenerating GRUB menu with Btrfs snapshots..."
if command -v grub-mkconfig >/dev/null 2>&1; then
    grub-mkconfig -o /boot/grub/grub.cfg
else
    echo "ERROR: grub-mkconfig binary not found." >&2
    exit 1
fi
INNER_EOF
chmod +x /etc/kernel.d/post-install/99-grub-btrfs
cp /etc/kernel.d/post-install/99-grub-btrfs /etc/kernel.d/post-remove/99-grub-btrfs

else
# BOOTLOADER = limine
# AI (Claude, Sonnet 5, Medium) ADDITION — Beta-v2.3.0: replaces the GRUB install /
# grub-mkconfig / grub-btrfs block above. See CHANGELOG §4.7/§4.9.
install_pkgs limine

LIMINE_EFI_SRC=""
for _limine_efi_candidate in /usr/share/limine/BOOTX64.EFI /usr/share/limine/BOOTX64.efi; do
    [ -f "$_limine_efi_candidate" ] && LIMINE_EFI_SRC="$_limine_efi_candidate" && break
done
if [ -z "$LIMINE_EFI_SRC" ]; then
    echo "FATAL: could not find Limine's BOOTX64.EFI under /usr/share/limine — Limine install incomplete." >&2
    exit 1
fi
mkdir -p /boot/efi/EFI/BOOT
cp -f "$LIMINE_EFI_SRC" /boot/efi/EFI/BOOT/BOOTX64.EFI

# AI (Claude, Sonnet 5, Medium) ADDITION — Beta-v2.3.0 [KERNEL-MODE]/[KERNEL-HOOK] §4.8/§4.10:
# esp-copy mode keeps versioned kernel/initramfs copies for every
# installed kernel on the ESP (see [LIMINE-MULTI-KERNEL]) — limine.conf
# itself still never needs manual editing across kernel updates, since
# void-limine-write-conf regenerates the whole menu (one stanza per
# kernel found) rather than referencing fixed filenames.
if [ "$KERNEL_MODE" = "esp-copy" ]; then
    mkdir -p /boot/efi/void-kernel
fi

# AI (Claude, Sonnet 5, Medium) CHANGE — Beta-v2.3.0 [LIMINE-SYNC-CRON]: limine-snapper-sync
# (the openSUSE/Arch tool that auto-updates a bootloader's snapshot menu
# whenever snapper creates a NEW snapshot) has no Void package and no
# equivalent — Void's snapper build ships no general pre/post-snapshot
# hook mechanism to attach anything to (CHANGELOG Open Item #2). Rather
# than only regenerating limine.conf at kernel-hook time (which meant any
# timeline snapshot created between kernel updates was invisible in the
# menu until the next kernel install/remove), the snapshot-menu logic is
# now a single standalone script — /usr/local/sbin/void-limine-write-conf
# — invoked from TWO independent trigger points that both call the exact
# same file, so there is only one copy of the generation logic to keep in
# sync:
#   1. The kernel post-install/post-remove hook (handles the ESP
#      kernel/initramfs copy in esp-copy mode, then calls this script for
#      the config itself).
#   2. The 00-void-limine-snapper-sync snapper plugin ([SNPR-EV], installed
#      later in this same Limine branch), which regenerates limine.conf the
#      instant snapper creates or deletes a snapshot.
# Chosen over a runit-supervised inotify watcher: a kernel hook + snapper
# plugin pair can't be silently clobbered by a package update the way a
# long-running service can regress across runit/dracut/kernel changes, and
# there's no supervision-correctness (double-fork, signal handling,
# restart-on-crash) to get wrong.
#
# Beta-v2.5.6 ([SNPR-EV-NO-CRON]): the former /etc/cron.d/void-limine-sync
# 15-min safety-net generator was REMOVED. With the snapper plugin proven to
# fire reliably, the cron's only remaining value was a theoretical guard
# against snapshot operations that bypass snapper's own plugin runner — and
# rewriting limine.conf to the ESP every 15 minutes forever (flash wear,
# disk wakeups, menu churn) for a fallback that never needed to fire was not
# worth it. Menu updates now come from exactly two real events: a kernel
# install/remove (the hook) or a snapper snapshot create/delete (the
# plugin). A snapshot created outside snapper (e.g. a raw `btrfs subvolume
# snapshot`) will not show until one of those fires, which is accepted.
#
# Both trigger points, and the initial install-time call below, read their
# parameters (KERNEL_MODE, BTRFS_UUID, the two SYSPREFIX values) from a
# small persisted state file rather than any install-time bash environment
# — the standalone script has to work standing alone, long after this
# chroot phase and this shell are gone.
mkdir -p /etc/void-installer
cat > /etc/void-installer/limine-env << INNER_EOF
KERNEL_MODE="${KERNEL_MODE}"
BTRFS_UUID="${BTRFS_UUID}"
SYSPREFIX_ESP="${SYSPREFIX_ESP}"
SYSPREFIX_BTRFS="${SYSPREFIX_BTRFS}"
# AI (Big Pickle) ADDITION — Beta-v2.4.0 [SWAP]: baked at install time so the
# kernel/cron generators know whether to emit resume-from-disk kernel params.
HIBERNATION_ENABLED="${ENABLE_HIBERNATION}"
# AI (Big Pickle) ADDITION — Beta-v2.5.1 [LIMINE-WALLPAPER]: persisted so
# void-limine-write-conf keeps re-emitting the wallpaper lines on every
# kernel update / snapper-plugin resync (the regenerated limine.conf overwrites the
# file each time, so this must be state the generator can re-read).
LIMINE_WALLPAPER="${LIMINE_WALLPAPER}"
LIMINE_WALLPAPER_STYLE="${LIMINE_WALLPAPER_STYLE}"
# AI (Big Pickle) ADDITION — Beta-v2.9.47 [TEE-BOOT-QUIET]/[TEE-BLACKLIST]:
# env-only PUBLIC boot-cmdline knobs, persisted beside LIMINE_WALLPAPER so
# void-limine-write-conf re-derives the shared TEE_QB_FRAG ("quiet" +
# "modprobe.blacklist=tee") on every kernel update / snapper-plugin resync —
# the regenerated limine.conf is rewritten each time, so the fragment must be
# state the generator can re-read. "no" = absent from the cmdline.
DEFAULT_QUIET_BOOT="${DEFAULT_QUIET_BOOT:-no}"
DEFAULT_TEE_BLACKLIST="${DEFAULT_TEE_BLACKLIST:-no}"
# AI (Big Pickle) ADDITION — Beta-v2.5.5 [ENCRYPT]: persisted so
# void-limine-write-conf re-emits the rd.luks.uuid=/rd.luks.name= kernel
# params on every kernel update / snapper-plugin resync (the generated limine.conf is
# rewritten each time, so the LUKS knowledge must be state the generator can
# re-read, exactly like the wallpaper choice above). LUKS_UUID is the
# ciphertext container's header UUID — public (it is in rd.luks.uuid= on the
# boot cmdline), never the passphrase. Empty/unset when not encrypted.
ENCRYPT="${ENCRYPT}"
LUKS_UUID="${LUKS_UUID}"
# AI (Big Pickle) ADDITION — Beta-v2.7.1 [CRYPT-NAME]: the mapper name is
# persisted (public, non-secret) so void-limine-write-conf re-emits
# rd.luks.name=<this> on every kernel update / snapper-plugin resync. Defaults
# to void-root. Used together with LUKS_UUID above; only the name, never the
# passphrase.
CRYPT_NAME="${CRYPT_NAME:-void-root}"
# AI (Big Pickle) ADDITION — Beta-v2.5.4 [YUBIKEY]: persisted so
# void-limine-write-conf re-emits the rd.luks.name=void-root keyscript unlock
# params on every kernel update / snapper-plugin resync, consistent with how the
# encryption params above are carried. Only PUBLIC values are baked — SLOT and
# CHALLENGE are not credentials (the HMAC response is; it is NEVER persisted).
# Unset/empty when YubiKey unlock is off.
YK_MODE="${YK_MODE}"
YK_SLOT="${YK_SLOT}"
YK_CHALLENGE="${YK_CHALLENGE}"
YK_FALLBACK="${YK_FALLBACK}"
YK_TOUCH="${YK_TOUCH}"
INNER_EOF
chmod 644 /etc/void-installer/limine-env

# AI (Big Pickle) ADDITION — Beta-v2.5.1 [INSTALL-CONFIG]: write a
# human-readable record of every install-time CHOICE into the target, so the
# finished machine is self-documenting and reproducible without relying on
# this shell's (now-gone) environment or a USB transfer. This is the recovery-
# first project's equivalent of writing the "as-built" config onto the box
# itself. It deliberately excludes secrets: NO password hashes, only booleans/
# choices (limine-env, the resume-state file, or the account provisioning
# already stores whatever secrets the system actually needs at runtime).
mkdir -p /etc/void-installer
# AI (Big Pickle) FIX — Beta-v2.9.68 [INSTALL-CONFIG-SSHKEY]: `SSH_KEY_COMMENT`/
# `SSH_KEY_PROTECTED` are initialized to their prompt defaults BEFORE the
# [SSH-KEYS] prompts and exported unconditionally, so a run that imported AND
# generated nothing still wrote those two rows — a false positive that read as
# if a key existed. Derive presence from the actual deposit (done earlier this
# stage into ~/.ssh) and emit the comment/protection rows ONLY when present.
_ssh_key_present="no"
if [ -f "/home/${TARGET_USER}/.ssh/id_ed25519" ] || [ -f "/home/${TARGET_USER}/.ssh/imported" ]; then
    _ssh_key_present="yes"
fi
if [ "$_ssh_key_present" = "yes" ]; then
    _ssh_key_rows="SSH_KEY_COMMENT=\"${SSH_KEY_COMMENT:-<unset>}\"
SSH_KEY_PROTECTED=\"${SSH_KEY_PROTECTED:-<unset>}\""
else
    _ssh_key_rows="# (no SSH key imported or generated — comment/protection rows omitted)"
fi

# AI (Big Pickle) ADDITION — Beta-v2.9.84 [FLATPAK-PULL-DETECT]: safety net
# for the toggle's blind spots. The [COSMIC-STORE] prompt only appears when
# INSTALL_FLATPAK=true and its Stage-2 install site re-checks the flag (the
# Brave rule) — but nothing can stop a FUTURE metapackage revision (or a
# manual xbps-install) from pulling flatpak into a run where the operator
# explicitly declined it at the prompt. When INSTALL_FLATPAK=false but flatpak
# still ends up installed, this warns loudly and records WHO pulled it
# (xbps-query -X flatpak = reverse dependencies) in the as-built install-config
# — surfacing the opt-out violation instead of letting it pass silently. Never
# FATAL: the operator's decline is a preference, and the detection exists to
# inform, not abort.
FLATPAK_PULLED_BY=""
if [ "$INSTALL_FLATPAK" != "true" ] && xbps-query -p pkgver flatpak >/dev/null 2>&1; then
    FLATPAK_PULLED_BY="$(xbps-query -X flatpak 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')"
    echo "WARNING: [FLATPAK-PULL-DETECT] Flatpak was declined at the prompt (INSTALL_FLATPAK=false) but IS installed on this system." >&2
    echo "         Reverse dependencies (who pulled it): ${FLATPAK_PULLED_BY:-unknown}" >&2
    echo "         This is recorded in /etc/void-installer/install-config as FLATPAK_PULLED_BY." >&2
fi

# AI (Big Pickle) ADDITION — Beta-v2.9.86 [BR0-SKIP]: as-built record of the
# bridged-profile decision. Same condition as the Stage-2 profile gate, so the
# row always matches what was actually written: "created" = the br0/br0-slave
# pair exists; "skipped (no wired NIC; virbr0 kept)" = no physical wired NIC
# at all (NET_INTERFACE_MATCH empty) — rc.local likewise suppressed the
# virbr0 teardown, so virbr0 is the live VM-network path; "n/a" = no
# virtualization chosen. Public fact only, per this file's secret-free rule.
VIRT_BR0="n/a"
if [ "$INSTALL_VIRT" = "true" ]; then
    if [ -n "${NET_INTERFACE_MATCH:-}" ]; then
        VIRT_BR0="created"
    else
        VIRT_BR0="skipped (no wired NIC; virbr0 kept)"
    fi
fi

cat > /etc/void-installer/install-config << INNER_EOF
# Void Linux Installer — install-time configuration for THIS machine.
# Written by Void_Linux_Installer.sh (v${SCRIPT_VERSION}) at install time.
# Human-readable "as-built" summary for recovery/troubleshooting/reproducibility.
SCRIPT_VERSION="${SCRIPT_VERSION:-<unknown>}"
HOSTNAME="${TARGET_HOSTNAME:-<unset>}"
USER="${TARGET_USER:-<unset>}"
USER_FULL_NAME="${TARGET_FULL_NAME:-<unset>}"
USER_SHELL="${USER_SHELL:-<unset>}"
DESKTOP_ENV="${DESKTOP_ENV:-<unset>}"
DISPLAY_MANAGER="${DISPLAY_MANAGER:-<unset>}"
# AI (Big Pickle) ADDITION — Beta-v2.9.48 [HEADLESS]: RECORD-ONLY copy of the
# resolved graphics flags (the REAL in-chroot runtime defaults live at the
# Stage-2 xorg/wayland gate — Beta-v2.9.60 [RESUME-GFX-FLAGS]). These lines
# only print to this config file; they are never evaluated as shell code.
HAS_GRAPHICAL="${HAS_GRAPHICAL:-yes}"
INSTALL_XORG="${INSTALL_XORG:-false}"
INSTALL_AUDIO="${INSTALL_AUDIO:-true}"
BOOTLOADER="${BOOTLOADER:-<unset>}"
KERNEL_MODE="${KERNEL_MODE:-<unset>}"
# AI (Big Pickle) ADDITION — Beta-v2.9.16 [KERNEL-SELECT]: as-built record of
# the resolved kernel set (always starts with linux; space-joined).
KERNEL_PKGS="${KERNEL_PKGS:-<unset>}"
# AI (Big Pickle) ADDITION — Beta-v2.9.17 [DEVICE-PROFILE]: as-built record
# of the resolved profile + the booleans that actually drove the install.
DEVICE_PROFILE="${DEVICE_PROFILE:-<unset>}"
PROFILE_TLP="${PROFILE_TLP:-<unset>}"
PROFILE_BT="${PROFILE_BT:-<unset>}"
PROFILE_PRELOAD="${PROFILE_PRELOAD:-<unset>}"
POWER_PPD="${POWER_PPD:-false}"  # [COSMIC-PPD] true = COSMIC build carries PPD (tlp skipped)
# AI (Big Pickle) ADDITION — Beta-v2.7.1 [CRYPT-NAME]: record the encryption
# choice + LUKS mapper name in the as-built config. Both are PUBLIC (no
# passphrase — matches the secret-free rule for this file and limine-env).
ENCRYPT="${ENCRYPT:-no}"
CRYPT_NAME="${CRYPT_NAME:-void-root}"
SESSION_STACK="${SESSION_STACK:-<unset>}"
LOCALE="${LOCALE:-<unset>}"
TIMEZONE="${TIMEZONE:-<unset>}"
REPO_PRIMARY="${REPO_PRIMARY:-<unset>}"
# AI (Big Pickle) ADDITION — Beta-v2.9.59 [LOCAL-CACHE]: flag only — the cache
# PATH itself is media-scoped and meaningless after the install completes
# (mirrors remain the installed system's package source).
LOCAL_CACHE_REUSE="${LOCAL_CACHE_REUSE:-no}"
SWAP_BACKEND="${SWAP_BACKEND:-<unset>}"
ENABLE_HIBERNATION="${ENABLE_HIBERNATION:-<unset>}"
SWAPFILE_SIZE="${SWAPFILE_SIZE:-<unset>}"
LIMINE_WALLPAPER="${LIMINE_WALLPAPER:-<unset>}"
LIMINE_WALLPAPER_STYLE="${LIMINE_WALLPAPER_STYLE:-<unset>}"
# AI (Big Pickle) ADDITION — Beta-v2.9.23 [SSH-SERVER]/[SSH-KEYS]: as-built
# record of the OpenSSH server decision + the PUBLIC key facts (comment /
# protection flag). Never any key material or passphrase here — matches the
# secret-free rule for this file.
INSTALL_SSH_SERVER="${INSTALL_SSH_SERVER:-false}"
SSH_PORT="${SSH_PORT:-<unset>}"
SSH_PASSWORD_AUTH="${SSH_PASSWORD_AUTH:-<unset>}"
SSH_ROOT_LOGIN="${SSH_ROOT_LOGIN:-<unset>}"
SSH_KEY_PRESENT="${_ssh_key_present}"
${_ssh_key_rows}
# AI (Big Pickle) ADDITION — Beta-v2.9.25 [HARDWARE-REVIEW]/[NVIDIA-GATE]:
# hardware facts are public as-built data; the driver decision is recorded
# too (probe results persist for future use, e.g. the Steam/gaming TODO).
GPU_FAMILIES="${GPU_FAMILIES:-<unset>}"
WIFI_HW="${WIFI_HW:-<unset>}"
HAS_NVIDIA_GPU="${HAS_NVIDIA_GPU:-<unset>}"
HAS_AMD_GPU="${HAS_AMD_GPU:-<unset>}"
HAS_INTEL_GPU="${HAS_INTEL_GPU:-<unset>}"
INSTALL_NVIDIA="${INSTALL_NVIDIA:-<unset>}"
# AI (Big Pickle) ADDITION — Beta-v2.9.27 [CPU-DETECT]/[NIC-DETECT]: the
# microcode package decision (the one genuinely pruned package) and the wired
# NIC that feeds the bridged VM network are public as-built facts recorded here
# alongside the other hardware review data.
BR0_NIC="${BR0_NIC:-<unset>}"
# AI (Big Pickle) ADDITION — Beta-v2.9.86 [BR0-SKIP]: created / skipped /
# n/a — computed just above this heredoc; mirrors the Stage-2 profile gate.
VIRT_BR0="${VIRT_BR0:-n/a}"
MICROCODE_PKG="${MICROCODE_PKG:-<unset>}"
MICROCODE_DECIDED="${MICROCODE_DECIDED:-<unset>}"
# AI (Big Pickle) ADDITION — Beta-v2.9.46 [INSTALL-CONFIG-FLATPAK]: record the
# Flatpak/Flathub channel + the Brave browser decision in the as-built config —
# Heroic/Bottles ship via that first-boot Flatpak queue, so INSTALL_FLATPAK is
# the gate row that explains why (or why not) they're present. Public flags only.
INSTALL_FLATPAK="${INSTALL_FLATPAK:-false}"
INSTALL_COSMIC_STORE="${INSTALL_COSMIC_STORE:-false}"
# AI (Big Pickle) ADDITION — Beta-v2.9.84 [FLATPAK-PULL-DETECT]: when Flatpak
# was DECLINED at the prompt (INSTALL_FLATPAK=false) but is installed anyway
# (a future metapackage revision or a manual install pulled it), this row
# records who pulled it (reverse deps via `xbps-query -X flatpak`). Empty when
# Flatpak is absent or was accepted. Public facts only.
FLATPAK_PULLED_BY="${FLATPAK_PULLED_BY:-}"
INSTALL_BRAVE="${INSTALL_BRAVE:-false}"
# AI (Big Pickle) ADDITION — Beta-v2.9.36 [INSTALL-BREW]: record the Homebrew
# channel decision + its (separate, opt-in) subvolume isolation flag. Public
# flags only — no brew credentials/prefix keys, matches secret-free rule.
INSTALL_BREW="${INSTALL_BREW:-false}"
PROVISION_LINUXBREW_SUBVOL="${PROVISION_LINUXBREW_SUBVOL:-false}"
# AI (Big Pickle) ADDITION — Beta-v2.9.37 [GAME-LAUNCHERS]/[GAME-SUBVOL]:
# as-built record of the game-launcher umbrella (Lutris/Heroic/Bottles/Wine/
# gamemode + the shared INSTALL_ANY_GAME gate + the ONE @game subvolume flag).
# Wine/gamemode have no isolated datadir so only launchers feed INSTALL_ANY_GAME.
INSTALL_LUTRIS="${INSTALL_LUTRIS:-false}"
INSTALL_HEROIC="${INSTALL_HEROIC:-false}"
INSTALL_BOTTLES="${INSTALL_BOTTLES:-false}"
INSTALL_WINE="${INSTALL_WINE:-false}"
INSTALL_GAMEMODE="${INSTALL_GAMEMODE:-false}"
INSTALL_ANY_GAME="${INSTALL_ANY_GAME:-false}"
PROVISION_GAME_SUBVOL="${PROVISION_GAME_SUBVOL:-false}"
# AI (Big Pickle) FIX — Beta-v2.9.68 [INSTALL-CONFIG-BACKENDS]: record the Steam
# client + the container backend decisions. These were never emitted, so the
# as-built config could not explain why steam/podman/docker were present (a
# fresh install had steam + podman installed and @containers mounted with no
# row for any of them). PROVISION_* rows name the subvols the [SUBVOL-GATES]
# resolver actually created (@containers / @containers-user / @docker).
INSTALL_STEAM="${INSTALL_STEAM:-false}"
INSTALL_DOCKER="${INSTALL_DOCKER:-false}"
INSTALL_PODMAN_ROOTLESS="${INSTALL_PODMAN_ROOTLESS:-false}"
INSTALL_PODMAN_ROOTFUL="${INSTALL_PODMAN_ROOTFUL:-false}"
PROVISION_DOCKER_SUBVOL="${PROVISION_DOCKER_SUBVOL:-false}"
PROVISION_PODMAN_SUBVOL="${PROVISION_PODMAN_SUBVOL:-false}"
PROVISION_PODMAN_ROOTLESS_SUBVOL="${PROVISION_PODMAN_ROOTLESS_SUBVOL:-false}"
# AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS]: as-built record of every
# data-region decision (fs per location + carved sizes + the derived carve
# list). Sizes/fs strings are public config, secret-free. REGION_PARTITIONED
# is the space-joined carve list in fixed order; the per-location fs/size rows
# let the recovery diagnosis map a mountpoint back to its partition.
REGION_HOME_FS="${REGION_HOME_FS:-btrfs}"
REGION_VAR_FS="${REGION_VAR_FS:-btrfs}"
REGION_CACHE_FS="${REGION_CACHE_FS:-btrfs}"
REGION_SRV_FS="${REGION_SRV_FS:-btrfs}"
REGION_OPT_FS="${REGION_OPT_FS:-btrfs}"
REGION_GAMES="${REGION_GAMES:-none}"
REGION_PARTITIONED="${REGION_PARTITIONED:-}"
REGION_HOME_SIZE="${REGION_HOME_SIZE:-}"
REGION_VAR_SIZE="${REGION_VAR_SIZE:-}"
REGION_CACHE_SIZE="${REGION_CACHE_SIZE:-}"
REGION_SRV_SIZE="${REGION_SRV_SIZE:-}"
REGION_OPT_SIZE="${REGION_OPT_SIZE:-}"
REGION_GAMES_SIZE="${REGION_GAMES_SIZE:-}"
INNER_EOF
chmod 644 /etc/void-installer/install-config

# AI (Big Pickle) ADDITION — Beta-v2.6.2 [DOCS-LOG]: drop a human-readable
# install record into the target user's ~/Documents so the box itself
# advertises which installer version built it (and where the full as-built
# config + archived installer live), without booting rescue media to find
# out. Kept secret-free like install-config — public facts and a pointer
# only; nothing here unlocks anything.
if [ -n "${TARGET_USER}" ] && [ -d "/home/${TARGET_USER}" ]; then
    mkdir -p "/home/${TARGET_USER}/Documents"
    # mkdir -p above runs as root and the inner write only chowns the FILE —
    # chown Documents itself too or the shell-owned xdg-user-dirs home leaves a
    # root-owned Documents dir the user cannot chmod. [DOCS-LOG-CHOWN] Beta-v2.7.8.
    chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/Documents"
    {
        echo "# ========================================================================="
        echo "# VOID LINUX install record for THIS machine"
        echo "# Written to ~/Documents by Void_Linux_Installer.sh v${SCRIPT_VERSION} at install time."
        echo "# Secret-free 'as-built' tracking. Full install-time CHOICES + installer"
        echo "# version live in /etc/void-installer/install-config; the installer itself"
        echo "# is archived at /etc/void-installer/Void_Linux_Installer.sh."
        echo "# ========================================================================="
        echo "SCRIPT_VERSION=${SCRIPT_VERSION:-<unknown>}"
        echo "INSTALLED_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "HOSTNAME=${TARGET_HOSTNAME:-<unset>}"
        echo "USER=${TARGET_USER:-<unset>}"
        echo "BOOTLOADER=${BOOTLOADER:-<unset>}"
        if [ "${GRUB_ESP_BOOT}" = "true" ]; then
            echo "ESP_MOUNTED_AT=/boot (GRUB+ENCRYPT combo: boot tree unencrypted, on the ESP)"
        else
            echo "ESP_MOUNTED_AT=/boot/efi"
        fi
        echo "ENCRYPT=${ENCRYPT:-no}"
        echo "LUKS_MAPPER=${CRYPT_NAME:-void-root}"
        echo "YUBIKEY_UNLOCK=${YK_MODE:-off}"
        echo "SESSION_STACK=${SESSION_STACK:-<unset>}"
        echo "DESKTOP_ENV=${DESKTOP_ENV:-<unset>}"
        # AI (Big Pickle) ADDITION — Beta-v2.9.23 [SSH-SERVER]: one pointer
        # line for the OpenSSH decision; the port + a pointer to the
        # authoritative as-built config (which holds auth/root-login policy).
        # Public facts only.
        echo "SSH_SERVER=${INSTALL_SSH_SERVER:-no} (port ${SSH_PORT:-22}; policy: /etc/void-installer/install-config)"
        # AI (Big Pickle) ADDITION — Beta-v2.9.25 [NVIDIA-GATE]: one pointer
        # line for the hardware-gated driver; the wifi presence flag rides
        # here alongside the GPU families (both are live-probed facts).
        echo "NVIDIA_DRIVER=${INSTALL_NVIDIA:-no} (GPU: ${GPU_FAMILIES:-<none detected>}, wifi: ${WIFI_HW:-no})"
        # AI (Big Pickle) ADDITION — Beta-v2.9.25 [WIFI-HARDWARE]: the probe's
        # raw vendor:device id(s) for the detected wireless radio(s), so a
        # support person can map the box to its firmware without re-probing.
        echo "WIFI_HARDWARE=${WIFI_IDS:-<none>}"
        # AI (Big Pickle) ADDITION — Beta-v2.9.27 [CPU-DETECT]: the CPU vendor
        # (re-derived in-chroot from /proc/cpuinfo — same hardware as the live
        # probe) + the microcode package the installer chose for it.
        _doc_cpu="$(grep -m1 vendor_id /proc/cpuinfo 2>/dev/null | awk '{print $3}')"
        echo "CPU=${_doc_cpu:-<unknown>} (microcode: ${MICROCODE_PKG:-none})"
        unset _doc_cpu
        # AI (Big Pickle) ADDITION — Beta-v2.9.36 [INSTALL-BREW]: one pointer
        # line for the Homebrew (Linuxbrew) channel. The prefix itself is
        # deliberately NOT created by the installer — this is the NEWS step
        # reminder: the operator runs Homebrew's official installer on first
        # login to create ~/.linuxbrew. Declining the subvolume only leaves a
        # correctly-owned plain ~/.linuxbrew inside @home.
        echo "HOMEBREW=${INSTALL_BREW:-no} (deps: git/curl/file via xbps; install the prefix yourself: ~/.linuxbrew — see NEWS; isolation: ${PROVISION_LINUXBREW_SUBVOL:-false})"
        # AI (Big Pickle) ADDITION — Beta-v2.9.37 [GAME-LAUNCHERS]: one pointer
        # line listing the enabled launchers (flatpak-delivered ones tagged);
        # full per-launcher flags live in install-config.
        _doc_g=""
        [ "$INSTALL_STEAM" = "true" ] && _doc_g="$_doc_g steam"
        [ "$INSTALL_LUTRIS" = "true" ] && _doc_g="$_doc_g lutris"
        [ "$INSTALL_HEROIC" = "true" ] && _doc_g="$_doc_g heroic(flatpak)"
        [ "$INSTALL_BOTTLES" = "true" ] && _doc_g="$_doc_g bottles(flatpak)"
        [ "$INSTALL_WINE" = "true" ] && _doc_g="$_doc_g wine"
        [ "$INSTALL_GAMEMODE" = "true" ] && _doc_g="$_doc_g gamemode"
        if [ -n "$_doc_g" ]; then
            echo "GAMING=${_doc_g# } (@game isolation: ${PROVISION_GAME_SUBVOL:-false})"
        else
            echo "GAMING=no"
        fi
        unset _doc_g
        # AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS]: one secret-free
        # pointer line listing ALL SIX data-region locations in fixed order
        # with their resolved filesystem (btrfs subvol or carved ext4/partition);
        # games omitted only when REGION_GAMES=none. Matches the recovered
        # as-built record format (home:fs,var:fs,...,games:fs).
        _doc_regions="home:${REGION_HOME_FS:-btrfs},var:${REGION_VAR_FS:-btrfs},cache:${REGION_CACHE_FS:-btrfs},srv:${REGION_SRV_FS:-btrfs},opt:${REGION_OPT_FS:-btrfs}"
        [ "${REGION_GAMES:-none}" != "none" ] && _doc_regions="${_doc_regions},games:${REGION_GAMES}"
        echo "DATA_REGIONS=${_doc_regions}"
        unset _doc_regions
        echo ""
        # AI (Big Pickle) ADDITION — Beta-v2.7.6 [PKG-LIST]: append the FULL
        # finished-system package inventory (every package on this box — the
        # base-system, its dependencies, and everything the installer added on
        # top) so the record shows not just the installer version and choices
        # but precisely WHAT was installed. Captured in the chroot via
        # `xbps-query -l` against the target's own /var/db/xbps, then normed:
        # each line is stripped of xbps's `[installed] ` status prefix so it
        # reads as clean `pkgname-version`, sorted for scannability.
        # Kept secret-free (a package list contains no credentials) and the
        # SCRIPT_VERSION line above still records which installer built it.
        echo "# -------- INSTALLED PACKAGES (full xbps-query -l inventory) --------"
        if command -v xbps-query >/dev/null 2>&1; then
            xbps-query -l 2>/dev/null | sed -E 's/^\[installed\] //' | sort
        else
            echo "# xbps-query unavailable in chroot — package inventory omitted"
        fi
    } > "/home/${TARGET_USER}/Documents/Void_Install.txt"
    chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/Documents/Void_Install.txt"
    chmod 644 "/home/${TARGET_USER}/Documents/Void_Install.txt"
fi

# AI (Big Pickle) ADDITION — Beta-v2.5.1 [LIMINE-WALLPAPER]: if the user
# opted in at the prompt, /tmp/limine-splash.<ext> (staged from /mnt/tmp in
# the live env — same path chroot_env.sh uses) holds the image. Move it onto
# the ESP at the fixed name the generator references (boot():/limine-splash.<ext>).
# If it is absent (declined, or the USB staging was lost), do nothing — the
# menu simply has no wallpaper line, which is the safe default.
if [ "${LIMINE_WALLPAPER}" = "yes" ]; then
    for _wp in /tmp/limine-splash.*; do
        [ -f "$_wp" ] || continue
        if cp -f "$_wp" "/boot/efi/limine-splash.${_wp##*.}" 2>/dev/null; then
            echo "Limine wallpaper installed → /boot/efi/limine-splash.${_wp##*.}"
            LIMINE_WALLPAPER="yes"
        else
            echo "WARNING: could not copy Limine wallpaper to ESP — wallpaper omitted." >&2
            LIMINE_WALLPAPER="none"
        fi
        break
    done
    # If nothing was staged/copied, fall back to none so the generator stays quiet.
    if ! ls /boot/efi/limine-splash.* >/dev/null 2>&1; then
        LIMINE_WALLPAPER="none"
    fi
fi

mkdir -p /usr/local/sbin
# AI (Big Pickle) ADDITION — Beta-v2.5.1 [LIMINE-ENV-LOAD]: the two Limine
# helper scripts (void-limine-write-conf and void-limine-sync-kernels) both
# needed to load /etc/void-installer/limine-env and both used to duplicate
# the identical existence-check + source block. That duplicated a load-bearing
# bit of logic in two heredocs that could drift. Factor it once into this
# shared, source-only library: each helper sources it and calls
# load_limine_env, so the guard (FATAL if limine-env missing — "was this system
# installed with BOOTLOADER=limine?") lives in exactly one place. Deliberately
# a .inc source file (no shebang, not executable): it defines a function and
# returns, it is not a standalone command.
cat > /usr/local/sbin/void-limine-env.inc << 'INNER_EOF'
# Shared loader for /etc/void-installer/limine-env — source (not execute) me.
# shellcheck shell=bash
# Defines load_limine_env(); callers invoke it after setting PATH. Guards on
# the env file existing and sources it once. See [LIMINE-ENV-LOAD].
load_limine_env() {
    local _env=/etc/void-installer/limine-env
    if [ ! -f "$_env" ]; then
        echo "FATAL: ${_env} missing — was this system installed with BOOTLOADER=limine?" >&2
        exit 1
    fi
    # shellcheck disable=SC1090
    . "$_env"
}
INNER_EOF
chmod 0644 /usr/local/sbin/void-limine-env.inc

cat > /usr/local/sbin/void-limine-write-conf << 'INNER_EOF'
#!/bin/bash
# [LIMINE-SYNC-CRON] Single generator for limine.conf — shared verbatim by
# the kernel post-install/post-remove hook and the 00-void-limine-snapper-sync
# snapper plugin, so both trigger points can never drift out of sync with
# each other. Safe to run at any time, any number of times: purely reads
# current system state (installed kernel version, current snapshot list,
# current swapfile resume offset) and rewrites the same file. No `exit`
# used for the "nothing to do" cases, only for genuine failures, since this
# runs unattended and a silent partial failure is worse than a loud one.
set -eEo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin"

# AI (Big Pickle) ADDITION — Beta-v2.5.1 [LIMINE-ENV-LOAD]: shared loader.
# shellcheck disable=SC1090
. /usr/local/sbin/void-limine-env.inc
load_limine_env

# Recomputed on every run (cron included) — same rationale as the GRUB
# path's 99-grub-btrfs hook: a balance/resize can relocate the swapfile's
# physical extents even though it's nodatacow, silently invalidating a
# stale resume_offset baked in at install time. Only applies when the
# system was installed with hibernation enabled (AI (Big Pickle) [SWAP]).
# AI (Big Pickle) ADDITION — Beta-v2.5.5 [ENCRYPT]: when the system was
# installed encrypted (ENCRYPT=yes in limine-env), the LUKS container UUID is
# injected via rd.luks.uuid= + rd.luks.name= so dracut's `crypt` module opens
# void-root before root is mounted. `resume=` stays on the Btrfs filesystem
# UUID — the swapfile lives inside the LUKS volume, so hibernation resumes
# after unlock — and `root=UUID=` likewise resolves through the opened mapper.
if [ "${ENCRYPT}" = "yes" ]; then
    LUKS_RD="rd.luks.uuid=${LUKS_UUID} rd.luks.name=${LUKS_UUID}=${CRYPT_NAME:-void-root}"
else
    LUKS_RD=""
fi
if [ "${HIBERNATION_ENABLED}" = "true" ] && [ -f /var/swap/swapfile ]; then
    TARGET_OFFSET=$(btrfs inspect-internal map-swapfile -r /var/swap/swapfile 2>/dev/null || echo 0)
    BASE_CMD="loglevel=3 ${LUKS_RD} resume=UUID=${BTRFS_UUID} resume_offset=${TARGET_OFFSET} root=UUID=${BTRFS_UUID} rootflags=subvol=@"
else
    BASE_CMD="loglevel=3 ${LUKS_RD} root=UUID=${BTRFS_UUID} rootflags=subvol=@"
fi
# AI (Big Pickle) ADDITION — Beta-v2.9.47 [TEE-BOOT-QUIET]/[TEE-BLACKLIST]:
# re-derive the shared TEE_QB_FRAG from the persisted PUBLIC limine-env rows
# on EVERY resync (kernel update / snapper-plugin resync / manual run), so the
# "quiet" / "modprobe.blacklist=tee" cmdline fragment can never silently drop
# out of the regenerated limine.conf. Same values as the GRUB branch bakes at
# install time; limine always re-reads state instead of baking once.
TEE_QB_FRAG=""
if [ "${DEFAULT_QUIET_BOOT:-no}" = "yes" ]; then
    TEE_QB_FRAG=" quiet"
fi
if [ "${DEFAULT_TEE_BLACKLIST:-no}" = "yes" ]; then
    TEE_QB_FRAG="${TEE_QB_FRAG} modprobe.blacklist=tee"
fi
BASE_CMD="${BASE_CMD}${TEE_QB_FRAG}"
unset TEE_QB_FRAG

# [LIMINE-MULTI-KERNEL] Enumerate every kernel actually available — always
# on the ESP under /boot/efi/void-kernel (esp-copy is now the only mode) —
# newest first, one "/Void Linux (VERSION)" stanza per kernel. The
# snapshot section further below deliberately still uses only the single
# newest kernel (captured here as NEWEST_KVER): one stanza per
# (snapshot x kernel) combination would make the menu unwieldy for a
# combination (booting an old snapshot against an old kernel) that's rare
# enough not to be worth it.
kernel_path_for() {
    echo "${SYSPREFIX_ESP}:/void-kernel/vmlinuz-$1"
}
module_path_for() {
    echo "${SYSPREFIX_ESP}:/void-kernel/initramfs-$1.img"
}

NEWEST_KVER=""
KERNEL_ENTRIES=""
# shellcheck disable=SC2012  # deliberate sort -V glob list; ls+sort is the version-ordering primitive here
for _kf in $(ls /boot/efi/void-kernel/vmlinuz-* 2>/dev/null | sort -V -r); do
    _kver="${_kf#/boot/efi/void-kernel/vmlinuz-}"
    [ -f "/boot/efi/void-kernel/initramfs-${_kver}.img" ] || continue
    [ -z "$NEWEST_KVER" ] && NEWEST_KVER="$_kver"
    KERNEL_ENTRIES="${KERNEL_ENTRIES} ${_kver}"
done

if [ -z "$NEWEST_KVER" ]; then
    echo "WARNING: no bootable kernel found under /boot/efi/void-kernel — limine.conf will have no /Void Linux entries. Run void-limine-sync-kernels first." >&2
fi

TMP_CONF="$(mktemp /boot/efi/EFI/BOOT/limine.conf.XXXXXX)"
{
    echo "timeout: 5"
    # AI (Big Pickle) CHANGE — Beta-v2.5.1 [LIMINE-HDR]: the kernels now
    # live inside a /+Void Linux submenu (see below), so a bare 1-based
    # `default_entry` index can no longer descend into it — Limine instead
    # needs an entry PATH (directory separator is "/") to auto-select a
    # kernel inside the submenu. Point it at the newest kernel's entry. On
    # first boot this makes the default OS the highlighted/auto-booted
    # target; after that remember_last_entry=y takes over. If no kernel was
    # detected (shouldn't happen post-install, but guarded), fall back to
    # entry index 1.
    if [ -n "$NEWEST_KVER" ]; then
        echo "default_entry: Void Linux/Void Linux (${NEWEST_KVER})"
    else
        echo "default_entry: 1"
    fi
    echo "remember_last_entry: yes"

    # AI (Big Pickle) ADDITION — Beta-v2.5.1 [LIMINE-WALLPAPER]: the Limine
    # boot-screen background. Emit LIVE `wallpaper:` and `wallpaper_style:`
    # lines only when the user opted in at install time AND the image is still
    # present on the ESP. Limine reads boot():/<name> as the root of the boot
    # drive (the ESP here — the image lived at /boot/efi/limine-splash.<ext>).
    # Guarded on existence so a missing file (declined, or ESP copy removed)
    # never leaves a dangling wallpaper line. NOTE: this file is regenerated on
    # every kernel update / snapshot change, so there is deliberately NO
    # hand-uncommented shortcut here — the ONLY durable way to enable a
    # background is to set LIMINE_WALLPAPER=yes (and LIMINE_WALLPAPER_STYLE)
    # in /etc/void-installer/limine-env and place the image on the ESP, which
    # the generator re-copies/re-emits every resync.
    if [ "${LIMINE_WALLPAPER}" = "yes" ]; then
        for _wpfile in /boot/efi/limine-splash.*; do
            [ -f "$_wpfile" ] || continue
            echo "wallpaper: boot():/limine-splash.${_wpfile##*.}"
            echo "wallpaper_style: ${LIMINE_WALLPAPER_STYLE:-stretched}"
            break
        done
    else
        # AI (Big Pickle) CHANGE — Beta-v2.5.4 [LIMINE-WALLPAPER-OPT-OUT]: when the
        # user declines the wallpaper at install, keep a commented section here so
        # limine.conf still documents the option (Limine ignores '#' lines, so this
        # is harmless). This is regenerated on every resync, so it is NOT a
        # hand-uncommented enable path — the only durable way to enable is to set
        # LIMINE_WALLPAPER=yes (and LIMINE_WALLPAPER_STYLE) in
        # /etc/void-installer/limine-env and place an image on the ESP as
        # boot():/limine-splash.<ext>, which void-limine-write-conf then re-emits
        # live above.
        echo "# Boot wallpaper disabled at install. To enable, set"
        echo "#   LIMINE_WALLPAPER=yes  (and optionally LIMINE_WALLPAPER_STYLE="
        echo "#     stretched | tiled | centered)"
        echo "# in /etc/void-installer/limine-env and place an image on the ESP as"
        echo "#   boot():/limine-splash.<ext>  (BMP/PNG/JPEG/QOI)"
        echo "# void-limine-write-conf re-emits the live wallpaper:/wallpaper_style"
        echo "# lines here on the next kernel sync or snapshot create/delete."
        echo "# wallpaper: boot():/limine-splash.png"
        echo "# wallpaper_style: ${LIMINE_WALLPAPER_STYLE:-stretched}"
    fi
    echo ""
    echo "# Paths below use guid(<PARTUUID>) addressing — no disk-enumeration-"
    echo "# order assumption, unlike the earlier hdd(N):<GUID> form this script"
    echo "# generated before Beta-v2.3.0 (which was invalid Limine URI syntax"
    echo "# and caused every kernel-mode boot attempt to PANIC with 'Failed to"
    echo "# open kernel with path... Is the path correct?')."
    echo "# Regenerated by void-limine-write-conf — do not hand-edit, it"
    echo "# will be overwritten on the next kernel update or snapshot"
    echo "# create/delete."

    echo ""
    # AI (Big Pickle) CHANGE — Beta-v2.5.1 [LIMINE-HDR]: the kernels are
    # now grouped inside a collapsible "/+Void Linux" submenu, mirroring the
    # existing "/+Snapshots" pattern below — a consistent, closed-by-default
    # top level. So this installer renders BOTH a "Void Linux" submenu
    # (holding each installed kernel as a "//..." sub-entry) and a
    # "+Snapshots" submenu (holding read-only overlay snapshot boots). The
    # earlier static "# Void Linux" comment banner is retired: with a real
    # submenu heading there's no need for a fake text heading. Sub-entries
    # MUST use the "//" prefix (Limine: "a sub-entry is ... started with a
    # number of '/' greater than 1 prepended"), exactly as the snapshots
    # block does.
    echo "/+Void Linux"
    for _kver in $KERNEL_ENTRIES; do
        echo "    //Void Linux (${_kver})"
        echo "    protocol: linux"
        echo "    kernel_path: $(kernel_path_for "$_kver")"
        echo "    kernel_cmdline: ${BASE_CMD}"
        echo "    module_path: $(module_path_for "$_kver")"
    done

    if [ -d /.snapshots ] && [ -n "$NEWEST_KVER" ]; then
        echo ""
        echo "/+Snapshots"
        for snap_dir in /.snapshots/*/; do
            [ -d "$snap_dir" ] || continue
            snap_id="$(basename "$snap_dir")"
            [ -f "${snap_dir}info.xml" ] || continue
            # AI (Big Pickle) ADDITION — Beta-v2.5.4 [LIMINE-SNAPDATE]: show the
            # snapshot creation date+time (from snapper info.xml <date>) in the menu
            # entry, so timeline snapshots are distinguishable at a glance.
            snap_date="$(sed -n 's:.*<date>\(.*\)</date>.*:\1:p' "${snap_dir}info.xml" | head -n1)"
            snap_desc="$(sed -n 's:.*<description>\(.*\)</description>.*:\1:p' "${snap_dir}info.xml" | head -n1)"
            # AI (Big Pickle) CHANGE — Beta-v2.5.4 [LIMINE-SNAPDATE]: reformat the
            # ISO creation date (YYYY-MM-DD HH:MM:SS) to an abbreviated-name date
            # + time (e.g. "Dec 4, 2027 15:04"), falling back to the raw string if
            # the date doesn't parse (so an odd info.xml never breaks the menu).
            if [ -n "$snap_date" ]; then
                snap_fmt="$(date -d "$snap_date" '+%b %-d, %Y %H:%M' 2>/dev/null || echo "$snap_date")"
            else
                snap_fmt=""
            fi
            if [ -n "$snap_fmt" ]; then
                if [ -n "$snap_desc" ]; then
                    echo "    //${snap_desc} · ${snap_fmt} (#${snap_id})"
                else
                    echo "    //${snap_fmt} (#${snap_id})"
                fi
            else
                [ -n "$snap_desc" ] || snap_desc="snapshot ${snap_id}"
                echo "    //${snap_desc} (#${snap_id})"
            fi
            echo "    protocol: linux"
            echo "    kernel_path: $(kernel_path_for "$NEWEST_KVER")"
            echo "    kernel_cmdline: ${BASE_CMD/rootflags=subvol=@/rootflags=subvol=@snapshots\/${snap_id}\/snapshot} rd.live.overlay.overlayfs=1"
            echo "    module_path: $(module_path_for "$NEWEST_KVER")"
        done
    fi

    echo ""
    echo "/Reboot Into Firmware"
    echo "    protocol: efi_firmware_update_request"
} > "$TMP_CONF"
# Atomic swap — a cron run landing mid-write (e.g. install disk full,
# process killed) never leaves limine.conf truncated or half-written.
mv -f "$TMP_CONF" /boot/efi/EFI/BOOT/limine.conf
INNER_EOF
chmod 0755 /usr/local/sbin/void-limine-write-conf

# AI (Big Pickle) ADDITION — Beta-v2.5.4 [YUBIKEY]: standalone keyscript that
# dracut's cryptroot-ask runs at boot to obtain the LUKS key WITHOUT a typed
# passphrase. It challenges the YubiKey (slot $YK_SLOT programmed with hmac-lt64
# at install time) using $YK_CHALLENGE and prints the HMAC-SHA1 response (the
# browser-plugin-style OTP body) on stdout; dracut's cryptroot-ask captures that
# and feeds it to luksOpen. With YK_FALLBACK=yes, if the YubiKey is absent or
# returns a wrong response the luksOpen fails and cryptroot-ask automatically
# falls back to a typed-passphrase prompt. Only public values (SLOT + CHALLENGE)
# are baked into the file — the HMAC response is never stored, so possession of
# the YubiKey is the credential. YK_TOUCH=yes adds a button-trigger wait so the
# response is only issued after physical confirmation.
# AI (Big Pickle) FIX — Beta-v2.5.8 [YK-KEYSCRIPT-BAKE]: the heredoc below
# MUST stay UNQUOTED (<< INNER_EOF), exactly like the limine-env heredoc — its
# ${YK_SLOT}/${YK_CHALLENGE} placeholders are the install-time values that bake
# the challenge into the file. A quoted heredoc left the literal unexpanded
# ${...} tokens in the installed keyscript; nothing passes those vars into
# keyscripts at boot (cryptroot-ask execs them with no environment), so under
# `set -u` the keyscript aborted on its first `YK_SLOT="${YK_SLOT}"` line and a
# possession-only boot could never unlock. The body contains no other
# $/backtick/backslash, so unquoting is safe.
if [ "$YK_MODE" = "hmac-sha1" ]; then
    mkdir -p /usr/local/sbin
    cat > /usr/local/sbin/void-reveal-yubikey-key << INNER_EOF
#!/bin/sh
# dracut keyscript — prints the HMAC-SHA1 challenge-response OTP for the YubiKey.
# Never stores the response; the YubiKey's possession is the LUKS credential.
# The two public values below (slot and challenge) are baked at install time by
# the UNQUOTED heredoc; nothing in the initramfs environment could provide them.
set -u
# The challenge is intentionally passed the same way it was at enroll (raw
# 40-hex string, matching the -ohmac-lt64 slot), so the response that dracut
# feeds luksOpen is identical to the key that luksAddKey bound at install
# time. If the slot was programmed with -ochal-btn-trig (YK_TOUCH=yes),
# ykchalresp blocks until the touch naturally; otherwise it responds at once.
# On failure print nothing and exit non-zero so dracut falls back to the
# passphrase prompt when YK_FALLBACK=yes.
exec ykchalresp -${YK_SLOT} "${YK_CHALLENGE}"
INNER_EOF
    chmod 0755 /usr/local/sbin/void-reveal-yubikey-key
fi

# AI (Claude, Sonnet 5, Medium) ADDITION — Beta-v2.3.0 [LIMINE-MULTI-KERNEL]
# (item 12): esp-copy mode previously kept exactly ONE kernel/initramfs
# pair on the ESP under fixed versionless names (vmlinuz-current /
# initramfs.img), overwritten in place on every update — meaning Limine's
# boot menu could only ever offer the single most recent kernel, unlike
# GRUB's grub-mkconfig, which already lists every /boot/vmlinuz-* it
# finds (confirmed directly in this script's own terminal-log evidence:
# "Found linux image: /boot/vmlinuz-7.2.0_1" AND
# "/boot/vmlinuz-6.18.45_1" from a single real GRUB install). This
# standalone script closes that gap: it syncs the ESP to hold a copy of
# EVERY currently-installed kernel (versioned filenames, not overwritten)
# and removes any ESP copy whose /lib/modules directory no longer exists
# (so old menu entries don't linger pointing at kernels that are gone).
# Verified in isolation before going anywhere near this script — both the
# multi-kernel sync/cleanup logic and void-limine-write-conf's new
# multi-stanza generation (below) were built and tested standalone first,
# including the exact orphan-cleanup case (a stale ESP kernel copy with no
# matching /lib/modules directory gets removed, real kernels stay).
mkdir -p /usr/local/sbin
cat > /usr/local/sbin/void-limine-sync-kernels << 'INNER_EOF'
#!/bin/bash
# [LIMINE-MULTI-KERNEL] Syncs the ESP's kernel/initramfs copies to exactly
# match what's currently installed under /lib/modules (esp-copy — the only
# Limine mode). Adds any newly-installed kernel under a VERSIONED filename
# (not the old single versionless vmlinuz-current/initramfs.img pair), and
# removes any ESP copy whose /lib/modules directory is gone, so Void's own
# kernel package upgrades/vkpurge cleanup on the source side are mirrored
# here rather than leaving stale ESP files with no real kernel behind them.
set -eEo pipefail
export PATH="/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"

# AI (Big Pickle) ADDITION — Beta-v2.5.1 [LIMINE-ENV-LOAD]: shared loader.
# shellcheck disable=SC1090
. /usr/local/sbin/void-limine-env.inc
load_limine_env

mkdir -p /boot/efi/void-kernel

INSTALLED_KVERS=""
for _kdir in /lib/modules/*/; do
    [ -d "$_kdir" ] || continue
    _kver="$(basename "$_kdir")"
    [ -f "/boot/vmlinuz-${_kver}" ] || continue
    [ -f "/boot/initramfs-${_kver}.img" ] || continue
    INSTALLED_KVERS="${INSTALLED_KVERS} ${_kver}"
done

if [ -z "$INSTALLED_KVERS" ]; then
    echo "WARNING: no installed kernel with both vmlinuz and initramfs found under /boot — ESP kernel sync skipped." >&2
    exit 0
fi

for _kver in $INSTALLED_KVERS; do
    # AI (Big Pickle) ADDITION — Beta-v2.9.45 [INNER-PARTSCAN-DMPROBE]: verify
    # the initramfs actually carries what this install's boot needs BEFORE
    # overwriting the ESP copy — a future kernel upgrade must never be able to
    # push a broken image over the last-known-good one (crash #009 residual:
    # the 19:54 boot opened LUKS but never registered the inner-GPT partitions
    # because partprobe was missing from the image, and the ESP had already
    # been overwritten). Same demand-gating as the install-time FATAL gate:
    # ENCRYPT=yes requires cryptsetup; when the 98void-inner-partscan module
    # dir exists (carved regions), kpartx (Beta-v2.9.56 PRIMARY) + partprobe +
    # the helper are required too.
    # Skip-with-warning on failure and leave the old ESP copy in place. Only
    # verified when lsinitrd is available (it ships with dracut, so it always
    # is on these installs); skipping the check then is a bug detector, so the
    # copy is also skipped — a missing lsinitrd means the image can't be
    # audited and must not be trusted blind.
    _img_ok=1
    if command -v lsinitrd >/dev/null 2>&1; then
        if [ "${ENCRYPT:-}" = "yes" ]; then
            lsinitrd "/boot/initramfs-${_kver}.img" 2>/dev/null | grep -c 'bin/cryptsetup' >/dev/null || _img_ok=0
            if [ -d /usr/lib/dracut/modules.d/98void-inner-partscan ]; then
                lsinitrd "/boot/initramfs-${_kver}.img" 2>/dev/null | grep -c 'kpartx' >/dev/null || _img_ok=0
                lsinitrd "/boot/initramfs-${_kver}.img" 2>/dev/null | grep -c 'partprobe' >/dev/null || _img_ok=0
                lsinitrd "/boot/initramfs-${_kver}.img" 2>/dev/null | grep -c 'void-inner-partscan.sh' >/dev/null || _img_ok=0
                lsinitrd "/boot/initramfs-${_kver}.img" 2>/dev/null | grep -c '10-void-inner-partscan.rules' >/dev/null || _img_ok=0
            fi
        fi
    else
        _img_ok=0
    fi
    if [ "$_img_ok" != "1" ]; then
        echo "WARNING: /boot/initramfs-${_kver}.img fails boot-content verification (missing cryptsetup and/or kpartx/partprobe/void-inner-partscan bits) — NOT copying it to the ESP; the previous ESP initramfs stays. Re-run 'dracut --force /boot/initramfs-${_kver}.img ${_kver}' once the required packages (cryptsetup, kpartx, parted) are installed." >&2
        continue
    fi
    cp -f "/boot/vmlinuz-${_kver}" "/boot/efi/void-kernel/vmlinuz-${_kver}"
    cp -f "/boot/initramfs-${_kver}.img" "/boot/efi/void-kernel/initramfs-${_kver}.img"
done
unset _img_ok
echo "==> Limine ESP kernels synced (${INSTALLED_KVERS# })"

for _esp_kfile in /boot/efi/void-kernel/vmlinuz-*; do
    [ -f "$_esp_kfile" ] || continue
    _esp_kver="${_esp_kfile#/boot/efi/void-kernel/vmlinuz-}"
    case " ${INSTALLED_KVERS} " in
        *" ${_esp_kver} "*) : ;;
        *)
            echo "==> Removing stale ESP kernel copy: ${_esp_kver}"
            rm -f "$_esp_kfile" "/boot/efi/void-kernel/initramfs-${_esp_kver}.img"
            ;;
    esac
done
INNER_EOF
chmod 0755 /usr/local/sbin/void-limine-sync-kernels

# AI (Claude, Sonnet 5, Medium) ADDITION — Beta-v2.3.0 [KERNEL-HOOK] §4.10: kernel hook now
# just delegates to the two shared scripts above — sync-kernels for the
# ESP copy/cleanup (esp-copy mode; multi-kernel aware as of
# [LIMINE-MULTI-KERNEL]), then write-conf for the menu itself — so this
# file stays tiny and can never fall out of sync with the cron-triggered
# path. No more single-kernel-version resolution here at all: sync-kernels
# now syncs EVERY installed kernel, not just whichever one xbps happened
# to pass as $1 (a previously-open question, CHANGELOG §4.10 Verification
# / Open Item #6, that this change makes moot — it no longer matters which
# form xbps passes, every installed kernel gets synced regardless).
mkdir -p /etc/kernel.d/post-install
cat > /etc/kernel.d/post-install/50-sync-limine-kernels.sh << 'INNER_EOF'
#!/bin/sh
# [KERNEL-HOOK] Delegates to void-limine-sync-kernels (ESP copy/cleanup,
# esp-copy mode only) then void-limine-write-conf (menu generation) — see
# [LIMINE-SYNC-CRON] and [LIMINE-MULTI-KERNEL].
set -eu
export PATH="/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"
/usr/local/sbin/void-limine-sync-kernels
/usr/local/sbin/void-limine-write-conf
INNER_EOF
chmod +x /etc/kernel.d/post-install/50-sync-limine-kernels.sh
cp /etc/kernel.d/post-install/50-sync-limine-kernels.sh /etc/kernel.d/post-remove/50-sync-limine-kernels.sh 2>/dev/null || \
    { mkdir -p /etc/kernel.d/post-remove; cp /etc/kernel.d/post-install/50-sync-limine-kernels.sh /etc/kernel.d/post-remove/50-sync-limine-kernels.sh; }

# AI (Big Pickle) ADDITION — Beta-v2.5.2 [SNPR-EV]: event-driven snapshot-menu
# sync. Empirically verified on the target hardware (see Debug/snpr_ev/probe_void_snapper_plugin.sh):
# Void's snapper DOES execute /usr/lib/snapper/plugins — the probe observed
# create-snapshot-pre/post (and the delete-snapshot-pre/post family) firing for
# a single throwaway snapshot. That contradicts the old Beta-v2.3.0
# [LIMINE-SYNC-CRON] assumption that Void's snapper had NO hook mechanism (the
# premise for the 15-min cron). So instead of waiting up to 15 minutes for a
# timeline snapshot to appear, we now attach a tiny Void-native plugin that
# calls the SAME /usr/local/sbin/void-limine-write-conf, so the menu updates
# the instant snapper creates or deletes a snapshot. Also see the
# [LIMINE-SYNC-CRON] block up top for the menu-generation architecture.
#
# AI (Big Pickle) SUPERSEDED — Beta-v2.5.6 [SNPR-EV-NO-CRON]: the /etc/cron.d/
# void-limine-sync 15-min safety-net fallback was REMOVED. The plugin has fired
# reliably in practice; the cron's only remaining value was a theoretical guard
# against snapshot operations that bypass snapper's own plugin runner (e.g. a
# raw `btrfs subvolume snapshot`), and that cost — rewriting limine.conf to the
# ESP every 15 minutes forever (flash wear, disk wakeups, menu churn) for a
# fallback that never needed to fire — outweighed the benefit. Menu updates now
# come from exactly two real events: a kernel install/remove (the hook below)
# or a snapper snapshot create/delete (this plugin). A snapshot created
# outside snapper will not show until one of those fires, which is the
# accepted trade-off.
#
# Design:
#   - Drop it in /usr/lib/snapper/plugins (snapper's plugin dir, confirmed by
#     the probe + the man page: "plugins have to be placed in
#     /usr/lib/snapper/plugins"). Only created inside this Limine branch, so
#     GRUB installs never get it (mirrors how void-limine-write-conf itself is
#     Limine-only — see [LIMINE-SYNC-CRON] and invariant #5: the two bootloader
#     paths stay fully separate).
#   - snapper invokes each executable plugin with: ACTION SUBVOL FSTYPE SNAPNO
#     (the man page verbs create-snapshot-pre / create-snapshot-post / delete-...).
#     We act ONLY on the *-post hooks (the moment the snapshot actually exists
#     / is actually gone) so one create fires ONE menu regen, not the pre +
#     in-progress + post threesome — the write-conf call is cheap and idempotent,
#     but there is no point re-reading/re-writing the menu three times.
#   - Runs as root (snapperd is supervised under runit, linked into
#     runsvdir/default — see below), so it can write /boot/efi. It reuses the
#     shared void-limine-write-conf so there is still exactly one copy of the
#     menu-generation logic (kernel hook and this plugin both call the same
#     script).
#   - `set -e` + intent-to-exit-0 so a plugin that cannot regenerate (e.g. no
#     bootable kernel yet, bootloader removed) still lets snapper finish its
#     transaction instead of turning snapshot creation into a failure.
mkdir -p /usr/lib/snapper/plugins
cat > /usr/lib/snapper/plugins/00-void-limine-snapper-sync << 'INNER_EOF'
#!/bin/bash
# [SNPR-EV] Snapper plugin (Void-native limine-snapper-sync): regenerate the
# Limine snapshot boot menu the moment a snapshot is created or deleted.
# Invoked by snapper as: ACTION SUBVOL FSTYPE SNAPNO (see snapper(8) PLUGINS).
# Acts only on the *-post hooks so each snapshot CREATE/DELETE produces
# exactly one menu regeneration.
# NOTE: snapper REQUIRES plugin names to START WITH A DIGIT (man snapper,
# PLUGINS: "The name has to start with a digit, execution order is
# alphabetical"); anything else is silently ignored. Hence the "00-" prefix.
set -eEo pipefail
export PATH="/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"

case "${1:-}" in
    create-snapshot-post|delete-snapshot-post)
        /usr/local/sbin/void-limine-write-conf >/dev/null 2>&1
        ;;
esac
exit 0
INNER_EOF
chmod 0755 /usr/lib/snapper/plugins/00-void-limine-snapper-sync
echo "Snapper event-driven Limine menu sync installed (/usr/lib/snapper/plugins/00-void-limine-snapper-sync)"

# Initial kernel sync + first limine.conf write (no snapshots exist yet,
# so the /Snapshots submenu is simply empty/absent — void-limine-write-conf
# handles that fine, [ -d /.snapshots ] guards it).
/usr/local/sbin/void-limine-sync-kernels
/usr/local/sbin/void-limine-write-conf

fi
# End of GRUB/Limine branch. From here down, everything is shared between
# both bootloaders except where explicitly gated on $BOOTLOADER again
# (rc.local service link, and the baseline-snapshot/final-regen block near
# the end of this chroot phase).

# This whole block reconciles a conflict between OUR pre-existing dedicated
# @snapshots subvolume (mounted at /.snapshots via fstab, created back in
# Stage 1) and snapper's own default behavior: `snapper create-config`
# normally wants to create ITS OWN nested subvolume at /.snapshots and will
# refuse/misbehave if something is already mounted there. The workaround:
#   1. Unmount our @snapshots subvolume and remove the now-empty mountpoint
#      dir, so /.snapshots looks "unclaimed" to snapper.
#   2. Let `snapper create-config` create its own nested subvolume there —
#      this is what it wants to do and can't be skipped.
#   3. Remove snapper's nested subvolume (rmdir works here — Linux 4.18+
#      allows the plain rmdir(2) syscall to delete an EMPTY subvolume, no
#      `btrfs subvolume delete` needed) and remount OUR @snapshots subvolume
#      in its place. Snapper's config now points at /.snapshots without
#      knowing/caring that the subvolume underneath is ours, not its own.
# AI (Big Pickle) FIX — Beta-v2.9.4 [SNAPPER-PRESENT]: ensure the snapper
# binary actually exists before configuring it. install_pkgs can report
# success even when a mid-transaction network drop left the package absent
# (observed: a failed install died here with the cryptic unguarded `rmdir`
# below, and the live-medium probe showed `snapper: command not found`).
# Guarding the binary turns that into a clear, actionable message instead
# of a confusing abort deep in the chroot.
if ! command -v snapper >/dev/null 2>&1; then
    echo "CRITICAL: snapper is not installed in the target (install_pkgs reported the package install succeeded, but 'snapper' is absent — likely a mid-transaction network drop during the package sync)." >&2
    echo "          Re-running the installer after re-establishing a stable network connection is the recommended recovery." >&2
    exit 1
fi
umount -fl /.snapshots || true
rmdir /.snapshots || true
snapper --no-dbus -c root create-config /
rmdir /.snapshots || true
mkdir -p /.snapshots
mount /.snapshots
chmod 750 /.snapshots

sed -i 's/TIMELINE_LIMIT_HOURLY="10"/TIMELINE_LIMIT_HOURLY="3"/g' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_DAILY="10"/TIMELINE_LIMIT_DAILY="5"/g' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_WEEKLY="10"/TIMELINE_LIMIT_WEEKLY="2"/g' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_MONTHLY="10"/TIMELINE_LIMIT_MONTHLY="0"/g' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_YEARLY="10"/TIMELINE_LIMIT_YEARLY="0"/g' /etc/snapper/configs/root
sed -i 's/EMPTY_PRE_POST_CLEANUP="false"/EMPTY_PRE_POST_CLEANUP="true"/g' /etc/snapper/configs/root
mkdir -p /etc/snapper/filters
echo "var/service/*" >> /etc/snapper/filters/void-runit.txt

# AI (Big Pickle) ADDITION — Beta-v2.6.4 [PKG-SNAPSHOT]: an explicit
# pre/post snapshot wrapper around xbps. Snapper guards accidental/logical
# damage to the @ root via its timeline snapshots, but a timeline snapshot
# can be many minutes old when a system update lands, so an "undo this exact
# update" rollback point is only guaranteed if we snapshot right before and
# right after an update. `void-xbps-snap` wraps `xbps-install` (it is really
# `/usr/local/sbin/void-xbps-snap`): it takes a snapper "pre" snapshot before
# running the real xbps-install, then a "post" snapshot afterwards (paired
# via the pre snapshot number), with the update description in the snapshot
# description for easy identification. The wrapper passes ALL other args
# through verbatim, so it is a drop-in for `xbps-install`.
#   - Only snapshots on INSTALL actions (no -S/-u). A bare dry-run such as
#     `xbps-install -nu` or a plain search/query (`-s`, no flag) is left
#     untouched — no pointless snapshot pair.
#   - Only snapshots when the target filesystem is btrfs (this installer
#     always is, but the wrapper should never wedge on a non-btrfs box).
#   - Pairs pre/post even if the update itself fails (post still taken so
#     the rollback point reflects the partially-applied state).
#   - Needs --no-dbus like the install-time calls: snapperd may not be up
#     yet, and --no-dbus never races a daemon.
#   - The wrapper is self-contained in /usr/local/sbin as void-xbps-snap
#     (already a privileged helper dir holding void-limine-sync-kernels etc.)
#     and the standalone name is kept so it can also be invoked explicitly.
#     Beta-v2.6.5 [PKG-SNAPSHOT-AUTO] additionally SHADOWS
#     /usr/bin/xbps-install (see the block right after the heredoc) so users
#     never need to change their normal `xbps-install` habit. The wrapper
#     always locates the REAL binary (`.real` companion, else PATH with a
#     self-recursion guard) before invoking it.
mkdir -p /usr/local/sbin
cat > /usr/local/sbin/void-xbps-snap << 'INNER_EOF'
#!/bin/bash
# [PKG-SNAPSHOT] Pre/post snapper snapshots around xbps-install, the
# "undo this exact update" rollback pair. Drop-in wrapper for xbps-install:
# all CLI args pass through verbatim.
# Two deployment modes with the SAME script:
#   * standalone  — installed as /usr/local/sbin/void-xbps-snap; users call it
#                   explicitly (sudo void-xbps-snap -Su).
#   * shadowed    — the real /usr/bin/xbps-install is renamed to
#                   /usr/bin/xbps-install.real and a symlink is placed at
#                   /usr/bin/xbps-install -> this script, so EVERY xbps-install
#                   invocation (with or without sudo, any shell) snapshots
# The wrapper ALWAYS calls the real binary via $REAL_XBPS, resolved below.
# Look for the shadowed real binary first, then fall back to PATH. A guard
# prevents self-recursion (if we end up resolving to our own file — i.e. a
# broken shadow with no .real companion — we abort loudly rather than loop).
set -euo pipefail

SNAP_CONFIG="root"
SNAP_TIMELINE="/.snapshots"
export PATH="/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"

_self="$(readlink -f "${0:-/nonexistent}")"
REAL_XBPS=""
if [ -x /usr/bin/xbps-install.real ]; then
    REAL_XBPS="/usr/bin/xbps-install.real"
else
    _cand="$(command -v xbps-install 2>/dev/null || true)"
    if [ -n "$_cand" ] && [ "$(readlink -f "$_cand" 2>/dev/null || printf '%s' "$_cand")" != "$_self" ]; then
        REAL_XBPS="$_cand"
    fi
fi
if [ -z "$REAL_XBPS" ]; then
    echo "ERROR: could not resolve the real xbps-install binary (shadowed without a .real companion?)." >&2
    exit 1
fi

_snap_enabled() {
    [ -f "/etc/snapper/configs/$SNAP_CONFIG" ] || return 1
    [ -d "$SNAP_TIMELINE" ] || return 1
    # Only bother when the root is actually btrfs (with snapper configured
    # for it); there is no point snapshotting a non-btrfs root.
    findmnt -no FSTYPE / 2>/dev/null | grep -q '^btrfs$'
}

_should_snap() {
    # Snapshot only when we are mutating packages: -S (install) or a bare
    # -u (update). The `--` end-of-options is irrelevant to detection.
    local _a
    for _a in "$@"; do
        case "$_a" in
            -S) return 0 ;;
            -Su|-us|-Su*|-S*) return 0 ;;
            -u) return 0 ;;
            -U) return 0 ;;
            --) break ;;
        esac
    done
    return 1
}

_main() {
    if ! _should_snap "$@" || ! _snap_enabled; then
        exec "$REAL_XBPS" "$@"
    fi

    desc="${DESC:-xbps system update ($(date '+%Y-%m-%d %H:%M:%S'))}"
    echo "==> [void-xbps-snap] before-update snapshot: $desc"

    pre_snap="$(
        snapper --no-dbus -c "$SNAP_CONFIG" create --type pre \
            --description "$desc" --cleanup number --print-number 2>/dev/null
    )" || {
        # If the pre snapshot cannot be taken, do not block the update;
        # fall back to running it unsnapshotted.
        echo "WARNING: could not take pre snapshot; running xbps-install without snapshots." >&2
        pre_snap=""
    }

    set +e
    "$REAL_XBPS" "$@"
    _rc=$?
    set -e

    if [ -n "$pre_snap" ]; then
        echo "==> [void-xbps-snap] after-update snapshot (pre #$pre_snap): $desc"
        snapper --no-dbus -c "$SNAP_CONFIG" create --type post \
            --pre-number "$pre_snap" --description "$desc" --cleanup number \
            >/dev/null 2>&1 || \
            echo "WARNING: could not take post snapshot." >&2
    fi

    exit "$_rc"
}

_main "$@"
INNER_EOF
chmod 0755 /usr/local/sbin/void-xbps-snap
echo "void-xbps-snap package-update snapshot wrapper installed (/usr/local/sbin/void-xbps-snap)"

# AI (Big Pickle) ADDITION — Beta-v2.6.5 [PKG-SNAPSHOT-AUTO]: shadow
# /usr/bin/xbps-install so NO behavior change is needed — every invocation
# (bare or via sudo, any shell) goes through the wrapper and snapshots
# automatically. The real ELF is renamed to xbps-install.real and a symlink
# is dropped in its place.
#   - Idempotent: `mv -n` never clobbers an existing .real, `ln -sf`
#     re-points the symlink — a re-run is a no-op.
#   - CAVEAT (self-update): `/usr/bin/xbps-install` BELONGS to the `xbps`
#     package. A future `posix: xbps-update`/`xbps-install -u xbps` that
#     re-installs the `xbps` package will re-place a REAL binary over our
#     symlink, silently un-shadowing the wrapper. Because the shadowed run
#     is itself executed by xbps, we deliberately do NOT wrap xbps's own
#     reinstall here (that would be recursion); the recovery is simply to
#     re-run this same block (or the documented one-liner) after an xbps
#     self-update. This is an accepted, documented maintenance tradeoff of
#     binary shadowing.
#   - Always installed (both GRUB and Limine, any config) — unlike the
#     snapper plugin, this is bootloader-independent.
if [ -f /usr/bin/xbps-install ] && [ -x /usr/local/sbin/void-xbps-snap ]; then
    [ -e /usr/bin/xbps-install.real ] || mv -n /usr/bin/xbps-install /usr/bin/xbps-install.real
    ln -sf /usr/local/sbin/void-xbps-snap /usr/bin/xbps-install
    echo "xbps-install shadowed -> void-xbps-snap (real binary kept at /usr/bin/xbps-install.real)"
fi

# AI (Big Pickle) ADDITION — Beta-v2.6.6 [TOOLS-DIR]: a persistent,
# self-contained maintenance/tools folder at /root/tools, written ONCE at
# install time and left for the admin to run later when something needs
# re-applying. These are the re-runnable recovery scripts the project's
# maintainers would otherwise have to regenerate by hand. Each is idempotent.
# Shipping them here (root's home) means they survive normal package updates
# and are available when a documented caveat hits (e.g. the xbps self-update
# that un-shadows /usr/bin/xbps-install). NOT on PATH — they are run-on-demand
# maintenance scripts, not live helpers; the live helpers stay in /usr/local/sbin.
# Contents (all RELATIVE references use this dir so the folder is relocatable):
mkdir -p /root/tools

# 1) Canonical backup copy of the xbps snapshot wrapper. /usr/local/sbin is
#    the live home; this pristine copy feeds re-shadow-xbps.sh below and is the
#    ultimate fallback if /usr/local/sbin is ever lost.
cp -f /usr/local/sbin/void-xbps-snap /root/tools/void-xbps-snap
chmod 0755 /root/tools/void-xbps-snap

# 1b) AI (Big Pickle) ADDITION — Beta-v2.6.8 [TOOLS-LIMINE-BACKUP]: canonical
#    backup copies of the three live Limine menu-engine helpers. Previously
#    /root/tools could RE-TRIGGER a menu regen (limine-sync.sh) and RE-INSTALL
#    the snapper trigger plugin (re-provision-snapper.sh) but could NOT rebuild
#    the /usr/local/sbin/void-* engines themselves if they were lost — so the
#    Limine+snapper menu pipeline was only reconstructible via a full reinstall.
#    These pristine copies close that gap: limine-sync.sh can now restore a
#    damaged /usr/local/sbin from here, making /root/tools a self-contained
#    regeneration kit for the whole void-limine + limine-snapper-sync pipeline.
#    (env.inc is sourced by the generator; sync-kernels and write-conf are the
#    two executables limine-sync.sh drives; void-reveal-yubikey-key is a
#    dracut keyscript-derived helper and is intentionally NOT backed up here.)
#    Beta-v2.7.9 [TOOLS-LIMINE-GUARD]: the cp+chmod calls are wrapped in a
#    BOOTLOADER=limine guard — on GRUB installs these files were never created
#    and the unguarded cp (under set -e) ENOENTed, killing the install.
if [ "$BOOTLOADER" = "limine" ]; then
    cp -f /usr/local/sbin/void-limine-env.inc /root/tools/void-limine-env.inc
    cp -f /usr/local/sbin/void-limine-sync-kernels /root/tools/void-limine-sync-kernels
    cp -f /usr/local/sbin/void-limine-write-conf /root/tools/void-limine-write-conf
    chmod 0644 /root/tools/void-limine-env.inc
    chmod 0755 /root/tools/void-limine-sync-kernels
    chmod 0755 /root/tools/void-limine-write-conf
fi

# 2) re-shadow-xbps.sh — recovery for the [PKG-SNAPSHOT-AUTO] caveat: an
#    `xbps` package self-update re-places a REAL ELF over the /usr/bin/xbps-install
#    symlink, silently un-shadowing it. This restores the wrapper + shadow.
#    Idempotent and self-healing (works whether .real exists or not, whether
#    the live wrapper survives or not).
cat > /root/tools/re-shadow-xbps.sh << 'INNER_EOF'
#!/bin/bash
# [TOOLS] Re-apply the automatic-update snapshot shadow. Run after an 'xbps'
# package self-update (which re-places a real binary over the symlink) or any
# time /usr/bin/xbps-install stops going through void-xbps-snap.
# Usage: sudo /root/tools/re-shadow-xbps.sh     (idempotent, safe to re-run)
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER=/usr/local/sbin/void-xbps-snap
BACKUP="$SELF_DIR/void-xbps-snap"
REAL=/usr/bin/xbps-install.real

if [ -x "$BACKUP" ]; then
    install -m 0755 "$BACKUP" "$WRAPPER"
    echo "==> wrapper restored to $WRAPPER (from $BACKUP)"
elif [ ! -x "$WRAPPER" ]; then
    echo "ERROR: no wrapper available (neither $BACKUP nor $WRAPPER). Reinstall or restore manually." >&2
    exit 1
fi

case "$(readlink /usr/bin/xbps-install 2>/dev/null || true)" in
    "$WRAPPER")
        echo "==> /usr/bin/xbps-install already -> void-xbps-snap; nothing to do."
        ;;
    "")
        # not a symlink — likely a real ELF (fresh xbps self-update)
        if [ -f /usr/bin/xbps-install ] && [ ! -e "$REAL" ]; then
            mv -n /usr/bin/xbps-install "$REAL"
            echo "==> moved real binary to $REAL"
        fi
        ln -sf "$WRAPPER" /usr/bin/xbps-install
        echo "==> re-linked /usr/bin/xbps-install -> void-xbps-snap"
        ;;
    *)
        # a dangling/stale symlink (or wrong target) — fix it
        rm -f /usr/bin/xbps-install
        ln -sf "$WRAPPER" /usr/bin/xbps-install
        echo "==> re-pointed /usr/bin/xbps-install -> void-xbps-snap"
        ;;
esac

echo "==> state:"
ls -la /usr/bin/xbps-install "$REAL" 2>/dev/null || true
echo "==> done. A normal 'sudo xbps-install -Su' now auto-snapshots again."
INNER_EOF
chmod 0755 /root/tools/re-shadow-xbps.sh

# 2b) AI ADDITION — Beta-v2.9.73 [ELOGIND-RUN-SELFHEAL]: keep the elogind
#     runit run-script fix in place across elogind package upgrades. Void's
#     elogind daemonizes itself (double-fork, reparent to PID 1, write
#     /run/elogind.pid); the STOCK /etc/sv/elogind/run `exec`s it, so runsv's
#     supervised child exits at once and runsv respawns it ~1x/sec forever,
#     flooding the kernel log with "elogind is already running as PID <n>".
#     The fixed run script (below) stays alive and waits on the live daemon
#     instead of respawning — it never signals the real daemon. Written once
#     here and applied at install time when SESSION_STACK=elogind; afterwards
#     the rc.local self-heal below re-applies it whenever an elogind upgrade
#     reverts the file (same pattern as re-shadow-xbps.sh).
cat > /root/tools/elogind.run.fixed << 'INNER_EOF'
#!/bin/sh
exec 2>&1
# elogind doesn't work right if it starts before dbus
sv check dbus >/dev/null || exit 1
# [elogind-respawn-loop fix, 2026-10-04]
# Void's elogind daemonizes itself (double-forks into the background,
# reparents to PID 1, writes /run/elogind.pid). The stock run script
# `exec`s it, so runsv's supervised child exits immediately and runsv
# respawns it about once per second forever, flooding the kernel log with
# "elogind is already running as PID <n>".
#
# If logind is ALREADY running, do NOT start another one (and never signal
# the live one): just stay alive as runsv's child and wait for the real
# daemon to exit. This stops the respawn loop without disturbing the live
# session. The daemon reparents to PID 1 and runs in its own session, so a
# runsv TERM to our process group cannot reach it.
if _pid=$(cat /run/elogind.pid 2>/dev/null) && [ -n "$_pid" ] && kill -0 "$_pid" 2>/dev/null; then
    while kill -0 "$_pid" 2>/dev/null; do
        sleep 10
    done
    exit 0
fi
# No running daemon: start it the stock way. It daemonizes and exits, so
# runsv will see us exit once; the next respawn finds the pidfile and takes
# the wait branch above.
exec /usr/libexec/elogind/elogind.wrapper
INNER_EOF
chmod 0755 /root/tools/elogind.run.fixed

cat > /root/tools/re-fix-elogind-run.sh << 'INNER_EOF'
#!/bin/sh
# =============================================================================
# [ELOGIND-RUN-SELFHEAL] — keep /etc/sv/elogind/run patched across upgrades.
#
# Problem: Void's elogind daemonizes itself (double-forks, reparents to PID 1,
# writes /run/elogind.pid). The STOCK /etc/sv/elogind/run `exec`s it, so runsv's
# supervised child exits immediately and runsv respawns it ~1x/sec forever,
# flooding the kernel log with "elogind is already running as PID <n>".
#
# Fix: a run script that, when logind is ALREADY running, stays alive and waits
# for the daemon to exit (no kill, no restart) instead of respawning. The daemon
# runs in its own session, so a runsv signal cannot reach it.
#
# The elogind xbps package OWNS /etc/sv/elogind/run, so any package upgrade
# overwrites the fix. This script (invoked from /etc/rc.local each boot, the
# same pattern as re-shadow-xbps.sh) restores the canonical fixed copy from
# /root/tools/elogind.run.fixed, but ONLY when the on-disk run script does not
# already match. Idempotent and safe at any time; never signals the live daemon
# (a later `runsv` respawn picks up the file automatically).
#
# To revert: remove this script's rc.local call and restore the stock run
# script (backup is /etc/sv/elogind/run.orig-20261004 and the USB bundle).
# =============================================================================
set -eu
export PATH="/usr/bin:/usr/sbin:/bin:/sbin"

FIXED="/root/tools/elogind.run.fixed"
TARGET="/etc/sv/elogind/run"

[ -f "$FIXED" ] || { echo "ERROR: $FIXED missing" >&2; exit 1; }
[ -f "$TARGET" ] || { echo "ERROR: $TARGET missing" >&2; exit 1; }

# Fast path: already fixed (compare bytes).
if cmp -s "$FIXED" "$TARGET"; then
    exit 0
fi

# The target is the stock (or otherwise different) script. Restore ours.
# Use `install` to preserve mode 0755. Never touch the running daemon.
install -m 0755 "$FIXED" "$TARGET"
echo "elogind run script restored to fixed copy (was reverted, likely by upgrade)."
INNER_EOF
chmod 0755 /root/tools/re-fix-elogind-run.sh

# Apply the fix IMMEDIATELY at install time (when the elogind session stack
# was chosen): replace the stock run script with the fixed copy and keep the
# stock one aside. No signal is sent to any daemon — elogind is not running
# in the chroot at this point.
if [ "${SESSION_STACK:-}" = "elogind" ] && [ -f /etc/sv/elogind/run ]; then
    [ -e /etc/sv/elogind/run.orig ] || cp /etc/sv/elogind/run /etc/sv/elogind/run.orig
    install -m 0755 /root/tools/elogind.run.fixed /etc/sv/elogind/run
    echo "elogind run script replaced with fixed copy (stock kept at /etc/sv/elogind/run.orig)"
fi

# 3) limine-sync.sh — manual, on-demand Limine boot-menu resync. Normally the
#    kernel hook and the snapper plugin regenerate the menu automatically; this
#    exists for the admin to force a rebuild (e.g. after manually moving/cleaning
#    /boot/efi/void-kernel or /.snapshots, or rule #8/#10 recovery). Limine-only:
#    a no-op with a clear message when this is a GRUB box.
cat > /root/tools/limine-sync.sh << 'INNER_EOF'
#!/bin/bash
# [TOOLS] Force a manual Limine boot-menu regeneration (kernel sync + config),
# and SELF-REBUILD a damaged /usr/local/sbin Limine helper stack from the
# canonical backups kept alongside this script.
# Usage: sudo /root/tools/limine-sync.sh
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The live engines limine-sync.sh drives. If one is missing but a canonical
# backup sits in this folder, restore it first (this is what makes /root/tools
# a self-contained regeneration kit even after /usr/local/sbin is wiped).
# map of backup-source -> live-destination (mode).
RESTORE_LIST="void-limine-env.inc:root:0644
void-limine-sync-kernels:root:0755
void-limine-write-conf:root:0755"

for entry in $RESTORE_LIST; do
    src_name="${entry%%:*}"
    rest="${entry#*:}"
    owner="${rest%%:*}"
    mode="${rest##*:}"
    src="$SELF_DIR/$src_name"
    dst="/usr/local/sbin/$src_name"
    if [ ! -e "$dst" ]; then
        if [ -f "$src" ]; then
            install -o "$owner" -g "0" -m "$mode" "$src" "$dst"
            echo "==> restored $dst from backup ($src)"
        else
            echo "ERROR: $dst missing and no backup at $src." >&2
            exit 1
        fi
    fi
done

# Only proceed on a real Limine box: the two executables underly the sync.
if [ ! -x /usr/local/sbin/void-limine-sync-kernels ] || \
   [ ! -x /usr/local/sbin/void-limine-write-conf ]; then
    echo "This is not a Limine install (limine helpers still absent); nothing to sync." >&2
    exit 0
fi
# Only meaningful on a Limine box: fail fast if no ESP limine.conf target.
[ -d /boot/efi ] || { echo "No /boot/efi mount — aborting limine sync." >&2; exit 1; }

echo "==> [void-limine-sync-kernels]"
/usr/local/sbin/void-limine-sync-kernels
echo "==> [void-limine-write-conf]"
/usr/local/sbin/void-limine-write-conf
echo "==> Limine boot menu regenerated."
INNER_EOF
chmod 0755 /root/tools/limine-sync.sh

# 4) re-provision-snapper.sh — SAFE snapper recovery, deliberately NOT the
#    full destructive reconciliation (the umount/rmdir/create-config dance that
#    would WIPE existing snapshots). This only restores the config file if it
#    is missing, re-applies the installer's timeline/retention tuning, and
#    re-installs the 00-void-limine-snapper-sync plugin (Limine only). Any
#    existing snapshots are left intact.
cat > /root/tools/re-provision-snapper.sh << 'INNER_EOF'
#!/bin/bash
# [TOOLS] Safely restore/re-tune the snapper 'root' config and (on Limine) the
# snapshot-boot plugin WITHOUT touching existing snapshots. Safe to re-run.
# Usage: sudo /root/tools/re-provision-snapper.sh
set -euo pipefail

if ! command -v snapper >/dev/null 2>&1; then
    echo "ERROR: snapper not installed." >&2
    exit 1
fi

# Only recreate a MISSING config; never clobber one that exists (avoid the
# destructive reconciliation that would lose the @snapshots mount/snapshots).
if [ ! -f /etc/snapper/configs/root ]; then
    echo "==> creating missing snapper 'root' config..."
    # Best-effort mirror of the installer's create-config (safe if /.snapshots
    # is already the @snapshots subvolume — create-config tolerates a mounted
    # subvolume; the install-time dance unmounted it only to live entirely in
    # the fresh-chroot case).
    snapper --no-dbus -c root create-config / || \
        { echo "ERROR: could not create snapper root config." >&2; exit 1; }
    mkdir -p /.snapshots
    mount /.snapshots 2>/dev/null || true
    chmod 750 /.snapshots
fi

# Re-apply the installer's retention tuning (idempotent sed on existing values).
CFG=/etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_HOURLY="10"/TIMELINE_LIMIT_HOURLY="3"/g' "$CFG"
sed -i 's/TIMELINE_LIMIT_DAILY="10"/TIMELINE_LIMIT_DAILY="5"/g' "$CFG"
sed -i 's/TIMELINE_LIMIT_WEEKLY="10"/TIMELINE_LIMIT_WEEKLY="2"/g' "$CFG"
sed -i 's/TIMELINE_LIMIT_MONTHLY="10"/TIMELINE_LIMIT_MONTHLY="0"/g' "$CFG"
sed -i 's/TIMELINE_LIMIT_YEARLY="10"/TIMELINE_LIMIT_YEARLY="0"/g' "$CFG"
sed -i 's/EMPTY_PRE_POST_CLEANUP="false"/EMPTY_PRE_POST_CLEANUP="true"/g' "$CFG"

# runit filter (exclude ephemeral service symlinks from snapshots).
mkdir -p /etc/snapper/filters
grep -qx 'var/service/*' /etc/snapper/filters/void-runit.txt 2>/dev/null || \
    echo "var/service/*" >> /etc/snapper/filters/void-runit.txt

# Limine-only: re-install the snapshot-boot menu plugin.
if [ -x /usr/local/sbin/void-limine-write-conf ] && [ -d /boot/efi ]; then
    mkdir -p /usr/lib/snapper/plugins
    cat > /usr/lib/snapper/plugins/00-void-limine-snapper-sync << 'PLUGIN_EOF'
#!/bin/bash
set -eEo pipefail
export PATH="/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"
case "${1:-}" in
    create-snapshot-post|delete-snapshot-post)
        /usr/local/sbin/void-limine-write-conf >/dev/null 2>&1
        ;;
esac
exit 0
PLUGIN_EOF
    chmod 0755 /usr/lib/snapper/plugins/00-void-limine-snapper-sync
    echo "==> Limine snapper plugin re-installed."
fi

echo "==> Snapper provisioning OK. Existing snapshots untouched."
INNER_EOF
chmod 0755 /root/tools/re-provision-snapper.sh

# 4b) AI (Big Pickle) ADDITION — Beta-v2.7.3 [SUBVOL-TOOL]:
# void-subvol-tool.sh — post-install subvolume management. Unlike the
# install-time SUBVOL_LIST/create-loop/mount/fstab lock-step (Stage 1), this is
# an on-demand maintenance tool that creates/flattens/detaches an additional
# flat sibling subvolume at runtime. It is PURELY STRUCTURAL: it never installs
# software (it has exactly the same guarantee the PROVISION_* paths give at
# install — you can build @postgresql, @steam, @containers, etc. for manual use
# later without pulling the owning package). Additions are top-level siblings
# (never nested inside @), so they are automatically outside Snapper rollback
# scope — the same flat-topology property as the base layout. nodatacow is
# applied ONLY via fstab mount options, never `chattr +C` (AGENTS.md [NODATACOW]
# invariant: chattr on a btrfs subvolume root is shadowed by the mount). The
# btrfs device is discovered from the mounted root source (findmnt), and the
# filesystem UUID for the fstab line resolved via blkid, so it stays correct
# under LUKS/mapper.
# AI (Big Pickle) CHANGE — Beta-v2.9.3 [SUBVOL-INSTALL]: still PURELY
# STRUCTURAL by default, but `add ... --install` now ALSO runs xbps-install for
# the subvol's owning package(s) (see PKG_MAP in the tool body) AFTER the
# sibling is mounted at its runtime path, so the software's data lands on the
# isolated subvolume from the first run — mirroring the installer's own
# provisioning. Without --install the structural guarantee is unchanged: the
# tool still never pulls the owning package.
cat > /root/tools/void-subvol-tool.sh << 'INNER_EOF'
#!/bin/bash
# [TOOLS] Post-install subvolume manager for the installer's flat Btrfs layout.
# Creates / checks / detaches / destroys a FLAT sibling subvolume (a top-level
# sibling of @, never nested inside it), matching the topology Snapper
# rollbacks already assume. Purely structural — it never installs software, so
# you can add @steam/@postgresql/@docker etc. for later manual use.
#
# Critical btrfs detail: a flat sibling can ONLY be created from the TOP-LEVEL
# tree (subvolid=5), NOT from inside the running @ mount. Running
# `btrfs subvolume create <mountpoint>` from inside @ would create a NESTED
# subvolume inside @ — silently making it part of Snapper rollback scope. This
# tool therefore mounts the top-level tree (the same subvolid=5 dance the
# installer's own Stage-1 uses) to create/inspect/destroy siblings, then mounts
# the new subvol at its runtime path via fstab.
#
# Usage: sudo /root/tools/void-subvol-tool.sh <verb> [args]
#   list                                  show every flat sibling + mount/fstab state
#   check <subvol>                        read-only status of one sibling
#   add <subvol> <mountpoint> [--nodatacow] [--install]   create sibling + mount + fstab
#   add <subvol> <mountpoint> <source-dir> [--nodatacow] [--install]  same, migrating source's contents in
#   add <subvol> --user <name> [--nodatacow] [--install]  per-user profile: mountpoint derived from
#                                                      /home/<name>/<known relative path> (asks to confirm)
#   add <subvol> [--nodatacow] [--install] (per-user profile only) prompts for the username, then derives the
#                                                      mountpoint from /home/<name>/<known relative path>
#   add --class <name> [--user <name>] [--install]   create EVERY subvol in an optional-software family:
#                                                     containers databases web mail game virtualization flatpak
#                                                     (per-user members need a username; pass --user or it prompts once)
#   --install            additionally run xbps-install for the owning package(s) of
#                        the subvol(s) being added (see PKG_MAP below). Subvols with
#                        no xbps mapping (e.g. @postgresql, @mariadb, @usercache,
#                        @brave — a Flatpak-only app) are created/isolated but no
#                        package is installed.
#   detach <subvol>                       umount + drop fstab line (subvol + data preserved)
#   destroy <subvol>                      umount + drop fstab + btrfs subvolume delete (asks)
set -euo pipefail

die()  { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*"; }

DEVDIR=""     # btrfs filesystem device path (e.g. /dev/mapper/void-root or raw)
FSUUID=""     # btrfs filesystem UUID (for the fstab line)
TOPMNT=""     # temp mountpoint for the top-level tree (subvolid=5)

# Resolve the running root's btrfs source: a device PATH (not UUID), since the
# btrfs tools + subvolid=5 mount need a real device. Works on LUKS/mapper and
# raw partitions alike.
resolve_dev() {
    local src
    src="$(findmnt -no SOURCE / 2>/dev/null)" || die "cannot resolve mounted root device."
    # [SUBVOL-TOOL-RESOLVEDEV] (Beta-v2.9.46): btrfs findmnt SOURCE appends the
    # active subvol as `[/@]` (e.g. /dev/mapper/void3[/@]), but a subvolid=5 mount
    # needs the bare device node — every verb failed with "special device
    # /dev/mapper/void3[/@] does not exist". Strip any `[/...]` suffix.
    DEVDIR="${src%%\[*}"
    FSUUID="$(blkid -s UUID -o value "$DEVDIR" 2>/dev/null || \
              findmnt -no UUID / 2>/dev/null || true)"
    [ -n "$DEVDIR" ] || die "empty root device."
    [ -n "$FSUUID" ] || die "cannot resolve btrfs filesystem UUID for $DEVDIR."
}

# Mount the top-level tree (subvolid=5) at a temp dir. Call unmount_top()
# when done. This is required for any operation on flat siblings.
mount_top() {
    TOPMNT="$(mktemp -d)"
    mount -o noatime,subvolid=5 "$DEVDIR" "$TOPMNT" || {
        rmdir "$TOPMNT"; TOPMNT=""; die "cannot mount top-level tree (subvolid=5) from $DEVDIR."
    }
}
unmount_top() {
    [ -n "$TOPMNT" ] || return 0
    umount "$TOPMNT" 2>/dev/null || true
    rmdir "$TOPMNT" 2>/dev/null || true
    TOPMNT=""
}
trap unmount_top EXIT

norm_subvol() {
    local name="$1"
    name="${name#/}"
    case "$name" in
        @*) ;;
        *)  name="@$name" ;;
    esac
    # AI (Big Pickle) ADDITION — Beta-v2.9.37 [GAME-SUBVOL] alias resolution:
    # the old @steam subvol is gone (replaced by the shared @game multi-mount).
    # A pre-2.9.37 command (`add @steam --user alice`) resolves to @game so the
    # one canonical sibling is addressed; PKG_MAP keeps `[@steam]` for any
    # --install issued through the alias.
    if [ "$name" = "@steam" ]; then
        echo "@game"
    else
        echo "$name"
    fi
}

# Per-user profile subvolumes: their mountpoint lives under /home/<user>, so the
# relative path is fully known once a username is supplied. `--user <name>`
# derives the mountpoint; empty = not a per-user profile (plain system path).
# NOTE: per-user mounts must not pre-exist root-owned. The tool CREATES the
# sibling but does NOT chown/remake the parent chain — the caller must ensure
# /home/<user> and the intermediate parents (e.g. .config / .local/share) are
# owned by <user>, the same rule provision_browser_subvol enforces at install.
declare -A USER_PROFILE_PATH=(
    [@mozilla]="/.config/mozilla"
    [@mozilla-cache]="/.cache/mozilla"
    [@chromium]="/.config/chromium"
    [@vivaldi]="/.config/vivaldi"
    [@falkon]="/.config/falkon"
    [@brave]="/.config/BraveSoftware/Brave-Browser"
    [@thunderbird]="/.thunderbird"
    [@steam]="/.local/share/Steam"
    # AI (Big Pickle) ADDITION — Beta-v2.9.37 [GAME-SUBVOL]: ONE @game subvol
    # mounted at several per-user paths (space-separated = multi-mount; a btrfs
    # subvolume may mount at many paths, one fstab line each). The set is
    # derived from the launchers the installer selected (Steam + lutris).
    # `add --user` loops the set; `@steam` above stays as a back-compat alias.
    # Heroic/Bottles are NOT here — Flatpak-delivered, their data lives under
    # @home at ~/.var/app/...
    [@game]="/.local/share/Steam /.local/share/lutris"
    [@containers-user]="/.local/share/containers"
    [@usercache]="/.cache"
    [@virtualbox]="/VirtualBox VMs"
    # AI (Big Pickle) ADDITION — Beta-v2.9.36 [INSTALL-BREW]: Homebrew's
    # user-owned ~/.linuxbrew prefix. Structural-only (no xbps package —
    # brew's CLI/dev runtime deps git/curl/file/procps-ng are installed by the
    # installer separately from the xbps stage, not by this tool).
    [@linuxbrew]="/.linuxbrew"
)

# Software-class grouping for `--class <name>`: a class is a set of subvolumes
# that usually belong to one optional-software family. Members are resolved to
# a mountpoint via SYS_MOUNT (system paths) or USER_PROFILE_PATH (per-user,
# needing a username). add_subvol() does the actual create/mount/fstab.
declare -A SYS_MOUNT=(
    [@docker]="/var/lib/docker"
    [@containers]="/var/lib/containers"
    [@postgresql]="/var/lib/postgresql"
    [@mariadb]="/var/lib/mysql"
    [@libvirt]="/var/lib/libvirt"
    [@flatpak]="/var/lib/flatpak"
)
# System-path siblings that should be nodatacow (db/disk-churn datadirs) —
# same `[NODATACOW]`-via-fstab rule as the installer.
declare -A SYS_NODATACOW=(
    [@postgresql]=1
    [@mariadb]=1
    [@libvirt]=1
)
declare -A CLASS_SUBVOLS=(
    [containers]="@docker @containers @containers-user"
    [databases]="@postgresql @mariadb"
    [web]="@mozilla @mozilla-cache @chromium @vivaldi @falkon @brave"
    [mail]="@thunderbird"
    [game]="@game"
    # AI (Big Pickle) ADDITION — Beta-v2.9.37 [GAME-SUBVOL]: `gaming` is kept
    # as a back-compat alias of `game` (pre-2.9.37 docs/CLI used it with
    # `@steam`); it resolves to the same @game multi-mount set.
    [gaming]="@game"
    [dev]="@linuxbrew"
    [virtualization]="@libvirt @virtualbox"
    [flatpak]="@flatpak"
)
CLASS_LIST="containers databases web mail game dev virtualization flatpak"

# xbps package(s) that own each subvol's data directory, for `--install` /
# `install --class`. Subvols absent here are structural-only (no Void package to
# install): @postgresql/@mariadb (never auto-installed by the installer — they
# are pre-create/manual targets), @usercache (cache dir only), @mozilla-cache
# (companion of @mozilla — installs with it), @brave (no official Void package;
# Flatpak-only, and this tool is xbps-only by design — see [INSTALL-BRAVE]).
# Mirrors the installer's own Stage-2 install lines (see grep:
# `[ "$INSTALL_X" = "true" ] && install_pkgs ...`).
declare -A PKG_MAP=(
    [@docker]="docker"
    [@containers]="podman fuse-overlayfs slirp4netns crun catatonit"
    [@containers-user]="podman fuse-overlayfs slirp4netns crun catatonit"
    [@libvirt]="qemu libvirt virt-manager"
    [@virtualbox]="virtualbox-ose virtualbox-ose-dkms"
    [@mozilla]="firefox"
    [@chromium]="chromium"
    [@vivaldi]="vivaldi"
    [@falkon]="falkon"
    [@thunderbird]="thunderbird"
    [@steam]="steam"
    [@game]="steam lutris"
    [@flatpak]="flatpak"
)

# Install a set of packages via xbps-install. Like the installer's own
# install_pkgs, -Sy syncs metadata first so a just-added package is found, and
# failures are loud (set -e aborts onward). OPTIONAL packages that no longer
# exist as installable xbps packages are a hard error here — better to fail
# loudly than silently hand the caller a subvol with nothing in it.
install_packages() {
    [ $# -ge 1 ] || return 0
    info "installing package(s): $*"
    xbps-install -Sy "$@" || die "xbps-install failed for: $*"
}

# List of packages that own subvol(s) being added via a class (dedup to avoid
# re-syncing xbps metadata per member).
class_packages() {
    local cls="$1" sv pkgs=""
    for sv in ${CLASS_SUBVOLS[$cls]:-}; do
        pkgs="$pkgs ${PKG_MAP[$sv]:-}"
    done
    echo "${pkgs# }"
}

# List every top-level sibling (direct child of the top-level tree).
siblings() { btrfs subvolume list -o "$TOPMNT" 2>/dev/null | sed -n 's/.*path \([^ ]*\)$/\1/p'; }

sibling_path() { echo "$TOPMNT/$1"; }

fstab_line() { grep -E "(^|[[:space:]])subvol=$1([[:space:]]|,)" /etc/fstab || true; }
is_mounted() { findmnt -n "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# list
# ---------------------------------------------------------------------------
cmd_list() {
    mount_top
    local found=0
    while IFS= read -r sv; do
        [ -n "$sv" ] || continue
        found=1
        local mnt
        mnt="$(awk -v svpat="subvol=$sv" '$1 ~ /^UUID=/ && $0 ~ svpat {print $2; exit}' /etc/fstab)"
        printf '  %-20s fstab=%s\n' "$sv" "${mnt:-<no fstab>}"
    done < <(siblings)
    [ "$found" = "1" ] || echo "  (no flat siblings found)"
}

# ---------------------------------------------------------------------------
# check
# ---------------------------------------------------------------------------
cmd_check() {
    [ $# -eq 1 ] || die "usage: void-subvol-tool.sh check <subvol>"
    local sv fst
    sv="$(norm_subvol "$1")"
    mount_top
    if [ -e "$(sibling_path "$sv" )" ]; then
        echo "subvol $sv: PRESENT (top-level sibling; outside Snapper rollback scope)."
    else
        echo "subvol $sv: absent."
    fi
    fst="$(fstab_line "$sv")"
    if [ -n "$fst" ]; then
        echo "fstab: mounted at $(awk '$1 ~ /^UUID=/ && $0 ~ "subvol='"$sv"'([[:space:],])" {print $2}' /etc/fstab | tr '\n' ' ')"
    else
        echo "fstab: no mount entry."
    fi
    mnt="$(awk '{print $2}' <<<"$fst")"
    if [ -n "$mnt" ] && is_mounted "$mnt"; then
        echo "mounted: yes (at $mnt)"
    else
        echo "mounted: no"
    fi
}

# ---------------------------------------------------------------------------
# AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS-GUARD]: data-region guard.
# When a data region was carved onto its own partition at install time, the
# subvolumes that region owns can NEVER be created as root-Btrfs subvolumes
# (they would collide with — and be shadowed by — the region partition mount
# at the same mountpoint). Reads /etc/void-installer/install-config REGION_*
# facts (default btrfs = not carved); dies with an actionable message when an
# add would create an owned subvol under a carved region. Mirrors the
# host-asbuilt guard. Region ownership map (must match the FOLD in the
# installer): home owns the per-user/browser set, var owns the /var set,
# cache/srv/opt own themselves, games owns nothing (a plain dir).
# ---------------------------------------------------------------------------
region_fs() { # $1=region name -> the fs it was carved to (default btrfs)
    local _v _rfv
    if [ "$1" = "games" ]; then
        _rfv="REGION_GAMES"
    else
        _rfv="REGION_${1^^}_FS"
    fi
    _v=$(sed -n "s/^${_rfv}=//p" /etc/void-installer/install-config 2>/dev/null | tail -1 | tr -d '"')
    [ -n "$_v" ] || _v="btrfs"
    echo "$_v"
}

guard_region_subvol() { # $1=subvol name; dies if its region was carved
    local sv="$1" reg=""
    case "$sv" in
        @home|@usercache|@mozilla|@mozilla-cache|@chromium|@vivaldi|@falkon|@brave|@thunderbird|@game|@containers-user|@linuxbrew|@virtualbox) reg="home" ;;
        @log|@spool|@network|@sddm|@lightdm|@libvirt|@flatpak|@docker|@containers) reg="var" ;;
        @cache) reg="cache" ;;
        @srv)  reg="srv" ;;
        @opt)  reg="opt" ;;
    esac
    if [ -n "$reg" ] && [ "$(region_fs "$reg")" != "btrfs" ]; then
        unmount_top
        die "subvolume '$sv' is owned by the '$reg' data region, which is carved onto its own partition on this machine (REGION_${reg}_FS != btrfs). It cannot be created as a root-Btrfs subvolume — its mountpoint is provided by the region partition. (MULTI-FS-GUARD)"
    fi
}

# ---------------------------------------------------------------------------
# add_subvol — the actual create/mount/fstab body, shared by `add <subvol>`
# and `add --class <name>`. nodatacow: 1/0. src: optional migration source.
# install: 1/0 — when 1, xbps-install the owning package(s) AFTER the subvol is
# mounted, so the software's data lands on the isolated subvolume from the first
# run (mirrors the installer's own install-time provisioning).
# ---------------------------------------------------------------------------
add_subvol() {
    local sv="$1" mnt="$2" nodatacow="$3" src="$4" install="$5" mode sp pkgs
    pkgs="${PKG_MAP[$sv]:-}"
    # [MULTI-FS-GUARD] (Beta-v2.9.38): refuse to create region-owned subvols on
    # a machine where that region lives on its own partition. Runs before
    # mount_top so the top-level mount is not touched on a disallowed add.
    guard_region_subvol "$sv"
    mount_top
    sp="$(sibling_path "$sv")"
    [ -e "$sp" ] && { unmount_top; die "sibling '$sv' already exists (delete it first if you mean to recreate)."; }
    # AI (Big Pickle) ADDITION — Beta-v2.9.37 [GAME-SUBVOL]: the fstab guard is
    # RELAXED for @game — a btrfs subvolume may mount at several paths (each
    # adopted launcher's datadir has its own fstab line). The first mount
    # already wrote `subvol=@game`; later mounts of the same sibling are added
    # via --add-mount and must NOT hit the "already has an fstab entry" die.
    if [ "${ADD_MOUNT:-0}" = "1" ]; then
        if [ -e "$sp" ]; then
            info "sibling '$sv' exists — adding another mountpoint (multi-mount)."
        else
            unmount_top; die "sibling '$sv' does not exist yet — create it with a plain 'add' first."
        fi
    else
        [ -e "$sp" ] && { unmount_top; die "sibling '$sv' already exists (delete it first if you mean to recreate)."; }
        [ -z "$(fstab_line "$sv")" ] || { unmount_top; die "subvolume '$sv' already has an fstab entry."; }
    fi
    is_mounted "$mnt" && { unmount_top; die "'$mnt' is already a mountpoint in use."; }

    # Beta-v2.9.3 [SUBVOL-DATA-GUARD]: mounting a fresh (empty) sibling OVER a
    # non-empty target hides whatever is already at $mnt (it stays on disk inside
    # @ but becomes inaccessible behind the mount) — e.g. software installed
    # BEFORE the subvol was built. Refuse unless the caller is migrating the
    # existing contents in via a source-dir (add <sv> <mnt> <mnt>), which copies
    # them onto the sibling before mounting. This forces the safe path instead of
    # silently stranding pre-existing data.
    if [ -z "$src" ] && [ -d "$mnt" ] && [ -n "$(ls -A "$mnt" 2>/dev/null)" ]; then
        unmount_top
        die "target '$mnt' already contains data, but no source-dir was given to migrate it (add $sv $mnt $mnt). Mounting an empty sibling over it would HIDE that data inside @. Provide the source-dir, or empty the target first."
    fi

    mnt="$(readlink -f "$mnt")"

    # AI (Big Pickle) ADDITION — Beta-v2.9.37 [GAME-SUBVOL]: under ADD_MOUNT the
    # sibling + fstab line already exist from the first mount — only the new
    # mountpoint line + mount are added. The create/migrate/install steps are
    # first-mount-only.
    if [ "${ADD_MOUNT:-0}" != "1" ]; then
        info "creating flat sibling $sv (top-level tree) for $mnt..."
        btrfs subvolume create "$sp" || { unmount_top; die "btrfs subvolume create failed."; }

        # optional migration: copy existing contents of $src into the fresh sibling
        # BEFORE mounting it over $mnt, preserving ownership/permissions. $src is
        # live under the running @ mount; copying into the subvolid=5-tree path is
        # a cross-visible copy (both views show the same filesystem).
        if [ -n "$src" ]; then
            [ -d "$src" ] || {
                echo "ERROR: source '$src' not a dir (removing partially-created sibling)." >&2
                btrfs subvolume delete "$sp"
                unmount_top
                exit 1
            }
            info "migrating contents of $src into new sibling..."
            cp -a -- "$src"/. "$sp"/ 2>/dev/null || true
        fi
        unmount_top
    fi

    # fstab mount options: nodatacow MUST be via mount options, never chattr.
    if [ "$nodatacow" = "1" ]; then
        mode="noatime,nodatacow,compress=none"
        info "mount options: $mode (nodatacow via fstab, per installer [NODATACOW])"
    else
        mode="noatime,compress=zstd:1"
        info "mount options: $mode"
    fi

    # fstab is whitespace-delimited, so escape any space in the mountpoint
    # (e.g. VirtualBox's "VirtualBox VMs") as `\040` — the mount call below
    # still uses the literal path, it's only the fstab field that's escaped.
    local fstab_path="${mnt// /\\040}"
    echo "UUID=$FSUUID $fstab_path btrfs $mode,subvol=$sv 0 0" >> /etc/fstab
    mount "$mnt"
    info "done: $sv mounted at $mnt (flat sibling; outside Snapper rollback scope)."

    # --install: now that the subvol is live at its runtime path, install the
    # owning package(s) so their data lands on the isolated subvolume directly.
    if [ "$install" = "1" ] && [ "${ADD_MOUNT:-0}" != "1" ]; then
        if [ -n "$pkgs" ]; then
            # shellcheck disable=SC2086 # deliberate: $pkgs is a space-separated list of package names
            install_packages $pkgs
            info "installed package(s) for $sv: $pkgs"
        else
            echo "NOTE: $sv has no xbps package mapping — subvol created/isolated but nothing installed." >&2
            info "if you install its software manually, its data will land on $mnt (isolated)."
        fi
    fi
}

# ---------------------------------------------------------------------------
# add — create a single flat sibling (subvol + mountpoint + fstab).
# ---------------------------------------------------------------------------
cmd_add() {
    local sv mnt src nodatacow=0 opt sp user="" install=0
    local -a positional=()
    for opt in "$@"; do
        case "$opt" in
            --nodatacow) nodatacow=1 ;;
            --install)   install=1 ;;
            --user)      user="unset-next" ;;
            --user=*)    user="${opt#--user=}" ;;
            --*)         die "unknown option '$opt' (--nodatacow | --install | --user <name>)" ;;
            *)
                if [ "$user" = "unset-next" ]; then
                    user="$opt"
                else
                    positional+=("$opt")
                fi
                ;;
        esac
    done
    [ "$user" = "unset-next" ] && die "--user requires a username (e.g. --user alice)."

    # <subvol> is always the first positional; an explicit <mountpoint> /
    # <source-dir> come after.
    [ "${#positional[@]}" -ge 1 ] || die "usage: void-subvol-tool.sh add <subvol> <mountpoint> [source-dir] [--nodatacow] [--install] [--user <name>]"
    sv="$(norm_subvol "${positional[0]}")"
    mnt="${positional[1]:-}"
    src="${positional[2]:-}"
    [ "${#positional[@]}" -le 3 ] || die "too many positional args (subvol mountpoint [source-dir], plus --user/--nodatacow/--install flags)."

    # Derive a per-user mountpoint from --user when no explicit one was given.
    # AI (Big Pickle) ADDITION — Beta-v2.9.37 [GAME-SUBVOL]: a MULTI-MOUNT set
    # (space-separated, e.g. @game) is NOT derived into one bogus path here —
    # it falls through to the multi-mount loop below.
    if [ -z "$mnt" ] && [ -n "$user" ]; then
        local rel="${USER_PROFILE_PATH[$sv]:-}"
        [ -n "$rel" ] || die "no known per-user path for '$sv' — supply an explicit <mountpoint>."
        if [[ "$rel" != *" "* ]]; then
            mnt="/home/$user$rel"
            echo "Derived per-user mountpoint: $mnt"
            read -r -p "Use this mountpoint? [Y/n]: " ans
            case "$ans" in [nN]*) die "aborted." ;; esac
        fi
    fi

    # No mountpoint and no --user: if this is a known per-user profile, offer to
    # prompt for the username instead of demanding the full path.
    if [ -z "$mnt" ] && [ -z "$user" ]; then
        local rel="${USER_PROFILE_PATH[$sv]:-}"
        if [ -n "$rel" ]; then
            read -r -p "Per-user profile $sv — enter the username to target (e.g. alice): " user
            [ -n "$user" ] || die "no username given."
            if [[ "$rel" != *" "* ]]; then
                mnt="/home/$user$rel"
                echo "Derived per-user mountpoint: $mnt"
                read -r -p "Use this mountpoint? [Y/n]: " ans
                case "$ans" in [nN]*) die "aborted." ;; esac
            fi
        fi
    fi

    [ -n "$mnt" ] || die "no mountpoint — pass one explicitly, or --user <name> (or just the subvol name for a per-user prompt)."
    if [ -d "$mnt" ]; then :; else
        if [ -n "$user" ]; then
            die "mountpoint '$mnt' does not exist — create and chown it to $user first."
        else
            die "mountpoint '$mnt' does not exist."
        fi
    fi

    # --user with an explicit mountpoint: warn so a wrong path isn't silent.
    if [ -n "$user" ] && [ -n "${positional[1]:-}" ]; then
        echo "Note: --user $user given with explicit mountpoint — using '$mnt' as typed."
    fi

    # AI (Big Pickle) ADDITION — Beta-v2.9.37 [GAME-SUBVOL]: MULTI-MOUNT loop.
    # A per-user subvol whose USER_PROFILE_PATH value contains a space (@game)
    # mounts at EVERY path in the set, each with its own fstab line. The first
    # path creates + mounts the fresh sibling; each later path is an ADD_MOUNT
    # (relaxed fstab-guard; same subvolume, additional mountpoint). An explicit
    # <mountpoint> positional wins and behaves like a plain single mount.
    local _sv_relset="${USER_PROFILE_PATH[$sv]:-}"
    if [ -z "${positional[1]:-}" ] && [ -n "$user" ] && [[ "$_sv_relset" == *" "* ]]; then
        local _sv_mnt_rel _sv_first=1
        for _sv_mnt_rel in $_sv_relset; do
            _sv_mnt="/home/$user$_sv_mnt_rel"
            [ -d "$_sv_mnt" ] || die "mountpoint '$_sv_mnt' does not exist — create and chown it to $user first."
            if [ "$_sv_first" = "1" ]; then
                ADD_MOUNT=0 add_subvol "$sv" "$_sv_mnt" "$nodatacow" "$src" "$install"
                _sv_first=0
            else
                ADD_MOUNT=1 add_subvol "$sv" "$_sv_mnt" "$nodatacow" "" "$install"
            fi
        done
        return 0
    fi

    add_subvol "$sv" "$mnt" "$nodatacow" "$src" "$install"
}

# ---------------------------------------------------------------------------
# add --class <name> — create every subvol in an optional-software family.
#   classes: containers databases web mail game virtualization flatpak
#   --user <name> seeds the username for all per-user members (or prompts once).
# ---------------------------------------------------------------------------
cmd_add_class() {
    local cls="" user="" opt install=0
    local -a cls_args=()
    for opt in "$@"; do
        case "$opt" in
            --user)      user="unset-next" ;;
            --user=*)    user="${opt#--user=}" ;;
            --install)   install=1 ;;
            --*)         die "unknown option '$opt' (--user <name> | --install)" ;;
            *)           if [ "$user" = "unset-next" ]; then user="$opt"; else cls_args+=("$opt"); fi ;;
        esac
    done
    [ "$user" = "unset-next" ] && die "--user requires a username (e.g. --user alice)."
    [ "${#cls_args[@]}" -eq 1 ] || die "usage: void-subvol-tool.sh add --class <name> [--user <name>] [--install]  (classes: $CLASS_LIST)"
    cls="${cls_args[0]}"
    local members="${CLASS_SUBVOLS[$cls]:-}"
    [ -n "$members" ] || die "unknown class '$cls' (classes: $CLASS_LIST)."

    info "class '$cls' -> creating: $members"
    if [ "$install" = "1" ]; then
        local cpkgs
        cpkgs="$(class_packages "$cls")"
        if [ -n "$cpkgs" ]; then
            info "class '$cls' --install -> packages: $cpkgs"
        else
            echo "NOTE: class '$cls' has no xbps package mapping — creating subvols only, nothing installed." >&2
        fi
    fi

    # If any member is a per-user profile and no --user was given, prompt once
    # for the shared username so browsing/mail/steam/virtualbox land under it.
    local sv has_user=0
    for sv in $members; do
        [ -n "${USER_PROFILE_PATH[$sv]:-}" ] && has_user=1
    done
    if [ "$has_user" = "1" ] && [ -z "$user" ]; then
        read -r -p "Class '$cls' has per-user profile subvol(s) — enter the username to target (e.g. alice): " user
        [ -n "$user" ] || die "no username given for per-user members of class '$cls'."
    fi

    for sv in $members; do
        local mnt ndc
        if [ -n "${USER_PROFILE_PATH[$sv]:-}" ]; then
            [ -n "$user" ] || die "internal: class member '$sv' is per-user but no username resolved."
            # AI (Big Pickle) ADDITION — Beta-v2.9.37 [GAME-SUBVOL]: a multi-mount
            # member (@game) has a SPACE-separated USER_PROFILE_PATH value: the
            # sibling is created + mounted at its FIRST path, and each later path
            # becomes an ADD_MOUNT (a second fstab line for the same subvol).
            for _pbs_rel in ${USER_PROFILE_PATH[$sv]}; do
                mnt="/home/$user$_pbs_rel"
                [ -d "$mnt" ] || die "mountpoint '$mnt' does not exist — create (and for per-user paths chown to $user) first."
                if [ "$_pbs_rel" = "${USER_PROFILE_PATH[$sv]%% *}" ]; then
                    ADD_MOUNT=0 add_subvol "$sv" "$mnt" 0 "" "$install"
                else
                    ADD_MOUNT=1 add_subvol "$sv" "$mnt" 0 "" "$install"
                fi
            done
            unset _pbs_rel
        else
            mnt="${SYS_MOUNT[$sv]:-}"
            [ -n "$mnt" ] || die "internal: no mountpoint mapping for class member '$sv'."
            ndc="${SYS_NODATACOW[$sv]:-0}"
            [ -d "$mnt" ] || die "mountpoint '$mnt' does not exist — create (and for per-user paths chown to $user) first."
            ADD_MOUNT=0 add_subvol "$sv" "$mnt" "$ndc" "" "$install"
        fi
    done
    info "class '$cls' complete."
}

# ---------------------------------------------------------------------------
# detach — safe undo: drop fstab line + umount, preserving the sibling + data.
# ---------------------------------------------------------------------------
cmd_detach() {
    [ $# -eq 1 ] || die "usage: void-subvol-tool.sh detach <subvol>"
    local sv fst mnt
    sv="$(norm_subvol "$1")"
    fst="$(fstab_line "$sv")"
    [ -n "$fst" ] || die "no fstab entry for '$sv' (nothing to detach)."
    # AI (Big Pickle) ADDITION — Beta-v2.9.37 [GAME-SUBVOL]: @game multi-mount
    # means several fstab lines / mountpoints may reference the same subvol;
    # unmount EVERY one, then drop EVERY matching fstab line.
    for mnt in $(awk '$1 ~ /^UUID=/ && $0 ~ "subvol='"$sv"'([[:space:],])" {print $2}' /etc/fstab); do
        info "unmounting $mnt..."
        umount "$mnt" 2>/dev/null || true
    done
    # CRITICAL: BRE parens MUST be escaped (\( \)) — unescaped parens in POSIX
    # BRE are literal characters, so `subvol=$sv([[:space:],])` would match
    # nothing and leave every fstab line dangling after the umount above.
    sed -i "\~subvol=$sv\([[:space:],]\)~d" /etc/fstab
    info "detached $sv. Subvolume and data remain on disk. Re-attach with:"
    echo "  sudo /root/tools/void-subvol-tool.sh add $sv $mnt"
}

# ---------------------------------------------------------------------------
# destroy — full teardown (sibling + data deleted). Requires confirmation.
# ---------------------------------------------------------------------------
cmd_destroy() {
    [ $# -eq 1 ] || die "usage: void-subvol-tool.sh destroy <subvol>"
    local sv fst mnt sp
    sv="$(norm_subvol "$1")"
    fst="$(fstab_line "$sv")"
    # AI (Big Pickle) ADDITION — Beta-v2.9.37 [GAME-SUBVOL]: @game multi-mount —
    # unmount every path + drop every matching fstab line (escaped BRE parens,
    # same rule as cmd_detach) before deleting the sibling.
    if [ -n "$fst" ]; then
        for mnt in $(awk '$1 ~ /^UUID=/ && $0 ~ "subvol='"$sv"'([[:space:],])" {print $2}' /etc/fstab); do
            info "unmounting $mnt..."
            umount "$mnt" 2>/dev/null || true
        done
        sed -i "\~subvol=$sv\([[:space:],]\)~d" /etc/fstab
    fi
    echo "WARNING: this DELETES subvolume $sv and ALL data it holds. Cannot be undone."
    read -r -p "Type YES to confirm: " ans
    [ "$ans" = "YES" ] || die "aborted."
    mount_top
    sp="$(sibling_path "$sv")"
    [ -e "$sp" ] || die "sibling '$sv' not found in top-level tree."
    btrfs subvolume delete "$sp" >/dev/null
    info "destroyed $sv."
}

# ---------------------------------------------------------------------------
# dispatch
# ---------------------------------------------------------------------------
[ $# -ge 1 ] || { echo "usage: $0 <verb> [args]  (list|check|add|detach|destroy)" >&2; exit 1; }
verb="$1"; shift
resolve_dev
case "$verb" in
    list)    cmd_list "$@" ;;
    check)   cmd_check "$@" ;;
    add)     if [ "$1" = "--class" ]; then shift; cmd_add_class "$@"; else cmd_add "$@"; fi ;;
    detach)  cmd_detach "$@" ;;
    destroy) cmd_destroy "$@" ;;
    *) die "unknown verb '$verb' (list|check|add|detach|destroy)." ;;
esac
INNER_EOF
chmod 0755 /root/tools/void-subvol-tool.sh

# 5) README.md — user-facing documentation for the tools folder: what each tool
#    does, WHEN to reach for it, and the exact command to run. This is the
#    discoverability layer the admin sees first (and the one that survives on a
#    fresh install unlike the repo-side CHANGELOG/README).
cat > /root/tools/README.md << 'INNER_EOF'
# /root/tools — Void Linux maintenance & recovery tools

This folder is shipped by the Void Linux Installer (the same project that built
this box) and holds the re-runnable maintenance/recovery scripts. They are
**idempotent** (safe to run more than once). Most are **run-on-demand** — not on
`PATH`, because you invoke them deliberately rather than as background helpers.
One exception: `re-shadow-xbps.sh` is auto-invoked at every boot by
`/etc/rc.local` (the "void-reshadow" boot self-heal), so it is both a boot-time
fixup **and** a tool you can still run by hand to force a recovery without
rebooting.

Run every tool with **`sudo`** (they write to system-owned paths).

---

## Tool index

### `re-shadow-xbps.sh` — restore automatic update-snapshots
**What it does:** repairs the "shadow" that makes every `xbps-install` take an
automatic snapper pre/post snapshot pair. The real `/usr/bin/xbps-install` lives
at `/usr/bin/xbps-install.real`, and `/usr/bin/xbps-install` is a symlink to the
wrapper `void-xbps-snap`.

**When to run it yourself:** normally you **don't need to**. Every boot,
`/etc/rc.local` runs this script automatically (see `void-reshadow`), so if an
**`xbps` package self-update** re-places a *real* binary over the symlink —
silently disabling automatic snapshots, a known caveat of binary shadowing —
the shadow is repaired on the next boot before any later update can run
unsnapshotted. Run it manually only if you want to restore the shadow *without
rebooting*, or to confirm updates are still snapshotting (e.g. after a
`sudo xbps-install -Su` no longer prints "before-update snapshot").

**How:**
```bash
sudo /root/tools/re-shadow-xbps.sh
```
It restores the wrapper, re-establishes `/usr/bin/xbps-install.real`, and
re-links `/usr/bin/xbps-install -> void-xbps-snap`. Idempotent — safe to run at
every boot or by hand.

---

### `limine-sync.sh` — force a boot-menu resync (Limine only)
**What it does:** re-runs the kernel copy + `void-limine-write-conf` to
regenerate the Limine boot menu (including the `+Snapshots` submenu). If a
live Limine helper under `/usr/local/sbin` is missing, it **first restores it
from the canonical backup kept in this folder**, so this one script can
rebuild the whole menu pipeline even after `/usr/local/sbin` was wiped.

**When to use it:** the kernel hook and the snapper plugin normally do this
automatically. Reach for this if you manually changed `/boot/efi/void-kernel/`
or `/.snapshots/`, or if the snapshot menu looks stale and you want to force a
rebuild without waiting for a kernel/snapshot event — **or** if the
`/usr/local/sbin/void-limine-*` helpers were lost and you need to regenerate
them from backup.

**How:**
```bash
sudo /root/tools/limine-sync.sh
```
On a GRUB install it is a harmless no-op (prints a notice). It needs `/boot/efi`
mounted.

---

### Limine engine backups — `void-limine-env.inc`, `void-limine-sync-kernels`, `void-limine-write-conf`
Canonical pristine copies of the live Limine menu engines that `/usr/local/sbin`
uses. They are not meant to be run from here (their live home is
`/usr/local/sbin`, on `PATH`/sourced by the generator); they are the fallback
that `limine-sync.sh` restores from if the live copies are lost or damaged.
Without these, a broken `/usr/local/sbin` Limine stack was only fixable by a
full reinstall — now `sudo /root/tools/limine-sync.sh` can rebuild it.

---

### `re-provision-snapper.sh` — safely restore snapper (root config + plugin)
**What it does:** recreates a *missing* snapper `root` config, re-applies the
installer's retention/timeline tuning and the runit filter, and (on Limine)
re-installs the `00-void-limine-snapper-sync` plugin that keeps the snapshot
boot menu fresh.

**When to use it:** if `/etc/snapper/configs/root` was deleted or corrupted, if
the snapshot menu plugin stopped firing, or if you want to re-apply tuning after
editing it by hand.

**How:**
```bash
sudo /root/tools/re-provision-snapper.sh
```
It is **deliberately non-destructive**: it will only *create* a missing config
and *tune* an existing one. It will **never** delete or touch your existing
snapshots. It does not run the destructive "reconcile" step from the original
install (which would have wiped snapshots).

---

### `void-xbps-snap` — the update-snapshot wrapper (canonical backup)
Not a separate tool; this is a pristine copy of the `/usr/local/sbin/void-xbps-snap`
wrapper that `re-shadow-xbps.sh` restores from. You normally never run it
directly here — it lives on `PATH` via `/usr/local/sbin` already. Its job: when
run as `xbps-install`, it snapshots the root filesystem (snapper pre, then post)
around a mutating package operation so every update is rollback-able.

**When to use it:** only manually if you want an explicit, single-shot
snapshotted operation (it is the same engine the shadow uses):
```bash
sudo /root/tools/void-xbps-snap -S <pkg>
```

---

### `void-subvol-tool.sh` — add / inspect / detach flat subvolumes (post-install)
**What it does:** manages the installer's *flat* Btrfs subvolume topology after
the fact. It creates, checks, detaches, or destroys a **top-level sibling**
subvolume (never nested inside `@`), so anything you add is automatically
outside Snapper rollback scope — the same property as `@home`, `@opt`, etc.
It is **purely structural**: it never installs software, so you can create
`@steam`, `@postgresql`, `@containers`, etc. ahead of installing that software
manually, or wall off an existing directory.

**When to use it:** you want the profile/data of an app on its own
rollback-excluded subvolume but don't want (or already have) the app — e.g.
creating `@postgresql` before installing PostgreSQL, or turning an existing
`/var/lib/app` into its own subvol later. It mirrors the installer's own
flat-topology and nodatacow-via-fstab conventions.

**How:**
```bash
sudo /root/tools/void-subvol-tool.sh list
sudo /root/tools/void-subvol-tool.sh add @steam /home/USER/.local/share/Steam
sudo /root/tools/void-subvol-tool.sh add @postgresql /var/lib/postgresql --nodatacow
sudo /root/tools/void-subvol-tool.sh add @app /var/lib/app /var/lib/app   # migrate existing data + wall it off
sudo /root/tools/void-subvol-tool.sh check @app
sudo /root/tools/void-subvol-tool.sh detach @app        # umount + drop fstab (data preserved)
sudo /root/tools/void-subvol-tool.sh destroy @app       # full delete, asks for confirmation
```
Per-user profile subvolumes (browser profiles, `@game`, `@thunderbird`,
`@containers-user`, `@usercache`, ...) live under `/home/<user>`, so the tool
can derive the exact mountpoint from the username instead of you typing the
whole path. Use `--user <name>`, or just the subvol name and it will **prompt**
for the username:
```bash
sudo /root/tools/void-subvol-tool.sh add @chromium --user alice      # -> /home/alice/.config/chromium
sudo /root/tools/void-subvol-tool.sh add @containers-user --user alice   # -> /home/alice/.local/share/containers
sudo /root/tools/void-subvol-tool.sh add @steam                     # prompts "enter the username..."
# @game is a MULTI-MOUNT subvol (Beta-v2.9.37 [GAME-SUBVOL]): it mounts at
# each adopted launcher's datadir with its own fstab line:
sudo /root/tools/void-subvol-tool.sh add @game --user alice         # mounts at the FULL derived set (.local/share/Steam, .local/share/lutris)
```
Important: as at install (`[PERSONAL-DATA]`/`provision_browser_subvol`), the
per-user parents must already exist and be owned by the target user. Create and
`chown` the chain **before** the tool call, or run the migrate form
(`add @x /home/user/... /home/user/...`) so any pre-existing data is copied in
with ownership preserved. The tool creates the sibling and fstab line only — it
never chowns/remakes your home.

It refuses to double-create or double-mount. The one exception is `@game`,
whose `--add-mount` path intentionally relaxes the fstab-guard so a second
launcher's datadir can be added to the same sibling (`--add-mount` skips the
"already has an fstab entry" die; without it the tool refuses, so a plain
`add @game` on an already-mounted @game still refuses). `destroy` requires
typing `YES`. `nodatacow` is applied via the fstab mount option (never
`chattr +C`), matching the installer's `[NODATACOW]` rule that `chattr` on a
subvolume root is shadowed by the mount.

**Data-safety guard (`[SUBVOL-DATA-GUARD]`):** if the target mountpoint is
already non-empty (e.g. the software was installed *before* you built its
subvol, so its data sits inside `@`), the tool **refuses to proceed** unless you
supply the migrate form — `add <sv> <mnt> <mnt>` copies that existing data onto
the fresh sibling *before* it is mounted, so nothing is lost. Mounting an empty
sibling over a populated directory would HIDE the pre-existing data (it stays on
disk inside `@` but becomes inaccessible behind the mount). Provide the
source-dir to migrate, or empty the target first.

**Create every subvol for an optional-software family in one pass** with
`add --class <name>`. The tool resolves each member's mountpoint (system paths
from an internal map, per-user profiles under `/home/<user>`) and creates them
all — idempotently (already-created siblings are skipped by the existing-sibling
guard). By default it never installs or checks for the software, so the siblings
get created even on a lean system with none of it installed:
```bash
sudo /root/tools/void-subvol-tool.sh add --class containers --user alice
sudo /root/tools/void-subvol-tool.sh add --class databases          # @postgresql + @mariadb (nodatacow)
sudo /root/tools/void-subvol-tool.sh add --class web --user alice   # all browser profiles
sudo /root/tools/void-subvol-tool.sh add --class mail --user alice  # @thunderbird
sudo /root/tools/void-subvol-tool.sh add --class gaming --user alice# @game (multi-mount: Steam + lutris datadirs)
sudo /root/tools/void-subvol-tool.sh add --class dev --user alice    # @linuxbrew (Homebrew CLI/dev prefix)
sudo /root/tools/void-subvol-tool.sh add --class virtualization --user alice  # @libvirt + @virtualbox
sudo /root/tools/void-subvol-tool.sh add --class flatpak            # @flatpak
```

**Install the software at the same time** with `--install` (on a single `add` or
an `add --class`). After the subvol is created and mounted at its runtime path,
the tool runs `xbps-install -Sy` for the owning package(s) (see `PKG_MAP`), so
the software's data lands on the isolated subvolume from the very first run —
mirroring the installer's own provisioning:
```bash
sudo /root/tools/void-subvol-tool.sh add @steam --user alice --install   # create + install steam
sudo /root/tools/void-subvol-tool.sh add --class game --user alice --install
sudo /root/tools/void-subvol-tool.sh add --class virtualization --install # @libvirt + @virtualbox + their packages
```
Only subvols with an xbps package mapping install something. Subvols with no
Void package are still created/isolated but nothing is installed: `@postgresql`
and `@mariadb` (manual/pre-create targets, never auto-installed),
`@mozilla-cache` (installs with `@mozilla`), `@usercache` (cache dir only),
`@linuxbrew` (Homebrew's ~/.linuxbrew prefix, created on first login by the
vendor's own installer — structural-only, its runtime deps git/curl/file/procps-ng
are installed at install time), and
`@brave` (no official Void package — it is Flatpak-only, and this tool is
xbps-based by design). `@docker`/`@containers`/`@containers-user`/`@libvirt`/
`@virtualbox`/`@mozilla`/`@chromium`/`@vivaldi`/`@falkon`/`@thunderbird`/
`@steam`/`@flatpak` all map to their real packages. `--install` needs network
access and root, like any `xbps-install`.

Classes and their subvolumes:

| class | subvolumes |
|---|---|
| `containers` | `@docker`, `@containers`, `@containers-user` |
| `databases` | `@postgresql`, `@mariadb` (both nodatacow) |
| `web` | `@mozilla`, `@mozilla-cache`, `@chromium`, `@vivaldi`, `@falkon`, `@brave` |
| `mail` | `@thunderbird` |
| `game` | `@game` (multi-mount: `.local/share/Steam`, `.local/share/lutris`; `gaming` is a back-compat alias) |
| `virtualization` | `@libvirt` (nodatacow), `@virtualbox` |
| `flatpak` | `@flatpak` |

Class members are per-user profiles (every subvol whose name is `@`-prefixed
under a `/home` root — browser profiles, `@game`, `@thunderbird`,
`@containers-user`, `@virtualbox`) only when they use a per-user mountpoint.
Pass `--user <name>` to target all per-user members at once; if the class has
per-user members and you omit `--user`, the tool prompts once for the shared
username. System-path members (`@postgresql`, `@mariadb`, `@libvirt`,
`@flatpak`, `@docker`, `@containers`) need no username. `@grub` and `@swap` are
excluded — they are bootloader/swapfile-context-dependent and the tool cannot
infer them from a class name.

---

## Notes
- All tools assume the installer-provisioned layout (btrfs root, a snapper
  `root` config, and — for the Limine tools — Limine as the bootloader).
- The authoritative, up-to-date copy of these tools + this README lives in the
  installer itself; this folder is the deployable/on-box copy for later reuse.
INNER_EOF
chmod 0644 /root/tools/README.md
echo "/root/tools maintenance folder complete (void-xbps-snap backup, 3 limine-engine backups, re-shadow-xbps.sh, limine-sync.sh, re-provision-snapper.sh, void-subvol-tool.sh, README.md)"

# AI (Big Pickle) ADDITION — Beta-v2.6.7 [RESHADOW-BOOT]: make the xbps
# self-update shadow-clobber SELF-HEALING instead of a manual recovery. The
# shadow-repair line is added to the TOP of /etc/rc.local (the every-boot
# section, OUTSIDE the firstboot.log guard) so it runs on every boot via
# runit stage 2 (/etc/runit/2 executes /etc/rc.local unconditionally). If an
# `xbps` update replaced the /usr/bin/xbps-install symlink with a real ELF
# (that ELF will have been running the very transaction via .real, so the
# wrapper could not self-heal mid-flight), the next boot repairs the shadow
# BEFORE any later update can run without snapshots.
# Delegates to /root/tools/re-shadow-xbps.sh (idempotent, self-healing; the
# canonical backup copy feeds it), so there is exactly one shadow-repair
# implementation. rc.local is deliberately the home here (not a runit sv/):
# it already runs every boot through runit stage 2, is where this installer
# does its boot-time fixups, and avoids runit's one-shot restart semantics.

# fstrim cron from the legacy `fstrim-nvme` to `fstrim-discard`. The old name
# dated back to when the target disk was hardcoded to /dev/nvme0n1; since disk
# selection became interactive (nvme / mmcblk / sdX), `fstrim -A -q` trims any
# mounted discard-capable filesystem regardless of bus, so the name should not
# claim to be NVMe-only. No behavior change.
mkdir -p /etc/cron.weekly
cat > /etc/cron.weekly/fstrim-discard << 'INNER_EOF'
#!/bin/sh
export PATH="/usr/bin:/usr/sbin:/bin:/sbin"
if command -v fstrim >/dev/null 2>&1; then
    exec fstrim -A --quiet
else
    echo "ERROR: fstrim binary missing from the system path." >&2
    exit 1
fi
INNER_EOF
chmod +x /etc/cron.weekly/fstrim-discard

# AI (Big Pickle) ADDITION — Beta-v2.5.3 [SCRUB]: monthly btrfs integrity
# scrub — the physical-corruption half of the recovery story (Snapper guards
# against logical/accidental damage; scrub catches silent checksum failures
# and repairs them). One pass per btrfs filesystem (subvolume mounts all
# share the same major:minor, so the mount list is deduped on that instead
# of scrubbing one fs once per subvol mount), logged to
# /var/log/btrfs-scrub.log. Never forced: if a manual scrub is already
# running, this monthly pass fails fast and records why rather than racing
# it. cron.monthly is executed by cronie's stock /etc/crontab (draining
# missed runs on boot), same mechanism the weekly fstrim-discard entry above relies on.
mkdir -p /etc/cron.monthly
cat > /etc/cron.monthly/btrfs-scrub << 'INNER_EOF'
#!/bin/sh
# [SCRUB] Monthly btrfs integrity scrub, logged (appended) to
# /var/log/btrfs-scrub.log.
export PATH="/usr/bin:/usr/sbin:/bin:/sbin"
LOG="/var/log/btrfs-scrub.log"

if ! command -v btrfs >/dev/null 2>&1; then
    echo "ERROR: btrfs binary missing from the system path." >&2
    exit 1
fi

# Bail out cleanly when no btrfs filesystem is mounted (a cheap guard: this
# installer only ever produces btrfs roots, but nothing should be created
# on the unlikely non-btrfs box).
_fslist="$(
    awk '
        { for (i = 1; i <= NF; i++) if ($i == "-") { sep = i; break } }
        $(sep+1) == "btrfs" { print $3 " " $5 }
    ' /proc/self/mountinfo 2>/dev/null | sort -k1,1 -u
)"
[ -n "$_fslist" ] || exit 0

{
    echo "=== btrfs scrub run: $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
    printf '%s\n' "$_fslist" | while read -r _devno _mnt; do
        # Blocking (-B) with per-device stats (-d). Deliberately NO -f:
        # btrfs scrub refuses a second concurrent scrub on one filesystem,
        # so a manually-started run makes this pass fail fast (and the log
        # records the exit code) instead of racing it.
        btrfs scrub start -B -d "$_mnt" 2>&1
        _rc=$?
        echo "scrub $_mnt (dev $_devno): exit $_rc"
    done
} >> "$LOG" 2>&1

exit 0
INNER_EOF
chmod +x /etc/cron.monthly/btrfs-scrub

mkdir -p /etc/dracut.conf.d
cat > /etc/dracut.conf.d/90-system.conf << INNER_EOF
add_dracutmodules+=" btrfs resume snapshot-overlay udev-rules "
filesystems+=" btrfs "
install_items+=" /usr/bin/btrfs /usr/sbin/blkid "
INNER_EOF
# AI (Big Pickle) ADDITION — Beta-v2.5.5 [ENCRYPT]: when encryption is
# enabled, dracut must also pull in the `crypt` module (LUKS unlocking — it
# installs its own copy of cryptsetup + udev rules) so the initramfs can
# prompt for the passphrase and open void-root before mounting root.
# Appended to the shared 90-system.conf so the crypt knowledge is inherited
# by every initramfs the kernel-hook regen loop builds.
if [ "$ENCRYPT" = "yes" ]; then
    echo 'add_dracutmodules+=" crypt "' >> /etc/dracut.conf.d/90-system.conf
    # AI (Big Pickle) ADDITION — Beta-v2.6.9 [KEYMAP]: pull dracut's `i18n`
    # module and bake the captured keymap into the initramfs, so the EARLY-BOOT
    # passphrase prompt (before root/console is up) maps keys exactly like the
    # install console. Without this the pre-unlock prompt uses the kernel's
    # built-in US map even when the passphrase was typed under a different one.
    # (AI (Big Pickle) FIX — Beta-v2.9.67 [KEYMAP-CMDLINE]: this was written as
    # a BARE `rd.vconsole.keymap=<k>` line, but dracut SOURCES every file under
    # dracut.conf.d with bash — a dotted bare assignment is not valid shell, so
    # bash executed the line as a command and every dracut run logged
    # `rd.vconsole.keymap=us: command not found` (3x per install, once per
    # kernel image). Worse, the parameter was therefore NEVER baked into the
    # initramfs — the [KEYMAP] feature silently did nothing. The dracut-native
    # form is `kernel_cmdline="..."` (man dracut.conf: "only sets initrd
    # parameters"), which is shell-valid and actually lands the param.)
    echo 'add_dracutmodules+=" i18n "' >> /etc/dracut.conf.d/90-system.conf
    echo "kernel_cmdline=\"rd.vconsole.keymap=${KEYMAP_LIVE:-us}\"" >> /etc/dracut.conf.d/90-system.conf
fi

# AI (Big Pickle) ADDITION — Beta-v2.5.4 [YUBIKEY]: when YubiKey unlock is
# enabled, dracut must ship the keyscript + `ykchalresp` (and its libusb
# runtime) inside the initramfs, otherwise the boot unlock cannot run
# /usr/local/sbin/void-reveal-yubikey-key. Written as a dedicated `99void-`
# module (runs AFTER 90crypt's module-setup.sh, so its `/sbin/cryptroot-ask`
# override wins over 90crypt's) so the initramfs is self-contained. ykpers is
# a plain C + libusb tool, so `inst` + `inst_libdir_file` cover it — no
# heavyweight runtime.
# AI (Big Pickle) ADDITION — Beta-v2.5.4 [YUBIKEY]: the boot-unlock path
# REQUIRES a custom `/sbin/cryptroot-ask` override because upstream dracut
# (and dracut-ng) does NOT execute the Debian-style `keyscript=` crypttab
# option — it treats the third-field `luksfile` as a static keyfile (via
# `readkey`, a `cat`) and silently ignores `keyscript=` in the options field.
# So the stock cryptroot-ask would never run void-reveal-yubikey-key and
# would always prompt for the typed passphrase — a possession-only install
# (YK_FALLBACK=no, slot 0 removed) would be UNBOOTABLE. This module installs
# `cryptroot-ask.sh` (a faithful mirror of upstream that ADDS a `keyscript=`
# exec branch feeding the keyscript's stdout to `cryptsetup luksOpen`) over
# 90crypt's, so the YubiKey unlock actually runs at boot. When the keyscript
# fails (YubiKey absent/wrong) it falls through to the typed-passphrase
# prompt, preserving the YK_FALLBACK=yes behavior. Because this module's
# `check()` requires `ykchalresp`, it only activates when YubiKey unlock is
# enabled — a plain ENCRYPT-only install keeps upstream cryptroot-ask and is
# unaffected (no regression).
if [ "$YK_MODE" = "hmac-sha1" ]; then
    mkdir -p /usr/lib/dracut/modules.d/99void-yubikey
    cat > /usr/lib/dracut/modules.d/99void-yubikey/module-setup.sh << 'INNER_EOF'
#!/bin/bash
# shellcheck disable=SC2154  # $moddir is set by dracut before module install() is sourced

check() {
    require_binaries ykchalresp || return 1
    return 0
}

depends() {
    echo base
    return 0
}

install() {
    inst /usr/local/sbin/void-reveal-yubikey-key /usr/local/sbin/void-reveal-yubikey-key
    inst_binary ykchalresp /usr/bin/ykchalresp
    inst_libdir_file "libusb-*.so*" "libusb-*.so.*"
    inst_script "$moddir/cryptroot-ask.sh" /sbin/cryptroot-ask
}
INNER_EOF
    cat > /usr/lib/dracut/modules.d/99void-yubikey/cryptroot-ask.sh << 'INNER_EOF'
#!/bin/sh
# [YUBIKEY] dracut initqueue unlock handler for LUKS volumes, installed over
# 90crypt's /sbin/cryptroot-ask by the 99void-yubikey module. It is a mirror
# of upstream dracut's cryptroot-ask.sh (dracutdevs/dracut master) that ADDS
# a `keyscript=<path>` exec branch: when the target device's crypttab entry
# carries that Debian-style option, the keyscript is run and its stdout is
# piped to `cryptsetup luksOpen`. This is exactly what the plain upstream
# handler omits (it `cat`s the third-field luksfile as a static keyfile and
# ignores `keyscript=` in the options field), so without this override a
# YubiKey-crypttab-enabled volume would never unlock via the key's
# challenge-response — it would always prompt for the typed passphrase. When
# the keyscript outputs nothing/fails (YubiKey absent or wrong), we fall
# through to the typed-passphrase prompt, preserving the YK_FALLBACK=yes
# behavior (a fallback slot must exist for that prompt to succeed).
# shellcheck disable=SC2154  # moddir / luksdev / hookdir are dracut-injected globals
PATH=/usr/sbin:/usr/bin:/sbin:/bin
NEWROOT=${NEWROOT:-"/sysroot"}

# Don't ask if we already have root.
[ -f "$NEWROOT"/proc ] && exit 0

. /lib/dracut-lib.sh

[ -d /run/cryptsetup ] || mkdir -m 0700 /run/cryptsetup

# If device name is /dev/dm-X, convert to /dev/mapper/name.
if [ "${1##/dev/dm-}" != "$1" ]; then
    device="/dev/mapper/$(dmsetup info -c --noheadings -o name "$1")"
else
    device="$1"
fi

# Default luksname - luks-UUID.
luksname=$2

# is_keysource - ask for a passphrase even if an rd.luks.key argument is set.
is_keysource=${3:-0}

# Number of tries.
numtries=${4:-10}

# Resolve the target's crypttab entry (name, dev, luksfile, luksoptions).
if [ -f /etc/crypttab ] && getargbool 1 rd.luks.crypttab -d -n rd_NO_CRYPTTAB; then
    while read -r name dev luksfile luksoptions || [ -n "$name" ]; do
        # Skip blank lines and comments.
        if [ -z "$name" ] || [ "${name#\#}" != "$name" ]; then
            continue
        fi

        # PARTUUID used in crypttab.
        if [ "${dev%%=*}" = "PARTUUID" ]; then
            if [ "luks-${dev##PARTUUID=}" = "$luksname" ]; then
                luksname="$name"
                break
            fi
        # UUID used in crypttab.
        elif [ "${dev%%=*}" = "UUID" ]; then
            if [ "luks-${dev##UUID=}" = "$luksname" ]; then
                luksname="$name"
                break
            fi
        # ID used in crypttab.
        elif [ "${dev%%=*}" = "ID" ]; then
            if [ "luks-${dev##ID=}" = "$luksname" ]; then
                luksname="$name"
                break
            fi
        # Path used in crypttab.
        else
            cdev=$(readlink -f "$dev")
            mdev=$(readlink -f "$device")
            if [ "$cdev" = "$mdev" ]; then
                luksname="$name"
                break
            fi
        fi
    done < /etc/crypttab
    unset name dev
fi

# Check if the destination already exists (opened or already being asked).
[ -b /dev/mapper/"$luksname" ] && exit 0
asked_file=/tmp/cryptroot-asked-$luksname
[ -f "$asked_file" ] && exit 0

[ -d /sys/module/dm_crypt ] || modprobe dm_crypt

. /lib/dracut-crypt-lib.sh

info "luksOpen $device $luksname $luksfile $luksoptions"

OLD_IFS="$IFS"
IFS=,
# shellcheck disable=SC2086
set -- $luksoptions
IFS="$OLD_IFS"

cryptsetupopts=""
allowdiscards=""
keyscript=""

while [ $# -gt 0 ]; do
    case $1 in
        noauto)
            exit 0
            ;;
        swap)
            exit 0
            ;;
        tmp)
            exit 0
            ;;
        allow-discards)
            allowdiscards="--allow-discards"
            ;;
        header=*)
            cryptsetupopts="${cryptsetupopts} --${1}"
            ;;
        keyscript=*)
            # [YUBIKEY] Capture the keyscript path for the boot unlock.
            keyscript="${1#keyscript=}"
            ;;
    esac
    shift
done

# Parse for allow-discards.
if strstr "$(cryptsetup --help)" "allow-discards"; then
    if discarduuids=$(getargs "rd.luks.allow-discards"); then
        discarduuids=$(str_replace "$discarduuids" 'luks-' '')
        if strstr " $discarduuids " " ${luksdev##luks-}"; then
            allowdiscards="--allow-discards"
        fi
    elif getargbool 0 rd.luks.allow-discards; then
        allowdiscards="--allow-discards"
    fi
fi

if strstr "$(cryptsetup --help)" "allow-discards"; then
    cryptsetupopts="$cryptsetupopts $allowdiscards"
fi

unset allowdiscards

# Fallback to the passphrase prompt (see the keyscript branch below).
ask_passphrase=1

# [YUBIKEY] If the crypttab entry carries `keyscript=<path>`, run the
# keyscript and pipe its stdout to luksOpen. This is the boot-time YubiKey
# hmac-sha1 unlock: void-reveal-yubikey-key challenges the key with the
# persisted 40-hex CHALLENGE and prints the HMAC response (the LUKS key).
# Retry briefly so a YubiKey that udev hasn't recognized yet (hot-plug at
# boot, or a slow hub) has time to appear — mirroring upstream's bounded
# retry for missing keydevs. If the keyscript ultimately produces nothing /
# fails (key absent or wrong), we fall through to the passphrase prompt:
# with YK_FALLBACK=yes a typed-passphrase slot exists and success is
# possible; with YK_FALLBACK=no (possession-only) there is none by design.
if [ -n "$keyscript" ] && [ -x "$keyscript" ]; then
    _keyscript_tries=${YTries:-10}
    while [ "$_keyscript_tries" -gt 0 ]; do
        # shellcheck disable=SC2086  # deliberate word-splitting of $cryptsetupopts (dracut option string)
        if "$keyscript" | cryptsetup -d - $cryptsetupopts luksOpen "$device" "$luksname"; then
            ask_passphrase=0
            break
        fi
        _keyscript_tries=$((_keyscript_tries - 1))
        [ -b /dev/mapper/"$luksname" ] && break
        sleep 1
    done
    unset _keyscript_tries
elif [ -n "$luksfile" ] && [ "$luksfile" != "none" ] && [ -e "$luksfile" ]; then
    # shellcheck disable=SC2086
    if readkey "$luksfile" / "$device" \
        | cryptsetup -d - $cryptsetupopts luksOpen "$device" "$luksname"; then
        ask_passphrase=0
    fi
elif [ "$is_keysource" -ne 0 ]; then
    info "Asking for passphrase because $device is a keysource."
else
    while [ -n "$(getarg rd.luks.key)" ]; do
        if tmp=$(getkey /tmp/luks.keys "$device"); then
            keydev="${tmp%%:*}"
            keypath="${tmp#*:}"
        else
            if [ "$numtries" -eq 0 ]; then
                warn "No key found for $device.  Fallback to passphrase mode."
                break
            fi
            sleep 1
            info "No key found for $device.  Will try $numtries time(s) more later."
            initqueue --unique --onetime --settled \
                --name cryptroot-ask-"$luksname" \
                "$(command -v cryptroot-ask)" "$device" "$luksname" "$is_keysource" "$((numtries - 1))"
            exit 0
        fi
        unset tmp

        info "Using '$keypath' on '$keydev'"
        # shellcheck disable=SC2086
        readkey "$keypath" "$keydev" "$device" \
            | cryptsetup -d - $cryptsetupopts luksOpen "$device" "$luksname" \
            && ask_passphrase=0
        unset keypath keydev
        break
    done
fi

if [ $ask_passphrase -ne 0 ]; then
    luks_open="$(command -v cryptsetup) $cryptsetupopts luksOpen"
    _timeout=$(getargs "rd.luks.timeout")
    _timeout=${_timeout:-0}
    ask_for_password --ply-tries 5 \
        --ply-cmd "$luks_open -T1 $device $luksname" \
        --ply-prompt "Password ($device)" \
        --tty-tries 1 \
        --tty-cmd "$luks_open -T5 -t $_timeout $device $luksname"
    unset luks_open
    unset _timeout
fi

if [ "$is_keysource" -ne 0 ] && [ "${luksname##luks-}" != "$luksname" ]; then
    luks_close="$(command -v cryptsetup) close"
    {
        printf -- '[ -e /dev/mapper/%s ] && ' "$luksname"
        printf -- '%s "%s"\n' "$luks_close" "$luksname"
    } >> "$hookdir/cleanup/31-crypt-keysource.sh"
    unset luks_close
fi

unset device luksname luksfile

# Mark device as asked.
: >> "$asked_file"

need_shutdown
udevsettle

exit 0
INNER_EOF
    chmod 0755 /usr/lib/dracut/modules.d/99void-yubikey/cryptroot-ask.sh
    chmod 0755 /usr/lib/dracut/modules.d/99void-yubikey/module-setup.sh
    echo 'add_dracutmodules+=" void-yubikey "' >> /etc/dracut.conf.d/90-system.conf
fi

mkdir -p /usr/lib/dracut/modules.d/95snapshot-overlay
cat > /usr/lib/dracut/modules.d/95snapshot-overlay/module-setup.sh << 'INNER_EOF'
#!/bin/bash
# shellcheck disable=SC2154  # $moddir is set by dracut before module install() is sourced

check() {
    require_binaries btrfs || return 1
    return 0
}

depends() {
    echo base btrfs
    return 0
}

installkernel() {
    hostonly="" instmods overlay
}

install() {
    inst_hook pre-pivot 20 "$moddir/mount-snapshot-overlay.sh"
}
INNER_EOF

cat > /usr/lib/dracut/modules.d/95snapshot-overlay/mount-snapshot-overlay.sh << 'INNER_EOF'
#!/bin/sh
# Runs at the pre-pivot stage — strictly after dracut's own root-mount
# machinery has mounted the real root (read-only snapshot or normal @) at
# $NEWROOT. No `exit` calls anywhere in this script — pre-pivot hooks are
# commonly SOURCED into a shared shell, and `exit` inside a sourced script
# kills the whole hook-processing shell (surfaces as "dracut Warning:
# Signal caught!" on every boot, normal ones included — confirmed the hard
# way). Pure nested if/then conditionals instead, matching stock dracut's
# own overlayfs module convention.

command -v getarg > /dev/null || . /lib/dracut-lib.sh

if getargbool 0 rd.live.overlay.overlayfs; then
    if command -v btrfs > /dev/null 2>&1; then
        ro_state=$(btrfs property get "$NEWROOT" ro 2>/dev/null)
        if [ "$ro_state" = "ro=true" ]; then
            info "snapshot-overlay: read-only snapshot detected at $NEWROOT, building RAM overlay"
            mkdir -m 0755 /run/rootfsbase
            if mount --bind "$NEWROOT" /run/rootfsbase; then
                mkdir -m 0755 /run/overlayfs /run/ovlwork
                if ! mount -t overlay overlay \
                    -o lowerdir=/run/rootfsbase,upperdir=/run/overlayfs,workdir=/run/ovlwork \
                    "$NEWROOT"; then
                    warn "snapshot-overlay: overlay mount failed, booting read-only"
                    umount /run/rootfsbase
                fi
            else
                warn "snapshot-overlay: failed to bind-mount $NEWROOT, booting read-only"
            fi
        fi
    else
        warn "snapshot-overlay: btrfs binary not found in initramfs, skipping overlay"
    fi
fi
INNER_EOF
chmod 0755 /usr/lib/dracut/modules.d/95snapshot-overlay/module-setup.sh
chmod 0755 /usr/lib/dracut/modules.d/95snapshot-overlay/mount-snapshot-overlay.sh

# AI (Big Pickle) ADDITION — Beta-v2.9.43 [INNER-PARTSCAN-BOOT]: the inner-GPT
# partscan dracut module (MULTI-FS + ENCRYPT carve). Written ONLY when ENCRYPT
 # + carved REGION_PARTITIONED, and PLACED here (before the final
# `xbps-reconfigure -f $KERNEL_PKGS` below) so the very first boot already has
# it. When the opened LUKS2 mapper node appears, udev RUNs the helper the
# instant sysfs ATTR{dm/name} matches the mapper name (since Beta-v2.9.57;
# ENV{DM_NAME} never carries at add-uevent time), forcing the kernel to
# REGISTER the on-disk inner GPT before dracut's udev settle resolves
# root=UUID=<inner btrfs> — an unregistered inner GPT strands boot at the
# emergency shell (crash #009 residual). Beta-v2.9.45 [INNER-PARTSCAN-DMPROBE]: the helper's PRIMARY tool
# is partprobe (libparted dm-linear submaps — the ONLY tool that can BLKPG a
# device-mapper target); partx -a is fallback only. Beta-v2.9.56
# [INNER-PARTSCAN-KPARTX]: HARDWARE-PROVEN rewrite — kpartx -a is now PRIMARY
# (reads the on-disk GPT off the opened dm-crypt mapper and creates real
# dm-linear submaps void-root1/void-root2... via dmsetup; the partprobe-first
# order failed on the first real ENCRYPT+regions boot where BLKPG produced no
# child devices and dracut looped "Scanning for all btrfs devices" to the
# emergency shell, while `kpartx -av` registered both inner partitions
# instantly). partprobe then partx -a remain as fallbacks. Do NOT "simplify"
# back to partx-primary or partprobe-primary alone (both can fail against a dm
# mapper: "partx: ... error adding partitions"), do NOT rework to a
# settled/initqueue hook (dracut resolves root through the same settle — too
# late), do NOT udevadm-settle inside the RUN script (deadlocks udevd), keep
# inst_binary kpartx + partprobe, and keep the __CRYPT_NAME__ token bake
# (sed-special &\/ escaped — never a raw typed name).
if [ "$ENCRYPT" = "yes" ] && [ -n "${REGION_PARTITIONED:-}" ]; then
    mkdir -p /usr/lib/dracut/modules.d/98void-inner-partscan

    cat > /usr/lib/dracut/modules.d/98void-inner-partscan/module-setup.sh << 'INNER_EOF'
#!/bin/bash
# AI (Big Pickle) ADDITION — Beta-v2.9.43 [INNER-PARTSCAN-BOOT]: module-setup
# for the inner-GPT partscan at boot (MULTI-FS + ENCRYPT carve).
# Beta-v2.9.45 [INNER-PARTSCAN-DMPROBE]: MUST keep `inst_binary partprobe` —
# the installer installs parted INTO the target whenever this module ships, so
# this inst can never abort the dracut run.
# Beta-v2.9.56 [INNER-PARTSCAN-KPARTX]: kpartx is now the PRIMARY registration
# tool — it reads the on-disk GPT off the OPENED LUKS2 mapper and creates real
# dm-linear submaps (void-root1/void-root2...) via dmsetup. The old
# partprobe-first order was proven dead on the first real ENCRYPT+regions boot
# (luksopen worked, inner GPT readable, yet dracut looped "Scanning for all
# btrfs devices" until root=UUID dead; `kpartx -av <mapper>` fixed it live and
# instantly). module-setup therefore REQUIRES kpartx and inst's it FIRST, then
# partprobe + partx as fallbacks (kept for environments where partprobe's
# BLKPG does register). The installer installs kpartx AND parted INTO the
# target whenever this module ships, so these inst's never abort the run.
# shellcheck disable=SC2154  # $moddir is set by dracut before install() runs

check() {
    require_binaries kpartx || return 1
    require_binaries partprobe || return 1
    return 0
}

depends() {
    # Numeric 98 > 90crypt: the container must already be open for the
    # mapper's sysfs dm/name to exist when our rule fires, so pull crypt
    # explicitly alongside udev-rules.
    echo crypt udev-rules
    return 0
}

install() {
    inst_binary kpartx
    inst_binary partprobe
    inst_binary partx
    inst_script "$moddir/void-inner-partscan.sh" /usr/bin/void-inner-partscan.sh
    inst_rules "$moddir/10-void-inner-partscan.rules"
}
INNER_EOF

    cat > /usr/lib/dracut/modules.d/98void-inner-partscan/void-inner-partscan.sh << 'INNER_EOF'
#!/bin/sh
# AI (Big Pickle) ADDITION — Beta-v2.9.43 [INNER-PARTSCAN-BOOT] / Beta-v2.9.45
# [INNER-PARTSCAN-DMPROBE] / Beta-v2.9.56 [INNER-PARTSCAN-KPARTX]: udev RUN
# helper for the 98void-inner-partscan module. Fires the instant the opened
# LUKS2 mapper node appears, forcing the kernel to REGISTER the on-disk inner
# GPT BEFORE dracut resolves root=UUID=<inner btrfs> through the udev settle.
#
# Beta-v2.9.56: kpartx -a is PRIMARY — it reads the on-disk GPT off the opened
# dm-crypt mapper and creates real dm-linear submaps (void-root1/void-root2...)
# via dmsetup, which is the only mechanism that provably registers the inner
# partitions (proof: first real ENCRYPT+regions boot luksopened fine and the
# mapper showed PTTYPE=gpt, yet partprobe's BLKPG produced no child devices and
# the btrfs-device scan looped to the emergency shell; `kpartx -av` on that
# live box created both submaps instantly). partprobe (BLKPG/libparted) remains
# the first FALLBACK, partx -a the last (both can fail against a dm mapper:
# "partx: /dev/mapper/<name>: error adding partitions 1-N"). Best-effort by
# design: exit 0 even on failure — udev must never wedge, and the post-open
# partscan covers the non-critical cases. NO `udevadm settle` here: settling
# inside a udev RUN deadlocks udevd.
#
# shellcheck disable=SC2154  # DEVNAME is injected by udev at run time
_dev="${1:-${DEVNAME:-/dev/mapper/__CRYPT_NAME__}}"

[ -b "$_dev" ] || exit 0

if command -v kpartx > /dev/null 2>&1; then
    kpartx -a "$_dev" 2> /dev/null || partprobe "$_dev" 2> /dev/null || partx -a "$_dev" 2> /dev/null || true
elif command -v partprobe > /dev/null 2>&1; then
    partprobe "$_dev" 2> /dev/null || partx -a "$_dev" 2> /dev/null || true
else
    partx -a "$_dev" 2> /dev/null || true
fi
unset _dev
exit 0
INNER_EOF

    cat > /usr/lib/dracut/modules.d/98void-inner-partscan/10-void-inner-partscan.rules << 'INNER_EOF'
# AI (Big Pickle) ADDITION — Beta-v2.9.43 [INNER-PARTSCAN-BOOT], fixed
# Beta-v2.9.57 [INNER-PARTSCAN-UDEV-ATTR]: RUN the partscan helper the instant
# the opened LUKS2 mapper node appears (MULTI-FS + ENCRYPT carve), so the inner
# GPT is registered BEFORE dracut's udev settle resolves root=UUID=<inner btrfs>.
# Do NOT match on ENV{DM_NAME}: the kernel's dm add-uevent carries NO DM_NAME
# (libdevmapper writes it into the udev db later, AFTER udev rules evaluate), so
# an ENV{DM_NAME} predicate never matched and the RUN never executed — both the
# 2.9.45 partprobe and 2.9.56 kpartx "fixes" silently did nothing at boot. The
# sysfs attribute ATTR{dm/name} IS present at add-time (live-proven: the RUN
# helper then creates void-root1/void-root2 via kpartx -a). __CRYPT_NAME__ is a
# placeholder baked at install time (sed-special &\/ escaped — never a raw
# typed name).
ACTION=="add", SUBSYSTEM=="block", KERNEL=="dm-*", ATTR{dm/name}=="__CRYPT_NAME__", RUN+="/usr/bin/void-inner-partscan.sh"
INNER_EOF

    chmod 0755 /usr/lib/dracut/modules.d/98void-inner-partscan/module-setup.sh
    chmod 0755 /usr/lib/dracut/modules.d/98void-inner-partscan/void-inner-partscan.sh

    # AI (Big Pickle) FIX — Beta-v2.9.64 [PARTSCAN-HOST-COPY]: dracut's udev-rule
    # scan (_inst_rule_programs in dracut-functions.sh) resolves each RUN= program
    # against the BUILD HOST root, never the module dir — the partscan udev rule
    # references /usr/bin/void-inner-partscan.sh, which at dracut time exists ONLY
    # as $moddir/void-inner-partscan.sh, so EVERY initramfs build logged the
    # cosmetic "Skipping program /usr/bin/void-inner-partscan.sh using in udev rule
    # 10-void-inner-partscan.rules as it cannot be found" (the initrd was still
    # correct — module-setup's inst_script embeds it). Materialize the helper at the
    # target's /usr/bin/: the scan then resolves it and embeds it via inst_binary,
    # the warning disappears, and a directly-inspectable copy also lives on the
    # installed system for boot troubleshooting. Mirrors install_items+=" .../btrfs"
    # precedent in 90-system.conf. The $moddir copy stays; inst_script remains the
    # image's source of truth if the /usr/bin copy is ever removed.
    cp -f /usr/lib/dracut/modules.d/98void-inner-partscan/void-inner-partscan.sh /usr/bin/void-inner-partscan.sh
    chmod 0755 /usr/bin/void-inner-partscan.sh

    # Bake the mapper name in (rules match + helper fallback): never a raw
    # typed name — escape sed replacement specials (& / \) before substitution.
    _cn_esc=$(printf '%s' "$CRYPT_NAME" | sed 's/[&/\\]/\\&/g')
    sed -i "s/__CRYPT_NAME__/$_cn_esc/g" \
        /usr/lib/dracut/modules.d/98void-inner-partscan/10-void-inner-partscan.rules
    unset _cn_esc

    echo 'add_dracutmodules+=" void-inner-partscan "' >> /etc/dracut.conf.d/90-system.conf
fi

if [ "$DISPLAY_MANAGER" = "sddm" ]; then
cat > /etc/sv/sddm/conf << 'INNER_EOF'
for i in $(seq 1 10); do
    if [ -d /run/initramfs ] || [ -f /var/log/firstboot.log ]; then
        break
    fi
    sleep 1
done
INNER_EOF
fi

# AI (Big Pickle) ADDITION — Beta-v2.4.0 [COSMIC]; AI (Big Pickle) FIX —
# Beta-v2.9.10 [COSMIC-GREETER-DM]: when cosmic-greeter was chosen as the
# display manager, rc.local links /etc/sv/${DM_SERVICE_NAME}, so the runit
# service dir must exist or first boot leaves a dangling symlink.
# Beta-v2.9.10 replaces the old best-effort direct `exec /usr/bin/cosmic-greeter`
# service (a real Beta-v2.9.9 COSMIC install that chose this DM booted to a
# bare terminal login with NO login screen: the greeter is a greetd frontend
# that must run inside cosmic-comp, and without greetd/cosmic-comp/DBus it
# aborts instantly). A known-good, maintainer-matching runit stack is baked
# here so the install never depends on which community-repo revision ships:
#   - /etc/sv/cosmic-greeter/run        -> greetd -c /etc/greetd/cosmic-greeter.toml
#     (the config launches `cosmic-comp cosmic-greeter` under the
#     cosmic-greeter user; logic mirrors the repo maintainer's own run script:
#     dbus -> cosmic-greeter-daemon -> elogind checks, then execute greetd)
#   - /etc/sv/cosmic-greeter-daemon/run -> cosmic-greeter-daemon, owning
#     /run/cosmic-greeter for cosmic-greeter. AI (Big Pickle) FIX —
#     Beta-v2.9.12 [COSMIC-GREETER-USER]: the account is EXACTLY `cosmic-greeter`
#     (never `_cosmicgreeter`); the binary picks greeter-vs-locker from the
#     current username and anything other than `cosmic-greeter` silently locks
#     the screen instead of showing the DM (verified live on <host> 2026-09-06).
#   - /etc/greetd/cosmic-greeter.toml   -> deterministic greetd config
#   - log/run (svlogd) under BOTH services. AI (Big Pickle) FIX — Beta-v2.9.11
#     [COSMIC-GREETER-LOG]: the log/ dirs were created but had no run script,
#     so runsv spammed "fatal: unable to start log/./run" and no greeter output
#     survived a reboot — the living-validation run (2026-09-05) showed the
#     greetd stack launches but renders grey with no UI, and the missing
#     logging was hiding exactly the evidence needed to debug that. Each
#     service now writes a standard Void svlogd log/run (root-owned syslog
#     dir; both services exec as root).
# The packaged services shipped by older cosmic-greeter revisions (1.2.0-era)
# predate the daemon/greetd hosting and would otherwise leave a broken link.
if [ "$DISPLAY_MANAGER" = "cosmic-greeter" ]; then
    # greetd config: launches the greeter inside the COSMIC compositor as the
    # cosmic-greeter user on VT 1 (Beta-v2.9.12 [COSMIC-GREETER-USER]: the match
    # name must be exactly this — matching the packaged cosmic-greeter.toml).
    # AI (Big Pickle) FIX — Beta-v2.9.14 [COSMIC-GREETER-SESSION-BUS]: the
    # toml's command is NOT a bare `cosmic-comp cosmic-greeter` but the
    # /etc/greetd/cosmic-greeter.start wrapper below. Verified live on `<host>`
    # 2026-09-06: with the account fixed, a bare greetd spawn still rendered
    # grey + cursor — cosmic-greeter is built to run *inside* a COSMIC session
    # that provides DBUS_SESSION_BUS_ADDRESS, and with no session bus
    # cosmic-comp cannot init its own session D-Bus or update the activation
    # environment, so the iced login panel never maps as a layer. The wrapper
    # delegates the session bus to dbus-run-session (matching the proven-good
    # as-built /etc/greetd/cosmic-greeter.start on <host>) and keeps the whole
    # compositor+greeter tree a single direct child of greetd.
    mkdir -p /etc/greetd
    cat > /etc/greetd/cosmic-greeter.start << 'INNER_EOF'
#!/bin/sh
# v5 [COSMIC-GREETER-SESSION-BUS]: run the whole compositor+greeter tree
# inside a session D-Bus. cosmic-greeter is built to run "inside cosmic-comp"
# (i.e. under a COSMIC session that provides DBUS_SESSION_BUS_ADDRESS); a bare
# greetd spawn had no session bus, so cosmic_comp could not init its session
# DBus nor update the activation environment, and the iced login panel never
# mapped as a layer (grey + cursor only). The session bus is now delegated to
# dbus-run-session, which also keeps the daemon supervisable (greetd execs a
# single direct child).
exec dbus-run-session -- cosmic-comp cosmic-greeter >> /var/log/cosmic-greeter-session.log 2>&1
INNER_EOF
    chmod 0755 /etc/greetd/cosmic-greeter.start
    # The wrapper appends to a fixed log path AS the cosmic-greeter user
    # (greetd drop-privileges before exec'ing default_session, and /var/log is
    # root-only), so pre-create the file owned by the greeter or the redirect
    # fails before the compositor ever starts. Perms match the live <host> file
    # (cosmic-greeter:cosmic-greeter 0644, from the as-built capture).
    install -o cosmic-greeter -g cosmic-greeter -m 0644 /dev/null /var/log/cosmic-greeter-session.log
    cat > /etc/greetd/cosmic-greeter.toml << 'INNER_EOF'
[terminal]
vt = "1"

[general]
service = "cosmic-greeter"

[default_session]
command = "/etc/greetd/cosmic-greeter.start"
user = "cosmic-greeter"
INNER_EOF
    chmod 0644 /etc/greetd/cosmic-greeter.toml
    mkdir -p /etc/sv/cosmic-greeter/log
    cat > /etc/sv/cosmic-greeter/run << 'INNER_EOF'
#!/bin/sh
exec 2>&1
sv check dbus >/dev/null || exit 1
sv check cosmic-greeter-daemon >/dev/null || exit 1
# pam_elogind.so (cosmic-greeter's PAM file) needs a running logind to
# register the session; without this greetd starts but logins fail.
# Beta-v2.9.70 [ELOGIND-NO-STRAY-KILL]: the old "stray elogind PID sweep"
# (kill any pgrep'd elogind/elogind-daemon whose pid != supervise/pid) is
# REMOVED — proven on <host> that it kills the LIVE daemon. Void's elogind
# runs as a single daemonized `elogind-daemon` reparented to PID 1
# (pgrep -x 'elogind' matched NOTHING; pgrep -x 'elogind-daemon' returned
# exactly the serving daemon, ppid 1, argv0 elogind-daemon), so
# supervise/pid — the runsv child that already exited — never equals it,
# and the sweep killed the serving logind: seat/session/run-user vanished
# -> live desktop hang. elogind is single-instance by design (a duplicate
# cannot bind org.freedesktop.login1), so no killable stray exists; runit
# restarts a dead one itself, and `sv check elogind` below is the single
# authoritative gate.
sv check elogind >/dev/null || exit 1
exec greetd -c /etc/greetd/cosmic-greeter.toml
INNER_EOF
    chmod 0755 /etc/sv/cosmic-greeter/run
    install -d -m0750 -o root -g root /var/log/cosmic-greeter
    cat > /etc/sv/cosmic-greeter/log/run << 'INNER_EOF'
#!/bin/sh
exec svlogd -tt /var/log/cosmic-greeter
INNER_EOF
    chmod 0755 /etc/sv/cosmic-greeter/log/run
    mkdir -p /etc/sv/cosmic-greeter-daemon/log
    cat > /etc/sv/cosmic-greeter-daemon/run << 'INNER_EOF'
#!/bin/sh
exec 2>&1
sv check dbus >/dev/null || exit 1
install -d -m0755 -o cosmic-greeter -g cosmic-greeter /run/cosmic-greeter
exec cosmic-greeter-daemon
INNER_EOF
    chmod 0755 /etc/sv/cosmic-greeter-daemon/run
    install -d -m0750 -o root -g root /var/log/cosmic-greeter-daemon
    cat > /etc/sv/cosmic-greeter-daemon/log/run << 'INNER_EOF'
#!/bin/sh
exec svlogd -tt /var/log/cosmic-greeter-daemon
INNER_EOF
    chmod 0755 /etc/sv/cosmic-greeter-daemon/log/run
    echo "WARNING: cosmic-greeter was chosen as the display manager. Selecting it is your" >&2
    echo "         explicit at-own-risk choice of a third-party-repo greeter; rc.local links" >&2
    echo "         both the greetd-hosted cosmic-greeter and cosmic-greeter-daemon services." >&2
fi

# AI (Big Pickle) ADDITION — Beta-v2.9.74 [USB-AUTOMOUNT]: a supervised udisks2
# service. Void's udisks2 package ships only a D-Bus activation unit, so on a
# runit box udisksd was never started reliably (removable media only mounted
# via an explicit cosmic-files click). udiskie (installed by [COSMIC] DE
# branch) plus this service gives plug-and-mount.
mkdir -p /etc/sv/udisksd/log /var/log/udisksd
cat > /etc/sv/udisksd/run << 'INNER_EOF'
#!/bin/sh
exec 2>&1
exec /usr/libexec/udisks2/udisksd
INNER_EOF
chmod 0755 /etc/sv/udisksd/run
cat > /etc/sv/udisksd/log/run << 'INNER_EOF'
#!/bin/sh
exec svlogd -tt /var/log/udisksd
INNER_EOF
chmod 0755 /etc/sv/udisksd/log/run

cat > /etc/rc.local << 'INNER_EOF'
#!/bin/sh
# shellcheck disable=SC2050  # __TOKEN__ placeholders (__BOOTLOADER__ ...) are sed-substituted to real values after generation
if command -v vkpurge >/dev/null 2>&1; then
    echo "==> Runtime Maintenance: Sweeping unreferenced kernel artifacts..."
    vkpurge rm all >/dev/null 2>&1
fi

if ! grep -q 'rd.live.overlay.overlayfs=1' /proc/cmdline 2>/dev/null; then
    # AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS]: when the home region
    # is carved onto its own partition, ~/.cache lives on that partition and
    # MUST NOT get a @usercache mount on top (it would shadow the region
    # data). __REGION_PARTITIONED__ is baked at generation time (space-joined
    # carve list); the case match confirms the home region was NOT carved.
    case " __REGION_PARTITIONED__ " in
        *" home "*) : ;;
        *) mountpoint -q "/home/__TARGET_USER__/.cache" || mount "/home/__TARGET_USER__/.cache" 2>/dev/null || true ;;
    esac
fi

# [RESHADOW-BOOT] Self-heal the xbps-install shadow on every boot (OUTSIDE the
# firstboot guard below). If an `xbps` self-update replaced the wrapper symlink
# with a real ELF, restore it through void-xbps-snap before any later update
# can run unsnapshotted. Idempotent; logs to /var/log/void-reshadow.log.
if [ -x /root/tools/re-shadow-xbps.sh ]; then
    { echo "=== void-reshadow: $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
      /root/tools/re-shadow-xbps.sh || echo "WARNING: re-shadow failed."
    } >> /var/log/void-reshadow.log 2>&1
fi

# [ELOGIND-RUN-SELFHEAL] — Void's elogind daemonizes itself while the stock
# runit run script `exec`s it, so runsv respawns it ~1x/sec and floods the
# kernel log with "elogind is already running". /root/tools/elogind.run.fixed
# is a run script that waits on the live daemon instead of respawning. The
# elogind package OWNS /etc/sv/elogind/run, so an upgrade reverts the fix;
# restore it on every boot (same pattern as re-shadow-xbps.sh). Idempotent,
# never signals the live daemon. Logs to /var/log/void-elogind-selfheal.log.
if [ "__SESSION_STACK__" = "elogind" ] && [ -x /root/tools/re-fix-elogind-run.sh ]; then
    { echo "=== void-elogind-selfheal: $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
      /root/tools/re-fix-elogind-run.sh || echo "WARNING: elogind run self-heal failed."
    } >> /var/log/void-elogind-selfheal.log 2>&1
fi

if [ ! -f /var/log/firstboot.log ]; then
    mkdir -p /etc/runit/runsvdir/default
    ln -sfn /etc/sv/dbus /etc/runit/runsvdir/default/dbus
    ln -sfn /etc/sv/nftables /etc/runit/runsvdir/default/nftables
    # AI (Big Pickle) ADDITION — Beta-v2.9.23 [SSH-SERVER]: link the OpenSSH
    # server on first boot when enabled (baked placeholder, same class as
    # __PROFILE_*__/__DISPLAY_MANAGER__ — never a live $VAR in this single-
    # quoted rc.local heredoc). The openssh package was already installed in
    # the chroot; this is the runsvdir link invariant #3 requires. Kept EARLY
    # (before the DM link) so a headless/SSH-first install gets remote access
    # as soon as the service set links.
    [ "__INSTALL_SSH_SERVER__" = "true" ] && ln -sfn /etc/sv/sshd /etc/runit/runsvdir/default/sshd
    [ "__DISPLAY_MANAGER__" != "none" ] && ln -sfn /etc/sv/__DISPLAY_MANAGER__ /etc/runit/runsvdir/default/__DISPLAY_MANAGER__
    # AI (Big Pickle) FIX — Beta-v2.9.10 [COSMIC-GREETER-DM]: the cosmic-greeter
    # DM is a greetd-hosted stack, so its daemon service is linked alongside
    # the main service (see the baked /etc/sv/cosmic-greeter{,-daemon} above),
    # and the greeter's own VT (1, per /etc/greetd/cosmic-greeter.toml) is
    # freed of the base-system agetty — per greetd's README.voidlinux
    # ("disable the agetty service for the tty set in config.toml"). Other TTYs
    # stay available for console login if the greeter ever fails.
    [ "__DISPLAY_MANAGER__" = "cosmic-greeter" ] && \
        ln -sfn /etc/sv/cosmic-greeter-daemon /etc/runit/runsvdir/default/cosmic-greeter-daemon
    [ "__DISPLAY_MANAGER__" = "cosmic-greeter" ] && \
        rm -f /etc/runit/runsvdir/default/agetty-tty1
    ln -sfn /etc/sv/NetworkManager /etc/runit/runsvdir/default/NetworkManager
    ln -sfn /etc/sv/chronyd /etc/runit/runsvdir/default/chronyd
    ln -sfn /etc/sv/cronie /etc/runit/runsvdir/default/cronie
    ln -sfn /etc/sv/snapperd /etc/runit/runsvdir/default/snapperd
    [ "__BOOTLOADER__" = "grub" ] && ln -sfn /etc/sv/grub-btrfs /etc/runit/runsvdir/default/grub-btrfs
    if [ "__INSTALL_VIRT__" = "true" ]; then
        ln -sfn /etc/sv/libvirtd /etc/runit/runsvdir/default/libvirtd
        ln -sfn /etc/sv/virtlogd /etc/runit/runsvdir/default/virtlogd
    fi
    [ "__INSTALL_DOCKER__" = "true" ] && ln -sfn /etc/sv/docker /etc/runit/runsvdir/default/docker
    # AI (Big Pickle) FIX — Beta-v2.9.46 [VBOX-SV-GUARD]: virtualbox-ose
    # 7.2.16 dropped /etc/sv/vboxdrv (only vboxwebsrv + virtvboxd remain), so
    # an unconditional link left a permanent runsvdir FAIL entry. Guard on the
    # service directory actually shipping.
    [ "__INSTALL_VIRTUALBOX__" = "true" ] && [ -d /etc/sv/vboxdrv ] && \
        ln -sfn /etc/sv/vboxdrv /etc/runit/runsvdir/default/vboxdrv
    # AI (Big Pickle) ADDITION — Beta-v2.9.17 [DEVICE-PROFILE] + Beta-v2.9.19d
    # [DEVICE-PROFILE-RCL]: these links are gated on __PROFILE_*__ placeholders
    # (sed-substituted to the resolved booleans downstream) so the laptop
    # profile actually links tlp + bluetoothd and preload stays absent — the
    # first attempt used plain Chroot-var $PROFILE_* (never exported), which
    # rendered empty and silently skipped the links.
    [ "__PROFILE_BT__" = "true" ] && ln -sfn /etc/sv/bluetoothd /etc/runit/runsvdir/default/bluetoothd
    [ "__PROFILE_TLP__" = "true" ] && ln -sfn /etc/sv/tlp /etc/runit/runsvdir/default/tlp
    # AI (Big Pickle) ADDITION — Beta-v2.9.90 [COSMIC-PPD]: COSMIC builds
    # link power-profiles-daemon (its runit service) so the net.hadess
    # PowerProfiles D-Bus backend exists at first boot — the same
    # sed-substituted placeholder trick as the PROFILE_* links above.
    [ "__POWER_PPD__" = "true" ] && ln -sfn /etc/sv/power-profiles-daemon /etc/runit/runsvdir/default/power-profiles-daemon
    [ "__PROFILE_PRELOAD__" = "true" ] && ln -sfn /etc/sv/preload /etc/runit/runsvdir/default/preload
    if [ "__SESSION_STACK__" = "turnstile" ]; then
        ln -sfn /etc/sv/turnstiled /etc/runit/runsvdir/default/turnstiled
        ln -sfn /etc/sv/seatd /etc/runit/runsvdir/default/seatd
        ln -sfn /etc/sv/acpid /etc/runit/runsvdir/default/acpid
    fi
    # AI (Big Pickle) CHANGE — Beta-v2.5.0 [LIGHTDM-HW]: enable the mklive
    # known-good service set instead of leaving these to D-Bus activation.
    # On Void, accountsservice (org.freedesktop.Accounts) ships with NO
    # runit service — only a D-Bus activation file — and both the Slick and
    # GTK greeters hard-depend on it for the user list; on first boot the
    # on-demand activation races lightdm's own start and times out (the
    # "black screen / hang / 25s delay" failure in void-packages#59538, and
    # the specific hung-Slick-greeter seen during physical-hardware
    # installs). Running accounts-daemon as a supervised service removes the
    # race. elogind and polkitd are linked too (per the Void handbook — D-Bus
    # activation "can lead to issues" — and matching what Void's own mklive
    # images do: dbus elogind lightdm NetworkManager polkitd); elogind only
    # under SESSION_STACK=elogind, since the turnstile stack (above)
    # deliberately omits it. accounts-daemon is created in the LightDM
    # install branch (see [LIGHTDM-HW] there) and, since Beta-v2.9.10
    # [COSMIC-GREETER-DM], also in the cosmic-greeter branch (the greeter
    # lists users through org.freedesktop.Accounts); when it's absent the
    # guard below refuses to create a dangling link.
    [ "__DISPLAY_MANAGER__" = "lightdm" ] || [ "__DISPLAY_MANAGER__" = "cosmic-greeter" ] && \
        [ -d /etc/sv/accounts-daemon ] && \
        ln -sfn /etc/sv/accounts-daemon /etc/runit/runsvdir/default/accounts-daemon
    [ "__SESSION_STACK__" = "elogind" ] && \
        ln -sfn /etc/sv/elogind /etc/runit/runsvdir/default/elogind
    ln -sfn /etc/sv/polkitd /etc/runit/runsvdir/default/polkitd
    # AI (Big Pickle) ADDITION — Beta-v2.9.74 [USB-AUTOMOUNT]: Void's udisks2
    # package ships only the D-Bus activation unit (no /etc/sv entry), so on a
    # runit box nothing was reliably supervising udisksd. The installer now
    # writes /etc/sv/udisksd (below) and links it like any other base service.
    ln -sfn /etc/sv/udisksd /etc/runit/runsvdir/default/udisksd
    # AI (Big Pickle) ADDITION — Beta-v2.4.0 [SWAP]: enable the zramen (zram) runit
    # service on first boot when the chosen backend uses zram (zram or both).
    [ "__SWAP_BACKEND__" = "zram" ] || [ "__SWAP_BACKEND__" = "both" ] && \
        ln -sfn /etc/sv/zramen /etc/runit/runsvdir/default/zramen
    for i in $(seq 1 15); do
        if [ -S /run/dbus/system_bus_socket ]; then
            break
        fi
        sleep 1
    done

    # AI (Big Pickle) ADDITION — Beta-v2.5.7 [RCL-VIRT-WAIT]: only wait for
    # libvirtd's socket (and tear down libvirt's default NAT bridge) when
    # virtualization was actually chosen at install time. The libvirt-socket
    # wait below used to run unconditionally; on a non-virt install
    # /run/libvirt/libvirt-sock never appears, so every first boot burned a
    # full 15 seconds sleeping through this loop before rc.local moved on.
    # AI (Big Pickle) CHANGE — Beta-v2.9.86 [BR0-SKIP]: the teardown now also
    # requires the br0 NM profile to actually EXIST. The file lands on disk at
    # install time, so this is a pure disk-state check with no NM-timing
    # dependency; on a machine with NO wired NIC the br0 pair was skipped and
    # virbr0 must STAY enabled — it is the VM-networking fallback, so a virt
    # install can never land with zero networking (the old unconditional kill
    # did exactly that on a Wi-Fi-only topology). A resumed run reaches the
    # same decision: the profile presence is decided in Stage-2 and survives.
    if [ "__INSTALL_VIRT__" = "true" ] && [ -f /etc/NetworkManager/system-connections/br0.nmconnection ]; then
        for i in $(seq 1 15); do
            if [ -S /run/libvirt/libvirt-sock ]; then
                break
            fi
            sleep 1
        done
        if command -v virsh >/dev/null 2>&1; then
            virsh net-destroy default >/dev/null 2>&1 || true
            virsh net-autostart default --disable >/dev/null 2>&1 || true
        fi
    fi

    if command -v flatpak >/dev/null 2>&1; then
        # AI (Big Pickle) CHANGE — Beta-v2.5.2 [FLATHUB-RCL]: this block used
        # to run `flatpak remote-add` synchronously at first boot. That is a
        # BLOCKING network fetch (flathub.flatpakrepo + summary.idx) and
        # rc.local runs in runit stage 2 BEFORE NetworkManager is up, so when
        # Flatpak was selected the boot hung on a "Flathub idx / Failed to
        # fetch summary" error. The remote is now added inside the chroot at
        # install time (see [FLATHUB-CHROOT]) where the network is already up;
        # here we only (a) re-guard the add as an idempotent no-op fallback.
        # Same [FLATHUB-URL-FIX] (Beta-v2.9.49): .flatpakrepo URL carries the
        # repo base + signing key; the bare website URL imports no key.
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
        flatpak remote-modify --enable flathub 2>/dev/null || true
        # AI (Big Pickle) CHANGE — Beta-v2.9.34 [FLATPAK-NM-DISPATCH]: the
        # queued Flatpak app install (Brave etc.) was moved from the old
        # background subshell to a NetworkManager dispatcher script
        # (/etc/NetworkManager/dispatcher.d/99-flatpak-firstboot) written at
        # install time. The dispatcher fires on the first up/vpn-up event when
        # the interface has a default route — guaranteed DNS — and stamps
        # /var/log/flatpak-firstboot.done only when EVERY queued app succeeds
        # ([FLATPAK-NM-DISPATCH-STAMP], Beta-v2.9.46), so a partial failure
        # leaves the queue live for the next up/vpn-up. Nothing to do here.
    fi
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database -q
    fi
    mkdir -p /var/log
    touch /var/log/firstboot.log
fi
INNER_EOF

# AI (Claude, Sonnet 5, Medium) FIX: __BOOTLOADER__/__INSTALL_VIRT__/
# __INSTALL_DOCKER__/__INSTALL_VIRTUALBOX__/__DISPLAY_MANAGER__ are new placeholders alongside
# __TARGET_USER__ — a real, previously-undiscovered bug found while adding
# the DISPLAY_MANAGER toggle: the rc.local heredoc above is single-quoted
# (deliberately, so ITS OWN embedded $(...) / ${...} shell syntax isn't
# expanded at generation time — same reason __TARGET_USER__ already needed
# this substitution step), which means $BOOTLOADER/$INSTALL_VIRT/
# $INSTALL_DOCKER as previously written were being evaluated at REAL BOOT
# TIME against a shell environment that never had them set (they only
# ever existed as chroot-phase install variables, never exported or
# persisted anywhere) — always empty, meaning the grub-btrfs, libvirtd,
# virtlogd, and docker runit service links could never actually fire via
# this code path regardless of what was chosen at install time. Fixed by
# baking the real values in at generation time, the same way
# __TARGET_USER__ already was. __SESSION_STACK__ (added by AI (Big Pickle)
# — Beta-v2.4.0 [item 9]) follows here too so the first-boot block that (only
# when SESSION_STACK=turnstile) links turnstiled/seatd/acpid sees the
# real choice rather than the always-empty install variable.
sed -i \
    -e "s/__TARGET_USER__/${TARGET_USER}/g" \
    -e "s/__BOOTLOADER__/${BOOTLOADER}/g" \
    -e "s/__INSTALL_VIRT__/${INSTALL_VIRT}/g" \
    -e "s/__INSTALL_DOCKER__/${INSTALL_DOCKER}/g" \
    -e "s/__INSTALL_VIRTUALBOX__/${INSTALL_VIRTUALBOX}/g" \
    -e "s/__INSTALL_SSH_SERVER__/${INSTALL_SSH_SERVER}/g" \
    -e "s/__DISPLAY_MANAGER__/${DM_SERVICE_NAME}/g" \
    -e "s/__SESSION_STACK__/${SESSION_STACK}/g" \
    -e "s/__SWAP_BACKEND__/${SWAP_BACKEND}/g" \
    -e "s/__REGION_PARTITIONED__/${REGION_PARTITIONED}/g" \
    -e "s/__PROFILE_BT__/${PROFILE_BT}/g" \
    -e "s/__PROFILE_TLP__/${PROFILE_TLP}/g" \
    -e "s/__POWER_PPD__/${POWER_PPD}/g" \
    -e "s/__PROFILE_PRELOAD__/${PROFILE_PRELOAD}/g" \
    /etc/rc.local
chmod +x /etc/rc.local

# NOTE: "xbps-trigger kernel-hooks" is not a real xbps command. Kernel
# hooks under /etc/kernel.d/post-install/ (including our
# 50-sync-limine-kernels.sh above) are fired by xbps-reconfigure(1) when it
# reconfigures a kernel package. -f forces that even though the package is
# already "configured", so the hook runs now instead of waiting for the
# next real kernel update.
# AI (Big Pickle) CHANGE — Beta-v2.9.16 [KERNEL-SELECT]: reconfigure EVERY
# kernel in the resolved $KERNEL_PKGS set (deliberately word-split,
# shellcheck disable=SC2086) so each installed flavor's hooks + dracut run.
# shellcheck disable=SC2086  # KERNEL_PKGS is a space-joined word list; per-element args intended
xbps-reconfigure -f $KERNEL_PKGS

# CRITICAL — DO NOT REMOVE: must run after xbps-reconfigure -f
# $KERNEL_PKGS above, not before — its own kernel-package post-install
# hook fires a second dracut run of its own, producing a smaller initramfs
# that no longer carries our custom dracut.conf.d modules. Running this
# loop LAST guarantees our explicitly-built, fully-featured initramfs is
# what actually ships.
for kver_dir in /lib/modules/*; do
    kver="$(basename "$kver_dir")"
    dracut --force "/boot/initramfs-${kver}.img" "$kver"
done

# AI (Big Pickle) ADDITION — Beta-v2.9.45 [INNER-PARTSCAN-DMPROBE] / Beta-v2.9.56
# [INNER-PARTSCAN-KPARTX]: FATAL initramfs-content gate. Every /boot initramfs
# MUST actually carry the boot-required bits — a broken image that slips past
# here would be copied to the ESP by the Limine re-sync below (and even GRUB
# would fail a LUKS root whose initramfs cannot unlock/register it), dying only
# at next boot when disk re-provisioning hurts. Abort HERE, while the disk is
# still consistent and nothing half-built has shipped. Since Beta-v2.9.56 the
# partscan module also REQUIRES the kpartx binary (its PRIMARY tool) — an
# image with only partprobe is exactly the broken one that stranded the first
# real ENCRYPT+regions boot at the emergency shell. Uses the same SIGPIPE-safe
# lsinitrd gates as the live-side per-image guard; lsinitrd absent = cannot
# audit = FATAL.
if [ "$ENCRYPT" = "yes" ]; then
    _gate_fail=0
    for kver_gate in /boot/*.img; do
        [ -f "$kver_gate" ] || continue
        _img="$kver_gate"
        if command -v lsinitrd > /dev/null 2>&1; then
            lsinitrd "$_img" 2> /dev/null | grep -c 'bin/cryptsetup' > /dev/null || _gate_fail=1
            if [ -d /usr/lib/dracut/modules.d/98void-inner-partscan ]; then
                lsinitrd "$_img" 2> /dev/null | grep -c 'kpartx' > /dev/null || _gate_fail=1
                lsinitrd "$_img" 2> /dev/null | grep -c 'partprobe' > /dev/null || _gate_fail=1
                lsinitrd "$_img" 2> /dev/null | grep -c 'void-inner-partscan.sh' > /dev/null || _gate_fail=1
                lsinitrd "$_img" 2> /dev/null | grep -c '10-void-inner-partscan.rules' > /dev/null || _gate_fail=1
            fi
        else
            echo "FATAL: lsinitrd not available in chroot; cannot verify initramfs content." >&2
            _gate_fail=1
        fi
        [ "$_gate_fail" -eq 1 ] && break
    done
    if [ "$_gate_fail" -eq 1 ]; then
        echo "FATAL: initramfs ${_img} is missing required boot content (cryptsetup and/or kpartx/partprobe/void-inner-partscan bits)." >&2
        echo "       Aborting before the ESP sync — do not boot this disk. Install cryptsetup/kpartx/parted, rebuild with dracut --force, and re-run." >&2
        exit 1
    fi
    unset _gate_fail
fi

# AI (Big Pickle) ADDITION — Beta-v2.9.26 [WIFI-FW-VERIFY]: prove the finished
# system really has driver + firmware for every radio detected on the LIVE box
# (live hardware == target hardware). Iterates the detected chipset IDs; for
# the newest installed kernel checks the firmware dir map AND the module in
# modules.dep/modules.builtin (built-in drivers otherwise false-flag).
# Informational only — nothing is gated on it.
newest_kver="$(ls -1 /lib/modules/ 2>/dev/null | sort -V | tail -n1)"
for _wid in $WIFI_IDS; do
    case "$_wid" in
        0x14e4:*) _fw_dir="brcm" ;;
        0x14c3:*) _fw_dir="mediatek" ;;
        0x10ec:*) _fw_dir="rtw88 rtw89 rtlwifi" ;;
        0x8086:*) _fw_dir="iwlwifi" ;;
        0x168c:*) _fw_dir="ath9k ath10k ath11k" ;;
        0x17cb:*) _fw_dir="qca" ;;
        *) _fw_dir="" ;;
    esac
    _fw_ok="no"
    for _d in $_fw_dir; do
        [ -d "/usr/lib/firmware/${_d}" ] && _fw_ok="yes" && break
    done
    _mod_ok="no"
    if [ -n "$newest_kver" ]; then
        for _g in grep; do :; done
        if grep -qiE 'wireless|wifi|mac80211|mt76|iwl|rtw|ath|brcmfmac' "/lib/modules/${newest_kver}/modules.dep" 2>/dev/null; then
            _mod_ok="yes"
        elif grep -qiE 'wireless|wifi|mac80211|mt76|iwl|rtw|ath|brcmfmac' "/lib/modules/${newest_kver}/modules.builtin" 2>/dev/null; then
            _mod_ok="yes"
        fi
    fi
    if [ "$_fw_ok" = "yes" ] && [ "$_mod_ok" = "yes" ]; then
        echo "[wifi] verified: ${_wid} — driver + firmware present in target (kernel ${newest_kver:-<none>})"
    else
        echo "WARNING [wifi]: ${_wid} — $([ "$_fw_ok" = "yes" ] && echo "firmware present" || echo "firmware MISSING (install the matching linux-firmware-* split)") / $([ "$_mod_ok" = "yes" ] && echo "module present" || echo "module NOT FOUND (out-of-tree/dkms driver — firmware alone can't fix it)")" >&2
    fi
done
unset _wid _fw_dir _d _fw_ok _mod_ok newest_kver

# AI (Big Pickle) ADDITION — Beta-v2.9.32 [FW-AUDIT]: report-only firmware
# accounting. Void's wholesale firmware set is a hard dependency wall
# (linux-base depends on dracut alsa-firmware linux-firmware-network
# sof-firmware + (x86_64) linux-firmware-intel -nvidia -amd; and
# linux-firmware-network depends on linux-firmware-broadcom) — so pruning is
# impossible from the installer, which acts AFTER the dependency contract. The
# honest contribution is accurate accounting of what ships vs what this box
# actually needs. Queries the TARGET pkgdb (xbps-query -l) and prints, per
# split, what is present and why. Report-only — nothing is gated on it.
FW_AUDIT_TEXT=""
fw_audit_line() { FW_AUDIT_TEXT="${FW_AUDIT_TEXT}${1}"$'\n'; }

fw_audit_line "[fw] Firmware accounting (report-only):"

# linux-firmware-network is the always-kept bulk (every LAN/WLAN/BT vendor
# wholesale; never prunable — it is pulled by linux-base and is the single
# split that drags in the Broadcom gap closer).
if xbps-query -l 2>/dev/null | grep -q '^linux-firmware-network-'; then
    fw_audit_line "  linux-firmware-network : present — always-kept bulk (every LAN/WLAN/Bluetooth vendor wholesale; never prunable)."
else
    fw_audit_line "  linux-firmware-network : ABSENT (unexpected — linux-base should pull it)."
fi

# -amd : amdgpu/radeon firmware blob. Present when installed; "matches this
# box's probe" when the live hardware review saw an AMD GPU, otherwise kept
# ONLY by the linux-base dependency wall. (linux-firmware-amd also doubles as
# the amdgpu/radeon blob, so it is not dropped on an AMD-GPU box even under
# the wall — that is why HAS_AMD_GPU is not a prune signal here.)
if xbps-query -l 2>/dev/null | grep -q '^linux-firmware-amd-'; then
    if [ "${HAS_AMD_GPU:-no}" = "yes" ]; then
        fw_audit_line "  linux-firmware-amd      : present — matches this box's probe (AMD GPU present)."
    else
        fw_audit_line "  linux-firmware-amd      : present — kept ONLY by the linux-base dependency wall (no AMD GPU detected)."
    fi
else
    fw_audit_line "  linux-firmware-amd      : absent."
fi

# -intel : Intel GPU/firmware. Same logic as -amd.
if xbps-query -l 2>/dev/null | grep -q '^linux-firmware-intel-'; then
    if [ "${HAS_INTEL_GPU:-no}" = "yes" ]; then
        fw_audit_line "  linux-firmware-intel    : present — matches this box's probe (Intel GPU present)."
    else
        fw_audit_line "  linux-firmware-intel    : present — kept ONLY by the linux-base dependency wall (no Intel GPU detected)."
    fi
else
    fw_audit_line "  linux-firmware-intel    : absent."
fi

# -nvidia : NVIDIA GPU firmware. Same logic.
if xbps-query -l 2>/dev/null | grep -q '^linux-firmware-nvidia-'; then
    if [ "${HAS_NVIDIA_GPU:-no}" = "yes" ]; then
        fw_audit_line "  linux-firmware-nvidia   : present — matches this box's probe (NVIDIA GPU present)."
    else
        fw_audit_line "  linux-firmware-nvidia   : present — kept ONLY by the linux-base dependency wall (no NVIDIA GPU detected)."
    fi
else
    fw_audit_line "  linux-firmware-nvidia   : absent."
fi

# The one genuinely closed gap: Broadcom. Installed for a detected Broadcom
# radio (the gap-closing prompt), or flagged absent when declined.
# AI (Big Pickle) FIX — [RECONSTRUCTED]: Solar Pro 4's draft compared WIFI_IDS
# against the glob "*0x14e4:*" with a string `=` (never true), so the
# broadcom-present-but-declined case fell into the wrong branch. This `case`
# contains-check matches the space-joined ID list (an entry of form 0x14e4:*)
# the way the live probe actually builds it.
if xbps-query -l 2>/dev/null | grep -q '^linux-firmware-broadcom-'; then
    fw_audit_line "  linux-firmware-broadcom : present — the ONE closed gap (installed for the detected Broadcom radio)."
else
    case " ${WIFI_IDS:-} " in
        *" 0x14e4:"*)
            fw_audit_line "  linux-firmware-broadcom : ABSENT but a Broadcom radio was detected — the detected radio has no firmware (declined, or the [WIFI-FW] install failed)."
            ;;
        *)
            fw_audit_line "  linux-firmware-broadcom : absent (no Broadcom radio detected — nothing to close)."
            ;;
    esac
fi

# The one genuinely pruned package: CPU microcode. Exactly one is installed
# (or neither, on an opt-out / unknown-vendor build). Shows the decision that
# [CPU-DETECT] already made live.
if xbps-query -l 2>/dev/null | grep -q '^intel-ucode-'; then
    fw_audit_line "  intel-ucode             : present — the one genuinely pruned package (Intel microcode, installed per live CPU-detect)."
elif xbps-query -l 2>/dev/null | grep -q '^linux-firmware-amd-'; then
    : # linux-firmware-amd line already covers the AMD case above; microcode
       # on AMD is the same split, so do not double-count it here.
else
    fw_audit_line "  intel-ucode             : absent (microcode: ${MICROCODE_PKG:-<none>} per live CPU-detect / opt-out)."
fi

# audio firmware: alsa-firmware + sof-firmware when present.
_fw_audio=""
xbps-query -l 2>/dev/null | grep -q '^alsa-firmware-' && _fw_audio="alsa-firmware "
xbps-query -l 2>/dev/null | grep -q '^sof-firmware-' && _fw_audio="${_fw_audio}sof-firmware"
if [ -n "$_fw_audio" ]; then
    fw_audit_line "  ${_fw_audio% } : present (audio firmware)."
fi
unset _fw_audio

echo "$FW_AUDIT_TEXT"

if [ "$BOOTLOADER" = "limine" ]; then
# AI (Claude, Sonnet 5, Medium) ADDITION — Beta-v2.3.0 [KERNEL-HOOK follow-up] §4.15: re-sync
# the ESP copies (and rewrite limine.conf) AFTER the dracut regen loop
# above, closing the same ordering gap 3.0.x fixed for grub-mkconfig — the
# initial sync earlier in this block predates the final, fully-featured
# initramfs build; without this second call the ESP would ship the
# smaller pre-custom-module initramfs xbps-reconfigure produced as a side
# effect. Uses the same shared scripts the kernel hook and snapper plugin
# use (see [LIMINE-SYNC-CRON] and [LIMINE-MULTI-KERNEL]).
/usr/local/sbin/void-limine-sync-kernels
/usr/local/sbin/void-limine-write-conf
fi

# AI (Claude, Sonnet 5, Medium) CHANGE: Baseline snapshot creation moved
# here — it now runs after the dracut regen loop (and, for Limine, the
# final ESP/limine.conf sync) directly above, so the initramfs frozen into
# this snapshot already has the snapshot-overlay module baked in, same as
# any timeline snapshot created afterward. For GRUB, grub-btrfs's own
# grub.d hook (41_snapshots-btrfs) is disabled/re-enabled around the
# create call: at the moment this runs there are still zero snapshots yet,
# so the hook would otherwise do a pointless scan-of-nothing / risk a race
# with snapper mid-create.
if [ "$BOOTLOADER" = "grub" ]; then
    [ -f /etc/grub.d/41_snapshots-btrfs ] && chmod -x /etc/grub.d/41_snapshots-btrfs
fi
snapper --no-dbus -c root create --description "Baseline Automated System Installation"
if [ "$BOOTLOADER" = "grub" ]; then
    [ -f /etc/grub.d/41_snapshots-btrfs ] && chmod +x /etc/grub.d/41_snapshots-btrfs
    grub-mkconfig -o /boot/grub/grub.cfg
else
    # Final limine.conf regeneration — picks up the baseline snapshot (and
    # any snapshots snapper's own create-config bookkeeping may have
    # produced) in the static /Snapshots submenu.
    /usr/local/sbin/void-limine-write-conf
fi
CHROOT_EOF

# AI (Big Pickle) ADDITION — Beta-v2.9.23 [SSH-KEYS]: the chroot deposit
# shredded the TARGET /tmp copies; now shred the LIVE /tmp stage behind it
# (still on the live runtime after the chroot exits). Belt-and-braces with the
# deposit shred + the cleanup_on_failure shred below, so no key material ever
# persists on the live medium after a successful or aborted run.
if [ -d /tmp/ssh-keygen ] || [ -d /tmp/ssh-import ]; then
    shred -u /tmp/ssh-keygen/* /tmp/ssh-import/* 2>/dev/null || true
    rm -rf /tmp/ssh-keygen /tmp/ssh-import
    echo "  SSH key stage shredded from live environment."
fi

# =============================================================================
# STAGE 3: CLEAN POST-CHROOT RECOVERY TEARDOWN ON LIVE SYSTEM
# =============================================================================
echo ""
echo "${C_CYN}==============================================================================${C_RST}"
echo "${C_CYN}${C_BOLD} STAGE 3: Clean post-chroot recovery teardown${C_RST}"
STAGE_CONTEXT="STAGE3:teardown"
jl "Begin Stage 3 (post-chroot teardown)"
echo "${C_CYN}==============================================================================${C_RST}"
echo "Tearing down system targets cleanly..."
sync

swapoff /mnt/var/swap/swapfile || true

# Beta-v2.6.2 [GRUB-ESP-BOOT]: same ESP-mountpoint change in the clean
# success teardown (combo mounts the ESP at /mnt/boot; those umounts are
# harmless no-ops when the combo is not in effect).
[ "$GRUB_ESP_BOOT" = "true" ] && umount -v /mnt/boot || true
umount -v /mnt/boot/efi || true
umount -v /mnt/boot/grub || true
umount -fl /mnt/dev || true
umount -fl /mnt/proc || true
umount -fl /mnt/sys || true
umount -fl /mnt/run || true

umount -v /mnt/var/swap || true
umount -v /mnt/var/spool || true
umount -v /mnt/var/log || true
umount -v /mnt/var/lib/libvirt || true
# AI (Big Pickle) ADDITION — Beta-v2.6.1 [SUBVOLS]: teardown for @network.
# All || true — no-op safe when not created.
umount -v /mnt/var/lib/NetworkManager || true
# AI (Big Pickle) ADDITION — Beta-v2.8.2 [SUBVOL-PRE-SYS]: teardown for the
# system-level "pre-created for later" data subvols (Flatpak/Docker/Podman
# rootful). No-op safe (|| true) when the matching software is neither being
# installed now nor pre-provisioned.
umount -v /mnt/var/lib/flatpak || true
umount -v /mnt/var/lib/docker || true
umount -v /mnt/var/lib/containers || true
# AI (Big Pickle) CHANGE — Beta-v2.4.0 [item 3]: lightdm umount added alongside
# sddm; both are no-op-safe (|| true) when the matching DM wasn't chosen.
umount -v /mnt/var/lib/sddm || true
umount -v /mnt/var/lib/lightdm || true
umount -v /mnt/var/cache || true
umount -v /mnt/srv || true
umount -v /mnt/opt || true
umount -v /mnt/.snapshots || true
umount -v /mnt/home || true
# AI (Big Pickle) ADDITION — Beta-v2.9.59 [LOCAL-CACHE]: release the media cache
# bind mount before /mnt itself; a live nested mount here would make the final
# umount fail. No-op safe when the cache was never bound.
umount -v /mnt/tmp/xbps-cache || true
umount -v /mnt || true

# AI (Big Pickle) ADDITION — Beta-v2.4.0 [item 10]: POST-INSTALL "NEXT STEPS" SUMMARY.
# Displayed just before the automatic reboot. Because the live environment is
# ephemeral but the TARGET disk persists, everything the user needs for the
# first boot of the freshly installed system is echoed here. Passwords were
# cleared earlier (unset) so nothing secret is ever printed.
case "$DESKTOP_ENV" in
    kde)      _DE_FRIENDLY="KDE Plasma";;
    cinnamon) _DE_FRIENDLY="Cinnamon";;
    gnome)    _DE_FRIENDLY="GNOME";;
    xfce)     _DE_FRIENDLY="Xfce";;
    mate)     _DE_FRIENDLY="MATE";;
    lxqt)     _DE_FRIENDLY="LXQt";;
    cosmic)   _DE_FRIENDLY="COSMIC";;
    *)        _DE_FRIENDLY="$DESKTOP_ENV";;
esac
_DE_FRIENDLY="${_DE_FRIENDLY:-$DESKTOP_ENV}"

echo ""
echo "${C_GRN}==============================================================================${C_RST}"
echo "${C_GRN}${C_BOLD}  INSTALL SUCCESSFUL — Void Linux ${SCRIPT_VERSION}${C_RST}"
echo "${C_GRN}==============================================================================${C_RST}"
echo ""
echo "${C_BOLD}  Target disk:${C_RST}   ${DISK}"
echo "${C_BOLD}  Hostname:${C_RST}     ${TARGET_FQDN:-$TARGET_HOSTNAME}"
echo "${C_BOLD}  Primary user:${C_RST}  ${TARGET_USER}"
# AI (Big Pickle) ADDITION — Beta-v2.5.2 [SHELL]: echo the chosen login shell
# so the summary confirms which shell the primary user will get at first login.
echo "${C_BOLD}  Login shell:${C_RST}  ${USER_SHELL}"
echo "${C_BOLD}  Desktop:${C_RST}      ${_DE_FRIENDLY} (${DESKTOP_ENV})"
echo "${C_BOLD}  Display manager:${C_RST} ${DISPLAY_MANAGER}"
# AI (Big Pickle) CHANGE — Beta-v2.5.0 [LIGHTDM-HW]: echo which LightDM
# greeter was selected (only LightDM has a greeter choice), so the summary
# confirms the exact greeter that will greet first boot.
if [ "$DISPLAY_MANAGER" = "lightdm" ]; then
    case "$LIGHTDM_GREETER_PKG" in
        lightdm-slick-greeter) _GREETER_FRIENDLY="Slick (lightdm-slick-greeter)" ;;
        lightdm-gtk-greeter)   _GREETER_FRIENDLY="GTK (lightdm-gtk-greeter)" ;;
        *)                     _GREETER_FRIENDLY="${LIGHTDM_GREETER_PKG:-<not selected>}" ;;
    esac
    echo "${C_BOLD}  Greeter:${C_RST}       ${_GREETER_FRIENDLY}"
    unset _GREETER_FRIENDLY
fi
echo "${C_BOLD}  Bootloader:${C_RST}   ${BOOTLOADER}"
# AI (Big Pickle) ADDITION — Beta-v2.4.0 [LOCALIZE]: echo the chosen locale and
# timezone in the summary so the user knows the target's configured language
# and zone before first boot.
echo "${C_BOLD}  Locale:${C_RST}        ${LOCALE}"
echo "${C_BOLD}  Timezone:${C_RST}     ${TIMEZONE}"
# AI (Big Pickle) ADDITION — Beta-v2.4.0 [SWAP]: echo the swap backend and whether
# hibernation is enabled so the user knows the configured swap before boot.
# Display-only: the stored SWAPFILE_SIZE (lowercase 'g') is kept for the
# btrfs mkswapfile command; we uppercase just for a friendlier readout.
_SWAP_DISPLAY_SIZE=$(printf '%s' "$SWAPFILE_SIZE" | tr '[:lower:]' '[:upper:]')
case "$SWAP_BACKEND" in
    swapfile) _SWAP_FRIENDLY="swapfile (${_SWAP_DISPLAY_SIZE})" ;;
    zram)     _SWAP_FRIENDLY="zram" ;;
    both)     _SWAP_FRIENDLY="swapfile (${_SWAP_DISPLAY_SIZE}) + zram" ;;
    none)     _SWAP_FRIENDLY="none" ;;
    *)        _SWAP_FRIENDLY="$SWAP_BACKEND" ;;
esac
unset _SWAP_DISPLAY_SIZE
echo "${C_BOLD}  Swap:${C_RST}         ${_SWAP_FRIENDLY}"
echo "${C_BOLD}  Hibernation:${C_RST}  ${ENABLE_HIBERNATION}"
echo "${C_BOLD}  Encryption:${C_RST}   $([ "$ENCRYPT" = "yes" ] && { [ "$YK_MODE" = "hmac-sha1" ] && echo "LUKS2 full-disk + YubiKey hmac-sha1 (fallback: $YK_FALLBACK)" || echo "LUKS2 full-disk (passphrase required at boot)"; } || echo "none")"
echo ""
echo "${C_BOLD}  NEXT STEPS${C_RST}"
echo "${C_GRN}  1.${C_RST} Remove the live USB, then this system will reboot into your install automatically."
echo "${C_GRN}  2.${C_RST} First boot is a clean initial-boot state. If no graphical login appears, log in"
if [ "$DISPLAY_MANAGER" = "cosmic-greeter" ]; then
    echo "     at the console and run:  ${C_BOLD}ln -sf /etc/sv/cosmic-greeter /etc/runit/runsvdir/default/ && ln -sf /etc/sv/cosmic-greeter-daemon /etc/runit/runsvdir/default/${C_RST}"
else
    echo "     at the console and run:  ${C_BOLD}ln -sf /etc/sv/${DISPLAY_MANAGER} /etc/runit/runsvdir/default/${C_RST}  (or your chosen DM)."
fi
if [ "$BOOTLOADER" = "limine" ]; then
    echo "${C_GRN}  3.${C_RST} Limine boots automatically (no NVRAM entry needed on UEFI)."
    echo "     To snapshot a running system later:  ${C_BOLD}sudo snapper create -d 'manual'${C_RST}"
else
    echo "${C_GRN}  3.${C_RST} GRUB is installed (with grub-btrfs snapshots). To update the menu:"
    echo "     ${C_BOLD}grub-mkconfig -o /boot/grub/grub.cfg${C_RST}"
fi
echo "${C_GRN}  4.${C_RST} A baseline snapper snapshot has already been created for the clean install."
echo "${C_GRN}  5.${C_RST} The exact choices + installer version that built this box are archived on it:"
echo "     ${C_BOLD}/etc/void-installer/install-config${C_RST}  and  ${C_BOLD}/etc/void-installer/Void_Linux_Installer.sh${C_RST}"
echo "     Quick record: ${C_BOLD}~/Documents/Void_Install.txt${C_RST} (installed user)"
# AI (Big Pickle) ADDITION — Beta-v2.6.5 [PKG-SNAPSHOT-AUTO]:
# tell the user that updates now snapshot automatically — no habit change needed.
echo "${C_GRN}  6.${C_RST} System updates now auto-take a snapper pre/post rollback pair:"
echo "     xbps-install is shadowed through void-xbps-snap, so your normal"
echo "     ${C_BOLD}sudo xbps-install -Su${C_RST} is unchanged. If an 'xbps' package"
echo "     self-update un-shadows the wrapper, the next boot repairs it"
echo "     automatically (see /root/tools/README.md, re-shadow-xbps.sh)."
# AI (Big Pickle) ADDITION — Beta-v2.6.6 [TOOLS-DIR]: point the admin at the
# maintenance/tools folder shipped for future recovery so it is discoverable.
echo "${C_GRN}  7.${C_RST} Re-runnable maintenance tools shipped in ${C_BOLD}/root/tools${C_RST}:"
echo "     ${C_BOLD}re-shadow-xbps.sh${C_RST}  restore auto-update snapshots after an xbps update"
echo "     ${C_BOLD}limine-sync.sh${C_RST}      force a manual Limine boot-menu resync"
echo "     ${C_BOLD}re-provision-snapper.sh${C_RST}  safely restore snapshots/plugin (no data loss)"
echo ""
echo "${C_GRN}======================================================================${C_RST}"
# AI (Big Pickle) ADDITION — Beta-v2.4.0 [RESUME]: The install completed fully, so
# the resume record is no longer needed — remove it so the next run starts
# fresh instead of offering to resume an already-finished install.
STAGE_CONTEXT="DONE"
jl "Install COMPLETED successfully (bootloader=${BOOTLOADER}, DE=${DESKTOP_ENV})"
[ -f "$STATE_FILE" ] && rm -f "$STATE_FILE"
# AI (Big Pickle) ADDITION — Beta-v2.5.1 [INSTALL-CONFIG]: carry an exact copy
# of the installer that built this machine into the target (alongside the
# /etc/void-installer/install-config summary written in the chroot), so the
# running system records both WHAT was chosen and WHICH revision built it.
mkdir -p /mnt/etc/void-installer
if [ -n "$0" ] && [ -f "$0" ]; then
    cp -f "$0" /mnt/etc/void-installer/Void_Linux_Installer.sh 2>/dev/null \
        && jl "Installer script archived to /etc/void-installer/Void_Linux_Installer.sh" \
        || echo "WARNING: could not archive installer script into target." >&2
fi
# AI (Big Pickle) ADDITION — Beta-v2.9.38 [MULTI-FS-RUNLOG]: also keep the
# run journal in the target. /tmp is tmpfs on the live USB and dies on reboot;
# this is the durable, on-disk copy of everything the install logged (including
# the [MULTI-FS] geometry/mkfs/mount/fstab audit lines above). Secret-free by
# the same construction as the journal itself — it prints flags, never secrets.
cp -f "$JOURNAL" /mnt/etc/void-installer/installer-run.log 2>/dev/null \
    && jl "Journal archived to /etc/void-installer/installer-run.log" \
    || echo "WARNING: could not archive installer journal into target." >&2
# AI (Big Pickle) CHANGE — Beta-v2.5.0 [REBOOT-COUNTDOWN]: the pre-reboot
# wait now prints the ACTUAL remaining seconds (from $REBOOT_DELAY rather
# than the old canned "a few seconds" message) as a live, self-updating
# countdown, with optional keyboard control on the installer's terminal:
#     R or Enter — reboot immediately;  P — pause the countdown;
#     C — continue;  S — stop, stay at the live shell without rebooting.
# On a terminal without a usable /dev/tty the keys silently do nothing and
# the countdown simply elapses for REBOOT_DELAY seconds before rebooting.
echo ""
echo "  Rebooting in ${C_BOLD}${REBOOT_DELAY}${C_RST} second(s) — press ${C_BOLD}R${C_RST}/${C_BOLD}Enter${C_RST} to reboot now,"
echo "  ${C_BOLD}P${C_RST} to pause, ${C_BOLD}C${C_RST} to continue, ${C_BOLD}S${C_RST} to stop and stay at the live shell."
sync
_do_reboot=1
_now_paused=0
_tl="$REBOOT_DELAY"
_tty_avail=0
{ [ -r /dev/tty ] && [ -w /dev/tty ]; } && _tty_avail=1
while [ "$_tl" -gt 0 ]; do
    if [ "$_now_paused" -eq 1 ]; then
        printf "\r  [%s]  PAUSED — R/Enter=reboot now, C=continue, S=stop:             " "$_tl"
    else
        printf "\r  Reboot in %s second(s)...  R/Enter=now, P=pause, S=stop:       " "$_tl"
    fi
    _break_key=""
    _tick=0
    if [ "$_tty_avail" -eq 1 ] && read -r -s -n 1 -t 1 _break_key < /dev/tty 2>/dev/null; then
        case "$_break_key" in
            R|r|$'\r'|$'\n') _do_reboot=1; break ;;
            P|p)             _now_paused=1 ;;
            C|c)             _now_paused=0 ;;
            S|s)             _do_reboot=0; break ;;
        esac
    elif [ "$_tty_avail" -eq 1 ]; then
        _tick=1
    else
        sleep 1
        _tick=1
    fi
    if [ "$_now_paused" -eq 0 ] && [ "$_tick" -eq 1 ]; then
        _tl=$((_tl - 1))
    fi
done
printf "\r\033[K"
if [ "$_do_reboot" -eq 1 ]; then
    echo "Rebooting now..."
    reboot
else
    echo "Reboot skipped — staying at the live shell. When ready, reboot with: ${C_BOLD}reboot${C_RST}"
fi
# (No code after the reboot branch is reachable; a stopped run falls through
# to EOF and returns the user to the live shell prompt.)
