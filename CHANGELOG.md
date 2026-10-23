# Changelog

## 3.0.0 (2026-10-23)

**Complex projects: every stage is proven, and planning matches the best public methods.** Checked against
AWS AI-DLC workflows (a gate and an audit trail at every stage; per-unit functional and NFR design; contract
design between units), GitHub Spec Kit (read-only cross-artifact analysis, no open clarification markers,
test-first), Kiro specs (requirements → design → tasks; bug specs with unchanged behaviour) and Anthropic's
Claude Code best practices (a check Claude can run, evidence instead of claims, an end-to-end verification
step, a fresh session to implement, a reviewer that flags only real gaps).
- **Stages are proven (S1):** `verify-plan.sh` (full check of a draft plan) fails when an earlier stage was
  skipped or not approved: a full-depth feature needs `requirements.md` (F2) and `integration-plan.md` (F3)
  approved (their Status line, or an APPROVED row in the audit log); a light plan needs its stories with
  acceptance criteria in §1; a project scaffold needs the project requirements, architecture and delivery plan
  approved; a bug fix needs `path:line` evidence for its root cause. Core rule §5: after an approval the
  document's Status becomes APPROVED and the audit row names the stage.
- **Traceability (S2):** every user story needs a test in §12 and a file or task; every NFR a named check
  (§10, §12 or §13); business rules and integrations not named in the plan are warnings.
- **No open blocking question at a gate (S3):** real `[OPEN-BLOCKING]` items in the plan, `questions.md`,
  requirements or integration plan fail the check (comments, placeholders and checklist lines don't count).
- **Construction evidence at `--done` (S1):** every numbered task done (or skipped with a reason); the test
  report has a baseline row and a verification run; the review report has a PASS verdict and no open Blocking
  finding; a missing `git-baseline.txt` is a warning.
- **Doctor process audit:** finished work items without their test, review or reflection report are listed.
- **Design for complex features (S4):** `integration-plan.md` §11 at full depth: data model with migrations,
  states and flows, how each NFR is met and verified, compatibility and rollout.
- **Test-first for logic (S5, decision D1):** models, repositories, controllers, notifiers and utilities get
  their failing test before the code; screens and wiring are tested right after; C3 covers the remaining
  widget, integration and end-to-end tests.
- **End-to-end check with evidence (S6):** every plan names it (§13); C5 records its output.
- **Several units (S7):** shared contracts in the delivery plan; a milestone check (its user journeys end to
  end) before the next milestone.
- **Spikes (S8):** a time-boxed, approved experiment in `spikes/<slug>/`, outside the app, for questions no
  document can settle; the answer becomes a research note.
- **Bug fixes (S9):** the plan states what must not change, and tests keep it covered.
- **Reviewer and planning (S10):** the reviewer reports only gaps in correctness, requirements, the standard,
  security or performance; every new package, layer or abstraction needs a one-line reason; large plans are
  built in a new session.
- **Release:** rollout gates for staged releases; a deploy path for web and backend projects.
- Decision D2: real gaps block (✗); business rules, integrations and the git baseline are warnings.
- Tests: **432 checks** (was 394).

## 2.8.0 (2026-10-23)

**Full review: gaps fixed, faster plan checks, fewer tokens.** Measured first: the hooks take 12–39 ms per call
(no change needed); agents read the 45,149-byte Flutter standard before every plan; the plan check took 15.2 s
for 10 classes on a 3,000-file app.
- **Faster plan check (G1):** one search for every class in the plan (`git grep`, or `grep -r` outside git)
  instead of one per class: 15.2 s → 0.38 s on a 3,000-file git repository (2.23 s without git).
- **Your own work is safe (G2):** construction C1 runs `verify-plan.sh <plan> --baseline`, which records the
  files that already had uncommitted changes, with content hashes. `--done` reports them as warnings while they
  are untouched and never asks to revert them; a file that changed again is still a problem.
- **Monorepos (plan change PC-1):** `--done` and `--baseline` read only the project folder, with paths relative
  to it, when the app is a folder inside a bigger repository.
- **The kit's own files are protected (G3):** the plan gate and `--done` treat the rules and skills marked
  `aidlc-kit:managed` and the shared-brain copy like code: an approved plan must list them. The architecture
  skill, `20-architecture.md` and your own rule files stay free, so the architecture choice (A5) works as before.
- **Lean Flutter standard (D1):** `SKILL.md` keeps sections 1–6 and 17–19 in full and, for every other section,
  one line naming its topic file and when to read it. The full text moved word for word to
  `reference/patterns.md`, `routing-api.md`, `app-shell.md`, `build-test-security.md` and `adopting-v3.md`:
  45,149 → 23,056 bytes read before every plan; the compile check still passes 39 tests on Riverpod 2 and 3.
  New projects get it; existing ones with `--update-architecture`.
- **Light plans (D2):** light work (about 5 files or fewer, no new API, package or data change) gets one
  document (the plan holds the stories and acceptance criteria), one approval and one diagram. Full features
  keep everything.
- **Token rule:** read several files in one step; open the standard's topic files only when needed; fill
  templates without their instruction comments; a section with nothing to say is one line.
- **Size budgets:** the project profile ≤ about 10 KB (it is read in every session); a standard written from
  your code ≤ about 20 KB, with long topics in `reference/`.
- Fixed a stale reference in the profile template ("10-quality-gates §8" → aidlc-construction C6); a new test
  checks every "rule §N" and skill-step reference.
- Tests: **394 checks** (was 365).

## 2.7.1 (2026-10-23)

- `verify-plan.sh`: a plan without the `aidlc:files` markers (or with only one of them) is now a problem (✗),
  not a warning. The plan gate reads only the files between the markers, so before this fix such a plan skipped
  every file check and the Claude Code hook stayed silent. A plan in progress whose file table is still empty
  stays a warning.
- Tests: **365 checks** (was 359).

## 2.7.0 (2026-10-23)

**Anti-hallucination protocol.** Built on Anthropic's guidance (allow "I don't know", ground in direct quotes,
cite every claim), Chain-of-Verification (Meta AI, ACL Findings 2024) and the package-hallucination study by
Spracklen et al. 2024 (19.7% of packages suggested by 16 code models did not exist; "slopsquatting").
- **Always-on rule `50-anti-hallucination.md`** (decision D1): evidence for every claim, "unknown" or a
  question instead of a guess, verify code, packages and files before use, re-ground in long tasks, report
  only real output, learn from every hallucination caught.
