---
id: S-026
title: Most tokens are the context read again on every call; keep it small and sessions short
type: fact
scope: shared
stack: any
tags: [tokens, context, sessions]
status: active
confidence: high
source: analysis
evidence: Claude Code records of the session that built kit v2.2 and v2.3 (tokens.sh) · 240 model calls · 116M tokens · 98.7% of the input was cached context read again on every call · new input under 500 tokens
created: 2026-10-22
last_verified: 2026-10-22
recheck: 2027-04-22
helpful: 0
harmful: 0
shared_as: S-026
---

# Most tokens are the context read again on every call; keep it small and sessions short

**When it applies:** Every task with an AI agent. Everything read, run or written in a session stays in the
context and is sent again with each model call.

**Do:** Read only the parts of files the task needs, keep tool output short, and start a new session for
each work item (the state file and the brain carry everything over).

**Don't:** Don't read big files or full logs "just in case", and don't keep unrelated tasks in one long
session.

**Why:** In the measured session the user's prompts were a tiny part of the tokens; almost everything was
the growing context read again on every call. A shorter request saves little; a smaller context and fewer,
better calls save the most.
