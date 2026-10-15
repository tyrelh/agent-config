# Markdown as state store

Use an Obsidian note section as both human-readable UI and machine-readable state for automation. The cron job (or a companion script) reads the markdown, parses headings as records, diffs them against an external source, and writes surgical edits back.

## When this pattern fits

- Tracking external data that changes over time (job postings, releases, prices, inventory).
- The user wants the data visible and editable in Obsidian, not locked in a JSON file.
- Diffs are per-record (new items, closed items, updated timestamps), not full-table overwrites.

## Structure

Use H2 for the category/company and H3 for each tracked item. Bullets hold fields.

```markdown
## Tailscale
### Tailscale - Infrastructure Engineer
- [Posting](https://job-boards.greenhouse.io/tailscale/jobs/4733403005) (Discovered Oct 14 2026)
- ID: 4733403005
- First seen: Oct 14 2026
- Last seen: Oct 14 2026
- Location(s): Remote (Canada), Remote (United States)
- Status: 🆕 New
```

Rules:
- Keep one durable identifier in a bullet (e.g., `- ID: 12345` or extract an ID from the `[Posting](URL)` link) so the parser can match records across runs even if the H3 title changes.
- Append state-change markers as new bullets rather than rewriting history, so the user sees the timeline:
  - `- 🚪 No longer listed on careers page (Oct 15 2026)`
  - `- ✅ Applied Oct 16 2026`
- Leave a blank line after each H3 block so inserts are clean.

## Companion script conventions

Put the fetch/parse/diff/write logic in a standalone Python script, not in the cron prompt. The script should:

1. Accept `--note <path>` and `--apply` flags. Without `--apply`, it prints a JSON diff and exits 1 when there are no changes.
2. Exit 0 when changes were applied (or would be applied in dry-run), exit 2 on error. This lets the cron prompt decide whether to notify.
3. Parse the markdown by scanning lines: find the H2, then walk H3 blocks until the next H1/H2 or EOF.
4. Make surgical edits: insert new H3s at the end of the section, append marker bullets to existing H3s, update specific bullets in place.
5. Write the full file back with `path.write_text("\n".join(lines) + "\n", encoding="utf-8")`.

## Cron prompt shape

Keep the cron prompt thin. Its only job is to run the script, parse the JSON output, and post a summary when `new` or `closed` is non-empty:

```
Run: python3 ~/.hermes/scripts/my_watcher.py --apply --note "$OBSIDIAN_VAULT_PATH/inbox/Note.md"

If exit 2, post a failure notice.
If exit 0, parse the JSON. Post a summary only when new or closed items exist.
If exit 1, stay silent.
```

## Status-driven exclusion

Use a `Status:` bullet to let the user mute an entry without deleting it. The companion script should recognize these emojis and skip the entry on all future operations:

| Emoji | Meaning | Script behavior |
|---|---|---|
| `🚫` | Ignored | Do not re-add if removed from API; do not mark closed; do not update `Last seen` |
| `⏭️` | Passed | Same as Ignored — the user saw it and chose not to act |

Example:
```markdown
- Status: ⏭️ Passed
```

## Conventions

- **Manual entries** use `(Saw {date})` on the posting link; **auto-discovered entries** use `(Discovered {date})`. This makes it obvious which items were added by hand vs by the cron.
- The status regex must match both `Status: ✅ Applied` and bare `✅ Applied` because manual entries may not have the `Status:` prefix. Use `(?:Status:\s*)?` in the pattern.

## Pitfalls

- Do not use `obsidian eval` or the Obsidian API to write. Write to the file directly and let Obsidian pick up the change on disk.
- If the note is open in Obsidian with unsaved edits, the app buffer can win. Prefer one write, then verify with `grep`.
- When inserting new H3s, place them before the next H1/H2 (or a `# Archive` sentinel), not at the very end of the file.
- Avoid duplicating an item that was already tracked under a different H3 title. Match by durable ID, not by title string.
- A status regex that only matches `Status: ✅` will miss bare `✅ Applied` lines and treat manual entries as untracked. Make the `Status:` prefix optional.
