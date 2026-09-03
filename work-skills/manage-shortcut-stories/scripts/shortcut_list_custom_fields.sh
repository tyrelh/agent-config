#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_shortcut_env.sh"
require_shortcut_api_token

# Lists custom fields and their allowed values, so a field/value name can be
# looked up before setting it on a story.
# Usage: shortcut_list_custom_fields.sh [name_regex]

NAME_REGEX="${1:-}"
BASE_URL="${SHORTCUT_API_BASE_URL:-https://api.app.shortcut.com/api/v3}"

FIELDS_JSON="$(curl -sS "$BASE_URL/custom-fields" -H "Shortcut-Token: $SHORTCUT_API_TOKEN")"

# The heredoc below occupies stdin, so the API response is passed by environment.
FIELDS_JSON="$FIELDS_JSON" NAME_REGEX="$NAME_REGEX" python3 - <<'PY'
import json, os, re

pattern = os.environ.get("NAME_REGEX") or ""
regex = re.compile(pattern, re.IGNORECASE) if pattern else None

for field in json.loads(os.environ["FIELDS_JSON"]):
    name = field.get("name", "")
    if regex and not regex.search(name):
        continue
    state = "" if field.get("enabled") else "  (disabled)"
    print(f"{field['id']}  {name}{state}")
    for value in field.get("values", []):
        print(f"    {value['id']}  {value.get('value')}")
PY
