#!/usr/bin/env bash
# AI-DLC kit: brain tools. Plain bash + awk; works for every agent and by hand.
#   bash brain.sh stats <project>   lessons, inbox, research notes, index sizes, scorecard rows
#   bash brain.sh lint  <project>   checks lessons and indexes (fields, evidence, duplicates, size, secrets)
#   bash brain.sh push  <project>   approved lessons with `scope: shared` → shared brain (ids S-101 and up)
#   bash brain.sh pull  <project>   shared brain → <project>/.agents/brain/shared/ (read-only copy)
#   bash brain.sh sync  <project>   push, then pull
# Shared brain: ${AIDLC_KIT_HOME:-~/.aidlc-kit}/brain (starter lessons ship in the kit's brain/ folder).

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED="${AIDLC_KIT_HOME:-$HOME/.aidlc-kit}/brain"
PROJECT_INDEX_MAX=8192
SHARED_INDEX_MAX=8192

usage() { sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

cmd="${1:-}"
project="${2:-$PWD}"
case "$cmd" in stats|lint|push|pull|sync) ;; *) usage; exit 2 ;; esac
[ -d "$project" ] || { echo "✗ not a folder: $project" >&2; exit 1; }
project="$(cd "$project" && pwd)"
BRAIN="$project/aidlc-docs/brain"
COPY="$project/.agents/brain/shared"

# fm <file> <key>: a frontmatter value.
fm() {
  awk 'NR == 1 && $0 == "---" {inside = 1; next} inside && $0 == "---" {exit} inside' "$1" 2>/dev/null \
    | grep -E "^$2:" | head -n 1 | cut -d: -f2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# set_fm <file> <key> <value>: replace one frontmatter value in place.
set_fm() {
  local tmp; tmp="$(mktemp)"
  awk -v key="$2" -v value="$3" '
    NR == 1 && $0 == "---" {inside = 1; print; next}
    inside && $0 == "---" {inside = 0}
    inside && index($0, key ":") == 1 {print key ": " value; next}
    {print}
  ' "$1" > "$tmp" && cat "$tmp" > "$1"
  rm -f "$tmp"
}

count_index() { local n; n="$(grep -c '^- \[' "$1" 2>/dev/null)"; echo "${n:-0}"; }

# private_data <file> → a short description of the first project-specific detail in the file, or nothing.
# Shared lessons are copied into every project (and its git repository), so they must stay generic.
private_data() {
  local hit
  hit="$(grep -oE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$1" 2>/dev/null | grep -vE '@[0-9]+x\.' | head -n 1)"
  if [ -n "$hit" ]; then echo "an email address ($hit)"; return 0; fi
  hit="$(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$1" 2>/dev/null | grep -vE '^(127\.0\.0\.1|10\.0\.2\.2|0\.0\.0\.0)$' | head -n 1)"
  if [ -n "$hit" ]; then echo "an IP address ($hit)"; return 0; fi
  hit="$(grep -oE '(/Users/|/home/)[A-Za-z0-9._-]+' "$1" 2>/dev/null | head -n 1)"
  if [ -n "$hit" ]; then echo "a home-folder path ($hit)"; return 0; fi
  hit="$(grep -oE 'http://[A-Za-z0-9][^[:space:])`>"]*' "$1" 2>/dev/null | grep -vE '^http://(localhost|127\.0\.0\.1|10\.0\.2\.2)([:/]|$)' | head -n 1)"
  if [ -n "$hit" ]; then echo "an http:// address ($hit)"; return 0; fi
  return 0
}

index_line() { # index_line <lesson file> <id> <relative path>
  local tags; tags="$(fm "$1" tags | tr -d '[]')"
  printf -- '- [%s](%s) · %s · %s · %s · %s · ✓%s ✗%s\n' "$2" "$3" "$(fm "$1" type)" "$(fm "$1" stack)" \
    "$tags" "$(fm "$1" title)" "$(fm "$1" helpful)" "$(fm "$1" harmful)"
}

