---
name: aidlc-anti-hallucination
description: Anti-hallucination protocol for large or complex tasks and plans. Ground every fact in evidence, keep a facts table, verify claims again from the sources (Chain-of-Verification), run verify-plan.sh, keep names and numbers consistent, and report only real results. Use for full-depth plans, new projects, more than about 5 files, a new package or API, migrations, security work, or when the user says "verify the plan" or "check for hallucinations".
---
<!-- aidlc-kit:managed · replaced when the kit is updated -->

# Anti-Hallucination Protocol

**When:** full-depth thinking, a new project, more than about 5 files, a new package or API, a migration,
security or privacy work, or the user asks. Small tasks follow the always-on rule
(`.agents/rules/50-anti-hallucination.md`) only.

Built on Chain-of-Verification (draft → verification questions → answer them again from the sources →
revise; Meta AI, ACL Findings 2024) and Anthropic's guidance ("I don't know" is allowed, ground in direct
quotes, cite every claim, remove claims without support). For code, the strongest checks are mechanical:
does it exist, does it compile, does the test pass.

## H1. Ground before you draft
1. Collect the evidence first: the files, definitions, contracts and docs the task needs, each with
   `path:line` or a URL. For long specs or API docs, copy the exact sentences you will rely on into the
   work item's notes and quote them.
2. Facts about this project, its APIs, its versions and its users come only from that evidence and the
   user's words. General knowledge is for ideas, never for facts about this project.

## H2. Draft with a facts table
Write the plan and its **Facts and assumptions** table: every fact the result depends on.
```
| #  | Claim the plan depends on                        | Evidence                                                    | Status     |
|----|--------------------------------------------------|-------------------------------------------------------------|------------|
| F1 | `ItemsRepository.getItems({page})` exists        | `lib/features/items/repository/items_repository.dart:14`    | verified   |
| F2 | The API returns `items` and `total`              | backend doc https://… §3, quoted in questions.md Q4          | verified   |
| F3 | dio 5.x has `DioExceptionType.transformTimeout`  | `~/.pub-cache/hosted/pub.dev/dio-5.10.0/lib/src/dio_exception.dart:40` | verified |
| F4 | A user has at most a few hundred items           | the user: "max a few hundred"                               | assumption |
```
Status: **verified** (seen in this session) · **assumption** (listed at the gate) · **unknown** (find it or
ask; never shown at a gate).

## H3. Verification questions, answered again
For each important claim, write the question that would prove it wrong, for example "Does
`items_repository.dart` have `getItems` with a `page` parameter?". Answer each one **from the source again**:
open the file, run the search, read the package source or the doc. Do not answer from the draft. A claim
that fails → fix the plan; a claim the sources can't settle → `unknown` → a question to the user.

## H4. Mechanical check
Run `bash ~/.aidlc-kit/verify-plan.sh <plan>`. It checks that:
- every file to modify exists (and suggests the real path when a name is close);
- files to create are new (while the plan is a draft);
- classes and members marked "changed" in "Classes and methods affected" exist in the code;
- cited lessons (S-…, L-…) and research notes (R-…) exist;
- "verified" facts show evidence and no fact is "unknown".
Fix every ✗ before the gate. No kit on the machine: do the same checks by hand.

## H5. Consistency
- Every acceptance criterion → a task → a test; every task → a file in the Files tables; the diagrams match
  the tables.
- One spelling per name everywhere (class, file, route, provider, endpoint).
- Versions, counts, limits and sizes come from a source, never from memory.

## H6. While building
- Before you use a symbol, find its definition; before you use a package API, check the installed version.
- Run the analyzer after each phase: invented APIs show up as errors. Fix the cause; never silence it.
- Re-ground at each phase start (rule §4). After the build: `bash ~/.aidlc-kit/verify-plan.sh <plan> --done`
  (every planned file exists, no file outside the plan changed).

## H7. Report honestly
Quote real output. List what was not run or not verified, and why. Never "all good" without the check.

## Thinking summary line
`- Verification: <n> facts verified · <n> assumptions (listed at the gate) · 0 unknown · verify-plan.sh ✓`

## Rules
- "Unknown" and a question are always better than a plausible guess.
- Evidence you did not see in this session does not count: open it again.
- A hallucination caught becomes an inbox row (trigger: failed-check) with what was invented and what is true.
