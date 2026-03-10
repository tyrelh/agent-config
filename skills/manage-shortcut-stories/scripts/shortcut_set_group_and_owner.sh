#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_shortcut_env.sh"
require_shortcut_api_token

if [[ $# -lt 1 ]]; then
  echo "Usage: shortcut_set_group_and_owner.sh <story_id> [group_id] [owner_ids_csv]" >&2
  exit 1
fi

STORY_ID="$1"
GROUP_ID="${2:-${SHORTCUT_GROUP_ID:-}}"
OWNER_IDS="${3:-${SHORTCUT_OWNER_IDS:-}}"
DRY_RUN="${SHORTCUT_DRY_RUN:-0}"

if [[ -z "$GROUP_ID" && -z "$OWNER_IDS" ]]; then
  echo "Provide group_id, owner_ids, or both." >&2
  exit 1
fi

payload=""
if command -v jq >/dev/null 2>&1; then
  payload="$(jq -n \
    --arg group_id "$GROUP_ID" \
    --arg owner_ids "$OWNER_IDS" \
    '
    def split_ids(s): if s == "" then [] else s | split(",") end;
    {}
    + (if $group_id != "" then {group_id: $group_id} else {} end)
    + (if $owner_ids != "" then {owner_ids: split_ids($owner_ids)} else {} end)
    '
  )"
elif command -v python3 >/dev/null 2>&1; then
  payload="$(GROUP_ID="$GROUP_ID" OWNER_IDS="$OWNER_IDS" python3 - <<'PY'
import json
import os

group_id = os.environ.get("GROUP_ID")
owner_ids = os.environ.get("OWNER_IDS")

body = {}
if group_id:
    body["group_id"] = group_id
if owner_ids:
    body["owner_ids"] = [part for part in owner_ids.split(",") if part]

print(json.dumps(body))
PY
  )"
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

curl -sS -X "$METHOD" \
  -H "Shortcut-Token: $SHORTCUT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$payload" \
  "$BASE_URL/stories/$STORY_ID"
