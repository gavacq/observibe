#!/usr/bin/env bash
# Idempotently merge Observibe hook entries into project .cursor/hooks.json
# Usage: bash scripts/merge-hooks-json.sh /path/to/project
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${1:?project path required}"
CURSOR_DIR="$PROJECT/.cursor"
TARGET="$CURSOR_DIR/hooks.json"
SOURCE="$PLUGIN_ROOT/hook-templates/hooks.json"

mkdir -p "$CURSOR_DIR"

# Normalize plugin hook commands to project-relative paths (.cursor/hooks/...)
transformed="$(jq '
  .hooks |= with_entries(
    .value |= map(
      if (.command | type) == "string" then
        if (.command | startswith(".cursor/")) then .
        elif (.command | startswith("hooks/")) then .command = ".cursor/" + .command
        else . end
      else . end
    )
  )
' "$SOURCE")"

if [ ! -f "$TARGET" ]; then
  echo "$transformed" | jq '{version: 1, hooks: .hooks}' >"$TARGET"
  echo "Created $TARGET with Observibe hooks"
  exit 0
fi

merged="$(jq -s '
  .[0] as $existing |
  .[1] as $incoming |
  ($existing.version // 1) as $version |
  ($existing.hooks // {}) as $existingHooks |
  ($incoming.hooks // {}) as $incomingHooks |
  ($existingHooks | keys + ($incomingHooks | keys) | unique) as $allKeys |
  {
    version: $version,
    hooks: (
      reduce $allKeys[] as $k ({};
        .[$k] = (
          (($existingHooks[$k] // []) + ($incomingHooks[$k] // []))
          | unique_by(.command)
        )
      )
    )
  }
' "$TARGET" <(echo "$transformed" | jq '{hooks: .hooks}'))"

tmp="$(mktemp)"
echo "$merged" >"$tmp"
mv "$tmp" "$TARGET"
echo "Merged Observibe hooks into $TARGET"
