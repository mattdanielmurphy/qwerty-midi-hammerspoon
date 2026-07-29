# Crash Hardening & Auto-Reopen on Reload

## Goal
User reported a crash when holding transpose-up key and rapidly pressing oct-. Goal: make the key repeat system crash-proof and add auto-reopen logic so the controller window respawns after crashes or config reloads.

## User Feedback & Decisions
- Crash was reproducible by holding a repeat-capable control key while firing another simultaneously
- Window should auto-reopen after reload only if it was open before the reload
- Should also detect webview crashes and auto-respawn

## Changes Made

### `src/controls.lua`
- **Root crash fix #1 – Stale timer cleanup on reload**: `controlRepeatTimers` is now stored in `_G._qmidiRepeatTimers` (a global). On each module load, any lingering timers from a previous Hammerspoon reload are stopped before reassigning. This prevents old timer callbacks from firing into freshly-reset module state.
- **Root crash fix #2 – No undo snapshot during key repeat**: `pushStateSnapshot` was being called on every 80ms repeat interval for every held key. With two keys held simultaneously that's 25+ snapshots/sec and expensive table operations under real-time constraints. Now `pushStateSnapshot` is locally suppressed (replaced with a no-op) inside all interval callbacks — the snapshot is only pushed on the initial keydown.
- **Crash isolation – pcall in repeat intervals**: All `doEvery` interval callbacks are now wrapped in `pcall` so a single action error (e.g. bad state type, nil dereference) cannot crash the timer and leave it zombie-running or corrupt the eventtap.
- **Guard against nil entry**: Added `if not controlRepeatTimers[code] then return end` guards at the start of both the `doAfter` and `doEvery` callbacks.
- **Exported `stopAllControlRepeats()`**: Added a public function so `init.lua` can flush all active repeats when deactivating MIDI mode.

### `src/init.lua`
- **Persist window state**: `toggleMidiMode` now writes `hs.settings.set("qwertyMidi_wasOpen", state.midiActive)` so the open/closed state survives across reloads.
- **Auto-reopen on reload**: At end of init, reads `qwertyMidi_wasOpen`. If true, calls `toggleMidiMode(true)` after a 300ms delay (to let Hammerspoon finish loading). This means if the window was open when a crash/reload happened, it comes back automatically.
- **Stop repeats on deactivate**: Calls `controls.stopAllControlRepeats()` before stopping the eventtap so no zombie repeat timers survive after the controller is turned off.

### `src/hud.lua`
- **Webview crash detection**: `windowCallback` now checks if `state.midiActive` is still true when the `"closing"` action fires. If it is, that means the webview died unexpectedly (crash, not a user close). A 500ms debounced respawn fires `createMidiWebview()` to bring it back. A `_respawning` guard prevents respawn loops.

## What Worked
- Bundle and reload succeeded cleanly
- All three files edited without syntax issues

## What Didn't Work / Known Issues
- `pushStateSnapshot` suppression inside repeat uses a local variable swap rather than a flag; this is safe since Lua is single-threaded but slightly hacky — a cleaner approach would be a `skipNextSnapshot` flag in state

## Architecture Notes
- Hammerspoon reloads reset all module-local Lua variables but **do not** cancel previously created `hs.timer` objects if those timer tables are no longer reachable. Using `_G._qmidiRepeatTimers` to retain a reference across reloads allows the cleanup step to actually reach and cancel them.
- `windowCallback("closing")` fires for both user-initiated closes AND WebKit process crashes — `state.midiActive` is the discriminator.
