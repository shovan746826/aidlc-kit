---
id: S-014
title: Dispose every TextEditingController, FocusNode and AnimationController
type: pitfall
scope: shared
stack: flutter
tags: [lifecycle, memory]
status: active
confidence: high
source: analysis
evidence: analysis of a production Flutter app (263 files), 2026-10-22: 14 TextEditingControllers created, only 3 dispose() methods in the whole app
created: 2026-10-22
last_verified: 2026-10-22
recheck: never
helpful: 0
harmful: 0
shared_as: S-014
---

# Dispose every TextEditingController, FocusNode and AnimationController

**When it applies:** A screen or form uses text, focus or animation controllers.

**Do:** Create them in a State object and dispose them in dispose(); or in an autoDispose provider whose controller disposes them.

**Don't:** Don't keep them in a long-lived (non-autoDispose) ChangeNotifier controller.

**Why:** Undisposed controllers leak memory and keep old text when the screen opens again.
