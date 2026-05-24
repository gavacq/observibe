#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/common/hook-runtime.sh"

input="$(read_input)"
root="$(get_project_root "$input")"
session="$(get_session_uuid "$input")"
runtime="$("$SCRIPT_DIR/../scripts/common/runtime-dir.sh" "$root")"

if should_skip_observibe "$runtime" "$session"; then exit 0; fi

tool="$(echo "$input" | jq -r '.tool_name // .tool // empty' 2>/dev/null || true)"
error="$(echo "$input" | jq -r '.error // .error_message // empty' 2>/dev/null || true)"
command="$(echo "$input" | jq -r '.input.command // .tool_input.command // empty' 2>/dev/null || true)"

append_event "$runtime" "$(jq -nc \
  --arg ts "$(timestamp_utc)" \
  --arg event "postToolUseFailure" \
  --arg session "$session" \
  --arg tool "$tool" \
  --arg error "$error" \
  --arg command "$command" \
  '{ts: $ts, event: $event, sessionUuid: $session, tool: $tool, error: $error, command: $command}')"
exit 0
