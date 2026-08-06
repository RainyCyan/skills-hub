## 分支保护 / 贡献流程

`main` **禁止直接 push**，所有改动必须走 feature 分支 + Pull Request。

### 本地一次性设置（启用辅助 hook）

clone 本仓库后运行一次：

```sh
bash scripts/setup-hooks.sh
```

它会把 `core.hooksPath` 指向 `.githooks`，之后本地误 push 到 `main` 会被 `pre-push` 立即拦截。注意：hook 只是本地辅助反馈，可被 `--no-verify` 绕过，真正的强制层是下面的服务端 Ruleset。

### 日常流程

```sh
git switch -c <your-name>/feat/<topic>
# ...修改...
git push -u origin HEAD
# 到 GitHub 上开 Pull Request，评审通过后合入 main
```

### 服务端强制规则（仓库管理员在 GitHub 网页设置一次）

`Settings → Rules → Rulesets → New branch ruleset`：

- **Enforcement status**: `Active`
- **Bypass list**: 留空（含管理员也受限）
- **Target branches**: `Include default branch`
- 勾选：**Restrict deletions**、**Block force pushes**、**Require a pull request before merging**（Required approvals = `1`）

设置后：直接 push、force-push、删除 `main` 均被服务端拒绝，管理员也不例外。
