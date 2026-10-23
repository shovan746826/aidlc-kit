#!/usr/bin/env bash
# AI-DLC kit: mechanical check of a plan (implementation, bug-fix or release plan): anti-hallucination and stages.
#   bash verify-plan.sh <plan.md> [--quick | --baseline | --done]
# Checks that what the plan relies on is real and that no stage was skipped:
#   • the file tables sit between the aidlc:files markers (the plan gate reads only the files between them)
#   • every file to modify exists (with "did you mean" suggestions); files to create are new (draft plans)
#   • classes and members marked "changed" in "Classes and methods affected" exist in the code
#   • cited lessons (S-…, L-…) and research notes (R-…) exist
#   • Facts and assumptions: "verified" rows show evidence, no row is "unknown" (assumptions are listed)
#   • stages (draft plans): the documents before the plan are approved; every user story (US-n) has a test and a
#     file or task, every NFR-n a named check; no [OPEN-BLOCKING] item is left
#   --quick     files, classes and IDs only (the Claude Code hook uses it while a plan is being written)
#   --baseline  before building (C1): records the files that already have uncommitted changes (git-baseline.txt)
#   --done      after building: every planned file exists, nothing outside the plan changed (git), every numbered
#               task is done, and the test and review reports show the baseline, the verification and a PASS
# Exit 0 = no problems · 1 = problems: fix them, or ask the user, before the gate.

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=claude/hooks/lib.sh
. "$KIT/claude/hooks/lib.sh"

usage() { sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

plan=""; mode="full"
while [ $# -gt 0 ]; do
  case "$1" in
    --quick) mode="quick"; shift ;;
    --baseline) mode="baseline"; shift ;;
    --done) mode="done"; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) usage; exit 2 ;;
    *) plan="$1"; shift ;;
  esac
done
if [ -z "$plan" ] || [ ! -f "$plan" ]; then usage; echo "✗ plan file not found: ${plan:-none}" >&2; exit 2; fi
plan="$(cd "$(dirname "$plan")" && pwd)/$(basename "$plan")"
case "$plan" in
  */aidlc-docs/*) root="${plan%%/aidlc-docs/*}" ;;
  *) root="$(git -C "$(dirname "$plan")" rev-parse --show-toplevel 2>/dev/null)" || root="$(dirname "$plan")" ;;
esac

problems=0; warnings=0
ok()   { printf '  ✓ %s\n' "$1"; }
bad()  { printf '  ✗ %s\n' "$1"; problems=$((problems + 1)); }
warn() { printf '  ! %s\n' "$1"; warnings=$((warnings + 1)); }
rel_to_root() { R="$root/" awk 'index($0, ENVIRON["R"]) == 1 { print substr($0, length(ENVIRON["R"]) + 1); next } { print }'; }

SKIP_DIRS=".git build .dart_tool .gradle Pods node_modules aidlc-docs .agents .idea .vscode DerivedData .fvm"
EXCLUDES=""; for d in $SKIP_DIRS; do EXCLUDES="$EXCLUDES --exclude-dir=$d"; done
GIT_EXCLUDES=(); for d in $SKIP_DIRS; do GIT_EXCLUDES+=(":(exclude,glob)**/$d/**"); done
in_git() { git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; }

PLAN_DIR="$(dirname "$plan")"; PLAN_NAME="$(basename "$plan")"; WORK_ITEM="$(basename "$PLAN_DIR")"
# section <file> <n>: the text under the heading "## <n>." up to the next "## " heading.
section() { N="$2" awk 'index($0, "## " ENVIRON["N"] ".") == 1 { on = 1; next } on && /^## / { exit } on' "$1" 2>/dev/null; }
# header_value <file> <Key>: the first word after "Key:" ("> Type: feature" → feature, "- Depth: light" → light).
header_value() {
  grep -m 1 -iE "^[>[:space:]*_-]*$2[*_]*:" "$1" 2>/dev/null | sed -E 's/^[^:]*:[*_]*[[:space:]]*//' | awk '{ print tolower($1) }'
}
# doc_approved <file> <stage code> [work item]: its Status line says APPROVED, or the audit log has an APPROVED row
# for that work item and stage (00-aidlc-core §5).
doc_approved() {
  local s wi="${3:-$WORK_ITEM}" log="$root/aidlc-docs/audit-log.md"
  s="$(grep -m 1 -oiE 'status[*_]*:[*_]*[[:space:]]*[A-Za-z]+' "$1" 2>/dev/null | sed -E 's/.*[[:space:]:*_]//' | tr '[:lower:]' '[:upper:]')"
  [ "$s" = "APPROVED" ] && return 0
  [ -f "$log" ] || return 1
  grep -F -- "$wi" "$log" | grep -E "(^|[^A-Za-z0-9])$2([^0-9]|\$)" | grep -q 'APPROVED'
}
# ids <text> <prefix>: the IDs with that prefix (US-3, NFR-2, …) named in the text, once each.
ids() { printf '%s\n' "$1" | grep -oE "(^|[^A-Za-z0-9])$2-[0-9]+" | grep -oE "$2-[0-9]+" | sort -u; }
# mentions <text> <id or pattern>: the text names it (US-1 does not match US-10).
mentions() { printf '%s\n' "$1" | grep -qE "(^|[^A-Za-z0-9])$2([^0-9]|\$)"; }
# open_items <file>: "line:text" of real [OPEN-BLOCKING] items (not comments, checklist lines or placeholders).
open_items() {
  grep -n '\[OPEN-BLOCKING\]' "$1" 2>/dev/null | grep -v '<!--' | grep -vi 'no \[OPEN-BLOCKING\]' \
    | grep -vE '\[OPEN-BLOCKING\][[:space:]]*…[[:space:]]*$'
}

