#!/usr/bin/env bash
# AI-DLC kit: doctor. Checks the machine installation and (optionally) a project.
# Usage: doctor.sh [project-dir]   (default: current folder)
#        doctor.sh --machine       (machine checks only)

KIT_HOME="${AIDLC_KIT_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export AIDLC_KIT_HOME="$KIT_HOME"
# shellcheck source=../hooks/lib.sh
. "$KIT_HOME/claude/hooks/lib.sh"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
GEMINI_DIR="${AIDLC_GEMINI_DIR:-$HOME/.gemini}"

errors=0
warnings=0
ok()   { printf '  ✓ %s\n' "$1"; }
warn() { printf '  ! %s\n' "$1"; warnings=$((warnings + 1)); }
err()  { printf '  ✗ %s\n' "$1"; errors=$((errors + 1)); }

days_since() { # YYYY-MM-DD → days ago (empty if unknown)
  command -v python3 >/dev/null 2>&1 || return 0
  python3 -c 'import datetime, sys
try:
    d = datetime.date.fromisoformat(sys.argv[1])
    print((datetime.date.today() - d).days)
except Exception:
    pass' "$1" 2>/dev/null
}

machine_only=0
project=""
case "${1:-}" in
  --machine) machine_only=1 ;;
  "") project="$PWD" ;;
  *) project="$1" ;;
esac

echo "AI-DLC doctor"
echo
echo "Machine"
if [ -f "$KIT_HOME/VERSION" ]; then ok "kit $(cat "$KIT_HOME/VERSION") at $KIT_HOME"; else err "kit files not found at $KIT_HOME"; fi
if command -v jq >/dev/null 2>&1; then ok "jq available (hooks read their input with it)"
elif command -v python3 >/dev/null 2>&1; then ok "python3 available (jq not found; hooks use python3)"
else err "neither jq nor python3 found: the hooks cannot read their input and let every edit through"; fi
echo "    settings: AIDLC_ENFORCE=$(aidlc_config AIDLC_ENFORCE project) · AIDLC_GATE_SCOPE=$(aidlc_config AIDLC_GATE_SCOPE plan-files) · AIDLC_AUTOFORMAT=$(aidlc_config AIDLC_AUTOFORMAT new-files) · AIDLC_LEARN_HINTS=$(aidlc_config AIDLC_LEARN_HINTS on)"

if [ -f "$CLAUDE_DIR/skills/aidlc/SKILL.md" ]; then ok "Claude Code: /aidlc command"; else warn "Claude Code: /aidlc command not installed (run install.sh)"; fi
if [ -f "$CLAUDE_DIR/agents/aidlc-reviewer.md" ]; then ok "Claude Code: aidlc-reviewer agent"; else warn "Claude Code: aidlc-reviewer agent not installed"; fi
for h in plan-gate plan-check session-start auto-format learn-hint; do
  if grep -q "claude/hooks/$h.sh" "$CLAUDE_DIR/settings.json" 2>/dev/null; then
    if [ -f "$KIT_HOME/claude/hooks/$h.sh" ]; then ok "Claude Code hook registered: $h"; else err "hook $h is registered but $KIT_HOME/claude/hooks/$h.sh is missing"; fi
  else
    warn "Claude Code hook not registered: $h (run install.sh)"
  fi
done
if grep -q "AIDLC:BEGIN" "$CLAUDE_DIR/CLAUDE.md" 2>/dev/null; then ok "$CLAUDE_DIR/CLAUDE.md has the plan-first rule"; else warn "$CLAUDE_DIR/CLAUDE.md has no plan-first rule"; fi
if grep -q "AIDLC:BEGIN" "$GEMINI_DIR/GEMINI.md" 2>/dev/null; then ok "$GEMINI_DIR/GEMINI.md has the plan-first rule (Antigravity / Gemini)"; else warn "$GEMINI_DIR/GEMINI.md has no plan-first rule (Antigravity / Gemini)"; fi
if [ -f "$KIT_HOME/brain/INDEX.md" ]; then ok "shared brain: $(grep -c '^- \[' "$KIT_HOME/brain/INDEX.md") lessons in $KIT_HOME/brain"; else warn "no shared brain in $KIT_HOME/brain (run install.sh)"; fi
if [ -f "$KIT_HOME/tokens.sh" ]; then ok "token measurement: tokens.sh (reads Claude Code's own records)"; else warn "tokens.sh missing (run install.sh)"; fi
if [ -f "$KIT_HOME/verify-plan.sh" ]; then ok "anti-hallucination plan check: verify-plan.sh"; else warn "verify-plan.sh missing (run install.sh)"; fi

