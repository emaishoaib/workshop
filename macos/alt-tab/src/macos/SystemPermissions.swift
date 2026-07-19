import Cocoa

enum PermissionStatus {
    case granted
    case notGranted
    case skipped
}

// macOS has some privacy restrictions. The user needs to grant certain permissions, app by app, in System Preferences > Security & Privacy
//
// Startup is gated behind a custom `PermissionsWindow` explaining each permission with its own
// "Open Settings…" button. Neither permission check here ever triggers a native macOS
// alert on its own: `AccessibilityPermission` deliberately never passes
// `kAXTrustedCheckOptionPrompt: true` (so the "AltTab would like to control this computer"
// dialog never surfaces), and `ScreenRecordingPermission` uses `CGPreflightScreenCaptureAccess`
// instead of probing via ScreenCaptureKit/CGDisplayStream (which would trigger the "would like
// to record this computer's screen" dialog as a side effect — see the comment on
// `ScreenRecordingPermission.detect()` below for the trade-off that entails). The custom window
// is the only UI ever asking the user to grant either permission.
class SystemPermissions {
    static var preStartupPermissionsPassed = false
    private static var timer: DispatchSourceTimer!
    private static var timerIsFrequent = false
    // After permissions are granted at startup, we listen for `com.apple.accessibility.api`
    // on the distributed notification center to learn about revocation, instead of polling
    // every 5s. The notification name is undocumented by Apple and its firing behaviour across
    // every System Settings action (toggle off, remove from list, etc.) is not reliably
    // characterised in public sources, so we also keep a sparse 60s backstop timer below.
    // Infra requirements: NSDistributedNotificationCenter since 10.15 ignores nil-name
    // observers (we pass a name) and since macOS 15 silently fails for unsigned binaries
    // (AltTab is Developer ID signed). macOS 13+ has a known bug where `AXIsProcessTrusted`
    // can return stale values right after a toggle; we call `AccessibilityPermission.update()`
    // which re-runs the API rather than caching.
    private static let axRevokeNotificationName = "com.apple.accessibility.api"
    private static var distributedObserver: NSObjectProtocol?
    private static var reactivationObserver: NSObjectProtocol?
    private static var hasBecomeActiveOnce = false

    static func ensurePermissionsAreGranted() {
        timer = DispatchSource.makeTimerSource(queue: BackgroundWork.permissionsCheckOnTimerQueue.strongUnderlyingQueue)
        timer.setEventHandler(handler: checkPermissionsOnTimer)
        setImmediateTimer()
        timer.resume()
    }

