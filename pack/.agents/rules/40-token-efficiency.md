---
trigger: always_on
description: AI-DLC token efficiency. Turn each request into a short task brief, read and run only what the task needs, write lean, keep sessions small, measure. Never trade correctness for tokens.
---
<!-- aidlc-kit:managed · replaced when the kit is updated -->

# AI-DLC Token Efficiency (mandatory)

Most tokens are not the user's prompt. They are the context the model reads again on every call: files you
read, tool output and the whole conversation. Keep that small, and avoid rework.
**Never drop a requirement, a check or a test to save tokens.**

## 1. Brief first
Before work that changes files or needs more than a short answer, write the task brief
(`.agents/skills/aidlc-prompt/SKILL.md`): at most 7 lines at the top of your reply, then continue.
Plain questions get a direct answer and no brief.

## 2. Read smart
- Search first (file names, symbols, `grep`), then read only the parts of big files that you need.
- Never read an unchanged file twice in a session. Never paste file contents back into the chat.
- Reuse what is already written: the brief, the plan, `aidlc-docs/project-profile.md`, the brain indexes.
- Architecture standard: its rules first; open its `reference/` code only when you copy that code.

## 3. Run quiet
- Show only the output that matters: `flutter test --reporter failures-only` (it keeps the pass count),
  `flutter analyze`, long builds `… 2>&1 | tail -n 40`, Gradle `-q`, `xcodebuild -quiet`.
- Full output only when something fails, and then only the failing part.

## 4. Write lean
- Change only the lines that change. Never rewrite a whole file for a small edit.
- Lead with the result. Link documents by path instead of repeating them. Keep gate cards short.

## 5. Small sessions
- One work item per session. When it is completed, suggest a new session: the state file and the brain
  carry everything over.
- Wide read-only searches: use a search subagent if your tool has one, and ask it for paths and short
  excerpts only.

## 6. Measure and learn
Claude Code: the completion report shows
`bash ~/.aidlc-kit/tokens.sh "<project root>" --work-item <id> --line`. Other tools: "not measured".
A work item that used more than twice the usual tokens → an inbox row (trigger: surprise) that says why.
