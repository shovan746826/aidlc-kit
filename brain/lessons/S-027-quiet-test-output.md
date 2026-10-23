---
id: S-027
title: Run checks with quiet output; read the full output only for failures
type: pattern
scope: shared
stack: any
tags: [tokens, tests, output]
status: active
confidence: high
source: analysis
evidence: Flutter standard v3 test suite (39 tests) · default reporter 8,089 bytes and 46 lines · --reporter failures-only 826 bytes and 7 lines with the same "+39 All tests passed" summary
created: 2026-10-22
last_verified: 2026-10-22
recheck: 2027-04-22
helpful: 0
harmful: 0
shared_as: S-027
---

# Run checks with quiet output; read the full output only for failures

**When it applies:** Running tests, analyzers or builds during a work item (baseline, quick checks,
verification).

**Do:** Flutter: `flutter test --reporter failures-only` (it still prints the pass count). Long builds:
`… 2>&1 | tail -n 40`. Gradle: `-q`. Xcode: `xcodebuild -quiet`. Open the full output only for the test or
build that failed.

**Don't:** Don't print every passing test or a whole build log into the conversation.

**Why:** Tool output stays in the context and is read again on every later call. The quiet reporter cut the
test output by 90% and kept the result.
