# KeyStep 32 Rate Knob Master Volume Realignment (CC #17 & CC #7) with 0dB Unity Gain Cap

## Context & Objectives
- **User Problem Statement:**
  1. The Time Div knob was inadvertently assigned to volume control instead of the Rate knob.
  2. For the volume control, especially in Arturia audio plugins (Analog Lab, Pigments, V Collection), the volume control had too large a range and the top end added an excessive amount of gain (+12dB boost), causing heavy digital distortion and fried audio.
- **Root Cause Analysis:**
  - In Arturia plugins, CC #16..19 are hardcoded to Macros 1..4 by default, where Macro 2 (CC #17) typically controls Output Level / Master Volume / Gain.
  - Previously, `config.divCc` was set to 17 (intended as a generic unassigned CC), which Arturia intercepted as Macro 2 / Volume! Turning Time Div through its 8 positions caused sudden jumping volume changes, and at step 8 sent CC 127 (+12dB digital gain boost).
  - Meanwhile, the Rate knob was emitting CC #7, which Arturia does not listen to for output volume by default.
  - When volume was set to CC 127 in Arturia, it exceeded 0dB unity gain into $+6\text{ dB}$ to $+12\text{ dB}$ digital clipping boost.

## Changes Made
1. **Realigned Volume Control to Rate Knob:**
   - In `packages/keystep-interceptor/keystep.lua`:
     - Updated `config.rateCc = 17` (Arturia Macro 2 / Output Level).
     - Added `config.rateStandardCc = 7` (Standard MIDI Channel/Master Volume).
     - Added `config.maxVolumeCc = 100` and `config.minVolumeCc = 0`.
     - Created `rateToVolumeCc(rateVal)` function:
       $$\text{volCc} = \lfloor \text{minV} + \frac{\text{clamp}(\text{rateVal}, 0, 127)}{127} \times (\text{maxV} - \text{minV}) + 0.5 \rfloor$$
       This maps Rate $0..127$ strictly to Volume CC $0..100$.
       At Rate 0 (30 BPM / minimum knob), Volume CC is 0 (mute).
       At Rate 64 (120 BPM / center knob), Volume CC is 50.
       At Rate 127 (240 BPM / maximum knob), Volume CC is 100 ($0\text{ dB}$ unity gain), completely eliminating digital distortion and gain boost.
2. **Reassigned Stepped Knobs to Safe Unreserved CCs:**
   - Set `config.modeCc = 105` (continuous) and discrete `sendCC(102, mode)`.
   - Set `config.divCc = 106` (continuous) and discrete `sendCC(103, division.ccValue)`.
   - Neither knob touches CC 16, 17, 18, or 19, completely freeing Arturia Macros from stepped knob interference.
3. **Synchronized Master Volume with QWERTY MIDI Engine & HUD:**
   - `setBpm` and `setRate` emit both CC #17 and CC #7 with `volCcVal`, as well as raw Rate CC on CC #104.
   - Synchronized with `state.topRowVolume = volCcVal` and `state.bottomRowVolume = volCcVal`.
   - Updated `src/web/index.html` to display `Vol ${volPercent}% (${bpm} BPM)` where `volPercent = Math.round((rate / 127) * 100)`.
   - Updated tooltips and titles on `ks-knob-rate-unit` (`title="Rate / Master Volume CC #17 & CC #7 (0-100% Unity Gain)"`) and `ks-knob-div-unit` (`title="Time Div (8 Positions, CC 103 & CC 106)"`).
4. **Bundling & Production Sync:**
   - Bundled all modules into `qwerty_midi.lua` via `bin/hs-bundler --target qwerty-midi`.
   - Reloaded Hammerspoon. Verified state and volume dispatch live via `hs -c`.

## Verification
- **Automated Tests:**
  - Updated `tests/keystep_interceptor.test.js` to assert:
    - Rate knob maps to Master Volume via CC #17 and CC #7 with 0dB unity gain cap (`maxVolumeCc = 100`).
    - Verified mathematical volume scaling ($[0, 50, 100]$ at rates $[0, 64, 127]$).
    - Mode and Time Div knobs use safe unreserved CCs (102/105 and 103/106).
  - Ran `bun test`: All 32 tests passed across 8 test suites.
- **Hammerspoon Runtime Verification:**
  - `hs -c "return hs.json.encode(_G.activeWatchers.keystep.getFullState())"`:
    `{"shift":false,"hold":false,"playing":false,"connected":true,"seqArp":"seq","rate":77,"octave":0,"mode":1,"divCc":106,"deviceName":"Arturia KeyStep 32","division":"1\/16","bpm":157,"modeName":"Seq 1","rateCc":17,"modWheel":0,"divIdx":3,"recording":false,"pitchBend":8192,"modeCc":105}`
  - Verified `rateToVolumeCc`: $\{ \text{min}=0, \text{mid}=50, \text{max}=100 \}$.
  - Verified `handleGuiAction('rate', { rate = 127 })`: sets `topRowVolume = 100` ($0\text{ dB}$ unity gain).
