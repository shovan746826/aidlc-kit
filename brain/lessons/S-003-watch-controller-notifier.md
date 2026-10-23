---
id: S-003
title: Inside another provider use ref.watch(controllerProvider.notifier), not the provider itself
type: pattern
scope: shared
stack: flutter
tags: [riverpod, state]
status: active
confidence: high
source: failed-check
evidence: kit v2 build, 2026-10-21: test on flutter_riverpod 2.6.1 and 3.3.2: a StateNotifierProvider that watched a ChangeNotifierProvider lost its data on every notifyListeners(); with .notifier the data was kept
created: 2026-10-22
last_verified: 2026-10-22
recheck: never
helpful: 0
harmful: 0
shared_as: S-003
---

# Inside another provider use ref.watch(controllerProvider.notifier), not the provider itself

**When it applies:** A provider needs a ChangeNotifier controller (e.g. a StateNotifier that calls controller methods).

**Do:** `return DataNotifier(ref.watch(featureControllerProvider.notifier));`

**Don't:** Don't `ref.watch(featureControllerProvider)` inside another provider unless it must rebuild on every controller change.

**Why:** Watching the ChangeNotifierProvider re-creates the dependent provider each time the controller notifies, which resets its state.
