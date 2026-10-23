#!/usr/bin/env bash
# AI-DLC kit: automated tests.  Usage: bash tests/run-tests.sh
# Uses temporary folders only. Never touches your real ~/.claude, ~/.gemini or ~/.aidlc-kit.

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="$(mktemp -d 2>/dev/null)" || BASE=""
case "$BASE" in
  ""|"/"|"$HOME") echo "could not create a temporary folder" >&2; exit 1 ;;
esac
[ -d "$BASE" ] || { echo "could not create a temporary folder" >&2; exit 1; }
TMP="$BASE/aidlc tests"   # a space in every path on purpose
mkdir -p "$TMP"
trap 'rm -rf "$BASE"' EXIT

PASS=0; FAIL=0; SKIP=0
ok()   { PASS=$((PASS + 1)); printf '  ✓ %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  ✗ %s\n' "$1"; }
skip() { SKIP=$((SKIP + 1)); printf '  - %s (skipped)\n' "$1"; }
section() { printf '\n%s\n' "$1"; }
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
expect_rc() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected exit $2, got $3)"; fi; }
contains() { grep -qF -- "$2" "$1" 2>/dev/null; }
count_in() { grep -cF -- "$2" "$1" 2>/dev/null || true; }

# Isolate from the user's environment.
unset AIDLC_ENFORCE AIDLC_GATE_SCOPE AIDLC_AUTOFORMAT AIDLC_JSON_TOOL CLAUDE_PROJECT_DIR CLAUDE_CONFIG_DIR AIDLC_GEMINI_DIR
export AIDLC_KIT_HOME="$TMP/kit-home-defaults"
mkdir -p "$AIDLC_KIT_HOME"
GIT="git -c user.name=test -c user.email=test@example.com -c init.defaultBranch=main"

new_flutter_project() { # new_flutter_project <dir>
  mkdir -p "$1/lib"
  printf 'name: demo\nenvironment:\n  sdk: ">=3.5.0 <4.0.0"\ndependencies:\n  flutter:\n    sdk: flutter\n' > "$1/pubspec.yaml"
  $GIT -C "$1" init -q
}

# =====================================================================================================
section "1. Static checks"
syntax_ok=1
while IFS= read -r f; do bash -n "$f" 2>/dev/null || { syntax_ok=0; bad "syntax error: ${f#"$KIT"/}"; }; done \
  < <(find "$KIT" -name '*.sh' -type f)
[ "$syntax_ok" = 1 ] && ok "all shell scripts parse"

for f in install.sh init-project.sh uninstall.sh claude/hooks/plan-gate.sh claude/hooks/session-start.sh \
         claude/hooks/auto-format.sh claude/bin/doctor.sh; do
  [ -x "$KIT/$f" ] || bad "not executable: $f"
done
ok "entry scripts are executable"

fm_ok=1
while IFS= read -r f; do
  rel="${f#"$KIT"/}"
  [ "$(head -n 1 "$f")" = "---" ] || { fm_ok=0; bad "no frontmatter: $rel"; continue; }
  fm="$(awk 'NR == 1 {next} /^---$/ {exit} {print}' "$f")"
  printf '%s\n' "$fm" | grep -q '^name:' || { fm_ok=0; bad "no name: $rel"; }
  printf '%s\n' "$fm" | grep -q '^description:' || { fm_ok=0; bad "no description: $rel"; }
  name="$(printf '%s\n' "$fm" | grep '^name:' | head -n 1 | sed 's/^name:[[:space:]]*//')"
  case "$rel" in
    standards/*) [ "$name" = "project-architecture" ] || { fm_ok=0; bad "standard skill must be named project-architecture: $rel"; } ;;
    *) [ "$name" = "$(basename "$(dirname "$f")")" ] || { fm_ok=0; bad "skill name '$name' does not match its folder: $rel"; } ;;
  esac
done < <(find "$KIT/pack" "$KIT/claude" "$KIT/standards" -name 'SKILL.md' -type f)
[ "$fm_ok" = 1 ] && ok "every SKILL.md has frontmatter with a matching name and a description"

rules_ok=1
for f in "$KIT"/pack/.agents/rules/*.md "$KIT"/standards/*/architecture-rules.md; do
  rel="${f#"$KIT"/}"
  [ "$(head -n 1 "$f")" = "---" ] && head -n 5 "$f" | grep -q '^trigger: always_on$' || { rules_ok=0; bad "rule without 'trigger: always_on' frontmatter: $rel"; }
  [ "$(wc -c < "$f")" -lt 24000 ] || { rules_ok=0; bad "rule over 24,000 bytes (Antigravity truncates): $rel"; }
done
[ "$rules_ok" = 1 ] && ok "rules have 'trigger: always_on' frontmatter and stay under 24,000 bytes"

for s in flutter android ios generic; do
  total=$(( $(wc -c < "$KIT/pack/AGENTS.md") + $(wc -c < "$KIT/pack/.agents/rules/00-aidlc-core.md") \
          + $(wc -c < "$KIT/pack/.agents/rules/10-quality-gates.md") + $(wc -c < "$KIT/pack/.agents/rules/30-learning.md") \
          + $(wc -c < "$KIT/pack/.agents/rules/40-token-efficiency.md") + $(wc -c < "$KIT/pack/.agents/rules/50-anti-hallucination.md") \
          + $(wc -c < "$KIT/standards/$s/architecture-rules.md") ))
  if [ "$total" -lt 30000 ]; then ok "always-on text for $s: $total bytes (< 30,000)"; else bad "always-on text for $s too big: $total bytes"; fi
done

n="$(ls "$KIT/pack/.agents/templates/"*.md | wc -l | tr -d ' ')"
expect_rc "24 templates" 24 "$n"
n="$(ls -d "$KIT"/pack/.agents/skills/*/ | wc -l | tr -d ' ')"
expect_rc "11 workflow skills in the pack" 11 "$n"
PA="$KIT/pack/.agents/skills/project-analysis/SKILL.md"; AS="$KIT/pack/.agents/templates/architecture-standard.md"
check "analysis ends with the architecture choice (A5: yours, AI-DLC, mix)" sh -c \
  "grep -q '^## A5. Architecture choice' '$PA' && grep -q 'A) Your architecture' '$PA' && grep -q 'B) The AI-DLC standard' '$PA' && grep -q 'C) Mix' '$PA'"
check "A5 writes the standard from the template, an ADR and profile section 15" sh -c \
  "grep -q 'architecture-standard.md' '$PA' && grep -q 'decision-record.md' '$PA' && grep -q 'profile section 15' '$PA'"
check "architecture-standard template: skill frontmatter, one-line description, 'generated' marker" sh -c \
  "sed -n '2p' '$AS' | grep -qx 'name: project-architecture' && sed -n '3p' '$AS' | grep -q '^description: [^>|]' && grep -q 'aidlc-kit:standard=generated' '$AS'"
check "... with the sections the workflow needs (checklist, placement, commands, testing)" sh -c \
  "grep -q '^## 18. New-feature checklist' '$AS' && grep -q '^## 19. Placement rules' '$AS' && grep -q '^## 20\\.' '$AS' && grep -q '^## 21. Testing standard' '$AS'"
check "profile template has section 15 Architecture choice" grep -q '^## 15. Architecture choice' "$KIT/pack/.agents/templates/project-profile.md"
check "routing table and /aidlc know the architecture choice" sh -c \
  "grep -q '^| Architecture choice |' '$KIT/pack/.agents/rules/00-aidlc-core.md' && grep -q '^| \\\`architecture\\\` |' '$KIT/claude/skills/aidlc/SKILL.md'"
size="$(wc -c < "$KIT/pack/.agents/rules/40-token-efficiency.md" | tr -d ' ')"
[ "$size" -lt 3000 ] && ok "the token rule itself stays lean ($size bytes < 3,000)" || bad "the token rule is too long: $size bytes"
QG="$KIT/pack/.agents/rules/10-quality-gates.md"; CON="$KIT/pack/.agents/skills/aidlc-construction/SKILL.md"
if ! grep -q '^## 6. Completion report\|^## 7. Error recovery\|^## 8. Knowledge retention' "$QG" \
   && grep -q '^## Error recovery' "$CON" && grep -q '✅ <work item> complete' "$CON" && grep -q 'tokens.sh' "$CON"; then
  ok "build-only parts moved from the always-on quality gates into the construction skill"
else
  bad "build-only parts moved from the always-on quality gates into the construction skill"
fi
check "the quality gates still forbid weakening tests" contains "$QG" "never \"fix\" a failure by"
lines="$(awk '/^🎯 Brief/ {on=1} on {n++} on && /^Unknowns:/ {print n; exit}' "$KIT/pack/.agents/skills/aidlc-prompt/SKILL.md")"
expect_rc "the task brief format is at most 7 lines" 7 "$lines"
IP="$KIT/pack/.agents/templates/implementation_plan.md"; BP="$KIT/pack/.agents/templates/bugfix_plan.md"
expect_rc "implementation plan template: 3 diagrams (plan flow, file map, runtime flow)" 3 "$(grep -c '^```mermaid' "$IP")"
check "... the runtime flow is a sequence diagram with an error path" sh -c "grep -q '^sequenceDiagram' '$IP' && grep -q 'else error' '$IP'"
tasks="$(sed -n '/^## 14\./,/^## 15\./p' "$IP" | grep -c '\*\*\[PENDING\]\*\* T[0-9]')"
hows="$(sed -n '/^## 14\./,/^## 15\./p' "$IP" | grep -c '^  - How:')"
[ "$tasks" -ge 9 ] && [ "$tasks" = "$hows" ] && ok "every task in the plan template has How / Why / Check ($tasks tasks)" \
  || bad "every task in the plan template has How / Why / Check ($tasks tasks, $hows How lines)"
check "plan templates have the Facts and assumptions table and the Verification line" sh -c \
  "grep -q '^## Facts and assumptions' '$IP' && grep -q '^## Facts and assumptions' '$BP' && grep -q '^- Verification:' '$IP' && grep -q '^- Verification:' '$BP'"
