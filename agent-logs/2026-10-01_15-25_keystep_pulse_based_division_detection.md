# KeyStep Pulse-Based Time Division Detection

**Date**: 2026-10-01 15:25  
**Workspace**: `/Users/matt/projects/qwerty-midi-hammerspoon`  
**Status**: Completed & Verified  

## Summary
Resolved the issue where turning the KeyStep `Rate` knob erroneously caused the software to detect a change in `Time Div`.

1. **Root Cause Analysis**:
   - The previous division heuristic evaluated wall-clock elapsed time between notes (`noteDelta` in seconds) against `quarterNoteSeconds = 60 / state.bpm`.
   - `state.bpm` was perpetually stuck at default 120 because Hammerspoon's `hs.midi` emits MIDI timing clock (`0xF8`) as `commandType == "systemMessage"` with `metadata.data == "f8"`, rather than `"systemTimingClock"`.
   - Consequently, `handleClock` had never been invoked. The code always assumed 120 BPM, forcing the user to manually dial the physical Rate knob to exactly 120 BPM for Time Div to match.

2. **Pulse-Based Division Invariant & Realtime Clock Hook**:
   - Updated `handleMidiEvent` to recognize `systemMessage` with `f8` (clock), `fa`/`fb` (start/continue), and `fc` (stop).
   - Replaced micro-delta clock division with a 24-pulse quarter-note window calculation (`CLOCK_PULSES_PER_QUARTER = 24`), completely eliminating USB batching jitter.
   - For side-channel one-note sequences with no rests or ties, step division is fundamentally an integer count of 24-PPQN MIDI timing clock pulses (`0xF8`):
     - `1/32T`: 2 pulses
     - `1/32`:  3 pulses
     - `1/16T`: 4 pulses
     - `1/16`:  6 pulses
     - `1/8T`:  8 pulses
     - `1/8`:   12 pulses
     - `1/4T`:  16 pulses
     - `1/4`:   24 pulses
   - Sequence note arrival queries `nearestDivisionByPulses(pulses)` directly from `state.clocksSinceLastNote`.
   - Verified live in Hammerspoon: turning Rate from 120 BPM to 153+ BPM tracked tempo smoothly while maintaining exact pulse counts (`Pulses: 8` for `1/8T`) without jumping divisions.

3. **Testing & Bundling**:
   - Added unit test in `tests/keystep_interceptor.test.js` verifying pulse-based quantization and windowed BPM calculation.
   - All 27 tests passing via `bun test`.
   - Rebundled `qwerty_midi.lua` and `dist/keystep_interceptor.lua`.

