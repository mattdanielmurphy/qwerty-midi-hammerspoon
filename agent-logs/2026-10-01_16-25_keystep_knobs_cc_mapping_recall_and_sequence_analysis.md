# KeyStep 32 Knob CC Mapping, Immediate State Recall & Sequence Analysis

**Date**: 2026-10-01 16:25  
**Workspace**: `/Users/matt/projects/qwerty-midi-hammerspoon`  
**Status**: Completed & Verified  

## Summary
Resolved KeyStep 32 knob parameter mapping and state preservation across HUD summon cycles. Mapped the continuous Rate knob to Master Volume (MIDI CC #7), added 8-step quantized CC outputs for the stepped Mode and Time Div knobs, eliminated GUI knob resets via immediate dual-layer state recall (`hs.settings` and WebKit `localStorage`), and implemented an automated sequence analysis engine to infer knob changes from live clock deltas, sequence marker notes, and inter-note pulse spacing.

1. **Master Volume Mapping for Rate Knob (CC #7)**:
   - Configured `config.rateCc = 7` by default in `packages/keystep-interceptor/keystep.lua`.
   - Wired `setRate` and `setBpm` to transmit standard MIDI Channel Volume (CC #7, 0..127) to CoreMIDI/Logic Pro.
   - Synchronized Rate with the QWERTY MIDI engine volume levels (`state.topRowVolume` and `state.bottomRowVolume`), updating the QWERTY HUD dual volume meters in real-time.
   - Preserved CC 104 as a secondary emission for backward compatibility.
   - Updated the embedded hardware silhouette GUI to display `Rate / Vol` with dynamic readouts (`Vol <rate> (<bpm> BPM)`).

2. **8-Position Quantized CC Outputs for Mode & Time Div Knobs**:
   - Mapped the 8-position stepped knobs (Seq/Arp Mode and Time Div) across the full 0..127 MIDI CC scale:
     $$\text{CC Value} = \lfloor \frac{\text{step} - 1}{7} \times 127 + 0.5 \rfloor$$
     yielding values $[0, 18, 36, 54, 73, 91, 109, 127]$.
   - Mapped Mode knob to `config.modeCc = 16` (General Purpose Controller 1) and Time Div knob to `config.divCc = 17` (General Purpose Controller 2).
   - Preserved raw step CCs 102 and 103 for backward compatibility.

3. **Immediate State Recall on GUI Summon (Zero Reset / Zero Flicker)**:
   - Diagnosed root cause: WebKit webview re-initialization on `_G.toggleMidiMode(true)` reset JS memory to default values (`mode: 1, div: "1/16", rate: 64`), while Hammerspoon's initial `renderHud` omitted KeyStep knob positions.
   - Added persistence via `hs.settings` (`qwertyMidi_ks_mode`, `qwertyMidi_ks_division`, `qwertyMidi_ks_rate`, `qwertyMidi_ks_bpm`, `qwertyMidi_ks_seqArpMode`).
   - Added synchronous WebKit `localStorage` caching in `src/web/index.html` so the UI immediately renders the last known knob angles and labels on frame 0 before IPC arrives.
   - Updated `src/hud.lua` to include `keystepState` in the authoritative `renderHud` payload and automatically trigger `keystep.syncToHud()` upon `domReady`.

4. **Automated Sequence Analysis & Best-Guess Knob Inference**:
   - Implemented `KeyStep.analyzeSequenceAndInferKnobs()`:
     - **Rate Knob**: Evaluates recent clock pulse history (24 PPQN). If clock pulses have been running within the last 1.5s, derives instantaneous BPM from the sliding window and updates Rate.
     - **Mode Knob**: Inspects rolling `state.sequenceHistory` for recent sequencer marker notes (C10..G10 / 120..127 or C8..G8 / 108..115) to detect sequence position changes.
     - **Time Div Knob**: Analyzes pulse intervals $\Delta P$ between consecutive sequence note onsets to identify the minimum step interval ($24, 16, 12, 8, 6, 4, 3, 2$ pulses), resolving the matching straight or triplet division ($1/4$ through $1/32T$).
   - Runs automatically on GUI summon and live note reception.

5. **Testing & Live Hardware Verification**:
   - Added 3 new unit tests in `tests/keystep_interceptor.test.js`. All 32 tests pass via `bun test`.
   - Bundled all targets via `bin/bundle_and_reload.sh`.
   - Verified live in Hammerspoon via `hs -c "return hs.json.encode(_G.activeWatchers.keystep.getFullState())"`.
