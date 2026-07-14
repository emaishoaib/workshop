# workshop

> Where I build and maintain the tools that run my machine.

A personal collection of macOS automation scripts, AI agent tooling, and anything else that makes my setup work smarter. Equal parts reference for myself and resource for anyone who finds it useful.

---

# New machine setup

```bash
git clone git@github.com:mustafa.shoaib/workshop.git ~/Documents_Public/repos/workshop
cd ~/Documents_Public/repos/workshop
bash setup.sh
source ~/.zshrc
```

`setup.sh` installs prerequisites (fzf, gh, pypdf, send2trash) and wires the shell config into `~/.zshrc`. Any machine-specific config can still live in `~/.zshrc` alongside it as normal.

---

# `shell/`

`init.zsh` is the single entry point sourced by `~/.zshrc`. It loads fzf, git functions, shell aliases, and (if present) `work_aliases.zsh` — everything in the repo that should be available in every shell session.

General aliases in `aliases.zsh`:

| Alias | Description |
|-------|-------------|
| `czsh` | Open `~/.zshrc` in VS Code |
| `rzsh` | Reload `~/.zshrc` |
| `mergeinv` | Merge paired invoice PDFs in the current directory (see `scripts/`) |

`prompt.zsh` sets a green `PROMPT` (`user@host cwd %`) using zsh's portable `%F{color}` escapes, so it renders correctly in any terminal emulator without needing terminal-specific config.

# `work_aliases.zsh`

Work-project specific functions. Deliberately **not version controlled** (gitignored) since it's tied to a specific employer's tooling/repos — `init.zsh` sources it only if the file exists, so a fresh clone works fine without it.

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
| `gbra` | `git branch` — passes all arguments through directly |
| `gbra delete` | Fuzzy delete local branch; if the branch also exists remotely, prompts to delete it there too |
| `gbra rename <new-name>` | Rename current branch locally and remotely |
| `gchy` | `git cherry-pick` — passes all arguments through directly |
| `gchy branch` | Fuzzy-pick a branch, then multi-select (Tab) from the commits unique to that branch, and cherry-pick them onto the current branch, oldest first |
| `gcko` | Fuzzy checkout — local branches only |
| `gcko remote` | Fuzzy checkout — all branches (local + remote) |
| `gcko pr [number]` | Checkout a PR by number, or fuzzy-pick from open PRs |
| `glog` | Show all commits introduced on current branch (or `-N` for last N, e.g. `glog -5`) |
| `glog branch` | Fuzzy-pick a local branch to compare against; shows commits on current branch not in the selection |
| `gpush` | `git push` — passes all arguments through directly |
| `gpush force` | Force-push current branch to its tracked upstream (`git push --force-with-lease`) |
| `gpush head` | Fuzzy-pick a remote branch, then force-push HEAD to it (`git push origin HEAD:<branch> --force-with-lease`) |
| `gpush head:<branch>` | Force-push HEAD straight to `<branch>`, no prompt |
| `gpush new` | Push a newly created local branch to origin and set up tracking (`git push -u origin HEAD`) |
| `gsmod` | `git submodule` — passes all arguments through directly |
| `gsmod reset` | Sync all submodules to the commit pinned by the parent repo (`git submodule update --init`) — fixes the "S" (submodule with new commits) indicator in VS Code |
| `grbe` | `git rebase` — passes all arguments through directly |
| `grbe branch` | Fuzzy-pick a local branch, then interactive rebase over commits on current branch not in that branch |
| `grbe preview` | Fuzzy-pick a commit from those on the current branch vs the default branch, and surface it in VS Code for observation |
| `grbe onto` | Fuzzy-pick a local branch to rebase onto, then fuzzy-pick the fork point SHA from commits on the current branch |
| `grbe all` | Interactive rebase over every commit on the current branch vs the default branch — no guessing a commit count |
| `gtools` | Interactive GitHub + SSH helper — fzf-pick to create repos, list repos, clone, manage SSH keys |
| `gunlock` | Remove a stale git index lock (`rm -f .git/index.lock`) — fixes "Another git process seems to be running" after a crashed/killed git process |
| `ghelp` | Print all available commands and aliases |

## `gtools`

Interactive GitHub + SSH helper. Run `gtools` from anywhere — fzf picks the action, then walks through any inputs:

- **Create new repo** — pick personal or org account, name, visibility, optional README, optional local clone
- **List repos** — pick account, shows name, visibility, description, and URL
- **Clone a repo** — pick account, fzf over all repos, clone into a named directory
- **List SSH keys** — shows all public keys with fingerprints, agent-loaded keys, and optionally adds a key to the agent

Requires `gh` (installed by `setup.sh`).

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
ln -sf ~/Documents_Public/repos/workshop/vscode/settings.json \
  ~/Library/Application\ Support/Code/User/settings.json

ln -sf ~/Documents_Public/repos/workshop/vscode/keybindings.json \
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
| `workshopSync.repoPath` | `~/Documents_Public/repos/workshop` | Path to the workshop repo |

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

