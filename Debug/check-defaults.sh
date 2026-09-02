#!/bin/bash
# Debug/check-defaults.sh
# [AI (Big Pickle)] Reproducible prompt-defaults consistency check for
# Void_Linux_Installer.sh.
#
# AGENTS.md requires that the `[PROMPT-DEFAULTS]` (v3.3.0-beta24) top block —
# the editable `DEFAULT_*` answers that drive every interactive prompt's
# bare-Enter fallback — stays in sync with the prompts that consume it. This
# script makes that a committed, one-shot gate instead of a manual grep:
#
#   ./Debug/check-defaults.sh [path/to/Void_Linux_Installer.sh]
#
# It verifies:
#   1. DECLARED  -> every `DEFAULT_*=` assignment in the top block is actually
#      wired to a prompt (referenced at least once beyond its own declaration
#      line and the adjacent comment), so an orphaned default can't silently
#      stop applying.
#   2. REFERENCED -> every `DEFAULT_*` used in the script was declared in the
#      top block, so a typo'd config name (which would always fall back to the
#      built-in default and would be a dead knob) is caught.
#
# Exit 0: block is consistent. Non-zero: list the offenders.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SRC=${1:-"$DIR/../Void_Linux_Installer.sh"}

if [ ! -f "$SRC" ]; then
    echo "check-defaults: source not found: $SRC" >&2
    exit 2
fi
mapfile -t LINES < "$SRC"

# ---- collect the declared DEFAULT_* names (top block) ----------------------
declare -A DECLARED=()
for i in "${!LINES[@]}"; do
    line=${LINES[$i]}
    if [[ "$line" =~ ^(DEFAULT_[A-Z0-9_]+)=\"\$\{DEFAULT_[A-Z0-9_]+\:- ]]; then
        DECLARED[${BASH_REMATCH[1]}]=$((i + 1))
    fi
done

if [ "${#DECLARED[@]}" -eq 0 ]; then
    echo "check-defaults: no DEFAULT_* declarations found in $SRC" >&2
    exit 2
fi

# ---- verify each declared default is actually wired to a prompt ------------
status=0
echo "check-defaults: ${#DECLARED[@]} DEFAULT_* vars declared in $SRC"

for name in $(printf '%s\n' "${!DECLARED[@]}" | sort); do
    decl_line=${DECLARED[$name]}
    wired=0
    for i in "${!LINES[@]}"; do
        ln=$((i + 1))
        # skip the declaration line and its immediate comment neighbours
        if [ "$ln" -ge $((decl_line - 1)) ] && [ "$ln" -le $((decl_line + 1)) ]; then
            continue
        fi
        if [[ "${LINES[$i]}" == *"\${$name}"* || "${LINES[$i]}" == *"\$$name"* ]]; then
            wired=1
            break
        fi
    done
    if [ "$wired" -ne 1 ]; then
        echo "  UNWIRED: $name (declared at $SRC:${decl_line}) is not referenced by any prompt" >&2
        status=1
    else
        echo "  ok: $name"
    fi
done

# ---- verify every referenced DEFAULT_* was declared --------------------------
used_undeclared=0
while IFS= read -r name; do
    [ -z "$name" ] && continue
    if [ -z "${DECLARED[$name]:-}" ]; then
        echo "  UNDECLARED-REF: $name used but never declared in the top block" >&2
        status=1
        used_undeclared=1
    fi
done < <(grep -oE '\$\{?DEFAULT_[A-Z0-9_]+' "$SRC" | grep -oE 'DEFAULT_[A-Z0-9_]+' | sort -u)

if [ "$used_undeclared" -eq 1 ]; then
    echo "  (an undeclared DEFAULT_* always falls back to its built-in value — a dead knob)" >&2
fi

if [ "$status" -eq 0 ]; then
    echo "check-defaults: ALL CONSISTENT — every default declared & wired, no stray references."
else
    echo "check-defaults: INCONSISTENT — fix the offenders above (see [PROMPT-DEFAULTS])." >&2
fi
exit "$status"
