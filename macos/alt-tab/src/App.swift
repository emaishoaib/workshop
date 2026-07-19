import Cocoa
import Darwin
import ShortcutRecorder

class App: NSApplication {
    /// periphery:ignore
    static let activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep,
        reason: "Prevent App Nap to preserve responsiveness")
    static let bundleIdentifier = Bundle.main.bundleIdentifier!
    static let bundleURL = Bundle.main.bundleURL
    static let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
    static let licence = Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as! String
    static let repository = "https://github.com/lwouis/alt-tab-macos"
    static let appIconReps = CGImage.allNamed("app.icns")

    static func appIcon(for size: NSSize) -> CGImage {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let scaled = NSSize(width: size.width * scale, height: size.height * scale)
        return CGImage.bestMatch(appIconReps, for: scaled)
    }
    override class var shared: App { super.shared as! App }
    static var isTerminating = false
    private static var isVeryFirstSummon = true
    // don't queue multiple delayed rebuildUi() calls
    private static var delayedDisplayScheduled = 0
    private static let switcherUiRefreshThrottler = Throttler(delayInMs: 200)

    override init() {
        super.init()
        delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    /// we put application code here which should be executed on init() and Preferences change
    static func resetPreferencesDependentComponents() {
        TilesView.reset()
    }

    static func restart() {
        // we use -n to open a new instance, to avoid calling applicationShouldHandleReopen
        // we use Bundle.main.bundlePath in case of multiple AltTab versions on the machine
        printStackTrace()
        Process.launchedProcess(launchPath: "/usr/bin/open", arguments: ["-n", Bundle.main.bundlePath])
        App.shared.terminate(nil)
    }

    static func hideUi(_ keepPreview: Bool = false) {
        Logger.info { "active:\(SwitcherSession.isActive)" }
        guard SwitcherSession.current != nil else { return } // already hidden
        SwitcherSession.current = nil
        // (removed: UsageStats.resetSession() — UsageStats only ever fed the pro-upsell usage-count
        // UI, which was deleted along with pro/; nothing read its stats back, so UsageStats.swift/
        // UsageStatsTestable.swift were deleted too)
        ContextMenuEvents.toggle(false)
        CursorEvents.toggle(false)
        // (removed: TrackpadEvents.reset() — trackpad-gesture switching was deleted along with TrackpadEvents.swift/ScrollwheelEvents.swift)
        Tooltips.hideAll()
        hideTilesPanelWithoutChangingKeyWindow()
        // (removed: PreviewPanel.shared.orderOut(nil) — PreviewPanel.swift was deleted; `keepPreview` is now unused but left as a parameter for call-site compatibility)
        MainMenu.toggle(true)
    }

    /// we don't want another window to become key when the TilesPanel is hidden
    static func hideTilesPanelWithoutChangingKeyWindow() {
        allSecondaryWindowsCanBecomeKey(false)
        TilesPanel.shared.orderOut(nil)
        allSecondaryWindowsCanBecomeKey(true)
    }

    private static func allSecondaryWindowsCanBecomeKey(_ canBecomeKey_: Bool) {
        PermissionsWindow.canBecomeKey_ = canBecomeKey_
    }

    static func focusTarget() {
        guard SwitcherSession.isActive else { return } // already hidden
        let selectedWindow = Windows.selectedWindow()
        Logger.info { selectedWindow?.debugId }
        focusSelectedWindow(selectedWindow)
    }

    // (removed: supportProject() — an @objc menu-item action for the "Support the project" menu
    // bar item, which no longer exists. Endpoints.swift/Secrets.swift (src/api/) were deleted
    // along with it, since nothing else read from them.)
    // (removed: checkPermissions(_:) — was a menu-item action for a menu bar that no longer
    // exists. showSecondaryWindow(_:) also stays removed — it had zero callers even before this
    // build's Settings-window removal; PermissionsWindow.show() does its own positioning.)

    private static func initializePermissionsWindowIfNeeded() {
        if PermissionsWindow.shared == nil { _ = PermissionsWindow() }
    }

    static func showPermissionsWindow() {
        initializePermissionsWindowIfNeeded()
        PermissionsWindow.show()
    }

    static func showUi(_ shortcutIndex: Int) {
        showUiOrCycleSelection(shortcutIndex, true)
    }

    @objc static func showUiFromShortcut0() {
        showUi(0)
    }

    static func cycleSelection(_ direction: Direction, allowWrap: Bool = true) {
        (TilesView.scrollView?.documentView as? TilesDocumentView)?.cancelDraggingTimer()
        CursorEvents.resetDeadzone()
        if direction == .up || direction == .down {
            TilesView.navigateUpOrDown(direction, allowWrap: allowWrap)
        } else {
            Windows.cycleSelectedWindowIndex(direction.step(), allowWrap: allowWrap)
        }
    }

    static func previousWindowShortcutWithRepeatingKey() {
        cycleSelection(.trailing)
        KeyRepeatTimer.startRepeatingKeyPreviousWindow()
    }

    static func focusSelectedWindow(_ selectedWindow: Window?) {
        guard SwitcherSession.isActive else { return } // already hidden
        hideUi(true)
        if let window = selectedWindow, MissionControl.state() == .inactive || MissionControl.state() == .showDesktop {
            window.focus()
            if Preferences.cursorFollowFocus == .always || (
                Preferences.cursorFollowFocus == .differentScreen && (Spaces.screenSpacesMap.first { $0.value.contains { space in window.spaceIds.contains(space) } })?.key != NSScreen.active()?.cachedUuid()) {
                moveCursorToSelectedWindow(window)
            }
        } else {
            // (removed: PreviewPanel.shared.orderOut(nil) — PreviewPanel.swift was deleted)
        }
    }

    static func moveCursorToSelectedWindow(_ window: Window) {
        let referenceWindow = window.referenceWindowForTabbedWindow()
        guard let position = referenceWindow?.position, let size = referenceWindow?.size else { return }
        let point = CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)
        CGWarpMouseCursorPosition(point)
    }

    static func refreshOpenUiAfterExternalEvent(_ windowsToScreenshot: [Window], windowRemoved: Bool = false) {
        WindowThumbnails.refreshAsync(windowsToScreenshot, .refreshUiAfterExternalEvent, windowRemoved: windowRemoved)
        switcherUiRefreshThrottler.throttleOrProceed {
            guard SwitcherSession.isActive else { return }
            if !Windows.updatesBeforeShowing() { hideUi(); return }
            refreshUi(true)
        }
    }

    static func refreshUi(_ preserveScrollPosition: Bool = false) {
        guard SwitcherSession.isActive else { return }
        let preservedScrollOrigin = preserveScrollPosition ? TilesView.currentScrollOrigin() : nil
        Windows.updateSelectedWindow()
        guard SwitcherSession.isActive else { return }
        TilesPanel.shared.updateContents(preservedScrollOrigin)
        guard SwitcherSession.isActive else { return }
        Windows.voiceOverWindow() // at this point TileViews are assigned to the window, and ready
        guard SwitcherSession.isActive else { return }
        WindowThumbnails.previewSelectedIfNeeded()
        guard SwitcherSession.isActive else { return }
        Applications.refreshBadgesAsync()
    }

    static func showUiOrCycleSelection(_ shortcutIndex: Int, _ forceDoNothingOnRelease_: Bool) {
        let session = SwitcherSession.current ?? {
            let new = SwitcherSession()
            SwitcherSession.current = new
            return new
        }()
        session.forceDoNothingOnRelease = forceDoNothingOnRelease_
        Logger.debug { "isFirstSummon:\(session.isFirstSummon) shortcutIndex:\(shortcutIndex)" }
        // (removed: UsageStats.recordTrigger(shortcutIndex) — see hideUi() for why UsageStats was deleted)
        if session.isFirstSummon || shortcutIndex != session.shortcutIndex {
            NSScreen.updatePreferred()
            if isVeryFirstSummon {
                Windows.sortByLevel()
                isVeryFirstSummon = false
            }
            session.isFirstSummon = false
            session.shortcutIndex = shortcutIndex
            // Hide instantly so the rebuild for a different shortcut (Appearance change, layout
            // recalc) is invisible. `TilesPanel.show()` flips alpha back to 1 once everything is
            // in its final state. No-op on first summon (panel was orderOut'd with alpha=0).
            TilesPanel.shared.alphaValue = 0
            // (removed: TilesView.startSearchSession(...) — search-in-switcher was deleted, along
            // with the `.searchOnRelease` shortcut style path that used to force `forceDoNothingOnRelease`)
            if !Windows.updatesBeforeShowing() { hideUi(); return }
            Windows.setInitialSelectedAndHoveredWindowIndex()
            if Preferences.windowDisplayDelay == DispatchTimeInterval.milliseconds(0) {
                buildUiAndShowPanel()
            } else {
                delayedDisplayScheduled += 1
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Preferences.windowDisplayDelay) { () -> () in
                    if delayedDisplayScheduled == 1 {
                        buildUiAndShowPanel()
                    }
                    delayedDisplayScheduled -= 1
                }
            }
        } else {
            cycleSelection(.leading)
            KeyRepeatTimer.startRepeatingKeyNextWindow()
        }
    }

    static func buildUiAndShowPanel() {
        guard SwitcherSession.isActive else { return }
        Appearance.update()
        guard SwitcherSession.isActive else { return }
        TilesView.swapBackgroundViewIfNeeded()
        guard SwitcherSession.isActive else { return }
        refreshUi()
        guard SwitcherSession.isActive else { return }
        TilesPanel.shared.show()
        WindowThumbnails.previewSelectedIfNeeded()
        KeyRepeatTimer.startRepeatingKeyNextWindow()
        let prioritizedIds = TilesView.windowIdsInViewport()
        WindowThumbnails.refreshAsync(Windows.list, .refreshOnlyThumbnailsAfterShowUi, prioritizedIds: prioritizedIds)
    }

    static func checkIfShortcutsShouldBeDisabled(_ activeWindow: Window?, _ activeApp: Application?) {
        let app = activeWindow?.application ?? activeApp!
        let shortcutsShouldBeDisabled = ExceptionMatcher.disablesShortcuts(
            app.state,
            isFullscreen: activeWindow?.isFullscreen ?? false,
            exceptions: Preferences.exceptions)
        KeyboardEvents.toggleGlobalShortcuts(shortcutsShouldBeDisabled)
        if shortcutsShouldBeDisabled && SwitcherSession.isActive {
            hideUi()
        }
    }

    static func continueAppLaunchAfterPermissionsAreGranted() {
        Logger.info { "System permissions are granted; continuing launch" }
        BackgroundWork.start()
        NSScreen.updatePreferred()
        Appearance.update()
        TilesPanel.updateMaxPossibleThumbnailSize()
        TilesPanel.updateMaxPossibleAppIconSize()
        // headless-mode: no menu bar status item, no auto-updater UI, no first-launch
        // Settings prompt. This build is meant to run invisibly with two fixed shortcuts.
        // See ../../../README.md (workshop/macos/alt-tab/README.md) for details.
        MainMenu.create()
        _ = TilesPanel()
        // (removed: _ = PreviewPanel() — PreviewPanel.swift was deleted)
        Spaces.refresh()
        Screens.refresh()
        SpacesEvents.observe()
        ScreensEvents.observe()
        SystemAppearanceEvents.observe()
        SystemScrollerStyleEvents.observe()
        InputSourceEvents.observe()
        Applications.initialDiscovery()
        KeyboardEvents.addEventHandlers()
        CursorEvents.observe()
        // (removed: TrackpadEvents.observe() — trackpad-gesture switching was deleted along with TrackpadEvents.swift/ScrollwheelEvents.swift)
        // (removed: CliEvents.observe() — the CLI protocol (--list/--focus=/--show= over a Mach
        // port) only ever mattered when the binary was invoked with flags from Terminal; a
        // LaunchAgent-launched headless build never does that. Deleted along with CliEvents.swift.)
        PreferencesEvents.initialize()
        // BenchmarkRunner.startIfNeeded() used to run here — dead code even before this pass,
        // since nothing ever called BenchmarkRunner.configureFromArgs(_:), so `config` was
        // permanently nil and startIfNeeded() always no-op'd. Dropped along with debug/Benchmark.swift.
        // (removed: the `#if DEBUG` QAMenu/DebugMenu block — both were deleted in an earlier
        // pass along with settings-window/; this only ever compiled in Debug builds, which is
        // why `build.sh`'s Release build never caught the dangling references.)
        // (removed: UsageStats.prune() — see hideUi() for why UsageStats was deleted)
        Logger.info { "Finished launching AltTab" }
    }
}

