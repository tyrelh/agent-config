#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_shortcut_env.sh"
require_shortcut_api_token

if [[ $# -lt 1 ]]; then
  echo "Usage: shortcut_search.sh \"<keywords>\" [page_size]" >&2
  exit 1
fi

BASE_URL="${SHORTCUT_API_BASE_URL:-https://api.app.shortcut.com/api/v3}"
QUERY="$1"
PAGE_SIZE="${2:-10}"
DETAIL="${SHORTCUT_SEARCH_DETAIL:-full}"
WORKFLOW_ID="${SHORTCUT_WORKFLOW_ID:-500004423}"

response="$(curl -sS -G "$BASE_URL/search/stories" \
  -H "Shortcut-Token: $SHORTCUT_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data-urlencode "query=$QUERY" \
  --data-urlencode "page_size=$PAGE_SIZE" \
  --data-urlencode "detail=$DETAIL")"

if command -v jq >/dev/null 2>&1; then
  if [[ -n "${WORKFLOW_ID}" ]]; then
    echo "$response" | jq --arg wf "$WORKFLOW_ID" '
      def filter_arr(a):
        if a | type == "array" then
          a | map(select(.workflow_id? and (.workflow_id | tostring) == $wf))
        else
          a
        end;
      if .data then
        .data = filter_arr(.data)
      elif .stories then
        .stories = filter_arr(.stories)
      elif .results then
        .results = filter_arr(.results)
      else
        .
      end
    '
  else
    echo "$response" | jq .
  fi
else
  echo "$response"
fi
