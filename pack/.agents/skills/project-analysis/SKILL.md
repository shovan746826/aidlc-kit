---
name: project-analysis
description: Analyze an existing codebase and write aidlc-docs/project-profile.md (stack, architecture conformance, feature registry, conventions, dependency risks, verification commands and a baseline). Use at the first AI-DLC session in a project, when the profile is missing or older than 30 days, when the structure changed, or when the user asks to analyze the project.
---
<!-- aidlc-kit:managed · replaced when the kit is updated -->

# Project Analysis

**Goal:** understand the project well enough that every later plan is right, without guessing.
**Output:** `aidlc-docs/project-profile.md` (template: `.agents/templates/project-profile.md`).
This skill only READS the project and writes inside `aidlc-docs/` (plus, for a generic standard, the
project's architecture skill and rules in `.agents/`, see A4). It never changes code, config or dependencies.

| Stage | What | Output |
|---|---|---|
| A1 | Detect stack, identity, greenfield or brownfield | notes |
| A2 | Map structure, compare with the standard, feature registry | notes |
| A3 | Dependencies, configuration, tests, hotspots | notes |
| A4 | Verification commands + baseline → write the profile | `project-profile.md` → **gate** |

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

## Gate
Show the gate card (`00-aidlc-core.md` §5): summary, top deviations, top dependency risks, baseline.
Ask: **"Is this analysis correct? Anything to add or correct?"** Update the state file (`stage: A4 Profile`)
and wait. After approval: log it in the audit log, set `mode: idle` (or continue with the request that
started the analysis) and write the next action.

## Rules
- Facts only, with paths. Write "unknown" rather than guess.
- Never change code, configuration or dependencies during the analysis.
- Never print secrets (keys, tokens, passwords, keystore passwords).
- Large projects: summarize; put details in tables, not prose.
