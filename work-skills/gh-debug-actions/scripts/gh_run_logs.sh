#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Fetch GitHub Actions logs for a workflow run using gh.

Usage:
  gh_run_logs.sh --repo owner/repo [options]

Options:
  --repo <owner/repo>     (required)
  --run-id <id>           Use a specific run id (skips listing)
  --workflow <name>       Workflow name
  --branch <name>         Branch name
  --status <status>       Run status filter (default: failure). Use "any" to skip
  --user <username>       GitHub username who triggered the run
  --event <event>         Event that triggered the run (push, workflow_dispatch, etc.)
  --limit <n>             Max runs to consider (default: 20)
  --attempt <n>           Attempt number
  --failed-only           Fetch failed steps only
  --output <path>         Write logs to file
  --help                  Show this help

Examples:
  gh_run_logs.sh --repo Giftbit/lightrail --workflow "CI" --branch main
  gh_run_logs.sh --repo Giftbit/giftbitfe --run-id 123456 --failed-only
  gh_run_logs.sh --repo Giftbit/lightrail --workflow "Deploy" --user alice --output /tmp/run.log
USAGE
}

repo=""
run_id=""
workflow=""
branch=""
status="failure"
user=""
event=""
limit="20"
attempt=""
failed_only="false"
output=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --run-id) run_id="$2"; shift 2 ;;
    --workflow) workflow="$2"; shift 2 ;;
    --branch) branch="$2"; shift 2 ;;
    --status) status="$2"; shift 2 ;;
    --user) user="$2"; shift 2 ;;
    --event) event="$2"; shift 2 ;;
    --limit) limit="$2"; shift 2 ;;
    --attempt) attempt="$2"; shift 2 ;;
    --failed-only) failed_only="true"; shift ;;
    --output) output="$2"; shift 2 ;;
    --help) usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$repo" ]]; then
  echo "--repo is required" >&2
  usage
  exit 2
fi

select_run_id() {
  local cmd
  cmd=(gh run list -R "$repo" -L "$limit" --json databaseId,workflowName,headBranch,status,conclusion,createdAt,url)
  if [[ -n "$workflow" ]]; then cmd+=(-w "$workflow"); fi
  if [[ -n "$branch" ]]; then cmd+=(-b "$branch"); fi
  if [[ -n "$user" ]]; then cmd+=(-u "$user"); fi
  if [[ -n "$event" ]]; then cmd+=(-e "$event"); fi
  if [[ -n "$status" && "$status" != "any" && "$status" != "all" ]]; then cmd+=(-s "$status"); fi

  local line
  line=$("${cmd[@]}" --jq '.[0] | "\(.databaseId)\t\(.workflowName)\t\(.headBranch)\t\(.status)\t\(.conclusion)\t\(.createdAt)\t\(.url)"') || true
  if [[ -z "$line" || "$line" == $'\t'* ]]; then
    local detail=""
    [[ -n "$workflow" ]] && detail+=" workflow=$workflow"
    [[ -n "$branch" ]] && detail+=" branch=$branch"
    [[ -n "$user" ]] && detail+=" user=$user"
    [[ -n "$event" ]] && detail+=" event=$event"
    if [[ -n "$status" && "$status" != "any" && "$status" != "all" ]]; then
      detail+=" status=$status"
    fi
    if [[ -z "$detail" ]]; then detail=" no filters"; fi
    echo "No runs found for $repo ($detail)." >&2
    exit 1
  fi

  IFS=$'\t' read -r run_id workflow_name head_branch run_status run_conclusion created_at run_url <<<"$line"
  echo "Selected run: id=$run_id workflow=$workflow_name branch=$head_branch status=$run_status conclusion=$run_conclusion createdAt=$created_at url=$run_url" >&2
  echo "$run_id"
}

if [[ -z "$run_id" ]]; then
  run_id=$(select_run_id)
fi

view_cmd=(gh run view "$run_id" -R "$repo")
if [[ -n "$attempt" ]]; then view_cmd+=(-a "$attempt"); fi
if [[ "$failed_only" == "true" ]]; then
  view_cmd+=(--log-failed)
else
  view_cmd+=(--log)
fi

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  "${view_cmd[@]}" >"$output"
  echo "Wrote logs to $output" >&2
else
  "${view_cmd[@]}"
fi
