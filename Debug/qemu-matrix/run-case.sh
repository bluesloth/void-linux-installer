#!/bin/bash
# =============================================================================
# QEMU matrix harness for Void_Linux_Installer.sh BIOS/UEFI boot support.
#
# usage: run-case.sh <case>
#   cases:  dryrun-bios-limine  dryrun-bios-grub  dryrun-uefi-limine
#           bios-limine-plain   bios-grub-plain   bios-limine-encrypt
#           bios-grub-encrypt   uefi-limine-plain uefi-grub-plain
#
# Each case: fresh qcow2 -> boot the REAL void-live medium (kernel/initrd
# extracted from the ISO so console=ttyS0 gives a scriptable serial console)
# -> one driver run that logs in, preinstalls gptfdisk/limine (absent from
# this medium), drives Void_Linux_Installer.sh, then probes the result.
# A non-dry case then cold-boots the installed disk in the SAME firmware mode
# and screendumps the bootloader menu + login prompt.
# =============================================================================
set -u
# --- self-snapshot -----------------------------------------------------------
# This harness gets edited while older cases are still running, and bash reads
# a script file AS it executes: an in-place edit shifts the byte offsets, so the
# running copy resumes mid-line. It once died with a syntax error at line 175
# (rc=2) right at the end of two otherwise successful installs — and its
# cleanup never ran, orphaning both guests. Execute a private copy instead, so
# an edit can only ever affect the NEXT case. VLI_SNAPSHOT=0 opts out.
if [ -z "${VLI_SNAPSHOT:-}" ]; then
    _snap=$(mktemp "${TMPDIR:-/tmp}/vlio-run-case.XXXXXX") || exit 1
    cp -- "$(readlink -f "$0")" "$_snap" || exit 1
    exec env VLI_SNAPSHOT=1 VLI_REALDIR="$(cd "$(dirname "$0")" && pwd)" bash "$_snap" "$@"
fi
HERE=${VLI_REALDIR:-$(cd "$(dirname "$0")" && pwd)}
[ -n "${VLI_REALDIR:-}" ] && trap 'rm -f -- "$0"' EXIT
# Default SRC = the installer tree two levels up from Debug/qemu-matrix, so the
# harness travels with the repo; every path is overridable from the environment.
SRC=${VLI_SRC:-$(cd "$HERE/../.." && pwd)}
cd "$HERE"

CASE=${1:?usage: run-case.sh <case>}
# Machine-independent by design: both default INSIDE this directory and are
# gitignored, so the committed script carries no local usernames, hostnames or
# device identifiers (the project's sanitize deny-list would block it).
#   VLI_ISO=/path/to/void-live-*.iso   the live medium (or symlink it to ./void-live.iso)
#   VLI_DATA=/path/to/artifacts        per-case qcow2/log/PNG output
ISO=${VLI_ISO:-$HERE/void-live.iso}
DATA=${VLI_DATA:-$HERE/artifacts}
# Live kernel/initrd extracted from the ISO once (see README); absolute, so a
# case can be launched from any working directory.
LIVE_EXTRACT=${VLI_LIVE_EXTRACT:-$HERE/live-extract}
mkdir -p "$DATA"
if [ ! -r "$ISO" ]; then
    printf 'FATAL: live ISO not found: %s\n' "$ISO" >&2
    printf '       ln -s /path/to/void-live-*.iso %s/void-live.iso\n' "$HERE" >&2
    printf '       ...or export VLI_ISO=/path/to/void-live-*.iso\n' >&2
    exit 9
fi
# --- sockets vs artifacts ----------------------------------------------------
# AF_UNIX socket paths are capped at 108 bytes on Linux, and this tree lives
# deep on removable media: keeping the sockets next to the artifacts put them
# at 172 chars and every case died instantly with
# "OSError: AF_UNIX path too long" (the old out-of-tree path was 97 — it fit
# by 11). So transient IPC stays in a short, machine-independent dir while the
# bulky artifacts (qcow2, logs, PNGs) live wherever VLI_DATA points.
SOCKDIR=${VLI_SOCKDIR:-/tmp/vlio-sock}
mkdir -p "$SOCKDIR"
SSOCK=$SOCKDIR/$CASE-serial.sock
QSOCK=$SOCKDIR/$CASE-qmp.sock
IMG=$DATA/$CASE.qcow2
LOG=$DATA/$CASE.log
# EDK2 firmware dir (OVMF_VARS.fd / OVMF_CODE.fd) — Debian/Fedora/Arch layout
OVMF=${VLI_OVMF:-/usr/share/edk2/x64}