check "light plans: one document, one gate, one diagram (template note + feature skill)" sh -c "grep -q 'Light plan (light mode' '$IP' && grep -q 'skip F2 and F3' '$KIT/pack/.agents/skills/aidlc-feature/SKILL.md'"
TE="$KIT/pack/.agents/rules/40-token-efficiency.md"
check "token rule: parallel reads, topic files, templates filled without their instruction comments" sh -c "grep -q 'Batch independent reads' '$TE' && grep -q 'open a topic file' '$TE' && grep -q 'without their instruction comments' '$TE'"
check "size budgets: project profile about 10 KB, a project's own standard about 20 KB" sh -c "grep -q '10 KB' '$KIT/pack/.agents/templates/project-profile.md' && grep -q '20 KB' '$KIT/pack/.agents/templates/architecture-standard.md'"
check "construction records a git baseline at C1" contains "$KIT/pack/.agents/skills/aidlc-construction/SKILL.md" "verify-plan.sh <plan> --baseline"
check "bug-fix plan template: before/after diagram and How under its tasks" sh -c "grep -q '^\`\`\`mermaid' '$BP' && grep -q 'subgraph After' '$BP' && [ \$(grep -c '^  - How:' '$BP') -ge 2 ]"
n="$(ls "$KIT"/brain/lessons/*.md | wc -l | tr -d ' ')"
[ "$n" -ge 25 ] && ok "shared-brain starter has $n lessons" || bad "shared-brain starter has only $n lessons"
size="$(wc -c < "$KIT/brain/INDEX.md" | tr -d ' ')"
[ "$size" -le 8192 ] && ok "shared-brain index within budget ($size / 8192 bytes)" || bad "shared-brain index over budget ($size bytes)"
mkdir -p "$TMP/starter-home"; cp -R "$KIT/brain" "$TMP/starter-home/brain"; mkdir -p "$TMP/starter-project/aidlc-docs"
AIDLC_KIT_HOME="$TMP/starter-home" bash "$KIT/brain.sh" lint "$TMP/starter-project" >"$TMP/lint.out" 2>&1
expect_rc "shared-brain starter passes brain.sh lint" 0 "$?"
lsha() { ( . "$KIT/lib/kit.sh"; lesson_sha "$1" ); }
missing_sha=""
for f in "$KIT"/brain/lessons/*.md; do
  grep -qF "$(lsha "$f")  $(basename "$f")" "$KIT/lib/starter-lessons.sha256" || missing_sha="$missing_sha$(printf '\n      %s  %s  v%s' "$(lsha "$f")" "$(basename "$f")" "$(cat "$KIT/VERSION")")"
done
[ -z "$missing_sha" ] && ok "every starter lesson's current version is in lib/starter-lessons.sha256" \
  || bad "add these lines to lib/starter-lessons.sha256:$missing_sha"
n="$(cat "$KIT/standards/flutter/SKILL.md" "$KIT"/standards/flutter/reference/*.md | grep -c '^```dart')"
[ "$n" -ge 70 ] && ok "Flutter standard v3 contains $n Dart code blocks (compile-checked by tests/flutter-standard-check.sh)" || bad "Flutter standard has only $n Dart code blocks"
for r in core feature-items feature-sign-in tests patterns routing-api app-shell build-test-security adopting-v3; do
  [ -f "$KIT/standards/flutter/reference/$r.md" ] || bad "missing Flutter reference file: $r.md"
done
n="$(grep -c '^// lib/\|^// test/' "$KIT/standards/flutter/SKILL.md")"
expect_rc "Flutter SKILL.md has no whole-file code (it lives in reference/)" 0 "$n"
size="$(wc -c < "$KIT/standards/flutter/SKILL.md" | tr -d ' ')"
[ "$size" -lt 24000 ] && ok "Flutter SKILL.md core (read before every plan) is $size bytes (< 24,000; topic files on demand)" || bad "Flutter SKILL.md core is too big to read before every plan: $size bytes"
FS="$KIT/standards/flutter/SKILL.md"; heads_ok=1
for n in $(seq 1 24); do grep -q "^## $n\. " "$FS" || heads_ok=0; done
[ "$heads_ok" = 1 ] && ok "Flutter SKILL.md keeps every section heading 1–24 (references like §9 still resolve)" || bad "Flutter SKILL.md lost a section heading"
topic_ok=1
for t in patterns routing-api app-shell build-test-security adopting-v3; do
  tf="$KIT/standards/flutter/reference/$t.md"
  grep -q "^→ \`reference/$t.md\`" "$FS" || topic_ok=0
  while IFS= read -r h; do grep -qxF -- "$h" "$FS" || topic_ok=0; done <<EOF
$(grep '^## [0-9]' "$tf")
EOF
done
[ "$topic_ok" = 1 ] && ok "each Flutter topic file holds whole sections, and SKILL.md names it under the same headings" || bad "Flutter topic files and SKILL.md do not match"
check "the always-on Flutter rule no longer asks to read sections 1–24 before planning" sh -c "! grep -q '1–24' '$KIT/standards/flutter/architecture-rules.md'"
for s in flutter android ios generic; do
  sed -n '2,4p' "$KIT/standards/$s/SKILL.md" | grep -q '^description: [^>|]' || bad "standards/$s/SKILL.md: description must be one line"
done
ok "standard skills have one-line descriptions (safe for every skill parser)"
[ -z "$(find "$KIT" -name '*.dart' -print -quit)" ] && ok "no .dart files in the kit (code lives in SKILL.md)" || bad "the kit contains .dart files"
check "reviewer agent has name, description and tools" sh -c "head -n 5 '$KIT/claude/agents/aidlc-reviewer.md' | grep -q '^tools:'"
for e in AGENTS.md CLAUDE.md GEMINI.md; do
  check "pack/$e is a complete AI-DLC block" sh -c "head -n 1 '$KIT/pack/$e' | grep -q 'AIDLC:BEGIN' && tail -n 1 '$KIT/pack/$e' | grep -q 'AIDLC:END'"
done

# =====================================================================================================
section "2. init-project.sh"
P="$TMP/flutter app"
new_flutter_project "$P"
printf '# Team notes for agents\n' > "$P/AGENTS.md"
out="$(bash "$KIT/init-project.sh" "$P" 2>&1)"; rc=$?
expect_rc "init on a Flutter project succeeds" 0 "$rc"
printf '%s\n' "$out" | grep -q 'flutter (detected)' && ok "detects Flutter" || bad "detects Flutter"
missing=0
while IFS= read -r rel; do [ -f "$P/$rel" ] || { missing=1; bad "not installed: $rel"; }; done < <(cd "$KIT/pack" && find .agents -type f | sort)
[ "$missing" = 0 ] && ok "every kit file is installed"
check "Flutter architecture standard installed" contains "$P/.agents/skills/project-architecture/SKILL.md" "aidlc-kit:standard=flutter"
check "20-architecture.md installed" contains "$P/.agents/rules/20-architecture.md" "Flutter house standard"
for e in AGENTS.md CLAUDE.md GEMINI.md; do check "$e has the block" contains "$P/$e" "<!-- AIDLC:BEGIN"; done
check "existing AGENTS.md text is kept" contains "$P/AGENTS.md" "# Team notes for agents"
check "block is placed at the top of AGENTS.md" sh -c "head -n 1 '$P/AGENTS.md' | grep -q 'AIDLC:BEGIN'"
check "state file created" contains "$P/aidlc-docs/aidlc-state.md" "code_gate: closed"
check "audit log has an INIT line" contains "$P/aidlc-docs/audit-log.md" "| INIT |"
check ".gitignore ignores backups" contains "$P/.gitignore" ".agents/.backup/"
check "version file" contains "$P/.agents/.aidlc-version" "standard=flutter"
REFD=".agents/skills/project-architecture/reference"
ref_ok=1
for r in core feature-items feature-sign-in tests patterns routing-api app-shell build-test-security adopting-v3; do
  cmp -s "$KIT/standards/flutter/reference/$r.md" "$P/$REFD/$r.md" || ref_ok=0
done
[ "$ref_ok" = 1 ] && ok "the Flutter reference files are installed with the standard" || bad "the Flutter reference files are installed with the standard"
for f in AGENTS.md CLAUDE.md GEMINI.md .gitignore .agents/.aidlc-version; do
  [ "$(ls -ld "$P/$f" | cut -c1-10)" = "-rw-r--r--" ] || { bad "created with private permissions: $f"; continue; }
done
ok "files made by init are readable like the others (-rw-r--r--)"

lines_before="$(wc -l < "$P/aidlc-docs/audit-log.md")"
out="$(bash "$KIT/init-project.sh" "$P" 2>&1)"
printf '%s\n' "$out" | grep -q 'Everything is up to date' && ok "second run changes nothing" || bad "second run changes nothing"
printf '%s\n' "$out" | grep -q 'learning.md is kept\|token-efficiency.md is kept' \
  && bad "a re-run gives no false warning about the kit's own rules" || ok "a re-run gives no false warning about the kit's own rules"
expect_rc "second run adds no audit line" "$lines_before" "$(wc -l < "$P/aidlc-docs/audit-log.md")"
[ ! -d "$P/.agents/.backup" ] || [ "$(ls "$P/.agents/.backup" | wc -l | tr -d ' ')" = "1" ] && ok "second run makes no new backup" || bad "second run makes no new backup"

printf '\nlocal edit\n' >> "$P/.agents/rules/00-aidlc-core.md"
printf '\nproject rule\n' >> "$P/.agents/rules/20-architecture.md"
chmod 600 "$P/AGENTS.md"
out="$(bash "$KIT/init-project.sh" "$P" 2>&1)"
check "kit-owned file restored on update" cmp -s "$KIT/pack/.agents/rules/00-aidlc-core.md" "$P/.agents/rules/00-aidlc-core.md"
check "local edit of kit file is backed up" sh -c "grep -rl 'local edit' '$P/.agents/.backup' | grep -q 00-aidlc-core.md"
check "project-owned 20-architecture.md is kept" contains "$P/.agents/rules/20-architecture.md" "project rule"
printf '%s\n' "$out" | grep -q 'different version of the flutter standard' && ok "init notes that the kit's standard differs from the project's copy" \
  || bad "init notes that the kit's standard differs from the project's copy"
[ "$(ls -ld "$P/AGENTS.md" | cut -c1-10)" = "-rw-r--r--" ] && ok "a private AGENTS.md from an older kit is made readable again" \
  || bad "a private AGENTS.md from an older kit is made readable again"
rm "$P/$REFD/tests.md"
bash "$KIT/init-project.sh" "$P" >/dev/null 2>&1
check "a missing reference file is added back (the skill is the kit's)" test -f "$P/$REFD/tests.md"
printf '# old reference\n' > "$P/$REFD/old-example.md"
bash "$KIT/init-project.sh" "$P" --update-architecture >/dev/null 2>&1
check "--update-architecture replaces the rules" cmp -s "$KIT/standards/flutter/architecture-rules.md" "$P/.agents/rules/20-architecture.md"
check "--update-architecture backs up the edited rules" sh -c "grep -rl 'project rule' '$P/.agents/.backup' | grep -q 20-architecture.md"
check "--update-architecture removes reference files the standard no longer has" test ! -f "$P/$REFD/old-example.md"
check "... after backing them up" sh -c "find '$P/.agents/.backup' -name old-example.md | grep -q ."

M="$TMP/legacy app"
new_flutter_project "$M"
mkdir -p "$M/.agents/rules" "$M/.agents/skills/project-architecture"
printf '# Mandatory Agent Workflow Rules\n' > "$M/.agents/rules/agent-workflow.md"
printf '# Team style\n' > "$M/.agents/rules/style.md"
printf -- '---\nname: project-architecture\ndescription: old\n---\n# Old standard\n' > "$M/.agents/skills/project-architecture/SKILL.md"
out="$(bash "$KIT/init-project.sh" "$M" 2>&1)"
printf '%s\n' "$out" | grep -q 'agent-workflow.md looks like an old workflow rule' && ok "warns about the old workflow rule" || bad "warns about the old workflow rule"
check "without --migrate the old standard is kept" contains "$M/.agents/skills/project-architecture/SKILL.md" "# Old standard"
printf '%s\n' "$out" | grep -q 'own architecture standard (kept)' && ok "init says how to switch a project's own standard" || bad "init says how to switch a project's own standard"
check "the version file records the standard really installed (custom)" contains "$M/.agents/.aidlc-version" "standard=custom"
check "a project's own skill gets no kit reference files" test ! -d "$M/$REFD"
out="$(bash "$KIT/init-project.sh" "$M" --migrate 2>&1)"
check "--migrate archives agent-workflow.md" sh -c "[ ! -f '$M/.agents/rules/agent-workflow.md' ] && find '$M/.agents/archive' -name agent-workflow.md | grep -q ."
check "--migrate keeps unrelated rules" test -f "$M/.agents/rules/style.md"
check "--migrate keeps the project's own architecture skill" contains "$M/.agents/skills/project-architecture/SKILL.md" "# Old standard"
printf '%s\n' "$out" | grep -q 'come from different versions' && ok "init warns when the skill and 20-architecture.md do not match" \
  || bad "init warns when the skill and 20-architecture.md do not match"
bash "$KIT/init-project.sh" "$M" --update-architecture >/dev/null 2>&1
check "--update-architecture archives the project's own skill" sh -c "grep -rl 'Old standard' '$M/.agents/archive' | grep -q 'project-architecture/SKILL.md'"
check "--update-architecture installs the kit standard" contains "$M/.agents/skills/project-architecture/SKILL.md" "aidlc-kit:standard=flutter"
check "--update-architecture installs the matching rules" cmp -s "$KIT/standards/flutter/architecture-rules.md" "$M/.agents/rules/20-architecture.md"
check "--update-architecture installs the reference files" test -f "$M/$REFD/core.md"
check "the version file follows (flutter)" contains "$M/.agents/.aidlc-version" "standard=flutter"

G="$TMP/generic app"; mkdir -p "$G/.agents/skills/project-architecture"; printf 'module example.com/app\n' > "$G/go.mod"
printf -- '---\nname: project-architecture\ndescription: custom\n---\n# Custom Go standard\n' > "$G/.agents/skills/project-architecture/SKILL.md"
bash "$KIT/init-project.sh" "$G" --migrate >/dev/null 2>&1
check "--migrate never replaces a custom standard" contains "$G/.agents/skills/project-architecture/SKILL.md" "Custom Go standard"

A="$TMP/android app"; mkdir -p "$A/app"; printf 'rootProject.name = "demo"\n' > "$A/settings.gradle.kts"
bash "$KIT/init-project.sh" "$A" >/dev/null 2>&1
check "detects native Android" contains "$A/.agents/.aidlc-version" "standard=android"
I="$TMP/ios app"; mkdir -p "$I/Demo.xcodeproj"
bash "$KIT/init-project.sh" "$I" >/dev/null 2>&1
check "detects native iOS" contains "$I/.agents/.aidlc-version" "standard=ios"
E="$TMP/node app"; mkdir -p "$E"; printf '{ "name": "web" }\n' > "$E/package.json"
bash "$KIT/init-project.sh" "$E" >/dev/null 2>&1
check "falls back to the generic standard for other stacks" contains "$E/.agents/skills/project-architecture/SKILL.md" "NOT GENERATED"
out="$(bash "$KIT/init-project.sh" "$E" --standard flutter 2>&1)"
check "--standard flutter replaces the untouched generic placeholder" contains "$E/.agents/skills/project-architecture/SKILL.md" "aidlc-kit:standard=flutter"
check "... together with its rules" contains "$E/.agents/rules/20-architecture.md" "aidlc-kit:standard=flutter"
check "... and the version file says flutter" contains "$E/.agents/.aidlc-version" "standard=flutter"

N="$TMP/new app"; mkdir -p "$N"; $GIT -C "$N" init -q
out="$(bash "$KIT/init-project.sh" "$N" 2>&1)"; rc=$?
expect_rc "an empty folder without --standard is refused" 1 "$rc"
printf '%s\n' "$out" | grep -q -- '--standard flutter' && ok "the refusal shows the --standard command" || bad "the refusal shows the --standard command"
check "the refusal changes nothing" sh -c "[ \"\$(ls -A '$N')\" = '.git' ]"
bash "$KIT/init-project.sh" "$N" --standard flutter >/dev/null 2>&1
expect_rc "a new app in an empty folder with --standard flutter" 0 "$?"
check "the new app gets the Flutter house standard" contains "$N/.agents/skills/project-architecture/SKILL.md" "aidlc-kit:standard=flutter"
out="$(bash "$KIT/init-project.sh" "$N" 2>&1)"; rc=$?
expect_rc "a re-run in the still-empty folder keeps the installed standard" 0 "$rc"
printf '%s\n' "$out" | grep -q 'flutter (installed earlier)' && ok "the re-run says it kept the installed standard" || bad "the re-run says it kept the installed standard"

D="$TMP/dry app"; mkdir -p "$D"
out="$(bash "$KIT/init-project.sh" "$D" --standard flutter --dry-run 2>&1)"
check "--dry-run changes nothing" sh -c "[ -z \"\$(ls -A '$D')\" ]"
printf '%s\n' "$out" | grep -q 'DRY RUN' && ok "--dry-run says so" || bad "--dry-run says so"
F="$TMP/frontmatter app"; mkdir -p "$F"; printf -- '---\ntitle: x\n---\nbody\n' > "$F/AGENTS.md"
bash "$KIT/init-project.sh" "$F" --standard generic >/dev/null 2>&1
check "block goes after existing YAML frontmatter" sh -c "sed -n '1p;3p;4p' '$F/AGENTS.md' | tr '\n' '|' | grep -q '^---|---|<!-- AIDLC:BEGIN'"
mkdir -p "$TMP/fakehome"
HOME="$TMP/fakehome" bash "$KIT/init-project.sh" "$TMP/fakehome" >/dev/null 2>&1
expect_rc "refuses to run in the home folder" 1 "$?"
out="$(AIDLC_KIT_HOME="$KIT" bash "$KIT/claude/bin/doctor.sh" "$P" 2>&1)"; rc=$?
expect_rc "doctor passes on an initialized project" 0 "$rc"
printf '%s\n' "$out" | grep -q 'AIDLC_LEARN_HINTS=on' && ok "doctor shows every setting" || bad "doctor shows every setting"
printf '%s\n' "$out" | grep -q 'always-on rules: [0-9]* bytes' && ok "doctor reports the always-on size against Antigravity's budget" \
  || bad "doctor reports the always-on size against Antigravity's budget"
printf '%s\n' "$out" | grep -q 'different versions' && bad "doctor: matching skill and rules raise no warning" || ok "doctor: matching skill and rules raise no warning"
cp "$P/.agents/skills/project-architecture/SKILL.md" "$TMP/skill-save"
printf -- '---\nname: project-architecture\ndescription: own\n---\n# Own standard\n' > "$P/.agents/skills/project-architecture/SKILL.md"
out="$(AIDLC_KIT_HOME="$KIT" bash "$KIT/claude/bin/doctor.sh" "$P" 2>&1)"
printf '%s\n' "$out" | grep -q 'come from different versions' && ok "doctor warns when the skill and 20-architecture.md do not match" \
  || bad "doctor warns when the skill and 20-architecture.md do not match"
cat "$TMP/skill-save" > "$P/.agents/skills/project-architecture/SKILL.md"
for f in INDEX.md inbox.md metrics.md; do check "project brain created: aidlc-docs/brain/$f" test -f "$P/aidlc-docs/brain/$f"; done
GS="$TMP/own standard"; new_flutter_project "$GS"; bash "$KIT/init-project.sh" "$GS" >/dev/null 2>&1
mkdir -p "$GS/.agents/archive/20261023"; mv "$GS/.agents/skills/project-architecture/reference" "$GS/.agents/archive/20261023/"
sed 's/<Project>/Demo/g' "$KIT/pack/.agents/templates/architecture-standard.md" > "$GS/.agents/skills/project-architecture/SKILL.md"
printf -- '---\ntrigger: always_on\ndescription: Demo architecture hard rules.\n---\n<!-- aidlc-kit:standard=generated · project-owned -->\n# Architecture Rules: Demo\n1. Use GetX for state.\n' > "$GS/.agents/rules/20-architecture.md"
out="$(bash "$KIT/init-project.sh" "$GS" 2>&1)"
check "init keeps a project's own standard written by A5" contains "$GS/.agents/skills/project-architecture/SKILL.md" "# Demo Architecture Standard"
check "... and its rules" contains "$GS/.agents/rules/20-architecture.md" "Use GetX for state."
printf '%s\n' "$out" | grep -q 'different versions' && bad "... with no mismatch warning" || ok "... with no mismatch warning"
check "... records standard=generated" contains "$GS/.agents/.aidlc-version" "standard=generated"
check "... and adds no kit reference code next to it" test ! -d "$GS/.agents/skills/project-architecture/reference"
out="$(AIDLC_KIT_HOME="$KIT" bash "$KIT/claude/bin/doctor.sh" "$GS" 2>&1)"
printf '%s\n' "$out" | grep -q 'different versions' && bad "doctor: no mismatch warning for an A5 standard" || ok "doctor: no mismatch warning for an A5 standard"
check "shared brain copied into .agents/brain/shared/" test -f "$P/.agents/brain/shared/INDEX.md"
n="$(ls "$P"/.agents/brain/shared/lessons/*.md 2>/dev/null | wc -l | tr -d ' ')"
expect_rc "shared brain copy has every starter lesson" "$(ls "$KIT"/brain/lessons/*.md | wc -l | tr -d ' ')" "$n"
check "CLAUDE.md imports the brain indexes" contains "$P/CLAUDE.md" "@aidlc-docs/brain/INDEX.md"
check "AGENTS.md lists the learning rule" contains "$P/AGENTS.md" ".agents/rules/30-learning.md"
printf -- '- [L-001](lessons/L-001-x.md) · rule · flutter · t · my own lesson · ✓1 ✗0\n' >> "$P/aidlc-docs/brain/INDEX.md"
bash "$KIT/init-project.sh" "$P" >/dev/null 2>&1
check "re-running init keeps the project brain" contains "$P/aidlc-docs/brain/INDEX.md" "my own lesson"
MH="$TMP/mirror home"; mkdir -p "$MH"; cp -R "$KIT/brain" "$MH/brain"
rm "$MH/brain/lessons/S-007-guard-rm-rf.md"; grep -v 'S-007' "$MH/brain/INDEX.md" > "$TMP/idx" && cat "$TMP/idx" > "$MH/brain/INDEX.md"
out="$(AIDLC_KIT_HOME="$MH" bash "$KIT/init-project.sh" "$P" 2>&1)"
check "init mirrors the shared brain: a lesson it removed leaves the copy" test ! -f "$P/.agents/brain/shared/lessons/S-007-guard-rm-rf.md"
printf '%s\n' "$out" | grep -q 'no longer in the shared brain' && ok "... and init says so" || bad "... and init says so"

# =====================================================================================================
section "3. Plan gate (claude/hooks/plan-gate.sh)"
GATE="$KIT/claude/hooks/plan-gate.sh"
gate_rc() { # gate_rc <file> <tool> [VAR=value ...]
  local file="$1" tool="$2" key="file_path"
  shift 2
  [ "$tool" = "NotebookEdit" ] && key="notebook_path"
  printf '{"tool_name":"%s","cwd":"%s","tool_input":{"%s":"%s"}}' "$tool" "$P" "$key" "$file" \
    | env "$@" bash "$GATE" >/dev/null 2>"$TMP/gate.err"
  echo $?
}
expect_rc "closed gate blocks lib/main.dart" 2 "$(gate_rc "$P/lib/main.dart" Write)"
check "block message says 'plan first'" contains "$TMP/gate.err" "No approved plan is active"
expect_rc "planning file in aidlc-docs/ allowed" 0 "$(gate_rc "$P/aidlc-docs/work/001-feature-x/requirements.md" Write)"
expect_rc ".agents/ file allowed" 0 "$(gate_rc "$P/.agents/rules/20-architecture.md" Edit)"
expect_rc "closed gate: a kit-managed rule is blocked" 2 "$(gate_rc "$P/.agents/rules/00-aidlc-core.md" Edit)"
check "... and the message says it belongs to the kit" contains "$TMP/gate.err" "belongs to the AI-DLC kit"
expect_rc "closed gate: a kit-managed skill is blocked" 2 "$(gate_rc "$P/.agents/skills/aidlc-feature/SKILL.md" Edit)"
expect_rc "closed gate: the shared-brain copy is blocked" 2 "$(gate_rc "$P/.agents/brain/shared/INDEX.md" Edit)"
expect_rc "the project's architecture skill stays free" 0 "$(gate_rc "$P/.agents/skills/project-architecture/SKILL.md" Edit)"
expect_rc "a new project rule file stays free" 0 "$(gate_rc "$P/.agents/rules/60-project.md" Write)"
expect_rc "AGENTS.md allowed" 0 "$(gate_rc "$P/AGENTS.md" Edit)"
expect_rc "nested CLAUDE.md allowed" 0 "$(gate_rc "$P/lib/CLAUDE.md" Write)"
expect_rc "AIDLC_ENFORCE=off allows everything" 0 "$(gate_rc "$P/lib/main.dart" Write AIDLC_ENFORCE=off)"
printf 'AIDLC_ENFORCE = "off"  # from config\n' > "$TMP/kit-home-defaults/config"
expect_rc "config file setting is read" 0 "$(gate_rc "$P/lib/main.dart" Write)"
rm -f "$TMP/kit-home-defaults/config"

mkdir -p "$P/aidlc-docs/work/001-feature-a"
PLAN="$P/aidlc-docs/work/001-feature-a/implementation_plan.md"
cat > "$PLAN" <<'EOF'
# Implementation Plan
> **Status:** ✅ APPROVED 2026-10-22 10:00
## 1. Objective
Mentions `lib/outside.dart` outside the files markers (must not count).
<!-- aidlc:files:begin -->
## 3. Files to create
| # | Path | Purpose | Covers |
|---|---|---|---|
| C1 | `lib/features/a/a.dart` | feature | US-1 |
| C2 | `./lib/features/a/b c.dart` | file with a space | US-1 |
| C3 | `assets/images/` | folder entry | US-1 |
| C4 | `test/features/**` | glob entry | US-1 |
| C5 | `notebooks/x.ipynb` | notebook | US-1 |
| C6 | `lib/features/<feature>/example.dart` | template example row (ignored) | US-1 |
## 4. Files to modify
| M1 | `lib/core/config/router_config.dart` | add route `budget` | US-1 |
| M2 | `lib/main.dart` | move the setup into `lib/core/` and keep `*.dart` formatting | US-1 |
| M3 | `ios/Podfile`, `ios/Runner/Info.plist` | two paths in one cell | US-1 |
| M4 | `.agents/rules/10-quality-gates.md` | an approved change to a kit rule | US-1 |
- `lib/plan_change.dart`: added by PC-1 (it also mentions `lib/not_planned.dart`)
<!-- aidlc:files:end -->
EOF
sed -e 's/^code_gate: closed$/code_gate: open/' \
    -e 's#^active_plan: none$#active_plan: aidlc-docs/work/001-feature-a/implementation_plan.md#' \
    "$P/aidlc-docs/aidlc-state.md" > "$TMP/state" && cat "$TMP/state" > "$P/aidlc-docs/aidlc-state.md"
expect_rc "open gate: planned file allowed" 0 "$(gate_rc "$P/lib/features/a/a.dart" Write)"
expect_rc "open gate: planned file with a space allowed" 0 "$(gate_rc "$P/lib/features/a/b c.dart" Write)"
expect_rc "open gate: file to modify allowed" 0 "$(gate_rc "$P/lib/core/config/router_config.dart" Edit)"
expect_rc "open gate: folder entry allows files inside" 0 "$(gate_rc "$P/assets/images/logo.png" Write)"
expect_rc "open gate: glob entry allows deep files" 0 "$(gate_rc "$P/test/features/a/deep/a_test.dart" Write)"
expect_rc "open gate: notebook_path is checked" 0 "$(gate_rc "$P/notebooks/x.ipynb" NotebookEdit)"
expect_rc "open gate: unplanned file blocked" 2 "$(gate_rc "$P/lib/features/a/unplanned.dart" Write)"
check "block message explains the plan change procedure" contains "$TMP/gate.err" "Plan changes"
expect_rc "open gate: path outside the markers does not count" 2 "$(gate_rc "$P/lib/outside.dart" Write)"
expect_rc "a folder named in the description column does not count" 2 "$(gate_rc "$P/lib/core/secrets.dart" Write)"
expect_rc "a glob named in the description column does not count" 2 "$(gate_rc "$P/lib/features/pay/pay_screen.dart" Write)"
expect_rc "a word in backticks in the description column does not count" 2 "$(gate_rc "$P/budget" Write)"
expect_rc "several paths in one Path cell: first allowed" 0 "$(gate_rc "$P/ios/Podfile" Write)"
expect_rc "several paths in one Path cell: second allowed" 0 "$(gate_rc "$P/ios/Runner/Info.plist" Edit)"
expect_rc "bullet line: its first path is allowed" 0 "$(gate_rc "$P/lib/plan_change.dart" Write)"
expect_rc "bullet line: a path mentioned later does not count" 2 "$(gate_rc "$P/lib/not_planned.dart" Write)"
expect_rc "open gate: a kit-managed file listed in the approved plan is allowed" 0 "$(gate_rc "$P/.agents/rules/10-quality-gates.md" Edit)"
expect_rc "open gate: a kit-managed file the plan does not list is blocked" 2 "$(gate_rc "$P/.agents/rules/30-learning.md" Edit)"
( . "$KIT/claude/hooks/lib.sh"; plan_paths "$PLAN" ) > "$TMP/paths.out"
check "template example rows with <placeholders> are ignored" sh -c "! grep -q '<feature>' '$TMP/paths.out'"
cp "$PLAN" "$TMP/plan-approved"
sed 's/^> \*\*Status:\*\* ✅ APPROVED.*$/> Status: DRAFT | APPROVED <date-time> | COMPLETED <date-time>/' "$TMP/plan-approved" > "$PLAN"
expect_rc "open gate but the plan still says DRAFT: blocked" 2 "$(gate_rc "$P/lib/features/a/a.dart" Write)"
check "the DRAFT block message asks for the approval" contains "$TMP/gate.err" "not approved"
grep -v 'Status:' "$TMP/plan-approved" > "$PLAN"
expect_rc "open gate but the plan has no status line: blocked" 2 "$(gate_rc "$P/lib/features/a/a.dart" Write)"
sed 's/^> \*\*Status:\*\* ✅ APPROVED.*$/> Status: APPROVED 2026-10-22 11:30/' "$TMP/plan-approved" > "$PLAN"
expect_rc "plain '> Status: APPROVED <time>' line is accepted" 0 "$(gate_rc "$P/lib/features/a/a.dart" Write)"
cat "$TMP/plan-approved" > "$PLAN"
expect_rc "'..' in the path is normalized" 0 "$(gate_rc "$P/lib/features/x/../a/a.dart" Write)"
expect_rc "relative path is resolved against cwd" 0 "$(gate_rc "lib/features/a/a.dart" Write)"
expect_rc "AIDLC_GATE_SCOPE=any allows unplanned files" 0 "$(gate_rc "$P/lib/other.dart" Write AIDLC_GATE_SCOPE=any)"
expect_rc "python3 fallback: planned file allowed" 0 "$(gate_rc "$P/lib/features/a/a.dart" Write AIDLC_JSON_TOOL=python3)"
expect_rc "python3 fallback: unplanned file blocked" 2 "$(gate_rc "$P/lib/other.dart" Write AIDLC_JSON_TOOL=python3)"
printf 'not json' | bash "$GATE" >/dev/null 2>&1
expect_rc "malformed input never blocks" 0 "$?"
sed 's#^active_plan: .*#active_plan: aidlc-docs/work/missing.md#' "$P/aidlc-docs/aidlc-state.md" > "$TMP/state2"
cp "$P/aidlc-docs/aidlc-state.md" "$TMP/state-open"; cat "$TMP/state2" > "$P/aidlc-docs/aidlc-state.md"
expect_rc "missing active plan file blocks" 2 "$(gate_rc "$P/lib/features/a/a.dart" Write)"
cat "$TMP/state-open" > "$P/aidlc-docs/aidlc-state.md"

O="$TMP/no pack repo"; mkdir -p "$O/src"; $GIT -C "$O" init -q
P_SAVE="$P"; P="$O"
expect_rc "project without the pack: allowed (default mode)" 0 "$(gate_rc "$O/src/a.js" Write)"
expect_rc "all-repos mode: repository without the pack blocked" 2 "$(gate_rc "$O/src/a.js" Write AIDLC_ENFORCE=all-repos)"
expect_rc "all-repos mode: AGENTS.md still allowed" 0 "$(gate_rc "$O/AGENTS.md" Write AIDLC_ENFORCE=all-repos)"
mkdir -p "$TMP/loose"; P="$TMP/loose"
expect_rc "all-repos mode: files outside git repositories allowed" 0 "$(gate_rc "$TMP/loose/a.txt" Write AIDLC_ENFORCE=all-repos)"
P="$P_SAVE"

# =====================================================================================================
section "4. Session start (claude/hooks/session-start.sh)"
SES="$KIT/claude/hooks/session-start.sh"
out="$(printf '{"cwd":"%s"}' "$P/lib" | bash "$SES")"
printf '%s\n' "$out" | grep -q '\[AI-DLC\] Project:' && ok "AI-DLC project: context printed" || bad "AI-DLC project: context printed"
printf '%s\n' "$out" | grep -q 'code gate=open' && ok "shows the code gate" || bad "shows the code gate"
out="$(printf '{"cwd":"/nowhere"}' | CLAUDE_PROJECT_DIR="$P" bash "$SES")"
printf '%s\n' "$out" | grep -q "$P" && ok "uses CLAUDE_PROJECT_DIR" || bad "uses CLAUDE_PROJECT_DIR"
L="$TMP/legacy only"; mkdir -p "$L/.agents/rules" "$L/.agents/skills/project-architecture"
printf 'x\n' > "$L/.agents/rules/agent-workflow.md"; printf 'x\n' > "$L/.agents/skills/project-architecture/SKILL.md"
out="$(printf '{"cwd":"%s"}' "$L" | bash "$SES")"
printf '%s\n' "$out" | grep -q '.agents/rules/agent-workflow.md' && ok "lists other agents' rules so Claude follows them" || bad "lists other agents' rules"
out="$(printf '{"cwd":"%s"}' "$TMP/loose" | bash "$SES")"
[ -z "$out" ] && ok "plain folder: prints nothing" || bad "plain folder: prints nothing"
out="$(printf '{"cwd":"%s"}' "$O" | AIDLC_ENFORCE=all-repos bash "$SES")"
printf '%s\n' "$out" | grep -q 'all-repos' && ok "all-repos mode: reminds to set up the pack" || bad "all-repos reminder"
out="$(printf '{"cwd":"%s"}' "$P" | AIDLC_KIT_HOME="$KIT" bash "$SES")"
printf '%s\n' "$out" | grep -q '00-aidlc-core, 10-quality-gates, 20-architecture, 30-learning' && ok "lists the rule files that really exist" \
  || bad "lists the rule files that really exist"
printf '%s\n' "$out" | grep -q 'Update available' && bad "an up-to-date pack shows no update hint" || ok "an up-to-date pack shows no update hint"
cp "$P/.agents/.aidlc-version" "$TMP/version-save"; printf 'version=2.0.0\nstandard=flutter\n' > "$P/.agents/.aidlc-version"
out="$(printf '{"cwd":"%s"}' "$P" | AIDLC_KIT_HOME="$KIT" bash "$SES")"
printf '%s\n' "$out" | grep -q 'Update available: .*pack is 2.0.0' && ok "an older pack: the agent is told to offer the update" \
  || bad "an older pack: the agent is told to offer the update"
cat "$TMP/version-save" > "$P/.agents/.aidlc-version"

# =====================================================================================================
section "5. Auto-format (claude/hooks/auto-format.sh)"
FMT="$KIT/claude/hooks/auto-format.sh"
if command -v dart >/dev/null 2>&1; then
  printf 'void   main( ){ }\n' > "$P/lib/tracked.dart"
  $GIT -C "$P" add lib/tracked.dart && $GIT -C "$P" commit -qm tracked
  printf 'void   main( ){ }\n' > "$P/lib/new_file.dart"
  fmt() { printf '{"tool_input":{"file_path":"%s"}}' "$1" | env "${@:2}" bash "$FMT"; }
  fmt "$P/lib/new_file.dart"
  check "new (untracked) Dart file is formatted" contains "$P/lib/new_file.dart" "void main() {}"
  fmt "$P/lib/tracked.dart"
  check "tracked Dart file is left as it is" contains "$P/lib/tracked.dart" "void   main( ){ }"
  printf 'void   main( ){ }\n' > "$P/lib/new_off.dart"
  fmt "$P/lib/new_off.dart" AIDLC_AUTOFORMAT=off
  check "AIDLC_AUTOFORMAT=off formats nothing" contains "$P/lib/new_off.dart" "void   main( ){ }"
  fmt "$P/lib/tracked.dart" AIDLC_AUTOFORMAT=all
  check "AIDLC_AUTOFORMAT=all formats tracked files" contains "$P/lib/tracked.dart" "void main() {}"
  printf 'void   main( ){ }\n' > "$O/src/plain.dart"
  fmt "$O/src/plain.dart"
  check "a repository without the pack: nothing is formatted" contains "$O/src/plain.dart" "void   main( ){ }"
  fmt "$O/src/plain.dart" AIDLC_ENFORCE=all-repos
  check "... unless AIDLC_ENFORCE=all-repos" contains "$O/src/plain.dart" "void main() {}"
else
  skip "auto-format tests need dart"
fi
printf '{"tool_input":{"file_path":"%s"}}' "$TMP/loose/a.txt" | bash "$FMT"
expect_rc "unknown file type: exits 0" 0 "$?"

# =====================================================================================================
section "6. install.sh / uninstall.sh (in a fake home)"
H="$TMP/home dir"
mkdir -p "$H/.claude/agents" "$H/.gemini"
cat > "$H/.claude/settings.json" <<'EOF'
{
  "model": "opus",
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [ { "type": "command", "command": "echo user-hook" } ] }
    ]
  }
}
EOF
printf '# My global rules\n' > "$H/.claude/CLAUDE.md"
printf 'Old AI-DLC v1 Flutter reviewer\n' > "$H/.claude/agents/flutter-reviewer.md"
printf '# My Gemini rules\n' > "$H/.gemini/GEMINI.md"

run_install() { env -u AIDLC_KIT_HOME HOME="$H" "$@" bash "$KIT/install.sh" >"$TMP/install.out" 2>&1; }

env HOME="$H" AIDLC_KIT_HOME="$H" bash "$KIT/install.sh" >/dev/null 2>&1
expect_rc "install refuses the home folder as kit folder" 1 "$?"
check "the refused install changed nothing" sh -c "[ ! -e '$H/VERSION' ] && [ ! -e '$H/.claude/skills/aidlc' ]"
hooks_count() { grep -c "claude/hooks/$1.sh" "$H/.claude/settings.json" 2>/dev/null || true; }

run_install; rc=$?
expect_rc "install succeeds (jq)" 0 "$rc"
check "kit copied to ~/.aidlc-kit" test -f "$H/.aidlc-kit/VERSION"
check "config created" contains "$H/.aidlc-kit/config" "AIDLC_ENFORCE=project"
check "config has every setting, including AIDLC_LEARN_HINTS" contains "$H/.aidlc-kit/config" "AIDLC_LEARN_HINTS=on"
check "/aidlc skill installed" test -f "$H/.claude/skills/aidlc/SKILL.md"
check "reviewer agent installed" test -f "$H/.claude/agents/aidlc-reviewer.md"
check "v1 flutter-reviewer removed" test ! -f "$H/.claude/agents/flutter-reviewer.md"
check "v1 flutter-reviewer backed up" sh -c "find '$H/.aidlc-kit/backups' -name flutter-reviewer.md | grep -q ."
check "settings.json is valid JSON" jq empty "$H/.claude/settings.json"
check "other settings kept" sh -c "jq -e '.model == \"opus\"' '$H/.claude/settings.json'"
check "user's own hook kept" contains "$H/.claude/settings.json" "echo user-hook"
for h in plan-gate auto-format session-start learn-hint plan-check; do expect_rc "hook $h registered once" 1 "$(hooks_count $h)"; done
check "shared brain installed in ~/.aidlc-kit/brain" test -f "$H/.aidlc-kit/brain/INDEX.md"
check "brain.sh installed" test -f "$H/.aidlc-kit/brain.sh"
check "tokens.sh installed and executable" test -x "$H/.aidlc-kit/tokens.sh"
check "remove-project.sh installed and executable" test -x "$H/.aidlc-kit/remove-project.sh"
expect_rc "CLAUDE.md block added once" 1 "$(count_in "$H/.claude/CLAUDE.md" "AIDLC:BEGIN")"
check "CLAUDE.md user text kept" contains "$H/.claude/CLAUDE.md" "# My global rules"
expect_rc "GEMINI.md block added once" 1 "$(count_in "$H/.gemini/GEMINI.md" "AIDLC:BEGIN")"
check "GEMINI.md user text kept" contains "$H/.gemini/GEMINI.md" "# My Gemini rules"

printf -- '---\nid: S-900\ntitle: my own shared lesson\n---\n' > "$H/.aidlc-kit/brain/lessons/S-900-mine.md"
printf -- '- [S-900](lessons/S-900-mine.md) · rule · any · t · my own shared lesson · ✓0 ✗0\n' >> "$H/.aidlc-kit/brain/INDEX.md"
rm -f "$H/.aidlc-kit/brain/lessons/S-025-statenotifier-state-in-tests.md"
grep -v 'S-025' "$H/.aidlc-kit/brain/INDEX.md" > "$TMP/idx" && cat "$TMP/idx" > "$H/.aidlc-kit/brain/INDEX.md"
printf '# my old config\nAIDLC_AUTOFORMAT=off\n' > "$H/.aidlc-kit/config"
sed 's/Keep under 8 KB\./Keep under 6 KB./' "$H/.aidlc-kit/brain/INDEX.md" > "$TMP/idx" && cat "$TMP/idx" > "$H/.aidlc-kit/brain/INDEX.md"
run_install AIDLC_JSON_TOOL=python3; rc=$?
expect_rc "second install succeeds (python3 path)" 0 "$rc"
check "re-install keeps your config values" contains "$H/.aidlc-kit/config" "AIDLC_AUTOFORMAT=off"
check "re-install adds settings that are new in the kit" contains "$H/.aidlc-kit/config" "AIDLC_LEARN_HINTS=on"
expect_rc "re-install does not add a setting you already have" 1 "$(count_in "$H/.aidlc-kit/config" "AIDLC_AUTOFORMAT=")"
check "re-install keeps your own shared lessons" contains "$H/.aidlc-kit/brain/INDEX.md" "my own shared lesson"
check "re-install adds missing starter lessons" test -f "$H/.aidlc-kit/brain/lessons/S-025-statenotifier-state-in-tests.md"
check "re-install changes the kit's old 6 KB index header line to 8 KB" contains "$H/.aidlc-kit/brain/INDEX.md" "Keep under 8 KB."
check "... after backing up the old index" sh -c "find '$H/.aidlc-kit/backups' -path '*brain/INDEX.md' | grep -q ."
# A newer kit (a copy with one more released version of S-003) meets a brain with an untouched old S-003,
# an edited S-004 and a lesson of yours that took the ID S-005.
KC="$TMP/kit copy"; cp -R "$KIT" "$KC"; HB="$H/.aidlc-kit/brain"
L3="$(basename "$KIT"/brain/lessons/S-003-*.md)"; L4="$(basename "$KIT"/brain/lessons/S-004-*.md)"; L5="$(basename "$KIT"/brain/lessons/S-005-*.md)"
{ cat "$KIT/brain/lessons/$L3"; printf 'Older wording.\n'; } > "$TMP/old-S-003.md"
printf '%s  %s  test-old\n' "$(lsha "$TMP/old-S-003.md")" "$L3" >> "$KC/lib/starter-lessons.sha256"
sed 's/^helpful: .*/helpful: 4/' "$TMP/old-S-003.md" > "$HB/lessons/$L3"
sed "/(lessons\/$L3)/s/✓[0-9]* ✗[0-9]*\$/✓4 ✗0/" "$HB/INDEX.md" > "$TMP/idx" && cat "$TMP/idx" > "$HB/INDEX.md"
printf 'My own note.\n' >> "$HB/lessons/$L4"
mv "$HB/lessons/$L5" "$HB/lessons/S-005-my-own-lesson.md"
sed 's/Keep under 8 KB\./Keep under 6 KB (my own words)./' "$HB/INDEX.md" > "$TMP/idx" && cat "$TMP/idx" > "$HB/INDEX.md"
env -u AIDLC_KIT_HOME HOME="$H" bash "$KC/install.sh" > "$TMP/install3.out" 2>&1
expect_rc "re-install with a newer kit succeeds" 0 "$?"
if [ "$(grep -v '^helpful:' "$HB/lessons/$L3")" = "$(grep -v '^helpful:' "$KIT/brain/lessons/$L3")" ]; then
  ok "a starter lesson you never edited is updated to the kit's version"