# plan_files <plan>: "create|modify|any<TAB>path" for each planned path (the Path column, as the plan gate reads it).
plan_files() {
  awk '
    function emit(tok) {
      gsub(/^[ \t]+/, "", tok); gsub(/[ \t]+$/, "", tok); sub(/^\.\//, "", tok)
      if (tok == "" || tok ~ /[<>]/ || index(tok, "…") > 0) return
      print kind "\t" tok
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
    /aidlc:files:begin/ { inside = 1; kind = "any"; pathcol = 0; next }
    /aidlc:files:end/ { inside = 0; next }
    !inside { next }
    /^#+[ \t].*[Ff]iles to create/ { kind = "create"; pathcol = 0; next }
    /^#+[ \t].*[Ff]iles to modify/ { kind = "modify"; pathcol = 0; next }
    {
      line = $0; sub(/^[ \t]+/, "", line)
      if (substr(line, 1, 1) != "|") { pathcol = 0; if (line ~ /^[-*+] /) tokens(line, 0); next }
      n = split(line, cells, "|")
      if (index(line, "`") == 0) { for (i = 1; i <= n; i++) if (tolower(trim(cells[i])) == "path") pathcol = i; next }
      if (pathcol > 0 && pathcol <= n) { tokens(cells[pathcol], 1); next }
      for (i = 1; i <= n; i++) if (index(cells[i], "`") > 0) { tokens(cells[i], 1); break }
    }
  ' "$1" 2>/dev/null
}

# plan_classes <plan>: "class<TAB>member" for rows marked changed / existing in "Classes and methods affected".
plan_classes() {
  awk '
    function trim(x) { gsub(/^[ \t`]+/, "", x); gsub(/[ \t`]+$/, "", x); return x }
    /^#+[ \t].*Classes and methods affected/ { inside = 1; next }
    inside && /^#/ { inside = 0 }
    !inside || !/^\|/ { next }
    {
      n = split($0, c, "|"); if (n < 5) next
      cls = trim(c[2]); mem = trim(c[3]); state = tolower(c[4])
      if (cls == "" || cls ~ /^:?-+:?$/ || tolower(cls) == "class" || cls ~ /[<>…]/) next
      if (state ~ /chang|exist|modif/) print cls "\t" mem
    }
  ' "$1" 2>/dev/null
}

# plan_facts <plan>: "id<TAB>status<TAB>evidence" per row of "Facts and assumptions" ("MISSING" without the table).
plan_facts() {
  awk '
    function trim(x) { gsub(/^[ \t]+/, "", x); gsub(/[ \t]+$/, "", x); return x }
    /^#+[ \t]+Facts and assumptions/ { inside = 1; found = 1; next }
    inside && /^#/ { inside = 0 }
    !inside || !/^\|/ { next }
    {
      n = split($0, c, "|"); if (n < 6) next
      id = trim(c[2]); claim = trim(c[3]); ev = trim(c[4]); st = tolower(trim(c[5]))
      if (id == "" || id == "#" || id ~ /^:?-+:?$/ || (claim ~ /[<>]/ && st ~ /[<>]/)) next
      print id "\t" st "\t" ev
    }
    END { if (!found) print "MISSING" }
  ' "$1" 2>/dev/null
}

# suggest <path>: up to three real files with the same name, else with a similar name (router.dart → router_config.dart).
suggest() {
  local base stem found
  base="$(basename "$1")"; stem="${base%.*}"
  find_named() {
    find "$root" \( -name .git -o -name build -o -name .dart_tool -o -name node_modules -o -name Pods -o -name .gradle \) \
      -prune -o -type f -name "$1" -print 2>/dev/null | rel_to_root | head -n 3
  }
  found="$(find_named "$base")"
  [ -n "$found" ] || [ "${#stem}" -lt 3 ] || found="$(find_named "*$stem*.${base##*.}")"
  printf '%s' "$found" | tr '\n' ',' | sed -e 's/,$//' -e 's/,/, /g'
}

# exists_planned <path>: the path, folder entry ("dir/") or glob matches something in the project.
exists_planned() {
  local p="$1" m
  case "$p" in
    */) [ -d "$root/$p" ] ;;
    *'*'*) for m in "$root"/$p; do [ -e "$m" ] && return 0; done; return 1 ;;
    *) [ -e "$root/$p" ] ;;
  esac
}