extension App: NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // (removed: App.appCenterDelegate = AppCenterCrash() — AppCenter crash reporting/telemetry was deleted)
        App.shared.disableRelaunchOnLogin()
        Logger.initialize()
        Logger.info { "Launching AltTab \(App.version)" }
        #if DEBUG
        UserDefaults.standard.set(true, forKey: "NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints")
        #endif
        // headless-mode: never prompt to move into /Applications — this build is meant to
        // run from workshop/macos/alt-tab, launched silently by a LaunchAgent.
        AXUIElement.setGlobalTimeout()
        Preferences.initialize()
        // The entire LicenseManager/ProTransitionManager wiring that used to live here was the
        // trial/upsell state machine (Day 1/4/12/15/21/35 windows, free-pass sessions, Settings
        // upgrade-button refresh). All of it is gone now: `pro/` was deleted, and its only real
        // effects — the Day-X windows, the Settings UI it kept in sync, and the license cookie
        // it wrote for Sparkle's appcast request — no longer exist. See README for the full trace.
        BackgroundWork.preStart()
        SystemPermissions.ensurePermissionsAreGranted()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        // headless-mode: license activation used to arrive via a custom URL scheme
        // (com.lwouis.alt-tab-macos://activate?license_key=...), routed to UpgradeTab's
        // auto-activation UI in Settings. Settings no longer exists, and `LicenseManager`
        // is hardcoded to `.pro` regardless (see pro/license/LicenseManager.swift), so this
        // is a no-op. Dropped as part of extracting the engine from settings-window/.
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // headless-mode: no Settings window to reopen into; just show the switcher.
        App.showUiFromShortcut0()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        // symbolic hotkeys state persist after the app is quit; we restore this shortcut before quitting
        setNativeCommandTabEnabled(true)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Logger.info { "" }
        makeSureAllCapturesAreFinished()
        return .terminateNow
    }
}

enum RefreshCausedBy {
    case refreshOnlyThumbnailsAfterShowUi
    case refreshUiAfterExternalEvent
}
