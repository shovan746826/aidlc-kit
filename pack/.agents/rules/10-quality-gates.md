---
trigger: always_on
description: AI-DLC quality gates. Code preservation, baseline, review and gap analysis, verification before completion, definition of done. The completion report, error recovery and knowledge retention are in the construction skill.
---
<!-- aidlc-kit:managed · replaced when the kit is updated · project rules go in 20-architecture.md -->

# AI-DLC Quality Gates (mandatory)

## 1. Preserve existing code
1. NEVER delete or modify code unrelated to the current task.
2. Preserve all existing comments and docstrings.
3. Change only what is necessary. Do not reformat, reorder or restructure unrelated code, and never run a
   formatter over a whole existing file.
4. When adding to a file (e.g. a new route), follow its existing formatting and comment style.
5. Ideas for unrelated improvements go into the completion report under "Follow-ups", not into the code.

## 2. Baseline (before the first change of a work item)
Run the verification commands from `aidlc-docs/project-profile.md` (section "Verification commands") and
record the results in the work item's `test-report.md` → "Baseline". Pre-existing problems are not yours to
fix (unless the plan says so), but you must not add new ones.

## 3. Review and gap analysis (after all tasks are done)
Review every created and modified file:
1. **Architecture**: right folder; follows `.agents/skills/project-architecture/SKILL.md` and `20-architecture.md`.
2. **Naming**: files, classes, variables, providers/view models.
3. **Data flow**: layers connect in the standard order (e.g. Screen → Provider → Controller → Repository → Model).
4. **Imports**: the standard's import style.
5. **Plan conformance**: every planned file exists; no unplanned file changed; every task ✅.
6. **Requirements**: every acceptance criterion is implemented and has a test.
7. **Gaps**: error handling? loading / empty / error states? null-safety? route registered? API URL
   registered? permissions / platform config? analytics events? localized strings? accessibility labels?
8. **Security**: no secrets or tokens in code or logs; input validated; sensitive data stored securely.
9. **Performance**: no heavy work in build/render paths; long lists are lazy; controllers and streams disposed.
Fix every gap, then write the work item's `review-report.md` (template in `.agents/templates/`).
If your tool offers a separate reviewer agent, use it: an independent review finds more.

## 4. Verification before completion: HARD STOP
1. Run every verification command from the profile: analyzer/lint, tests, build.
   Flutter: `flutter analyze`, `flutter test --reporter failures-only` (it keeps the pass count),
   `flutter build apk --debug`, and on macOS when the app targets iOS: `flutter build ios --debug --no-codesign`.
2. Compare with the baseline. Pass = zero errors, no NEW warnings or lint issues, all tests pass (only tests
   that already failed in the baseline may still fail), and the build succeeds.
3. On failure: find the root cause, fix it, run again, until clean.
4. Record the real results in `test-report.md`.
🛑 Do NOT report a work item as complete until verification passes. If a command cannot run (no SDK, no
device), say so clearly and ask the user how to proceed.

## 5. Definition of done
- [ ] every task is ✅ (or ⏭️ with the user's approval)
- [ ] review and gap analysis done; every gap fixed
- [ ] verification passed and recorded
- [ ] completion report given (`aidlc-construction` C6)
- [ ] reflection done and lessons proposed (`aidlc-construction` C6, `30-learning.md` §3)
- [ ] state file: work item completed, `code_gate: closed`, `active_plan: none`

## 6. While building
The completion report, error recovery and knowledge retention are in
`.agents/skills/aidlc-construction/SKILL.md` (C6 and "Error recovery"). Always: never "fix" a failure by
deleting tests, weakening assertions, disabling lints or adding ignore comments without the user's approval.
