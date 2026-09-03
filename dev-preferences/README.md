# Developer Preferences

This skill lets an AI agent learn, apply, and maintain developer-specific coding preferences
without committing personal rules, PR evidence, or usage history.

Developers should interact with the skill through their agent (Cursor or Codex). The Python
scripts are implementation details the skill runs to initialize local data, refresh compact rules,
record usage, mine PRs, and update the local dashboard.

## How To Use

For first-time setup, ask your agent to configure the skill:

```text
Use $dev-preferences and configure my profile.
```

Ask your agent to use the skill during coding work:

```text
Use $dev-preferences for this task.
```

The agent will load the current local rules, prefer the compact runtime file when it is up to date,
apply matching rules, and record which rules shaped the work. If the compact file is stale, it
regenerates before reading; if regeneration fails, it falls back to the full local rules.
The compact runtime file includes a small generated summary with the source file, active rule
count, section count, and generation time so agents can report the same rule inventory without
guessing from line counts.
Usage records store agent, model, and project separately. Agent is the execution surface, such as
`Cursor` or `Codex`. Model is the model name, such as `Opus 4.8`, `Sonnet 5`, `Grok 4.5`, or
`Composer 2.5`. Project is the current repository and always uses `OWNER/REPO` format. Agents
resolve it from the current Git remote first, infer it only from explicit repository context when
no remote is available, and ask the developer when it remains ambiguous. Legacy history is
backfilled only from recorded repository evidence; entries without enough evidence remain
`UNKNOWN`. Counter-only legacy rule applications stay anchored at the first tracked point instead
of disappearing from timelines or totals.
Do not use provider names or bare versions like `Claude`, `4.5`, or `2.5` as model metadata.

## Managing Rules

Rules are maintained by the agent after explicit confirmation. Useful prompts:

```text
Use $dev-preferences and remember that I prefer small focused PRs.
```

```text
Use $dev-preferences and remove the rule about default exports.
```

```text
Use $dev-preferences and show me the rules you applied on this task.
```

When the agent notices a durable preference during normal work, it should ask whether to save it. If
you confirm, it updates the local rules, refreshes the compact rules and dashboard, and avoids
adding duplicates.

Developers may still edit `.local/RULES.md` manually, but the intended workflow is to ask the agent
to maintain it.

## Learning From PRs

Ask your agent to mine merged PRs for patterns:

```text
Use $dev-preferences to analyze my PR comments in an organization and propose rules.
```

The agent will run PR mining and inspect **only your comments/reviews** on any PR (including your
own). Other people's comments are omitted. It then proposes non-duplicate candidate rules. It
infers the GitHub username from local GitHub auth unless you explicitly ask to analyze another
author. PR mining is evidence only: the agent must ask before saving any rule. Mining another
author does not rewrite your local developer profile.

## Dashboard

Ask your agent for the dashboard link:

```text
Use $dev-preferences and show me the dashboard.
```

The dashboard has four views. `Rules` shows each active or removed rule, including its usage
history loaded on demand and paginated per rule, added date, and last-used date, with sorts for
added date (default, newest first), last used, most used, and original rule order. `Analytics`
shows filtered timelines for activity, per-rule usage, project, agent, model, and agent/model
activity. Every usage breakdown includes active and removed rule applications and reconciles to the
same Usage events total for the selected range. `PR mining` and `Local files` show ignored JSON/text
inline with short context for each file or mining run.
Analytics Range both filters the lookback window and sets chart bucket size. Filter changes update
charts in place, so legend toggles survive filtering. Local data stays under `.local/` and is
ignored by Git.

## Files

- `SKILL.md` is versioned. It tells the agent how to load, apply, and maintain the rules.
- `RULES.example.md` is versioned. It is a starter template for first-time local setup.
- `generate.py` and `analyze_prs.py` are versioned automation files used by the skill.
- `dashboard/` holds the versioned dashboard UI: `dashboard.template.html`, `dashboard.css`, and the
  dashboard JavaScript modules loaded in order (`dashboard-state.js`, `dashboard-utils.js`,
  `dashboard-data.js`, `dashboard-charts.js`, `dashboard-views.js`, `dashboard.js`).
  Charts use D3 for distinct series colors, hover tooltips, and clickable legend toggles, and
  they update in place when filters change.
- `.local/RULES.md`, `.local/RULES.compact.md`, `.local/candidates.json`,
  `.local/rule-metadata.json`, `.local/rule-aliases.json`, `.local/usage.json`,
  `.local/removed.json`, `.local/section-metadata.json`, `.local/dashboard.html`,
  `.local/profile.json`, and `.local/pr-analysis/` are ignored local state.
- `.local/candidates.json` holds relatively stable rule/catalog data (sections, rule IDs, and
  developer profile). `.local/rule-metadata.json` holds per-rule added dates keyed by compact rule
  IDs. `.local/usage.json` holds high-churn usage counters/history keyed by compact rule IDs so the
  rule text is not repeated. Because a rule ID is a hash of its text, rewording a rule mints a new
  ID; `.local/rule-aliases.json` maps superseded IDs to their replacement so usage counters and
  history survive rewrites and merges. `.local/removed.json` and `.local/pr-analysis/index.json`
  are the sources of truth for removed rules and mining history.

## Trust Boundary

The agent may apply existing rules automatically, but it may not save, remove, or rewrite local rules
without direct confirmation from the developer.
