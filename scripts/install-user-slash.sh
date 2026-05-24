#!/usr/bin/env bash
# Expose Observibe slash commands via user-level paths Cursor reliably discovers.
# Plugin bundle stays in ~/.cursor/plugins/local/observibe; this mirrors UI entry points.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USER_COMMANDS="${OBSERVIBE_USER_COMMANDS:-$HOME/.cursor/commands}"
USER_SKILLS="${OBSERVIBE_USER_SKILLS:-$HOME/.cursor/skills}"

mkdir -p "$USER_COMMANDS"

for cmd in observibe setup-observe observe; do
  ln -sfn "$PLUGIN_ROOT/commands/$cmd.md" "$USER_COMMANDS/$cmd.md"
done

install_skill() {
  local name="$1"
  local body_file="$2"
  mkdir -p "$USER_SKILLS/$name"
  cp "$body_file" "$USER_SKILLS/$name/SKILL.md"
}

# setup-observe: reuse plugin skill (already has correct name frontmatter)
install_skill setup-observe "$PLUGIN_ROOT/skills/setup-observe/SKILL.md"

# observibe: user skill named /observibe → master scout protocol
mkdir -p "$USER_SKILLS/observibe"
cat >"$USER_SKILLS/observibe/SKILL.md" <<EOF
---
name: observibe
description: Start Observibe Master Scout in a dedicated observer chat. Arm watcher, run scout loop, propose-only backlog. Use when the user invokes /observibe.
---

$(tail -n +5 "$PLUGIN_ROOT/commands/observibe.md")

Read and follow \`$PLUGIN_ROOT/skills/master-scout/SKILL.md\` for the full tick protocol.
EOF

# observe: manual single tick
mkdir -p "$USER_SKILLS/observe"
cat >"$USER_SKILLS/observe/SKILL.md" <<EOF
---
name: observe
description: Run one Observibe scout tick now, bypass cooldowns. Use when the user invokes /observe.
---

$(tail -n +5 "$PLUGIN_ROOT/commands/observe.md")
EOF

echo "User slash entry points:"
echo "  commands: $USER_COMMANDS/{observibe,setup-observe,observe}.md"
echo "  skills:   $USER_SKILLS/{observibe,setup-observe,observe}/SKILL.md"
echo ""
echo "Reload Cursor (Developer: Reload Window) then type / in Agent chat."
