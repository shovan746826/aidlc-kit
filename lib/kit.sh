#!/usr/bin/env bash
# AI-DLC kit: helpers shared by install.sh, init-project.sh and uninstall.sh (bash 3.2 compatible).

say()  { printf '%s\n' "$*"; }
warn() { printf '! %s\n' "$*" >&2; }
die()  { printf '✗ %s\n' "$*" >&2; exit 1; }

# backup_to <source> <destination>: copy a file or folder (keeps permissions).
backup_to() {
  [ -e "$1" ] || return 0
  mkdir -p "$(dirname "$2")"
  cp -Rp "$1" "$2"
}

# strip_trailing_blank: stdin → stdout without trailing blank lines.
strip_trailing_blank() {
  awk '{ lines[NR] = $0 } END { n = NR; while (n > 0 && lines[n] ~ /^[[:space:]]*$/) n--; for (i = 1; i <= n; i++) print lines[i] }'
}

# render_with_block <target> <block-file> <top|bottom>: prints <target> with the AIDLC block
# replaced in place, or added at the top (after YAML frontmatter, if any) or at the bottom.
render_with_block() {
  local target="$1" block="$2" where="$3"
  if [ -f "$target" ] && grep -q '<!-- AIDLC:BEGIN' "$target"; then
    awk -v bf="$block" '
      /<!-- AIDLC:BEGIN/ { while ((getline line < bf) > 0) print line; close(bf); skip = 1; next }
      skip && /<!-- AIDLC:END -->/ { skip = 0; next }
      !skip { print }
    ' "$target"
  elif [ -f "$target" ] && [ -s "$target" ]; then
    if [ "$where" = "top" ]; then
      awk -v bf="$block" '
        function emit() { while ((getline line < bf) > 0) print line; close(bf); print ""; done = 1 }
        NR == 1 && $0 == "---" { fm = 1; print; next }
        fm == 1 { print; if ($0 == "---") { fm = 2; emit() }; next }
        NR == 1 { emit() }
        { print }
        END { if (!done) emit() }
      ' "$target"
    else
      strip_trailing_blank < "$target"
      printf '\n'
      cat "$block"
    fi
  else
    cat "$block"
  fi
}

# render_without_block <target>: prints <target> without the AIDLC block (and the blank line after it).
render_without_block() {
  awk '
    /<!-- AIDLC:BEGIN/ { skip = 1; next }
    skip && /<!-- AIDLC:END -->/ { skip = 0; after = 1; next }
    skip { next }
    after && /^[[:space:]]*$/ { after = 0; next }
    { after = 0; print }
  ' "$1" | strip_trailing_blank
}

# lesson_sha <lesson file>: sha256 of a lesson without its usage counters (helpful, harmful, last_verified).
# lib/starter-lessons.sha256 lists it for every released version of every starter lesson.
lesson_sha() {
  if command -v shasum >/dev/null 2>&1; then
    grep -v -E '^(helpful|harmful|last_verified):' "$1" | shasum -a 256 | cut -d' ' -f1
  else
    grep -v -E '^(helpful|harmful|last_verified):' "$1" | sha256sum | cut -d' ' -f1
  fi
}

# json_tool: jq (preferred, built into recent macOS) or python3. AIDLC_JSON_TOOL=jq|python3 forces one.
json_tool() {
  case "${AIDLC_JSON_TOOL:-}" in
    jq|python3) command -v "$AIDLC_JSON_TOOL" >/dev/null 2>&1 && { echo "$AIDLC_JSON_TOOL"; return 0; } ;;
  esac
  command -v jq >/dev/null 2>&1 && { echo jq; return 0; }
  command -v python3 >/dev/null 2>&1 && python3 -c 'import json' >/dev/null 2>&1 && { echo python3; return 0; }
  return 1
}

# json_valid <file>
json_valid() {
  case "$(json_tool)" in
    jq) jq empty "$1" >/dev/null 2>&1 ;;
    python3) python3 -c 'import json, sys; json.load(open(sys.argv[1]))' "$1" >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

