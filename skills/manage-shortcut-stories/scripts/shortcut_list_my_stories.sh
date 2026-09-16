#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_shortcut_env.sh"
require_shortcut_api_token

usage() {
  echo "Usage: shortcut_list_my_stories.sh <state> [page_size]" >&2
  echo "  state: unstarted | started | done" >&2
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for shortcut_list_my_stories.sh" >&2
  exit 1
fi

STATE="$1"
case "$STATE" in
  unstarted|started|done) ;;
  *) echo "Invalid state: $STATE (must be unstarted, started, or done)" >&2; usage ;;
esac

PAGE_SIZE="${2:-25}"
DETAIL="${SHORTCUT_SEARCH_DETAIL:-full}"
WORKFLOW_ID="${SHORTCUT_WORKFLOW_ID:-}"
INCLUDE_ARCHIVED="${SHORTCUT_INCLUDE_ARCHIVED:-0}"
BASE_URL="${SHORTCUT_API_BASE_URL:-https://api.app.shortcut.com/api/v3}"

# Resolve current user's mention_name from the API token
MENTION_NAME="$(curl -sS "$BASE_URL/member" \
  -H "Shortcut-Token: $SHORTCUT_API_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.mention_name // empty')"

if [[ -z "$MENTION_NAME" ]]; then
  echo "Failed to resolve current member from API token" >&2
  exit 1
fi

QUERY="owner:$MENTION_NAME is:$STATE"

if ! [[ "$PAGE_SIZE" =~ ^[0-9]+$ ]] || [[ "$PAGE_SIZE" -le 0 ]]; then
  echo "page_size must be a positive integer" >&2
  exit 1
fi

all_pages_file="$(mktemp)"
trap 'rm -f "$all_pages_file" "${all_pages_file}.tmp"' EXIT
echo '[]' > "$all_pages_file"

next_cursor=""
while true; do
  if [[ -n "$next_cursor" ]]; then
    response="$(curl -sS -G "$BASE_URL/search/stories" \
      -H "Shortcut-Token: $SHORTCUT_API_TOKEN" \
      -H "Content-Type: application/json" \
      --data-urlencode "query=$QUERY" \
      --data-urlencode "page_size=$PAGE_SIZE" \
      --data-urlencode "detail=$DETAIL" \
      --data-urlencode "next=$next_cursor")"
  else
    response="$(curl -sS -G "$BASE_URL/search/stories" \
      -H "Shortcut-Token: $SHORTCUT_API_TOKEN" \
      -H "Content-Type: application/json" \
      --data-urlencode "query=$QUERY" \
      --data-urlencode "page_size=$PAGE_SIZE" \
      --data-urlencode "detail=$DETAIL")"
  fi

  page_data="$(echo "$response" | jq '.data // []')"
  jq --argjson page "$page_data" '. + $page' "$all_pages_file" > "${all_pages_file}.tmp"
  mv "${all_pages_file}.tmp" "$all_pages_file"

  next_cursor="$(echo "$response" | jq -r '.next // empty')"
  if [[ -z "$next_cursor" ]]; then
    break
  fi
done

jq \
  --arg state "$STATE" \
  --arg query "$QUERY" \
  --arg wf "$WORKFLOW_ID" \
  --arg include_archived "$INCLUDE_ARCHIVED" \
  '
    (if $wf != "" then map(select(.workflow_id? and ((.workflow_id | tostring) == $wf))) else . end)
    | (if $include_archived == "1" then . else map(select(.archived == false)) end)
    | {state: $state, query: $query, count: length, data: .}
  ' "$all_pages_file"