## Markdown behaviour

`formatOnSave` and `trimTrailingWhitespace` are both disabled for Markdown via a `[markdown]` language override in `settings.json`. This prevents Prettier (or any active Markdown formatter) from reflowing content on every `⌘S`, and preserves intentional trailing spaces (which are valid line-break syntax in Markdown).

# `cmux/`

Config for [cmux](https://cmux.com/), the terminal used to run AI coding agents in parallel. `setup.sh` installs the app itself (`brew install --cask cmux`, if it's not already in `/Applications`), then symlinks its settings into place. cmux splits its settings across two files, both version-controlled here:

| File | Symlinked to | Controls |
|------|-------------|----------|
| `cmux/cmux.json` | `~/.config/cmux/cmux.json` | App-level settings — shortcuts, sidebar, notifications, custom commands, browser behaviour |
| `cmux/ghostty/config` | `~/.config/ghostty/config` | Terminal rendering — theme, font, colors, cursor (cmux renders via libghostty) |

NOTE -- stuff like a prompt color, for example, isn't set here - it comes from `shell/prompt.zsh`, since the prompt is a shell-level concept, not a terminal one. `cmux/` is for things that are genuinely terminal-specific, like keybindings or the color palette of the terminal itself.

To wire it up manually:

```bash
mkdir -p ~/.config/cmux ~/.config/ghostty
ln -sf ~/Documents_Public/repos/workshop/cmux/cmux.json ~/.config/cmux/cmux.json
ln -sf ~/Documents_Public/repos/workshop/cmux/ghostty/config ~/.config/ghostty/config
```

## cmux CLI on PATH

cmux ships a `cmux` CLI binary inside its app bundle (`/Applications/cmux.app/Contents/Resources/bin/cmux`), installed on first launch of the app. It's only on `PATH` automatically inside shells that cmux itself opens — `shell/init.zsh` adds that bin directory to `PATH` (guarded by an existence check) so `cmux` also works from iTerm2, Terminal.app, or any other shell. If you've just installed cmux for the first time, launch it once, then `source ~/.zshrc`.

## cmux socket access mode

The `cmux` CLI (and the Raycast extension in `raycast/`) talk to the running app over a Unix socket (`~/.local/state/cmux/cmux.sock` by default per `cmux --help` — cmux.com's docs site says `/tmp/cmux.sock`, which is stale for the version this repo was set up against; override either way with `CMUX_SOCKET_PATH`). By default, cmux only accepts connections from processes it spawned itself — so `cmux` commands work fine from a workspace shell inside cmux, but fail with a broken-pipe error from any other terminal, or from Raycast.

`shell/init.zsh` runs `launchctl setenv CMUX_SOCKET_MODE allowAll` so cmux accepts connections from **any local process**, not just ones it launched — this is what makes the Raycast extension (and running `cmux` from any other terminal) work. It only takes effect for apps launched after it's set, so quit and relaunch cmux once after cloning this repo.

**Tradeoff:** `allowAll` means any process running as you — not just your own shells — can read workspace state over that socket, and can call `cmux send` to inject keystrokes into your terminals. This is a reasonable default on a personal, single-user machine, but per cmux's own docs, avoid it on a shared machine. If that's a concern, remove the `launchctl setenv` block from `shell/init.zsh`; the CLI and Raycast extension will then only work when invoked from inside cmux itself.

# `raycast/`

A Raycast extension (`raycast/cmux-workspaces/`) that jumps to an open cmux workspace by name: type a few letters, the list fuzzy-narrows live (Raycast's built-in `List` filtering, not a hardcoded Quicklink), arrow keys or Enter to select, and it switches cmux to that workspace and brings the app forward.

Needs `CMUX_SOCKET_MODE=allowAll` (see above) since Raycast runs it as its own subprocess, not one cmux spawned.

**Requires signing in to Raycast.** Raycast doesn't require an account for everyday use, but its Import Extension / Store / dev-extension flow does gate behind a sign-in — there's no way around that from the extension side.

Raycast has no CLI-installable-extension mechanism, so this is the one setup step that stays manual — see `raycast/README.md` for build and import instructions.

# `ai/`

Global Claude instructions, kept here so they're version-controlled and consistent across machines. `CLAUDE.md` is symlinked from `~/.claude/CLAUDE.md` so Claude Code picks it up globally and any changes are tracked in git.

This is handled automatically by `setup.sh`, but to wire it up manually:

```bash
mkdir -p ~/.claude
ln -sf ~/Documents_Public/repos/workshop/ai/CLAUDE.md ~/.claude/CLAUDE.md
```

# `scripts/`

Standalone utility scripts for day-to-day tasks, on `$PATH` automatically via `shell/init.zsh` (available as commands in every shell session after `setup.sh` runs). See [`scripts/README.md`](scripts/README.md) for what's available and how to use each one.

---

*More to come as the workshop grows.*