import Cocoa

class StackView: NSStackView {
    convenience init(_ views: [NSView], _ orientation: NSUserInterfaceLayoutOrientation = .horizontal, _ shouldFit: Bool = true, top: CGFloat = 0, right: CGFloat = 0, bottom: CGFloat = 0, left: CGFloat = 0) {
        self.init(views: views)
        translatesAutoresizingMaskIntoConstraints = false
        edgeInsets = NSEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        alignment = orientation == .horizontal ? .firstBaseline : .leading
        if shouldFit {
            // Used to special-case horizontal stacks containing a `CustomRecorderControl` (a
            // fittingSize.height quirk with that Settings-only shortcut-recorder widget). That
            // type no longer exists — it was settings-window-only — so this always fits plainly now.
            fit()
        }
    }
}
