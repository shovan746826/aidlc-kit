#!/usr/bin/env bash
# AI-DLC kit: Claude Code PostToolUse hook for Edit|Write|MultiEdit. Formats files after Claude writes them.
# AIDLC_AUTOFORMAT = new-files (default) | all | off
#   new-files: only files that git does not track yet, so existing code is never reformatted
#              (10-quality-gates §1). Outside a git repository nothing is formatted.
# Never blocks: always exits 0.

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

input="$(cat)"
mode="$(aidlc_config AIDLC_AUTOFORMAT new-files)"
[ "$mode" = "off" ] && exit 0

file="$(json_get "$input" .tool_input.file_path)"
[ -n "$file" ] && [ -f "$file" ] || exit 0
dir="$(dirname "$file")"

# Only in AI-DLC projects, like the plan gate (every repository when AIDLC_ENFORCE=all-repos).
if ! find_up "$dir" aidlc-docs/aidlc-state.md >/dev/null; then
  [ "$(aidlc_config AIDLC_ENFORCE project)" = "all-repos" ] || exit 0
fi

if [ "$mode" != "all" ]; then
  git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
  git -C "$dir" ls-files --error-unmatch -- "$file" >/dev/null 2>&1 && exit 0   # tracked → leave it
fi

case "$file" in
  *.dart)
    root="$(find_up "$dir" pubspec.yaml)" || root=""
    if [ -n "$root" ] && [ -x "$root/.fvm/flutter_sdk/bin/dart" ]; then
      "$root/.fvm/flutter_sdk/bin/dart" format "$file" >/dev/null 2>&1
    elif command -v dart >/dev/null 2>&1; then
      dart format "$file" >/dev/null 2>&1
    fi ;;
  *.kt|*.kts)
    if command -v ktlint >/dev/null 2>&1 && find_up "$dir" .editorconfig >/dev/null; then
      ktlint -F "$file" >/dev/null 2>&1
    fi ;;
  *.swift)
    if command -v swiftformat >/dev/null 2>&1 && find_up "$dir" .swiftformat >/dev/null; then
      swiftformat "$file" >/dev/null 2>&1
    elif command -v swift-format >/dev/null 2>&1 && find_up "$dir" .swift-format >/dev/null; then
      swift-format format -i "$file" >/dev/null 2>&1
    fi ;;
  *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs|*.vue|*.css|*.scss)
    root="$(find_up "$dir" package.json)" || root=""
    if [ -n "$root" ] && [ -x "$root/node_modules/.bin/prettier" ]; then
      "$root/node_modules/.bin/prettier" --write "$file" >/dev/null 2>&1
    fi ;;
  *.py)
    if command -v ruff >/dev/null 2>&1; then ruff format "$file" >/dev/null 2>&1
    elif command -v black >/dev/null 2>&1; then black -q "$file" >/dev/null 2>&1; fi ;;
  *.go)
    command -v gofmt >/dev/null 2>&1 && gofmt -w "$file" >/dev/null 2>&1 ;;
esac
exit 0
