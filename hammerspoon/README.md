# hammerspoon/

Lua scripts for [Hammerspoon](https://www.hammerspoon.org/) — macOS automation triggered by system events, hotkeys, and login hooks.

## Hotkeys

| Shortcut | Context | Description |
|----------|---------|-------------|
| `⌘⇧T` | Finder frontmost | Open current Finder folder in iTerm2 (if installed) or Terminal |
| `⌘↩` | Finder frontmost | Open selected item (`cmd+o`) |
| `⌃L` | Global | Lock screen |
| `⌘⌥P` | Global | Play a sound (media/attention cue) |

`⌘⌥S` (save picture of selected area as a file) and `⌘⌥R` (screenshot and
recording options) are *not* handled here right now — see the note in
[`modules/hotkeys.lua`](modules/hotkeys.lua) and
[`../macos/bettermouse/README.md`](../macos/bettermouse/README.md) for why.

## Keyboard

[`modules/keyboard.lua`](modules/keyboard.lua) swaps two keys on the
MacBook's built-in ISO keyboard, so they match the US layout:

- The `§ ±` key, left of `1`, types `` ` ~ ``.
- The `` ` ~ `` key, left of `Z`, types `§ ±`.

The swap is applied when Hammerspoon loads and again on every wake from
sleep. External keyboards are left alone.

The module matches the built-in keyboard by its vendor ID (`0x5ac`, Apple)
and product ID (`0x343`). The product ID differs between MacBook models, so
on another Mac the swap does nothing until it's updated. To find the right
ID, look for "Apple Internal Keyboard" in the output of `hidutil list`.

To put both keys back until the next reload:

```bash
hidutil property --matching '{"VendorID":0x5ac,"ProductID":0x343}' --set '{"UserKeyMapping":[]}'
```

## Setup

`setup.sh` installs Hammerspoon with Homebrew if it isn't already in
`/Applications`, then creates the symlink below. After a fresh install, open
Hammerspoon once and grant it Accessibility access in System Settings →
Privacy & Security. Its hotkeys don't fire without it.

If you already have a Hammerspoon config that isn't in the repo yet, setup
won't overwrite it. Move it into the repo by hand first, then symlink so
Hammerspoon can still find it at the path it expects:

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
