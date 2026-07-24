## Goal
Fix Shift key note tap behavior so that holding Shift explicitly bypasses active Sustain and Arp modes, forcing a standard un-sustained direct note tap rather than enabling inactive features.

## User Feedback & Decisions
- Holding Shift while tapping a note when Sustain is ON and Arp is OFF was mistakenly enabling Arp mode and latching notes.
- Shift key taps must strictly bypass active modes (setting both `isArpNote = false` and `isSustainedNote = false`).

## Changes Made
- Updated [src/controls.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/controls.lua):
  - Fixed `handleKeyDown` when `state.shiftHeld` is true: explicitly set `isArpNote = false` and `isSustainedNote = false`.
  - Updated `handleKeyUp` to check `isSustainedNote` directly (rather than fallback `or state.sustainActive`) so bypassed notes immediately dispatch `noteOff` on key release.
- Re-bundled modules into `qwerty_midi.lua` via `bin/bundle_and_reload.sh`.

## What Worked
- Tapping a note while holding Shift when Sustain is ON now plays a standard direct note and stops cleanly upon key release without triggering the Arpeggiator or sustaining the note.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- Note press metadata in `state.pressedKeys[code]` explicitly controls whether a key release triggers `arpeggiator.arpRemoveNote`, stores in `state.sustainedPitches`, or sends a direct `noteOff`.
