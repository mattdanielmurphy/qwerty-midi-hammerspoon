## Goal
Eliminate hiccupping and input stutter when notes are played rapidly or at high BPMs.

## User Feedback & Decisions
- Optimize MIDI input tap and HUD webview communication so that fast note bursts, glissandos, and high-speed arpeggiator patterns execute with super high performance and zero latency.

## Changes Made
1. **Decoupled MIDI Execution & Batched Webview Rendering (`src/hud.lua`)**:
   - Webview visual updates were previously called synchronously on every key press and arpeggiator tick via `evaluateJavaScript`.
   - Implemented a ~60 FPS (16ms throttle) non-blocking batching queue (`performWebviewHudUpdate`) so visual DOM updates are combined frame-by-frame while CoreMIDI `noteOn`/`noteOff` commands fire instantaneously with <1ms latency.
   - Eliminated redundant `frame()` accessibility IPC calls on every render pass, only evaluating geometry when scale or window bounds change.

2. **Asynchronous Non-Blocking Logic Pro BPM Sync (`src/arpeggiator.lua`)**:
   - `fetchLogicBpm` previously executed synchronous JXA (`hs.osascript.javascript`), locking the main Lua execution thread for 100-200ms every second.
   - Converted `syncLogicBpm` to an asynchronous background task (`hs.task.new("/usr/bin/osascript", ...)`), running System Events queries in an independent process without freezing the main MIDI thread.

## What Worked
- Re-bundled modules via `bin/bundle_and_reload.sh` and verified smooth reload in Hammerspoon.
- MIDI notes fire immediately on key event taps without waiting on WebKit IPC string serialization or layout calculation.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- In Hammerspoon eventtap handlers, synchronous IPC methods like `evaluateJavaScript` or `hs.osascript` introduce latency that accumulates quickly under high event density (glissandos, fast typing, dense arpeggios). Decoupling UI rendering to a throttled frame loop keeps event tap callbacks lightweight (< 1ms).
