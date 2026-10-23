#!/usr/bin/env bash
# AI-DLC kit: install once per machine.
#   • copies the kit to ~/.aidlc-kit (used by init-project.sh and the hooks)
#   • Claude Code: /aidlc command, aidlc-reviewer agent, 5 hooks in settings.json, plan-first rule in CLAUDE.md
#   • Antigravity / Gemini: plan-first rule in ~/.gemini/GEMINI.md
# Every file it changes is backed up first to ~/.aidlc-kit/backups/<time>/. Safe to run again (updates).
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/kit.sh
. "$SRC/lib/kit.sh"

usage() {
  cat <<'EOF'
Usage: bash install.sh [--no-claude] [--no-gemini] [--no-hooks]
  --no-claude   skip Claude Code (command, agent, hooks, ~/.claude/CLAUDE.md)
  --no-gemini   skip the Antigravity / Gemini global rule (~/.gemini/GEMINI.md)
  --no-hooks    install the Claude Code command and agent, but not the hooks
Environment: AIDLC_KIT_HOME (default ~/.aidlc-kit) · CLAUDE_CONFIG_DIR (default ~/.claude)
             AIDLC_GEMINI_DIR (default ~/.gemini)
EOF
}

DO_CLAUDE=1; DO_GEMINI=1; DO_HOOKS=1
for arg in "$@"; do
  case "$arg" in
    --no-claude) DO_CLAUDE=0 ;;
    --no-gemini) DO_GEMINI=0 ;;
    --no-hooks) DO_HOOKS=0 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; die "unknown option: $arg" ;;
  esac
done

VERSION="$(cat "$SRC/VERSION")"
KIT_HOME="${AIDLC_KIT_HOME:-$HOME/.aidlc-kit}"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
GEMINI_DIR="${AIDLC_GEMINI_DIR:-$HOME/.gemini}"
STAMP="$(date +%Y%m%d-%H%M%S)-$$"
BACKUP="$KIT_HOME/backups/$STAMP"
case "$KIT_HOME" in
  ""|"/"|"$HOME"|"$HOME/") die "unsafe kit folder '$KIT_HOME': set AIDLC_KIT_HOME to a dedicated folder such as ~/.aidlc-kit" ;;
esac

say "AI-DLC kit $VERSION: machine install"
say ""

# 1. Kit home ------------------------------------------------------------------------------------------
mkdir -p "$KIT_HOME"
if [ "$(cd "$KIT_HOME" && pwd)" != "$SRC" ]; then
  for item in VERSION README.md GUIDE.md CHANGELOG.md FLUTTER-STANDARD-V3-ANALYSIS.md install.sh init-project.sh uninstall.sh remove-project.sh brain.sh tokens.sh verify-plan.sh lib pack standards claude global tests; do
    rm -rf "${KIT_HOME:?}/$item"
    if [ -e "$SRC/$item" ]; then cp -R "$SRC/$item" "$KIT_HOME/$item"; fi
  done
