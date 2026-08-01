# Fix: Arp Latch Chord Highlighting + Chord Mode Arp Update

## Summary
Fixed two related bugs in arp latch + chord mode interaction.

## Bug 1: Latched chord keys not highlighted blue in HUD
- **Root cause**: `hud.lua` line 188 checked `state.arpHeldNotes[code]` using integer keycode, but arp held notes in chord mode use compound string keys like `"45_60"` (code_pitch). Match was never found.
- **Fix**: Changed latch detection to prefix-scan all keys in `arpHeldNotes` and check if any starts with the base keycode string.

## Bug 2: Changing chord mode type didn't update the arpeggiated chord
- **Root cause**: `chordUp`/`chordDown` actions in `controls.lua` only changed `state.chordIdx` but didn't rebuild the `arpHeldNotes` table for the new chord intervals.
- **Fix**: Added `updateLatchedArpChordNotes()` to `arpeggiator.lua` which: (1) collects all unique base keycodes from `arpHeldNotes`, (2) removes all their compound key entries, (3) re-adds with new chord pitches from `transposer.getChordPitches()`.

## Files Changed
- `src/hud.lua`: Fixed latch detection (line ~188) to use prefix matching for compound keys
- `src/arpeggiator.lua`: Added `updateLatchedArpChordNotes()` function + exported it
- `src/controls.lua`: Added `arpeggiator.updateLatchedArpChordNotes()` call in all 4 chord change handlers (2x chordUp, 2x chordDown)

## Technical Notes
- Used two-pass pattern for table mutation safety (collect keys, then delete) in `updateLatchedArpChordNotes`
- Existing `updateLatchedArpNotes` already handled compound key prefix parsing via `code:match("^(%d+)")` for transposition updates — the new function follows same pattern
