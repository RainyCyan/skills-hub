#!/usr/bin/env bash
# PR 提交前检查脚本
# 用法: ./check_pr_ready.sh [branch-name]
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
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

echo "=== PR 提交前检查 ==="
echo ""

# 1. Fetch latest（sandbox 下 .git 可能只读，fetch 失败降级为 WARN 而非中断）
echo "1. 同步远程仓库..."
if git fetch origin --prune 2>/tmp/.pr_fetch_err; then
    check "git fetch origin --prune" 0
else
    echo -e "  \033[1;33m[WARN]\033[0m git fetch 失败（可能是 sandbox 只读 .git），基于本地已知远端引用继续"
    sed 's/^/    /' /tmp/.pr_fetch_err 2>/dev/null | head -2
fi

# 2. 当前分支
BRANCH=$(git branch --show-current)
echo "  当前分支: $BRANCH"

# 解析默认分支（不硬编码 main/master）
BASE="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')" || true
[ -z "$BASE" ] && BASE="master"
echo "  默认分支: $BASE"

# 3. 检查是否有未跟踪或未暂存的文件
echo ""
echo "2. 工作区是否 clean?"
STATUS_OUT=$(git status --short 2>&1) || true
if [ -z "$STATUS_OUT" ]; then
    check "git status --short 无输出（clean）" 0
else
    echo "    未提交的变更:"
    echo "$STATUS_OUT" | sed 's/^/    /'
    check "git status --short 无输出（clean）" 1
fi

# 4. 检查 commit 历史
echo ""
echo "3. 当前分支的 commits (origin/$BASE..HEAD):"
COMMITS=$(git log --oneline "origin/$BASE..HEAD" 2>&1) || true
if [ -z "$COMMITS" ]; then
    echo "  (无 commits，当前分支与 origin/$BASE 一致)"
    check "有 commits 待合入" 1
else
    echo "$COMMITS" | sed 's/^/  /'
    check "有 commits 待合入" 0
fi

# 5. 检查改动的文件
echo ""
echo "4. 改动的文件 (origin/$BASE...HEAD):"
FILES=$(git diff --name-only "origin/$BASE...HEAD" 2>&1) || true
if [ -z "$FILES" ]; then
    echo "  (无文件改动)"
    check "有文件改动" 1
else
    echo "$FILES" | sed 's/^/  /'
    check "有文件改动" 0
fi

# 6. diff --check 检查格式问题
echo ""
echo "5. 格式检查 (git diff --check):"
DIFF_CHECK=$(git diff "origin/$BASE...HEAD" --check 2>&1) || true
if [ -z "$DIFF_CHECK" ]; then
    check "git diff --check 无格式问题" 0
else
    echo "    格式问题:"
    echo "$DIFF_CHECK" | sed 's/^/    /'
    check "git diff --check 无格式问题" 1
fi

# 总结
echo ""
echo "=== 结果: $PASS 通过, $FAIL 失败 ==="
if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}所有检查通过，可以创建 PR。${NC}"
    echo ""
    echo "创建 PR 命令:"
    echo "  gh pr create --title \"...\" --body \"\$(cat <<'EOF'"
    echo "  ## Summary"
    echo "  - ..."
    echo "  "
    echo "  ## Dependency"
    echo "  - ..."
    echo "  "
    echo "  ## Test Plan"
    echo "  - [x] ..."
    echo "  "
    echo "  ## Risk / Rollback"
    echo "  - ..."
    echo "  EOF"
    echo "  )\""
    exit 0
else
    echo -e "${RED}$FAIL 项检查不通过，请修复后再创建 PR。${NC}"
    exit 1
fi