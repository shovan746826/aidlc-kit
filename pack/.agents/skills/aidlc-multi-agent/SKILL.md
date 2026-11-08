---
name: aidlc-multi-agent
description: AI-DLC multi-agent protocol for the lead agent. When and how to use helper agents (analyst, builder, tester, debugger, researcher, reviewer) so one prepares the next step while another builds the current one, tests run and failures get debugged at the same time. Covers the Agent plan modes (single, pipeline, parallel), the handoff and result cards, file ownership, checking every result, blocked helpers, and notes for Claude Code and Antigravity. Use when a plan's Agent plan is pipeline or parallel, or the user asks to use agents.
---
<!-- aidlc-kit:managed · replaced when the kit is updated -->

# Multi-agent work (for the lead agent)

You are the **lead**: the agent the user talks to. Only you ask the user, show gates, record approvals, change the
plan, the state file and the audit log, and mark tasks ✅ (`00-aidlc-core.md` §11). Helpers do one job each and
report back. Every stage, gate and check of the normal flow stays the same.

## M1. Choose the mode (the plan's Agent plan line)
| Mode | Use it when | How it runs |
|---|---|---|
| `single` | light plans, small fixes, 3 tasks or fewer, tightly linked edits | you do everything (the normal flow) |
| `pipeline` | most full plans | one builder at a time; an analyst prepares the next task; a tester checks each phase in the background; a debugger takes failures; the reviewer at C4 |
| `parallel` | large work with independent parts | pipeline, plus up to 3 builders at once on tasks with no `needs:` between them and no shared file |
- Helpers cost tokens of their own (multi-agent work can use many times the tokens of one agent). Use one only
  where it pays: wide reading, long output (test logs), or work that can really run at the same time. A small
  read, a one-file change or a task that needs the conversation: do it yourself.
- At most 4 helpers at once (at most 3 builders), unless the user agrees to more.
- Write the mode, its reason and the roles in the plan's §14 (`**Agent plan:** pipeline · …`), and `· needs: T1, T2`
  on every task that must wait for others. `verify-plan.sh` checks the order and, in parallel mode, that tasks
  which can run at the same time never change the same file. The user approves the mode with the plan.

