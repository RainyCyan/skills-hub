---
name: git-workflow
description: 管理 git 仓库的并发安全、worktree 隔离与完整分支生命周期。触发场景：创建分支/worktree、提交代码、推送、创建或合入 PR/MR、rebase、MR 合入后追平默认分支、在主 checkout 或临时集成 worktree 上做合入后回归、把运行时迁回主 checkout、以及安全清理已完成的 worktree 和分支。确保线性历史、文件完整性、多 agent 不互相覆盖，并让"功能完成→回归主线→清理"形成闭环。
---

# Git Workflow

## 核心原则

1. **main 只做集成，不做开发。** Never commit directly to main. main 是唯一事实源，只通过 PR/MR 合入。
2. **一个任务 = 一个 worktree + 一个 branch + 一份 scope。** 每个 agent 在自己的 worktree 中工作，文件系统隔离，互不干扰。
3. **线性历史。** main 只接受 fast-forward。禁止本地 merge commit 出现在 main 上。
4. **破坏性命令必须慢动作。** Never force push、hard reset、stash 他人的工作。
5. **完成 = 回归 + 清理，不是开发完就删。** feature 分支测试通过只是中间态；只有远端已合入、合入后的主线已回归、运行时已迁回，才允许清理 worktree（见「Worktree 完成定义」）。

## Checkout 角色

- **default branch**：远端事实源，通常是 `origin/main` 或 `origin/master`。用 `git symbolic-ref --short refs/remotes/origin/HEAD` 动态解析，不要硬编码。
- **primary checkout**：仓库的长期入口目录（如 `/cloudide/workspace/agent`）。推荐保持 clean、停在 default branch、只做同步与主服务运行。**primary checkout ≠ default branch，必须显式检查它当前分支和 dirty 状态。**
- **feature worktree**：开发目录，只承载一个 feature branch。
- **integration worktree**：当 primary checkout 不可安全同步（dirty 或停在别的活跃分支）时，用 default branch 的确切 SHA 临时创建的回归目录。

## Worktree 生命周期状态机

```
CREATED → DEVELOPED → FEATURE_VERIFIED → PUSHED → MR_MERGED
       → BASE_SYNCED → POST_MERGE_VERIFIED → RUNTIME_HANDED_OFF
       → CLEANUP_READY → CLEANED
```

任务只有走到 `CLEANED`（或用户明确选择保留 worktree）才算闭环。下面各节按此顺序展开。

## 创建 worktree

Always create a worktree from origin/<default-branch> before starting any task. Use `--no-track` so the new branch does NOT inherit the default branch as upstream:

```bash
git fetch origin --prune
git worktree add ../<dir-name> -b <branch-name> --no-track origin/<default-branch>
```

为什么 `--no-track`：不加时新分支 upstream 会指向 default branch，导致 `git status` 的 ahead/behind 相对 main 计算、`git pull` 把 main 合进来污染线性历史、首次 `git push` 默认指向 main。首次推送时显式建立本分支的远端跟踪：

```bash
git push -u origin <branch-name>
```

分支命名规范（携带来源和 scope）：

```
codex/<scope>-<task>
claude/<scope>-<task>
feat/<topic>
fix/<topic>
```

禁止使用 `update`、`fixes`、`wip`、`new-code` 等看不出责任边界的名字。

### 目录名与分支名的确定性映射

`<dir-name>` 与 `<branch-name>` 是两个值，但清理时 `git worktree remove ../<dir-name>` 和 `git branch -d <branch-name>` 要求同时记住二者。固定映射规则：**目录名 = 分支名去掉 `feat/`、`fix/`、`codex/`、`claude/` 等前缀**（如分支 `feat/tdd` → 目录 `tdd`）。不要用带 `/` 的分支名直接作目录名，`../feat/tdd` 会被当成子目录路径而非隔离 worktree。

### 进入与列出

```bash
cd ../<dir-name>
git status --short --branch   # 必须 clean
git worktree list
```

## 任务分配契约

Before starting work, define the task boundary in writing. 契约要在**创建 worktree 时**就写清"如何结束"，而不是开发完再临时决定：

