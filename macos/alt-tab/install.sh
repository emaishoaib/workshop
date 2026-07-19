#!/bin/bash
# Installs the LaunchAgent so the headless AltTab build starts silently at login.
# Run ./build.sh first so AltTab.app exists in this directory.
set -euo pipefail

DEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_NAME="com.mustafa.alttab-headless.plist"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
TARGET_PLIST="$LAUNCH_AGENTS_DIR/$PLIST_NAME"

if [ ! -d "$DEST_DIR/AltTab.app" ]; then
    echo "AltTab.app not found in $DEST_DIR — run ./build.sh first." >&2
    exit 1
fi

echo "Quitting any currently running AltTab (only one instance should run at a time —"
echo "running both would fight over the same global shortcuts and Accessibility session)."

osascript -e 'tell application "AltTab" to quit' 2>/dev/null || true
pkill -x AltTab 2>/dev/null || true
sleep 1

mkdir -p "$LAUNCH_AGENTS_DIR"
sed "s#__DEST_DIR__#$DEST_DIR#g" "$DEST_DIR/$PLIST_NAME" > "$TARGET_PLIST"

launchctl unload "$TARGET_PLIST" 2>/dev/null || true
launchctl load "$TARGET_PLIST"

echo "Installed and loaded: $TARGET_PLIST"
echo "AltTab (headless) should now be running silently — no Dock icon, no menu bar item."
echo "First run may prompt for Accessibility / Screen Recording permission if not already granted."
