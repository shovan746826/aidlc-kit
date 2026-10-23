# AI-DLC Kit: Guide

1. [What AI-DLC is](#1-what-ai-dlc-is)
2. [Quick start](#2-quick-start)
3. [How each agent loads the kit](#3-how-each-agent-loads-the-kit)
4. [The workflows](#4-the-workflows)
5. [Answering questions](#5-answering-questions)
6. [Approval gates](#6-approval-gates)
7. [The plan gate in Claude Code](#7-the-plan-gate-in-claude-code)
8. [Files and folders](#8-files-and-folders)
9. [Architecture standards](#9-architecture-standards)
10. [The brain: how the agent learns](#10-the-brain-how-the-agent-learns)
11. [Thinking and research](#11-thinking-and-research)
12. [Token optimization](#12-token-optimization)
13. [Anti-hallucination protocol](#13-anti-hallucination-protocol)
14. [Worked example](#14-worked-example-a-new-feature)
15. [Working in a team](#15-working-in-a-team)
16. [Updating the kit](#16-updating-the-kit)
17. [Troubleshooting and FAQ](#17-troubleshooting-and-faq)

---

## 1. What AI-DLC is

**AI-DLC (AI-Driven Development Lifecycle)** turns the usual roles around: the **AI does the work** (analysis,
questions, plans, code, tests, reviews), and **you make the decisions** at fixed approval points.

| Phase | What happens | Written to |
|---|---|---|
| **Inception** | Analyze, ask, plan: project brief, business plan, requirements, integration plan, architecture, delivery plan (new project), or requirements, integration plan, implementation plan (feature) | `aidlc-docs/project/`, `aidlc-docs/work/<id>/` |
| **Construction** | Build the approved plan phase by phase with live status, test, review, verify | code + `test-report.md`, `review-report.md` |
| **Operations** | Release: version, changelog, builds, rollout, monitoring | `aidlc-docs/releases/<version>/` |

Three ideas make it reliable:
1. **Plan first.** No file changes without a plan you approved. Claude Code enforces it with a hook.
2. **Ask, don't guess.** Every plan starts with questions. Unknowns are marked, never invented.
3. **Everything is written down.** State, decisions, approvals and reports live in `aidlc-docs/`, so any
   agent (or teammate) can continue the work.

## 2. Quick start

Three steps. The scripts back up every file they change, and you can run them again at any time to update.

```bash
# 1. Once per machine
cd aidlc-kit && bash install.sh

# 2. Once per project (use --dry-run first to preview; --migrate if you have old .agents rules)
bash ~/.aidlc-kit/init-project.sh ~/StudioProjects/MyApp

# 3. Commit the pack
cd ~/StudioProjects/MyApp && git add AGENTS.md CLAUDE.md GEMINI.md .agents aidlc-docs .gitignore && git commit -m "chore: add AI-DLC"
```

| Step | What it changes |
|---|---|
| 1. `install.sh` | `~/.aidlc-kit/`: the scripts, hooks, settings (`config`) and the shared brain. **Claude Code:** the `/aidlc` command, the `aidlc-reviewer` agent, 5 hooks in `~/.claude/settings.json` (your other settings are kept) and the plan-first rule in `~/.claude/CLAUDE.md`. **Antigravity / Gemini:** the plan-first rule in `~/.gemini/GEMINI.md`. Skip parts with `--no-claude`, `--no-gemini` or `--no-hooks`. |
| 2. `init-project.sh` | In the project: `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` (text you wrote is kept), `.agents/` (rules, skills, templates, the architecture standard, a copy of the shared brain) and `aidlc-docs/` (state, audit log, project brain). The standard is detected (Flutter, Android, iOS or other); choose one with `--standard`. In a git project it adds `.agents/.backup/` to `.gitignore`. |
| 3. Commit | These paths hold everything step 2 added, so your team and every agent get the same workflow. |

**Old rules** such as `agent-workflow.md`: their content is merged into the kit, and `--migrate` moves them
to `.agents/archive/`. The project's **own architecture standard** (for example an old `project-architecture`
skill) is kept. To switch to the kit's standard (e.g. Flutter v3), add `--update-architecture`: your files
are archived first.

**A new app in an empty folder:** there is nothing to detect yet, so name the standard (otherwise step 2
stops and tells you to):
```bash
mkdir -p ~/StudioProjects/NewApp && cd ~/StudioProjects/NewApp && git init
bash ~/.aidlc-kit/init-project.sh . --standard flutter
```
In your agent, start with "new project: <your idea>" (Claude Code: `/aidlc new-project <idea>`) instead of
the analysis below.

Then open the project in your agent:
- **Claude Code:** start a **new** session, type `/aidlc analyze`.
- **Antigravity / Gemini:** say "analyze this project".

Approve the analysis, then ask for anything: "new feature: budget alerts", "fix bug: login crashes on
Android 14", "prepare release 1.3.0".

## 3. How each agent loads the kit

| Agent | Loads automatically | Notes |
|---|---|---|
| **Claude Code** | `CLAUDE.md` → imports `AGENTS.md`, the 6 rule files and both brain indexes | Claude Code reads `AGENTS.md` by itself only when there is no `CLAUDE.md`, and never reads `.agents/`: the imports load everything. Skills in `.agents/skills/` are read when the rules route to them; `/aidlc` routes for you. Hooks: plan gate, plan check, session context, auto-format, learning hint. |
| **Antigravity** | `.agents/rules/*.md` (with `trigger: always_on`), `.agents/skills/`, `AGENTS.md`, `GEMINI.md` | Use Planning mode and let the agent ask for your review before changes. Limits (official docs): 24,000 bytes per rule file; always-on and global rules share 20,000 tokens (`doctor` checks both). |
| **Gemini CLI** | `GEMINI.md` → imports `AGENTS.md` and the rule files; skills in `.agents/skills/` | |
| **Gemini in Android Studio** | `GEMINI.md` (it wins over `AGENTS.md` in the same folder) → `@` imports `AGENTS.md`, the rule files and both brain indexes | `AGENTS.md` and imports need Android Studio Narwhal 4 Feature Drop or newer. |
| **Other agents** (Codex, Cursor, Copilot, …) | `AGENTS.md` | Same pointers. |

Global rule for **every** project, even without the pack: `~/.claude/CLAUDE.md` (Claude Code) and
`~/.gemini/GEMINI.md` (Antigravity / Gemini). They say: plan first, ask before planning, suggest the pack.

## 4. The workflows

The always-on rule `00-aidlc-core.md` routes each request:

| You say | Route | Skill |
|---|---|---|
| "create a new app …" | New project | `aidlc-new-project` |
| "add / build / new screen …" | Feature | `aidlc-feature` |
| "change / improve / refactor …" | Change (light mode) | `aidlc-feature` |
| "bug / crash / not working …" | Bug fix | `aidlc-bugfix` |
| "release / publish / build apk …" | Release | `aidlc-release` |
| "approve" (after a plan) | Construction | `aidlc-construction` |
| "status" / "continue" | Resume | state file |
| a question | Answer only | none |

### 4.1 New project (`aidlc-new-project`)
| Stage | You answer | You approve |
|---|---|---|
| NP1 Set up | none | none |
| NP2 Discovery | Round 1: idea, problem, users, competitors, success, constraints | `01-project-brief.md` |
| NP3 Business plan | Round 2: model, pricing, costs, channels, KPIs, legal | `02-business-plan.md` |
| NP4 Requirements | Round 3: MVP scope, platforms, quality | `03-requirements.md` (stories with Given/When/Then) |
| NP5 Integration plan | Round 4: backend, auth, payments, push, analytics, environments | `04-integration-plan.md` (contracts, sequence diagrams, environments) |
| NP6 Architecture | Round 5: storage, offline, navigation, design values | `05-architecture.md` (+ architecture skill updates) |
| NP7 Delivery plan | Round 6 only if needed | `06-delivery-plan.md` (units, shared contracts, milestones, traceability) |
| NP8 Scaffold plan | none | `work/001-setup-project-scaffold/implementation_plan.md` → construction |

After the scaffold, each unit of the delivery plan becomes a feature work item. When the last unit of a milestone
is done, the milestone's user journeys are run end to end before the next milestone starts.

### 4.2 Feature or change (`aidlc-feature`)
F1 questions → F2 `requirements.md` → F3 `integration-plan.md` (at full depth with a **design**: data model,
states and flows, how each NFR is met and verified, compatibility and rollout) → F4 `implementation_plan.md`
(🛑 approval) → construction. **Light mode** (changes and small features of about 5 files or fewer, with no new API,
package or data change) skips F2 and F3: one **light plan** holds the stories with acceptance criteria, the
integration points and one diagram, and it is the only approval. Questions and the plan approval are never
skipped.

**Every plan shows how it works, before you approve it:**
- **Three diagrams** (a light plan: one; Mermaid, drawn by GitHub, VS Code, Android Studio and Antigravity): the **plan flow**
  (tasks in order, what needs what, the checks), the **file map** (new files green, changed files orange,
  how they connect) and the **runtime flow** (what happens when the user uses the feature, with the error
  path).
- **How / Why / Check under every task:** the approach (file, change, key code shape), the reason (a
  requirement, a standard section or a lesson) and the proof that it works. During construction the agent
  builds each task as its How says and runs its Check; the reviewer checks both.
- **Traceability:** every user story has a file or task and a test, every NFR a named check, and an
  **end-to-end check** proves the flow the user sees. `verify-plan.sh` stops the plan at the gate otherwise.
- Bug-fix plans: a **before/after** diagram of the code path and How / Why / Check under each task.

### 4.3 Bug fix (`aidlc-bugfix`)
B1 triage questions → B2 reproduce and root cause (`path:line` evidence) → B3 `bugfix_plan.md` with what must
not change and a regression test that fails before the fix (🛑 approval) → construction.

### 4.4 Construction (`aidlc-construction`)
C1 baseline (verification before changes) → C2 build phase by phase, **logic test first** (write the test,
see it fail, then the code), with live status (`⏳ [PENDING]` → `🔄 [IN PROGRESS]` → `✅ [COMPLETED]`),
reporting after each phase → C3 remaining tests (widget, integration, end-to-end) → C4 review and gap analysis
→ C5 verification and the end-to-end check with its evidence (🛑 must pass; `verify-plan.sh --done` proves every
task, report and approval) → C6 completion report, feature registry, gate closed.

**Plan changes:** if the agent needs a file the plan does not list, it stops, adds a "proposed" row to the
plan's "Plan changes" table, explains it, and waits for your approval.

### 4.5 Release (`aidlc-release`)
R1 questions → R2 `release-plan.md` (🛑 approval) → R3 version, changelog, builds → R4 hand-over: **you
publish** (the agent never uploads, tags or pushes by itself) → R5 monitoring and lessons learned. A staged
rollout widens only while crash-free users stay at the target; web and backend projects deploy instead of
publishing.

### 4.6 Status, continue, switching
- "status": progress, stage, code gate, last approval, next action.
- "continue": resumes at the recorded stage (in any agent).
- Only one work item is active at a time. To switch, the agent parks the current one (closes the gate) and
  lists it under "Parked".

### 4.7 Analysis and the architecture choice (`project-analysis`)
"Analyze this project" (`/aidlc analyze`) maps the project and writes `aidlc-docs/project-profile.md` (A1–A4,
gate). The first time, it then asks **which architecture AI-DLC should follow** (A5):
1. It compares, with `path:line` evidence: architecture and folders, API calling, state management,
   routing, storage and session, error handling, dependency injection, design system and testing, each
   against the AI-DLC standard for your stack, with the risks it found.
2. It asks: **A) your architecture** (it writes your standard from your code) · **B) the AI-DLC standard**
   (new code follows it; old code changes only through planned work items) · **C) a mix** (one question per
   area, e.g. keep your state management, take AI-DLC's API calling). Each option comes with a ★ and the
   reason.
3. After your approval it changes only `.agents/` (never your code): your architecture skill and
   `20-architecture.md` (marked as the project's own, so updates keep them), or `--update-architecture` for
   B. It writes an ADR in `aidlc-docs/project/decisions/` and profile section 15.

Every later plan follows the chosen standard: its new-feature checklist gives the plan's phases and files. To
choose again later: `/aidlc architecture`, or "keep my architecture" / "use the AI-DLC architecture".

## 5. Answering questions

Questions come in rounds (at most 10), each with options and a ★ recommendation:
```
Q3. Where should offline data be stored?  (why it matters: decides the sync design)
    A) Hive — already used in this project ★ recommended
    B) sqflite / drift — only needed for complex queries
    C) Other: ___
```
Answer however you like:
- `1A 2C 3B`
- `1A, 2: use the same API as the profile screen, 3B`
- `use your recommendations`
- `use your recommendations except 4: B`

All answers are saved in `questions.md`. Unanswered questions that change what gets built block the next
approval; small ones become visible `[ASSUMPTION]`s.

## 6. Approval gates

Every document ends with a card like this:
```
━━━ AI-DLC GATE · 004-feature-budget-alerts · F4 Implementation plan ━━━
📄 Document: aidlc-docs/work/004-feature-budget-alerts/implementation_plan.md
✔ Produced: 9 files to create, 3 to modify, 14 tasks in 5 phases, 11 tests
⚖ Decisions: alerts checked locally on each expense save (no new API), reason: works offline
❓ Open items: [ASSUMPTION] alert threshold default 80%
➡ Next: construction phase 1 (data layer)
Reply: approve · change: <what> · stop
```
| Reply | Effect |
|---|---|
| `approve` · `approved` · `proceed` · `go ahead` · `do it` · `lgtm`, a plain `yes` / `ok` right after the card, or clicking **Approve** in a question card | Approved: the document's Status becomes APPROVED and the audit log gets a row with the stage; next stage |
| `change: …` (also "ok, but …") | The document is revised and shown again |
| `stop` | The work item is paused (gate closed) |
| anything else | **Not** an approval: the agent waits |

## 7. The plan gate in Claude Code

The `plan-gate.sh` hook runs before every file edit by Claude:

| Situation | Result |
|---|---|
| File in `aidlc-docs/`, `.agents/` (the architecture skill, `20-architecture.md`, your own rule files), or `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` | allowed (planning files) |
| The kit's own files: rules and skills marked `aidlc-kit:managed`, the shared-brain copy in `.agents/brain/shared/` | like code: only with an approved plan that lists them (they are replaced on every kit update) |
| `code_gate: closed` in `aidlc-state.md` | **blocked**: "plan first" |
| Gate open, plan status `APPROVED`, file listed in the Path column of the plan's Files tables | allowed |
| Gate open, but the plan still says `DRAFT` (or has no status line) | **blocked**: "not approved" |
| Gate open, file not listed | **blocked**: "use the plan change procedure" |
| Project without the pack | allowed (unless `AIDLC_ENFORCE=all-repos`) |

Plan entries can be exact paths (`lib/a.dart`), folders ending in `/` (`assets/images/`) or globs
(`lib/features/budget/**`). Prefer exact paths. Only the **Path** column counts (one or more paths in
backticks per row): paths mentioned in other columns never widen the plan, and rows with `<placeholders>`
are template examples.

Settings live in `~/.aidlc-kit/config`, or as environment variables for one session
(e.g. `AIDLC_ENFORCE=off claude`):
- `AIDLC_ENFORCE`: `project` (default) · `all-repos` · `off`
- `AIDLC_GATE_SCOPE`: `plan-files` (default) · `any`
- `AIDLC_AUTOFORMAT`: `new-files` (default) · `all` · `off`
- `AIDLC_LEARN_HINTS`: `on` (default) · `off`

**Auto-format** (in AI-DLC projects; in every repository with `AIDLC_ENFORCE=all-repos`) formats only files
git does not track yet (new files), so existing code is never reformatted. Dart uses `dart format` (FVM aware); Kotlin, Swift, JS/TS, Python and Go are formatted only if
the project has the tool and its config.

**Limits:** the hook guards Claude's file-edit tools. Shell commands that write files are forbidden by the
rules, not blocked by the hook; `verify-plan.sh --done` still finds such changes after the build. Antigravity and Gemini have no hooks; they follow the always-on rules.

## 8. Files and folders

```
<project>/
├── AGENTS.md · CLAUDE.md · GEMINI.md        AI-DLC block (managed) + your own text
├── .agents/
│   ├── rules/00-aidlc-core.md                  kit: workflow
│   ├── rules/10-quality-gates.md               kit: quality
│   ├── rules/20-architecture.md                project: architecture hard rules
│   ├── skills/project-architecture/SKILL.md    project: full architecture standard
│   ├── skills/project-architecture/reference/  project: its complete code (Flutter standard)
│   ├── rules/30-learning.md                    kit: the brain rules
│   ├── rules/40-token-efficiency.md            kit: the token rule (brief, lean context)
│   ├── rules/50-anti-hallucination.md          kit: evidence for every claim, plan check
│   ├── skills/<11 workflow skills>/SKILL.md    kit (incl. aidlc-think, aidlc-reflect, aidlc-research, aidlc-prompt,
│   │                                           aidlc-anti-hallucination)
│   ├── brain/shared/                           kit: copy of the shared brain (read-only)
│   ├── templates/                              kit: 24 templates
│   ├── .aidlc-version                          kit version + standard
│   ├── .backup/<time>/                         replaced files (git-ignored)
│   └── archive/<time>/                         old files moved by --migrate
└── aidlc-docs/
    ├── aidlc-state.md            where the work stands (machine-read block + progress + next action)
    ├── audit-log.md              every approval and decision, with date and time
    ├── project-profile.md        analysis, feature registry, verification commands, baseline
    ├── brain/                    INDEX.md · inbox.md · metrics.md · lessons/ · research/
    ├── project/                  new project: 01-project-brief … 06-delivery-plan, questions.md, decisions/
    ├── work/<NNN>-<type>-<slug>/ questions, requirements, integration plan, implementation_plan.md or
    │                             bugfix_plan.md, test-report.md, review-report.md
    └── releases/<version>/       release-plan.md, test-report.md
```
**Kit-owned** files are replaced when you update (your edits are backed up first). **Project-owned** files
(`project-architecture` with its `reference/` files, `20-architecture.md`, `aidlc-docs/`) are never
overwritten. The architecture files change only together, with `--update-architecture`.

## 9. Architecture standards

| Standard | Status | Shape |
|---|---|---|
| **Flutter** | House standard v3: built from a production app. Rules in a 23 KB `SKILL.md` core (read before every plan) and 5 topic files (opened when a task touches that area); complete core, feature and test code in 4 more `reference/` files (opened only when needed), compile-checked on Riverpod 2 and 3 (`FLUTTER-STANDARD-V3-ANALYSIS.md`) | Riverpod + GoRouter + Dio + Hive + ScreenUtil; `controller/ model/ presentation/ provider/ repository/` |
| **Android** | Proposed v1: review it | Kotlin + Compose + MVVM + Hilt + Retrofit; `viewmodel/ model/ presentation/ di/ repository/` |
| **iOS** | Proposed v1: review it | Swift + SwiftUI + MVVM + async/await; `ViewModel/ Model/ View/ Repository/` |
| **Generic** | Generated per project | During analysis (existing code) or NP6 (new project), with your approval |

All four share the same section layout, so every project's standard reads the same way.

**Customizing**
- **Keep your existing architecture:** analyze the project (or `/aidlc architecture`) and choose "your
  architecture" (section 4.7): the agent writes your standard from your code, and every plan follows it.
- **One project only:** edit `.agents/skills/project-architecture/SKILL.md` and `.agents/rules/20-architecture.md`
  in that project. The kit never overwrites them.
- **All future projects:** edit `standards/<stack>/` in the kit, run `install.sh`, then use
  `init-project.sh --update-architecture` on the projects that should get it (a project's own files are
  archived, kit-made ones backed up).
- Agents propose standard updates themselves when they find a new pattern (knowledge retention). Updates
  apply only after you approve them.

## 10. The brain: how the agent learns

The AI model never changes. The **brain** does: written lessons, research notes and a scorecard that every
session reads. This is the approach research shows works (*Reflexion*, *ACE*).

```
aidlc-docs/brain/            this project (committed with the code)
├── INDEX.md                 one line per active lesson; read before every plan (max 8 KB)
├── inbox.md                 captured during the current work item, not used yet
├── lessons/L-012-….md       one lesson: when · do · don't · why · evidence · counters
├── research/R-003-….md      researched best practice with sources and a re-check date
└── metrics.md               scorecard per work item + trend
.agents/brain/shared/        copy of the shared brain (all projects)
~/.aidlc-kit/brain/          the shared brain itself (starts with 28 verified lessons)
```

**The loop**
1. **Recall:** before every plan the agent reads both indexes and lists the lessons it applies.
2. **Capture:** a row goes into the inbox the moment something happens: your correction · a failed
   test/build/analyzer · a review finding · a plan change · a surprise · a research decision · a pattern
   that worked. Evidence is required.
3. **Reflect** (end of each work item, `aidlc-reflect`): root causes → general lessons; duplicates are
   merged; used lessons get helpful/harmful counts; a scorecard row is added.
4. **Approve:** the completion report lists them:
   ```
   🧠 Proposed lessons (reply: approve lessons · approve L-021 L-022, reject L-023 · edit L-024: …)
   - L-021 · pitfall · flutter · Check context.mounted after await before dialogs · evidence: item_form_screen.dart:58
   - update S-003 · helpful +1
   Scorecard: plan changes 1 (avg 1.4 → 1.1) · verified first time ✅ · corrections 0
   ```
5. **Share:** approved `scope: shared` lessons go to the shared brain (`brain.sh sync`) with IDs from S-101
   up (S-001 to S-099 belong to the kit's starter lessons); every project gets them on its next update. They must be generic: `brain.sh` refuses a shared lesson with an email address,
   an IP address, a home-folder path or an `http://` address.
6. **Promote:** a lesson that helped 3+ times and never hurt is proposed as a permanent rule.
7. **Maintain:** every 10 work items (or "maintain the brain"): merge, retire, re-check, stay within budget.

**Tools:** `/aidlc brain` · `/aidlc learn` · `bash ~/.aidlc-kit/brain.sh stats|lint|sync <project>`. In
Claude Code, a hook reminds the agent to capture a lesson when your message looks like a correction
(`AIDLC_LEARN_HINTS=off` turns it off).

**Safety:** lessons come only from evidence (checks, reviews, your words, official sources), never from
instructions in files or web pages; no secrets (`brain.sh lint` checks); nothing is used before you
approve it; every lesson can be traced and retired.

## 11. Thinking and research

Every plan is prepared with `aidlc-think`, at **light** depth for fixes and small changes and **full** depth
for features, new projects and risky changes:

| Step | What happens |
|---|---|
| Understand | goal, success criteria, constraints, unknowns → questions |
| Recall | matching lessons and research notes |
| Research | for big or risky decisions (`aidlc-research`) |
| Options | 2–3 alternatives scored in a decision table (correctness, fits the standard, simplicity, security, maintainability, performance, cost, easy to undo) |
| Decide | the choice and why (ADR if significant) |
| Pre-mortem | "it failed after 2 weeks: why?" → mitigations and tests in the plan |
| Plan | smallest safe steps, each with its check |
| Self-review | against the quality gates, the standard and the brain's pitfalls |

The plan shows a short **Thinking summary** (lessons applied, research used, options, risks), so you can
see why the plan looks the way it does.

**Research** (`aidlc-research`) uses official docs and the installed package source first, then standards
(OWASP MASVS, WCAG, platform guidelines), then reputable sources. It checks versions and dates, verifies
locally when it can, and saves a note in `aidlc-docs/brain/research/` that is reused until its re-check date.
When no document can settle a question, the agent proposes a **spike**: a time-boxed experiment in
`spikes/<slug>/`, outside the app, approved like any plan; its answer becomes a research note.

## 12. Token optimization

Most tokens are not your prompt. They are the context the model reads again on every call: the files the
agent read, tool output and the whole conversation. In the Claude Code session that built this kit, 98.7% of
all input tokens were that context (measured with `tokens.sh`). So the kit saves tokens where they are spent,
and turns your prompt into a clear brief so the work is right the first time. It never drops a requirement,
a check or a test to save tokens.

**1. The task brief (automatic, every agent).** Before real work, the agent shows a brief of at most 7 lines
and continues:
```
🎯 Brief · feature · depth full
Goal: budget alerts when monthly spending passes a limit the user sets
Must: limit per category · push + in-app banner · "Budget exceeded" text exactly as given
Out of scope: email alerts
Context: lib/features/budget/ · profile §7 · lessons S-015, L-004
Done when: a test shows the banner at 101% of the limit; analyzer clean
Unknowns: should the limit reset monthly or on a chosen day?
```
It keeps your exact names, numbers and texts, and turns "it" or "that screen" into real paths. Plain
questions get a direct answer without a brief. If the brief is wrong, say so in one line: the agent fixes it
before planning. For a work item it is saved at the top of `questions.md`, and the completion report checks
its "Done when".

**2. The prompt rewriter (on request).** `/aidlc prompt <text>` (Claude Code) or "optimize prompt: <text>"
(any agent) returns a better prompt for any AI tool: Goal · Context · Requirements · Constraints · Output ·
Done when, plus what changed, the gaps to fill and the size before and after. Nothing is invented; missing
facts are marked `[fill in: …]`.

**3. The token rule** (`.agents/rules/40-token-efficiency.md`, always on):
- **Read smart:** search first, read only the needed part of big files, read several files in one step,
  never re-read an unchanged file, reuse the profile, the brain and the plan; open the architecture
  standard's topic files only for the areas the task touches.
- **Run quiet:** `flutter test --reporter failures-only` printed 826 bytes instead of 8,089 for the same 39
  tests and the same pass count; long build logs go through `tail -n 40`.
- **Write lean:** change lines instead of rewriting files; link documents instead of repeating them; fill
  templates without their instruction comments; small changes get a light plan (one document, one approval).
- **Small sessions:** one work item per session; the state file and the brain carry everything over.

**4. Measure (Claude Code).** `tokens.sh` reads only the numbers in Claude Code's own records, never the
conversation:
```bash
bash ~/.aidlc-kit/tokens.sh ~/StudioProjects/MyApp                                          # latest session
bash ~/.aidlc-kit/tokens.sh ~/StudioProjects/MyApp --work-item 004-feature-budget-alerts --line
bash ~/.aidlc-kit/tokens.sh ~/StudioProjects/MyApp --since "2026-10-22 09:00"               # or --all
```
`/aidlc tokens` runs it for you. The completion report and the brain scorecard show the tokens of every work
item, and a work item that used more than twice the usual becomes a lesson ("why?").

**Tips per tool**
| Tool | What helps |
|---|---|
| Claude Code | `/context` (what fills the context) · `/compact <focus>` at the end of a phase · `/clear` after a work item · `/aidlc tokens` |
| Gemini CLI | `/stats` (token use) · `/compress` (summarize the conversation) |
| Antigravity | a new conversation per work item (the state file carries the context over) |

## 13. Anti-hallucination protocol

An agent "hallucinates" when it invents something: a file, a class or method, a package, a version, a fact
about your project, or a result it never saw. The kit stops this in layers, from research that works:
Anthropic's guidance (allow "I don't know", ground in quotes, cite every claim), Chain-of-Verification (check
each claim again from the source) and, for code, mechanical checks against the real project.

**1. The rule (always on, every agent):** `.agents/rules/50-anti-hallucination.md`
- Every claim has evidence seen in this session: `path:line`, command output, your words or an official URL.
  Otherwise it is an `[ASSUMPTION]` or a question; "unknown" is a valid answer.
- Verify before use: the agent finds and reads a class or method before calling it, checks the installed
  package version and its source, confirms a new package's exact name on the official registry (invented
  names are an attack target: "slopsquatting"), and reads a file right before editing it.
- Long tasks: it re-reads the brief, the plan and the state at each phase and after a pause or a summarized
  conversation.
- It reports only real output and says when a check was not run.

**2. Facts and assumptions in every plan:** each fact the plan depends on, with its evidence and status
(verified · assumption · unknown). An unknown fact never reaches a gate: the agent finds it in the code or
docs, or asks you.

**3. The plan check:** `bash ~/.aidlc-kit/verify-plan.sh <plan>` (`/aidlc verify`) checks that:
- every file to modify exists, with "did you mean `router_config.dart`?" for close names;
- files to create are new;
- classes and methods marked "changed" exist in the code;
- cited lessons and research notes exist;
- verified facts show evidence, and no fact is unknown;
- (draft plans) the earlier stages were approved, every user story has a file or task and a test, every NFR a
  named check, and no blocking question is open.

The agent fixes every ✗ before you see the plan. Before the build (C1), `--baseline` records the files that
already had uncommitted changes; after the build, `--done` checks that every planned file exists, nothing
outside the plan changed, every numbered task is done, and the test and review reports show the baseline, the
verification and a PASS. Your earlier changes show up only as warnings and are never reverted. Both also work
when the app is a folder inside a bigger repository.

**4. In Claude Code it is automatic:** a hook runs the check the moment the agent writes a plan file and
tells the agent what does not exist, so it fixes the plan before you see it.

**5. Large or complex work** (full depth, a new project, more than about 5 files, a new package or API, a
migration, security) follows `.agents/skills/aidlc-anti-hallucination/SKILL.md`: ground first, draft with
the facts table, answer verification questions again from the sources, check, keep names and numbers
consistent, report honestly. The reviewer treats an invented API or an unsupported claim as Blocking, and
every hallucination caught becomes a lesson.

## 14. Worked example: a new feature

> **You:** new feature: budget alerts. Warn me when a category passes its monthly budget.

> **Agent:** 🎯 Brief · feature · depth full · Goal: warn when a category passes its monthly budget ·
> Context: `category_settings`, the expense save flow, the notification setup · Unknowns: when, threshold,
> storage, alert type. Work item `004-feature-budget-alerts`. Round 1:
> ```
> Q1. When should the alert appear?  (decides where the check runs)
>     A) Right after saving an expense that crosses the limit ★ (works offline, no new API)
>     B) Daily summary notification
> Q2. Threshold?  A) 80% and 100% ★  B) 100% only  C) Custom per category
> Q3. Where is the budget stored?  A) New field in the existing category model ★  B) Separate Hive box
> Q4. Alert type?  A) In-app banner ★  B) Local push notification  C) Both
> ```

> **You:** use your recommendations, but Q4: C

> **Agent:** (writes `requirements.md`: 3 stories, 9 acceptance criteria, including "no budget set" and
> "edited expense drops below the limit") → **gate F2**

> **You:** approve

> **Agent:** (writes `integration-plan.md`: touch points in `category_settings` model and controller,
> `router_config.dart`, notification permission in `AndroidManifest.xml` / `Info.plist`, two analytics
> events; no backend change) → **gate F3** → you approve → (writes `implementation_plan.md`: 9 files to
> create, 3 to modify, plan-flow, file-map and runtime diagrams, 14 tasks in 5 phases each with How / Why /
> Check, 11 tests, risks, rollback) → **gate F4**

> **You:** approve

> **Agent:** Plan approved and logged. Code gate open.
> C1 baseline: `flutter analyze` 3 infos (existing), `flutter test` 1/1 passing.
> 🔄 Now: Phase 1, "Create budget_alert_response_model.dart" … ✅ Phase 1 done (4 files). Analyzer: no
> new issues. 🔄 Now: Phase 2 …
> ⛔ I need to change `lib/core/global/widgets/custom_popup.dart` to support a warning style. It is not in
> the plan. Proposed plan change PC-1 (one new optional parameter, default unchanged). Approve PC-1?

> **You:** approve PC-1

> **Agent:** … C4 review: PASS WITH FIXES (1 missing empty state, fixed). C5: analyze no new issues,
> 12/12 tests passing, `flutter build apk --debug` OK, iOS build OK.
> ```
> ✅ 004-feature-budget-alerts complete
> Files created: 9 · Files modified: 4 (incl. PC-1) · Routes added: /budgetAlerts
> Tests: 11 added · 12/12 passing · analyzer: no new issues · build: android ✓ ios ✓
> Done when (from the brief): ✅ banner at 80% and 100% ✅ push at 100% ✅ analyzer clean
> Tokens (Claude Code, work item 004-feature-budget-alerts): 6.1M · 58 calls · 96% from cache · output 92k
> Follow-ups: daily summary (Q1-B) as a later feature
> Suggested commit message: feat(budget): alerts when a category passes its budget
> ```
> Feature registry updated. Code gate closed. Commit? Next work item in a new session.

## 15. Working in a team

- **Commit `.agents/` and `aidlc-docs/`.** Plans and decisions get reviewed in pull requests like code.
  A good PR description is the work item's completion report plus links to its plan.
- **One active work item per branch.** Parallel work: separate branches or git worktrees, each with its own
  state. Expect merge conflicts in `aidlc-state.md`; keep the newest state and re-check the "Work items" table.
- **Mob elaboration:** run the question rounds of a new project together on a call, with the agent asking
  and the team answering. Approvals are recorded with the person's words in the audit log.

## 16. Updating the kit

1. Run `bash install.sh` in the new kit folder. It updates `~/.aidlc-kit` and the Claude Code layer; your
   settings and your shared brain are kept: new settings and starter lessons are added, starter lessons you
   never edited are updated (your helpful/harmful counts stay), and lessons you edited or wrote are never
   changed (the installer lists them).
2. In each project: `bash ~/.aidlc-kit/init-project.sh <project> --dry-run`, then without `--dry-run`.
   Kit-owned files are updated (your edits are backed up); project-owned files are kept. Claude Code tells
   you at session start when a project's pack is older than the kit, and `doctor` does too.
3. Architecture standard: init keeps the project's copy and notes when the kit has a different version. To
   switch, add `--update-architecture`: the skill, its `reference/` files and `20-architecture.md` are
   replaced together (your own versions are archived in `.agents/archive/`, kit-made ones backed up). Flutter
   projects on the older 45 KB standard get the lean 23 KB core and its topic files this way.
4. Commit: `git add AGENTS.md CLAUDE.md GEMINI.md .agents aidlc-docs .gitignore && git commit -m "chore: update AI-DLC"`
5. Check: `/aidlc doctor` (Claude Code) or `bash ~/.aidlc-kit/claude/bin/doctor.sh <project>`.

**Changing the kit itself:** edit the kit source (a rule, a template, a standard), bump `VERSION`, run
`bash tests/run-tests.sh` (and `bash tests/flutter-standard-check.sh` after changing the Flutter standard),
then follow steps 1–5.

## 17. Troubleshooting and FAQ

**Claude wrote nothing: "AI-DLC plan gate: blocked …".** Working as intended. Either no plan is approved
(`code_gate: closed`), or the file is not in the plan. Approve the plan or the plan change. For a one-off,
start Claude with `AIDLC_ENFORCE=off`.

**Blocked: "The active plan is not approved".** The state file opened the gate, but the plan's status line
still says `DRAFT`. Approve the plan; the agent then sets `> Status: APPROVED <date-time>`.

**"This folder is empty, so the stack cannot be detected".** A new app: add `--standard flutter` (or
`android`, `ios`, `generic`).

**A project has an older pack (for example 2.0.0).** Run init again (`--dry-run` first). Add `--migrate` for
old workflow rules. The project's own architecture standard is kept; switch with `--update-architecture`.

**Does "yes" approve a plan?** A reply that is only "yes" or "ok" right after a gate card does, and so does
choosing "Approve" in a question card. "ok, but change X" is a change request.

**The rules don't seem to load in Claude Code.** Start a new session after `init-project.sh` (`CLAUDE.md`
loads at session start). Check with `/aidlc doctor`.

**Antigravity ignores my rules.** Every file in `.agents/rules/` needs frontmatter with
`trigger: always_on` (the kit's files have it). The official limits are 24,000 bytes per rule file and
20,000 tokens for all always-on and global rules together; above that, Antigravity turns the largest files
into short pointers. `doctor.sh` checks the frontmatter and the size.

**The agent skipped the questions or the plan.** Reply: "Follow `.agents/rules/00-aidlc-core.md`: ask the
questions and write the plan first." Recurring? Add one line to `aidlc-docs/audit-log.md` as a `LESSON` and
consider a stricter model or Antigravity's review setting.

**Do I need a plan for a one-line fix?** Yes, a short one (that is your rule). Or say "skip the plan for
this": the agent confirms once and logs it.

**Old `implementation_plan.md` files from before?** Keep them. New plans go to `aidlc-docs/work/<id>/`.

**The analyzer already had warnings.** Fine. Verification compares against the baseline and only *new*
issues block.

**Remove the kit from a project?** `bash ~/.aidlc-kit/remove-project.sh <project> --dry-run`, then without
`--dry-run`. It removes the AI-DLC blocks (your own text stays), the kit's files in `.agents/`, the state file
and the `.gitignore` lines, and keeps your architecture standard, your archived old files and `aidlc-docs/`
(add `--all` to remove those too). Everything is copied to `~/.aidlc-kit/backups/` first. Remove it from
your projects before you uninstall the kit from the machine.

**Remove the kit from the machine?** `bash ~/.aidlc-kit/uninstall.sh`. Copies of everything it touches
are saved in `~/.aidlc-kit-uninstall-<time>/`.