## M2. Roles
| Role | Job | Changes | Start it |
|---|---|---|---|
| `aidlc-analyst` | maps an area; prepares the next task (files, definitions, callers, exact edits, risks, the test to write) | its notes | planning (F1, F3), and one task ahead in C2 |
| `aidlc-builder` | builds one task test first, only in the files you give it, runs its Check | the task's files | C2, C3, fixes |
| `aidlc-tester` | baseline, phase checks, full verification; failures with the exact output | its notes | C1, end of each phase, C5 |
| `aidlc-debugger` | reproduces a failure, root cause with `path:line`, the smallest fix (doesn't apply it) | its notes | a failed check; a bug (B2) |
| `aidlc-researcher` | sources and findings for one question | its notes | decisions, packages, APIs (`aidlc-research`) |
| `aidlc-reviewer` | the independent review (`10-quality-gates.md` §3) | nothing | C4 |
Notes: `aidlc-docs/work/<item>/agents/<task>-<role>.md`. Helpers can't start helpers and can't ask the user.

## M3. Handoff card (you → helper)
A helper doesn't see the conversation: the card and the files are all it has. Name every file and the lessons
that apply (helpers don't load the shared lessons index); never paste file contents into the card.
```
AI-DLC handoff · <work item> · <task> · <role>
Goal: <one line>
Read: <plan path> §14 <task> · <notes> · <files> · lessons <IDs that apply>
Own: `<file>`, …  (builder) | none
Done when: <the task's Check: command and expected result>
Return: the result card; details → aidlc-docs/work/<item>/agents/<task>-<role>.md
```

## M4. Result card (helper → you)
```
AI-DLC result · <task> · <role> · DONE | BLOCKED | FAILED
Changed: `<file>` … | none
Evidence: <command → quoted line> · <path:line>
Found: <up to 5 bullets>
Needs the lead: <a plan change, a question for the user, or none>
Notes: <path or none>
```
Long findings stay in the notes file; pass its path on to the next helper instead of copying it.

## M5. The loop, stage by stage
- **Planning** (F1, F3, new project): one analyst per area, all at once; the researcher compares options. You write
  the documents from their notes. While the user reviews a gate, an analyst may prepare the next stage (read
  only); if the user changes the document, check its notes again.
- **Bug** (B2): up to 3 debuggers, one hypothesis each. You pick the root cause that has the evidence.
- **C1:** the tester runs the baseline while an analyst prepares the first tasks.
- **C2:** start a builder on the next ready task (everything it needs is ✅, no running task owns its files) and an
  analyst on the task after it. Mark the task `🔄 [IN PROGRESS] (builder)` before you start it. When a result
  comes, check it (M6), mark ✅, start the next. At the end of a phase, the tester runs the quick check in the
  background; on a failure, a debugger finds the cause and a builder applies the fix. Builders go on only with
  tasks the failure doesn't touch. A small task (one line of wiring) you may build yourself.
- **C3:** a builder writes the remaining tests; the tester runs them.
- **C4 + C5:** the reviewer and the tester's full verification run at the same time; then fix the gaps (a builder),
  run `verify-plan.sh <plan> --done` yourself and write the reports.
- In chat, say what is running: `🔄 T3 builder · 🔍 T4 analyst · 🧪 phase 1 tester`.

## M6. Check every result: trust the files, not the claim
- Builder: `git diff --stat` shows only its files; its Check's output line is in the card. Run the check again
  when it matters (always before a phase is reported done).
- Analyst and researcher notes are leads, not proof: the builder reads the files again before it edits.
- Debugger: the cause has `path:line` and a reproduction.
- A claim without evidence goes back once; then do that part yourself. Never mark ✅ on a helper's word alone.

## M7. Parallel builders
- Only tasks whose needs are all ✅ and whose files no running task owns. Every builder works in the same folder:
  no git worktrees (they start from the default branch, without the uncommitted plan and code).
- Anything the plan doesn't decide (a name, a shape, an error message) → the builder returns BLOCKED and you decide
  once for all builders, or ask the user. The C4 review checks that the parts fit together.
- The app and its backend are separate repositories: one lead session per repository; the contract in the
  integration plan keeps them in step.

## M8. Blocked, failed or lost helpers
- BLOCKED for a file outside the plan → the plan change procedure (`aidlc-construction`), then a new handoff.
- Two helpers disagree → decide from the evidence, or ask the user.
- A helper never returned (the session ended) → on resume, read its notes and `git diff` of its files, then
  finish the task or start it again.

## M9. Tool notes
- **Claude Code:** the kit installs the roles in `~/.claude/agents/`. Start one with the Agent tool
  (`subagent_type: aidlc-<role>`, the handoff card as the prompt); several Agent calls in one message run at the
  same time, and each result arrives when it is done. The plan gate also runs for subagents and keeps them out of
  the plan, the state file and, for read-only roles, the code. Read-only roles start without CLAUDE.md and read
  only what the handoff names. Agent teams (experimental) can use the same roles as teammate types; the same
  rules apply.
- **Antigravity** (App and CLI): the same roles are in `~/.gemini/config/agents/`. Start one with
  `invoke_subagent` (its type name `aidlc-<role>`, the handoff card as the prompt) and keep the same workspace (no
  branch). Read-only roles have no file-writing tools there: they put their notes after the result card; save
  them if a builder needs them. `/teamwork` runs its own team without the AI-DLC gates: don't use it in an AI-DLC
  project.
- **A tool without subagents:** use `single`.

## M10. Learn
In the reflection (C6): the mode, the helpers you used and the token line (`tokens.sh` counts subagents). Did
they save time? A helper that caused rework (a missed file, a claim without evidence) → an inbox row with the
evidence (`30-learning.md` §2).
