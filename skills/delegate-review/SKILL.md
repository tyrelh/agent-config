---
name: delegate-review
description: "Delegate review of the current branch to CodeRabbit and Codex in parallel sub-agents, then collate the findings. Use when the user asks to review the branch, review the diff, review before a PR, or says delegate-review."
allowed-tools: Agent, Bash(git:*), AskUserQuestion
---

# delegate-review

Delegate review of the current branch (vs `main`) to two external reviewers.
You do **not** review the code yourself — you have no file tools, only `Agent`.

## 1. Scope the diff

```sh
git diff --stat main...HEAD
```

Nothing changed? Say so and stop.

## 2. Spawn both reviewers — in one message

Both `Agent` calls go in a **single** assistant turn so they run concurrently.
Each wrapper only shells out to a CLI, so `haiku` is enough.

```
Agent({ subagent_type: "coderabbit-runner", model: "haiku",
        description: "CodeRabbit review",
        prompt: "Review the current branch against main. Report findings only, apply nothing." })

Agent({ subagent_type: "codex-delegate", model: "haiku",
        description: "Codex review",
        prompt: "Run `codex-companion.mjs review --base main --scope branch` ... (see below)" })
```

Substitutions if one is unavailable:

| Reviewer | First choice | Fallback |
|---|---|---|
| CodeRabbit | `coderabbit-runner` | `coderabbit:code-reviewer` |
| Codex | `codex-delegate` | `codex:codex-rescue` |

`codex-delegate` sees none of this conversation — its prompt must be
self-contained: name the repo path, the base ref, and "review only, do not edit".

**Do not** substitute `coderabbit:code-review` or `/codex:review`. The first is a
skill that runs in this thread (not a sub-agent); the second is a slash command
with `disable-model-invocation: true` and cannot be called.

## 3. Collate

Wait for both. Then:

- De-duplicate — same file, same line, same defect = one finding, note both reviewers agreed.
- Drop anything neither reviewer tied to a concrete failure.
- Sort by severity, then by file.

## 4. Present

One finding per block: `path:line`, severity, the problem, the suggested fix.
State which reviewer(s) raised it. Say plainly if a reviewer returned nothing or
failed — never fill the gap with your own review.
