import Cocoa

class Button: NSButton {
    convenience init(_ title: String, _ action: @escaping (NSButton) -> Void) {
        self.init(title: title, target: nil, action: nil)
        let wrapper = ButtonActionWrapper(action)
        target = wrapper
        self.action = #selector(ButtonActionWrapper.callAction(_:))
        objc_setAssociatedObject(self, &ButtonActionWrapper.associationKey, wrapper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        translatesAutoresizingMaskIntoConstraints = false
        fit()
    }
}

/// `NSControl.target` is unowned/unsafe, so this wrapper (retained on the button via associated
/// object) is what actually receives the click and forwards it to the closure. Replaces the
/// generic `ActionClosure`/`NSControl.onAction` mechanism that used to live in the now-deleted
/// `HelperExtensionsTestable.swift` (that file's only other content, `resizedCopyWithCoreGraphics`,
/// stays deleted — genuinely unused).
private class ButtonActionWrapper: NSObject {
    static var associationKey: UInt8 = 0
    let action: (NSButton) -> Void

    init(_ action: @escaping (NSButton) -> Void) {
        self.action = action
    }

    @objc func callAction(_ sender: NSButton) {
        action(sender)
    }
}
