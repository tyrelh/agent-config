---
name: todo
description: Add, list, or check off tasks in Tyrel's Obsidian vault (the current term log note). Use whenever the user asks to add or capture a todo or task, list today's todos, or check one off — "add a todo", "add a task", "todo: X", "what are my todos", /todo. This is the user's real personal task list in Obsidian, NOT the session TodoWrite list and NOT Notion or Shortcut; prefer this skill over those unless the user names Notion or Shortcut.
---

# Todo

Today's tasks live under `## Tasks` in the current term log note. Vault layout and note structure are in the `obsidian` skill — read it if anything below needs context.

## Script

The shared daily-note editor, `~/.claude/skills/obsidian/scripts/daily-note.sh`:

```bash
daily-note.sh add    Tasks "<task text>"    # insert at the top of today's Tasks list
daily-note.sh list   Tasks                  # print today's Tasks list
daily-note.sh done   Tasks "<substring>"    # check off first open task containing substring
```

It edits the markdown file on disk; Obsidian does not need to be running. Overrides: `NOTES=~/Notes`, `TODO_DAY="Thu Sep 3"`.

Exit 1 with an `ERR:` line means nothing was written — report it verbatim, don't work around it. The common one is no `# <today>` heading, i.e. the daily note template isn't inserted yet; tell the user rather than creating the section.

## Task text rules

Pass the text through verbatim — no rewording, no expanding, no tags or dates the user didn't type. Obsidian Tasks syntax (`#tag`, `📅 2026-09-10`, `⏫`) and wikilinks are already valid. `- [ ] ` is prefixed unless the text already starts with a checkbox.

`done` leaves the task in place (only `[ ]` → `[x]`) — Tyrel moves finished tasks to the bottom of the list himself.

## Output

One line: what was added or checked off, and where. For `list`, the lines as-is — no summarizing, no reordering.
