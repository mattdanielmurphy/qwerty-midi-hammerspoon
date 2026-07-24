#!/bin/bash
# watch_src.sh — Long-running watcher script for qwerty-midi-bundler daemon.
# Watches src/ directory using fswatch and triggers bundle_and_reload.sh on changes.

PROJECT_DIR="/Users/matt/projects/qwerty-midi-hammerspoon"
FSWATCH_BIN="/opt/homebrew/bin/fswatch"

cd "$PROJECT_DIR" || exit 1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting src watcher daemon..."
python3 "$PROJECT_DIR/bin/hs-bundler" --src "$PROJECT_DIR/src" --entry "init.lua" --output "$PROJECT_DIR/qwerty_midi.lua"

DEBOUNCE_DELAY=1.5

"$FSWATCH_BIN" -0 "$PROJECT_DIR/src" 2>/dev/null | while read -d "" _file; do
    # Drain any additional pending change events that arrived during rapid succession
    while read -t 0.1 -d "" _extra 2>/dev/null; do :; done

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Change detected in src/ ($_file), debouncing ${DEBOUNCE_DELAY}s..."
    sleep "$DEBOUNCE_DELAY"

    # Drain events queued up during the sleep wait period before triggering rebuild
    while read -t 0.1 -d "" _extra 2>/dev/null; do :; done

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Triggering bundle and reload..."
    "$PROJECT_DIR/bin/bundle_and_reload.sh"
done
