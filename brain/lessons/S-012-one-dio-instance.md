---
id: S-012
title: Reuse one Dio instance configured with BaseOptions (base URL, timeouts)
type: pattern
scope: shared
stack: flutter
tags: [networking, dio, performance]
status: active
confidence: high
source: analysis
evidence: analysis of a production Flutter app (263 files), 2026-10-22: DioClient() created a new Dio for every call with empty BaseOptions (no timeouts)
created: 2026-10-22
last_verified: 2026-10-22
recheck: never
helpful: 0
harmful: 0
shared_as: S-012
---

# Reuse one Dio instance configured with BaseOptions (base URL, timeouts)

**When it applies:** Creating the network client.

**Do:** Make DioClient a real singleton with baseUrl, connectTimeout, receiveTimeout and sendTimeout.

**Don't:** Don't create a new Dio per request.

**Why:** Requests without timeouts can hang forever, and per-call clients lose shared configuration.
