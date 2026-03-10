---
name: "gh-pr"
description: "Use this skill when a user asks to create a GitHub PR (pull request). It contains conventions for creating PRs."
---

# GitHub PR

## Overview

Use this skill as a reference for creating PRs.

## Prerequisites

Use the `gh` CLI and `git` CLI whenever possible.

Ensure `gh` is authenticated (for example, run `gh auth login` once), then run `gh auth status` with escalated permissions (include workflow/repo scopes) so `gh` commands succeed. If sandboxing blocks `gh auth status`, rerun it with `sandbox_permissions=require_escalated`.

## Conventions

### PR Naming

Format: `<type>[(<scope>)]: sc-<story or ticket number> <short description>`
Example: `feat(billing)-sc-12345-add-new-feature`

Loosely follow conventional commits for naming PRs.

Generally can use the branch name for the PR name, but note the differences in separators. `type(scope)` should be followed by a colon `:` and a space, and the story or ticket number should be followed by a space. The short description should be the rest of the branch name with spaces between words.

The description should be concise, but can be longer than the branch name. Try to keep it within 60 characters.

### PR Description Body

The PR description body should outline the changes made in the PR. Ideally in 2-3 sentences, but can be more or less depending on the complexity of the changes.

Try not to use `\n` characters. They don't render well in the GitHub PR description body.

If a ticket is available when creating the PR, add a link to the ticket in the description body.

### PR Creation

Create the PR using the `gh` CLI.

## References

Use `references/teammates.md` for teammate names to GitHub handle lookups when adding reviewers.
Use `references/tags.md` for mapping generic tag requests to exact GitHub label names.
