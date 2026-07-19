import Cocoa

class SleepWakeEvents {
    static func observe() {
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(handleWake), name: NSWorkspace.didWakeNotification, object: nil)
    }

    @objc private static func handleWake(_ notification: Notification) {
        Logger.info { "" }
        reEnableAllTaps()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { reEnableAllTaps() }
    }

    private static func reEnableAllTaps() {
        // (removed: TrackpadEvents/ScrollwheelEvents re-enable calls — deleted along with trackpad-gesture switching)
        KeyboardEvents.reEnableTapIfNeeded()
        CursorEvents.reEnableTapIfNeeded()
    }
}
