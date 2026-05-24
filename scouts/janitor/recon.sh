#!/usr/bin/env bash
# Janitor scout recon: whole-repo opportunistic cleanup scan
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${OBSERVIBE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PLUGIN_COMMON="$PLUGIN_ROOT/scripts/common"

runtime="${OBSERVIBE_RUNTIME_DIR:-$("$PLUGIN_COMMON/runtime-dir.sh" "${OBSERVIBE_PROJECT_ROOT:-$(pwd)}")}"
project_root="${OBSERVIBE_PROJECT_ROOT:-$(pwd)}"

python3 - "$project_root" "$runtime" <<'PY'
import json, os, re, subprocess, sys, glob, time

root, runtime = sys.argv[1:3]

def run(cmd, cwd=root):
    try:
        return subprocess.check_output(cmd, shell=True, text=True, cwd=cwd, stderr=subprocess.DEVNULL).strip()
    except subprocess.CalledProcessError:
        return ""

recent_commits = run('git log --since="3 hours ago" --name-only --pretty=format:"%h %s"')
changed_files = [l.strip() for l in recent_commits.splitlines() if l.strip() and not l.startswith(" ") and len(l.split()) == 1]

# TODO inventory in changed paths
todos = []
for path in changed_files[:50]:
    full = os.path.join(root, path)
    if not os.path.isfile(full):
        continue
    try:
        for i, line in enumerate(open(full, encoding="utf-8", errors="replace"), 1):
            if re.search(r"TODO|FIXME|XXX|HACK", line):
                todos.append({"path": path, "line": i, "text": line.strip()[:200]})
    except OSError:
        pass

# Untested: new .ts files without co-located test
untested = []
for path in changed_files:
    if not path.endswith((".ts", ".tsx")) or ".test." in path or ".spec." in path:
        continue
    base, ext = os.path.splitext(path)
    candidates = [f"{base}.test.ts", f"{base}.test.tsx", f"{base}.spec.ts"]
    if not any(os.path.isfile(os.path.join(root, c)) for c in candidates):
        untested.append(path)

# Agent file staleness
now = time.time()
stale_days = 30
agent_files = []
for pattern in ["AGENTS.md", "**/AGENTS.md", ".agents/skills/**/SKILL.md"]:
    for path in glob.glob(os.path.join(root, pattern), recursive=True):
        if os.path.isfile(path):
            age_days = (now - os.path.getmtime(path)) / 86400
            if age_days > stale_days:
                agent_files.append({"path": os.path.relpath(path, root), "ageDays": round(age_days, 1)})

# Observibe self-review: scout recon error rate
scout_errors = {}
runs_file = os.path.join(runtime, "scout-runs.jsonl")
if os.path.isfile(runs_file):
    hour_ago = now - 3600
    for line in open(runs_file, encoding="utf-8", errors="replace"):
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        ts = obj.get("ts", "")
        try:
            from datetime import datetime
            t = datetime.strptime(ts, "%Y-%m-%dT%H:%M:%SZ").timestamp()
        except Exception:
            t = 0
        if t < hour_ago:
            continue
        scout = obj.get("scout", "?")
        if obj.get("exitCode", 0) != 0:
            scout_errors[scout] = scout_errors.get(scout, 0) + 1

# Dead code hint: exports never imported (simple rg)
dead_hints = []
exports = run(r'rg -l "^export (async )?function " --glob "*.ts" --glob "*.tsx" apps packages src 2>/dev/null | head -20')
for path in exports.splitlines()[:10]:
    if not path:
        continue
    name_match = re.search(r"export (?:async )?function (\w+)", open(os.path.join(root, path), encoding="utf-8", errors="replace").read())
    if not name_match:
        continue
    name = name_match.group(1)
    refs = run(f'rg -l "\\b{name}\\b" --glob "*.ts" --glob "*.tsx" . 2>/dev/null | wc -l')
    try:
        if int(refs.strip()) <= 1:
            dead_hints.append({"path": path, "export": name})
    except ValueError:
        pass

print(json.dumps({
    "recentCommits": recent_commits[:3000],
    "changedFiles": changed_files[:50],
    "todos": todos[:30],
    "untestedNewFiles": untested[:20],
    "staleAgentFiles": agent_files[:20],
    "observibeScoutErrorsLastHour": scout_errors,
    "deadCodeHints": dead_hints[:15],
}, indent=2))
PY
