---
name: aidlc-construction
description: Carry out an implementation, bug-fix or release plan that the user has approved. Covers live task status, the plan change procedure, tests, review and gap analysis, verification and the completion report. Use right after the user approves a plan, or to continue a work item that is in progress.
---
<!-- aidlc-kit:managed · replaced when the kit is updated -->

# Construction: carry out an approved plan

**Preconditions.** Check them first; if any fails, STOP and tell the user:
- the plan's status line says `APPROVED`, and `aidlc-docs/audit-log.md` has that approval;
- `aidlc-docs/aidlc-state.md` has `code_gate: open` and `active_plan:` = this plan.

| Stage | What | Output |
|---|---|---|
| C1 Baseline | Verification before any change | `test-report.md` §1 |
| C2 Build | Tasks phase by phase, live status | code + plan statuses |
| C3 Tests | Tests from the test plan | test files |
| C4 Review | Review and gap analysis | `review-report.md` |
| C5 Verify | Analyzer, tests, build vs baseline (🛑 hard stop) | `test-report.md` §3–4 |
| C6 Complete | Completion report, knowledge retention, close the gate | user confirms |

Update `stage:` in the state file at every stage.

## C1. Baseline
Run the verification commands from the profile before changing anything and record the results
(`10-quality-gates.md` §2). If the project does not build now, tell the user before you start. Then run
`bash ~/.aidlc-kit/verify-plan.sh <plan> --baseline`: it records the files that already have uncommitted
changes (`git-baseline.txt` next to the plan), so C5 can tell them from yours.

## C2. Build, phase by phase
For each task of the plan's task plan, in order:
1. Mark it `🔄 **[IN PROGRESS]**` in the plan file. Say in chat: "🔄 Now: <task>".
2. Do it as the task's **How** says, **only in files listed in the plan**, following the architecture skill
   exactly (copy the reference implementation's patterns if the profile names one), and run its **Check**.
   **Logic is built test first** (models, repositories, controllers or view models, notifiers, utilities):
   write the task's test from its Check, run it and see it fail for the expected reason, then write the code
   until it passes. Screens and wiring: build them, then add their test right away.
   If the How turns out wrong, that is a plan change: update the How and the diagrams after approval.
3. Mark it `✅ **[COMPLETED]**` as soon as it is done. Keep the project compiling.
4. At the end of each phase: run the quick check (e.g. `flutter analyze` and
   `flutter test --reporter failures-only`) and report to the user: phase done, files touched, issues found.
5. **Capture** as soon as it happens (`30-learning.md` §2): a correction from the user, a failed check with
   its cause, a surprise, or a pattern that worked → one row in `aidlc-docs/brain/inbox.md`, with evidence.

### Plan change procedure (you need something the plan does not list)
1. STOP. Do not touch the file.
2. Add a row to the plan's "Plan changes" table: file, change, reason, status `proposed`.
3. Tell the user exactly what and why, and ask: "Approve plan change PC-<n>?"
4. Approved → set the row to `approved`, add the file to the Files tables (between the `aidlc:files`
   markers), log `PLAN-CHANGE` in the audit log, continue. Rejected → stay within the plan, or stop and
   discuss.

## C3. Remaining tests
Write the rest of the plan's test plan (widget, integration and end-to-end tests that need the whole slice),
following the architecture skill's testing section. Every acceptance criterion has at least one test and every
NFR its named check. Run them all.

## C4. Review and gap analysis
Do the review in `10-quality-gates.md` §3 on every created and modified file. A separate reviewer agent is
better than reviewing your own work, if your tool has one. Fix every gap (a fix that needs a new file →
plan change procedure). Write `review-report.md`.

## C5. Verification: 🛑 HARD STOP
Follow `10-quality-gates.md` §4. Compare with the baseline. Fix and re-run until clean. Run the plan's
**end-to-end check**. Record the real results in `test-report.md` §3, quoting the summary lines and the
end-to-end evidence (test output or screenshot paths). Run `bash ~/.aidlc-kit/verify-plan.sh <plan> --done`:
every planned file exists, no file outside the plan changed, every numbered task is ✅, and the test and review
reports are complete. Files that were already changed before C1 and
are untouched since are only warnings: never revert them; name them in the report. Never continue to C6 with
failing verification.

## Error recovery (C2–C5)
1. Build/test error → find the root cause, fix it, record what went wrong in `test-report.md`.
2. The fix needs a file or change outside the plan → plan change procedure (stop, propose, wait).
3. Pattern conflict with the architecture standard → stop and ask the user.
4. The standard looks outdated or wrong → tell the user and propose an update; never change it on your own.
5. Dependency conflict → if a `dart-resolve-package-conflicts` (or similar) skill exists, use it. Otherwise
   use the stack's tools (Flutter: `flutter pub deps`, `dart pub outdated`), find the smallest constraint
   change and propose it as a plan change.
6. Never "fix" a failure by deleting tests, weakening assertions, disabling lints or adding ignore comments
   without the user's approval.

## C6. Complete and close
1. **Measure** (Claude Code): `bash ~/.aidlc-kit/tokens.sh "<project root>" --work-item <id> --line`.
   Other tools: "not measured".
2. **Reflect** with `.agents/skills/aidlc-reflect/SKILL.md` (R1–R6): `reflection.md`, lessons from the
   evidence, helpful/harmful counts, the scorecard row with the tokens.
3. **Completion report** in chat, saved at the end of `test-report.md`:
   ```
   ✅ <work item> complete
   Files created:  <list>
   Files modified: <list>
   Routes / screens added: <list or none>
   Tests: <n> added · <passed>/<total> passing · analyzer: <result> · build: <result>
   Done when (from the brief): <each item ✅ or ❌>
   Tokens: <the tokens.sh line, or "not measured">
   Known limitations / follow-ups: <list or none>
   Suggested commit message: <type(scope): summary>
   🧠 Proposed lessons: <list, or "none"> (reply: approve lessons · approve L-1 L-2, reject L-3 · edit L-4: …)
   Scorecard: plan changes <n> · verified first time <✅/❌> · corrections <n> · trend <…>
   ```
   Do not commit or push unless the user asks. When the user answers about the lessons, apply it
   (aidlc-reflect R7–R8).
4. **Knowledge retention:** update the feature registry in `aidlc-docs/project-profile.md` (features,
   screens, routes, endpoints). A new pattern or convention → propose an update to
   `.agents/skills/project-architecture/SKILL.md` (and `20-architecture.md`); apply it only after the user
   approves.
5. Plan status: `COMPLETED <date-time>`. State: the work item ✅ in the "Work items" table,
   `code_gate: closed`, `active_plan: none`, `mode: idle`, next action = the next work item or "waiting for
   the user". Audit log: `COMPLETED`.
6. Ask the user to confirm, and whether to commit (suggest the message). Suggest the next work item, in a
   new session (`40-token-efficiency.md` §5).

## Release plans
For a release plan (from `aidlc-release`): C3 is the smoke-test checklist, C5 is the release build, and
publishing is always done by the user, or by you only after the user approves that exact action.

## Resuming
Re-ground first (`50-anti-hallucination.md` §4): read the brief, the plan and the state file again. Continue at
the first task that is not ✅. Run the quick check first. If the code on disk does not match the statuses,
tell the user before you continue.

## Rules
- Never mark a task ✅ that is not done. Never mark a work item done while verification fails.
- Never change files outside the plan, not even "small" ones such as formatting or imports elsewhere.
