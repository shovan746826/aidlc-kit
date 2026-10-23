<!-- AIDLC:BEGIN · managed by aidlc-kit (~/.aidlc-kit) · re-run install.sh to update, uninstall.sh to remove -->
## AI-DLC: plan before you build (every project)
1. If the project has `AGENTS.md` or `.agents/rules/`, read and follow them before anything else. Claude Code
   does not load `.agents/` by itself.
2. Before you create, change or delete any file, show a plan and wait for the user's explicit approval
   ("approve", "proceed", "go ahead", "do it", or a plain "yes" / "ok" reply to the plan). Reading,
   searching and answering never need a plan.
3. Projects with the AI-DLC pack (`.agents/rules/00-aidlc-core.md`): follow its workflow. `/aidlc` shows the
   status and routes requests.
4. Projects without it: for a new project, a feature, or anything touching more than 3 files, suggest
   `/aidlc init` first. For smaller changes, show a quick plan (goal and what is out of scope · files to
   create or change, one line each · how you will verify · risks and how to undo) and wait for approval.
5. Ask before you plan when anything is unclear: numbered questions with options and a ★ recommended answer.
6. Learn: if the project has `aidlc-docs/brain/`, read its `INDEX.md` and `.agents/brain/shared/INDEX.md`
   before planning, and record corrections and failures as lessons (`.agents/rules/30-learning.md`).
7. Tokens: turn each task into a short brief (goal · must · done when), read only what it needs, keep
   command output short, and use one session per task. Never skip a requirement or a check to save tokens.
8. If the user says "skip the plan" for a task, confirm once, then proceed.
<!-- AIDLC:END -->
