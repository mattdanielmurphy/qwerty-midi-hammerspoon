#!/bin/bash
set -euo pipefail

# bin/build_app.sh
# Builds DualSynth into a proper macOS .app bundle, installs it to /Applications, and launches it.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="DualSynth.app"
TMP_DIR="$REPO_ROOT/tmp"
TMP_APP="$TMP_DIR/$APP_NAME"
DEST_APP="/Applications/$APP_NAME"
MACOS_SRC="$REPO_ROOT/packages/dualsynth/macos"

mkdir -p "$TMP_DIR"

echo "⚡ [1/5] Building DualSynth Release Binary..."
swift build -c release --package-path "$MACOS_SRC" --product dualsynth-gui

# Ensure AppIcon.icns exists
if [ ! -f "$MACOS_SRC/Resources/AppIcon.icns" ]; then
    echo "🎨 Generating AppIcon.icns..."
    python3 "$REPO_ROOT/scripts/generate_app_icon.py"
    mkdir -p "$MACOS_SRC/Resources"
    cp "$TMP_DIR/AppIcon.icns" "$MACOS_SRC/Resources/AppIcon.icns"
fi

echo "📦 [2/5] Creating $APP_NAME bundle..."
if [ -d "$TMP_APP" ]; then
    mv "$TMP_APP" ~/.Trash/ 2>/dev/null || true
fi

mkdir -p "$TMP_APP/Contents/MacOS"
mkdir -p "$TMP_APP/Contents/Resources"

# Copy binary
cp "$MACOS_SRC/.build/release/dualsynth-gui" "$TMP_APP/Contents/MacOS/DualSynth"
chmod +x "$TMP_APP/Contents/MacOS/DualSynth"

# Copy Info.plist and PkgInfo
cp "$MACOS_SRC/Resources/Info.plist" "$TMP_APP/Contents/Info.plist"
echo -n "APPL????" > "$TMP_APP/Contents/PkgInfo"

# Copy Icon
cp "$MACOS_SRC/Resources/AppIcon.icns" "$TMP_APP/Contents/Resources/AppIcon.icns"

echo "🔏 [3/5] Codesigning bundle (Ad-Hoc)..."
codesign --force --deep --sign - "$TMP_APP"

echo "📂 [4/5] Installing to /Applications..."
# Terminate existing instance if running
killall DualSynth 2>/dev/null || true
sleep 0.5

if [ -d "$DEST_APP" ]; then
    mv "$DEST_APP" ~/.Trash/ 2>/dev/null || true
fi

cp -R "$TMP_APP" /Applications/

echo "🚀 [5/5] Launching $DEST_APP..."
open "$DEST_APP"

echo "✅ DualSynth successfully installed and launched from /Applications/DualSynth.app!"
