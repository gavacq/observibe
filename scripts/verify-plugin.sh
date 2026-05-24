#!/usr/bin/env bash
# Verify Observibe plugin is installed where Cursor auto-loads local plugins
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_LINK="$HOME/.cursor/plugins/local/observibe"
errors=0

check() {
  if [ "$1" -eq 0 ]; then
    echo "  OK  $2"
  else
    echo "  FAIL $2" >&2
    errors=$((errors + 1))
  fi
}

echo "Observibe install verification"
echo ""

[ -e "$LOCAL_LINK" ]
check $? "local plugin link exists: $LOCAL_LINK"

[ -f "$LOCAL_LINK/.cursor-plugin/plugin.json" ]
check $? ".cursor-plugin/plugin.json present"

[ -f "$LOCAL_LINK/commands/observibe.md" ]
check $? "commands/observibe.md present"

[ -f "$HOME/.cursor/commands/observibe.md" ]
check $? "user command link ~/.cursor/commands/observibe.md"

[ -f "$HOME/.cursor/skills/observibe/SKILL.md" ]
check $? "user skill ~/.cursor/skills/observibe/SKILL.md"

[ ! -f "$LOCAL_LINK/hooks/hooks.json" ]
check $? "plugin hooks/ not auto-loaded (use /setup-observe per project)"

for cmd in jq python3; do
  command -v "$cmd" >/dev/null 2>&1
  check $? "$cmd on PATH"
done

echo ""
if [ "$errors" -gt 0 ]; then
  echo "Fix failures, then reload Cursor (Developer: Reload Window)." >&2
  exit 1
fi

echo "Plugin files look good."
echo ""
echo "In chat, type / and search: observibe"
echo "Commands should include:"
echo "  /observibe          — start observer loop (second chat)"
echo "  /setup-observe      — install project hooks (once per repo)"
echo "  /observe            — single scout tick"
echo ""
echo "Installed to ~/.cursor/commands/ and ~/.cursor/skills/ for reliable menu discovery."
echo "If slash menu still empty: Cmd+Q quit Cursor fully, reopen, new Agent chat (Cmd+L)."
