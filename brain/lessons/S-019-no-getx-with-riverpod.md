---
id: S-019
title: Don't use GetX in Riverpod + GoRouter apps; use navigator and messenger keys
type: rule
scope: shared
stack: flutter
tags: [architecture, navigation, dependencies]
status: active
confidence: high
source: analysis
evidence: analysis of a production Flutter app (263 files), 2026-10-22: Get.context / Get.key used 36 times plus GetX widget extensions, next to Riverpod and GoRouter
created: 2026-10-22
last_verified: 2026-10-22
recheck: never
helpful: 0
harmful: 0
shared_as: S-019
---

# Don't use GetX in Riverpod + GoRouter apps; use navigator and messenger keys

**When it applies:** Code outside widgets must navigate or show a snackbar or dialog.

**Do:** Use a global rootNavigatorKey and scaffoldMessengerKey (core) and an AppFeedback helper.

**Don't:** Don't add GetX for context access, navigation or widget extensions.

**Why:** Two navigation systems conflict, and Get.context! crashes when no context is ready.