| 字段 | 说明 |
|------|------|
| branch name | 分支名 |
| default branch | `main` / `master` / 其他目标分支 |
| primary checkout | 长期入口目录路径 |
| owned files | 允许修改的文件范围 |
| out-of-scope | 禁止触碰的文件 |
| feature test command | feature 分支上的验证命令 |
| post-merge test command | 合入主线后必须重跑的回归命令 |
| runtime handoff | required / not-required（是否需要把服务迁回 primary） |
| runtime smoke command | 服务迁回后的验证命令（若 handoff required） |
| can commit? / can push? | 默认 push=no，除非人类明确授权 |
| cleanup policy | MR 合入后删除或保留 worktree |
| dependency PRs | 依赖的 PR 号 |

## 编辑前 / Commit 前检查

```bash
git fetch origin --prune
git status --short --branch    # 必须 clean
git diff --stat
git diff --name-only; git diff --cached --name-only
git diff --check                # 尾随空格、混合 tab/space
```

If staged files include paths outside the task's scope — STOP. AI 经常"顺手"动到不在 scope 里的文件。

## PR/MR 前检查

```bash
bash <git-workflow-skill-dir>/scripts/check_pr_ready.sh
```

> 所有 bundled scripts 都相对本 `SKILL.md` 所在目录解析，不要假设目标仓库里存在 `scripts/`。

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

## 同步默认分支与 rebase

```bash
git fetch origin --prune
git status --short --branch
git rev-list --left-right --count <default-branch>...origin/<default-branch>
git config pull.rebase true
git config pull.ff only
```

工作分支 rebase 到最新默认分支：

```bash
git fetch origin
git rebase origin/<default-branch>
```

如果默认分支在 rebase 之前有冲突，不要在脏的主分支上直接 pull 解决。创建 isolation worktree 从 origin/<default-branch> 重放。

## 合并策略：只经远端 MR

**正常集成只能通过远端 MR/PR。** 默认 squash merge——一个 PR 对应 mainline 上一个 commit（更易 revert、更易生成 release notes）；只有当 commit sequence 本身有清晰审查价值时才用 rebase merge。

MR 合入后，本地默认分支只做 fast-forward，**不产生本地 merge commit**：

```bash
git fetch origin --prune
git pull --ff-only origin <default-branch>
```

> 即使远端产生 squash commit，本地 `pull --ff-only` 也只是把本地指针前移，不会新建本地 merge commit。

## MR 合入后的回归闭环（缺失环节的核心）

feature worktree 验证完成 **不等于** 任务完成。合入后必须走完回归与迁回：

1. 从远端平台确认 MR 已 merged，记录 merge/squash commit SHA。
2. `git fetch origin --prune`。
3. 用脚本确认功能确实"落地"到默认分支：
   ```bash
   bash <git-workflow-skill-dir>/scripts/check_feature_landed.sh \
     --repo <repo-path> --branch <feature-branch> \
     [--base <default-branch>] --merge-sha <mr-merge-or-squash-sha>
   ```
4. 选择回归 checkout：
   - primary checkout **clean 且停在 default branch** → `git pull --ff-only origin <default-branch>`。
   - 否则（dirty 或停在别的活跃分支）→ **禁止自动 switch/reset/stash**，改用临时 integration worktree：
     ```bash
     git worktree add --detach <integration-path> origin/<default-branch>
     ```
5. 在回归 checkout 上重新 build，并运行契约里的 **post-merge test command**。
6. 若 `runtime handoff = required`：从 durable checkout 重启主服务，验证进程 cwd、配置，并跑 smoke command。
7. 停掉 feature worktree 里的服务，释放端口和 owner。

平台差异、服务迁回细节、回归失败处理见 `references/post-merge-handoff.md`。

## Worktree 完成定义（Definition of Done）

以下条件全部满足，feature worktree 才算完成：

1. feature worktree clean，改动已 commit。
2. feature test command 在 feature 分支通过。
3. branch 已基于最新 `origin/<default-branch>` rebase / 线性追平。
4. branch 已完整 push（ahead upstream 为 0）。
5. MR/PR 已由远端平台确认 **merged**。
6. merge/squash SHA 已进入 `origin/<default-branch>`。
7. 在含该 merge SHA 的默认分支 SHA 上重跑 post-merge 回归通过。
8. 若影响运行时：主服务已从 durable checkout 启动并通过 smoke test。
9. feature worktree 不再承载服务、端口或活跃 owner。
10. cleanup checker 全部通过。

## 清理 worktree

