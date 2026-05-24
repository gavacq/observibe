#!/usr/bin/env bash
# Chat scout recon: sibling session transcripts + efficiency metrics
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${OBSERVIBE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PLUGIN_COMMON="$PLUGIN_ROOT/scripts/common"

runtime="${OBSERVIBE_RUNTIME_DIR:-}"
project_root="${OBSERVIBE_PROJECT_ROOT:-$(pwd)}"
event_context="${OBSERVIBE_EVENT_CONTEXT:-{}}"

if [ -z "$runtime" ]; then
  runtime="$("$PLUGIN_COMMON/runtime-dir.sh" "$project_root")"
fi

observibe_uuid="$(jq -r '.observibeSessionUuid // empty' "$runtime/state.json" 2>/dev/null || true)"
transcripts_dir="$("$PLUGIN_COMMON/find-transcripts-dir.sh")"

if [ -z "$transcripts_dir" ] || [ ! -d "$transcripts_dir" ]; then
  jq -nc '{error:"no transcripts dir", sessions:[], metrics:{}}'
  exit 0
fi

python3 - "$transcripts_dir" "$observibe_uuid" "$event_context" <<'PY'
import json, os, sys, glob, re
from collections import Counter

transcripts_dir, observibe_uuid, event_ctx_raw = sys.argv[1:4]
try:
    event_ctx = json.loads(event_ctx_raw) if event_ctx_raw else {}
except json.JSONDecodeError:
    event_ctx = {}

sessions = []
for parent in sorted(glob.glob(os.path.join(transcripts_dir, "*", "*.jsonl"))):
    session_id = os.path.basename(os.path.dirname(parent))
    if observibe_uuid and session_id == observibe_uuid:
        continue
    mtime = os.path.getmtime(parent)
    timeline = []
    tool_calls = []
    user_msgs = 0
    read_paths = Counter()
    shell_cmds = Counter()
    try:
        with open(parent, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                role = obj.get("role", "")
                content = obj.get("message", {}).get("content", [])
                if role == "user":
                    user_msgs += 1
                    for block in content:
                        if block.get("type") == "text":
                            text = block.get("text", "")[:500]
                            timeline.append({"role": "user", "type": "text", "text": text})
                elif role == "assistant":
                    for block in content:
                        btype = block.get("type", "")
                        if btype == "text":
                            timeline.append({"role": "assistant", "type": "text", "text": block.get("text", "")[:500]})
                        elif btype == "tool_use":
                            name = block.get("name", "")
                            inp = block.get("input", {})
                            summary = name
                            if name in ("Read", "Grep", "Glob"):
                                path = inp.get("path") or inp.get("pattern", "")
                                summary = f"{name}:{path}"[:120]
                                if name == "Read" and path:
                                    read_paths[path] += 1
                            elif name == "Shell":
                                cmd = inp.get("command", "")[:120]
                                summary = f"Shell:{cmd}"
                                shell_cmds[cmd] += 1
                            tool_calls.append(summary)
                            timeline.append({"role": "assistant", "type": "tool_use", "summary": summary})
    except OSError:
        continue
    if not timeline:
        continue
    sessions.append({
        "sessionId": session_id,
        "mtime": mtime,
        "timeline": timeline[-80:],
        "metrics": {
            "userMessageCount": user_msgs,
            "toolCallCount": len(tool_calls),
            "repeatedCommandCount": sum(1 for c, n in shell_cmds.items() if n > 1),
            "sameFileReadCount": sum(1 for p, n in read_paths.items() if n > 2),
            "topRepeatedReads": [{"path": p, "count": n} for p, n in read_paths.most_common(5) if n > 2],
            "topRepeatedCommands": [{"command": c, "count": n} for c, n in shell_cmds.most_common(5) if n > 1],
        }
    })

sessions.sort(key=lambda s: s["mtime"], reverse=True)
sessions = sessions[:3]
for s in sessions:
    del s["mtime"]

print(json.dumps({"sessions": sessions, "eventContext": event_ctx}, indent=2))
PY