else
  bad "a starter lesson you never edited is updated to the kit's version"
fi
check "... keeping your helpful count" contains "$HB/lessons/$L3" "helpful: 4"
check "... and your counts in the index" sh -c "grep -F '(lessons/$L3)' '$HB/INDEX.md' | grep -q '✓4 ✗0'"
check "... after backing up your old copy" sh -c "find '$H/.aidlc-kit/backups' -path '*brain/lessons/$L3' | grep -q ."
check "the installer says what it updated" contains "$TMP/install3.out" "updated: S-003"
check "a starter lesson you edited is kept" contains "$HB/lessons/$L4" "My own note."
check "the installer says it kept your edit" contains "$TMP/install3.out" "kept your edited starter lessons: S-004"
check "a kit lesson is not added when one of yours has its ID" test ! -f "$HB/lessons/$L5"
check "the installer says why" contains "$TMP/install3.out" "uses the same ID: S-005"
check "an index header line you edited is kept" contains "$HB/INDEX.md" "Keep under 6 KB (my own words)."
env -u AIDLC_KIT_HOME HOME="$H" bash "$KC/install.sh" > "$TMP/install4.out" 2>&1
check "a second run changes no lesson" contains "$TMP/install4.out" "updated: none"
expect_rc "re-install does not duplicate starter index lines" 1 "$(grep -c 'S-001-riverpod3-legacy-import' "$H/.aidlc-kit/brain/INDEX.md")"
for h in plan-gate auto-format session-start learn-hint plan-check; do expect_rc "after re-install, hook $h still registered once" 1 "$(hooks_count $h)"; done
expect_rc "after re-install, CLAUDE.md block still once" 1 "$(count_in "$H/.claude/CLAUDE.md" "AIDLC:BEGIN")"
check "settings.json still valid" jq empty "$H/.claude/settings.json"

