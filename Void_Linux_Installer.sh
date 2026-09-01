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
#     AI (Big Pickle) ADDITION — v3.3.0-beta6 [ENCRYPT]: optionally, partition
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
#     in memory during the chroot phase only, never persisted.
#     AI (Big Pickle) ADDITION — v3.3.0-beta7 [YUBIKEY]: optionally, a
#     YubiKey hmac-sha1 challenge-response slot can take over boot unlock
#     instead of / in addition to the typed passphrase. Enrollment programs
#     an OTP slot with a random secret and binds HMAC-SHA1(slot_secret,
#     CHALLENGE) as a LUKS key slot; a dracut `keyscript=` in crypttab
#     challenges the YubiKey at boot and prints that same response as the
#     key. YK_FALLBACK=yes keeps the typed-passphrase slot too (YubiKey
#     fails → dracut prompts), YK_FALLBACK=no removes it (YubiKey-only
#     unlock — possession-required, nothing to type). YubiKey-only requires
#     BOOTLOADER=limine (GRUB cryptodisk needs a passphrase slot to read the
#     encrypted /boot); with GRUB the fallback slot is forced on. The
#     CHALLENGE (public, in the keyscript/limine-env) is not itself a
#     credential — the response only exists on the YubiKey, so nothing
#     that unlocks is ever persisted; the passphrase and the HMAC key are
#     memory-only.
#   - Most subvolumes use noatime+zstd:1 compression. Several are
#     deliberately nodatacow+compress=none instead: @swap (COW + compression
#     both break swapfiles), @libvirt (COW hurts qcow2/raw VM disk
#     performance and defeats their own internal COW), the churn-heavy var
#     subvols @srv/@cache/@log/@spool/@tmp (server/cache/log/queue/temp
#     churn constantly — COW is pure write amplification), and the browser
#     profile/cache subvols @mozilla, @mozilla-cache, @chromium, @vivaldi
#     (profile sqlite/cache churn constantly — COW there is pure write
#     amplification). AI (Big Pickle) FIX — v3.3.0-beta4 [NODATACOW]: the var
#     subvols are made nodatacow via their MOUNT OPTIONS (and fstab), not the
#     pre-mount `chattr +C` — chattr on a mountpoint dir inode is shadowed the
#     moment a subvolume mounts over it, so it never took effect before.
#   - Hibernation: one physical BTRFS-native swapfile (not swap partition),
#     resume offset computed via `btrfs inspect-internal map-swapfile -r`
#     and injected into the kernel command line (Limine's kernel_cmdline)
#     plus dracut's resume module.
#     AI (Big Pickle) FIX — v3.3.0-beta4: `SWAPFILE_MODE` (derived from
#     `SWAP_BACKEND`, drives @swap subvol creation, the swapfile mount, mkswapfile,
#     and the fstab swap entries) was missing from the persisted state-file list,
#     so a resumed run skipped all swap setup silently. It is now persisted
#     (single source stays the prompt-block derivation from `SWAP_BACKEND`).
#   - Init: runit, not systemd. Session/seat management (v3.2.0) is a real
#     choice, $SESSION_STACK: elogind (default, the standalone systemd-logind
#     fork satisfying the org.freedesktop.login1 D-Bus interface that
#     SDDM/polkit/NetworkManager expect) OR the lighter turnstile + seatd +
#     acpid stack. Neither makes this a systemd system. Never add
#     systemctl/journalctl/loginctl/.service-unit logic anywhere in this
#     script; services are enabled via `ln -s /etc/sv/X /etc/runit/...`.
#   - Virtualization: QEMU/KVM + libvirt on a custom `br0` bridge (built natively
#     via NetworkManager connection profile tracking configurations at boot),
#     NOT libvirt's default NAT `virbr0` (explicitly disabled on first boot — see rc.local).
#     AI (Big Pickle) FIX — v3.3.0-beta4 [NM-IFACE]: NM's `[connection]
#     interface-name=` is a LITERAL device name, not a glob (only `[match]`
#     globs). The NIC-detection fallback `NET_INTERFACE_MATCH="enp*"` is therefore
#     NOT emitted as `interface-name=` in br0-slave (it can never bind); the key is
#     omitted so the slave matches by role on any free ethernet device. A concrete
#     auto-detected NIC still emits the literal name, unchanged.
#   - Login shell (v3.3.0-beta4 [SHELL]): a real install-time choice,
#     $USER_SHELL — bash (default, bundled in base-system, no package) or
#     zsh/fish/mksh (installed from the official repos and set as the primary
#     user's login shell via useradd -s). The binary path and its providing
#     package are carried through chroot_env and the resume state file so a
#     resumed run restores the choice. (v3.3.0-beta7 [ZSHRC]: when the choice
#     is zsh, a minimal ~/.zshrc is pre-created for the primary user so the
#     first login doesn't hit zsh's zsh-newuser-install wizard.)
#   - Desktop (v3.2.0): a real install-time choice, $DESKTOP_ENV — KDE
#     Plasma (default, primary tested path), Cinnamon via cinnamon-all,
#     GNOME via the full `gnome` metapackage, Xfce via `xfce4`, MATE via
#     `mate`, LXQt via `lxqt`, or COSMIC — which is NOT in the official
#     repos and is installed from a community repo (maintained by REDACTED
#     REDACTED), a third-party signing-trust choice made at the user's
#     own risk with runtime repo verification and a graceful abort if it is
#     unavailable. VERIFIED against Void's docs and real user reports: Void
#     lists Wayland sessions for GNOME/KDE Plasma only — the GTK/Qt desktops
#     (Cinnamon/Xfce/MATE/LXQt) are X11 on Void today.
#     `wayland`/`wayland-protocols` are still installed unconditionally
#     for all options (cheap, harmless, future-proofing).
#     Display manager (v3.2.0) is an independent choice, $DISPLAY_MANAGER:
#     SDDM (default for KDE/LXQt/COSMIC), LightDM (Cinnamon/Xfce/MATE), GDM
#     (GNOME), or cosmic-greeter (COSMIC's own greeter, offered only when
#     COSMIC is chosen; its maintainer warns it does not work reliably).
#     LightDM additionally asks for a greeter (GTK [default] /
#     Slick / WebKit2). v3.3.0-beta2 [LIGHTDM-HW] hardens the LightDM path
#     against the greeter failures observed on real hardware: accounts-daemon
#     (org.freedesktop.Accounts) is granted a real runit service + first-boot
#     link instead of racy on-demand D-Bus activation (fixes Slick-greeter
#     hang / GTK-greeter auth flakiness — void-packages#59538), WebKit2's
#     config is written to point at Void's actually-shipped `void` theme,
#     and the @lightdm subvolume is chowned to lightdm:lightdm.
#     [LIGHTDM-SWRAP] also writes `session-wrapper=/etc/lightdm/Xsession`
#     into the generated lightdm.conf — mandatory, since overwriting Void's
#     package-default conf would otherwise leave LightDM using its
#     compiled-in default wrapper `lightdm-session`, which Void does not ship
#     (this made every session bounce back to the greeter with an empty
#     .xsession-errors). PipeWire
#     audio (with WirePlumber as session
#     manager — auto-managed via robust XDG rules).
#   - Recovery: Snapper (timeline snapshots) + a dracut overlay so a
#     snapshot boot is read-only with a writable RAM overlay rather than
#     mutating the snapshot itself. Snapshot-boot MENU generation depends
#     on which bootloader was chosen (next bullet).
#     AI (Big Pickle) ADDITION — v3.3.0-beta5 [SCRUB]: the physical half of
#     that same recovery story — a monthly /etc/cron.monthly/btrfs-scrub
#     job catches silent checksum failures (bitrot) and lets Btrfs repair
#     them, complementing Snapper (logical/accidental damage). It scrubs
#     once per btrfs FILESYSTEM (the mount list is deduped by major:minor
#     since every subvolume mount is a view of the same fs) and logs to
#     /var/log/btrfs-scrub.log. Never forced: a manually-running scrub
#     makes the monthly pass fail fast and record why instead of racing it.
#   - Bootloader (v3.2.0-beta1): a real per-install CHOICE, $BOOTLOADER,
#     between two fully separate code paths in Stage 2:
#       * grub   — mature, real-hardware-tested path carried from 3.0.x.
#         Snapshot boot menu via grub-btrfs (dynamic, auto-regenerated by
#         a kernel hook). 1GiB ESP.
#       * limine — newer, simpler, single-file portable UEFI binary
#         deployed directly onto the ESP (EFI/BOOT/BOOTX64.EFI) — no
#         efibootmgr, no NVRAM entries. Snapshot boot menu is a static
#         config written by /usr/local/sbin/void-limine-write-conf, a
#         standalone script shared by the kernel hook AND a snapper plugin
#         (/usr/lib/snapper/plugins/00-void-limine-snapper-sync) that fires the
#         moment a snapshot is created/deleted, with a /etc/cron.d/
#         void-limine-sync entry (every 15 min) kept as a safety-net fallback
#         — no grub-btrfs equivalent exists on Void, and Void's snapper DOES
#         execute its plugin dir (empirically verified; see [SNPR-EV] and
#         Debug/snpr_ev/probe_void_snapper_plugin.sh). 4GiB ESP. Treat as
#         experimental — see §1/§3.19-§3.26 of the companion CHANGELOG.
#         v3.3.0-beta3 [LIMINE-WALLPAPER] optionally adds a boot-screen
#         wallpaper: an opt-in prompt takes an image from the live system,
#         copies it onto the ESP at boot():/limine-splash.<ext>, and records
#         the choice in limine-env so void-limine-write-conf re-emits
#         wallpaper:/wallpaper_style (guarded on the file existing). Void's
#         limine package ships the plain BOOTX64.EFI — wallpaper works with
#         it, it is not a limine-gui-only feature.
#     Both paths are UEFI-only; BIOS boot is not implemented for either.
#   - Repo mirror (v3.3.0): the official Void repository mirror is a real
#     install-time choice auto-derived from the selected timezone (regional
#     selection from the authoritative registry at xmirror.voidlinux.org),
#     with an override menu. $REPO_PRIMARY is set to the chosen mirror while
#     $REPO_BACKUP1 (Fastly CDN) and $REPO_BACKUP2 (tier-1 load-balanced
#     default) are retained for global failover. All baked-in mirror URLs were
#     live-verified (HTTP 200 + valid x86_64-repodata). The community COSMIC
#     repo is unaffected.
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
#      hook or cron.d — see [LIMINE-SYNC-CRON]).
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
#      applies under BOOTLOADER=grub; void-limine-write-conf and its cron.d
#      entry only apply under BOOTLOADER=limine. Neither should leak into
#      the other's branch.
#   6. [BOOTLOADER=limine, LIMINE-WALLPAPER] The Limine wallpaper is a
#      persisted opt-in: choice + style live in /etc/void-installer/limine-env,
#      the image lives on the ESP as boot():/limine-splash.<ext>, and
#      void-limine-write-conf re-emits wallpaper:/wallpaper_style ONLY when
#      that ESP file exists. Do not hardcode a wallpaper path, do not drop the
#      existence guard (a missing image must not leave a dangling wallpaper
#      line), do not forget it works with Void's plain BOOTX64.EFI, and do NOT
#      reintroduce a commented wallpaper template in limine.conf — the cron
#      resync rewrites the file every 15 min, so the only durable enable path
#      is LIMINE_WALLPAPER=yes in limine-env + an image on the ESP.
# =============================================================================
set -eE
# errtrace (-E) makes the ERR trap below fire inside functions/subshells too,
# not just at the top level.
set -o pipefail
# AI (Big Pickle) ADDITION — v3.3.0-beta3 [PIPEFAIL]: pipefail closes the
# silent-failure gap that `set -e` alone misses: without it a pipeline whose
# LAST command succeeds masks an earlier failing stage (e.g. a failed
# `sed`/`grep` extract followed by a `head` that returns 0 would look
# healthy). Guarded extractor pipelines that already use `|| true` /
# `|| echo 0` are unaffected.

# AI (Claude, Sonnet 5, Medium) ADDITION: Bump SCRIPT_VERSION on every revision so the running
# terminal always shows which file/revision is actually executing — matches
# the filename this script is currently distributed under.
SCRIPT_VERSION="3.3.0-beta7"

# =============================================================================
# AI (Big Pickle) ADDITION — v3.2.0 [FAILURE-JOURNAL]: FAILURE TRACE / INSTALL
# JOURNAL. A persistent (same-live-session) log of install milestones plus,
# on any failure, a diagnostic trace: exit code, the exact failing command,
# and the function-call stack. It lives in /tmp alongside the resume state
# file so a crash both leaves a resumable record AND a debuggable trace. The
# `jl` helper appends timestamped milestone lines. Defined before the ERR
# trap so it is always available when an error fires.
# =============================================================================
JOURNAL="/tmp/void-installer-journal.log"
jl() { echo "[$(date +%H:%M:%S)] $*" >> "$JOURNAL" 2>/dev/null; }
: > "$JOURNAL"
# =============================================================================
# AI (Big Pickle) CHANGE — v3.3.0-beta2 [REBOOT-COUNTDOWN]: how long the
# completed-install summary waits before auto-rebooting. The end summary
# prints this actual value and then a live per-second countdown, so changing
# this one variable changes both the summary text and the wait. Overridable
# from the environment (REBOOT_DELAY=10 ...) for scripting/resume runs.
REBOOT_DELAY="${REBOOT_DELAY:-20}"
# =============================================================================
# AI (Big Pickle) ADDITION — v3.2.0 [COSMETIC]: ANSI color + formatting helpers
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

echo "=============================================================================="
echo " ${C_BOLD}${C_CYN}Void Linux Unified Installer${C_RST} — version ${C_BOLD}${SCRIPT_VERSION}${C_RST}"
echo " Bootloader: choose GRUB or Limine below — UEFI only, BIOS unsupported"
echo "=============================================================================="

# Best-effort unwind of whatever got mounted, run ONLY on an actual command
# failure under set -e (trap ... ERR), not on a Ctrl-C or a deliberate exit.
cleanup_on_failure() {
    ec=$?

    # =========================================================================
    # AI (Big Pickle) ADDITION — v3.2.0 [FAILURE-JOURNAL]: write the failure
    # trace to the journal while the shell's error context is still intact.
    # Everything here is guarded (|| true) so the unwind below still runs even
    # if the journal write itself fails.
    # =========================================================================
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
    umount -fl /mnt/boot/efi 2>/dev/null || true
    umount -fl /mnt/boot/grub 2>/dev/null || true
    umount -fl /mnt/dev 2>/dev/null || true
    umount -fl /mnt/proc 2>/dev/null || true
    umount -fl /mnt/sys 2>/dev/null || true
    umount -fl /mnt/run 2>/dev/null || true
    # AI (Big Pickle) CHANGE — v3.2.0 [item 3]: var/lib/lightdm added to the
    # unwind list to mirror the new @lightdm subvolume (only ever mounted
    # when DISPLAY_MANAGER=lightdm; the umount is safe/no-op otherwise).
    for m in var/swap var/tmp var/spool var/log var/lib/libvirt var/lib/sddm var/lib/lightdm \
             var/cache srv opt .snapshots home; do
        umount -fl "/mnt/${m}" 2>/dev/null || true
    done
    umount -fl /mnt 2>/dev/null || true
    echo "!! Unwind attempted. Re-check 'mount | grep /mnt' before re-running." >&2
}
trap cleanup_on_failure ERR

sec_banner "STAGE 1" "Disk management and OS bootstrapping (outside chroot)"
STAGE_CONTEXT="STAGE1:setup"
jl "Begin Stage 1"

# Fail fast with a clear message if the Live CD hasn't got a network yet,
# rather than letting the first xbps-install die on a cryptic repo error.
# AI (Big Pickle) CHANGE — v3.3.0: this check probes the authoritative mirror
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
# AI (Big Pickle) ADDITION — v3.2.0 [RESUME]: COARSE PHASE RESUME / SUBVOL RESET
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
RESUME=0
AUTO_RESUME=0
STATE_FILE="/tmp/void-installer-state.sh"
DRY_RUN=0
for _arg in "$@"; do
    case "$_arg" in
        -r|--resume) AUTO_RESUME=1 ;;
        -d|--dry-run|--dryrun|-n)
            # AI (Big Pickle) ADDITION — v3.3.0-beta3 [DRY-RUN]: see header —
            # walk the full interactive config, print the complete plan of what
            # would be done, and stop at the destructive partition boundary
            # WITHOUT touching any disk, running the chroot, or installing
            # anything into the live environment.
            DRY_RUN=1 ;;
        -h|--help)
            echo "Usage: $0 [-r|--resume]          (resume a previous interrupted install)" >&2
            echo "       $0 [-d|--dry-run] [args]   (walk config, print the plan, touch nothing)" >&2
            echo "       $0                         (fresh interactive install)" >&2
            exit 0 ;;
        *)
            echo "Unknown option: $_arg" >&2
            exit 2 ;;
    esac
done
unset _arg

# AI (Big Pickle) ADDITION — v3.3.0 [PREREQ]: this installer mounts, partitions
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

# =============================================================================
# AI (Big Pickle) CHANGE — v3.2.0 [RESUME]: The entire interactive
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

# AI (Big Pickle) ADDITION — v3.3.0-beta4 [SHELL]: real login-shell choice.
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
    ask "Enter choice [1-4, default 1]: "
    read -r USER_SHELL_INPUT
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
# AI (Big Pickle) ADDITION — v3.2.0 [LOCALIZE]: REAL LOCALIZATION.
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
    ask "Enter locale choice [1-12, default 1]: "
    read -r LOCALE_INPUT
    case "${LOCALE_INPUT:-1}" in
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
    ask "Enter timezone choice [1-15, default 1]: "
    read -r TZ_INPUT
    case "${TZ_INPUT:-1}" in
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
# AI (Big Pickle) ADDITION — v3.3.0 [MIRROR]: REGIONAL OFFICIAL MIRROR SELECTION.
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
# AI (Big Pickle) ADDITION — v3.2.0 [SWAP]: REAL SWAP / ZRAM / HIBERNATION
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
    ask "Enter swap choice [1-4, default 1]: "
    read -r SWAP_INPUT
    case "${SWAP_INPUT:-1}" in
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
        [yY]*) ENABLE_HIBERNATION="true" ;;
        *)     ENABLE_HIBERNATION="false" ;;
    esac
