---
name: link
description: Link every skill in skills/ into ~/.claude/skills. Use when a skill has been added, removed, renamed, or moved, when links in ~/.claude/skills are stale or dangling, or when setting this repo up on a new machine.
---

# link

Skills live in `skills/` in this repo. `~/.claude/skills` is a real directory
holding one symlink per skill rather than a single link to that directory, so
skills added there by hand keep working.

## Run it

```sh
.claude/skills/link/link.sh
```

Pass a different destination as the first argument to link somewhere else.

## What it does

Idempotent. Safe to re-run at any time.

- Links each directory under `skills/` into the destination.
- Prunes links it owns (target inside this repo) that no longer resolve, so a
  deleted or moved skill does not linger as a dangling link.
- Repoints links it owns whose target has changed.

## What it refuses to touch

Each is reported on stderr and skipped, never overwritten:

- A destination entry that exists but is not a symlink.
- A symlink pointing outside this repo — someone else owns it.

## Verifying

```sh
ls -la ~/.claude/skills
```

Every target should resolve. Dangling links after a run mean the skill was
removed from `skills/` but the link is not ours to prune.