cmd="$(jq -r '.hooks.PreToolUse[] | .hooks[] | select(.command | contains("plan-gate.sh")) | .command' "$H/.claude/settings.json")"
printf '{"tool_input":{"file_path":"%s/x.txt"}}' "$TMP/loose" | env -u AIDLC_KIT_HOME HOME="$H" sh -c "$cmd" >/dev/null 2>&1
expect_rc "registered hook command runs (path with a space)" 0 "$?"
printf '{"tool_input":{"file_path":"%s/lib/zzz.dart"}}' "$P" | env -u AIDLC_KIT_HOME HOME="$H" sh -c "$cmd" >/dev/null 2>&1
expect_rc "registered hook command blocks an unplanned file" 2 "$?"
env -u AIDLC_KIT_HOME HOME="$H" bash "$H/.aidlc-kit/claude/bin/doctor.sh" --machine >/dev/null 2>&1
expect_rc "doctor --machine passes after install" 0 "$?"

env -u AIDLC_KIT_HOME HOME="$H" bash "$H/.aidlc-kit/uninstall.sh" >"$TMP/uninstall.out" 2>&1
expect_rc "uninstall succeeds" 0 "$?"
check "settings.json valid after uninstall" jq empty "$H/.claude/settings.json"
expect_rc "AI-DLC hooks removed" 0 "$(grep -c 'claude/hooks/' "$H/.claude/settings.json" || true)"
check "user's hook still there" contains "$H/.claude/settings.json" "echo user-hook"
check "other settings still there" sh -c "jq -e '.model == \"opus\"' '$H/.claude/settings.json'"
expect_rc "CLAUDE.md block removed" 0 "$(count_in "$H/.claude/CLAUDE.md" "AIDLC:BEGIN")"
check "CLAUDE.md user text kept" contains "$H/.claude/CLAUDE.md" "# My global rules"
expect_rc "GEMINI.md block removed" 0 "$(count_in "$H/.gemini/GEMINI.md" "AIDLC:BEGIN")"
check "/aidlc skill removed" test ! -e "$H/.claude/skills/aidlc"
check "reviewer agent removed" test ! -e "$H/.claude/agents/aidlc-reviewer.md"
check "~/.aidlc-kit removed" test ! -e "$H/.aidlc-kit"
check "uninstall kept copies" sh -c "ls -d '$H'/.aidlc-kit-uninstall-* >/dev/null 2>&1"
check "uninstall saved your shared brain" sh -c "grep -rq 'my own shared lesson' '$H'/.aidlc-kit-uninstall-*/kit/brain/INDEX.md"