# settings_hooks <add|remove> <settings.json> <hooks-dir>
# Adds (or removes) the five AI-DLC hooks. Other settings and hooks are kept.
settings_hooks() {
  local action="$1" settings="$2" hooks="$3" tool tmp
  tool="$(json_tool)" || die "jq or python3 is needed to edit $settings"
  [ -s "$settings" ] || printf '{}\n' > "$settings"
  json_valid "$settings" || die "$settings is not valid JSON; fix it first (nothing was changed)"
  tmp="$(mktemp)"
  if [ "$tool" = "jq" ]; then
    jq --arg action "$action" \
       --arg gate "bash \"$hooks/plan-gate.sh\"" \
       --arg fmt "bash \"$hooks/auto-format.sh\"" \
       --arg ses "bash \"$hooks/session-start.sh\"" \
       --arg hint "bash \"$hooks/learn-hint.sh\"" \
       --arg check "bash \"$hooks/plan-check.sh\"" \
       --arg sub "bash \"$hooks/subagent-start.sh\"" \
       --arg shell "bash \"$hooks/shell-gate.sh\"" '
      def ours: (.command // "") | test("claude/hooks/(plan-gate|auto-format|session-start|learn-hint|plan-check|subagent-start|shell-gate)\\.sh");
      def clean: map(if ((.hooks // []) | length) > 0 and ((.hooks // []) | all(ours))
                     then empty
                     else .hooks = ((.hooks // []) | map(select(ours | not))) end);
      if $action == "add" then
        .hooks = (.hooks // {})
        | .hooks.PreToolUse = (((.hooks.PreToolUse // []) | clean)
            + [{matcher: "Edit|Write|MultiEdit|NotebookEdit", hooks: [{type: "command", command: $gate, timeout: 15}]},
               {matcher: "Bash", hooks: [{type: "command", command: $shell, timeout: 15}]}])
        | .hooks.PostToolUse = (((.hooks.PostToolUse // []) | clean)
            + [{matcher: "Edit|Write|MultiEdit", hooks: [{type: "command", command: $fmt, timeout: 60},
                                                        {type: "command", command: $check, timeout: 30}]}])
        | .hooks.SessionStart = (((.hooks.SessionStart // []) | clean)
            + [{hooks: [{type: "command", command: $ses, timeout: 15}]}])
        | .hooks.UserPromptSubmit = (((.hooks.UserPromptSubmit // []) | clean)
            + [{hooks: [{type: "command", command: $hint, timeout: 10}]}])
        | .hooks.SubagentStart = (((.hooks.SubagentStart // []) | clean)
            + [{hooks: [{type: "command", command: $sub, timeout: 10}]}])
      else
        if (.hooks | type) == "object" then
          .hooks |= (with_entries(.value |= (if type == "array" then clean else . end))
                     | with_entries(select((.value | type) != "array" or (.value | length) > 0)))
          | if .hooks == {} then del(.hooks) else . end
        else . end
      end
    ' "$settings" > "$tmp" || { rm -f "$tmp"; die "could not update $settings"; }
  else
    python3 - "$action" "$settings" "$hooks" > "$tmp" <<'PY' || { rm -f "$tmp"; die "could not update $settings"; }
import json, re, sys
action, path, hooks = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
ours = re.compile(r"claude/hooks/(plan-gate|auto-format|session-start|learn-hint|plan-check|subagent-start|shell-gate)\.sh")

def clean(groups):
    result = []
    for group in groups:
        entries = group.get("hooks", []) or []
        kept = [h for h in entries if not ours.search(h.get("command", "") or "")]
        if entries and not kept:
            continue
        group["hooks"] = kept
        result.append(group)
    return result

all_hooks = data.get("hooks")
if action == "add":
    all_hooks = all_hooks if isinstance(all_hooks, dict) else {}
    def cmd(name):
        return 'bash "%s/%s"' % (hooks, name)
    wanted = [
        ("PreToolUse", "Edit|Write|MultiEdit|NotebookEdit", [("plan-gate.sh", 15)]),
        ("PreToolUse", "Bash", [("shell-gate.sh", 15)]),
        ("PostToolUse", "Edit|Write|MultiEdit", [("auto-format.sh", 60), ("plan-check.sh", 30)]),
        ("SessionStart", None, [("session-start.sh", 15)]),
        ("UserPromptSubmit", None, [("learn-hint.sh", 10)]),
        ("SubagentStart", None, [("subagent-start.sh", 10)]),
    ]
    for event in dict.fromkeys(e for e, _m, _c in wanted):   # one event can get several entries
        all_hooks[event] = clean(all_hooks.get(event) or [])
    for event, matcher, commands in wanted:
        entry = {"hooks": [{"type": "command", "command": cmd(name), "timeout": timeout} for name, timeout in commands]}
        if matcher:
            entry = {"matcher": matcher, **entry}
        all_hooks[event].append(entry)
    data["hooks"] = all_hooks
elif isinstance(all_hooks, dict):
    for event in list(all_hooks):
        if isinstance(all_hooks[event], list):
            all_hooks[event] = clean(all_hooks[event])
            if not all_hooks[event]:
                del all_hooks[event]
    if not all_hooks:
        del data["hooks"]
print(json.dumps(data, indent=2))
PY
  fi
  cat "$tmp" > "$settings"
  rm -f "$tmp"
  json_valid "$settings" || die "$settings became invalid JSON; restore it from the backup"
}

# antigravity_hooks <add|remove> <hooks.json> <hooks dir>: the AI-DLC hooks in Google Antigravity's global hooks
# file (~/.gemini/config/hooks.json): "aidlc-plan-gate" (PreToolUse on file edits and run_command) and
# "aidlc-plan-check" (Stop).
# The user's own hooks are kept; a file that "remove" leaves empty is deleted.
antigravity_hooks() {
  local action="$1" file="$2" hooks="$3" tool tmp
  tool="$(json_tool)" || die "jq or python3 is needed to edit $file"
  if [ "$action" = remove ] && [ ! -f "$file" ]; then return 0; fi
  [ -s "$file" ] || printf '{}\n' > "$file"
  json_valid "$file" || die "$file is not valid JSON; fix it first (nothing was changed)"
  tmp="$(mktemp)"
  if [ "$tool" = "jq" ]; then
    jq --arg action "$action" \
       --arg gate "bash \"$hooks/antigravity.sh\" pre-tool" \
       --arg check "bash \"$hooks/antigravity.sh\" stop" '
      del(.["aidlc-plan-gate"], .["aidlc-plan-check"])
      | if $action == "add" then
          . + {"aidlc-plan-gate": {PreToolUse: [{matcher: "write_to_file|replace_file_content|multi_replace_file_content|run_command",
                                                  hooks: [{type: "command", command: $gate, timeout: 15}]}]},
               "aidlc-plan-check": {Stop: [{type: "command", command: $check, timeout: 60}]}}
        else . end
    ' "$file" > "$tmp" || { rm -f "$tmp"; die "could not update $file"; }
  else
    python3 - "$action" "$file" "$hooks" > "$tmp" <<'PY' || { rm -f "$tmp"; die "could not update $file"; }
import json, sys
action, path, hooks = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
for key in ("aidlc-plan-gate", "aidlc-plan-check"):
    data.pop(key, None)
if action == "add":
    data["aidlc-plan-gate"] = {"PreToolUse": [{
        "matcher": "write_to_file|replace_file_content|multi_replace_file_content|run_command",
        "hooks": [{"type": "command", "command": 'bash "%s/antigravity.sh" pre-tool' % hooks, "timeout": 15}]}]}
    data["aidlc-plan-check"] = {"Stop": [
        {"type": "command", "command": 'bash "%s/antigravity.sh" stop' % hooks, "timeout": 60}]}
print(json.dumps(data, indent=2))
PY
  fi
  cat "$tmp" > "$file"
  rm -f "$tmp"
  json_valid "$file" || die "$file became invalid JSON; restore it from the backup"
  if [ "$action" = remove ] && [ "$(tr -d ' \n\t' < "$file")" = "{}" ]; then rm -f "$file"; fi
}

# gemini_hooks <add|remove> <settings.json> <hooks dir>: the AI-DLC plan gate as a Gemini CLI BeforeTool hook
# (matcher write_file|replace; exit 2 blocks, as in Claude Code). The user's own settings and hooks are kept.
gemini_hooks() {
  local action="$1" file="$2" hooks="$3" tool tmp
  tool="$(json_tool)" || die "jq or python3 is needed to edit $file"
  if [ "$action" = remove ] && [ ! -f "$file" ]; then return 0; fi
  [ -s "$file" ] || printf '{}\n' > "$file"
  json_valid "$file" || die "$file is not valid JSON; fix it first (nothing was changed)"
  tmp="$(mktemp)"
  if [ "$tool" = "jq" ]; then
    jq --arg action "$action" --arg gate "bash \"$hooks/plan-gate.sh\"" '
      def ours: (.name // "") == "aidlc-plan-gate" or ((.command // "") | test("claude/hooks/plan-gate\\.sh"));
      def clean: map(if ((.hooks // []) | length) > 0 and ((.hooks // []) | all(ours))
                     then empty
                     else .hooks = ((.hooks // []) | map(select(ours | not))) end);
      (if (.hooks | type) == "object" and (.hooks.BeforeTool | type) == "array"
         then .hooks.BeforeTool |= clean else . end)
      | if $action == "add" then
          .hooks = (.hooks // {})
          | .hooks.BeforeTool = ((.hooks.BeforeTool // []) + [{matcher: "write_file|replace",
              hooks: [{name: "aidlc-plan-gate", type: "command", command: $gate, timeout: 15000}]}])
        else
          (if (.hooks | type) == "object" and .hooks.BeforeTool == [] then .hooks |= del(.BeforeTool) else . end)
          | (if .hooks == {} then del(.hooks) else . end)
        end
    ' "$file" > "$tmp" || { rm -f "$tmp"; die "could not update $file"; }
  else
    python3 - "$action" "$file" "$hooks" > "$tmp" <<'PY' || { rm -f "$tmp"; die "could not update $file"; }
import json, re, sys
action, path, hooks = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
ours = lambda h: h.get("name") == "aidlc-plan-gate" or re.search(r"claude/hooks/plan-gate\.sh", h.get("command", "") or "")
all_hooks = data.get("hooks") if isinstance(data.get("hooks"), dict) else None
if all_hooks is not None and isinstance(all_hooks.get("BeforeTool"), list):
    kept = []
    for group in all_hooks["BeforeTool"]:
        entries = group.get("hooks", []) or []
        rest = [h for h in entries if not ours(h)]
        if entries and not rest:
            continue
        group["hooks"] = rest
        kept.append(group)
    all_hooks["BeforeTool"] = kept
if action == "add":
    all_hooks = all_hooks if all_hooks is not None else {}
    all_hooks.setdefault("BeforeTool", []).append({"matcher": "write_file|replace", "hooks": [
        {"name": "aidlc-plan-gate", "type": "command", "command": 'bash "%s/plan-gate.sh"' % hooks, "timeout": 15000}]})
    data["hooks"] = all_hooks
elif all_hooks is not None:
    if all_hooks.get("BeforeTool") == []:
        del all_hooks["BeforeTool"]
    if not all_hooks:
        del data["hooks"]
print(json.dumps(data, indent=2))
PY
  fi
  cat "$tmp" > "$file"
  rm -f "$tmp"
  json_valid "$file" || die "$file became invalid JSON; restore it from the backup"
  if [ "$action" = remove ] && [ "$(tr -d ' \n\t' < "$file")" = "{}" ]; then rm -f "$file"; fi
}

# The AI-DLC role agents (claude/agents/<name>.md): one source per role, for Claude Code and Antigravity.
KIT_AGENTS="aidlc-analyst aidlc-builder aidlc-tester aidlc-debugger aidlc-researcher aidlc-reviewer"

# antigravity_agent <claude/agents/<name>.md>: prints the role as an Antigravity custom subagent
# (~/.gemini/config/agents/<name>/agent.md): name, description, the tools from "antigravity-tools", the main
# model, a subagent only (not a main agent). The body (its system prompt) stays the same.
antigravity_agent() {
  awk '
    NR == 1 && /^---[ \t]*$/ { fm = 1; next }
    fm && /^---[ \t]*$/ {
      fm = 0
      print "---"; print "name: " name; print "description: " desc; print "tools: " tools
      print "model: inherit"; print "mainAgent: false"; print "subagent: true"; print "---"
      next
    }
    fm {
      if (sub(/^name:[ \t]*/, "")) name = $0
      else if (sub(/^description:[ \t]*/, "")) desc = $0
      else if (sub(/^antigravity-tools:[ \t]*/, "")) tools = $0
      next
    }
    { print }
  ' "$1"
}