else
    ENABLE_HIBERNATION="false"
fi
export ENABLE_HIBERNATION

# AI (Big Pickle) CHANGE — v3.2.0 [SWAP]: the disk swapfile's size comes from
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
    _RAM_GB=$(( ( (_RAM_MB + 1023) / 1024 ) ))   # whole GiB of RAM, rounded up
    _SWAP_GB=$(( ( (_RAM_GB * 5) + 3 ) / 4 ))    # ceil(RAM_GB * 1.25)
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

# AI (Big Pickle) ADDITION — v3.3.0-beta6 [ENCRYPT]: optional LUKS2 full-disk
# encryption of partition 2 (the Btrfs filesystem). The ESP stays
# unencrypted. When enabled, the user types a passphrase (twice, hiding it)
# so it never lands on screen. Since v3.3.0-beta7 this passphrase can be
# supplemented or replaced by YubiKey hmac-sha1 unlock ([YUBIKEY]); the
# passphrase is always captured here so luksFormat has a primary slot to
# create the container with (and, at boot, YK_FALLBACK=yes lets it stand in
# if the YubiKey is absent).
# ENCRYPT (yes/no) is persisted in the resume state file; the passphrase is
# NOT — it lives only in this process's memory for the duration of the chroot
# phase and is unset as soon as luksFormat/luksOpen are done, so a crashed-
# then-resumed run re-prompts for it.
ENCRYPT="no"
echo ""
echo "${C_BOLD}${C_BLU}Encrypt disk?${C_RST}"
echo ""
echo "  Encrypt partition 2 (the root filesystem) with LUKS2. Every subvolume"
echo "  (root, home, snapshots, swap, ...) lives inside the encrypted volume."
echo "  A passphrase is required at every boot; the ESP/bootloader stays"
echo "  unencrypted so it can find the system before the passphrase exists."
echo ""
ask "Enable full-disk encryption (LUKS2)? [y/N]: "
read -r ENCRYPT_INPUT
case "$ENCRYPT_INPUT" in
    [yY]*)
        ENCRYPT="yes"
        while :; do
            echo ""
            echo "Enter a passphrase for the encrypted disk (hidden input):"
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
        ;;
    *)
        ENCRYPT="no"
        ENCRYPT_PASSPHRASE=""
        ;;
esac
export ENCRYPT

# AI (Big Pickle) ADDITION — v3.3.0-beta7 [YUBIKEY]: optional YubiKey
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
                [nN]*) YK_TOUCH="no" ;;
                *)     YK_TOUCH="yes" ;;
            esac
            echo ""
            echo "  Passphrase fallback: with 'yes' (default) the typed passphrase slot is"
            echo "  kept too, so YubiKey absent/wrong still boots by typing the passphrase."
            echo "  With 'no' the passphrase slot is removed and the YubiKey is the ONLY"
            echo "  unlock — possession-required, nothing to type. NOTE: YubiKey-only is"
            echo "  only supported with the Limine bootloader (GRUB must read the encrypted"
            echo "  /boot via a passphrase), so with GRUB the fallback is kept regardless."
            ask "Keep the typed-passphrase fallback (YubiKey OR passphrase)? [Y/n]: "
            read -r YK_FALLBACK_INPUT
            case "$YK_FALLBACK_INPUT" in
                [nN]*) YK_FALLBACK="no" ;;
                *)     YK_FALLBACK="yes" ;;
            esac
            ;;
    esac
fi
export YK_MODE YK_FALLBACK YK_SLOT YK_TOUCH
unset YK_INPUT YK_SLOT_INPUT YK_TOUCH_INPUT YK_FALLBACK_INPUT

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
    [yY]*) ENABLE_SNAPSHOT_AUDIO="true" ;;
    *) ENABLE_SNAPSHOT_AUDIO="false" ;;
esac
export ENABLE_SNAPSHOT_AUDIO

# =============================================================================
# BOOTLOADER CHOICE: GRUB or LIMINE (v3.2.0-beta1) — [LIMINE-1]
# =============================================================================
# AI (Claude, Sonnet 5, Medium) CHANGE — v3.1.0-beta1: Limine was briefly made the ONLY
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

echo ""
echo "${C_BOLD}${C_BLU}Choose bootloader${C_RST}"
echo "  ${C_BOLD}1)${C_RST} ${C_GRN}GRUB${C_RST} — mature, battle-tested snapshot-boot support via"
echo "     grub-btrfs. Extensively real-hardware tested on this script's"
echo "     3.0.x line, including snapshot boot. 1GiB EFI partition."
echo "     ${C_RED}NOTE:[YUBIKEY] if YubiKey-only unlock (YK_FALLBACK=no) was"
echo "     selected, GRUB cannot be used — GRUB cryptodisk must read the"
echo "     encrypted /boot via a typed passphrase, so fallback is forced on.${C_RST}"
echo "  ${C_BOLD}2)${C_RST} ${C_YLW}Limine${C_RST} — newer, simpler, single-file UEFI bootloader with no"
echo "     efibootmgr/NVRAM dependency. Snapshot-boot menu support is a"
echo "     static config this script writes itself (no grub-btrfs"
echo "     equivalent) — treat as experimental, expect to need real-"
echo "     hardware testing and iteration. Requires a 4GiB+ EFI partition"
echo "     (ArchWiki's own recommendation for bootable snapshots, kernel"
echo "     versions, and large early-boot modules)."
while true; do
    ask "Enter choice [1/2]: "
    read -r BOOTLOADER_INPUT
    case "$BOOTLOADER_INPUT" in
        1) BOOTLOADER="grub"; EFI_PART_SIZE="1G"; break ;;
        2) BOOTLOADER="limine"; EFI_PART_SIZE="4G"; break ;;
        *) echo "Please enter 1 or 2." >&2 ;;
    esac
done
export BOOTLOADER
export EFI_PART_SIZE

# AI (Big Pickle) ADDITION — v3.3.0-beta7 [YUBIKEY]: GRUB cryptodisk must
# unlock /boot (inside the encrypted @grub) via a typed passphrase at early
# boot — a YubiKey-only volume (no passphrase LUKS slot) is unreadable by
# GRUB. YubiKey-only unlock therefore requires BOOTLOADER=limine (whose ESP
# kernel copies live on the unencrypted ESP). If the user picked GRUB after
# asking for YubiKey-only, CLAMP the fallback back on here, after the
# bootloader prompt, so the constraint is reflected in persisted state and
# in every summary/dry-run below. This is the single canonical place the
# dependency is resolved (mirrored by the same enforced fact in
# void-limine-write-conf / crypttab generation later).
if [ "$BOOTLOADER" = "grub" ] && [ "$YK_MODE" = "hmac-sha1" ] && [ "$YK_FALLBACK" = "no" ]; then
    echo "==> [YUBIKEY] YubiKey-only unlock needs GRUB to read an encrypted /boot via a"
    echo "       typed passphrase — keeping the passphrase fallback slot (YK_FALLBACK=yes)."
    YK_FALLBACK="yes"
fi

# AI (Big Pickle) ADDITION — v3.3.0-beta3 [LIMINE-WALLPAPER]: optional boot-
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
        while true; do
            ask "Path to wallpaper image on this live system: "
            read -r WP_SRC
            if [ -n "$WP_SRC" ] && [ -f "$WP_SRC" ]; then
                WP_EXT="${WP_SRC##*.}"
                case "${WP_EXT,,}" in
                    bmp|png|jpg|jpeg|qoi)
                        LIMINE_WALLPAPER="yes"
                        break ;;
                    *) echo "Unsupported extension '${WP_EXT}'. Use BMP/PNG/JPEG/QOI." >&2 ;;
                esac
            else
                echo "File not found: ${WP_SRC:-<empty>}" >&2
            fi
        done
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
export LIMINE_WALLPAPER
export LIMINE_WALLPAPER_STYLE

# AI (Claude, Sonnet 5, Medium) ADDITION — v3.1.0-beta1 [KERNEL-MODE]: Where Limine reads the
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
# AI (Big Pickle) ADDITION — v3.3.0-beta3 [LIMINE-ESP-ONLY]: the former
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
# AI (Claude, Sonnet 5, Medium) EXPANSION — v3.2.0: desktop environment is
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
echo "  ${C_BOLD}2)${C_RST} Cinnamon (X11) — Wayland session not yet packaged by Void."
echo "  ${C_BOLD}3)${C_RST} GNOME — Wayland session, confirmed available on Void."
echo "  ${C_BOLD}4)${C_RST} Xfce (X11) — lightweight GTK desktop, ships as Void's default"
echo "     graphical live-medium flavor."
echo "  ${C_BOLD}5)${C_RST} MATE (X11) — classic GNOME 2-style GTK desktop."
echo "  ${C_BOLD}6)${C_RST} LXQt (X11) — lightweight Qt desktop."
echo "  ${C_BOLD}7)${C_RST} ${C_RED}COSMIC (third-party repo)${C_RST} — the System76 desktop. NOT in the"
echo "     official Void repositories: installed from a community repo maintained"
echo "     by REDACTED REDACTED (GitHub REDACTED / Codeberg REDACTED),"
echo "     https://github.com/REDACTED/void-packages. It is a third-party"
echo "     signing-trust choice made at your own risk — audit the repo before"
echo "     installing. The repo URL is verified reachable at runtime; if it is"
echo "     unavailable the install aborts cleanly rather than failing mid-way."
while true; do
    ask "Enter choice [1/2/3/4/5/6/7]: "
    read -r DESKTOP_ENV_INPUT
    case "$DESKTOP_ENV_INPUT" in
        ""|1) DESKTOP_ENV="kde"; break ;;
        2) DESKTOP_ENV="cinnamon"; break ;;
        3) DESKTOP_ENV="gnome"; break ;;
        4) DESKTOP_ENV="xfce"; break ;;
        5) DESKTOP_ENV="mate"; break ;;
        6) DESKTOP_ENV="lxqt"; break ;;
        7) DESKTOP_ENV="cosmic"; break ;;
        *) echo "Please enter 1, 2, 3, 4, 5, 6, or 7." >&2 ;;
    esac
done
export DESKTOP_ENV

# AI (Claude, Sonnet 5, Medium) ADDITION — v3.2.0: store the display manager
# typically paired with the just-chosen DE so the DM prompt below can offer
# that as its recommended/default entry, while still allowing any other DM.
case "$DESKTOP_ENV" in
    kde|lxqt) RECOMMENDED_DM="sddm" ;;
    gnome)    RECOMMENDED_DM="gdm" ;;
    cinnamon|mate) RECOMMENDED_DM="lightdm" ;;
    xfce)     RECOMMENDED_DM="lightdm" ;;
    cosmic)   RECOMMENDED_DM="sddm" ;;  # COSMIC's maintainer recommends SDDM; cosmic-greeter is offered as a DM option below when COSMIC is chosen, but the author reports it does not work reliably (see the greeter/DM prompts).
    *)        RECOMMENDED_DM="sddm" ;;
esac

# =============================================================================
# DISPLAY MANAGER CHOICE: SDDM or LightDM
# =============================================================================
# AI (Claude, Sonnet 5, Medium) ADDITION: display manager is now a real,
# independent choice from desktop environment — either DM works with
# either DE, this just picks which is typically associated with which so
# the choice is informed rather than a coin flip.
echo ""
echo "${C_BOLD}${C_BLU}Choose display manager${C_RST} (works with any desktop environment — this"
echo "just picks which is typically paired with which; the recommended pairing"
echo "for your selected DE (${C_BOLD}${DESKTOP_ENV}${C_RST}) is ${C_GRN}${RECOMMENDED_DM}${C_RST}):"
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
while true; do
    if [ "$DESKTOP_ENV" = "cosmic" ]; then
        ask "Enter choice [1/2/3/4] (default: ${RECOMMENDED_DM}): "
        read -r DISPLAY_MANAGER_INPUT
        case "$DISPLAY_MANAGER_INPUT" in
            "")  note "Using recommended display manager: ${C_BOLD}${RECOMMENDED_DM}${C_RST}"; DISPLAY_MANAGER="$RECOMMENDED_DM"; break ;;
            1) DISPLAY_MANAGER="sddm"; break ;;
            2) DISPLAY_MANAGER="lightdm"; break ;;
            3) DISPLAY_MANAGER="gdm"; break ;;
            4) DISPLAY_MANAGER="cosmic-greeter"; break ;;
            *) echo "Please enter 1, 2, 3, or 4." >&2 ;;
        esac
    else
        ask "Enter choice [1/2/3] (default: ${RECOMMENDED_DM}): "
        read -r DISPLAY_MANAGER_INPUT
        case "$DISPLAY_MANAGER_INPUT" in
            "")  note "Using recommended display manager: ${C_BOLD}${RECOMMENDED_DM}${C_RST}"; DISPLAY_MANAGER="$RECOMMENDED_DM"; break ;;
            1) DISPLAY_MANAGER="sddm"; break ;;
            2) DISPLAY_MANAGER="lightdm"; break ;;
            3) DISPLAY_MANAGER="gdm"; break ;;
            *) echo "Please enter 1, 2, or 3." >&2 ;;
        esac
    fi
done
export DISPLAY_MANAGER

# AI (Claude, Sonnet 5, Medium) ADDITION — v3.2.0: LightDM needs an explicit
# greeter. Previously the script hard-attempted the Slick greeter and fell
# back to GTK with a fragile loop that could fail an install under `set -e`.
# Now it is an explicit install-time choice, offered only when LightDM was
# selected. All three greeters below ship as official Void packages, so no
# fallback dance is required — the choice is honored directly.
if [ "$DISPLAY_MANAGER" = "lightdm" ]; then
    echo ""
    echo "${C_BOLD}${C_BLU}Choose a LightDM greeter${C_RST}"
    echo "  ${C_BOLD}1)${C_RST} ${C_GRN}GTK Greeter (lightdm-gtk-greeter)${C_RST} — the default, plain and"
    echo "     reliable, minimal dependencies."
    echo "  ${C_BOLD}2)${C_RST} Slick Greeter (lightdm-slick-greeter) — Linux Mint style,"
    echo "     more polished appearance (GTK-based)."
    echo "  ${C_BOLD}3)${C_RST} WebKit2 Greeter (lightdm-webkit2-greeter) — HTML/JavaScript"
    echo "     themable (project development has slowed significantly;"
    echo "     largest dependency footprint of the three)."
    while true; do
        ask "Enter choice [1/2/3] (default 1: GTK): "
        read -r LIGHTDM_GREETER_INPUT
        case "$LIGHTDM_GREETER_INPUT" in
            ""|1) LIGHTDM_GREETER="gtk"; break ;;
            2) LIGHTDM_GREETER="slick"; break ;;
            3) LIGHTDM_GREETER="webkit2"; break ;;
            *) echo "Please enter 1, 2, or 3." >&2 ;;
        esac
    done
    if [ "$LIGHTDM_GREETER" = "slick" ]; then
        LIGHTDM_GREETER_PKG="lightdm-slick-greeter"
        LIGHTDM_GREETER_SESSION="lightdm-slick-greeter"
    elif [ "$LIGHTDM_GREETER" = "webkit2" ]; then
        LIGHTDM_GREETER_PKG="lightdm-webkit2-greeter"
        LIGHTDM_GREETER_SESSION="lightdm-webkit2-greeter"
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
# AI (Big Pickle) ADDITION — v3.2.0 [item 9]: Void does not run systemd,
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
echo ""
echo "${C_BOLD}${C_BLU}Choose session/seat management (logind)${C_RST}"
echo "  ${C_BOLD}1)${C_RST} ${C_GRN}elogind (Default)${C_RST} — the well-tested fork of systemd-logind;"
echo "     broadly required/compatible with GNOME, KDE, polkit auth."
echo "  ${C_BOLD}2)${C_RST} turnstile + seatd + acpid — the leaner alternative: turnstile for"
echo "     user sessions, seatd for graphical seat/input, acpid for ACPI"
echo "     power events. Avoids the logind runtime entirely; some software"
echo "     that hard-requires logind may not work."
while true; do
    ask "Enter choice [1/2] (default 1: elogind): "
    read -r LOGIND_INPUT
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
# Yes to match the prior always-installed behavior.
ask "Install OctoXBPS (graphical package manager + update notifier)? [Y/n]: "
read -r INSTALL_OCTOXBPS_INPUT
case "$INSTALL_OCTOXBPS_INPUT" in
    [nN]*) INSTALL_OCTOXBPS="false" ;;
    *) INSTALL_OCTOXBPS="true" ;;
esac
export INSTALL_OCTOXBPS

ask "Install Flatpak (+ Flathub)? [Y/n]: "
read -r INSTALL_FLATPAK_INPUT
case "$INSTALL_FLATPAK_INPUT" in
    [nN]*) INSTALL_FLATPAK="false" ;;
    *) INSTALL_FLATPAK="true" ;;
esac
export INSTALL_FLATPAK

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
echo ""
echo "Choose web browsers to install (each is independent — pick any"
echo "combination, or none at all):"
ask "Install Firefox? [Y/n]: "
read -r INSTALL_FIREFOX_INPUT
case "$INSTALL_FIREFOX_INPUT" in
    [nN]*) INSTALL_FIREFOX="false" ;;
    *) INSTALL_FIREFOX="true" ;;
esac
export INSTALL_FIREFOX

ask "Install Chromium? [Y/n]: "
read -r INSTALL_CHROMIUM_INPUT
case "$INSTALL_CHROMIUM_INPUT" in
    [nN]*) INSTALL_CHROMIUM="false" ;;
    *) INSTALL_CHROMIUM="true" ;;
esac
export INSTALL_CHROMIUM

