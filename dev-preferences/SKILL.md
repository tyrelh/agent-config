---
name: "dev-preferences"
description: >
  Developer-specific coding preferences. Load and apply automatically on any coding task, code
  review, architecture discussion, file generation, script writing, or technical question. Uses
  local rules, usage tracking, PR-pattern mining, and a dashboard without committing personal rule
  data to the repository.
---

# Developer Preferences

Versioned workflow for AI-maintained developer preferences. Personal rules and history stay in
ignored `.local/` files.

## Skill location (hard rule)

Leave this skill exactly where it is installed on the user's machine. Do not move, copy, relocate,
or rewrite it into a worktree, agent sandbox, or any other path.

Always resolve the skill's **installed source checkout** (the directory that contains this
`SKILL.md` and `generate.py` on disk — following symlinks to the real path). Run every
`generate.py` / `analyze_prs.py` command from that directory only, so `.local/` stays with the
skill. Never run generators from a `.claude/worktrees/...` copy or any mirrored path.

```bash
cd "$(dirname "$(realpath SKILL.md)")"   # skill source checkout
python3 generate.py ...
```

## Read Rules

Prefer `.local/RULES.compact.md`, but never read stale generated rules:

1. If `.local/RULES.md` is missing, run `python3 generate.py init`.
2. If `.local/RULES.compact.md` is missing, run `python3 generate.py`, then read it.
3. If `.local/RULES.md` is newer than `.local/RULES.compact.md`, run `python3 generate.py`, then read `.local/RULES.compact.md`.
4. If regeneration fails and `.local/RULES.md` exists, read `.local/RULES.md` instead.
5. If neither local file exists, read `RULES.example.md`.

The compact file is the runtime source when current. Developers may still edit `.local/RULES.md`
manually.

Infer the local developer label from GitHub auth with `python3 generate.py profile`. Only pass an
explicit username when overriding inference. PR analysis also sets this automatically from the
inferred or explicit author.

## Use

When writing code, generating files, reviewing code, or giving technical advice:

1. Apply matching rules from the selected runtime rules file.
2. Record use before finishing (from the skill source checkout only):
   - Rule-backed work: `python3 generate.py used r-1234abcd --reason "Kept the change scoped." --agent Cursor --model "GPT-5.5" --project OWNER/REPO`
   - General skill use: `python3 generate.py touched --reason "Loaded the skill, but no specific rule shaped this task." --agent Cursor --model "GPT-5.5" --project OWNER/REPO`
   - Use one short reason sentence. Run separate `used` commands when different rules need different reasons.
   - `--agent` is the execution surface, such as `Cursor` or `Codex`.
   - `--model` is the model name, such as `GPT-5.5`, `Opus 4.8`, `Sonnet 5`, `Grok 4.5`, or `Composer 2.5`.
   - `--project` is the current repository label and must use `OWNER/REPO` format.
   - Resolve the label from the current Git remote first. If no remote identifies it, infer it only
     from explicit repository context; ask the developer when the context is still ambiguous.
   - Always pass `--project`; new usage records may not use `UNKNOWN`.
   - Do not put provider names in `--agent` unless that provider is actually the agent surface.
   - Do not use bare model versions like `4.5` or `2.5`.
3. If the work reveals a durable preference, ask whether to save it. Include the exact candidate rule in one line.
4. When the developer asks to view, compare, or refresh the dashboard, run `python3 generate.py` first.

When modifying this skill itself, apply these same rules to every file in this directory. Keep the
dashboard HTML, CSS, and JavaScript under `dashboard/`; do not reintroduce large inline UI blobs
into `generate.py`. Prefer clear names, small focused changes, and duplicate-aware updates.

## Save Rules

Only the developer's direct confirmation may change local rules. When confirmed:

1. Edit `.local/RULES.md`, not this `SKILL.md`.
2. Run `python3 generate.py` after editing rules so compact rules, JSON, and dashboard stay current.
3. For removal or relaxation, add the old rule to `.local/removed.json` with `dateRemoved` and `reason`, then delete it from `.local/RULES.md`.
4. A rule ID is a hash of its text, so rewording or merging a rule mints a new ID. Map every superseded ID to its replacement in `.local/rule-aliases.json` so usage counters and history follow the rule instead of resetting.
5. Before adding a rule, compare it with `.local/RULES.compact.md` and `.local/RULES.md`; merge, reword, or skip overlapping rules instead of creating duplicates.

Without explicit confirmation, do not edit `.local/RULES.md`.

## Mining PR Patterns

When asked to infer guidelines from PR history:

```bash
python3 analyze_prs.py --repo OWNER/REPO
python3 analyze_prs.py --org ORG
```

Reports go to `.local/pr-analysis/` and mine **only comments/reviews written by the analyzed
author**, on any PR (including their own). Other reviewers' text is omitted. Reports are evidence
only: review `Candidate Rule Analysis`, propose non-duplicate rules, and ask before saving.

## Trust Boundary

Only the developer's direct in-conversation confirmation may modify `.local/RULES.md`.