# find_decls <Name1|Name2|…>: "path<TAB>name" for every declaration of these classes, found in ONE search of the
# project (git grep in a git work tree: fast, and it skips ignored files; grep -r elsewhere).
find_decls() {
  local re="(class|struct|enum|protocol|interface|object|mixin|extension|actor|typealias|typedef)[[:space:]]+($1)([^A-Za-z0-9_]|\$)"
  if in_git; then
    git -C "$root" grep -IoE --untracked "$re" -- . "${GIT_EXCLUDES[@]}" 2>/dev/null | R="$root/" awk '{ print ENVIRON["R"] $0 }'
  else
    # shellcheck disable=SC2086
    grep -rIoE $EXCLUDES "$re" "$root" 2>/dev/null
  fi | awk '{
    i = index($0, ":"); n = split(substr($0, i + 1), w, /[^A-Za-z0-9_]+/)
    for (k = 2; k <= n; k++) if (w[k] != "") { print substr($0, 1, i - 1) "\t" w[k]; break }
  }'
}

# git_changes: the project's changed files (git status), one per line and relative to the project root, also when
# the project is a folder inside a bigger repository (changes outside that folder are not listed).
git_changes() {
  local prefix line p
  prefix="$(git -C "$root" rev-parse --show-prefix 2>/dev/null)"
  git -C "$root" status --porcelain --untracked-files=all -- . 2>/dev/null | while IFS= read -r line; do
    [ -n "$line" ] || continue
    p="${line#???}"; p="${p##* -> }"; p="${p#\"}"; p="${p%\"}"
    printf '%s\n' "${p#"$prefix"}"
  done
}
BASE_FILE="$(dirname "$plan")/git-baseline.txt"
# content_hash <path>: git's hash of the file as it is now, or "deleted".
content_hash() { if [ -e "$root/$1" ]; then git -C "$root" hash-object -- "$1" 2>/dev/null; else echo deleted; fi; }
# baseline_hash <path>: the hash that --baseline recorded for the path, or nothing.
baseline_hash() { [ -f "$BASE_FILE" ] && P="$1" awk -F '\t' '!/^#/ && $2 == ENVIRON["P"] { print $1; exit }' "$BASE_FILE"; }

