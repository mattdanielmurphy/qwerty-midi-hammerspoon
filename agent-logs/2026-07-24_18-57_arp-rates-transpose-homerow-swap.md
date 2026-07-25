## Goal
Three changes requested:
1. Expand arp rates: add 4, 2, 1, 1/2 on the slow end and 1/64 on the fast end; add triplet variants for ALL rates (not just 1/8T and 1/16T as before).
2. Transpose changes should update latched arpeggiator notes in real time (same as scale/root/mode already do).
3. Swap Transpose and Vol+/- on the home row — Transpose should be directly on G/; (no Shift required), Vol+/- moves to Shift+G/Shift+;.

## User Feedback & Decisions
- No explicit design questions were asked; the request was unambiguous.

## Changes Made

### `src/config.lua`
- `arpRateIdx` default changed from 2 (`1/8`) to 5 (`1/4`) since indexing shifted.
- `ARP_RATES` expanded from 6 entries to 18 entries:
  - Straight: 4, 2, 1, 1/2, 1/4, 1/8, 1/16, 1/32, 1/64
  - Triplet: 4T, 2T, 1T, 1/2T, 1/4T, 1/8T, 1/16T, 1/32T, 1/64T
  - Triplet factor formula: straight_factor / 1.5 (one triplet = 2/3 of a straight note duration)
- `homeRowControls[5]` (G key): changed action from `volDown` → `trnspDown`, shiftAction still `volDown` (now Shift+G = Vol-)
- `homeRowControls[41]` (`;` key): changed action from `volUp` → `trnspUp`, shiftAction still `volUp` (now Shift+; = Vol+)

### `src/controls.lua`
- `trnspDown` handler: added `arpeggiator.updateLatchedArpNotes()` call immediately after modifying `transposeShift`.
- `trnspUp` handler: same.

## What Worked
- Bundle succeeded cleanly (9 modules).
- Hammerspoon reloaded via AppleScript.

## What Didn't Work / Known Issues
- None known. The triplet formula `factor / 1.5` is the standard musical triplet relationship.

## Architecture Notes
- `updateLatchedArpNotes()` in arpeggiator.lua iterates `arpHeldNotes` and re-calls `getTransposedPitch()` for each key. Since `getTransposedPitch` uses `state.transposeShift`, calling it after changing transposeShift correctly retunes held arp notes.
- The ARP_RATES factor represents the fraction of one quarter-note beat. Factor 1.0 = quarter note. Factor 16.0 = 4 whole notes. Factor 0.0625 = 64th note.
