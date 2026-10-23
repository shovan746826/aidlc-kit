---
name: project-architecture
description: Architecture standard for this project. It has no ready-made house standard yet, so this file explains how to generate it from the code (existing project) or from the approved architecture document (new project). MANDATORY: read it before planning or writing any code.
---
<!-- aidlc-kit:standard=generic · NOT GENERATED YET · project-owned copy: init-project.sh never overwrites it (use --update-architecture) -->

# Project Architecture (generic: NOT GENERATED YET)

> **Status: not generated.** Until this file is replaced with the project's real standard:
> 1. Follow the existing code exactly: find the most similar existing file and copy its structure, naming
>    and patterns.
> 2. Never introduce a new pattern, library, folder layout or naming style without an approved plan.
> 3. Generate the standard (instructions below): in an existing project during
>    `.agents/skills/project-analysis/SKILL.md`; in a new project in stage NP6 of
>    `.agents/skills/aidlc-new-project/SKILL.md`.

## How to generate this standard
1. **Source.** Existing project: read 2–3 representative modules end to end (entry point → UI → logic →
   data). New project: the approved `aidlc-docs/project/05-architecture.md`.
2. **Write** the sections below into this file, with real paths and short code examples from this project
   (`path:line`). Keep the section names, so every project's standard reads the same way as the Flutter,
   Android and iOS house standards.
3. **Rules.** Replace `.agents/rules/20-architecture.md` with 10–20 short, checkable hard rules taken from
   the standard. Keep its frontmatter (`trigger: always_on`).
4. **Marker.** Change the marker line at the top of both files to `aidlc-kit:standard=generated`.
5. **Gate.** Show both files to the user. They apply only after explicit approval (audit log entry).

### Required sections
1. Architecture overview: stack table (layer → technology → version)
2. Top-level directory structure (tree)
3. Shared / core module structure
4. Feature / module structure (exact folders and files per feature)
5. Data flow (diagram + numbered steps)
6. Naming conventions (files, classes, variables, routes, tests)
7. Implementation patterns: a code example for each layer, taken from the project
8. Routing / navigation (apps) or request routing (backends)
9. API integration: adding an endpoint, standard headers, authentication
10. State management or data access rules
11. Error handling
12. Storage
13. Entry point and startup
14. Design system / UI conventions (if there is a UI)
15. Assets and static files
16. Shared base classes and global features
17. Import and module dependency rules
18. New-feature checklist (ordered steps; this becomes the task-plan order)
19. Placement rules (table: what you add → where it goes)
20. Build, run, lint and test commands
21. Testing standard (what, how, where)
22. Dependencies and security
