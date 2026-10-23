---
id: S-006
title: Antigravity reads .agents/rules/*.md only when the file has a trigger: frontmatter
type: fact
scope: shared
stack: any
tags: [agents, antigravity, rules]
status: active
confidence: high
source: research
evidence: Official Antigravity docs https://antigravity.google/docs/rules (read 2026-10-22) · rules in .agents/rules/*.md need frontmatter with a trigger (always_on, model_decision, glob, manual) · 24,000 bytes per file · always-on and global rules share 20,000 tokens
created: 2026-10-22
last_verified: 2026-10-22
recheck: 2027-01-22
helpful: 0
harmful: 0
shared_as: S-006
---

# Antigravity reads .agents/rules/*.md only when the file has a trigger: frontmatter

**When it applies:** Writing or reviewing rule files in .agents/rules/.

**Do:** Start every rule file with frontmatter `trigger: always_on` (or model_decision / glob / manual). Keep
each rule file under 24,000 bytes, and all always-on text (rules, `AGENTS.md`, `GEMINI.md`, global rules)
well under 20,000 tokens.

**Don't:** Don't leave rule files without frontmatter.

**Why:** The official docs require the frontmatter; files without a valid trigger never apply. Above the
20,000-token budget Antigravity turns the largest rule files into short pointers, so the most important
rules can stop loading in full.