do_stats() {
  [ -d "$BRAIN" ] || { echo "No project brain in $project (run init-project.sh)."; return 1; }
  local proposed=0 retired=0 f
  for f in "$BRAIN"/lessons/*.md; do
    [ -f "$f" ] || continue
    case "$(fm "$f" status)" in proposed) proposed=$((proposed + 1)) ;; retired) retired=$((retired + 1)) ;; esac
  done
  local inbox research rows
  inbox="$(grep -cE '^\| [0-9]+ \|' "$BRAIN/inbox.md" 2>/dev/null || true)"
  research="$(ls "$BRAIN"/research/*.md 2>/dev/null | wc -l | tr -d ' ')"
  rows="$(awk '/^## Trend/ {exit} /^\| [0-9]{4}-/' "$BRAIN/metrics.md" 2>/dev/null | wc -l | tr -d ' ')"
  echo "AI-DLC brain · $project"
  echo "  project lessons: $(count_index "$BRAIN/INDEX.md") active · $proposed proposed · $retired retired"
  echo "  shared lessons (copy): $(count_index "$COPY/INDEX.md")"
  echo "  inbox: ${inbox:-0} waiting · research notes: $research · scorecard rows: $rows"
  echo "  index size: $(wc -c < "$BRAIN/INDEX.md" | tr -d ' ') / $PROJECT_INDEX_MAX bytes"
  grep -m1 '^Last maintenance' "$BRAIN/metrics.md" 2>/dev/null | sed 's/^/  /'
}

lint_dir() { # lint_dir <brain dir> <index max> <label>
  local dir="$1" max="$2" label="$3" errors=0 f key value
  [ -f "$dir/INDEX.md" ] || { echo "  ✗ $label: INDEX.md missing"; return 1; }
  local size; size="$(wc -c < "$dir/INDEX.md" | tr -d ' ')"
  if [ "$size" -gt "$max" ]; then echo "  ✗ $label: INDEX.md is $size bytes (max $max): run maintenance"; errors=$((errors + 1)); fi
  for f in "$dir"/lessons/*.md; do
    [ -f "$f" ] || continue
    for key in id title type scope stack status confidence source evidence created; do
      value="$(fm "$f" "$key")"
      if [ -z "$value" ]; then echo "  ✗ $label: ${f##*/} has no '$key'"; errors=$((errors + 1)); fi
    done
    case "$(fm "$f" evidence)" in "<"*|"") echo "  ✗ $label: ${f##*/} has no real evidence"; errors=$((errors + 1)) ;; esac
    if [ "$(fm "$f" status)" = "active" ] && ! grep -qF "(lessons/${f##*/})" "$dir/INDEX.md"; then
      echo "  ✗ $label: active lesson ${f##*/} is missing from INDEX.md"; errors=$((errors + 1))
    fi
  done
  local ref
  while IFS= read -r ref; do
    [ -f "$dir/$ref" ] || { echo "  ✗ $label: INDEX.md points to a missing file: $ref"; errors=$((errors + 1)); }
  done < <(grep -E '^- \[' "$dir/INDEX.md" | grep -oE '\]\(lessons/[^)]+\)' | sed -e 's/^](//' -e 's/)$//')
  local dupes
  dupes="$(for f in "$dir"/lessons/*.md; do [ -f "$f" ] && [ "$(fm "$f" status)" != "retired" ] && fm "$f" title; done \
    | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9\n' | sort | uniq -d)"
  if [ -n "$dupes" ]; then echo "  ✗ $label: duplicate lesson titles (merge them): $(printf '%s' "$dupes" | tr '\n' ' ')"; errors=$((errors + 1)); fi
  if grep -rEn 'AIza[0-9A-Za-z_-]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY|Bearer [A-Za-z0-9._-]{24,}|(password|passwd|secret|api[_-]?key)[[:space:]]*[:=][[:space:]]*[^[:space:]<]{6,}' \
       "$dir" >/dev/null 2>&1; then
    echo "  ✗ $label: something that looks like a secret is stored in the brain:"
    grep -rEln 'AIza[0-9A-Za-z_-]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY|Bearer [A-Za-z0-9._-]{24,}|(password|passwd|secret|api[_-]?key)[[:space:]]*[:=][[:space:]]*[^[:space:]<]{6,}' "$dir" | sed 's/^/      /'
    errors=$((errors + 1))
  fi
  local why
  for f in "$dir"/lessons/*.md; do   # lessons that every project gets must not carry one project's details
    [ -f "$f" ] || continue
    [ "$label" = "shared brain" ] || [ "$(fm "$f" scope)" = "shared" ] || continue
    why="$(private_data "$f")"
    if [ -n "$why" ]; then echo "  ✗ $label: ${f##*/} is for every project but contains $why: make it generic"; errors=$((errors + 1)); fi
  done
  [ "$errors" -eq 0 ] && echo "  ✓ $label: $(count_index "$dir/INDEX.md") lessons in the index, index $size bytes"
  [ "$errors" -eq 0 ]
}