fi
chmod +x "$KIT_HOME"/*.sh "$KIT_HOME"/claude/hooks/*.sh "$KIT_HOME"/claude/bin/*.sh 2>/dev/null || true
# config_block <KEY>: the default line of one setting, with its explanation.
config_block() {
  case "$1" in
    AIDLC_ENFORCE) cat <<'EOF'

# AIDLC_ENFORCE: project   = plan gate in projects that have aidlc-docs/aidlc-state.md (default)
#                all-repos = also block edits in git repositories that do not have the AI-DLC pack
#                off       = no blocking (the rules still apply)
AIDLC_ENFORCE=project
EOF
    ;;
    AIDLC_GATE_SCOPE) cat <<'EOF'

# AIDLC_GATE_SCOPE: plan-files = only files listed in the approved plan may change (default)
#                   any        = any file may change once a plan is approved
AIDLC_GATE_SCOPE=plan-files
EOF
    ;;
    AIDLC_AUTOFORMAT) cat <<'EOF'

# AIDLC_AUTOFORMAT: new-files = in AI-DLC projects, format only files git does not track yet (default)
#                   all = also tracked files · off
AIDLC_AUTOFORMAT=new-files
EOF
    ;;
    AIDLC_LEARN_HINTS) cat <<'EOF'

# AIDLC_LEARN_HINTS: on  = when your message looks like a correction, remind Claude to record the lesson (default)
#                    off = no reminder
AIDLC_LEARN_HINTS=on
EOF
    ;;
  esac
}
SETTINGS="AIDLC_ENFORCE AIDLC_GATE_SCOPE AIDLC_AUTOFORMAT AIDLC_LEARN_HINTS"
if [ ! -f "$KIT_HOME/config" ]; then
  printf '# AI-DLC kit settings. Environment variables with the same names override these values.\n' > "$KIT_HOME/config"
  for key in $SETTINGS; do config_block "$key" >> "$KIT_HOME/config"; done
else
  added_settings=""
  for key in $SETTINGS; do   # settings added by newer kits; your values are never changed
    grep -qE "^[[:space:]]*$key[[:space:]]*=" "$KIT_HOME/config" && continue
    config_block "$key" >> "$KIT_HOME/config"
    added_settings="$added_settings $key"
  done
  [ -z "$added_settings" ] || say "✓ new settings added to $KIT_HOME/config (defaults):$added_settings"
fi
say "✓ kit files: $KIT_HOME (settings: $KIT_HOME/config)"

# Shared brain: installed once. Afterwards new starter lessons are added, starter lessons you never edited are
# updated (your helpful/harmful counts are kept), and lessons you edited or wrote are never changed.
BRAIN="$KIT_HOME/brain"

# index_add_kit_line <lesson file>: the kit's index line, added under "Added by kit updates".
index_add_kit_line() {
  if ! grep -q '^## Added by kit updates' "$BRAIN/INDEX.md"; then printf '\n## Added by kit updates\n' >> "$BRAIN/INDEX.md"; fi
  grep -F "(lessons/$1)" "$SRC/brain/INDEX.md" >> "$BRAIN/INDEX.md" || true
}

# index_update_line <lesson file>: the lesson's line in your index becomes the kit's, with your ✓/✗ counts.
index_update_line() {
  local kit_line old_line counts tmp
  kit_line="$(grep -F "(lessons/$1)" "$SRC/brain/INDEX.md" | head -n 1 || true)"
  [ -n "$kit_line" ] || return 0
  old_line="$(grep -F "(lessons/$1)" "$BRAIN/INDEX.md" | head -n 1 || true)"
  if [ -z "$old_line" ]; then index_add_kit_line "$1"; return 0; fi
  counts="$(printf '%s' "$old_line" | grep -o '✓[0-9]* ✗[0-9]*$' || true)"
  if [ -n "$counts" ]; then kit_line="$(printf '%s' "$kit_line" | sed "s/✓[0-9]* ✗[0-9]*\$/$counts/")"; fi
  if [ "$kit_line" = "$old_line" ]; then return 0; fi
  tmp="$(mktemp)"
  OLD="$old_line" NEW="$kit_line" awk '!done && $0 == ENVIRON["OLD"] { print ENVIRON["NEW"]; done = 1; next } { print }' \
    "$BRAIN/INDEX.md" > "$tmp"
  cat "$tmp" > "$BRAIN/INDEX.md"
  rm -f "$tmp"
}

# with_counters <kit lesson> <your lesson>: the kit's text with your helpful/harmful counts and the later
# last_verified date of the two.
with_counters() {
  local helpful harmful mine kits verified
  helpful="$(grep -m 1 '^helpful:' "$2" || true)"; harmful="$(grep -m 1 '^harmful:' "$2" || true)"
  mine="$(grep -m 1 '^last_verified:' "$2" | cut -d: -f2- | tr -d ' ' || true)"
  kits="$(grep -m 1 '^last_verified:' "$1" | cut -d: -f2- | tr -d ' ' || true)"
  verified="$kits"; if [[ "$mine" > "$kits" ]]; then verified="$mine"; fi
  H="$helpful" X="$harmful" V="$verified" awk '
    /^helpful:/ && ENVIRON["H"] != "" { print ENVIRON["H"]; next }
    /^harmful:/ && ENVIRON["X"] != "" { print ENVIRON["X"]; next }
    /^last_verified:/ && ENVIRON["V"] != "" { print "last_verified: " ENVIRON["V"]; next }
    { print }' "$1"
}

if [ ! -f "$BRAIN/INDEX.md" ]; then
  mkdir -p "$BRAIN"
  cp -R "$SRC/brain/." "$BRAIN/"
  say "✓ shared brain: $(grep -c '^- \[' "$BRAIN/INDEX.md") starter lessons in $BRAIN"
else
  added=0; updated=""; kept_edits=""; id_taken=""
  # Kits before 2.7 named a 6 KB budget in the index header. Only that line of the kit's own text changes.
  old_head='This is a read-only copy in each project; the source is `~/.aidlc-kit/brain/`. Keep under 6 KB.'
  new_head="$(grep -m 1 -F 'This is a read-only copy in each project;' "$SRC/brain/INDEX.md" || true)"
  if [ -n "$new_head" ] && grep -qxF "$old_head" "$BRAIN/INDEX.md"; then
    backup_to "$BRAIN/INDEX.md" "$BACKUP/brain/INDEX.md"
    tmp="$(mktemp)"
    OLD="$old_head" NEW="$new_head" awk '$0 == ENVIRON["OLD"] { print ENVIRON["NEW"]; next } { print }' \
      "$BRAIN/INDEX.md" > "$tmp"
    cat "$tmp" > "$BRAIN/INDEX.md"
    rm -f "$tmp"
    say "✓ shared brain index: the budget line now says 8 KB"
  fi
  mkdir -p "$BRAIN/lessons"
  for lesson in "$SRC"/brain/lessons/*.md; do
    name="$(basename "$lesson")"; id="$(printf '%s' "$name" | cut -d- -f1-2)"; mine="$BRAIN/lessons/$name"
    if [ ! -f "$mine" ]; then
      if ls "$BRAIN/lessons/$id-"*.md >/dev/null 2>&1; then id_taken="$id_taken $id"; continue; fi   # yours uses the ID
      cp "$lesson" "$mine"
      index_add_kit_line "$name"
      added=$((added + 1))
      continue
    fi
    if cmp -s "$lesson" "$mine"; then continue; fi
    if grep -qF "$(lesson_sha "$mine")  $name" "$SRC/lib/starter-lessons.sha256"; then   # an older kit version
      tmp="$(mktemp)"
      with_counters "$lesson" "$mine" > "$tmp"
      if ! cmp -s "$tmp" "$mine"; then
        backup_to "$mine" "$BACKUP/brain/lessons/$name"
        cat "$tmp" > "$mine"
        index_update_line "$name"
        updated="$updated $id"
      fi
      rm -f "$tmp"
    else
      kept_edits="$kept_edits $id"
    fi
  done
  say "✓ shared brain kept ($(grep -c '^- \[' "$BRAIN/INDEX.md") lessons) · starter lessons added: $added · updated:${updated:- none}"
  [ -z "$kept_edits" ] || say "  ! kept your edited starter lessons:$kept_edits (the kit's versions are in $SRC/brain/lessons/)"
  [ -z "$id_taken" ] || say "  ! not added, because one of your lessons uses the same ID:$id_taken (renumber yours from S-101 up to get the kit's)"
fi

# 2. Claude Code ---------------------------------------------------------------------------------------
if [ "$DO_CLAUDE" = 1 ]; then
  mkdir -p "$CLAUDE_DIR/skills" "$CLAUDE_DIR/agents"

  if [ -d "$CLAUDE_DIR/skills/aidlc" ]; then
    backup_to "$CLAUDE_DIR/skills/aidlc" "$BACKUP/claude/skills/aidlc"
    rm -rf "$CLAUDE_DIR/skills/aidlc"
  fi
  cp -R "$KIT_HOME/claude/skills/aidlc" "$CLAUDE_DIR/skills/aidlc"
  say "✓ Claude Code command: /aidlc"

  backup_to "$CLAUDE_DIR/agents/aidlc-reviewer.md" "$BACKUP/claude/agents/aidlc-reviewer.md"
  cp "$KIT_HOME/claude/agents/aidlc-reviewer.md" "$CLAUDE_DIR/agents/aidlc-reviewer.md"
  say "✓ Claude Code agent: aidlc-reviewer"

  # The v1 kit installed a Flutter-only reviewer; v2 replaces it.
  legacy="$CLAUDE_DIR/agents/flutter-reviewer.md"
  if [ -f "$legacy" ] && grep -q "AI-DLC" "$legacy"; then
    backup_to "$legacy" "$BACKUP/claude/agents/flutter-reviewer.md"
    rm -f "$legacy"
    say "✓ removed the v1 flutter-reviewer agent (backup kept)"
  fi

  if [ "$DO_HOOKS" = 1 ]; then
    settings="$CLAUDE_DIR/settings.json"
    backup_to "$settings" "$BACKUP/claude/settings.json"
    settings_hooks add "$settings" "$KIT_HOME/claude/hooks"
    say "✓ Claude Code hooks in $settings: plan gate · plan check · session start · auto-format (new files) · learning hint"
  fi

  tmp="$(mktemp)"
  render_with_block "$CLAUDE_DIR/CLAUDE.md" "$KIT_HOME/global/claude-block.md" bottom > "$tmp"
  if ! cmp -s "$tmp" "$CLAUDE_DIR/CLAUDE.md" 2>/dev/null; then
    backup_to "$CLAUDE_DIR/CLAUDE.md" "$BACKUP/claude/CLAUDE.md"
    cat "$tmp" > "$CLAUDE_DIR/CLAUDE.md"
  fi
  rm -f "$tmp"
  say "✓ plan-first rule for every project: $CLAUDE_DIR/CLAUDE.md"
fi

# 3. Antigravity / Gemini ------------------------------------------------------------------------------
if [ "$DO_GEMINI" = 1 ]; then
  mkdir -p "$GEMINI_DIR"
  tmp="$(mktemp)"
  render_with_block "$GEMINI_DIR/GEMINI.md" "$KIT_HOME/global/gemini-block.md" bottom > "$tmp"
  if ! cmp -s "$tmp" "$GEMINI_DIR/GEMINI.md" 2>/dev/null; then
    backup_to "$GEMINI_DIR/GEMINI.md" "$BACKUP/gemini/GEMINI.md"
    cat "$tmp" > "$GEMINI_DIR/GEMINI.md"
  fi
  rm -f "$tmp"
  say "✓ plan-first rule for every project (Antigravity / Gemini): $GEMINI_DIR/GEMINI.md"
fi

# 4. Check ---------------------------------------------------------------------------------------------
say ""
bash "$KIT_HOME/claude/bin/doctor.sh" --machine || true

say ""
say "Next steps (GUIDE.md §2)"
say "  2. Once per project (preview first with --dry-run; --migrate if it has old .agents rules like agent-workflow.md):"
say "       bash \"$KIT_HOME/init-project.sh\" /path/to/project"
say "  3. Commit the pack, in the project folder:"
say "       git add AGENTS.md CLAUDE.md GEMINI.md .agents aidlc-docs .gitignore && git commit -m \"chore: add AI-DLC\""
say "  Then open the project. Claude Code: start a new session and type /aidlc analyze."
say "  Antigravity / Gemini: say \"analyze this project\"."
[ -d "$BACKUP" ] && say "  Backups of changed files: $BACKUP"
say "  Remove everything: bash \"$KIT_HOME/uninstall.sh\""
