# KeyStep 32 Volume Knob Full 0..127 MIDI Range Realignment

**Date**: 2026-10-03 10:52  
**Workspace**: `/Users/matt/projects/qwerty-midi-hammerspoon`  
**Status**: Completed & Verified  

## Summary
Uncapped the Master Volume / Rate knob scaling from its previous 100 limit, restoring the full 0..127 (or 1..127 active velocity) MIDI range. The previous 100 cap was an artifact of Arturia plugin gain distortion testing (+12dB at CC 127 vs 0dB unity gain at CC 100), which is no longer needed.

1. **Volume Scaling Uncapped**:
   - Updated `config.maxVolumeCc` in `packages/keystep-interceptor/keystep.lua` from `100` to `127`.
   - Updated `rateToVolumeCc()` fallback from `100` to `127`, enabling 1:1 continuous mapping across the full 0..127 range.
   - Synchronized Master Volume and QWERTY engine row volumes (`state.topRowVolume` and `state.bottomRowVolume`) so sweeping the Rate/Vol knob spans the complete 0% to 100% (CC 0..127) scale.

2. **Testing & Verification**:
   - Updated unit test in `tests/keystep_interceptor.test.js` to assert `maxVolumeCc = 127` and verified that Rate 127 maps to Volume CC 127.
   - Passed all 35 tests across 8 test suites via `bun test`.
   - Re-bundled all modules into `qwerty_midi.lua` via `bin/bundle_and_reload.sh`.
