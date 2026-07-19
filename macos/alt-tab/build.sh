#!/bin/bash
# Builds the headless AltTab fork (Release) via SwiftPM and stages the resulting .app here
# so the LaunchAgent has a stable path to launch.
#
# This no longer uses xcodebuild/alt-tab-macos.xcodeproj — see CHANGELOG.md ("Migrated off
# Xcode/xcodebuild to SwiftPM"). Only the Command Line Tools are required now, not full Xcode.app.
# `swift build` assembles a plain binary; this script does what Xcode's build phases used to do
# (Info.plist variable substitution, resource copying, ad-hoc code signing) by hand.
set -euo pipefail

ALT_TAB_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="$ALT_TAB_REPO"
APP_NAME="AltTab.app"

cd "$ALT_TAB_REPO"

# --- Values Xcode used to substitute from config/*.xcconfig into Info.plist ---
PRODUCT_NAME="AltTab"
PRODUCT_BUNDLE_IDENTIFIER="com.lwouis.alt-tab-macos"
EXECUTABLE_NAME="AltTab"
MACOSX_DEPLOYMENT_TARGET="10.13"
CURRENT_PROJECT_VERSION="1" # was config/local.xcconfig's CURRENT_PROJECT_VERSION before config/ was deleted alongside the Xcode project

swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/$EXECUTABLE_NAME"
if [ ! -f "$BIN_PATH" ]; then
    echo "Build succeeded but couldn't find $BIN_PATH — check swift build's output above." >&2
    exit 1
fi

# --- Assemble the .app bundle by hand ---
APP_BUNDLE="$ALT_TAB_REPO/.build/$APP_NAME"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
cp resources/icons/app/app.icns "$APP_BUNDLE/Contents/Resources/app.icns"
cp resources/SF-Pro-Text-Regular.otf "$APP_BUNDLE/Contents/Resources/SF-Pro-Text-Regular.otf"

# ShortcutRecorder's Package.swift declares its own resources (Images.xcassets), which SwiftPM
# compiles into a bundle sitting next to the built binary rather than embedding it in ours — Xcode
# used to copy this into Contents/Resources automatically as part of its build phases; swift build
# doesn't, so it has to be done here. Without it, SRShortcut can't find its resource bundle at
# runtime and crashes on launch trying to archive the default shortcut preferences (this is why
# the app appeared to hang/do nothing after install — it was crash-looping before either shortcut
# ever registered).
SR_BUNDLE_NAME="ShortcutRecorder_ShortcutRecorder.bundle"
SR_BUNDLE_PATH="$(dirname "$BIN_PATH")/$SR_BUNDLE_NAME"
if [ ! -d "$SR_BUNDLE_PATH" ]; then
    echo "Couldn't find $SR_BUNDLE_NAME next to the built binary at $(dirname "$BIN_PATH") — AltTab will crash on launch without it. Check vendor/ShortcutRecorder/Package.swift's resources declaration if this bundle's name ever changes." >&2
    exit 1
fi
cp -R "$SR_BUNDLE_PATH" "$APP_BUNDLE/Contents/Resources/$SR_BUNDLE_NAME"

sed \
    -e "s#\$(PRODUCT_NAME)#$PRODUCT_NAME#g" \
    -e "s#\$(PRODUCT_BUNDLE_IDENTIFIER)#$PRODUCT_BUNDLE_IDENTIFIER#g" \
    -e "s#\$(EXECUTABLE_NAME)#$EXECUTABLE_NAME#g" \
    -e "s#\$(MACOSX_DEPLOYMENT_TARGET)#$MACOSX_DEPLOYMENT_TARGET#g" \
    -e "s#\$(CURRENT_PROJECT_VERSION)#$CURRENT_PROJECT_VERSION#g" \
    Info.plist > "$APP_BUNDLE/Contents/Info.plist"

# Ad-hoc sign (matches config/local.xcconfig's previous CODE_SIGN_IDENTITY = -, --timestamp=none,
# hardened runtime disabled — this is why permissions typically need re-granting after every
# rebuild, documented in README.md's "Permissions" section).
codesign --force --sign - --timestamp=none --entitlements alt_tab_macos.entitlements "$APP_BUNDLE"

rm -rf "$DEST_DIR/$APP_NAME"
cp -R "$APP_BUNDLE" "$DEST_DIR/$APP_NAME"

echo "Built and staged: $DEST_DIR/$APP_NAME"
echo "Run ./install.sh to (re)load the LaunchAgent."
