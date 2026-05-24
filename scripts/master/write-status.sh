#!/usr/bin/env bash
# Overwrite STATUS.md from state.json + scout-runs.jsonl
# Usage: bash write-status.sh --trigger "post-scout chat"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
trigger="unknown"
while [ $# -gt 0 ]; do
  case "$1" in
    --trigger) trigger="$2"; shift 2 ;;
    *) shift ;;
  esac
done

project_root="${OBSERVIBE_PROJECT_ROOT:-$(pwd)}"
runtime="$("$SCRIPT_DIR/../common/runtime-dir.sh" "$project_root")"
state="$runtime/state.json"
runs="$runtime/scout-runs.jsonl"
status="$runtime/STATUS.md"
now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

session_start="$(jq -r '.sessionStartedAt // empty' "$state")"
janitor_eval="$(bash "$SCRIPT_DIR/check-janitor-gate.sh" 2>/dev/null || echo '{"allowed":false,"reason":"eval failed"}')"
janitor_reason="$(echo "$janitor_eval" | jq -r '.reason')"

# Build scout table rows
scout_rows=""
for scout in chat instructions terminal refactor janitor; do
  stats="$(jq -r --arg s "$scout" '.scoutStats[$s] // empty' "$state")"
  if [ -z "$stats" ] || [ "$stats" = "null" ]; then
    scout_rows+="| $scout | 0 | — | — | — | ~0 | 0 |"$'\n'
    continue
  fi
  runs_count=$(echo "$stats" | jq -r '.runs')
  last_run=$(echo "$stats" | jq -r '.lastRunAt // "—"')
  total_wall=$(echo "$stats" | jq -r '.totalWallMs')
  avg_dur="—"
  if [ "$runs_count" -gt 0 ]; then
    avg_dur="$(echo "scale=1; $total_wall / $runs_count / 1000" | bc 2>/dev/null || echo "—")s"
  fi
  total_wall_s="$(echo "scale=1; $total_wall / 1000" | bc 2>/dev/null || echo "—")s"
  tokens=$(echo "$stats" | jq -r '.approxTokens')
  token_k="~$(( tokens / 1000 ))k"
  errors=$(echo "$stats" | jq -r '.errors')
  scout_rows+="| $scout | $runs_count | $last_run | $avg_dur | $total_wall_s | $token_k | $errors |"$'\n'
done

recent=""
if [ -f "$runs" ]; then
  recent="$(tail -n 50 "$runs" | jq -s -r '
    [.[] | select(.ts != null and .scout != null)]
    | .[-10:]
    | reverse
    | .[]
    | "| "
      + (.ts | sub(".*T"; "") | sub("Z$"; ""))
      + " | "
      + .scout
      + " | "
      + (.trigger // "—")
      + " | "
      + ((.durationMs / 1000 * 10 | floor) / 10 | tostring)
      + "s | ~"
      + (.approxTokens | tostring)
      + " |"
  ' 2>/dev/null || true)"
fi

cooldown_skips=$(jq -r '.cooldownSkipsMs // 0' "$state")
cooldown_skips_s="$(echo "scale=0; $cooldown_skips / 1000" | bc 2>/dev/null || echo 0)s"

cat >"$status" <<EOF
# Observibe — STATUS

_Updated $now (trigger: $trigger)_

## Uptime
- Observibe session started: $session_start
- Heartbeat: ${OBSERVIBE_POLL_SEC:-5}s stat / ${OBSERVIBE_HEARTBEAT_SEC:-600}s full-scan / ${OBSERVIBE_HOURLY_SEC:-3600}s self-tick
- Last wake reason: $trigger

## Scouts (this session)

| Scout | Runs | Last run | Avg dur | Total wall | Approx tokens | Errors |
|-------|------|----------|---------|------------|---------------|--------|
$scout_rows

## Recent activity (last 10 runs)
| ts | scout | trigger | dur | tokens |
|----|-------|---------|-----|--------|
${recent:-| — | — | — | — | — |}

## Wait time
- Time spent in cooldown skips (this session): ${cooldown_skips_s}
- Last janitor idle gate eval: $now → $janitor_reason

## Errors (last 5)
$(tail -n 100 "$runs" 2>/dev/null | jq -s -r '[.[] | select(.exitCode != null and .exitCode != 0)] | .[-5:] | .[] | "- \(.ts) `\(.scout)/recon.sh` — exit \(.exitCode), \(.error // "see stderr")"' 2>/dev/null || true)

## Pending self-heal approvals
See BACKLOG.md § Pending script approvals

_Token counts are approximate (~4 chars/token)._
EOF

jq --arg now "$now" --arg trigger "$trigger" --arg reason "$janitor_reason" \
  '.lastReportAt = $now | .lastJanitorGateEval = $now | .lastJanitorGateResult = $reason' \
  "$state" >"$state.tmp" && mv "$state.tmp" "$state"

echo "$status"
