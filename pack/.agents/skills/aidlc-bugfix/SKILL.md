---
name: aidlc-bugfix
description: Fix a bug the AI-DLC way. Triage questions, reproduce, find the root cause with file:line evidence, then a bug-fix plan with a regression test that the user approves before any code changes. Use for "bug", "crash", "error", "not working" and "wrong result" reports.
---
<!-- aidlc-kit:managed · replaced when the kit is updated -->

# Bug Fix

**Output folder:** `aidlc-docs/work/<NNN>-bugfix-<slug>/` with `bugfix_plan.md` (+ `questions.md`,
`test-report.md`, `review-report.md` during construction)

| Stage | Output | Gate |
|---|---|---|
| B1 Triage | `questions.md` | the user's answers (skip if the report is already complete) |
| B2 Reproduce and root cause | `bugfix_plan.md` §1–4 | none |
| B3 Fix plan | `bugfix_plan.md` §5–12 | 🛑 approve → the code gate opens |

## B1. Triage
1. Create the work item (type `bugfix`, e.g. `005-bugfix-login-crash`); state `mode: inception`,
   `stage: B1 Triage`; add it to the "Work items" table; save the task brief at the top of `questions.md`.
2. Ask what is missing (question bank K): steps to reproduce; expected vs actual; how often; device, OS and
   app version; logs or screenshots; since when; severity; workaround.

## B2. Reproduce and find the root cause
1. Reproduce by following the code path, reading logs, or running the existing tests. If you cannot
   reproduce it, say so and ask for more data. **Never guess a fix.**
2. Root cause with evidence: `path:line`, the exact condition, why it happens. Recent history helps
   (read-only: `git log -p -- <file>`).
3. Blast radius: other callers of this code, and the same bug pattern elsewhere (search for it). Report other
   instances; include them only if the user agrees.
4. Check the brain's pitfalls for this stack: is this a known lesson that was missed? If so, note that the
   lesson was not applied (evidence for its counter). If the bug teaches something new, add an inbox row.

## B3. Fix plan
1. Think with `.agents/skills/aidlc-think/SKILL.md` at light depth (full depth if the fix is risky), then
   plan the smallest change that fixes the root cause, not just the symptom. Alternatives considered.
   Fill the plan's Thinking summary.
2. A regression test that fails before the fix and passes after it. If it cannot be automated: a manual
   check and the reason.
3. Files tables, verification, risk and rollback, task plan (Phase 1 regression test → Phase 2 fix →
   Phase 3 verification and review) with **How / Why / Check** under every task, and the before/after
   diagram of the code path in §7.
4. Gate. 🛑 **HARD STOP.** On approval: plan status `APPROVED <date-time>`; audit log; state
   `mode: construction`, `stage: C1 Baseline`, `code_gate: open`, `active_plan:` the bug-fix plan path.
   Then follow `.agents/skills/aidlc-construction/SKILL.md`.

## Rules
- Change behaviour only where the bug is. No refactoring "while you are there".
- Urgent production bug: the user may ask for a fast path. Keep the documents short, but the plan and the
  approval are still required.
