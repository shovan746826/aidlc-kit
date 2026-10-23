---
name: aidlc-new-project
description: Plan a brand-new project or app the AI-DLC way. Question rounds first, then project brief, business plan, requirements, integration plan, architecture and delivery plan, each approved by the user, then a scaffold implementation plan. Use when the user wants to create a new project, app or product, or the repository is empty.
---
<!-- aidlc-kit:managed · replaced when the kit is updated -->

# New Project (AI-DLC Inception)

You produce 6 planning documents in `aidlc-docs/project/`. Each one comes after a question round and is
approved separately. Then the project scaffold is planned and built through construction.
**Never write a section from a guess:** ask, or mark it `[ASSUMPTION]` and list it at the gate.

| Stage | Output (in `aidlc-docs/project/`) | Question round (question-bank sections) |
|---|---|---|
| NP1 Set up | workspace, state, `questions.md` | none |
| NP2 Discovery | `01-project-brief.md` | Round 1: A (vision), B (users) |
| NP3 Business plan | `02-business-plan.md` | Round 2: A5–A10 (model, pricing, budget, team), G (privacy), I1 |
| NP4 Requirements | `03-requirements.md` | Round 3: C (scope), D (platforms), H (quality) |
| NP5 Integration plan | `04-integration-plan.md` | Round 4: F (integration), G (data) |
| NP6 Architecture | `05-architecture.md` + the project's architecture skill | Round 5: E (technical) |
| NP7 Delivery plan | `06-delivery-plan.md` | Round 6 only if needed: dates, team, priorities |
| NP8 Scaffold plan | `aidlc-docs/work/001-setup-project-scaffold/implementation_plan.md` | none |

