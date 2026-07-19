import Cocoa
import Carbon.HIToolbox.Events
import ShortcutRecorder

/// The live, in-memory shortcut registry — extracted out of `ControlsTab` (Settings UI) so the
/// core hotkey engine doesn't depend on Settings UI code. `ControlsTab` used to own this state
/// directly (it's still called "the global shortcut-registry logic" in its own doc comment) because
/// nobody had split "what shortcut is bound to what" (needed by `KeyboardEvents`, `ATShortcut`,
/// `TilesView`, `KeyRepeatTimer` — all core engine) from "how do we draw the row that lets you
/// record a new one" (Settings-only).
///
/// This does NOT change behavior. It's a pure move: every function here is the same code that
/// used to live in `ControlsTab.swift`, with the UI-refresh side effects (editor rebind, sidebar
/// row refresh, appearance tab label refresh) dropped — those only matter while the Settings
/// window is open, which never happens in this headless build. If Settings UI is ever restored,
/// re-wire `preferenceChanged` here to also call back into `ControlsTab`'s UI refresh methods.
///
/// Nothing is marked `private` here (unlike the original) since `ControlsTab`'s remaining UI
/// callbacks (`shortcutChangedCallback`, `arrowKeysEnabledCallback`, etc.) still call into this
/// registry — e.g. when the user records a new shortcut in Settings, that flow still needs to
/// reach `addShortcut`/`removeShortcutIfExists` here.
class ShortcutRegistry {
    /// Runtime model of all globally-bound shortcuts, keyed by their identifier
    /// (`holdShortcut0`, `nextWindowShortcut2`, etc.). Read by KeyboardEvents, KeyRepeatTimer,
    /// ATShortcut, TilesView, CustomRecorderControl, and the conflict detectors.
    static var shortcuts = [String: ATShortcut]()

    static let arrowKeys = ["←", "→", "↑", "↓"]
    static let arrowKeyCodes: Set<KeyCode> = [.leftArrow, .rightArrow, .upArrow, .downArrow]
    static let vimKeyActions = [
        "h": "vimCycleLeft",
        "l": "vimCycleRight",
        "k": "vimCycleUp",
        "j": "vimCycleDown",
    ]
    // "searchShortcut"/"lockSearchShortcut" removed along with the search-in-switcher feature —
    // no shortcut is ever bound for them now, so search mode is structurally unreachable.
    static let staticManagedShortcutPreferences = [
        "focusWindowShortcut", "previousWindowShortcut", "cancelShortcut",
        "closeWindowShortcut", "minDeminWindowShortcut", "toggleFullscreenWindowShortcut", "quitAppShortcut", "hideShowAppShortcut",
    ]

    // MARK: - Startup / preference-change entry points (called from PreferencesEvents.swift)

    static func initializePreferencesDependentState() {
        applyActiveShortcutPreferences()
        staticManagedShortcutPreferences.forEach { applyShortcutPreference($0) }
        applyArrowKeysPreferenceWithoutDialogs()
        applyVimKeysPreferenceWithoutDialogs()
    }

    /// Trimmed from `ControlsTab.preferenceChanged(_:)` — registry-relevant branches only. The
    /// original also refreshed Settings UI (editor rebind, sidebar rows, appearance tab labels);
    /// that's dropped here since Settings is never shown in this build.
    static func preferenceChanged(_ key: String) {
        switch key {
        case "shortcutCount":
            applyActiveShortcutPreferences()
        case let k where isShortcutPreferenceKey(k):
            let i = Preferences.nameToIndex(k)
            if i < Preferences.shortcutCount {
                applyShortcutPreference(k)
            } else {
                removeShortcutIfExists(k)
            }
        case let k where staticManagedShortcutPreferences.contains(k):
            applyShortcutPreference(k)
        case "arrowKeysEnabled":
            applyArrowKeysPreferenceWithoutDialogs()
        case "vimKeysEnabled":
            applyVimKeysPreferenceWithoutDialogs()
        default:
            break
        }
    }

