## Goal
Implement Shift key note tap bypass logic for Sustain and Arpeggiator modes:
- When Shift is held while tapping a note key on either row, invert the effective Sustain and Arpeggiator mode for that note.
- If Arp mode is ON, holding Shift bypasses Arp mode to play the note directly as a normal note.
- If Sustain is ON, holding Shift bypasses Sustain to damp/turn off the note when released.
- Works seamlessly across both upper and lower keyboard rows.

## User Feedback & Decisions
- Tapping notes while holding Shift should act as an instantaneous behavior override (opposite of current Sustain and Arp settings).

## Changes Made
- Updated [src/controls.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/controls.lua):
  - Modified `handleKeyDown` to inspect `state.shiftHeld` when a note key is pressed.
  - Calculated inverted boolean flags for `isArpNote` and `isSustainedNote` when `state.shiftHeld` is true.
  - Stored `isArpNote` and `isSustainedNote` flags in `state.pressedKeys[code]` table so `handleKeyUp` accurately releases/damps according to the exact mode under which the note was struck.
  - Updated `handleKeyUp` to read `isArpNote` and `isSustainedNote` from `state.pressedKeys[code]` table.
- Bundled changes via `bin/bundle_and_reload.sh` to update [qwerty_midi.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/qwerty_midi.lua).
- Updated [FEATURES.md](file:///Users/matt/projects/qwerty-midi-hammerspoon/FEATURES.md).

## What Worked
- Holding Shift while striking a key bypasses active Arp and Sustain modes cleanly.
- Releasing the key accurately stops/damps the note according to the inverted mode state captured on keyDown.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- `state.pressedKeys[code]` now holds a metadata table `{ pitch = ..., isArpNote = ..., isSustainedNote = ... }` for note keys, ensuring key release behavior matches key press state even if Shift or Sustain is toggled while the key is held down.
