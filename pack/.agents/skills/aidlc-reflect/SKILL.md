---
name: aidlc-reflect
description: Reflect at the end of every work item and curate the brain. Compares plan and result, turns captured evidence into lessons, merges duplicates, updates helpful and harmful counters, adds the scorecard row, proposes lessons for batch approval, shares approved lessons, proposes promotions and maintains the brain. Use at construction stage C6, at the end of a bug fix or release, when the user says "reflect" or "maintain the brain", or after 10 work items.
---
<!-- aidlc-kit:managed · replaced when the kit is updated -->

# Reflect and Curate the Brain

Built on *Reflexion* (agents learn from feedback written in memory) and *ACE* (a playbook of small,
numbered lessons updated one at a time, with helpful/harmful counts).

**Inputs:** the plan and its plan changes, `test-report.md`, `review-report.md`, `aidlc-docs/audit-log.md`,
`aidlc-docs/brain/inbox.md`, the user's corrections in the conversation.
**Outputs:** `reflection.md` in the work item folder, lesson files, `INDEX.md` lines, a `metrics.md` row,
and the **🧠 Proposed lessons** block in the completion report.

## R1. Gather the evidence (facts only)
Plan vs result (plan changes, skipped or blocked tasks), failed checks and their causes, review findings,
the user's corrections (their words), inbox rows, and the lessons applied (from the plan's Thinking
summary). Write sections 1–4 of `reflection.md` (template `.agents/templates/reflection.md`).

## R2. Root causes
For each problem, ask "why?" until you reach something a lesson can prevent: a rule, a check, a pattern,
or a question to ask earlier. That usually takes 2–4 whys.

## R3. Write lessons
For each root cause or reusable success:
1. **Search first:** look in both indexes for the same topic.
   - Same lesson exists → no copy. Raise its counter, update `last_verified`, and improve its text if the
     new evidence adds something.
   - It contradicts a lesson → propose to edit or retire the old one, with the evidence.
   - New → `aidlc-docs/brain/lessons/L-<next number>-<slug>.md` from `.agents/templates/lesson.md`,
     `status: proposed`.
2. **General but concrete:** it must help on the next task of the same kind.
   Bad: "fix line 40 of home_screen.dart". Good: "check context.mounted after await before showing dialogs".
3. One idea per lesson, title written as advice, evidence required, no secrets or personal data.
4. **Scope:** `shared` for stack, tool or general engineering lessons; `project` for this project's domain,
   APIs and team preferences. A shared lesson is copied into **every** project: write it without this
   project's or client's name, people, hosts, URLs, endpoint paths or business data (`brain.sh push` refuses
   lessons with an email address, an IP address, a home-folder path or an `http://` address).
5. **Confidence:** high = proven by a check or seen again; medium = clear cause, seen once; low = likely.

## R4. Counters
For each lesson applied in this work item: `helpful +1` if it prevented a problem or saved time;
`harmful +1` if following it caused a problem (and propose an edit or retirement). Update ✓/✗ in the index.

## R5. Scorecard
Add the row to `aidlc-docs/brain/metrics.md`, with the tokens from C6 (the `tokens.sh` line, or "n/a").
Once there are 10 or more rows, update the trend table (previous 10 vs last 10). Increase "Work items since
maintenance". Tokens more than twice the median of the last 10 rows → an inbox row (trigger: surprise) that
names the cause (big files read whole, long logs, a long session, rework).

## R6. Propose (in the completion report)
```
🧠 Proposed lessons (reply: approve lessons · approve L-021 L-022, reject L-023 · edit L-024: …)
- L-021 · pitfall · flutter · <title> · evidence: <short> · scope: project
- update S-003 · helpful +1 (prevented …)
- retire L-007 · contradicted by <evidence>
Scorecard: plan changes 1 (avg 1.4 → 1.1) · verified first time ✅ · corrections 0
```
Proposed lessons do not go into `INDEX.md` yet.

## R7. Apply the user's decision
- Approved → `status: active`, add its line to the right `INDEX.md` section, log `APPROVED` in the audit log.
- Edited → apply the edit, then the same as approved.
- Rejected → delete the proposed file and log it, with the reason if one was given.
- Remove the handled rows from `inbox.md`.

## R8. Share approved shared-scope lessons
- `~/.aidlc-kit/brain.sh` exists → run `bash ~/.aidlc-kit/brain.sh sync "<project root>"`. It copies new
  shared lessons into the shared brain with an `S-` id and refreshes `.agents/brain/shared/`.
- Otherwise tell the user which lesson files to copy into `~/.aidlc-kit/brain/lessons/`.

## R9. Promote
A lesson with `helpful ≥ 3` and `harmful = 0` → propose making it permanent: a rule in
`.agents/rules/20-architecture.md`, a section in the architecture skill, or (shared) a kit standard. Only
with the user's approval.

## R10. Maintain (grow and refine)
**When:** 10+ work items since maintenance, an index over budget, a lesson past its `recheck` date, or the
user asks.
1. Merge duplicates: keep the clearer lesson, add up the counters, retire the other.
2. Retire lessons with harmful > helpful, or that new evidence contradicts.
3. Re-check lessons past their `recheck` date (`aidlc-research`): confirm (new dates) or retire.
4. Shorten long index lines to stay within budget.
5. Propose everything as one batch, apply after approval, and set "Last maintenance" in `metrics.md`.

## Rules
- Facts and evidence only. No blame and no invented lessons.
- Change single lines and files. Never rewrite the whole index at once.
- Never edit `.agents/brain/shared/` (it is a copy).
