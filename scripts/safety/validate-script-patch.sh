#!/usr/bin/env bash
# Classify a recon.sh patch as safe | needs_approval | deny
# Usage: bash validate-script-patch.sh --scout terminal --patch /path/to/patch.sh
set -euo pipefail

scout=""
patch_file=""

while [ $# -gt 0 ]; do
  case "$1" in
    --scout) scout="$2"; shift 2 ;;
    --patch) patch_file="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[ -f "$patch_file" ] || { echo '{"verdict":"deny","reason":"patch file missing"}'; exit 0; }

content="$(cat "$patch_file")"

deny_patterns=(
  'rm\s+-rf\s+/'
  'sudo\s'
  'curl\s.*\|\s*(ba)?sh'
  '\beval\s'
  'chmod\s+777'
  '>\s*/etc/'
  'wget\s.*\|\s*sh'
)

for pat in "${deny_patterns[@]}"; do
  if echo "$content" | grep -qE "$pat"; then
    jq -nc --arg reason "deny pattern: $pat" '{verdict:"deny",reason:$reason}'
    exit 0
  fi
done

needs_approval_patterns=(
  '\bcurl\b'
  '\bwget\b'
  '\bnc\s'
  '>\s*/'
  '\bchmod\b'
)

for pat in "${needs_approval_patterns[@]}"; do
  if echo "$content" | grep -qE "$pat"; then
    jq -nc --arg reason "needs approval: $pat" '{verdict:"needs_approval",reason:$reason}'
    exit 0
  fi
done

jq -nc '{verdict:"safe",reason:"read-only recon adjustments"}'
