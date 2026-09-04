---
name: obsidian
description: Map of Tyrel's Obsidian vault at ~/Notes — where notes live, the term log / daily note structure, and when to use the obsidian CLI vs editing files directly. Load before reading or writing anything in the vault, and alongside obsidian-cli, obsidian-markdown, or obsidian-bases.
---

# Obsidian vault

Vault root: `~/Notes`. It has its own `AGENTS.md` (`~/Notes/AGENTS.md`) — read it for conventions; this skill is the operational layer on top.

## Related skills

- `obsidian-cli` — the `obsidian` CLI: search, read, tasks, properties, plugin dev. Requires Obsidian running.
- `obsidian-markdown` — Obsidian Flavored Markdown: wikilinks, embeds, callouts, properties.
- `obsidian-bases` — `.base` files: views, filters, formulas.

## Layout

| Path | Holds |
|---|---|
| `~/Notes/inbox/` | Term logs, plus any new standalone note (clearly named) |
| `~/Notes/notes/`, `topics/`, `projects/`, `books/` | Long-lived notes |
| `~/Notes/templates/insertable/daily note.md` | The daily note template |
| `~/Notes/archive/` | Old material — don't write here |

## Term log (the running daily note)

One note per term (a third of a year), in `~/Notes/inbox/`, named `T<n> <year>.md` — older quarterly ones are `Q<n> <year>.md`. **The current one has `now` in the filename**: `T3 2026 now.md`. Find it with `ls ~/Notes/inbox/*now*.md`; expect exactly one match and stop if that isn't true.

Structure — first H1 is persistent term notes, every H1 after it is one day, **newest first**:

```markdown
# T3 2026              <- persistent notes/links for the whole term
## 📅 Upcoming things
## Misc

---
# Fri Sep 4            <- today, format: ddd MMM D (no leading zero)
## Meetings
- [ ] 9:10: Standup 🟢🟡🔴 🏆😞
## Tasks
- [ ] newest task first
- [x] checked-off tasks get moved to the bottom of the list by hand
## Notes
## Left off
## Personal

---
# Thu Sep 3            <- yesterday, and so on down to the start of the term
```

A new day is started by inserting `templates/insertable/daily note.md` above the previous day's H1 (below the persistent notes). Don't create a day section as a side effect of another task — if today's H1 is missing, say so.

## Editing today's note

`scripts/daily-note.sh` (in this skill) is the one editor for sections of today's H1 in the term log. Use it instead of hand-rolling another file walk:

```bash
daily-note.sh list   Notes                    # print a section
daily-note.sh add    Tasks "write the thing"  # insert at the TOP of a section
daily-note.sh append Notes "[[Some note]]"    # insert at the BOTTOM of a section
daily-note.sh done   Tasks "write the"        # check off first open task matching
```

Sections are the H2s under today's H1: `Meetings`, `Tasks`, `Notes`, `Left off`, `Personal`. `add`/`append` to `Tasks` get a `- [ ] ` prefix; other sections take the text as-is. Overrides: `NOTES=~/Notes`, `TODO_DAY="Thu Sep 3"`. Exit 1 with an `ERR:` line means nothing was written — no `# <today>` heading (template not inserted yet) or no such section.

Callers: the `todo` skill, and `hooks/save-plan.sh` in the agent-config repo.

## Plans

`PostToolUse:ExitPlanMode` runs `hooks/save-plan.sh` (agent-config repo, symlinked to `~/.claude/hooks`), which copies the plan Claude Code wrote in `~/.claude/plans/` into `~/Notes/Plans/<date> <title>.md` with frontmatter (repo, branch, cwd, session, source) and appends `[[<plan name>]]` to today's `## Notes`. Re-approving a revised plan overwrites the same vault file — it is matched on the `source:` line — and does not add a second link.

## CLI vs direct file edits

**Read and edit the markdown files directly** for anything structural: inserting mid-document, editing a specific section, rewriting a list. Plain file edits, `sed`/`awk`, or the Edit tool.

Do **not** write through `obsidian eval` / `app.vault.process`. Verified failure (Sep 4 2026): writes to a note that was open in the app landed in the editor buffer only, read back fine through the API, and were then lost when the buffer reloaded from disk — file mtime never changed. Writes must go to disk.

Use the CLI for what it does better than a file walk, all read-only:

```bash
obsidian search:context query="text" limit=5   # vault-wide search with context
obsidian tasks todo verbose                    # tasks across the vault
obsidian outline path="inbox/T3 2026 now.md"   # heading map of a note
obsidian backlinks file="Note"                 # links in / out
obsidian history path="..."                    # local version history (recovery)
```

Obsidian picks up external file changes on its own. If a note is open with unsaved edits, the app's buffer can still win — prefer one write, then verify with `grep` on the file.
