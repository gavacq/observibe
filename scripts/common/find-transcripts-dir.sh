#!/usr/bin/env bash
# Find agent-transcripts dir for current workspace
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
slug="$("$SCRIPT_DIR/project-slug.sh" "${OBSERVIBE_PROJECT_ROOT:-$(pwd)}")"

if [ -n "${CURSOR_PROJECT_DIR:-}" ] && [ -d "$CURSOR_PROJECT_DIR/agent-transcripts" ]; then
  echo "$CURSOR_PROJECT_DIR/agent-transcripts"
  exit 0
fi

candidate="$HOME/.cursor/projects/$slug/agent-transcripts"
if [ -d "$candidate" ]; then
  echo "$candidate"
  exit 0
fi

# Fuzzy match project folder
found="$(find "$HOME/.cursor/projects" -maxdepth 2 -type d -name agent-transcripts 2>/dev/null | while IFS= read -r dir; do
  parent="$(basename "$(dirname "$dir")")"
  if echo "$parent" | grep -qi "$(basename "${OBSERVIBE_PROJECT_ROOT:-$(pwd)}")"; then
    echo "$dir"
    break
  fi
done | head -n1)"

if [ -n "$found" ]; then
  echo "$found"
fi
