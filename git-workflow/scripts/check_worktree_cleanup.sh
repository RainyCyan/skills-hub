#!/usr/bin/env bash
# 验证 worktree 删除前的安全条件（闭环版）
# 用法:
#   check_worktree_cleanup.sh --branch <branch-name> --worktree <worktree-path> \
#     [--base <default-branch>] [--merge-sha <mr-merge-sha>] \
#     [--post-merge-verified] [--runtime-handed-off]
#
# 相比旧版修复:
# - 删除不可达条件（旧版要求 "worktree list 中已无该分支"，但删除前必然还在）。
# - 默认分支动态解析，不再硬编码 origin/main。
# - 用 rev-list @{upstream}..HEAD 判断未推送 commit，不解析 branch -vv 文本。
# - squash merge 兼容: 落地判定依赖 --merge-sha（ancestry）或平台 CLI，不用 feature commit 祖先关系。
# - MR 状态未知时 fail closed，不再 SKIP 放行。
# - "已 push" 与 "已 merged" 分成独立条件。
set -euo pipefail

BRANCH=""; WORKTREE_PATH=""; BASE=""; MERGE_SHA=""
POST_MERGE_VERIFIED=1; RUNTIME_HANDED_OFF=1

while [ $# -gt 0 ]; do
    case "$1" in
        --branch) BRANCH="$2"; shift 2 ;;
        --worktree) WORKTREE_PATH="$2"; shift 2 ;;
        --base) BASE="$2"; shift 2 ;;
        --merge-sha) MERGE_SHA="$2"; shift 2 ;;
        --post-merge-verified) POST_MERGE_VERIFIED=0; shift ;;
        --runtime-handed-off) RUNTIME_HANDED_OFF=0; shift ;;
        # 兼容旧位置参数: <branch> [worktree]
        *) if [ -z "$BRANCH" ]; then BRANCH="$1"; elif [ -z "$WORKTREE_PATH" ]; then WORKTREE_PATH="$1"; else echo "未知参数: $1" >&2; exit 2; fi; shift ;;
    esac
done

if [ -z "$BRANCH" ]; then
    echo "用法: $0 --branch <branch-name> --worktree <worktree-path> [--base <b>] [--merge-sha <sha>] [--post-merge-verified] [--runtime-handed-off]" >&2
    exit 2
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0
check() {
    if [ "$2" -eq 0 ]; then echo -e "  ${GREEN}[PASS]${NC} $1"; PASS=$((PASS+1));
    else echo -e "  ${RED}[FAIL]${NC} $1"; FAIL=$((FAIL+1)); fi
}

# 在 worktree 目录内执行 git（存在则用，不存在则用当前目录）
if [ -n "$WORKTREE_PATH" ] && [ -d "$WORKTREE_PATH" ]; then
    GIT() { git -C "$WORKTREE_PATH" "$@"; }
else
    GIT() { git "$@"; }
fi

echo "=== 检查 worktree 清理条件: $BRANCH ==="
echo ""

# 解析默认分支
if [ -z "$BASE" ]; then
    BASE="$(GIT symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')" || true
fi
[ -z "$BASE" ] && BASE="master"
echo "默认分支: $BASE"
echo ""

# 1. 工作区 clean
echo "1. 工作区是否 clean?"
STATUS_OUT=$(GIT status --short 2>&1) || true
if [ -z "$STATUS_OUT" ]; then check "工作区 clean" 0
else echo "$STATUS_OUT" | sed 's/^/    /'; check "工作区 clean" 1; fi

# 2. 无未推送 commit（rev-list，不解析文本）
echo ""
echo "2. 是否有未推送 commits?"
if GIT rev-parse --verify "$BRANCH@{upstream}" >/dev/null 2>&1; then
    AHEAD="$(GIT rev-list --count "$BRANCH@{upstream}..$BRANCH" 2>/dev/null || echo "?")"
    if [ "$AHEAD" = "0" ]; then check "已完整 push (ahead=0)" 0
    else check "已完整 push (ahead=$AHEAD)" 1; fi
else
    check "feature 分支有 upstream 跟踪" 1
