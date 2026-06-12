# workshop

> Where I build and maintain the tools that run my machine.

A personal collection of macOS automation scripts, AI agent tooling, and anything else that makes my setup work smarter. Equal parts reference for myself and resource for anyone who finds it useful.

---

# `git/`

Fzf-powered git functions and aliases. Replaces tedious branch/file picking with fuzzy search.

## Prerequisites

```bash
brew install fzf && $(brew --prefix)/opt/fzf/install
brew install gh && gh auth login
```

## Setup

```bash
# Source the functions in your shell
echo 'source ~/path/to/workshop/git/functions.zsh' >> ~/.zshrc
source ~/.zshrc

# Add to ~/.gitconfig to enable git aliases:
[include]
    path = ~/path/to/workshop/git/aliases.gitconfig
```

## Functions

| Command | Description |
|---------|-------------|
| `gco` | Fuzzy checkout — all branches (local + remote) |
| `gcol` | Fuzzy checkout — local branches only |
| `gbd` | Fuzzy delete local branch |
| `gbdr` | Fuzzy delete remote branch |
| `gadd` | Fuzzy `git add` (multi-select with Tab) |
| `gres` | Fuzzy `git restore` (multi-select with Tab) |
| `gstash` | Fuzzy stash pop |
| `gsha` | Fuzzy checkout a commit (detached HEAD) |
| `gpr [number]` | Checkout a PR by number, or fuzzy-pick from open PRs |
| `grbi` | Interactive rebase over all commits on current branch (auto-detects `main`/`master`) |
| `git rbi` | Same as `grbi` but as a native git alias (requires `aliases.gitconfig` include) |

# `hammerspoon/`
Lua scripts for [Hammerspoon](https://www.hammerspoon.org/) — macOS automation triggered by system events, hotkeys, and login hooks.

## Setup

Move your existing Hammerspoon config into the repo, then symlink so Hammerspoon
can still find it at the path it expects:

```bash
# 1. Copy your existing init.lua into the repo first
cp ~/.hammerspoon/init.lua ~/Documents/.../hammerspoon/init.lua

# 2. Delete the original
rm -rf ~/.hammerspoon

# 3. Symlink the repo folder to where Hammerspoon expects its config
ln -s ~/Documents/.../hammerspoon ~/.hammerspoon
```

Then reload Hammerspoon from the menu bar icon. From this point all changes
are version controlled — Hammerspoon reads directly from the repo via the symlink.

# `ai/`
AI agent skills, prompts, and integrations. Includes reusable skill definitions and any tooling built around LLM workflows.

---

*More to come as the workshop grows.*