import Cocoa

enum LabelPosition {
    case right
}

/// Control-binding toolkit. Originally `preferences/settings-window/LabelAndControl.swift` (~370
/// lines covering every Settings-UI control type: dropdowns, sliders, radio buttons, shortcut
/// recorders, image buttons, info popovers, search indexing, etc). Trimmed twice now: once down
/// to just the checkbox path when settings-window/ was deleted, and again here to drop the
/// `TextField`/`SettingsSearchIndex`/`Switch`/`ActionClosure`+`NSControl.onAction` dependencies
/// that came along with the original checkbox path but were never actually exercised by it (the
/// `PermissionsWindow` checkbox always uses `labelPosition: .right`, which short-circuits before
/// touching any of those). The only remaining caller is `PermissionsWindow`'s screen-recording
/// skip checkbox.
class LabelAndControl: NSObject {
    static func makeLabelWithCheckbox(_ labelText: String, _ rawName: String, labelPosition: LabelPosition = .right) -> [NSView] {
        let checkbox = NSButton(checkboxWithTitle: labelText, target: nil, action: nil)
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        checkbox.state = CachedUserDefaults.bool(rawName) ? .on : .off
        checkbox.identifier = NSUserInterfaceItemIdentifier(rawName)
        let wrapper = CheckboxActionWrapper(rawName)
        checkbox.target = wrapper
        checkbox.action = #selector(CheckboxActionWrapper.checkboxToggled(_:))
        objc_setAssociatedObject(checkbox, &CheckboxActionWrapper.associationKey, wrapper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return [checkbox]
    }
}

/// `NSControl.target` is unowned/unsafe, so this wrapper (retained on the checkbox via
/// associated object) is what actually receives the action and writes the preference.
private class CheckboxActionWrapper: NSObject {
    static var associationKey: UInt8 = 0
    let rawName: String

    init(_ rawName: String) {
        self.rawName = rawName
    }

    @objc func checkboxToggled(_ sender: NSButton) {
        Preferences.set(rawName, String(sender.state == .on))
    }
}
