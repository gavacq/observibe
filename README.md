# Observibe

Background observation for vibe coding. Run in a **dedicated second chat** while you ship features in your primary chat.

## Install

```bash
git clone https://github.com/gavacq/observibe.git
cd observibe
bash install.sh
```

Then **Developer: Reload Window** (Cmd+Shift+P). If `/observibe` still missing from the menu, fully quit Cursor (Cmd+Q) and reopen.

Install also mirrors slash entry points to:

- `~/.cursor/commands/` (same discovery path as built-in commands)
- `~/.cursor/skills/` (same path as your `/commit` skill)

Verify install:

```bash
bash ~/.cursor/plugins/local/observibe/scripts/verify-plugin.sh
```

## Per-project setup

In any workspace where you want observation:

```
/setup-observe
```

Or manually:

```bash
bash scripts/setup-observe.sh /path/to/project
```

This installs `.cursor/hooks/`, merges `.cursor/hooks.json`, bootstraps runtime, and verifies hook → `events.jsonl`.

## Commands

| Command | Purpose |
|---------|---------|
| `/setup-observe` | Install hooks + bootstrap runtime (once per project) |
| `/observibe` | Start Master Scout + watcher loop (dedicated second chat) |
| `/observe` | Single tick, all scouts, bypass cooldowns |

## Runtime data

Written into each workspace at `.cursor/observibe/`:

```
.cursor/observibe/
├── BACKLOG.md       # human review backlog (commit-friendly)
├── STATUS.md        # telemetry dashboard (gitignored by default)
├── state.json       # cooldowns + stats
├── events.jsonl     # hook events
├── scout-runs.jsonl # per-run telemetry
└── scouts/*/recon.sh
```

Legacy path `~/.cursor/observibe/<slug>/` is migrated on first bootstrap.

## Scouts

| Scout | Trigger | Role |
|-------|---------|------|
| chat | `stop` | Session efficiency, wasted effort |
| instructions | `stop` | AGENTS.md / skill proposals |
| terminal | shell exit ≠ 0, heartbeat | All Cursor terminals |
| refactor | debounced edits | git diff duplication |
| janitor | idle gate | broad cleanup proposals |

## Hooks (project install)

Use `/setup-observe` (or `scripts/setup-observe.sh`). Hooks append to `events.jsonl` in <100ms. Re-run after plugin upgrades to refresh scripts.

## Troubleshooting

**Slash commands missing?**

Local plugin commands often don't appear in `/` autocomplete ([known Cursor issue](https://forum.cursor.com/t/local-plugin-not-loading-commands/161008)). Re-run `bash install.sh` — it mirrors to `~/.cursor/commands/` and `~/.cursor/skills/`.

1. Confirm links: `ls ~/.cursor/commands/observibe.md ~/.cursor/skills/observibe/SKILL.md`
2. Run `bash ~/.cursor/plugins/local/observibe/scripts/verify-plugin.sh`
3. **Cmd+Q** quit Cursor fully (reload alone may not refresh menu cache)
4. New **Agent chat** (Cmd+L), type `/observ` — not `setup observe` (use `/setup-observe`)
5. Try typing `/observibe` fully even if autocomplete is empty — it may still run

**Files in `plugins/cache/local/` but commands don't work?**

Cursor loads from `plugins/local/`, not `cache/local/`. Re-run `bash install.sh`.

## Cleanup workflow

Open a third chat:

```
Read `.cursor/observibe/BACKLOG.md` in the project. Fix or skip each item. Mark done.
```

## Env

- `OBSERVIBE_POLL_SEC` (default 5)
- `OBSERVIBE_HEARTBEAT_SEC` (default 600)
- `OBSERVIBE_HOURLY_SEC` (default 3600)
- `OBSERVIBE_JANITOR_IDLE_SEC` (default 300)
- `OBSERVIBE_JANITOR_COOLDOWN_SEC` (default 1800)
- `OBSERVIBE_TERMINAL_TAIL_LINES` (default 80)
