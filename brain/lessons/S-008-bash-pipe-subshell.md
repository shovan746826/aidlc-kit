---
id: S-008
title: Piping into a bash function runs it in a subshell; its variable changes are lost
type: pitfall
scope: shared
stack: any
tags: [shell, bash]
status: active
confidence: high
source: failed-check
evidence: kit v2 build, 2026-10-21: `render | write_content file` lost the added/updated lists in init-project.sh
created: 2026-10-22
last_verified: 2026-10-22
recheck: never
helpful: 0
harmful: 0
shared_as: S-008
---

# Piping into a bash function runs it in a subshell; its variable changes are lost

**When it applies:** A bash function updates variables and receives input through a pipe.

**Do:** Write the input to a temp file (or use a here-string) and call the function in the main shell.

**Don't:** Don't `cmd | my_function` when my_function must change shell variables.

**Why:** Each part of a pipeline runs in its own subshell (bash 3.2 on macOS has no lastpipe).