# =====================================================================================================
section "7. Broken references"
broken=0
while IFS= read -r ref; do
  case "$ref" in *'<'*|*'*'*|*'.backup'*|*'archive'*|*agent-workflow.md|*style.md) continue ;; esac
  [ -e "$P/$ref" ] || { broken=1; bad "referenced but not installed: $ref"; }
done < <(grep -rhoE '\.agents/[A-Za-z0-9_./*<>-]+' "$KIT/pack" "$KIT/standards" "$KIT/claude" "$KIT/global" \
           "$KIT/README.md" "$KIT/GUIDE.md" | sed -E 's/[.,:;)]+$//' | sort -u)
[ "$broken" = 0 ] && ok "every .agents/ path mentioned in the kit exists in an installed project"
missing_tpl=0
while IFS= read -r t; do
  [ -f "$KIT/pack/.agents/templates/$t" ] || { missing_tpl=1; bad "template referenced but missing: $t"; }
done < <(grep -rhoE 'template[s]? `[a-z_-]+\.md`' "$KIT/pack" | sed -E 's/.*`([a-z_-]+\.md)`/\1/' | sort -u)
[ "$missing_tpl" = 0 ] && ok "every template named in the skills exists"
stale="$(python3 - "$KIT" <<'PYEOF'
import os, re, sys
kit = sys.argv[1]
rdir = os.path.join(kit, "pack/.agents/rules")
secs = {f[:2]: set(re.findall(r"^##\s+(\d+)\.", open(os.path.join(rdir, f), encoding="utf-8").read(), re.M)) for f in os.listdir(rdir)}
steps = {}
sdir = os.path.join(kit, "pack/.agents/skills")
for name in os.listdir(sdir):
    t = open(os.path.join(sdir, name, "SKILL.md"), encoding="utf-8").read()
    steps[name] = set(re.findall(r"^#+\s+([A-Z]\d+)\b", t, re.M)) | set(re.findall(r"^\|\s*([A-Z]\d+)\b", t, re.M))
out = []
for d, _, fs in os.walk(kit):
    if os.path.relpath(d, kit).split(os.sep)[0] == "tests":
        continue
    for f in fs:
        if not f.endswith((".md", ".sh")) or f == "CHANGELOG.md":
            continue
        p = os.path.join(d, f)
        for i, line in enumerate(open(p, encoding="utf-8", errors="ignore"), 1):
            for m in re.finditer(r"\b(00|10|30|40|50)-[a-z-]+(?:\.md)?`?\s*§\s*(\d+)", line):
                if m.group(2) not in secs.get(m.group(1), set()):
                    out.append(f"{os.path.relpath(p, kit)}:{i}: {m.group(0)}")
            for m in re.finditer(r"\b(aidlc-[a-z-]+|project-analysis)`?\s*\(?\b([A-Z])(\d+)(?:\s*[–-]\s*([A-Z]?)(\d+))?", line):
                s, L, a, _, b = m.groups()
                if s in steps and any(f"{L}{n}" not in steps[s] for n in ([a] if not b else [a, b])):
                    out.append(f"{os.path.relpath(p, kit)}:{i}: {m.group(0)}")
print("\n".join(out))
PYEOF
)"
[ -z "$stale" ] && ok "every \"rule §N\" and skill-step reference points to something that exists" || bad "stale references:
$stale"

# =====================================================================================================
section "8. Brain (brain.sh, learning hint, session context)"
B="$TMP/brain project"
new_flutter_project "$B"
bash "$KIT/init-project.sh" "$B" >/dev/null 2>&1
SH="$TMP/shared home"; mkdir -p "$SH"; cp -R "$KIT/brain" "$SH/brain"
brain() { AIDLC_KIT_HOME="$SH" bash "$KIT/brain.sh" "$@"; }
brain lint "$B" >"$TMP/lint.out" 2>&1
expect_rc "lint passes on a fresh project" 0 "$?"
brain stats "$B" >"$TMP/stats.out" 2>&1
check "stats shows the shared lessons" contains "$TMP/stats.out" "shared lessons (copy): $(grep -c '^- \[' "$KIT/brain/INDEX.md")"
lesson="$B/aidlc-docs/brain/lessons/L-001-check-mounted.md"
mkdir -p "$(dirname "$lesson")"
cat > "$lesson" <<'EOF'
---
id: L-001
title: Check context.mounted after await before showing dialogs
type: pitfall
scope: shared
stack: flutter
tags: [async, context]
status: active
confidence: high
source: failed-check
evidence: work item 004: crash in item_form_screen.dart:58 after leaving the screen
created: 2026-10-22
last_verified: 2026-10-22
recheck: never
helpful: 1
harmful: 0
shared_as: none
---
# Check context.mounted after await before showing dialogs
EOF
printf -- '- [L-001](lessons/L-001-check-mounted.md) · pitfall · flutter · async · Check context.mounted after await · ✓1 ✗0\n' >> "$B/aidlc-docs/brain/INDEX.md"
brain lint "$B" >"$TMP/lint.out" 2>&1
expect_rc "lint passes with a complete lesson" 0 "$?"
sed -e 's/^evidence: .*/evidence: <work item + path:line>/' "$lesson" > "$TMP/l2" && cp "$TMP/l2" "$B/aidlc-docs/brain/lessons/L-002-no-evidence.md"
brain lint "$B" >"$TMP/lint.out" 2>&1
expect_rc "lint fails for a lesson without real evidence" 1 "$?"
check "lint reports the duplicate title" contains "$TMP/lint.out" "duplicate lesson titles"
rm -f "$B/aidlc-docs/brain/lessons/L-002-no-evidence.md"
secret_value="$(printf 'AI%s' 'zaSyB0123456789abcdefghijklmnopqrstuv')"
printf 'api_key = %s\n' "$secret_value" >> "$lesson"
brain lint "$B" >"$TMP/lint.out" 2>&1
expect_rc "lint fails when a secret is stored in the brain" 1 "$?"
grep -v '^api_key' "$lesson" > "$TMP/l3" && cat "$TMP/l3" > "$lesson"
cp "$B/aidlc-docs/brain/INDEX.md" "$TMP/index-backup"
head -c 9000 /dev/zero | tr '\0' 'x' >> "$B/aidlc-docs/brain/INDEX.md"
brain lint "$B" >"$TMP/lint.out" 2>&1
expect_rc "lint fails when the index is over budget" 1 "$?"
cp "$TMP/index-backup" "$B/aidlc-docs/brain/INDEX.md"
brain lint "$B" >"$TMP/lint.out" 2>&1
expect_rc "lint passes again after the fixes" 0 "$?"
brain push "$B" >"$TMP/push.out" 2>&1
new_id="S-101"   # your shared lessons start at S-101; S-001 to S-099 are the kit's
check "push copies the approved shared lesson into the shared brain" sh -c "ls '$SH/brain/lessons/' | grep -q '^$new_id-check-mounted.md$'"
check "push adds the lesson to the shared index" contains "$SH/brain/INDEX.md" "[$new_id](lessons/$new_id-check-mounted.md)"
check "push records shared_as in the project lesson" contains "$lesson" "shared_as: $new_id"
brain push "$B" >"$TMP/push2.out" 2>&1
check "a second push shares nothing again" contains "$TMP/push2.out" "push: 0 lesson(s)"
brain pull "$B" >/dev/null 2>&1
check "pull brings the new shared lesson into the project copy" test -f "$B/.agents/brain/shared/lessons/$new_id-check-mounted.md"
brain lint "$B" >"$TMP/lint.out" 2>&1
expect_rc "lint passes on project and shared brain after sync" 0 "$?"
lesson2="$B/aidlc-docs/brain/lessons/L-002-staging-login.md"
sed -e 's/^id: L-001/id: L-002/' -e 's/^title: .*/title: Log in to staging before the smoke test/' \
    -e 's/^shared_as: .*/shared_as: none/' "$lesson" > "$lesson2"
printf 'Ask %s for the staging account.\n' "$(printf 'qa%sexample.com' '@')" >> "$lesson2"
printf -- '- [L-002](lessons/L-002-staging-login.md) · rule · flutter · qa · Log in to staging · ✓0 ✗0\n' >> "$B/aidlc-docs/brain/INDEX.md"
brain push "$B" >"$TMP/push3.out" 2>&1
expect_rc "push refuses a shared lesson with an email address" 1 "$?"
check "the refusal says why" contains "$TMP/push3.out" "not shared: it contains an email address"
check "the refused lesson is not in the shared brain" sh -c "! ls '$SH/brain/lessons/' | grep -q 'staging-login'"
brain lint "$B" >"$TMP/lint.out" 2>&1
expect_rc "lint flags project details in a shared-scope lesson" 1 "$?"
grep -v '^Ask ' "$lesson2" > "$TMP/l4" && cat "$TMP/l4" > "$lesson2"
printf 'Use a test account from the team password manager.\n' >> "$lesson2"
brain sync "$B" >"$TMP/push4.out" 2>&1
expect_rc "after making it generic, sync shares it" 0 "$?"
brain lint "$B" >"$TMP/lint.out" 2>&1
expect_rc "lint passes again" 0 "$?"

HINT="$KIT/claude/hooks/learn-hint.sh"
hint() { printf '{"cwd":"%s","prompt":"%s"}' "$1" "$2" | env "${@:3}" bash "$HINT"; }
out="$(hint "$B" "No, that's wrong. Use the existing controller instead.")"
printf '%s' "$out" | grep -q 'AI-DLC learning' && ok "learning hint fires on a correction" || bad "learning hint fires on a correction"
out="$(hint "$B" "I said use the existing widget, why you created a new one")"
printf '%s' "$out" | grep -q 'AI-DLC learning' && ok "learning hint fires on 'I said …'" || bad "learning hint fires on 'I said …'"
out="$(hint "$B" "Add a settings screen with a dark mode switch")"
[ -z "$out" ] && ok "learning hint stays quiet on a normal request" || bad "learning hint stays quiet on a normal request"
out="$(hint "$B" "No, that's wrong." AIDLC_LEARN_HINTS=off)"
[ -z "$out" ] && ok "AIDLC_LEARN_HINTS=off turns the hint off" || bad "AIDLC_LEARN_HINTS=off turns the hint off"
out="$(hint "$TMP/loose" "No, that's wrong.")"
[ -z "$out" ] && ok "no hint outside AI-DLC projects" || bad "no hint outside AI-DLC projects"
out="$(printf '{"cwd":"%s"}' "$B" | bash "$KIT/claude/hooks/session-start.sh")"
printf '%s\n' "$out" | grep -q '^Brain: ' && ok "session start reports the brain" || bad "session start reports the brain"

# =====================================================================================================
section "9. Privacy: nothing from the reference project in the kit"
p1="$(printf 'pocket%s' 'tracker')"; p2="$(printf 'xp%s' 'enz')"; p3="$(printf '91%s' '\.99\.')"
p4="$(printf 'AI%s' 'za[0-9A-Za-z_-]{30}')"; p5="$(printf 'JW9t%s' 'c0By')"; p6="$(printf 'AUTH%s' 'KEY@')"
leaks="$(grep -rEil "$p1|$p2|$p3|$p4|$p5|$p6" "$KIT" 2>/dev/null)"
[ -z "$leaks" ] && ok "no reference-project names, IPs or keys anywhere in the kit" || bad "reference-project data found in: $leaks"

# =====================================================================================================
section "10. Setup: the 3 steps from GUIDE.md (new home folder, real git repository)"
GH="$TMP/guide home"; mkdir -p "$GH"
gh_env() { env -u AIDLC_KIT_HOME HOME="$GH" "$@"; }
# git without the user's global config (no signing, no hooks), like a fresh machine
ggit() { env HOME="$GH" GIT_CONFIG_NOSYSTEM=1 git -c user.name=test -c user.email=test@example.com \
           -c init.defaultBranch=main -c commit.gpgsign=false "$@"; }
git_clean() { [ -z "$(ggit -C "$1" status --porcelain --untracked-files=all)" ]; }
new_repo() { # new_repo <dir>: a committed Flutter project
  mkdir -p "$1/lib"
  printf 'name: demo\nenvironment:\n  sdk: ">=3.5.0 <4.0.0"\ndependencies:\n  flutter:\n    sdk: flutter\n' > "$1/pubspec.yaml"
  printf 'void main() {}\n' > "$1/lib/main.dart"; printf 'build/\n' > "$1/.gitignore"
  ggit -C "$1" init -q && ggit -C "$1" add -A && ggit -C "$1" commit -qm initial
}
step3() { (cd "$1" && ggit add AGENTS.md CLAUDE.md GEMINI.md .agents aidlc-docs .gitignore && ggit commit -qm "chore: add AI-DLC"); }
GP="$GH/StudioProjects/MyApp"
new_repo "$GP" >/dev/null 2>&1

(cd "$KIT" && gh_env bash install.sh) >"$TMP/step1.out" 2>&1
expect_rc "step 1: cd aidlc-kit && bash install.sh (new machine: no ~/.claude, no ~/.gemini)" 0 "$?"
n_hooks="$(grep -o 'aidlc-kit/claude/hooks/[a-z-]*\.sh' "$GH/.claude/settings.json" 2>/dev/null | sort -u | wc -l | tr -d ' ')"
expect_rc "step 1 registers the 5 hooks in a new settings.json" 5 "$n_hooks"
check "step 1 creates ~/.claude/CLAUDE.md with the plan-first rule" contains "$GH/.claude/CLAUDE.md" "AIDLC:BEGIN"
check "step 1 creates ~/.gemini/GEMINI.md with the plan-first rule" contains "$GH/.gemini/GEMINI.md" "AIDLC:BEGIN"
check "step 1 prints the commands for steps 2 and 3" contains "$TMP/step1.out" "git add AGENTS.md CLAUDE.md GEMINI.md .agents aidlc-docs .gitignore && git commit"
gh_env bash "$GH/.aidlc-kit/claude/bin/doctor.sh" --machine >"$TMP/doctor1.out" 2>&1
check "doctor after step 1: no errors, no warnings" contains "$TMP/doctor1.out" "Result: 0 error(s), 0 warning(s)"