    /// `CGPreflightScreenCaptureAccess` (see `ScreenRecordingPermission.detect()`) avoids ever
    /// showing macOS's native screen-recording alert, but its return value can go stale if the
    /// permission is toggled in System Settings while this process keeps running — the exact
    /// thing the "Open Screen Recording Settings…" button invites the user to do. Rather than
    /// making the user remember to manually relaunch, we watch for AltTab regaining focus (the
    /// natural signal that they just switched back from System Settings) and restart automatically
    /// so the next process gets a guaranteed-fresh preflight read. Only relevant pre-startup,
    /// while `PermissionsWindow` might be asking for something; a no-op once granted.
    static func startListeningForReactivationDuringPreStartup() {
        guard reactivationObserver == nil else { return }
        reactivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            guard !preStartupPermissionsPassed else { return }
            // The very first activation is just normal launch; nothing to refresh yet. Only
            // *regaining* activation (after having been elsewhere, e.g. System Settings) matters.
            guard hasBecomeActiveOnce else {
                hasBecomeActiveOnce = true
                return
            }
            Logger.info { "AltTab regained focus while permissions were pending; restarting for a fresh screen-recording read" }
            App.restart()
        }
    }

    private static func startListeningForDistributedRevoke() {
        guard distributedObserver == nil else { return }
        distributedObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(axRevokeNotificationName),
            object: nil,
            queue: nil
        ) { _ in
            BackgroundWork.permissionsCheckOnTimerQueue.addOperation {
                if AccessibilityPermission.update() == .notGranted {
                    Logger.error { "Accessibility permission revoked (distributed notification); restarting" }
                    DispatchQueue.main.async { App.restart() }
                }
            }
        }
    }

    private static func checkPermissionsOnTimer() {
        AccessibilityPermission.update()
        let isPermissionsWindowVisible = PermissionsWindow.shared?.isVisible ?? false
        if !preStartupPermissionsPassed || isPermissionsWindowVisible {
            ScreenRecordingPermission.update()
        }
        Logger.debug { "accessibility:\(AccessibilityPermission.status) screenRecording:\(ScreenRecordingPermission.status)" }
        if !preStartupPermissionsPassed {
            checkPermissionsPreStartup()
        } else {
            checkPermissionsPostStartup()
            if isPermissionsWindowVisible && !timerIsFrequent {
                setFrequentTimer()
            } else if !isPermissionsWindowVisible && timerIsFrequent {
                setInfrequentTimer()
            }
        }
        DispatchQueue.main.async {
            if PermissionsWindow.shared != nil {
                PermissionsWindow.updatePermissionViews()
            }
        }
    }

    private static func checkPermissionsPreStartup() {
        if AccessibilityPermission.status != .notGranted && ScreenRecordingPermission.status != .notGranted {
            DispatchQueue.main.async {
                preStartupPermissionsPassed = true
                PermissionsWindow.shared?.close()
                setInfrequentTimer()
                startListeningForDistributedRevoke()
                App.continueAppLaunchAfterPermissionsAreGranted()
            }
        } else {
            DispatchQueue.main.async {
                App.showPermissionsWindow()
                startListeningForReactivationDuringPreStartup()
            }
        }
    }

    private static func checkPermissionsPostStartup() {
        if AccessibilityPermission.status == .notGranted {
            Logger.error { "Accessibility permission revoked while AltTab was running; restarting" }
            DispatchQueue.main.async { App.restart() }
        }
    }

    // Post-startup, with the distributed-notification listener wired up, we only need a sparse
    // backstop poll. The notification's firing behaviour isn't fully characterised, so the 60s
    // timer is the recovery path for cases where it doesn't fire.
    static func setInfrequentTimer() {
        timerIsFrequent = false
        if preStartupPermissionsPassed && distributedObserver != nil {
            timer.schedule(deadline: .now() + 60, repeating: 60, leeway: .seconds(10))
            return
        }
        timer.schedule(deadline: .now() + 5, repeating: 5, leeway: .seconds(1))
    }

    static func setFrequentTimer() {
        timerIsFrequent = true
        timer.schedule(deadline: .now(), repeating: 0.5, leeway: .milliseconds(500))
    }

    private static func setImmediateTimer() {
        timerIsFrequent = false
        timer.schedule(deadline: .now(), repeating: .never, leeway: .never)
    }
}

class AccessibilityPermission {
    static var status = PermissionStatus.notGranted

    @discardableResult
    static func update() -> PermissionStatus {
        status = detect()
        return status
    }

    private static func detect() -> PermissionStatus {
        // `prompt: false` is deliberate — this never triggers macOS's native accessibility dialog.
        // The custom `PermissionsWindow` is the only UI that asks the user to grant this.
        return AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeRetainedValue(): false] as CFDictionary) ? .granted : .notGranted
    }
}

class ScreenRecordingPermission {
    static var status = PermissionStatus.notGranted

    @discardableResult
    static func update() -> PermissionStatus {
        status = detect()
        return status
    }

    private static func detect() -> PermissionStatus {
        if #available(macOS 10.15, *) {
            guard !Preferences.screenRecordingPermissionSkipped else { return .skipped }
            // `CGPreflightScreenCaptureAccess()` reports current authorization status without
            // ever surfacing macOS's native "would like to record this computer's screen" alert.
            // The previous approach (probing via SCShareableContent/CGDisplayStream — see git
            // history) triggers that native alert as an unavoidable side effect the first time
            // it's called while the permission is undecided; upstream AltTab used it anyway since
            // it (unlike the preflight call) reliably reflects live status changes without
            // needing a relaunch. We prefer never showing an unprompted native dialog over that:
            // the custom PermissionsWindow's "Open Screen Recording Settings…" button is the only
            // path meant to lead the user toward granting it.
            //
            // Known caveat: CGPreflightScreenCaptureAccess's return value isn't guaranteed to
            // live-update if the permission is toggled while this process keeps running. Rather
            // than requiring a manual relaunch, `startListeningForReactivationDuringPreStartup()`
            // auto-restarts the app when it regains focus after the user has likely just been in
            // System Settings, so this stays accurate without the user having to do anything.
            //
            // Note: `WindowCaptureEvents.swift`'s actual thumbnail-capture path still calls
            // `SCShareableContent` directly when capturing a screenshot — that's the real API
            // that needs frame data, not just a yes/no. By the time a user reaches that path
            // they will already have granted or explicitly skipped the permission via this
            // window, so it should not surprise them with a fresh native prompt in practice.
            return CGPreflightScreenCaptureAccess() ? .granted : .notGranted
        }
        return .granted
    }
}
