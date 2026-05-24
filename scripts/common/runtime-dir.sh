#!/usr/bin/env bash
# Resolve and bootstrap ~/.cursor/observibe/<workspace-slug>/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

project_root="${OBSERVIBE_PROJECT_ROOT:-${1:-$(pwd)}}"
slug="$("$SCRIPT_DIR/project-slug.sh" "$project_root")"
runtime_dir="${OBSERVIBE_RUNTIME_DIR:-$HOME/.cursor/observibe/$slug}"

mkdir -p "$runtime_dir/scouts"/{chat,instructions,terminal,refactor,janitor}
touch "$runtime_dir/events.jsonl"
touch "$runtime_dir/scout-runs.jsonl"

if [ ! -f "$runtime_dir/BACKLOG.md" ]; then
  cp "$PLUGIN_ROOT/BACKLOG.example.md" "$runtime_dir/BACKLOG.md" 2>/dev/null || cat >"$runtime_dir/BACKLOG.md" <<'EOF'
# Observibe Backlog

Propose-only items from scouts. Triage during cleanup; check off when done.

EOF
fi

if [ ! -f "$runtime_dir/state.json" ]; then
  cat >"$runtime_dir/state.json" <<EOF
{
  "version": 1,
  "sessionStartedAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "lastEventLine": 0,
  "lastReportAt": null,
  "observibeSessionUuid": null,
  "lastScoutRun": {},
  "scoutStats": {},
  "terminalChecksums": {},
  "editTimestamps": [],
  "cooldownSkipsMs": 0,
  "idleMs": 0,
  "lastJanitorGateEval": null,
  "lastJanitorGateResult": null,
  "projectRoot": "$project_root"
}
EOF
fi

# Copy recon templates on first run (refresh from plugin if plugin newer)
for scout in chat instructions terminal refactor janitor; do
  dest="$runtime_dir/scouts/$scout/recon.sh"
  src="$PLUGIN_ROOT/scouts/$scout/recon.sh"
  if [ -f "$src" ]; then
    if [ ! -f "$dest" ] || [ "$src" -nt "$dest" ]; then
      cp "$src" "$dest"
      chmod +x "$dest"
    fi
  fi
done

echo "$runtime_dir"
