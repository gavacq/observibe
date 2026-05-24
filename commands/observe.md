---
name: observe
description: Run one Observibe observation tick now (manual / debug)
---

# /observe

Single Master Scout tick — same protocol as `/observibe` but **no continuous loop**.

## Plugin root

```bash
OBSERVIBE_PLUGIN="$(bash "$HOME/.cursor/plugins/local/observibe/scripts/common/plugin-root.sh")"
```

## On invoke

1. Read `$OBSERVIBE_PLUGIN/skills/master-scout/SKILL.md`.
2. Run one tick with `trigger: manual-observe` and **bypass all cooldowns**.
3. Fire **all 5 scouts** (chat, instructions, terminal, refactor, janitor) in parallel.
4. Refresh `STATUS.md` and append to `BACKLOG.md`.
5. Do **not** start `poll-changes.sh` unless user asks.

## Hard rules

- Propose only — never edit app code or project instruction files.
- Read-only on project tree except runtime dir.
