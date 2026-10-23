---
name: project-analysis
description: Analyze an existing codebase and write aidlc-docs/project-profile.md (stack, architecture conformance, feature registry, conventions, dependency risks, verification commands and a baseline). Use at the first AI-DLC session in a project, when the profile is missing or older than 30 days, when the structure changed, or when the user asks to analyze the project.
---
<!-- aidlc-kit:managed · replaced when the kit is updated -->

# Project Analysis

**Goal:** understand the project well enough that every later plan is right, without guessing.
**Output:** `aidlc-docs/project-profile.md` (template: `.agents/templates/project-profile.md`).
This skill only READS the project and writes inside `aidlc-docs/` (plus the project's architecture skill
and rules in `.agents/`: A4 for a generic standard, A5 after the user's architecture choice). It never changes
code, config or dependencies.

| Stage | What | Output |
|---|---|---|
| A1 | Detect stack, identity, greenfield or brownfield | notes |
| A2 | Map structure, compare with the standard, feature registry | notes |
| A3 | Dependencies, configuration, tests, hotspots | notes |
| A4 | Verification commands + baseline → write the profile | `project-profile.md` → **gate** |
| A5 | Architecture choice: your architecture, the AI-DLC standard, or a mix | the project's standard → **gate** |

Before you start: set the state file to `mode: analysis`, `stage: A1 Detect`, and tell the user what you
are going to read (one line).

## A1. Detect the project
1. Find the stack(s) from manifest files at the project root:
   | Signal | Stack |
   |---|---|
   | `pubspec.yaml` with `sdk: flutter` | Flutter |
   | `settings.gradle(.kts)` or `app/build.gradle(.kts)`, no `pubspec.yaml` | Native Android |
   | `*.xcodeproj`, `*.xcworkspace` or `Package.swift`, no `pubspec.yaml` | Native iOS |
   | `package.json`, `pyproject.toml`, `go.mod`, `composer.json`, … | Other (generic standard) |
   A repository can hold several (e.g. app + backend folder). Record each with its root folder.
2. Identity: app name, package / bundle id, version, platform folders present, minimum OS versions.
3. Greenfield (empty, or only the default scaffold) → stop here and tell the user to use
   `.agents/skills/aidlc-new-project/SKILL.md`. Otherwise it is brownfield: continue.

## A2. Map the structure
1. List the top 3 levels of the source tree (skip build output, generated code, `.dart_tool`, `Pods`,
   `node_modules`). Flutter house standard: list `lib/core/` and `lib/features/` completely.
2. Compare with `.agents/skills/project-architecture/SKILL.md`. Record which conventions are followed and
   every deviation with its exact path (e.g. "`lib/features/agreement/presentation/widget/` uses `widget/`
   instead of `component/`").
3. Feature registry: for each feature folder, record screens, routes (from the router config), API endpoints
   (from the URL config), state holders (providers / view models) and short notes.
4. Conventions actually used, with one `path:line` example each: state, routing, networking, models, error
   handling, storage, design system (colors, sizes), imports, naming.
5. Reference implementation: if a complete example feature exists, record it. Later plans copy its
   patterns. An empty demo feature does not count: then the architecture skill's reference files (`reference/`) are
   the reference.
6. Flutter house standard: check the v3 deviations with the search patterns in section 23 of the
   architecture skill (hand-written headers, `DioClient().dio` in repositories, GetX, `statusCode == 200`,
   `response!`, `state.extra as`, fire-and-forget storage writes, provider writes in `build`, cross-feature
   imports, hardcoded colors, `http://` URLs, keys in source). Record counts and paths in profile section 7.

## A3. Dependencies, configuration, tests, hotspots
1. Key dependencies with constraint and resolved version (lock file). Flag:
   - `any` or missing version constraints
   - two libraries for one job (e.g. two state-management libraries)
   - legacy APIs (e.g. Riverpod 3 legacy providers without the `legacy.dart` import)
   - packages that are installed but unused, or used in a way the standard does not allow
2. Configuration: flavors, environment files, base URLs, Firebase projects, signing. Never copy secret
   values: write "present in <file>".
3. Tests: number of test files, kinds (unit / widget / integration), what they cover. CI pipelines.
4. Hotspots: files over ~500 lines, clusters of TODO/FIXME, duplicated code, fragile areas.

## A4. Verification commands, baseline, profile
1. Decide the verification commands (profile section 10) from the project and its stack:
   - Flutter: `flutter pub get` · `flutter analyze` · `flutter test` · `flutter build apk --debug` ·
     on macOS with an iOS target: `flutter build ios --debug --no-codesign`. Use `fvm flutter …` when the
     project has `.fvmrc` or `.fvm/`. Add `dart run build_runner build --delete-conflicting-outputs` only if
     the project uses code generation.
   - Native Android: `./gradlew lint testDebugUnitTest assembleDebug`.
   - Native iOS: `xcodebuild -scheme <App> -destination 'platform=iOS Simulator,name=<device>' build test`.
   - Other stacks: the project's own scripts (package.json scripts, Makefile, CI config).
2. Baseline: run the analyzer/lint and the tests now and record counts (errors / warnings / infos; tests
   passed / failed). Builds are slow: ask the user before running a build for the baseline. These commands
   may create caches (`.dart_tool`, `build/`); that is fine.
3. Write `aidlc-docs/project-profile.md` from the template. Set `analyzed:` to today.
4. If `.agents/skills/project-architecture/SKILL.md` says **"NOT GENERATED"** (generic standard), generate
   it now from the code, following the instructions inside that file, together with the project's
   `.agents/rules/20-architecture.md`. Both are part of this gate and apply only after approval.
5. Brain: add an inbox row for each surprising finding that would help future work (trigger: surprise,
   evidence: counts and paths). They become lessons after the user's batch approval.

## A5. Architecture choice
**When:** after the A4 gate, the first time the project is analyzed (profile section 15 is empty). Later only
when the user asks (`/aidlc architecture`, "change the architecture", "keep my architecture", "use the AI-DLC
architecture"), or when this analysis finds that the code no longer follows the chosen standard: then ask
whether to keep the choice. New projects choose in `aidlc-new-project` NP6 instead.

1. **Compare**, one row per area, with evidence (`path:line`): architecture and folders · API calling · state
   management · routing · storage and session · error handling and user feedback · dependency injection ·
   design system · testing. Columns: this project today · the AI-DLC standard for the stack
   (`~/.aidlc-kit/standards/<stack>/SKILL.md`, or the installed copy) · risks found (profile §7) · ★.
   ★ rules: state management, folder layout and dependency injection → keep yours unless they cause real
   problems (changing them in a working app is expensive); an area with security or crash risks (tokens in
   logs, force-unwrapped responses, keys in source) → take AI-DLC's; otherwise keep what is consistent.
   A generic project has no kit standard: only A is possible (generated as in A4.4).
2. **Ask** (question protocol, `00-aidlc-core.md` §4):
   ```
   Q1. Which architecture should AI-DLC follow in this project?  (decides every later plan)
       A) Your architecture: AI-DLC writes your standard from your code
       B) The AI-DLC standard (<stack>): new code follows it; old code changes only through planned work items
       C) Mix: choose per area
   ```
   Put the ★ on the option the comparison supports, with the reason. For C, ask one question per area
   ("API calling: A) keep yours  B) take AI-DLC's ★ …"). Record every question and answer in
   `aidlc-docs/project/questions.md` (create it if missing).
3. **Gate** (`00-aidlc-core.md` §5): the choice, the list of `.agents/` files that will change, and the ADR
   draft. The code never changes in this stage.
4. **Apply** after the approval (only `.agents/` and `aidlc-docs/` change):
   - **A, your architecture:**
     - The architecture skill is already the project's own (no `aidlc-kit:standard=` marker, or
       `generated`): keep its text. Add under its frontmatter the marker line
       `<!-- aidlc-kit:standard=generated · the project's own standard (architecture choice <date>, ADR-<NNN>) -->`
       and add, written from the code, any section the workflow needs that is missing (template
       `architecture-standard.md` §18 new-feature checklist, §19 placement rules, §20 commands, §21 testing).
     - The skill is a kit standard or the placeholder: write `.agents/skills/project-architecture/SKILL.md`
       from template `architecture-standard.md`, every section from the code with `path:line` examples. Move
       the kit's copy and its `reference/` folder to `.agents/archive/<YYYYMMDD>/`.
     - Rewrite `.agents/rules/20-architecture.md` as the template's last comment describes: frontmatter
       `trigger: always_on`, marker `aidlc-kit:standard=generated`, 10–20 short rules taken from the standard.
   - **B, the AI-DLC standard:** with the user's OK run
     `bash ~/.aidlc-kit/init-project.sh "<project root>" --update-architecture` (the project's own files are
     archived, kit-made ones backed up). Profile §7 becomes the migration list, in the order the standard
     gives (Flutter: §23); suggest the first work item. No kit on this machine → tell the user.
   - **C, mix:** write the standard from template `architecture-standard.md`. A section kept from the project
     says `Source: yours` (written from the code); a section taken from AI-DLC says `Source: AI-DLC` (the kit
     standard's section, shortened to what applies, with the reference files it needs copied into
     `reference/`). Write `20-architecture.md` from both. Both files carry the marker `generated`.
   - **Always:** an ADR `aidlc-docs/project/decisions/ADR-<NNN>-architecture-choice.md` (template
     `decision-record.md`), profile section 15 (decision, date, per-area table, ADR link), an audit-log line
     with the user's words, and the next action in the state file.
5. Every later plan follows the chosen standard: its new-feature checklist gives the plan's phases and files.

## Gate
Show the gate card (`00-aidlc-core.md` §5): summary, top deviations, top dependency risks, baseline.
Ask: **"Is this analysis correct? Anything to add or correct?"** Update the state file (`stage: A4 Profile`)
and wait. After approval: log it in the audit log, then go to A5 when it applies; otherwise set
`mode: idle` (or continue with the request that started the analysis) and write the next action.

## Rules
- Facts only, with paths. Write "unknown" rather than guess.
- Never change code, configuration or dependencies during the analysis.
- Never print secrets (keys, tokens, passwords, keystore passwords).
- Large projects: summarize; put details in tables, not prose. Keep the profile under about 10 KB (it is read in
  every session).
