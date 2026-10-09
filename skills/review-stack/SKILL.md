---
name: review-stack
description: Run the full review stack on the current changes in order — simplify-oss, then agent-review with the given model, then coderabbit:code-review when it's available — committing each accepted change on its own. Use when the user invokes /review-stack or asks to run all the reviewers.
argument-hint: "<model>  (passed straight to agent-review, e.g. astra, sol, fable, or codex astra)"
---

# review-stack

Every accepted change gets its own commit, so start from a clean tree. If there are uncommitted changes, ask the user to commit them first (or offer to do it), so the per-fix commits contain only the fixes. The reviewers then review the branch diff against the default branch.

Run these reviews one after another on the same target, each to completion before starting the next, so later reviewers see the fixes the earlier ones applied:

1. **`simplify-oss`.** Invoke it with no arguments and walk its findings with the user as that skill describes.
2. **`agent-review <args>`.** Pass this skill's arguments through to it unchanged, so `/review-stack astra` runs `/agent-review astra`. With no arguments, invoke it bare and let it ask for the harness and model.
3. **`coderabbit:code-review`.** Run it only if that skill is available in this session. If it isn't, say it was skipped and why.

If a step finds nothing, or the user rejects everything, move on to the next one. If a step fails to run, report the failure and continue with the rest.

## Commit each accepted change

This overrides the "never stage or commit" rule in the skills above. As soon as an accepted change is applied, commit it on its own before moving to the next finding: stage only the files that change touched and write a short commit message describing the fix. A rejected or skipped finding gets no commit. Never push.

Finish with a short summary per reviewer: findings accepted, rejected, or skipped, plus the list of commits made.
