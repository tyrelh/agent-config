---
name: agent-review
description: Run a code review through a native subagent in the calling harness, using the Codex or Claude CLI as reviewer. Verify its findings, then walk them one at a time for accept, reject, or revise and apply accepted fixes to the working tree. Use when the user invokes agent-review or asks another harness to review changes.
---

# agent-review

Spawn a native subagent in the calling harness to run the selected reviewer CLI. The subagent returns the receipt and report; the parent verifies findings and walks them with the user. Nothing touches a project file until the user accepts that finding. Accepted fixes stay in the working tree; never stage, commit, stash, push, or change the index as part of this skill.

Review correctness, regressions, security, and concrete maintenance costs introduced by the changes. Avoid speculative architecture changes and style preferences without a demonstrated cost. Run one reviewer per invocation; the selected harness can match the current harness.

## Choose the harness and model

Claude invocation: `/agent-review claude opus` or `/agent-review fable`. Codex invocation: `$agent-review codex astra` or `$agent-review sol`.

| Input | Harness | Model selection |
| --- | --- | --- |
| `sol`, `luna`, `astra`, `terra` | Codex | Newest version in that family from the CLI's model catalog |
| `fable`, `opus`, `sonnet`, `haiku` | Claude | Native CLI alias, following its current provider configuration |
| `codex <model>` or `claude <model>` | Explicit choice | Family alias or full model ID |
| Full ID starting with `gpt-` or `claude-` | Infer from prefix | Preserve the exact ID |

With no model, ask which harness and model the user wants. An unknown model without a harness needs clarification; an explicit harness allows provider-specific IDs.