删除前运行清理安全检查（消费上面的 landed 证据）：

```bash
bash <git-workflow-skill-dir>/scripts/check_worktree_cleanup.sh \
  --branch <branch-name> --worktree <worktree-path> \
  [--base <default-branch>] --merge-sha <mr-merge-sha>
```

全部通过后：

```bash
git worktree remove <worktree-path>   # 有未跟踪运行时资产时可加 --force
git worktree prune
git branch -d <branch-name>           # squash merge 后本地分支非主线祖先，-d 可能拒绝
# 仅当 MR merged + merge SHA landed + branch fully pushed + 回归通过，才可 git branch -D
```

不确定就保留。Never delete a worktree unless all conditions pass.

## 禁止的集成捷径

- 不要用本地 merge（尤其 `git merge --no-ff <feature>`）把 feature 分支塞进默认分支来代替 MR。
- 不要靠复制文件把**已提交**的 feature worktree 迁回 primary checkout。
- 不要仅凭 feature tests 通过就删除 worktree。
- 不要用"feature commit 是否为默认分支祖先"判断 **squash** MR 是否合入（squash 后不成立）。
- 不要在 dirty 或承载其他任务的 primary checkout 上自动 switch/reset/stash。
- MR 状态无法确认时 **fail closed**，不要以 SKIP 放行 cleanup。

## 例外路径（非默认，谨慎使用）

- **未提交的实验性 worktree 改动**：可用 `git diff HEAD --binary > /tmp/x.patch` + `git apply` 迁到一个新的集成 feature branch，但迁移后仍要 commit → test → push → MR，不能直接落 default branch。
- **单个目标 commit 跨分支**：`git cherry-pick <sha>` 适合把一个 commit 带到另一 feature branch，不代表已回归主线。

## 破坏性命令安全规则

| 动作 | 风险 | 必须先做 |
|------|------|----------|
| `git stash` | 藏起别人的未提交变更 | `git status --short` + `git diff --stat` 确认变更都是自己的 |
| `git reset --hard` | 丢失本地工作 | 先 `git stash` 或 `git branch backup/...` |
| `git push --force` | 覆盖上游 | 用 `--force-with-lease`；确认 owner、旧状态有 backup |
| 删 branch | 丢失 review 上下文 | 无 open PR 依赖、commits 已 merged |
| 删 worktree | 丢失本地未推送工作 | 通过 cleanup checker |

Never skip hooks (`--no-verify`, `--no-gpg-sign`). Never force push to main.

## 运行环境前置（sandbox / 只读 .git）

某些运行环境（如 CloudIDE sandbox）会拦截网络访问，并把 `.git` 挂成只读 overlay。凡是含 `git fetch`、`git worktree add`、`git commit`、`git push` 的命令，首次可能失败并报：

```
SandboxDenied: command was blocked by the sandbox.
error: cannot open '.git/FETCH_HEAD': Read-only file system
```

这是环境限制，不是仓库损坏或网络故障——不要据此判定 fetch 失败或 `.git` 损坏。处理方式：关闭 sandbox 后重试同一条命令（在 TRAE CLI 中用 `dangerouslyDisableSandbox: true`）。`.git` 可能只读而 worktree 目录可写，因此编辑文件成功、`git add`/`git commit` 却失败，属正常现象，同样按关闭 sandbox 重试处理。

## 并行 Agent 规则

- 并行 agent 只适合写入范围不重叠的任务；两个 agent 同时编辑同一文件 = 地雷。
- 如果一个文件被多个任务需要，只分配给一个 agent。
- 合并时按依赖顺序：先合被依赖的 PR，再 rebase 依赖方，逐个跑测试。
- worktree 拓扑、`node_modules` 共享、`.env.local`、端口隔离等环境准备见 `git-worktree-parallel-dev` 技能；功能完成后的回归与清理回到本技能的闭环。

## 注意事项

- Worktree 共享 `.git` 对象库，但每个 worktree 的 `.git` 是指向主仓库的引用，不是独立拷贝。
- 不隔离外部状态：数据库、Docker 容器、Redis 缓存是所有 worktree 共享的。
- 每个 worktree 需要独立端口（`.env.local` 中设置不同 PORT）。
- 磁盘：worktree 只复制 checkout 文件，不复制 `.git` 历史，开销远小于 clone。
