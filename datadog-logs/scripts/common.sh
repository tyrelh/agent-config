#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "${script_dir}/.." && pwd)"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

load_env() {
  local env_file="${1:-${skill_dir}/.env}"
  if [[ -f "$env_file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  fi
}

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required env var: $name" >&2
    exit 1
  fi
}

dd_api_base() {
  if [[ -n "${DD_API_BASE:-}" ]]; then
    echo "$DD_API_BASE"
    return
  fi
  local site="${DD_SITE:-}"
  if [[ -z "$site" ]]; then
    echo "Missing DD_SITE (example: us3) or set DD_API_BASE" >&2
    exit 1
  fi
  if [[ "$site" == *"datadoghq.com"* ]]; then
    echo "https://api.${site}/api"
  else
    echo "https://api.${site}.datadoghq.com/api"
  fi
}

curl_dd() {
  local method="$1"
  local url="$2"
  local data="${3:-}"

  require_var DD_API_KEY
  require_var DD_APP_KEY

  local base
  base="$(dd_api_base)"
  local full_url="${base}${url}"

  if [[ -n "$data" ]]; then
    curl -sS -X "$method" "$full_url" \
      -H "DD-API-KEY: $DD_API_KEY" \
      -H "DD-APPLICATION-KEY: $DD_APP_KEY" \
      -H "Content-Type: application/json" \
      -d "$data"
  else
    curl -sS -X "$method" "$full_url" \
      -H "DD-API-KEY: $DD_API_KEY" \
      -H "DD-APPLICATION-KEY: $DD_APP_KEY"
  fi
}

now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

calc_time() {
  local offset="$1"
  local unit="$2"
  local fmt="%Y-%m-%dT%H:%M:%SZ"

  if date -u -v -1M +"$fmt" >/dev/null 2>&1; then
    local mac_unit
    case "$unit" in
      s) mac_unit="S" ;;
      m) mac_unit="M" ;;
      h) mac_unit="H" ;;
      *) mac_unit="M" ;;
    esac
    date -u -v "${offset}${mac_unit}" +"$fmt"
  else
    local gnu_unit
    case "$unit" in
      s) gnu_unit="seconds" ;;
      m) gnu_unit="minutes" ;;
      h) gnu_unit="hours" ;;
      *) gnu_unit="minutes" ;;
    esac
    date -u -d "${offset} ${gnu_unit}" +"$fmt"
  fi
}

build_query() {
  local status="$1"
  local service="$2"
  local env="$3"
  local extra="$4"
  local query=""

  if [[ -n "$status" ]]; then
    query="status:${status}"
  fi
  if [[ -n "$service" ]]; then
    query="${query} service:${service}"
  fi
  if [[ -n "$env" ]]; then
    query="${query} environment:${env}"
  fi
  if [[ -n "$extra" ]]; then
    query="${query} ${extra}"
  fi

  echo "$query" | xargs
}
