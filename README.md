# agent-config

Centralized configuration for AI coding agents, shared across multiple tools.

## Structure

```
agent-config/
└── skills/          # Git subtree from Giftbit/agent-skills
```

## Working with the skills subtree

The `skills/` directory is a [git subtree](https://www.atlassian.com/git/tutorials/git-subtree) linked to [Giftbit/agent-skills](https://github.com/Giftbit/agent-skills). All files are fully committed in this repo, so it works as a standalone clone. The subtree remote is named `agent-skills`.

### Making changes to skills

Edit files in `skills/` and commit normally:

```sh
git add skills/
git commit -m "Update some skill"
```

### Pushing skill changes to Giftbit/agent-skills

```sh
git subtree push --prefix=skills agent-skills main
```

### Pulling updates from Giftbit/agent-skills

```sh
git subtree pull --prefix=skills agent-skills main --squash
```

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
