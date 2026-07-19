import Cocoa

struct ShortcutAction {
    let id: String
    let perform: () -> Void
}

enum ShortcutActions {
    static let all: [ShortcutAction] = [
        ShortcutAction(id: "focusWindowShortcut", perform: { App.focusTarget() }),
        ShortcutAction(id: "previousWindowShortcut", perform: { App.previousWindowShortcutWithRepeatingKey() }),
        ShortcutAction(id: "→", perform: { App.cycleSelection(.right) }),
        ShortcutAction(id: "←", perform: { App.cycleSelection(.left) }),
        ShortcutAction(id: "↑", perform: { App.cycleSelection(.up) }),
        ShortcutAction(id: "↓", perform: { App.cycleSelection(.down) }),
        ShortcutAction(id: "vimCycleRight", perform: { App.cycleSelection(.right) }),
        ShortcutAction(id: "vimCycleLeft", perform: { App.cycleSelection(.left) }),
        ShortcutAction(id: "vimCycleUp", perform: { App.cycleSelection(.up) }),
        ShortcutAction(id: "vimCycleDown", perform: { App.cycleSelection(.down) }),
        ShortcutAction(id: "cancelShortcut", perform: {
            // Used to route through `SearchModeResolver.escape(...)` to decide between exiting
            // search-editing vs. closing the switcher entirely. Search-in-switcher was deleted
            // (searchMode is now structurally always `.off`), so Escape always closes the switcher.
            App.hideUi()
        }),
        ShortcutAction(id: "closeWindowShortcut", perform: { Windows.selectedWindow()?.close() }),
        ShortcutAction(id: "minDeminWindowShortcut", perform: { Windows.selectedWindow()?.minDemin() }),
        ShortcutAction(id: "toggleFullscreenWindowShortcut", perform: { Windows.selectedWindow()?.toggleFullscreen() }),
        ShortcutAction(id: "quitAppShortcut", perform: { Windows.selectedWindow()?.application.quit() }),
        ShortcutAction(id: "hideShowAppShortcut", perform: { Windows.selectedWindow()?.application.hideOrShow() }),
        // "searchShortcut"/"lockSearchShortcut" actions removed along with search-in-switcher.
    ]

    private static let byId: [String: ShortcutAction] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func find(_ id: String) -> ShortcutAction? {
        byId[id]
    }

    static func execute(_ id: String) {
        // Used to gate *pressing* a Pro-only shortcut slot (index >= 1) here via
        // `ProFeature.extraShortcut(index:).attemptUse()` — always returned true since
        // LicenseManager was hardcoded to `.pro`. Dropped along with `pro/`.
        if let action = find(id) {
            action.perform()
            return
        }
        if id.hasPrefix("holdShortcut") {
            App.focusTarget()
            return
        }
        if id.hasPrefix("nextWindowShortcut") {
            App.showUiOrCycleSelection(Preferences.nameToIndex(id), false)
        }
    }
}
