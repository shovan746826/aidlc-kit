---
id: S-005
title: New Dart files use snake_case names; PascalCase file names fail flutter analyze
type: rule
scope: shared
stack: flutter
tags: [naming, lint]
status: active
confidence: high
source: failed-check
evidence: verified in a sample app, 2026-10-22: lib/BadName.dart → info 'file_names' and 'flutter analyze' reported 1 issue
created: 2026-10-22
last_verified: 2026-10-22
recheck: never
helpful: 0
harmful: 0
shared_as: S-005
---

# New Dart files use snake_case names; PascalCase file names fail flutter analyze

**When it applies:** Creating any new Dart file (models included).

**Do:** Name files lower_case_with_underscores, e.g. login_request_model.dart for class LoginRequestModel.

**Don't:** Don't create PascalCase file names; don't rename existing files without an approved plan.

**Why:** flutter_lints includes file_names; analyzer issues block AI-DLC verification.
