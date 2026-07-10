# skills-hub
Maybe Useful Skills

目前Agent的各种markdown按照作用可以分成三类：
一 规则类
自动，常驻。当session启动时注入系统上下文。通常按照作用域可以分为全局和项目级，内容性质：原则、约定、命令入口、代码风格、安全红线。描述的是"在这个范围内默认遵守什么"。

二 技能类

三 记忆类


当前最有效的skill组织结构是分层结构，通用的可以划分为全局(AGENTS.md)->项目级别()

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
