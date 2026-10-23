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
# Adds (or removes) the four AI-DLC hooks. Other settings and hooks are kept.
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
       --arg hint "bash \"$hooks/learn-hint.sh\"" '
      def ours: (.command // "") | test("claude/hooks/(plan-gate|auto-format|session-start|learn-hint)\\.sh");
      def clean: map(if ((.hooks // []) | length) > 0 and ((.hooks // []) | all(ours))
                     then empty
                     else .hooks = ((.hooks // []) | map(select(ours | not))) end);
      if $action == "add" then
        .hooks = (.hooks // {})
        | .hooks.PreToolUse = (((.hooks.PreToolUse // []) | clean)
            + [{matcher: "Edit|Write|MultiEdit|NotebookEdit", hooks: [{type: "command", command: $gate, timeout: 15}]}])
        | .hooks.PostToolUse = (((.hooks.PostToolUse // []) | clean)
            + [{matcher: "Edit|Write|MultiEdit", hooks: [{type: "command", command: $fmt, timeout: 60}]}])
        | .hooks.SessionStart = (((.hooks.SessionStart // []) | clean)
            + [{hooks: [{type: "command", command: $ses, timeout: 15}]}])
        | .hooks.UserPromptSubmit = (((.hooks.UserPromptSubmit // []) | clean)
            + [{hooks: [{type: "command", command: $hint, timeout: 10}]}])
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
ours = re.compile(r"claude/hooks/(plan-gate|auto-format|session-start|learn-hint)\.sh")

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
        ("PreToolUse", "Edit|Write|MultiEdit|NotebookEdit", cmd("plan-gate.sh"), 15),
        ("PostToolUse", "Edit|Write|MultiEdit", cmd("auto-format.sh"), 60),
        ("SessionStart", None, cmd("session-start.sh"), 15),
        ("UserPromptSubmit", None, cmd("learn-hint.sh"), 10),
    ]
    for event, matcher, command, timeout in wanted:
        entry = {"hooks": [{"type": "command", "command": command, "timeout": timeout}]}
        if matcher:
            entry = {"matcher": matcher, **entry}
        all_hooks[event] = clean(all_hooks.get(event) or []) + [entry]
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
