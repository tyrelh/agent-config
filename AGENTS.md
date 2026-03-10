About me: My name is Tyrel, I'm a senior software developer focusing on platform development and infrastructure. My GitHub handle is @tyrelh. I focus on developer experience. I work hard to craft interactions that are simple and intuitive.

About my work: I work at Giftbit (https://giftbit.com). We're building a system to sell digital gift cards B2B. We primarily use GitHub Actions & Workflows for our CI/CD automations. We use AWS as our core hosting provider. We use Terraform to define infrastructure. Our backend is written in Go and runs in a Docker container on AWS ECS. Our frontend is written in TypeScript and React and is served from both static S3 buckets and from AWS Amplify.

## Project context
Projects may contain configurations from other types of agents. You should read these into context.
- .cursor/rules/*.md in the root of the project. This contains multiple rule files each with a file glob pattern in it's metadata discribing which kinds of files it's applicable for.

## Git Etiquette
When using git, you should follow these conventions:
- Never add co-author information to commits unless explicitly asked by the user.

## Skills
A skill is a set of local instructions to follow that is stored in a `SKILL.md` file. Below is the list of skills that can be used. Each entry includes a name, description, and file path so you can open the source for full instructions when using a specific skill.
### Available skills
- datadog-logs: Interact with Datadog Logs via the Datadog API using bash scripts for searching, tailing, aggregating, and exporting error logs. Use when working with Datadog error logs, building log queries, or retrieving log data from the API. (file: /Users/tyrel/.codex/skills/datadog-logs/SKILL.md)
- gh-address-comments: Help address review/issue comments on the open GitHub PR for the current branch using gh CLI; verify gh auth first and prompt the user to authenticate if not logged in. (file: /Users/tyrel/.codex/skills/gh-address-comments/SKILL.md)
- gh-debug-actions: Debug GitHub Actions workflow runs and deployments by locating the relevant run, fetching logs (full or failed-only), and summarizing root causes. Use when asked to debug failed GitHub Actions runs, explain why a workflow run failed, retrieve logs, or investigate CI/CD deployments. Supports default repos Giftbit/lightrail and Giftbit/giftbitfe, and any explicitly specified repo. (file: /Users/tyrel/.codex/skills/gh-debug-actions/SKILL.md)
- gh-fix-ci: Use when a user asks to debug or fix failing GitHub PR checks that run in GitHub Actions; use `gh` to inspect checks and logs, summarize failure context, draft a fix plan, and implement only after explicit approval. Treat external providers (for example Buildkite) as out of scope and report only the details URL. (file: /Users/tyrel/.codex/skills/gh-fix-ci/SKILL.md)
- gh-pr: Use this skill when a user asks to create a GitHub PR (pull request). It contains conventions for creating PRs. (file: /Users/tyrel/.codex/skills/gh-pr/SKILL.md)
- git-branch: Use this skill when creating git branches. It contains conventions for creating branches. (file: /Users/tyrel/.codex/skills/git-branch/SKILL.md)
- manage-shortcut-stories: Manage Shortcut stories via API. Use when you need to find or create a Shortcut ticket, list projects/workflows/teams, assign owners/teams, fetch story details, or update a story's workflow state to in-progress (started) or ready-for-review. Includes keyword-based search with user prompts, story creation, and story updates. (file: /Users/tyrel/.codex/skills/manage-shortcut-stories/SKILL.md)
- openai-docs: Use when the user asks how to build with OpenAI products or APIs and needs up-to-date official documentation with citations (for example: Codex, Responses API, Chat Completions, Apps SDK, Agents SDK, Realtime, model capabilities or limits); prioritize OpenAI docs MCP tools and restrict any fallback browsing to official OpenAI domains. (file: /Users/tyrel/.codex/skills/openai-docs/SKILL.md)
- skill-creator: Guide for creating effective skills. This skill should be used when users want to create a new skill (or update an existing skill) that extends Codex's capabilities with specialized knowledge, workflows, or tool integrations. (file: /Users/tyrel/.codex/skills/.system/skill-creator/SKILL.md)
- skill-installer: Install Codex skills into $CODEX_HOME/skills from a curated list or a GitHub repo path. Use when a user asks to list installable skills, install a curated skill, or install a skill from another repo (including private repos). (file: /Users/tyrel/.codex/skills/.system/skill-installer/SKILL.md)
- htmx: HTMX development guidelines for building dynamic web applications with minimal JavaScript using HTML attributes. (file: /Users/tyrel/.codex/skills/htmx/SKILL.md)
- terraform-giftbit: Terraform workflows infrastructure on AWS with Datadog and Stytch providers. Use when Codex needs to create or update Terraform modules, add or refactor resources, manage state/backends, or edit environment configuration in `config/env.tfvars` files that CI/CD iterates over. (file: /Users/tyrel/.codex/skills/terraform-giftbit/SKILL.md)
### How to use skills
- Discovery: The list above is the skills available in this session (name + description + file path). Skill bodies live on disk at the listed paths.
- Trigger rules: If the user names a skill (with `$SkillName` or plain text) OR the task clearly matches a skill's description shown above, you must use that skill for that turn. Multiple mentions mean use them all. Do not carry skills across turns unless re-mentioned.
- Missing/blocked: If a named skill isn't in the list or the path can't be read, say so briefly and continue with the best fallback.
- How to use a skill (progressive disclosure):
  1) After deciding to use a skill, open its `SKILL.md`. Read only enough to follow the workflow.
  2) When `SKILL.md` references relative paths (e.g., `scripts/foo.py`), resolve them relative to the skill directory listed above first, and only consider other paths if needed.
  3) If `SKILL.md` points to extra folders such as `references/`, load only the specific files needed for the request; don't bulk-load everything.
  4) If `scripts/` exist, prefer running or patching them instead of retyping large code blocks.
  5) If `assets/` or templates exist, reuse them instead of recreating from scratch.
- Coordination and sequencing:
  - If multiple skills apply, choose the minimal set that covers the request and state the order you'll use them.
  - Announce which skill(s) you're using and why (one short line). If you skip an obvious skill, say why.
- Context hygiene:
  - Keep context small: summarize long sections instead of pasting them; only load extra files when needed.
  - Avoid deep reference-chasing: prefer opening only files directly linked from `SKILL.md` unless you're blocked.
  - When variants exist (frameworks, providers, domains), pick only the relevant reference file(s) and note that choice.
- Safety and fallback: If a skill can't be applied cleanly (missing files, unclear instructions), state the issue, pick the next-best approach, and continue.