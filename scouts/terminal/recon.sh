#!/usr/bin/env bash
# Terminal scout recon: ALL Cursor terminals for workspace
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${OBSERVIBE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PLUGIN_COMMON="$PLUGIN_ROOT/scripts/common"

runtime="${OBSERVIBE_RUNTIME_DIR:-$("$PLUGIN_COMMON/runtime-dir.sh" "${OBSERVIBE_PROJECT_ROOT:-$(pwd)}")}"
TAIL_LINES="${OBSERVIBE_TERMINAL_TAIL_LINES:-80}"
event_context="${OBSERVIBE_EVENT_CONTEXT:-{}}"

terminals_dir="$("$PLUGIN_COMMON/find-terminals-dir.sh" || true)"

if [ -z "$terminals_dir" ] || [ ! -d "$terminals_dir" ]; then
  jq -nc '{terminals:[], summary:{total_terminals:0,agent_managed_count:0,user_count:0,terminals_with_matches:0}}'
  exit 0
fi

python3 - "$terminals_dir" "$TAIL_LINES" "$event_context" <<'PY'
import json, os, re, sys, glob

terminals_dir, tail_lines, event_ctx_raw = sys.argv[1:4]
tail_lines = int(tail_lines)
try:
    event_ctx = json.loads(event_ctx_raw) if event_ctx_raw else {}
except json.JSONDecodeError:
    event_ctx = {}

error_patterns = [
    re.compile(r"error", re.I),
    re.compile(r"failed", re.I),
    re.compile(r"WARN", re.I),
    re.compile(r"SIGSEGV", re.I),
    re.compile(r"SyntaxError", re.I),
    re.compile(r"401|403|500", re.I),
]

def parse_frontmatter(text):
    meta = {}
    if not text.startswith("---"):
        return meta, text
    parts = text.split("---", 2)
    if len(parts) < 3:
        return meta, text
    fm, body = parts[1], parts[2]
    for line in fm.strip().splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            meta[k.strip()] = v.strip().strip('"')
    return meta, body

terminals = []
agent_managed = user = with_matches = 0

files = glob.glob(os.path.join(terminals_dir, "*.txt"))
files.sort(key=lambda p: os.path.getmtime(p), reverse=True)

for path in files:
    tid = os.path.splitext(os.path.basename(path))[0]
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            raw = f.read()
    except OSError:
        continue
    meta, body = parse_frontmatter(raw)
    command = meta.get("command", "")
    if "poll-changes.sh" in command or "observer-watch" in command:
        continue
    kind = "agent-managed" if command else "user"
    if kind == "agent-managed":
        agent_managed += 1
    else:
        user += 1
    lines = body.strip().splitlines()
    tail = lines[-tail_lines:]
    matched = []
    for i, line in enumerate(lines):
        for pat in error_patterns:
            if pat.search(line):
                matched.append({"pattern": pat.pattern, "line": line[:300], "line_no": i + 1})
                break
    if matched:
        with_matches += 1
    terminals.append({
        "id": tid,
        "path": path,
        "kind": kind,
        "pid": meta.get("pid"),
        "cwd": meta.get("cwd"),
        "command": command[:200] if command else None,
        "started_at": meta.get("started_at"),
        "running_for_ms": meta.get("running_for_ms"),
        "tail_lines": tail[-20:],
        "matched_lines": matched[:20],
    })

print(json.dumps({
    "terminals": terminals,
    "eventContext": event_ctx,
    "summary": {
        "total_terminals": len(terminals),
        "agent_managed_count": agent_managed,
        "user_count": user,
        "terminals_with_matches": with_matches,
    }
}, indent=2))
PY
