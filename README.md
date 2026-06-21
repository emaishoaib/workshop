# workshop

> Where I build and maintain the tools that run my machine.

A personal collection of macOS automation scripts, AI agent tooling, and anything else that makes my setup work smarter. Equal parts reference for myself and resource for anyone who finds it useful.

---

# New machine setup

```bash
git clone git@github.com:mustafa.shoaib/workshop.git ~/Documents_Public/repos_personal/workshop
cd ~/Documents_Public/repos_personal/workshop
bash setup.sh
source ~/.zshrc
```

`setup.sh` installs prerequisites (fzf, gh), wires the shell config into `~/.zshrc`, and adds the git aliases include to `~/.gitconfig`. Any machine-specific config can still live in `~/.zshrc` alongside it as normal.

---

# `shell/`

`init.zsh` is the single entry point sourced by `~/.zshrc`. It loads fzf, git functions, shell aliases, and docker helpers — everything in the repo that should be available in every shell session.

General aliases in `aliases.zsh`:

| Alias | Description |
|-------|-------------|
| `czsh` | Open `~/.zshrc` in VS Code |
| `rzsh` | Reload `~/.zshrc` |

# `docker/`

Docker helpers. Currently work-project specific.

| Function | Description |
|----------|-------------|
| `dcli` | Run a CLI command inside the app container |

# `git/`

Fzf-powered git functions and aliases. Replaces tedious branch/file picking with fuzzy search.

## Prerequisites

```bash
brew install fzf && $(brew --prefix)/opt/fzf/install
brew install gh && gh auth login
```

## Functions

| Command | Description |
|---------|-------------|
| `gck` | Fuzzy checkout — all branches (local + remote) |
| `gckl` | Fuzzy checkout — local branches only |
| `gckpr [number]` | Checkout a PR by number, or fuzzy-pick from open PRs |
| `gcoma` | Amend the last commit |
| `gdel` | Fuzzy delete local branch |
| `gdelr` | Fuzzy delete remote branch |
| `gfiles` | Fuzzy-pick a commit on the current branch and list the files it touched, with change status (`A`/`M`/`D`/`R`) |
| `glog` | Show all commits introduced on current branch (oneline) |
| `glogp` | Same as `glog` but relative to the branch this branch was branched off, rather than the default branch |
| `git blog` | Same as `glog` but as a native git alias (requires `aliases.gitconfig` include) |
| `grbi` | Interactive rebase over all commits on current branch (auto-detects `main`/`master`) |
| `git rbi` | Same as `grbi` but as a native git alias (requires `aliases.gitconfig` include) |
| `ghelp` | Print all available commands and aliases |
| `grem <new-name>` | Rename current branch locally and remotely (renames in place — no history rewrite) |
| `gstash <name>` | Multi-select changed files to stash under a name (`Tab` select, `Enter` confirm) |

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

# `vscode/`

VS Code user settings, kept here so they're version-controlled and consistent across machines. Both files are symlinked into the VS Code user config directory so any changes are tracked in git.

This is handled automatically by `setup.sh`, but to wire it up manually:

```bash
ln -sf ~/Documents_Public/repos_personal/workshop/vscode/settings.json \
  ~/Library/Application\ Support/Code/User/settings.json

ln -sf ~/Documents_Public/repos_personal/workshop/vscode/keybindings.json \
  ~/Library/Application\ Support/Code/User/keybindings.json
```

## `vscode/extensions/python-codelens/`

A custom VS Code extension that shows reference counts inline above Python classes and methods — the equivalent of PyCharm's "N usages" indicator. Pylance doesn't support this natively, so this fills the gap.

Built with the VS Code `CodeLensProvider` API: scans for `class` and `def` lines, then resolves counts lazily via Pylance's reference provider. Results are cached per symbol and invalidated on save.

To build and install:

```bash
cd vscode/extensions/python-codelens
npm install
npm run compile
npx vsce package
code --uninstall-extension emaishoaib.python-codelens 2>/dev/null; true
code --install-extension "$(ls python-codelens-*.vsix | tail -1)"
```

Config options (in `vscode/settings.json`):

| Setting | Default | Description |
|---------|---------|-------------|
| `pythonCodelens.enabled` | `true` | Toggle the extension on/off |
| `pythonCodelens.showZeroReferences` | `false` | Show lens even when count is 0 |

# `ai/`

Global Claude instructions, kept here so they're version-controlled and consistent across machines. `CLAUDE.md` is symlinked from `~/.claude/CLAUDE.md` so Claude Code picks it up globally and any changes are tracked in git.

This is handled automatically by `setup.sh`, but to wire it up manually:

```bash
mkdir -p ~/.claude
ln -sf ~/Documents_Public/repos_personal/workshop/ai/CLAUDE.md ~/.claude/CLAUDE.md
```

---

*More to come as the workshop grows.*