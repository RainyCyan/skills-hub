---
name: tdd
description: 使用严格的测试驱动开发状态机实现或修改可观察行为：先写并验证失败测试，再写最小实现，保持全绿后才重构。用于实现 feature、修复 bug、修改业务逻辑、重构有行为风险的代码，或用户提到 TDD、test-first、测试先行、red-green-refactor、回归测试时；不用于纯文档、无行为的静态配置或生成文件变更。
---

# TDD

将本 skill 作为行为变更的低自由度执行协议。每个切片必须留下可核验的 `RED -> GREEN -> REFACTOR` 证据；仅有最终通过的测试不构成 TDD 证据。

## 1. Establish The Contract

Before changing tests or production code:

- Read applicable repository instructions, requirement sources, neighboring tests, CI workflows, and build/test configuration.
- State one observable behavior for the current slice as `given / when / then`.
- If repository evidence is insufficient to state the expected behavior, ask for the missing requirement before writing a test.
- Name the public seam where the behavior is observed. Test through a public API, command, route, event, rendered UI, persisted result, or other consumer-visible boundary; never select a private method merely because it is easy to call.
- Name one realistic production mutation that the test must catch. If no incorrect production change would make the test fail, redesign or omit the test.
- Derive expected values from the requirement, a hand-checked literal, or an independent fixture. Never compute the expected value with production code or the same algorithm under test.
- If multiple plausible seams imply different public contracts or materially different cost, ask the user to choose before writing a test. Otherwise select the narrowest stable seam supported by repository evidence and record it.

For a bug fix, the first slice must reproduce the reported bug. For a new feature, the first slice must prove the smallest externally useful capability.

## 2. Discover The Test Runtime

Never assume a test command or framework.

1. Discover the language, checked-in wrappers, test configuration, neighboring test layout, focused-test syntax, and CI merge gates.
2. Record:
   - `FOCUSED_TEST`: runs only the current test or smallest relevant target;
   - `RELATED_TESTS`: runs the affected package/module;
   - `FULL_VALIDATION`: runs the repository-required suite and applicable type/lint/build gates.
3. Prefer repository scripts and checked-in wrappers over global binaries.
4. Run the smallest existing relevant test once before editing when it can reveal a dirty baseline. Record pre-existing failures separately.
5. If no runnable test infrastructure exists, stop before production changes. Ask before adding a framework, dependency, service, or broad harness.

Load `references/test-quality-gates.md` before writing or changing a test, mock, fake, fixture, snapshot, or test-only helper.

## 3. Execute One Vertical Slice

Never batch all tests before implementation. Complete one behavior through the full cycle, then use what it taught you to choose the next behavior.

### RED

1. Write one minimal test for the current behavior. Do not change production code in this phase.
2. Keep setup explicit enough that the test reads as a behavioral specification.
3. Run `FOCUSED_TEST`.
4. Accept RED only when all are true:
   - the test process ran;
   - the new test failed;
   - it failed at the intended behavioral assertion, or at a compile/type error that precisely identifies the missing public contract;
   - when an assertion ran, the observed result differs from the independently derived expectation;
   - the failure is caused by missing or incorrect production behavior, not an unrelated syntax, import, fixture, environment, or setup error.

If the test passes immediately, it does not prove the requested change. Confirm whether the behavior already exists, then strengthen or remove the test. If the test harness errors, fix the harness and rerun until it fails for the intended behavioral or public-contract reason.

Never weaken assertions, approve snapshots, or change expected values merely to manufacture RED or GREEN.

### GREEN

1. Change only the production code required by the failing test.
2. Do not add speculative options, abstractions, compatibility layers, or adjacent behavior not demanded by the current test.
3. Run `FOCUSED_TEST`.
4. Accept GREEN only when the new test passes and the output has no new error or warning attributable to the change.
5. Run `RELATED_TESTS` after a change that can affect neighboring behavior. Fix production code, not the test, when the implementation violates the established contract.

### REFACTOR

Refactor only while GREEN:

- Preserve the tested public behavior.
- Make one structural change at a time.
- Run `FOCUSED_TEST` after each refactor step; run `RELATED_TESTS` when the affected surface expands.
- If a test fails, revert or repair the refactor before continuing.
- Never introduce new behavior during refactoring. New behavior starts a new RED cycle.

Refactoring is optional. Skip it when no concrete duplication, naming defect, coupling, or structure problem remains.

## 4. Protect The Test Signal

- Assert observable state, output, side effects, or boundary contracts; do not assert private call sequences unless the sequence itself is the public contract.
- Prefer real implementations, then fakes, then stubs, and use mocks only at slow, external, non-deterministic, or destructive boundaries.
- Never assert that a mock exists or was rendered as the substitute for asserting real component behavior.
- Keep test-only cleanup and helpers in test code unless production owns that lifecycle.
- Control time, randomness, order, global state, filesystem, network, and concurrency so repeated runs have the same result.
- Use snapshots only for stable, reviewable contracts. Inspect the complete diff before accepting an update.
- Keep each test independent. A test must pass alone and must not depend on execution order or residue from another test.

## 5. Handle Existing Code Safely

- If this task wrote production code before its first failing test, revert only those task-owned production changes and restart at RED. Never delete or reset user-owned or pre-existing work.
- If implementation predates the current task, do not claim retroactive TDD. Add a characterization or regression test, prove that it catches the intended break where possible, and label the work accurately.
- Exploration code is allowed only when explicitly disposable. Remove it before beginning the recorded RED cycle.
- Pure documentation, static content, and configuration with no executable behavior are outside this protocol. If configuration changes runtime behavior, test that behavior at the consuming boundary.
- Generated code and throwaway prototypes may skip TDD only with explicit user approval; record the exception and its verification plan.

## 6. Finish The Change

Before declaring completion:

1. Complete every requested behavior as its own vertical slice.
2. Run `FULL_VALIDATION`; do not substitute a focused test for repository-required gates.
3. Confirm every new or changed test passes alone and in its relevant suite.
4. Perform the mutation check from `references/test-quality-gates.md`.
5. Inspect the final diff for:
   - production behavior with no proving test;
   - tests added after implementation without recorded RED evidence;
   - weakened assertions or blindly updated snapshots;
   - test-only methods leaked into production;
   - speculative production code not required by any test.

If any required command cannot run, report the exact blocker and mark validation incomplete. Never infer a pass from code inspection.

## Output Contract

Report evidence, not a generic statement that TDD was followed:

```markdown
## TDD Evidence

### Slice: [observable behavior]
- Contract: Given [state], when [action], then [outcome]
- Seam: [public boundary]
- Break caught: [realistic production mutation]
- RED: `[focused command]` — failed at [intended assertion or precise missing-contract compile/type error]
- GREEN: `[focused command]` — passed
- REFACTOR: [change + rerun result] | skipped: [reason]

### Final Validation
- Related: `[command]` — passed | failed | blocked
- Full: `[command]` — passed | failed | blocked
- Mutation check: [mutations covered or remaining gap]
- Pre-existing failures: [none or exact failures]
```

Never write `RED` unless the test command actually ran and failed for the intended reason. Never write `GREEN` unless the corresponding test command actually ran and passed after the production change.
