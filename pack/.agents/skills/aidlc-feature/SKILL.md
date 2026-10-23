---
name: aidlc-feature
description: Plan a new feature, module or screen, or a change, enhancement or refactor, in an existing project. Questions first, then requirements, an integration plan and an implementation_plan.md that the user must approve before any code changes. Use for "add/build/create X", "change/update/improve Y" and "refactor Z".
---
<!-- aidlc-kit:managed · replaced when the kit is updated -->

# Feature or Change Planning

**Output folder:** `aidlc-docs/work/<NNN>-<feature|change>-<slug>/`

| Stage | Output | Gate |
|---|---|---|
| F1 Context and questions | `questions.md` | the user's answers |
| F2 Requirements | `requirements.md` | approve |
| F3 Integration plan | `integration-plan.md` | approve |
| F4 Implementation plan | `implementation_plan.md` | 🛑 approve → the code gate opens |

**Light mode:** for changes, enhancements and small features (about 5 files or fewer, no new API), write
F2 and F3 as one `requirements.md` with an extra "Integration" section and approve it in one gate. Say that
you use light mode and why. Questions and the F4 approval are never skipped.

## F1. Context and questions
1. Session-start rules done: state read, architecture skill read, profile fresh (else run
   `.agents/skills/project-analysis/SKILL.md` first).
2. Create the work item: next free number `NNN` (look in `aidlc-docs/work/`), type `feature` or `change`,
   a short kebab-case slug, e.g. `004-feature-budget-alerts`. Create the folder and `questions.md` with the
   task brief at the top. State:
   `mode: inception`, `work_item`, `type`, `stage: F1 Questions`; add the item to the "Work items" table.
3. Read the code involved before asking: similar features (the reference implementation if the profile
   names one, or the architecture skill's reference files in `reference/`, if it has them), routes, state holders, URL config, shared widgets,
   models. **Recall:** read both brain indexes and open the lessons that match (`30-learning.md` §1).
4. **Ask round 1** (question bank J, plus C/E/F/G/H where relevant): goal and user; entry point; screens and
   UI states; data and API contract; business rules and validation; edge cases; permissions; offline;
   analytics; how the user will accept it. Record the answers. Ask more rounds until nothing blocking is left.
   (Units of a new project: the stories are already in `aidlc-docs/project/03-requirements.md`; confirm and
   narrow them for this unit instead of asking everything again.)

## F2. Requirements → `requirements.md`
Template `requirements.md`: user stories with Given/When/Then acceptance criteria (including error, empty
and offline cases), UI states per screen, business rules, the non-functional requirements that matter here,
out of scope. Gate.

## F3. Integration plan → `integration-plan.md`
Template `integration-plan.md`. Focus on section 7, **internal integration**: exactly where the feature plugs
into the existing app (routes and the screen that opens it, providers or global state it reads or changes,
shared widgets, core config entries such as URLs, colors and constants, platform files and permissions,
analytics, localization, local data changes). For every external call, write the contract (method, URL,
headers, request and response JSON examples, error codes). Unknown backend contract → ask; or plan
mock-first with typed models and mark the contract `[OPEN]`. Gate.

## F4. Implementation plan → `implementation_plan.md`
1. Think first with `.agents/skills/aidlc-think/SKILL.md` (full depth; light depth in light mode), and use
   `.agents/skills/aidlc-research/SKILL.md` for a new package or a version-sensitive API.
   Then fill every section of template `implementation_plan.md`, including the **Thinking summary**.
   Follow the architecture skill's "new feature checklist" for which files to create and in which order.
2. Files tables: every file with its full path, including tests and every config file you will edit
   (router, URL config, `pubspec.yaml`, platform manifests). The plan gate allows only these files.
3. Task plan phases (Data → Business logic → Presentation → Integration → Tests and verification), all ⏳.
   Under every task write **How** (file, change, key code shape), **Why** (requirement, standard section or
   lesson) and **Check** (how you will know it works).
3b. Draw the three diagrams of section 6 from the real tasks and files: plan flow, file map, runtime flow
   (with the error path). They show the user how the plan works before they approve it.
4. Self-check ("Ready to approve?"), then the gate. 🛑 **HARD STOP: wait for explicit approval.**
5. On approval: set the plan status `APPROVED <date-time>`; audit log; state `mode: construction`,
   `stage: C1 Baseline`, `code_gate: open`, `active_plan: aidlc-docs/work/<id>/implementation_plan.md`.
   Then follow `.agents/skills/aidlc-construction/SKILL.md`.

## Rules
- One work item = one coherent change. Split big requests into several work items and ask for the order.
- A bug found while planning becomes its own `bugfix` work item, unless the user wants it included.
- Never start coding "to explore". Read code, ask, plan.
