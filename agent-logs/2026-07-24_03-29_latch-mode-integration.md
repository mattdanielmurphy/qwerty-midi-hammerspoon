## Goal
Transition sustain pedal / Tab / A key behavior to Latch Mode, enabling sustained notes and arpeggiator chord pattern latching.

## User Feedback & Decisions
- Sustain control updated to Latch Mode (`Tab` / `A` key).
- In Arpeggiator mode, turning Latch Mode ON keeps arpeggiated patterns playing after key release. Playing a new chord automatically clears the previous latched chord and latches the new pattern.

## Changes Made
- `qwerty_midi.lua`:
  - Renamed `Sustain` button label to `Latch` across home row controls and HUD UI.
  - Updated key handler logic so `sustainActive` acts as Latch Mode.
  - Modified `arpAddNote` and `arpRemoveNote` to support Latch mode: releasing keys does not clear latched arpeggiated notes, while pressing new keys resets the latched set to the new chord.
  - Toggling Latch Mode off or triggering Panic/Reset clears latched notes and stops the arpeggiator when no physical keys are down.

## What Worked
- Latch mode holds both standard sustained MIDI notes (CC #64) and arpeggiator patterns effortlessly across key releases.
- Starting a new chord smoothly replaces the previous latched chord.

## What Didn't Work / Known Issues
- None.
