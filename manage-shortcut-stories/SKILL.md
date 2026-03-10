---
name: manage-shortcut-stories
description: Manage Shortcut stories via API. Use when you need to find or create a Shortcut ticket, list projects/workflows/teams, assign owners/teams, fetch story details, or update a story's workflow state to in-progress (started) or ready-for-review. Includes keyword-based search with user prompts, story creation, and story updates.
---

# Manage Shortcut Stories

## Overview
Find the best-matching Shortcut story for the current thread, create new stories when needed, assign teams/owners, and update workflow states using the Shortcut API.

## Quick Start
1. Read `references/shortcut-config.md` for workflow IDs and configuration.
2. Add `SHORTCUT_API_TOKEN=<token>` to `manage-shortcut-stories/.env` (see `.env.example`) or export it in your shell; scripts load `.env` automatically and fail fast if missing.
3. Use the bash scripts in `scripts/` for search, creation, listing, and updates to simplify debugging.
4. Before keyword search, check the current branch for `sc-<id>-` and fetch that story.
5. If a branch story is found, ask the user to confirm it is the correct ticket.
6. For search, collect keywords from the thread and prompt for more if ambiguous.
7. For creation, provide either `project_id` or `workflow_state_id`. If projects are not used, pick a workflow state (typically "Unstarted") via the workflows list.
8. "Team" in the UI maps to `group_id` in the API; list groups to find the team ID.
9. For state updates, update the story with the target `workflow_state_id`.

## Conventions
- When taking on a ticket, always ensure it's assigned to the user, gets put in the current iteration, and it gets moved to in-progress appropriately.
  - To put a ticket in the current iteration: run `shortcut_get_current_iteration.sh` to find the active iteration ID, then run `shortcut_set_iteration.sh <story_id> <iteration_id>`.
- When opening a pull request for a given ticket, move the ticket to ready for review.

## Scripts
- `scripts/shortcut_search.sh "<keywords>" [page_size]`
- `scripts/shortcut_set_in_progress.sh <story_id>`
- `scripts/shortcut_set_ready_for_review.sh <story_id>`
- `scripts/shortcut_get_member.sh <member_id>`
- `scripts/shortcut_get_story.sh <story_id>`
- `scripts/shortcut_list_projects.sh [name_regex]`
- `scripts/shortcut_list_groups.sh [name_regex]`
- `scripts/shortcut_list_workflows.sh [name_regex]`
- `scripts/shortcut_list_members.sh [name_or_email_regex]`
- `scripts/shortcut_list_stories_by_label.sh "<label_name>" [page_size]`
- `scripts/shortcut_create_story.sh "<name>" "<description>" <story_type> [workflow_state_id] [group_id] [owner_ids_csv]`
- `scripts/shortcut_set_group_and_owner.sh <story_id> [group_id] [owner_ids_csv]`
- `scripts/shortcut_list_iterations.sh [name_regex]`
- `scripts/shortcut_get_current_iteration.sh`
- `scripts/shortcut_set_iteration.sh <story_id> <iteration_id>`

All scripts respect:
- `SHORTCUT_API_TOKEN` (required)
- `SHORTCUT_ENV_FILE` (optional path override for `.env`, default `manage-shortcut-stories/.env`)
- `SHORTCUT_API_BASE_URL` (optional override)
- `SHORTCUT_UPDATE_METHOD` (optional, default `PUT`)
- `SHORTCUT_STARTED_STATE_ID` and `SHORTCUT_READY_FOR_REVIEW_STATE_ID` (optional overrides)
- `SHORTCUT_WORKFLOW_ID` (optional, default from `references/shortcut-config.md` for search filtering)
- `SHORTCUT_SEARCH_DETAIL` (optional, default `full`)
- `SHORTCUT_PROJECT_ID` (optional, used by create script)
- `SHORTCUT_WORKFLOW_STATE_ID` (optional, used by create script)
- `SHORTCUT_GROUP_ID` and `SHORTCUT_OWNER_IDS` (optional, used by update/create scripts)
- `SHORTCUT_INCLUDE_ARCHIVED` (optional, list scripts include archived when set to `1`)
- `SHORTCUT_DRY_RUN` (optional, when set to `1` prints payload without modifying data)

