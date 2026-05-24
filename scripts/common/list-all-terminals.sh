#!/usr/bin/env bash
# List all terminal *.txt paths for workspace, newest mtime first
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
terminals_dir="$("$SCRIPT_DIR/find-terminals-dir.sh" || true)"

if [ -z "$terminals_dir" ] || [ ! -d "$terminals_dir" ]; then
  exit 0
fi

for f in "$terminals_dir"/*.txt; do
  [ -f "$f" ] || continue
  stat -f "%m %N" "$f" 2>/dev/null || stat -c "%Y %n" "$f" 2>/dev/null
done | sort -rn | cut -d' ' -f2-
