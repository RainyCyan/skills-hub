#!/usr/bin/env bash
# 验证 feature 分支是否真正"落地"到默认分支（支持 squash merge）
# 用法:
#   check_feature_landed.sh --repo <repo-path> --branch <feature-branch> \
#     [--base <default-branch>] [--merge-sha <mr-merge-or-squash-sha>]
#
# 设计要点:
# - 默认分支动态解析，禁止硬编码 main/master。
# - 不用 "feature commit 是否为默认分支祖先" 判断 squash MR（squash 后不成立）。
# - MR 落地判定依赖显式 --merge-sha（来自远端 MR/UI/API 的权威 merge/squash SHA），
#   或平台 CLI（gh / glab）查询到的 merged 状态。二者都拿不到时 fail closed。
# - 只做只读校验：不 merge、不 switch、不删除。输出结构化结果供后续步骤消费。
set -euo pipefail

REPO=""
BRANCH=""
BASE=""
MERGE_SHA=""

while [ $# -gt 0 ]; do
    case "$1" in
        --repo) REPO="$2"; shift 2 ;;
        --branch) BRANCH="$2"; shift 2 ;;
        --base) BASE="$2"; shift 2 ;;
        --merge-sha) MERGE_SHA="$2"; shift 2 ;;
        *) echo "未知参数: $1" >&2; exit 2 ;;
    esac
done

if [ -z "$BRANCH" ]; then
    echo "用法: $0 --repo <repo-path> --branch <feature-branch> [--base <default-branch>] [--merge-sha <sha>]" >&2
    exit 2
fi

REPO="${REPO:-$(pwd)}"
GIT() { git -C "$REPO" "$@"; }

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0
check() {
    if [ "$2" -eq 0 ]; then echo -e "  ${GREEN}[PASS]${NC} $1"; PASS=$((PASS+1));
    else echo -e "  ${RED}[FAIL]${NC} $1"; FAIL=$((FAIL+1)); fi
}

echo "=== 检查 feature 落地: $BRANCH (repo=$REPO) ==="

# 0. fetch 最新远端状态（网络失败不致命，但会降低判定可信度）
if GIT fetch origin --prune >/dev/null 2>&1; then
    echo "  fetch origin --prune: ok"
else
    echo -e "  ${YELLOW}[WARN]${NC} fetch 失败，判定基于本地已知的远端引用"
fi

# 1. 解析默认分支
if [ -z "$BASE" ]; then
    BASE="$(GIT symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')" || true
fi
if [ -z "$BASE" ]; then
    echo -e "  ${RED}[FAIL]${NC} 无法解析默认分支，请显式传入 --base" ; exit 1
fi
echo "  默认分支: $BASE"

# 2. feature 分支存在
if GIT rev-parse --verify "refs/heads/$BRANCH" >/dev/null 2>&1; then
    check "本地存在 feature 分支 $BRANCH" 0
    FEATURE_SHA="$(GIT rev-parse "$BRANCH")"
else
    check "本地存在 feature 分支 $BRANCH" 1
    FEATURE_SHA=""
fi

# 3. upstream 存在 & 无未推送 commit
UPSTREAM_SHA=""
if GIT rev-parse --verify "$BRANCH@{upstream}" >/dev/null 2>&1; then
    check "feature 分支有 upstream 跟踪" 0
    UPSTREAM_SHA="$(GIT rev-parse "$BRANCH@{upstream}")"
    AHEAD="$(GIT rev-list --count "$BRANCH@{upstream}..$BRANCH" 2>/dev/null || echo "?")"
    if [ "$AHEAD" = "0" ]; then
        check "无未推送 commit (ahead=0)" 0
    else
        check "无未推送 commit (ahead=$AHEAD)" 1
    fi
else
    check "feature 分支有 upstream 跟踪" 1
fi

# 4. 权威 merge 证据: --merge-sha 或平台 CLI merged 状态
BASE_SHA="$(GIT rev-parse "origin/$BASE" 2>/dev/null || echo "")"
MERGE_LANDED=1
if [ -n "$MERGE_SHA" ]; then
    if GIT rev-parse --verify "$MERGE_SHA^{commit}" >/dev/null 2>&1; then
        if GIT merge-base --is-ancestor "$MERGE_SHA" "origin/$BASE" 2>/dev/null; then
            check "merge SHA $MERGE_SHA 已进入 origin/$BASE" 0
            MERGE_LANDED=0
        else
            check "merge SHA $MERGE_SHA 已进入 origin/$BASE（未进入）" 1
        fi
    else
        echo -e "  ${YELLOW}[WARN]${NC} 本地找不到 merge SHA 对象，可能需要先 fetch"
        check "merge SHA $MERGE_SHA 存在于本地对象库" 1
    fi
else
    # 尝试平台 CLI 查询 MR/PR merged 状态
    QUERIED=1
    if command -v glab >/dev/null 2>&1; then
        if glab mr view "$BRANCH" -R "$(GIT remote get-url origin 2>/dev/null)" 2>/dev/null | grep -qiE 'state:\s*merged|merged'; then
            check "glab: MR($BRANCH) 状态 merged" 0; MERGE_LANDED=0; QUERIED=0
        fi
    fi
    if [ "$QUERIED" != "0" ] && command -v gh >/dev/null 2>&1; then
        if gh pr view "$BRANCH" --json state 2>/dev/null | grep -qi 'MERGED'; then
            check "gh: PR($BRANCH) 状态 MERGED" 0; MERGE_LANDED=0; QUERIED=0
        fi
    fi
    if [ "$QUERIED" != "0" ]; then
        echo -e "  ${RED}[FAIL]${NC} 无 --merge-sha 且平台 CLI 无法确认 merged 状态 → fail closed"
        FAIL=$((FAIL+1))
    fi
fi

echo ""
echo "--- 结构化结果 ---"
echo "repo=$REPO"
echo "base=$BASE"
echo "feature_sha=${FEATURE_SHA:-none}"
echo "upstream_sha=${UPSTREAM_SHA:-none}"
echo "merge_sha=${MERGE_SHA:-none}"
echo "base_sha=${BASE_SHA:-none}"
if [ "$FAIL" -eq 0 ] && [ "$MERGE_LANDED" -eq 0 ]; then
    echo "landed=yes"
    echo "post_merge_regression=allowed"
else
    echo "landed=no"
    echo "post_merge_regression=blocked"
fi

echo ""
echo "=== 结果: $PASS 通过, $FAIL 失败 ==="
if [ "$FAIL" -eq 0 ] && [ "$MERGE_LANDED" -eq 0 ]; then
    echo -e "${GREEN}功能已落地默认分支，可进入合入后回归。${NC}"
    exit 0
else
    echo -e "${RED}未确认落地，暂不进入回归/清理（fail closed）。${NC}"
    exit 1
fi
