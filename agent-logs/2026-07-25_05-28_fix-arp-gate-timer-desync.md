## Goal
Fix arpeggiator gate percentage changes not taking immediate effect across sounding arpeggiated notes, causing staggered or delayed gate duration shifts per note in a sequence.

## User Feedback & Decisions
- User experienced a bug where changing gate percentage did not update sounding arpeggiated notes immediately; instead, notes shifted gate lengths one by one starting from the top note as keys were pressed.

## Changes Made
- `src/arpeggiator.lua`:
  - Fixed timer tracking in `state.arpActiveGateTimers` to stop and clear existing timers when pitches re-trigger.
  - Stopped existing note gate timers when `gateRatio <= 1.0` and `state.arpCurrentPitch` is cleared, preventing duplicate or premature `noteOff` callbacks.
  - Ensured all active note timers in `state.arpActiveGateTimers` are stopped and cleared when `#pitchList == 0`.
  - Added `applyGatePercentChange()` function to flush lingering overlap note-offs immediately when gate percentage drops to <=100%.
  - Exported `applyGatePercentChange`.
- `src/controls.lua` & `src/hud.lua`:
  - Called `arpeggiator.applyGatePercentChange()` whenever `state.arpGatePercent` is modified via hotkeys or UI interactions (`arpGateDown`, `arpGateUp`, `dragGate`, `gateUp`, `gateDown`).

## What Worked
- Arpeggiator note-off timer scheduling is now clean and synchronized.
- Gate changes immediately update sounding/active arpeggiated notes without staggered note releases.

## Architecture Notes
- `state.arpActiveGateTimers` maps pitches to running `hs.timer` objects for >100% gate overlap. Stopping individual pitch timers on re-trigger and flushing overlap timers on gate reduction prevents orphaned background note-off callbacks.
