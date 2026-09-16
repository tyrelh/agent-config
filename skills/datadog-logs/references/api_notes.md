# Datadog Logs API Notes

## Base URL

Use `https://api.us3.datadoghq.com/api` (from `DD_API_BASE`).

## Auth Headers

- `DD-API-KEY: $DD_API_KEY`
- `DD-APPLICATION-KEY: $DD_APP_KEY`
- `Content-Type: application/json`

## Endpoints Used

- Search logs: `POST /v2/logs/events/search`
- Aggregate logs: `POST /v2/logs/aggregate`

## Payload Shapes (high level)

Search:

```
{
  "filter": {
    "from": "2026-02-04T00:00:00Z",
    "to": "2026-02-04T01:00:00Z",
    "query": "status:error service:api env:prod"
  },
  "sort": "-timestamp",
  "page": {"limit": 100, "cursor": "..."}
}
```

Aggregate:

```
{
  "filter": {
    "from": "2026-02-04T00:00:00Z",
    "to": "2026-02-04T01:00:00Z",
    "query": "status:error env:prod"
  },
  "compute": [{"aggregation": "count"}],
  "group_by": [{"facet": "service"}]
}
```

## Query Tips

- `status:error` is a good base filter for error logs.
- Add `service:<name>` and `environment:<name>` to narrow results.
- Append other filters with `--query` (for example `team:platform @http.status_code:500`).
