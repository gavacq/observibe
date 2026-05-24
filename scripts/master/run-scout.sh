#!/usr/bin/env bash
# Run one scout recon.sh; write JSON output to stdout + sidecar files
# Usage: bash run-scout.sh chat [event_context_json]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
scout="${1:?scout name required}"
event_context="${2:-{}}"

project_root="${OBSERVIBE_PROJECT_ROOT:-$(pwd)}"
runtime="$("$SCRIPT_DIR/../common/runtime-dir.sh" "$project_root")"
recon="$runtime/scouts/$scout/recon.sh"

if [ ! -x "$recon" ]; then
  echo "{\"scout\":\"$scout\",\"error\":\"recon.sh not found\",\"exitCode\":127}" >&2
  exit 127
fi

export OBSERVIBE_RUNTIME_DIR="$runtime"
export OBSERVIBE_EVENT_CONTEXT="$event_context"
export OBSERVIBE_PROJECT_ROOT="$project_root"
export OBSERVIBE_PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

start_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
stderr_file="$(mktemp)"
stdout_file="$(mktemp)"

set +e
OBSERVIBE_RUNTIME_DIR="$runtime" OBSERVIBE_EVENT_CONTEXT="$event_context" OBSERVIBE_PROJECT_ROOT="$project_root" OBSERVIBE_PLUGIN_ROOT="$OBSERVIBE_PLUGIN_ROOT" \
  "$recon" >"$stdout_file" 2>"$stderr_file"
exit_code=$?
set -e
end_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
duration=$((end_ms - start_ms))

stderr_content="$(cat "$stderr_file")"
stdout_content="$(cat "$stdout_file")"
input_chars=${#stdout_content}
output_chars=${#stderr_content}

result_file="$runtime/scouts/$scout/last-recon.json"
stderr_out="$runtime/scouts/$scout/last-recon.stderr"

cp "$stdout_file" "$result_file" 2>/dev/null || true
echo "$stderr_content" >"$stderr_out"

if jq empty "$stdout_file" 2>/dev/null; then
  jq -n \
    --arg scout "$scout" \
    --argjson exit_code "$exit_code" \
    --argjson duration_ms "$duration" \
    --argjson input_chars "$input_chars" \
    --arg stderr "$stderr_content" \
    --slurpfile recon "$stdout_file" \
    '{scout: $scout, exitCode: $exit_code, durationMs: $duration_ms, inputChars: $input_chars, stderr: $stderr, recon: ($recon[0] // null)}'
else
  jq -nc \
    --arg scout "$scout" \
    --argjson exit_code "$exit_code" \
    --argjson duration_ms "$duration" \
    --argjson input_chars "$input_chars" \
    --arg stderr "$stderr_content" \
    '{scout: $scout, exitCode: $exit_code, durationMs: $duration_ms, inputChars: $input_chars, stderr: $stderr, recon: null}'
fi

rm -f "$stderr_file" "$stdout_file"
exit "$exit_code"
