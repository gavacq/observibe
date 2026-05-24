#!/usr/bin/env bash
# Shared hook helper: resolve runtime dir + skip Observibe self-session
set -euo pipefail

HOOK_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HOOK_COMMON_DIR/../.." && pwd)"

read_input() {
  cat
}

get_project_root() {
  local input="$1"
  local root
  root="$(echo "$input" | jq -r '.workspace_roots[0] // .cwd // .project_path // empty' 2>/dev/null || true)"
  if [ -z "$root" ] || [ "$root" = "null" ]; then
    root="$(pwd)"
  fi
  echo "$root"
}

get_session_uuid() {
  local input="$1"
  echo "$input" | jq -r '.conversation_id // .session_id // .transcript_id // empty' 2>/dev/null || true
}

should_skip_observibe() {
  local runtime_dir="$1"
  local session_uuid="$2"
  [ -z "$session_uuid" ] && return 1
  [ ! -f "$runtime_dir/state.json" ] && return 1
  local observibe_uuid
  observibe_uuid="$(jq -r '.observibeSessionUuid // empty' "$runtime_dir/state.json" 2>/dev/null || true)"
  [ -n "$observibe_uuid" ] && [ "$observibe_uuid" = "$session_uuid" ]
}

append_event() {
  local runtime_dir="$1"
  local line="$2"
  mkdir -p "$runtime_dir"
  touch "$runtime_dir/events.jsonl"
  echo "$line" >>"$runtime_dir/events.jsonl"
}

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}
