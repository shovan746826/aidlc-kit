---
id: S-024
title: Plain test() files that touch GlobalKeys (navigator, messenger) need TestWidgetsFlutterBinding.ensureInitialized()
type: pitfall
scope: shared
stack: flutter
tags: [testing]
status: active
confidence: high
source: failed-check
evidence: verified in a sample app, 2026-10-22: controller tests calling AppFeedback failed with 'Binding has not yet been initialized'
created: 2026-10-22
last_verified: 2026-10-22
recheck: never
helpful: 0
harmful: 0
shared_as: S-024
---

# Plain test() files that touch GlobalKeys (navigator, messenger) need TestWidgetsFlutterBinding.ensureInitialized()

**When it applies:** Unit tests call code that uses rootNavigatorKey / scaffoldMessengerKey (e.g. AppFeedback in controllers).

**Do:** First line of main(): `TestWidgetsFlutterBinding.ensureInitialized();`.

**Don't:** Don't skip it because the test is not a widget test.

**Why:** GlobalKey.currentContext needs the widgets binding; without it the test crashes.
