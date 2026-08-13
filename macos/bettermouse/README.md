# macos/bettermouse/

Version-controlled export of [BetterMouse](https://better-mouse.com/)'s
configuration (`better_mouse_config.plist`), so the mouse/keyboard remaps it
holds aren't only living in `~/Library/Preferences/com.naotanhaocan.BetterMouse.plist`
on one machine.

## Why this exists

`cmd+alt+s` and `cmd+alt+r` used to be handled by
[`hammerspoon/`](../../hammerspoon/README.md) (re-posting `cmd+shift+4` and
`cmd+shift+5` respectively — see the note in
[`modules/hotkeys.lua`](../../hammerspoon/modules/hotkeys.lua)). They stopped
firing after a BetterMouse update; the exact cause wasn't confirmed, but
quitting BetterMouse restored the Hammerspoon shortcuts, and disabling
whatever changed in that update wasn't worth the time. As a stopgap, the same
two shortcuts are now remapped directly inside BetterMouse instead, and this
file is BetterMouse's exported config with that remap in place.

## File format

BetterMouse exports this as an Apple *binary* property list (`bplist00`),
which is unreadable in an editor and produces useless git diffs. It's
version-controlled here as an XML plist instead, converted with:

```bash
plutil -convert xml1 better_mouse_config.plist
```

macOS/BetterMouse read XML plists the same as binary ones, so this only
affects how the file looks on disk, not how it's used. Re-run this after
re-exporting from BetterMouse, since exports come out binary by default.

## Restoring on a new machine

BetterMouse → Preferences → the import/export option in its settings → import
`better_mouse_config.plist`.

## Revisiting the Hammerspoon conflict

If you're investigating why BetterMouse and Hammerspoon fought over
`cmd+alt+s`/`cmd+alt+r`, or want to move these back to
[`hammerspoon/modules/hotkeys.lua`](../../hammerspoon/modules/hotkeys.lua):

1. Remove the remap from BetterMouse's preferences (or import a version of
   this plist without it).
2. Re-add the two `hs.hotkey.bind` calls to `hotkeys.lua` (previously their
   own module, `modules/system.lua`, since removed — see git history).
3. Re-export BetterMouse's config and update this plist.
