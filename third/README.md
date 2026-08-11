# Third-Party Skill Sources

This directory stores upstream skill libraries as submodules. The files inside
submodules are reference material and are not first-class `skills-hub` skills
until they are reviewed, adapted, and promoted into a top-level skill directory.

## Inventory

| Path | Upstream | Pin | Contents |
| --- | --- | --- | --- |
| `agent-skills/` | `https://github.com/addyosmani/agent-skills.git` | tag `0.6.6` | Engineering workflow skills, slash-command definitions, agent prompts, docs, hooks, and validation scripts. |
| `superpowers/` | `https://github.com/obra/superpowers.git` | commit `44c9b2d6e889982ac18c27d05a19fefe335194e1` (`package.json` version `6.2.0`) | Methodology skills, runtime bootstrap files, plugin manifests, docs, tests, and helper scripts. |

## Promotion Rules

1. Keep third-party source as submodules. Do not vendor upstream files directly
   into this repository.
2. Promote one skill at a time into a top-level directory such as `review/`,
   `tdd/`, `grill/`, or a new skill directory.
3. Rewrite promoted skills for this repo's execution model instead of copying
   upstream prose wholesale.
4. Preserve upstream attribution and license notes in the promoted skill when
   upstream text or structure materially influences the result.
5. Add scripts only when they enforce a repeatable gate that model instructions
   alone cannot reliably enforce.

## Current Integration Notes

- `review/` overlaps with `agent-skills/skills/code-review-and-quality` and
  external Matt Pocock review patterns. Future review work should compare those
  sources against the repo's existing `Diff`, `Spec`, and `Standards` anchors
  before changing behavior.
- `tdd/` already incorporates external TDD references. Future changes should
  keep the local state machine as the source of truth and use `third/` only as
  supporting evidence.
- `git-workflow/` should remain stricter than generic upstream worktree
  guidance because this repo has shared `.git` sandbox constraints and active
  multi-worktree usage.
