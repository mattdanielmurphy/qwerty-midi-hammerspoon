## Goal
Synchronize the arpeggiator speed and internal BPM automatically with the active Logic Pro session's tempo.

## User Feedback & Decisions
- Auto-detect Logic Pro tempo in real time.
- Provide a `SYNC: ON/OFF` toggle button on the visual HUD header so the user can easily switch between automatic Logic Pro session sync and manual BPM control.

## Changes Made
- `src/config.lua`: Added `logicSyncEnabled = true` to the state.
- `src/arpeggiator.lua`: Added `fetchLogicBpm()` via JavaScript for Automation (JSA) to read Logic's Control Bar Tempo UI element, `syncLogicBpm()` timer callback (running every 1s), and `toggleLogicSync()` function.
- `src/hud.lua`: Added `logicSyncEnabled` to HUD payload and added webview callback handling for `toggleLogicSync`.
- `src/ui_html.lua`: Added interactive `<button id="logic-sync-btn">` to HUD header and attached click event listeners & render updates.
- Bundled modules via `bin/bundle_and_reload.sh`.

## What Worked
- High-efficiency JSA query reliably polls Logic Pro's Control Bar Tempo value without blocking the main event loop.
- Modifying session tempo in Logic Pro automatically updates the internal arpeggiator rate and HUD display within 1 second.
- Toggling `SYNC: OFF` disables auto-sync and returns tempo control to manual mode (drag, arrow buttons, digit entry).

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- Logic Pro exposes UI element attributes via macOS Accessibility (AppleScript / JSA). Accessing `window 1 -> group 1 -> uiElement 1 ("Control Bar") -> Tempo` retrieves the active session tempo dynamically.
