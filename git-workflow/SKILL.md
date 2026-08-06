---
name: git-workflow
description: 管理 git 仓库的并发安全与工作区隔离。触发场景：创建分支、提交代码、创建 PR、合并分支、rebase、使用 git worktree、并行 agent 开发、git 工作流操作。确保线性历史、文件完整性、多 agent 不互相覆盖。
---

# Git Workflow

## 核心原则

1. **main 只做集成，不做开发。** Never commit directly to main. main 是唯一事实源，只通过 PR 合入。
2. **一个任务 = 一个 worktree + 一个 branch + 一份 scope。** 每个 agent 在自己的 worktree 中工作，文件系统隔离，互不干扰。
3. **线性历史。** main 只接受 fast-forward。禁止 merge commit 出现在 main 上。
4. **破坏性命令必须慢动作。** Never force push、hard reset、stash 他人的工作。

## Worktree 工作流

### 创建 worktree

Always create a worktree from origin/main before starting any task:

```bash
git fetch origin --prune
git worktree add ../<task-name> -b <branch-name> origin/main
```

分支命名规范（携带来源和 scope）：

```
codex/<scope>-<task>
claude/<scope>-<task>
feat/<topic>
fix/<topic>
```

禁止使用 `update`、`fixes`、`wip`、`new-code` 等看不出责任边界的名字。

### 进入 worktree

```bash
cd ../<task-name>
git status --short --branch   # 必须 clean
```

### 列出所有 worktree

```bash
git worktree list
```

### 清理 worktree

Before removing a worktree, run the cleanup safety check:

```bash
bash scripts/check_worktree_cleanup.sh <branch-name> [worktree-path]
```

This verifies all five conditions: clean status, no unpushed commits, no active worktree, no open PR, all commits merged. Only proceed if all pass.

```bash
git worktree remove ../<task-name>
git branch -d <branch-name>
```

不确定就保留。Never delete a worktree unless all five conditions pass.

## 任务分配契约

Before starting work, define the task boundary in writing:

| 字段 | 说明 |
|------|------|
| branch name | 分支名 |
| owned files | 允许修改的文件范围 |
| out-of-scope | 禁止触碰的文件 |
| test command | 验证命令 |
| can commit? | yes/no |
| can push? | no (默认，除非人类明确授权) |
| dependency PRs | 依赖的 PR 号 |

## 编辑前检查

```bash
git fetch origin --prune
git status --short --branch    # 必须 clean
git diff --stat
```

## Commit 前检查

```bash
git diff --name-only
git diff --cached --name-only
git diff --check                # 检查尾随空格、混合 tab/space
```

If staged files include paths outside the task's scope — STOP. Do not commit. AI 经常"顺手"动到不在 scope 里的文件。

## PR 前检查

Run the PR readiness check:

```bash
bash scripts/check_pr_ready.sh
```

This runs fetch, status check, commit log, file diff, and `git diff --check` in one pass.

PR 必须小到一个人类 reviewer 能读完。每个 PR 必须包含：

```
## Summary
- what changed

## Dependency
- dependency PRs, branches, or versions

## Test Plan
- [x] command actually run

## Risk / Rollback
- risk and rollback path
```

AI-assisted PR 额外说明：哪个 agent/tool 写的、branch owner 是谁、实际跑过的验证命令。

## 同步 main 与 rebase

同步 main 之前先诊断：

```bash
git fetch origin --prune
git status --short --branch
git rev-list --left-right --count main...origin/main
```

main 只允许 fast-forward：

```bash
git config pull.rebase true
git config pull.ff only
```

工作分支 rebase 到 main：

```bash
git fetch origin
git rebase origin/main
```

如果 main 在 rebase 之前有冲突，不要在脏的 main 上直接 pull 解决。创建 isolation worktree 从 origin/main 重放。

## 破坏性命令安全规则

| 动作 | 风险 | 必须先做 |
|------|------|----------|
| `git stash` | 藏起别人的未提交变更 | `git status --short` + `git diff --stat` 确认所有变更是自己的 |
| `git reset --hard` | 丢失本地工作 | 先 `git stash` 或 `git branch backup/...` |
| `git push --force` | 覆盖上游 | 确认 owner、旧状态有 backup branch 或 tag |
| 删 branch | 丢失 review 上下文 | 无 open PR 依赖、commits 已 merged |
| 删 worktree | 丢失本地未推送工作 | 通过五条检查 |

Never skip hooks (`--no-verify`, `--no-gpg-sign`). Never force push to main.

## 并行 Agent 规则

- 并行 agent 只适合写入范围不重叠的任务
- 两个 agent 同时编辑同一个文件 = 地雷
- 如果一个文件被多个任务需要，只分配给一个 agent
- 合并时按依赖顺序：先合被依赖的 PR，再 rebase 依赖方

## 合并策略

默认 squash merge——一个 PR 对应 mainline 上一个 commit。只有当 commit sequence 本身有清晰审查价值时才用 rebase merge。

合并后运行完整测试套件：

```bash
git merge --no-ff <branch> && <test-command>
```

## 注意事项

- Worktree 共享 `.git` 对象库，但每个 worktree 的 `.git` 实际是指向主仓库的引用，不是独立拷贝
- 不隔离外部状态：数据库、Docker 容器、Redis 缓存是所有 worktree 共享的
- 每个 worktree 需要独立的端口配置（`.env.local` 中设置不同的 PORT）
- 磁盘空间：worktree 只复制 checkout 文件，不复制 `.git` 历史，空间开销远小于 clone