fi

# 3. worktree 注册正常、未 locked、无残留运行时
echo ""
echo "3. worktree 状态是否正常（已注册、未 locked）?"
if [ -n "$WORKTREE_PATH" ]; then
    WT_PORCELAIN="$(GIT worktree list --porcelain 2>/dev/null || true)"
    if echo "$WT_PORCELAIN" | grep -qF "worktree $WORKTREE_PATH"; then
        # lock 检测：老版本 git 不在 porcelain 里输出 locked，用 .git/worktrees/<id>/locked 兜底
        LOCKED=1
        if echo "$WT_PORCELAIN" | awk -v p="worktree $WORKTREE_PATH" '$0==p{f=1;next} /^worktree /{f=0} f&&/^locked/{print "L"}' | grep -q L; then
            LOCKED=0
        fi
        WT_GITDIR="$(git -C "$WORKTREE_PATH" rev-parse --git-dir 2>/dev/null || true)"
        if [ -n "$WT_GITDIR" ] && [ -e "$WT_GITDIR/locked" ]; then
            LOCKED=0
        fi
        if [ "$LOCKED" -eq 0 ]; then
            check "worktree $WORKTREE_PATH 未被 lock" 1
        else
            check "worktree $WORKTREE_PATH 已注册且未 lock" 0
        fi
    else
        echo -e "  ${YELLOW}[INFO]${NC} $WORKTREE_PATH 未在 worktree 列表（可能已移除）"
        check "worktree 路径可识别" 0
    fi
else
    echo -e "  ${YELLOW}[SKIP]${NC} 未提供 --worktree，跳过注册状态检查"
fi

# 4. runtime handoff 已完成（服务/端口/owner 已释放）
echo ""
echo "4. 运行时是否已迁回/释放?"
if [ "$RUNTIME_HANDED_OFF" -eq 0 ]; then
    check "runtime 已迁回 durable checkout（--runtime-handed-off）" 0
else
    echo -e "  ${YELLOW}[INFO]${NC} 若任务不涉及运行时可忽略；涉及时须先迁回并释放端口后加 --runtime-handed-off"
    check "runtime handoff 已确认" 1
fi

# 5. 合入后回归已通过
echo ""
echo "5. 合入后回归是否已通过?"
if [ "$POST_MERGE_VERIFIED" -eq 0 ]; then
    check "post-merge 回归已通过（--post-merge-verified）" 0
else
    check "post-merge 回归已通过" 1
fi

# 6. MR 已 merged 且 merge SHA 落地默认分支（squash 兼容, fail closed）
echo ""
echo "6. MR 是否 merged 且已落地 origin/$BASE?"
GIT fetch origin --prune >/dev/null 2>&1 || true
if [ -n "$MERGE_SHA" ]; then
    if GIT rev-parse --verify "$MERGE_SHA^{commit}" >/dev/null 2>&1 \
       && GIT merge-base --is-ancestor "$MERGE_SHA" "origin/$BASE" 2>/dev/null; then
        check "merge SHA $MERGE_SHA 已进入 origin/$BASE" 0
    else
        check "merge SHA $MERGE_SHA 已进入 origin/$BASE" 1
    fi
else
    echo -e "  ${RED}[FAIL]${NC} 未提供 --merge-sha，无法确认 MR 落地 → fail closed"
    echo "    先运行 check_feature_landed.sh 取得权威 merge SHA"
    FAIL=$((FAIL+1))
fi

# 总结
echo ""
echo "=== 结果: $PASS 通过, $FAIL 失败 ==="
if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}所有条件通过，可以安全删除 worktree。${NC}"
    echo ""
    echo "执行清理:"
    echo "  git worktree remove ${WORKTREE_PATH:-<worktree-path>}   # 有未跟踪运行时资产时加 --force"
    echo "  git worktree prune"
    echo "  git branch -d $BRANCH   # squash 后可能拒绝；证据齐全时才用 -D"
    exit 0
else
    echo -e "${RED}$FAIL 项条件不满足，请不要删除 worktree。${NC}"
    exit 1
fi
