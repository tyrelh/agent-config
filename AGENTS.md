About me: My name is Tyrel, I'm a senior software developer focusing on platform development and infrastructure. My GitHub handle is @tyrelh. I focus on developer experience. I work hard to craft interactions that are simple and intuitive.

About my job: I work at Giftbit (https://www.giftbit.com). We're building a system to sell digital gift cards B2B. I mostly do infrastructure and platform work, but also am a full-stack developer at time. We primarily use GitHub Actions & Workflows for our CI/CD automations. We use AWS as our core hosting provider. We use Terraform to define infrastructure. Our backend is written in Go and runs in a Docker container on AWS ECS. Our frontend is written in TypeScript and React and is served from both static S3 buckets and from AWS Amplify.

## Terminology
When I say "side pane" or "on the side", I mean run it in a herdr pane.

## Markdown formatting

Never hard-wrap markdown at a line-length limit. One paragraph is one line, however long it is. I use word wrap in every editor I read these files in, so wrapped lines break as soon as the width differs and they make diffs noisy. This applies to every markdown file you write or edit: skills, agents, notes, plans, READMEs, PR bodies, commit bodies.

Line breaks stay meaningful: between paragraphs, between list items, and inside code blocks.

## Obsidian Vault

I maintain knowledge, research, and daily notes in my Obsidian vault. It's located in _${OBSIDIAN_VAULT_PATH}_. Use the `obsidian` skill whenever you need to interact with the vault.

Ask the user if they want completed work to be logged in today's daily note (the current term log) before finishing, including work from any project. Only tasks that result in one of the following should be logged: new PR created, a PR is merged, some long-lived asset is created like a note, ticket, or issue, or a long-lived change is made in some system. Give the user 3 options: record as a completed task in `## Tasks`, record as a reference in `## Notes`, or don't record. Load the `obsidian` skill and use its `scripts/daily-note.sh` helper:

- **Tasks:** Record completed actions, fixes, implementations, reviews, and other tasks in `## Tasks` as checked items (`- [x]`). Check off a matching existing task; otherwise append a concise completed task.
- **Reference material:** Record captured information, research findings, and reference documents in `## Notes`, with a short, verb-led summary and links to relevant material. Use Wikilinks for vault documents.

Check today's entries first and avoid duplicates, including entries already written by a hook. Log meaningful outcomes, not every intermediate tool call; updating the daily log does not itself need another entry. If today's section is missing or logging fails, report that it could not be completed.

New standalone notes go into _inbox/_; new plans go directly into _plans/_. Link each new note, and each new or substantially revised plan, from `## Notes` with a short reason for it, and put the action to carry out a plan in `## Tasks`. A `## Notes` wikilink is also how Magpie discovers a source, so a document that should be ingested has to be linked there the day it is created or substantially changed.

A new day is started by inserting the `templates/insertable/daily note.md` template above the previous day's H1, below the persistent notes at the top. One H1 per day.

## LLM Knowledge Wiki (magpie)

I maintain an LLM Wiki of knowledge and research in my Obsidian vault called _magpie_. It's located in _${OBSIDIAN_VAULT_PATH}/magpie/_

Structure:

- _raw/_: holds captured source material that has no other home in the vault
- _wiki/_: holds compiled, source-traceable knowledge notes
	- _wiki/index.md_: Contains queryable links to every compiled document in the wiki
	- _wiki/log.md_: Contains every change and addition to the wiki in linear time order
- _schema/_: holds rules, commands, and maintenance references
- _source-ledger.csv_: tracks every source Magpie has seen, by vault-relative path

Whenever searching for information, you should always query _magpie_ first. Treat it like a cache for research and knowledge.

Sources live wherever they belong in the vault. A clean article or a finished research note stays where it is and Magpie cites it in place; only material with no other home gets captured into _magpie/raw/_. Ingestion is tracked in the ledger, independent of the folder a document sits in.

### Discovery

Magpie finds sources through wikilinks in the `## Notes` section of today's entry in the current term log. Anything you want ingested must be linked from there on the day you create or substantially change it.

- Links in `## Tasks`, `## Meetings`, `## Left off`, and `## Personal` are not scanned
- Compiled Magpie pages, daily notes, and templates are never treated as sources
- A document opts out permanently with `magpie: ignore` in its frontmatter
- A source queued on an earlier day stays queued until a pass ingests it, so a failed run is not forgotten tomorrow

### Workflows

All commands run from any working directory as long as `OBSIDIAN_VAULT_PATH` is exported. The script also resolves its own location, so `python3 magpie/scripts/wiki_tool.py <command>` works in a clone with nothing set.
Exit codes: `0` success, `1` content problem, `2` usage error.

#### Ingest

1. Capture anything with no other home in the vault into _${OBSIDIAN_VAULT_PATH}/magpie/raw/_; leave everything else where it lives
2. Link each new or substantially changed source from today's `## Notes`
3. Run `python3 ${OBSIDIAN_VAULT_PATH}/magpie/scripts/wiki_tool.py discover`. It queues new and changed sources and reports `MISSING`, `AMBIGUOUS`, and `EXCLUDED` links
4. Run `python3 ${OBSIDIAN_VAULT_PATH}/magpie/scripts/wiki_tool.py pending` for the full queue, including sources left over from earlier days
5. Read each pending source directly from its vault path. Update or create compact _wiki_ notes, referencing _schema/note-schema.md_
6. Run the `humanizer` or `humanize` skill on the note if available and implement changes if needed
7. Preserve `topics` and `sources` traceability
8. Run `python3 ${OBSIDIAN_VAULT_PATH}/magpie/scripts/wiki_tool.py finish "<what changed>" --ingested "<vault path>"`, repeating `--ingested` once per source you actually read and compiled. It fixes `source_count`, rebuilds the index, lints, and only then records ingestion and logs the message
9. If `finish` exits `1`, fix the lint findings it printed and rerun it. Nothing is recorded or logged until lint is clean
10. A source reported as `GONE` is missing and stays pending.

Only sources named with `--ingested` are ever marked ingested. `finish` records their current content hashes for future change detection; it assumes the files did not change between reading and finishing. A citation in a compiled note is not proof that its current version was read.

#### Query

1. Start with _${OBSIDIAN_VAULT_PATH}/magpie/wiki/index.md_
2. Use `python3 ${OBSIDIAN_VAULT_PATH}/magpie/scripts/wiki_tool.py search --query "<some query>"`, optionally with `--tag <topic|concept|entity|project>` or `--limit N`
3. Open only relevant compiled pages
4. Answer from the wiki and preserve source links

#### Maintain

1. Run `python3 ${OBSIDIAN_VAULT_PATH}/magpie/scripts/wiki_tool.py discover`
2. Run `python3 ${OBSIDIAN_VAULT_PATH}/magpie/scripts/wiki_tool.py pending`. If it reports `0 pending`, stop. Do not edit files
3. Read and process the pending sources
4. Seal the pass with `python3 ${OBSIDIAN_VAULT_PATH}/magpie/scripts/wiki_tool.py finish "<what changed>" --ingested "<vault path>"`, rerunning after fixing any lint findings
5. Find sources the wiki never cites with `python3 ${OBSIDIAN_VAULT_PATH}/magpie/scripts/wiki_tool.py source-coverage --uncovered`
6. After editing the script itself, run `python3 ${OBSIDIAN_VAULT_PATH}/magpie/scripts/wiki_tool.py selftest`

Use _magpie/scripts/wiki_tool.py_ as the canonical maintenance tool for discovery, pending queue, build, lint, coverage, search, log, and finish. It is one file, standard library only, and never needs `pip install`.

Default write locations:

- Topic hubs: _wiki/topics/_
- Concepts: _wiki/concepts/_
- Entities: _wiki/entities/_
- Projects: _wiki/projects/_
- Index: _wiki/index.md_
- Logs: _wiki/log.md_

Non-negotiable rules:

- Keep source notes source-faithful
- Do not overwrite source content during compilation, wherever the source lives
- Use plain tags only
- Use `topics` and `sources` frontmatter on compiled wiki notes
- Treat `source_count` as derived
- Keep compiled notes short, single-purpose, and source-traceable
- Pending sources are ingest backlog, not errors; lint does not fail on them
- Query from _wiki/index.md_ before opening broad context

### Plans

A plan linked from `## Notes` is ingested like any other source. Keep the reasoning and decisions in the compiled note, including what the plan is meant to achieve and any constraints. Distinguish proposed changes from work that shipped: "the plan proposes scanning daily notes" must not become "Magpie scans daily notes" without evidence that the change landed. Leave task checklists and progress tracking in the plan itself.

## Project context
Projects may contain configurations from other types of agents. You should read these into context.
- .cursor/rules/*.md in the root of the project. This contains multiple rule files each with a file glob pattern in it's metadata describing which kinds of files it's applicable for.

## Skills
A skill is a set of local instructions to follow that is stored in a `SKILL.md` file. Below is the list of skills that can be used. Each entry includes a name, description, and file path so you can open the source for full instructions when using a specific skill.
### Available skills
- gh-debug-actions: Debug GitHub Actions workflow runs and deployments by locating the relevant run, fetching logs (full or failed-only), and summarizing root causes. Use when asked to debug failed GitHub Actions runs, explain why a workflow run failed, retrieve logs, or investigate CI/CD deployments. Supports default repos Giftbit/lightrail and Giftbit/giftbitfe, and any explicitly specified repo. (file: /Users/tyrel/.codex/skills/gh-debug-actions/SKILL.md)
- gh-fix-ci: Use when a user asks to debug or fix failing GitHub PR checks that run in GitHub Actions; use `gh` to inspect checks and logs, summarize failure context, draft a fix plan, and implement only after explicit approval. Treat external providers (for example Buildkite) as out of scope and report only the details URL. (file: /Users/tyrel/.codex/skills/gh-fix-ci/SKILL.md)
- gh-pr: Use this skill when a user asks to create a GitHub PR (pull request). It contains conventions for creating PRs. (file: /Users/tyrel/.codex/skills/gh-pr/SKILL.md)
- git-branch: Use this skill when creating git branches. It contains conventions for creating branches. (file: /Users/tyrel/.codex/skills/git-branch/SKILL.md)
- manage-shortcut-stories: Manage Shortcut stories via API. Use when you need to find or create a Shortcut ticket, list projects/workflows/teams, assign owners/teams, fetch story details, or update a story's workflow state to in-progress (started) or ready-for-review. Includes keyword-based search with user prompts, story creation, and story updates. (file: /Users/tyrel/.codex/skills/manage-shortcut-stories/SKILL.md)
- htmx: HTMX development guidelines for building dynamic web applications with minimal JavaScript using HTML attributes. (file: /Users/tyrel/.codex/skills/htmx/SKILL.md)
- terraform-giftbit: Terraform workflows infrastructure on AWS with Datadog and Stytch providers. Use when Codex needs to create or update Terraform modules, add or refactor resources, manage state/backends, or edit environment configuration in `config/env.tfvars` files that CI/CD iterates over. (file: /Users/tyrel/.codex/skills/terraform-giftbit/SKILL.md)
- handoff: Used to summarize a threads context to be passed off to a new agent or thread.
