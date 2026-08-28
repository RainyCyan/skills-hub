# Repo Git Workflow Gate

这份共享规则用于把 `git-workflow` 从“建议”提升为“硬门禁”。
凡是把仓库根目录 `AGENTS.md` 软链到本文件的仓库，都应默认执行以下约束。

## 1. 编辑前硬门禁

在第一次编辑任何文件前，必须先完成并读取：

- `git status --short --branch`
- `git branch -vv`
- `git worktree list --porcelain`

未完成这三项检查，不允许编辑文件。

## 2. 开发契约先于改动

在第一次编辑前，必须显式说明：

- 当前分支
- 目标分支
- 是否新建 worktree
- 可修改目录范围
- 交付路径是 `push` 还是 `push + PR/MR`

如果这些信息没有说清，视为还没进入可编辑状态。

## 3. 分支语义必须匹配任务

如果当前任务与当前分支名语义不一致，必须立即停止，不得直接继续开发。

允许的后续动作只有两种：

- 从 `origin/main` 新建语义正确的分支或 worktree
- 向用户明确说明冲突，并得到“允许挂在现有分支上”的明确授权

默认禁止把 `kv-cache` 修复做在 `kv-cache-turboquant` 之类语义不匹配的分支上。

## 4. 默认采用 worktree-first

除非任务极小且用户明确要求复用当前 checkout，否则默认：

- 从 `origin/main` 创建独立分支
- 优先在独立 worktree 中开发

推荐形态：

- `git worktree add ../<repo>-<branch-slug> -b <branch> --no-track origin/main`

默认禁止直接在 `main` 上开发非一次性临时改动。

## 5. 只提交显式范围

提交前必须显式暂存目标文件，禁止：

- `git add -A`
- 顺手带上无关文件
- 混合多个任务的改动

提交前至少检查一次：

- `git diff --cached --stat`

如果要改写历史，先检查：

- `git show --stat HEAD`

## 6. Push 不是闭环，校验才是

push 前后都要校验：

- push 前：`git log --oneline origin/main..HEAD`
- push 后：`git ls-remote origin refs/heads/<branch>`

如果是改写历史后的 push，必须先：

- `git fetch origin`
- 再执行 `git push --force-with-lease`

不得把“命令退出码为 0”当作流程闭环的唯一依据。

## 7. PR/MR 能力要前置检查

如果目标交付包含 `PR/MR`，必须在开发开始前确认：

- 当前环境里真正可用的 `gh` / GitHub API / GitLab CLI
- 当前凭证是否足以创建 `PR/MR`

如果环境不支持，必须在流程早期明确告知用户，而不是等到 push 之后才暴露。

## 8. 多 worktree / 多 agent 安全

仓库存在共享 `.git` 时，必须假设：

- 可能有其他 worktree
- 可能有其他 agent / shell 正在操作同一仓库

因此默认要求：

- 先看 `git worktree list --porcelain`
- 不删除、不覆盖、不清理未知 worktree
- 不重置、不回滚、不覆盖未确认来源的改动

## 9. 现有仓库规则优先

如果目标仓库已经有自己的 `AGENTS.md`，不要自动覆盖。

已有仓库级规则通常承载该仓库独有的：

- 构建方式
- 测试方式
- 代码规范
- 发布约束

这种情况下，应人工合并，而不是直接用软链替换。

## 10. 最低执行标准

以后凡是涉及 git 开发流，默认最少执行以下顺序：

1. 审计 git 上下文
2. 判断分支语义是否匹配任务
3. 必要时新建 worktree / 分支
4. 声明开发契约
5. 编辑并验证
6. 显式暂存并提交
7. push 并校验远端
8. 进入 PR/MR 阶段

缺任何一步，都不应声称自己“已经按 git-workflow 执行”。
