#!/usr/bin/env bash
# Find Cursor terminals dir for current workspace
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
slug="$("$SCRIPT_DIR/project-slug.sh" "${OBSERVIBE_PROJECT_ROOT:-$(pwd)}")"

if [ -n "${MVMT_TERMINALS_DIR:-}" ] && [ -d "$MVMT_TERMINALS_DIR" ]; then
  echo "$MVMT_TERMINALS_DIR"
  exit 0
fi

if [ -n "${CURSOR_PROJECT_DIR:-}" ] && [ -d "$CURSOR_PROJECT_DIR/terminals" ]; then
  echo "$CURSOR_PROJECT_DIR/terminals"
  exit 0
fi

candidate="$HOME/.cursor/projects/$slug/terminals"
if [ -d "$candidate" ]; then
  echo "$candidate"
  exit 0
fi

found="$(find "$HOME/.cursor/projects" -maxdepth 3 -type d -name terminals 2>/dev/null | while IFS= read -r dir; do
  if ls "$dir"/*.txt >/dev/null 2>&1; then
    project_name="$(basename "${OBSERVIBE_PROJECT_ROOT:-$(pwd)}")"
    if grep -l "$project_name" "$dir"/*.txt >/dev/null 2>&1; then
      echo "$dir"
      break
    fi
  fi
done | head -n1)"

if [ -n "$found" ]; then
  echo "$found"
fi
