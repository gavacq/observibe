#!/usr/bin/env bash
# Evaluate janitor idle gate; prints JSON {allowed, reason}
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="${OBSERVIBE_PROJECT_ROOT:-$(pwd)}"
runtime="$("$SCRIPT_DIR/../common/runtime-dir.sh" "$project_root")"
state="$runtime/state.json"
events="$runtime/events.jsonl"

idle_sec="${OBSERVIBE_JANITOR_IDLE_SEC:-300}"
cooldown_sec="${OBSERVIBE_JANITOR_COOLDOWN_SEC:-1800}"
now_epoch=$(date +%s)

# Check janitor cooldown
last_janitor="$(jq -r '.lastScoutRun.janitor // empty' "$state")"
if [ -n "$last_janitor" ]; then
  last_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_janitor" +%s 2>/dev/null || date -d "$last_janitor" +%s 2>/dev/null || echo 0)
  if [ $((now_epoch - last_epoch)) -lt "$cooldown_sec" ]; then
    jq -nc --arg reason "janitor cooldown (${cooldown_sec}s)" '{allowed:false, reason:$reason}'
    exit 0
  fi
fi

# Check recent afterFileEdit in events.jsonl
if [ -f "$events" ]; then
  recent_edit=$(tail -n 200 "$events" | jq -r 'select(.event=="afterFileEdit") | .ts' 2>/dev/null | tail -n1)
  if [ -n "$recent_edit" ]; then
    edit_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$recent_edit" +%s 2>/dev/null || date -d "$recent_edit" +%s 2>/dev/null || echo 0)
    if [ $((now_epoch - edit_epoch)) -lt "$idle_sec" ]; then
      secs=$((now_epoch - edit_epoch))
      jq -nc --arg reason "git edit ${secs}s ago (need ${idle_sec}s quiet)" '{allowed:false, reason:$reason}'
      exit 0
    fi
  fi
fi

# Check scout currently running (flag in state)
running="$(jq -r '.scoutRunning // false' "$state")"
if [ "$running" = "true" ]; then
  jq -nc --arg reason "another scout running" '{allowed:false, reason:$reason}'
  exit 0
fi

jq -nc --arg reason "idle gate met" '{allowed:true, reason:$reason}'
