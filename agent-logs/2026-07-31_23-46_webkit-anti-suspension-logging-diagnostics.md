# Agent Log — WebKit Anti-Suspension Sentinel & Comprehensive Logging Diagnostics

**Date:** 2026-07-31 23:46
**Scope:** `src/web/index.html`, `src/hud.lua`, `src/init.lua`, `src/ui_html.lua`, `qwerty_midi.lua`

## Diagnostics & Root Cause Discovery

1. **Root Cause Uncovered (macOS WebKit Process Throttling)**:
   - System log inspection revealed `ProcessThrottler::setThrottleState: Updating process assertion type to 1 (foregroundActivities=0, backgroundActivities=2)`.
   - Because the HUD webview runs as a borderless utility window without direct typing focus, macOS WebKit was classifying the WebProcess as a **Background View** and throttling/suspending DOM repaints, timer ticks, and `evaluateJavaScript` execution.

2. **WebKit Anti-Suspension Audio Sentinel (`src/web/index.html`)**:
   - Added a silent Web Audio Context sentinel oscillator (`gain.value = 0.00001`).
   - In WebKit, active Web Audio forces `foregroundActivities > 0` in ProcessThrottler, permanently preventing macOS from putting the web content process into sleep/suspension.

3. **Comprehensive Diagnostic Logging (`src/hud.lua` & `src/init.lua`)**:
   - Implemented `hudLog(msg)` and `_G.dumpMidiLogs()` to dump both Lua startup logs (`/tmp/midi_startup.log`) and Webview JS logs (`/tmp/wv_js.log`) directly to clipboard and console.
   - Added execution timing diagnostics to `renderHud(data)` in JS.

## Verification
- Bundled and reloaded Hammerspoon via `bin/bundle_and_reload.sh`.
- Confirmed log entries in `/tmp/midi_startup.log`.
