---
id: S-021
title: Riverpod 2: AsyncValue.value throws on an error state without data; use hasValue + requireValue
type: pitfall
scope: shared
stack: flutter
tags: [riverpod, asyncvalue]
status: active
confidence: high
source: research
evidence: Package source riverpod-2.6.1/lib/src/common.dart: `if (!hasValue) throwErrorWithCombinedStackTrace(error, stackTrace)`
created: 2026-10-22
last_verified: 2026-10-22
recheck: 2027-04-22
helpful: 0
harmful: 0
shared_as: S-021
---

# Riverpod 2: AsyncValue.value throws on an error state without data; use hasValue + requireValue

**When it applies:** Code (not widgets) reads the current value of an AsyncValue, e.g. to append the next page.

**Do:** `final previous = state.hasValue ? state.requireValue : const <T>[];` (works on Riverpod 2 and 3); in widgets use `when(...)`.

**Don't:** Don't read `.value` on an AsyncValue that may be an error in Riverpod 2.

**Why:** The read throws inside the notifier and breaks pagination after an error.