# --- removable-media guard ---------------------------------------------------
# A full case sustains gigabytes/minute of qcow2 writes (xbps unpack), plus 9p
# script reads and the OVMF/ISO loads. When those paths sit on a USB-attached
# filesystem whose bus is unhealthy, the GUEST wedges first: its btrfs
# transactions block on qcow2 I/O that never completes, the console fills with
# hung-task spam and then goes silent — the driver calls it rc=7 ("serial dead
# ≥420 s") although QMP screenshots still work, because QEMU itself never
# died. Two overnight waves were lost exactly that way while the host log
# showed USB disconnects and its own btrfs writers stuck on an rw-semaphore
# the same evening. Warn — never fail — when a hot path is on removable
# media; run the harness state from a local disk (override VLI_DATA/VLI_SRC/
# VLI_ISO/VLI_LIVE_EXTRACT).
_VLI_REM_WARNED=
_warn_if_removable() { # $1 = label, $2 = path
    local dev parent
    dev=$(findmnt -n -o SOURCE --target "$2" 2>/dev/null) || return 0
    case "$dev" in /dev/*) ;; *) return 0 ;; esac
    dev=${dev%%\[*}   # btrfs subvolume mounts print /dev/sdX1[/@subvol]
    # PKNAME on a whole disk is empty (fall back to the disk itself); strip
    # whitespace — lsblk right-aligns padded columns and " sda" != "sda".
    parent=$(lsblk -no PKNAME "$dev" 2>/dev/null | tr -d '[:space:]')
    [ -z "$parent" ] && parent=${dev##*/}
    [ -r "/sys/class/block/$parent/removable" ] || return 0
    [ "$(cat "/sys/class/block/$parent/removable" 2>/dev/null)" = "1" ] || return 0
    case " $_VLI_REM_WARNED " in *" $parent "*) return 0 ;; esac
    _VLI_REM_WARNED="$_VLI_REM_WARNED $parent"
    printf 'WARN: %s lives on removable disk %s (%s)\n' "$1" "$parent" "$2" >&2
    printf '      sustained installs have frozen there before — prefer a local disk\n' >&2
    return 0
}
_warn_if_removable SRC     "$SRC"
_warn_if_removable ISO     "$ISO"
_warn_if_removable EXTRACT "$LIVE_EXTRACT"
_warn_if_removable DATA    "$DATA"

case "$CASE" in
    dryrun-*)   DRY=1 ;;
    *)          DRY=0 ;;
esac
case "$CASE" in *grub*)    BOOTLOADER=grub  ;; *) BOOTLOADER=limine ;; esac
case "$CASE" in *encrypt*) ENCRYPT=yes      ;; *) ENCRYPT=no        ;; esac
# Substring matches, NOT anchored: the dry-run cases are named
# `dryrun-uefi-*` / `dryrun-bios-*`, so `uefi*)` silently classified every
# UEFI dry-run as BIOS (first attempt: a "UEFI control" that reported
# `==> Boot mode: legacy BIOS`).
case "$CASE" in *uefi*)    MODE=uefi        ;; *) MODE=bios         ;; esac

echo "### case=$CASE mode=$MODE bootloader=$BOOTLOADER encrypt=$ENCRYPT dry=$DRY"

# ---------------------------------------------------------------- fresh disk
# A case that died before reaching its cleanup leaves its guest running: it
# would hold the serial/QMP listeners and share the disk with the new run (the
# rc=2 incident above orphaned two guests exactly this way). Match on the
# qcow2 argument specifically — the bracket stops pkill matching its own
# command line, and no other process here puts "<case>.qcow2" in one.
pkill -9 -f "[q]emu-system.*[/-]$CASE\.qcow2" 2>/dev/null || true
rm -f "$IMG" "$SSOCK" "$QSOCK" "$LOG" "$DATA/$CASE-boot"*.png "$DATA/$CASE-vars.fd"
qemu-img create -f qcow2 "$IMG" 40G >/dev/null

