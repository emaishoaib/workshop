# workshop

> Where I build and maintain the tools that run my machine.

A personal collection of macOS automation scripts, AI agent tooling, and anything else that makes my setup work smarter. Equal parts reference for myself and resource for anyone who finds it useful.

---

# New machine setup

```bash
git clone git@github.com:mustafa.shoaib/workshop.git ~/docs/repos/workshop
cd ~/docs/repos/workshop
bash setup.sh
source ~/.zshrc
```

`setup.sh` installs prerequisites (fzf, gh, pypdf, send2trash), wires the shell config into `~/.zshrc`, configures a global gitignore (`.dbtoolsrc`, used by [`db/`](db/README.md)'s tooling, is always ignored machine-wide, not just where you remember to add it), and builds + installs [AltTab (headless)](macos/alt-tab/README.md) (requires Xcode, not just Command Line Tools — skipped with a warning if missing). Any machine-specific config can still live in `~/.zshrc` alongside it as normal.

---

# What's here

Each directory has its own README with the full detail — this is just the map.

| Directory | What's there |
|-----------|--------------|
| [`shell/`](shell/README.md) | Entry point sourced by `~/.zshrc`, general aliases, prompt |
| [`db/`](db/README.md) | Docker/Alembic DB tooling (`ddb`, `dmig`) — config-driven, plus a gitignored slot for employer-specific hook implementations |
| [`git/`](git/README.md) | Fzf-powered git functions: branch, rebase, push, PR checkout, and a GitHub/SSH helper (`gtools`) |
| [`hammerspoon/`](hammerspoon/README.md) | macOS automation — hotkeys, Finder shortcuts, login hooks |
| [`vscode/`](vscode/README.md) | Synced settings and keybindings, the extension list, and two custom extensions |
| [`cmux/`](cmux/README.md) | Config for the cmux terminal — app settings, Ghostty theme, PATH setup, socket access mode |
| [`raycast/`](raycast/README.md) | Raycast extension for jumping to an open cmux workspace by name. Requires signing in to Raycast; see its README for the (manual) build/import steps |
| [`ai/`](ai/CLAUDE.md) | Global Claude instructions, symlinked to `~/.claude/CLAUDE.md` so changes stay version-controlled |
| [`macos/alt-tab/`](macos/alt-tab/README.md) | Headless, two-shortcut fork of AltTab — built and installed automatically by `setup.sh` |
| [`macos/manual-setup.md`](macos/manual-setup.md) | macOS settings that can't be automated — check this on any new machine |
| [`macos/screen-recording-internal-audio.md`](macos/screen-recording-internal-audio.md) | Free screen recording with internal computer audio, using BlackHole |
| [`scripts/`](scripts/README.md) | Standalone utility scripts, on `$PATH` automatically via `shell/init.zsh` |

---

*More to come as the workshop grows.*
