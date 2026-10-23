#!/usr/bin/env bash
# AI-DLC kit: remove the AI-DLC pack from one project (the machine install stays).
#   bash remove-project.sh <project> [--dry-run] [--all]
# Removes: the AI-DLC blocks in AGENTS.md, CLAUDE.md and GEMINI.md (your own text stays; a file left empty is
#   deleted), the kit's own files in .agents/, the AI-DLC lines in .gitignore, and aidlc-docs/aidlc-state.md
#   (it switches on the plan gate and the session context).
# Keeps: your architecture standard (.agents/rules/20-architecture.md, .agents/skills/project-architecture/),
#   old files moved aside by --migrate (.agents/archive/), the rest of aidlc-docs/ (plans, decisions, project
#   brain) and every other file of yours. --all also removes the standard, the archive and aidlc-docs/.
# Everything removed or changed is copied first to ~/.aidlc-kit/backups/<time>-removed-<project>/.
set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/kit.sh
. "$KIT/lib/kit.sh"

usage() { sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

PROJECT=""; DRY=0; ALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --all) ALL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) usage; die "unknown option: $1" ;;
    *) [ -z "$PROJECT" ] || die "give only one project folder"; PROJECT="$1"; shift ;;
  esac
done
[ -n "$PROJECT" ] || { usage; die "name the project folder"; }
[ -d "$PROJECT" ] || die "not a folder: $PROJECT"
PROJECT="$(cd "$PROJECT" && pwd)"
case "$PROJECT" in "/"|"$HOME") die "refusing to work on $PROJECT: choose a project folder" ;; esac
if [ ! -f "$PROJECT/.agents/rules/00-aidlc-core.md" ] && [ ! -f "$PROJECT/aidlc-docs/aidlc-state.md" ] \
   && ! grep -qs '<!-- AIDLC:BEGIN' "$PROJECT/AGENTS.md" "$PROJECT/CLAUDE.md" "$PROJECT/GEMINI.md"; then
  die "no AI-DLC pack found in $PROJECT"
fi

KIT_HOME="${AIDLC_KIT_HOME:-$HOME/.aidlc-kit}"
SAFE="$KIT_HOME/backups/$(date +%Y%m%d-%H%M%S)-$$-removed-$(basename "$PROJECT")"
REMOVED=""; CHANGED=""; KEPT=""
NL='
'

# take_out <relative path>: copy it to the backup folder, then delete it (a file or a folder).
take_out() {
  local rel="$1"
  case "$rel" in ""|/*|*..*) die "unsafe path: '$rel'" ;; esac
  [ -e "$PROJECT/$rel" ] || return 0
  REMOVED="$REMOVED$NL  - $rel"
  [ "$DRY" = 1 ] && return 0
  backup_to "$PROJECT/$rel" "$SAFE/$rel"
  rm -rf "${PROJECT:?}/$rel"
}

# rewrite <relative path> <new content>: copy the old file to the backup folder, then write the new content.
rewrite() {
  CHANGED="$CHANGED$NL  ~ $1"
  [ "$DRY" = 1 ] && return 0
  backup_to "$PROJECT/$1" "$SAFE/$1"
  printf '%s\n' "$2" > "$PROJECT/$1"
}

# 1. The AI-DLC blocks in the agent entry files (your own text stays)
for entry in AGENTS.md CLAUDE.md GEMINI.md; do
  if [ -f "$PROJECT/$entry" ] && grep -q '<!-- AIDLC:BEGIN' "$PROJECT/$entry"; then
    rest="$(render_without_block "$PROJECT/$entry")"
    if [ -z "$(printf '%s' "$rest" | tr -d '[:space:]')" ]; then take_out "$entry"; else rewrite "$entry" "$rest"; fi
  fi
done

# 2. The kit's own files in .agents/ (only paths the kit itself ships)
while IFS= read -r rel; do take_out "$rel"; done < <(cd "$KIT/pack" && find .agents -type f ! -name '.DS_Store' | sort)
for rel in .agents/brain/shared .agents/.aidlc-version .agents/.backup; do take_out "$rel"; done

# 3. Your AI-DLC work: kept (the state file goes, so the plan gate and session context stop), or all of it
if [ "$ALL" = 1 ]; then
  for rel in .agents/rules/20-architecture.md .agents/skills/project-architecture .agents/archive aidlc-docs; do
    take_out "$rel"
  done
else
  take_out "aidlc-docs/aidlc-state.md"
  for rel in .agents/rules/20-architecture.md .agents/skills/project-architecture .agents/archive aidlc-docs; do
    if [ -e "$PROJECT/$rel" ]; then KEPT="$KEPT$NL  = $rel"; fi
  done
fi

# 4. The AI-DLC lines in .gitignore
if [ -f "$PROJECT/.gitignore" ] && grep -qx '.agents/.backup/' "$PROJECT/.gitignore"; then
  rest="$( { grep -vx '.agents/.backup/' "$PROJECT/.gitignore" || true; } \
    | { grep -vx '# AI-DLC kit: backups of replaced files' || true; } | strip_trailing_blank)"
  if [ -z "$(printf '%s' "$rest" | tr -d '[:space:]')" ]; then take_out ".gitignore"; else rewrite ".gitignore" "$rest"; fi
fi

# 5. Folders left empty
if [ "$DRY" = 0 ] && [ -d "$PROJECT/.agents" ]; then
  find "$PROJECT/.agents" -depth -type d -empty -exec rmdir {} \; 2>/dev/null || true
fi

# 6. Summary
if [ "$DRY" = 1 ]; then say "DRY RUN: nothing was changed. This is what would happen:"; fi
say "AI-DLC pack removed from $PROJECT"
if [ -n "$REMOVED" ]; then say "Removed:$REMOVED"; fi
if [ -n "$CHANGED" ]; then say "Changed (the AI-DLC part only, your text kept):$CHANGED"; fi
if [ -n "$KEPT" ]; then say "Kept (your work; add --all to remove it too):$KEPT"; fi
if [ "$DRY" = 0 ] && [ -d "$SAFE" ]; then say "Copies of everything removed or changed: $SAFE"; fi
say "Next: check with git status, then commit. To add AI-DLC again later: bash \"$KIT_HOME/init-project.sh\" \"$PROJECT\""
exit 0
