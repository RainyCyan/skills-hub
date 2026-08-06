#!/usr/bin/env bash
# 验证 worktree 删除前的五条安全条件
# 用法: ./check_worktree_cleanup.sh <branch-name> [worktree-path]
set -euo pipefail

BRANCH="${1:-}"
WORKTREE_PATH="${2:-}"

if [ -z "$BRANCH" ]; then
    echo "用法: $0 <branch-name> [worktree-path]"
    exit 1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
    local desc="$1"
    if [ "$2" -eq 0 ]; then
        echo -e "  ${GREEN}[PASS]${NC} $desc"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} $desc"
        FAIL=$((FAIL + 1))
    fi
}

# 切换到目标 worktree
if [ -n "$WORKTREE_PATH" ]; then
    cd "$WORKTREE_PATH"
fi

echo "=== 检查 worktree 清理条件: $BRANCH ==="
echo ""

# 1. git status 必须 clean
echo "1. 工作区是否 clean?"
STATUS_OUT=$(git status --short 2>&1) || true
if [ -z "$STATUS_OUT" ]; then
    check "git status --short 无输出（clean）" 0
else
    echo "    未跟踪或修改的文件:"
    echo "$STATUS_OUT" | sed 's/^/    /'
    check "git status --short 无输出（clean）" 1
fi

# 2. 无 unpushed commits
echo ""
echo "2. 是否有未推送的 commits?"
BRANCH_VV=$(git branch -vv 2>/dev/null | grep "^*" || true)
if echo "$BRANCH_VV" | grep -q '\[origin/'; then
    if echo "$BRANCH_VV" | grep -q 'ahead'; then
        echo "    分支有未推送的 commits:"
        echo "    $BRANCH_VV"
        check "git branch -vv 无 unpushed commits" 1
    else
        check "git branch -vv 无 ahead 标记" 0
    fi
else
    echo "    $BRANCH_VV"
    check "git branch -vv 有 upstream 跟踪" 1
fi

# 3. 无人在用此 worktree
echo ""
echo "3. 是否有人在用此 worktree?"
WT_LIST=$(git worktree list 2>&1) || true
if echo "$WT_LIST" | grep -q "$BRANCH"; then
    echo "    worktree 列表:"
    echo "$WT_LIST" | sed 's/^/    /'
    check "git worktree list 显示分支 $BRANCH 对应 worktree 仍在" 1
else
    check "git worktree list 中无 $BRANCH" 0
fi

# 4. 无 open PR
echo ""
echo "4. 是否有 open PR?"
if command -v gh &>/dev/null && gh pr list --state open --head "$BRANCH" &>/dev/null 2>&1; then
    PR_LIST=$(gh pr list --state open --head "$BRANCH" 2>&1) || true
    if [ -z "$PR_LIST" ]; then
        check "gh pr list --state open --head $BRANCH 无结果" 0
    else
        echo "    open PR:"
        echo "$PR_LIST" | sed 's/^/    /'
        check "gh pr list --state open --head $BRANCH 无结果" 1
    fi
else
    echo -e "  ${YELLOW}[SKIP]${NC} gh 命令不可用或不支持 pr list，无法自动检查 PR 状态"
    echo "    手动检查: 访问 GitHub 仓库的 Pull Requests 页面确认 $BRANCH 无 open PR"
fi

# 5. 有价值的 commits 已 push/merge
echo ""
echo "5. 是否有未合并的 commits?"
git fetch origin --prune 2>/dev/null || true
COMMITS=$(git log --oneline origin/main.."$BRANCH" 2>&1) || true
if [ -z "$COMMITS" ]; then
    check "origin/main..$BRANCH 无 commits（已合并或已推送）" 0
else
    echo "    未合并的 commits:"
    echo "$COMMITS" | sed 's/^/    /'
    check "origin/main..$BRANCH 无 commits" 1
fi

# 总结
echo ""
echo "=== 结果: $PASS 通过, $FAIL 失败 ==="
if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}所有条件通过，可以安全删除 worktree。${NC}"
    echo ""
    echo "执行清理:"
    echo "  git worktree remove <worktree-path>"
    echo "  git branch -d $BRANCH"
    exit 0
else
    echo -e "${RED}$FAIL 项条件不满足，请不要删除 worktree。${NC}"
    exit 1
fi