# AI-DLC State

<!-- aidlc:state:begin · machine-read by AI-DLC tools: keep these keys and the "key: value" format -->
mode: idle
work_item: none
type: none
stage: none
code_gate: closed
active_plan: none
updated: never
<!-- aidlc:state:end -->

<!--
mode:        idle | analysis | inception | construction | release
type:        new-project | setup | feature | change | bugfix | release | none
stage:       stage id + name from the skill you follow, e.g. "F4 Implementation plan"
code_gate:   closed | open   ← open ONLY right after the user approved the active_plan
active_plan: path of the approved plan, e.g. aidlc-docs/work/003-feature-budget-alerts/implementation_plan.md
updated:     date-time from the system clock (YYYY-MM-DD HH:MM)
-->

## Progress: current work item
<!-- Copy the stage list of the skill you follow and keep the status markers current:
     ⏳ [PENDING] · 🔄 [IN PROGRESS] · ✅ [COMPLETED] · ⛔ [BLOCKED] · ⏭️ [SKIPPED] -->
_No active work item._

## Work items
| ID | Type | Title | Status | Folder |
|---|---|---|---|---|

## Parked
_None._

## Next action
Analyze the project (`.agents/skills/project-analysis/SKILL.md`), or tell the agent what you want to build.
