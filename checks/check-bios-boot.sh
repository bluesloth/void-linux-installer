#!/bin/bash
# checks/check-bios-boot.sh
# Version-3.1.00 [BIOS-BOOT] gate: every firmware-dependent path must sit
# behind an explicit `$BOOT_MODE` gate, and every BIOS-only artifact must be
# wired end to end — detection -> geometry -> budget -> chroot_env -> carve ->
# Stage 2 -> config generator -> records. Purely static: it reads the
# installer as text, so it runs rootless and cannot touch a live system.
#
# The proximity checks (a construct must be preceded within N lines by its
# gate) are deliberately textual rather than an AST walk: they are the checks
# that keep a later refactor from silently un-gating a UEFI-only command,
# which under `set -eE` would turn into a hard FATAL on a legacy boot.
DIR="$(cd "$(dirname "$0")" && pwd)"
SRC=${1:-"$DIR/../Void_Linux_Installer.sh"}
[ -f "$SRC" ] || { echo "EXTRACT FAILED (no installer at $SRC)"; exit 1; }

pass=0; fail=0
ok()   { pass=$((pass+1)); printf 'ok   %-46s\n' "$1"; }
bad()  { fail=$((fail+1)); printf 'FAIL %-46s -> %s\n' "$1" "$2"; }

has()      { grep -qF -- "$1" "$SRC"; }
line_of()  { grep -nF -- "$1" "$SRC" | head -1 | cut -d: -f1; }

check()    { # check <name> <literal> — the text exists somewhere
    if has "$2"; then ok "$1"; else bad "$1" "missing: $2"; fi
}

# every_line_gated <name> <literal> <gate-substring> <window-lines>
# EVERY non-comment occurrence of <literal> must have <gate-substring> within
# the preceding <window> lines (comment-only hits are ignored so the docs can
# mention the command freely).
every_line_gated() {
    local name=$1 lit=$2 gate=$3 win=$4 n from hits=0
    while read -r n; do
        case "$(sed -n "${n}p" "$SRC" | sed 's/^[[:space:]]*//')" in \#*) continue ;; esac
        hits=$((hits+1))
        from=$(( n > win ? n - win : 1 ))
        if ! sed -n "${from},${n}p" "$SRC" | grep -qF -- "$gate"; then
            bad "$name" "ungated occurrence at line $n (window $from..$n lacks '$gate')"
            return 0
        fi
    done < <(grep -nF -- "$lit" "$SRC" | cut -d: -f1)
    if [ "$hits" -eq 0 ]; then bad "$name" "no occurrence of '$lit'"; else ok "$name"; fi
}

echo "== Version-3.1.00 [BIOS-BOOT] gate: $SRC"

# --- A. detection and plumbing ---------------------------------------------
if has 'if [ -d /sys/firmware/efi ]' && has 'BOOT_MODE="uefi"' \
   && has 'BOOT_MODE="bios"' && has 'export BOOT_MODE'; then
    ok "detect /sys/firmware/efi -> uefi|bios + export"
else
    bad "detect /sys/firmware/efi -> uefi|bios + export" "detection block incomplete"
fi

_nd=$(grep -nF 'if [ -d /sys/firmware/efi ]' "$SRC" | grep -v ':[[:space:]]*#' | head -1 | cut -d: -f1)
_nr=$(grep -nF 'if [ "$RESUME" != "1" ]' "$SRC" | grep -v ':[[:space:]]*#' | head -1 | cut -d: -f1)
if [ -n "$_nd" ] && [ -n "$_nr" ] && [ "$_nd" -lt "$_nr" ]; then
    ok "detection runs before the RESUME gate (line $_nd < $_nr)"
else
    bad "detection runs before the RESUME gate" "detect=$_nd resume=$_nr"
fi

check "BOOT_MODE in resume-state var list" \
      'TARGET_DOMAIN TARGET_FQDN NET_INTERFACE_MATCH BOOTLOADER BOOT_MODE \'
check "BOOT_MODE exported into Stage-2 chroot env" \
      'echo "export BOOT_MODE=\"$BOOT_MODE\"" >> /mnt/tmp/chroot_env.sh'
check "BOOT_MODE recorded in install-config" 'BOOT_MODE="${BOOT_MODE:-<unset>}"'
check "BOOT_MODE in DRY-RUN plan"  'Boot mode             : ${BOOT_MODE:-<unset>}'
check "BOOT_MODE in final summary" 'Boot mode:${C_RST}     ${BOOT_MODE}'
check "BOOT_MODE in crash-log dump" 'BOOT_MODE=${BOOT_MODE:-<n/a>}'
check "mode banner (both branches echoed)" '==> Boot mode: legacy BIOS'
check "mode banner UEFI branch" '==> Boot mode: UEFI'

# --- B. UEFI-only behaviour is gated ---------------------------------------
every_line_gated "NVRAM prompt gated on uefi" \
    'Register Limine NVRAM entry' 'if [ "$BOOT_MODE" = "uefi" ]; then' 40
every_line_gated "efivarfs mount gated on uefi" \
    'mount -v -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars' \
    'if [ "$BOOT_MODE" = "uefi" ]; then' 12
every_line_gated "Stage-2 efibootmgr gated on uefi" \
    'efibootmgr --create' \
    '[ "$BOOT_MODE" = "uefi" ]' 16
every_line_gated "firmware menu entry gated on uefi" \
    'protocol: efi_firmware_update_request' \
    '[ "${BOOT_MODE:-uefi}" = "uefi" ]' 12

