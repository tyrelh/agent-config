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
