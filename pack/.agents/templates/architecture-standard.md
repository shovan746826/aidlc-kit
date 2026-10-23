---
name: project-architecture
description: <Project> architecture standard (<stack>): <pattern, state management, API layer, routing in one line>. Written from this project's code and the user's architecture choice. MANDATORY: read it before planning or writing any code.
---
<!-- aidlc-kit:standard=generated · the project's own standard (architecture choice <YYYY-MM-DD>, ADR-<NNN>) · project-owned: init-project.sh never overwrites it -->

# <Project> Architecture Standard

> Written by `project-analysis` A5 from this project's code, with `path:line` examples. Every section names
> its **Source**: `yours` (this project's code) or `AI-DLC` (the kit standard for the stack, shortened to
> what applies, its code in `reference/`). Change this file only through an approved plan.
> Keep it under about 20 KB: it is read before every plan. Long code examples and rarely needed topics go into
> `reference/<topic>.md`; the section that needs one names it and says when to read it.

**Contents:** 1 Overview · 2 Directory structure · 3 Shared / core module · 4 Feature module · 5 Data flow ·
6 Naming · 7 Implementation patterns · 8 Routing · 9 API integration · 10 State management · 11 Error
handling · 12 Storage · 13 Entry point · 14 Design system · 15 Assets · 16 Shared base classes and global
features · 17 Imports · 18 New-feature checklist · 19 Placement rules · 20 Commands · 21 Testing ·
22 Dependencies and security

## 1. Architecture overview
Source: yours | AI-DLC
| Layer | Technology | Version |
|---|---|---|

## 2. Top-level directory structure
Source: … (a tree with one comment per folder)

## 3. Shared / core module structure
Source: …

## 4. Feature / module structure
Source: … (the exact folders and files of one feature)

## 5. Data flow
Source: … (a diagram and numbered steps, e.g. screen → state holder → repository → API and back)

## 6. Naming conventions
Source: … (files, classes, variables, state holders, routes, tests)

## 7. Implementation patterns
Source: … (one short code example per layer, each with `path:line`)

## 8. Routing / navigation
Source: …

## 9. API integration
Source: … (the client, headers and authentication, how an endpoint is added, error mapping)

## 10. State management
Source: … (the library, where state lives, how a screen reads and changes it)

## 11. Error handling and user feedback
Source: …

## 12. Storage and session
Source: … (local storage, tokens, where secrets go)

## 13. Entry point and startup
Source: …

## 14. Design system / UI conventions
Source: … (colors, sizes, fonts, shared widgets)

## 15. Assets and static files
Source: …

## 16. Shared base classes and global features
Source: …

## 17. Import and module dependency rules
Source: …

## 18. New-feature checklist
Source: … The ordered steps to add a feature. Every implementation plan uses this order for its task phases.
1. …

## 19. Placement rules
Source: …
| You add | It goes to |
|---|---|

## 20. Build, run, lint and test commands
Source: … (the commands the project profile lists for verification)

## 21. Testing standard
Source: … (what is tested, how, where; helpers and fakes)

## 22. Dependencies and security
Source: … (how packages are added, what is not allowed, secrets)

<!--
Companion file .agents/rules/20-architecture.md (write it too; do not copy this comment into SKILL.md):
  frontmatter:  trigger: always_on
                description: <Project> architecture hard rules (<stack>). The full standard is in
                .agents/skills/project-architecture/SKILL.md.
  first line after the frontmatter: an HTML comment with "aidlc-kit:standard=generated · project-owned"
  title:        # Architecture Rules: <Project> (mandatory)
  body:         10–20 short rules a reviewer can check, taken from the sections above
-->
