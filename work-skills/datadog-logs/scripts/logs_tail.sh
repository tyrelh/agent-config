#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${script_dir}/common.sh"

usage() {
  cat <<'USAGE'
Usage: logs_tail.sh [options]

Options:
  --env-file PATH     Path to .env file (default: skill .env)
  --query QUERY       Additional query text
  --service NAME      Service name
  --env NAME          Environment name (maps to environment:<name>)
  --environment NAME  Alias for --env
  --status VALUE      Log status (default: error)
  --interval SECONDS  Poll interval (default: 15)
  --window SECONDS    Initial lookback window (default: 300)
  --limit N           Page size per poll (default: 100)
  --raw               Output raw JSON instead of formatted lines
  -h, --help          Show help
USAGE
}

ENV_FILE=""
EXTRA_QUERY=""
SERVICE=""
ENV_NAME=""
STATUS="error"
INTERVAL=15
WINDOW=300
LIMIT=100
RAW=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file) ENV_FILE="$2"; shift 2 ;;
    --query) EXTRA_QUERY="$2"; shift 2 ;;
    --service) SERVICE="$2"; shift 2 ;;
    --env|--environment) ENV_NAME="$2"; shift 2 ;;
    --status) STATUS="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --window) WINDOW="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --raw) RAW=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac

done

load_env "$ENV_FILE"
require_cmd jq

QUERY="$(build_query "$STATUS" "$SERVICE" "$ENV_NAME" "$EXTRA_QUERY")"
LAST_TS="$(calc_time "-${WINDOW}" s)"

while true; do
  NOW="$(now_iso)"
  BODY=$(jq -n \
    --arg from "$LAST_TS" \
    --arg to "$NOW" \
    --arg query "$QUERY" \
    --arg sort "timestamp" \
    --argjson limit "$LIMIT" \
    '{filter:{from:$from,to:$to,query:$query},sort:$sort,page:{limit:$limit}}')

  RESP=$(curl_dd POST "/v2/logs/events/search" "$BODY")

  if [[ "$RAW" == "true" ]]; then
    echo "$RESP" | jq -c '.data[]'
  else
    echo "$RESP" | jq -r '.data[] | [
      .attributes.timestamp,
      (.attributes.service // "-"),
      (.attributes.status // "-"),
      (.attributes.message // "")
    ] | @tsv' | while IFS=$'\t' read -r ts svc st msg; do
      printf "%s [%s] %s %s\n" "$ts" "$svc" "$st" "$msg"
    done
  fi

  LAST_TS="$NOW"
  sleep "$INTERVAL"
done
