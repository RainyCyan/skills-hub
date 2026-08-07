#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: collect_diff.sh [--target <git-diff-target> | --staged] [--path <path> ...]

Without --target, compare the current worktree against HEAD so staged,
unstaged, and untracked files are all included.
EOF
}

TARGET=""
STAGED=0
PATHS=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        --target)
            if [ "$#" -lt 2 ]; then
                echo "error: --target requires a git diff target" >&2
                exit 2
            fi
            TARGET="$2"
            shift 2
            ;;
        --staged|--cached)
            STAGED=1
            shift
            ;;
        --path)
            if [ "$#" -lt 2 ]; then
                echo "error: --path requires a repository-relative path" >&2
                exit 2
            fi
            if [ -z "$2" ]; then
                echo "error: --path cannot be empty" >&2
                exit 2
            fi
            PATHS+=("$2")
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [ -n "$TARGET" ] && [ "$STAGED" -eq 1 ]; then
    echo "error: --target and --staged are mutually exclusive" >&2
    exit 2
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "error: current directory is not inside a git worktree" >&2
    exit 2
}

path_is_in_scope() {
    local candidate="$1"
    local scope

    if [ "${#PATHS[@]}" -eq 0 ]; then
        return 0
    fi

    for scope in "${PATHS[@]}"; do
        scope="${scope#./}"
        scope="${scope%/}"
        if [ -z "$scope" ]; then
            return 0
        fi
        if [ "$candidate" = "$scope" ] || [[ "$candidate" == "$scope/"* ]]; then
            return 0
        fi
    done
    return 1
}

if [ "$STAGED" -eq 1 ]; then
    git -C "$REPO_ROOT" diff --no-ext-diff --no-textconv --cached -- "${PATHS[@]}"
    exit 0
fi

if [ -n "$TARGET" ]; then
    git -C "$REPO_ROOT" diff --no-ext-diff --no-textconv "$TARGET" -- "${PATHS[@]}"
    exit 0
fi

git -C "$REPO_ROOT" diff --no-ext-diff --no-textconv HEAD -- "${PATHS[@]}"

UNTRACKED_FILE="$(mktemp)"
trap 'rm -f "$UNTRACKED_FILE"' EXIT
git -C "$REPO_ROOT" ls-files --others --exclude-standard -z >"$UNTRACKED_FILE"

while IFS= read -r -d '' path; do
    if ! path_is_in_scope "$path"; then
        continue
    fi
    git -C "$REPO_ROOT" diff --no-ext-diff --no-textconv --no-index -- /dev/null "$path" || status=$?
    if [ "${status:-0}" -ne 1 ]; then
        exit "${status:-1}"
    fi
    unset status
done <"$UNTRACKED_FILE"