gh_env bash "$GH/.aidlc-kit/init-project.sh" "$GP" --dry-run >"$TMP/step2d.out" 2>&1
expect_rc "step 2 preview: init-project.sh <project> --dry-run" 0 "$?"
check "the preview changes nothing" git_clean "$GP"
gh_env bash "$GH/.aidlc-kit/init-project.sh" "$GP" >"$TMP/step2.out" 2>&1
expect_rc "step 2: bash ~/.aidlc-kit/init-project.sh <project>" 0 "$?"
check "step 2 detects Flutter" contains "$GP/.agents/.aidlc-version" "standard=flutter"
check "step 2 copies the shared brain from ~/.aidlc-kit" cmp -s "$GH/.aidlc-kit/brain/INDEX.md" "$GP/.agents/brain/shared/INDEX.md"
check "step 2 prints the commit command" contains "$TMP/step2.out" "git commit -m \"chore: add AI-DLC\""

step3 "$GP" >"$TMP/step3.out" 2>&1
expect_rc "step 3: git add AGENTS.md CLAUDE.md GEMINI.md .agents aidlc-docs .gitignore && git commit" 0 "$?"
check "step 3 leaves nothing uncommitted" git_clean "$GP"
not_committed=""
for f in AGENTS.md CLAUDE.md GEMINI.md .gitignore .agents/.aidlc-version .agents/rules/20-architecture.md \
         .agents/skills/project-architecture/SKILL.md .agents/brain/shared/INDEX.md \
         aidlc-docs/aidlc-state.md aidlc-docs/audit-log.md aidlc-docs/brain/INDEX.md aidlc-docs/brain/inbox.md \
         aidlc-docs/brain/metrics.md; do
  ggit -C "$GP" ls-files --error-unmatch -- "$f" >/dev/null 2>&1 || not_committed="$not_committed $f"
done
while IFS= read -r f; do
  ggit -C "$GP" ls-files --error-unmatch -- "$f" >/dev/null 2>&1 || not_committed="$not_committed $f"
done < <(cd "$KIT/pack" && find .agents -type f ! -name '.DS_Store' | sort)
[ -z "$not_committed" ] && ok "the commit holds every rule, skill, template, the standard and both brains" \
  || bad "not committed:$not_committed"
gh_env bash "$GH/.aidlc-kit/claude/bin/doctor.sh" "$GP" >"$TMP/doctor2.out" 2>&1
expect_rc "doctor after step 3: no errors in the project" 0 "$?"

printf '\nlocal edit\n' >> "$GP/.agents/rules/10-quality-gates.md"
gh_env bash "$GH/.aidlc-kit/init-project.sh" "$GP" >/dev/null 2>&1
check "running step 2 again restores kit files (no diff in .agents/)" ggit -C "$GP" diff --quiet -- .agents
if [ -d "$GP/.agents/.backup" ] && ! ggit -C "$GP" status --porcelain --untracked-files=all | grep -q '[.]agents/[.]backup'; then
  ok "backups of replaced files stay out of git"
else
  bad "backups of replaced files stay out of git"
fi

GO="$GH/StudioProjects/OldApp"
new_repo "$GO" >/dev/null 2>&1
mkdir -p "$GO/.agents/rules" "$GO/.agents/skills/project-architecture"
printf '# Agent workflow\n' > "$GO/.agents/rules/agent-workflow.md"
printf '# Old standard\n' > "$GO/.agents/skills/project-architecture/SKILL.md"
ggit -C "$GO" add -A >/dev/null 2>&1 && ggit -C "$GO" commit -qm "old agent rules" >/dev/null 2>&1
gh_env bash "$GH/.aidlc-kit/init-project.sh" "$GO" --migrate >"$TMP/migrate.out" 2>&1
expect_rc "step 2 with --migrate (project with old .agents rules)" 0 "$?"
step3 "$GO" >"$TMP/step3m.out" 2>&1
expect_rc "step 3 after --migrate" 0 "$?"
check "step 3 after --migrate leaves nothing uncommitted" git_clean "$GO"
archived="$(ggit -C "$GO" ls-files .agents/archive)"
if ! ggit -C "$GO" ls-files --error-unmatch .agents/rules/agent-workflow.md >/dev/null 2>&1 \
   && printf '%s\n' "$archived" | grep -q 'rules/agent-workflow.md' \
   && grep -q '# Old standard' "$GO/.agents/skills/project-architecture/SKILL.md"; then
  ok "the commit moves the old rule to .agents/archive/ and keeps the project's own standard"
else
  bad "the commit moves the old rule to .agents/archive/ and keeps the project's own standard"
fi
gh_env bash "$GH/.aidlc-kit/init-project.sh" "$GO" --update-architecture >/dev/null 2>&1
(cd "$GO" && ggit add AGENTS.md CLAUDE.md GEMINI.md .agents aidlc-docs .gitignore && ggit commit -qm "chore: switch to the kit's standard") >/dev/null 2>&1
expect_rc "switching to the kit's standard later is one more init + commit" 0 "$?"
check "... and leaves nothing uncommitted" git_clean "$GO"
if ggit -C "$GO" ls-files .agents/archive | grep -q 'project-architecture/SKILL.md' \
   && grep -q 'aidlc-kit:standard=flutter' "$GO/.agents/skills/project-architecture/SKILL.md"; then
  ok "the old standard is in .agents/archive/, the kit's standard is installed"
else
  bad "the old standard is in .agents/archive/, the kit's standard is installed"
fi

# =====================================================================================================
section "11. Token measurement (tokens.sh, sample Claude Code records)"
TOK="$KIT/tokens.sh"
TH="$TMP/tokens home"; TP="$TMP/token project"; mkdir -p "$TP/aidlc-docs/work/001-feature-x"
TD="$TH/.claude/projects/$(printf '%s' "$TP" | sed 's/[^A-Za-z0-9]/-/g')"; mkdir -p "$TD/s2/subagents"
call() { # call <id> <time> <input> <cache writes> <cache reads> <output> [thinking]
  printf '{"type":"assistant","timestamp":"%s","message":{"id":"%s","model":"claude-test","usage":{"input_tokens":%s,"cache_creation_input_tokens":%s,"cache_read_input_tokens":%s,"output_tokens":%s,"output_tokens_details":{"thinking_tokens":%s}}}}\n' \
    "$2" "$1" "$3" "$4" "$5" "$6" "${7:-0}"
}
{
  printf '{"type":"user","timestamp":"2026-10-20T09:59:00.000Z","message":{"role":"user","content":"SECRET-CONVERSATION-TEXT"}}\n'
  call msg_A 2026-10-20T10:00:00.000Z 10 100 1000 50 20   # one call written on three lines: counted once
  call msg_A 2026-10-20T10:00:00.100Z 10 100 1000 50 20
  call msg_A 2026-10-20T10:00:00.200Z 10 100 1000 50 20
  printf 'not json\n[1,2]\n'
  printf '{"type":"assistant","timestamp":"2026-10-20T10:30:00.000Z","message":{"id":"msg_S","model":"<synthetic>","usage":{"input_tokens":0,"output_tokens":0}}}\n'
  call msg_B 2026-10-20T11:00:00.000Z 5 0 2000 30
} > "$TD/s1.jsonl"
call msg_C 2026-10-21T09:00:00.000Z 1 10 500 5 > "$TD/s2.jsonl"
call msg_D 2026-10-21T09:05:00.000Z 2 0 100 3 > "$TD/s2/subagents/agent-1.jsonl"
touch -t 202610200000 "$TD/s1.jsonl"; touch -t 202610210000 "$TD/s2.jsonl"
printf '| Date-time | Work item | Stage | Event | Details |\n|---|---|---|---|---|\n| 2026-10-20 10:30 | 001-feature-x | F2 | APPROVED | approve |\n| 2026-10-20 11:30 | 001-feature-x | C6 | COMPLETED | done |\n' > "$TP/aidlc-docs/audit-log.md"
tok() { env -u CLAUDE_CONFIG_DIR HOME="$TH" TZ=UTC bash "$TOK" "$TP" "$@"; }
jval() { python3 -c 'import json, sys; print(json.load(sys.stdin).get(sys.argv[1]))' "$1"; }
expect_rc "latest session (with its subagent): total tokens" 621 "$(tok --json | jval total)"
expect_rc "latest session: model calls" 2 "$(tok --json | jval calls)"
expect_rc "all sessions: a call written on several lines is counted once" 3816 "$(tok --all --json | jval total)"
expect_rc "all sessions: calls (synthetic records and broken lines skipped)" 4 "$(tok --all --json | jval calls)"
expect_rc "all sessions: thinking tokens" 20 "$(tok --all --json | jval thinking)"
expect_rc "all sessions: share of input from the cache" 96.6 "$(tok --all --json | jval cached_share)"
expect_rc "--since keeps only later calls" 621 "$(tok --since '2026-10-21 00:00' --json | jval total)"
expect_rc "--work-item uses the audit log window" 2035 "$(tok --work-item 001-feature-x --json | jval total)"
tok --work-item 001-feature-x --line > "$TMP/tok.out" 2>&1
check "--line prints one summary line" sh -c "[ \$(wc -l < '$TMP/tok.out') -eq 1 ] && grep -q '1 call · 99.8% from cache' '$TMP/tok.out'"
tok --work-item 999-missing --line > "$TMP/tok.out" 2>&1
expect_rc "unknown work item: exit 0" 0 "$?"
check "unknown work item: not measured" contains "$TMP/tok.out" "not measured (work item 999-missing not found"
env HOME="$TH" bash "$TOK" "$TMP/loose" --line > "$TMP/tok.out" 2>&1
expect_rc "a folder without records: exit 0" 0 "$?"
check "a folder without records: not measured" contains "$TMP/tok.out" "not measured (no Claude Code records"
check "tokens.sh never prints conversation text" sh -c "! env HOME='$TH' TZ=UTC bash '$TOK' '$TP' --all | grep -q 'SECRET-CONVERSATION-TEXT'"

# =====================================================================================================
section "12. Remove from a project (remove-project.sh)"
RM="$KIT/remove-project.sh"; RK="$TMP/remove kit home"
RP="$TMP/remove me"; new_flutter_project "$RP"
printf '# Team notes for agents\n' > "$RP/AGENTS.md"; printf 'build/\n' > "$RP/.gitignore"
bash "$KIT/init-project.sh" "$RP" >/dev/null 2>&1
printf '# my own rule\n' > "$RP/.agents/rules/style.md"
printf -- '- [L-001](lessons/L-001-x.md) · rule · flutter · t · my own lesson · ✓1 ✗0\n' >> "$RP/aidlc-docs/brain/INDEX.md"
snap() { (cd "$1" && find . -type f ! -path './.git/*' -exec shasum {} + | sort | shasum); }
before="$(snap "$RP")"
out="$(AIDLC_KIT_HOME="$RK" bash "$RM" "$RP" --dry-run 2>&1)"; rc=$?
expect_rc "remove --dry-run succeeds" 0 "$rc"
[ "$(snap "$RP")" = "$before" ] && ok "remove --dry-run changes nothing" || bad "remove --dry-run changes nothing"
printf '%s\n' "$out" | grep -q 'DRY RUN' && ok "... and says so" || bad "... and says so"
AIDLC_KIT_HOME="$RK" bash "$RM" "$RP" > "$TMP/remove.out" 2>&1
expect_rc "remove succeeds" 0 "$?"
check "your own text in AGENTS.md is kept" contains "$RP/AGENTS.md" "# Team notes for agents"
check "... without the AI-DLC block" sh -c "! grep -q 'AIDLC:BEGIN' '$RP/AGENTS.md'"
check "CLAUDE.md and GEMINI.md that held only the block are deleted" sh -c "[ ! -e '$RP/CLAUDE.md' ] && [ ! -e '$RP/GEMINI.md' ]"
check "the kit's rules, skills, templates, brain copy and version file are gone" sh -c \
  "[ ! -e '$RP/.agents/rules/00-aidlc-core.md' ] && [ ! -e '$RP/.agents/skills/aidlc-feature' ] && [ ! -e '$RP/.agents/templates' ] && [ ! -e '$RP/.agents/brain' ] && [ ! -e '$RP/.agents/.aidlc-version' ]"
check "your own rule file is kept" test -f "$RP/.agents/rules/style.md"
check "your architecture standard is kept" sh -c "[ -f '$RP/.agents/rules/20-architecture.md' ] && [ -f '$RP/.agents/skills/project-architecture/SKILL.md' ]"
check "your aidlc-docs work is kept" contains "$RP/aidlc-docs/brain/INDEX.md" "my own lesson"
check "the state file (the AI-DLC switch) is removed" test ! -e "$RP/aidlc-docs/aidlc-state.md"
check ".gitignore keeps your lines without the AI-DLC ones" sh -c "grep -qx 'build/' '$RP/.gitignore' && ! grep -q 'agents/.backup' '$RP/.gitignore'"
check "everything removed or changed is backed up first" sh -c \
  "find '$RK/backups' -path '*-removed-*' -name 00-aidlc-core.md | grep -q . && find '$RK/backups' -path '*-removed-*' -name aidlc-state.md | grep -q . && grep -rq 'AIDLC:BEGIN' '$RK/backups'"
printf '{"tool_name":"Write","cwd":"%s","tool_input":{"file_path":"%s/lib/main.dart"}}' "$RP" "$RP" | bash "$KIT/claude/hooks/plan-gate.sh" >/dev/null 2>&1
expect_rc "after removal the plan gate no longer blocks" 0 "$?"
out="$(printf '{"cwd":"%s","prompt":"No, that is wrong."}' "$RP" | bash "$KIT/claude/hooks/learn-hint.sh")"
[ -z "$out" ] && ok "after removal no learning hint (PC-1)" || bad "after removal no learning hint (PC-1)"
out="$(printf '{"cwd":"%s"}' "$RP" | bash "$KIT/claude/hooks/session-start.sh")"
printf '%s\n' "$out" | grep -q '^\[AI-DLC\] Project:' && bad "after removal no AI-DLC session context" || ok "after removal no AI-DLC session context"
bash "$KIT/init-project.sh" "$RP" >/dev/null 2>&1
expect_rc "AI-DLC can be added again" 0 "$?"
check "... with the state file back and your lessons kept" sh -c "[ -f '$RP/aidlc-docs/aidlc-state.md' ] && grep -q 'my own lesson' '$RP/aidlc-docs/brain/INDEX.md'"
RA="$TMP/remove all"; new_flutter_project "$RA"; bash "$KIT/init-project.sh" "$RA" >/dev/null 2>&1
printf '# my own rule\n' > "$RA/.agents/rules/style.md"
AIDLC_KIT_HOME="$RK" bash "$RM" "$RA" --all >/dev/null 2>&1
expect_rc "remove --all succeeds" 0 "$?"
check "--all removes aidlc-docs and the standard, keeps your other files" sh -c \
  "[ ! -e '$RA/aidlc-docs' ] && [ ! -e '$RA/.agents/skills' ] && [ \"\$(cd '$RA/.agents' && find . -type f)\" = './rules/style.md' ]"
