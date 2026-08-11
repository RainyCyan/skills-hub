<div align="center">
# skills-hub

<p align="center">
  <strong>把 Agent 的执行规则沉淀成可复用、可触发、可验证的技能基础设施。</strong>
</p>

<p align="center">
  <img alt="TRAE CLI" src="https://img.shields.io/badge/TRAE%20CLI-Agent%20Skills-2f6f5e?logo=github&logoColor=white">
  <img alt="Markdown" src="https://img.shields.io/badge/Docs-Markdown-000000?logo=markdown&logoColor=white">
  <img alt="Shell" src="https://img.shields.io/badge/Scripts-Shell-4eaa25?logo=gnubash&logoColor=white">
  <img alt="Git" src="https://img.shields.io/badge/Git-Worktree%20First-f05032?logo=git&logoColor=white">
</p>

</div>
## 项目定位

`skills-hub` 不是普通知识库。它沉淀的是 Agent 执行任务时会改变行为的规则、技能和脚本：让模型在合适的时机加载合适的约束，并把脆弱流程交给确定性脚本。

仓库面向三类上下文：

| 类型 | 作用 | 典型位置 |
| --- | --- | --- |
| 规则 | 常驻加载，定义仓库内默认遵守的协作边界 | `AGENTS.md` |
| 技能 | 按任务触发，改变模型在某类任务中的执行协议 | `<skill>/SKILL.md` |
| 资源 | 被技能按需调用，承载脚本、长文档或模板 | `scripts/`, `references/`, `assets/` |

核心原则：常驻内容越少越好，触发内容越准越好，可重复流程尽量脚本化。

## 技能目录

| 图标 | 技能 | 触发场景 | 产出 |
| --- | --- | --- | --- |
| <img alt="Git" src="https://img.shields.io/badge/-git--workflow-f05032?logo=git&logoColor=white"> | `git-workflow` | 创建分支、worktree、提交、PR、清理工作区 | 隔离的工作分支和可审计的 Git 流程 |
| <img alt="Review" src="https://img.shields.io/badge/-review-111827?logo=githubactions&logoColor=white"> | `review` | 审查 diff、提交前检查、质量门判断 | 基于冻结 diff 的审查结论 |
| <img alt="Skill Creator" src="https://img.shields.io/badge/-skill--creator-2563eb?logo=markdown&logoColor=white"> | `skill-creator` | 新建、重构或优化 Skill | 可触发、可维护的 `SKILL.md` |
| <img alt="TDD" src="https://img.shields.io/badge/-tdd-16a34a?logo=testinglibrary&logoColor=white"> | `tdd` | 实现 feature、修 bug、改行为逻辑 | `RED -> GREEN -> REFACTOR` 证据链 |
| <img alt="Grill" src="https://img.shields.io/badge/-grill-7c3aed?logo=openai&logoColor=white"> | `grill` | 需求欠定、目标不清、疑似 XY 问题 | 经用户确认的真实意图 |

## 仓库结构

```text
.
├── AGENTS.md                 # 仓库级执行原则与协作约束
├── README.md                 # 项目说明
├── git-workflow/             # worktree、分支、PR、清理流程
├── grill/                    # 实现前需求澄清门
├── review/                   # 基于 diff 证据的审查质量门
├── skill-creator/            # Skill 创建与优化协议
└── tdd/                      # 测试驱动开发状态机
```

每个 Skill 优先保持同一种物理形态：

```text
<skill>/
├── SKILL.md          # 必需：触发信息与执行规则
├── scripts/          # 可选：确定性脚本和检查器
├── references/       # 可选：按需加载的长文档
└── assets/           # 可选：模板、样例或可复用产物
```

## 快速使用

在仓库根目录执行，安装或更新本仓库的技能链接：

```bash
mkdir -p ~/.trae/skills
ln -sfn "$PWD/git-workflow" ~/.trae/skills/git-workflow
ln -sfn "$PWD/review" ~/.trae/skills/review
ln -sfn "$PWD/skill-creator" ~/.trae/skills/skill-creator
ln -sfn "$PWD/tdd" ~/.trae/skills/tdd
ln -sfn "$PWD/grill" ~/.trae/skills/grill
```

在本仓库开发时，默认从干净的 `origin/main` 创建独立 worktree：

```bash
git fetch origin --prune
git worktree add ../skills-hub-<task> -b codex/<scope>-<task> --no-track origin/main
```

## 编写原则

Skill 的目标不是把公共知识复制给模型，而是改变模型在具体任务上的行为。判断一段内容是否应该进入 Skill，只看两个条件：

1. 模型没有这段信息，或无法从任务本身可靠推断出来。
2. 这段信息会改变同类任务的执行结果。

| 放置位置 | 判断标准 |
| --- | --- |
| `AGENTS.md` | 仓库内所有任务都必须遵守。 |
| `SKILL.md` frontmatter | 这段文字决定技能是否会被触发。 |
| `SKILL.md` 正文 | 技能触发后，模型必须读取这些执行规则。 |
| `references/` | 信息有用，但体积大，或只在部分场景需要。 |
| `scripts/` | 行为应当确定、可重复，不能依赖模型自由发挥。 |

如果删掉某条规则后，另一个模型执行同类任务的结果不变，这条规则就不应该存在。

## 验证

按变更范围运行对应检查。文档变更至少运行 diff 空白检查；脚本或质量门变更再运行对应脚本。

```bash
git diff --check
bash git-workflow/scripts/check_pr_ready.sh
bash review/scripts/check_secrets.sh
bash review/scripts/check_debug_code.sh
```

`review` 类质量门必须基于同一份冻结 diff，避免不同检查器审查不同版本的工作区。

## 贡献方式

每个任务使用独立 worktree 和独立分支。提交前显式暂存文件，不使用 `git add -A`，并在 PR 中写明实际运行过的验证命令。

推荐 PR 结构：

```markdown
## Summary
- What changed

## Test Plan
- [x] Command that actually ran

## Risk / Rollback
- Risk and rollback path
```
