# Magpie backlog ingestion (multi-day, large queue)

When daily runs were missed and the user asks for "everything since <date>".

## Re-queue the backlog

1. Daily `discover` scans only today's entry. With no H1 heading for a date it exits 0 with `NO ENTRY ... nothing discovered` — a normal result, not an error; confirm the day actually has an entry before trusting an empty queue.
2. Loop the gap in order: `python3 "$OBSIDIAN_VAULT_PATH/magpie/scripts/wiki_tool.py" discover --date YYYY-MM-DD` per date. Re-running a date that was already ingested is safe — unchanged sources don't re-queue, only changed content does.
3. `pending` for the full queue. If it is empty while `wiki/log.md` shows a gap, the missed runs never queued anything; step 2 rebuilds the queue. Nothing was lost.

## Compile a large queue

One context cannot hold every source and every note (a ~20-source, few-hundred-KB backlog already overflows it). Batch:

1. Read `magpie/schema/note-schema.md` and `magpie/schema/context.md`; `cat magpie/wiki/index.md` for the existing notes; list `magpie/wiki/topics/` for the available hubs.
2. Group pending sources into batches by theme (plans for one project together; meetings with one vendor together). Batches must have **disjoint write ownership** — no two batches may create or edit the same wiki file, or their writes collide.
3. Dispatch one subagent per batch, all in parallel. Each task's context must be self-contained — a child has none of your conversation: exact source paths (quote them; names contain spaces, em-dashes, `~`), the frontmatter contract and lint rules below, a style exemplar (tell it to read one existing good compiled note), the forbidden files (`magpie/wiki/index.md`, `magpie/wiki/log.md`, `magpie/source-ledger.csv`, `magpie/wiki/topics/*`, plus any file owned by another batch), and: self-check with `wiki_tool.py lint`, ignore only the `index ... generated region is stale` finding (the parent seals it), and do not run `finish` or `log`.
4. On return, verify each reported wiki file exists on disk. Then a single `finish "<what changed>"` call with `--ingested "<vault-relative path>"` repeated once per source actually compiled. The ledger update, index rebuild, and log entry happen only when lint is clean.
5. A batch that failed or produced unusable notes: leave its sources out of `--ingested` — they stay pending for the next run. Say so in the report.

## Lint rules (from `wiki_tool.py`)

- Required frontmatter: `tags`, `topics`, `status`, `created`, `updated`, `sources`, `source_count`.
- Exactly one role tag, and it must be one of: `topic`, `concept`, `entity`, `project`. The schema doc lists `log` as a core tag, but lint does not count it — a `log`-only note fails.
- Tags must be plain: no `#`, no `/`.
- `status` ∈ seed, active, canonical, stale, needs_review; `created`/`updated` are strict `YYYY-MM-DD`.
- Every `topics:` wikilink must resolve to a file under `magpie/wiki/topics/` — or use an empty list.
- Every non-URL `sources:` wikilink must resolve to a real vault file; quote every frontmatter wikilink entry (filenames contain spaces).
- `source_count` must equal the number of `sources` entries (`finish` fixes this mechanically before linting).
- The body must contain `## Related` and `## Sources` headings.
- Global: `wiki/index.md` must match the rendered index (`finish` rebuilds it), and `source-ledger.csv` must exist.

## Pitfalls

- `finish` assumes sources did not change between reading and sealing. In a long parallel pass, a source the user edits mid-pass gets its new hash recorded, and the next `discover` re-queues it — self-healing, but expect one extra pass.
- Do not hand-rebuild a missing `wiki_tool.py` or `source-ledger.csv` from memory: a rewritten script will not match the canonical one, and without the ledger every source re-queues. Fix the sync or clone that supplies the files, then re-run.
- The in-vault `magpie/schema/context.md` still says discovery scans only `## Notes`; the tool actually scans every `##` section of the day. Trust the tool (and this skill), not that snippet, when deciding where a link must live.
