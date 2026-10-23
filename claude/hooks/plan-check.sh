#!/usr/bin/env bash
# AI-DLC kit: Claude Code PostToolUse hook for Edit|Write|MultiEdit. When Claude writes a plan file
# (implementation_plan.md, bugfix_plan.md or release-plan.md under aidlc-docs/), run verify-plan.sh --quick and
# show Claude invented paths, classes or lesson IDs right away. Exit 2 = feedback to Claude; nothing is
# blocked or undone. Other files and missing tools: silent exit 0.

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

input="$(cat)"
[ "$(aidlc_config AIDLC_ENFORCE project)" = "off" ] && exit 0
file="$(json_get "$input" .tool_input.file_path)"
case "$file" in
  */aidlc-docs/*/implementation_plan.md|*/aidlc-docs/*/bugfix_plan.md|*/aidlc-docs/*/release-plan.md) ;;
  *) exit 0 ;;
esac
[ -f "$file" ] && [ -f "$AIDLC_KIT_HOME/verify-plan.sh" ] || exit 0

if out="$(bash "$AIDLC_KIT_HOME/verify-plan.sh" "$file" --quick 2>&1)"; then exit 0; fi
{
  echo "AI-DLC plan check: $(basename "$file") refers to things that do not exist (anti-hallucination)."
  printf '%s\n' "$out" | grep -E '^  ✗'
  echo "Fix them from the code (search, read the definition) or ask the user. Never show a plan with ✗ at a gate."
} >&2
exit 2
