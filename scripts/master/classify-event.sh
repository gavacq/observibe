#!/usr/bin/env bash
# Map one events.jsonl line → JSON array of scouts to fire
# Usage: echo '{"event":"stop",...}' | bash classify-event.sh
set -euo pipefail

line="$(cat)"
event="$(echo "$line" | jq -r '.event // empty')"
exit_code="$(echo "$line" | jq -r '.exitCode // .exit_code // 0')"
tool="$(echo "$line" | jq -r '.tool // empty')"

scouts=()

case "$event" in
  stop)
    scouts+=("chat" "instructions")
    ;;
  subagentStop)
    scouts+=("chat")
    ;;
  afterShellExecution)
    if [ "${exit_code:-0}" != "0" ] && [ "${exit_code:-0}" != "null" ]; then
      scouts+=("terminal")
    fi
    ;;
  postToolUseFailure)
    if [ "$tool" = "Shell" ] || [ -z "$tool" ]; then
      scouts+=("terminal")
    fi
    ;;
  afterFileEdit)
    scouts+=("refactor")
    ;;
  beforeSubmitPrompt)
    # log-only
    ;;
esac

printf '%s\n' "${scouts[@]}" | jq -R . | jq -s .
