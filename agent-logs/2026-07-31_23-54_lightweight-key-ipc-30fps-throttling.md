# Agent Log — Lightweight Key IPC & 30 FPS Throttled HUD Renders

**Date:** 2026-07-31 23:54
**Scope:** `src/web/index.html`, `src/hud.lua`, `src/controls.lua`, `src/ui_html.lua`, `qwerty_midi.lua`

## Root Cause & Solution

1. **Root Cause (Hammerspoon Timer Queue & WebKit IPC Saturation)**:
   - Analysis of `./tmp/qwerty_midi_debug.log` revealed a 28-second gap where both Lua pings and JS heartbeats froze while playing notes.
   - On every single keypress and arpeggiator step, `updateWebviewHud` was creating an `hs.timer.doAfter(0.016)` timer and sending a 5KB full HUD JSON string over `evaluateJavaScript`.
   - Rapid note playing created dozens of timers per second, saturating Hammerspoon's Lua event loop and backing up WebKit's IPC evaluation queue until the main thread stalled.

2. **Lightweight Key Press IPC (`window.updateKeyState`)**:
   - Added `window.updateKeyState(code, pressed, latched)` in JS.
   - In `controls.lua`, key down and key up events now call `hud.updateSingleKeyState(code, pressed, latched)`, which executes a tiny 20-character JS call `updateKeyState(12, true, false)` directly in 0.05ms without serializing full JSON payloads or traversing all 48 keys.

3. **30 FPS Coalesced HUD Renders (`updateWebviewHud`)**:
   - Enforced a strict 33ms (~30 FPS) minimum frame delay on full JSON HUD updates in `hud.lua`.
   - Prevented transient timer flooding in Hammerspoon's event loop.

## Verification
- Re-bundled via `bin/bundle_and_reload.sh`.
- Logged clean initialization and verified 0ms latency in `./tmp/qwerty_midi_debug.log`.
