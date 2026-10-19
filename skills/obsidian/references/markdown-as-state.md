# Markdown as state store

Use an Obsidian note section as both human-readable UI and machine-readable state for automation. The cron job (or a companion script) reads the markdown, parses headings as records, diffs them against an external source, and writes surgical edits back.

## When this pattern fits

- Tracking external data that changes over time (job postings, releases, prices, inventory).
- The user wants the data visible and editable in Obsidian, not locked in a JSON file.
- Diffs are per-record (new items, closed items, updated timestamps), not full-table overwrites.

## Structure

Use H2 for the category/company and H3 for each tracked item. Bullets hold fields. Low-value records that are still live collapse into one-liners under an H4 list at the end of the H2 (see "Secondary lists").

```markdown
## Tailscale
### Tailscale - Infrastructure Engineer
- [Posting](https://job-boards.greenhouse.io/tailscale/jobs/4733403005) (Discovered Oct 14 2026)
- ID: 4733403005
- First seen: Oct 14 2026
- Last seen: Oct 14 2026
- Location(s): Remote (Canada), Remote (United States)
- Status: 🆕 New

#### Disqualified
- 🗑️ 4/10 [Software Engineer, Networking (Features)](https://job-boards.greenhouse.io/tailscale/jobs/4739666005) · Last seen Oct 18 2026 · reason
```

Rules:
- The primary key is the source's own record ID. Keep it in a `- ID:` bullet or derive it from the record's link (`id_from_url`); a link alone is enough, so one-liners need no ID field.
- Which list a record is on is decided by WHERE its ID sits (active H3 block, secondary H4 list, anywhere under `# Archive`, or nowhere = new), not by a stored state field. The status emoji is a secondary signal; when it disagrees with position, position wins.
- Append state-change markers as new bullets rather than rewriting history, so the user sees the timeline:
  - `- 🚪 No longer listed on careers page (Oct 15 2026)`
  - `- ✅ Applied Oct 16 2026`
- Leave a blank line after each H3 block so inserts are clean.

## Companion script conventions

Put the fetch/parse/diff/write logic in a standalone Python script, not in the cron prompt. The script should:

1. Accept `--note <path>` and `--apply` flags. Without `--apply`, it prints a JSON diff and exits 1 when there are no changes.
2. Exit 0 when there is something to report, 1 when nothing is reportable (it may still have written housekeeping edits), 2 on error. This lets the cron prompt decide whether to notify.
3. Parse the markdown by scanning lines: find the H2, then walk H3 blocks until the next H1/H2 or EOF (or the secondary-list H4).
4. Make surgical edits through an edit set keyed by ORIGINAL line numbers (insert-before, replace, delete), rendered in one pass.
5. Before writing, re-read the file and bail if it changed since the run started; write the full file back with `path.write_text("\n".join(lines) + "\n", encoding="utf-8")`.

## Changing a watcher script

1. Read the whole script and the cron prompt (`jobs.json` under `~/.hermes/cron/` has the full prompt; `cronjob_manage list` only shows a preview).
2. Back up the script (`cp x.py x.py.pre-<change>`) and the note into the scratch dir.
3. Edit, then test against a scratch COPY of the note with `--note` (live API fetches are fine, writes go only to the copy): run `check --apply`, inspect the file, run it again and `diff` to prove idempotence, then exercise each subcommand on a doctored copy (e.g. reset a fit line to its `{...}/10` slot, inject a fake closed record, delete a block so it reappears as new).
4. Only then run on the real note, so migrations land immediately instead of at the next cron fire.
5. Keep new report keys for housekeeping (`moved`, `dropped`) out of the "reportable" exit-0 test so the cron doesn't notify on them.

## Cron prompt shape

Keep the cron prompt thin. Its only job is to run the script, parse the JSON output, and post a summary when `new` or `closed` is non-empty:

```
Run: python3 ~/.hermes/scripts/my_watcher.py --apply --note "$OBSIDIAN_VAULT_PATH/inbox/Note.md"

If exit 2, post a failure notice.
If exit 0, parse the JSON. Post a summary only when new or closed items exist.
If exit 1, stay silent.
```

## Status-driven exclusion

Use a `Status:` bullet to let the user mute an entry without deleting it:

| Emoji | Meaning | Script behavior |
|---|---|---|
| `🚫` | Not viable / ignored | Muted block: never re-added, no closed marker, no `Last seen` update |
| `⏭️` | Passed | Same as 🚫 |
| `🗑️` | Not a good fit | Collapsed into the `#### Disqualified` one-liner list and still tracked (see below) |

The status regex must match both `Status: ✅ Applied` and bare `✅ Applied` because manual entries may not have the `Status:` prefix. Use `(?:Status:\s*)?` in the pattern.

## Secondary lists (active but uninteresting records)

To get still-live but rejected records out of the main list without losing track of them, collapse each into a one-liner under an H4 at the end of its H2, e.g. `#### Disqualified`:

