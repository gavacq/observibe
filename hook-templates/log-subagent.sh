#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/common/hook-runtime.sh"

input="$(read_input)"
root="$(get_project_root "$input")"
session="$(get_session_uuid "$input")"
runtime="$("$SCRIPT_DIR/../scripts/common/runtime-dir.sh" "$root")"

if should_skip_observibe "$runtime" "$session"; then exit 0; fi

subagent_type="$(echo "$input" | jq -r '.subagent_type // .agent_type // empty' 2>/dev/null || true)"
duration="$(echo "$input" | jq -r '.duration_ms // empty' 2>/dev/null || true)"

append_event "$runtime" "$(jq -nc \
  --arg ts "$(timestamp_utc)" \
  --arg event "subagentStop" \
  --arg session "$session" \
  --arg subagent "$subagent_type" \
  --arg duration "${duration:-}" \
  '{ts: $ts, event: $event, sessionUuid: $session, subagentType: $subagent, durationMs: ($duration | if . == "" then null else (.|tonumber?) end)}')"
exit 0
