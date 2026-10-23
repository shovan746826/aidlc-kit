#!/usr/bin/env bash
# AI-DLC kit: real token use, read from Claude Code's own session records (~/.claude/projects/<project>/).
#   bash tokens.sh [project] [--work-item <id> | --since "YYYY-MM-DD HH:MM" [--until "…"] | --all] [--line | --json]
# Default: the latest session of the project. Each model call is counted once (Claude Code writes one call
# on several lines). Reads only the usage numbers, times and model names, never the conversation text.
# Prints "not measured" (exit 0) when there are no records or python3 is missing.

usage() { sed -n '2,6p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

project=""; work_item=""; since=""; until_=""; scope="latest"; format="table"
while [ $# -gt 0 ]; do
  case "$1" in
    --work-item) [ $# -ge 2 ] || { usage; exit 2; }; work_item="$2"; scope="work-item"; shift 2 ;;
    --since) [ $# -ge 2 ] || { usage; exit 2; }; since="$2"; scope="window"; shift 2 ;;
    --until) [ $# -ge 2 ] || { usage; exit 2; }; until_="$2"; scope="window"; shift 2 ;;
    --all) scope="all"; shift ;;
    --line) format="line"; shift ;;
    --json) format="json"; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) usage; exit 2 ;;
    *) project="$1"; shift ;;
  esac
done
project="${project:-$PWD}"
[ -d "$project" ] || { echo "✗ not a folder: $project" >&2; exit 1; }
root="$(git -C "$project" rev-parse --show-toplevel 2>/dev/null)" || root="$(cd "$project" && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Tokens: not measured (python3 is needed to read Claude Code's records)"
  exit 0
fi

# Claude Code keeps each folder's sessions in ~/.claude/projects/<the folder path, every other character
# turned into "-">/. Try the path as given and with symlinks resolved.
projects="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"
NL='
'
dirs=""
for p in "$root" "$(cd "$root" && pwd -P)"; do
  d="$projects/$(printf '%s' "$p" | sed 's/[^A-Za-z0-9]/-/g')"
  [ -d "$d" ] || continue
  case "$NL$dirs$NL" in *"$NL$d$NL"*) ;; *) dirs="$dirs${dirs:+$NL}$d" ;; esac
done 2>/dev/null

python3 - "$root" "$scope" "$work_item" "$since" "$until_" "$format" "$dirs" <<'PY'
import datetime, glob, json, os, sys

root, scope, work_item, since_s, until_s, fmt, dirs_s = sys.argv[1:8]
dirs = [d for d in dirs_s.split("\n") if d]

def local_ts(text):          # "YYYY-MM-DD HH:MM" in local time → epoch seconds
    return datetime.datetime.strptime(text.strip(), "%Y-%m-%d %H:%M").timestamp()

def record_ts(text):         # "2026-10-21T16:41:33.843Z" → epoch seconds
    try:
        return datetime.datetime.fromisoformat(text.replace("Z", "+00:00")).timestamp()
    except (AttributeError, ValueError):
        return None

def not_measured(why):
    if fmt == "json":
        print(json.dumps({"measured": False, "reason": why}))
    else:
        print("Tokens: not measured (%s)" % why)
    sys.exit(0)

since = until = None
label = {"latest": "latest session", "all": "all sessions"}.get(scope, "")
try:
    if since_s:
        since = local_ts(since_s)
    if until_s:
        until = local_ts(until_s) + 59
except ValueError:
    print("✗ use the time format YYYY-MM-DD HH:MM", file=sys.stderr)
    sys.exit(2)
if scope == "window":
    label = "since %s" % since_s if since_s else "until %s" % until_s
    if since_s and until_s:
        label = "%s to %s" % (since_s, until_s)

if scope == "work-item":
    # From the work item's first trace (its folder or its first audit-log line) to its COMPLETED line.
    starts, ends = [], []
    audit = os.path.join(root, "aidlc-docs", "audit-log.md")
    try:
        for line in open(audit, encoding="utf-8"):
            cells = [c.strip() for c in line.split("|")]
            if len(cells) > 4 and cells[2] == work_item:
                try:
                    t = local_ts(cells[1])
                except ValueError:
                    continue
                starts.append(t)
                if cells[4].upper() == "COMPLETED":
                    ends.append(t + 59)
    except OSError:
        pass
    for folder in (os.path.join(root, "aidlc-docs", "work", work_item),
                   os.path.join(root, "aidlc-docs", "releases", work_item.replace("release-", "", 1))):
        if os.path.isdir(folder):
            st = os.stat(folder)
            starts.append(getattr(st, "st_birthtime", st.st_mtime))
    if not starts:
        not_measured("work item %s not found in aidlc-docs" % work_item)
    since, until = min(starts), (max(ends) if ends else None)
    label = "work item %s" % work_item

