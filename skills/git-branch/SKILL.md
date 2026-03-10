---
name: "git-branch"
description: "Use this skill when creating git branches. It contains conventions for creating branches."
---

# Git Branching

## Overview

Use this skill to create git branches. It contains conventions for creating branches. It should be used when prompted to "create a branch" or "create a new branch".

## Conventions

### Branch Naming

Format: `<type>[(<scope>)]-sc-<story or ticket number>-<short description>`
Example: `feat(billing)-sc-12345-add-new-feature`

Loosely follow conventional commits for naming branches.

Avoid `\` and prefer `-` for separators.

The `type(scope)`, `sc-#`, and `descriptsion` should be separated by a dash `-`.

#### Types

- Use the prefix `build-` for changes to the build system.
- Use the prefix `chore-` for chore changes.
- Use the prefix `ci-` for changes to the testing and validation systems.
- Use the prefix `cd-` for changes to the deployment systems.
- Use the prefix `docs-` for documentation changes.
- Use the prefix `feat-` for new features, generally customer facing.
- Use the prefix `fix-` for bug fixes.
- Use the prefix `perf-` for performance improvements.
- Use the prefix `refactor-` for refactoring changes.
- Use the prefix `revert-` for reverting changes.
- Use the prefix `style-` for style changes.

#### Scope

Optional. Use sparingly only when specificity is needed.

You can include a scope after the type prefix. Scopes are always in parentheses.

Example: `fix(accounts)`

#### Story or Ticket Number

Always require a branch to have a story or ticket number. If the ticket number isn't known yet, ask the user if you can search for it or create it. We use Shortcut for stories. I use the terms story and ticket interchangeably.

There's a skill, `manage-shortcut-stories`, that can be used to search for and create stories.

Format: `sc-<story or ticket number>`
Example: `sc-12345`

#### Description

Keep the description concise and clear. Don't use too technical of language, branch and PR names make it into our public changelogs.

Avoid special characters, use only letters, numbers, and hyphens.

Example: `add-new-feature`
Example: `use-resolved-product-instead-of-variant-for-payout`

### Branch Creation

Ensure you branch off of the main branch unless otherwise specified.

Create the branch locally and push it to the remote repository.