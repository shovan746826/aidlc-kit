#!/usr/bin/env bash
# AI-DLC kit: add or update the AI-DLC pack in a project. Works for every agent; Claude Code is not required.
#   • kit-owned files (rules 00/10/30, workflow skills, templates, shared-brain copy) are added or updated;
#     changed ones backed up
#   • project-owned files are never overwritten: aidlc-docs/ and the architecture standard (the skill, its
#     reference files and 20-architecture.md, always handled as one set; --update-architecture replaces it)
#   • AGENTS.md, CLAUDE.md and GEMINI.md get an AI-DLC block; your own text in them is kept
# Safe to run again: it only changes what differs from the kit.
set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/kit.sh
. "$KIT/lib/kit.sh"

usage() {
  cat <<'EOF'
Usage: bash init-project.sh [project-folder] [options]
  project-folder            default: the current folder
  --standard <name>         auto (default) | flutter | android | ios | generic. Needed for a new app in an
                            empty folder (there is nothing to detect yet). Re-runs keep the installed standard.
  --migrate                 archive old workflow rules (.agents/rules/*workflow*.md, e.g. agent-workflow.md)
                            into .agents/archive/<time>/. Their rules are already merged into the AI-DLC rules.
                            The project's architecture standard is not touched.
  --update-architecture     switch to the kit's standard: replace the architecture skill, its reference files
                            and 20-architecture.md together (the project's own versions go to
                            .agents/archive/<time>/, kit-made ones to .agents/.backup/<time>/)
  --dry-run                 show what would change, change nothing
  -h, --help
EOF
}

PROJECT=""; STANDARD="auto"; MIGRATE=0; UPDATE_ARCH=0; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --standard) [ $# -ge 2 ] || die "--standard needs a value"; STANDARD="$2"; shift 2 ;;
    --standard=*) STANDARD="${1#*=}"; shift ;;
    --migrate) MIGRATE=1; shift ;;
    --update-architecture) UPDATE_ARCH=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) usage; die "unknown option: $1" ;;
    *) [ -z "$PROJECT" ] || die "give only one project folder"; PROJECT="$1"; shift ;;
  esac
done

PROJECT="${PROJECT:-$PWD}"
[ -d "$PROJECT" ] || die "not a folder: $PROJECT"
PROJECT="$(cd "$PROJECT" && pwd)"
case "$PROJECT" in "/"|"$HOME") die "refusing to set up AI-DLC in $PROJECT: choose a project folder" ;; esac

detect_standard() {
  local p="$1" x
  if [ -f "$p/pubspec.yaml" ] && grep -Eq '^[[:space:]]+sdk:[[:space:]]*flutter' "$p/pubspec.yaml"; then echo flutter; return; fi
  for x in "$p"/settings.gradle "$p"/settings.gradle.kts "$p"/app/build.gradle "$p"/app/build.gradle.kts; do
    if [ -f "$x" ]; then echo android; return; fi
  done
  for x in "$p"/*.xcodeproj "$p"/*.xcworkspace "$p"/Package.swift; do
    if [ -e "$x" ]; then echo ios; return; fi
  done
  echo generic
}

# standard_of <file> → what an architecture file is: flutter | android | ios (kit-made) | placeholder (generic,
# not generated yet) | generated (generated for this project) | custom (no kit marker) | none (missing).
standard_of() {
  [ -f "$1" ] || { echo none; return 0; }
  local marker
  marker="$(grep -m 1 -o 'aidlc-kit:standard=[^>]*' "$1" 2>/dev/null || true)"
  case "$marker" in
    "") echo custom ;;
    *"NOT GENERATED"*) echo placeholder ;;
    *) printf '%s\n' "$marker" | sed -E 's/^aidlc-kit:standard=([a-z]+).*/\1/' ;;
  esac
}

# is_empty_project <dir>: nothing in it yet except git, editor, readme/license and AI-DLC files.
is_empty_project() {
  local f
  for f in "$1"/* "$1"/.[!.]* "$1"/..?*; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in
      .git|.gitignore|.gitattributes|.DS_Store|.idea|.vscode|.claude|README*|readme*|LICENSE*|license*) ;;
      AGENTS.md|CLAUDE.md|CLAUDE.local.md|GEMINI.md|.agents|aidlc-docs) ;;
      *) return 1 ;;
    esac
  done
  return 0
}

RECORDED="$(grep -m 1 '^standard=' "$PROJECT/.agents/.aidlc-version" 2>/dev/null | cut -d= -f2 || true)"
how="given"
if [ "$STANDARD" = "auto" ]; then
  case "$RECORDED" in
    flutter|android|ios) STANDARD="$RECORDED"; how="installed earlier" ;;
    *)
      STANDARD="$(detect_standard "$PROJECT")"; how="detected"
      if [ "$STANDARD" = "generic" ] && [ -z "$RECORDED" ] && is_empty_project "$PROJECT"; then
        die "this folder is empty, so the stack cannot be detected. For a new app, choose the standard:
    bash \"$KIT/init-project.sh\" \"$PROJECT\" --standard flutter     (or android, ios, generic)
Nothing was changed."
      fi ;;
  esac
fi
case "$STANDARD" in flutter|android|ios|generic) ;; *) die "unknown standard: $STANDARD (use flutter, android, ios or generic)" ;; esac

VERSION="$(cat "$KIT/VERSION")"
STAMP="$(date +%Y%m%d-%H%M%S)-$$"
NOW="$(date '+%Y-%m-%d %H:%M')"
BACKUP_DIR="$PROJECT/.agents/.backup/$STAMP"
ARCHIVE_DIR="$PROJECT/.agents/archive/$STAMP"
ADDED=""; UPDATED=""; KEPT=""; ARCHIVED=""; REMOVED=""; NOTES=""; BACKED_UP=0
NL='
'

# write_file <source> <relative-destination>: install a kit file; back up a different existing file.
write_file() {
  local src="$1" rel="$2" dst="$PROJECT/$2"
  if [ -f "$dst" ]; then
    cmp -s "$src" "$dst" && return 0
    UPDATED="$UPDATED$NL  ~ $rel"
    [ "$DRY" = 1 ] && return 0
    backup_to "$dst" "$BACKUP_DIR/$rel"
    BACKED_UP=1
  else
    ADDED="$ADDED$NL  + $rel"
    [ "$DRY" = 1 ] && return 0
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
}

# write_generated <relative-destination> <command...>: run the command, install its output.
# (No pipes into write_file: a pipe runs it in a subshell and loses the change lists.)
write_generated() {
  local rel="$1" tmp
  shift
  tmp="$(mktemp)"
  "$@" > "$tmp"
  chmod 644 "$tmp"   # mktemp files are private (600); project files must be readable like the others
  write_file "$tmp" "$rel"
  rm -f "$tmp"
  # Kit versions before 2.2 created these files private: make them normal again.
  if [ "$DRY" = 0 ] && [ "$(ls -ld "$PROJECT/$rel" 2>/dev/null | cut -c1-10)" = "-rw-------" ]; then
    chmod 644 "$PROJECT/$rel"
  fi
}

version_file() { printf 'version=%s\nstandard=%s\n' "$VERSION" "$INSTALLED_STD"; }

gitignore_with_backup_rule() {
  if [ -s "$PROJECT/.gitignore" ]; then strip_trailing_blank < "$PROJECT/.gitignore"; printf '\n'; fi
  printf '# AI-DLC kit: backups of replaced files\n.agents/.backup/\n'
}

# archive_file <relative-path>: move it into .agents/archive/<time>/ (--migrate: old workflow rules;
# --update-architecture: the project's own architecture files).
archive_file() {
  local dest="$ARCHIVE_DIR/${1#.agents/}"
  ARCHIVED="$ARCHIVED$NL  → $1  (to ${dest#"$PROJECT"/})"
  [ "$DRY" = 1 ] && return 0
  mkdir -p "$(dirname "$dest")"
  mv "$PROJECT/$1" "$dest"
}

# 1. Old agent rules ---------------------------------------------------------------------------------------
if [ -d "$PROJECT/.agents/rules" ]; then
  for f in "$PROJECT"/.agents/rules/*.md; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    if [ "$name" = "20-architecture.md" ] || [ -f "$KIT/pack/.agents/rules/$name" ]; then continue; fi   # the kit's own rules
    case "$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')" in
      *workflow*)
        if [ "$MIGRATE" = 1 ]; then
          archive_file ".agents/rules/$name"
        else
          NOTES="$NOTES$NL  ! .agents/rules/$name looks like an old workflow rule. Its rules are merged into the AI-DLC rules; re-run with --migrate to archive it."
        fi ;;
      *) NOTES="$NOTES$NL  ! .agents/rules/$name is kept: check that it does not conflict with the AI-DLC rules." ;;
    esac
  done
fi

# 2. Kit-owned files ---------------------------------------------------------------------------------------
while IFS= read -r rel; do
  write_file "$KIT/pack/$rel" "$rel"
done < <(cd "$KIT/pack" && find .agents -type f ! -name '.DS_Store' | sort)

# 3. The architecture standard (project-owned): SKILL.md, its reference files and 20-architecture.md -----------
# are one set. Missing → installed. --update-architecture, or the untouched generic placeholder when a real
# stack is chosen → replaced together. Otherwise kept, with a note when the kit has something different.
SKILL_REL=".agents/skills/project-architecture/SKILL.md"
RULES_REL=".agents/rules/20-architecture.md"
REF_REL=".agents/skills/project-architecture/reference"
STD_SRC="$KIT/standards/$STANDARD"
SKILL_WAS="$(standard_of "$PROJECT/$SKILL_REL")"
RULES_WAS="$(standard_of "$PROJECT/$RULES_REL")"
REPLACE_SET=0
if [ "$UPDATE_ARCH" = 1 ] || { [ "$SKILL_WAS" = placeholder ] && [ "$STANDARD" != generic ]; }; then REPLACE_SET=1; fi

# std_label <file> → e.g. "house standard v3" (empty for older files without a version).
std_label() { grep -m 1 -o 'house standard v[0-9][0-9.]*' "$1" 2>/dev/null || true; }

install_standard_file() { # <source> <relative destination>
  local src="$1" rel="$2" was
  was="$(standard_of "$PROJECT/$rel")"
  if [ "$was" = none ]; then
    write_file "$src" "$rel"
  elif [ "$REPLACE_SET" = 1 ]; then
    case "$was" in
      custom|generated)   # the project's own work: keep it visible in .agents/archive/ (committed)
        archive_file "$rel"
        if [ "$DRY" = 1 ]; then ADDED="$ADDED$NL  + $rel"; else write_file "$src" "$rel"; fi ;;
      *) write_file "$src" "$rel" ;;   # kit-made or placeholder: the old copy goes to .agents/.backup/
    esac
  else
    KEPT="$KEPT$NL  = $rel (project-owned, kept)"
  fi
}
install_standard_file "$STD_SRC/SKILL.md" "$SKILL_REL"
install_standard_file "$STD_SRC/architecture-rules.md" "$RULES_REL"

# Reference files (complete code for the standard) belong to the kit's SKILL.md: installed with it, never
# next to a different skill.
if [ -d "$STD_SRC/reference" ]; then
  if [ "$SKILL_WAS" = none ] || [ "$REPLACE_SET" = 1 ] || cmp -s "$STD_SRC/SKILL.md" "$PROJECT/$SKILL_REL"; then
    for f in "$STD_SRC"/reference/*.md; do
      [ -f "$f" ] || continue
      if [ "$REPLACE_SET" = 1 ] || [ ! -f "$PROJECT/$REF_REL/$(basename "$f")" ]; then
        write_file "$f" "$REF_REL/$(basename "$f")"
      fi
    done
  fi
fi
if [ "$REPLACE_SET" = 1 ]; then   # reference files the new standard no longer has
  for f in "$PROJECT/$REF_REL"/*.md; do
    [ -f "$f" ] || continue
    [ -f "$STD_SRC/reference/$(basename "$f")" ] && continue
    REMOVED="$REMOVED$NL  - $REF_REL/$(basename "$f")  (saved in ${BACKUP_DIR#"$PROJECT"/}/)"
    [ "$DRY" = 1 ] && continue
    backup_to "$f" "$BACKUP_DIR/$REF_REL/$(basename "$f")"; BACKED_UP=1
    rm -f "$f"
  done
fi

# The standard really installed now (recorded in .agents/.aidlc-version; re-runs keep it).
if [ "$SKILL_WAS" = none ] || [ "$REPLACE_SET" = 1 ]; then INSTALLED_STD="$STANDARD"
elif [ "$SKILL_WAS" = placeholder ]; then INSTALLED_STD="generic"
else INSTALLED_STD="$SKILL_WAS"; fi

if [ "$REPLACE_SET" = 0 ]; then
  case "$SKILL_WAS" in
    custom|generated)
      [ "$STANDARD" != generic ] && NOTES="$NOTES$NL  • This project has its own architecture standard (kept). To use the kit's $STANDARD standard instead, add --update-architecture (yours is archived in .agents/archive/)." ;;
    placeholder)
      NOTES="$NOTES$NL  • The architecture standard is not generated yet: ask the agent to analyze the project (it generates it for your approval)." ;;
    flutter|android|ios)
      if [ "$SKILL_WAS" != "$STANDARD" ]; then
        NOTES="$NOTES$NL  ! The architecture files are the $SKILL_WAS standard, but $STANDARD was $how. They are kept. To replace them, add --update-architecture (a backup is kept)."
      elif ! cmp -s "$STD_SRC/SKILL.md" "$PROJECT/$SKILL_REL" || ! cmp -s "$STD_SRC/architecture-rules.md" "$PROJECT/$RULES_REL"; then
        kit_label="$(std_label "$STD_SRC/SKILL.md")"
        NOTES="$NOTES$NL  • The kit has a different version of the $STANDARD standard${kit_label:+ ($kit_label)}. Yours is kept (it belongs to the project). To switch, add --update-architecture (your files are backed up)."
      fi ;;
  esac
  # After this run (a missing file is added from the kit): do the skill and its rules still match?
  kind_after() { if [ "$1" != none ]; then echo "$1"; elif [ "$STANDARD" = generic ]; then echo placeholder; else echo "$STANDARD"; fi; }
  label_after() { if [ "$1" != none ]; then std_label "$2"; else std_label "$3"; fi; }
  skill_kind="$(kind_after "$SKILL_WAS")"; rules_kind="$(kind_after "$RULES_WAS")"
  skill_label="$(label_after "$SKILL_WAS" "$PROJECT/$SKILL_REL" "$STD_SRC/SKILL.md")"
  rules_label="$(label_after "$RULES_WAS" "$PROJECT/$RULES_REL" "$STD_SRC/architecture-rules.md")"
  if [ "$skill_kind" != "$rules_kind" ] || [ "$skill_label" != "$rules_label" ]; then
    NOTES="$NOTES$NL  ! The architecture skill ($skill_kind${skill_label:+, $skill_label}) and 20-architecture.md ($rules_kind${rules_label:+, $rules_label}) come from different versions: make them agree, or add --update-architecture."
  fi
fi
write_generated ".agents/.aidlc-version" version_file

# 4. Agent entry files -----------------------------------------------------------------------------------------
for entry in AGENTS.md CLAUDE.md GEMINI.md; do
  write_generated "$entry" render_with_block "$PROJECT/$entry" "$KIT/pack/$entry" top
done

# 5. Workspace ---------------------------------------------------------------------------------------------------
new_workspace=0
if [ ! -f "$PROJECT/aidlc-docs/aidlc-state.md" ]; then
  new_workspace=1
  write_file "$KIT/pack/.agents/templates/aidlc-state.md" "aidlc-docs/aidlc-state.md"
fi
[ -f "$PROJECT/aidlc-docs/audit-log.md" ] || write_file "$KIT/pack/.agents/templates/audit-log.md" "aidlc-docs/audit-log.md"

# 5b. Brain: the project's own brain (project-owned, never overwritten) + a copy of the shared brain
for pair in "brain-index.md:INDEX.md" "brain-inbox.md:inbox.md" "metrics.md:metrics.md"; do
  tpl="${pair%%:*}"; dst="aidlc-docs/brain/${pair##*:}"
  [ -f "$PROJECT/$dst" ] || write_file "$KIT/pack/.agents/templates/$tpl" "$dst"
done
SHARED_SRC="${AIDLC_KIT_HOME:-$HOME/.aidlc-kit}/brain"
[ -f "$SHARED_SRC/INDEX.md" ] || SHARED_SRC="$KIT/brain"
if [ -f "$SHARED_SRC/INDEX.md" ]; then
  write_file "$SHARED_SRC/INDEX.md" ".agents/brain/shared/INDEX.md"
  for lesson in "$SHARED_SRC"/lessons/*.md; do
    [ -f "$lesson" ] && write_file "$lesson" ".agents/brain/shared/lessons/$(basename "$lesson")"
  done
  for lesson in "$PROJECT"/.agents/brain/shared/lessons/*.md; do   # a mirror: drop lessons the shared brain removed
    [ -f "$lesson" ] || continue
    [ -f "$SHARED_SRC/lessons/$(basename "$lesson")" ] && continue
    REMOVED="$REMOVED$NL  - .agents/brain/shared/lessons/$(basename "$lesson")  (no longer in the shared brain)"
    [ "$DRY" = 1 ] || rm -f "$lesson"
  done
fi

# 6. Keep backups out of git -------------------------------------------------------------------------------------
if git -C "$PROJECT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if ! grep -qx '.agents/.backup/' "$PROJECT/.gitignore" 2>/dev/null; then
    write_generated ".gitignore" gitignore_with_backup_rule
  fi
else
  NOTES="$NOTES$NL  ! This folder is not a git repository. Use git so every AI change can be reviewed and undone."
fi

# 7. Audit log -----------------------------------------------------------------------------------------------------
if [ "$DRY" = 0 ] && [ -n "$ADDED$UPDATED$ARCHIVED$REMOVED" ]; then
  event="UPDATE"; [ "$new_workspace" = 1 ] && event="INIT"
  extra=""
  [ "$MIGRATE" = 1 ] && [ -n "$ARCHIVED" ] && extra="$extra · archived old workflow rules"
  [ "$REPLACE_SET" = 1 ] && [ "$SKILL_WAS" != none ] && extra="$extra · replaced the architecture standard ($SKILL_WAS → $STANDARD)"
  printf '| %s | none | init-project.sh | %s | aidlc-kit v%s · standard: %s%s |\n' \
    "$NOW" "$event" "$VERSION" "$INSTALLED_STD" "$extra" >> "$PROJECT/aidlc-docs/audit-log.md"
fi

# 8. Summary -------------------------------------------------------------------------------------------------------
[ "$DRY" = 1 ] && say "DRY RUN: nothing was changed."
say "AI-DLC pack v$VERSION → $PROJECT"
if [ "$INSTALLED_STD" = "$STANDARD" ]; then
  say "Architecture standard: $STANDARD ($how)"
else
  say "Architecture standard: $INSTALLED_STD (the project's own, kept) · kit standard for this stack: $STANDARD ($how)"
fi
[ -n "$ADDED" ]    && say "Added:$ADDED"
[ -n "$UPDATED" ]  && say "Updated:$UPDATED"
[ "$BACKED_UP" = 1 ] && say "  (previous versions saved in ${BACKUP_DIR#"$PROJECT"/}/)"
[ -n "$ARCHIVED" ] && say "Archived:$ARCHIVED"
[ -n "$REMOVED" ]  && say "Removed:$REMOVED"
[ -n "$KEPT" ]     && say "Kept:$KEPT"
[ -z "$ADDED$UPDATED$ARCHIVED$REMOVED" ] && say "Everything is up to date."
[ -n "$NOTES" ]    && say "Notes:$NOTES"
if [ "$INSTALLED_STD" = "android" ] || [ "$INSTALLED_STD" = "ios" ]; then
  say "  ! The $INSTALLED_STD standard is a proposed v1: review .agents/skills/project-architecture/SKILL.md."
fi
if [ "$DRY" = 0 ] && [ -n "$ADDED" ]; then
  say ""
  say "Next steps"
  say "  1. Review the changes, then commit the pack:"
  say "       cd \"$PROJECT\" && git add AGENTS.md CLAUDE.md GEMINI.md .agents aidlc-docs .gitignore && git commit -m \"chore: add AI-DLC\""
  say "  2. Claude Code: start a NEW session in this project, then type /aidlc analyze"
  say "     Antigravity / Gemini: open the project and say \"analyze this project\""
  say "  3. Then ask for what you want: a new feature, a change, a bug fix or a release. The agent asks"
  say "     questions, writes the plan and waits for your approval before it changes any file."
fi
