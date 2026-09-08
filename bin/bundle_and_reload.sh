#!/usr/bin/env bash
# bundle_and_reload.sh — Watcher script executed by launchd/tmux-agent-wrapper.
# Automatically runs hs-bundler to build qwerty_midi.lua and triggers Hammerspoon reload with notification.

PROJECT_DIR="/Users/matt/projects/qwerty-midi-hammerspoon"

cd "$PROJECT_DIR" || exit 1

echo "📦 Bundling Hammerspoon modules..."
python3 "$PROJECT_DIR/bin/hs-bundler" --target qwerty-midi

if [ $? -eq 0 ]; then
  echo "⚡ Reloading Hammerspoon via AppleScript..."
  osascript -e 'tell application "Hammerspoon" to execute lua code "hs.reload()"' >/dev/null 2>&1 &
else
  echo "❌ Bundling failed!"
fi