ask "Install Vivaldi (proprietary, nonfree repo)? [y/N]: "
read -r INSTALL_VIVALDI_INPUT
case "$INSTALL_VIVALDI_INPUT" in
    [yY]*) INSTALL_VIVALDI="true" ;;
    *) INSTALL_VIVALDI="false" ;;
esac
export INSTALL_VIVALDI

ask "Install Falkon (KDE's browser, works fine standalone too)? [y/N]: "
read -r INSTALL_FALKON_INPUT
case "$INSTALL_FALKON_INPUT" in
    [yY]*) INSTALL_FALKON="true" ;;
    *) INSTALL_FALKON="false" ;;
esac
export INSTALL_FALKON

echo "NOTICE: Brave has no official Void package. If selected, it will only"
echo "be installed via Flatpak — and only if Flatpak was selected above. If"
echo "Flatpak wasn't selected, Brave will be skipped rather than reaching"
echo "for an unofficial third-party package repository."
ask "Install Brave? [y/N]: "
read -r INSTALL_BRAVE_INPUT
case "$INSTALL_BRAVE_INPUT" in
    [yY]*) INSTALL_BRAVE="true" ;;
    *) INSTALL_BRAVE="false" ;;
esac
export INSTALL_BRAVE

# AI (Claude, Sonnet 5, Medium) ADDITION: for any browser NOT selected above,
# offer to pre-create its isolated nodatacow subvolume anyway (same
# treatment already given to every installed browser — see
# provision_browser_subvol in Stage 2) so that if it's installed manually
# after the fact, its profile lands on an isolated subvolume from the
# start instead of mixing into @home. Asked individually per browser
# (not a single bulk yes/no) since the person may only care about this for
# one or two of them.
echo ""
echo "For any browser you did NOT select above, you can still pre-create its"
echo "isolated profile subvolume now, in case you install that browser"
echo "manually later:"
PROVISION_FIREFOX_SUBVOL="false"
if [ "$INSTALL_FIREFOX" != "true" ]; then
    ask "Pre-create Firefox's profile subvolume anyway? [y/N]: "
    read -r _pfs_input
    case "$_pfs_input" in [yY]*) PROVISION_FIREFOX_SUBVOL="true" ;; esac
fi
export PROVISION_FIREFOX_SUBVOL

PROVISION_CHROMIUM_SUBVOL="false"
if [ "$INSTALL_CHROMIUM" != "true" ]; then
    ask "Pre-create Chromium's profile subvolume anyway? [y/N]: "
    read -r _pcs_input
    case "$_pcs_input" in [yY]*) PROVISION_CHROMIUM_SUBVOL="true" ;; esac
fi
export PROVISION_CHROMIUM_SUBVOL

PROVISION_VIVALDI_SUBVOL="false"
if [ "$INSTALL_VIVALDI" != "true" ]; then
    ask "Pre-create Vivaldi's profile subvolume anyway? [y/N]: "
    read -r _pvs_input
    case "$_pvs_input" in [yY]*) PROVISION_VIVALDI_SUBVOL="true" ;; esac
fi
export PROVISION_VIVALDI_SUBVOL

PROVISION_FALKON_SUBVOL="false"
if [ "$INSTALL_FALKON" != "true" ]; then
    ask "Pre-create Falkon's profile subvolume anyway? [y/N]: "
    read -r _pfks_input
    case "$_pfks_input" in [yY]*) PROVISION_FALKON_SUBVOL="true" ;; esac
fi
export PROVISION_FALKON_SUBVOL

PROVISION_BRAVE_SUBVOL="false"
if [ "$INSTALL_BRAVE" != "true" ]; then
    ask "Pre-create Brave's profile subvolume anyway? [y/N]: "
    read -r _pbrs_input
    case "$_pbrs_input" in [yY]*) PROVISION_BRAVE_SUBVOL="true" ;; esac
fi
export PROVISION_BRAVE_SUBVOL

# AI (Claude, Sonnet 5, Medium) ADDITION [item 9]: this is the exact case that
# prompted the retrofit — Podman rootless, Podman rootful, and Docker are
# three SEPARATE, independent container-backend choices, each asked one
# at a time below. You are not choosing between them; you can say yes to
# any combination (all three, any two, one, or none). If you only need
# one backend, it's fine to say no to the other two when they're asked.
echo ""
echo "Container backends — Podman rootless, Podman rootful, and Docker are"
echo "three independent choices below (any combination is fine, including"
echo "all three or none)."
# AI (Big Pickle) CHANGE — v3.3.0-beta2 [OPT-DEFAULTS]: Podman rootless,
# Podman rootful, Docker, and virtualization are now all default-OFF.
# A bare "just press Enter" run therefore installs a lean base system —
# the container/virtualization stack must be explicitly opted into per
# prompt. This matches the "assume no background daemons unless asked
# for" posture already applied to the docker-group and distrobox prompts.
ask "Install Podman rootless? [y/N]: "
read -r INSTALL_PODMAN_ROOTLESS_INPUT
case "$INSTALL_PODMAN_ROOTLESS_INPUT" in
    [yY]*) INSTALL_PODMAN_ROOTLESS="true" ;;
    *) INSTALL_PODMAN_ROOTLESS="false" ;;
esac
export INSTALL_PODMAN_ROOTLESS

ask "Install Podman rootful capability? [y/N]: "
read -r INSTALL_PODMAN_ROOTFUL_INPUT
case "$INSTALL_PODMAN_ROOTFUL_INPUT" in
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
    [yY]*) INSTALL_DOCKER="true" ;;
    *) INSTALL_DOCKER="false" ;;
esac
if [ "$INSTALL_DOCKER" = "true" ]; then
    ask "Add your user to the docker group (root-equivalent access, run docker without sudo)? [y/N]: "
    read -r DOCKER_GROUP_ADD_INPUT
    case "$DOCKER_GROUP_ADD_INPUT" in
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
        [yY]*) INSTALL_DISTROBOX="true" ;;
        *) INSTALL_DISTROBOX="false" ;;
    esac
else
    INSTALL_DISTROBOX="false"
fi
export INSTALL_DISTROBOX

# AI (Claude, Sonnet 5, Medium) CHANGE — v3.1.0-beta1 [DISTROBOX-3]: Third release-track option
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
        ask "Enter choice [1/2/3]: "
        read -r DISTROBOX_TRACK_INPUT
        case "$DISTROBOX_TRACK_INPUT" in
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
        ask "Enter choice [1/2]: "
        read -r DISTROBOX_ENGINE_INPUT
        case "$DISTROBOX_ENGINE_INPUT" in
            ""|1) DISTROBOX_DEFAULT_ENGINE="podman"; break ;;
            2) DISTROBOX_DEFAULT_ENGINE="docker"; break ;;
            *) echo "Please enter 1 or 2." >&2 ;;
        esac
    done
else
    DISTROBOX_DEFAULT_ENGINE=""
fi
export DISTROBOX_DEFAULT_ENGINE

ask "Install virtualization (qemu/libvirt/virt-manager + br0 bridge)? [y/N]: "
read -r INSTALL_VIRT_INPUT
case "$INSTALL_VIRT_INPUT" in
    [yY]*) INSTALL_VIRT="true" ;;
    *) INSTALL_VIRT="false" ;;
esac
export INSTALL_VIRT

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
echo "${C_YLW}${C_BOLD}  When ready, press Enter to continue.${C_RST}"
read -r -p "Press Enter once ready to continue: " _
# End of the skipped-on-resume interactive configuration block.
fi

# =============================================================================
# AI (Big Pickle) CHANGE — v3.2.0 [RESUME]: NIC detection, disk enumeration,
# disk selection, the already-installed guard, and the ERASE confirmation are
# all skipped on a resumed run — the target disk and NIC were already chosen
# in the interrupted run and are restored from the state file.
# =============================================================================
if [ "$RESUME" != "1" ]; then
DETECTED_NIC=""

for _nic_candidate in $(ls /sys/class/net/ 2>/dev/null); do
    [ -e "/sys/class/net/${_nic_candidate}/device" ] || continue
    [ -d "/sys/class/net/${_nic_candidate}/wireless" ] && continue
    if [ "$(cat "/sys/class/net/${_nic_candidate}/carrier" 2>/dev/null)" = "1" ]; then
        DETECTED_NIC="$_nic_candidate"
        break
    fi
done

if [ -z "$DETECTED_NIC" ]; then
    for _nic_candidate in $(ls /sys/class/net/ 2>/dev/null); do
        [ -e "/sys/class/net/${_nic_candidate}/device" ] || continue
        [ -d "/sys/class/net/${_nic_candidate}/wireless" ] && continue
        case "$(readlink -f "/sys/class/net/${_nic_candidate}/device" 2>/dev/null)" in
            *usb*) DETECTED_NIC="$_nic_candidate"; break ;;
        esac
    done
fi

if [ -n "$DETECTED_NIC" ]; then
    export NET_INTERFACE_MATCH="$DETECTED_NIC"
else
    echo "WARNING: could not auto-detect a physical ethernet interface — falling back to 'enp*' (may not match any real device)." >&2
    export NET_INTERFACE_MATCH="enp*"
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

# =============================================================================
# AI (Big Pickle) ADDITION — v3.2.0 [item 7]: RE-RUN / ALREADY-INSTALLED GUARD
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
    # Pickle) v3.3.0-beta4): the chosen disk is displayed prominently right
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
# AI (Big Pickle) ADDITION — v3.3.0-beta4 [CONFIRM]: post-ERASE, pre-partition
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
    case "$LIGHTDM_GREETER_SESSION" in
        lightdm-slick-greeter)   _rev_dm="LightDM (Slick greeter)" ;;
        lightdm-webkit2-greeter) _rev_dm="LightDM (WebKit2 greeter)" ;;
        lightdm-gtk-greeter)     _rev_dm="LightDM (GTK greeter)" ;;
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
echo "${C_BOLD}  Primary user     :${C_RST} ${TARGET_USER}  (login shell: ${_rev_shell})"
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

# AI (Big Pickle) ADDITION — v3.3.0 [MIRROR]: these defaults are only applied
# when no mirror was chosen in the earlier prompt step (e.g. on a resumed run
# that skipped it); otherwise the user's regional selection is preserved.
REPO_PRIMARY="${REPO_PRIMARY:-https://mirrors.summithq.com/voidlinux/current}"
REPO_BACKUP1="${REPO_BACKUP1:-https://repo-fastly.voidlinux.org/current}"
REPO_BACKUP2="${REPO_BACKUP2:-https://repo-default.voidlinux.org/current}"

LIVECD_SYNC_OK=0
# AI (Big Pickle) ADDITION — v3.3.0-beta7 [YUBIKEY]: when YubiKey hmac-sha1
# unlock was requested, the live medium also needs the ykpers C tools
# (ykpersonalize + ykchalresp) to program the slot and compute the HMAC key.
# They are added to the sync (and to the prereq list below) only in that case.
YK_LIVE_PKGS=""
[ "$YK_MODE" = "hmac-sha1" ] && YK_LIVE_PKGS=" ykpers"
if [ "$DRY_RUN" = "1" ]; then
    # AI (Big Pickle) ADDITION — v3.3.0-beta3 [DRY-RUN]: a plan run must not
    # modify the live environment (xbps-install -Syu would sync/upgrade and
    # install gptfdisk/parted/btrfs-progs/openssl into the running medium).
    # Pretend success so the flow reaches the plan printout at the partition
    # boundary; the packages are not actually installed.
    echo "==> [DRY-RUN] Skipping live-CD package sync (would install gptfdisk/parted/btrfs-progs/openssl${YK_LIVE_PKGS} into the live env)."
    LIVECD_SYNC_OK=1
else
for REPO_ATTEMPT in "$REPO_PRIMARY" "$REPO_BACKUP1" "$REPO_BACKUP2"; do
    echo "==> Attempting live-CD package sync against repository: ${REPO_ATTEMPT}"
    if xbps-install -Syu -R "$REPO_ATTEMPT" xbps -y && xbps-install -R "$REPO_ATTEMPT" gptfdisk parted btrfs-progs openssl${YK_LIVE_PKGS} -y; then
        LIVECD_SYNC_OK=1
        echo "==> Live-CD package sync succeeded using: ${REPO_ATTEMPT}"
        break
    fi
    echo "==> Live-CD package sync attempt against ${REPO_ATTEMPT} failed — trying next repository, if any." >&2
done
fi

if [ "$LIVECD_SYNC_OK" -ne 1 ]; then
    echo "FATAL: live-CD package sync failed against all configured repositories (primary + both backups)." >&2
    exit 1
fi

# AI (Big Pickle) ADDITION — v3.3.0 [PREREQ], AI (Big Pickle) CORRECTION —
# v3.3.0-beta4 [PREREQ-CURL]: after the live sync the tools this installer's
# OUTER (live-CD) stage invokes directly must actually exist on the medium —
# the sync just installed gptfdisk/btrfs-progs/openssl, so the next step
# (destructive partitioning) should not be reached without them. Tools that
# are only used INSIDE the chroot are deliberately excluded from this list
# (they get installed INTO the target via xbps, not the live env). NOTE the
# deliberate exclusion here: `curl` is NOT an outer-stage tool — every curl
# use is inside the chroot, and the live-CD sync never installs curl into the
# medium, so a Void Live ISO that ships without curl (as some do) made this
# prereq FATAL even though the sync "succeeded". It is removed below.
for _prereq in sgdisk mkfs.fat mkfs.btrfs btrfs parted openssl mount umount \
               chroot lsblk blkid xbps-install${YK_LIVE_PKGS:+ ykpersonalize ykchalresp}; do
    if ! command -v "$_prereq" >/dev/null 2>&1; then
        echo "FATAL: required live-CD command not found: '${_prereq}'." >&2
        echo "       The live-CD package sync reported success, but this tool is missing." >&2
        exit 1
    fi
done
unset _prereq

# AI (Big Pickle) ADDITION — v3.3.0-beta7 [YUBIKEY]: YubiKey hmac-sha1
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
        if ! ykpersonalize -${YK_SLOT} -ochal-resp -ochal-hmac -ohmac-lt64 -oserial-api-visible${YK_TOUCH_OPT} -y 2>&1; then
            echo "FATAL: ykpersonalize failed to program slot ${YK_SLOT}. Check the YubiKey is plugged in (no hub pass-through) and not read-only." >&2
            exit 1
        fi
        YK_CHALLENGE=$(head -c 20 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 40)
        [ -z "$YK_CHALLENGE" ] && { echo "FATAL: could not generate the 40-hex YubiKey challenge." >&2; exit 1; }
        YK_KEY=$(ykchalresp -${YK_SLOT} "$YK_CHALLENGE" 2>&1)
        [ -z "$YK_KEY" ] && { echo "FATAL: ykchalresp failed to compute the HMAC response. Enrollment incomplete." >&2; exit 1; }
        echo "==> Slot ${YK_SLOT} programmed and LUKS key envelope computed (key held in memory only)."
        unset YK_TOUCH_OPT YK_ENROLL_CONFIRM
    fi
fi

# AI (Big Pickle) CHANGE — v3.2.0 [RESUME]: Password hashing is skipped on a
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
# AI (Big Pickle) ADDITION — v3.2.0 [RESUME]: PERSIST CONFIGURATION STATE.
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
               USER_SHELL USER_SHELL_PKG \
               LIGHTDM_GREETER LIGHTDM_GREETER_PKG LIGHTDM_GREETER_SESSION \
               LIMINE_WALLPAPER LIMINE_WALLPAPER_STYLE \
               SESSION_STACK ENABLE_SNAPSHOT_AUDIO \
               LOCALE LOCALE_CODESET TIMEZONE SWAP_BACKEND SWAPFILE_MODE ENABLE_HIBERNATION SWAPFILE_SIZE \
               ENCRYPT \
               YK_MODE YK_FALLBACK YK_SLOT YK_CHALLENGE YK_TOUCH \
               REPO_PRIMARY REPO_BACKUP1 REPO_BACKUP2 \
               DISTROBOX_TRACK DISTROBOX_DEFAULT_ENGINE INSTALL_OCTOXBPS \
               INSTALL_FLATPAK INSTALL_FIREFOX INSTALL_CHROMIUM \
               INSTALL_VIVALDI INSTALL_FALKON INSTALL_BRAVE \
               INSTALL_PODMAN INSTALL_PODMAN_ROOTLESS INSTALL_PODMAN_ROOTFUL \
               INSTALL_DOCKER DOCKER_GROUP_ADD INSTALL_DISTROBOX INSTALL_VIRT \
               PROVISION_FIREFOX_SUBVOL PROVISION_CHROMIUM_SUBVOL \
               PROVISION_VIVALDI_SUBVOL PROVISION_FALKON_SUBVOL \
               PROVISION_BRAVE_SUBVOL DISK PART_EFI PART_SYS; do
        printf 'export %s=%q\n' "$_sv" "${!_sv}"
    done
} > "$STATE_FILE"
chmod 600 "$STATE_FILE"
echo "==> Install state saved to ${STATE_FILE} (resumable later with '$0 -r')."
STAGE_CONTEXT="STAGE1:partition"
jl "Config persisted to $STATE_FILE (DISK=${DISK}, bootloader=${BOOTLOADER})"
unset _sv