- Format: `- {emoji} {score}/10 [{title}]({url}) · Last seen {date} · {reason}`. Replace `[`/`]` in titles and `·` in reasons so the line stays parseable.
- `check` keeps each one-liner's `Last seen` current and DELETES the line once the ID leaves the source, so the list only shows live records.
- Any H3 block with the collapsing status (set by the rule, by hand, or by an older script version) is converted on the next `check`; that doubles as the migration path.
- The subcommand that applies the rule (e.g. `fit` scoring at/below threshold) collapses the block in the same write. Subcommands that find the ID in the secondary list exit 1 ("exists"/"already muted") rather than 2 ("not found").
- Insert new H3 records at the end of the ACTIVE area (above the H4), and when the H4 doesn't exist yet, insert new records before creating the heading at the same index.

## Conventions

- **Manual entries** use `(Saw {date})` on the posting link; **auto-discovered entries** use `(Discovered {date})`. This makes it obvious which items were added by hand vs by the cron.

## Pitfalls

- Do not use `obsidian eval` or the Obsidian API to write. Write to the file directly and let Obsidian pick up the change on disk.
- If the note is open in Obsidian with unsaved edits, the app buffer can win. Prefer one write, then verify with `grep`.
- When inserting new H3s, place them before the next H1/H2 (or a `# Archive` sentinel), not at the very end of the file.
- Avoid duplicating an item that was already tracked under a different H3 title. Match by durable ID, not by title string.
- Never mix `lines.insert()` with later edits addressed by line numbers parsed earlier: each insert shifts every later index, so the following replace lands one line too high. Collect edits keyed by ORIGINAL line numbers (inserts-before-index, replacements, deletes) and render the file in a single pass.
- Make the H3 parser stop at the secondary-list H4: `^###\s` doesn't match `####`, so without an explicit boundary every line under the H4 is attributed to the last H3 block, and a link regex that searches anywhere in the line steals the block's ID.
- Muting a record (skip all processing) also stops liveness tracking: its `Last seen` freezes and it never gets a closed marker. If the user wants to know a rejected record is still live, collapse it into a tracked secondary list instead of muting it.
- When deleting a block, delete its trailing blank lines too; for the LAST block in an area, delete the blank lines before it instead, and only prepend a blank spacer to a newly created heading when the last surviving line isn't already blank — otherwise double blank lines accumulate.
- Mark a record closed only when its ID is absent from the whole external source, not from the filtered set you'd add. Otherwise tightening a keyword or location filter falsely closes tracked items. Treat an empty API response as an error, never as "everything closed".
- When checking for new items, collect IDs from `- ID:` bullets AND every markdown link target anywhere in the note (including `# Archive` and one-liners), so archived or collapsed items aren't re-added.
- Give the agent a script subcommand for any field it writes (e.g. `job_watch.py fit --id ... --score ...`) instead of having it hand-edit by heading. Headings aren't unique (one employer can list the same title in two regions); IDs are.

## Multi-source watchers

The job watcher (`~/.hermes/scripts/job_watch.py` + `job_watch_employers.json`, cron "2*Daily Job Watcher") shows the shape: one config entry per source (`name` = the H2 heading, `source` adapter such as `greenhouse` or `ashby`, `board` slug, location rule), shared keyword defaults, a per-source `error` in the JSON report so one failing board doesn't block the others, and auto-creation of a missing `## {name}` section above `# Archive`. Adding a source is a config edit, not a code or prompt change.

The watcher's entry format comes from a vault template the user owns (`"template": "inbox/_Job post template.md"` in the config), re-read every run, so the user can change it without touching code. The template uses descriptive single-brace placeholders (`{employer}`, `{link to posting}`, `{unique identifier for post}`), and the script maps them by keyword. Unmatched placeholders are left in place and reported as warnings. A line containing `{...}/10` is the fit slot: it's kept as-is when the entry is inserted, and the `fit` subcommand fills it in later. If the template is missing or malformed, the script uses an embedded copy of it and warns, but only on runs that actually render an entry, so a broken template doesn't send a notification twice a day.

Location viability is a single rule in the config's `defaults`, because it's the user's constraint, not the employer's. For each location: a remote location qualifies if it mentions an allowed region (Canada, BC, North America, worldwide); a location of any workplace type qualifies if it's the home city and also mentions the home region or country, so Victoria, Australia doesn't pass for Victoria, BC. On Greenhouse, remoteness is per location name (`Remote (Canada)` vs `Hybrid (Vancouver, British Columbia)`). On Ashby, it's the posting's `workplaceType`, applied to every structured address. The rule is re-applied every run to tracked entries still at `🆕`, so filter changes clean up old entries too. Entries the user has acted on (✅, ❌, 🗑️) are never auto-muted. Description-only restrictions ("must reside in Ontario") are left to the cron agent, which records them with `job_watch.py not-viable`; 🚫 entries stay as full muted blocks.

The fit threshold follows the same pattern. Put the rule in the script, not the prompt (`"disqualify_fit_at_or_below": 5`): `fit` collapses a `🆕` entry rated at or below it into the employer's `#### Disqualified` list in the same write as the rating, and every `check` re-applies it to `🆕` entries. That way the rule covers existing entries and threshold changes, and it doesn't depend on the agent remembering. Tell the agent to record every rating rather than skipping low ones, or the rule never fires.
