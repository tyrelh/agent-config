#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_shortcut_env.sh"
require_shortcut_api_token

BASE_URL="${SHORTCUT_API_BASE_URL:-https://api.app.shortcut.com/api/v3}"
PATTERN="${1:-}"

response="$(curl -sS "$BASE_URL/members" \
  -H "Shortcut-Token: $SHORTCUT_API_TOKEN" \
  -H "Content-Type: application/json")"

if command -v jq >/dev/null 2>&1; then
  if [[ -n "$PATTERN" ]]; then
    echo "$response" | jq --arg pattern "$PATTERN" '
      map(select((.profile.name // "" | test($pattern; "i")) or (.profile.email // "" | test($pattern; "i"))))
      | map({id, name: .profile.name, email: .profile.email})
    '
  else
    echo "$response" | jq 'map({id, name: .profile.name, email: .profile.email})'
  fi
else
  echo "$response"
fi
