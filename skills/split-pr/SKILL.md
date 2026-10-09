---
name: split-pr
description: Split a large branch or PR into a stack of sequential PRs of under 500 changed lines each, grouped logically so each one reviews and builds on its own. Use when the user invokes /split-pr or asks to break up, split, or stack a large PR.
argument-hint: "[<branch or PR number>]  (defaults to the current branch)"
---

# split-pr

Break one large change into a stack of smaller PRs. Each PR targets under 500 changed lines (additions plus deletions), covers one logical concern, and builds on the one before it. Use the `git-branch` and `gh-pr` skills for naming, and the `like-me` skill for PR descriptions.

## 1. Measure

Resolve the source: the argument if given (check out a PR with `gh pr checkout <number>`), otherwise the current branch. Resolve the default branch from the repository rather than assuming `main`. If the tree has uncommitted changes, ask the user to commit or stash them first.

Measure the diff against the default branch with `git diff --stat <base>...<source>`. If it's already under 500 lines, say so and stop. Call out lockfiles, generated files, and snapshots separately; they still go in a PR but shouldn't drive the split.

## 2. Propose

Group the changes into PRs and present the plan before touching anything. For each PR give a title, the files (or parts of files) it takes, its approximate line count, and why it stands on its own.

- Order by dependency: foundations first (schemas, migrations, types, shared helpers, infrastructure), then the code that uses them, then callers, wiring, and config. Keep tests with the code they test.
- Every PR must build and pass tests on top of the ones before it. Nothing should reference code that only arrives in a later PR.
- Prefer fewer, coherent PRs over many tiny ones. A PR can go over 500 lines when the change can't be split sensibly (one large file, one atomic migration); flag it in the plan.
- If a file holds changes that belong to different PRs, split it by hunk and say so.

Wait for the user to approve or adjust the plan.

## 3. Build the stack

Leave the source branch untouched as the reference and backup. For each PR in order:

1. Create its branch from the previous PR's branch (the first one from the default branch).
2. Bring over its changes from the source: `git checkout <source> -- <paths>` for whole files, or `git checkout -p <source> -- <path>` for individual hunks.
3. Commit, then run the project's build and relevant tests. If they fail, fix the grouping (usually by moving a dependency earlier) rather than patching in new code.

When the stack is done, `git diff <last branch> <source>` must be empty. If it isn't, find what's missing or extra before going further.

## 4. Open the PRs

If the repo uses tickets in PRs, reuse the source's ticket unless the user says otherwise. Push each branch and open its PR with `gh pr create --base <previous branch>` (the first one against the default branch). Keep each description concise, note its place in the stack (for example "Part 2 of 3, builds on #123"), and run it through `like-me`.

If the source already had an open PR, ask the user whether to close it or keep it. Don't delete the source branch and don't merge anything.

Finish with the list of PRs in merge order, with their URLs and line counts.