AIDLC_KIT_HOME="$RK" bash "$RM" "$TMP/loose" >/dev/null 2>&1
expect_rc "refuses a folder without AI-DLC" 1 "$?"
HOME="$TMP/fakehome" AIDLC_KIT_HOME="$RK" bash "$RM" "$TMP/fakehome" >/dev/null 2>&1
expect_rc "refuses the home folder" 1 "$?"

# =====================================================================================================
section "13. Anti-hallucination (verify-plan.sh and the plan-check hook)"
VP="$KIT/verify-plan.sh"; PCK="$KIT/claude/hooks/plan-check.sh"
VA="$TMP/verify app"; new_flutter_project "$VA"; bash "$KIT/init-project.sh" "$VA" >/dev/null 2>&1
mkdir -p "$VA/lib/features/items" "$VA/lib/core/config" "$VA/aidlc-docs/work/001-feature-items" "$VA/aidlc-docs/brain/lessons"
printf 'class ItemsController {\n  void fetchMore() {}\n}\n' > "$VA/lib/features/items/items_controller.dart"
printf '// router\n' > "$VA/lib/core/config/router_config.dart"
printf -- '---\nid: L-001\n---\n' > "$VA/aidlc-docs/brain/lessons/L-001-x.md"
(cd "$VA" && $GIT add -A && $GIT commit -qm base) >/dev/null 2>&1
VPLAN="$VA/aidlc-docs/work/001-feature-items/implementation_plan.md"
cat > "$VPLAN" <<'EOF'
# Implementation Plan: 001-feature-items
> Status: DRAFT
> Type: change · Covers: US-1
## Thinking summary
- Depth: light (paging in one feature)
- Lessons applied: S-003 (watch the notifier), L-001 (paging)
## Facts and assumptions
| # | Claim the plan depends on | Evidence | Status |
|---|---|---|---|
| F1 | <e.g. a claim> | <evidence> | <verified> |
| F2 | `ItemsController.fetchMore` exists | `lib/features/items/items_controller.dart:2` | verified |
| F3 | A user has at most a few hundred items | the user: "a few hundred" | assumption |
## 1. Objective
### US-1: Page through items
- **AC1:** Given 25 items, when the user scrolls to the end, then the next page loads.
<!-- aidlc:files:begin -->
## 3. Files to create
| # | Path | Purpose | Covers |
|---|---|---|---|
| C1 | `lib/features/items/items_screen.dart` | screen | US-1 |
## 4. Files to modify
| # | Path | What changes | Covers |
|---|---|---|---|
| M1 | `lib/features/items/items_controller.dart` | paging | US-1 |
| M2 | `lib/core/config/router_config.dart` | route | US-1 |
<!-- aidlc:files:end -->
## 12. Test plan
| Test file | Type | What it proves | AC · NFR |
|---|---|---|---|
| `test/features/items/items_controller_test.dart` | unit | paging | US-1 AC1 |
## 5. Classes and methods affected
| Class | Method / member | New or changed | Purpose |
|---|---|---|---|
| `ItemsController` | `fetchMore()` | changed | paging |
| `ItemsScreen` | `build` | new | screen |
EOF
bash "$VP" "$VPLAN" > "$TMP/vp.out" 2>&1
expect_rc "a correct plan passes the check" 0 "$?"
check "... and its assumption is listed for the gate" contains "$TMP/vp.out" "fact F3 is an assumption"
BPLAN="$VA/aidlc-docs/work/001-feature-items/bugfix_plan.md"
sed -e 's#`lib/core/config/router_config.dart`#`lib/core/config/router.dart`#' \
    -e 's#| C1 | `lib/features/items/items_screen.dart`#| C1 | `lib/features/items/items_controller.dart`#' \
    -e 's#L-001 (paging)#L-001 (paging), S-999 (none), R-004 (none)#' "$VPLAN" > "$BPLAN"
printf '| `ItemsController` | `loadAll()` | changed | invented member |\n| `BudgetService` | `check` | changed | invented class |\n' >> "$BPLAN"
python3 - "$BPLAN" <<'PYEOF'
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
s = s.replace('| F3 | A user has', '| F4 | The API pages by 20 | | verified |\n| F5 | The backend sends `total` | ? | unknown |\n| F3 | A user has')
open(p, "w", encoding="utf-8").write(s)
PYEOF
bash "$VP" "$BPLAN" > "$TMP/vp.out" 2>&1
expect_rc "a plan with invented things fails the check" 1 "$?"
check "invented file to modify, with the real one suggested" contains "$TMP/vp.out" "does not exist: lib/core/config/router.dart (did you mean: lib/core/config/router_config.dart?)"
check "a file to create that already exists" contains "$TMP/vp.out" "file to create already exists: lib/features/items/items_controller.dart"
check "an invented class" contains "$TMP/vp.out" "class not found in the code: BudgetService"
check "an invented member of a real class" contains "$TMP/vp.out" 'ItemsController has no member "loadAll"'
check "an invented lesson ID" contains "$TMP/vp.out" "lesson S-999 not found"
check "an invented research note" contains "$TMP/vp.out" "research note R-004 not found"
check "a 'verified' fact without evidence" contains "$TMP/vp.out" "fact F4 is marked verified but shows no evidence"
check "an unknown fact" contains "$TMP/vp.out" "fact F5 is unknown"
bash "$VP" "$BPLAN" --quick > "$TMP/vp.out" 2>&1
expect_rc "--quick still fails on invented paths and classes" 1 "$?"
check "--quick skips the facts table (plans in progress)" sh -c "! grep -q 'fact F5' '$TMP/vp.out'"
sed 's/^> Status: DRAFT$/> Status: APPROVED 2026-10-23 10:00/' "$BPLAN" > "$TMP/approved.md" && cat "$TMP/approved.md" > "$BPLAN"
bash "$VP" "$BPLAN" --quick > "$TMP/vp.out" 2>&1
check "an approved plan no longer checks that files to create are new" sh -c "! grep -q 'already exists' '$TMP/vp.out'"
out="$(printf '{"tool_input":{"file_path":"%s"}}' "$BPLAN" | AIDLC_KIT_HOME="$KIT" bash "$PCK" 2>&1)"; rc=$?
expect_rc "hook: a plan with invented things → exit 2 (feedback to Claude)" 2 "$rc"
printf '%s\n' "$out" | grep -q 'router.dart (did you mean' && ok "hook: the feedback names the invented file and the real one" || bad "hook: the feedback names the invented file and the real one"
out="$(printf '{"tool_input":{"file_path":"%s"}}' "$VPLAN" | AIDLC_KIT_HOME="$KIT" bash "$PCK" 2>&1)"; rc=$?
[ "$rc" = 0 ] && [ -z "$out" ] && ok "hook: a correct plan → silent" || bad "hook: a correct plan → silent"
printf '{"tool_input":{"file_path":"%s"}}' "$VA/lib/core/config/router_config.dart" | AIDLC_KIT_HOME="$KIT" bash "$PCK" >/dev/null 2>&1
expect_rc "hook: other files are never checked" 0 "$?"
NPLAN="$VA/aidlc-docs/work/002-feature-markers/implementation_plan.md"; mkdir -p "$(dirname "$NPLAN")"
grep -v 'aidlc:files:' "$VPLAN" > "$NPLAN"
bash "$VP" "$NPLAN" > "$TMP/vp.out" 2>&1
expect_rc "a plan without the aidlc:files markers fails the check" 1 "$?"
check "... and says why" contains "$TMP/vp.out" "aidlc:files markers missing"
printf '{"tool_input":{"file_path":"%s"}}' "$NPLAN" | AIDLC_KIT_HOME="$KIT" bash "$PCK" >/dev/null 2>&1
expect_rc "hook: a plan without the markers → exit 2" 2 "$?"
grep -v 'aidlc:files:end' "$VPLAN" > "$NPLAN"
bash "$VP" "$NPLAN" --quick > "$TMP/vp.out" 2>&1
expect_rc "a plan with only the begin marker fails the check" 1 "$?"
awk '/aidlc:files:begin/ { print; skip = 1; next } /aidlc:files:end/ { skip = 0 } !skip' "$VPLAN" > "$NPLAN"
bash "$VP" "$NPLAN" --quick > "$TMP/vp.out" 2>&1
expect_rc "a plan in progress with an empty file table passes --quick" 0 "$?"
check "... with a warning" contains "$TMP/vp.out" "no files found between the aidlc:files markers"
rm -f "$NPLAN"; rmdir "$(dirname "$NPLAN")"
printf 'class DraftService {\n  void save() {}\n}\n' > "$VA/lib/features/items/draft_service.dart"
UPLAN="$VA/aidlc-docs/work/003-feature-draft/implementation_plan.md"; mkdir -p "$(dirname "$UPLAN")"
printf '# Plan\n> Status: DRAFT\n<!-- aidlc:files:begin -->\n## 4. Files to modify\n| # | Path | What changes |\n|---|---|---|\n| M1 | `lib/features/items/draft_service.dart` | x |\n<!-- aidlc:files:end -->\n## 5. Classes and methods affected\n| Class | Method / member | New or changed | Purpose |\n|---|---|---|---|\n| `DraftService` | `save()` | changed | x |\n| `ItemsController` | `fetchMore()` | changed | x |\n' > "$UPLAN"
bash "$VP" "$UPLAN" --quick > "$TMP/vp.out" 2>&1
expect_rc "a class in a file git does not track yet is found (git grep --untracked)" 0 "$?"
check "... in the same single search as a tracked one" contains "$TMP/vp.out" "2 changed class(es) checked"
rm -f "$UPLAN" "$VA/lib/features/items/draft_service.dart"; rmdir "$(dirname "$UPLAN")"
NG="$TMP/nogit app"; mkdir -p "$NG/lib" "$NG/aidlc-docs/work/001-feature-x"
printf 'class Foo {\n  void bar() {}\n}\n' > "$NG/lib/foo.dart"
printf '# Plan\n> Status: DRAFT\n<!-- aidlc:files:begin -->\n## 4. Files to modify\n| # | Path | What changes |\n|---|---|---|\n| M1 | `lib/foo.dart` | x |\n<!-- aidlc:files:end -->\n## 5. Classes and methods affected\n| Class | Method / member | New or changed | Purpose |\n|---|---|---|---|\n| `Foo` | `bar()` | changed | x |\n| `Baz` | `qux()` | changed | x |\n' > "$NG/aidlc-docs/work/001-feature-x/implementation_plan.md"
if git -C "$NG" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  skip "class search outside git (the test folder is inside a git repository)"
else
  bash "$VP" "$NG/aidlc-docs/work/001-feature-x/implementation_plan.md" --quick > "$TMP/vp.out" 2>&1
  expect_rc "outside git (grep -r): an invented class still fails the check" 1 "$?"
  check "... the real class is found and the invented one is named" sh -c "grep -q 'class not found in the code: Baz' '$TMP/vp.out' && ! grep -q 'not found in the code: Foo' '$TMP/vp.out'"
fi
rm -f "$BPLAN"
printf '// my own work in progress\n' > "$VA/lib/wip.dart"
bash "$VP" "$VPLAN" --baseline > "$TMP/vp.out" 2>&1
expect_rc "--baseline succeeds" 0 "$?"
check "... and records the file that already had uncommitted changes" sh -c "grep -q 'lib/wip.dart' '$VA/aidlc-docs/work/001-feature-items/git-baseline.txt'"
report_files() { # report_files <work item folder>: a test report with baseline and verification rows, a PASS review
  printf '# Test report\n## 1. Baseline\n| Date-time | Check | Command | Result |\n|---|---|---|---|\n| 2026-10-23 10:00 | Tests | flutter test | +3 passed |\n## 3. Verification runs\n| # | Date-time | Command | Result |\n|---|---|---|---|\n| 1 | 2026-10-23 11:00 | flutter test | +4 passed |\n' > "$1/test-report.md"
  printf '# Review\n> Reviewer: aidlc-reviewer · Verdict: PASS\n' > "$1/review-report.md"
}
report_files "$VA/aidlc-docs/work/001-feature-items"
printf 'class ItemsScreen {}\n' > "$VA/lib/features/items/items_screen.dart"
printf '// paging\n' >> "$VA/lib/features/items/items_controller.dart"
printf '// not planned\n' > "$VA/lib/other.dart"
bash "$VP" "$VPLAN" --done > "$TMP/vp.out" 2>&1
expect_rc "--done: a file changed outside the plan fails" 1 "$?"
check "... and is named" contains "$TMP/vp.out" "changed but not in the plan: lib/other.dart"
rm -f "$VA/lib/other.dart"
bash "$VP" "$VPLAN" --done > "$TMP/vp.out" 2>&1
expect_rc "--done: every planned file exists and nothing else changed" 0 "$?"
check "--done: a file changed before the work item and untouched since is only a warning" contains "$TMP/vp.out" "changed before this work item and untouched since (baseline): lib/wip.dart"
printf '// changed again\n' >> "$VA/lib/wip.dart"
bash "$VP" "$VPLAN" --done > "$TMP/vp.out" 2>&1
expect_rc "--done: a baseline file that changed again fails" 1 "$?"
check "... and says so" contains "$TMP/vp.out" "changed but not in the plan: lib/wip.dart (it had changes before this work item and changed again)"
rm -f "$VA/lib/wip.dart"
printf '\n' >> "$VA/.agents/rules/10-quality-gates.md"
bash "$VP" "$VPLAN" --done > "$TMP/vp.out" 2>&1
expect_rc "--done: a changed kit-managed rule counts as an unplanned change" 1 "$?"
check "... and is named" contains "$TMP/vp.out" "changed but not in the plan: .agents/rules/10-quality-gates.md"
(cd "$VA" && $GIT checkout -q -- .agents/rules/10-quality-gates.md)
MR="$TMP/mono repo"; mkdir -p "$MR/apps/mobile/lib" "$MR/apps/mobile/aidlc-docs/work/001-feature-x" "$MR/other"
printf 'class X {}\n' > "$MR/apps/mobile/lib/x.dart"; printf 'y\n' > "$MR/other/y.txt"
printf '# Plan\n> Status: APPROVED 2026-10-23 10:00\n<!-- aidlc:files:begin -->\n## 4. Files to modify\n| # | Path | What changes |\n|---|---|---|\n| M1 | `lib/x.dart` | x |\n<!-- aidlc:files:end -->\n' > "$MR/apps/mobile/aidlc-docs/work/001-feature-x/implementation_plan.md"
(cd "$MR" && $GIT init -q && $GIT add -A && $GIT commit -qm base) >/dev/null 2>&1
printf '// changed\n' >> "$MR/apps/mobile/lib/x.dart"; printf 'changed by another team\n' >> "$MR/other/y.txt"
report_files "$MR/apps/mobile/aidlc-docs/work/001-feature-x"
bash "$VP" "$MR/apps/mobile/aidlc-docs/work/001-feature-x/implementation_plan.md" --done > "$TMP/vp.out" 2>&1
expect_rc "--done in a project folder inside a bigger repository: the planned change passes, other folders are ignored" 0 "$?"
check "... with paths relative to the project folder" sh -c "! grep -q 'apps/mobile' '$TMP/vp.out'"

