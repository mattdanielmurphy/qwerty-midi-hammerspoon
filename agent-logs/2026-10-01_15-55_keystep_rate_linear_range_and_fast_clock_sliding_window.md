# KeyStep 32 Rate Linear Range & Fast Sliding-Window Clock Tracking

**Date**: 2026-10-01 15:55  
**Workspace**: `/Users/matt/projects/qwerty-midi-hammerspoon`  
**Status**: Completed & Verified  

## Summary
Resolved KeyStep 32 Rate knob range clipping and replaced the slow 24-pulse EMA clock estimator with a sub-second adaptive sliding-window pulse tracker. Copied the official KeyStep manual to the repository root for reference.

1. **Linear 30–240 BPM Range with ~137 BPM Midpoint**:
   - Discovered `config.rateCcValue` previously used `math.floor(bpm + 0.5)` clamped to 127, causing the rate value to reach 127 at only 127 BPM (halfway across the rotation) and stay stuck for all higher tempos up to 240 BPM, while minimum (30 BPM) showed 30 instead of 0.
   - Replaced with a linear potentiometer mapping: 30 BPM $\to$ Rate 0, ~136–137 BPM $\to$ Rate 64 (midpoint / 12:00), and 240 BPM $\to$ Rate 127.
   - Synchronized mapping across `packages/keystep-interceptor/keystep.lua`, `src/web/index.html`, and `src/ui_html.lua`.

2. **Sub-Second Adaptive Sliding-Window Clock Estimator**:
   - Diagnosed root cause of the 5–10 second settling lag: the old estimator waited for 24 non-overlapping pulses before calculating (2.0s at 30 BPM) and then blended with a 60% exponential memory (`bpm * 0.6 + instantBpm * 0.4`), requiring 6–10 multi-second iterations to settle.
   - Rebuilt `handleClock` with an adaptive ring buffer evaluating on **every clock pulse** over a sliding window target of ~200ms ($\ge 4$ pulses, up to 16 pulses).
   - Added adaptive slew rates: $\alpha = 0.85$ on active knob sweeps ($|\Delta| > 8$ BPM) for instant snapping ($< 0.25$s), scaling to $\alpha = 0.10$ with deadband hysteresis in steady state to reject USB timing jitter.
   - Throttled console state publishing to 0.5s intervals during rapid sweeps.

3. **KeyStep 32 Slim Manual Reference**:
   - Copied `Arturia KeyStep 32 Slim Manual.pdf` into project root and verified Chapter 2 (Operations), Chapter 6 (Synchronization / Clock), and Chapter 8 (MIDI Control Center).

4. **Testing & Live Hardware Verification**:
   - All 29 tests pass via `bun test`.
   - Bundled via `bin/bundle_and_reload.sh` and live-verified in Hammerspoon with the physical KeyStep 32 streaming clock pulses.
