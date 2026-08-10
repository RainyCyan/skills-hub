---
name: review
description: 编排基于变更证据的代码审查质量门，检查正确性、安全性、回归风险和仓库约束，并委托可用的 test skill 做动态验证。用于用户请求 /review、review diff/PR/commit、提交或合入前检查、代码质量门、安全审查，或询问变更是否可提交/合入时；不用于直接修复代码。
---

# Review

将本 skill 作为只读质量门编排器：钉住对照物、冻结 diff、隔离双轴审查、运行确定性检查、委托动态验证并给出判定。Never modify reviewed files or implement fixes unless the user separately asks for remediation. Always provide a structural remediation action for every finding; describing a remedy is not implementing it.

## 1. Pin Three Anchors

Before reading the diff for findings, record all three anchors:

| Anchor | Required evidence | Failure behavior |
|--------|-------------------|------------------|
| **Diff** | Exact base ref and resolved commit OID; target commit, worktree, staged set, PR, or path scope | Ask for the intended base when ambiguous. Return `信息不足` if it cannot be resolved. |
| **Spec** | User requirement, issue, PR description, design/spec document, or acceptance criteria that states expected behavior | A request that only says “review this” is not a spec. Ask for the requirement source and stop before findings. |
| **Standards** | Every applicable `AGENTS.md` plus repository-enforced contracts such as contribution rules, schemas, formatter/linter/type/test config, or documented API conventions | Search the repository. If no normative source can be identified, state what was searched and return `信息不足`. |

- Never infer a missing anchor from implementation code: the implementation is the review subject, not its own requirement or standard.
- Never assume the base branch is `main`, `master`, or that `origin` exists.
- Use the user-specified commit, branch, PR, staged set, or path scope when provided.
- Otherwise pin the current worktree as `base = HEAD <OID>`, `target = WORKTREE`, including staged, unstaged, and untracked files.
- Read every applicable instruction file for each changed path. More-specific instructions override broader ones.
- If any anchor is missing, ask one focused question when interaction is possible. Otherwise output only the anchor table, `判定: 信息不足`, and the missing evidence; do not continue into scanners or findings.

## 2. Freeze The Diff

- Use `scripts/collect_diff.sh` for the default worktree scope. Use `--staged` for staged-only review, repeat `--path <path>` for path scopes, and pass `--target <git-diff-target>` only for the pinned diff anchor.
- Save or retain one immutable diff snapshot and use that same snapshot or target arguments for every scanner, delegated reviewer, and test. If the worktree changes, invalidate prior results and restart.
- Stop with `信息不足` if the target cannot be resolved or the diff cannot be collected. Never reinterpret a tool error as an empty diff.
- If the collected diff is empty, return `无变更`; do not claim the codebase passed review.
- Count changed files and changed lines (`additions + deletions`) from the frozen diff. Report generated, vendored, lockfile, and migration changes separately rather than silently excluding them.

Classify review size using both thresholds; choose the larger class:

| Size | Threshold | Required handling |
|------|-----------|-------------------|
| **S** | `<= 200` changed lines and `<= 10` files | Normal review. Use isolated reviewers when the current context authored the change or the diff touches security, concurrency, persistence, public APIs, or generated AI code. |
| **M** | `201–800` changed lines or `11–25` files | Run isolated Spec and Quality reviewers. Review by subsystem when more than one subsystem changed. |
| **L** | `> 800` changed lines or `> 25` files | Ask for a split or review subsystem slices independently. Overall verdict remains `信息不足` until every slice is covered. |

Inspect complete changed files and their callers, tests, schemas, configuration, and error paths when the diff alone cannot establish behavior. Review only regressions introduced by the frozen scope; do not report unrelated pre-existing defects.

## 3. Isolate Spec And Quality Review

Keep two evidence ledgers. Never let a pass or high severity on one axis change the status or ordering of the other axis.

### Spec Axis

Check only whether the frozen diff implements the pinned requirement:

- Map each acceptance criterion to changed code and a validation result.
- Trace missing, extra, or contradictory behavior and changed public semantics.
- Mark an item `未证明` when no code or validation evidence establishes it.
- Do not downgrade a spec mismatch because the implementation is clean or tests pass.

### Quality Axis

Check only whether the frozen diff preserves correctness, security, operability, and repository standards:

- Use the pinned repository standards and reachable behavior as evidence.
- Do not treat the author’s rationale as proof.
- Do not downgrade a quality failure because the feature matches the spec.
- Inspect in this order:
  1. correctness and data integrity;
  2. security boundaries;
  3. regression and operability, including compatibility, concurrency, resource ownership, rollout, and observability;
  4. repository contracts;
  5. test adequacy for changed success, failure, and boundary behavior.

When sub-agents or multiple models are available and isolation is required:

1. Start fresh Spec and Quality reviewers in parallel.
2. Give both the frozen diff anchor and only the sources required for their axis.
3. Do not give them the author’s analysis, the other reviewer’s findings, suspected answers, or a draft verdict.
4. Require file-and-line evidence and axis-local status from each.
5. Synthesize after both finish without moving findings across axes.

