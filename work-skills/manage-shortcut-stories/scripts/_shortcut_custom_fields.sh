#!/usr/bin/env bash
# Shared helpers for Shortcut custom fields (Technical Area, Priority, Skill Set, Severity).
#
# Custom fields are set on a story as:
#   {"custom_fields": [{"field_id": "<uuid>", "value_id": "<uuid>"}]}
#
# Both IDs are opaque UUIDs, so these helpers accept human-readable names
# ("Technical Area", "Lightrail API") and resolve them against /custom-fields.
# Matching is case-insensitive. A name that is already a UUID is passed through.

# resolve_custom_field <field_name_or_id> <value_name_or_id>
# Prints: <field_id> <value_id>
# Exits non-zero with a message listing valid options when either lookup fails.
resolve_custom_field() {
  local field_ref="$1"
  local value_ref="$2"
  local base_url="${SHORTCUT_API_BASE_URL:-https://api.app.shortcut.com/api/v3}"

  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required to resolve custom field names." >&2
    return 1
  fi

  local fields_json
  fields_json="$(curl -sS "$base_url/custom-fields" -H "Shortcut-Token: $SHORTCUT_API_TOKEN")"

  # The heredoc below occupies stdin, so the API response is passed by environment.
  FIELDS_JSON="$fields_json" FIELD_REF="$field_ref" VALUE_REF="$value_ref" python3 - <<'PY'
import json, os, sys

field_ref = os.environ["FIELD_REF"].strip()
value_ref = os.environ["VALUE_REF"].strip()
fields = json.loads(os.environ["FIELDS_JSON"])


def matches(candidate, ref):
    return candidate and candidate.lower() == ref.lower()


field = next(
    (f for f in fields if matches(f.get("name"), field_ref) or f.get("id") == field_ref),
    None,
)
if field is None:
    names = ", ".join(f.get("name", "?") for f in fields if f.get("enabled"))
    sys.exit(f"Unknown custom field '{field_ref}'. Enabled fields: {names}")

if not field.get("enabled"):
    sys.exit(f"Custom field '{field['name']}' is disabled in this workspace.")

value = next(
    (
        v
        for v in field.get("values", [])
        if matches(v.get("value"), value_ref) or v.get("id") == value_ref
    ),
    None,
)
if value is None:
    options = ", ".join(v.get("value", "?") for v in field.get("values", []))
    sys.exit(f"Unknown value '{value_ref}' for '{field['name']}'. Options: {options}")

print(field["id"], value["id"])
PY
}

# custom_fields_json <field_name_or_id> <value_name_or_id>
# Prints the JSON array for the "custom_fields" key of a story create/update payload.
custom_fields_json() {
  local resolved
  resolved="$(resolve_custom_field "$1" "$2")" || return 1
  local field_id="${resolved% *}"
  local value_id="${resolved#* }"
  printf '[{"field_id":"%s","value_id":"%s"}]' "$field_id" "$value_id"
}
