# Post-Merge Handoff：合入后回归、运行时迁回与清理

本文件是 `git-workflow` 的变体参考，仅在 MR 合入后需要做主线回归、把服务迁回 primary checkout、或决定清理策略时按需加载。核心状态机与硬规则见 `SKILL.md`，此处只放会随平台/环境变化的细节。

## 目录

- [1. 默认分支发现](#1-默认分支发现)
- [2. MR/PR merged 状态验证](#2-mrpr-merged-状态验证)
- [3. 三种远端合并策略差异](#3-三种远端合并策略差异)
- [4. primary checkout clean 时的同步](#4-primary-checkout-clean-时的同步)
- [5. primary checkout dirty/占用时的 integration worktree](#5-primary-checkout-dirty占用时的-integration-worktree)
- [6. 例外：未提交实验改动的 patch 迁移](#6-例外未提交实验改动的-patch-迁移)
- [7. 例外：单 commit 跨分支 cherry-pick](#7-例外单-commit-跨分支-cherry-pick)
- [8. 运行时迁回 primary checkout](#8-运行时迁回-primary-checkout)
- [9. 回归失败处理](#9-回归失败处理)
- [10. 清理决策表](#10-清理决策表)

## 1. 默认分支发现

```bash
git symbolic-ref --short refs/remotes/origin/HEAD | sed 's#^origin/##'   # -> main / master
# 若为空（浅克隆或未设 HEAD 引用）:
git remote set-head origin -a
```

不要在脚本或文档里写死 `main`。本仓库家族默认分支实为 `master`。

## 2. MR/PR merged 状态验证

优先用平台权威状态，而不是靠本地 commit 祖先推断（squash 会失效）：

```bash
# GitLab
glab mr view <branch>            # 看 state: merged + Merge commit SHA
# GitHub
gh pr view <branch> --json state,mergeCommit
```

平台 CLI 不可用时，从 MR/PR 页面复制 merge/squash commit SHA，作为 `--merge-sha` 传给
`check_feature_landed.sh` / `check_worktree_cleanup.sh`。**拿不到权威 merge 证据时 fail closed，不清理。**

## 3. 三种远端合并策略差异

| 策略 | mainline 结果 | feature commit 是否成为主线祖先 | 落地判定 |
|------|---------------|-------------------------------|----------|
| squash merge（默认） | 单个 squash commit | 否 | 用 `--merge-sha`（squash SHA）判 ancestry；不要用 feature commit |
| rebase merge | feature commits 线性追加 | 是 | ancestry 可判；`git branch -d` 通常可用 |
| merge commit | 一个 merge commit | 是（经 merge commit） | ancestry 可判 |

结论：唯一对三种策略都成立的判定是"**权威 merge SHA 是否为 `origin/<base>` 祖先**"。

## 4. primary checkout clean 时的同步

```bash
cd <primary-checkout>
git rev-parse --abbrev-ref HEAD        # 必须 == <default-branch>
git status --short                     # 必须 clean
git fetch origin --prune
git pull --ff-only origin <default-branch>
```

`--ff-only` 保证不产生本地 merge commit；即便远端是 squash，也只是本地指针前移。

## 5. primary checkout dirty/占用时的 integration worktree

primary checkout dirty，或停在别的活跃 feature 分支时，**禁止** `switch`/`reset`/`stash` 去强行腾出它。改用临时 detached worktree 回归：

```bash
git fetch origin --prune
git worktree add --detach <integration-path> origin/<default-branch>
cd <integration-path>
git rev-parse HEAD                                  # 记录回归所用 SHA
git merge-base --is-ancestor <merge-sha> HEAD       # 确认包含目标 merge
# build + 运行 post-merge test command
```

回归结束后清理临时目录：

```bash
git worktree remove <integration-path>
git worktree prune
```

注意：临时 integration worktree 只用于**验证**主线。如果主服务必须常驻在 primary checkout，则 runtime handoff 仍为 pending，不能用临时目录冒充最终迁回。

## 6. 例外：未提交实验改动的 patch 迁移

worktree 里有已验证但**未提交**的改动、且 `.git` 元数据写受限时，可迁到一个新的集成 feature branch（不可直接落 default）：

```bash
# 源 worktree
git diff HEAD --binary > /tmp/<name>.patch
# 目标：从最新默认分支开出的集成分支
git worktree add ../<intg> -b <intg-branch> --no-track origin/<default-branch>
cd ../<intg> && git apply /tmp/<name>.patch
# 之后仍走正常闭环: commit -> feature test -> push -> MR -> 回归 -> 清理
```

## 7. 例外：单 commit 跨分支 cherry-pick

把某一个已提交的目标 commit 带到另一 feature branch（不代表已回归主线）：

```bash
# 先做文件重叠检查，避免踩到目标分支未提交改动
git show --stat --name-only <sha>
git -C <target-worktree> diff --stat
git -C <target-worktree> cherry-pick <sha>
```

## 8. 运行时迁回 primary checkout

当 `runtime handoff = required`（服务需常驻 primary checkout）：

```bash
# 1. 停掉 feature worktree 里的实例，释放端口
#    先确认真正 owner，再停
ps -eo pid,cmd | grep -i <service>
readlink -f /proc/<pid>/cwd            # 确认 cwd 指向哪个 checkout
kill <pid>

# 2. 从 primary checkout 重建并启动
cd <primary-checkout>
<build-command>                        # 如 bun run build / npm run build
<start-command>                        # 用 setsid nohup 使其脱离当前 shell

# 3. 校验 owner 真的换到了 primary
readlink -f /proc/<new-pid>/cwd        # 必须指向 primary-checkout
<runtime smoke command>                # 契约里声明的 smoke 校验
```

要点：
- 迁回后 PID 的 cwd 必须是 primary checkout，而不是 feature worktree。
- 端口（如 4096）同一时刻只能一个 owner；确认旧实例已退出。
- 只有 smoke test 通过，才算 `RUNTIME_HANDED_OFF`。

## 9. 回归失败处理

post-merge 回归失败时：

- **保留** feature worktree，不删分支。
- **不要** 重写已合入历史（不 force push default branch、不 rebase 已合入 commit）。
- 通过新的 follow-up fix MR 或 revert MR 修复，走完整闭环。
- 记录失败证据（命令、输出）在任务里，供后续排查。

## 10. 清理决策表

| 前置条件 | 满足 | 动作 |
|----------|------|------|
| worktree clean | 否 | 停止，先提交或确认改动归属 |
| branch 已完整 push（ahead=0） | 否 | 先 push |
| MR authoritative merged + merge SHA landed | 否 | 停止（fail closed），先取权威证据 |
| post-merge 回归通过 | 否 | 停止，回到第 9 节 |
| runtime handoff（若 required）完成 | 否 | 停止，先迁回并 smoke |
| 以上全满足 | 是 | `git worktree remove` → `git worktree prune` → `git branch -d`（squash 且证据齐全才 `-D`） |

不确定就保留 worktree。
