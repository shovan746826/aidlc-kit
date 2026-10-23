---
id: S-009
title: Never force-unwrap DioException.response; it is null for connection, certificate and unknown errors
type: pitfall
scope: shared
stack: flutter
tags: [networking, dio, errors]
status: active
confidence: high
source: analysis
evidence: analysis of a production Flutter app (263 files), 2026-10-22: the error mapper used dioError.response!.statusCode! in the default branch
created: 2026-10-22
last_verified: 2026-10-22
recheck: never
helpful: 0
harmful: 0
shared_as: S-009
---

# Never force-unwrap DioException.response; it is null for connection, certificate and unknown errors

**When it applies:** Mapping a DioException to a message or error type.

**Do:** Use `e.response?.statusCode` and `e.response?.data`; handle every DioExceptionType, with a default message.

**Don't:** Don't write `response!` or `statusCode!` in error handling.

**Why:** The crash happens inside the catch block, so the app fails exactly when the network fails.