# 0. Before building (C1): record what already had uncommitted changes, so --done can tell it apart ----------------
if [ "$mode" = "baseline" ]; then
  printf 'AI-DLC baseline · %s\n' "$(printf '%s\n' "$plan" | rel_to_root)"
  if in_git; then
    {
      printf '# Uncommitted changes before this work item (verify-plan.sh --baseline, %s). --done reads this file.\n' "$(date '+%Y-%m-%d %H:%M')"
      git_changes | while IFS= read -r p; do
        is_free_doc "$p" "$root/$p" || printf '%s\t%s\n' "$(content_hash "$p")" "$p"
      done
    } > "$BASE_FILE"
    ok "$(grep -vc '^#' "$BASE_FILE") file(s) already had uncommitted changes: $(printf '%s\n' "$BASE_FILE" | rel_to_root)"
  else
    warn "not a git repository: nothing to record"
  fi
  printf 'Result: %d problem(s), %d warning(s)\n' "$problems" "$warnings"
  exit 0
fi

printf 'AI-DLC plan check · %s\n' "$(printf '%s\n' "$plan" | rel_to_root)"
files="$(plan_files "$plan")"
status="$(plan_status "$plan")"

# 1. Files ---------------------------------------------------------------------------------------------------------
n_mod=0; n_new=0; markers=1
if ! grep -q 'aidlc:files:begin' "$plan" || ! grep -q 'aidlc:files:end' "$plan"; then
  markers=0
  bad "aidlc:files markers missing: put the file tables between them, as in the plan template (the plan gate reads only those files)"
fi
while IFS="$(printf '\t')" read -r kind p; do
  [ -n "$p" ] || continue
  if [ "$mode" = "done" ]; then
    if [ "$kind" != "any" ] && ! exists_planned "$p"; then bad "planned but missing after the build: $p"; fi
    continue
  fi
  if [ "$kind" = "modify" ]; then
    n_mod=$((n_mod + 1))
    if ! exists_planned "$p"; then
      s="$(suggest "$p")"
      bad "file to modify does not exist: $p${s:+ (did you mean: $s?)}"
    fi
  elif [ "$kind" = "create" ]; then
    n_new=$((n_new + 1))
    if [ "$status" != "APPROVED" ] && [ "$status" != "COMPLETED" ] && [ -e "$root/$p" ]; then
      bad "file to create already exists: $p (move it to the files to modify)"
    fi
  fi
done <<EOF
$files
EOF
if [ "$mode" != "done" ]; then
  [ "$markers" = 1 ] && [ "$n_mod$n_new" = "00" ] && warn "no files found between the aidlc:files markers"
  [ "$n_mod" -gt 0 ] && ok "$n_mod file(s) to modify checked"
  [ "$n_new" -gt 0 ] && ok "$n_new file(s) to create checked"
fi

# 2. Classes and members (one search for all of them) ------------------------------------------------------------
if [ "$mode" != "done" ]; then
  TAB="$(printf '\t')"; rows=""; names=""
  while IFS="$TAB" read -r cls mem; do
    name="$(printf '%s' "$cls" | grep -oE '[A-Za-z_][A-Za-z0-9_]*' | head -n 1)"
    [ -n "$name" ] || continue
    rows="$rows$name$TAB$(printf '%s' "$mem" | grep -oE '[A-Za-z_][A-Za-z0-9_]*' | head -n 1)
"
    names="$names${names:+|}$name"
  done <<EOF
