#!/usr/bin/env bash
# AI-DLC kit: Claude Code SubagentStart hook. In an AI-DLC project, every subagent (built-in ones like Explore
# included) gets the helper rules of the aidlc-multi-agent skill as added context. The kit's own roles
# (aidlc-*) have these rules in their prompt and get nothing. It never blocks.

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

input="$(cat)"
[ "$(aidlc_config AIDLC_ENFORCE project)" = "off" ] && exit 0
case "$(json_get "$input" .agent_type)" in aidlc-*) exit 0 ;; esac
cwd="$(json_get "$input" .cwd)"
find_up "${cwd:-$PWD}" aidlc-docs/aidlc-state.md >/dev/null || exit 0

rules="AI-DLC helper rules (this project uses AI-DLC; the agent that started you is the lead):
1. The lead owns the user, questions, approvals, the plan, aidlc-docs/aidlc-state.md and the audit log. Never change them, never approve anything, never open the code gate.
2. Change only the files your task gives you. If you only read, change nothing; long findings go to aidlc-docs/work/<item>/agents/<task>-<role>.md.
3. Evidence for every claim: path:line or quoted command output. Don't know: say unknown.
4. You need another file, a decision or the user: stop and say so in your answer.
5. End with the card: AI-DLC result · <task> · <role> · DONE | BLOCKED | FAILED, then Changed, Evidence, Found, Needs the lead, Notes."
printf '{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":%s}}\n' "$(json_string "$rules")"
exit 0
