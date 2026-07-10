#!/bin/sh
# 启用仓库共享 git hooks。clone 本仓库后运行一次即可。
#   bash scripts/setup-hooks.sh

set -e

repo_root=$(git rev-parse --show-toplevel)
git config core.hooksPath .githooks
chmod +x "$repo_root/.githooks/pre-push" 2>/dev/null || true

echo "✓ 已启用共享 hooks (core.hooksPath = .githooks)"
echo "  直接 push 到 main 将被本地 pre-push 拦截。"
