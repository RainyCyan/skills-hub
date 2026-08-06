#!/usr/bin/env bash
# 扫描 diff 中未清理的调试代码
# 用法: bash check_debug_code.sh [diff-target]
set -euo pipefail

TARGET="${1:-origin/main...HEAD}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== 调试代码残留扫描 ==="
echo "对比范围: $TARGET"
echo ""

DIFF=$(git diff "$TARGET" 2>&1) || true
if [ -z "$DIFF" ]; then
    echo -e "${GREEN}无 diff，跳过扫描。${NC}"
    exit 0
fi

FOUND=0

# 模式: 正则 -> 描述 -> 严重程度
declare -A DEBUG_PATTERNS=(
    ['console\.log\s*\(']="console.log() 调试输出"
    ['console\.debug\s*\(']="console.debug()"
    ['console\.warn\s*\(']="console.warn()"
    ['console\.error\s*\(']="console.error()"
    ['debugger\b']="debugger 断点语句"
    ['print\s*\(\s*[\x27"]']="print() 调试输出"
    ['dump\s*\(']="dump() 调试输出"
    ['var_dump\s*\(']="var_dump() 调试输出"
    ['alert\s*\(']="alert() 调试弹窗"
    ['TODO\b']="TODO 注释"
    ['FIXME\b']="FIXME 注释"
    ['HACK\b']="HACK 注释"
    ['XXX\b']="XXX 标记注释"
)

while IFS= read -r line; do
    if [[ "$line" =~ ^\+[^+] ]]; then
        content="${line:1}"
        for pattern in "${!DEBUG_PATTERNS[@]}"; do
            if echo "$content" | grep -qiE "$pattern" 2>/dev/null; then
                # 排除注释中的 TODO/FIXME（仅限 // 或 # 开头的行）
                trimmed=$(echo "$content" | sed 's/^[[:space:]]*//')
                if echo "$trimmed" | grep -qE '^(//|#|/\*|\*)'; then
                    if [[ "$pattern" =~ TODO|FIXME|HACK|XXX ]]; then
                        echo -e "${YELLOW}[警告]${NC} 注释中的 ${DEBUG_PATTERNS[$pattern]}: ${content:0:120}"
                        FOUND=$((FOUND + 1))
                        break
                    fi
                    continue
                fi
                echo -e "${YELLOW}[警告]${NC} ${DEBUG_PATTERNS[$pattern]}: ${content:0:120}"
                FOUND=$((FOUND + 1))
                break
            fi
        done
    fi
done <<< "$DIFF"

echo ""
if [ "$FOUND" -eq 0 ]; then
    echo -e "${GREEN}未发现调试代码残留。${NC}"
    exit 0
else
    echo -e "${YELLOW}发现 $FOUND 处调试代码残留，建议清理。${NC}"
    exit 0  # 警告不阻塞，不返回错误码
fi