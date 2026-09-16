#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_shortcut_env.sh"
require_shortcut_api_token

BASE_URL="${SHORTCUT_API_BASE_URL:-https://api.app.shortcut.com/api/v3}"
DOC_TITLE="${SHORTCUT_ITERATION_DOC_TITLE:-Sprint/Iteration Planning}"

iteration_id="${1:-}"
if [[ -z "$iteration_id" ]]; then
  iteration_id="$("$SCRIPT_DIR/shortcut_get_current_iteration.sh" | jq -r '.[0].id')"
  if [[ -z "$iteration_id" || "$iteration_id" == "null" ]]; then
    echo "Could not determine current iteration ID." >&2
    exit 1
  fi
  echo "Using current iteration: $iteration_id" >&2
fi

doc_ids="$(curl -sS "$BASE_URL/documents" \
  -H "Shortcut-Token: $SHORTCUT_API_TOKEN" \
  -H "Content-Type: application/json" \
  | jq -r --arg title "$DOC_TITLE" '.[] | select(.title == $title) | .id')"

if [[ -z "$doc_ids" ]]; then
  echo "No documents found with title \"$DOC_TITLE\"." >&2
  exit 1
fi

iteration_pattern="iteration/$iteration_id"

for doc_id in $doc_ids; do
  doc="$(curl -sS "$BASE_URL/documents/$doc_id" \
    -H "Shortcut-Token: $SHORTCUT_API_TOKEN" \
    -H "Content-Type: application/json")"

  if echo "$doc" | jq -r '.content_markdown' | grep -q "$iteration_pattern"; then
    echo "$doc" | jq '{id, title, created_at, updated_at, app_url, content_markdown}'
    exit 0
  fi
done

echo "No document found linking to iteration $iteration_id." >&2
exit 1