section "14. Every stage is proven (stages, traceability, open items, construction records)"
SP="$TMP/stage app"; SW="$SP/aidlc-docs/work/004-feature-budget"; mkdir -p "$SW" "$SP/lib/features/budget"
printf 'class BudgetController {\n  void save() {}\n}\n' > "$SP/lib/features/budget/budget_controller.dart"
printf '# AI-DLC Audit Log\n| Date-time | Work item | Stage | Event | Details |\n|---|---|---|---|---|\n| 2026-10-23 10:00 | 004-feature-budget | F3 Integration plan | APPROVED | "approve" |\n' > "$SP/aidlc-docs/audit-log.md"
cat > "$SW/requirements.md" <<'EOF'
# Requirements: budget
> Stage NP4 / F2 · Status: DRAFT · Work item: 004-feature-budget
### US-1: Set a budget
- **AC1:** Given no budget, when the user saves 100, then the budget is 100.
### US-2: Budget alert
- **AC1:** Given a budget of 100, when spending reaches 100, then an alert is shown.
| NFR-1 | Performance | the alert appears within 1 s |
| BR-1 | A budget is greater than 0 | budget form |
EOF
printf '# Integration Plan\n> Stage NP5 / F3 · Status: DRAFT · Work item: 004-feature-budget\n| INT-1 | push notifications |\n' > "$SW/integration-plan.md"
printf '# Questions\n## Open items\n<!-- Remove items once answered. No gate can pass while an [OPEN-BLOCKING] item exists. -->\n- [OPEN-BLOCKING] …\n- [OPEN-BLOCKING] Which push provider?\n' > "$SW/questions.md"
SPLAN="$SW/implementation_plan.md"
cat > "$SPLAN" <<'EOF'
# Implementation Plan: 004-feature-budget
> Status: DRAFT
> Type: feature · Covers: US-1, US-2
## Thinking summary
- Depth: full (a new feature)
## Facts and assumptions
| # | Claim the plan depends on | Evidence | Status |
|---|---|---|---|
| F1 | `BudgetController.save` exists | `lib/features/budget/budget_controller.dart:2` | verified |
## 1. Objective
Budgets and alerts.
<!-- aidlc:files:begin -->
## 4. Files to modify
| # | Path | What changes | Covers |
|---|---|---|---|
| M1 | `lib/features/budget/budget_controller.dart` | save | US-1 |
<!-- aidlc:files:end -->
## 12. Test plan
| Test file | Type | What it proves | AC · NFR |
|---|---|---|---|
| `test/budget_controller_test.dart` | unit | saves | US-1 AC1 |
## 13. Verification
flutter analyze, flutter test
## 14. Task plan
- [ ] ⏳ **[PENDING]** T1 Save the budget (US-1)
---
☐ no [OPEN-BLOCKING] question left
EOF
(cd "$SP" && $GIT init -q && $GIT add -A && $GIT commit -qm base) >/dev/null 2>&1
bash "$VP" "$SPLAN" > "$TMP/sp.out" 2>&1
expect_rc "a plan with gaps in its earlier stages and traceability fails the check" 1 "$?"
check "... requirements (F2) not approved" contains "$TMP/sp.out" "stage F2 not approved: requirements.md"
check "... an APPROVED row in the audit log counts (F3)" contains "$TMP/sp.out" "stage F3: integration-plan.md approved"
check "... a story without a test" contains "$TMP/sp.out" "US-2 has no test in the test plan"
check "... a story without a file or task" contains "$TMP/sp.out" "US-2 is not built by any file or task"
check "... an NFR without a named check" contains "$TMP/sp.out" "NFR-1: name how it is verified"
check "... business rules and integrations are warnings" sh -c "grep -q '! BR-1 (business rule)' '$TMP/sp.out' && grep -q '! INT-1 (integration)' '$TMP/sp.out'"
expect_rc "... one open blocking item (comments, placeholders and checklist lines don't count)" 1 "$(grep -c 'open blocking item' "$TMP/sp.out")"
sed 's/Status: DRAFT/Status: APPROVED 2026-10-23 11:00/' "$SW/requirements.md" > "$TMP/r.md" && cat "$TMP/r.md" > "$SW/requirements.md"
grep -v 'Which push provider' "$SW/questions.md" > "$TMP/q.md" && cat "$TMP/q.md" > "$SW/questions.md"
python3 - "$SPLAN" <<'PYEOF'
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
s = s.replace("| save | US-1 |", "| save; alert through INT-1; BR-1 | US-1, US-2 |")
s = s.replace("| saves | US-1 AC1 |", "| saves; alerts within 1 s (NFR-1) | US-1 AC1, US-2 AC1 |")
open(p, "w", encoding="utf-8").write(s)
PYEOF
bash "$VP" "$SPLAN" > "$TMP/sp.out" 2>&1
expect_rc "after the fixes the plan passes" 0 "$?"
check "... with its traceability line" contains "$TMP/sp.out" "traceability: 2 user stories and 1 NFR(s) traced"
sed 's/^> Status: DRAFT$/> Status: APPROVED 2026-10-23 12:00/' "$SPLAN" > "$TMP/p.md" && cat "$TMP/p.md" > "$SPLAN"
bash "$VP" "$SPLAN" > "$TMP/sp.out" 2>&1
check "an approved plan is not checked for earlier stages again" sh -c "! grep -q 'stage F2' '$TMP/sp.out'"
bash "$VP" "$SPLAN" --done > "$TMP/sp.out" 2>&1
expect_rc "--done before the work is finished fails" 1 "$?"
check "... names the open task" contains "$TMP/sp.out" "task not done: T1 Save the budget"
check "... and the missing reports" sh -c "grep -q 'test-report.md is missing' '$TMP/sp.out' && grep -q 'review-report.md is missing' '$TMP/sp.out'"
sed 's/^- \[ \] ⏳ \*\*\[PENDING\]\*\* T1/- [x] ✅ **[COMPLETED]** T1/' "$SPLAN" > "$TMP/p.md" && cat "$TMP/p.md" > "$SPLAN"
printf '# Test report\n## 1. Baseline\n| Date-time | Check | Command | Result |\n|---|---|---|---|\n| 2026-10-23 12:05 | Tests | flutter test | +3 passed |\n## 3. Verification runs\n| # | Date-time | Command | Result |\n|---|---|---|---|\n' > "$SW/test-report.md"
printf '# Review\n> Reviewer: aidlc-reviewer · Verdict: PASS | PASS WITH FIXES | BLOCKED\n' > "$SW/review-report.md"
bash "$VP" "$SPLAN" --done > "$TMP/sp.out" 2>&1
check "--done: a test report without a verification run fails" contains "$TMP/sp.out" "C5: no verification run with a date"
check "--done: a review with the template's verdict fails" contains "$TMP/sp.out" "review-report.md has no verdict yet"
printf '| 1 | 2026-10-23 13:00 | flutter test | +5 passed |\n' >> "$SW/test-report.md"
printf '# Review\n> Reviewer: aidlc-reviewer · Verdict: BLOCKED\n' > "$SW/review-report.md"
bash "$VP" "$SPLAN" --done > "$TMP/sp.out" 2>&1
check "--done: a BLOCKED review fails" contains "$TMP/sp.out" "the review verdict is BLOCKED"
printf '# Review\n> Reviewer: aidlc-reviewer · Verdict: PASS WITH FIXES\n## 4. Findings\n| Severity | Path:line | Issue | Fix | Status |\n|---|---|---|---|---|\n| Blocking | lib/x.dart:3 | y | z | open |\n' > "$SW/review-report.md"
bash "$VP" "$SPLAN" --done > "$TMP/sp.out" 2>&1
check "--done: an open Blocking finding fails" contains "$TMP/sp.out" "still has an open Blocking finding"
sed 's/| open |$/| fixed |/' "$SW/review-report.md" > "$TMP/rr.md" && cat "$TMP/rr.md" > "$SW/review-report.md"
bash "$VP" "$SPLAN" --done > "$TMP/sp.out" 2>&1
expect_rc "--done: every stage left its record → passes" 0 "$?"
check "... and says so" contains "$TMP/sp.out" "every stage left its record"
check "... a missing git baseline is only a warning" contains "$TMP/sp.out" "no git-baseline.txt"
LPLAN="$SP/aidlc-docs/work/005-change-label/implementation_plan.md"; mkdir -p "$(dirname "$LPLAN")"
printf '# Plan\n> Status: DRAFT\n> Type: change\n## Thinking summary\n- Depth: light (one label)\n## 1. Objective\nRename a label.\n<!-- aidlc:files:begin -->\n## 4. Files to modify\n| # | Path | What changes |\n|---|---|---|\n| M1 | `lib/features/budget/budget_controller.dart` | label |\n<!-- aidlc:files:end -->\n' > "$LPLAN"
bash "$VP" "$LPLAN" > "$TMP/sp.out" 2>&1
check "a light plan without its stories in §1 fails" contains "$TMP/sp.out" "light plan: §1 needs the user stories"
grep -v '^> Type:' "$LPLAN" > "$TMP/p.md" && cat "$TMP/p.md" > "$LPLAN"
bash "$VP" "$LPLAN" > "$TMP/sp.out" 2>&1
check "a plan without a Type line fails" contains "$TMP/sp.out" 'the plan header has no "Type:" line'
FPLAN="$SP/aidlc-docs/work/006-bugfix-total/bugfix_plan.md"; mkdir -p "$(dirname "$FPLAN")"
printf '# Bug-fix Plan\n> Status: DRAFT\n## 3. Root cause\n- Where: `path/to/file:line`\n<!-- aidlc:files:begin -->\n## 6. Files to modify\n| # | Path | What changes |\n|---|---|---|\n| M1 | `lib/features/budget/budget_controller.dart` | guard |\n<!-- aidlc:files:end -->\n' > "$FPLAN"
bash "$VP" "$FPLAN" > "$TMP/sp.out" 2>&1
check "a bug fix whose root cause has no path:line fails" contains "$TMP/sp.out" "Root cause needs path:line evidence"
sed 's#`path/to/file:line`#`lib/features/budget/budget_controller.dart:2`#' "$FPLAN" > "$TMP/p.md" && cat "$TMP/p.md" > "$FPLAN"
bash "$VP" "$FPLAN" > "$TMP/sp.out" 2>&1
check "... and passes with it" contains "$TMP/sp.out" "the root cause cites path:line"
mkdir -p "$SP/aidlc-docs/project"; printf '# Requirements\n> Stage NP4 · Status: DRAFT\n' > "$SP/aidlc-docs/project/03-requirements.md"
XPLAN="$SP/aidlc-docs/work/001-setup-project-scaffold/implementation_plan.md"; mkdir -p "$(dirname "$XPLAN")"
printf '# Plan\n> Status: DRAFT\n> Type: setup\n<!-- aidlc:files:begin -->\n## 3. Files to create\n| # | Path | Purpose |\n|---|---|---|\n| C1 | `lib/main.dart` | entry |\n<!-- aidlc:files:end -->\n' > "$XPLAN"
bash "$VP" "$XPLAN" > "$TMP/sp.out" 2>&1
check "a scaffold plan before the project documents are approved fails" sh -c "grep -q 'stage NP4 missing or not approved' '$TMP/sp.out' && grep -q 'stage NP6 missing or not approved' '$TMP/sp.out'"
DW="$VA/aidlc-docs/work/005-feature-done"; mkdir -p "$DW"
printf '# Plan\n> Status: COMPLETED 2026-10-23 12:00\n' > "$DW/implementation_plan.md"; printf 'x\n' > "$DW/test-report.md"; printf 'x\n' > "$DW/reflection.md"
out="$(AIDLC_KIT_HOME="$KIT" bash "$KIT/claude/bin/doctor.sh" "$VA" 2>&1)"
printf '%s\n' "$out" | grep -q 'without the record of a stage: 005-feature-done/review-report.md' \
  && ok "doctor: a completed work item without its review report is listed" || bad "doctor: a completed work item without its review report is listed"
printf 'x\n' > "$DW/review-report.md"
out="$(AIDLC_KIT_HOME="$KIT" bash "$KIT/claude/bin/doctor.sh" "$VA" 2>&1)"
printf '%s\n' "$out" | grep -q 'process audit: 1 completed work item' \
  && ok "doctor: the process audit passes when every record is there" || bad "doctor: the process audit passes when every record is there"
rm -f "$DW/implementation_plan.md" "$DW/test-report.md" "$DW/reflection.md" "$DW/review-report.md"; rmdir "$DW"
CS="$KIT/pack/.agents"
check "core rule: after approval the document's Status becomes APPROVED" contains "$CS/rules/00-aidlc-core.md" "set the document's Status line to"
check "integration plan: a design section for full depth" contains "$CS/templates/integration-plan.md" "## 11. Design (full depth)"
check "construction: logic is built test first" contains "$CS/skills/aidlc-construction/SKILL.md" "Logic is built test first"
check "plan template: an end-to-end check" contains "$CS/templates/implementation_plan.md" "**End-to-end check:**"
check "delivery plan: shared contracts between units" contains "$CS/templates/delivery-plan.md" "### 3.1 Shared contracts"
check "new project: a milestone check" contains "$CS/skills/aidlc-new-project/SKILL.md" "**Milestone check:**"
check "research: spikes" contains "$CS/skills/aidlc-research/SKILL.md" "## Spike (when the docs can't settle it)"
check "bug fix: what must not change" contains "$CS/templates/bugfix_plan.md" "- Must not change:"
check "reviewer: only real gaps" contains "$KIT/claude/agents/aidlc-reviewer.md" "**Scope:** report only what affects correctness"
check "release: web and backend deploys, rollout gates" sh -c "grep -q 'Web or backend' '$CS/skills/aidlc-release/SKILL.md' && grep -q 'with gates' '$CS/skills/aidlc-release/SKILL.md'"

# =====================================================================================================
printf '\nResult: %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
command -v flutter >/dev/null 2>&1 && printf 'Also run: bash tests/flutter-standard-check.sh (compiles and tests the Flutter standard)\n'
[ "$FAIL" -eq 0 ]
