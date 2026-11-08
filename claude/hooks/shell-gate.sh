#!/usr/bin/env bash
# AI-DLC kit: shell gate. Claude Code PreToolUse hook for Bash; Antigravity reaches it through antigravity.sh
# (run_command). Finds the files a shell command would write (shell-targets.py) and asks the plan gate about each
# one, with the same rules and messages (helper agents included).
# Exit 0 = the command runs · exit 2 = blocked (the message on stderr). It fails open: when it can't read a
# command (no python3, a variable as the target, an unknown command), the command runs.

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

input="$(cat)"
[ "$(aidlc_config AIDLC_ENFORCE project)" = "off" ] && exit 0
cmd="$(json_get "$input" .tool_input.command)"
[ -n "$cmd" ] || exit 0
# Most commands write nothing: no redirect and none of the words of a writing command.
case "$cmd" in
  *'>'*|*tee*|*sed*|*perl*|*cp*|*mv*|*rm*|*touch*|*trunc*|*ln*|*install*|*rsync*|*unlink*|*shred*|*dd*|*git*|\
  *format*|*fix*|*prettier*|*eslint*|*black*|*isort*|*ruff*|*gofmt*|*pub*|*npm*|*yarn*|*pnpm*|*bun*|*composer*|\
  *poetry*|*uv*|*cargo*|*go*|*sh*|*eval*) ;;
  *) exit 0 ;;
esac
command -v python3 >/dev/null 2>&1 || exit 0

cwd="$(json_get "$input" .cwd)"; cwd="${cwd:-$PWD}"
extra=""
v="$(json_get "$input" .agent_id)"; [ -z "$v" ] || extra="$extra,\"agent_id\":$(json_string "$v")"
v="$(json_get "$input" .agent_type)"; [ -z "$v" ] || extra="$extra,\"agent_type\":$(json_string "$v")"

while IFS= read -r target; do
  [ -n "$target" ] || continue
  case "$target" in */) target="${target}(all files)" ;; esac   # a folder: everything in it
  msg="$(printf '{"tool_name":"Bash","cwd":%s,"tool_input":{"file_path":%s}%s}' \
    "$(json_string "$cwd")" "$(json_string "$target")" "$extra" | bash "$HOOKS_DIR/plan-gate.sh" 2>&1 >/dev/null)"
  if [ "$?" = 2 ]; then
    printf '%s\nShell commands count as file changes (00-aidlc-core §3): run this one only when the approved plan lists that file.\n' "$msg" >&2
    exit 2
  fi
done <<EOF
$(printf '%s' "$cmd" | python3 -I "$HOOKS_DIR/shell-targets.py" "$cwd" 2>/dev/null)
EOF
exit 0
