# hammerspoon/

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
