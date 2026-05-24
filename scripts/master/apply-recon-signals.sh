#!/usr/bin/env bash
# Turn deterministic recon signals into BACKLOG bullets (no LLM).
# Usage: bash apply-recon-signals.sh --scout chat
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
scout=""

while [ $# -gt 0 ]; do
  case "$1" in
    --scout) scout="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[ -n "$scout" ] || exit 0

project_root="${OBSERVIBE_PROJECT_ROOT:-$(pwd)}"
runtime="$("$SCRIPT_DIR/../common/runtime-dir.sh" "$project_root")"
recon="$runtime/scouts/$scout/last-recon.json"
[ -f "$recon" ] || exit 0
jq empty "$recon" 2>/dev/null || exit 0

items_file="$(mktemp)"
trap 'rm -f "$items_file"' EXIT

case "$scout" in
  instructions)
    jq -r '
      [.corrections[]? | .message | gsub("\\s+"; " ") | .[0:160]]
      | unique
      | .[]
      | "- [ ] **Instructions** — " + .
    ' "$recon" >"$items_file"
    section="Instructions (proposed)"
    ;;
  chat)
    jq -r '
      .sessions[]?.metrics.topRepeatedCommands[]?
      | select(.count >= 2)
      | "- [ ] Retried command \(.count)× — \(.command | .[0:120])"
    ' "$recon" >"$items_file"
    section="Session efficiency (chat-scout)"
    ;;
  terminal)
    jq -r '
      .terminals[]?
      | select((.matched_lines | length) > 0)
      | "- [ ] **[\\(.kind) \\(.id)]** \\(.matched_lines[0].line | .[0:140])"
    ' "$recon" >"$items_file"
    section="Terminal / dev server"
    ;;
  refactor)
    jq -r '
      .duplicates[]?
      | "- [ ] Duplicate pattern in \\(.files | join(" + ")) — extract shared helper"
    ' "$recon" 2>/dev/null >"$items_file" || : >"$items_file"
    section="Refactoring"
    ;;
  janitor)
    jq -r '
      .untestedFiles[]?
      | "- [ ] `\\(.path)` — new export, no matching test file"
    ' "$recon" 2>/dev/null >"$items_file" || : >"$items_file"
    section="Janitor — test coverage"
    ;;
  *)
    exit 0
    ;;
esac

if [ -s "$items_file" ]; then
  bash "$SCRIPT_DIR/merge-findings.sh" --scout "$scout" --section "$section" --items-file "$items_file"
fi
