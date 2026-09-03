#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_shortcut_env.sh"
require_shortcut_api_token

BASE_URL="${SHORTCUT_API_BASE_URL:-https://api.app.shortcut.com/api/v3}"

response="$(curl -sS "$BASE_URL/iterations" \
  -H "Shortcut-Token: $SHORTCUT_API_TOKEN" \
  -H "Content-Type: application/json")"

if command -v jq >/dev/null 2>&1; then
  result="$(echo "$response" | jq '
    map(select(.status == "started"))
    | map({id, name, status, start_date, end_date})
  ')"

  count="$(echo "$result" | jq 'length')"
  if [[ "$count" -eq 0 ]]; then
    echo "No current (started) iteration found." >&2
    exit 1
  fi

  echo "$result"
else
  echo "$response"
fi
