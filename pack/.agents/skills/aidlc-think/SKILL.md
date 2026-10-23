---
name: aidlc-think
description: The AI-DLC thinking protocol used before any plan is written. Understand, recall lessons, research when needed, compare options in a decision table, decide, run a pre-mortem, plan and self-review. Light for bug fixes and small changes, full for features, new projects and risky changes. Use while preparing an implementation plan, bug-fix plan, architecture document or release plan.
---
<!-- aidlc-kit:managed · replaced when the kit is updated -->

# Thinking Protocol

**Goal:** every plan comes from the same careful thinking, not from the first idea.
**Output:** a better plan and its **Thinking summary** section (format at the end).

## Choose the depth (say it in one line, with the reason)
| Depth | Use for |
|---|---|
| **Light** | bug fix, small change (about 5 files or fewer), no new API, package or data change |
| **Full** | feature, new project, architecture, new package, security or privacy, data migration, anything risky |
When unsure, use full.

## The 8 steps
| # | Step | Light | Full |
|---|---|---|---|
| 1 | Understand | ✓ | ✓ |
| 2 | Recall lessons | ✓ | ✓ |
| 3 | Research | only if version-sensitive | when big or risky |
| 4 | Options | 2, briefly | 2–3 + decision table |
| 5 | Decide | ✓ | ✓ (+ ADR if significant) |
| 6 | Pre-mortem | 1–2 risks | 3–5 risks |
| 7 | Plan | ✓ | ✓ |
| 8 | Self-review | ✓ | ✓ |

### 1. Understand
- Start from the task brief (`.agents/skills/aidlc-prompt/SKILL.md`): its Goal and **Done when** are the
  goal and the success criteria (how the user will check it).
- List the constraints (architecture standard, platforms, versions, deadline) and the unknowns.
- Unknowns that change the result become questions (`00-aidlc-core.md` §4). Never guess.

### 2. Recall
- Read `aidlc-docs/brain/INDEX.md` and `.agents/brain/shared/INDEX.md`; open the lessons whose stack or tags
  match; check `aidlc-docs/brain/research/` for the topic.
- Note which lessons you apply (ID + how) and which do not fit (ID + why).

### 3. Research
- Big or risky decision, version-sensitive API, or a stale research note → follow
  `.agents/skills/aidlc-research/SKILL.md`.
- If the architecture standard already decides the question, write "decided by the standard §x" and skip.

### 4. Options
Write 2–3 real alternatives, including the simplest one that could work and the one the standard
suggests. Score each criterion 1–5 (5 = best):

| Criterion | Weight | Option A | Option B | Option C |
|---|---|---|---|---|
| Correct for the requirements | 3 | | | |
| Fits the architecture standard | 3 | | | |
| Simplicity (fewer files and concepts) | 2 | | | |
| Security and privacy | 2 | | | |
| Maintainability and testability | 2 | | | |
| Performance | 1 | | | |
| Cost and time | 1 | | | |
| Easy to undo | 1 | | | |
| **Weighted total** | | | | |

Light depth: two options compared in 2–3 lines.

### 5. Decide
- Choose the best weighted score unless a hard constraint rules it out. Explain in 1–3 sentences.
- Significant or hard-to-undo decision → ADR (`.agents/templates/decision-record.md`).

### 6. Pre-mortem
- Imagine: *"Two weeks later this change failed in production. Why?"* Write the causes.
- Give each cause a mitigation in the plan: a test, a check, a fallback, or a smaller step.
- Check the brain pitfalls for this stack: would any of them hit this plan?

### 7. Plan
- Smallest safe steps; the project still compiles after each step, and each step has a check.
- Every acceptance criterion has a test, every risk a mitigation, every file a reason.

### 8. Self-review (before the gate)
- Check the plan against its template's "Ready to approve?" list, `10-quality-gates.md` §3, the
  architecture rules and the brain pitfalls.
- Red team: *"What would a strict senior reviewer reject here?"* Fix it now.
- Simplify: remove anything the requirements don't need.
- Note what self-review changed. That is a good sign, not a failure.

## Thinking summary (put this section into the plan)
```
## Thinking summary
- Depth: full | light (reason)
- Lessons applied: S-003 (…), L-012 (…) · not applicable: …
- Research: R-004 (topic) | not needed (reason)
- Options: A … (score) · B … (score) → chosen: A, because …
- Pre-mortem: 1) … → mitigation … 2) … → mitigation …
- Self-review changes: …
```

## Rules
- Thinking happens before the gate. The user sees the summary and a better plan.
- Steps 1, 2, 6 and 8 are never skipped, even at light depth.
