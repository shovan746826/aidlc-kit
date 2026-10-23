---
id: S-004
title: Widget tests need ScreenUtilInit above widgets that use .w .h .r .sp
type: pitfall
scope: shared
stack: flutter
tags: [testing, screenutil]
status: active
confidence: high
source: failed-check
evidence: verified in a sample app, 2026-10-22: pumping a Text with 16.sp without ScreenUtilInit → LateInitializationError: Field '_minTextAdapt' has not been initialized
created: 2026-10-22
last_verified: 2026-10-22
recheck: never
helpful: 0
harmful: 0
shared_as: S-004
---

# Widget tests need ScreenUtilInit above widgets that use .w .h .r .sp

**When it applies:** Writing widget tests for screens or components that use flutter_screenutil extensions.

**Do:** Wrap the widget under test: ProviderScope → ScreenUtilInit(designSize: same as the app) → MaterialApp(home: widget).

**Don't:** Don't pump ScreenUtil-based widgets directly.

**Why:** ScreenUtil is initialized by ScreenUtilInit; without it every size extension throws.
