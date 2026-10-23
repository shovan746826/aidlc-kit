---
id: S-007
title: Never rm -rf a computed path without guarding empty, / and $HOME
type: pitfall
scope: shared
stack: any
tags: [shell, safety]
status: active
confidence: high
source: review
evidence: kit v2 build, 2026-10-21: a test script's cleanup ran rm -rf on $(dirname of a mktemp path); if mktemp failed it would have been rm -rf /
created: 2026-10-22
last_verified: 2026-10-22
recheck: never
helpful: 0
harmful: 0
shared_as: S-007
---

# Never rm -rf a computed path without guarding empty, / and $HOME

**When it applies:** A script deletes a folder whose path comes from a variable or a command.

**Do:** Check the value first: refuse empty, '/', '$HOME'; prefer deleting the exact folder you created.

**Don't:** Don't use `rm -rf "$(dirname "$X")"` or unguarded variables.

**Why:** One failed command turns the cleanup into deleting the whole disk.
