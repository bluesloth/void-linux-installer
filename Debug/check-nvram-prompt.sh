#!/bin/bash
# Debug/check-nvram-prompt.sh
# Sandbox test for the Version-3.0.01 [LIMINE-NVRAM-PROMPT-MOVE] +
# [LIMINE-NVRAM-LABEL] prompt code, extracted VERBATIM from the installer so
# the test cannot drift from the shipped logic. Live system is never touched.
DIR="$(cd "$(dirname "$0")" && pwd)"
SRC=${1:-"$DIR/../Void_Linux_Installer.sh"}
BLOCK=$(mktemp /tmp/nvram-block.XXXXXX.sh)
trap 'rm -f "$BLOCK"' EXIT

# Locate the prompt block dynamically (line numbers shift whenever the
# history/changelog blocks above it grow): from the toggle's section header to
# the line after the label loop's `unset`, which must be the closing `fi`.
start=$(grep -n 'Limine NVRAM registration\${C_RST}' "$SRC" | head -1 | cut -d: -f1)
unset_line=$(grep -n 'unset _lbl LIMINE_NVRAM_LABEL_INPUT' "$SRC" | head -1 | cut -d: -f1)
[ -n "$start" ] && [ -n "$unset_line" ] || { echo "EXTRACT FAILED (markers not found)"; exit 1; }
end=$((unset_line + 2))
[ "$(sed -n "${end}p" "$SRC" | tr -d ' ')" = "fi" ] || { echo "EXTRACT FAILED (no closing fi at $end)"; exit 1; }
awk -v s="$start" -v e="$end" 'NR>=s && NR<=e' "$SRC" > "$BLOCK"
grep -q 'UEFI boot entry name' "$BLOCK"        || { echo "EXTRACT FAILED (label prompt missing)"; exit 1; }
grep -q 'Register Limine NVRAM entry' "$BLOCK" || { echo "EXTRACT FAILED (toggle missing)"; exit 1; }
grep -q 'BOOTLOADER="grub"' "$BLOCK"           && { echo "EXTRACT FAILED (reached the next case arm)"; exit 1; }
grep -q 'esp_size_choose' "$BLOCK"             && { echo "EXTRACT FAILED (reached backwards)"; exit 1; }
echo "extracted lines ${start}..${end}"

pass=0; fail=0

invoke() { # invoke <input-lines...> -> stdout+stderr of one run of the real block
    local input
    input="$(printf '%s\n' "$@")"
    {
        C_BOLD=""; C_BLU=""; C_RST=""; C_GRN=""
        # Real `ask` prints no newline; the user's Enter does. Printing one
        # here keeps later output line-aligned so assertions can anchor.
        ask() { printf '%s\n' "$1"; }
        LIMINE_NVRAM="no"
        LIMINE_NVRAM_LABEL="Void Linux (Limine)"
        DEFAULT_LIMINE_NVRAM="false"
        # TEST_DEFAULT_LABEL may be preset (even to "") by a caller; - (not :-) so
        # an explicitly empty default is exercised rather than replaced.
        DEFAULT_LIMINE_NVRAM_LABEL="${TEST_DEFAULT_LABEL-Void Linux (Limine)}"
        # shellcheck disable=SC1090
        . "$BLOCK"
        printf 'RESULT\t%s\t%s\n' "$LIMINE_NVRAM" "$LIMINE_NVRAM_LABEL"
    } 2>&1 <<< "$input"
}

run_case() { # run_case <name> <expected-label> <expected-toggle> <input-lines...>
    local name=$1 want_label=$2 want_toggle=$3 out got_toggle got_label
    shift 3
    out=$(invoke "$@")
    got_toggle=$(printf '%s\n' "$out" | sed -n 's/^.*RESULT\t//p' | cut -f1)
    got_label=$(printf '%s\n' "$out" | sed -n 's/^.*RESULT\t//p' | cut -f2)
    if [ "$got_toggle" = "$want_toggle" ] && [ "$got_label" = "$want_label" ]; then
        pass=$((pass+1)); printf 'ok   %-48s -> %-3s [%s]\n' "$name" "$got_toggle" "$got_label"
    else
        fail=$((fail+1)); printf 'FAIL %-48s -> got %s [%s], want %s [%s]\n%s\n' \
            "$name" "$got_toggle" "$got_label" "$want_toggle" "$want_label" "$out"
    fi
}

expect_msg() { # expect_msg <name> <substring> <input-lines...>
    local name=$1 want=$2 out
    shift 2
    out=$(invoke "$@")
    if printf '%s' "$out" | grep -qF -- "$want"; then
        pass=$((pass+1)); printf 'ok   %-48s -> warned as expected\n' "$name"
    else
        fail=$((fail+1)); printf 'FAIL %-48s -> missing %q\n%s\n' "$name" "$want" "$out"
    fi
}

A80=$(printf 'a%.0s' $(seq 1 80))
A81=$(printf 'a%.0s' $(seq 1 81))
TAB=$'\t'
SOH=$'\x01'

echo "== toggle (moved code) =="
run_case "bare Enter = default off"                   "Void Linux (Limine)" no  ""
run_case "n"                                          "Void Linux (Limine)" no  "n"
run_case "yes"                                        "Void Linux (Limine)" yes "yes"
run_case "true (toggle convention)"                   "Void Linux (Limine)" yes "true"
run_case "false"                                      "Void Linux (Limine)" no  "false"
run_case "garbage then n"                             "Void Linux (Limine)" no  "maybe" "n"
run_case "NVRAM=no never asks for a label"            "Void Linux (Limine)" no  "n"

echo "== label prompt (new) =="
run_case "y + Enter = canonical default"              "Void Linux (Limine)" yes "y" ""
run_case "spaces+parens kept, whitespace trimmed"     "Void Linux (my box)" yes "y" "  Void Linux (my box)  "
run_case "80 chars accepted"                          "$A80"                yes "y" "$A80"
run_case "garbage toggle, then yes, then custom"      "My Firmware Entry"   yes "huh" "y" "My Firmware Entry"
TEST_DEFAULT_LABEL="  Padded Default  " run_case "padded DEFAULT is trimmed" "Padded Default" yes "y" ""

echo "== label validation =="
run_case "quote rejected, then default"               "Void Linux (Limine)" yes "y" 'bad"label' ""
run_case "backtick rejected, then ok"                 "ok"                  yes "y" 'bad`label' "ok"
run_case "dollar rejected, then ok"                   "ok"                  yes "y" '$(evil)' "ok"
run_case "backslash rejected, then ok"                "ok"                  yes "y" 'bad\label' "ok"
run_case "81 chars rejected, then ok"                 "ok"                  yes "y" "$A81" "ok"
run_case "control char rejected, then ok"             "ok"                  yes "y" "a${SOH}b" "ok"
run_case "leading tab/whitespace normalized"          "x"                   yes "y" "${TAB}  x"
TEST_DEFAULT_LABEL="" run_case "empty DEFAULT + Enter rejected, then ok" "ok" yes "y" "" "ok"

echo "== validation messages =="
expect_msg "long label message"      "Label too long"          "y" "$A81" "ok"
expect_msg "unsafe char message"     "may not contain quotes"  "y" 'a"b' "ok"
TEST_DEFAULT_LABEL="" expect_msg "empty message" "cannot be empty" "y" "" "ok"

echo
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
