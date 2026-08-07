---
name: review
description: 编排基于变更证据的代码审查质量门，检查正确性、安全性、回归风险和仓库约束，并委托可用的 test skill 做动态验证。用于用户请求 /review、review diff/PR/commit、提交或合入前检查、代码质量门、安全审查，或询问变更是否可提交/合入时；不用于直接修复代码。
---

# Review

将本 skill 作为只读质量门编排器：确定范围、收集证据、运行廉价扫描、审查行为变化、委托动态验证并给出判定。Never modify reviewed files or implement fixes unless the user separately asks for remediation.

## 1. Freeze The Scope

Before reviewing:

- Read every applicable `AGENTS.md` for the changed files.
- Use the user-specified commit, branch, PR, staged set, or path scope when provided.
- Otherwise review the current worktree against `HEAD`, including staged、unstaged 和 untracked 文件。
- Use `scripts/collect_diff.sh` for the default scope. Use `--staged` for staged-only review, repeat `--path <path>` for path scopes, and pass `--target <git-diff-target>` only when the user supplied or the repository clearly defines that target.
- Never assume the base branch is `main`, `master`, or that `origin` exists.
- Stop with `信息不足` if the target cannot be resolved or the diff cannot be collected. Never reinterpret a tool error as an empty diff.
- If the collected diff is empty, return `无变更` and do not claim the codebase passed review.

Inspect complete changed files and their callers, tests, schemas, configuration, and error paths when the diff alone cannot establish behavior. Review only regressions introduced by the selected scope; do not report unrelated pre-existing defects.

## 2. Run Candidate Scanners

Keep the working directory at the reviewed repository and invoke both bundled scripts by their skill-directory path with the same scope:

```bash
scripts/check_secrets.sh [--target <git-diff-target> | --staged] [--path <path> ...]
scripts/check_debug_code.sh [--target <git-diff-target> | --staged] [--path <path> ...]
```

Interpret exit codes consistently:

- `0`: no candidate found.
- `1`: candidate found; manually verify it before reporting.
- `2+`: scanner or diff collection failed; final verdict cannot be `可以提交`.

Scanner output is triage evidence, not a finding. Never expose a matched credential value in the report.

## 3. Review Changed Behavior

Prioritize findings in this order:

1. **Correctness and data integrity**: changed behavior contradicts requirements, callers, schemas, lifecycle rules, error semantics, or persisted-state invariants.
2. **Security boundaries**: changed data flow crosses trust, authorization, execution, file, serialization, logging, or response boundaries without adequate enforcement. Load `references/security_checklist.md` only for these changes.
3. **Regression and operability**: changed failure paths, compatibility, concurrency, resource ownership, rollout configuration, or observability can break supported use.
4. **Repository contract**: changed files violate applicable `AGENTS.md` or explicit task scope.
5. **Test adequacy**: behavior changed without evidence for the meaningful success, failure, or boundary cases.

Only report a finding when all are present:

- a precise changed `file:line`;
- the triggering input, state, or execution path;
- the violated contract or invariant;
- the concrete user, security, data, or operational impact.

Read enough surrounding code to prove reachability. Do not report style preferences, generic best practices, speculative risks, or scanner keywords without a causal path. If a material concern cannot be resolved from available evidence, list it under `信息缺口` rather than converting it into a finding.

## 4. Delegate Dynamic Validation

After static review, use an available `test` or `test-*` skill to run the narrowest relevant validation for the frozen scope. Pass it the changed behavior, affected paths, and any risk hypotheses; do not reimplement a generic test workflow here.

- Never claim tests passed unless a command actually ran and its exit status/output support that claim.
- If no test skill is available, record `未验证：未提供 test skill`.
- If tests cannot run because of environment or dependency limits, record the exact blocker.
- Treat missing or blocked dynamic validation as `信息不足` unless the user explicitly requested static review only.

## 5. Decide The Gate

Use exactly one verdict:

- `需要修复`: at least one blocking finding, a relevant test failed, or a required scanner failed.
- `信息不足`: no blocking finding is proven, but scope collection, required context, scanner execution, or dynamic validation is incomplete.
- `可以提交`: no blocking finding remains and required scanners plus relevant dynamic validation completed successfully.
- `无变更`: the frozen scope contains no changes.

Classify findings:

- **阻塞**: can produce incorrect behavior, security compromise, data corruption/loss, incompatible public behavior, failed required validation, or violation of a hard repository constraint.
- **警告**: proven non-blocking regression or operability/test-coverage risk.
- **建议**: omit by default; include only when the user explicitly asks for improvement ideas.

## Output Contract

Lead with findings ordered by severity, then evidence. Omit empty finding sections.

```markdown
## 审查结论

**判定**: 需要修复 | 信息不足 | 可以提交 | 无变更
**范围**: [reviewed target and changed paths]

### 阻塞项
- `path/to/file:line` — [problem]
  - 触发路径: [input/state/call path]
  - 影响: [concrete consequence]

### 警告项
- `path/to/file:line` — [problem and consequence]

### 动态验证
- `[command or delegated test]` — 通过 | 失败 | 未验证

### 信息缺口
- [missing evidence and why it affects confidence]
```

If there are no findings, state `未发现可报告问题`; never replace that sentence with a guarantee of correctness. Keep remediation out of the report unless the user requests it.
