#!/usr/bin/env bash
# Deterministic Master Scout tick (recon only, no LLM scouts)
# Usage: bash process-tick.sh --trigger stop [--force-all]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
trigger="manual"
force_all=false

while [ $# -gt 0 ]; do
  case "$1" in
    --trigger) trigger="$2"; shift 2 ;;
    --force-all) force_all=true; shift ;;
    *) shift ;;
  esac
done

project_root="${OBSERVIBE_PROJECT_ROOT:-$(pwd)}"
runtime="$("$SCRIPT_DIR/../common/runtime-dir.sh" "$project_root")"
export OBSERVIBE_PROJECT_ROOT="$project_root"

scouts=()
if $force_all; then
  scouts=(chat instructions terminal refactor janitor)
else
  case "$trigger" in
    stop) scouts=(chat instructions) ;;
    hourly|heartbeat-terminal|terminals-delta) scouts=(terminal) ;;
    events-delta)
      last="$(tail -n1 "$runtime/events.jsonl" 2>/dev/null || true)"
      if [ -n "$last" ]; then
        while IFS= read -r s; do
          [ -n "$s" ] && scouts+=("$s")
        done < <(echo "$last" | bash "$SCRIPT_DIR/classify-event.sh" | jq -r '.[]')
      fi
      ;;
    *) scouts=(terminal) ;;
  esac
fi

for scout in "${scouts[@]}"; do
  [ -z "$scout" ] && continue
  echo "Running recon: $scout"
  bash "$SCRIPT_DIR/run-scout.sh" "$scout" "{\"trigger\":\"$trigger\"}" || true
done

bash "$SCRIPT_DIR/check-janitor-gate.sh"
bash "$SCRIPT_DIR/write-status.sh" --trigger "$trigger"
echo "Tick complete: $runtime"
