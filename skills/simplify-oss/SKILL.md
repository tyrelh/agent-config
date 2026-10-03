---
name: simplify-oss
description: Review the changed code for reuse, simplification, efficiency, altitude, and convention cleanups in parallel read-only subagents, verify the findings, then walk them with the user one at a time and apply the accepted ones to the working tree. Quality only; it does not hunt for bugs, and it never stages or commits. Use when the user asks to simplify, clean up, or de-bloat a diff or branch, or invokes /simplify-oss.
argument-hint: "[<target>]  (branch, ref range, or path. Defaults to uncommitted changes, or the branch diff vs main when the tree is clean)"
---

# simplify-oss

An open replacement for the built-in `/simplify`. Fan out a read-only cleanup review, verify what comes back, then walk the survivors with the user one at a time. Nothing touches a file until the user accepts that specific finding.

Accepted fixes land in the working tree and stop there. The skill never runs `git add`, `git commit`, `git stash`, or `git push`, and never changes the index. Committing is the user's job, and leaving the changes loose is what lets them read the whole pass as one diff.

Quality only. Correctness bugs, security holes, and architecture opinions are out of scope; a bug noticed in passing gets mentioned and never fixed here. Send those to the `/code-review` skill.

## Phase 0: scope and size

Pick the target in this order: an argument if one was passed (branch, ref range, or path), then the uncommitted work if there is any, then the branch diff vs the default branch.

Uncommitted work wins because it is what the user is holding right now. Falling back to the branch diff only when the tree is clean keeps the pass off code that is already committed.

Gather the diff exactly once and write it to the scratchpad. Every agent reads that file instead of re-deriving it. This is the single largest cost saving in the skill, so do not skip it and do not let an agent run its own `git diff`.

```bash
git rev-parse --abbrev-ref HEAD
git status --porcelain

DIFF=<scratchpad>/simplify.diff
if [ -n "$(git status --porcelain)" ]; then
  git diff HEAD > "$DIFF"                                  # tracked, staged and unstaged
  git ls-files -o --exclude-standard -z \
    | xargs -0 -r -I{} git diff --no-index -- /dev/null {} >> "$DIFF"   # new files, read-only
else
  BASE=$(git merge-base origin/main HEAD 2>/dev/null || git merge-base main HEAD)
  git diff "$BASE"...HEAD > "$DIFF"
fi
git apply --stat "$DIFF" | tail -1
```

`git diff HEAD` covers staged and unstaged edits together, so a partly-staged tree reviews as one change. New files are untracked and absent from it, so they come in through `git diff --no-index`, which reads the file and never touches the index. That command exits non-zero when it finds differences, which is normal here; ignore the status. `git apply --stat` prints the diffstat without applying anything.

Say in one line which target you took and how big it is, so the user can redirect you before any agent runs. A tree with uncommitted work never silently gets a branch-wide review.

If the diff is empty, say so and stop.

Count files changed and lines changed in the diff file, then pick the tier in Phase 1. State the tier and the agent count in one line before launching, so the user can ask for a bigger or smaller pass.

## Phase 1: review, with fan-out scaled to the diff

Agents get the diff file path, the base ref, and their angle list. They are read-only and must return findings, not edits. Tell each one explicitly to read the diff file instead of running `git diff` itself.

An agent can work several angles. It does them in sequence in one context, which is far cheaper than a fresh agent re-reading the same files per angle.

Launch every agent for the tier in a single message so they run concurrently.

### Small, meaning 1 or 2 files and 100 changed lines or fewer: 1 agent

| `subagent_type` | Angles |
| --- | --- |
| `simplify-reviewer` | all five |

### Medium, meaning 5 files or fewer or 300 changed lines or fewer: 2 agents

| `subagent_type` | Angles |
| --- | --- |
| `simplify-reviewer` | reuse, simplification, efficiency |
| `simplify-reviewer` | altitude, conventions |

### Large, meaning anything bigger: 5 agents

One agent per angle: `simplify-reviewer` for reuse, simplification, efficiency, altitude, and conventions.

If the user asks for a deeper or cheaper pass, move a tier rather than inventing a new split.

