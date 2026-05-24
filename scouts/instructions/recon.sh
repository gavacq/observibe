#!/usr/bin/env bash
# Instructions scout recon: user corrections + friction from events + recent transcript
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${OBSERVIBE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PLUGIN_COMMON="$PLUGIN_ROOT/scripts/common"

runtime="${OBSERVIBE_RUNTIME_DIR:-$("$PLUGIN_COMMON/runtime-dir.sh" "${OBSERVIBE_PROJECT_ROOT:-$(pwd)}")}"
events="$runtime/events.jsonl"
project_root="${OBSERVIBE_PROJECT_ROOT:-$(pwd)}"

python3 - "$events" "$project_root" <<'PY'
import json, os, re, sys, glob

events_file, project_root = sys.argv[1:3]
correction_patterns = [
    re.compile(r"\bdon'?t\b", re.I),
    re.compile(r"\buse .+ not\b", re.I),
    re.compile(r"\bstop\b", re.I),
    re.compile(r"\bwrong\b", re.I),
    re.compile(r"\bagents\.md\b", re.I),
    re.compile(r"\bread .+ first\b", re.I),
    re.compile(r"\binstead\b", re.I),
]

user_messages = []
if os.path.isfile(events_file):
    with open(events_file, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if obj.get("event") == "beforeSubmitPrompt":
                msg = obj.get("message", "")
                if msg:
                    user_messages.append({"ts": obj.get("ts"), "message": msg[:2000]})

corrections = []
for um in user_messages[-20:]:
    msg = um["message"]
    if any(p.search(msg) for p in correction_patterns):
        corrections.append(um)

agent_files = []
for pattern in ["AGENTS.md", "**/AGENTS.md", ".agents/skills/**/SKILL.md", ".cursor/rules/*.mdc"]:
    for path in glob.glob(os.path.join(project_root, pattern), recursive=True):
        if os.path.isfile(path):
            rel = os.path.relpath(path, project_root)
            mtime = os.path.getmtime(path)
            agent_files.append({"path": rel, "mtimeEpoch": int(mtime)})

print(json.dumps({
    "recentUserMessages": user_messages[-10:],
    "corrections": corrections,
    "agentFiles": sorted(agent_files, key=lambda x: x["path"])[:50],
}, indent=2))
PY
