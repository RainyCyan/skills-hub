---
name: distill-paper-knowledge
description: 从学术论文中重建问题动机、旧方案失效原因、设计约束、核心 claim、证据强度、隐藏假设与可迁移原则。触发场景：用户要求分析 paper、论文、arXiv、research paper，或明确要求不要只做 summary/总结，而要验证 evidence、limitations、assumptions、design trade-off。
---

# Distill Paper Knowledge

## Core Frame

Always treat a paper as a causal chain:

Problem -> Existing Limitation -> New Constraint -> Key Insight -> Design -> Evidence -> Conclusion -> Boundary

Never organize the answer by paper sections such as `Introduction`, `Method`, or `Experiments` unless the user explicitly asks for section-by-section reading notes.

## Before Starting

- If the paper source is missing, ask for the title plus one concrete source: link, PDF path, pasted text, or notes.
- If only an abstract, slide deck, or secondary summary is available, state that the evidence review is source-limited before analyzing.
- If the user requests comparison with prior, concurrent, or later work but does not provide extra sources, use only the methods explicitly discussed in the paper and label the comparison as paper-scoped.
- If a theorem, benchmark detail, or system constraint is not present in the available source, mark it as `Unknown` rather than inferring.

## Required Separation

- Always separate `Author Claim` from `Your Evaluation`.
- Always attach evidence to every major claim.
- Never invent metrics, proofs, dataset properties, author intent, or unstated implementation details.
- Never convert a benchmark win into universal superiority without stating workload and evaluation boundaries.

## Workflow

### 1. Extract Claims

- Record only claims that affect the paper's reasoning chain, not every local observation.
- For each major claim, capture `Claim`, `Evidence`, `Evidence Type`, `Confidence`, and one-line reason for the confidence level.
- Use these evidence types only: `theoretical proof`, `experiment`, `ablation`, `empirical observation`, `assumption`.

### 2. Reconstruct the Problem

- Write the causal path as `Previous Approach -> Failure -> New Constraint -> Insight -> Design`.
- Prefer causal language such as `X causes Y, so Z is required`.
- Never write `the paper proposes ...` as the primary framing if the motivation can be reconstructed.

### 3. Analyze the Design

- For each major component, answer `Why Needed`, `What Problem It Solves`, `How It Works`, and `Trade-off`.
- Trade-off must include `Benefit`, `Cost`, `When it works`, and `When it fails`.
- Never describe a mechanism without the constraint that made it necessary.

### 4. Verify Evidence

- Judge each major conclusion as `Supported`, `Partially Supported`, or `Unsupported`.
- Check whether the baselines are strong enough, ablations isolate the claimed factors, datasets represent the intended workload, and conclusions exceed the evidence.
- If the evidence supports only a narrow claim, narrow the verdict instead of broadening the conclusion.

### 5. Extract Hidden Assumptions

- Capture only assumptions that materially affect validity or transferability.
- Classify them under `Data Assumption`, `System Assumption`, `Workload Assumption`, or `Evaluation Assumption`.
- Ignore trivial assumptions shared by nearly all papers unless they are central to failure or misuse.

### 6. Distill Reusable Knowledge

- Extract `Core Principle`, `Design Pattern`, `Applicable Scenario`, and `Failure Boundary`.
- Answer the retention test: what should a strong reader still remember after forgetting the implementation details in six months?
- Prefer principles that transfer across papers or systems; avoid paraphrasing the abstract.

## Output Contract

- Unless the user asks for a different format, follow `references/paper_knowledge_card.md`.
- Use `references/evidence_review_checklist.md` to decide whether evidence is supported, partial, or unsupported.
- Keep conclusions evidence-backed and scoped; if the source cannot justify a statement, say so explicitly.
- If the paper lacks enough information for a requested section, keep the section and mark the missing parts as `Unknown` or `Not established in the provided source`.

## Stop Conditions

- Stop and ask for clarification if the user has not provided the paper itself or a reliable source.
- Stop and ask for more evidence if the user wants exact experimental results that are absent from the available material.
- Stop extending the claim list once new items no longer change the reconstructed causal chain.

## Failure Patterns

- Never produce a section-by-section summary as the default output.
- Never collapse `Author Claim` and `Your Evaluation` into one statement.
- Never hide uncertainty behind vague language such as `seems`, `likely`, or `possibly` without naming the missing evidence.
- Never treat a narrow benchmark result as proof of general design superiority.

## Evolution Policy

- If this skill is later refined, prefer updating examples, evaluation criteria, and recurring failure patterns first.
- Treat changes to the causal reasoning framework or verdict taxonomy as a major version change.
- Treat clarification of prompts, templates, and review heuristics as a minor version change.
