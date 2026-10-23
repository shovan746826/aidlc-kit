---
id: S-002
title: Riverpod 3 tests: the Override type is in misc.dart
type: pitfall
scope: shared
stack: flutter
tags: [riverpod, testing, versions]
status: active
confidence: high
source: failed-check
evidence: kit v2 build, 2026-10-21: test helper `List<Override>` on flutter_riverpod 3.3.2 → non_type_as_type_argument; fixed by importing misc.dart
created: 2026-10-22
last_verified: 2026-10-22
recheck: 2027-04-22
helpful: 0
harmful: 0
shared_as: S-002
---

# Riverpod 3 tests: the Override type is in misc.dart

**When it applies:** Tests (or helpers) declare `List<Override>` on flutter_riverpod 3.x.

**Do:** Add `import 'package:flutter_riverpod/misc.dart';` to the test file.

**Don't:** Don't remove the type annotation to make it compile; keep tests typed.

**Why:** Riverpod 3 moved rarely used types such as Override to misc.dart.
