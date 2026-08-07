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
    echo "PASS secrets: no changes to scan"
    exit 0
fi

PATTERNS=(
    "password[[:space:]]*[=:][[:space:]]*['\"][^'\"]{3,}"
    "passwd[[:space:]]*[=:][[:space:]]*['\"][^'\"]{3,}"
    "api[_-]?key[[:space:]]*[=:][[:space:]]*['\"][^'\"]{8,}"
    "secret[[:space:]]*[=:][[:space:]]*['\"][^'\"]{8,}"
    "token[[:space:]]*[=:][[:space:]]*['\"][^'\"]{8,}"
    "private[_-]?key[[:space:]]*[=:][[:space:]]*['\"]"
    "-----BEGIN ([A-Z0-9]+ )?PRIVATE KEY-----"
    "Authorization:[[:space:]]*(Basic|Bearer)[[:space:]]+['\"]?[A-Za-z0-9._+/=-]{20,}"
    "AKIA[0-9A-Z]{16}"
    "sk-[A-Za-z0-9_-]{32,}"
    "gh[oprsu]_[A-Za-z0-9]{36,}"
    "xox[bpras]-[A-Za-z0-9-]{10,}"
)

LABELS=(
    "hard-coded password"
    "hard-coded password"
    "hard-coded API key"
    "hard-coded secret"
    "hard-coded token"
    "hard-coded private key"
    "PEM private key"
    "hard-coded authorization header"
    "AWS access key"
    "OpenAI-style API key"
    "GitHub token"
    "Slack token"
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
            if grep -qiE -- '(your[-_]?api[-_]?key|test[-_]?key|placeholder|replace[-_]?me|changeme|<[^>]+>)' <<<"$content"; then
                new_line=$((new_line + 1))
                continue
            fi
            for index in "${!PATTERNS[@]}"; do
                if grep -qiE -- "${PATTERNS[$index]}" <<<"$content"; then
                    printf 'CANDIDATE secrets %s:%s %s\n' \
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
    echo "FOUND secrets: $found candidate(s); inspect values without reproducing them"
    exit 1
fi

echo "PASS secrets: no candidates found"
