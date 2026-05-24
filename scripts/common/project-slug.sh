#!/usr/bin/env bash
# Emit a stable workspace slug for ~/.cursor/observibe/<slug>/
set -euo pipefail

project_root="${1:-${OBSERVIBE_PROJECT_ROOT:-$(pwd)}}"
project_root="$(cd "$project_root" 2>/dev/null && pwd || echo "$project_root")"

# Prefer Cursor project folder name when available
if [ -n "${CURSOR_PROJECT_DIR:-}" ]; then
  basename "$CURSOR_PROJECT_DIR"
  exit 0
fi

# Derive from path: /Users/gavacq/src/mvmtchallenge -> Users-gavacq-src-mvmtchallenge
slug="$(echo "$project_root" | sed 's|^/||' | tr '/ ' '-')"
echo "${slug:-workspace}"
