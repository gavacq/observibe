#!/usr/bin/env bash
# Install Observibe hooks into a project .cursor/hooks/
# Usage: bash scripts/install-hooks.sh /path/to/project
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${1:?project path required}"
CURSOR_DIR="$PROJECT/.cursor"
HOOKS_DIR="$CURSOR_DIR/hooks"

mkdir -p "$HOOKS_DIR"

for hook in log-stop-event.sh log-subagent.sh log-shell-event.sh log-tool-fail.sh log-edit-event.sh log-user-msg.sh; do
  cp "$PLUGIN_ROOT/hook-templates/$hook" "$HOOKS_DIR/$hook"
  chmod +x "$HOOKS_DIR/$hook"
  # Point installed hooks at plugin scripts (project .cursor/hooks has no scripts/common/)
  sed -i '' \
    -e "s|source \"\$SCRIPT_DIR/../scripts/common/hook-runtime.sh\"|source \"${PLUGIN_ROOT}/scripts/common/hook-runtime.sh\"|g" \
    -e "s|\"\$SCRIPT_DIR/../scripts/common/runtime-dir.sh\"|\"${PLUGIN_ROOT}/scripts/common/runtime-dir.sh\"|g" \
    "$HOOKS_DIR/$hook" 2>/dev/null || \
  sed -i \
    -e "s|source \"\$SCRIPT_DIR/../scripts/common/hook-runtime.sh\"|source \"${PLUGIN_ROOT}/scripts/common/hook-runtime.sh\"|g" \
    -e "s|\"\$SCRIPT_DIR/../scripts/common/runtime-dir.sh\"|\"${PLUGIN_ROOT}/scripts/common/runtime-dir.sh\"|g" \
    "$HOOKS_DIR/$hook"
done

echo "Installed hooks to $HOOKS_DIR"
echo "Run: bash $PLUGIN_ROOT/scripts/merge-hooks-json.sh \"$PROJECT\""
echo "Or full setup: bash $PLUGIN_ROOT/scripts/setup-observe.sh \"$PROJECT\""
