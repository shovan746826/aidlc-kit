---
id: S-015
title: Check context.mounted after every await before using context
type: pitfall
scope: shared
stack: flutter
tags: [async, context]
status: active
confidence: high
source: analysis
evidence: analysis of a production Flutter app (263 files), 2026-10-22: many awaits followed by dialogs, snackbars and navigation, only 3 mounted checks
created: 2026-10-22
last_verified: 2026-10-22
recheck: never
helpful: 0
harmful: 0
shared_as: S-015
---

# Check context.mounted after every await before using context

**When it applies:** Code awaits something and then shows a dialog, snackbar or navigates with a BuildContext.

**Do:** `if (!context.mounted) return;` right after the await.

**Don't:** Don't use a BuildContext across an async gap without the check.

**Why:** If the user left the screen, the context is gone and the call crashes or does nothing.
