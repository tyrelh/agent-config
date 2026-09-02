# agent-config

Centralized configuration for AI coding agents, shared across multiple tools.

## Structure

```
agent-config/
├── AGENTS.md                # Shared agent instructions
├── claude-settings.json     # Claude Code settings
├── statusline-command.sh    # Claude Code statusline renderer
├── agents/                  # Claude Code subagents
├── plugins/                 # Plugin defaults
│   ├── caveman/config.json
│   └── ponytail/config.json
└── skills/                  # Git subtree from Giftbit/agent-skills
```

## Symlinks

Nothing in this repo is read from here directly. Each tool reads its own
location, and those locations are symlinks pointing back into this repo, so
edits take effect without a copy step.

| Repo file | Symlinked to |
| --- | --- |
| `AGENTS.md` | `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md` |
| `claude-settings.json` | `~/.claude/settings.json` |
| `statusline-command.sh` | `~/.claude/statusline-command.sh` |
| `skills/` | `~/.claude/skills`, `~/.codex/skills` |
| `agents/` | `~/.claude/agents` |
| `plugins/caveman/config.json` | `~/.config/caveman/config.json` |
| `plugins/ponytail/config.json` | `~/.config/ponytail/config.json` |

### Creating the symlinks

Run from anywhere. `ln -sfn` replaces an existing link rather than nesting a
new one inside it, which is what plain `ln -s` does when the target is already
a directory symlink.

```sh
REPO=~/agent-config

mkdir -p ~/.claude ~/.codex ~/.config/caveman ~/.config/ponytail

# Claude Code
ln -sfn "$REPO/AGENTS.md"              ~/.claude/CLAUDE.md
ln -sfn "$REPO/claude-settings.json"   ~/.claude/settings.json
ln -sfn "$REPO/statusline-command.sh"  ~/.claude/statusline-command.sh
ln -sfn "$REPO/skills"                 ~/.claude/skills
ln -sfn "$REPO/agents"                 ~/.claude/agents

# Codex
ln -sfn "$REPO/AGENTS.md"              ~/.codex/AGENTS.md
ln -sfn "$REPO/skills"                 ~/.codex/skills

# Plugin defaults (caveman, ponytail)
ln -sfn "$REPO/plugins/caveman/config.json"   ~/.config/caveman/config.json
ln -sfn "$REPO/plugins/ponytail/config.json"  ~/.config/ponytail/config.json
```

Move an existing real file out of the way before linking over it — `ln -sfn`
will happily replace it and the contents are gone.

### Verifying

```sh
ls -la ~/.claude ~/.codex ~/.config/caveman ~/.config/ponytail | grep -- '->'
```

### Installing the plugins

`enabledPlugins` in `claude-settings.json` only says which plugins *should* be
on; it does not fetch them. Claude Code refuses to load an enabled plugin whose
files aren't on disk and prints the `claude plugin install` command instead. So
on a fresh machine, register the marketplaces and install the plugins from the
same file that lists them:

```sh
REPO=~/agent-config

jq -r '.extraKnownMarketplaces[].source | .repo // .url' "$REPO/claude-settings.json" \
  | xargs -n1 claude plugin marketplace add

jq -r '.enabledPlugins | keys[]' "$REPO/claude-settings.json" \
  | xargs -n1 claude plugin install
```

Both loops are idempotent, so re-run them after adding a plugin on another
machine and pulling. Order matters: a plugin install fails until its
marketplace is on disk.

### Plugin defaults

`plugins/*/config.json` sets the default intensity level the caveman and
ponytail plugins start a session at:

```json
{ "defaultMode": "full" }
```

Caveman accepts `off`, `lite`, `full`, `ultra`, `wenyan-lite`, `wenyan`,
`wenyan-full`, `wenyan-ultra`. Ponytail accepts `off`, `lite`, `full`,
`ultra`. Both fall back to `full` when the file is absent.

A `CAVEMAN_DEFAULT_MODE` or `PONYTAIL_DEFAULT_MODE` environment variable
outranks the file, and an explicit `/caveman lite` outranks both for that
session. `$XDG_CONFIG_HOME`, when set, replaces `~/.config` as the directory
each plugin looks in.

## Working with the skills subtree

The `skills/` directory is a [git subtree](https://www.atlassian.com/git/tutorials/git-subtree) linked to [Giftbit/agent-skills](https://github.com/Giftbit/agent-skills). All files are fully committed in this repo, so it works as a standalone clone. The subtree remote is named `agent-skills`.

### Making changes to skills

Edit files in `skills/` and commit normally:

```sh
git add skills/
git commit -m "Update some skill"
```

### Pushing skill changes directly to Giftbit/agent-skills

```sh
git subtree push --prefix=skills agent-skills main
```

### Pushing skill changes via PR

To push changes to a feature branch on Giftbit/agent-skills for code review:

```sh
# 1. Edit files in skills/, commit normally in this repo
git add skills/
git commit -m "Add new skill"

# 2. Push to a feature branch on Giftbit/agent-skills
git subtree push --prefix=skills agent-skills my-feature-branch

# 3. Open a PR from my-feature-branch into main on Giftbit/agent-skills

# 4. After the PR is merged, pull main back into this repo
git subtree pull --prefix=skills agent-skills main --squash
```

Branches in this repo and Giftbit/agent-skills are independent — you don't need to be on a matching branch here. The subtree push rewrites commits with the `skills/` prefix stripped, so commits in Giftbit/agent-skills will have different SHAs.

### Pulling updates from Giftbit/agent-skills

```sh
git subtree pull --prefix=skills agent-skills main --squash
```

The `--squash` flag collapses incoming changes into a single merge commit to keep this repo's history clean.

### Cloning this repo

No special flags needed. A regular clone gets everything:

```sh
git clone https://github.com/tyrelh/agent-config.git
```

After cloning, add the subtree remote so you can push/pull to the skills repo:

```sh
cd agent-config
git remote add agent-skills https://github.com/Giftbit/agent-skills.git
```
