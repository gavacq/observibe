#!/usr/bin/env bash
# Resolve Observibe plugin root (installed local symlink or source checkout)
set -euo pipefail

if [ -n "${OBSERVIBE_PLUGIN_ROOT:-}" ] && [ -d "$OBSERVIBE_PLUGIN_ROOT" ]; then
  echo "$OBSERVIBE_PLUGIN_ROOT"
  exit 0
fi

LOCAL="$HOME/.cursor/plugins/local/observibe"
if [ -e "$LOCAL" ]; then
  if [ -L "$LOCAL" ]; then
    python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$LOCAL"
  else
    echo "$LOCAL"
  fi
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "$(cd "$SCRIPT_DIR/../.." && pwd)"
