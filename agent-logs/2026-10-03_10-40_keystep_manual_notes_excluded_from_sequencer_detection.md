# KeyStep 32 Manual Playable Notes Exclusion from Sequencer Detection & Time Div Inference

**Date**: 2026-10-03 10:40  
**Workspace**: `/Users/matt/projects/qwerty-midi-hammerspoon`  
**Status**: Completed & Verified  

## Summary
Resolved an issue where playing keys manually on the Arturia KeyStep 32 inadvertently altered the Time Div knob. Diagnosed that incoming playable notes occurring while `state.playing` was true were being treated as sequencer notes, computing inter-note pulse intervals and firing `setDivision()`. Fully decoupled manual playable performance keys from the sequencer detection engine so only authentic KeyStep sequencer marker notes (C10..G10 / notes 120..127) drive Mode and Time Division inference.

1. **Root Cause Diagnosis**:
   - In `packages/keystep-interceptor/keystep.lua`, non-marker `noteOn` events included a fallback block executing whenever `state.playing` was true.
   - Any manual keypress while transport/clock was running recorded the human-played pitch into `state.sequenceHistory`, calculated `pulses = state.clocksSinceLastNote`, reset `clocksSinceLastNote = 0`, and invoked `setDivision(nearestDivisionByPulses(pulses))`.
   - This caused the Time Div knob to jump erratically based on the rhythm of human finger strikes and simultaneously corrupted the pulse accumulator for actual sequencer steps.

2. **Decoupling Manual Keys from Sequencer Detection**:
   - Completely removed the `if state.playing then ... setDivision(...)` fallback from manual note handling in `packages/keystep-interceptor/keystep.lua`.
   - Manual notes (black-key modal shift triggers and white-key transposed notes) now bypass all sequence history tracking and pulse resets.
   - Updated `analyzeSequenceAndInferKnobs()` to strictly filter `state.sequenceHistory` entries, ensuring only valid sequence marker notes (`note >= 120` or marker notes) contribute to minimum pulse delta evaluation.
   - Guarded `noteOff` handling so playable manual keys are never mistakenly swallowed as marker notes.

3. **Testing & Verification**:
   - Added unit test in `tests/keystep_interceptor.test.js` validating that manual notes are strictly excluded from sequencer detection, sequence history, and Time Div inference.
   - Verified all 35 tests pass across 8 test suites via `bun test`.
   - Bundled all modules into `qwerty_midi.lua` via `bin/bundle_and_reload.sh` and verified live Hammerspoon state.
