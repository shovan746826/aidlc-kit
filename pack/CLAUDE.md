<!-- AIDLC:BEGIN · managed by aidlc-kit (init-project.sh) · text outside this block is yours and is kept -->
# AI-DLC (Claude Code)

@AGENTS.md
@.agents/rules/00-aidlc-core.md
@.agents/rules/10-quality-gates.md
@.agents/rules/20-architecture.md
@.agents/rules/30-learning.md
@.agents/rules/40-token-efficiency.md
@.agents/rules/50-anti-hallucination.md
@aidlc-docs/brain/INDEX.md
@.agents/brain/shared/INDEX.md

Claude Code notes:
- Claude Code does not list skills from `.agents/skills/` by itself. Read the SKILL.md that the routing table
  in `00-aidlc-core.md` names. The `/aidlc` command (installed by the kit) does this routing for you.
- When the AI-DLC hooks are installed, edits to project files are blocked unless the approved plan lists
  them. If an edit is blocked, follow the message. Never work around the gate.
- For review and gap analysis, use the `aidlc-reviewer` agent if it is available.
- For question rounds you may use the AskUserQuestion tool (up to 4 questions per call). Still record every
  answer in `questions.md`.
- When you write a plan, a hook runs `verify-plan.sh` on it and shows you invented paths, classes or IDs:
  fix them before the gate.
- Tokens: you may suggest `/context` (what fills the context), `/compact <focus>` at the end of a phase, and
  `/clear` (a new session) after a work item.
<!-- AIDLC:END -->
