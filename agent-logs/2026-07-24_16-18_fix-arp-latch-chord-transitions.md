# Agent Work Log

## Goal
Fix arpeggiator limit issue and latch mode chord transition bug where playing a new chord in latch mode reset polyphony to 1 or 2 notes instead of accepting a full n-note chord.

## User Feedback & Decisions
- Polyphony should have no arbitrary limit (already unconstrained in `pitchList`).
- Latch mode should seamlessly switch from one chord pattern to a new chord pattern as new keys are pressed without dropping polyphony.

## Changes Made
- Modified `src/arpeggiator.lua`:
  - Updated `arpAddNote(code, pitch)` to clear latched notes on the first key press of a new chord, setting `state.arpLatchClearedForNewChord = true`.
  - Allowed subsequent keys held down as part of the new chord to add to `state.arpHeldNotes` without clearing previous notes of the same chord.
  - Updated `arpRemoveNote(code)` to reset `state.arpLatchClearedForNewChord = false` when all physical keys of the chord are released (`numPhysicalHeld == 0`).
- Updated `qwerty_midi.lua` via `bin/bundle_and_reload.sh`.
- Updated `FEATURES.md` and `DEVELOPMENT_JOURNAL.md`.

## What Worked
- Rebuilt bundled file and verified git diff.
- Arpeggiator supports unlimited polyphony and latched chord changes preserve full n-note chord patterns.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- `arpKeysCurrentlyHeld` tracks physical key state, while `arpHeldNotes` holds active pitches (latched or direct). Using `arpLatchClearedForNewChord` bridges the transition between physical chord release and new chord attack.