Every stage follows the same loop: **questions → document from the template → self-check ("Ready to
approve?") → gate → approval → audit log + state → next stage.**

## NP1. Set up
1. If `aidlc-docs/aidlc-state.md` is missing, create `aidlc-docs/` with `aidlc-state.md` and `audit-log.md`
   from `.agents/templates/`.
2. Create `aidlc-docs/project/` and `aidlc-docs/project/questions.md`.
3. State: `mode: inception`, `type: new-project`, `work_item: project`, `stage: NP1 Set up`. Progress list =
   the 8 stages above, all ⏳.
4. Tell the user the stages (the table above, short) and that each document waits for their approval.

## NP2. Discovery → `01-project-brief.md`
1. **Round 1:** the idea in one sentence; the problem; who has it; how they solve it today; why now;
   competitors they know; target countries and languages; success after 6 months; budget, timeline and
   team constraints.
2. Write the brief (template `project-brief.md`). Competitors and market facts come only from the user or
   from research you actually did, with sources. Never invent numbers.
3. Gate.

## NP3. Business plan → `02-business-plan.md`
1. **Round 2:** business model; pricing and free-vs-paid boundary; who pays; expected costs (backend,
   services); launch channels; KPIs that matter; legal concerns (personal, financial, health or children's
   data); store accounts.
2. Write the plan (template `business-plan.md`). Every number is user-provided or marked `[ESTIMATE]` with
   how it was estimated. Use `.agents/skills/aidlc-research/SKILL.md` for store policies, payment rules and
   privacy laws (cite sources). Store commissions apply to in-app purchases: ask the user to confirm current rates.
3. Gate.

## NP4. Requirements → `03-requirements.md`
1. **Round 3:** MVP features (must / should / could / won't); user roles; accounts; offline needs;
   notifications; platforms and minimum OS versions; phone or tablet; dark mode; accessibility; languages.
2. Write (template `requirements.md`): functional requirements with priority and release; user stories with
   Given/When/Then acceptance criteria, **including error and empty cases**; UI states; business rules;
   measurable non-functional requirements.
3. Gate.

## NP5. Integration plan → `04-integration-plan.md`
1. **Round 4:** backend (exists? who builds it? API docs? base URLs per environment?); authentication;
   payments; push notifications; analytics and crash reporting; maps and location; file storage;
   email/SMS; other SDKs; environments; who owns each account; where secrets are kept.
2. Research every third-party service you plan to use (`aidlc-research`: official docs, limits, pricing,
   SDK versions), then write (template `integration-plan.md`): system context diagram, inventory, a specification per
   integration (contract, errors, limits, testing, monitoring), sequence diagrams for the key flows (login,
   payment, sync), environment matrix, and the order of integrations. If the backend is not ready, plan
   **mock-first**: typed models + fake repositories, real API later.
3. Gate.

## NP6. Architecture → `05-architecture.md`
1. The architecture skill `.agents/skills/project-architecture/SKILL.md` was installed by `init-project.sh`
   for the platform (Flutter house standard, native Android, native iOS, or generic). Read it fully (the
   Flutter standard keeps its complete code in `reference/`: open those files at NP8).
   If it is the generic placeholder ("NOT GENERATED") but the app is Flutter, Android or iOS, stop: ask the
   user to approve `bash ~/.aidlc-kit/init-project.sh "<project root>" --standard <flutter|android|ios>`
   (it replaces the untouched placeholder), then read the new standard.
2. **Round 5:** only what the standard leaves open: local storage needs, offline/sync strategy, navigation
   structure (tabs, drawer, stack), design size, fonts, brand colors, dark mode, flavors, organization id.
3. Think with `.agents/skills/aidlc-think/SKILL.md` (full depth) for every open decision, and research
   versions (`aidlc-research`). Write (template `architecture.md`): standard applied and approved deviations, stack table with versions,
   feature/module map from the requirements, navigation map, state design, data model, networking,
   security, non-functional design, project-specific values. Write an ADR (template `decision-record.md`)
   for every significant decision or deviation.
4. If the skill is the **generic** one: write the full project architecture skill and replace
   `.agents/rules/20-architecture.md` with this project's hard rules, following the instructions inside
   the generic skill. The user approves them at this gate.
5. Gate. The user approves the document **and** any change to the architecture skill or rules.

## NP7. Delivery plan → `06-delivery-plan.md`
1. Split the requirements into **units of work**: vertical slices (UI → logic → data) that a user can see
   working. For each unit: stories, dependencies, size (S/M/L), milestone. Models, APIs or events that more
   than one unit uses are **shared contracts**: define each once (owner unit, file, shape) before those units
   start.
2. Order: `001-setup-project-scaffold` first, then by dependency and priority. Milestones with exit
   criteria. Traceability: goal → FR → story → unit → work item.
3. Add every unit to the "Work items" table in `aidlc-state.md` (`002-feature-…`, `003-feature-…`), all ⏳.
4. Gate.

## NP8. Scaffold plan → `aidlc-docs/work/001-setup-project-scaffold/implementation_plan.md`
1. Plan the skeleton exactly as the architecture standard defines it. For Flutter, copy the complete files
   in `.agents/skills/project-architecture/reference/core.md` (core layer) and use `reference/feature-items.md`
   as the pattern for features.
   Include the create command (e.g.
   `flutter create --org <org> --project-name <name> --platforms android,ios .`, listed in section 9),
   folder structure, core module (configs, network client, theme, router, base classes, storage helpers),
   entry point, lint configuration, flavors and environments, asset folders, a first test, CI (if wanted).
2. It is a normal implementation plan (template `implementation_plan.md`), so the gate is a 🛑 HARD STOP.
3. On approval: audit log; state `mode: construction`, `work_item: 001-setup-project-scaffold`,
   `type: setup`, `stage: C1 Baseline`, `code_gate: open`, `active_plan:` the plan path. Then follow
   `.agents/skills/aidlc-construction/SKILL.md`.

## After the scaffold
Continue with the next unit from the delivery plan using `.agents/skills/aidlc-feature/SKILL.md`. Its stories
already exist in `03-requirements.md`, so in F1/F2 confirm and narrow them for this unit instead of asking
everything again. **Milestone check:** when the last unit of a milestone is done, run the full verification and
the milestone's user journeys end to end, and mark its exit criteria ✅ or ❌ in `06-delivery-plan.md` before
the next milestone starts.

## Rules
- At most 10 questions per round. Skip questions that are already answered.
- Every document starts with a 3–5 bullet summary.
- Keep IDs consistent across documents (FR-, US-, BR-, NFR-, INT-, U-, ADR-).
- Light mode (only if the user asks to go faster): combine NP2+NP3 and NP4+NP5 into one gate each. The
  questions and the approvals are never skipped.