$(plan_classes "$plan")
EOF
  decls=""; [ -z "$names" ] || decls="$(find_decls "$names")"
  n_cls=0
  while IFS="$TAB" read -r name member; do
    [ -n "$name" ] || continue
    n_cls=$((n_cls + 1))
    decl="$(printf '%s\n' "$decls" | N="$name" awk -F '\t' '$2 == ENVIRON["N"] { print $1 }' | sort -u)"
    if [ -z "$decl" ]; then
      bad "class not found in the code: $name (marked \"changed\")"
    elif [ -n "$member" ]; then
      found=""
      while IFS= read -r f; do
        if grep -qw -- "$member" "$f"; then found=1; break; fi
      done <<DECL
$decl
DECL
      [ -n "$found" ] || bad "$name has no member \"$member\" in $(printf '%s\n' "$decl" | rel_to_root | head -n 1)"
    fi
  done <<EOF
$rows
EOF
  [ "$n_cls" -gt 0 ] && ok "$n_cls changed class(es) checked"
fi

# 3. Cited lessons and research notes -------------------------------------------------------------------------------
if [ "$mode" != "done" ]; then
  ids="$(grep -oE '(^|[^A-Za-z0-9_-])(S|L|R)-[0-9]{2,4}([^0-9]|$)' "$plan" | grep -oE '(S|L|R)-[0-9]{2,4}' | sort -u)"
  n_ids=0
  for id in $ids; do
    n_ids=$((n_ids + 1)); num=$((10#${id#*-})); pre="${id%%-*}"; padded="$(printf '%s-%03d' "$pre" "$num")"
    case "$pre" in
      S) ls "$root/.agents/brain/shared/lessons/$padded-"*.md >/dev/null 2>&1 \
           || ls "$AIDLC_KIT_HOME/brain/lessons/$padded-"*.md >/dev/null 2>&1 \
           || bad "lesson $id not found in the shared brain" ;;
      L) ls "$root/aidlc-docs/brain/lessons/$padded-"*.md >/dev/null 2>&1 || bad "lesson $id not found in aidlc-docs/brain/lessons/" ;;
      R) ls "$root/aidlc-docs/brain/research/$padded-"*.md >/dev/null 2>&1 || bad "research note $id not found in aidlc-docs/brain/research/" ;;
    esac
  done
  [ "$n_ids" -gt 0 ] && ok "$n_ids cited lesson / research ID(s) checked"
fi

# 4. Facts and assumptions ------------------------------------------------------------------------------------------
if [ "$mode" = "full" ]; then
  facts="$(plan_facts "$plan")"
  if [ "$facts" = "MISSING" ]; then
    warn "no \"Facts and assumptions\" table (plan template v2.7): list the facts the plan depends on"
  else
    n_f=0
    while IFS="$(printf '\t')" read -r id st ev; do
      [ -n "$id" ] || continue
      n_f=$((n_f + 1))
      case "$st" in
        *unknown*|*unverif*) bad "fact $id is unknown: find it in the code or docs, or ask the user before the gate" ;;
        *verif*)
          printf '%s' "$ev" | grep -qE ':[0-9]+|https?://|`|"|user' \
            || bad "fact $id is marked verified but shows no evidence (path:line, command, URL or the user's words)" ;;
        *assum*) warn "fact $id is an assumption: list it at the gate" ;;
        *) bad "fact $id: status must be verified, assumption or unknown (found: ${st:-empty})" ;;
      esac
    done <<EOF
$facts
EOF
    [ "$n_f" -gt 0 ] && ok "$n_f fact(s) checked"
  fi
fi

