#!/usr/bin/env bash
# AI-DLC kit: remove the machine installation (Claude Code command, agent, hooks, global rules, ~/.aidlc-kit).
# Projects are NOT changed. Copies of everything removed or edited go to ~/.aidlc-kit-uninstall-<time>/.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/kit.sh
. "$SRC/lib/kit.sh"

KEEP_HOME=0
for arg in "$@"; do
  case "$arg" in
    --keep-home) KEEP_HOME=1 ;;
    -h|--help) say "Usage: bash uninstall.sh [--keep-home]   (--keep-home keeps ~/.aidlc-kit, its config and backups)"; exit 0 ;;
    *) die "unknown option: $arg" ;;
  esac
done

KIT_HOME="${AIDLC_KIT_HOME:-$HOME/.aidlc-kit}"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
GEMINI_DIR="${AIDLC_GEMINI_DIR:-$HOME/.gemini}"
SAFE="$HOME/.aidlc-kit-uninstall-$(date +%Y%m%d-%H%M%S)-$$"
case "$KIT_HOME" in
  ""|"/"|"$HOME"|"$HOME/") die "unsafe kit folder '$KIT_HOME': set AIDLC_KIT_HOME to the kit's own folder" ;;
esac

say "AI-DLC kit: uninstall"

if [ -f "$CLAUDE_DIR/settings.json" ] && grep -q "claude/hooks/" "$CLAUDE_DIR/settings.json"; then
  backup_to "$CLAUDE_DIR/settings.json" "$SAFE/claude/settings.json"
  settings_hooks remove "$CLAUDE_DIR/settings.json" ""
  say "✓ removed the AI-DLC hooks from $CLAUDE_DIR/settings.json (other settings kept)"
fi

for pair in "$CLAUDE_DIR/CLAUDE.md:claude" "$GEMINI_DIR/GEMINI.md:gemini"; do
  file="${pair%:*}"; tag="${pair##*:}"
  if [ -f "$file" ] && grep -q '<!-- AIDLC:BEGIN' "$file"; then
    backup_to "$file" "$SAFE/$tag/$(basename "$file")"
    tmp="$(mktemp)"
    render_without_block "$file" > "$tmp"
    if [ -s "$tmp" ]; then cat "$tmp" > "$file"; else rm -f "$file"; fi
    rm -f "$tmp"
    say "✓ removed the plan-first rule from $file (your own text kept)"
  fi
done

if [ -d "$CLAUDE_DIR/skills/aidlc" ]; then
  backup_to "$CLAUDE_DIR/skills/aidlc" "$SAFE/claude/skills/aidlc"
  rm -rf "$CLAUDE_DIR/skills/aidlc"
  say "✓ removed the /aidlc command"
fi
if [ -f "$CLAUDE_DIR/agents/aidlc-reviewer.md" ]; then
  backup_to "$CLAUDE_DIR/agents/aidlc-reviewer.md" "$SAFE/claude/agents/aidlc-reviewer.md"
  rm -f "$CLAUDE_DIR/agents/aidlc-reviewer.md"
  say "✓ removed the aidlc-reviewer agent"
fi

if [ "$KEEP_HOME" = 0 ] && [ -d "$KIT_HOME" ]; then
  if [ -f "$KIT_HOME/VERSION" ] && [ -d "$KIT_HOME/claude/hooks" ]; then
    backup_to "$KIT_HOME/config" "$SAFE/kit/config"
    backup_to "$KIT_HOME/backups" "$SAFE/kit/backups"
    backup_to "$KIT_HOME/brain" "$SAFE/kit/brain"
    [ -d "$SAFE/kit/brain" ] && say "✓ your shared brain is saved in $SAFE/kit/brain (copy it back to ~/.aidlc-kit/brain after a reinstall)"
    rm -rf "${KIT_HOME:?}"
    say "✓ removed $KIT_HOME"
  else
    warn "$KIT_HOME does not look like the AI-DLC kit; left it alone"
  fi
fi

say ""
[ -d "$SAFE" ] && say "Copies of everything removed or edited: $SAFE"
say "Projects were not changed. To remove AI-DLC from a project as well, run remove-project.sh from a kit"
say "folder (best before uninstalling: bash ~/.aidlc-kit/remove-project.sh <project> --dry-run)."