# AI (Big Pickle) ADDITION — v3.3.0-beta3 [DRY-RUN]: if --dry-run/-d/-n was
# given, everything above has run interactively (all prompts, no disk touched,
# no live-env package sync, no chroot). Print the complete as-planned summary
# of what a real run WOULD do — destination disk/partitions, bootloader,
# desktop/DM, session stack, kernel mode, wallpaper resolution — then stop at
# the destructive partition boundary with exit 0. Nothing on disk is modified.
if [ "$DRY_RUN" = "1" ]; then
    echo ""
    echo "${C_MAG}========================= DRY-RUN PLAN =========================${C_RST}"
    echo "  Mode                  : --dry-run — no disk changes performed."
    echo "  Target disk           : ${DISK:-<not selected>}"
    echo "  Destructive steps     : sgdisk -Z + -og, ESP(+${EFI_PART_SIZE}) + LINUX parts,"
    echo "                          mkfs.fat -F32 EFI, mkfs.btrfs -f, subvolume layout."
    echo "  Bootloader            : ${BOOTLOADER:-<unset>}"
    if [ "$BOOTLOADER" = "limine" ]; then
        echo "  Kernel access         : ${KERNEL_MODE:-<unset>} (Limine)"
        echo "  Wallpaper             : ${LIMINE_WALLPAPER:-none}${LIMINE_WALLPAPER_STYLE:+ (style=${LIMINE_WALLPAPER_STYLE})}"
    fi
    echo "  Desktop / DM          : ${DESKTOP_ENV:-<unset>} / ${DISPLAY_MANAGER:-<unset>}"
    echo "  Session stack         : ${SESSION_STACK:-<unset>}"
    echo "  Login shell           : ${USER_SHELL:-<unset>}"
    echo "  Locale / Timezone     : ${LOCALE:-<unset>} / ${TIMEZONE:-<unset>}"
    echo "  Repo (primary)        : ${REPO_PRIMARY:-<unset>}"
    echo "  Swap / Hibernation    : ${SWAP_BACKEND:-<unset>} / ${ENABLE_HIBERNATION:-<unset>}"
    echo "  Encryption            : ${ENCRYPT:-no}${ENCRYPT:+$([ "$ENCRYPT" = "yes" ] && { [ "$YK_MODE" = "hmac-sha1" ] && echo " (LUKS2 full-disk + YubiKey hmac-sha1, fallback=$YK_FALLBACK)" || echo " (LUKS2 full-disk, passphrase at boot)"; } || true)}"
    echo "  Accounts model        : ${ACCOUNT_MODEL:-<unset>}"
    echo "=============================================================="
    echo "  Nothing was written to disk. Re-run WITHOUT --dry-run to install for real."
    echo ""
    # A dry-run persists a state file earlier (so the plan data was collected);
    # remove it so a later real run isn't offered a pointless "resume".
    rm -f "$STATE_FILE" 2>/dev/null || true
    exit 0
fi

# AI (Big Pickle) CHANGE — v3.2.0 [RESUME]: The destructive partitioning and
# filesystem creation below run ONLY on a fresh install. A resumed run reuses
# the existing partition table and filesystems (the installer's own, from the
# interrupted run) — the target's *contents* are reset separately further on.
#
# AI (Big Pickle) ADDITION — v3.3.0-beta6 [ENCRYPT]: when encryption is
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
CRYPT_DEV="/dev/mapper/void-root"

if [ "$RESUME" != "1" ]; then
    # Clear disk maps and slice target partitions
    sgdisk -Z "$DISK" && sgdisk -og "$DISK"
    sgdisk -n "1::+${EFI_PART_SIZE}" -t 1:ef00 -c 1:'ESP' "$DISK"
    sgdisk -n 2:: -t 2:8300 -c 2:'LINUX' "$DISK"

    partprobe "$DISK"
    sleep 2

    if [ "$ENCRYPT" = "yes" ]; then
        # Fresh: create the LUKS2 container from the typed passphrase. Fed
        # via stdin so it never appears on the command line or in the
        # process list. The ESP is formatted after this.
        echo ""
        echo "==> Formatting partition 2 as a LUKS2 container (cryptsetup)"
        cryptsetup luksFormat --type luks2 -q --key-file=- "$PART_SYS" <<<"$ENCRYPT_PASSPHRASE"
        echo "==> Opening LUKS2 container ${PART_SYS} -> ${CRYPT_DEV}"
        cryptsetup luksOpen --key-file=- "$PART_SYS" void-root <<<"$ENCRYPT_PASSPHRASE"
        BTRFS_DEV="$CRYPT_DEV"
        # AI (Big Pickle) ADDITION — v3.3.0-beta7 [YUBIKEY]: bind the YubiKey
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
            cryptsetup luksAddKey "$PART_SYS" --key-file=- --new-keyfile="$YK_KEY_FILE" <<<"$ENCRYPT_PASSPHRASE"
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
    mkfs.btrfs -f -L VOID "$BTRFS_DEV"
    mount -v "$BTRFS_DEV" /mnt
else
    # Resume: defensively clear any leftover mount on /mnt (e.g. from a crash
    # that never ran the cleanup trap), then mount the top-level Btrfs tree
    # (subvolid=5 — explicitly NOT the default subvolume) so the subvolumes
    # can be deleted/recreated below.
    umount -l /mnt 2>/dev/null || true

    if [ "$ENCRYPT" = "yes" ]; then
        # Resume: the container exists but the mapper is closed. With YubiKey
        # unlock enabled, prefer unlocking via the hmac-sha1 response (the
        # YubiKey is still at hand on the live medium); only a genuine YubiKey
        # failure falls back to the typed passphrase, and only when a fallback
        # slot exists. With YK_FALLBACK=no (possession-only) the YubiKey is the
        # only way in.
        if [ "$YK_MODE" = "hmac-sha1" ]; then
            YK_KEY_FILE="/tmp/void-yubikey-key"
            YK_KEY=$(ykchalresp -${YK_SLOT} "$YK_CHALLENGE" 2>&1)
            [ -n "$YK_KEY" ] || { echo "FATAL: YubiKey unlock failed (ykchalresp did not return a response)." >&2; exit 1; }
            printf '%s' "$YK_KEY" > "$YK_KEY_FILE"
            chmod 600 "$YK_KEY_FILE"
            echo "==> Opening LUKS2 container ${PART_SYS} -> ${CRYPT_DEV} (YubiKey)"
            if ! cryptsetup luksOpen --key-file="$YK_KEY_FILE" "$PART_SYS" void-root; then
                shred -u "$YK_KEY_FILE" 2>/dev/null || rm -f "$YK_KEY_FILE"
                unset YK_KEY YK_KEY_FILE
                if [ "$YK_FALLBACK" = "yes" ]; then
                    echo "   YubiKey unlock failed (absent/wrong?). Falling back to typed passphrase." >&2
                    echo ""
                    echo "Enter the passphrase to unlock ${PART_SYS} (LUKS2):"
                    read -r -s ENCRYPT_PASSPHRASE
                    echo
                    [ -n "$ENCRYPT_PASSPHRASE" ] || { echo "FATAL: empty passphrase." >&2; exit 1; }
                    cryptsetup luksOpen --key-file=- "$PART_SYS" void-root <<<"$ENCRYPT_PASSPHRASE"
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
            cryptsetup luksOpen --key-file=- "$PART_SYS" void-root <<<"$ENCRYPT_PASSPHRASE"
            unset ENCRYPT_PASSPHRASE
        fi
        BTRFS_DEV="$CRYPT_DEV"
        jl "LUKS2 mapper re-opened for resume: $PART_SYS -> $BTRFS_DEV"
    fi

    mount -v -o subvolid=5 "$BTRFS_DEV" /mnt