## Task: Find Matching Story
- First check the current branch for a Shortcut ID pattern `sc-<id>-`.
- If found, fetch the story details and prompt the user to confirm it matches this thread.
- Only fall back to keyword search if the branch check is missing or rejected.
- Extract candidate keywords from the thread (feature name, repo/module, error strings, component names, service names).
- If results are ambiguous or too broad, prompt the user for 2-5 more keywords.
- Build a query string by joining keywords with spaces. Avoid stop words.
- Call the Shortcut search endpoint and request a short page size (10-20).
- Filter results by `workflow_id` client-side when `SHORTCUT_WORKFLOW_ID` is set.
- Present the top 3-5 results with `id`, `name`, `workflow_state_id`, `owner_ids`, and `updated_at`.
- If multiple candidates remain, ask the user to pick the correct story.
- Always return at least the story `id` once selected.

### Branch Extraction Example
```bash
branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$branch" =~ sc-([0-9]+)- ]]; then
  story_id="${BASH_REMATCH[1]}"
  echo "Found story ID: $story_id"
fi
```
If `story_id` is found, use the `shortcut-story-details` skill to fetch and show the title and owners, then ask the user to confirm.

### API Example (search)
```bash
curl -sS -G "$SHORTCUT_API_BASE_URL/search/stories" \
  -H "Shortcut-Token: $SHORTCUT_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data-urlencode "query=<keywords>" \
  --data-urlencode "page_size=10" \
  --data-urlencode "detail=full"
```
Use `scripts/shortcut_search.sh` for a debuggable version of this call.

If the endpoint, HTTP method, or response fields differ, ask the user for their Shortcut API details or docs and adjust.

## Task: Create Story
- Use when no existing story matches or the user requests a new ticket.
- Provide either `project_id` or `workflow_state_id`.
- If projects are not used, pick a workflow state from the workflows list (often "Unstarted").
- Use the create script and include `group_id`/`owner_ids` if needed.

### API Example (create)
```bash
curl -sS -X POST "$SHORTCUT_API_BASE_URL/stories" \
  -H "Shortcut-Token: $SHORTCUT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"<title>","story_type":"bug","workflow_state_id":500004424}'
```
Use `scripts/shortcut_create_story.sh` for a debuggable version of this call.

## Task: List Projects
- Use when the user wants to pick a project ID.
- List projects and filter by name when possible.

### API Example (projects)
```bash
curl -sS "$SHORTCUT_API_BASE_URL/projects" \
  -H "Shortcut-Token: $SHORTCUT_API_TOKEN"
```
Use `scripts/shortcut_list_projects.sh` for a debuggable version of this call.

## Task: List Teams (Groups)
- "Teams" in the Shortcut UI map to `group_id` values in the API.
- List groups and filter by team name to find the correct `group_id`.

### API Example (groups)
```bash
curl -sS "$SHORTCUT_API_BASE_URL/groups" \
  -H "Shortcut-Token: $SHORTCUT_API_TOKEN"
```
Use `scripts/shortcut_list_groups.sh` for a debuggable version of this call.

## Task: List Workflows and States
- Use when you need a `workflow_state_id` for story creation or transitions.
- If no project is set, select an appropriate default state (often "Unstarted").

### API Example (workflows)
```bash
curl -sS "$SHORTCUT_API_BASE_URL/workflows" \
  -H "Shortcut-Token: $SHORTCUT_API_TOKEN"
```
Use `scripts/shortcut_list_workflows.sh` for a debuggable version of this call.

## Task: List Members
- Use when you need owner IDs for assignment.
- Filter by name or email to find the correct member.

### API Example (members)
```bash
curl -sS "$SHORTCUT_API_BASE_URL/members" \
  -H "Shortcut-Token: $SHORTCUT_API_TOKEN"
```
Use `scripts/shortcut_list_members.sh` for a debuggable version of this call.

## Task: List Stories by Label
- Use when you need all stories/tickets for a given label.
- The script paginates through all results using Shortcut search `next` cursors.
- Default query is exact label match (`label:"<label_name>"`).
- By default archived stories are excluded; set `SHORTCUT_INCLUDE_ARCHIVED=1` to include them.
- Optional workflow filtering is respected via `SHORTCUT_WORKFLOW_ID`.

### API Example (label search)
```bash
curl -sS -G "$SHORTCUT_API_BASE_URL/search/stories" \
  -H "Shortcut-Token: $SHORTCUT_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data-urlencode "query=label:\"<label_name>\"" \
  --data-urlencode "page_size=25" \
  --data-urlencode "detail=full"
```
Use `scripts/shortcut_list_stories_by_label.sh` for a paginated, debuggable version of this call.