If required isolation is unavailable, record `独立审查未完成`. For M/L changes or changes authored in the current context, the verdict cannot be `可以提交`. For other S changes, run two separate passes with separate ledgers and disclose that both passes used one context.

## 4. Run Candidate Scanners

Keep the working directory at the reviewed repository and invoke both bundled scripts by their skill-directory path with the frozen scope:

```bash
scripts/check_secrets.sh [--target <git-diff-target> | --staged] [--path <path> ...]
scripts/check_debug_code.sh [--target <git-diff-target> | --staged] [--path <path> ...]
```

Interpret exit codes consistently:

- `0`: no candidate found.
- `1`: candidate found; manually verify it before reporting.
- `2+`: scanner or diff collection failed; final verdict cannot be `可以提交`.

Scanner output is triage evidence, not a finding. Never expose a matched credential value in the report.

## 5. Match Detectable Shapes

Use these shapes as candidate generators. Report only when the changed lines make the shape reachable and violate a pinned spec, standard, or invariant.

| Detectable shape in the diff | Required remediation action |
|------------------------------|-----------------------------|
| The same discriminator or feature flag drives repeated condition branches in two or more locations | Centralize dispatch in one policy/map/strategy boundary; make callers consume the selected behavior. |
| A shared/core module imports feature-specific code or branches on a feature identity | Move the policy into the feature adapter or inject a narrow capability into the shared module. |
| Added helpers repeat the same validation, normalization, mapping, or error flow with only names/constants changed | Keep one implementation with explicit parameters when semantics are identical; otherwise name and test the semantic difference. |
| Added `any`, unchecked cast, type-ignore, lint suppression, or broad exception bypass has no adjacent invariant or runtime guard | Model the real type/schema, narrow at the boundary, or add the missing guard; remove the suppression. |
| Request, JSON, environment, database, cache, queue, or file data is used before type/range/enum/schema validation | Validate once at the trust boundary and pass a typed/validated value inward. |
| A loop performs one query, RPC, filesystem call, or other remote I/O per item | Batch, preload, join, or bound concurrency; add a query/call-count assertion where practical. |
| A catch/default/fallback path discards an error or converts failure into success without a specified contract | Propagate or translate the error at the boundary; if fallback is required, make it explicit and observable. |
| Resource acquisition or state mutation has an early-return/exception path without cleanup, rollback, or idempotency | Use scoped cleanup/transaction semantics and test the failing path. |
| Authorization, existence, quota, or version is checked separately from the protected mutation | Move check-and-act behind one authoritative atomic boundary or use compare-and-swap/transaction enforcement. |
| Public behavior, persisted schema, config, or protocol changes without caller migration, compatibility handling, or boundary tests | Add the migration/compatibility path and tests for old and new states. |
| New behavior has only happy-path tests or mocks out the changed boundary | Add the smallest failure and boundary cases that can falsify the implementation. |
| Comments, names, or docs claim behavior that executable paths do not enforce | Enforce the invariant in code or remove/rewrite the claim. |

For security-boundary changes, load `references/security_checklist.md` and prove `Source -> Missing/Bypassed Guard -> Sink -> Impact`.

Only report a finding when all are present:

- a precise changed `file:line`;
- the triggering input, state, or execution path;
- the violated contract or invariant;
- the concrete user, security, data, or operational impact.
- one structural remediation action that removes the cause rather than restating the symptom.

Read enough surrounding code to prove reachability. Do not report style preferences, generic best practices, speculative risks, or scanner keywords without a causal path. If a material concern cannot be resolved from available evidence, list it under `信息缺口` rather than converting it into a finding.

## 6. Classify And Rank Findings

Classify each finding on its own axis:

| Severity | Mechanical threshold |
|----------|----------------------|
| **Critical** | Reachable exploit, authorization bypass, credential exposure, data corruption/loss, irreversible operation, or broad production outage. |
| **Required** | Proven spec mismatch, incorrect supported behavior, hard repository-standard violation, compatibility break, or missing validation for a changed high-risk boundary. |
| **Optional** | Proven local maintainability, performance, operability, or test weakness without current incorrect behavior. |
| **Nit** | Localized mechanical cleanup with no behavioral effect. Omit by default; include only when requested. |
| **FYI** | Context or follow-up that requires no action for this change. Never use FYI to hide uncertainty or a real defect. |

Within each axis, order by leverage:

1. Rank broader blast radius and earlier trust/lifecycle boundaries first.
2. Prefer one root structural finding over many downstream symptoms.
3. If one structural defect explains the review, make it the first finding; never bury it below Nits.
4. Quantify affected files, call sites, branches, queries, or uncovered cases when evidence permits.
5. Never move a Spec finding below a Quality finding, or vice versa; each axis has its own ordering and status.

## 7. Delegate Dynamic Validation

