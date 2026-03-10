#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_shortcut_env.sh"
require_shortcut_api_token

if [[ $# -lt 2 ]]; then
  echo "Usage: shortcut_set_iteration.sh <story_id> <iteration_id>" >&2
  exit 1
fi

STORY_ID="$1"
ITERATION_ID="$2"
DRY_RUN="${SHORTCUT_DRY_RUN:-0}"

payload=""
if command -v jq >/dev/null 2>&1; then
  payload="$(jq -n \
    --arg iteration_id "$ITERATION_ID" \
    '{iteration_id: ($iteration_id | tonumber)}'
  )"
elif command -v python3 >/dev/null 2>&1; then
  payload="$(ITERATION_ID="$ITERATION_ID" python3 -c '
import json, os
print(json.dumps({"iteration_id": int(os.environ["ITERATION_ID"])}))
')"
else
  echo "jq or python3 is required to build JSON payload." >&2
  exit 1
fi

if [[ "$DRY_RUN" == "1" ]]; then
  echo "$payload"
  exit 0
fi

BASE_URL="${SHORTCUT_API_BASE_URL:-https://api.app.shortcut.com/api/v3}"
METHOD="${SHORTCUT_UPDATE_METHOD:-PUT}"

response="$(curl -sS -X "$METHOD" \
  -H "Shortcut-Token: $SHORTCUT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$payload" \
  "$BASE_URL/stories/$STORY_ID")"

if command -v jq >/dev/null 2>&1; then
  echo "$response" | jq .
else
  echo "$response"
fi