# ------------------------------------------------------------- firmware mode
FW_ARGS=()
if [ "$MODE" = "uefi" ]; then
    cp -f "$OVMF/OVMF_VARS.fd" "$DATA/$CASE-vars.fd"
    FW_ARGS=(-drive "if=pflash,format=raw,readonly=on,file=$OVMF/OVMF_CODE.fd"
             -drive "if=pflash,format=raw,file=$DATA/$CASE-vars.fd")
fi

# --------------------------------------------------------------- live session
# Firmware must be active in the LIVE session too: BOOT_MODE is derived from
# /sys/firmware/efi on the machine that RUNS the installer, and a live session
# booted without OVMF would (correctly) report legacy BIOS and turn a UEFI
# control case into a second BIOS case — that is exactly what the first
# dryrun-uefi-limine run did.
#
# Under OVMF the live medium also cannot ride on the IDE CD: ata_piix probes
# both PIIX channels and finds no device (identical `-cdrom` + SeaBIOS boots
# the same kernel/initrd and sees it), so dracut's root=live:CDLABEL= lookup
# fails and the run drops to the emergency shell. Resolving the label through
# blkid does not care which bus the medium is on, so a UEFI case puts the ISO
# on a second virtio disk instead (read-only). The target image is attached
# FIRST so it stays /dev/vda — the live medium on vdb is mounted and is
# filtered out of the installer's disk menu exactly like the CD was.
CMDLINE="root=live:CDLABEL=VOID_LIVE init=/sbin/init ro rd.luks=0 rd.md=0 rd.dm=0 loglevel=4 vconsole.unicode=1 vconsole.keymap=us locale.LANG=en_US.UTF-8 rd.overlay=LABEL=VOID_OVL console=tty0 console=ttyS0,115200"

# The live KDE session's power management suspends the WHOLE VM (ACPI S3)
# after a few idle minutes of VGA input — QMP then reports
# {"status": "suspended"} and the serial-driven install freezes mid-xbps
# install with no output, no CPU and no I/O (it cost two full installs to
# diagnose; the driver saw 20 minutes of dead silence). PIIX4_PM is the
# i440FX ACPI PM device, so disabling S3/S4 makes the guest's sleep request a
# no-op. Purely test-side: the installer never sees this difference.
NO_SUSPEND=(-global PIIX4_PM.disable_s3=1 -global PIIX4_PM.disable_s4=1)

# ------------------------------------------------------------------------
# media_probe <tag> <qemu media args...>
#
# Boot the REAL ISO under SeaBIOS with no -kernel/-initrd, i.e. exercise the
# medium's own firmware boot chain (isolinux + El Torito / isohybrid MBR),
# which every install case in this matrix bypasses by hand-feeding QEMU the
# extracted kernel. The live console is VGA-only (the isolinux cmdline has no
# console=ttyS0), so serial stays silent BY DESIGN here: progress is judged
# from the screendumps and from how many DISTINCT screens the guest showed
# (isolinux menu -> kernel scroll -> desktop means >= 3).
# Returns 1 when the screen never changed (firmware never got past the menu).
media_probe() {
    local tag=$1; shift
    local pid t prev=0 h frames=""
    rm -f "$QSOCK" "$DATA/$CASE-$tag"*.png
    qemu-system-x86_64 -machine pc -enable-kvm -m 3072 \
        "$@" \
        "${NO_SUSPEND[@]}" \
        -display none -vga std \
        -qmp "unix:$QSOCK,server,nowait" >/dev/null 2>&1 &
    pid=$!
    for i in $(seq 1 200); do [ -S "$QSOCK" ] && break; sleep 0.25; done
    prev=0
    for t in 10 25 45 75 120; do
        sleep $((t - prev)); prev=$t
        python3 qmp-dump.py "$QSOCK" "$DATA/$CASE-$tag$t.ppm" >/dev/null 2>&1
        h=$(md5sum < "$DATA/$CASE-$tag$t.ppm" 2>/dev/null | cut -c1-12)
        python3 ppm2png.py "$DATA/$CASE-$tag$t.ppm" "$DATA/$CASE-$tag$t.png" >/dev/null 2>&1
        rm -f "$DATA/$CASE-$tag$t.ppm"
        frames="$frames $h"
        echo "### $tag ${t}s md5=$h -> $DATA/$CASE-$tag$t.png"
    done
    kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
    distinct=$(echo $frames | tr ' ' '\n' | sort -u | grep -c .)
    echo "### $tag: $distinct distinct screen(s) in 120s"
    [ "$distinct" -ge 2 ]
}

