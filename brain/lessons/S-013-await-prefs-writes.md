---
id: S-013
title: Await SharedPreferences writes: return Future<void>, never `static void ... async`
type: pitfall
scope: shared
stack: flutter
tags: [storage, async]
status: active
confidence: high
source: analysis
evidence: analysis of a production Flutter app (263 files), 2026-10-22: token and profile writes were fire-and-forget, followed immediately by navigation and reads
created: 2026-10-22
last_verified: 2026-10-22
recheck: never
helpful: 0
harmful: 0
shared_as: S-013
---

# Await SharedPreferences writes: return Future<void>, never `static void ... async`

**When it applies:** Writing storage helpers or saving data before navigating.

**Do:** `static Future<void> storeX(String v) async {...}` and `await SharedPreference.storeX(v);`

**Don't:** Don't call storage writes without await before reading the same key.

**Why:** The read can happen before the write finishes, e.g. an empty token right after login.
