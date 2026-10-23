---
id: S-001
title: Riverpod 3: import legacy.dart for ChangeNotifierProvider, StateNotifierProvider and StateProvider
type: pitfall
scope: shared
stack: flutter
tags: [riverpod, versions]
status: active
confidence: high
source: failed-check
evidence: kit v2 build, 2026-10-21: flutter analyze on flutter_riverpod 3.3.2 without the import → 'The function ChangeNotifierProvider isn't defined' (undefined_function)
created: 2026-10-22
last_verified: 2026-10-22
recheck: 2027-04-22
helpful: 0
harmful: 0
shared_as: S-001
---

# Riverpod 3: import legacy.dart for ChangeNotifierProvider, StateNotifierProvider and StateProvider

**When it applies:** The project uses flutter_riverpod 3.x and the provider types ChangeNotifierProvider, StateNotifierProvider or StateProvider.

**Do:** Add `import 'package:flutter_riverpod/legacy.dart';` in every file that uses them (keep the normal flutter_riverpod import too).

**Don't:** Don't assume 2.x code compiles on 3.x; don't silently migrate to Notifier without an approved plan.

**Why:** Riverpod 3 moved these types to legacy.dart. Without the import the project does not compile.
