# Project Profile: <app name>

> analyzed: YYYY-MM-DD · by: <agent> · kind: brownfield | greenfield · standard: flutter | android | ios | generic
> Facts only, with paths. Write "unknown" instead of guessing. Never write secret values.
> Keep it under about 10 KB: it is read in every session (one row per feature; the details stay in the code).

## 1. Summary
- <3–5 bullets: what the app is, stack, size, health, biggest risks>

## 2. Identity
| Item | Value |
|---|---|
| App name | |
| Package / bundle id | |
| Version | |
| Platforms | android · ios · web · macos · windows · linux |
| Min OS versions | Android API … · iOS … |
| Repository / main branch | |

## 3. Stack
| Layer | Technology | Version (resolved) | Notes |
|---|---|---|---|
| State management | | | |
| Routing / navigation | | | |
| Networking | | | |
| Local storage | | | |
| UI / responsive | | | |
| Code generation | | | |
| Testing | | | |

## 4. Architecture
- Standard: `.agents/skills/project-architecture/SKILL.md` (<name>) · conformance: high | partial | low
- Reference implementation (copy its patterns): `<path or none>`
- Structure (top levels; skip build and generated folders):
```
<tree>
```

## 5. Feature registry
<!-- Updated after every completed work item (aidlc-construction C6). -->
| Feature | Folder | Screens | Routes | API endpoints | State holders | Notes |
|---|---|---|---|---|---|---|

## 6. Conventions observed
| Topic | Convention | Example (path:line) |
|---|---|---|

## 7. Deviations from the standard
| Deviation | Where (path) | Impact | Recommendation (keep · fix in a work item) |
|---|---|---|---|

## 8. Dependencies and risks
| Package | Constraint | Resolved | Risk (any-constraint · legacy API · duplicate purpose · outdated) |
|---|---|---|---|

## 9. Configuration and environments
| Item | Where | Notes |
|---|---|---|
<!-- flavors, environment files, base URLs, Firebase projects, signing: write "present in <file>", never the value -->

## 10. Verification commands
| Purpose | Command | Notes |
|---|---|---|
| Dependencies | | |
| Code generation | | only if the project uses it |
| Analyzer / lint | | |
| Tests | | |
| Build (Android) | | |
| Build (iOS) | | macOS only |

## 11. Baseline
| Date-time | Check | Result (counts: errors / warnings / infos · tests passed / failed · build) |
|---|---|---|

## 12. Tests and CI
- Test files: <count> · kinds: unit / widget / integration · covered areas: …
- CI: <pipelines or none>

## 13. Hotspots and risks
- <large files, TODO clusters, duplicated code, fragile areas: with paths>

## 14. Glossary
| Term | Meaning |
|---|---|

## 15. Architecture choice
<!-- Filled by project-analysis A5. Empty = not chosen yet. -->
- Decision: yours | AI-DLC (<stack>) | mix · Date: YYYY-MM-DD · ADR: `aidlc-docs/project/decisions/ADR-<NNN>-architecture-choice.md`

| Area | This project | AI-DLC standard | Choice | Reason |
|---|---|---|---|---|
| Architecture and folders | | | yours / AI-DLC | |
| API calling | | | | |
| State management | | | | |
| Routing | | | | |
| Storage and session | | | | |
| Error handling and feedback | | | | |
| Dependency injection | | | | |
| Design system | | | | |
| Testing | | | | |

---
**Ready to approve?** ☐ every section filled or "unknown" ☐ deviations have paths ☐ verification commands
checked ☐ baseline recorded ☐ feature registry complete ☐ no secret values
