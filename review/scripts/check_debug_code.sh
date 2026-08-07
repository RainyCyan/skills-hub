#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DIFF_FILE="$(mktemp)"
trap 'rm -f "$DIFF_FILE"' EXIT

if ! "$SCRIPT_DIR/collect_diff.sh" "$@" >"$DIFF_FILE"; then
    echo "error: unable to collect the review diff" >&2
    exit 2
fi

if [ ! -s "$DIFF_FILE" ]; then
    echo "PASS debug: no changes to scan"
    exit 0
fi

PATTERNS=(
    'console\.(log|debug)[[:space:]]*\('
    '^[[:space:]]*debugger([[:space:]]*;|[[:space:]]*(//.*)?$)'
    '(^|[^[:alnum:]_])(pdb|breakpoint)[[:space:]]*\('
    '(^|[^[:alnum:]_])var_dump[[:space:]]*\('
    '(^|[^[:alnum:]_])dump[[:space:]]*\('
    '(^|[^[:alnum:]_])alert[[:space:]]*\('
)

LABELS=(
    "console debug output"
    "debugger statement"
    "Python debugger call"
    "var_dump call"
    "dump call"
    "alert call"
)

current_file=""
new_line=0
found=0

while IFS= read -r line; do
    case "$line" in
        "+++ b/"*)
            current_file="${line#+++ b/}"
            ;;
        "@@ "*)
            hunk="${line#*+}"
            new_line="${hunk%%[, ]*}"
            ;;
        "+"*)
            if [[ "$line" == "+++"* ]] || [ -z "$current_file" ]; then
                continue
            fi
            content="${line:1}"
            for index in "${!PATTERNS[@]}"; do
                if grep -qE "${PATTERNS[$index]}" <<<"$content"; then
                    printf 'CANDIDATE debug %s:%s %s\n' \
                        "$current_file" "$new_line" "${LABELS[$index]}"
                    found=$((found + 1))
                    break
                fi
            done
            new_line=$((new_line + 1))
            ;;
        "-"*)
            ;;
        *)
            if [ "$new_line" -gt 0 ]; then
                new_line=$((new_line + 1))
            fi
            ;;
    esac
done <"$DIFF_FILE"

if [ "$found" -gt 0 ]; then
    echo "FOUND debug: $found candidate(s); confirm intent before reporting"
    exit 1
fi

echo "PASS debug: no candidates found"
