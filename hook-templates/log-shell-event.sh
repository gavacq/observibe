#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/common/hook-runtime.sh"

input="$(read_input)"
root="$(get_project_root "$input")"
session="$(get_session_uuid "$input")"
runtime="$("$SCRIPT_DIR/../scripts/common/runtime-dir.sh" "$root")"

if should_skip_observibe "$runtime" "$session"; then exit 0; fi

command="$(echo "$input" | jq -r '.command // .shell_command // empty' 2>/dev/null || true)"
exit_code="$(echo "$input" | jq -r '.exit_code // .exitCode // 0' 2>/dev/null || echo 0)"
terminal_id="$(echo "$input" | jq -r '.terminal_id // .terminalId // empty' 2>/dev/null || true)"

append_event "$runtime" "$(jq -nc \
  --arg ts "$(timestamp_utc)" \
  --arg event "afterShellExecution" \
  --arg session "$session" \
  --arg command "$command" \
  --argjson exit_code "${exit_code:-0}" \
  --arg terminal_id "$terminal_id" \
  '{ts: $ts, event: $event, sessionUuid: $session, command: $command, exitCode: $exit_code, terminalId: $terminal_id}')"
exit 0
