# KeyStep Pulse-Based Time Division Detection

**Date**: 2026-10-01 15:25  
**Workspace**: `/Users/matt/projects/qwerty-midi-hammerspoon`  
**Status**: Completed & Verified  

## Summary
Resolved the issue where turning the KeyStep `Rate` knob erroneously caused the software to detect a change in `Time Div`.

1. **Root Cause Analysis**:
   - The previous division heuristic evaluated wall-clock elapsed time between notes (`noteDelta` in seconds) against `quarterNoteSeconds = 60 / state.bpm`.
   - Because `state.bpm` was derived from a rolling 24-pulse moving average of MIDI clock ticks, turning the physical `Rate` knob changed the note arrival interval immediately while `bpm` lagged behind, temporarily skewing the ratio and misclassifying the division.

2. **Pulse-Based Division Invariant**:
   - For side-channel one-note sequences with no rests or ties, step division is fundamentally an integer count of 24-PPQN MIDI timing clock pulses (`0xF8`):
     - `1/32T`: 2 pulses
     - `1/32`:  3 pulses
     - `1/16T`: 4 pulses
     - `1/16`:  6 pulses
     - `1/8T`:  8 pulses
     - `1/8`:   12 pulses
     - `1/4T`:  16 pulses
     - `1/4`:   24 pulses
   - Updated `packages/keystep-interceptor/keystep.lua` to count incoming `systemTimingClock` events between sequence notes (`state.clocksSinceLastNote`).
   - Sequence note arrival queries `nearestDivisionByPulses(pulses)` directly. Because the number of clock pulses per step is constant regardless of tempo, spinning the Rate knob no longer alters the pulse count or triggers false division changes.

3. **Testing & Bundling**:
   - Added unit test in `tests/keystep_interceptor.test.js` verifying pulse-based quantization.
   - All 27 tests passing via `bun test`.
   - Rebundled `qwerty_midi.lua` and `dist/keystep_interceptor.lua`.
