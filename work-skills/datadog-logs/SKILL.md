---
name: datadog-logs
description: Interact with Datadog Logs via the Datadog API using bash scripts for searching, tailing, aggregating, and exporting error logs. Use for generic prompts like "fetch logs", "search logs", "tail logs", "export logs", or "count/aggregate logs" (including time windows such as "last 24 hours") and filters like service/environment (for example "api service in production"), even when the user does not explicitly mention Datadog or the skill name.
---

# Datadog Logs

## Overview

Use this skill to query Datadog Logs for error-focused workflows with bash scripts that call the Datadog API directly.

## Quick Start

- Create `datadog-logs/.env` from `datadog-logs/.env.example` and set `DD_API_KEY`, `DD_APP_KEY`, and `DD_SITE` (default is `us3`).
- Run a search:
  - `./scripts/logs_search.sh --service api --env production --last 60`
- Tail recent errors:
  - `./scripts/logs_tail.sh --service api --env production --interval 15`
- Aggregate counts by service:
  - `./scripts/logs_aggregate.sh --env production --last 1440 --group-by service`
- Export to CSV:
  - `./scripts/logs_export.sh --env production --last 1440 --format csv --out /tmp/error_logs.csv`

## Tasks

### Search Error Logs

- Run `./scripts/logs_search.sh` to search recent errors.
- Pass `--query` for additional filters (for example: `--query 'team:platform @http.status_code:500'`).
- Use `--since`/`--until` with RFC3339 timestamps for precise windows.

### Tail Error Logs

- Run `./scripts/logs_tail.sh` to poll for new error logs.
- Adjust `--interval` (seconds) and `--window` (seconds) to control polling cadence and initial lookback.

### Aggregate Error Logs

- Run `./scripts/logs_aggregate.sh` to group counts by a facet (default `service`).
- Use `--group-by env` or `--group-by host` to change the facet.

### Export Error Logs

- Run `./scripts/logs_export.sh` for NDJSON (`--format json`) or CSV (`--format csv`).
- Use `--all` to paginate and export more than one page.

## Configuration

- Use `datadog-logs/.env.example` as the template for `datadog-logs/.env`.
- Use `--env-file` to point scripts at a specific env file.
- Keep secrets in `.env`; do not commit real keys.

## Query Notes

- Default query includes `status:error` and adds `service:` and `environment:` when provided.
- Append additional filters with `--query`.

## Resources

### scripts/

- `common.sh`: shared helpers (env loading, Datadog base URL, time helpers, curl wrapper).
- `logs_search.sh`: search error logs with time windows.
- `logs_tail.sh`: poll for new error logs.
- `logs_aggregate.sh`: aggregate counts by facet.
- `logs_export.sh`: export results to NDJSON or CSV.

### references/

- `api_notes.md`: Datadog Logs API endpoint notes and payload shapes.
