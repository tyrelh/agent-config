#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${script_dir}/common.sh"

usage() {
  cat <<'USAGE'
Usage: logs_export.sh [options]

Options:
  --env-file PATH     Path to .env file (default: skill .env)
  --query QUERY       Additional query text
  --service NAME      Service name
  --env NAME          Environment name (maps to environment:<name>)
  --environment NAME  Alias for --env
  --status VALUE      Log status (default: error)
  --since TIME        RFC3339 start time (default: now - --last)
  --until TIME        RFC3339 end time (default: now)
  --last MINUTES      Lookback window in minutes (default: 60)
  --limit N           Page size (default: 100)
  --format json|csv   Output format (default: json)
  --out PATH          Output file path (default: stdout)
  --all               Paginate until no next page
  -h, --help          Show help
USAGE
}

ENV_FILE=""
EXTRA_QUERY=""
SERVICE=""
ENV_NAME=""
STATUS="error"
SINCE=""
UNTIL=""
LAST_MINUTES=60
LIMIT=100
FORMAT="json"
OUT=""
ALL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file) ENV_FILE="$2"; shift 2 ;;
    --query) EXTRA_QUERY="$2"; shift 2 ;;
    --service) SERVICE="$2"; shift 2 ;;
    --env|--environment) ENV_NAME="$2"; shift 2 ;;
    --status) STATUS="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    --until) UNTIL="$2"; shift 2 ;;
    --last) LAST_MINUTES="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --all) ALL=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac

done

load_env "$ENV_FILE"
require_cmd jq

if [[ -z "$SINCE" ]]; then
  SINCE="$(calc_time "-${LAST_MINUTES}" m)"
fi
if [[ -z "$UNTIL" ]]; then
  UNTIL="$(now_iso)"
fi

QUERY="$(build_query "$STATUS" "$SERVICE" "$ENV_NAME" "$EXTRA_QUERY")"

output() {
  if [[ -n "$OUT" ]]; then
    cat >> "$OUT"
  else
    cat
  fi
}

if [[ -n "$OUT" ]]; then
  : > "$OUT"
fi

if [[ "$FORMAT" == "csv" ]]; then
  echo "timestamp,service,status,host,source,message" | output
fi

CURSOR=""
FIRST=true

while true; do
  if [[ -n "$CURSOR" ]]; then
    BODY=$(jq -n \
      --arg from "$SINCE" \
      --arg to "$UNTIL" \
      --arg query "$QUERY" \
      --arg sort "-timestamp" \
      --arg cursor "$CURSOR" \
      --argjson limit "$LIMIT" \
      '{filter:{from:$from,to:$to,query:$query},sort:$sort,page:{limit:$limit,cursor:$cursor}}')
  else
    BODY=$(jq -n \
      --arg from "$SINCE" \
      --arg to "$UNTIL" \
      --arg query "$QUERY" \
      --arg sort "-timestamp" \
      --argjson limit "$LIMIT" \
      '{filter:{from:$from,to:$to,query:$query},sort:$sort,page:{limit:$limit}}')
  fi

  RESP=$(curl_dd POST "/v2/logs/events/search" "$BODY")

  if [[ "$FORMAT" == "csv" ]]; then
    echo "$RESP" | jq -r '.data[] | [
      .attributes.timestamp,
      (.attributes.service // ""),
      (.attributes.status // ""),
      (.attributes.host // ""),
      (.attributes.source // ""),
      (.attributes.message // "")
    ] | @csv' | output
  else
    echo "$RESP" | jq -c '.data[]' | output
  fi

  CURSOR=$(echo "$RESP" | jq -r '.meta.page.after // empty')

  if [[ "$ALL" != "true" ]] || [[ -z "$CURSOR" ]]; then
    break
  fi

done
