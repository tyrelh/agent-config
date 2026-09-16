---
name: pr-review-comments
description: Iterate through comments on a PR
argument-hint: "Who's comments would you like to review?"
---

Iterate through all the unresolved comments on the PR associated with the current branch. If the user provides a target username only iterate through that user's unresolved comments.

For each comment:
1. Show the quoted comment
2. Provide a brief description and interpretation
3. Provide a brief outline on the changes you suggest
4. Ask the user if they'd like to implement the suggested changes, skip this comment and do nothing, or if they would want to suggest an alternate change

Each change made should be an independent commit so they can be easily viewed in isolation.
