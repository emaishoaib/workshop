# cmux/

Config for [cmux](https://cmux.com/), the terminal used to run AI coding agents in parallel. `setup.sh` installs the app itself (`brew install --cask cmux`, if it's not already in `/Applications`), then symlinks its settings into place. cmux splits its settings across two files, both version-controlled here:

| File | Symlinked to | Controls |
|------|-------------|----------|
| `cmux/cmux.json` | `~/.config/cmux/cmux.json` | App-level settings — shortcuts, sidebar, notifications, custom commands, browser behaviour |
| `cmux/ghostty/config` | `~/.config/ghostty/config` | Terminal rendering — theme, font, colors, cursor (cmux renders via libghostty) |

NOTE -- stuff like a prompt color, for example, isn't set here - it comes from [`shell/prompt.zsh`](../shell/README.md), since the prompt is a shell-level concept, not a terminal one. `cmux/` is for things that are genuinely terminal-specific, like keybindings or the color palette of the terminal itself.

To wire it up manually:

```bash
mkdir -p ~/.config/cmux ~/.config/ghostty
ln -sf ~/Documents_Public/repos/workshop/cmux/cmux.json ~/.config/cmux/cmux.json
ln -sf ~/Documents_Public/repos/workshop/cmux/ghostty/config ~/.config/ghostty/config
```

## cmux CLI on PATH

cmux ships a `cmux` CLI binary inside its app bundle (`/Applications/cmux.app/Contents/Resources/bin/cmux`), installed on first launch of the app. It's only on `PATH` automatically inside shells that cmux itself opens — `shell/init.zsh` adds that bin directory to `PATH` (guarded by an existence check) so `cmux` also works from iTerm2, Terminal.app, or any other shell. If you've just installed cmux for the first time, launch it once, then `source ~/.zshrc`.

## cmux socket access mode

The `cmux` CLI (and the Raycast extension in [`raycast/`](../README.md)) talk to the running app over a Unix socket (`~/.local/state/cmux/cmux.sock` by default per `cmux --help` — cmux.com's docs site says `/tmp/cmux.sock`, which is stale for the version this repo was set up against; override either way with `CMUX_SOCKET_PATH`). By default, cmux only accepts connections from processes it spawned itself — so `cmux` commands work fine from a workspace shell inside cmux, but fail with a broken-pipe error from any other terminal, or from Raycast.

`shell/init.zsh` runs `launchctl setenv CMUX_SOCKET_MODE allowAll` so cmux accepts connections from **any local process**, not just ones it launched — this is what makes the Raycast extension (and running `cmux` from any other terminal) work. It only takes effect for apps launched after it's set, so quit and relaunch cmux once after cloning this repo.

**Tradeoff:** `allowAll` means any process running as you — not just your own shells — can read workspace state over that socket, and can call `cmux send` to inject keystrokes into your terminals. This is a reasonable default on a personal, single-user machine, but per cmux's own docs, avoid it on a shared machine. If that's a concern, remove the `launchctl setenv` block from `shell/init.zsh`; the CLI and Raycast extension will then only work when invoked from inside cmux itself.
