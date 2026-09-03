---
name: gh-debug-actions
description: Debug GitHub Actions workflow runs and deployments by locating the relevant run, fetching logs (full or failed-only), and summarizing root causes. Use when asked to debug failed GitHub Actions runs, explain why a workflow run failed, retrieve logs, or investigate CI/CD deployments. Supports default repos Giftbit/lightrail and Giftbit/giftbitfe, and any explicitly specified repo.
---

# GitHub Actions Debugging

## Overview
Identify the correct workflow run, pull logs with `gh`, and provide either raw logs or a concise failure analysis with key excerpts.

## Workflow

### 1) Confirm Access
- Verify `gh` authentication first:
  - `gh auth status -h github.com`
  - If not logged in: `gh auth login`
- If access is missing, ask the user to authenticate or request repo access.

### 2) Determine the Target Repo
Use the following priority order:
1. Use the repo explicitly named by the user.
2. If running inside a git repo, derive it:
   - `gh repo view --json nameWithOwner -q .nameWithOwner`
3. If none, default to this fallback list:
   - `Giftbit/lightrail`
   - `Giftbit/giftbitfe`
If still ambiguous, ask which repo to inspect.

### 3) Identify the Run
Preferred signals (use in order of specificity):
- Run ID or URL mentioned by the user
- Workflow name (`-w`) and branch (`-b`)
- User who triggered the run (`-u`) when the prompt mentions a specific developer
- Recent failed runs (`-s failure`) if no other filters are provided

Common query patterns:
- Latest failed run for a workflow:
  - `gh run list -R <owner/repo> -w "<workflow name>" -s failure -L 5`
- Latest failed run on a branch:
  - `gh run list -R <owner/repo> -b <branch> -s failure -L 5`
- Latest failed run for a user:
  - `gh run list -R <owner/repo> -u <github-username> -s failure -L 5`

If multiple candidates exist, ask for confirmation before fetching large logs.

### 4) Fetch Logs
Use `gh run view` to pull logs:
- Full logs: `gh run view <run-id> -R <owner/repo> --log`
- Failed steps only: `gh run view <run-id> -R <owner/repo> --log-failed`

Prefer `--log-failed` when the user asks “why did it fail?” or wants a summary. Prefer full logs when they explicitly ask for raw logs.

If logs are missing (e.g., `log not found` for a job), use these fallbacks:
- Download the full run log archive and inspect locally:
  - `gh api /repos/<owner>/<repo>/actions/runs/<run-id>/logs > /tmp/run-<id>-logs.zip`
- Pull the job’s check-run annotations for a concise failure reason:
  - `gh run view <run-id> -R <owner/repo> --json jobs -q '.jobs[].databaseId'`
  - `gh api /repos/<owner>/<repo>/check-runs/<job-id>/annotations`
- If the check-run includes a deployment, inspect deployment status:
  - `gh api /repos/<owner>/<repo>/check-runs/<job-id>`
  - `gh api /repos/<owner>/<repo>/deployments/<deployment-id>/statuses`

Use the helper script when you want consistent, repeatable log capture:
- `scripts/gh_run_logs.sh` (see Resources)

### 5) Respond with the Right Output Shape
- **Raw logs requested**: provide the log output or write it to a file and point to the file path.
- **Debugging/summary requested**: summarize root cause, include key log excerpts, and list likely next actions.

Summary format guidance:
- Run metadata (repo, workflow, run id, branch, conclusion)
- Failing job/step name
- 3–8 lines of log excerpt showing the error
- Likely root cause in 1–2 sentences
- Suggested next steps (code change, infra change, retry, or open issue)

## Resources
- `scripts/gh_run_logs.sh` — fetches logs for the latest matching run (or an explicit run id)
- `references/gh-actions-cli.md` — `gh` command patterns, fields, and log caveats
