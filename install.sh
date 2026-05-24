#!/usr/bin/env bash
# Install Observibe plugin locally for Cursor
set -euo pipefail

PLUGIN_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${1:-$HOME/.cursor/plugins/cache/local/observibe}"
LOCAL_LINK="${OBSERVIBE_LOCAL_LINK:-$HOME/.cursor/plugins/local/observibe}"

mkdir -p "$(dirname "$DEST")"
rm -rf "$DEST"
cp -R "$PLUGIN_SRC" "$DEST"

find "$DEST" -name '*.sh' -exec chmod +x {} \;

# Cursor loads local dev plugins from ~/.cursor/plugins/local/<name>/
mkdir -p "$(dirname "$LOCAL_LINK")"
ln -sfn "$DEST" "$LOCAL_LINK"

# User-level commands/skills — reliable / menu discovery (local plugin commands often missing from autocomplete)
bash "$DEST/scripts/install-user-slash.sh"

echo "Installed Observibe to: $DEST"
echo "Linked for Cursor:  $LOCAL_LINK -> $DEST"
echo ""
bash "$DEST/scripts/verify-plugin.sh" || true
