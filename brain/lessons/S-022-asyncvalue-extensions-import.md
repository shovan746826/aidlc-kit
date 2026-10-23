---
id: S-022
title: AsyncValue getters like requireValue and hasError need the flutter_riverpod import (they are extensions in 2.x)
type: pitfall
scope: shared
stack: flutter
tags: [riverpod, testing]
status: active
confidence: high
source: failed-check
evidence: verified in a sample app, 2026-10-22: a notifier test without the import → 'The getter requireValue isn't defined for AsyncValue<List<Item>>'
created: 2026-10-22
last_verified: 2026-10-22
recheck: 2027-04-22
helpful: 0
harmful: 0
shared_as: S-022
---

# AsyncValue getters like requireValue and hasError need the flutter_riverpod import (they are extensions in 2.x)

**When it applies:** A file (often a test) reads requireValue, hasError, isLoading or valueOrNull on an AsyncValue.

**Do:** Import `package:flutter_riverpod/flutter_riverpod.dart` in that file.

**Don't:** Don't assume the getters come with the type's own import.

**Why:** In Riverpod 2 they are extension getters; without the import the file does not compile.
