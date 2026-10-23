#!/usr/bin/env bash
# AI-DLC kit: Claude Code SessionStart hook. Prints project context for Claude (stdout). Never blocks.

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

input="$(cat)"
start="${CLAUDE_PROJECT_DIR:-}"
[ -n "$start" ] || start="$(json_get "$input" .cwd)"
[ -n "$start" ] || start="$PWD"
mode="$(aidlc_config AIDLC_ENFORCE project)"

# 1. AI-DLC workspace: show where the work stands.
root="$(find_up "$start" aidlc-docs/aidlc-state.md)" || root=""
if [ -n "$root" ]; then
  state="$root/aidlc-docs/aidlc-state.md"
  v() { local x; x="$(state_get "$state" "$1")"; printf '%s' "${x:-?}"; }
  next="$(awk '/^## Next action/ {inside=1; next} /^## / {inside=0} inside && NF {print; exit}' "$state")"
  rules="$(cd "$root/.agents/rules" 2>/dev/null && ls -- *.md 2>/dev/null | sed 's/\.md$//' | tr '\n' ',' | sed -e 's/,$//' -e 's/,/, /g')"
  cat <<EOF
[AI-DLC] Project: $root
Follow AGENTS.md and the rules in .agents/rules/ (${rules:-none found}). Plan first: no file changes without a plan the user approved.
State: mode=$(v mode) · work item=$(v work_item) ($(v type)) · stage=$(v stage) · code gate=$(v code_gate) · active plan=$(v active_plan)
Next action: ${next:-see aidlc-docs/aidlc-state.md}
Before planning or coding, read aidlc-docs/aidlc-state.md and .agents/skills/project-architecture/SKILL.md. The /aidlc command shows status and routes requests.
EOF
  brain="$root/aidlc-docs/brain"
  if [ -f "$brain/INDEX.md" ]; then
    active="$(grep -c '^- \[' "$brain/INDEX.md" 2>/dev/null)"
    shared="$(grep -c '^- \[' "$root/.agents/brain/shared/INDEX.md" 2>/dev/null)"
    inbox="$(grep -cE '^\| [0-9]+ \|' "$brain/inbox.md" 2>/dev/null)"
    echo "Brain: ${active:-0} project lessons · ${shared:-0} shared lessons · ${inbox:-0} waiting in the inbox. Recall them before planning; capture corrections and failures as they happen (30-learning.md)."
  fi
  pack="$(grep -m 1 '^version=' "$root/.agents/.aidlc-version" 2>/dev/null | cut -d= -f2)"
  kit="$(cat "$AIDLC_KIT_HOME/VERSION" 2>/dev/null)"
  if [ -n "$pack" ] && [ -n "$kit" ] && version_lt "$pack" "$kit"; then
    echo "Update available: this project's AI-DLC pack is $pack, the kit on this machine is $kit. Tell the user at the start of your reply and offer the update (run it only after they agree): bash ~/.aidlc-kit/init-project.sh \"$root\" --dry-run to preview, then without --dry-run. Their project-owned files are kept."
  elif [ -n "$pack" ] && [ -n "$kit" ] && version_lt "$kit" "$pack"; then
    echo "Note: this project's AI-DLC pack ($pack) is newer than the kit on this machine ($kit). Tell the user to update the kit (run install.sh from the newer kit)."
  fi
  [ "$mode" = "off" ] && echo "Note: hook enforcement is off (AIDLC_ENFORCE=off). The rules still apply."
  exit 0
fi

base="$(git -C "$start" rev-parse --show-toplevel 2>/dev/null)" || base=""
in_repo=1
[ -n "$base" ] || { base="$start"; in_repo=0; }

# 2. Pack installed but state missing.
if [ -f "$base/.agents/rules/00-aidlc-core.md" ]; then
  echo "[AI-DLC] The AI-DLC pack is installed in $base but aidlc-docs/aidlc-state.md is missing. Run /aidlc init to repair it. Plan first: no file changes without an approved plan."
  exit 0
fi

# 3. Other agents' instructions in .agents/ (e.g. Antigravity): Claude Code does not load them by itself.
rules=""; skills=""
for f in "$base"/.agents/rules/*.md; do [ -f "$f" ] && rules="$rules ${f#"$base"/}"; done
for d in "$base"/.agents/skills/*/; do [ -f "${d}SKILL.md" ] && skills="$skills ${d#"$base"/}SKILL.md"; done
if [ -n "$rules$skills" ]; then
  echo "[AI-DLC] This project has agent instructions in .agents/ (written for other agents; they apply to Claude Code too)."
  [ -n "$rules" ] && echo "Rules (read and follow before doing anything):$rules"
  [ -n "$skills" ] && echo "Skills (read the one that fits the task):$skills"
  echo "Tip: /aidlc init adds the full AI-DLC pack (use --migrate to merge old workflow rules)."
  exit 0
fi

# 4. Enforcement for every repository.
if [ "$mode" = "all-repos" ] && [ "$in_repo" = 1 ]; then
  echo "[AI-DLC] Enforcement is set to all-repos and this repository has no AI-DLC workspace. Run /aidlc init before changing files. Plan first."
fi
exit 0
