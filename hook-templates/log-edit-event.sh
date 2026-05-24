#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/common/hook-runtime.sh"

input="$(read_input)"
root="$(get_project_root "$input")"
session="$(get_session_uuid "$input")"
runtime="$("$SCRIPT_DIR/../scripts/common/runtime-dir.sh" "$root")"

if should_skip_observibe "$runtime" "$session"; then exit 0; fi

paths="$(echo "$input" | jq -c '[.paths[]?, .file_path?, .edited_file?] | map(select(. != null and . != "")) | unique' 2>/dev/null || echo '[]')"

append_event "$runtime" "$(jq -nc \
  --arg ts "$(timestamp_utc)" \
  --arg event "afterFileEdit" \
  --arg session "$session" \
  --argjson paths "$paths" \
  '{ts: $ts, event: $event, sessionUuid: $session, paths: $paths}')"
exit 0
