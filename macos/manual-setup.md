# Manual macOS Setup

Things that can't be scripted and need to be done by hand on a new machine.

---

## Keyboard: disable "Move focus to next window"

**Where:** System Settings → Keyboard → Keyboard Shortcuts → Keyboard → "Move focus to next window"

**Why:** macOS assigns `Cmd+`` ` to this system-wide, which conflicts with VS Code's terminal toggle (`Cmd+`` `). When multiple VS Code windows are open, macOS intercepts the key before VS Code sees it, making the terminal shortcut unreliable. Disabling it here lets VS Code own `Cmd+`` ` reliably.

## Keyboard: reassign (don't just disable) "Move focus to next window" for AltTab's Alt+`` ` shortcut

**Where:** System Settings → Keyboard → Keyboard Shortcuts → Keyboard → "Move focus to next window"

**Why:** [AltTab (headless)](alt-tab/README.md)'s active-app-only shortcut is `Alt+`` ` (see its README). On this machine, "Move focus to next window" was also bound to that combo, and it intermittently swallowed the keypress before AltTab ever saw it — so `Alt+`` ` would work most of the time, then silently do nothing.

**Important — unlike the VS Code case above, unticking the checkbox is not a reliable fix here.** Even fully disabled (checkbox off), macOS still intercepted the keypress some of the time and consumed it, producing no visible action — worse than either behavior working consistently, since it looked like a flaky AltTab bug rather than a system-level conflict. The fix that actually worked: reassign the shortcut itself to a different combo entirely (e.g. `Cmd+`` `, same character, different modifier) rather than leaving it bound and disabled. Once reassigned away, `Alt+`` ` became fully reliable.

If another app's global shortcut ever seems to work "most of the time" and then randomly does nothing, check this same System Settings pane first and reassign (not just disable) anything sharing the combo.
