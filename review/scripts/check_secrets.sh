#!/usr/bin/env bash
# 扫描 diff 中的硬编码密钥和敏感信息
# 用法: bash check_secrets.sh [diff-target]
# 默认对比 origin/main...HEAD
set -euo pipefail

TARGET="${1:-origin/main...HEAD}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== 硬编码密钥扫描 ==="
echo "对比范围: $TARGET"
echo ""

# 获取 diff
DIFF=$(git diff "$TARGET" 2>&1) || true
if [ -z "$DIFF" ]; then
    echo -e "${GREEN}无 diff，跳过扫描。${NC}"
    exit 0
fi

FOUND=0

# 模式列表: 正则 -> 描述
declare -A PATTERNS=(
    ['password\s*[=:]\s*["\x27][^"\x27]{3,}']="硬编码密码"
    ['passwd\s*[=:]\s*["\x27][^"\x27]{3,}']="硬编码密码(passwd)"
    ['api[_]?key\s*[=:]\s*["\x27][^"\x27]{8,}']="硬编码 API Key"
    ['secret\s*[=:]\s*["\x27][^"\x27]{8,}']="硬编码 Secret"
    ['token\s*[=:]\s*["\x27][^"\x27]{8,}']="硬编码 Token"
    ['private[_]?key\s*[=:]\s*["\x27]']="硬编码私钥"
    ['-----BEGIN (RSA|EC|DSA|OPENSSH)?\s*PRIVATE KEY-----']="PEM 私钥"
    ['Authorization:\s*(Basic|Bearer)\s+["\x27]?[A-Za-z0-9+/=]{20,}']="硬编码认证头"
    ['AKIA[0-9A-Z]{16}']="AWS Access Key"
    ['sk-[A-Za-z0-9]{32,}']="OpenAI API Key"
    ['ghp_[A-Za-z0-9]{36}']="GitHub Personal Access Token"
    ['gho_[A-Za-z0-9]{36}']="GitHub OAuth Token"
    ['xox[bpras]-[A-Za-z0-9-]{10,}']="Slack Token"
)

# 逐行检查 diff 中新增的行（以 + 开头）
while IFS= read -r line; do
    # 只检查新增行
    if [[ "$line" =~ ^\+[^+] ]]; then
        content="${line:1}"
        for pattern in "${!PATTERNS[@]}"; do
            if echo "$content" | grep -qiE "$pattern" 2>/dev/null; then
                # 排除明显是注释或测试占位符的行
                if echo "$content" | grep -qiE '(your-api-key|test_key|example|placeholder|xxxx|changeme|todo)' 2>/dev/null; then
                    continue
                fi
                echo -e "${RED}[阻塞]${NC} ${PATTERNS[$pattern]}: ${content:0:120}"
                FOUND=$((FOUND + 1))
                break
            fi
        done
    fi
done <<< "$DIFF"

echo ""
if [ "$FOUND" -eq 0 ]; then
    echo -e "${GREEN}未发现硬编码密钥。${NC}"
    exit 0
else
    echo -e "${RED}发现 $FOUND 处疑似硬编码密钥，请修复。${NC}"
    exit 1
fi