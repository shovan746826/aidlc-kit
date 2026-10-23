---
name: aidlc-prompt
description: Prompt optimizer. Turns the user's request into a short task brief that every later step works from (automatic before real work), and on request rewrites any prompt into a clear, compact prompt for any AI tool. Use before planning or building, or when the user says "optimize prompt", "improve this prompt" or /aidlc prompt.
---
<!-- aidlc-kit:managed · replaced when the kit is updated -->

# Prompt Optimizer: task brief and prompt rewriter

**Goal:** the best result with the fewest tokens. A clear brief prevents rework (the most expensive tokens)
and says exactly what to read. Compress the words, never the meaning.

## P1. Task brief (automatic)
**When:** before any work that changes files or needs more than a short answer. Not for plain questions.
1. Read the request and what you already have: the state file, the profile, the brain indexes, earlier
   answers. Do not read code yet, unless you must find what a name refers to.
2. Write the brief in the format below:
   - Keep the user's exact names, numbers, paths, error text and quoted words. Never paraphrase them.
   - Turn vague references ("it", "that screen", "like before") into real paths or IDs, or ask.
   - One goal per brief. A mixed request becomes one brief per work item; ask for the order.
   - **Must** holds every requirement and constraint of the request: nothing is dropped. Add a requirement
     only when the standard or a lesson demands it, and name the source ("standard §9", "S-015").
   - **Context** lists only what the task needs: paths, profile sections, lesson IDs. Never pasted content.
   - **Done when** can be checked: a test, a command result, a visible behaviour.
   - **Unknowns** that change the result become questions (`00-aidlc-core.md` §4) before any plan.
3. Show it at the top of your reply, then continue with the route (`00-aidlc-core.md` §2). For a work
   item, also save it at the top of the work item's `questions.md`.

```
🎯 Brief · <route> · depth <light|full>
Goal: <the outcome the user wants, one sentence, in their key words>
Must: <requirements and constraints; exact names, numbers and texts kept>
Out of scope: <what is not included, or "nothing stated">
Context: <only the paths, profile sections and lesson IDs this task needs>
Done when: <how the result is checked>
Unknowns: <questions that change the result, or "none">
```
A small task (one or two files, no unknowns) may use 2–3 lines: Goal, Context, Done when.

## P2. Work from the brief
- Questions, plans and reviews refer to the brief instead of repeating the request.
- Read what **Context** lists, then only what the code leads you to. If the brief turns out wrong, update
  it in one line instead of starting over.
- The completion report checks **Done when** item by item.

## P3. Rewrite a prompt (on request)
**When:** `/aidlc prompt <text>`, "optimize prompt: …", "improve this prompt".
1. Find the intent: the goal, who it is for, the inputs, the expected output.
2. Rewrite it with these parts (leave out empty ones):
   ```text
   Goal: <what to achieve and why>
   Context: <facts, files and constraints the model needs; long material before the question>
   Requirements:
   - <each requirement, specific and testable>
   Constraints: <what to keep or avoid; style; limits>
   Output: <format, length, language>
   Done when: <how to check the answer>
   ```
   - Be explicit and specific. Say what to do, not only what to avoid. Give the reason when it matters.
   - Keep every fact, name, number and example of the original; remove filler and repetition.
   - Never invent facts. Missing information becomes `[fill in: …]`.
3. Reply with the optimized prompt in a code block, then 2–3 bullets "What changed", the gaps to fill, and
   the size before → after (≈ characters ÷ 4 tokens; an estimate).

## Rules
- Correctness first: a shorter brief or prompt that loses a requirement is wrong.
- The brief is a working note: no headings, no repetition, at most 7 lines.
