About me: My name is Tyrel, I'm a senior software developer focusing on platform development and infrastructure. My GitHub handle is @tyrelh. I focus on developer experience. I work hard to craft interactions that are simple and intuitive.

About my job: I work at Giftbit (https://www.giftbit.com). We're building a system to sell digital gift cards B2B. I mostly do infrastructure and platform work, but also am a full-stack developer at time. We primarily use GitHub Actions & Workflows for our CI/CD automations. We use AWS as our core hosting provider. We use Terraform to define infrastructure. Our backend is written in Go and runs in a Docker container on AWS ECS. Our frontend is written in TypeScript and React and is served from both static S3 buckets and from AWS Amplify.

## Terminology
When I say "side pane" or "on the side", I mean run it in a herdr pane.

## Obsidian Vault

I maintain knowledge, research, and daily notes in my Obsidian vault. It's located in _${OBSIDIAN_VAULT_PATH}_. Use the `obsidian` skill whenever you need to interact with the vault.

Record any completed work in today's daily note (the current term log) before finishing, including work outside the vault. Load the `obsidian` skill and use its `scripts/daily-note.sh` helper:

- **Tasks:** Record completed actions, fixes, implementations, reviews, and other tasks in `## Tasks` as checked items (`- [x]`). Check off a matching existing task; otherwise append a concise completed task.
- **Reference material:** Record captured information, research findings, and reference documents in `## Notes`, with a short, verb-led summary and links to relevant material. Use Wikilinks for vault documents.

Check today's entries first and avoid duplicates, including entries already written by a hook. Log meaningful outcomes, not every intermediate tool call; updating the daily log does not itself need another entry. If today's section is missing or logging fails, report that it could not be completed.

## LLM Knowledge Wiki (fog)

I maintain an LLM Wiki of knowledge and research in my Obsidian vault called _fog_. It's located in _${OBSIDIAN_VAULT_PATH}/fog/_

Structure:

- _raw/_: holds captured source material
	- _raw/source-manifest.csv_
- _wiki/_: holds compiled, source-traceable knowledge notes
	- _wiki/index.md_: Contains queryable links to every compiled document in the wiki
	- _wiki/log.md_: Contains every change and addition to the wiki in linear time order
- _schema/_: holds rules, commands, and maintenance references

Whenever searching for information, you should always query _fog_ first. Treat it like a cache for research and knowledge.

When referencing online resources or resources elsewhere in my Obsidian vault, should write findings to _fog/raw/_ for later ingestion.

### Workflows

All commands run from any working directory as long as `OBSIDIAN_VAULT_PATH` is exported. The script also resolves its own location, so `python3 fog/scripts/wiki_tool.py <command>` works in a clone with nothing set.
Exit codes: `0` success, `1` content problem, `2` usage error.

#### Ingest

1. Capture source material into _${OBSIDIAN_VAULT_PATH}/fog/raw/_
2. Run `python3 ${OBSIDIAN_VAULT_PATH}/fog/scripts/wiki_tool.py source-delta`
3. Read only actionable _raw_ sources, those listed under `NEW`, `CHANGED`, or `PENDING`. `REMOVED` rows need no reading; the manifest refresh in `finish` clears them
4. Update or create compact _wiki_ notes, referencing _schema/note-schema.md_
5. Run the `humanizer` or `humanize` skill on the note if available and implement changes if needed
6. Preserve `topics` and `sources` traceability
7. Run `python3 ${OBSIDIAN_VAULT_PATH}/fog/scripts/wiki_tool.py finish "<what changed>"`. It fixes `source_count`, rebuilds the index, refreshes the manifest with `--accept-covered`, lints, and logs the message
8. If `finish` exits `1`, fix the lint findings it printed and rerun it. Nothing is logged until lint is clean

#### Query

1. Start with _${OBSIDIAN_VAULT_PATH}/fog/wiki/index.md_
2. Use `python3 ${OBSIDIAN_VAULT_PATH}/fog/scripts/wiki_tool.py search --query "<some query>"`, optionally with `--tag <topic|concept|entity|project>` or `--limit N`
3. Open only relevant compiled pages
4. Answer from the wiki and preserve source links

#### Maintain

1. Run `python3 ${OBSIDIAN_VAULT_PATH}/fog/scripts/wiki_tool.py source-delta`
2. If it prints `NO DELTA`, stop. Do not edit files
3. Process changed _raw_ sources
4. Seal the pass with `python3 ${OBSIDIAN_VAULT_PATH}/fog/scripts/wiki_tool.py finish "<what changed>"`, rerunning after fixing any lint findings
5. Find the ingest backlog with `python3 ${OBSIDIAN_VAULT_PATH}/fog/scripts/wiki_tool.py source-coverage --uncovered`
6. After editing the script itself, run `python3 ${OBSIDIAN_VAULT_PATH}/fog/scripts/wiki_tool.py selftest`

Use _fog/scripts/wiki_tool.py_ as the canonical maintenance tool for build, lint, source scan, source delta, source coverage, search, log, and finish. It is one file, standard library only, and never needs `pip install`.

Default write locations:

- Topic hubs: _wiki/topics/_
- Concepts: _wiki/concepts/_
- Entities: _wiki/entities/_
- Projects: _wiki/projects/_
- Index: _wiki/index.md_
- Logs: _wiki/log.md_

Non-negotiable rules:

- Keep raw source notes source-faithful
- Do not overwrite raw source content during compilation
- Use plain tags only
- Use `topics` and `sources` frontmatter on compiled wiki notes
- Treat `source_count` as derived
- Keep compiled notes short, single-purpose, and source-traceable
- Uncovered raw sources are ingest backlog, not errors: track them with `source-coverage --uncovered`; lint does not fail on them
- Query from _wiki/index.md_ before opening broad context


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
