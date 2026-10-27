---
trigger: always_on
description: Backend baseline rules until this project's backend standard is generated (see .agents/skills/project-architecture/SKILL.md).
---
<!-- aidlc-kit:standard=backend · NOT GENERATED YET · project-owned: init-project.sh never overwrites this file (use --update-architecture) -->

# Architecture Rules: backend baseline (mandatory)

Standard: `.agents/skills/project-architecture/SKILL.md`. While it says "NOT GENERATED", generate it during
the project analysis (new project: NP6), with the user's approval. Until then follow the existing code exactly
and never introduce a new pattern, library or folder layout without an approved plan.

## API
1. Every endpoint validates its input at the boundary (schema, DTO or form request) and answers with the
   project's error format.
2. Every endpoint checks authentication and authorization. A public endpoint is named as public in the plan.
3. An endpoint change updates the API contract (OpenAPI or the project's API docs) in the same work item. No
   breaking change to a published endpoint without a new version or the user's approval.

## Data
4. Database access only through the ORM or parameterized queries: never build SQL from user input.
5. Every schema change is a migration with its rollback. Data migrations are separate, and reversible or
   backed up first.
6. Lists are paginated; no N+1 queries (eager loading or joins). Multi-step writes run in a transaction.

## Configuration and security
7. No secrets, keys or passwords in code, tests, logs or commits: they come from the environment or a secret
   store.
8. Logs are structured, carry a request ID and never contain tokens, passwords or personal data.
9. Calls to other services have timeouts and handle errors; only safe (idempotent) calls are retried.

## Quality
10. Every endpoint has tests for success, invalid input and refused access; tests never call real external
    services.
11. New packages only through an approved plan, pinned in the lock file.
12. Feature code stays in its module, shared code in the shared module; never two frameworks or two ORMs for
    the same job.
