#!/usr/bin/env bash
# Resolve and bootstrap <project>/.cursor/observibe/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

project_root="${OBSERVIBE_PROJECT_ROOT:-${1:-$(pwd)}}"
project_root="$(cd "$project_root" 2>/dev/null && pwd || echo "$project_root")"
slug="$("$SCRIPT_DIR/project-slug.sh" "$project_root")"
runtime_dir="${OBSERVIBE_RUNTIME_DIR:-$project_root/.cursor/observibe}"
legacy_dir="$HOME/.cursor/observibe/$slug"

mkdir -p "$runtime_dir/scouts"/{chat,instructions,terminal,refactor,janitor}

# One-time migration from legacy global runtime dir (before creating empty placeholders)
if [ -d "$legacy_dir" ] && [ "$legacy_dir" != "$runtime_dir" ]; then
  for f in BACKLOG.md STATUS.md state.json events.jsonl scout-runs.jsonl; do
    if [ -f "$legacy_dir/$f" ] && [ ! -f "$runtime_dir/$f" ]; then
      cp "$legacy_dir/$f" "$runtime_dir/$f" 2>/dev/null || true
    fi
  done
  if [ -d "$legacy_dir/scouts" ]; then
    for scout in chat instructions terminal refactor janitor; do
      if [ -f "$legacy_dir/scouts/$scout/recon.sh" ] && [ ! -f "$runtime_dir/scouts/$scout/recon.sh" ]; then
        cp "$legacy_dir/scouts/$scout/recon.sh" "$runtime_dir/scouts/$scout/recon.sh" 2>/dev/null || true
        chmod +x "$runtime_dir/scouts/$scout/recon.sh" 2>/dev/null || true
      fi
    done
  fi
fi

touch "$runtime_dir/events.jsonl"
touch "$runtime_dir/scout-runs.jsonl"

if [ ! -f "$runtime_dir/.gitignore" ]; then
  cat >"$runtime_dir/.gitignore" <<'EOF'
# Observibe runtime (BACKLOG.md is kept for triage — commit if you want)
events.jsonl
scout-runs.jsonl
state.json
STATUS.md
scouts/
EOF
fi

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
