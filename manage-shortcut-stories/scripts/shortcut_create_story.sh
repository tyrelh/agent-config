#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_shortcut_env.sh"
require_shortcut_api_token

if [[ $# -lt 3 ]]; then
  echo "Usage: shortcut_create_story.sh \"<name>\" \"<description>\" <story_type> [workflow_state_id] [group_id] [owner_ids_csv]" >&2
  exit 1
fi

NAME="$1"
DESCRIPTION="$2"
STORY_TYPE="$3"
WORKFLOW_STATE_ID="${4:-${SHORTCUT_WORKFLOW_STATE_ID:-}}"
GROUP_ID="${5:-${SHORTCUT_GROUP_ID:-}}"
OWNER_IDS="${6:-${SHORTCUT_OWNER_IDS:-}}"
PROJECT_ID="${SHORTCUT_PROJECT_ID:-}"
DRY_RUN="${SHORTCUT_DRY_RUN:-0}"

if [[ -z "$WORKFLOW_STATE_ID" && -z "$PROJECT_ID" ]]; then
  echo "Provide workflow_state_id (arg4 or SHORTCUT_WORKFLOW_STATE_ID) or SHORTCUT_PROJECT_ID." >&2
  exit 1
fi

payload=""
if command -v jq >/dev/null 2>&1; then
  payload="$(jq -n \
    --arg name "$NAME" \
    --arg description "$DESCRIPTION" \
    --arg story_type "$STORY_TYPE" \
    --arg workflow_state_id "$WORKFLOW_STATE_ID" \
    --arg project_id "$PROJECT_ID" \
    --arg group_id "$GROUP_ID" \
    --arg owner_ids "$OWNER_IDS" \
    '
    def split_ids(s): if s == "" then [] else s | split(",") end;
    {name: $name, description: $description, story_type: $story_type}
    + (if $workflow_state_id != "" then {workflow_state_id: ($workflow_state_id | tonumber)} else {} end)
    + (if $project_id != "" then {project_id: ($project_id | tonumber)} else {} end)
    + (if $group_id != "" then {group_id: $group_id} else {} end)
    + (if $owner_ids != "" then {owner_ids: split_ids($owner_ids)} else {} end)
    '
  )"
elif command -v python3 >/dev/null 2>&1; then
  payload="$(NAME="$NAME" DESCRIPTION="$DESCRIPTION" STORY_TYPE="$STORY_TYPE" WORKFLOW_STATE_ID="$WORKFLOW_STATE_ID" PROJECT_ID="$PROJECT_ID" GROUP_ID="$GROUP_ID" OWNER_IDS="$OWNER_IDS" python3 - <<'PY'
import json
import os

name = os.environ.get("NAME")
description = os.environ.get("DESCRIPTION")
story_type = os.environ.get("STORY_TYPE")
workflow_state_id = os.environ.get("WORKFLOW_STATE_ID")
project_id = os.environ.get("PROJECT_ID")
group_id = os.environ.get("GROUP_ID")
owner_ids = os.environ.get("OWNER_IDS")

body = {"name": name, "description": description, "story_type": story_type}
if workflow_state_id:
    body["workflow_state_id"] = int(workflow_state_id)
if project_id:
    body["project_id"] = int(project_id)
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

curl -sS -X POST \
  -H "Shortcut-Token: $SHORTCUT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$payload" \
  "$BASE_URL/stories"