    static func isShortcutPreferenceKey(_ key: String) -> Bool {
        return (0..<Preferences.maxShortcutCount).contains(where: { index in
            ["holdShortcut", "nextWindowShortcut"].contains { key == Preferences.indexToName($0, index) }
        })
    }

    // MARK: - Shortcut registry (global keyboard binding — unchanged from the old ControlsTab code)

    static func applyActiveShortcutPreferences() {
        (0..<Preferences.maxShortcutCount).forEach { index in
            ["holdShortcut", "nextWindowShortcut"].forEach { base in
                let key = Preferences.indexToName(base, index)
                if index < Preferences.shortcutCount {
                    applyShortcutPreference(key)
                } else {
                    removeShortcutIfExists(key)
                }
            }
        }
    }

    static func addShortcut(_ triggerPhase: ShortcutTriggerPhase, _ scope: ShortcutScope, _ shortcut: Shortcut, _ controlId: String, _ index: Int?) {
        let atShortcut = ATShortcut(shortcut, controlId, scope, triggerPhase, index)
        removeShortcutIfExists(controlId)
        shortcuts[controlId] = atShortcut
        if scope == .global {
            KeyboardEvents.addGlobalShortcut(controlId, atShortcut.shortcut)
            toggleNativeCommandTabIfNeeded()
        }
        recomputeEscapeAbsorption()
    }

    /// Issue #5585. The shared cghidEventTap absorbs Esc keyDown only when a configured shortcut
    /// binds Escape; otherwise Esc passes through to the active app unchanged.
    static func recomputeEscapeAbsorption() {
        KeyboardEvents.anyShortcutUsesEscape = shortcuts.values.contains { $0.shortcut.carbonKeyCode == kVK_Escape }
    }

    /// Thin adapter over `NativeHotkeyResolver.resolve` — builds the snapshot inputs from the live
    /// shortcut registry and applies the resolver's verdict via the symbolic-hotkey API. Moved
    /// verbatim from `ControlsTab`; `NativeHotkeyResolver` itself still lives under
    /// `preferences/settings-window/tabs/controls/` — fine for now since it's small/self-contained,
    /// worth relocating whenever that folder is finally extracted/removed.
    static func toggleNativeCommandTabIfNeeded() {
        let snapshots = shortcuts.values.map { ShortcutSnapshot(modifiers: $0.shortcut.carbonModifierFlags, keyCode: $0.shortcut.carbonKeyCode) }
        let holdShortcutModifiers: [UInt32] = (0..<Preferences.holdShortcut.count).compactMap { i in
            shortcuts[Preferences.indexToName("holdShortcut", i)]?.shortcut.carbonModifierFlags
        }
        let result = NativeHotkeyResolver.resolve(shortcuts: snapshots, holdShortcutModifiers: holdShortcutModifiers)
        setNativeCommandTabEnabled(false, Array(result.disable))
        setNativeCommandTabEnabled(true, Array(result.enable))
    }

    static func removeShortcutIfExists(_ controlId: String) {
        if let atShortcut = shortcuts[controlId] {
            if atShortcut.scope == .global {
                KeyboardEvents.removeGlobalShortcut(controlId, atShortcut.shortcut)
            }
            shortcuts.removeValue(forKey: controlId)
            if atShortcut.scope == .global {
                toggleNativeCommandTabIfNeeded()
            }
            recomputeEscapeAbsorption()
        }
    }

    static func applyShortcutPreference(_ controlId: String) {
        if isShortcutPreferenceKey(controlId) && Preferences.nameToIndex(controlId) >= Preferences.shortcutCount {
            removeShortcutIfExists(controlId)
            return
        }
        if controlId.hasPrefix("holdShortcut") {
            applyHoldShortcutPreference(controlId)
            applyShortcutPreference(Preferences.indexToName("nextWindowShortcut", Preferences.nameToIndex(controlId)))
            return
        }
        guard let shortcut = combinedShortcut(controlId) else {
            removeShortcutIfExists(controlId)
            restrictModifiersOfHoldShortcut(controlId, [])
            return
        }
        addShortcut(.down, controlId.hasPrefix("nextWindowShortcut") ? .global : .local, shortcut, controlId, nil)
        restrictModifiersOfHoldShortcut(controlId, [shortcut.modifierFlags])
    }

