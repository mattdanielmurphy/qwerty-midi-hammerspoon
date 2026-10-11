# Handoff Report — Audio & MIDI Test Suite Design (R1, R2, R3, R6, R7)

**Agent**: M1 Explorer 1 (Audio & MIDI Test Suite Design)  
**Date**: 2026-10-11  
**Working Directory**: `/Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_explorer_m1_1`  
**Handoff Type**: Hard (Investigation & Test Suite Design Complete)

---

## 1. Observation

1. **R1 Track Volume Key Controls & Synchronous Persistence**:
   - `src/controls.lua:495-512` defines `adjustTrackVolume(trackId, delta)`, which modifies `trk.volume` and calls `midi.sendMidiCC(7, trk.volume, trk.channel or (id - 1))`.
   - `src/controls.lua:503` calls `config.saveSettings()` unconditionally inside `adjustTrackVolume`.
   - `src/controls.lua:2114-2120` runs repeat timers every 80ms (`hs.timer.doEvery(0.08, ...)`), invoking `executeControlAction`, which in turn executes `config.saveSettings()` on line 2025 as well as inside `adjustTrackVolume`.
   - `src/config.lua:197-250` in `saveSettings()` makes >35 synchronous calls to `hs.settings.set(...)`.
   - `src/controls.lua:559-640` and `src/config.lua:388-393` lack dedicated keyboard action bindings for individual tracks (`trk1VolUp`..`trk4VolDown`), only exposing active/row volume actions (`volUp`, `volDown`, `topVolUp`, `topVolDown`, `botVolUp`, `botVolDown`).

2. **R2 Rich Arpeggiator Patterns & Velocity Contours**:
   - `src/config.lua:58` and `packages/music-engine/clock.lua:4` define only 7 basic directions:
     ```lua
     ARP_DIRECTIONS = { "UP", "DOWN", "UP-DOWN", "DOWN-UP", "CONVERGE", "DIVERGE", "RANDOM" }
     ```
   - `src/arpeggiator.lua:418-420` calculates velocity statically:
     ```lua
     local vel = math.floor(math.min(127, (trk.volume or 100) * 1.0))
     ```
   - `src/arpeggiator.lua:441` computes gate length strictly linearly:
     ```lua
     local gateDuration = trackStepSec * gateRatio
     ```
   - No velocity contours (accents, groove pulses), dynamic gate variations, or microtiming/swing deviations exist in `src/arpeggiator.lua`.

3. **R3 Configurable Quantization Amount**:
   - `packages/music-engine/quantizer.lua:36-64` defines `calculateDelay(bpm, mode)` taking only two arguments.
   - Delay calculation `timeToNext = stepDuration - elapsed` is strictly all-or-nothing (100% grid delay or 0% for `"Off"`).
   - There is no strength factor ($S \in [0, 100]\%$) or default 90% parameter in `quantizer.lua` or `src/config.lua`.

4. **R6 Stuck Note Mitigation & Watchdog Loop**:
   - `packages/music-engine/quantizer.lua:83-88`:
     ```lua
     if pendingEvents[eventId] then
       if pendingEvents[eventId].timer then pcall(function() pendingEvents[eventId].timer:stop() end) end
       if pendingEvents[eventId].gateTimer then pcall(function() pendingEvents[eventId].gateTimer:stop() end) end
       pendingEvents[eventId] = nil
     end
     ```
   - When a note is played with staccato release, `ev.gateTimer` is scheduled for 60ms to fire Note-Off. If the player re-triggers the same key before 60ms expires, `pendingEvents[eventId].gateTimer` is stopped and wiped without calling `onRelease` or sending Note-Off, causing an orphaned stuck note on the synth.
   - `src/midi.lua:97-98` records voices in `activeNoteLedger[noteNum][ch]` without a timestamp (`startTime`).
   - `src/midi.lua` has no orphan detection function (`checkOrphanedVoices`).
   - `src/init.lua:418-445` runs `keyTapWatchdog` monitoring webview heartbeat only, with no watchdog loop for orphaned MIDI voices.

5. **R7 Tap Tempo Engine**:
   - `src/controls.lua:2018-2022`:
     ```lua
     elseif act == "tapTempo" then
       if arpeggiator.tapTempo then
         arpeggiator.tapTempo()
       end
       hud.updateWebviewHud(...)
     ```
   - `grep -n "tapTempo" src/arpeggiator.lua packages/music-engine/clock.lua` returns 0 results. `arpeggiator.tapTempo` is completely undefined / nil.

---

## 2. Logic Chain

1. **R1 Logic**:
   - From Observation 1, repeating volume keystrokes fire `config.saveSettings()` every 80ms, generating heavy I/O contention (>35 settings writes per tick).
   - Therefore, volume repeat timers must decouple in-memory state mutation from disk persistence using a debounced trailing timer (e.g. 300ms).
   - Individual track volume actions (`trkVolUp1..4`, `trkVolDown1..4`) must be registered in `controls.lua` and `config.lua` to fulfill R1.
   - Tests in Tier 1 and Tier 2 must verify action registration, CC 7 emission per track channel, strict 0..127 clamping, muted state handling, and debounced timer coalescing.