- **Skill `aidlc-anti-hallucination`** for large or complex work: ground first, facts table, verification
  questions answered again from the sources, mechanical check, consistency, honest report.
- **`verify-plan.sh`**: catches invented files to modify (with "did you mean"), files to create that already
  exist, invented classes and members, missing lessons and research notes, "verified" facts without evidence
  and unknown facts; `--done` checks the build against the plan. Errors block the gate (decision D2); what the
  code and docs can't settle becomes a question to the user.
- **Claude Code hook `plan-check.sh`** (decision D3, the 5th hook): runs the check whenever the agent writes a
  plan file and tells it what does not exist.
- Plan templates: a **Facts and assumptions** table and a "Verification" line in the Thinking summary; the
  feature, bug-fix, construction and thinking skills, the reviewer (check 10) and `/aidlc verify` use them.
- Starter lesson **S-028**: confirm a new package's exact name on the official registry.
- Plan change PC-1: the shared-brain index budget is 8 KB (was 6 KB; the 28 starter lessons used 5.8 KB).
- Plan change PC-2: updating the kit changes the old "Keep under 6 KB." line in your shared index's header to
  8 KB (old index backed up; a header line you edited is kept).
- Tests: **359 checks** (was 332).

## 2.6.0 (2026-10-23)

**Your architecture or AI-DLC's: the analysis now asks.**
- `project-analysis` stage **A5 "Architecture choice"**, after the analysis gate, the first time a project is
  analyzed and later only on request (`/aidlc architecture`, "keep my architecture", "use the AI-DLC
  architecture") or when the code no longer follows the chosen standard.
- It compares, with `path:line` evidence: architecture and folders, API calling, state management, routing,
  storage and session, error handling, dependency injection, design system and testing, against the AI-DLC
  standard for the stack, and asks: **A) your architecture** · **B) the AI-DLC standard** · **C) a mix** per
  area, each with a ★ and its reason (state management, folders and DI: keep yours unless they cause real
  problems; areas with security or crash risks: take AI-DLC's).
- After the approval it changes only `.agents/`: A writes or completes your standard and makes
  `20-architecture.md` agree with it (both marked `generated`, so updates keep them, and the kit's reference
  code is archived); B runs `--update-architecture`; C writes one standard whose sections name their source.
  Always an ADR and profile section 15.
- New template `architecture-standard.md` (24 templates), the same 22 sections as the kit standards, each
  with its source. Plans take their phases from the chosen standard's new-feature checklist.
- Tests: **332 checks** (was 320), including init keeping an A5 standard with no mismatch warning.

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
