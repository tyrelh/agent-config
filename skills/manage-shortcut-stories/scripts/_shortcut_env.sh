#!/usr/bin/env bash

load_shortcut_env() {
  local script_dir skill_dir env_file

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  skill_dir="$(cd "$script_dir/.." && pwd)"
  env_file="${SHORTCUT_ENV_FILE:-$skill_dir/.env}"

  if [[ -f "$env_file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  fi

  SHORTCUT_ENV_FILE="$env_file"
}

require_shortcut_api_token() {
  if [[ -z "${SHORTCUT_API_TOKEN:-}" ]]; then
    echo "SHORTCUT_API_TOKEN is not set. Add it to $SHORTCUT_ENV_FILE or export it in your shell." >&2
    exit 1
  fi
}

load_shortcut_env
