#!/usr/bin/env bash
# Deterministic Master Scout tick (recon + signal merge)
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
state="$runtime/state.json"
events="$runtime/events.jsonl"
export OBSERVIBE_PROJECT_ROOT="$project_root"

scouts=()
if $force_all; then
  scouts=(chat instructions terminal refactor janitor)
else
  case "$trigger" in
    stop|observibe-boot)
      scouts=(chat instructions)
      ;;
    hourly|heartbeat-terminal|terminals-delta)
      scouts=(terminal)
      ;;
    events-delta)
      last_line="$(jq -r '.lastEventLine // 0' "$state" 2>/dev/null || echo 0)"
      total="$(wc -l <"$events" 2>/dev/null | tr -d ' ' || echo 0)"
      if [ "$total" -gt "$last_line" ]; then
        while IFS= read -r scout_name; do
          [ -n "$scout_name" ] && scouts+=("$scout_name")
        done < <(
          tail -n +"$((last_line + 1))" "$events" | while IFS= read -r line; do
            [ -n "$line" ] || continue
            echo "$line" | bash "$SCRIPT_DIR/classify-event.sh" | jq -r '.[]?' 2>/dev/null || true
          done | sort -u
        )
      fi
      ;;
    *)
      scouts=(terminal)
      ;;
  esac
fi

# Dedupe scout list (bash 3 compatible)
if [ "${#scouts[@]}" -gt 0 ]; then
  deduped=()
  while IFS= read -r scout_name; do
    [ -n "$scout_name" ] && deduped+=("$scout_name")
  done < <(printf '%s\n' "${scouts[@]}" | sort -u)
  scouts=("${deduped[@]}")
fi

if [ "${#scouts[@]}" -gt 0 ]; then
  for scout in "${scouts[@]}"; do
    [ -z "$scout" ] && continue
    echo "Running recon: $scout"
    bash "$SCRIPT_DIR/run-scout.sh" "$scout" "$(jq -nc --arg t "$trigger" '{trigger: $t}')" || true
    bash "$SCRIPT_DIR/apply-recon-signals.sh" --scout "$scout" || true
  done
fi

if [ "$trigger" = "hourly" ] || $force_all; then
  if bash "$SCRIPT_DIR/check-janitor-gate.sh" | jq -e '.allowed == true' >/dev/null 2>&1; then
    echo "Running recon: janitor"
    bash "$SCRIPT_DIR/run-scout.sh" janitor "$(jq -nc --arg t "$trigger" '{trigger: $t}')" || true
    bash "$SCRIPT_DIR/apply-recon-signals.sh" --scout janitor || true
  fi
fi

bash "$SCRIPT_DIR/check-janitor-gate.sh" >/dev/null || true

if [ -f "$events" ]; then
  events_lines="$(wc -l <"$events" | tr -d ' ')"
  tmp="$(mktemp)"
  jq --argjson line "$events_lines" '.lastEventLine = $line' "$state" >"$tmp" && mv "$tmp" "$state"
fi

bash "$SCRIPT_DIR/write-status.sh" --trigger "$trigger"
echo "Tick complete: $runtime"
