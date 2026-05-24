---
name: observibe
description: Start Observibe Master Scout — arm watcher, enter dynamic loop, observe vibe coding
---

# /observibe

Start **Observibe** in this dedicated chat. Do not vibe-code features here — use a separate chat for that.

## Plugin root

Resolve once at start of every script invocation:

```bash
OBSERVIBE_PLUGIN="$(bash "$HOME/.cursor/plugins/local/observibe/scripts/common/plugin-root.sh")"
```

## On invoke

1. Read the skill at `$OBSERVIBE_PLUGIN/skills/master-scout/SKILL.md` and follow it exactly.
2. Resolve runtime dir:
   ```bash
   bash "$OBSERVIBE_PLUGIN/scripts/common/runtime-dir.sh"
   ```
3. Record this chat's session UUID in `state.json` as `observibeSessionUuid` (self-exclude from hooks).
4. Start the watcher if not already running:
   ```bash
   bash "$OBSERVIBE_PLUGIN/scripts/master/poll-changes.sh"
   ```
   Use `block_until_ms: 0` and `notify_on_output` on pattern `^AGENT_LOOP_WAKE_OBSERVIBE`.
5. Enter dynamic `/loop` per the loop skill:
   - On each `AGENT_LOOP_WAKE_OBSERVIBE` sentinel, run one Master Scout tick.
   - Re-arm heartbeat at end of each tick.

## Hard rules

- **Propose only** — append to `BACKLOG.md`; never edit app code or project AGENTS.md/skills.
- Master Scout **schedules only** — delegates all analysis to scout subagents.
- Read-only on project tree except `.cursor/observibe/` in the workspace.

## Stop

User asks to stop → kill watcher PID, stop arming loop heartbeats.
