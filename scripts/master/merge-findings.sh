#!/usr/bin/env bash
# Append scout findings to BACKLOG.md with dedup (same scout + title in last 24h → skip)
# Usage: bash merge-findings.sh --scout chat --section "Session efficiency" --items-file /tmp/items.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
scout=""
section=""
items_file=""
tick_ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

while [ $# -gt 0 ]; do
  case "$1" in
    --scout) scout="$2"; shift 2 ;;
    --section) section="$2"; shift 2 ;;
    --items-file) items_file="$2"; shift 2 ;;
    --tick-ts) tick_ts="$2"; shift 2 ;;
    *) shift ;;
  esac
done

project_root="${OBSERVIBE_PROJECT_ROOT:-$(pwd)}"
runtime="$("$SCRIPT_DIR/../common/runtime-dir.sh" "$project_root")"
backlog="$runtime/BACKLOG.md"

[ -f "$items_file" ] || exit 0
[ -s "$items_file" ] || exit 0

# Dedup: skip lines already in backlog (fuzzy: first 80 chars of item text)
new_items=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  key="$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*\[[ x]\][[:space:]]*//' | cut -c1-80)"
  if grep -qF "$key" "$backlog" 2>/dev/null; then
    continue
  fi
  new_items+="$line"$'\n'
done <"$items_file"

[ -n "$new_items" ] || exit 0

{
  echo ""
  echo "## $tick_ts tick ($scout)"
  echo ""
  echo "### $section"
  echo "$new_items"
} >>"$backlog"

echo "appended"
