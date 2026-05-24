#!/usr/bin/env bash
# Refactor scout recon: git diff + duplication hints
set -euo pipefail

project_root="${OBSERVIBE_PROJECT_ROOT:-$(pwd)}"
cd "$project_root"

python3 - "$project_root" <<'PY'
import json, os, re, subprocess, sys

root = sys.argv[1]
os.chdir(root)

def run(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.DEVNULL).strip()
    except subprocess.CalledProcessError:
        return ""

stat = run("git diff --stat HEAD 2>/dev/null") or run("git diff --stat")
names = run("git diff --name-only HEAD 2>/dev/null") or run("git diff --name-only")
status = run("git status --porcelain")

touched = [l.strip() for l in names.splitlines() if l.strip()]
duplication_hints = []

# Simple: same function name exported/defined in 2+ new files
func_names = {}
for path in touched:
    if not path.endswith((".ts", ".tsx", ".js", ".jsx")):
        continue
    full = os.path.join(root, path)
    if not os.path.isfile(full):
        continue
    try:
        text = open(full, encoding="utf-8", errors="replace").read()
    except OSError:
        continue
    for m in re.finditer(r"(?:export\s+)?(?:async\s+)?function\s+(\w+)", text):
        func_names.setdefault(m.group(1), []).append(path)
    for m in re.finditer(r"(?:export\s+const\s+)(\w+)\s*=", text):
        func_names.setdefault(m.group(1), []).append(path)

for name, paths in func_names.items():
    if len(set(paths)) >= 2:
        duplication_hints.append({"type": "same_function_name", "name": name, "paths": list(set(paths))})

print(json.dumps({
    "diffStat": stat[:4000],
    "touchedPaths": touched[:100],
    "statusPorcelain": status[:2000],
    "duplicationHints": duplication_hints[:20],
}, indent=2))
PY
