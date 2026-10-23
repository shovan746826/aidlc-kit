---
id: S-018
title: Models and providers used by two or more features belong in core/global/global_features
type: rule
scope: shared
stack: flutter
tags: [architecture, features]
status: active
confidence: high
source: analysis
evidence: analysis of a production Flutter app (263 files), 2026-10-22: 22 imports from one feature into another feature's models and providers
created: 2026-10-22
last_verified: 2026-10-22
recheck: never
helpful: 0
harmful: 0
shared_as: S-018
---

# Models and providers used by two or more features belong in core/global/global_features

**When it applies:** A feature needs another feature's data or provider.

**Do:** Move the shared model/provider to core/global/global_features and import it from there.

**Don't:** Don't import another feature's model, provider, controller or repository.

**Why:** Cross-feature imports tie features together and break the feature-first structure.
