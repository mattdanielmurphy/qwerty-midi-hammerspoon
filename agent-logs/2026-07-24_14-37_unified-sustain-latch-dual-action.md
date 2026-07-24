## Goal
Unify Sustain (CC #64) and Arpeggiator Latch Mode into a single key (`Tab` / `A`) while restoring dual-action behavior (Tap to toggle ON/OFF, Hold for momentary sustain/latch).

## User Feedback & Decisions
- Sustain and Latch Mode should share the exact same state and key. Turning Sustain on turns Latch mode on.
- The Sustain key must retain its dual-action behavior: tapping the key toggles it ON/OFF, while holding it down acts as a momentary hold that releases on keyUp.

## Changes Made
- `qwerty_midi.lua`:
  - Re-unified `sustainActive` as the single truth state for both CC #64 sustain pedal and Arpeggiator pattern latching.
  - Retained `sustainKeyDownTime` and `sustainWasActiveOnPress` timestamp tracking on `keyDown`.
  - Implemented dual-action check on `keyUp`:
    - `holdDuration > 0.25s` -> Momentary release: `sustainActive` set to `false`, CC #64 = 0, arpeggiator latched notes released if no keys are down.
    - `holdDuration <= 0.25s` -> Tap toggle: if it was active when pressed, set to `false`; if inactive, toggle to `true` and latch.
  - Updated key label to `"Sustain"` on key pad 0 (`A`) and 48 (`Tab`).

## What Worked
- Tapping `A` or `Tab` toggles Sustain & Arpeggiator Latch ON or OFF cleanly.
- Holding `A` or `Tab` maintains Sustain & Arpeggiator Latch for the duration of the hold, releasing cleanly when let go.
- Starting new chords while sustained/latched replaces old arpeggiator patterns seamlessly.

## What Didn't Work / Known Issues
- None.
