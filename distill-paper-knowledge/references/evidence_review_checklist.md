# Evidence Review Checklist

Use this checklist before rating a conclusion as `Supported`, `Partially Supported`, or `Unsupported`.

## Baselines

- Are the compared baselines credible for the paper's claimed setting?
- Are obvious prior strong baselines missing?
- If a baseline is weak, does the conclusion depend on that weakness?

## Experimental Coverage

- Do experiments test the claim directly, or only a nearby proxy?
- Are dataset choices representative of the intended workload?
- Are hardware, system, or scale conditions narrow enough to limit transfer?
- Are results stable across more than one dataset, setting, or scale point?

## Ablation Quality

- Does the ablation isolate the factor that the authors say matters?
- Could multiple changes be moving together?
- Is the claimed mechanism tested, or only the final full system?

## Theoretical Support

- Does the theorem prove the operational claim, or only a weaker property?
- Do key assumptions hold in the empirical setting?
- Is the proof descriptive, existence-based, asymptotic, or practically binding?

## Verdict Rules

Rate as `Supported` only if the presented evidence directly matches the scope of the conclusion.

Rate as `Partially Supported` if evidence exists but the conclusion depends on narrow settings, weak assumptions, incomplete ablation, or proxy metrics.

Rate as `Unsupported` if the conclusion extends beyond the evidence, ignores missing baselines, or relies on assumptions that are not validated.

## Typical Failure Signals

- Benchmark win is reported, but no mechanism-level ablation exists.
- Theorem is correct, but engineering claims rely on unstated system assumptions.
- Improvement appears only on one dataset or one operating point.
- Recall, accuracy, or another proxy metric is treated as complete task quality without justification.
- Static-dataset results are generalized to dynamic or adversarial workloads.
