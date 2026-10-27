#!/usr/bin/env bash
# AI-DLC kit: Google Antigravity hooks (~/.gemini/config/hooks.json). Antigravity sends JSON on stdin and reads
# the answer as JSON on stdout.
#   antigravity.sh pre-tool   PreToolUse for write_to_file | replace_file_content | multi_replace_file_content:
#                             runs the plan gate (the same script as Claude Code) and answers allow or deny.
#   antigravity.sh stop       Stop: a draft plan changed in the last hour that fails verify-plan.sh sends the agent
#                             back with the problems, once per version of the plan and at most 3 times.
# Never blocks by mistake: a missing field or tool answers "allow" (pre-tool) or nothing to do (stop).

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY="$(cd "$HOOKS_DIR/../.." && pwd)/verify-plan.sh"   # the checker of this kit copy
NL='
'

input="$(cat)"
ws="$(json_get "$input" '.workspacePaths[0]')"

# answer <decision> [reason]: the JSON Antigravity reads.
answer() {
  if [ -n "${2:-}" ]; then printf '{"decision":"%s","reason":%s}\n' "$1" "$(json_string "$2")"
  else printf '{"decision":"%s"}\n' "$1"; fi
}

case "${1:-}" in
  pre-tool)
    file="$(json_get "$input" .toolCall.args.TargetFile)"
    [ -n "$file" ] || { answer allow; exit 0; }
    gate_input="$(printf '{"tool_name":"Edit","cwd":%s,"tool_input":{"file_path":%s}}' \
      "$(json_string "${ws:-$PWD}")" "$(json_string "$file")")"
    if msg="$(printf '%s' "$gate_input" | bash "$HOOKS_DIR/plan-gate.sh" 2>&1 >/dev/null)"; then
      answer allow
    elif [ "$?" = 2 ]; then
      answer deny "$msg"
    else
      answer allow
    fi ;;

  stop)
    nothing() { printf '{}\n'; exit 0; }
    [ "$(aidlc_config AIDLC_ENFORCE project)" = "off" ] && nothing
    root="$(find_up "${ws:-$PWD}" aidlc-docs/aidlc-state.md)" || nothing
    [ -f "$VERIFY" ] || nothing
    report=""
    while IFS= read -r plan; do
      [ -n "$plan" ] || continue
      case "$(plan_status "$plan")" in APPROVED|COMPLETED) continue ;; esac
      out="$(bash "$VERIFY" "$plan" 2>&1)" && continue
      guard="${TMPDIR:-/tmp}/aidlc-kit-stop/$(printf '%s' "$plan" | cksum | cut -d' ' -f1)"
      version="$guard/$(cksum < "$plan" | cut -d' ' -f1)"
      [ -f "$version" ] && continue                                               # this version was sent back
      [ "$(ls "$guard" 2>/dev/null | wc -l | tr -d ' ')" -lt 3 ] || continue      # at most 3 rounds per plan
      mkdir -p "$guard" && : > "$version"
      report="$report$NL${plan#"$root"/}$NL$(printf '%s\n' "$out" | grep -E '^  ✗')"
    done <<EOF
$(find "$root/aidlc-docs/work" "$root/aidlc-docs/releases" -maxdepth 2 -type f \
    \( -name implementation_plan.md -o -name bugfix_plan.md -o -name release-plan.md \) -mmin -60 2>/dev/null)
EOF
    [ -n "$report" ] || nothing
    answer continue "AI-DLC plan check (anti-hallucination): before you show a plan at a gate, fix these problems from the code (search, read the definition), or ask the user what the code and docs can't settle.$report" ;;

  *) answer allow ;;
esac
exit 0
