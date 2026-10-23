#!/usr/bin/env bash
# AI-DLC kit: plan gate. Claude Code PreToolUse hook for Edit|Write|MultiEdit|NotebookEdit.
# Blocks changes to project files unless an approved plan lists them.
# Exit 0 = allow · exit 2 = block (the message on stderr is shown to Claude).
#
# Settings (environment variable or ~/.aidlc-kit/config):
#   AIDLC_ENFORCE    = project (default: projects with aidlc-docs/aidlc-state.md) | all-repos | off
#   AIDLC_GATE_SCOPE = plan-files (default: only files listed in the active plan) | any

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

input="$(cat)"
mode="$(aidlc_config AIDLC_ENFORCE project)"
[ "$mode" = "off" ] && exit 0

file="$(json_get "$input" .tool_input.file_path)"
[ -n "$file" ] || file="$(json_get "$input" .tool_input.notebook_path)"
[ -n "$file" ] || exit 0
case "$file" in
  /*) ;;
  *) cwd="$(json_get "$input" .cwd)"; file="${cwd:-$PWD}/$file" ;;
esac
file="$(normalize_path "$file")"
dir="$(dirname "$file")"

KIT_NOTE=""
block() {
  printf 'AI-DLC plan gate: blocked a change to %s\n%s\n' "$1" "$2" >&2
  [ -z "$KIT_NOTE" ] || printf '%s\n' "$KIT_NOTE" >&2
  exit 2
}

root="$(find_up "$dir" aidlc-docs/aidlc-state.md)" || root=""

if [ -z "$root" ]; then
  [ "$mode" = "all-repos" ] || exit 0
  repo="$(find_up "$dir" .git)" || exit 0
  rel="${file#"$repo"/}"
  is_governance "$rel" && exit 0
  block "$rel" "This repository has no AI-DLC workspace (aidlc-docs/aidlc-state.md) and enforcement is set to all-repos.
Set it up first (/aidlc init, or: bash ~/.aidlc-kit/init-project.sh \"$repo\"), then plan the change and get the user's approval."
fi

rel="${file#"$root"/}"
if is_governance "$rel"; then
  is_kit_owned "$rel" "$file" || exit 0   # planning documents and project-owned rules: no plan needed
  KIT_NOTE="Note: $rel belongs to the AI-DLC kit and is replaced on every kit update. Project rules go into a new file in .agents/rules/; the shared brain changes only through brain.sh."
fi

state="$root/aidlc-docs/aidlc-state.md"
gate="$(state_get "$state" code_gate | tr '[:upper:]' '[:lower:]')"
if [ "$gate" != "open" ]; then
  block "$rel" "No approved plan is active (aidlc-docs/aidlc-state.md has code_gate: ${gate:-missing}).
Plan first (.agents/rules/00-aidlc-core.md): write the plan, show the gate card, and wait for the user's explicit approval. Only then set code_gate: open and active_plan in the state file. Never open the gate without that approval."
fi

[ "$(aidlc_config AIDLC_GATE_SCOPE plan-files)" = "any" ] && exit 0

plan="$(state_get "$state" active_plan)"
case "$plan" in
  ''|none) block "$rel" "code_gate is open but active_plan is empty. Set active_plan in aidlc-docs/aidlc-state.md to the approved plan file." ;;
  /*) plan_file="$plan" ;;
  *) plan_file="$root/$plan" ;;
esac
[ -f "$plan_file" ] || block "$rel" "The active plan file does not exist: $plan"

status="$(plan_status "$plan_file")"
[ "$status" = "APPROVED" ] || block "$rel" "The active plan is not approved (its status line says: ${status:-nothing}; plan: $plan).
Show the gate card and wait for the user's explicit approval. After the approval, set the plan's status line to
\"> Status: APPROVED <date-time>\". A completed plan needs a new work item: close the gate (code_gate: closed)."

path_in_plan "$rel" "$plan_file" && exit 0

block "$rel" "This file is not listed in the approved plan ($plan).
If it must change: STOP. Add a row to the plan's \"Plan changes\" table (status: proposed), explain the change to the user and wait for approval. After approval, add the file to the plan's Files tables (between the aidlc:files markers) and try again."
