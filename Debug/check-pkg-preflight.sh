#!/bin/bash
# Debug/check-pkg-preflight.sh
# [AI (Big Pickle)] Reproducible [PKG-PREFLIGHT] drift-guard for
# Void_Linux_Installer.sh.
#
# AGENTS.md invariant #17 ([PKG-PREFLIGHT], Beta-v2.9.40) requires the Stage-1
# PKG_PREFLIGHT candidate list in Void_Linux_Installer.sh to stay a SUPERSET
# of every literal package name the Stage-2 chroot can install — every literal
# (non-variable) argument of every `install_pkgs ...` call plus the raw
# base-bootstrap literals (`base-system btrfs-progs glibc-locales`). If a chroot
# package name is ever added to the installer without also being added to
# PKG_PREFLIGHT, this gate fails, so a doomed install can't silently reach the
# disk (crash #005). This script makes that a committed, one-shot check instead
# of a manual audit:
#
#   ./Debug/check-pkg-preflight.sh [path/to/Void_Linux_Installer.sh]
#
# It verifies:
#   1. COVERAGE  -> every literal `install_pkgs` argument appears in the
#      PKG_PREFLIGHT list. Dynamic / quoted-shell arguments ($var, ${var},
#      "$VAR") are placeholders probed by the concrete names their values
#      resolve to (kernel / microcode / greeter / shell / wifi variants),
#      which DO live in PKG_PREFLIGHT as individual names — they cannot be
#      probed literally and are skipped here.
#   2. BOOTSTRAP  -> the base-bootstrap literals on the `xbps-install ... -r
#      /mnt` line are covered too.
#   3. NO-HEROIC/BOTTLES -> [GAME-FLATPAK-GATE] (Beta-v2.9.40): `install_pkgs
#      heroic` / `install_pkgs bottles` must NEVER come back as a literal
#      (no official Void package — the former crash #005). Historical
#      `# install_pkgs heroic crashed ...` comments are comment lines and are
#      correctly skipped, so they do not fail this gate.
#
# Exit 0: all literals covered. Non-zero: uncovered literal(s) or a forbidden
# Heroic/Bottles literal — list the offenders.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SRC=${1:-"$DIR/../Void_Linux_Installer.sh"}

if [ ! -f "$SRC" ]; then
    echo "check-pkg-preflight: source not found: $SRC" >&2
    exit 2
fi

PKG_NAME_RE='^[A-Za-z0-9][A-Za-z0-9.+-]*$'   # xbps package-name character class

# ---- 1. Extract the PKG_PREFLIGHT candidate list ----------------------------
declare -A PREFLIGHT=()
while IFS= read -r p; do
    PREFLIGHT[$p]=1
done < <(awk '
    /^PKG_PREFLIGHT="/ { inside = 1; next }
    inside && /^"$/    { inside = 0; next }
    inside             { n = $0; sub(/^[ \t]+/, "", n); sub(/[ \t]+$/, "", n); if (n != "") print n }
' "$SRC")

if [ "${#PREFLIGHT[@]}" -eq 0 ]; then
    echo "check-pkg-preflight: PKG_PREFLIGHT list not found in $SRC" >&2
    exit 2
fi

status=0
uncovered=0
literals_checked=0

check_literal() {   # $1 = candidate package name
    case "$1" in
        heroic|Heroic|bottles|Bottles)
            echo "  FORBIDDEN: literal \`install_pkgs $1\` must never come back ([GAME-FLATPAK-GATE] Beta-v2.9.40 / crash #005)" >&2
            status=1
            ;;
        *)
            if [ -z "${PREFLIGHT[$1]:-}" ]; then
                echo "  UNCOVERED: literal \`install_pkgs $1\` is not in the PKG_PREFLIGHT list" >&2
                uncovered=$((uncovered + 1))
                status=1
            fi
            literals_checked=$((literals_checked + 1))
            ;;
    esac
}

# ---- 2. Walk every install_pkgs call (skip comment lines / the function def) -
while IFS= read -r raw; do
    nl=${raw%%:*}
    text=${raw#*:}
    trimmed=${text#"${text%%[![:space:]]*}"}
    case "$trimmed" in \#*) continue ;; esac   # comment line -> skip
    if [[ "$text" == *"install_pkgs() {"* ]]; then
        continue                               # the function definition itself
    fi
    # Only treat an occurrence as a command-shaped call: the char immediately
    # before it must be line-start / whitespace / `&&` / `)` (case-arm or
    # subshell). A preceding `(`, letter or `_` means prose mention inside a
    # string (e.g. `echo "... (install_pkgs reported ..."`), which is skip.
    last_pre=${text%install_pkgs*}
    prev=${last_pre: -1}
    if [[ "$prev" != "" && "$prev" != [[:space:]] && "$prev" != "&" && "$prev" != ")" ]]; then
        continue   # prose mention, not a command-shaped call
    fi
    # Take the text after the LAST 'install_pkgs' word on the line (handles
    # `[ ... ] && install_pkgs a b c` and case-arm calls), then drop any
    # trailing `;`/`#` tail (case arms `;;`, `; then`, inline comments).
    after=${text##*install_pkgs}
    after=${after%%;*}
    after=${after%%#*}
    for tok in $after; do
        tok="${tok%\"}"; tok="${tok#\"}"     # unwrap one layer of quotes
        tok="${tok%\'}"; tok="${tok#\'}"
        [[ "$tok" =~ \$ ]] && continue      # dynamic $var / ${var} placeholder
        [[ "$tok" == *"*"* ]] && continue   # glob arms (*linux-mainline*)
        [[ "$tok" == *"["* ]] && continue   # test-ish residue
        [[ "$tok" == /* ]] && continue      # paths like /mnt
        [[ "$tok" == -* ]] && continue      # flags like -Sy, -y
        [[ "$tok" =~ $PKG_NAME_RE ]] || continue
        check_literal "$tok"
    done
done < <(grep -nE 'install_pkgs' "$SRC")

# ---- 3. Base-bootstrap literals ---------------------------------------------
# The raw `xbps-install ... -r /mnt base-system btrfs-progs $KERNEL_PKGS
# glibc-locales -y` line: $KERNEL_PKGS is dynamic (kernel variants are listed
# individually in PKG_PREFLIGHT), the three static names are literals.
bootstrap_line=$(grep -nE 'xbps-install.*base-system' "$SRC" || true)
if [ -n "$bootstrap_line" ]; then
    btext=${bootstrap_line#*:}
    btext=${btext##*xbps-install}
    btext=${btext%%;*}
    btext=${btext%%#*}
    for tok in $btext; do
        [[ "$tok" =~ \$ ]] && continue
        [[ "$tok" == /* ]] && continue
        [[ "$tok" == -* ]] && continue
        [[ "$tok" =~ $PKG_NAME_RE ]] || continue
        case "$tok" in xbps-install) continue ;; esac
        check_literal "$tok"
    done
else
    echo "check-pkg-preflight: WARN — no base-bootstrap xbps-install line found; skipping bootstrap literals" >&2
fi

# ---- 4. Report ---------------------------------------------------------------
if [ "$status" -eq 0 ]; then
    echo "check-pkg-preflight: ALL COVERED (${#PREFLIGHT[@]} preflight packages; ${literals_checked} install_pkgs + bootstrap literals checked)"
else
    echo "check-pkg-preflight: ${uncovered} uncovered literal(s) — add them to PKG_PREFLIGHT (or, for Heroic/Bottles, to the Flatpak queue) before committing." >&2
fi
exit "$status"