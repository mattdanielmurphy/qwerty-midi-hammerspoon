#!/usr/bin/env bash
# bundle_and_reload.sh — Watcher script executed by launchd/tmux-agent-wrapper.
# Automatically runs hs-bundler to build qwerty_midi.lua and triggers Hammerspoon reload with notification.

PROJECT_DIR="/Users/matt/projects/qwerty-midi-hammerspoon"

cd "$PROJECT_DIR" || exit 1

echo "📦 Bundling Hammerspoon modules..."
python3 "$PROJECT_DIR/bin/hs-bundler" --src "$PROJECT_DIR/src" --entry "init.lua" --output "$PROJECT_DIR/qwerty_midi.lua"

if [ $? -eq 0 ]; then
  echo "🔔 Sending notification & reloading Hammerspoon..."
  osascript -e 'display notification "Reloading Hammerspoon Config..." with title "Hammerspoon"'
  (hs -c "hs.reload()" >/dev/null 2>&1 &)
else
  echo "❌ Bundling failed!"
fi
