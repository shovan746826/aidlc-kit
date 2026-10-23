<!-- AIDLC:BEGIN · managed by aidlc-kit (init-project.sh) · text outside this block is yours and is kept -->
# AI-DLC (Gemini CLI, Antigravity, Gemini in Android Studio)

@./AGENTS.md
@./.agents/rules/00-aidlc-core.md
@./.agents/rules/10-quality-gates.md
@./.agents/rules/20-architecture.md
@./.agents/rules/30-learning.md
@./.agents/rules/40-token-efficiency.md
@./.agents/rules/50-anti-hallucination.md
@./aidlc-docs/brain/INDEX.md
@./.agents/brain/shared/INDEX.md

Notes:
- Antigravity loads `.agents/rules/` and `.agents/skills/` by itself. Gemini CLI imports the files above.
  If you see the lines above as plain text, open and read those files now.
- Skills live in `.agents/skills/<name>/SKILL.md`. If your tool does not list them, read the one that the
  routing table in `00-aidlc-core.md` names.
- Antigravity: work in Planning mode and let the agent ask for your review before it changes files.
- Gemini CLI tokens: `/stats` shows the token use, `/compress` summarizes the conversation.
<!-- AIDLC:END -->
