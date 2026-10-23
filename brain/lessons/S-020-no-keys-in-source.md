---
id: S-020
title: No API keys, auth keys or Firebase options in source; HTTPS only
type: pitfall
scope: shared
stack: flutter
tags: [security, config]
status: active
confidence: high
source: analysis
evidence: analysis of a production Flutter app (263 files), 2026-10-22: Firebase options and an app auth key hardcoded in source; the API used plain http:// to an IP address
created: 2026-10-22
last_verified: 2026-10-22
recheck: never
helpful: 0
harmful: 0
shared_as: S-020
---

# No API keys, auth keys or Firebase options in source; HTTPS only

**When it applies:** Configuring Firebase, API base URLs or app keys.

**Do:** Use flutterfire's firebase_options.dart, `--dart-define-from-file=env/<flavor>.json` (git-ignored) and HTTPS base URLs.

**Don't:** Don't commit keys or use http:// for APIs.

**Why:** Keys in an app can be extracted, and http:// sends tokens unencrypted.
