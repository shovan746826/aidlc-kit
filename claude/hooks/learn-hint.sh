#!/usr/bin/env bash
# AI-DLC kit: Claude Code UserPromptSubmit hook. When the user's message looks like a correction, Claude
# gets a one-line reminder to capture the lesson in the brain inbox (30-learning.md §2).
# Only in projects that have a brain. Never blocks. AIDLC_LEARN_HINTS = on (default) | off

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

input="$(cat)"
[ "$(aidlc_config AIDLC_LEARN_HINTS on)" = "off" ] && exit 0

cwd="$(json_get "$input" .cwd)"
start="${CLAUDE_PROJECT_DIR:-${cwd:-$PWD}}"
root="$(find_up "$start" aidlc-docs/aidlc-state.md)" || exit 0   # only where AI-DLC is switched on
[ -f "$root/aidlc-docs/brain/INDEX.md" ] || exit 0

prompt="$(json_get "$input" .prompt | tr '[:upper:]' '[:lower:]' | tr '\n' ' ')"
[ -n "$prompt" ] || exit 0

case " $prompt " in
  *" no "*|*" no,"*|*" no."*|*" wrong"*|*"not like that"*|*"not what i"*|*"that's not"*|*"that is not"*|\
  *" instead"*|*"why did you"*|*"don't "*|*"do not "*|*" never "*|*"you forgot"*|*"you missed"*|\
  *"incorrect"*|*"mistake"*|*"should have"*|*"shouldn't have"*|*"i said"*|*"i told you"*|*"not this"*|\
  *"you didn't"*|*"you did not"*|*"why you "*)
    echo "[AI-DLC learning] This message may be a correction or a preference. If it is, add a row to aidlc-docs/brain/inbox.md (trigger: correction, evidence: the user's words) before you continue (30-learning.md §2)."
    ;;
esac
exit 0