After static review, use an available `test` or `test-*` skill to run the narrowest relevant validation for the frozen scope. Pass it the changed behavior, affected paths, and any risk hypotheses; do not reimplement a generic test workflow here.

- Never claim tests passed unless a command actually ran and its exit status/output support that claim.
- If no test skill is available, record `未验证：未提供 test skill`.
- If tests cannot run because of environment or dependency limits, record the exact blocker.
- Treat missing or blocked dynamic validation as `信息不足` unless the user explicitly requested static review only.

## 8. Enforce Anti-Sycophancy

- Never rubber-stamp. `未发现可报告问题` means no issue met the evidence threshold; it does not mean the change is correct.
- Never soften a proven defect because the author is confident, the change is urgent, or most of the implementation is good.
- Never use “clean”, “simple”, “robust”, or “well-designed” without naming the observable evidence.
- Quantify changed size, repeated occurrences, boundary cases, and validation results whenever the data is available.
- Review known AI-generated code more strictly for invented APIs, near-duplicate helpers, broad casts/suppressions, placeholder behavior, dead abstractions, and tests that mirror the implementation instead of the spec.

Reject these shortcuts:

| Excuse | Reality check |
|--------|---------------|
| “Tests pass.” | Tests only cover executed assertions; map them to acceptance criteria and changed failure boundaries. |
| “The diff is small.” | A one-line authorization, config, migration, or default-value change can be Critical. |
| “The repository already does this.” | Existing code is not a standard unless a pinned normative source requires it; precedent does not justify a newly introduced defect. |
| “This is temporary.” | Treat code as permanent unless an enforced removal mechanism and owner exist. |
| “AI generated it.” | Generation speed is not evidence; duplication and fabricated-contract risk are higher. |
| “It works locally.” | Local success does not prove CI, production configuration, concurrency, compatibility, or failure behavior. |

## 9. Decide The Gate

Give each axis an independent status: `通过 | 失败 | 信息不足`.

Use exactly one verdict:

- `需要修复`: either axis contains a `Critical` or `Required` finding, a scanner candidate is verified as a `Critical` or `Required` defect, or a relevant test fails because of the change.
- `信息不足`: an anchor, axis, required isolation, scanner execution, scope slice, or required dynamic validation is incomplete.
- `可以提交`: both axes are `通过`, no `Critical` or `Required` finding remains, required isolation completed, and scanners plus relevant dynamic validation succeeded or were explicitly excluded by the user.
- `无变更`: the frozen scope contains no changes.

Never average, compensate, or rerank across axes. A Spec failure and a Quality pass still produce `需要修复`; a Spec pass and a Quality failure also produce `需要修复`.

## Output Contract

After the three-anchor gate passes, always emit the anchor table, size, two axis sections, validation checklist, and verdict. Omit only empty severity subsections inside an axis. If the anchor gate fails, emit the verdict, anchor table, and information gaps only, as required by Section 1.

```markdown
## 审查结论

**判定**: 需要修复 | 信息不足 | 可以提交 | 无变更
**变更体量**: S | M | L — [N files, +A/-D, generated/vendor/migration count]

### 对照物
| 对照物 | 已钉住的来源 |
|--------|--------------|
| Diff | [base ref + OID -> target; paths] |
| Spec | [requirement/issue/spec path or missing] |
| Standards | [AGENTS/config/schema/contribution sources or missing] |

### Spec Compliance — 通过 | 失败 | 信息不足
| Acceptance criterion | Code evidence | Validation evidence | Status |
|----------------------|---------------|---------------------|--------|
| [criterion] | [`path:line`] | [test/static evidence] | 通过 / 失败 / 未证明 |

#### Critical
- [finding, or omit this subsection]

#### Required
- `path/to/file:line` — [problem]
  - 证据链: [criterion -> changed path -> contradiction]
  - 影响: [concrete consequence]
  - 补救: [structural remediation action]

#### Optional
- [finding, or omit this subsection]

### Quality & Standards — 通过 | 失败 | 信息不足
#### Critical
- [finding, or omit this subsection]

#### Required
- `path/to/file:line` — [problem]
  - 触发路径: [input/state/call path]
  - 违反: [standard or invariant]
  - 影响: [concrete consequence]
  - 补救: [structural remediation action]

#### Optional
- [finding, or omit this subsection]

#### Nit / FYI
- [include only when explicitly requested]

### 验证清单
- [x/ ] Diff snapshot frozen
- [x/ ] Spec reviewer isolated
- [x/ ] Quality reviewer isolated
- [x/ ] Secret scanner: 通过 | 候选已核查 | 失败
- [x/ ] Debug scanner: 通过 | 候选已核查 | 失败
- [x/ ] `[command or delegated test]`: 通过 | 失败 | 未验证

### 信息缺口
- [missing evidence and why it affects confidence]
```

For every completed axis with no findings, state `未发现可报告问题`; never replace that sentence with a guarantee of correctness. Every reported finding must include `补救`; keep code edits out of the report unless the user separately requests remediation.
