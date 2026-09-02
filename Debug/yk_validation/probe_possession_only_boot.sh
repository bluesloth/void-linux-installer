#!/bin/bash
# Debug/yk_validation/probe_possession_only_boot.sh
# [AI (Big Pickle)] Pre-boot assertion suite for the possession-only YubiKey
# LUKS unlock chain ([ENCRYPT] + [YUBIKEY]). Run it ON the freshly installed
# system as root, BEFORE the first reboot into the new OS:
#     sudo ./probe_possession_only_boot.sh
# Per check prints PASS/FAIL and, on FAIL, the exact artifact inspected so the
# failure is actionable. It prints LENGTH/EXISTENCE only — never the YubiKey
# OTP (that is the LUKS credential). Public values (YK_CHALLENGE, YK_SLOT,
# crypto container UUID) are OK to display.
set -u

ROOT=/
pass=0; fail=0

ok()  { pass=$((pass+1)); echo "PASS  $1"; }
bad() { fail=$((fail+1)); echo "FAIL  $1"; }

s() { printf '%s' "${ROOT%/}${1#/}"; }

[ "$YK_FALLBACK" = "no" ] || echo "NOTE: $0 does not gate itself; YK_FALLBACK is decided at install. Read Debug/yk_validation/PROTOCOL.md."

echo "== 1. crypttab wires the keyscript =="
ct=$(s /etc/crypttab)
if grep -q 'keyscript=/usr/local/sbin/void-reveal-yubikey-key' "$ct"; then
  ok "crypttab: $ct carries keyscript= for void-root"
else
  bad "crypttab: $ct lacks the keyscript= option (possession-only boot has no key path)"
fi

echo "== 2. reveal keyscript is BAKED (the [YK-KEYSCRIPT-BAKE] regression) =="
rk=$(s /usr/local/sbin/void-reveal-yubikey-key)
if [ ! -x "$rk" ]; then
  bad "reveal keyscript: $rk missing/not executable"
elif grep -q '\${YK_' "$rk"; then
  bad "reveal keyscript: literal \${YK_...} placeholders survived — heredoc was quoted; possession-only boot is UNBOOTABLE (unbound var under set -u)"
else
  ok "reveal keyscript: no literal \${YK_...} placeholders (values baked)"
  slot=$(grep -oE 'ykchalresp -[0-9]+' "$rk" | grep -oE '[0-9]+')
  chal=$(grep -oE '"[0-9a-fA-F]{40}"' "$rk" | tr -d '"')
  [ -n "${slot:-}" ] && ok "reveal keyscript: slot is ${slot}" || bad "reveal keyscript: slot empty"
  if [ -n "${chal:-}" ]; then
    ok "reveal keyscript: challenge is a 40-hex string (${#chal} chars)"
  else
    bad "reveal keyscript: challenge missing / not 40-hex"
  fi
  grep -q '^set -u' "$rk" && ok "reveal keyscript: set -u present (bake gap would abort)" || bad "reveal keyscript: set -u missing"
fi

echo "== 3. 99void-yubikey module + dracut conf =="
ms=$(s /usr/lib/dracut/modules.d/99void-yubikey/module-setup.sh)
[ -f "$ms" ] && ok "module: $ms exists" || bad "module: $ms missing"
grep -q 'inst_script .*cryptroot-ask' "$ms" 2>/dev/null && ok "module: installs /sbin/cryptroot-ask override" || bad "module: override inst missing"
ca=$(s /usr/lib/dracut/modules.d/99void-yubikey/cryptroot-ask.sh)
grep -q 'keyscript' "$ca" 2>/dev/null && ok "cryptroot-ask: keyscript branch present" || bad "cryptroot-ask: keyscript branch missing"
grep -q 'rk="'"'"'\\/usr/local/sbin/void-reveal' -- "$ca" 2>/dev/null || true
dc=$(s /etc/dracut.conf.d/90-system.conf)
grep -q '99void-yubikey' "$dc" 2>/dev/null && ok "dracut.conf: 90-system.conf adds 99void-yubikey" || bad "dracut.conf: 99void-yubikey not added to $dc"
grep -q 'crypt"' "$dc" 2>/dev/null && ok "dracut.conf: crypt module added" || bad "dracut.conf: crypt module not in $dc"

echo "== 4. initramfs actually contains the override (reconfigure may be needed first) =="
kver=$(ls -1t /boot/void-kernel 2>/dev/null | head -1)
if command -v lsinitrd >/dev/null 2>&1 && [ -n "${kver:-}" ]; then
  ini="$ROOT/boot/void-kernel/initramfs-$kver.img"
  lsinitrd "$ini" 2>/dev/null | grep -q '/sbin/cryptroot-ask' \
    && ok "initramfs $kver: /sbin/cryptroot-ask present" \
    || bad "initramfs $kver: /sbin/cryptroot-ask MISSING — xbps-reconfigure -f <kernel-pkg> did not run, or module order is wrong"
  lsinitrd "$ini" 2>/dev/null | grep -q 'ykchalresp' \
    && ok "initramfs $kver: ykchalresp present" \
    || bad "initramfs $kver: ykchalresp missing"
else
  echo "skip  initramfs inspection: no lsinitrd or no /boot/void-kernel (GRUB layouts differ; inspect manually)"
fi

echo "== 5. offline possession round-trip (real key inserted) =="
if command -v ykchalresp >/dev/null 2>&1 && [ -n "${slot:-}" ] && [ -n "${chal:-}" ]; then
  resp=$(ykchalresp -"$slot" "$chal" 2>/dev/null)
  if [ -n "$resp" ]; then
    ok "ykchalresp produced a ${#resp}-char response (length only; response never printed)"
  else
    bad "ykchalresp produced NOTHING — touch required? slot renumbered? challenge mismatch? boot would hang at the prompt"
  fi
else
  echo "skip  possession round-trip: ykchalresp absent here"
fi

echo
echo "== 6. slot layout (possession-only means slot 0 is EMPTY) =="
if command -v cryptsetup >/dev/null 2>&1; then
  map=$(s /dev/mapper/void-root)
  dump=$(cryptsetup luksDump /dev/disk/by-uuid/"${LUKS_UUID:-}" 2>/dev/null || cryptsetup luksDump "$map" 2>/dev/null)
  echo "$dump" | awk '/^  Keyslot [0-9]+:/{ks=$2; getline; on=$0; if (on ~ /ENABLED/) print "slot " ks " ENABLED"; else print "slot " ks " disabled"}'
  echo "NOTE: possession-only (YK_FALLBACK=no) expects exactly ONE enabled slot. YK_FALLBACK=yes expects two."
else
  echo "skip  slot layout: cryptsetup absent"
fi

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && echo "READY TO REBOOT — run PROTOCOL.md phase B (cold boot with/without key)." || echo "NOT READY — fix the FAILs above, then rerun."