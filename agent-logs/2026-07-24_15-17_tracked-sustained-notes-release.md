## Goal
Restore working sustain pedal behavior (latching/holding notes across releases) while ensuring all sustained pitches receive explicit `noteOff` and `MIDI CC #123` when sustain mode is turned off or window is closed.

## User Feedback & Decisions
- Notes must sustain when sustain mode is active.
- Notes must not ring infinitely after disabling sustain or closing/reopening the controller window.

## Changes Made
1. **`src/config.lua`**:
   - Added `sustainedPitches = {}` to the global state object.
2. **`src/controls.lua`**:
   - Re-enabled sustain note-holding logic in `handleKeyUp`: when `isSustainedNote` is `true`, keyUp suppresses immediate `noteOff` and tracks the pitch in `state.sustainedPitches[pitch] = true`.
   - When sustain mode turns `OFF` (via tap or momentary key release), `controls.lua` loops through all tracked `state.sustainedPitches` and sends individual explicit `noteOff` MIDI messages, followed by `MIDI CC #64 = 0` and `MIDI CC #123 = 0`.
3. **`src/init.lua`**:
   - Clears `state.sustainedPitches` when toggling off / closing MIDI mode.
4. Re-bundled via `./bin/bundle_and_reload.sh`.

## What Worked
- Sustain works as expected (notes continue ringing after key release while sustain is active).
- Disabling sustain cleanly silences all active sustained pitches by sending explicit `noteOff` messages for all tracked pitches plus `CC #64 = 0` and `CC #123 = 0`.

## Architecture Notes
- Many virtual MIDI synths and DAW plugins do not automatically release held notes upon receiving `CC #64 = 0` if `noteOff` was never dispatched for those note numbers while key was held down. Explicitly tracking `sustainedPitches` in Lua and flushing `noteOff` messages when sustain drops to `OFF` bridges DAWs that ignore `CC #64 = 0` alone.
