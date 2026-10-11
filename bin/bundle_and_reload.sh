#!/usr/bin/env bash
# bundle_and_reload.sh — Watcher script executed by launchd/tmux-agent-wrapper.
# Automatically runs hs-bundler to build qwerty_midi.lua and triggers Hammerspoon reload with notification.

PROJECT_DIR="/Users/matt/projects/qwerty-midi-hammerspoon"

cd "$PROJECT_DIR" || exit 1

echo "📦 Bundling Hammerspoon modules..."
python3 "$PROJECT_DIR/bin/hs-bundler" --target qwerty-midi
if [ $? -ne 0 ]; then
  echo "❌ Bundling failed!" >&2
  exit 1
fi

echo "🔍 Validating bundled Lua syntax..."
LUAC_BIN="luac"
if ! command -v "$LUAC_BIN" >/dev/null 2>&1; then
  if [ -x "/opt/homebrew/bin/luac" ]; then
    LUAC_BIN="/opt/homebrew/bin/luac"
  elif [ -x "/usr/local/bin/luac" ]; then
    LUAC_BIN="/usr/local/bin/luac"
  fi
fi

if ! "$LUAC_BIN" -p qwerty_midi.lua; then
  echo "❌ Lua syntax validation failed on qwerty_midi.lua! Aborting reload." >&2
  exit 1
fi
echo "✅ Syntax validation passed."

echo "⚡ Reloading Hammerspoon..."
if command -v hs >/dev/null 2>&1; then
  hs -c "hs.reload()" >/dev/null 2>&1 &
else
  osascript -e 'tell application "Hammerspoon" to execute lua code "hs.reload()"' >/dev/null 2>&1 &
fi
