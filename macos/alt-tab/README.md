# alt-tab (headless)

A personal, no-chrome build of [alt-tab-macos](https://github.com/lwouis/alt-tab-macos): same window-switcher engine, but stripped down to run invisibly in the background with exactly two shortcuts, nothing else. No menu bar icon, no Dock icon, no Settings window, no auto-updater, no licensing/upsell UI, no CLI, no first-launch flow. It's meant to run the same way Hammerspoon does — always on, never seen.

## What it does

- **Alt+Tab** — cycle thumbnails across all open windows, all apps.
- **Alt+`<key>`** — cycle thumbnails across only the active app's windows.

Both shortcuts are read from this Mac's existing `com.lwouis.alt-tab-macos` preferences (`UserDefaults`) domain — they are **not** hardcoded in source. Everything else upstream AltTab can do (search, trackpad gestures, a preview panel, per-app shortcut editing, licensing) has been either removed or hardcoded to sensible fixed defaults, because this build has no UI to configure any of it.

The one piece of UI that remains is a small first-run permissions window (Accessibility + Screen Recording) — see "Permissions" below.

## Origin

This build is based on / originally derived from [lwouis/alt-tab-macos](https://github.com/lwouis/alt-tab-macos), diverged from upstream release **v11.3.0** (commit `9fadf36b`). `src/` in *this* directory (`<repo root>/macos/alt-tab/`) is the only copy of the source, and has diverged heavily from upstream: entire subsystems (Settings UI, search, trackpad gestures, preview panel, licensing/Pro upsell, auto-updater, telemetry, CLI protocol, localization, unit tests) have been stripped out, leaving just the two-shortcut headless switcher described above. `CHANGELOG.md` is the detailed, file-by-file record of that work.

## Why this matters: diagnosing future breakage

This build is based on an **actively maintained** project. When a macOS update breaks something here (a permission API changes behavior, a private API upstream relies on gets locked down, a deprecated API finally gets removed, etc.), the upstream project has very likely already hit the same problem and shipped a fix — AltTab has a large user base and a maintainer who tracks macOS betas closely.

When something breaks after a macOS update:

1. Check upstream's recent commits and releases for a fix: [github.com/lwouis/alt-tab-macos/commits](https://github.com/lwouis/alt-tab-macos/commits/master) and [releases](https://github.com/lwouis/alt-tab-macos/releases). Search for the API name, error message, or symptom.
2. Find the equivalent file in this repo's `src/` (paths mostly still match upstream's `src/` layout, minus everything documented as deleted in `CHANGELOG.md`) and apply the equivalent fix by hand — this build has diverged enough from upstream (see `CHANGELOG.md`) that a raw `git merge`/`cherry-pick` from upstream is unlikely to apply cleanly.
3. If the affected file was deleted here (check `CHANGELOG.md`), the fix may not apply at all — confirm the feature it's fixing still exists in this build before spending time on it.

An AI assistant working in this repo should be told explicitly to check the upstream repo (`https://github.com/lwouis/alt-tab-macos`) when diagnosing anything that looks like a macOS-version-specific regression, rather than guessing at a fix from first principles.

## Permissions

Accessibility and Screen Recording are both requested through a small custom window (`secondary-windows/permission-window/`), not macOS's native permission-request dialogs — deliberately: neither permission check in this build ever triggers a native "would like to..." alert on its own. The custom window's own "Open [X] Settings…" buttons are the only thing that ever prompts you. See `CHANGELOG.md` ("Permission window") for the mechanics of how that's guaranteed, including a fix for a known macOS quirk (Screen Recording status can go briefly stale if you grant it while AltTab is still running — this build auto-restarts itself when it detects you've switched back from System Settings, so you don't have to remember to relaunch).

Code signing is ad-hoc, which means these permissions typically need re-granting after every rebuild (ad-hoc signatures aren't stable across builds, so macOS treats each one as a new, unrecognized app).

## Where things live

Everything lives directly in this directory (`<repo root>/macos/alt-tab/`) — there's no nested project folder anymore (see CHANGELOG.md, "Flattened directory structure").

- `src/` — the source. This is what you edit.
- `Package.swift` — SwiftPM manifest, the build definition. There's no `.xcodeproj`.
- `resources/`, `vendor/`, `Sources/` (the `ObjCExceptionCatcherKit` helper target), `Info.plist`, `alt_tab_macos.entitlements`, `alt-tab-macos-Bridging-Header.h` — everything else the build reads.
- `CHANGELOG.md` — file-by-file record of everything changed from upstream, and why.
- `build.sh` — runs `swift build`, then assembles `AltTab.app` by hand (Info.plist substitution, resource copying, ad-hoc signing) and stages it in this directory.
- `install.sh` — quits any running AltTab instance, installs + loads the LaunchAgent.

Building only requires the Xcode Command Line Tools (`xcode-select --install`), not the full Xcode.app — see CHANGELOG.md ("Migrated off Xcode/xcodebuild to SwiftPM") for why that move was made and what it cost. If you do have Xcode.app installed, `swift package` projects open directly in it (`open Package.swift` from this directory) for full IDE/debugger support — nothing about this migration blocks that.

## Setup

The workshop root `setup.sh` handles this automatically on every run: it checks whether the LaunchAgent is loaded, and if the source (`src/`, `resources/`, `vendor/`, `Sources/`, `Package.swift`, and the other build-input files — not the docs or scripts) has changed since the last build (via a content checksum), rebuilds and reinstalls. If `swift` isn't found (Command Line Tools not installed), it skips this step with a warning rather than failing the rest of setup.

To do it manually instead:

```bash
cd <repo root>/macos/alt-tab
./build.sh
./install.sh
```

After that, AltTab starts silently at every login — no icon anywhere, just the two shortcuts working.

## Verifying it worked

- Press Alt+Tab: should cycle thumbnails across all open windows.
- Press Alt+`<key>`: should cycle only the active app's windows.
- Check Activity Monitor / `ps aux | grep AltTab`: should show one AltTab process, no Dock icon, no menu bar item.
- If either shortcut doesn't fire, check `/tmp/alttab-headless.log` for errors — most likely cause is Accessibility or Screen Recording permission needing re-granting (see "Permissions" above).
- If Alt+`<key>` works *most* of the time but occasionally does nothing, it's likely a conflicting macOS system shortcut on the same key combo (e.g. "Move focus to next window") silently swallowing the keypress — see `../manual-setup.md` ("reassign, don't just disable"). Unticking the conflicting shortcut in System Settings is not enough; it needs to be reassigned to a different combo.

## Rebuilding after changes

Edit files under `src/`, then re-run `./build.sh` followed by `./install.sh` — or just re-run the workshop's `setup.sh`, which will detect the source change and do both automatically.

## Uninstalling

```bash
launchctl unload ~/Library/LaunchAgents/com.mustafa.alttab-headless.plist
rm ~/Library/LaunchAgents/com.mustafa.alttab-headless.plist
```
