---
id: S-010
title: Add standard headers in one interceptor and handle errors in one ApiRequest helper
type: pattern
scope: shared
stack: flutter
tags: [networking, dio, architecture]
status: active
confidence: high
source: analysis
evidence: analysis of a production Flutter app (263 files), 2026-10-22: 43 API calls, 'Authorization' written by hand 39 times and 'module' 42 times, the same try/catch in every method
created: 2026-10-22
last_verified: 2026-10-22
recheck: never
helpful: 0
harmful: 0
shared_as: S-010
---

# Add standard headers in one interceptor and handle errors in one ApiRequest helper

**When it applies:** Adding or changing an API call.

**Do:** Let AuthInterceptor add Authorization / app headers; call `ApiRequest.send(...)` with a fromJson and an onError builder.

**Don't:** Don't build headers or try/catch blocks per repository method.

**Why:** Copied code drifts: one forgotten header or catch becomes a production bug.
