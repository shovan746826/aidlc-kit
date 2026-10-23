<!-- AIDLC:BEGIN · managed by aidlc-kit (init-project.sh) · text outside this block is yours and is kept -->
# AI-DLC: instructions for every AI agent

This project uses **AI-DLC** (AI-Driven Development Lifecycle).
**Rule #1: plan first.** No file is created or changed without a plan the user approved.

Before doing anything else, read and follow these rule files, in this order:
1. `.agents/rules/00-aidlc-core.md`: workflow, request routing, questions, approvals, live status
2. `.agents/rules/10-quality-gates.md`: review, verification, definition of done, code preservation
3. `.agents/rules/20-architecture.md`: this project's architecture rules
4. `.agents/rules/30-learning.md`: the brain (recall lessons, capture, reflect)
5. `.agents/rules/40-token-efficiency.md`: the task brief and lean context (tokens)

Then:
- **Current work and next action:** `aidlc-docs/aidlc-state.md`
- **Brain (read before every plan):** `aidlc-docs/brain/INDEX.md` and `.agents/brain/shared/INDEX.md`
- **Architecture standard** (read before any planning or code): `.agents/skills/project-architecture/SKILL.md`
- **Workflow skills:** `.agents/skills/`: `project-analysis`, `aidlc-new-project`, `aidlc-feature`,
  `aidlc-bugfix`, `aidlc-construction`, `aidlc-release`,
  `aidlc-think`, `aidlc-reflect`, `aidlc-research`, `aidlc-prompt`
- **Document templates:** `.agents/templates/`
- **All analyses, plans and reports:** `aidlc-docs/`
<!-- AIDLC:END -->
