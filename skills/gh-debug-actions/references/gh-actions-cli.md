# GitHub Actions CLI Quick Reference

## Common Commands
- List runs (filter by workflow/branch/user):
  - `gh run list -R <owner/repo> -w "<workflow>" -b <branch> -u <user> -s failure -L 10`
- View a run summary:
  - `gh run view <run-id> -R <owner/repo>`
- View full logs for a run:
  - `gh run view <run-id> -R <owner/repo> --log`
- View only failed steps:
  - `gh run view <run-id> -R <owner/repo> --log-failed`
- Download full run log archive (when job logs are missing):
  - `gh api /repos/<owner>/<repo>/actions/runs/<run-id>/logs > /tmp/run-<id>-logs.zip`
- Check-run annotations (often the only failure reason for “log not found” jobs):
  - `gh api /repos/<owner>/<repo>/check-runs/<job-id>/annotations`
- Deployment status for protected environments:
  - `gh api /repos/<owner>/<repo>/check-runs/<job-id>`
  - `gh api /repos/<owner>/<repo>/deployments/<deployment-id>/statuses`

## Useful JSON Fields (gh run list --json)
`databaseId, displayTitle, createdAt, conclusion, status, headBranch, workflowName, event, url`

## Log Caveats
- `gh run view --log` may show `UNKNOWN STEP` for lines that cannot be matched to a step.
- Large runs can take time to stream logs. Prefer `--log-failed` for summaries.
- If runs are created by ruleset workflows, the workflow name may be missing in list output.
