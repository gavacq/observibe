---
name: setup-observe
description: Install Observibe hooks into the current project and bootstrap runtime. Use when the user runs /setup-observe or asks to enable Observibe for this repo.
---

# Setup Observe

Install Observibe into the **current workspace** so hooks fire from feature-coding chats and scouts write to the runtime backlog.

## On invoke

1. Resolve plugin root:
   ```bash
   OBSERVIBE_PLUGIN="$(bash "$HOME/.cursor/plugins/local/observibe/scripts/common/plugin-root.sh")"
   ```
2. Resolve workspace root — the open project root (not `~/.cursor`).
3. Run setup (non-interactive):
   ```bash
   bash "$OBSERVIBE_PLUGIN/scripts/setup-observe.sh" "<workspace-root>"
   ```
4. Read the script output and report to the user:
   - `.cursor/hooks/` scripts installed
   - `.cursor/hooks.json` merged (idempotent)
   - runtime dir at `.cursor/observibe/` in the workspace
   - hook verify result
5. Remind next steps:
   - **Dedicated second chat** → `/observibe`
   - Primary chat → normal vibe coding; hooks append to `events.jsonl`
   - Triage proposals in `BACKLOG.md` later

## Hard rules

- **Do not** start `/observibe` or the watcher in the same chat unless the user asks — setup only installs hooks + runtime.
- **Do not** edit app code or project AGENTS.md/skills.
- Re-running setup is safe — hook scripts are refreshed, `hooks.json` merge is deduped by command path.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `jq: command not found` | Install jq (`brew install jq`) |
| Hook verify failed | Check `.cursor/hooks/*.sh` are executable; re-run setup |
| No events during coding | Confirm hooks.json exists; restart Cursor after first install |
| Scouts never wake | Run `/observibe` in second chat to arm watcher |

## Re-install / update hooks

After plugin upgrade, run `/setup-observe` again in the project to refresh hook scripts and merge any new hook entries.
