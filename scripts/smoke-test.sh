#!/usr/bin/env bash
# Smoke test Observibe scripts (no LLM)
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="${OBSERVIBE_PROJECT_ROOT:-${1:-$(pwd)}}"
export OBSERVIBE_PROJECT_ROOT="$PROJECT_ROOT"

cd "$PLUGIN_ROOT"
find . -name '*.sh' -exec chmod +x {} \;

echo "== runtime bootstrap =="
runtime="$(bash scripts/common/runtime-dir.sh "$PROJECT_ROOT")"
echo "runtime: $runtime"

echo "== fake hook events =="
events="$runtime/events.jsonl"
now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "{\"ts\":\"$now\",\"event\":\"stop\",\"sessionUuid\":\"test-session\"}" >>"$events"
echo "{\"ts\":\"$now\",\"event\":\"beforeSubmitPrompt\",\"message\":\"don't use yarn, use pnpm\"}" >>"$events"
echo "{\"ts\":\"$now\",\"event\":\"afterShellExecution\",\"exitCode\":1,\"command\":\"false\",\"terminalId\":\"999\"}" >>"$events"

echo "== classify stop =="
stop_line="$(tail -n3 "$events" | head -n1)"
echo "$stop_line" | bash scripts/master/classify-event.sh

echo "== run all recons =="
for scout in chat instructions terminal refactor janitor; do
  echo "--- $scout ---"
  bash scripts/master/run-scout.sh "$scout" '{}' || true
done

echo "== janitor gate =="
bash scripts/master/check-janitor-gate.sh

echo "== write STATUS =="
bash scripts/master/write-status.sh --trigger smoke-test

echo "== validate patch safety =="
echo 'grep -E error' > /tmp/safe-patch.sh
bash scripts/safety/validate-script-patch.sh --scout terminal --patch /tmp/safe-patch.sh

echo ""
echo "OK — verify:"
echo "  $runtime/BACKLOG.md"
echo "  $runtime/STATUS.md"
echo "  $runtime/scout-runs.jsonl"
ls -la "$runtime/scouts/"*/last-recon.json 2>/dev/null || true
