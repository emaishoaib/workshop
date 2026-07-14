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

# What's here

Each directory has its own README with the full detail — this is just the map.

| Directory | What's there |
|-----------|--------------|
| [`shell/`](shell/README.md) | Entry point sourced by `~/.zshrc`, general aliases, prompt — plus the gitignored `work_aliases.zsh` |
| [`git/`](git/README.md) | Fzf-powered git functions: branch, rebase, push, PR checkout, and a GitHub/SSH helper (`gtools`) |
| [`hammerspoon/`](hammerspoon/README.md) | macOS automation — hotkeys, Finder shortcuts, login hooks |
| [`vscode/`](vscode/README.md) | Synced settings and keybindings, the extension list, and two custom extensions |
| [`cmux/`](cmux/README.md) | Config for the cmux terminal — app settings, Ghostty theme, PATH setup, socket access mode |
| [`raycast/`](raycast/README.md) | Raycast extension for jumping to an open cmux workspace by name. Requires signing in to Raycast; see its README for the (manual) build/import steps |
| [`ai/`](ai/CLAUDE.md) | Global Claude instructions, symlinked to `~/.claude/CLAUDE.md` so changes stay version-controlled |
| [`macos/manual-setup.md`](macos/manual-setup.md) | macOS settings that can't be automated — check this on any new machine |
| [`scripts/`](scripts/README.md) | Standalone utility scripts, on `$PATH` automatically via `shell/init.zsh` |

---

*More to come as the workshop grows.*
