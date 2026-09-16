---
name: review-and-apply
description: Full code review of the current branch — CodeRabbit plus correctness and quality angles run in parallel subagents, with the fan-out scaled to the size of the diff and findings verified to drop false positives — then walk the surviving findings one at a time for accept / reject / revise, committing each accepted change on its own. Use when the user asks for a full review, a review before opening a PR, or wants to review and apply fixes interactively.
argument-hint: "[<target>]  (branch, ref range, PR number, or path. Defaults to the branch diff vs main)"
---

# Review and apply

Fan out a read-only review, collate the findings, then walk them with the user
one at a time. **Nothing touches a file until the user accepts that specific
finding.** Commit each accepted change separately. Never push.

## Phase 0 — Scope and size

Default target: the branch diff vs the default branch.

```bash
git rev-parse --abbrev-ref HEAD
git status --porcelain
BASE=$(git merge-base origin/main HEAD 2>/dev/null || git merge-base main HEAD)
```

If an argument was passed, use it as the target instead (branch, ref range, PR
number, or path).

**Gather the diff exactly once** and write it to the scratchpad. Every agent
reads that file instead of re-deriving it — this is the single largest cost
saving in the skill, so do not skip it and do not let an agent run its own
`git diff`.

```bash
DIFF=<scratchpad>/review.diff
{ git diff "$BASE"...HEAD; git diff HEAD; } > "$DIFF"
git diff "$BASE"...HEAD --shortstat; git diff HEAD --shortstat
```

If the working tree is dirty with changes unrelated to the review, say so and
ask whether to continue — per-change commits get muddled otherwise. Stop for the
answer; do not stash on the user's behalf.

If the diff is empty, say so and stop.

**Size it.** Count files changed and lines changed across both diffs, then pick
the tier in Phase 1. State the tier and the agent count in one line before
launching, so the user can ask for a bigger or smaller pass.

## Phase 1 — Review (fan-out scaled to the diff)

Agents get the diff file path, the base ref, and their angle list. They are
read-only and must return findings, not edits. Tell each one explicitly to read
the diff file rather than running `git diff` itself.

An agent can work several angles — it does them in sequence in one context,
which is far cheaper than a fresh agent re-reading the same files per angle.

Launch every agent for the tier in a **single message** so they run
concurrently.

### Small — ≤3 files and ≤150 changed lines → 3 agents
| `subagent_type` | Angles |
| --- | --- |
| `coderabbit-runner` | — |
| `bug-hunter` | A (diff scan), B (removed behavior), C (cross-file) |
| `cleanup-reviewer` | all five |

### Medium — ≤10 files or ≤600 changed lines → 5 agents
| `subagent_type` | Angles |
| --- | --- |
| `coderabbit-runner` | — |
| `bug-hunter` | A, B |
| `bug-hunter` | C, D (language pitfalls) |
| `cleanup-reviewer` | reuse, simplification, altitude |
| `cleanup-reviewer` | efficiency, conventions |

### Large — anything bigger → 11 agents
One agent per angle: `coderabbit-runner`, `bug-hunter` × A/B/C/D/E,
`cleanup-reviewer` × reuse/simplification/efficiency/altitude/conventions.

### Every tier
Add a `bug-hunter` on **Angle E (wrapper/proxy correctness)** only when the diff
adds or modifies a wrapper, proxy, decorator, adapter, or cache type. Otherwise
it has nothing to look at — skip it and say so.

If the user asks for a deeper or cheaper pass, move a tier rather than
inventing a new split.

If the Agent tool is unavailable, work the tier's angles yourself in one pass
(definitions in `agents/bug-hunter.md` and `agents/cleanup-reviewer.md`), run
CodeRabbit inline, and say in your summary that the fan-out did not run — so
the user isn't misled about what ran.

## Phase 2a — Collate

Wait for all agents. Then:

1. **Dedup** candidates pointing at the same line or the same mechanism. Merge
   them into one entry, keeping the wording with the most concrete failure
   scenario and the union of their origins — a finding both CodeRabbit and the
   reuse agent flagged is stronger, and the user should see that.
2. **Drop** anything that would change intended behavior, reaches well outside
   the diff, or that you judge a plain false positive. Keep a short list of what
   you dropped and why; report it at the end.

Do not rank or present yet.

## Phase 2b — Verify

Verify every surviving candidate against the real code before showing it to the
user: Phase 3 asks for a decision on each one, so a false positive costs a real
interruption. Apply the rubric in `agents/finding-verifier.md` — CONFIRMED /
PLAUSIBLE / REFUTED, PLAUSIBLE by default, REFUTED only when you can quote the
line that disproves it.

**Do this inline, yourself, in this context.** You already hold the diff; a
verifier subagent per candidate re-reads files you have and is the second
largest cost in the skill. Read the cited line where the candidate's claim isn't
already settled by the diff in front of you.

Spawn `finding-verifier` subagents (one per candidate, batched in parallel) only
when inline verification is genuinely not viable: more than 12 surviving
candidates, or candidates spread across files far outside the diff. Say which
route you took.

Keep CONFIRMED and PLAUSIBLE. Drop REFUTED — list them with the evidence in the
wrap-up, so a wrong refutation is visible rather than silent.

## Phase 2c — Rank and preview

1. **Rank**: CONFIRMED bugs first, then PLAUSIBLE bugs, then CodeRabbit
   critical/warning, then cleanup and conventions findings, worst first.
   Correctness always outranks cleanup when it's a tie.
2. Show the user a numbered summary table — `#`, `file:line`, one-line summary,
   verdict, origins — before starting the walk, so they know how many are
   coming and can skip ahead.

## Phase 3 — Walk the findings

One at a time, in rank order. For each:

1. **Header**: `[n/total] path/to/file.ext:123` and the origin agents.
2. **What and why**: two or three lines. The problem, the concrete cost, and
   the verdict (CONFIRMED / PLAUSIBLE). For a PLAUSIBLE finding, say what is
   uncertain — the user is deciding with that in hand.
3. **The diff**: write the proposed patch to the scratchpad and show it as a
   fenced ```diff block. Do **not** apply it. If a hunk-level diff isn't
   practical (large refactor), show before/after snippets instead and say so.
4. **Ask**: accept / reject / revise. Wait. Never batch-ask, never assume.

On **accept**:
- Apply the edit.
- Run the narrowest available check that covers it (the file's tests, a type
  check, a build) if one exists and is fast. Report the result. If it fails,
  say so and ask whether to fix, revert, or keep going.
- Stage only the files this change touched: `git add <those paths>`.
- Commit alone. Conventional Commits, subject ≤50 chars, imperative. Body only
  when the "why" isn't obvious from the subject. No co-author trailer.
  ```bash
  git commit -m "refactor(auth): reuse existing token parser"
  ```
- Confirm the commit sha in one line, then move to the next finding.

On **reject**: note it, move on. No arguing.

On **revise**: take their direction, show the revised diff, ask again.

## Phase 4 — Wrap up

- List the commits created, sha + subject, oldest first.
- List rejected findings, and the ones dropped at collate or refuted at verify,
  one line each with the reason.
- State plainly that nothing was pushed. Ask whether to push. Only push if the
  user says yes; use the `gh-pr` skill if they want a PR.
