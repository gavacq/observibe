---
name: setup-observe
description: Install Observibe hooks and bootstrap runtime for this project
---

# /setup-observe

One-time (or re-run) setup for **this workspace**. Installs Cursor hooks so Observibe can observe your vibe-coding chat while you run `/observibe` in a separate chat.

## Plugin root

```bash
OBSERVIBE_PLUGIN="$(bash "$HOME/.cursor/plugins/local/observibe/scripts/common/plugin-root.sh")"
```

## On invoke

1. Read and follow `$OBSERVIBE_PLUGIN/skills/setup-observe/SKILL.md` exactly.
2. Run:
   ```bash
   bash "$OBSERVIBE_PLUGIN/scripts/setup-observe.sh"
   ```
   Use the current workspace root as the project path.
3. Summarize what was installed and where runtime data lives.

## What this does

- Copies hook scripts → `.cursor/hooks/`
- Merges Observibe entries into `.cursor/hooks.json` (idempotent)
- Bootstraps `.cursor/observibe/` in the workspace
- Verifies a test `stop` event reaches `events.jsonl`

## What this does NOT do

- Does not start the Master Scout loop — use `/observibe` in a **second chat** for that.
- Does not modify application source or project instructions.

## After setup

| Chat | Command | Role |
|------|---------|------|
| Primary | (normal coding) | Hooks fire → `events.jsonl` |
| Dedicated observer | `/observibe` | Watcher + scouts → `BACKLOG.md` |
| Cleanup (optional) | manual | Triage backlog items |