# 4b. Stages before this plan, traceability and open items (draft plans; the full check before the gate) ----------
if [ "$mode" = "full" ] && [ "$status" != "APPROVED" ] && [ "$status" != "COMPLETED" ]; then
  plan_type="$(header_value "$plan" Type)"; depth="$(header_value "$plan" Depth)"
  case "$PLAN_NAME" in
    implementation_plan.md)
      case "$plan_type" in
        feature|change)
          if [ "$depth" = "light" ]; then
            if mentions "$(section "$plan" 1)" 'US-[0-9]+' && section "$plan" 1 | grep -qiE 'given|AC[0-9]'; then
              ok "light plan: §1 holds the user stories with acceptance criteria"
            else
              bad "light plan: §1 needs the user stories (US-n) with acceptance criteria (aidlc-feature, light mode)"
            fi
          else
            for f in requirements.md:F2 integration-plan.md:F3; do
              doc="${f%%:*}"; code="${f#*:}"
              if [ ! -f "$PLAN_DIR/$doc" ]; then
                bad "stage $code skipped: no $doc in this work item (full depth: it is approved before the plan)"
              elif doc_approved "$PLAN_DIR/$doc" "$code"; then
                ok "stage $code: $doc approved"
              else
                bad "stage $code not approved: $doc (show its gate card, wait for the approval, set its Status to APPROVED)"
              fi
            done
          fi ;;
        setup)
          if [ -d "$root/aidlc-docs/project" ]; then
            for f in 03-requirements.md:NP4 05-architecture.md:NP6 06-delivery-plan.md:NP7; do
              doc="${f%%:*}"; code="${f#*:}"
              if [ -f "$root/aidlc-docs/project/$doc" ] && doc_approved "$root/aidlc-docs/project/$doc" "$code" project; then
                ok "stage $code: $doc approved"
              else
                bad "stage $code missing or not approved: aidlc-docs/project/$doc (aidlc-new-project)"
              fi
            done
          fi ;;
        "") bad "the plan header has no \"Type:\" line (feature · change · setup): the stage checks need it" ;;
      esac ;;
    bugfix_plan.md)
      if section "$plan" 3 | grep -qE '[A-Za-z0-9_-]\.[A-Za-z0-9]+:[0-9]+'; then ok "bug fix: the root cause cites path:line"
      else bad "bug fix: §3 Root cause needs path:line evidence (aidlc-bugfix B2): never guess a fix"; fi ;;
  esac

  # Traceability: every story is built and tested, every NFR has a named check (like Spec Kit's /analyze).
  if [ "$PLAN_NAME" = implementation_plan.md ] && { [ "$plan_type" = feature ] || [ "$plan_type" = change ]; }; then
    if [ "$depth" = "light" ]; then reqs="$(section "$plan" 1)"; else reqs="$(cat "$PLAN_DIR/requirements.md" 2>/dev/null)"; fi
    tests="$(section "$plan" 12)"
    built="$(sed -n '/aidlc:files:begin/,/aidlc:files:end/p' "$plan"; section "$plan" 14)"
    checks="$(section "$plan" 10; section "$plan" 12; section "$plan" 13)"
    whole="$(cat "$plan")"
    n_us=0; n_nfr=0
    for id in $(ids "$reqs" US); do
      n_us=$((n_us + 1))
      mentions "$tests" "$id" || bad "$id has no test in the test plan (§12)"
      mentions "$built" "$id" || bad "$id is not built by any file or task (Covers column or §14)"
    done
    for id in $(ids "$reqs" NFR); do
      n_nfr=$((n_nfr + 1))
      mentions "$checks" "$id" || bad "$id: name how it is verified (§12 test plan, §13 verification or §10 risks)"
    done
    for id in $(ids "$reqs" BR); do mentions "$whole" "$id" || warn "$id (business rule) is not named in the plan: where is it built and tested?"; done
    if [ -f "$PLAN_DIR/integration-plan.md" ]; then
      for id in $(ids "$(cat "$PLAN_DIR/integration-plan.md")" INT); do mentions "$whole" "$id" || warn "$id (integration) is not named in the plan"; done
    fi
    if [ "$n_us" -gt 0 ]; then ok "traceability: $n_us user stor$([ "$n_us" = 1 ] && echo y || echo ies) and $n_nfr NFR(s) traced to files, tasks and tests"
    elif [ "$depth" != "light" ]; then bad "no user stories (US-n) found in requirements.md to trace"; fi
  fi

  # Open blocking questions: no gate passes while one is left (00-aidlc-core §4).
  n_open=0
  for f in "$plan" "$PLAN_DIR/questions.md" "$PLAN_DIR/requirements.md" "$PLAN_DIR/integration-plan.md" \
           "$([ "${plan_type:-}" = setup ] && echo "$root/aidlc-docs/project/questions.md")"; do
    [ -n "$f" ] && [ -f "$f" ] || continue
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      n_open=$((n_open + 1)); bad "open blocking item, $(basename "$f") line ${line%%:*}: ask the user before the gate"
    done <<EOF