    static func applyHoldShortcutPreference(_ controlId: String) {
        let i = Preferences.nameToIndex(controlId)
        guard let shortcut = Preferences.shortcut(controlId) else {
            removeShortcutIfExists(controlId)
            return
        }
        addShortcut(.up, .global, shortcut, controlId, i)
    }

    /// Used to live: restricted which modifiers the Settings hold-shortcut *recorder widget*
    /// would accept while the user was actively typing a new shortcut, to prevent recording a
    /// combo that conflicts with the paired next-window shortcut. Purely a Settings-UI input
    /// guard — has zero effect on which shortcuts actually trigger — and `ControlsTab.shortcutControls`
    /// (the recorder-widget registry it read from) is always empty once Settings is never shown.
    /// No-op now that `preferences/settings-window/` is gone; kept as a stub so `applyShortcutPreference`'s
    /// call sites don't need to change.
    static func restrictModifiersOfHoldShortcut(_ controlId: String, _ modifiers: NSEvent.ModifierFlags) {
    }

    static func combinedShortcut(_ controlId: String) -> Shortcut? {
        guard let baseShortcut = Preferences.shortcut(controlId) else { return nil }
        if controlId.starts(with: "nextWindowShortcut") {
            let holdShortcut = Preferences.shortcut(Preferences.indexToName("holdShortcut", Preferences.nameToIndex(controlId)))
            return combineShortcuts(holdShortcut, baseShortcut)
        }
        return baseShortcut
    }

    static func combineShortcuts(_ holdShortcut: Shortcut?, _ baseShortcut: Shortcut) -> Shortcut {
        guard let holdShortcut else { return baseShortcut }
        return Shortcut(code: baseShortcut.keyCode, modifierFlags: [holdShortcut.modifierFlags, baseShortcut.modifierFlags], characters: baseShortcut.characters, charactersIgnoringModifiers: baseShortcut.charactersIgnoringModifiers)
    }

    static func applyArrowKeysPreferenceWithoutDialogs() {
        guard Preferences.arrowKeysEnabled else {
            arrowKeys.forEach { removeShortcutIfExists($0) }
            return
        }
        if hasArrowKeysConflictWithoutUi() {
            arrowKeys.forEach { removeShortcutIfExists($0) }
            Preferences.set("arrowKeysEnabled", "false", false)
            return
        }
        arrowKeys.forEach { addShortcut(.down, .local, Shortcut(keyEquivalent: $0)!, $0, nil) }
    }

    static func hasArrowKeysConflictWithoutUi() -> Bool {
        return shortcuts.values.contains {
            guard arrowKeyCodes.contains($0.shortcut.keyCode) else { return false }
            return !arrowKeys.contains($0.id)
        }
    }

    static func applyVimKeysPreferenceWithoutDialogs() {
        guard Preferences.vimKeysEnabled else {
            vimKeyActions.forEach { removeShortcutIfExists($1) }
            return
        }
        if hasVimKeysConflictWithoutUi() {
            vimKeyActions.forEach { removeShortcutIfExists($1) }
            Preferences.set("vimKeysEnabled", "false", false)
            return
        }
        vimKeyActions.forEach { addShortcut(.down, .local, Shortcut(keyEquivalent: $0)!, $1, nil) }
    }

    static func hasVimKeysConflictWithoutUi() -> Bool {
        return shortcuts.values.contains {
            if let key = $0.shortcut.characters, vimKeyActions.keys.contains(key) {
                return !vimKeyActions.values.contains($0.id)
            }
            return false
        }
    }
}
