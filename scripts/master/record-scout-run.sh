#!/usr/bin/env bash
# Record scout run telemetry to scout-runs.jsonl and update state.json scoutStats
# Usage: bash record-scout-run.sh --scout chat --trigger stop --duration-ms 4200 --input-chars 8000 --output-chars 1200 --exit-code 0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
scout="" trigger="" duration_ms=0 input_chars=0 output_chars=0 exit_code=0 error=""

while [ $# -gt 0 ]; do
  case "$1" in
    --scout) scout="$2"; shift 2 ;;
    --trigger) trigger="$2"; shift 2 ;;
    --duration-ms) duration_ms="$2"; shift 2 ;;
    --input-chars) input_chars="$2"; shift 2 ;;
    --output-chars) output_chars="$2"; shift 2 ;;
    --exit-code) exit_code="$2"; shift 2 ;;
    --error) error="$2"; shift 2 ;;
    *) shift ;;
  esac
done

project_root="${OBSERVIBE_PROJECT_ROOT:-$(pwd)}"
runtime="$("$SCRIPT_DIR/../common/runtime-dir.sh" "$project_root")"
state="$runtime/state.json"
runs="$runtime/scout-runs.jsonl"
ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
approx_tokens=$(( (input_chars + output_chars) / 4 ))

line="$(jq -nc \
  --arg ts "$ts" \
  --arg scout "$scout" \
  --arg trigger "$trigger" \
  --argjson duration_ms "$duration_ms" \
  --argjson input_chars "$input_chars" \
  --argjson output_chars "$output_chars" \
  --argjson approx_tokens "$approx_tokens" \
  --argjson exit_code "$exit_code" \
  --arg error "$error" \
  '{ts: $ts, scout: $scout, trigger: $trigger, durationMs: $duration_ms, inputChars: $input_chars, outputChars: $output_chars, approxTokens: $approx_tokens, exitCode: $exit_code, error: (if $error == "" then null else $error end)}')"

echo "$line" >>"$runs"

# Rotate if > 5MB
if [ -f "$runs" ]; then
  size=$(stat -f '%z' "$runs" 2>/dev/null || stat -c '%s' "$runs")
  if [ "$size" -gt 5242880 ]; then
    tail -n 5000 "$runs" >"$runs.tmp" && mv "$runs.tmp" "$runs"
  fi
fi

tmp="$(mktemp)"
jq \
  --arg scout "$scout" \
  --arg ts "$ts" \
  --argjson duration_ms "$duration_ms" \
  --argjson input_chars "$input_chars" \
  --argjson output_chars "$output_chars" \
  --argjson approx_tokens "$approx_tokens" \
  --argjson exit_code "$exit_code" \
  --arg error "$error" \
  '
  .lastScoutRun[$scout] = $ts
  | .scoutStats[$scout] = (
      (.scoutStats[$scout] // {runs:0,totalWallMs:0,totalInputChars:0,totalOutputChars:0,approxTokens:0,errors:0})
      | .runs += 1
      | .lastRunAt = $ts
      | .lastDurationMs = $duration_ms
      | .totalWallMs += $duration_ms
      | .totalInputChars += $input_chars
      | .totalOutputChars += $output_chars
      | .approxTokens += $approx_tokens
      | .errors += (if $exit_code != 0 then 1 else 0 end)
      | .lastError = (if $exit_code != 0 then $error else .lastError end)
    )
  ' "$state" >"$tmp" && mv "$tmp" "$state"

echo "$line"
