#!/bin/bash
# checks/check-heredocs.sh
# [AI (Big Pickle)] Reproducible heredoc linter for Void_Linux_Installer.sh.
#
# AGENTS.md (Validation) requires that after changing any heredoc you extract
# and `bash -n` the generated file directly, because the installer's own
# `bash -n` does NOT parse heredoc bodies. This script makes that check a
# committed, one-shot command instead of transient /tmp tooling.
#
#   ./checks/check-heredocs.sh [path/to/Void_Linux_Installer.sh]
#
# It extracts EVERY heredoc the installer emits — every cat-file heredoc
# (quoted and unquoted, any delimiter) plus the whole stage-2
# chroot ... << 'CHROOT_EOF' block — then runs bash -n
# on every shell-classified body (shebang, or a known shell
# allowlist: the chroot block, void-limine-env.inc).
# Additionally it runs shellcheck -f gcc, when shellcheck is installed, on
# quoted generated-file heredocs. Unquoted bodies are skipped for shellcheck:
# they legitimately still contain source-level ${VAR} bake placeholders
# (SC2154 noise). The big stage-2 chroot block is checked with bash -n only.
#
# Exit 0: every extracted body present and shell ones syntax-clean.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SRC=${1:-"$DIR/../Void_Linux_Installer.sh"}
OUT=$(mktemp -d /tmp/heredoc-check.XXXXXX)
trap 'rm -rf "$OUT"' EXIT
INDEX="$OUT/INDEX"
: > "$INDEX"

[ -r "$SRC" ] || { echo "usage: $0 [path/to/Void_Linux_Installer.sh]" >&2; exit 2; }

# NESTING-AWARE EXTRACTION
#
# The installer's heredoc layout is NESTED:
#   * stage-2 is one big chroot block   : `chroot /mnt /bin/bash << 'CHROOT_EOF'`
#     (lines ~2907..5555) — this body is bash THAT, while running in chroot,
#     emits all the smaller config/script files via `cat > X << ...`.
#   * so the 39 `cat > X << INNER_EOF|EOF|...` heredocs are each nested INSIDE
#     the chroot block, and each is contiguous (own terminator) within it.
#
# Two passes:
#   P1: capture the whole STAGE-2-CHROOT block as STAGE-2-CHROOT (bash-checkable).
#   P2: scan the WHOLE source for every `cat > X << DLM` body. Nesting is not a
#       problem for the cat scan: each body is contiguous until its own DLM
#       terminator, and the `chroot` opener does not match the `^cat` broker
#       regex, so the chroot block's interior simply falls through the scan.

P1_OUT="$OUT/STAGE-2-CHROOT"
awk -v out="$P1_OUT" '
  /chroot .*\/bin\/bash[[:space:]]+<<[[:space:]]+.?CHROOT_EOF.?[[:space:]]*$/ {
    cap = 1; next
  }
  cap && /^CHROOT_EOF[[:space:]]*$/ { cap = 0; next }
  cap { print > out }
' "$SRC"
printf 'STAGE-2-CHROOT\tCHROOT_EOF\t1\tSTAGE-2-CHROOT\n' >> "$INDEX"

# P2: extract every nested cat-file heredoc from the whole source.
awk -v OUT="$OUT" -v INDEX="$INDEX" -f - "$SRC" <<'AWK_EOF'
function slugify(t) {
  gsub(/[\/\.-]/, "_", t)
  gsub(/[${}]/, "_", t)
  return t
}
{
  if (idx) {
    s = $0
    sub(/\r$/, "", s)
    if (s == delim) { idx = 0; next }
    print > (OUT "/" slug)
    next
  }
  if ($0 ~ /^[[:space:]]*cat[[:space:]]+(>|>>)[[:space:]]+.*<<[[:space:]]+['"'"']?[A-Za-z_][A-Za-z0-9_]*['"'"']?[[:space:]]*$/) {
    delim = $0
    sub(/^.*<<[[:space:]]+['"'"']?/, "", delim)
    gsub(/[[:space:]'"'"']/, "", delim)
    quoted = ($0 ~ /<<[[:space:]]+['"'"']/ ? 1 : 0)
    t = $0
    sub(/^[[:space:]]*cat[[:space:]]+(>|>>)[[:space:]]+/, "", t)
    sub(/[[:space:]]*<<[[:space:]]+['"'"']?[A-Za-z_][A-Za-z0-9_]*['"'"']?[[:space:]]*$/, "", t)
    gsub(/[[:space:]"']/, "", t)
    slug = slugify(t)
    print slug "\t" delim "\t" quoted "\t" t >> INDEX
    idx = 1
    next
  }
}
AWK_EOF

is_shell() {
  local slug="$1" f="$2"
  if head -1 "$f" | grep -qE '^#![[:space:]]*[^ ]*(bash|sh)([[:space:]]|$)'; then return 0; fi
  case "$slug" in
    STAGE-2-CHROOT | *_usr_local_sbin_void_limine_env_inc) return 0 ;;
  esac
  return 1
}

shells=0
configs=0
fails=0
# shellcheck disable=SC2034  # the INDEX `delim` column is extracted for the record/debugging
while IFS=$'\t' read -r slug delim quoted target; do
  f="$OUT/$slug"
  if [ ! -e "$f" ]; then
    printf 'FAIL  %-46s body not extracted\n' "$target"
    fails=1
    continue
  fi
  if ! is_shell "$slug" "$f"; then
    configs=$((configs + 1))
    printf 'skip  %-46s non-shell config (%d lines)\n' "$target" "$(wc -l < "$f")"
    continue
  fi
  shells=$((shells + 1))
  if bash -n "$f" >/dev/null 2>&1; then
    printf 'OK    %-44s bash -n clean, %4d lines' "$target" "$(wc -l < "$f")"
  else
    printf 'FAIL  %-46s bash -n\n' "$target"
    bash -n "$f" 2>&1 | sed 's/^/        /'
    fails=1
    continue
  fi
  if [ "$quoted" = "1" ] && [ "$slug" != "STAGE-2-CHROOT" ]; then
    if command -v shellcheck >/dev/null 2>&1; then
      # SC1091 (info, "not following sourced file") is excluded: extracted bodies
      # source absolute paths like /lib/dracut-lib.sh and void-limine-env.inc that
      # do not exist in the flat extraction tree (system/dracut libs are never
      # generated here). SC1091 is context noise, not code.
      if shellcheck -f gcc -e SC1091 "$f" >/tmp/heredoc-sc.out 2>&1; then
        printf '  [shellcheck clean]\n'
      else
        printf '  [shellcheck FAILED]\n'
        cat /tmp/heredoc-sc.out | sed 's/^/        /'
        rm -f /tmp/heredoc-sc.out
        fails=1
      fi
    else
      printf '  (shellcheck not installed)\n'
    fi
  else
    printf '\n'
  fi
done < "$INDEX"

echo
printf 'SUMMARY: %d heredocs extracted (%d shell-classified, %d non-shell config)\n' \
  "$(wc -l < "$INDEX")" "$shells" "$configs"
if [ "$fails" -eq 0 ]; then
  echo "ALL CLEAN"
else
  echo "FAILURES PRESENT" >&2
fi
exit "$fails"