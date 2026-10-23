---
id: S-017
title: Never hard-cast GoRouterState.extra; it is null after a deep link or app restore
type: pitfall
scope: shared
stack: flutter
tags: [navigation, go_router]
status: active
confidence: high
source: analysis
evidence: analysis of a production Flutter app (263 files), 2026-10-22: routes used `state.extra as Type` without checks
created: 2026-10-22
last_verified: 2026-10-22
recheck: never
helpful: 0
harmful: 0
shared_as: S-017
---

# Never hard-cast GoRouterState.extra; it is null after a deep link or app restore

**When it applies:** A route receives an object through extra.

**Do:** Check the type (`state.extra is Item ? ... : null`) and show a fallback; pass an id for screens that can be opened by link.

**Don't:** Don't write `state.extra as T` without a check.

**Why:** extra is in-memory only; a cast on null crashes the route.
