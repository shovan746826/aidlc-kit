---
trigger: always_on
description: Temporary architecture rules until this project's architecture standard is generated (see .agents/skills/project-architecture/SKILL.md).
---
<!-- aidlc-kit:standard=generic · NOT GENERATED YET · project-owned: init-project.sh never overwrites this file (use --update-architecture) -->

# Architecture Rules (temporary: the standard is not generated yet)

1. Read `.agents/skills/project-architecture/SKILL.md`. While it says "NOT GENERATED", generate it during
   project analysis (existing project) or the architecture stage (new project), with the user's approval.
2. Until then, follow the existing code exactly: copy the structure, naming and patterns of the most
   similar existing file.
3. Never introduce a new pattern, library, folder layout or naming style without an approved plan.
4. Keep feature code out of shared/core modules; keep features self-contained.
5. Never hardcode URLs, secrets, colors or user-facing text where the project has a central place for them.
6. Every change comes with tests in the project's existing test style.