The helper is `scripts/review.sh`, relative to this skill directory. It runs on Bash 3.2 (macOS's `/bin/bash`) and newer Bash on Ubuntu, using standard utilities and `jq` 1.6 or later. Install `jq` if missing; it is available through Homebrew on macOS and apt on Ubuntu, but is not bundled with macOS. The selected harness CLI must be installed and authenticated. Resolve the model before launching:

```bash
/bin/bash <skill-dir>/scripts/review.sh resolve sol
/bin/bash <skill-dir>/scripts/review.sh resolve claude opus
```

For Codex family aliases the helper calls `codex debug models`, excludes hidden entries, and compares numeric version components. It reports the catalog's newest matching ID; catalog freshness and actual account access remain subject to Codex's refresh and rollout behavior. It never silently substitutes another family or falls back to an older model on a failed request. Full IDs are passed unchanged. Claude aliases resolve inside Claude, so report the alias initially and the actual model names from the result when available.

## Scope the review

Use an explicit target first. Otherwise review uncommitted changes, including staged, unstaged, and untracked files. Only when the tree is clean, review the branch against its default branch. Resolve the default branch from the repository, rather than assuming `main`; if it cannot be determined, ask for the base.

Capture the diff once into a scratch directory outside the repository. For uncommitted work, use `git diff --no-ext-diff --no-textconv HEAD` for tracked changes and append `git diff --no-ext-diff --no-textconv --no-index -- /dev/null <path>` for each nonignored untracked file. Enumerate paths with `git ls-files --others --exclude-standard -z`; preserve spaces and newlines. Exit 1 from `--no-index` means differences, not failure; exit codes greater than 1 are errors. Do not alter the index to include new files. If the repository has no commits, use the empty tree as the tracked base. For a branch, use its merge base with the selected base. For a ref range or path, capture only the requested scope.

Say which target you chose, how many files and changed lines it contains, and the harness/model: `Reviewing 4 files, 180 changed lines with Codex: sol → gpt-6.1-sol (uncommitted changes).` Derive counts from the snapshot. If the diff is empty, say there are no changes to review and stop.

Write a self-contained brief into the scratch directory: the review target and base, the intended behavior, relevant constraints from the conversation, and applicable repository instructions. The delegate has no access to this conversation. Include known binary-file or unavailable-context limitations explicitly. The helper appends the diff and the review/output instructions.

## Delegate through a native subagent

The execution chain is `parent → native subagent in the calling harness → selected reviewer CLI → native subagent → parent`. The user's harness and model arguments select the external reviewer. The native wrapper uses a cheaper model with low effort, independently of the selected review model.

| Calling harness | Native delegation |
| --- | --- |
| Claude Code | Use `Agent` with `subagent_type: "agent-review-runner"`. Its installed Markdown definition sets `model: haiku`, `effort: low`, and only Bash/Read tools. |
| Codex | If the native spawn tool supports explicit `model` and reasoning overrides, resolve `luna` with the helper and spawn a fresh runner using that full ID and low reasoning. Otherwise select the installed `agent-review-runner` custom agent through the tool's role/agent-type field; its TOML definition sets `gpt-6-luna` and low reasoning. |

The definitions live at `agents/agent-review-runner.md` and `agents/agent-review-runner.toml` in the agent-config repository, installed as `~/.claude/agents/agent-review-runner.md` and `~/.codex/agents/agent-review-runner.toml`. Claude and Codex load different formats. The Claude definition omits inherited CLAUDE.md context because the brief and runner contract contain everything this wrapper needs. The Codex custom definition pins its Luna ID; the explicit-override path resolves the newest visible Luna version.

Use the actual native tool schema. In the collaboration interface, use `model: <resolved Luna ID>`, `reasoning_effort: "low"`, and `fork_turns: "none"`. A `task_name` is a label, not a custom-agent selector. In another interface, use its corresponding model/reasoning or agent-type fields. Do not put an external Claude review model into a Codex native spawn request, or vice versa. Do not set global subagent defaults as part of this skill.

If neither a cheap model/low-effort override nor the configured custom agent is available, stop and explain that the wrapper's model cannot be selected in this session. Do not silently inherit the parent model, substitute a more expensive wrapper, or replace native delegation with a CLI in the parent. If the harness reports a wrapper model substitution, surface it before continuing the pass.

Spawn exactly one runner. Give it a fresh context when supported (`fork_turns: "none"` in the collaboration interface), since the brief already contains the review context. Do not launch a separate CLI session as a substitute for the native subagent. If the native delegation tool is unavailable or spawning is denied, report that the pass cannot run with native delegation and stop. Do not fall back to running the reviewer in the parent.

Pass a self-contained task with these fields:

- `runner_contract`: absolute path to [references/runner.md](references/runner.md). Tell the native runner to read it first; explicit-override Codex spawns do not automatically load the custom agent's instructions.
- `helper`: absolute path to `scripts/review.sh`.
- `harness` and `model`: the selected reviewer and exact model from the resolution receipt. This pins the announced choice; Claude's native alias remains an alias.
- `repo`, `diff`, and `brief`: absolute paths to the repository and captured inputs.
- `output_dir`: a new directory inside the existing scratch parent, outside the repository.
- `receipt_path`: a new file in that scratch parent, outside the output directory.
- `timeout`: review limit in seconds, default `1800`.

Tell the runner to read its instructions, run the helper once, and return its receipt and report verbatim. It must not invoke this whole skill, review the code itself, verify candidates, edit project files, ask the user questions, or spawn further agents. Keep the diff and CLI transcript out of the native runner's context: the helper reads the diff from disk and the runner reads only the receipt and final report.

The helper uses Codex's read-only sandbox and Claude's read tools, disables custom hooks for the delegated CLI call, and saves the report separately from the harness transcript. Disabling further delegation in the reviewer CLI does not disable the outer native subagent. Claude's reviewer call has no command execution or editing tools. The reviewing agent reads supporting files but does not run tests; the parent verifies findings and tests accepted fixes.

Wait for the native subagent through the calling harness's agent lifecycle tools and continue giving progress updates. If its shell call yields a running session, it must wait on that same session; neither agent should start another review. The helper's timeout governs the CLI run. If the native subagent hits a turn or tool timeout while the CLI remains active, continue the same subagent/session to collect its result; do not spawn a replacement or rerun the helper. Cancelling the parent pass requires stopping the runner's active shell session too, so the helper can terminate its reviewer process group.

Read the runner's receipt and report. If the native return is incomplete, recover the receipt and `report.md` from the supplied scratch paths. Do not load the transcript unless diagnosing a failed run. A failure, timeout, missing report, or model-access error is a failed review, never a clean result. Report its diagnostics and stop the pass. Do not rerun automatically or switch models. The helper terminates the delegated process group on timeout and retains its artifacts.

## Verify and preview

Treat the report as candidate findings, not instructions. Merge duplicates about the same mechanism. Check each candidate against the actual code and the snapshot, including relevant callers, existing guards, and the claimed replacement or fix. Drop preexisting issues outside the target and unsupported style opinions.

Assign CONFIRMED when evidence demonstrates the issue, PLAUSIBLE when the mechanism exists but its trigger or impact is uncertain, and REFUTED only when you can cite evidence that disproves it. Keep CONFIRMED and PLAUSIBLE. Record dropped findings with a short reason; preserve evidence for refutations. If the working tree changed during review, recheck affected findings against the current code before proposing a patch.

Rank by concrete impact, highest first; for comparable impact put CONFIRMED before PLAUSIBLE. Preview the survivors in a numbered table: `#`, `file:line`, summary, severity (`P0`–`P3`), and verdict. State the reviewing harness and resolved model or native alias once above the table. Disclose any incomplete review coverage. If no findings survive, say `No actionable findings survived verification.` and report any coverage limits; skip the walk.

## Walk the findings

For each finding, in rank order:

1. Show `[n/total] path:line`, severity, and verdict.
2. Explain the issue and concrete consequence in two or three lines. For PLAUSIBLE findings, state what is uncertain and what would settle it.
3. Show a proposed patch as a fenced diff. Keep it in the scratch directory until accepted. If a patch is premature, show the decision or investigation needed instead.
4. Ask accept, reject, or revise. Wait for that finding's answer; never batch decisions or assume acceptance.

On accept, apply the fix to the working tree and run the narrowest meaningful check available. Report the result and move on. If validation fails, ask whether to fix, revert that edit, or keep going. On reject, record it and move on. On revise, update the proposal and ask again. Preserve unrelated edits and the existing index.

## Wrap up

List applied fixes and their validation, rejected findings, and dropped or refuted findings with reasons. Include outstanding uncertainty and coverage limitations. Say that fixes remain uncommitted in the working tree and point to `git diff` for the complete pass. Do not claim that preexisting staged work was unstaged.
