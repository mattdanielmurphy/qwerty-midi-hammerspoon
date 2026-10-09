# Agent Work Log: Idle Timer & Watchdog Cleanup

**Timestamp:** 2026-10-09 10:10  
**Issue:** Mac internal keyboard dropped keys when typing on battery power / Low Power Mode due to unnecessary background timers running while the QWERTY MIDI HUD was closed.

## Root Cause Analysis
1. In `src/logic_names.lua`, `logic_names.init()` was called unconditionally on module load, starting a 2-second polling timer (`pollTimer`) and an application watcher even when the MIDI controller was closed.
2. In `src/arpeggiator.lua`, `initLogicSync()` was called unconditionally on module load, creating a 1-second recurring timer (`logicSyncTimer`) calling `syncLogicBpm()`.
3. In `src/init.lua`, `_G.activeWatchers.keyTapWatchdog` was started unconditionally with `hs.timer.doEvery(3.0)` on boot, ticking every 3 seconds even when `state.midiActive` was false.
4. These recurring timers created unnecessary run loop churn in Hammerspoon on battery power, contributing to input congestion and dropped keys.

## Solutions Applied
1. **Conditional Logic Names Lifecycle:**
   - In `src/logic_names.lua`, guarded `init()` to return immediately if `state.midiActive` is false.
   - Removed unconditional top-level `logic_names.init()` call from `src/init.lua`.
   - Wired `logic_names.init()` to start strictly on `toggleMidiMode(true)` and `logic_names.stop()` on `toggleMidiMode(false)` / `disarmMidiInput()`.
2. **Conditional Logic Sync Lifecycle:**
   - Exported `startLogicSync()` and `stopLogicSync()` from `src/arpeggiator.lua`.
   - Guaranteed `logicSyncTimer` only runs when both `state.midiActive` and `state.logicSyncEnabled` are true.
   - Stopped `logicSyncTimer` cleanly on HUD close or when logic sync is toggled off.
3. **Conditional Watchdog Lifecycle:**
   - Created `keyTapWatchdog` using `hs.timer.new(3.0, ...)` instead of `hs.timer.doEvery`.
   - Started watchdog strictly when `state.midiActive` is true; stopped it cleanly in `disarmMidiInput()` and `toggleMidiMode(false)`.
4. **Verification:**
   - Rebundled `qwerty_midi.lua` via `bin/hs-bundler`.
   - Passed all 77 Bun tests across 19 suites.
   - Verified via `hs -c` that when the MIDI HUD is closed, `keyTapWatchdog`, `logicNamesTimer`, and `logicSyncTimer` are completely stopped and inactive.
   - Verified that opening the HUD enables the key tap, watchdog, and track name sync, and closing the HUD tears down all timers.
