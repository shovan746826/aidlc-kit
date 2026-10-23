---
id: S-023
title: dio 5.10 added DioExceptionType.transformTimeout: exhaustive switches break across dio versions
type: pitfall
scope: shared
stack: flutter
tags: [networking, dio, versions]
status: active
confidence: high
source: failed-check
evidence: verified in a sample app, 2026-10-22: a switch over DioExceptionType failed with non_exhaustive_switch_statement on dio 5.10+; 5.9 has no transformTimeout
created: 2026-10-22
last_verified: 2026-10-22
recheck: 2027-04-22
helpful: 0
harmful: 0
shared_as: S-023
---

# dio 5.10 added DioExceptionType.transformTimeout: exhaustive switches break across dio versions

**When it applies:** Mapping DioExceptionType values.

**Do:** Use if/else on the known values and compare new ones by name (`type.name == 'transformTimeout'`), with a final else.

**Don't:** Don't write an exhaustive switch over DioExceptionType for code that must work on several dio versions.

**Why:** Code that compiles on 5.9 fails on 5.10+ (and the reverse if you name the new value).