2. **R2 Logic**:
   - From Observation 2, arpeggiator steps use flat velocity multipliers (1.0) and rigid gate lengths, producing a mechanical sound without human feel.
   - Adding pattern-based velocity contours ($v_{\text{step}} = v_{\text{base}} \times c_{\text{contour}}(i)$ clamped to 1..127), step gate ratios, and swing microtiming ($\Delta t_{\text{swing}} = (S - 0.5) \times t_{\text{step}}$) fulfills R2.
   - Tests in Tier 1 and Tier 2 must verify velocity accent multipliers, boundary clamping at 1 and 127, variable gate lengths, and straight vs heavy swing offsets.

3. **R3 Logic**:
   - From Observation 3, `quantizer.calculateDelay` has no strength scaling.
   - Updating the signature to `calculateDelay(bpm, mode, amount)` and applying $\text{delay} = \text{timeToNext} \times (\text{amount} / 100.0)$ with a default of 90% fulfills R3.
   - Tests in Tier 1 and Tier 2 must verify 0% (immediate trigger), 90% (humanized grid correction), 100% (hard snap), and boundary clamping for invalid numbers.

4. **R6 Logic**:
   - From Observation 4, retriggering a key before staccato `gateTimer` expires cancels the timer without releasing the prior voice.
   - Ensuring that re-triggering a key executes `onRelease` before overwriting the event solves the staccato hung note defect.
   - Adding `startTime` to `activeNoteLedger` and scheduling a periodic `midi.checkOrphanedVoices(maxAge)` watchdog in `init.lua` (guarded strictly by `state.midiActive`) completes the safety loop.
   - Tests in Tier 1, Tier 2, and Tier 3 must verify staccato retrigger voice cleanup, watchdog age thresholds, and immune states (held keys / smart sustain).

5. **R7 Logic**:
   - From Observation 5, tap tempo is an unhandled nil reference.
   - Implementing `arpeggiator.tapTempo()` with rolling average interval calculation ($N = 4..8$), >2s timeout reset, and [30, 300] BPM clamping restores tap tempo functionality.
   - Tests in Tier 1, Tier 2, and Tier 3 must verify baseline tap establishment, steady tempo calculation, timeout reset, sub-50ms debounce rejection, and active arpeggiator clock resynchronization.

---

## 3. Caveats

1. **Hammerspoon Native API Execution**: Hammerspoon APIs (`hs.midi`, `hs.timer`, `hs.settings`) require the Hammerspoon application runtime and cannot be executed in bare Node/Bun without mocks. The designed tests use Bun-native source contract validation and deterministic JavaScript mathematical simulations, backed by a specification for a pure-Lua mock shim (`tests/harness/hs_mock.lua`).
2. **DAW Audio Output**: Automated tests can verify CoreMIDI packet generation (status bytes, channel, controller number, value, timestamps), but physical audio synthesis depends on host DAW software (e.g., Logic Pro).

---

## 4. Conclusion

A complete, 4-tier testing specification covering 73 test cases has been designed and documented in `analysis.md`:
- **Tier 1 (Feature Contracts)**: 30 test cases across `tests/tier1_feature_contracts/` verifying exact function signatures, bindings, formulas, and exports for R1, R2, R3, R6, and R7.
- **Tier 2 (Boundary & Corner Cases)**: 30 test cases across `tests/tier2_boundary_edge_cases/` testing clamping extremes (0..127, 30..300 BPM, 0..100%), rapid bounce intervals (<10ms, <50ms), and timeout boundaries (>2.0s).
- **Tier 3 (Cross-Feature Combinations)**: 9 test cases across `tests/tier3_cross_feature_interactions/` testing volume repeats during quantized chord playing (R1+R6), live tap tempo resync during active arpeggiator playback (R2+R7), and partial quantization legato sustaining with watchdog monitoring (R3+R6).
- **Tier 4 (Real-World Application Scenarios)**: 4 test cases across `tests/tier4_real_world_e2e_scenarios/` validating multi-track live jamming and chaos key mashing with panic recovery.

This test architecture provides an unambiguous, verifiable implementation target for Milestone M2 (R3, R6) and Milestone M3 (R1, R2, R7).

---

## 5. Verification Method

To independently verify all findings and test designs:

1. **Inspect Existing Test Suite Baseline**:
   ```bash
   bun test
   ```
   Confirms 77 passing tests across 19 files with 0 failures in ~750ms.

2. **Verify Missing `tapTempo`**:
   ```bash
   grep -n "tapTempo" src/controls.lua src/arpeggiator.lua packages/music-engine/clock.lua
   ```
   Shows `controls.lua:2018` calls `arpeggiator.tapTempo()`, but it is nowhere defined.

3. **Verify Staccato Gate Dropping Code**:
   ```bash
   sed -n '83,88p' packages/music-engine/quantizer.lua
   ```
   Shows `gateTimer:stop()` without invoking `onRelease`.

4. **Verify Synchronous Settings Persistence in Volume Repeat**:
   ```bash
   sed -n '500,505p' src/controls.lua
   sed -n '2114,2121p' src/controls.lua
   ```
   Shows synchronous `config.saveSettings()` on repeat ticks.

5. **Review Complete Test Suite Specifications**:
   Inspect `/Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_explorer_m1_1/analysis.md` for full test code, test case names, inputs, and assertion criteria.
