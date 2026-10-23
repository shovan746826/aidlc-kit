---
id: S-016
title: Never write provider state from build() and never ref.watch inside callbacks
type: pitfall
scope: shared
stack: flutter
tags: [riverpod, build]
status: active
confidence: high
source: analysis
evidence: analysis of a production Flutter app (263 files), 2026-10-22: addPostFrameCallback inside build() copied data into StateProviders using ref.watch inside the callback
created: 2026-10-22
last_verified: 2026-10-22
recheck: never
helpful: 0
harmful: 0
shared_as: S-016
---

# Never write provider state from build() and never ref.watch inside callbacks

**When it applies:** A screen needs data derived from other providers.

**Do:** Derive it with a provider (or ref.watch/select in build); use ref.read inside callbacks.

**Don't:** Don't schedule provider writes in build(); don't call ref.watch in callbacks.

**Why:** It runs on every rebuild, can loop, and reads stale values.
