# Changelog

## 2.5.0 (2026-10-23)

- **README "Common tasks":** check versions, check health (doctor), update the kit, update a project (with
  `--migrate`, `--standard`, `--update-architecture`), remove AI-DLC from a project, uninstall, token use, the
  brain, pausing the plan gate, testing the kit.
- **`remove-project.sh`:** removes the AI-DLC pack from one project in one step: the AI-DLC blocks in
  `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` (your own text stays; a file left empty is deleted), the kit's own
  files in `.agents/`, the state file and the `.gitignore` lines. It keeps your architecture standard, your
  archived old files and `aidlc-docs/` (add `--all` to remove those too). `--dry-run` previews; everything is
  copied to `~/.aidlc-kit/backups/` first. Adding AI-DLC again later keeps your old work.
- The learning-hint hook works only where AI-DLC is switched on (the state file), like the other hooks
  (plan change PC-1), so a removed project gets no AI-DLC hints.
- Guide FAQ and the uninstall message point to the new command.
- Tests: **320 checks** (was 296).

## 2.4.0 (2026-10-23)

**Plans that show how they work.** Before, a plan listed files and tasks but not how each task is done.
- **Three Mermaid diagrams** in every implementation plan (section 6): the **plan flow** (tasks in order,
  dependencies, checks), the **file map** (new files green, changed files orange) and the **runtime flow**
  (a sequence diagram of the feature, with the error path). They replace the single data-flow diagram.
- **How / Why / Check under every task** (section 14): the approach, the reason and the proof.
- **Bug-fix plans:** a before/after diagram of the code path, and How / Why / Check under each task.
- `aidlc-feature` F4 and `aidlc-bugfix` B3 write them; `aidlc-construction` builds each task as its How says
  and runs its Check (a wrong How is a plan change that also updates the diagrams); the reviewer checks it.
- The four template diagrams were rendered with Mermaid 11.4.1: all parse and draw.
- Tests: **296 checks** (was 292): the templates' diagrams and How / Why / Check on every task.

## 2.3.1 (2026-10-22)

### Shared brain updates
- **Starter lessons update themselves.** Until now `install.sh` only added missing starter lessons, so an
  improved lesson never reached an existing install (S-006, improved in 2.2, was still the 2.1 text). Now
  the kit ships `lib/starter-lessons.sha256`, the checksums of every released version of every starter
  lesson. On re-install, a lesson that matches one of them (you never edited it) is updated to the kit's
  version, keeping your helpful/harmful counts and the later `last_verified` date; the old copy is backed up
  and its index line keeps your ✓/✗ counts. A lesson you edited is kept, and the installer lists it.
