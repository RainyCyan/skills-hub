#!/usr/bin/env bash
# 诊断当前执行路径能否写共享的 git 元数据
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

if ! command -v git >/dev/null 2>&1; then
    echo -e "${RED}[FAIL]${NC} git 不可用"
    exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo -e "${RED}[FAIL]${NC} 当前目录不是 git 仓库"
    exit 1
}

GIT_COMMON_DIR=$(git rev-parse --path-format=absolute --git-common-dir)
FETCH_HEAD=$(git rev-parse --path-format=absolute --git-path FETCH_HEAD)

PROBE_FILE="$GIT_COMMON_DIR/.trae-git-write-probe-$$"
ERR_FILE=$(mktemp /tmp/git-runtime-check.XXXXXX)

cleanup() {
    rm -f "$PROBE_FILE" "$ERR_FILE"
}
trap cleanup EXIT

echo "=== Git 运行环境检查 ==="
echo "repo_root: $REPO_ROOT"
echo "git_common_dir: $GIT_COMMON_DIR"
echo "fetch_head: $FETCH_HEAD"
echo ""

if : >"$PROBE_FILE" 2>"$ERR_FILE"; then
    rm -f "$PROBE_FILE"
    echo -e "${GREEN}[PASS]${NC} 当前执行路径可以写共享 git 元数据"
    echo "可安全执行会修改 .git 的命令，例如: git fetch, git worktree add, git add, git commit, git rebase"
    exit 0
fi

echo -e "${RED}[FAIL]${NC} 当前执行路径无法写共享 git 元数据"
if [ -s "$ERR_FILE" ]; then
    echo "错误输出:"
    sed 's/^/  /' "$ERR_FILE"
fi
echo ""
echo "影响:"
echo "  - git fetch 可能失败在 .git/FETCH_HEAD"
echo "  - git worktree add 可能失败在 .git/worktrees/..."
echo "  - git add 或 git commit 可能失败在 .git/index.lock"
echo "  - git rebase 可能失败在 .git/rebase-merge"
echo ""
echo "结论:"
echo "  这不是 branch state 问题，而是当前运行环境拦截了 .git 写入。"
echo "  先切换到可写 .git 的执行路径，再继续做 fetch / worktree / rebase / commit 诊断。"
exit 1
