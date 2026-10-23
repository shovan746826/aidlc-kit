#!/usr/bin/env bash
# AI-DLC kit: shared helpers for the Claude Code hooks.
# Compatible with macOS bash 3.2. Reads hook JSON with jq, or python3 if jq is missing.

AIDLC_KIT_HOME="${AIDLC_KIT_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# json_get <json> <.dot.path> → prints the value, or nothing if it is missing.
json_get() {
  local json="$1" path="$2"
  if [ "${AIDLC_JSON_TOOL:-}" != "python3" ] && command -v jq >/dev/null 2>&1; then
    printf '%s' "$json" | jq -r "$path // empty" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$json" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for key in sys.argv[1].lstrip(".").split("."):
    data = data.get(key) if isinstance(data, dict) else None
    if data is None:
        sys.exit(0)
print(json.dumps(data) if isinstance(data, (dict, list)) else data)
' "$path" 2>/dev/null
  fi
}

# aidlc_config <KEY> <default> → environment variable first, then $AIDLC_KIT_HOME/config.
aidlc_config() {
  local key="$1" def="$2" val
  val="$(printenv "$key" 2>/dev/null || true)"
  if [ -z "$val" ] && [ -f "$AIDLC_KIT_HOME/config" ]; then
    val="$(grep -E "^[[:space:]]*$key[[:space:]]*=" "$AIDLC_KIT_HOME/config" 2>/dev/null | tail -n 1 \
      | cut -d= -f2- | sed -e 's/#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')"
  fi
  printf '%s' "${val:-$def}"
}

# find_up <dir> <relative-path> → nearest ancestor of <dir> (itself included) containing <relative-path>.
find_up() {
  local dir="$1"
  while [ -n "$dir" ]; do
    if [ -e "$dir/$2" ]; then printf '%s' "$dir"; return 0; fi
    [ "$dir" = "/" ] && return 1
    dir="$(dirname "$dir")"
  done
  return 1
}

# normalize_path <path> → resolves "." and ".." segments (no filesystem access).
normalize_path() {
  case "$1" in
    */./*|*/../*|*/.|*/..|*//*)
      if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import os, sys; print(os.path.normpath(sys.argv[1]))' "$1"
        return 0
      fi ;;
  esac
  printf '%s' "$1"
}

# state_get <aidlc-state.md> <key> → value from the machine-read block.
state_get() {
  awk '/aidlc:state:begin/ {inside=1; next} /aidlc:state:end/ {inside=0} inside' "$1" 2>/dev/null \
    | grep -E "^[[:space:]]*$2[[:space:]]*:" | head -n 1 | cut -d: -f2- \
    | sed -e 's/`//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# plan_paths <plan.md> → the planned paths between the aidlc:files markers, one per line.
# Only the Path column counts: in a table row, the backticked paths of the "Path" column (or of the first
# cell with backticks when the table has no header); in a bullet line, its first backticked path.
# Backticks in other columns ("move code into `lib/core/`") never widen the plan. Rows with <placeholders>
# or "…" are template examples and are ignored.
plan_paths() {
  awk '
    function emit(tok) {
      gsub(/^[ \t]+/, "", tok); gsub(/[ \t]+$/, "", tok); sub(/^\.\//, "", tok)
      if (tok == "" || tok ~ /[<>]/ || index(tok, "…") > 0) return
      print tok
    }
    function tokens(text, all,    s, e) {
      while ((s = index(text, "`")) > 0) {
        text = substr(text, s + 1); e = index(text, "`")
        if (e == 0) return
        emit(substr(text, 1, e - 1)); text = substr(text, e + 1)
        if (!all) return
      }
    }
    function trim(x) { gsub(/^[ \t]+/, "", x); gsub(/[ \t]+$/, "", x); return x }
    /aidlc:files:begin/ { inside = 1; pathcol = 0; next }
    /aidlc:files:end/ { inside = 0; next }
    !inside { next }
    {
      line = $0; sub(/^[ \t]+/, "", line)
      if (substr(line, 1, 1) != "|") { pathcol = 0; if (line ~ /^[-*+] /) tokens(line, 0); next }
      n = split(line, cells, "|")
      if (index(line, "`") == 0) {                       # header or separator row
        for (i = 1; i <= n; i++) if (tolower(trim(cells[i])) == "path") pathcol = i
        next
      }
      if (pathcol > 0 && pathcol <= n) { tokens(cells[pathcol], 1); next }
      for (i = 1; i <= n; i++) if (index(cells[i], "`") > 0) { tokens(cells[i], 1); break }
    }
  ' "$1" 2>/dev/null
}

# plan_status <plan.md> → first word of the plan's "Status:" line in capitals (APPROVED, DRAFT, …), or nothing.
plan_status() {
  grep -m 1 -iE '^[>[:space:]]*[*_]*status[*_]*:' "$1" 2>/dev/null \
    | sed -E 's/^[>[:space:]]*[*_]*[Ss][Tt][Aa][Tt][Uu][Ss][*_]*:[*_]*[[:space:]]*//' \
    | sed -E 's/^[^A-Za-z]*//' | awk '{ print toupper($1) }'
}

# path_in_plan <relative-path> <plan.md> → success if the plan lists it (exact path, "dir/" prefix, or glob).
path_in_plan() {
  local rel="$1" entry
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    [ "$rel" = "$entry" ] && return 0
    case "$entry" in
      */) case "$rel" in "$entry"*) return 0 ;; esac ;;
      *'*'*) case "$rel" in $entry) return 0 ;; esac ;;
    esac
  done <<EOF
$(plan_paths "$2")
EOF
  return 1
}

# version_lt <a> <b> → success if version a (x.y.z) is lower than version b.
version_lt() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    split(a, x, "."); split(b, y, ".")
    for (i = 1; i <= 3; i++) { if (x[i] + 0 < y[i] + 0) exit 0; if (x[i] + 0 > y[i] + 0) exit 1 }
    exit 1
  }'
}

# is_governance <relative-path> → planning files that never need a code plan.
is_governance() {
  case "$1" in
    aidlc-docs/*|.agents/*) return 0 ;;
    AGENTS.md|CLAUDE.md|CLAUDE.local.md|GEMINI.md) return 0 ;;
    */AGENTS.md|*/CLAUDE.md|*/CLAUDE.local.md|*/GEMINI.md) return 0 ;;
  esac
  return 1
}

# is_kit_owned <relative-path> <file> → the kit's own files in a project: rules and skills with the
# "aidlc-kit:managed" marker (replaced on every kit update) and the read-only copy of the shared brain.
is_kit_owned() {
  case "$1" in
    .agents/brain/shared/*) return 0 ;;
    .agents/*) head -n 8 "$2" 2>/dev/null | grep -q 'aidlc-kit:managed' ;;
    *) return 1 ;;
  esac
}

# is_free_doc <relative-path> <file> → a planning file that never needs a plan: governance, except the kit's own files.
is_free_doc() { is_governance "$1" && ! is_kit_owned "$1" "$2"; }