if not dirs:
    not_measured("no Claude Code records for %s" % root)

sessions = []
for d in dirs:
    sessions += [f for f in glob.glob(os.path.join(d, "*.jsonl"))]
if not sessions:
    not_measured("no Claude Code records for %s" % root)
if scope == "latest":
    sessions = [max(sessions, key=os.path.getmtime)]
files = []
for s in sessions:   # each session's subagents keep their own records
    files.append(s)
    files += glob.glob(os.path.join(s[:-len(".jsonl")], "subagents", "*.jsonl"))

calls = {}
for path in files:
    try:
        handle = open(path, encoding="utf-8", errors="replace")
    except OSError:
        continue
    with handle:
        for n, line in enumerate(handle):
            if '"usage"' not in line:
                continue
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            if not isinstance(rec, dict) or rec.get("type") != "assistant":
                continue
            msg = rec.get("message")
            if not isinstance(msg, dict) or not isinstance(msg.get("usage"), dict):
                continue
            t = record_ts(rec.get("timestamp") or "")
            if (since is not None or until is not None) and t is None:
                continue
            if since is not None and t < since:
                continue
            if until is not None and t > until:
                continue
            if msg.get("model") == "<synthetic>":   # placeholders Claude Code writes, not model calls
                continue
            key = msg.get("id") or "%s:%d" % (path, n)
            calls[key] = (path, msg["usage"], msg.get("model") or "?")   # the last line of a call wins

if not calls:
    not_measured("no model calls for %s in %s" % (label, root))

def num(u, k):
    v = u.get(k) or 0
    return v if isinstance(v, int) else 0

total = {"calls": len(calls), "new_input": 0, "cache_writes": 0, "cache_reads": 0, "output": 0, "thinking": 0}
models, used_files = set(), set()
for path, u, model in calls.values():
    total["new_input"] += num(u, "input_tokens")
    total["cache_writes"] += num(u, "cache_creation_input_tokens")
    total["cache_reads"] += num(u, "cache_read_input_tokens")
    total["output"] += num(u, "output_tokens")
    details = u.get("output_tokens_details")
    if isinstance(details, dict):
        total["thinking"] += num(details, "thinking_tokens")
    models.add(model)
    used_files.add(path)
inputs = total["new_input"] + total["cache_writes"] + total["cache_reads"]
total["total"] = inputs + total["output"]
total["cached_share"] = round(100.0 * total["cache_reads"] / inputs, 1) if inputs else 0.0
total["sessions"] = len([f for f in used_files if "/subagents/" not in f])
total["models"] = sorted(models)

def short(n):
    for size, unit in ((1e9, "B"), (1e6, "M"), (1e3, "k")):
        if n >= size:
            return ("%.2f" % (n / size)).rstrip("0").rstrip(".") + unit
    return str(n)

if fmt == "json":
    total.update({"measured": True, "scope": label, "project": root})
    print(json.dumps(total))
elif fmt == "line":
    print("Tokens (Claude Code, %s): %s · %d call%s · %s%% from cache · output %s"
          % (label, short(total["total"]), total["calls"], "" if total["calls"] == 1 else "s",
             total["cached_share"], short(total["output"])))
else:
    print("Claude Code tokens · %s · %s" % (root, label))
    print("  model calls   %13s   (sessions: %d · models: %s)" % ("{:,}".format(total["calls"]), total["sessions"], ", ".join(total["models"])))
    print("  new input     %13s" % "{:,}".format(total["new_input"]))
    print("  cache writes  %13s" % "{:,}".format(total["cache_writes"]))
    print("  cache reads   %13s   (%s%% of the input came from the cache)" % ("{:,}".format(total["cache_reads"]), total["cached_share"]))
    print("  output        %13s   (thinking %s)" % ("{:,}".format(total["output"]), "{:,}".format(total["thinking"])))
    print("  total         %13s" % "{:,}".format(total["total"]))
    print("Every call reads the whole context again: a smaller context and shorter sessions save the most.")
PY
