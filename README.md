# agent-config

Centralized configuration for AI coding agents, shared across multiple tools.

## Structure

```
agent-config/
├── AGENTS.md                # Shared agent instructions
├── claude-settings.json     # Claude Code settings
├── codex-config.toml        # Codex settings
├── statusline-command.sh    # Claude Code statusline renderer
├── agents/                  # Claude Code subagents
├── hooks/                   # Claude Code hook scripts
├── plugins/                 # Plugin defaults
│   ├── caveman/config.json
│   └── ponytail/config.json
├── skills/                  # Skills
└── .claude/skills/link/     # "link" skill: links skills/ into ~/.claude/skills
```

## Symlinks

Nothing in this repo is read from here directly. Each tool reads its own
location, and those locations are symlinks pointing back into this repo, so
edits take effect without a copy step.

| Repo file | Symlinked to |
| --- | --- |
| `AGENTS.md` | `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md` |
| `claude-settings.json` | `~/.claude/settings.json` |
| `codex-config.toml` | `~/.codex/config.toml` |
| `statusline-command.sh` | `~/.claude/statusline-command.sh` |
| `skills/*` | one symlink per skill inside `~/.claude/skills` (see the `link` skill) |
| `agents/` | `~/.claude/agents` |
| `hooks/` | `~/.claude/hooks` |
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
ln -sfn "$REPO/agents"                 ~/.claude/agents
ln -sfn "$REPO/hooks"                  ~/.claude/hooks

# Codex
ln -sfn "$REPO/AGENTS.md"              ~/.codex/AGENTS.md
ln -sfn "$REPO/codex-config.toml"       ~/.codex/config.toml
ln -sfn "$REPO/skills"                 ~/.codex/skills

# Plugin defaults (caveman, ponytail)
ln -sfn "$REPO/plugins/caveman/config.json"   ~/.config/caveman/config.json
ln -sfn "$REPO/plugins/ponytail/config.json"  ~/.config/ponytail/config.json
```

Move an existing real file out of the way before linking over it — `ln -sfn`
will happily replace it and the contents are gone.

### Skill symlinks

`~/.claude/skills` is a real directory holding one symlink per skill in
`skills/` rather than a single link to the directory, so hand-added skills
alongside them keep working:

```sh
~/agent-config/.claude/skills/link/link.sh
```

Or ask Claude Code to run the `link` skill from inside this repo.

Re-run it after adding or removing a skill. It is idempotent, prunes links to
skills that no longer exist, and leaves anything it did not create alone.
Pass a different destination as the first argument to link somewhere else.

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

## Cloning this repo

No special flags needed. A regular clone gets everything:

```sh
git clone https://github.com/tyrelh/agent-config.git
```
