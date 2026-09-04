---
name: link
description: Link every skill in skills/ and work-skills/ into ~/.claude/skills. Use when a skill has been added, removed, renamed, or moved between the two directories, when links in ~/.claude/skills are stale or dangling, or when setting this repo up on a new machine.
---

# link

Skills live in two places in this repo — `skills/` (personal) and `work-skills/`
(the Giftbit/agent-skills subtree) — so `~/.claude/skills` is a real directory
holding one symlink per skill rather than a single link to one source.

## Run it

```sh
.claude/skills/link/link.sh
```

Pass a different destination as the first argument to link somewhere else.

## What it does

Idempotent. Safe to re-run at any time.

- Links each directory under `skills/` and `work-skills/` into the destination.
- Prunes links it owns (target inside this repo) that no longer resolve, so a
  deleted or moved skill does not linger as a dangling link.
- Repoints links it owns whose target has changed.

## What it refuses to touch

Each is reported on stderr and skipped, never overwritten:

- A name present in both source dirs — `skills/` wins, the work version is
  reported as shadowed.
- A destination entry that exists but is not a symlink.
- A symlink pointing outside this repo — someone else owns it.

## Verifying

```sh
ls -la ~/.claude/skills
```

Every target should resolve. Dangling links after a run mean the skill was
removed from both source dirs but the link is not ours to prune.
