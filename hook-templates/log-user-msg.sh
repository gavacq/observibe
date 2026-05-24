#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/common/hook-runtime.sh"

input="$(read_input)"
root="$(get_project_root "$input")"
session="$(get_session_uuid "$input")"
runtime="$("$SCRIPT_DIR/../scripts/common/runtime-dir.sh" "$root")"

if should_skip_observibe "$runtime" "$session"; then exit 0; fi

message="$(echo "$input" | jq -r '.prompt // .message // .text // empty' 2>/dev/null || true)"
# Truncate to 2000 chars
message="${message:0:2000}"

append_event "$runtime" "$(jq -nc \
  --arg ts "$(timestamp_utc)" \
  --arg event "beforeSubmitPrompt" \
  --arg session "$session" \
  --arg message "$message" \
  '{ts: $ts, event: $event, sessionUuid: $session, message: $message}')"
exit 0
