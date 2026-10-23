---
id: S-025
title: In tests read StateNotifier.state; debugState is deprecated
type: rule
scope: shared
stack: flutter
tags: [testing, riverpod]
status: active
confidence: high
source: failed-check
evidence: verified in a sample app, 2026-10-22: debugState → deprecated_member_use ('Use state instead'); state is @visibleForTesting
created: 2026-10-22
last_verified: 2026-10-22
recheck: 2027-04-22
helpful: 0
harmful: 0
shared_as: S-025
---

# In tests read StateNotifier.state; debugState is deprecated

**When it applies:** Unit-testing a StateNotifier directly.

**Do:** `expect(notifier.state.requireValue, ...)`.

**Don't:** Don't use debugState.

**Why:** Deprecated members are analyzer issues and block verification.