$(open_items "$f")
EOF
  done
  [ "$n_open" = 0 ] && ok "no open blocking item"
fi

# 5. After the build: nothing outside the plan changed ---------------------------------------------------------------
if [ "$mode" = "done" ]; then
  if in_git; then
    n_out=0
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      is_free_doc "$p" "$root/$p" && continue
      path_in_plan "$p" "$plan" && continue
      before="$(baseline_hash "$p")"
      if [ -n "$before" ] && [ "$before" = "$(content_hash "$p")" ]; then
        warn "changed before this work item and untouched since (baseline): $p. Leave it; name it in the report"
        continue
      fi
      bad "changed but not in the plan: $p${before:+ (it had changes before this work item and changed again)}"; n_out=$((n_out + 1))
    done <<EOF
$(git_changes)
EOF
    [ "$n_out" = 0 ] && ok "no file outside the plan changed"
  else
    warn "not a git repository: unplanned changes cannot be checked"
  fi

  # Every construction stage left its record (aidlc-construction C1–C5).
  open_tasks="$(grep -E '^[[:space:]]*- \[ \].*\*\*\[(PENDING|IN PROGRESS|BLOCKED)\]\*\*[[:space:]]+T[0-9]+' "$plan" \
    | sed -E 's/.*\*\*\[[A-Z ]+\]\*\*[[:space:]]+//' | cut -c1-90)"
  while IFS= read -r t; do [ -z "$t" ] || bad "task not done: $t"; done <<EOF
$open_tasks
EOF
  TR="$PLAN_DIR/test-report.md"; RR="$PLAN_DIR/review-report.md"
  if [ ! -f "$TR" ]; then
    bad "test-report.md is missing (C1 baseline, C5 verification)"
  else
    section "$TR" 1 | grep -qE '^\|[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}' || bad "C1: no baseline row with a date in test-report.md §1"
    section "$TR" 3 | grep -qE '^\|[^|]*\|[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}' || bad "C5: no verification run with a date in test-report.md §3"
  fi
  if [ "$PLAN_NAME" != release-plan.md ]; then
    if [ ! -f "$RR" ]; then
      bad "review-report.md is missing (C4 review and gap analysis)"
    else
      case "$(grep -m 1 'Verdict:' "$RR")" in
        *"PASS | PASS WITH FIXES"*|"") bad "C4: review-report.md has no verdict yet" ;;
        *BLOCKED*) bad "C4: the review verdict is BLOCKED: fix the Blocking findings and review again" ;;
        *PASS*) : ;;
        *) bad "C4: review-report.md has no verdict yet" ;;
      esac
      grep -iE '^\|[[:space:]]*Blocking[[:space:]]*\|' "$RR" | grep -qiE '\|[[:space:]]*open[[:space:]]*\|[[:space:]]*$' \
        && bad "C4: review-report.md still has an open Blocking finding"
    fi
  fi
  if in_git && [ ! -f "$BASE_FILE" ]; then
    warn "C1: no git-baseline.txt (--baseline was not run): changes made before this work item count as unplanned"
  fi
  [ "$problems" = 0 ] && ok "every planned file exists and every stage left its record"
fi

printf 'Result: %d problem(s), %d warning(s)\n' "$problems" "$warnings"
[ "$problems" -eq 0 ]
