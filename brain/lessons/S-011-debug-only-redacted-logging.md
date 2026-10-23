---
id: S-011
title: HTTP logging must be debug-only and redact secrets; never copy log fields into request headers
type: pitfall
scope: shared
stack: flutter
tags: [networking, security, logging]
status: active
confidence: high
source: analysis
evidence: analysis of a production Flutter app (263 files), 2026-10-22: the logging interceptor printed headers and bodies in release builds and added responseType/followRedirects/timeouts to the real request headers
created: 2026-10-22
last_verified: 2026-10-22
recheck: never
helpful: 0
harmful: 0
shared_as: S-011
---

# HTTP logging must be debug-only and redact secrets; never copy log fields into request headers

**When it applies:** Writing or reviewing a Dio interceptor that logs.

**Do:** Log only when kDebugMode; mask Authorization, cookies, passwords and tokens; work on a copy of the headers.

**Don't:** Don't `options.headers.addAll(...)` with logging data; don't print in release builds.

**Why:** Tokens and personal data end up in device logs, and junk headers reach the server.
