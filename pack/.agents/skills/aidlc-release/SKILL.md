---
name: aidlc-release
description: Plan and prepare an app release. Covers the version bump, changelog, pre-release checklist, builds, store listing and privacy changes, staged rollout, monitoring and lessons learned. Use for "release", "publish", "version bump", "build for the store" or "prepare version x.y.z".
---
<!-- aidlc-kit:managed · replaced when the kit is updated -->

# Release

**Output folder:** `aidlc-docs/releases/<version>/` with `release-plan.md` (+ `questions.md`, `test-report.md`)

| Stage | What | Gate |
|---|---|---|
| R1 Questions | scope, version, platforms, tracks, rollout | the user's answers |
| R2 Release plan | `release-plan.md` | 🛑 approve → the code gate opens |
| R3 Prepare and build | through `aidlc-construction` | verification |
| R4 Hand-over | publishing steps for the user | the user publishes |
| R5 After release | monitoring, lessons, registry | none |

## R1. Questions (question bank I)
Which completed work items are included; version type (patch / minor / major) and new build number;
platforms and tracks (internal, closed, open, production; TestFlight, App Store); rollout percentage;
release-notes languages; new permissions, data collection or payments (privacy labels); deadline.
State: `mode: release`, `type: release`, `work_item: release-<version>`, `stage: R1 Questions`.

## R2. Release plan → `release-plan.md`
1. Template `release-plan.md`. Version location per stack:
   - Flutter: `version: x.y.z+build` in `pubspec.yaml`
   - Android: `versionName` / `versionCode` in `app/build.gradle(.kts)`
   - iOS: `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`
   - Web or backend: the version tag; the deploy pipeline per environment (staging → production) takes the
     place of the stores; database migrations come with their rollback
2. Changelog from the completed work items. Pre-release checklist. Files tables (version files,
   `CHANGELOG.md`).
3. Build commands: Flutter `flutter build appbundle --release` and `flutter build ipa --release`; add
   `--flavor <name>` and `--obfuscate --split-debug-info=<dir>` if the project uses them.
4. Rollout and rollback, with gates: widen a staged rollout only while crash-free users stay at or above the
   target and no new top crash appears; otherwise halt it and open a bug-fix work item. Monitoring.
5. Gate. 🛑 **HARD STOP.** On approval: `code_gate: open`, `active_plan:` the release plan →
   `.agents/skills/aidlc-construction/SKILL.md`.

## R3. Prepare and build
Through construction: version edits, changelog, release builds. Record artifact paths and sizes. Give the
user a smoke-test checklist for a real device.

## R4. Hand-over for publishing
🚫 Never upload to a store, publish, tag, push or deploy on your own. Give the user the exact steps, or run
one only after an explicit "yes" for that exact action. Signing keys and store credentials stay with the user.

## R5. After release
Monitoring checklist (crash-free users, ANRs, reviews, key KPIs). Mark the release completed in the state
file and close the gate. Reflect with `.agents/skills/aidlc-reflect/SKILL.md` (lessons for the user's batch
approval, scorecard row). Record the version in the feature registry.
