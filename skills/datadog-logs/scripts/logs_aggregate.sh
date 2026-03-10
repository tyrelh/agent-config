#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${script_dir}/common.sh"

usage() {
  cat <<'USAGE'
Usage: logs_aggregate.sh [options]

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
  --group-by FACET    Facet to group by (default: service)
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
GROUP_BY="service"

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
    --group-by) GROUP_BY="$2"; shift 2 ;;
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

BODY=$(jq -n \
  --arg from "$SINCE" \
  --arg to "$UNTIL" \
  --arg query "$QUERY" \
  --arg facet "$GROUP_BY" \
  '{filter:{from:$from,to:$to,query:$query},compute:[{aggregation:"count"}],group_by:[{facet:$facet}]}')

curl_dd POST "/v2/logs/aggregate" "$BODY" | jq .
