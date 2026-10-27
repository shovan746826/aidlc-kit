---
name: project-architecture
description: Backend architecture standard for this project (Node.js/TypeScript, Python or Laravel). It is generated from the project's own code (existing project) or from the approved architecture document (new project); until then this file explains how. MANDATORY: read it before planning or writing any code.
---
<!-- aidlc-kit:standard=backend · NOT GENERATED YET · project-owned copy: init-project.sh never overwrites it (use --update-architecture) -->

# Backend Architecture (NOT GENERATED YET)

> **Status: not generated.** Until this file holds the project's real standard:
> 1. Follow the existing code exactly: find the most similar existing endpoint, module or job and copy its
>    structure, naming and patterns.
> 2. Never introduce a new pattern, library, folder layout or naming style without an approved plan.
> 3. Follow the backend baseline rules in `.agents/rules/20-architecture.md`.
> 4. Generate the standard: in an existing project during `.agents/skills/project-analysis/SKILL.md` (A4);
>    in a new project in stage NP6 of `.agents/skills/aidlc-new-project/SKILL.md`.

## How to generate this standard
1. **Source.** Existing project: read 2–3 representative endpoints end to end (route → middleware →
   validation → controller or handler → service → data access → response) and one background job if the
   project has them. New project: the approved `aidlc-docs/project/05-architecture.md`.
2. **Write** the sections below into this file, with real paths and short code examples from this project
   (`path:line`). Keep the section names, so every backend standard reads the same way.
3. **Rules.** Rewrite `.agents/rules/20-architecture.md` with 10–20 short, checkable hard rules taken from the
   standard. Keep the baseline rules of the current file (API, data, configuration and security, quality),
   adapted to this project's tools, unless the user decides otherwise. Keep its frontmatter
   (`trigger: always_on`).
4. **Marker.** Change the marker line at the top of both files to `aidlc-kit:standard=generated`.
5. **Gate.** Show both files to the user. They apply only after explicit approval (audit log entry).
6. **Size.** Keep this file under about 20 KB: it is read before every plan. Long examples go into
   `reference/<topic>.md`, named in the section that needs them.

### Required sections
1. Overview: stack table (runtime and language version, framework, database, ORM or query builder, cache,
   queue, authentication, hosting), with the versions from the lock file
2. Directory structure (tree, top 3 levels)
3. Request flow: diagram and numbered steps (route → middleware → validation → handler → service → data
   access → response)
4. Module structure: the exact folders and files of one module
5. Naming conventions: files, classes, functions, routes, database tables and columns, tests
6. Routing and endpoints: adding an endpoint, URL and versioning style, the API contract (OpenAPI file or
   generated docs) and how it is kept up to date
7. Validation: where input is validated and the error response format
8. Authentication and authorization: how a request is authenticated, where permissions are checked
9. Data access: ORM rules, transactions, pagination, how N+1 queries are avoided
10. Migrations and seed data: tool, naming, rollback, data migrations
11. Error handling and logging: status codes, error body, structured logs with request IDs
12. Configuration and secrets: environment files, config modules, where secrets come from per environment
13. Background jobs, queues, scheduled tasks and events (if any)
14. External services and HTTP clients: timeouts, retries, circuit breaking
15. Caching and rate limiting (if any)
16. Security: CORS, headers, uploads, output encoding, dependency audit
17. Observability: health check, metrics, tracing
18. New-endpoint checklist (ordered steps; this becomes the task-plan order)
19. Placement rules (table: what you add → where it goes)
20. Build, run, lint, type-check and test commands
21. Testing standard: unit, integration (test database or container), API tests per endpoint, test data
22. Dependencies and deployment: package manager, lock file, environments, deploy and rollback order

## Stack hints (write down what the project really does)
| | Node.js / TypeScript | Python | Laravel (PHP) |
|---|---|---|---|
| Frameworks | Express, NestJS, Fastify, Koa | FastAPI, Django (+ REST framework), Flask | Laravel |
| Routing | routers, controllers (`@Controller`) | `APIRouter`, `urls.py`, blueprints | `routes/api.php`, controllers |
| Validation | DTOs + class-validator, zod, Joi | Pydantic models, serializers, marshmallow | Form Requests, `$request->validate()` |
| Data access | Prisma, TypeORM, Sequelize, Knex | SQLAlchemy, Django ORM | Eloquent, query builder |
| Migrations | Prisma Migrate, TypeORM, Knex | Alembic, Django migrations | `php artisan migrate`, `migrate:rollback` |
| Jobs | BullMQ, Agenda | Celery, RQ, Django-Q | Queues, Horizon, the scheduler |
| Tests | Jest, Vitest, Supertest | pytest (+ `TestClient`, httpx), Django tests | PHPUnit or Pest (`php artisan test`) |
| Lint and types | ESLint, Prettier, `tsc --noEmit` | Ruff, Black, mypy | Pint, PHPStan / Larastan |
