#!/usr/bin/env bash
# AI-DLC kit: compile-check the Flutter house standard.
# Every code block in standards/flutter/SKILL.md and reference/*.md whose first line is `// lib/...` or `// test/...` is written
# into a fresh Flutter app named `app`; then `flutter analyze` must report no issues and `flutter test` must pass.
# Runs for flutter_riverpod 2.x and 3.x (on 3.x the commented legacy/misc imports are switched on).
#
# Usage: bash tests/flutter-standard-check.sh [--riverpod 2|3|both] [--keep]
# Skips (exit 0) when Flutter is not installed. Uses the local pub cache first (works offline).

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$KIT/standards/flutter/SKILL.md"
WHICH="both"; KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --riverpod) WHICH="$2"; shift 2 ;;
    --keep) KEEP=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

command -v flutter >/dev/null 2>&1 || { echo "SKIP: Flutter is not installed"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 is needed to extract the code blocks"; exit 0; }

BASE="$(mktemp -d 2>/dev/null)" || BASE=""
case "$BASE" in ""|"/"|"$HOME") echo "could not create a temporary folder" >&2; exit 1 ;; esac
[ "$KEEP" = 1 ] || trap 'rm -rf "$BASE"' EXIT

extract() { # extract <app-dir> <markdown files...> → prints the number of files written
  python3 - "$@" <<'PY'
import os, re, sys
app, sources = sys.argv[1], sys.argv[2:]
text = "\n".join(open(p, encoding="utf-8").read() for p in sources)
count = 0
for block in re.findall(r"```dart\n(.*?)```", text, flags=re.S):
    first = block.split("\n", 1)[0].strip()
    m = re.match(r"^// ((?:lib|test)/[\w/.-]+\.dart)$", first)
    if not m:
        continue
    path = os.path.join(app, m.group(1))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(block)
    count += 1
print(count)
PY
}

check() { # check <2|3>
  local v="$1" app="$BASE/riverpod$1/app" riverpod
  if [ "$v" = 3 ]; then riverpod="3.3.2"; else riverpod="2.6.1"; fi
  echo "── flutter_riverpod $v.x"
  mkdir -p "$(dirname "$app")"
  flutter create --no-pub --offline --project-name app --platforms android,ios "$app" >/dev/null 2>&1 \
    || flutter create --no-pub --project-name app --platforms android,ios "$app" >/dev/null 2>&1 \
    || { echo "  ✗ flutter create failed"; return 1; }
  rm -rf "$app/lib" "$app/test"
  n="$(extract "$app" "$SKILL" "$KIT"/standards/flutter/reference/*.md)"
  echo "  files extracted: $n"
  python3 - "$app/pubspec.yaml" "$riverpod" <<'PY'
import re, sys
path, riverpod = sys.argv[1], sys.argv[2]
created = open(path, encoding="utf-8").read()
sdk = re.search(r"^  sdk: (.+)$", created, flags=re.M).group(1)
open(path, "w", encoding="utf-8").write(f"""name: app
description: Compile check of the AI-DLC Flutter house standard.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: {sdk}

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^{riverpod}
  go_router: ^14.8.1
  dio: ^5.9.0
  flutter_screenutil: ^5.9.3
  shared_preferences: ^2.5.3
  flutter_secure_storage: ^9.2.4
  package_info_plus: ^8.3.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
""")
PY
  if [ "$v" = 3 ]; then
    grep -rl "flutter_riverpod 3.x: uncomment" "$app/lib" "$app/test" | while IFS= read -r f; do
      sed -i.bak -E "s#^// (import 'package:flutter_riverpod/(legacy|misc)\.dart';) // flutter_riverpod 3\.x: uncomment.*#\1#" "$f" && rm -f "$f.bak"
    done
  fi
  (cd "$app" && { flutter pub get --offline >/dev/null 2>&1 || flutter pub get >/dev/null 2>&1; }) \
    || { echo "  ✗ flutter pub get failed"; return 1; }
  if [ "$v" = 3 ]; then (cd "$app" && dart fix --apply --code=unused_import >/dev/null 2>&1); fi
  local analyze
  analyze="$(cd "$app" && flutter analyze 2>&1)"
  if printf '%s' "$analyze" | grep -q "No issues found"; then
    echo "  ✓ flutter analyze: no issues"
  else
    echo "  ✗ flutter analyze:"; printf '%s\n' "$analyze" | grep -E "error|warning|info" | sed 's/^/    /' | head -40
    return 1
  fi
  local tests
  tests="$(cd "$app" && flutter test 2>&1)"
  if printf '%s' "$tests" | grep -q "All tests passed"; then
    echo "  ✓ flutter test: $(printf '%s' "$tests" | grep -oE '\+[0-9]+' | tail -n 1 | tr -d '+') tests passed"
  else
    echo "  ✗ flutter test:"; printf '%s\n' "$tests" | tail -40 | sed 's/^/    /'
    return 1
  fi
}

status=0
case "$WHICH" in
  2) check 2 || status=1 ;;
  3) check 3 || status=1 ;;
  *) check 2 || status=1; check 3 || status=1 ;;
esac
[ "$KEEP" = 1 ] && echo "apps kept in $BASE"
exit "$status"