- **No ID clashes:** `brain.sh push` gives your shared lessons IDs from **S-101** up (S-001 to S-099 belong
  to the kit's starter lessons). The installer never adds a kit lesson whose ID one of your lessons already
  uses; it says so instead.
- README and guide: 27 starter lessons (the count was still 25).

### Tests
`tests/run-tests.sh`: **292 checks** (was 280): the checksum list covers every starter lesson; with a newer
kit an untouched old lesson is updated (counts kept, backup made), an edited lesson is kept, a taken ID is
not reused, a second run changes nothing; shared lessons start at S-101.

## 2.3.0 (2026-10-22)

**Token optimizer.** Measured first: in the Claude Code session that built this kit (240 model calls,
116 million tokens), 98.7% of all input tokens were the context read again on every call; the user's
prompts were a tiny part. So v2.3 saves tokens where they are spent, and turns every request into a clear
brief so the work is right the first time. It never drops a requirement, a check or a test to save tokens.

### New
- **Task brief** (`aidlc-prompt` P1, automatic, every agent; decision D1): before real work the agent shows
  a brief of at most 7 lines (goal · must · out of scope · context · done when · unknowns) and continues.
  It keeps the user's exact names, numbers and texts; plain questions get no brief. A work item saves it at
  the top of `questions.md`; the completion report checks its "Done when".
- **Prompt rewriter** (`aidlc-prompt` P3): `/aidlc prompt <text>` or "optimize prompt: <text>" returns a
  clear, compact prompt for any AI tool, with what changed, the gaps to fill and the size before and after.
- **Always-on token rule** `40-token-efficiency.md`: brief first, read smart, run quiet, write lean, small
  sessions, measure.
- **`tokens.sh`** (decision D2): real token use from Claude Code's own records for the latest session, a
  work item (from its folder and audit log), a time window or all sessions, including subagents. Each model
  call is counted once (Claude Code writes one call on several lines). Only numbers are read, never the
  conversation. `/aidlc tokens`; a "Tokens" column in the brain scorecard; more than twice the usual → a
  lesson.
- Starter lessons **S-026** (the context is the token cost) and **S-027** (quiet test output), with
  measured evidence (27 starter lessons).
- Token tips in `CLAUDE.md` (`/context`, `/compact`, `/clear`) and `GEMINI.md` (`/stats`, `/compress`); one
  token line in the global rules; guide section 12 "Token optimization".

### Changed
- **Slimmer always-on rules** (decision D3): the completion report, error recovery and knowledge retention
  moved from `10-quality-gates.md` into the construction skill (−1.9 KB on every call). With the new token
  rule the always-on text grew only 1.0 KB (22,283 → 23,314 bytes in a Flutter project).
- Verification and quick checks use `flutter test --reporter failures-only`: 826 bytes instead of 8,089 for
  the standard's 39 tests, same pass count.
- The thinking protocol starts from the brief; the routing table has "optimize a prompt".
- `init-project.sh` (plan change PC-1): no more false warning about the kit's own rule files on every
  re-run (since v2.1 it flagged `30-learning.md`).
- Guide section 6 lists all approval replies (the plain "yes" added in 2.2 was missing there).

### Tests
`tests/run-tests.sh`: **280 checks** (was 260): `tokens.sh` with sample records (one call on several lines
counted once, latest session with its subagent, all sessions, time window, work item, synthetic and broken
lines skipped, "not measured", no conversation text printed), the new rule and skill, the moved sections,
re-runs without false warnings.

### Upgrade
`bash install.sh` in this folder, then `bash ~/.aidlc-kit/init-project.sh <project>` in each project
(`--dry-run` first).

## 2.2.0 (2026-10-22)

A full check of the kit (every script, hook, rule, skill and template; probes in temporary folders; read-only
checks on a real project; today's official docs) found 16 problems. All are fixed and tested.

### Plan gate (Claude Code)
- **Only the Path column of the plan's Files tables counts.** Before, every backticked text in the tables
  did: a description such as "move the setup into `lib/core/`" or "`*.dart`" opened whole folders or every
  Dart file. Several paths in one Path cell, folder entries and globs still work; `<placeholder>` rows are
  ignored.
- The gate also needs the active plan's status line to say `APPROVED`. A plan that still says `DRAFT` is
  blocked even when the state file opened the gate.

### Setup and updates (`init-project.sh`)
- **An empty folder (a new app) is no longer guessed as "generic":** init stops and asks for
  `--standard flutter | android | ios | generic`. Re-runs keep the installed standard.
- `--standard <stack>` replaces the untouched generic placeholder. `.agents/.aidlc-version` records the
  standard that is really installed (`custom` for a project's own).
- **The architecture standard is one set** (the skill, its `reference/` files and `20-architecture.md`):
  installed, kept or replaced together. Init notes when the kit has a different version of your standard,
  and warns when the skill and its rules do not match (the mixed v2/v3 state a `--migrate` update created).
- **`--migrate` only archives old workflow rules** (decision D3). Switching a project's own standard to the
  kit's needs `--update-architecture` (your own files are archived, kit-made ones backed up).
- The shared-brain copy is a true mirror (lessons removed from the shared brain leave the project too).
- Files made by init are readable again (`-rw-r--r--`; older versions created them `-rw-------`).

### Flutter house standard v3 (decision D1)
- `SKILL.md` keeps the rules (sections 1–24): **45 KB instead of 148 KB**, so agents read 70% less before
  every plan. The complete code moved to `reference/core.md`, `feature-items.md`, `feature-sign-in.md` and
  `tests.md` (still Markdown, no `.dart` files). Same code, same result: analyzer clean, 39/39 tests on
  Riverpod 2 and 3.
- One-line `description:` in every standard's frontmatter (safe for every skill parser).

### Rules, brain and hooks
- **Approvals (decision D2):** a reply that is only "yes" or "ok" right after the gate card, or the user's
  own "Approve" choice in a question card, also approves. "ok, but …" is a change request. Updated in
  `00-aidlc-core.md`, the global rules and `/aidlc`.
- **Shared lessons stay generic:** `brain.sh push` refuses (and lint reports) a shared lesson with an email
  address, an IP address, a home-folder path or an `http://` address, because shared lessons go into every
  project. `aidlc-reflect` and `30-learning.md` say so too.
- Session start tells the agent when the project's pack is older than the kit (and how to update it), and
  lists the rule files that really exist.
- Auto-format runs only in AI-DLC projects (every repository with `AIDLC_ENFORCE=all-repos`).
- `AIDLC_LEARN_HINTS` is in the config file and in doctor. Re-install adds settings that are new in the kit
  and never changes your values. The learning hint knows more corrections ("I said …", "I told you", …).
- Doctor: clear "older / newer" version messages, the skill/rules version check, Antigravity's always-on
  budget.
- `aidlc-new-project` checks the installed standard at NP6; plan templates say "only the Path column counts"
  and ask "example rows replaced?".

### Checked against official docs (2026-10-22)
- **Antigravity:** `.agents/rules/*.md` with `trigger:` frontmatter, 24,000 bytes per rule file, 20,000 tokens
  for all always-on and global rules (above that the largest files become pointers), `.agents/skills/`,
  `~/.gemini/GEMINI.md`. Lesson S-006 now cites the official page (confidence high).
- **Claude Code** reads `AGENTS.md` by itself only when there is no `CLAUDE.md` and never reads `.agents/`,
  so the kit's `CLAUDE.md` imports remain the right approach.
- **Gemini CLI:** `GEMINI.md` with `@` imports. **Android Studio:** `GEMINI.md` wins over `AGENTS.md` in the
  same folder; it follows `@` imports.

### Tests
`tests/run-tests.sh`: **260 checks** (was 194), with tests for every fix above.
`tests/flutter-standard-check.sh` compiles `SKILL.md` + `reference/*.md`: 67 files, analyzer clean, 39/39
tests on flutter_riverpod 2.6.1 and 3.3.2.

### Upgrade
1. `bash install.sh` in this folder (your settings and shared brain are kept).
2. Each project: `bash ~/.aidlc-kit/init-project.sh <project> --dry-run`, then without `--dry-run`. Add
   `--migrate` for old workflow rules. The project's own standard is kept; switch with
   `--update-architecture`.

### Known limitations
- The plan gate trusts the state file and the plan, which the agent writes; it cannot prove that you
  approved in another tool. Shell commands that write files are forbidden by the rules, not blocked.
- Antigravity and Gemini have no hooks; they follow the always-on rules.

## 2.1.0 (2026-10-22)

The self-learning **brain**, a fixed **thinking process** and **research protocol**, the **Flutter house
standard v3** rebuilt from a production app, and a **3-step setup** that is tested end to end.

### Brain (learning from evidence)
Built on *Reflexion* (agents write down what feedback taught them and read it next time) and *ACE* (a
playbook of small, numbered lessons, updated one at a time, with helpful/harmful counts).
- `30-learning.md` (always on): recall before every plan, 7 capture triggers, reflection is part of "done",
  batch approval, safety and a size budget.
- Skills: `aidlc-reflect` (reflect, curate, share, promote, maintain), `aidlc-think` (understand → recall →
  research → options with a decision table → decide → pre-mortem → plan → self-review), `aidlc-research`
  (official sources first, version checks, reusable notes).
- Project brain in `aidlc-docs/brain/` (index, inbox, lessons, research, scorecard); shared brain in
  `~/.aidlc-kit/brain`, copied into every project as `.agents/brain/shared/`.
- **25 starter lessons**, each with evidence from building this kit, from analyzing a production Flutter app,
  and from compiling the standard.
- `brain.sh` (stats, lint, push, pull, sync); Claude Code learning-hint hook (`AIDLC_LEARN_HINTS`).
- Templates: lesson, research note, reflection, brain index, inbox, scorecard (23 in total). Plans gained a
  "Thinking summary" section.

### Flutter house standard v3
- Rebuilt from a read-only analysis of a production app (263 files). See `FLUTTER-STANDARD-V3-ANALYSIS.md`
  for the 20 findings and the decisions.
- API calling: `DioClient` singleton, `AuthInterceptor` (headers, 401, optional refresh), debug-only masked
  `LoggingInterceptor`, null-safe `DioExceptions`, `ApiRequest` (one try/catch for every call).
- `SessionManager` + secure storage, `AppFeedback` (no GetX), safe `extraAs<T>()`, login redirect.
- Complete code inside `SKILL.md` (no `.dart` files in the kit): core layer, reference features `items`
  (CRUD + pagination) and `sign_in`, and tests. `tests/flutter-standard-check.sh` extracts it into an app:
  **analyzer clean and 39/39 tests pass on flutter_riverpod 2.6.1 and 3.3.2.**

### Setup
- The same 3 steps as before (GUIDE.md §2): `install.sh` once per machine, `init-project.sh` once per
  project, then commit the pack. GUIDE.md now explains what each step changes.
- `install.sh` and `init-project.sh` print the next step, including the exact commit command.
- Install, re-install and uninstall keep your shared brain; re-install only adds new starter lessons.

### Tests
`tests/run-tests.sh`: 194 checks, including every `brain.sh` command, the learning hint, init creating the
brain, re-install keeping your lessons, uninstall saving the brain, and a privacy scan proving that no
reference-project name, IP address or key is in the kit. New section 10 runs the guide's 3 steps exactly
as written, in a new home folder with a real git repository: install, `--dry-run` (changes nothing), init,
commit (nothing left uncommitted), doctor, a second init (git stays clean, backups stay out of git), and
`--migrate` for a project with old `.agents` rules.

### Plan changes during the build
| # | Change | Why |
|---|---|---|
| PC-1 | No `.dart` files: all code is inside the Flutter `SKILL.md`; the check script extracts it | your instruction |
| PC-2 | No zip and no copy-paste layout: setup stays the 3 script steps from the guide, and a test runs them end to end | your instruction |
| PC-3 | 25 starter lessons instead of about 16 | compiling the standard taught 5 more |

## 2.0.0 (2026-10-21)

One kit for every project and every agent. The kit is no longer only for Flutter and Claude Code.
It merges kit v1 with the existing `agent-workflow.md` rule and `project-architecture` skill.

### Why v2: analysis of v1
| Gap in v1 | Fix in v2 |
|---|---|
| Flutter-only, Claude-only | `.agents/` pack read by every agent (Claude Code, Antigravity, Gemini, AGENTS.md readers); Flutter, Android, iOS and generic standards |
| "No code before approval" was only a sentence | Claude Code plan-gate hook blocks edits to files not listed in the approved plan; the same rule is always loaded for other agents |
| No path for new projects; no business or integration plan | `aidlc-new-project`: brief → business plan → requirements → integration plan → architecture → delivery plan |
| Questions asked once | A question round before every plan, a question bank, answers recorded in `questions.md` |
| No live status or completion report | 🔄 ✅ ⏳ ⛔ ⏭️ markers in every plan; completion report format |
| Installer overwrote files; no uninstall; no tests | Marked blocks, backups, idempotent init, uninstall, automated tests |

### Where your `agent-workflow.md` rules live now
| Your rule | New location |
|---|---|
| 1. Mandatory architecture analysis every session | `00-aidlc-core.md` §1 (session start) + `project-analysis` skill; results cached in `aidlc-docs/project-profile.md` and refreshed when older than 30 days |
| 2. Implementation plan before ANY code (11 sections) | `00-aidlc-core.md` §3 (hard stop) + `templates/implementation_plan.md` (same 11 sections, plus test plan, verification and plan changes) |
| 2.2 Task plan with phases | Template §14 (Data → Business logic → Presentation → Integration → Tests and verification) |
| 2.3 Wait for approval | `00-aidlc-core.md` §5 (approval words, gate card, audit log) + Claude Code plan-gate hook |
| 2.4 Live status tracking | `00-aidlc-core.md` §7 + `aidlc-construction` C2 |
| 3. Post-implementation review and gap analysis | `10-quality-gates.md` §3 + `aidlc-reviewer` agent (Claude Code) + `templates/review-report.md` |
| 4. Build verification before completion | `10-quality-gates.md` §4 (now also tests, iOS build on macOS, baseline comparison) |
| 5. Feature-first enforcement | `20-architecture.md` (Flutter) rules 1–4 |
| 6. Code style and pattern enforcement | `20-architecture.md` rules 5–17 + the architecture skill |
| 7. Communication and transparency | `00-aidlc-core.md` §8 + `10-quality-gates.md` §6 (completion report) |
| 8. Existing code preservation | `10-quality-gates.md` §1; auto-format only touches new files |
| 9. Error recovery protocol | `10-quality-gates.md` §7 (with a fallback when `dart-resolve-package-conflicts` is missing) |
| 10. Knowledge retention | `10-quality-gates.md` §8: feature registry in the project profile; proposed standard updates need approval |

**Problems fixed while merging:**
- **Antigravity may have ignored the old rule.** According to a March 2026 guide, `.agents/rules/*.md`
  files need a `trigger:` frontmatter, and `agent-workflow.md` had none. v2 rules have `trigger: always_on`,
  and `AGENTS.md` points to them as well.
- Plans had no fixed location, so they were lost between sessions and agents. Now they live in
  `aidlc-docs/work/<id>/` with a state file.
- Verification never ran tests, never built iOS, and old analyzer warnings would block every task. It now
  compares against a baseline.
- Rule 9 pointed to a skill that is not in the project. A fallback was added.
- Rule 10 referred to a feature list that did not exist. It is now the feature registry in the profile.

### Changes to the Flutter house standard
See section 23 of `standards/flutter/SKILL.md`. In short: Riverpod 3 `legacy.dart` import rule; snake_case
names for new files; optional repository/controller injection for tests; `.notifier` when a provider uses a
controller (avoids losing state on every `notifyListeners()`); tokens in `flutter_secure_storage`; UI-only
features may skip `model/` and `repository/`; `issuccess != true` means failure; testing standard;
dependency and security rules; feature registry; accessibility basics.

### New
- Skills: `project-analysis`, `aidlc-new-project`, `aidlc-feature` (with light mode), `aidlc-bugfix`,
  `aidlc-construction`, `aidlc-release`.
- 17 templates, including business plan, integration plan, question bank and bug-fix plan.
- Standards: Flutter (house), native Android (proposed v1), native iOS (proposed v1), generic (generated
  per project).
- Claude Code: `/aidlc` command, `aidlc-reviewer` agent, plan-gate / session-start / auto-format hooks,
  `doctor.sh`.
- Global plan-first rule for Claude Code (`~/.claude/CLAUDE.md`) and Antigravity / Gemini (`~/.gemini/GEMINI.md`).
- `init-project.sh` (`--standard`, `--migrate`, `--update-architecture`, `--dry-run`), `uninstall.sh`,
  `tests/run-tests.sh`.

### Verified
- `tests/run-tests.sh`: 130 automated checks covering the plan gate, session start, auto-format,
  install / re-install / uninstall in a fake home (jq and python3 paths), `init-project.sh` (Flutter,
  Android, iOS and generic detection, re-runs, `--migrate`, `--update-architecture`, `--dry-run`),
  broken-reference and size checks.
- The Flutter standard's code patterns and test examples were built into a sample app. With
  flutter_riverpod 2.6.1 and 3.3.2, `flutter analyze` reported no issues and all 8 tests passed. One test
  shows the `.notifier` fix: watching the controller itself loses the data state, `.notifier` keeps it.

### Known limitations
- Hard enforcement exists only in Claude Code (hooks). Antigravity and Gemini rely on the always-on rules.
- The Claude Code plan gate guards file-edit tools. Shell commands that write files are forbidden by the
  rules, not blocked by the hook.
- Antigravity rule details (frontmatter, size budget) come from third-party guides. The `.agents/skills`
  path is from the official docs.
- The Android and iOS standards are proposals: review them before your first native project.

## 1.0.0 (2026-10-21)
First version: Flutter-only AI-DLC skill for Claude Code (inception, construction, operations), a Flutter
reviewer agent and a `dart format` hook.
