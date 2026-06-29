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

`setup.sh` installs prerequisites (fzf, gh, pypdf, send2trash) and wires the shell config into `~/.zshrc`. Any machine-specific config can still live in `~/.zshrc` alongside it as normal.

---

# `shell/`

`init.zsh` is the single entry point sourced by `~/.zshrc`. It loads fzf, git functions, shell aliases, and docker helpers — everything in the repo that should be available in every shell session.

General aliases in `aliases.zsh`:

| Alias | Description |
|-------|-------------|
| `czsh` | Open `~/.zshrc` in VS Code |
| `rzsh` | Reload `~/.zshrc` |
| `mergeinv` | Merge paired invoice PDFs in the current directory (see `scripts/`) |

# `git/`

Fzf-powered git functions. Replaces tedious branch/file picking with fuzzy search.

## Prerequisites

```bash
brew install fzf && $(brew --prefix)/opt/fzf/install
brew install gh && gh auth login
```

## Functions

| Command | Description |
|---------|-------------|
| `gbra` | List all local branches |
| `gbra -d` / `gbra --delete` | Fuzzy delete local branch |
| `gbra -dr` / `gbra --remote-delete` | Fuzzy delete remote branch |
| `gbra -re <new-name>` / `gbra --rename <new-name>` | Rename current branch locally and remotely |
| `gcko` | Fuzzy checkout — local branches only |
| `gcko -r` | Fuzzy checkout — all branches (local + remote) |
| `gcko -pr [number]` | Checkout a PR by number, or fuzzy-pick from open PRs |
| `gcoma` | Amend the last commit |
| `glog` | Show all commits introduced on current branch (oneline) |
| `glog -c` / `glog --compare` | Fuzzy-pick a local branch to compare against; shows commits on current branch not in the selection. Inferred parent branch is labelled in the list. |
| `grbe -i` / `grbe --interactive` | Interactive rebase over all commits on current branch (auto-detects `main`/`master`) |
| `grbe -p` / `grbe --pick` | Fuzzy-pick a commit with a changed-files preview; on select, surfaces changes in VS Code for observation |
| `grbe -c` / `grbe --continue` | Continue an in-progress rebase (`git rebase --continue`) |
| `grbe -d` / `grbe --done` | Finish a `grbe -p` session — aborts the rebase and restores any stashed changes |
| `grbe -o` / `grbe --onto` | Fuzzy-pick a local branch to rebase onto, then fuzzy-pick the fork point SHA from commits on the current branch |
| `ghelp` | Print all available commands and aliases |
| `gstash <name>` | Multi-select changed files to stash under a name (`Tab` select, `Enter` confirm) |

# `hammerspoon/`
Lua scripts for [Hammerspoon](https://www.hammerspoon.org/) — macOS automation triggered by system events, hotkeys, and login hooks.

## Hotkeys

| Shortcut | Context | Description |
|----------|---------|-------------|
| `⌘⇧T` | Finder frontmost | Open current Finder folder in iTerm2 (if installed) or Terminal |
| `⌘↩` | Finder frontmost | Open selected item (`cmd+o`) |
| `⌃L` | Global | Lock screen |

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

# `macos/`

`manual-setup.md` documents macOS system changes that can't be automated — things like keyboard shortcut conflicts that need to be resolved in System Settings. Check this on any new machine setup.

# `vscode/`

VS Code user settings, kept here so they're version-controlled and consistent across machines. Both files are symlinked into the VS Code user config directory so any changes are tracked in git.

This is handled automatically by `setup.sh`, but to wire it up manually:

```bash
ln -sf ~/Documents_Public/repos_personal/workshop/vscode/settings.json \
  ~/Library/Application\ Support/Code/User/settings.json

ln -sf ~/Documents_Public/repos_personal/workshop/vscode/keybindings.json \
  ~/Library/Application\ Support/Code/User/keybindings.json
```

## `vscode/extensions.txt`

A list of installed marketplace extensions, one ID per line. Maintained automatically by the `workshop-sync` extension — any install or uninstall updates this file immediately. Commit the change to keep the repo current.

`setup.sh` reads this file on a new machine and installs everything via `code --install-extension`.

## `vscode/extensions/workshop-sync/`

A custom VS Code extension that keeps `vscode/extensions.txt` in sync automatically. Writes the full list of non-built-in extensions on startup and on every install/uninstall.

To build and install:

```bash
cd vscode/extensions/workshop-sync
npm install
npm run compile
npx vsce package
code --uninstall-extension emaishoaib.workshop-sync 2>/dev/null; true
code --install-extension "$(ls workshop-sync-*.vsix | tail -1)"
```

Config:

| Setting | Default | Description |
|---------|---------|-------------|
| `workshopSync.repoPath` | `~/Documents_Public/repos_personal/workshop` | Path to the workshop repo |

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

# `scripts/`

Standalone utility scripts for day-to-day macOS tasks. Each script is self-contained and runnable directly from the terminal.

Dependencies are managed by `setup.sh` — no manual `pip install` needed on a fresh machine.

## `merge_invoices.py`

Merges paired PDF files that follow this naming convention:

```
20250121 - Amazon Echo Dot.pdf           ← order details
20250121 - Amazon Echo Dot Invoice.pdf   ← invoice
```

For each matched pair it appends the invoice pages to the order-details PDF, overwrites the base file in place, and moves the separate invoice file to Trash.

```bash
# Preview without making changes
python scripts/merge_invoices.py ~/path/to/pdfs --dry-run

# Merge all pairs in a directory
python scripts/merge_invoices.py ~/path/to/pdfs
```

The `mergeinv` shell alias runs this against the current directory for quick use after opening a folder via `⌘⇧T`.

Requires: `pypdf`, `send2trash` (both installed by `setup.sh`)

---

*More to come as the workshop grows.*