# The ISO-media case never touches a disk: it boots the medium itself twice
# (CD / El Torito, then the isohybrid image attached as a raw disk — what a
# flashed USB stick looks like to firmware) and stops. ~4.5 min of waiting.
if [ "$CASE" = "iso-bios-media" ]; then
    rm -f "$IMG"    # the fresh-disk section above made an image this case never uses
    echo "### media-path case: booting the REAL ISO under SeaBIOS (no -kernel)"
    mrc=0
    media_probe cd -cdrom "$ISO" -boot order=d || mrc=8
    media_probe usb -drive "file=$ISO,format=raw,if=virtio,readonly=on" -boot order=c || mrc=8
    echo "### case $CASE complete rc=$mrc — inspect $CASE-{cd,usb}*.png"
    exit "$mrc"
fi

if [ "$MODE" = "uefi" ]; then
    LIVE_MEDIA=(-drive "file=$ISO,format=raw,if=virtio,readonly=on")
else
    LIVE_MEDIA=(-cdrom "$ISO")
fi

if [ ! -r "$LIVE_EXTRACT/vmlinuz" ] || [ ! -r "$LIVE_EXTRACT/initrd" ]; then
    echo "FATAL: missing $LIVE_EXTRACT/{vmlinuz,initrd} (needed to boot the live medium)" >&2
    echo "       mkdir -p '$LIVE_EXTRACT' && 7z e -o'$LIVE_EXTRACT' <ISO> boot/vmlinuz boot/initrd" >&2
    exit 9
fi

qemu-system-x86_64 -machine pc -enable-kvm -m 3072 \
    -kernel "$LIVE_EXTRACT/vmlinuz" -initrd "$LIVE_EXTRACT/initrd" -append "$CMDLINE" \
    -drive "file=$IMG,format=qcow2,if=virtio" \
    "${LIVE_MEDIA[@]}" \
    "${FW_ARGS[@]}" \
    "${NO_SUSPEND[@]}" \
    -netdev user,id=n0 \
    -device virtio-net-pci,netdev=n0 \
    -virtfs "local,path=$SRC,mount_tag=vlio,security_model=none,readonly" \
    -display none -vga std \
    -serial "unix:$SSOCK,server,nowait" \
    -qmp "unix:$QSOCK,server,nowait" >"$DATA/$CASE-qemu.log" 2>&1 &
QPID=$!
for i in $(seq 1 200); do [ -S "$SSOCK" ] && [ -S "$QSOCK" ] && break; sleep 0.25; done
echo "### qemu live pid=$QPID"

DRIVER_ARGS=(--sock "$SSOCK" --log "$LOG" --src "$SRC" --qmp "$QSOCK"
             --bootloader "$BOOTLOADER" --encrypt "$ENCRYPT" --mode "$MODE" --max 6600)
[ "$DRY" = "1" ] && DRIVER_ARGS+=(--dry)

# 9600 s outer / 6200 s install window. A clean install is ~25-35 min, but the
# runs that had to fight guest sleeps plus a USB disk shared with a second
# VM needed 55+ min and were killed at the 50-min window even though the
# bootloader step was executing (grub-install i386-pc) and the completion
# marker eventually arrived. The window only bounds "still working but slow":
# a genuinely dead serial is still caught by the watchdog's 7-minute give-up,
# and a wedged verify by its own idle timeouts.
timeout 9600 python3 run-install.py "${DRIVER_ARGS[@]}" 2>&1 | tee "$DATA/$CASE.driver.out"
DRIVER_RC=${PIPESTATUS[0]}
echo "### driver exit=$DRIVER_RC"

kill "$QPID" 2>/dev/null; wait "$QPID" 2>/dev/null
rm -f "$SSOCK"

