#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_shortcut_env.sh"
require_shortcut_api_token

if [[ $# -lt 1 ]]; then
  echo "Usage: shortcut_set_in_progress.sh <story_id>" >&2
  exit 1
fi

BASE_URL="${SHORTCUT_API_BASE_URL:-https://api.app.shortcut.com/api/v3}"
METHOD="${SHORTCUT_UPDATE_METHOD:-PUT}"
STATE_ID="${SHORTCUT_STARTED_STATE_ID:-500004425}"
STORY_ID="$1"

payload="{\"workflow_state_id\":${STATE_ID}}"

response="$(curl -sS -X "$METHOD" "$BASE_URL/stories/$STORY_ID" \
  -H "Shortcut-Token: $SHORTCUT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$payload")"

if command -v jq >/dev/null 2>&1; then
  echo "$response" | jq .
else
  echo "$response"
fi