## Task: Move Story to In-Progress
- Use the started state ID from `references/shortcut-config.md`.
- Update the story with `workflow_state_id`.

### API Example (update)
```bash
curl -sS -X PUT "$SHORTCUT_API_BASE_URL/stories/<story_id>" \
  -H "Shortcut-Token: $SHORTCUT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"workflow_state_id":500004425}'
```
If your API requires `PATCH` instead of `PUT`, swap the method.
Use `scripts/shortcut_set_in_progress.sh` for a debuggable version of this call.

## Task: Move Story to Ready for Review
- Use the ready-for-review state ID from `references/shortcut-config.md`.

### API Example (update)
```bash
curl -sS -X PUT "$SHORTCUT_API_BASE_URL/stories/<story_id>" \
  -H "Shortcut-Token: $SHORTCUT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"workflow_state_id":500005151}'
```
If your API requires `PATCH` instead of `PUT`, swap the method.
Use `scripts/shortcut_set_ready_for_review.sh` for a debuggable version of this call.

## Task: Assign Team and Owner
- Use when the user wants the story assigned to a team or owner.
- List groups for the team `group_id` and list members for owner IDs.
- Update the story with `group_id` and `owner_ids`.

### API Example (update)
```bash
curl -sS -X PUT "$SHORTCUT_API_BASE_URL/stories/<story_id>" \
  -H "Shortcut-Token: $SHORTCUT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"group_id":"<group_uuid>","owner_ids":["<member_uuid>"]}'
```
Use `scripts/shortcut_set_group_and_owner.sh` for a debuggable version of this call.

## Task: List Iterations
- Use when you need to find an iteration by name or list all iterations.
- Supports optional name filtering via regex.

### API Example (iterations)
```bash
curl -sS "$SHORTCUT_API_BASE_URL/iterations" \
  -H "Shortcut-Token: $SHORTCUT_API_TOKEN"
```
Use `scripts/shortcut_list_iterations.sh` for a debuggable version of this call.

## Task: Get Current Iteration
- Use when you need to find the active/started iteration (e.g., to assign a story to the current sprint).
- Lists all iterations and filters for `status == "started"`.
- Exits with code 1 if no current iteration is found.

Use `scripts/shortcut_get_current_iteration.sh` to find the current iteration.

## Task: Set Story Iteration
- Use when you need to assign a story to an iteration (sprint).
- First find the target iteration ID using `shortcut_get_current_iteration.sh` or `shortcut_list_iterations.sh`.
- Then update the story with the iteration ID.
- Supports `SHORTCUT_DRY_RUN=1` to preview the payload without making changes.

### API Example (set iteration)
```bash
curl -sS -X PUT "$SHORTCUT_API_BASE_URL/stories/<story_id>" \
  -H "Shortcut-Token: $SHORTCUT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"iteration_id":<iteration_id>}'
```
Use `scripts/shortcut_set_iteration.sh` for a debuggable version of this call.

## Task: Resolve Owner Details
- Given a story `owner_ids` entry, fetch the member details from the Shortcut API.
- Present the member `id`, `name`, `profile` (if present), and `email` (if present).

### API Example (member lookup)
```bash
curl -sS -X GET "$SHORTCUT_API_BASE_URL/members/<member_id>" \
  -H "Shortcut-Token: $SHORTCUT_API_TOKEN" \
  -H "Content-Type: application/json"
```
Use `scripts/shortcut_get_member.sh` for a debuggable version of this call.

## Task: Fetch Story by ID
- Accept a numeric story ID.
- Call `GET /api/v3/stories/<story_id>`.
- Present at least `id`, `name`, `workflow_state_id`, `workflow_id`, `owner_ids`, and `updated_at`.

### API Example (story lookup)
```bash
curl -sS -X GET "$SHORTCUT_API_BASE_URL/stories/<story_id>" \
  -H "Shortcut-Token: $SHORTCUT_API_TOKEN" \
  -H "Content-Type: application/json"
```
Use `scripts/shortcut_get_story.sh` for a debuggable version of this call.

## Error Handling
- 401/403: token missing or invalid. Ask the user to confirm `SHORTCUT_API_TOKEN`.
- 404: story not found. Confirm the story ID.
- 400: missing `project_id` and `workflow_state_id` on create. Ask for a project or workflow state.
- Other non-2xx: ask the user to confirm the API base URL or provide docs.

## References
- `references/shortcut-config.md`