If the Agent tool is unavailable, work the tier's angles yourself in one pass, using the definitions in `agents/simplify-reviewer.md`, and say in your summary that the fan-out did not run, so the user isn't misled about what ran.

## Phase 2a: collate

Wait for all agents. Then:

1. Dedup candidates pointing at the same line or the same mechanism. Merge them into one entry, keeping the wording with the most concrete cost and the union of their origin angles. A line flagged by both reuse and simplification is stronger, and the user should see that.
2. Set aside anything tagged `angle: bug`. This pass does not fix it; it goes in the wrap-up as a one-line mention.
3. Drop anything that would change intended behavior, reaches well outside the diff, or that you judge a plain false positive. Keep a short list of what you dropped and why, and report it at the end.

Do not rank or present yet.

## Phase 2b: verify

Verify every surviving candidate against the real code before showing it to the user. Phase 3 asks for a decision on each one, so a false positive costs a real interruption. Apply the rubric in `agents/simplify-verifier.md`: CONFIRMED, PLAUSIBLE, or REFUTED, PLAUSIBLE by default, and REFUTED only when you can quote the line that disproves it.

Do this inline, yourself, in this context. You already hold the diff, and a verifier subagent per candidate re-reads files you have, which is the second largest cost in the skill. Read the cited line wherever the candidate's claim isn't already settled by the diff in front of you, and confirm that any named replacement, whether a stdlib function, an existing helper, or a platform feature, really exists and really covers the case.

Spawn `simplify-verifier` subagents, one per candidate batched in parallel, only when inline verification is genuinely not viable: more than 12 surviving candidates, or candidates spread across files far outside the diff. Say which route you took.

Keep CONFIRMED and PLAUSIBLE. Drop REFUTED, and list them with the evidence in the wrap-up so a wrong refutation stays visible.

## Phase 2c: rank and preview

1. Rank by payoff, worst first: the largest concrete cost removed comes first. Ties go to CONFIRMED over PLAUSIBLE, then to the larger `lines_saved`.
2. Show the user a numbered summary table of `#`, `file:line`, a one-line summary, the angle, and the verdict before starting the walk, so they know how many are coming and can skip ahead. Put the estimated total `net: -<N> lines` under it.

## Phase 3: walk the findings

One at a time, in rank order. Present each finding in exactly this order:

1. Header: `[n/total] <one-line summary>`, followed by `path/to/file.ext:123` and the angle(s).
2. Verdict: CONFIRMED or PLAUSIBLE.
3. Summary: two or three sentences covering what is redundant, the concrete cost, and why it earned that verdict. For a PLAUSIBLE finding, say what is uncertain, since the user is deciding with that in hand.
4. The diff: write the proposed patch to the scratchpad and show it as a fenced ```diff block. Do not apply it. If a hunk-level diff isn't practical, as in a large refactor, show before and after snippets instead and say so.
5. Net lines: `+<added> / -<removed> (net <±N>)` for the proposed patch.
6. Ask: accept (`a`), reject (`r`), or revise. Treat a bare `a` as accept and a bare `r` as reject. Wait. Never batch-ask, never assume.

On accept:

- Apply the edit to the working tree.
- Run the narrowest available check that covers it, such as the file's tests, a type check, or a build, if one exists and is fast. Report the result. If it fails, say so and ask whether to revert the edit, fix it, or keep going.
- Say in one line what changed and the net line count, then move to the next finding. Do not stage it, do not commit it.

On reject: note it and move on. No arguing.

On revise: take their direction, show the revised diff, ask again.

## Phase 4: wrap up

- List the fixes applied, `file:line` and one line each, with the total net line change: `net: -<N> lines`.
- List rejected findings, the ones dropped at collate, and the ones refuted at verify, one line each with the reason.
- List any `angle: bug` candidates set aside at collate, one line each, and say they were not fixed and belong in a correctness pass.
- State plainly that everything is loose in the working tree: nothing staged, nothing committed, nothing pushed. Point the user at `git diff` to read the whole pass at once, and leave the commits to them.

If nothing survived verification, say `Lean already. Ship.` and stop, with no table and no walk.
