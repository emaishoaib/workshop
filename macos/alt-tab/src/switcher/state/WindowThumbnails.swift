import Cocoa

/// Off-main-thread screenshot capture for window thumbnails, plus the
/// "preview the selected window" overlay shown next to the switcher panel.
enum WindowThumbnails {
    /// Used to show/hide the standalone `PreviewPanel` (a full-size ghost preview of the selected
    /// window, floated behind the tile grid). `previewFocusedWindow` defaults to `false` and there's
    /// no Settings UI to turn it on anymore, so `PreviewPanel.swift` was deleted and this is now a
    /// no-op. Left in place (rather than removing all 6 call sites) since it's a harmless stub.
    static func previewSelectedIfNeeded() {}

    // dispatch screenshot requests off the main-thread, then wait for completion
    static func refreshAsync(_ windows: [Window], _ source: RefreshCausedBy, windowRemoved: Bool = false, prioritizedIds: Set<CGWindowID>? = nil) {
        let shortcutIndex = SwitcherSession.activeShortcutIndex
        guard (!windows.isEmpty || windowRemoved) && ScreenRecordingPermission.status == .granted
               && (!Appearance.hideThumbnails || Preferences.effectivePreviewSelectedWindow(shortcutIndex))
               && (Preferences.captureWindowsInBackground || SwitcherSession.isActive) else { return }
        var eligibleWindows = [Window]()
        for window in windows {
            if !window.isWindowlessApp, let cgWindowId = window.cgWindowId, cgWindowId != CGWindowID(bitPattern: -1) {
                eligibleWindows.append(window)
            }
        }
        guard (!eligibleWindows.isEmpty || windowRemoved) else { return }
        if #available(macOS 14.0, *),
           // mitigate macOS 15 bugs with ScreenCapture Kit (see https://github.com/lwouis/alt-tab-macos/issues/5190)
           ProcessInfo.processInfo.operatingSystemVersion.majorVersion != 15 {
            WindowCaptureScreenshots.oneTimeScreenshots(eligibleWindows, source, prioritizedIds: prioritizedIds)
        } else {
            WindowCaptureScreenshotsPrivateApi.oneTimeScreenshots(eligibleWindows, source, prioritizedIds: prioritizedIds)
        }
    }
}
