---
name: ship-it
description: Take the current work from uncommitted changes to a merged GitHub PR, handling the ticket, branch, commits, push, a concise PR description, and merging once checks pass. Use when the user says "ship it", "/ship-it", or asks to branch, commit, push, and open a PR in one go.
---

# Ship it

Take the current work to a merged PR. Use the `git-branch` and `gh-pr` skills for naming conventions, and the `manage-shortcut-stories` skill for any ticket work.

1. **Ticket.** Check whether this repo puts ticket numbers in PRs: look at recent PR titles (`gh pr list --state all --limit 10`) and branch names. If it does, use the ticket number if it's apparent from the branch name, the conversation, or the user. If it isn't, ask the user whether to create a new ticket or use an existing one. If the repo doesn't use tickets, skip this step.
2. **Branch.** If the work is already on a branch other than the default branch, use it. Otherwise create a new branch for the work.
3. **Commit.** Commit the changes to the branch. Group them into logical commits when the changes cover more than one concern; otherwise one commit is fine.
4. **PR.** Push the branch and open a PR with `gh pr create`. Keep the description concise, and run it through the `like-me` skill before creating the PR.
5. **Merge.** Wait for checks with `gh pr checks --watch`. If they all pass (or the PR has none), merge with `gh pr merge --squash`, or the method the repo allows if squash is disabled. If any check fails, stop and report the failure instead of merging. After merging, switch back to the default branch and pull.

Finish by giving the user the PR URL and whether it merged.
