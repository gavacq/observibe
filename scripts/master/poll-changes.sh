#!/usr/bin/env bash
# Heartbeat: stat events.jsonl + terminals/*.txt; emit wake sentinel on delta
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLL_SEC="${OBSERVIBE_POLL_SEC:-5}"
HEARTBEAT_SEC="${OBSERVIBE_HEARTBEAT_SEC:-600}"
HOURLY_SEC="${OBSERVIBE_HOURLY_SEC:-3600}"

project_root="${OBSERVIBE_PROJECT_ROOT:-$(pwd)}"
runtime="$("$SCRIPT_DIR/../common/runtime-dir.sh" "$project_root")"
state="$runtime/state.json"

last_events_lines=0
last_term_sig=""
last_heartbeat=0
last_hourly=0
start_ts=$(date +%s)
last_heartbeat=$start_ts
last_hourly=$start_ts

checksum_terminals() {
  local dir
  dir="$("$SCRIPT_DIR/../common/find-terminals-dir.sh" || true)"
  [ -z "$dir" ] || [ ! -d "$dir" ] && echo "none" && return
  find "$dir" -name '*.txt' 2>/dev/null | while IFS= read -r f; do
    # Exclude Observibe watcher terminal — its stdout IS the wake sentinel (feedback loop)
    if head -n 8 "$f" 2>/dev/null | grep -q 'poll-changes\.sh'; then
      continue
    fi
    stat -f '%m %z %N' "$f" 2>/dev/null || stat -c '%Y %s %n' "$f"
  done | sort | shasum | awk '{print $1}'
}

event_line_count() {
  local events_file="$1"
  [ -f "$events_file" ] || { echo 0; return; }
  wc -l <"$events_file" | tr -d ' '
}

while true; do
  now=$(date +%s)
  events_file="$runtime/events.jsonl"
  events_lines="$(event_line_count "$events_file")"
  term_sig="$(checksum_terminals)"

  trigger=""
  if [ "$events_lines" != "$last_events_lines" ]; then
    trigger="events-delta"
  elif [ "$term_sig" != "$last_term_sig" ] && [ "$term_sig" != "none" ]; then
    trigger="terminals-delta"
  elif [ $((now - last_heartbeat)) -ge "$HEARTBEAT_SEC" ]; then
    trigger="heartbeat-terminal"
    last_heartbeat=$now
  elif [ $((now - last_hourly)) -ge "$HOURLY_SEC" ]; then
    trigger="hourly"
    last_hourly=$now
  fi

  if [ -n "$trigger" ]; then
    echo "AGENT_LOOP_WAKE_OBSERVIBE $(jq -nc --arg t "$trigger" --argjson offset "$events_lines" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{prompt:"Run Observibe Master Scout tick",trigger:$t,eventOffset:$offset,ts:$ts}')"
  fi

  last_events_lines=$events_lines
  last_term_sig="$term_sig"
  sleep "$POLL_SEC"
done
