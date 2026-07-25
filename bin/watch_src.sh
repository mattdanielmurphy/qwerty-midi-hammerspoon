#!/bin/bash
# watch_src.sh — Long-running watcher script for qwerty-midi-bundler daemon.
# Watches src/ directory using fswatch and triggers bundle_and_reload.sh on changes.
#
# NOTE: Uses fswatch --batch-marker so all events per filesystem flush arrive
# together, avoiding the broken "read -d '' -t timeout" bash 3.2 drain idiom.

PROJECT_DIR="/Users/matt/projects/qwerty-midi-hammerspoon"
FSWATCH_BIN="/opt/homebrew/bin/fswatch"

cd "$PROJECT_DIR" || exit 1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting src watcher daemon..."
python3 "$PROJECT_DIR/bin/hs-bundler" --src "$PROJECT_DIR/src" --entry "init.lua" --output "$PROJECT_DIR/qwerty_midi.lua"

DEBOUNCE_DELAY=1.5
LAST_TRIGGER=0

# Use fswatch in line-based mode (one path per line, no null delimiter).
# --latency sets the minimum event coalescing window (seconds) before events fire.
# This replaces the broken bash 3.2 null-delimited drain loops entirely.
"$FSWATCH_BIN" --latency "$DEBOUNCE_DELAY" --recursive "$PROJECT_DIR/src" 2>/dev/null | \
while IFS= read -r changed_file; do
    NOW=$(date +%s)
    # Guard: skip if we already triggered within the last debounce window
    # (handles any residual rapid-fire events that slip through fswatch batching)
    if [ $((NOW - LAST_TRIGGER)) -lt 2 ]; then
        continue
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Change detected ($changed_file), triggering bundle and reload..."
    LAST_TRIGGER=$NOW
    "$PROJECT_DIR/bin/bundle_and_reload.sh"
done
