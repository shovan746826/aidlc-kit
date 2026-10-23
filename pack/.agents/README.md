# `.agents/`: the AI-DLC pack

This folder tells every AI coding agent (Claude Code, Antigravity, Gemini, and others that read `AGENTS.md`)
how to work in this project: plan first, ask before planning, wait for approval, then build, test and verify.

| Path | What it is | Owner |
|---|---|---|
| `rules/00-aidlc-core.md` | Workflow: routing, plan-first, questions, approvals, live status, state | kit (replaced on update) |
| `rules/10-quality-gates.md` | Code preservation, review, verification, done, error recovery | kit |
| `rules/20-architecture.md` | Architecture hard rules for **this** project | **project** (never overwritten) |
| `rules/30-learning.md` | The brain: recall lessons, capture, reflect, batch approval | kit |
| `rules/40-token-efficiency.md` | Tokens: the task brief; read, run and write lean; small sessions; measure | kit |
| `rules/50-anti-hallucination.md` | Evidence for every claim, verify before use, plan check, honest reports | kit |
| `skills/project-architecture/` | The full architecture standard for **this** project (Flutter: complete code in `reference/`) | **project** |
| `skills/project-analysis/` | How to analyze the codebase → `aidlc-docs/project-profile.md` | kit |
| `skills/aidlc-new-project/` | New project: brief, business plan, requirements, integration plan, architecture, delivery plan | kit |
| `skills/aidlc-feature/` | Feature or change: questions, requirements, integration plan, implementation plan | kit |
| `skills/aidlc-bugfix/` | Bug: triage, root cause, fix plan with a regression test | kit |
| `skills/aidlc-construction/` | Carry out an approved plan: live status, tests, review, verification | kit |
| `skills/aidlc-release/` | Release: version, changelog, builds, rollout, monitoring | kit |
| `skills/aidlc-think/` | Thinking protocol: options, decision table, pre-mortem, self-review | kit |
| `skills/aidlc-reflect/` | Reflection and brain care: lessons, counters, scorecard, sharing | kit |
| `skills/aidlc-research/` | Research protocol: official sources first, saved notes | kit |
| `skills/aidlc-prompt/` | Prompt optimizer: the task brief and the prompt rewriter | kit |
| `skills/aidlc-anti-hallucination/` | Full anti-hallucination protocol for large or complex work | kit |
| `brain/shared/` | Copy of the shared brain (lessons for all projects), read-only | kit |
| `templates/` | Templates for every AI-DLC document | kit |
| `.aidlc-version` | Kit version and standard installed here | kit |
| `.backup/` | Copies of files the kit replaced (git-ignored) | kit |
| `archive/` | Old rule/skill files moved aside by `init-project.sh --migrate` | you |

**How to change things**
- Architecture for this project: edit `skills/project-architecture/SKILL.md` and `rules/20-architecture.md`.
- Workflow for all projects: edit the kit source, then re-run `init-project.sh` on each project.
- Kit-owned files edited here are backed up to `.backup/` and replaced on the next update.

Everything the agents write (analyses, plans, reports, the project brain in `aidlc-docs/brain/`) lives in
`/aidlc-docs/`. Commit both folders.