# ------------------------------------------- cold-boot the installed disk
if [ "$DRY" = "0" ] && [ "$DRIVER_RC" = "0" ]; then
    echo "### cold-booting the installed disk ($MODE)"
    qemu-system-x86_64 -machine pc -enable-kvm -m 3072 \
        -drive "file=$IMG,format=qcow2,if=virtio" \
        -netdev user,id=n0 \
        -device virtio-net-pci,netdev=n0 \
        "${FW_ARGS[@]}" \
        "${NO_SUSPEND[@]}" \
        -display none -vga std \
        -qmp "unix:$QSOCK,server,nowait" >/dev/null 2>&1 &
    BPID=$!
    for i in $(seq 1 200); do [ -S "$QSOCK" ] && break; sleep 0.25; done
    prev=0
    for t in 10 20 40 90; do
        sleep $((t - prev)); prev=$t
        python3 qmp-dump.py "$QSOCK" "$DATA/$CASE-boot$t.ppm" >/dev/null 2>&1
        python3 ppm2png.py "$DATA/$CASE-boot$t.ppm" "$DATA/$CASE-boot$t.png" >/dev/null 2>&1
        rm -f "$DATA/$CASE-boot$t.ppm"
        echo "### screendump at ${t}s -> $DATA/$CASE-boot$t.png"
    done
    if [ "$ENCRYPT" = "yes" ]; then
        echo "### typing LUKS passphrase at the console"
        # qmp-sendkey.py decodes \n itself now: bash single quotes hand it a
        # literal backslash-n, HMP rejects `sendkey \` as an unknown key name,
        # and the guest ended up with the password minus its Enter — every
        # ENCRYPT cold boot sat at the prompt, and "typed 11 chars" in this log
        # was the only tell (cryptsetup does not echo, so the screendumps of a
        # stuck and an unlocking boot looked alike). A failed send is a
        # failed case: rc=8, not a warning to be scrolled past.
        COLD_RC=""
        python3 qmp-sendkey.py "$QSOCK" 'testpass1\n' \
            || { echo "### FATAL: qmp-sendkey failed — unlock was NOT attempted (rc=8)"; COLD_RC=8; }
        # Poll for the unlock instead of sleeping blind — in TWO stages,
        # because the pre-fix bios-grub-encrypt run passed rc=0 with NOTHING
        # typed and a single-change poll is exactly what would wave it
        # through again: the first post-typing frame differed from the
        # pre-typing one only by the prompt's cursor cell, and a WRONG
        # passphrase makes dracut reprint the prompt once (a change!) before
        # going static. So: (1) the frame must change within 90 s — a
        # correct passphrase has cryptsetup accepting in seconds and the
        # kernel resuming its console flood; (2) it must change AGAIN over
        # the next 30 s, because an unlocking boot keeps printing while a
        # re-prompted one sits still. Either failure = failed unlock = rc=8.
        if [ -z "$COLD_RC" ]; then
            firstsum="" sum=""
            for _i in $(seq 1 18); do
                sleep 5
                python3 qmp-dump.py "$QSOCK" "$DATA/$CASE-boot135.ppm" >/dev/null 2>&1
                sum=$(md5sum < "$DATA/$CASE-boot135.ppm" 2>/dev/null | cut -d' ' -f1)
                [ -z "$firstsum" ] && firstsum=$sum
                [ "$sum" != "$firstsum" ] && break
            done
            python3 ppm2png.py "$DATA/$CASE-boot135.ppm" "$DATA/$CASE-boot135.png" >/dev/null 2>&1
            rm -f "$DATA/$CASE-boot135.ppm"
            echo "### screendump after unlock -> $DATA/$CASE-boot135.png"
            if [ "$sum" = "$firstsum" ]; then
                echo "### FATAL: screen never changed after the unlock attempt — see the frame above (rc=8)"
                COLD_RC=8
            else
                firstsum=$sum
                sleep 30
                python3 qmp-dump.py "$QSOCK" "$DATA/$CASE-boot135.ppm" >/dev/null 2>&1
                sum=$(md5sum < "$DATA/$CASE-boot135.ppm" 2>/dev/null | cut -d' ' -f1)
                if [ "$sum" = "$firstsum" ]; then
                    python3 ppm2png.py "$DATA/$CASE-boot135.ppm" "$DATA/$CASE-boot135-verify.png" >/dev/null 2>&1
                    echo "### FATAL: one frame change then static — a re-prompted (wrong) passphrase, not an unlock (rc=8); see $CASE-boot135-verify.png"
                    COLD_RC=8
                fi
                rm -f "$DATA/$CASE-boot135.ppm"
            fi
        fi
    fi
    kill "$BPID" 2>/dev/null; wait "$BPID" 2>/dev/null
fi

[ -n "${COLD_RC:-}" ] && DRIVER_RC=$COLD_RC
echo "### case $CASE complete; log=$LOG rc=$DRIVER_RC"
exit "$DRIVER_RC"
