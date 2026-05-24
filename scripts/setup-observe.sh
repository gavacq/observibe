#!/usr/bin/env bash
# One-shot Observibe project setup: hooks + runtime bootstrap + verify
# Usage: bash scripts/setup-observe.sh [/path/to/project]
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$(cd "${1:-$(pwd)}" && pwd)"

missing=()
for cmd in jq python3; do
  command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "ERROR: missing required tools: ${missing[*]}" >&2
  exit 1
fi

echo "== Observibe setup =="
echo "project: $PROJECT"
echo "plugin:  $PLUGIN_ROOT"
echo ""

echo "== install hook scripts =="
bash "$PLUGIN_ROOT/scripts/install-hooks.sh" "$PROJECT"

echo ""
echo "== merge hooks.json =="
bash "$PLUGIN_ROOT/scripts/merge-hooks-json.sh" "$PROJECT"

echo ""
echo "== bootstrap runtime =="
export OBSERVIBE_PROJECT_ROOT="$PROJECT"
runtime="$(bash "$PLUGIN_ROOT/scripts/common/runtime-dir.sh" "$PROJECT")"
echo "runtime: $runtime"

echo ""
echo "== verify hook append =="
before_lines=0
[ -f "$runtime/events.jsonl" ] && before_lines="$(wc -l <"$runtime/events.jsonl" | tr -d ' ')"
now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
printf '%s\n' "{\"workspace_roots\":[\"$PROJECT\"],\"conversation_id\":\"observibe-setup-verify\",\"duration_ms\":0}" \
  | bash "$PROJECT/.cursor/hooks/log-stop-event.sh"
after_lines="$(wc -l <"$runtime/events.jsonl" | tr -d ' ')"
if [ "$after_lines" -le "$before_lines" ]; then
  echo "ERROR: hook verify failed — events.jsonl did not grow" >&2
  exit 1
fi
echo "hook verify OK ($before_lines -> $after_lines lines in events.jsonl)"

echo ""
echo "OK — Observibe is ready for this project."
echo ""
echo "Next steps:"
echo "  1. Open a dedicated second chat in this workspace"
echo "  2. Run /observibe there (not in your feature-coding chat)"
echo "  3. Vibe-code in your primary chat; scouts propose to:"
echo "     $runtime/BACKLOG.md"
echo ""
echo "Optional: bash $PLUGIN_ROOT/scripts/smoke-test.sh \"$PROJECT\""