do_lint() {
  local status=0
  echo "AI-DLC brain lint"
  if [ -d "$BRAIN" ]; then lint_dir "$BRAIN" "$PROJECT_INDEX_MAX" "project brain" || status=1; else echo "  ! no project brain"; fi
  if [ -d "$SHARED" ]; then lint_dir "$SHARED" "$SHARED_INDEX_MAX" "shared brain" || status=1; fi
  return "$status"
}

do_push() {
  [ -d "$BRAIN/lessons" ] || { echo "push: no project lessons"; return 0; }
  if [ ! -f "$SHARED/INDEX.md" ]; then
    mkdir -p "$SHARED/lessons"
    cp "$KIT/brain/INDEX.md" "$SHARED/INDEX.md" 2>/dev/null || printf '# Shared Brain: Index\n\n' > "$SHARED/INDEX.md"
    cp "$KIT"/brain/lessons/*.md "$SHARED/lessons/" 2>/dev/null || true
  fi
  mkdir -p "$SHARED/lessons"
  local pushed=0 refused=0 f next slug new_id target why
  for f in "$BRAIN"/lessons/*.md; do
    [ -f "$f" ] || continue
    [ "$(fm "$f" scope)" = "shared" ] && [ "$(fm "$f" status)" = "active" ] || continue
    case "$(fm "$f" shared_as)" in ""|none) ;; *) continue ;; esac
    why="$(private_data "$f")"
    if [ -n "$why" ]; then
      echo "  ✗ $(fm "$f" id) not shared: it contains $why. Every project gets shared lessons: make it generic, then sync again."
      refused=$((refused + 1)); continue
    fi
    # Your shared lessons are S-101 and up; S-001 to S-099 belong to the kit's starter lessons.
    next="$(ls "$SHARED"/lessons/S-*.md 2>/dev/null | sed -E 's#.*/S-([0-9]+).*#\1#' | awk '$1 + 0 >= 101 { print $1 + 0 }' | sort -n | tail -n 1)"
    next=$(( ${next:-100} + 1 ))
    new_id="$(printf 'S-%03d' "$next")"
    slug="$(basename "$f" .md | sed -E 's/^L-[0-9]+-//')"
    target="$SHARED/lessons/$new_id-$slug.md"
    cp "$f" "$target"
    set_fm "$target" id "$new_id"
    set_fm "$target" shared_as "$new_id"
    if ! grep -q '^## Shared from projects' "$SHARED/INDEX.md"; then printf '\n## Shared from projects\n' >> "$SHARED/INDEX.md"; fi
    index_line "$target" "$new_id" "lessons/${target##*/}" >> "$SHARED/INDEX.md"
    set_fm "$f" shared_as "$new_id"
    echo "  → $(fm "$f" id) shared as $new_id: $(fm "$f" title)"
    pushed=$((pushed + 1))
  done
  echo "push: $pushed lesson(s) added to the shared brain ($SHARED)"
  [ "$refused" -eq 0 ] || { echo "push: $refused lesson(s) refused (see above)"; return 1; }
}

do_pull() {
  local src="$SHARED"
  [ -f "$src/INDEX.md" ] || src="$KIT/brain"
  [ -f "$src/INDEX.md" ] || { echo "pull: no shared brain found"; return 1; }
  mkdir -p "$COPY/lessons"
  cp "$src/INDEX.md" "$COPY/INDEX.md"
  rm -f "$COPY"/lessons/*.md
  cp "$src"/lessons/*.md "$COPY/lessons/" 2>/dev/null || true
  echo "pull: $(count_index "$COPY/INDEX.md") shared lessons copied to ${COPY#"$project"/}"
}

case "$cmd" in
  stats) do_stats ;;
  lint) do_lint ;;
  push) do_push ;;
  pull) do_pull ;;
  sync) push_ok=1; do_push || push_ok=0; do_pull && [ "$push_ok" = 1 ] ;;
esac