# --- C. BIOS geometry is wired ---------------------------------------------
check "BIOSBOOT_PART_SIZE fixed at 1M + exported" 'BIOSBOOT_PART_SIZE="1M"'
check "budget gate counts the ef02 partition" \
      '_need=$(( _esp_b + _bb_b + _reg_b + DISK_BUDGET_MIN_SYS ))'
check "budget parses BIOSBOOT_PART_SIZE" '_bb_b="$(_size_to_bytes "${BIOSBOOT_PART_SIZE:-1M}")"'
check "BIOSBOOT_PN from NREG (region branch)" 'BIOSBOOT_PN=$((NREG + 2))'
check "BIOSBOOT_OFFSET=1 on BIOS" 'BIOSBOOT_OFFSET=1'
check "geometry exports BIOSBOOT_PN/OFFSET/PART_BIOSBOOT" \
      'export NREG BIOSBOOT_PN BIOSBOOT_OFFSET PART_BIOSBOOT'
check "PART_SYS shifted by the offset (nvme form)" \
      'export PART_SYS="${DISK}p$((2 + BIOSBOOT_OFFSET))"'
check "PART_SYS shifted by the offset (sd/vd form)" \
      'export PART_SYS="${DISK}$((2 + BIOSBOOT_OFFSET))"'
check "chroot env carries PART_BIOSBOOT" 'export PART_BIOSBOOT='
check "chroot env carries BIOSBOOT_PN"    'echo "export BIOSBOOT_PN='
_ef02=$(grep -c 'sgdisk .*:ef02' "$SRC")
if [ "$_ef02" = "2" ]; then ok "exactly two ef02 carves (region + plain)"; \
else bad "exactly two ef02 carves (region + plain)" "found $_ef02"; fi
check "ef02 sized from BIOSBOOT_PART_SIZE" 'sgdisk -n "2::+${BIOSBOOT_PART_SIZE}"'

# --- D. Stage-2 bootloader branches ----------------------------------------
every_line_gated "GRUB i386-pc install gated on bios" \
    'grub-install --target=i386-pc --recheck "$DISK"' \
    'if [ "$BOOT_MODE" = "bios" ]; then' 16
every_line_gated "limine bios-install gated on bios" \
    'limine bios-install "$DISK" "$BIOSBOOT_PN"' \
    'if [ "$BOOT_MODE" = "bios" ]; then' 24
every_line_gated "limine-bios.sys deploy gated on bios" \
    'cp -f /usr/share/limine/limine-bios.sys /boot/efi/limine-bios.sys' \
    'if [ "$BOOT_MODE" = "bios" ]; then' 30

# --- D2. ef02 gate: positive evidence + dual-source diagnostics --------------
# Regression guards for the 3.1.00 matrix catch: the first-cut gate compared
# BIOSBOOT_PN against raw `lsblk -no PARTN`, whose column is RIGHT-ALIGNED
# (" 2"), so the compare could never succeed and bios-limine-plain died rc=4
# on a table the verify probe had just printed as p1 EF00 / p2 EF02 / p3 8300.
check "ef02 gate reads the kernel partition number from sysfs first" \
      'cat "/sys/class/block/${PART_BIOSBOOT##*/}/partition"'
check "ef02 gate lsblk fallback strips the padded column" \
      "head -n1 | tr -d '[:space:]'"
check "ef02 gate names all sources in the missing-evidence FATAL" \
      'has no kernel partition number (/sys entry, lsblk answer, and device node all absent)'
check "ef02 gate reports the disagreeing kernel number in the FATAL" \
      'but the kernel reports p${_bb_pn}'
check "ef02 gate logs the kernel view on success" \
      'kernel number: p${_bb_pn:-unconfirmed}'
if grep -qF '! -b "$PART_BIOSBOOT" ] || [ "${BIOSBOOT_PN:-}" != "$(lsblk' "$SRC"; then
    bad "ef02 gate no longer compares raw lsblk output" "padded-compare construct still present"
else
    ok "ef02 gate no longer compares raw lsblk output"
fi

# UEFI paths must still be present verbatim (byte-identical UEFI contract).
check "UEFI grub-install x86_64-efi (/boot/efi variant)" \
      'grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Void_GRUB" --recheck'
check "UEFI ESP carve unchanged" 'sgdisk -n "1::+${EFI_PART_SIZE}" -t 1:ef00 -c 1:'"'"'ESP'"'"' "$DISK"'
check "UEFI plain LINUX carve unchanged" 'sgdisk -n 2:: -t 2:8300 -c 2:'"'"'LINUX'"'"' "$DISK"'

# --- E. Limine config generator (BIOS needs a second limine.conf) -----------
check "limine-env records BOOT_MODE" 'BOOT_MODE="${BOOT_MODE}"'
every_line_gated "generator's ESP-root limine.conf copy gated on bios" \
    'cp -f /boot/efi/EFI/BOOT/limine.conf /boot/efi/limine.conf' \
    '[ "${BOOT_MODE:-uefi}" = "bios" ]' 8

# --- F. user-facing claims ---------------------------------------------------
_hdr=$(head -60 "$SRC" | grep -c 'legacy BIOS')
if [ "$_hdr" -gt 0 ]; then ok "header advertises legacy BIOS support"; \
else bad "header advertises legacy BIOS support" "no 'legacy BIOS' in header"; fi
check "banner says both firmware modes" 'UEFI and legacy BIOS both supported'

echo
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
