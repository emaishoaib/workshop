# Changelog

Detailed, file-level record of every change made while turning upstream [alt-tab-macos](https://github.com/lwouis/alt-tab-macos) into this headless personal build. See `README.md` for orientation (what this is, current state, how to diagnose future breakage); this file is the "why does this specific line of code look like this" reference — useful when a future change touches the same area and you want to know what already got decided and why, or when comparing against upstream to see how they solved something this fork also had to deal with.

Organized roughly chronologically, oldest first.

## App.swift edits (not deletions)

- `continueAppLaunchAfterPermissionsAreGranted()`: removed the `Menubar.initialize()` call, the Sparkle `SPUStandardUpdaterController` setup, and `showSettingsWindowOnFirstLaunchIfNeeded()`.
- `applicationDidFinishLaunching()`: removed `MoveToApplicationsFolder.promptIfNeeded()` and the `Menubar.refreshLicenseMenuItems()` call inside `LicenseManager.onStateChanged`.
- `applicationShouldHandleReopen()`: now calls `showUiFromShortcut0()` instead of `showSettingsWindow()` (there's no Settings window to reopen into).
- Deleted dead first-launch helpers that referenced the now-removed Day-X windows: `showSettingsWindowOnFirstLaunchIfNeeded()`, `willShowDay1WelcomeOnAppLaunch()`, `deferFirstLaunchSettingsUntilDay1WelcomeCloses()`, `showAndCenterSettingsWindowOnFirstLaunch()`, plus the `pendingShowSettingsWindow`/`firstLaunchSettingsObserver` state they used.
- `showSettingsWindow()` itself is kept (still called internally by `UpgradeTab.navigateToUpgradeTab()`) but no longer gates on `Menubar.statusItem`.
- Removed `ProTransitionManager.shared.onAction = { ProPromptHost.shared.dispatch($0) }` — `ProTransitionManager` now emits into a `nil` closure and no-ops safely; it was already decoupled from concrete UI types via its `ProPromptAction` enum, so no changes were needed inside `ProTransitionManager.swift` itself.

## Shortcut registry extracted from Settings UI

`ControlsTab.swift` (Settings UI) used to also own the live in-memory shortcut registry — `ControlsTab.shortcuts`, plus the logic that populates it from preferences and reacts to changes — because nobody had split "what shortcut is bound to what" from "how do we draw the row that lets you record a new one." `events/KeyboardEvents.swift` (the actual `RegisterEventHotKey` calls), `switcher/ATShortcut.swift`, `switcher/main-window/TilesView.swift`, and `switcher/KeyRepeatTimer.swift` all read that registry directly, which meant the entire ~1100-line Settings tab had to stay in the build just to keep the hotkeys working.

That registry is now `switcher/ShortcutRegistry.swift` — a straight move, not a rewrite: `shortcuts`, `initializePreferencesDependentState()`, `preferenceChanged()` (trimmed of its UI-refresh branches — those only mattered while Settings was open, which never happens here), `addShortcut`/`removeShortcutIfExists`/`applyShortcutPreference`, `recomputeEscapeAbsorption`, `toggleNativeCommandTabIfNeeded`, and the arrow-keys/vim-keys local-shortcut logic. `ControlsTab.swift` keeps same-named forwarding functions (e.g. `static func addShortcut(...) { ShortcutRegistry.addShortcut(...) }`) so its ~15 internal UI-callback call sites (`shortcutChangedCallback`, `arrowKeysEnabledCallback`, etc.) didn't need to change. `events/PreferencesEvents.swift`, `switcher/ATShortcut.swift`, `switcher/main-window/TilesView.swift`, `switcher/KeyRepeatTimer.swift`, and `events/KeyboardEvents.swift` were updated to read `ShortcutRegistry.shortcuts` directly instead of `ControlsTab.shortcuts`.

One loose end: `ShortcutRegistry.toggleNativeCommandTabIfNeeded()` still calls into `NativeHotkeyResolver.resolve(...)`, and that type still lived under `preferences/settings-window/tabs/controls/NativeHotkeyResolver.swift` at the time — it was relocated to `switcher/NativeHotkeyResolver.swift` in the next pass, once `settings-window/` itself was deleted.

With this extraction done, `preferences/settings-window/` (~28 files) and the remaining `pro/ui/` upsell-adjacent pieces (`ProGradientButton.swift`, `UsageStatHeroView.swift`, `ProBadgeView.swift`) became pure UI with no engine dependents.

## `settings-window/` + `pro/ui` deleted; three files relocated first

A few real (non-comment) code dependencies had to be resolved before the folder could actually go.

**Dead-code call sites removed first** (each confirmed unreachable, not just unused):
- `PreferencesEvents.swift`: the `if LicenseManager.shared.isProLocked && ProFeature.isStoredValuePro(...) { UpgradeTab.navigateToUpgradeTab() }` branch. `LicenseManager.computeState()` is hardcoded to `.pro` (a pre-existing local commit), so `isProLocked` can never be true — this line could never run.
- `vendors/AppCenterCrashes.swift`'s `checkIfShouldSend()` (a real `Crashes.userConfirmationHandler` delegate callback — the "send a crash report?" alert still worked at the time): dropped the `GeneralTab.crashPolicyDropdown` refresh, a no-op since that dropdown only ever existed inside Settings.
- `switcher/ShortcutRegistry.swift`'s `restrictModifiersOfHoldShortcut(_:_:)`: used to reach into `ControlsTab.shortcutControls` to restrict which modifiers the Settings *recorder widget* would accept while the user was mid-recording a shortcut. Zero effect on which shortcuts actually trigger — it only guarded a Settings input widget — so the body became empty (kept as a stub so its call sites in `applyShortcutPreference` didn't need touching).
- `App.swift`: removed `showSettingsWindow()`, `showAboutWindow()`, `initializeSettingsWindowIfNeeded()`, `initializeAboutWindowIfNeeded()`, `openAccount()` (+ its `openAccountAction` selector), `handleCustomUrl(_:)` (license-activation custom URL scheme — also dead since license state is hardcoded), `checkForUpdatesNow()`'s `GeneralTab` call, and the `SettingsWindow`/`AboutWindow` lines from `allSecondaryWindowsCanBecomeKey`.

**Three files relocated (content unchanged) because kept code genuinely called into them:**
- `preferences/settings-window/tabs/controls/NativeHotkeyResolver.swift` → `switcher/NativeHotkeyResolver.swift`. Pure Carbon key-code kernel, no settings-window dependents.
- `preferences/settings-window/SettingsSearchIndex.swift` → `kit/SettingsSearchIndex.swift`, trimmed (its `sheetSearchableStrings(forButtonAction:)` lookup, only called from the now-deleted `SettingsWindow.highlightTarget`, was dropped).
- `preferences/settings-window/SettingsSearchHighlight.swift` → `kit/SettingsSearchHighlight.swift`, unchanged.
- `preferences/settings-window/SettingsSearch.swift` → `kit/SettingsSearch.swift`, unchanged.

(All four were later deleted anyway once `kit/LabelAndControl.swift`'s `makeLabel` — their only remaining caller — was trimmed further; see "`src/macos`, `src/preferences`, `src/util`, `src/api` dead-code sweep" below.)

**`preferences/settings-window/LabelAndControl.swift` was not a clean move — it was split.** The original ~370-line file covered every Settings control type (dropdowns, sliders, radio buttons, image buttons, info popovers, pro-upsell-gated widgets, the shortcut-recorder row builder). `secondary-windows/permission-window/PermissionsWindow.swift` only ever called `makeLabelWithCheckbox` for one row; `secondary-windows/DebugWindow.swift` only called `applySystemSelectedSegmentStyle`; `kit/CustomRecorderControl.swift` called `controlWasChanged` directly — none of them touched the `ControlsTab`/`UpgradeTab`-gated functions. `kit/LabelAndControl.swift` kept only: `makeLabelWithCheckbox`, `makeLabelWithProvidedControl`, `setupControl`, `controlWasChanged`, `makeLabel`, `getControlValue`, `applySystemSelectedSegmentStyle`, plus the small `LabelPosition`/`ControlIdentifierDiscriminator` types they need.

**`kit/SheetWindow.swift` turned out to be settings-window-only too.** It only compiled because it referenced `TableGroupSetView` (defined in the deleted `TableGroupView.swift`); nothing outside `kit/SheetWindow.swift` itself ever referenced `SheetWindow`. Deleted.

**`kit/CustomRecorderControl.swift` turned out to be settings-window-only too, despite its folder.** Only ever instantiated by `ShortcutEditor.swift` and the old `LabelAndControl.makeLabelWithRecorder` — both settings-window, both gone. Deleted (`CustomRecorderControl.swift`, `CustomRecorderControlTestable.swift`, `CustomRecorderControlTests.swift`, `CustomRecorderControlSpecs.md`). `kit/StackView.swift` had one leftover `views.contains { $0 is CustomRecorderControl }` layout workaround, simplified to always `fit()`.

**Also deleted:** `events/UserDefaultsEvents.swift` (Sparkle update-policy syncing, orphaned once `PreferencesEvents.swift` stopped calling it) and the three `pro/ui/` files (`ProGradientButton.swift`, `UsageStatHeroView.swift`, `ProBadgeView.swift` + Specs/Tests).

## MoveToApplicationsFolder, FeedbackWindow, DebugWindow, DebugMenu deleted

- `util/MoveToApplicationsFolder.swift` (188 lines) — zero real callers left; its only call site was removed from `App.swift` earlier but the file itself lingered.
- `secondary-windows/FeedbackWindow.swift`, `secondary-windows/DebugWindow.swift`, `secondary-windows/DebugMenu.swift` (~1,234 lines combined) — dead in Release builds once `Menubar.swift` (their only real trigger) was deleted, but `App.swift` still had live code paths pointing at them (`showFeedbackPanel()`, `showDebugWindow()`, `initializeFeedbackWindowIfNeeded()`, `initializeDebugWindowIfNeeded()`, `FeedbackWindow`/`DebugWindow` lines in `allSecondaryWindowsCanBecomeKey`) — all removed. `kit/LabelAndControl.swift`'s `applySystemSelectedSegmentStyle` (kept specifically for `DebugWindow`) dropped too.
- **Sparkle** (`vendors/SparkleDelegate.swift`, `vendor/Sparkle/`) and **`pro/license/`** were flagged as candidates but not yet touched at this point — see below, both were fully removed in later passes.

## Sparkle auto-updater framework fully unlinked

`Sparkle` had been inert since the very first stripping pass — `App.swift`'s `updaterController`/`sparkleDelegate` were declared but never assigned. This pass removed the framework dependency itself:

- `vendors/SparkleDelegate.swift` deleted (its only real caller, `FeedbackWindow.swift`, was already gone).
- `App.swift`: removed `import Sparkle` and the `sparkleDelegate`/`updaterController` static vars.
- `events/PreferencesEvents.swift`: removed unused `import Sparkle`.
- In Xcode: removed `Sparkle` from "Frameworks, Libraries, and Embedded Content", deleted the "Copy Sparkle Helpers" Run Script build phase, removed the local Swift Package reference.
- `vendor/Sparkle/` (4.3MB vendored source checkout) deleted from disk.

(The `vendor/Sparkle/` directory itself briefly lingered even after this — see "Vendor cleanup" below for when it was finally deleted.)

## `resources/` trimmed

- `resources/icons/menubar/menubar-0/1/2.pdf` deleted — status-bar icon images, unused since `Menubar.swift` was deleted.
- `resources/illustrations/*.heic` (16 files) deleted — Settings "preference explanation" illustrations.
- `resources/l10n/`: all non-English `.lproj` folders deleted first (ar, de, es, fr, he, id, it, ja, ko, nl, pl, pt-BR, ru, sv, th, tr, vi, zh-CN, zh-HK, zh-TW) — a real behavior change, not just cleanup: non-English users now see raw English strings instead of a translation. **Later fully superseded**: `resources/l10n/` (including the remaining `en.lproj/`) was deleted in its entirety in a much later pass — see "`config/` and `resources/` dead-file sweep" below. `NSLocalizedString` calls fall back to their own key text with no lookup table at all, which is functionally identical output for an English-only build.
- Kept throughout: `resources/icons/app/app.icns` (the app icon), `resources/SF-Pro-Text-Regular.otf` (force-unwrapped `NSFont(name: "SF Pro Text", ...)!` in 3 files — deleting it would crash the app).

## `experimentations/`, `ai/`, `scripts/` deleted

- `src/experimentations/` (`GhostWindowDetection.swift`, `TabbedWindowDetection.swift`, `PrivateApis.swift`, `IOKit.swift` + 2 `.md` files) — none of the four Swift files were in the Compile Sources build phase; pure research/reference material never wired into the build. (A separate `experimentations/EscapeAndGameOverlay.md` was added later — see "Full file-by-file audit" below — and was kept, since it documents a real, current design decision.)
- `ai/` (`build.sh`, `profile.sh`, `run.sh`) — Debug-scheme dev/profiling scripts, unrelated to this project's own `build.sh`/`install.sh`.
- `scripts/` (codesigning, changelog generation, l10n translation sync, AppCenter symbol upload, website updates) — confirmed zero references from this project's build phases; all upstream CI/release tooling for public notarized releases.
- Kept: `LICENCE.md` (GPLv3 text) — removing it wouldn't change the actual license, but keeping it avoids any GPL-compliance question if this build is ever shared.

## `src/debug/` deleted

- `debug/QAMenu.swift` — fully `#if DEBUG`-gated, contributed nothing to the Release build even before deletion.
- `debug/Benchmark.swift` (`BenchmarkRunner`, `BenchmarkConfig`) — a `--benchmark launch` / `--benchmark showUi N` CLI-flag-driven profiling harness. Turned out to already be fully dead: nothing ever called `BenchmarkRunner.configureFromArgs(_:)`, so `config` was permanently `nil` and `startIfNeeded()` always no-op'd.

## Unit-tests target and all test files deleted

The `unit-tests` target's `_test-support/Mocks.swift` had been broken since the settings-window deletion pass (it stubbed types that no longer exist). Rather than fix it, unit testing was dropped entirely for this personal fork — `build.sh` only ever built the Release app scheme, never the test target, so this doesn't affect the running app.

Deleted: `_test-support/` (`Helpers.swift`, `Mocks.swift`), an early version of `coverage.md`, all `*Tests.swift` files (17 across `events/`, `macos/`, `preferences/`, `pro/license/`, `pro/scheduling/`, `switcher/`, `switcher/state/`, `util/`), and all paired `*Specs.md` behavior-spec docs (16). The `unit-tests` Xcode target itself was deleted too.

**Kept at the time — misleadingly named but real production code, present in the Release app's Compile Sources:** `macos/api-wrappers/HelperExtensionsTestable.swift`, `pro/scheduling/ProTransitionManagerTestable.swift`, `util/UsageStatsTestable.swift`, `switcher/AppearanceTestable.swift`, `switcher/SearchTestable.swift`, `events/KeyboardEventsTestable.swift`. Despite the `Testable` suffix (a naming convention for logic extracted to be independently testable), these contained real runtime logic the switcher depended on. (Most were later deleted anyway as their underlying features — search, pro/license, UsageStats — were removed; see below. `KeyboardEventsTestable.swift` is still live: `handleKeyboardEvent`/`triggerMatchingShortcuts` actually live there.)

## Pro-trial upsell windows and menu bar deleted

- `pro/scheduling/`: `Day1WelcomeLetterWindow.swift`, `Day4TourPopover.swift`, `Day12HeadsUpPopover.swift`, `Day15ProactiveWindow.swift`, `Day15HardGatePopover.swift`, `Day15FullUpgradeWindow.swift`, `Day21ReminderPopover.swift`, `Day35FinalWindow.swift` — the Pro-trial upsell nag windows.
- `pro/ui/`: `ProPromptHost.swift`, `ProPromptPopover.swift`, `ProPromptWindow.swift`, `ProPromptHeader.swift` — the dispatcher that showed the Day-X windows above.
- `Menubar.swift` — the status bar icon + its dropdown menu, fully dead once `Menubar.initialize()` was never called.

## `pro/` deleted in full

`pro/license/` (LicenseManager, Keychain, RemoteLicenseClient, MachineFingerprint, LicenseAPI, LicenseCookie, Clock) and `pro/scheduling/` — previously left alone since `LicenseManager.computeState()` was hardcoded to always return `.pro`, so none of the real validation code ran — were finally deleted along with everything else in this pass. This removed the now-fully-orphaned source files themselves, plus the two leftover `LicenseManagerSpecs.md`/`ProTransitionSpecs.md` spec docs.

## Feature stripping: search-in-switcher, trackpad gestures, preview panel, exceptions hardcoded

The largest single round — going after actual runtime *features*, not just dead settings-UI code, based on the two-shortcut-only use case.

- **Search-in-switcher removed entirely.** `switcher/Search.swift`, `SearchTestable.swift`, `switcher/state/SearchModeResolver.swift` deleted. `switcher/main-window/TilesView.swift` lost its `SearchKeyResult` enum, `searchField`, `searchMode`, and every search-session method — all search-mode-conditional branches in `updateBackgroundView`/`layoutParentViews`/`resolveAutoSize` hardcoded to "off". `switcher/ShortcutRegistry.swift` dropped `searchShortcut`/`lockSearchShortcut`. `switcher/state/Windows.swift`, `Window.swift`, `SwitcherSession.swift`, `main-window/TileView.swift`, `events/CursorEvents.swift`, `events/KeyboardEventsTestable.swift` all had search-mode branches removed or hardcoded off. `ShortcutAction.swift`'s cancel-shortcut action now always calls `App.hideUi()` directly.
- **Trackpad gestures removed.** `events/TrackpadEvents.swift`, `events/ScrollwheelEvents.swift` deleted; their call sites in `App.swift`, `SleepWakeEvents.swift`, `PreferencesEvents.swift` replaced with comments. `GesturePreference` enum/`gestureIndex`/`trackpadHapticFeedbackEnabled` left as harmless dead declarations in `Preferences.swift`/`MacroPreferences.swift`.
- **Preview panel removed.** `switcher/PreviewPanel.swift` deleted. `switcher/state/WindowThumbnails.swift`'s `previewSelectedIfNeeded()` reduced to a no-op stub. Call sites removed from `App.swift`, `Windows.swift`, `Window.swift`.
- **Exceptions/blacklist hardcoded, not removed.** The feature itself (hide Finder when windowless, disable shortcuts in fullscreen VM/remote-desktop apps) still runs — `Preferences.exceptions` went from a live `UserDefaults`-backed array to a hardcoded `static let` literal with the exact same 12 default entries (Finder, ScreenSharing, RDC, TeamViewer, VirtualBox, Parallels, Citrix ×2, NICE DCV, VMware Fusion, UTM, McAfee). No Settings UI to edit this anymore, so `defaultExceptions()` and the "exceptions" defaults-dict entry were removed.
- **Orphaned test files deleted** (15 files, confirmed 0 in the Xcode Sources build phase before deletion): `AxEventRoutingTests.swift`, `KeyboardEventsTests.swift`, `PermissionCalloutResolverTests.swift`, `OnActionExtensionTests.swift`, `ResizedCopyWithCoreGraphicsTests.swift`, `PreferencesMigrationsTests.swift`, `AppearanceTests.swift`, `SearchTests.swift`, `ExceptionMatcherTests.swift`, `SearchModeResolverTests.swift`, `SelectionResolverTests.swift`, `WindowFilterResolverTests.swift`, `WindowOrderResolverTests.swift`, `SchedulingPolicyTests.swift`, `UsageStatsMessageTests.swift`.

## Vendor cleanup: AppCenter, leftover Sparkle folder, vendor scripts

- **AppCenter (crash reporting/telemetry) removed.** `vendors/AppCenterCrashes.swift`, `vendors/AppCenterApplication.h/.m` deleted. `App.swift`: `import AppCenterCrashes` removed, `class App: AppCenterApplication` → `class App: NSApplication`, the `appCenterDelegate`/`AppCenterCrash()` wiring removed. `Info.plist`'s `NSPrincipalClass` changed from `AppCenterApplication` to `App`; `AppCenterApplicationForwarderEnabled`/`AppCenterSecret` keys removed. `config/local.xcconfig`'s `APPCENTER_SECRET` line removed. Local Swift Package reference removed, `vendor/AppCenter/` deleted from disk. `src/secondary-windows/DebugProfile.swift` (its only caller) deleted too.
- **`vendor/Sparkle/`** (the actual framework checkout, left over from when Sparkle *code* was unlinked earlier) and **`vendor/scripts/`** (upstream's release maintenance scripts) both deleted from disk.
- **`src/api/`** (`Endpoints.swift`, `Secrets.swift`) deleted. `Secrets.swift` was already emptied by the AppCenter removal above; `Endpoints.swift` only fed `App.swift`'s `supportProject()`, itself a dead `@objc` menu-item action left over from the menu bar's removal. `Info.plist`'s `Domain`/`ApiDomain` keys and `config/base.xcconfig`'s `DOMAIN`/`API_DOMAIN` values, which only fed `Endpoints.swift`, removed too.

## CLI protocol removed

`events/CliEvents.swift` deleted (`CliEvents`, `CliServer`, `CliClient` — Mach-port-based IPC backing `--list`/`--detailed-list`/`--focus=`/`--show=` command-line flags). `App.swift`'s `CliEvents.observe()` call and `main.swift`'s `CliClient.detectCommand()` check removed. This only ever mattered when the binary was invoked with flags from Terminal — a LaunchAgent-launched headless build never does that.

## Permission window: replaced with native prompts, then restored

This one round-tripped. First: `secondary-windows/permission-window/` (`PermissionsWindow.swift`, `PermissionView.swift`) and 7 `kit/` view classes exclusively used by it (`StackView`, `LightImageView`, `LabelAndControl`, `GridView`, `Button`, `text/BoldLabel`, `text/TitleLabel`) were deleted in favor of macOS's own native Accessibility/Screen Recording permission dialogs.

Decided against that after using it — restored, with two real fixes layered on top rather than a plain revert:

1. **The native Accessibility dialog never surfaces.** `AccessibilityPermission.detect()` always calls `AXIsProcessTrustedWithOptions` with `kAXTrustedCheckOptionPrompt: false` (both before and after this round-trip — the *native-prompts* experiment temporarily added a `requestWithPrompt()` method passing `true`; that's gone again). The custom `PermissionsWindow` is the only thing that ever asks.
2. **The native Screen Recording dialog no longer surfaces either.** Screen Recording has no `prompt: false`-style flag; the original code checked status via `SCShareableContent`/`CGDisplayStream`, both of which trigger that native alert as a side effect the moment they're called while the permission is undecided. `ScreenRecordingPermission.detect()` now uses `CGPreflightScreenCaptureAccess()` instead — status-only, no alert side effect. Trade-off: its return value can go stale if the permission is toggled in System Settings while AltTab keeps running. Fixed rather than accepted: `SystemPermissions.startListeningForReactivationDuringPreStartup()` watches for AltTab regaining focus (`NSApplication.didBecomeActiveNotification`) — the signal that the user likely just switched back from System Settings — and calls `App.restart()` automatically, so the next process gets a guaranteed-fresh preflight read. `WindowCaptureEvents.swift`'s actual thumbnail-capture path still uses real `SCShareableContent` calls, untouched — by the time a user reaches that path they've already granted or explicitly skipped the permission through the window.

`kit/LabelAndControl.swift` and `kit/Button.swift` were **not** restored verbatim — the pre-existing versions pulled in dependencies (`TextField`, `SettingsSearchIndex`, `Switch`, the old `ActionClosure`/`NSControl.onAction` mechanism) that had been correctly deleted as genuinely dead in between the two permission-window passes. Both were rewritten, trimmed to only the checkbox/button paths `PermissionsWindow` actually calls, using small self-contained target/action wrapper classes.

**A real bug surfaced along the way and got fixed:** `kit/LightImageView.swift` (deleted in the first permission-window pass, as expected) had also quietly defined `CALayerContents` — an enum used by `Window.swift`, `WindowCaptureEvents.swift`, and `kit/LightImageLayer.swift`, none of which have anything to do with the permission window. Deleting the file broke those three files' builds. Fix: `CALayerContents` now lives in `kit/LightImageLayer.swift` (its closest actual consumer) instead of being re-declared in the restored `LightImageView.swift`. Lesson for future passes: check every top-level symbol in a file independently before assuming a whole file shares one owner, even when a file's *primary* class clearly belongs to one caller.

## `src/macos`, `src/preferences`, `src/util`, `src/api` dead-code sweep

A file-by-file audit of the remaining `macos/`, `preferences/`, `util/` directories, cross-referencing every top-level symbol against the rest of the codebase:

- **`macos/api-wrappers/Bash.swift`, `Markdown.swift`, `HelperExtensionsTestable.swift`** deleted — confirmed zero call sites. Orphaned spec docs (`OnActionExtensionSpecs.md`, `PermissionCalloutResolverSpecs.md`, `api-wrappers/README.md`) went with them. (A small piece of `HelperExtensionsTestable.swift`'s purpose — the `Button` action-wrapper pattern — was later reintroduced from scratch during the permission-window restoration above, but not the file itself.)
- **`macos/LoginItem.swift` and the `startAtLogin` preference removed.** It managed its own `startAtLogin` UserDefaults toggle by writing/removing a launchd Login Items entry — separate, redundant machinery from the LaunchAgent this build runs under.
- **`preferences/PreferencesMigrations.swift` gutted from 427 lines to ~27.** It carried upstream's full version-upgrade migration chain back to v6.18.1 — none of it applies to a fork with no legacy `UserDefaults` to carry forward. Kept only `removeCorruptedPreferences()` and the one-line `preferencesVersion` stamp. `migrateShortcutPreferencesToSecureCoding` turned out to already be dead code (declared, never called). `preferences/ShortcutConfiguration.swift` and `PreferencesMigrationsSpecs.md` also deleted.
- **`util/UsageStats.swift`/`UsageStatsTestable.swift` deleted.** Write-only telemetry that only ever fed the pro-upsell usage-count UI — every read accessor had zero callers; only the three write call sites in `App.swift` remained, feeding nothing. `util/SchedulingPolicy.swift`/`SchedulingPolicySpecs.md` checked and kept — genuinely still backs `Throttler.swift`/`AXCallScheduler.swift`.
- **Dead `MacroPreferences.swift` entries removed:** `MenubarIconPreference` + `menubarIcon`/`menubarIconShown`, `UpdatePolicyPreference` + `updatePolicy`, `CrashPolicyPreference` + `crashPolicy` — all confirmed zero references outside their own declarations.

## `config/` and `resources/` dead-file sweep

- **`config/test-base.xcconfig`, `test-debug.xcconfig`, `test-release.xcconfig` deleted.** Only one `PBXNativeTarget` exists in the project now (the app) — no Tests target to consume them, never wired via `baseConfigurationReference`.
- **`resources/l10n/` deleted in full** (superseding the earlier "reduced to English" pass above). The still-live `NSLocalizedString` calls all have key == English value, so falling back to the key text with no lookup table is functionally identical for an English-only build.
- **`resources/icons/app/app.iconset/` (3 source PNGs) deleted.** Never in the Resources build phase — unused source material for regenerating `app.icns`, which stays.
- Kept: `resources/icons/app/app.icns`, `resources/SF-Pro-Text-Regular.otf` (force-unwrapped font reference — deleting it crashes the app).

## Full file-by-file audit: `events/`, `kit/`, `switcher/`, `vendors/`, root files

A pass over every remaining file, cross-referencing every top-level type against the rest of the codebase. Two things came up that were left as-is — genuine judgment calls, not oversights:

- **`events/SleepWakeEvents.swift` is never called.** It exists to re-enable keyboard/cursor event taps after the Mac wakes from sleep (macOS sometimes kills background event taps across sleep) — but `SleepWakeEvents.observe()` has never actually been wired into `App.swift`'s launch sequence, in this fork *or* the original upstream commit it came from. Not something this project broke. Left unwired — if shortcuts ever seem to silently stop working after sleep, this is the first thing to check.
- **`MainMenu.swift` (~290 lines, builds a full standard app menu purely so Cmd+C/V/Z etc. work) was kept**, despite the app being `LSUIElement` and every remaining text field being non-editable. Judged too risky to remove without certainty that nothing subtle depends on `NSApp.mainMenu` existing (e.g. `TilesPanel`'s `MainMenu.toggle()` calls, which stop `MainMenu`'s own Cmd+Q binding from accidentally quitting AltTab while the switcher is key window).

Everything else checked out as load-bearing.

## Bundle identity

Bundle ID (`com.lwouis.alt-tab-macos`), entitlements, and Info.plist keys were deliberately left unchanged so this build inherits the existing shortcut config, appearance settings, and Accessibility/Screen Recording grants from whatever AltTab install was on this machine before — zero preference migration. The two shortcuts are **not** hardcoded anywhere in source; they're read from this Mac's existing `com.lwouis.alt-tab-macos` UserDefaults domain.

Code signing is ad-hoc (`CODE_SIGN_IDENTITY = -` in `config/local.xcconfig`), which means Accessibility/Screen Recording permissions need re-granting after every rebuild (ad-hoc signatures aren't stable across builds, so macOS treats each rebuild as a new, unrecognized app). Known tradeoff, not fixed.

## `install.sh` no longer asks for confirmation

It used to prompt before quitting any currently-running AltTab instance; it now just does it. There should only ever be one instance running — a second would fight the first over the same global shortcuts and Accessibility session.

## Migrated off Xcode/xcodebuild to SwiftPM

`alt-tab-macos.xcodeproj` was replaced with `Package.swift`; `build.sh` now runs `swift build` instead of `xcodebuild`. Motivation: `xcodebuild` specifically requires the full Xcode.app to be installed (Command Line Tools alone give you `swiftc`/`swift build` but not `xcodebuild`), which is a multi-gigabyte, GUI-installed dependency for a headless personal build that's never opened in Xcode's UI day to day.

This project turned out to be an easy migration candidate, which is the only reason it was attempted: no storyboards/XIBs (everything's built in code), no asset catalog (`app.iconset` was already deleted earlier in favor of a plain `.icns` file), no localizations (`l10n/` was already deleted), a single target, only one dependency (`vendor/ShortcutRecorder`, which was *already* a local SwiftPM package — the `.xcodeproj` referenced it via `XCLocalSwiftPackageReference`), and code signing was already ad-hoc. None of Xcode's harder-to-replicate machinery (asset catalog compilation, Interface Builder, multi-scheme builds) was in play.

What changed mechanically:

- **`Package.swift`** (new, at `alt-tab-macos/` root) replaces the `.xcodeproj`'s target/build-settings definitions. Single `executableTarget` named `AltTab`, `path: "src"`, depending on the local `ShortcutRecorder` package.
- **Bridging header preserved as-is.** `alt-tab-macos-Bridging-Header.h` (still does `@import Cocoa;` + `#import "ObjCExceptionCatcher.h"`) is wired in via `-import-objc-header` passed through `swiftSettings: [.unsafeFlags(...)]`, using an absolute path computed from `#filePath` so it doesn't depend on the working directory `swift build` is invoked from. This was a deliberate choice over the alternative (relying on SwiftPM 5.9's native mixed Swift/Objective-C target support and adding explicit `import Cocoa` to the ~24 files that currently rely on the bridging header's implicit global import) — same behavior, zero source files touched, lower risk.
- **`SkyLight.framework.swift`'s private-framework link** (`@_silgen_name`-based calls into WindowServer, previously wired via `config/base.xcconfig`'s `FRAMEWORK_SEARCH_PATHS`/`OTHER_LDFLAGS`) is now a `linkerSettings: [.unsafeFlags(["-F/System/Library/PrivateFrameworks"]), .linkedFramework("SkyLight")]` entry in `Package.swift`. `ApplicationServices.HIServices.framework.swift`'s `@_silgen_name` calls needed no equivalent — `ApplicationServices` is a public framework and autolinks normally via its `import`.
- **Resources (`app.icns`, `SF-Pro-Text-Regular.otf`) are intentionally *not* declared as SwiftPM target resources.** Every resource lookup in this codebase goes through `Bundle.main` (`CGImage.allNamed("app.icns")` in `App.swift`; `Bundle.main.url(forResource:...)` in `HelperExtensions.swift`), which only resolves inside a real `.app` bundle's `Contents/Resources` — not SwiftPM's `Bundle.module`/`.build` output. `build.sh` copies them into the hand-assembled bundle instead, same as Xcode's Resources build phase used to.
- **`build.sh` now does by hand what Xcode's build phases used to do implicitly:** runs `swift build -c release`, creates `AltTab.app/Contents/{MacOS,Resources}`, copies the compiled binary + the two resource files in, substitutes `Info.plist`'s `$(PRODUCT_NAME)`/`$(PRODUCT_BUNDLE_IDENTIFIER)`/`$(EXECUTABLE_NAME)`/`$(MACOSX_DEPLOYMENT_TARGET)`/`$(CURRENT_PROJECT_VERSION)` placeholders via `sed` (values hardcoded in the script now, pulled from what `config/base.xcconfig`/`config/local.xcconfig` used to provide), then ad-hoc code-signs with the entitlements file — same `codesign --sign - --timestamp=none` behavior `config/local.xcconfig` specified before.
- **`config/*.xcconfig` files are no longer read by the build** (nothing in `Package.swift`/`build.sh` sources them) but were left in place rather than deleted — they're the clearest record of what settings Xcode used to apply and why (each has explanatory comments), useful if this ever needs to be migrated back or cross-checked against upstream's own `.xcconfig` files.
- **`install.sh` is unchanged** — it only ever consumed the already-built `AltTab.app`, agnostic to how it was produced.

What this cost: no more Xcode GUI (indexing, jump-to-definition, Instruments) unless Xcode.app is separately installed later, in which case `open Package.swift` from `alt-tab-macos/` opens it directly with full IDE support — SwiftPM projects aren't second-class citizens in Xcode, this isn't a one-way door. `build.sh` now owns bundle-assembly correctness (Info.plist substitution, resource copying, signing) that Xcode's build phases previously handled — a small but real surface for a future bug (e.g. forgetting to add a new resource file to both the copy step and the bundle).

**Correction after the first real build attempt:** the plan above (leaving `ObjCExceptionCatcher.h`/`.m` inside `src/` alongside the Swift files, relying only on the bridging-header flag to wire them in) doesn't actually work — `swift build` failed with `target at .../src contains mixed language source files; feature not supported`. This machine's SwiftPM rejects *any* target whose directory contains both Swift and C-family source files, regardless of whether a bridging header is involved; that's a target-level restriction based on what file types are present, not on how Swift code imports them. (SwiftPM does have a native mixed-language-target feature in principle, but it's not enabled on this toolchain, and it wouldn't have used the bridging-header route anyway — it does its own auto-generated header, which is exactly the alternative the original plan said it was avoiding.)

Fix: `ObjCExceptionCatcher.h`/`.m` moved into their own target, `Sources/ObjCExceptionCatcherKit/` (a plain `.target`, `publicHeadersPath: "include"`), which `AltTab` now depends on. `Application.swift` (the one call site, `ObjCExceptionCatcher.catching { ... }`) got an explicit `import ObjCExceptionCatcherKit` instead of relying on the bridging header for it — the bridging header now only carries `@import Cocoa;`. The two original files under `src/vendors/` are excluded from the `AltTab` target's sources in `Package.swift` (`exclude:`) so they don't get compiled twice; they should be deleted from `src/vendors/` (`rm src/vendors/ObjCExceptionCatcher.{h,m}`) once the build is confirmed working, since `Sources/ObjCExceptionCatcherKit/` is now the only copy that matters.

**Confirmed working**: `./build.sh` completes end to end (`swift build` succeeds, `.app` assembly, ad-hoc signing) and stages `AltTab.app`. Expect a wall of `-Wdeprecated-declarations` warnings from `vendor/ShortcutRecorder`'s own Objective-C (old `os_trace_*` APIs, `NSCompositeSourceOver`, etc.) — that's pre-existing noise in the vendored dependency, not something this migration introduced; the only line that matters is `Build complete!` at the end.

**Second correction, found only after actually launching the built app**: it crash-looped on every launch, immediately, before either shortcut could register — `/tmp/alttab-headless.log` showed a fatal error in `Preferences.swift`'s `archiveShortcut()`, deep inside `SRShortcut.encodeWithCoder:` throwing `"Unable to find bundle with resources"`. Cause: `vendor/ShortcutRecorder/Package.swift` declares its own resources (`resources: [.process("Images.xcassets")]`), which SwiftPM compiles into a separate bundle, `ShortcutRecorder_ShortcutRecorder.bundle`, placed next to the built binary in `.build/release/` rather than embedded into the executable. Xcode used to copy this into `AltTab.app/Contents/Resources/` automatically as one of its build phases (visible in the old `DerivedData` tree if you go looking) — `build.sh` only copied `app.icns` and the font, missing this one entirely. Fixed by having `build.sh` locate `ShortcutRecorder_ShortcutRecorder.bundle` next to the built binary (same directory `swift build --show-bin-path` reports) and copy it into `Contents/Resources/` alongside the other two. If `vendor/ShortcutRecorder/Package.swift`'s resources declaration ever changes, this bundle's name (`<PackageName>_<TargetName>.bundle`) would change too and `build.sh` would need updating to match — it now fails loudly (`exit 1`) rather than silently shipping a build that will crash on launch, specifically so this doesn't regress silently again.

## Flattened directory structure

`<repo root>/macos/alt-tab/` used to contain a nested `alt-tab-macos/` subdirectory holding the actual source (`src/`, `resources/`, `vendor/`, `Package.swift`, etc.), with only `build.sh`, `install.sh`, `README.md`, and `CHANGELOG.md` at the outer level. That nesting was a leftover from when the source lived in a separate standalone clone and got moved in wholesale (see "App.swift edits" era, much earlier in this file) — once everything was consolidated into one repo, the extra layer no longer served a purpose. Flattened by moving everything up one level: `src/`, `resources/`, `vendor/`, `Sources/`, `Package.swift`, `Info.plist`, `alt_tab_macos.entitlements`, `alt-tab-macos-Bridging-Header.h`, and `LICENCE.md` now sit directly alongside `build.sh`/`install.sh`/`README.md`/`CHANGELOG.md` in `macos/alt-tab/`. The nested `alt-tab-macos/` directory no longer exists.

What had to change as a result:

- **`build.sh`**: used to have separate `ALT_TAB_REPO` (the nested source dir, where it ran `swift build`) and `DEST_DIR` (the outer dir, where it staged the built `.app`). Now both point at the same directory — collapsed to one variable.
- **The workshop root `setup.sh`**: its content-hash change-detection used to just `find` the entire nested `alt-tab-macos/` subtree, which cleanly separated "build input" from "docs/scripts, not build input" by directory boundary alone. With everything flattened into one directory, that boundary is gone, so the checksum now explicitly lists the paths that actually feed the build (`src`, `resources`, `vendor`, `Sources`, `Package.swift`, `Info.plist`, `alt_tab_macos.entitlements`, `alt-tab-macos-Bridging-Header.h`) rather than hashing the whole directory — editing `README.md` or `build.sh` itself no longer triggers a spurious rebuild.
- **`README.md`**: every reference to `alt-tab-macos/<path>` became just `<path>` ("Where things live", "Origin", "Rebuilding after changes", the upstream-diagnosis instructions).
- **`Package.swift` and `install.sh` needed no changes** — `Package.swift` computes the bridging header's path from its own location (`#filePath`) rather than a hardcoded relative path, and `install.sh` never referenced the nested directory to begin with.
- **The move itself hit two rough edges worth knowing about if this ever happens again**: `git mv` refuses to move untracked files/directories (`Package.swift` and `Sources/` were both new and untracked at the time — had to fall back to plain `mv`, then let `git add -A` pick up the adds/deletes, which `git` still resolves into renames for history purposes), and `git mv` on a directory aborts entirely if any file inside it is already staged as deleted-but-not-yet-committed relative to what's on disk (hit this with `src/vendors/ObjCExceptionCatcher.{h,m}`, deleted in the previous entry) — same fix, plain `mv` instead.
- **`.gitignore`**: `macos/alt-tab/alt-tab-macos/DerivedData/` and `macos/alt-tab/alt-tab-macos/.build/` became `macos/alt-tab/.build/` (the `DerivedData` line was dropped entirely — no Xcode project left to produce one).
