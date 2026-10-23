---
trigger: always_on
description: AI-DLC anti-hallucination rules. Evidence for every claim; verify code, packages and files before using them; "unknown" or a question instead of a guess; plans pass verify-plan.sh; report only what you saw.
---
<!-- aidlc-kit:managed · replaced when the kit is updated -->

# AI-DLC Anti-Hallucination Rules (mandatory)

An invented API, file, package, fact or result costs more than any question. When you don't know, say
**"unknown"**, then find out from the code or the docs, or ask the user.

## 1. Evidence for every claim
Every fact you state or plan on has a source you saw in this session: `path:line`, command output, the
user's own words, or an official page (URL). No source → mark it `[ASSUMPTION]` and list it at the gate, or
ask. Never fill a gap with a plausible guess: not a name, a path, a version, a number or a result.

## 2. Verify before you use
- **Project code:** before you call or change a class, method, provider, route or file, find it (search)
  and read its definition. Never use a member you have not seen.
- **Packages and APIs:** check the installed version (lock file) and read its source or official docs
  before you use an API. A new package: confirm its exact name and publisher on the official registry
  (pub.dev, Maven Central, CocoaPods / Swift Package Index, npm, PyPI). Invented package names are a
  known attack target ("slopsquatting").
- **Files:** read the part you change right before you edit it; never edit from memory.

## 3. Plans: facts table and check
Every plan has a **Facts and assumptions** table: each fact it depends on, its evidence and its status
(verified · assumption · unknown). Before the gate run `bash ~/.aidlc-kit/verify-plan.sh <plan>` (no kit
on the machine: do its checks by hand) and fix every ✗. What the code and docs can't settle becomes a
question to the user (`00-aidlc-core.md` §4) before the gate. Large or risky work (full depth, a new
project, more than about 5 files, a new package or API, a migration, security) also follows
`.agents/skills/aidlc-anti-hallucination/SKILL.md`.

## 4. Long tasks: re-ground
At the start of every phase, after a pause, a resumed session or a summarized conversation, re-read the
brief, the plan's open tasks and the state file before you continue. Trust the files, not your memory.

## 5. Report only what you saw
Results come from real command output, quoted (e.g. `+39: All tests passed!`). Never "should work", never a
number you did not see. A check you could not run is reported as **not run**, with the reason.

## 6. Learn from it
A hallucination caught (by you, a check, the analyzer, the reviewer or the user) → an inbox row (trigger:
failed-check): what was invented and what is true (`30-learning.md` §2).