if [ "$machine_only" = 0 ]; then
  root="$(git -C "$project" rev-parse --show-toplevel 2>/dev/null)" || root="$(cd "$project" 2>/dev/null && pwd)"
  echo
  echo "Project: ${root:-$project}"
  if [ -z "$root" ] || [ ! -d "$root" ]; then
    err "folder not found: $project"
  elif [ ! -f "$root/.agents/rules/00-aidlc-core.md" ]; then
    warn "no AI-DLC pack here. Add it with: bash $KIT_HOME/init-project.sh \"$root\""
    for f in "$root"/.agents/rules/*.md; do [ -f "$f" ] && warn "other agent rule found: ${f#"$root"/}"; done
  else
    for f in .agents/rules/00-aidlc-core.md .agents/rules/10-quality-gates.md .agents/rules/20-architecture.md \
             .agents/rules/30-learning.md .agents/rules/40-token-efficiency.md .agents/rules/50-anti-hallucination.md \
             .agents/skills/project-architecture/SKILL.md; do
      if [ -f "$root/$f" ]; then ok "$f"; else err "missing $f"; fi
    done
    missing=""
    for s in project-analysis aidlc-new-project aidlc-feature aidlc-bugfix aidlc-construction aidlc-release \
             aidlc-think aidlc-reflect aidlc-research aidlc-prompt aidlc-anti-hallucination; do
      [ -f "$root/.agents/skills/$s/SKILL.md" ] || missing="$missing $s"
    done
    if [ -z "$missing" ]; then ok "workflow skills (11)"; else err "missing skills:$missing"; fi
    n="$(ls "$root/.agents/templates/"*.md 2>/dev/null | wc -l | tr -d ' ')"
    if [ "$n" -ge 24 ]; then ok "templates ($n)"; else err "templates: $n of 24"; fi
    if [ -f "$root/aidlc-docs/brain/INDEX.md" ]; then
      if bash "$KIT_HOME/brain.sh" lint "$root" >/dev/null 2>&1; then ok "brain: $(grep -c '^- \[' "$root/aidlc-docs/brain/INDEX.md") project lessons, lint passed"
      else warn "brain lint found problems: run bash $KIT_HOME/brain.sh lint \"$root\""; fi
    else
      err "aidlc-docs/brain/ missing: re-run init-project.sh"
    fi
    [ -f "$root/.agents/brain/shared/INDEX.md" ] && ok "shared brain copy: $(grep -c '^- \[' "$root/.agents/brain/shared/INDEX.md") lessons" || warn "no shared brain copy in .agents/brain/shared (re-run init-project.sh)"
    for e in AGENTS.md CLAUDE.md GEMINI.md; do
      if grep -q "AIDLC:BEGIN" "$root/$e" 2>/dev/null; then ok "$e has the AI-DLC block"; else err "$e has no AI-DLC block"; fi
    done
    if [ -f "$root/.agents/.aidlc-version" ]; then
      pv="$(grep '^version=' "$root/.agents/.aidlc-version" | cut -d= -f2)"
      ps="$(grep '^standard=' "$root/.agents/.aidlc-version" | cut -d= -f2)"
      kv="$(cat "$KIT_HOME/VERSION" 2>/dev/null)"
      if [ -n "$kv" ] && version_lt "$pv" "$kv"; then warn "pack version $pv is older than the kit ($kv): update with bash $KIT_HOME/init-project.sh \"$root\" (add --dry-run to preview)"
      elif [ -n "$kv" ] && version_lt "$kv" "$pv"; then warn "pack version $pv is newer than the kit on this machine ($kv): update the kit (install.sh from the newer kit)"
      else ok "pack version $pv · standard $ps"; fi
    fi
    std="$(grep -o 'aidlc-kit:standard=[a-z]*' "$root/.agents/skills/project-architecture/SKILL.md" 2>/dev/null | head -n 1 | cut -d= -f2)"
    if grep -q "NOT GENERATED" "$root/.agents/skills/project-architecture/SKILL.md" 2>/dev/null; then
      warn "architecture standard not generated yet: run the project analysis"
    elif [ -n "$std" ]; then ok "architecture standard: $std"
    else ok "architecture standard: project-specific"; fi
    kind_of() {
      local m; m="$(grep -m 1 -o 'aidlc-kit:standard=[^>]*' "$1" 2>/dev/null)"
      case "$m" in "") echo custom ;; *"NOT GENERATED"*) echo placeholder ;; *) printf '%s\n' "$m" | sed -E 's/^aidlc-kit:standard=([a-z]+).*/\1/' ;; esac
    }
    label_of() { grep -m 1 -o 'house standard v[0-9][0-9.]*' "$1" 2>/dev/null; }
    sf="$root/.agents/skills/project-architecture/SKILL.md"; rf="$root/.agents/rules/20-architecture.md"
    if [ -f "$sf" ] && [ -f "$rf" ]; then
      sk="$(kind_of "$sf")"; rk="$(kind_of "$rf")"; sl="$(label_of "$sf")"; rl="$(label_of "$rf")"
      if [ "$sk" != "$rk" ] || [ "$sl" != "$rl" ]; then
        warn "the architecture skill ($sk${sl:+, $sl}) and 20-architecture.md ($rk${rl:+, $rl}) come from different versions: make them agree (init-project.sh --update-architecture switches both to the kit's standard)"
      fi
    fi
    always=0
    for f in "$root"/.agents/rules/*.md; do
      [ -f "$f" ] && head -n 6 "$f" | grep -q '^trigger: always_on' && always=$((always + $(wc -c < "$f")))
    done
    for f in AGENTS.md GEMINI.md; do [ -f "$root/$f" ] && always=$((always + $(wc -c < "$root/$f"))); done
    if [ "$always" -gt 60000 ]; then
      warn "always-on rules are $always bytes (about $((always / 4)) tokens). Antigravity gives always-on and global rules 20,000 tokens together and turns the largest files into short pointers above that: shorten 20-architecture.md"
    else
      ok "always-on rules: $always bytes (about $((always / 4)) of Antigravity's 20,000 tokens)"
    fi
    for f in "$root"/.agents/rules/*.md; do
      [ -f "$f" ] || continue
      head -n 6 "$f" | grep -q '^trigger:' || warn "${f#"$root"/} has no 'trigger:' frontmatter, so Antigravity ignores it"
      case "$(basename "$f")" in
        00-aidlc-core.md|10-quality-gates.md|20-architecture.md|30-learning.md|40-token-efficiency.md|50-anti-hallucination.md) ;;
        *) warn "extra rule file ${f#"$root"/}: check that it does not conflict with AI-DLC (init-project.sh --migrate archives old workflow rules)" ;;
      esac
    done
    state="$root/aidlc-docs/aidlc-state.md"
    if [ -f "$state" ]; then
      gate="$(state_get "$state" code_gate)"
      plan="$(state_get "$state" active_plan)"
      ok "state: work item=$(state_get "$state" work_item) · stage=$(state_get "$state" stage) · code gate=${gate:-?}"
      for k in mode work_item type stage code_gate active_plan updated; do
        [ -n "$(state_get "$state" "$k")" ] || err "state file is missing the key '$k'"
      done
      if [ "$gate" = "open" ]; then
        if [ -f "$root/$plan" ]; then
          c="$(plan_paths "$root/$plan" | wc -l | tr -d ' ')"
          ok "active plan $plan lists $c path(s)"
        else
          err "code gate is open but the active plan is missing: $plan"
        fi
      fi
    else
      err "aidlc-docs/aidlc-state.md missing: re-run init-project.sh"
    fi
    profile="$root/aidlc-docs/project-profile.md"
    if [ -f "$profile" ]; then
      d="$(grep -o 'analyzed: [0-9-]*' "$profile" | head -n 1 | cut -d' ' -f2)"
      age="$(days_since "$d")"
      if [ -n "$age" ] && [ "$age" -gt 30 ]; then warn "project profile is $age days old: re-run the project analysis"; else ok "project profile (analyzed ${d:-?})"; fi
    else
      warn "no project profile yet: ask the agent to analyze the project"
    fi
    # Process audit: every completed work item kept the record of its stages (test, review, reflection).
    n_done=0; missing=""
    for d in "$root"/aidlc-docs/work/*/; do
      pf=""
      for c in implementation_plan.md bugfix_plan.md; do [ -f "$d$c" ] && pf="$d$c"; done
      [ -n "$pf" ] && [ "$(plan_status "$pf")" = "COMPLETED" ] || continue
      n_done=$((n_done + 1))
      for r in test-report.md review-report.md reflection.md; do [ -f "$d$r" ] || missing="$missing $(basename "$d")/$r"; done
    done
    if [ -n "$missing" ]; then
      warn "completed work items without the record of a stage:$missing"
    elif [ "$n_done" -gt 0 ]; then
      ok "process audit: $n_done completed work item(s), each with its test, review and reflection reports"
    fi
    if [ -f "$root/pubspec.yaml" ]; then
      if [ -x "$root/.fvm/flutter_sdk/bin/flutter" ] || command -v flutter >/dev/null 2>&1; then ok "Flutter SDK available"; else warn "Flutter SDK not on PATH: verification commands cannot run"; fi
    fi
  fi
fi

echo
echo "Result: $errors error(s), $warnings warning(s)"
[ "$errors" -eq 0 ]
