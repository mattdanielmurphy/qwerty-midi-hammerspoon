# Fix: Arp Transposition Collapsing Chord Patterns into Single Notes

## Summary
Fixed an issue where transposing key, scale, or octave while an arpeggiator pattern was latched in Chord Mode collapsed the chord pattern down to playing only the single root note.

## Root Cause
- `updateLatchedArpNotes()` in `arpeggiator.lua` previously assumed all entries in `state.arpHeldNotes` represented single notes.
- In Chord Mode, compound string keys (e.g., `"45_60"`, `"45_64"`, `"45_67"`) are stored in `state.arpHeldNotes`.
- When updating pitches during transposition, the old logic called `transposer.getTransposedPitch(noteKey.baseNote)` for each entry, which returned only the root pitch for the base key code, overwriting all chord notes with identical root pitches.

## Fix
- Updated `updateLatchedArpNotes()` to check if any compound keys (keys containing `_`) exist in `state.arpHeldNotes`.
- If compound keys exist, it performs a full two-pass chord rebuild using `transposer.getChordPitches(noteKey.baseNote)` for all active base keys.
- If no compound keys exist, it preserves the standard single-note transposition logic.

## Files Changed
- `src/arpeggiator.lua`: Updated `updateLatchedArpNotes()` logic to branch on compound key detection.
