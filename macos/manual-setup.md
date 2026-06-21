# Manual macOS Setup

Things that can't be scripted and need to be done by hand on a new machine.

---

## Keyboard: disable "Move focus to next window"

**Where:** System Settings → Keyboard → Keyboard Shortcuts → Keyboard → "Move focus to next window"

**Why:** macOS assigns `Cmd+`` ` to this system-wide, which conflicts with VS Code's terminal toggle (`Cmd+`` `). When multiple VS Code windows are open, macOS intercepts the key before VS Code sees it, making the terminal shortcut unreliable. Disabling it here lets VS Code own `Cmd+`` ` reliably.