fi
# AI (Big Pickle) NOTE — Open Item #7 DECIDED (v3.3.0): @grub is KEPT as a
# dedicated top-level subvolume/mountpoint for BOOTLOADER=grub only (gated at
# the SUBVOL_LIST, mkdir, mount, fstab, and teardown-umount sites). Rationale:
# bootloader state is recovery-critical, so isolating /boot/grub on its own
# subvolume makes it immune to Snapper rollbacks of the @ root. Limine
# consumes nothing from it and under BOOTLOADER=limine no @grub subvolume is
# created at all. This closes former CHANGELOG Open Item #7 — no removal is
# planned.
SUBVOL_LIST="@ @home @opt @srv @snapshots @cache @log @spool @tmp @usercache @root"
[ "$INSTALL_VIRT" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @libvirt"
[ "$INSTALL_FLATPAK" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @flatpak"
[ "$INSTALL_DOCKER" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @docker"
[ "$INSTALL_PODMAN_ROOTFUL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @containers"
[ "$INSTALL_PODMAN_ROOTLESS" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @containers-user"
# AI (Claude, Sonnet 5, Medium) CHANGE — v3.2.0: the display-manager state
# subvolume is now created conditionally, matching whichever DM was actually
# chosen, instead of @sddm being unconditional. @sddm exists only when
# DISPLAY_MANAGER=sddm (its per-user runtime dir), and @lightdm exists only
# when DISPLAY_MANAGER=lightdm (persists LightDM's per-user state/history
# across logins; gated the same way). The fstab then mounts the matching
# one; the unselected DM's subvolume is never created at all, so no dead
# subvolume is left behind on the partition.
[ "$DISPLAY_MANAGER" = "sddm" ] && SUBVOL_LIST="$SUBVOL_LIST @sddm"
[ "$DISPLAY_MANAGER" = "lightdm" ] && SUBVOL_LIST="$SUBVOL_LIST @lightdm"
# AI (Big Pickle) CHANGE — v3.2.0 [item 5]: @grub exists only
# for BOOTLOADER=grub. The old script created and mounted a dedicated @grub
# subvolume at /boot/grub regardless of bootloader; under BOOTLOADER=limine
# nothing ever reads /boot/grub (Limine reads everything straight off the
# ESP), so a Limine install would carry a dead, empty /boot/grub mount.
# Gated now so a Limine install leaves no grub directory at all.
[ "$BOOTLOADER" = "grub" ] && SUBVOL_LIST="$SUBVOL_LIST @grub"
# AI (Big Pickle) ADDITION — v3.2.0 [SWAP]: @swap subvolume only exists when a
# disk-backed swapfile backend was chosen (swapfile or both); zram-only and
# no-swap installs leave no @swap subvolume at all.
[ "$SWAPFILE_MODE" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @swap"
# AI (Claude, Sonnet 5, Medium) CHANGE: @mozilla/@chromium moved out of the
# unconditional base list — browsers are real toggles now (see WEB BROWSER
# SELECTION in Stage 1). Each subvolume is created if that browser is
# being installed OR if its subvolume was explicitly pre-provisioned
# anyway for later manual installation.
# v3.2.0 (Firefox layout fix): modern Firefox stores its PROFILE under
# ~/.config/mozilla/firefox and its CACHE under ~/.cache/mozilla/firefox
# (XDG base-dir layout), NOT ~/.mozilla. @mozilla now backs
# ~/.config/mozilla (nodatacow profile+sqlite) and the new @mozilla-cache
# backs ~/.cache/mozilla (nodatacow cache). Both created whenever Firefox
# is installed OR explicitly pre-provisioned for later manual install.
if [ "$INSTALL_FIREFOX" = "true" ] || [ "$PROVISION_FIREFOX_SUBVOL" = "true" ]; then
    SUBVOL_LIST="$SUBVOL_LIST @mozilla @mozilla-cache"
fi
[ "$INSTALL_CHROMIUM" = "true" ] || [ "$PROVISION_CHROMIUM_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @chromium"
[ "$INSTALL_VIVALDI" = "true" ] || [ "$PROVISION_VIVALDI_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @vivaldi"
[ "$INSTALL_FALKON" = "true" ] || [ "$PROVISION_FALKON_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @falkon"
[ "$INSTALL_BRAVE" = "true" ] || [ "$PROVISION_BRAVE_SUBVOL" = "true" ] && SUBVOL_LIST="$SUBVOL_LIST @brave"

# AI (Big Pickle) ADDITION — v3.2.0 [RESUME]: SUBVOLUME RESET.
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
    btrfs subvolume create /mnt/$subv
done
umount -v /mnt

BTRFS_OPTS="noatime,compress=zstd:1"
mount -vo $BTRFS_OPTS,subvol=@ "$BTRFS_DEV" /mnt

mkdir -vp /mnt/home /mnt/.snapshots /mnt/opt /mnt/srv /mnt/boot/efi
[ "$BOOTLOADER" = "grub" ] && mkdir -vp /mnt/boot/grub
mkdir -vp /mnt/var/cache /mnt/var/log /mnt/var/spool /mnt/var/tmp
# AI (Big Pickle) CHANGE — v3.2.0 [SWAP]: /var/swap only created when a disk
# swapfile backend was chosen (swapfile or both).
[ "$SWAPFILE_MODE" = "true" ] && mkdir -vp /mnt/var/swap
[ "$DISPLAY_MANAGER" = "sddm" ] && mkdir -vp /mnt/var/lib/sddm
[ "$DISPLAY_MANAGER" = "lightdm" ] && mkdir -vp /mnt/var/lib/lightdm
mkdir -vp /mnt/root
[ "$INSTALL_VIRT" = "true" ] && mkdir -vp /mnt/var/lib/libvirt
[ "$INSTALL_FLATPAK" = "true" ] && mkdir -vp /mnt/var/lib/flatpak
[ "$INSTALL_DOCKER" = "true" ] && mkdir -vp /mnt/var/lib/docker
[ "$INSTALL_PODMAN_ROOTFUL" = "true" ] && mkdir -vp /mnt/var/lib/containers

# AI (Big Pickle) FIX — v3.3.0-beta4 [NODATACOW]: the churn-heavy var
# subvols are made nodatacow via their MOUNT OPTIONS (below) + fstab. A
# `chattr +C` is deliberately NOT used here: whether run pre-mount (shadowed
# the instant the subvolume mounts over its mountpoint dir) or post-mount (it
# would touch the covered mountpoint inode, not the subvolume), it cannot take
# effect on a Btrfs subvolume root. The mount/fstab `nodatacow,compress=none`
# options for @srv/@cache/@log/@spool/@tmp/@libvirt are the real mechanism.

mount -vo $BTRFS_OPTS,subvol=@home "$BTRFS_DEV" /mnt/home
mount -vo $BTRFS_OPTS,subvol=@opt "$BTRFS_DEV" /mnt/opt
mount -vo noatime,nodatacow,compress=none,subvol=@srv "$BTRFS_DEV" /mnt/srv
mount -vo $BTRFS_OPTS,subvol=@snapshots "$BTRFS_DEV" /mnt/.snapshots
mount -vo noatime,nodatacow,compress=none,subvol=@cache "$BTRFS_DEV" /mnt/var/cache
if [ "$DISPLAY_MANAGER" = "sddm" ]; then
    mount -vo $BTRFS_OPTS,subvol=@sddm "$BTRFS_DEV" /mnt/var/lib/sddm
elif [ "$DISPLAY_MANAGER" = "lightdm" ]; then
    mount -vo $BTRFS_OPTS,subvol=@lightdm "$BTRFS_DEV" /mnt/var/lib/lightdm
fi
if [ "$INSTALL_VIRT" = "true" ]; then
    mount -vo noatime,nodatacow,compress=none,subvol=@libvirt "$BTRFS_DEV" /mnt/var/lib/libvirt
fi
mount -vo noatime,nodatacow,compress=none,subvol=@log "$BTRFS_DEV" /mnt/var/log
mount -vo noatime,nodatacow,compress=none,subvol=@spool "$BTRFS_DEV" /mnt/var/spool
mount -vo noatime,nodatacow,compress=none,subvol=@tmp "$BTRFS_DEV" /mnt/var/tmp
[ "$BOOTLOADER" = "grub" ] && mount -vo $BTRFS_OPTS,subvol=@grub "$BTRFS_DEV" /mnt/boot/grub

[ "$INSTALL_FLATPAK" = "true" ] && mount -vo $BTRFS_OPTS,subvol=@flatpak "$BTRFS_DEV" /mnt/var/lib/flatpak
[ "$INSTALL_DOCKER" = "true" ] && mount -vo $BTRFS_OPTS,subvol=@docker "$BTRFS_DEV" /mnt/var/lib/docker
[ "$INSTALL_PODMAN_ROOTFUL" = "true" ] && mount -vo $BTRFS_OPTS,subvol=@containers "$BTRFS_DEV" /mnt/var/lib/containers
mount -vo $BTRFS_OPTS,subvol=@root "$BTRFS_DEV" /mnt/root

# AI (Big Pickle) CHANGE — v3.2.0 [SWAP]: @swap mounted + made nodatacow only
# when a disk swapfile backend (swapfile or both) was chosen. The mount is
# nodatacow,compress=none (a swapfile cannot live on a COW/compressed
# subtree), and `btrfs filesystem mkswapfile` later sets nodatacow on the
# swapfile itself — no `chattr +C` is needed or effective here.
if [ "$SWAPFILE_MODE" = "true" ]; then
    mount -vo defaults,noatime,nodatacow,compress=none,subvol=@swap "$BTRFS_DEV" /mnt/var/swap
fi
mount -v "$PART_EFI" /mnt/boot/efi

ARCH="x86_64"

mkdir -p /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/

BOOTSTRAP_OK=0
for REPO_ATTEMPT in "$REPO_PRIMARY" "$REPO_BACKUP1" "$REPO_BACKUP2"; do
    echo "==> Attempting base-system bootstrap against repository: ${REPO_ATTEMPT}"
    if XBPS_ARCH=$ARCH xbps-install -Suv -R "$REPO_ATTEMPT" -r /mnt base-system btrfs-progs linux-mainline glibc-locales -y; then
        BOOTSTRAP_OK=1
        echo "==> Bootstrap succeeded using: ${REPO_ATTEMPT}"
        break
    fi
    echo "==> Bootstrap attempt against ${REPO_ATTEMPT} failed — trying next repository, if any." >&2
done

if [ "$BOOTSTRAP_OK" -ne 1 ]; then
    echo "FATAL: base-system bootstrap failed against all configured repositories (primary + both backups)." >&2
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

    # v3.1.0 corrective addition, confirmed against a real
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
ESP_PARTUUID=$(lsblk -no PARTUUID "$PART_EFI")
BTRFS_PARTUUID=$(lsblk -no PARTUUID "$PART_SYS")
SYSPREFIX_ESP="guid(${ESP_PARTUUID})"
SYSPREFIX_BTRFS="guid(${BTRFS_PARTUUID})"

# AI (Big Pickle) CHANGE — v3.2.0 [SWAP]: the Btrfs-native swapfile is created
# only for a disk swapfile backend; its size honors the Stage 1 choice.
if [ "$SWAPFILE_MODE" = "true" ]; then
    rm -f /mnt/var/swap/swapfile
    btrfs filesystem mkswapfile --size "${SWAPFILE_SIZE}" /mnt/var/swap/swapfile
    mkswap -L SWAP /mnt/var/swap/swapfile
fi

cat > /mnt/etc/fstab << EOF
UUID=$BTRFS_UUID /                btrfs noatime,compress=zstd:1,subvol=@ 0 0
UUID=$BTRFS_UUID /home            btrfs noatime,compress=zstd:1,subvol=@home 0 0
UUID=$BTRFS_UUID /.snapshots      btrfs noatime,compress=zstd:1,subvol=@snapshots 0 0
UUID=$BTRFS_UUID /opt             btrfs noatime,compress=zstd:1,subvol=@opt 0 0
UUID=$BTRFS_UUID /srv             btrfs noatime,nodatacow,compress=none,subvol=@srv 0 0
UUID=$BTRFS_UUID /var/cache       btrfs noatime,nodatacow,compress=none,subvol=@cache 0 0
UUID=$BTRFS_UUID /var/log         btrfs noatime,nodatacow,compress=none,subvol=@log 0 0
UUID=$BTRFS_UUID /var/spool       btrfs noatime,nodatacow,compress=none,subvol=@spool 0 0
tmpfs            /tmp             tmpfs defaults,noatime,mode=1777 0 0
tmpfs            /var/tmp         tmpfs defaults,noatime,mode=1777 0 0
UUID=$EFI_UUID   /boot/efi        vfat  defaults,noatime 0 2
EOF

# AI (Big Pickle) ADDITION — v3.3.0-beta6 [ENCRYPT]: /etc/crypttab tells
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
        # AI (Big Pickle) ADDITION — v3.3.0-beta7 [YUBIKEY]: with YubiKey
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
        echo "void-root UUID=$LUKS_UUID none luks,keyscript=/usr/local/sbin/void-reveal-yubikey-key" > /mnt/etc/crypttab
    else
        echo "void-root UUID=$LUKS_UUID none luks" > /mnt/etc/crypttab
    fi
fi

# AI (Big Pickle) CHANGE — v3.2.0 [SWAP]: fstab swap entries now appear only
# when a disk swapfile backend (swapfile or both) was chosen.
if [ "$SWAPFILE_MODE" = "true" ]; then
    echo "UUID=$BTRFS_UUID /var/swap        btrfs noatime,nodatacow,subvol=@swap 0 0" >> /mnt/etc/fstab
    echo "/var/swap/swapfile               none  swap  defaults                  0 0" >> /mnt/etc/fstab
fi

if [ "$INSTALL_VIRT" = "true" ]; then
    echo "UUID=$BTRFS_UUID /var/lib/libvirt btrfs noatime,nodatacow,subvol=@libvirt 0 0" >> /mnt/etc/fstab
fi
if [ "$INSTALL_FLATPAK" = "true" ]; then
    echo "UUID=$BTRFS_UUID /var/lib/flatpak    btrfs noatime,compress=zstd:1,subvol=@flatpak 0 0" >> /mnt/etc/fstab
fi
if [ "$INSTALL_DOCKER" = "true" ]; then
    echo "UUID=$BTRFS_UUID /var/lib/docker     btrfs noatime,compress=zstd:1,subvol=@docker 0 0" >> /mnt/etc/fstab
fi
if [ "$INSTALL_PODMAN_ROOTFUL" = "true" ]; then
    echo "UUID=$BTRFS_UUID /var/lib/containers btrfs noatime,compress=zstd:1,subvol=@containers 0 0" >> /mnt/etc/fstab
fi
# AI (Claude, Sonnet 5, Medium) CHANGE — v3.2.0: mount the display manager's
# runtime/state subvolume, matching the one created in Stage 1. @sddm is
# mounted (via tmpfs in older revisions) for SDDM; when LightDM is chosen, a
# dedicated @lightdm btrfs subvolume persists its per-user state instead.
if [ "$DISPLAY_MANAGER" = "sddm" ]; then
    echo "UUID=$BTRFS_UUID /var/lib/sddm btrfs noatime,compress=zstd:1,subvol=@sddm 0 0" >> /mnt/etc/fstab
elif [ "$DISPLAY_MANAGER" = "lightdm" ]; then
    echo "UUID=$BTRFS_UUID /var/lib/lightdm btrfs noatime,compress=zstd:1,subvol=@lightdm 0 0" >> /mnt/etc/fstab
fi
# AI (Big Pickle) CHANGE — v3.2.0 [item 5]: /boot/grub fstab
# entry now exists only for BOOTLOADER=grub (the @grub subvolume is likewise
# gated in Stage 1). Under Limine nothing is mounted at /boot/grub.
[ "$BOOTLOADER" = "grub" ] && echo "UUID=$BTRFS_UUID /boot/grub       btrfs noatime,compress=zstd:1,subvol=@grub 0 0" >> /mnt/etc/fstab
echo "UUID=$BTRFS_UUID /root               btrfs noatime,compress=zstd:1,subvol=@root 0 0" >> /mnt/etc/fstab

: > /mnt/tmp/chroot_env.sh
chmod 600 /mnt/tmp/chroot_env.sh
echo "export BTRFS_UUID=\"$BTRFS_UUID\"" >> /mnt/tmp/chroot_env.sh
echo "export TARGET_USER=\"$TARGET_USER\"" >> /mnt/tmp/chroot_env.sh
echo "export TARGET_HOSTNAME=\"$TARGET_HOSTNAME\"" >> /mnt/tmp/chroot_env.sh
echo "export TARGET_DOMAIN=\"$TARGET_DOMAIN\"" >> /mnt/tmp/chroot_env.sh
echo "export TARGET_FQDN=\"$TARGET_FQDN\"" >> /mnt/tmp/chroot_env.sh
echo "export NET_INTERFACE_MATCH=\"$NET_INTERFACE_MATCH\"" >> /mnt/tmp/chroot_env.sh
echo "export REPO_PRIMARY=\"$REPO_PRIMARY\"" >> /mnt/tmp/chroot_env.sh
echo "export REPO_BACKUP1=\"$REPO_BACKUP1\"" >> /mnt/tmp/chroot_env.sh
echo "export REPO_BACKUP2=\"$REPO_BACKUP2\"" >> /mnt/tmp/chroot_env.sh
echo "export ENABLE_SNAPSHOT_AUDIO=\"$ENABLE_SNAPSHOT_AUDIO\"" >> /mnt/tmp/chroot_env.sh
echo "export ACCOUNT_MODEL=\"$ACCOUNT_MODEL\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_FLATPAK=\"$INSTALL_FLATPAK\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_FIREFOX=\"$INSTALL_FIREFOX\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_CHROMIUM=\"$INSTALL_CHROMIUM\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_VIVALDI=\"$INSTALL_VIVALDI\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_FALKON=\"$INSTALL_FALKON\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_BRAVE=\"$INSTALL_BRAVE\"" >> /mnt/tmp/chroot_env.sh
echo "export PROVISION_FIREFOX_SUBVOL=\"$PROVISION_FIREFOX_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export PROVISION_CHROMIUM_SUBVOL=\"$PROVISION_CHROMIUM_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export PROVISION_VIVALDI_SUBVOL=\"$PROVISION_VIVALDI_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export PROVISION_FALKON_SUBVOL=\"$PROVISION_FALKON_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export PROVISION_BRAVE_SUBVOL=\"$PROVISION_BRAVE_SUBVOL\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_PODMAN_ROOTLESS=\"$INSTALL_PODMAN_ROOTLESS\"" >> /mnt/tmp/chroot_env.sh
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
echo "export LIGHTDM_GREETER_PKG=\"$LIGHTDM_GREETER_PKG\"" >> /mnt/tmp/chroot_env.sh
echo "export LIGHTDM_GREETER_SESSION=\"$LIGHTDM_GREETER_SESSION\"" >> /mnt/tmp/chroot_env.sh
# AI (Big Pickle) ADDITION — v3.2.0 [LOCALIZE]: carry the chosen locale/timezone
# into the chroot so Stage 2 can generate+activate the locale and set the zone.
echo "export LOCALE=\"$LOCALE\"" >> /mnt/tmp/chroot_env.sh
echo "export LOCALE_CODESET=\"$LOCALE_CODESET\"" >> /mnt/tmp/chroot_env.sh
echo "export TIMEZONE=\"$TIMEZONE\"" >> /mnt/tmp/chroot_env.sh
# AI (Big Pickle) ADDITION — v3.2.0 [SWAP]: carry swap/zram/hibernation choices
# into the chroot so Stage 2 can provision the right backend(s).
echo "export SWAP_BACKEND=\"$SWAP_BACKEND\"" >> /mnt/tmp/chroot_env.sh
echo "export ENABLE_HIBERNATION=\"$ENABLE_HIBERNATION\"" >> /mnt/tmp/chroot_env.sh
echo "export SWAPFILE_SIZE=\"$SWAPFILE_SIZE\"" >> /mnt/tmp/chroot_env.sh
# AI (Big Pickle) ADDITION — v3.3.0-beta6 [ENCRYPT]: the yes/no flag is
# carried into the chroot so Stage 2 writes crypttab (and dracut/GRUB/Limine
# provision the crypt path). Deliberately NOT the passphrase — chroot_env.sh
# must stay secret-free (same rule as the pass hashes below), and the
# passphrase was already unset after luksOpen anyway.
echo "export ENCRYPT=\"$ENCRYPT\"" >> /mnt/tmp/chroot_env.sh
# The LUKS container UUID is public (it is stamped in the on-disk header and
# appears in rd.luks.uuid= on the kernel cmdline) so it is safe to persist
# into the chroot for the GRUB/Limine cmdline builders — unlike the
# passphrase. Computed at fstab/crypttab-write time when encrypted.
if [ "$ENCRYPT" = "yes" ]; then
    echo "export LUKS_UUID=\"$LUKS_UUID\"" >> /mnt/tmp/chroot_env.sh
fi
# AI (Big Pickle) ADDITION — v3.3.0-beta7 [YUBIKEY]: carry the YubiKey unlock
# choices into the chroot so Stage 2 can write the keyscript-invoking crypttab
# and the dracut module. Persisted values are PUBLIC (mode, slot, challenge) —
# the challenge is not itself a credential; the HMAC response (YK_KEY) is
# never exported to chroot_env (secret-free rule, same as the passphrase).
if [ "$YK_MODE" = "hmac-sha1" ]; then
    echo "export YK_MODE=\"$YK_MODE\"" >> /mnt/tmp/chroot_env.sh
    echo "export YK_SLOT=\"$YK_SLOT\"" >> /mnt/tmp/chroot_env.sh
    echo "export YK_CHALLENGE=\"$YK_CHALLENGE\"" >> /mnt/tmp/chroot_env.sh
    echo "export YK_FALLBACK=\"$YK_FALLBACK\"" >> /mnt/tmp/chroot_env.sh
    echo "export YK_TOUCH=\"$YK_TOUCH\"" >> /mnt/tmp/chroot_env.sh
fi
# AI (Big Pickle) ADDITION — v3.2.0 [item 9]: SESSION_STACK carried into the
# chroot so Stage 2 can branch elogind vs turnstile+seatd+acpid and validate.
echo "export SESSION_STACK=\"$SESSION_STACK\"" >> /mnt/tmp/chroot_env.sh
echo "export INSTALL_OCTOXBPS=\"$INSTALL_OCTOXBPS\"" >> /mnt/tmp/chroot_env.sh
echo "export BOOTLOADER=\"$BOOTLOADER\"" >> /mnt/tmp/chroot_env.sh
echo "export KERNEL_MODE=\"$KERNEL_MODE\"" >> /mnt/tmp/chroot_env.sh
echo "export LIMINE_WALLPAPER=\"$LIMINE_WALLPAPER\"" >> /mnt/tmp/chroot_env.sh
echo "export LIMINE_WALLPAPER_STYLE=\"$LIMINE_WALLPAPER_STYLE\"" >> /mnt/tmp/chroot_env.sh
echo "export SCRIPT_VERSION=\"$SCRIPT_VERSION\"" >> /mnt/tmp/chroot_env.sh
# AI (Big Pickle) ADDITION — v3.3.0-beta4 [SHELL]: carry the chosen login shell
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
if [ -z "${DESKTOP_ENV:-}" ] || { [ "$DESKTOP_ENV" != "kde" ] && [ "$DESKTOP_ENV" != "cinnamon" ] && [ "$DESKTOP_ENV" != "gnome" ] && [ "$DESKTOP_ENV" != "xfce" ] && [ "$DESKTOP_ENV" != "mate" ] && [ "$DESKTOP_ENV" != "lxqt" ] && [ "$DESKTOP_ENV" != "cosmic" ]; }; then
    echo "CRITICAL: DESKTOP_ENV is missing or invalid ('${DESKTOP_ENV:-<unset>}') inside target environment. Aborting." >&2
    exit 1
fi
if [ -z "${DISPLAY_MANAGER:-}" ] || { [ "$DISPLAY_MANAGER" != "sddm" ] && [ "$DISPLAY_MANAGER" != "lightdm" ] && [ "$DISPLAY_MANAGER" != "gdm" ] && [ "$DISPLAY_MANAGER" != "cosmic-greeter" ]; }; then
    echo "CRITICAL: DISPLAY_MANAGER is missing or invalid ('${DISPLAY_MANAGER:-<unset>}') inside target environment. Aborting." >&2
    exit 1
fi
if [ "$DISPLAY_MANAGER" = "lightdm" ]; then
    if [ -z "${LIGHTDM_GREETER_PKG:-}" ] || [ -z "${LIGHTDM_GREETER_SESSION:-}" ]; then
        echo "CRITICAL: LIGHTDM greeter choice missing inside target environment for DISPLAY_MANAGER=lightdm. Aborting." >&2
        exit 1
    fi
fi
# AI (Big Pickle) ADDITION — v3.2.0 [item 9]: hard validation so a missing or
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
# AI (Big Pickle) ADDITION — v3.3.0-beta4 [SHELL]: a missing/mangled
# USER_SHELL aborts in-chroot rather than creating the account with a bogus
# -s path (the chroot consumes it directly in useradd, so it must be real).
if [ -z "${USER_SHELL:-}" ]; then
    echo "CRITICAL: USER_SHELL is missing ('${USER_SHELL:-<unset>}') inside target environment. Aborting." >&2
    exit 1
fi

# AI (Big Pickle) ADDITION — v3.3.0 [INSTALL-PKGS]: install from the first
# mirror that succeeds, retrying the live-CD package sync across the primary +
# both backup repositories.
install_pkgs() {
    _ipkgs_ok=0
    for _ipkgs_repo in "$REPO_PRIMARY" "$REPO_BACKUP1" "$REPO_BACKUP2"; do
        if xbps-install -Suy -R "$_ipkgs_repo" "$@"; then
            _ipkgs_ok=1
            break
        fi
        echo "==> Package install attempt against ${_ipkgs_repo} failed for: $* — trying next repository, if any." >&2
        # AI (Big Pickle) CHANGE — v3.3.0 [INSTALL-PKGS]: a mid-transaction
        # failure can leave xbps's package db marked dirty/
        # locked; refresh the index and let xbps reconcile the db before the
        # next mirror attempt, rather than replaying the same stale state and
        # failing all three mirrors for the same root cause.
        xbps-install -Sy -R "$_ipkgs_repo" >/dev/null 2>&1 || true
        xbps-pkgdb -a >/dev/null 2>&1 || true
    done
    if [ "$_ipkgs_ok" -ne 1 ]; then
        echo "FATAL: package install failed against all configured repositories for: $*" >&2
        exit 1
    fi
}

# AI (Big Pickle) ADDITION — v3.2.0 [COSMIC]: COSMIC is NOT in the official
# Void repositories. It installs from a community repo maintained by REDACTED
# REDACTED (GitHub REDACTED / Codeberg REDACTED), pinned here to the
# CURRENT domain the maintainer documents (repo.REDACTED.de). Because this is a
# third-party signing-trust choice, this helper deliberately NEVER goes
# through install_pkgs() (which overrides -R with only the three official
# mirrors and would silently fail to reach the COSMIC repo). Instead it:
#   1. verifies the COSMIC repo is actually reachable at runtime (the
#      documented old github.io URL is now stale — it serves a web page, not
#      an xbps index), aborting gracefully with install instructions + the
#      audit link rather than failing mid-install;
#   2. drops the maintainer's documented repo config into /etc/xbps.d/;
#   3. trusts + syncs it and installs the requested COSMIC package(s) via a
#      dedicated xbps-install.
# The repo's signing key is whatever the maintainer publishes with the repo
# (fetched/trusted by xbps on first sync, exactly as the maintainer's own
# documented setup does); audit link: https://github.com/REDACTED/void-packages
install_cosmic() {
    _cosmic_repo="https://repo.REDACTED.de/repo/x86_64"
    _cosmic_repodata="https://repo.REDACTED.de/repo/x86_64/x86_64-repodata"
    _cosmic_audit="https://github.com/REDACTED/void-packages"

    if ! curl -fsSL --max-time 30 -o /dev/null "$_cosmic_repodata" 2>/dev/null; then
        echo "FATAL: the third-party COSMIC repository (${_cosmic_repo}) is not reachable right now." >&2
        echo "       Install aborted cleanly because COSMIC is a third-party repo and cannot be" >&2
        echo "       installed without it. You can still install the other desktops, or add the" >&2
        echo "       repo manually later and run:  xbps-install -S cosmic-desktop-full" >&2
        echo "       Repo docs / audit: ${_cosmic_audit}" >&2
        exit 1
    fi

    mkdir -p /etc/xbps.d
    if ! grep -q 'repo.REDACTED.de' /etc/xbps.d/59-cosmic.conf 2>/dev/null; then
        echo "repository=${_cosmic_repo}" > /etc/xbps.d/59-cosmic.conf
    fi

    # Sync the (freshly added) COSMIC repo index; this is what imports/trusts
    # the repo's signing key, matching the maintainer's documented setup.
    if ! xbps-install -Sy; then
        echo "FATAL: could not sync/trust the third-party COSMIC repository (${_cosmic_repo})." >&2
        echo "       If it is a missing-signing-key prompt, re-check the repo; install aborted cleanly." >&2
        echo "       Repo docs / audit: ${_cosmic_audit}" >&2
        exit 1
    fi

    if ! xbps-install -y "$@"; then
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

cat > /etc/nftables.conf << 'INNER_EOF'
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
    }
    chain forward {
        type filter hook forward priority filter; policy drop;
        iifname "br0" accept
        oifname "br0" accept
        iifname "virbr*" accept
        oifname "virbr*" accept
    }
    chain output {
        type filter hook output priority filter; policy accept;
    }
}

table ip mangle {
    chain postrouting {
        type filter hook postrouting priority mangle; policy accept;
        oifname "enp5s0f*" counter; ip ttl set 113
        oifname "enx*" counter; ip ttl set 113
    }
    chain prerouting {
        type filter hook prerouting priority mangle; policy accept;
        iifname "enp5s0f*" counter; ip ttl set 113
        iifname "enx*" counter; ip ttl set 113
    }
}

table ip6 mangle {
    chain postrouting {
        type filter hook postrouting priority mangle; policy accept;
        oifname "enp5s0f*" counter; ip6 hoplimit set 114
        oifname "enx*" counter; ip6 hoplimit set 114
    }
    chain prerouting {
        type filter hook prerouting priority mangle; policy accept;
        iifname "enp5s0f*" counter; ip6 hoplimit set 114
        iifname "enx*" counter; ip6 hoplimit set 114
    }
}
INNER_EOF

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

# AI (Big Pickle) CHANGE — v3.2.0 [LOCALIZE]: real localization. The chosen
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

[ "$INSTALL_VIRT" = "true" ] && install_pkgs qemu libvirt virt-manager

# AI (Big Pickle) ADDITION — v3.3.0-beta4 [SHELL]: install the chosen login
# shell's package if any (empty USER_SHELL_PKG = the bundled bash, nothing to
# install), before useradd so the selected shell binary already exists in the
# target when the account is created.
[ -n "$USER_SHELL_PKG" ] && install_pkgs "$USER_SHELL_PKG"

USER_GROUPS="adm,video,audio"
[ "$ACCOUNT_MODEL" != "debian" ] && USER_GROUPS="wheel,${USER_GROUPS}"
[ "$INSTALL_VIRT" = "true" ] && USER_GROUPS="${USER_GROUPS},kvm,libvirt"
useradd -m -G "$USER_GROUPS" -s "$USER_SHELL" -c "$TARGET_USER" "$TARGET_USER"

# AI (Big Pickle) ADDITION — v3.3.0-beta7 [ZSHRC]: when zsh is the login
# shell, pre-create a minimal ~/.zshrc so the user's first interactive
# session doesn't dump them into zsh's zsh-newuser-install wizard. Void's
# zsh package ships NO /etc/zsh/newuser.zshrc.recommended (a user then picks
# "create blank .zshrc", "recommended by admin", or "quit + touch ~/.zshrc"
# — the "instructions to touch ~/.zshrc" message), and useradd -m leaves the
# home dir with no zsh startup files — so every fresh zsh login previously
# fired the wizard. The mere presence of ~/.zshrc suppresses it (the
# zsh/newuser module halts once any of .zshenv/.zprofile/.zshrc/.zlogin
# exists). Written with the user's ownership to match useradd -m. Only
# created when zsh is the chosen shell — bash/fish/mksh are unaffected.
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

if [ "$INSTALL_VIRT" = "true" ]; then
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

CPU_VENDOR=$(grep -m1 vendor_id /proc/cpuinfo | awk '{print $3}')
case "$CPU_VENDOR" in
    GenuineIntel) MICROCODE_PKG="intel-ucode" ;;
    AuthenticAMD) MICROCODE_PKG="linux-firmware-amd" ;;
    *) echo "WARNING: unrecognized CPU vendor '${CPU_VENDOR}', skipping microcode package." >&2
       MICROCODE_PKG="" ;;
esac
install_pkgs ${MICROCODE_PKG} linux-firmware dracut sudo vim nano bash bash-completion curl
# AI (Big Pickle) ADDITION — v3.3.0-beta6 [ENCRYPT]: install the userspace
# cryptsetup/LUKS tooling into the target only when encryption was enabled
# (the dracut `crypt` module needs the cryptsetup binary + udev rules to
# unlock the volume at boot). Not installed for the unencrypted default.
[ "$ENCRYPT" = "yes" ] && install_pkgs cryptsetup
# AI (Big Pickle) ADDITION — v3.3.0-beta7 [YUBIKEY]: install the C-only
# `yubikey-personalization` (ykpers) tools (ykpersonalize for enrolling already
# ran on the live medium; ykchalresp is what the initramfs keyscript calls at
# boot). C + libusb only, so it fits cleanly in the dracut initramfs — the same
# tool is used at both enroll and boot to keep hmac-lt64 consistent.
[ "$YK_MODE" = "hmac-sha1" ] && install_pkgs ykpers

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
# AI (Big Pickle) CHANGE — v3.2.0 [item 9]: session/seat
# management is now a real choice. Default (elogind) installs the
# logind-fork as before. The alternative installs turnstile (user-session
# supervisor), seatd (graphical seat/input), and acpid (ACPI/power events)
# and omits elogind entirely. The two stacks are mutually exclusive — never
# both, they'd double-manage sessions and the seat.
if [ "$SESSION_STACK" = "elogind" ]; then
    install_pkgs wayland wayland-protocols NetworkManager dbus elogind xorg
else
    install_pkgs wayland wayland-protocols NetworkManager dbus turnstile seatd acpid xorg
fi

# AI (Big Pickle) ADDITION — v3.2.0 [items 1 & 6]: the display manager is a
# real choice ($DISPLAY_MANAGER, Stage 1) with three options now (sddm,
# lightdm, gdm). Each branch installs exactly its chosen DM and populates
# DM_SERVICE_NAME, used later in rc.local to link exactly ONE display
# manager's runit service — they must never both be linked, or they'd fight
# over the same VT/seat.
#
# v3.2.0 fixes: the LightDM branch previously hard-attempted the Slick
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
        # AI (Big Pickle) FIX — v3.3.0-beta2 [LIGHTDM-SWRAP]: the generated
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
    # AI (Big Pickle) FIX — v3.3.0-beta4 [LIGHTDM-ATOMIC]: atomic write. The
    # direct `>` redirect could truncate this load-bearing config (it carries
    # the mandatory session-wrapper from [LIGHTDM-SWRAP]) on a mid-write
    # interruption; write to a temp file then rename into place.
    mv -f /etc/lightdm/lightdm.conf.tmp /etc/lightdm/lightdm.conf
    # AI (Big Pickle) CHANGE — v3.3.0-beta2 [LIGHTDM-HW]: three real-hardware
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

    if [ "$LIGHTDM_GREETER_SESSION" = "lightdm-webkit2-greeter" ]; then
        mkdir -p /etc/lightdm
        {
            echo "[greeter]"
            echo "webkit-theme=void"
            echo "webkit-theme-ltr=void"
            echo "webkit-theme-rtl=void"
        } > /etc/lightdm/lightdm-webkit2-greeter.conf
    fi

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
    # AI (Big Pickle) CORRECTION — v3.3.0-beta4 [GDM-WAY]: gdm-wayland-session
    # does NOT exist as a Void package (only `gdm` is in the repo, verified
    # against the current binary index). Listing it aborted the whole DM
    # install for a GDM choice. `gdm` alone is what Void ships.
    install_pkgs gdm
    DM_SERVICE_NAME="gdm"
elif [ "$DISPLAY_MANAGER" = "cosmic-greeter" ]; then
    # AI (Big Pickle) ADDITION — v3.2.0 [COSMIC]: cosmic-greeter is COSMIC's
    # own greeter, available only from the third-party COSMIC repo (NOT the
    # official mirrors, so it cannot go through install_pkgs). The honored
    # DISPLAY_MANAGER value matches the package name. install_cosmic also
    # handles repo add/verify/trust + graceful abort. NOTE: the COSMIC
    # maintainer reports cosmic-greeter does not currently work reliably
    # (elogind doesn't recognize its session) and recommends SDDM instead;
    # it is installed only because the user explicitly chose it.
    install_cosmic cosmic-greeter
    DM_SERVICE_NAME="cosmic-greeter"
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
    #     AI (Big Pickle) CORRECTION — v3.3.0-beta4 [WSDD-ABSENT]: Void does
    #     NOT ship `wsdd` (nor `wsdd2`) in any official repo (verified against
    #     void-packages master; the package has only ever been a long-open
    #     request, void-packages#28216). Listing it made `xbps-install` abort
    #     the ENTIRE desktop-gap transaction with
    #     "'wsdd' not found in repository pool" on real hardware. It is
    #     deliberately NOT installed. Nemo's "Windows Network" entry will log
    #     the missing-daemon warning (harmless), but the install must not fail
    #     over an absent package.
    install_pkgs gedit gnome-backgrounds blueman network-manager-applet

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
    # AI (Big Pickle) ADDITION — v3.2.0 [item 2]: Xfce via the `xfce4`
    # metapackage, Void's own documented route (also the DE shipped on
    # Void's graphical live images). xfce4 pulls in its terminal
    # (xfce4-terminal), panel (xfce4-panel), settings daemon, power
    # manager, etc., so unlike Cinnamon no supplementary basics are needed.
    # The network-manager-applet secret agent is still useful for
    # X11/GTK desktops where a native tray applet is present, matching the
    # Cinnamon rationale — added here too.
    install_pkgs xfce4 network-manager-applet
elif [ "$DESKTOP_ENV" = "mate" ]; then
    # AI (Big Pickle) ADDITION — v3.2.0 [item 2]: MATE via the `mate`
    # metapackage (Void's full-MATE route, analogous to cinnamon-all). The
    # metapackage bundles mate-terminal, the panel, control center, etc.
    # network-manager-applet added for the same X11/GTK secret-agent
    # rationale as Cinnamon/Xfce.
    install_pkgs mate network-manager-applet
elif [ "$DESKTOP_ENV" = "lxqt" ]; then
    # AI (Big Pickle) ADDITION — v3.2.0 [item 2]: LXQt via the `lxqt`
    # metapackage (Qt-based, light). LXQt's conventional display manager
    # is SDDM, but the DM is chosen independently above. lxqt bundles its
    # own session/panel/file-manager stack.
    install_pkgs lxqt
elif [ "$DESKTOP_ENV" = "cosmic" ]; then
    # AI (Big Pickle) ADDITION — v3.2.0 [COSMIC]: COSMIC installed from the
    # third-party community repo (never the official mirrors), so it uses the
    # dedicated install_cosmic() helper instead of install_pkgs(). The
    # maintainer's metapackage is cosmic-desktop-full (all components). The
    # maintainer recommends also installing SDDM + Firefox with it; SDDM is
    # handled by the independent DISPLAY_MANAGER choice above, and Firefox by
    # the independent browser toggles — both may be selected separately, so
    # only the metapackage is installed here.
    install_cosmic cosmic-desktop-full
else
    install_pkgs kde-plasma kde-baseapps ark kio-admin
fi

# AI (Big Pickle) ADDITION — v3.2.0 [item 2]: polkit authentication
# agent. The kde-plasma metapackage ships its own (polkit-kde-agent), and
# GNOME has a built-in agent, but the GTK-family desktops added here
# (Cinnamon, Xfce, MATE — and LXQt) have no guarantee of one. Without a
# polkit agent, GUI privilege prompts (NetworkManager, blueman mounting,
# package managers) can hang with nothing to present the auth dialog.
# Installed for exactly those desktop environments.
case "$DESKTOP_ENV" in
    cinnamon|xfce|mate|lxqt)
        install_pkgs lxqt-policykit
        ;;
esac
install_pkgs xdg-user-dirs xdg-utils xtools bluez tlp tlp-rdw preload rsync git curl wget make binutils inotify-tools fastfetch chrony cronie bridge-utils
[ "$INSTALL_OCTOXBPS" = "true" ] && install_pkgs octoxbps

if [ "$INSTALL_FLATPAK" = "true" ]; then
    install_pkgs flatpak
    # AI (Big Pickle) ADDITION — v3.3.0-beta4 [FLATHUB-CHROOT]: add the
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
    flatpak remote-add --if-not-exists flathub https://flathub.org || \
        echo "WARNING: could not add flathub remote at install time. It will be re-attempted, non-blocking, at first boot (see [FLATHUB-RCL])." >&2
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

[ "$INSTALL_PODMAN" = "true" ] && install_pkgs podman
[ "$INSTALL_PODMAN_ROOTLESS" = "true" ] && install_pkgs fuse-overlayfs slirp4netns crun catatonit
[ "$INSTALL_DOCKER" = "true" ] && install_pkgs docker
if [ "$INSTALL_DOCKER" = "true" ] && [ "$DOCKER_GROUP_ADD" = "true" ]; then
    usermod -aG docker "$TARGET_USER"
fi

# AI (Claude, Sonnet 5, Medium) ADDITION — v3.1.0-beta1 [DISTROBOX-3] §4.13: podman image pulls
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
# AI (Claude, Sonnet 5, Medium) CHANGE — v3.1.0-beta1 [DISTROBOX-2]/[DISTROBOX-3]/[CLONE-RETRY]:
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

if [ "$INSTALL_VIRT" = "true" ]; then
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

# AI (Big Pickle) FIX — v3.3.0-beta4 [NM-IFACE]: NetworkManager's `[connection]
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
fi

mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/99-kvm-routing.conf << 'INNER_EOF'
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
INNER_EOF

# =============================================================================
# AUDIO AND HYPERVISOR SERVICE ORCHESTRATION LAYER
# =============================================================================

install_pkgs alsa-utils alsa-ucm-conf alsa-pipewire pipewire wireplumber sof-firmware libspa-bluetooth libjack-pipewire
# plasma-pa (the Plasma systray volume applet) only means anything under
# KDE — Cinnamon's own cinnamon-settings-daemon already provides a volume
# applet, no separate package needed.
[ "$DESKTOP_ENV" = "kde" ] && install_pkgs plasma-pa

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
    echo "UUID=${BTRFS_UUID} ${_pbs_fullpath} btrfs noatime,nodatacow,subvol=${_pbs_subvol} 0 0" >> /etc/fstab
    mount "$_pbs_fullpath"
    chown "${TARGET_USER}:${TARGET_USER}" "$_pbs_fullpath"
    chmod 700 "$_pbs_fullpath"
}

# AI (Big Pickle) ADDITION — v3.2.0 [item 4]: Firefox-specific helper.
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
[ "$INSTALL_FIREFOX" = "true" ] || [ "$PROVISION_FIREFOX_SUBVOL" = "true" ] && provision_firefox_subvols
[ "$INSTALL_CHROMIUM" = "true" ] || [ "$PROVISION_CHROMIUM_SUBVOL" = "true" ] && provision_browser_subvol "@chromium" ".config/chromium"
[ "$INSTALL_VIVALDI" = "true" ] || [ "$PROVISION_VIVALDI_SUBVOL" = "true" ] && provision_browser_subvol "@vivaldi" ".config/vivaldi"
[ "$INSTALL_FALKON" = "true" ] || [ "$PROVISION_FALKON_SUBVOL" = "true" ] && provision_browser_subvol "@falkon" ".config/falkon"
[ "$INSTALL_BRAVE" = "true" ] || [ "$PROVISION_BRAVE_SUBVOL" = "true" ] && provision_browser_subvol "@brave" ".config/BraveSoftware/Brave-Browser"

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
echo "UUID=${BTRFS_UUID} /home/${TARGET_USER}/.local/share/containers btrfs noatime,compress=zstd:1,subvol=@containers-user 0 0" >> /etc/fstab
mount "/home/${TARGET_USER}/.local/share/containers"
chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.local/share/containers"
chmod 700 "/home/${TARGET_USER}/.local/share/containers"

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

echo "UUID=${BTRFS_UUID} /home/${TARGET_USER}/.cache btrfs noatime,compress=zstd:1,subvol=@usercache,noauto 0 0" >> /etc/fstab

chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.cache"
mount "/home/${TARGET_USER}/.cache"
chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.cache"
chmod 700 "/home/${TARGET_USER}/.cache"

# AI (Big Pickle) CHANGE — v3.2.0 [SWAP]: activate the disk swapfile only when
# a disk swapfile backend was chosen (swapfile or both).
if [ "$SWAP_BACKEND" = "swapfile" ] || [ "$SWAP_BACKEND" = "both" ]; then
    swapon /var/swap/swapfile
fi
# AI (Big Pickle) ADDITION — v3.2.0 [SWAP]: provision zram (compressed-RAM
# swap) when the backend is zram or both. zramen installs the runit service and
# loads the zram module; we write a sane config here and enable the service for
# first boot in the rc.local block. (See the __SWAP_BACKEND__ placeholder in
# /etc/rc.local provisioning.)
if [ "$SWAP_BACKEND" = "zram" ] || [ "$SWAP_BACKEND" = "both" ]; then
    install_pkgs zramen
    cat > /etc/sv/zramen/conf << 'ZRAM_CONF'
# AI (Big Pickle) generated zramen config — v3.2.0 [SWAP]
export ZRAM_COMP_ALGORITHM=zstd
export ZRAM_PRIORITY=100
export ZRAM_SIZE=50
ZRAM_CONF
fi

install_pkgs snapper

# =============================================================================
# BOOTLOADER: GRUB or LIMINE, per $BOOTLOADER  [LIMINE-1] [LIMINE-2]
# =============================================================================
# AI (Claude, Sonnet 5, Medium) CHANGE — v3.1.0-beta1: both bootloader paths now coexist,
# gated on the choice made in Stage 1. GRUB's branch below is carried
# forward essentially unchanged from 3.0.112GC (grub-btrfs dynamic
# snapshot menu, confirmed real-hardware working including snapshot boot).
# Limine's branch is the new, still-experimental path from this beta line
# (CHANGELOG §4.7/§4.9) — static config this script writes itself, no
# grub-mkconfig-style generator.
if [ "$BOOTLOADER" = "grub" ]; then

install_pkgs grub-x86_64-efi efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Void_GRUB" --recheck

# AI (Big Pickle) CHANGE — v3.2.0 [SWAP]: resume-from-disk kernel params are
# only added when hibernation was enabled at install time (and a disk swapfile
# actually exists). Otherwise GRUB gets a plain cmdline with no resume= params.
# AI (Big Pickle) ADDITION — v3.3.0-beta6 [ENCRYPT]: when encryption is
# enabled, the LUKS container UUID is injected via rd.luks.uuid= + a fixed
# rd.luks.name= so dracut's `crypt` module opens void-root before root is
# mounted. `resume=` keeps the Btrfs filesystem UUID — the swapfile lives
# inside the LUKS volume, so hibernation resumes after the volume is
# unlocked.
if [ "$ENCRYPT" = "yes" ]; then
    LUKS_RD="rd.luks.uuid=${LUKS_UUID} rd.luks.name=${LUKS_UUID}=void-root"
else
    LUKS_RD=""
fi
if [ "$ENABLE_HIBERNATION" = "true" ] && [ -f /var/swap/swapfile ]; then
    TARGET_OFFSET=$(btrfs inspect-internal map-swapfile -r /var/swap/swapfile)
    GRUB_CMD="loglevel=3 ${LUKS_RD} resume=UUID=${BTRFS_UUID} resume_offset=${TARGET_OFFSET}"
else
    GRUB_CMD="loglevel=3 ${LUKS_RD}"
fi
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
# AI (Claude, Sonnet 5, Medium) ADDITION — v3.1.0-beta1: replaces the GRUB install /
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

# AI (Claude, Sonnet 5, Medium) ADDITION — v3.1.0-beta1 [KERNEL-MODE]/[KERNEL-HOOK] §4.8/§4.10:
# esp-copy mode keeps versioned kernel/initramfs copies for every
# installed kernel on the ESP (see [LIMINE-MULTI-KERNEL]) — limine.conf
# itself still never needs manual editing across kernel updates, since
# void-limine-write-conf regenerates the whole menu (one stanza per
# kernel found) rather than referencing fixed filenames.
if [ "$KERNEL_MODE" = "esp-copy" ]; then
    mkdir -p /boot/efi/void-kernel
fi

# AI (Claude, Sonnet 5, Medium) CHANGE — v3.1.0-beta1 [LIMINE-SYNC-CRON]: limine-snapper-sync
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
#   1. The kernel post-install/post-remove hook (unchanged trigger,
#      handles the ESP kernel/initramfs copy in esp-copy mode, then calls
#      this script for the config itself).
#   2. A new /etc/cron.d/void-limine-sync entry, every 15 minutes,
#      regenerating limine.conf alone (cheap — a few KB of text) so any
#      timeline snapshot snapper creates on its own schedule shows up in
#      the menu within 15 minutes, without waiting on a kernel update.
# Chosen over a runit-supervised inotify watcher: a cron.d file can't be
# silently clobbered by a package update the way a long-running service
# can regress across runit/dracut/kernel changes, and there's no
# supervision-correctness (double-fork, signal handling, restart-on-crash)
# to get wrong — cron either runs the (idempotent, cheap) job or it
# doesn't, worst case the menu is a few minutes stale.
#
# Both trigger points, and the initial install-time call below, read their
# parameters (KERNEL_MODE, BTRFS_UUID, the two SYSPREFIX values) from a
# small persisted state file rather than any install-time bash environment
# — the standalone script has to work standing alone, long after this
# chroot phase and this shell are gone.
#
# AI (Big Pickle) SUPERSEDED — v3.3.0-beta4 [SNPR-EV]: the opening premise of
# this v3.1.0-beta1 comment ("Void's snapper build ships no general
# pre/post-snapshot hook mechanism") was REFUTED on target hardware: Void's
# snapper DOES execute /usr/lib/snapper/plugins (probe observed both
# create-snapshot-* and delete-snapshot-* hooks firing). So the 15-min cron
# is demoted to a safety-net fallback, and the primary snapshot-menu path is
# now the event-driven 00-void-limine-snapper-sync plugin (installed later in
# this same Limine branch). The cron's "worst case a few minutes stale"
# bound no longer applies to the common path — the menu now tracks snapshots
# at the moment they happen. The historical rationale above is preserved for
# the record; the design that replaced the no-hook premise is [SNPR-EV].
mkdir -p /etc/void-installer
cat > /etc/void-installer/limine-env << INNER_EOF
KERNEL_MODE="${KERNEL_MODE}"
BTRFS_UUID="${BTRFS_UUID}"
SYSPREFIX_ESP="${SYSPREFIX_ESP}"
SYSPREFIX_BTRFS="${SYSPREFIX_BTRFS}"
# AI (Big Pickle) ADDITION — v3.2.0 [SWAP]: baked at install time so the
# kernel/cron generators know whether to emit resume-from-disk kernel params.
HIBERNATION_ENABLED="${ENABLE_HIBERNATION}"
# AI (Big Pickle) ADDITION — v3.3.0-beta3 [LIMINE-WALLPAPER]: persisted so
# void-limine-write-conf keeps re-emitting the wallpaper lines on every
# kernel update / cron resync (the regenerated limine.conf overwrites the
# file each time, so this must be state the generator can re-read).
LIMINE_WALLPAPER="${LIMINE_WALLPAPER}"
LIMINE_WALLPAPER_STYLE="${LIMINE_WALLPAPER_STYLE}"
# AI (Big Pickle) ADDITION — v3.3.0-beta6 [ENCRYPT]: persisted so
# void-limine-write-conf re-emits the rd.luks.uuid=/rd.luks.name= kernel
# params on every kernel update / cron resync (the generated limine.conf is
# rewritten each time, so the LUKS knowledge must be state the generator can
# re-read, exactly like the wallpaper choice above). LUKS_UUID is the
# ciphertext container's header UUID — public (it is in rd.luks.uuid= on the
# boot cmdline), never the passphrase. Empty/unset when not encrypted.
ENCRYPT="${ENCRYPT}"
LUKS_UUID="${LUKS_UUID}"
# AI (Big Pickle) ADDITION — v3.3.0-beta7 [YUBIKEY]: persisted so
# void-limine-write-conf re-emits the rd.luks.name=void-root keyscript unlock
# params on every kernel update / cron resync, consistent with how the
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

# AI (Big Pickle) ADDITION — v3.3.0-beta3 [INSTALL-CONFIG]: write a
# human-readable record of every install-time CHOICE into the target, so the
# finished machine is self-documenting and reproducible without relying on
# this shell's (now-gone) environment or a USB transfer. This is the recovery-
# first project's equivalent of writing the "as-built" config onto the box
# itself. It deliberately excludes secrets: NO password hashes, only booleans/
# choices (limine-env, the resume-state file, or the account provisioning
# already stores whatever secrets the system actually needs at runtime).
mkdir -p /etc/void-installer
cat > /etc/void-installer/install-config << INNER_EOF
# Void Linux Installer — install-time configuration for THIS machine.
# Written by Void_Linux_Installer.sh (v${SCRIPT_VERSION}) at install time.
# Human-readable "as-built" summary for recovery/troubleshooting/reproducibility.
SCRIPT_VERSION="${SCRIPT_VERSION:-<unknown>}"
HOSTNAME="${TARGET_HOSTNAME:-<unset>}"
USER="${TARGET_USER:-<unset>}"
USER_SHELL="${USER_SHELL:-<unset>}"
DESKTOP_ENV="${DESKTOP_ENV:-<unset>}"
DISPLAY_MANAGER="${DISPLAY_MANAGER:-<unset>}"
BOOTLOADER="${BOOTLOADER:-<unset>}"
KERNEL_MODE="${KERNEL_MODE:-<unset>}"
SESSION_STACK="${SESSION_STACK:-<unset>}"
LOCALE="${LOCALE:-<unset>}"
TIMEZONE="${TIMEZONE:-<unset>}"
REPO_PRIMARY="${REPO_PRIMARY:-<unset>}"
SWAP_BACKEND="${SWAP_BACKEND:-<unset>}"
ENABLE_HIBERNATION="${ENABLE_HIBERNATION:-<unset>}"
SWAPFILE_SIZE="${SWAPFILE_SIZE:-<unset>}"
LIMINE_WALLPAPER="${LIMINE_WALLPAPER:-<unset>}"
LIMINE_WALLPAPER_STYLE="${LIMINE_WALLPAPER_STYLE:-<unset>}"
INNER_EOF
chmod 644 /etc/void-installer/install-config

# AI (Big Pickle) ADDITION — v3.3.0-beta3 [LIMINE-WALLPAPER]: if the user
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
# AI (Big Pickle) ADDITION — v3.3.0-beta3 [LIMINE-ENV-LOAD]: the two Limine
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
# the kernel post-install/post-remove hook and the cron.d entry, so both
# trigger points can never drift out of sync with each other. Safe to run
# at any time, any number of times: purely reads current system state
# (installed kernel version, current snapshot list, current swapfile
# resume offset) and rewrites the same file. No `exit` used for the
# "nothing to do" cases, only for genuine failures, since this runs
# unattended from cron and a silent partial failure is worse than a loud
# one.
set -eEo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin"

# AI (Big Pickle) ADDITION — v3.3.0-beta3 [LIMINE-ENV-LOAD]: shared loader.
# shellcheck disable=SC1090
. /usr/local/sbin/void-limine-env.inc
load_limine_env

# Recomputed on every run (cron included) — same rationale as the GRUB
# path's 99-grub-btrfs hook: a balance/resize can relocate the swapfile's
# physical extents even though it's nodatacow, silently invalidating a
# stale resume_offset baked in at install time. Only applies when the
# system was installed with hibernation enabled (AI (Big Pickle) [SWAP]).
# AI (Big Pickle) ADDITION — v3.3.0-beta6 [ENCRYPT]: when the system was
# installed encrypted (ENCRYPT=yes in limine-env), the LUKS container UUID is
# injected via rd.luks.uuid= + rd.luks.name= so dracut's `crypt` module opens
# void-root before root is mounted. `resume=` stays on the Btrfs filesystem
# UUID — the swapfile lives inside the LUKS volume, so hibernation resumes
# after unlock — and `root=UUID=` likewise resolves through the opened mapper.
if [ "${ENCRYPT}" = "yes" ]; then
    LUKS_RD="rd.luks.uuid=${LUKS_UUID} rd.luks.name=${LUKS_UUID}=void-root"
else
    LUKS_RD=""
fi
if [ "${HIBERNATION_ENABLED}" = "true" ] && [ -f /var/swap/swapfile ]; then
    TARGET_OFFSET=$(btrfs inspect-internal map-swapfile -r /var/swap/swapfile 2>/dev/null || echo 0)
    BASE_CMD="loglevel=3 ${LUKS_RD} resume=UUID=${BTRFS_UUID} resume_offset=${TARGET_OFFSET} root=UUID=${BTRFS_UUID} rootflags=subvol=@"
else
    BASE_CMD="loglevel=3 ${LUKS_RD} root=UUID=${BTRFS_UUID} rootflags=subvol=@"
fi

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
    # AI (Big Pickle) CHANGE — v3.3.0-beta2.1 [LIMINE-HDR]: the kernels now
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

    # AI (Big Pickle) ADDITION — v3.3.0-beta3 [LIMINE-WALLPAPER]: the Limine
    # boot-screen background. Emit LIVE `wallpaper:` and `wallpaper_style:`
    # lines only when the user opted in at install time AND the image is still
    # present on the ESP. Limine reads boot():/<name> as the root of the boot
    # drive (the ESP here — the image lived at /boot/efi/limine-splash.<ext>).
    # Guarded on existence so a missing file (declined, or ESP copy removed)
    # never leaves a dangling wallpaper line. NOTE: this file is regenerated on
    # every kernel update / 15-min cron resync, so there is deliberately NO
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
    fi
    echo ""
    echo "# Paths below use guid(<PARTUUID>) addressing — no disk-enumeration-"
    echo "# order assumption, unlike the earlier hdd(N):<GUID> form this script"
    echo "# generated before v3.1.0-beta1 (which was invalid Limine URI syntax"
    echo "# and caused every kernel-mode boot attempt to PANIC with 'Failed to"
    echo "# open kernel with path... Is the path correct?')."
    echo "# Regenerated by void-limine-write-conf — do not hand-edit, it"
    echo "# will be overwritten on the next kernel update or cron run"
    echo "# (see /etc/cron.d/void-limine-sync)."

    echo ""
    # AI (Big Pickle) CHANGE — v3.3.0-beta2.1 [LIMINE-HDR]: the kernels are
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
            snap_desc="$(sed -n 's:.*<description>\(.*\)</description>.*:\1:p' "${snap_dir}info.xml" | head -n1)"
            [ -n "$snap_desc" ] || snap_desc="snapshot ${snap_id}"
            echo "    //${snap_desc} (#${snap_id})"
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

# AI (Big Pickle) ADDITION — v3.3.0-beta7 [YUBIKEY]: standalone keyscript that
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
if [ "$YK_MODE" = "hmac-sha1" ]; then
    mkdir -p /usr/local/sbin
    cat > /usr/local/sbin/void-reveal-yubikey-key << 'INNER_EOF'
#!/bin/sh
# dracut keyscript — prints the HMAC-SHA1 challenge-response OTP for the YubiKey.
# Never stores the response; the YubiKey's possession is the LUKS credential.
set -u
YK_SLOT="${YK_SLOT}"
YK_CHALLENGE="${YK_CHALLENGE}"
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

# AI (Claude, Sonnet 5, Medium) ADDITION — v3.1.0-beta1 [LIMINE-MULTI-KERNEL]
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

# AI (Big Pickle) ADDITION — v3.3.0-beta3 [LIMINE-ENV-LOAD]: shared loader.
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
    cp -f "/boot/vmlinuz-${_kver}" "/boot/efi/void-kernel/vmlinuz-${_kver}"
    cp -f "/boot/initramfs-${_kver}.img" "/boot/efi/void-kernel/initramfs-${_kver}.img"
done
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

# AI (Claude, Sonnet 5, Medium) ADDITION — v3.1.0-beta1 [KERNEL-HOOK] §4.10: kernel hook now
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
# esp-copy mode only) then void-limine-write-conf (menu generation) —
# both shared with the cron.d trigger, see [LIMINE-SYNC-CRON] and
# [LIMINE-MULTI-KERNEL].
set -eu
export PATH="/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"
/usr/local/sbin/void-limine-sync-kernels
/usr/local/sbin/void-limine-write-conf
INNER_EOF
chmod +x /etc/kernel.d/post-install/50-sync-limine-kernels.sh
cp /etc/kernel.d/post-install/50-sync-limine-kernels.sh /etc/kernel.d/post-remove/50-sync-limine-kernels.sh 2>/dev/null || \
    { mkdir -p /etc/kernel.d/post-remove; cp /etc/kernel.d/post-install/50-sync-limine-kernels.sh /etc/kernel.d/post-remove/50-sync-limine-kernels.sh; }

# AI (Claude, Sonnet 5, Medium) ADDITION — v3.1.0-beta1 [LIMINE-SYNC-CRON]: the actual
# durability fix for Open Item #2 — a plain /etc/cron.d drop-in survives
# xbps package updates untouched (nothing owns or overwrites it), needs no
# supervision/restart logic, and its failure mode is bounded (menu at most
# ~15 minutes stale) rather than silent-forever. Only regenerates
# limine.conf (cheap, a few KB) — it deliberately does NOT re-copy the
# kernel/initramfs on every run; that stays tied to actual kernel package
# transactions via the hook above, so this cron job never does needless
# multi-hundred-MB copies on a timer.
cat > /etc/cron.d/void-limine-sync << 'INNER_EOF'
# Regenerates /boot/efi/EFI/BOOT/limine.conf every 15 minutes so snapper
# timeline snapshots (hourly/daily/weekly, created independently of any
# kernel update) show up in the Limine /Snapshots menu promptly instead of
# only at the next kernel install/remove. See void-limine-write-conf.
# [SNPR-EV] This cron entry is now the SAFETY-NET fallback: the
# 00-void-limine-snapper-sync snapper plugin (below) already regenerates the
# menu the moment a snapshot is created/deleted, so this timer only covers
# menu changes the plugin path might miss (e.g. a manual snapshot taken via
# a tool that bypasses snapper's own plugin runner).
*/15 * * * * root /usr/local/sbin/void-limine-write-conf >/dev/null 2>&1
INNER_EOF
chmod 644 /etc/cron.d/void-limine-sync

# AI (Big Pickle) ADDITION — v3.3.0-beta4 [SNPR-EV]: event-driven snapshot-menu
# sync. Empirically verified on the target hardware (see Debug/snpr_ev/probe_void_snapper_plugin.sh):
# Void's snapper DOES execute /usr/lib/snapper/plugins — the probe observed
# create-snapshot-pre/post (and the delete-snapshot-pre/post family) firing for
# a single throwaway snapshot. That contradicts the old v3.1.0-beta1
# [LIMINE-SYNC-CRON] assumption that Void's snapper had NO hook mechanism (the
# premise for the 15-min cron). So instead of waiting up to 15 minutes for a
# timeline snapshot to appear, we now attach a tiny Void-native plugin that
# calls the SAME /usr/local/sbin/void-limine-write-conf, so the menu updates
# the instant snapper creates or deletes a snapshot.
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
#     menu-generation logic (kernel hook, cron, and now this plugin all call
#     the same script).
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
umount -fl /.snapshots || true
rmdir /.snapshots || true
snapper --no-dbus -c root create-config /
rmdir /.snapshots
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

mkdir -p /etc/cron.weekly
cat > /etc/cron.weekly/fstrim-nvme << 'INNER_EOF'
#!/bin/sh
export PATH="/usr/bin:/usr/sbin:/bin:/sbin"
if command -v fstrim >/dev/null 2>&1; then
    exec fstrim -A --quiet
else
    echo "ERROR: fstrim binary missing from the system path." >&2
    exit 1
fi
INNER_EOF
chmod +x /etc/cron.weekly/fstrim-nvme

# AI (Big Pickle) ADDITION — v3.3.0-beta5 [SCRUB]: monthly btrfs integrity
# scrub — the physical-corruption half of the recovery story (Snapper guards
# against logical/accidental damage; scrub catches silent checksum failures
# and repairs them). One pass per btrfs filesystem (subvolume mounts all
# share the same major:minor, so the mount list is deduped on that instead
# of scrubbing one fs once per subvol mount), logged to
# /var/log/btrfs-scrub.log. Never forced: if a manual scrub is already
# running, this monthly pass fails fast and records why rather than racing
# it. cron.monthly is executed by cronie's stock /etc/crontab (draining
# missed runs on boot), same mechanism the fstrim-nvme entry above relies on.
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
# AI (Big Pickle) ADDITION — v3.3.0-beta6 [ENCRYPT]: when encryption is
# enabled, dracut must also pull in the `crypt` module (LUKS unlocking — it
# installs its own copy of cryptsetup + udev rules) so the initramfs can
# prompt for the passphrase and open void-root before mounting root.
# Appended to the shared 90-system.conf so the crypt knowledge is inherited
# by every initramfs the kernel-hook regen loop builds.
if [ "$ENCRYPT" = "yes" ]; then
    echo 'add_dracutmodules+=" crypt "' >> /etc/dracut.conf.d/90-system.conf
fi

# AI (Big Pickle) ADDITION — v3.3.0-beta7 [YUBIKEY]: when YubiKey unlock is
# enabled, dracut must ship the keyscript + `ykchalresp` (and its libusb
# runtime) inside the initramfs, otherwise the boot unlock cannot run
# /usr/local/sbin/void-reveal-yubikey-key. Written as a dedicated `99void-`
# module (runs AFTER 90crypt's module-setup.sh, so its `/sbin/cryptroot-ask`
# override wins over 90crypt's) so the initramfs is self-contained. ykpers is
# a plain C + libusb tool, so `inst` + `inst_libdir_file` cover it — no
# heavyweight runtime.
# AI (Big Pickle) ADDITION — v3.3.0-beta7 [YUBIKEY]: the boot-unlock path
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
PATH=/usr/sbin:/usr/bin:/sbin:/bin
NEWROOT=${NEWROOT:-"/sysroot"}

# Don't ask if we already have root.
[ -f "$NEWROOT"/proc ] && exit 0

. /lib/dracut-lib.sh

mkdir -p -m 0700 /run/cryptsetup

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
        if [ -z "$name" -o "${name#\#}" != "$name" ]; then
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
        if "$keyscript" | cryptsetup -d - $cryptsetupopts luksOpen "$device" "$luksname"; then
            ask_passphrase=0
            break
        fi
        _keyscript_tries=$((_keyscript_tries - 1))
        [ -b /dev/mapper/"$luksname" ] && break
        sleep 1
    done
    unset _keyscript_tries
elif [ -n "$luksfile" -a "$luksfile" != "none" -a -e "$luksfile" ]; then
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

if [ "$is_keysource" -ne 0 -a "${luksname##luks-}" != "$luksname" ]; then
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
    echo 'add_dracutmodules+=" 99void-yubikey "' >> /etc/dracut.conf.d/90-system.conf
fi

mkdir -p /usr/lib/dracut/modules.d/95snapshot-overlay
cat > /usr/lib/dracut/modules.d/95snapshot-overlay/module-setup.sh << 'INNER_EOF'
#!/bin/bash

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
            mkdir -m 0755 -p /run/rootfsbase
            if mount --bind "$NEWROOT" /run/rootfsbase; then
                mkdir -m 0755 -p /run/overlayfs /run/ovlwork
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

# AI (Big Pickle) ADDITION — v3.2.0 [COSMIC]: when cosmic-greeter was chosen as
# the display manager, rc.local links /etc/sv/${DM_SERVICE_NAME}, so the runit
# service dir must exist or first boot leaves a dangling symlink. cosmic-greeter
# is from the third-party COSMIC repo; the maintainer warns it may not work
# reliably with elogind. We create a best-effort runit service that starts the
# greeter on the first free virtual terminal (matching the sddm wait-for-
# first-boot behavior so the network/file systems are up). Selecting it is the
# user's explicit at-own-risk choice.
if [ "$DISPLAY_MANAGER" = "cosmic-greeter" ]; then
    mkdir -p /etc/sv/cosmic-greeter
    cat > /etc/sv/cosmic-greeter/run << 'INNER_EOF'
#!/bin/sh
for i in $(seq 1 10); do
    if [ -d /run/initramfs ] || [ -f /var/log/firstboot.log ]; then
        break
    fi
    sleep 1
done
exec /usr/bin/cosmic-greeter
INNER_EOF
    chmod 0755 /etc/sv/cosmic-greeter/run
    echo "WARNING: cosmic-greeter was chosen as the display manager. Its maintainer reports it" >&2
    echo "         does not work reliably with elogind and recommends SDDM instead; it is being" >&2
    echo "         installed because you chose it, at your own risk. If the login screen fails" >&2
    echo "         to appear on first boot, install/login via a virtual console and switch to SDDM." >&2
fi

cat > /etc/rc.local << 'INNER_EOF'
#!/bin/sh
if command -v vkpurge >/dev/null 2>&1; then
    echo "==> Runtime Maintenance: Sweeping unreferenced kernel artifacts..."
    vkpurge rm all >/dev/null 2>&1
fi

if ! grep -q 'rd.live.overlay.overlayfs=1' /proc/cmdline 2>/dev/null; then
    mountpoint -q "/home/__TARGET_USER__/.cache" || mount "/home/__TARGET_USER__/.cache" 2>/dev/null || true
fi

if [ ! -f /var/log/firstboot.log ]; then
    mkdir -p /etc/runit/runsvdir/default
    ln -sfn /etc/sv/dbus /etc/runit/runsvdir/default/dbus
    ln -sfn /etc/sv/nftables /etc/runit/runsvdir/default/nftables
    ln -sfn /etc/sv/__DISPLAY_MANAGER__ /etc/runit/runsvdir/default/__DISPLAY_MANAGER__
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
    ln -sfn /etc/sv/bluetoothd /etc/runit/runsvdir/default/bluetoothd
    if [ "__SESSION_STACK__" = "turnstile" ]; then
        ln -sfn /etc/sv/turnstiled /etc/runit/runsvdir/default/turnstiled
        ln -sfn /etc/sv/seatd /etc/runit/runsvdir/default/seatd
        ln -sfn /etc/sv/acpid /etc/runit/runsvdir/default/acpid
    fi
    # AI (Big Pickle) CHANGE — v3.3.0-beta2 [LIGHTDM-HW]: enable the mklive
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
    # install branch (see [LIGHTDM-HW] there); when it's absent the guard
    # below refuses to create a dangling link.
    [ "__DISPLAY_MANAGER__" = "lightdm" ] && \
        [ -d /etc/sv/accounts-daemon ] && \
        ln -sfn /etc/sv/accounts-daemon /etc/runit/runsvdir/default/accounts-daemon
    [ "__SESSION_STACK__" = "elogind" ] && \
        ln -sfn /etc/sv/elogind /etc/runit/runsvdir/default/elogind
    ln -sfn /etc/sv/polkitd /etc/runit/runsvdir/default/polkitd
    # AI (Big Pickle) ADDITION — v3.2.0 [SWAP]: enable the zramen (zram) runit
    # service on first boot when the chosen backend uses zram (zram or both).
    [ "__SWAP_BACKEND__" = "zram" ] || [ "__SWAP_BACKEND__" = "both" ] && \
        ln -sfn /etc/sv/zramen /etc/runit/runsvdir/default/zramen
    for i in $(seq 1 15); do
        if [ -S /run/dbus/system_bus_socket ]; then
            break
        fi
        sleep 1
    done

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

    if command -v flatpak >/dev/null 2>&1; then
        # AI (Big Pickle) CHANGE — v3.3.0-beta4 [FLATHUB-RCL]: this block used
        # to run `flatpak remote-add` synchronously at first boot. That is a
        # BLOCKING network fetch (flathub.flatpakrepo + summary.idx) and
        # rc.local runs in runit stage 2 BEFORE NetworkManager is up, so when
        # Flatpak was selected the boot hung on a "Flathub idx / Failed to
        # fetch summary" error. The remote is now added inside the chroot at
        # install time (see [FLATHUB-CHROOT]) where the network is already up;
        # here we only (a) re-guard the add as an idempotent no-op fallback,
        # (b) wait for the network to come up, and (c) launch any queued app
        # install in the BACKGROUND so rc.local never blocks boot on the
        # network or on flatpak.
        flatpak remote-add --if-not-exists flathub https://flathub.org 2>/dev/null || true
        flatpak remote-modify --enable flathub 2>/dev/null || true
        # AI (Claude, Sonnet 5, Medium) ADDITION: installs any Flatpak apps
        # queued at install time (currently just Brave, when selected
        # without an official Void package available — see Stage 2's
        # WEB BROWSER SELECTION handling). Queue file is one app ID per
        # line; only present at all if something was actually queued.
        _fp_queue="/home/__TARGET_USER__/.config/void-installer/flatpak-install-on-first-boot.txt"
        if [ -f "$_fp_queue" ]; then
            (
                # Wait (bounded) for a route to reach flathub before trying;
                # without this the background install would fail instantly.
                i=0
                while [ "$i" -lt 90 ]; do
                    if getent hosts flathub.org >/dev/null 2>&1; then
                        break
                    fi
                    sleep 2
                    i=$((i + 1))
                done
                while IFS= read -r _fp_app_id; do
                    [ -n "$_fp_app_id" ] || continue
                    if flatpak remote-list --columns=name 2>/dev/null | grep -qx 'flathub'; then
                        echo "==> Installing queued Flatpak app: ${_fp_app_id}"
                        flatpak install -y --noninteractive flathub "$_fp_app_id" || \
                            echo "WARNING: failed to install queued Flatpak app '${_fp_app_id}' — install it manually later with 'flatpak install flathub ${_fp_app_id}'." >&2
                    else
                        echo "WARNING: flathub remote unavailable at first boot; queued Flatpak app '${_fp_app_id}' NOT installed. Install it manually later." >&2
                        break
                    fi
                done < "$_fp_queue"
            ) > /var/log/flatpak-firstboot.log 2>&1 &
        fi
    fi
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database -q
    fi
    mkdir -p /var/log
    touch /var/log/firstboot.log
fi
INNER_EOF

# AI (Claude, Sonnet 5, Medium) FIX: __BOOTLOADER__/__INSTALL_VIRT__/
# __INSTALL_DOCKER__/__DISPLAY_MANAGER__ are new placeholders alongside
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
# — v3.2.0 [item 9]) follows here too so the first-boot block that (only
# when SESSION_STACK=turnstile) links turnstiled/seatd/acpid sees the
# real choice rather than the always-empty install variable.
sed -i \
    -e "s/__TARGET_USER__/${TARGET_USER}/g" \
    -e "s/__BOOTLOADER__/${BOOTLOADER}/g" \
    -e "s/__INSTALL_VIRT__/${INSTALL_VIRT}/g" \
    -e "s/__INSTALL_DOCKER__/${INSTALL_DOCKER}/g" \
    -e "s/__DISPLAY_MANAGER__/${DM_SERVICE_NAME}/g" \
    -e "s/__SESSION_STACK__/${SESSION_STACK}/g" \
    -e "s/__SWAP_BACKEND__/${SWAP_BACKEND}/g" \
    /etc/rc.local
chmod +x /etc/rc.local

# NOTE: "xbps-trigger kernel-hooks" is not a real xbps command. Kernel
# hooks under /etc/kernel.d/post-install/ (including our
# 50-sync-limine-kernels.sh above) are fired by xbps-reconfigure(1) when it
# reconfigures a kernel package. -f forces that even though the package is
# already "configured", so the hook runs now instead of waiting for the
# next real kernel update.
xbps-reconfigure -f linux-mainline

# CRITICAL — DO NOT REMOVE: must run after xbps-reconfigure -f
# linux-mainline above, not before — its own kernel-package post-install
# hook fires a second dracut run of its own, producing a smaller initramfs
# that no longer carries our custom dracut.conf.d modules. Running this
# loop LAST guarantees our explicitly-built, fully-featured initramfs is
# what actually ships.
for kver_dir in /lib/modules/*; do
    kver="$(basename "$kver_dir")"
    dracut --force "/boot/initramfs-${kver}.img" "$kver"
done

if [ "$BOOTLOADER" = "limine" ]; then
# AI (Claude, Sonnet 5, Medium) ADDITION — v3.1.0-beta1 [KERNEL-HOOK follow-up] §4.15: re-sync
# the ESP copies (and rewrite limine.conf) AFTER the dracut regen loop
# above, closing the same ordering gap 3.0.x fixed for grub-mkconfig — the
# initial sync earlier in this block predates the final, fully-featured
# initramfs build; without this second call the ESP would ship the
# smaller pre-custom-module initramfs xbps-reconfigure produced as a side
# effect. Uses the same shared scripts the kernel hook and cron.d entry
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

umount -v /mnt/boot/efi || true
umount -v /mnt/boot/grub || true
umount -fl /mnt/dev || true
umount -fl /mnt/proc || true
umount -fl /mnt/sys || true
umount -fl /mnt/run || true

umount -v /mnt/var/swap || true
umount -v /mnt/var/tmp || true
umount -v /mnt/var/spool || true
umount -v /mnt/var/log || true
umount -v /mnt/var/lib/libvirt || true
# AI (Big Pickle) CHANGE — v3.2.0 [item 3]: lightdm umount added alongside
# sddm; both are no-op-safe (|| true) when the matching DM wasn't chosen.
umount -v /mnt/var/lib/sddm || true
umount -v /mnt/var/lib/lightdm || true
umount -v /mnt/var/cache || true
umount -v /mnt/srv || true
umount -v /mnt/opt || true
umount -v /mnt/.snapshots || true
umount -v /mnt/home || true
umount -v /mnt || true

# AI (Big Pickle) ADDITION — v3.2.0 [item 10]: POST-INSTALL "NEXT STEPS" SUMMARY.
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
# AI (Big Pickle) ADDITION — v3.3.0-beta4 [SHELL]: echo the chosen login shell
# so the summary confirms which shell the primary user will get at first login.
echo "${C_BOLD}  Login shell:${C_RST}  ${USER_SHELL}"
echo "${C_BOLD}  Desktop:${C_RST}      ${_DE_FRIENDLY} (${DESKTOP_ENV})"
echo "${C_BOLD}  Display manager:${C_RST} ${DISPLAY_MANAGER}"
# AI (Big Pickle) CHANGE — v3.3.0-beta2 [LIGHTDM-HW]: echo which LightDM
# greeter was selected (only LightDM has a greeter choice), so the summary
# confirms the exact greeter that will greet first boot.
if [ "$DISPLAY_MANAGER" = "lightdm" ]; then
    case "$LIGHTDM_GREETER_SESSION" in
        lightdm-slick-greeter)   _GREETER_FRIENDLY="Slick (lightdm-slick-greeter)" ;;
        lightdm-webkit2-greeter) _GREETER_FRIENDLY="WebKit2 (lightdm-webkit2-greeter)" ;;
        lightdm-gtk-greeter)     _GREETER_FRIENDLY="GTK (lightdm-gtk-greeter)" ;;
        *)                       _GREETER_FRIENDLY="${LIGHTDM_GREETER_SESSION:-<not selected>}" ;;
    esac
    echo "${C_BOLD}  Greeter:${C_RST}       ${_GREETER_FRIENDLY}"
    unset _GREETER_FRIENDLY
fi
echo "${C_BOLD}  Bootloader:${C_RST}   ${BOOTLOADER}"
# AI (Big Pickle) ADDITION — v3.2.0 [LOCALIZE]: echo the chosen locale and
# timezone in the summary so the user knows the target's configured language
# and zone before first boot.
echo "${C_BOLD}  Locale:${C_RST}        ${LOCALE}"
echo "${C_BOLD}  Timezone:${C_RST}     ${TIMEZONE}"
# AI (Big Pickle) ADDITION — v3.2.0 [SWAP]: echo the swap backend and whether
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
echo "     at the console and run:  ${C_BOLD}ln -sf /etc/sv/${DISPLAY_MANAGER} /etc/runit/runsvdir/default/${C_RST}  (or your chosen DM)."
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
echo ""
echo "${C_GRN}======================================================================${C_RST}"
# AI (Big Pickle) ADDITION — v3.2.0 [RESUME]: The install completed fully, so
# the resume record is no longer needed — remove it so the next run starts
# fresh instead of offering to resume an already-finished install.
STAGE_CONTEXT="DONE"
jl "Install COMPLETED successfully (bootloader=${BOOTLOADER}, DE=${DESKTOP_ENV})"
[ -f "$STATE_FILE" ] && rm -f "$STATE_FILE"
# AI (Big Pickle) ADDITION — v3.3.0-beta3 [INSTALL-CONFIG]: carry an exact copy
# of the installer that built this machine into the target (alongside the
# /etc/void-installer/install-config summary written in the chroot), so the
# running system records both WHAT was chosen and WHICH revision built it.
mkdir -p /mnt/etc/void-installer
if [ -n "$0" ] && [ -f "$0" ]; then
    cp -f "$0" /mnt/etc/void-installer/Void_Linux_Installer.sh 2>/dev/null \
        && jl "Installer script archived to /etc/void-installer/Void_Linux_Installer.sh" \
        || echo "WARNING: could not archive installer script into target." >&2
fi
# AI (Big Pickle) CHANGE — v3.3.0-beta2 [REBOOT-COUNTDOWN]: the pre-reboot
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
