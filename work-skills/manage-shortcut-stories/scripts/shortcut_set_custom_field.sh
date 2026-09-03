#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_shortcut_env.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_shortcut_custom_fields.sh"
require_shortcut_api_token

# Sets one custom field on a story. Field and value accept human-readable names
# or raw UUIDs, e.g.:
#   shortcut_set_custom_field.sh 24806 "Technical Area" "Lightrail API"
if [[ $# -lt 3 ]]; then
  echo "Usage: shortcut_set_custom_field.sh <story_id> <field_name_or_id> <value_name_or_id>" >&2
  exit 1
fi

STORY_ID="$1"
FIELD_REF="$2"
VALUE_REF="$3"
DRY_RUN="${SHORTCUT_DRY_RUN:-0}"

fields_json="$(custom_fields_json "$FIELD_REF" "$VALUE_REF")"
payload="{\"custom_fields\":$fields_json}"

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
