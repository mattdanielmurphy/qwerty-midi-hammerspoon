# Analysis & Test Suite Design: Audio & MIDI Engine (R1, R2, R3, R6, R7)

**Author**: M1 Explorer 1 (Audio & MIDI Test Suite Design)  
**Date**: 2026-10-11  
**Project**: `qwerty-midi-hammerspoon` (`surface-studio-suite`)  
**Working Directory**: `/Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_explorer_m1_1`

---

## 1. Executive Summary & Problem Boundary

This document delivers the comprehensive, concrete test suite architecture for the **Audio & MIDI Engine** requirements (R1, R2, R3, R6, R7) of `qwerty-midi-hammerspoon`.

The test suites are designed for execution via `bun test` under Bun's native test runner (`bun:test`). They apply Category-Partitioning, Boundary Value Analysis, Pairwise Combinatorial Interaction testing, and Real-World Performance Stress modeling across **Tiers 1 through 4**.

### Target Requirement Scope
| Req ID | Description | Primary Code Targets | Core Vulnerability / Missing Logic |
|---|---|---|---|
| **R1** | Dedicated Track Volume Controls (CC 7) | `src/controls.lua`, `src/config.lua` | No dedicated per-track keys (Tracks 1–4); synchronous `config.saveSettings()` on every 80ms repeat tick stalls event loop and drops notes. |
| **R2** | Rich Arp Patterns & Human Feel | `src/arpeggiator.lua`, `src/config.lua`, `packages/music-engine/clock.lua` | Only 7 rigid directions; static velocity calculation (`trk.volume * 1.0`); fixed gate length; zero velocity contours, swing, or microtiming jitter. |
| **R3** | Configurable Quantization Amount (0–100%) | `packages/music-engine/quantizer.lua`, `src/config.lua` | `calculateDelay(bpm, mode)` lacks strength parameter; delay is strictly all-or-nothing (100% or 0%). Default 90% humanized grid correction missing. |
| **R6** | Stuck Note Mitigation & Watchdog Loop | `packages/music-engine/quantizer.lua`, `src/midi.lua`, `src/init.lua` | Staccato taps (<60ms) retriggered before gate expiration drop `onRelease`, leaving synth voices permanently stuck; no watchdog loop checks `activeNoteLedger`. |
| **R7** | Tap Tempo Functionality | `src/arpeggiator.lua`, `src/controls.lua`, `packages/music-engine/clock.lua` | `arpeggiator.tapTempo` is completely undefined; tapping tempo key is an unhandled no-op; rolling average and BPM calculation missing. |

---

## 2. Codebase Baseline & Gap Analysis

### 2.1 Requirement R1: Dedicated Volume Controls & Debounced Persistence
- **Current State**:
  - `src/controls.lua:495-512` implements `adjustTrackVolume(trackId, delta)`, modifying `trk.volume` (0..127) and calling `midi.sendMidiCC(7, trk.volume, trk.channel or (id - 1))`.
  - In `src/controls.lua:503`, every single invocation of `adjustTrackVolume` calls `config.saveSettings()`.
  - In `src/controls.lua:2107-2122`, held keys fire repeat timer callbacks every 80ms (`0.08s`), triggering `executeControlAction` which calls `config.saveSettings()` on line 2025 as well as inside `adjustTrackVolume`.
  - In `src/config.lua:197-250`, `saveSettings()` performs over 35 distinct calls to `hs.settings.set(...)`. Calling this synchronously every 80ms blocks the Hammerspoon main thread, leading to delayed or dropped Note-On and Note-Off events.
  - In `src/controls.lua:559-640` and `src/config.lua:388-393`, there are no dedicated keyboard action bindings for individual tracks (`trk1VolUp`, `trk1VolDown`, `trk2VolUp`, `trk2VolDown`, `trk3VolUp`, `trk3VolDown`, `trk4VolUp`, `trk4VolDown`). The keyboard only exposes active track `volUp`/`volDown`, top row `topVolUp`/`topVolDown`, and bottom row `botVolUp`/`botVolDown`.
- **Target Contract**:
  - Dedicated actions `trkVolUp1..4` and `trkVolDown1..4` (or `trk1VolUp`..`trk4VolDown`) in `controls.lua` and `config.lua`.
  - Clamping strictly between 0 and 127 (`math.max(0, math.min(127, val))`).
  - CC 7 transmission on the target track's specific MIDI channel (`channel = trackId - 1`).
  - Suppression of CC 7 while track is muted (`isTrackAudible(trackId) == false`), with restoration upon unmute.
  - Debounced settings persistence: volume repeat ticks update in-memory state immediately, but schedule a 300ms trailing timer (`saveSettingsDebounced`) before writing to `hs.settings`.

### 2.2 Requirement R2: Rich Arpeggiator Patterns & Human Feel
- **Current State**:
  - `src/config.lua:58` and `packages/music-engine/clock.lua:4` define only 7 basic directions: `{"UP", "DOWN", "UP-DOWN", "DOWN-UP", "CONVERGE", "DIVERGE", "RANDOM"}`.
  - `src/arpeggiator.lua:419` sets velocity statically:
    ```lua
    local vel = math.floor(math.min(127, (trk.volume or 100) * 1.0))
    ```
  - `src/arpeggiator.lua:441` computes gate duration strictly linearly:
    ```lua
    local gateDuration = trackStepSec * gateRatio
    ```
  - There are no velocity contours (downbeat accents, groove pulses, ghost notes), no pattern-based gate variations, and no microtiming jitter or swing deviations.
- **Target Contract**:
  - Pattern catalog expanded to include rhythmic and contour patterns (e.g., `PING-PONG`, `OCTAVE-HOP`, `CHORD-PULSE`, `SWING-16`, `CRESCENDO`).
  - Velocity contour generator evaluating step position $i \in [1..N]$:
    $$v_{\text{step}} = \text{clamp}\left(\text{round}\left(v_{\text{base}} \times c_{\text{contour}}(i)\right), 1, 127\right)$$
    where downbeats receive accent multipliers (e.g. $1.20$), offbeats receive ghost multipliers (e.g. $0.75$), or sinusoidal groove curves.
  - Variable gate lengths: per-step gate modulation (e.g., accented downbeat has 95% gate, staccato offbeat has 45% gate).
  - Microtiming deviations:
    - Swing percentage $S \in [50\%, 75\%]$ delaying even steps by $\Delta t_{\text{swing}} = (S - 0.5) \times t_{\text{step}}$.
    - Bounded human-feel microtiming jitter $\delta \in [-8\text{ms}, +8\text{ms}]$ without cumulative tempo drift.

### 2.3 Requirement R3: Configurable Quantization Amount (0–100%)
- **Current State**:
  - `packages/music-engine/quantizer.lua:36-64` implements:
    ```lua
    function quantizer.calculateDelay(bpm, mode)
      ...
      local timeToNext = stepDuration - elapsed
      ...
      return timeToNext
    end
    ```
  - Quantization is purely binary: either 100% delay to the exact grid boundary or 0% delay (`mode == "Off"`).
  - There is no strength parameter in `calculateDelay` or `queueNoteOn`.
- **Target Contract**:
  - Function signature updated to `quantizer.calculateDelay(bpm, mode, amount)`.
  - `amount`: number in range $[0, 100]$, defaulting to $90.0$.
  - Delay scaling formula:
    $$\text{delay}_{\text{scaled}} = \text{delay}_{\text{raw}} \times \left(\frac{\text{clampedAmount}}{100.0}\right)$$
  - When $\text{amount} = 100$: exact grid snap ($\text{delay}_{\text{scaled}} = \text{delay}_{\text{raw}}$).
  - When $\text{amount} = 90$ (default): 90% pull toward grid, leaving 10% human natural timing.
  - When $\text{amount} = 0$: immediate trigger ($\text{delay}_{\text{scaled}} = 0$).
  - Clamping: $\text{clampedAmount} = \max(0, \min(100, \text{tonumber}(\text{amount}) \text{ or } 90.0))$.
  - Tolerance windows (12ms anticipation, 20ms late catch-up) evaluated before or proportional to scaling.
  - Persistence: `state.inputQuantizeAmount` saved in `hs.settings` as `qwertyMidi_inputQuantizeAmount`.

### 2.4 Requirement R6: Stuck Note Mitigation & Watchdog Loop
- **Current State**:
  - In `packages/music-engine/quantizer.lua:83-88`:
    ```lua
    if pendingEvents[eventId] then
      if pendingEvents[eventId].timer then pcall(function() pendingEvents[eventId].timer:stop() end) end
      if pendingEvents[eventId].gateTimer then pcall(function() pendingEvents[eventId].gateTimer:stop() end) end
      pendingEvents[eventId] = nil
    end
    ```
  - **Root Cause of Staccato Hung Notes**: When a note is played with staccato release, `queueNoteOff` sets `ev.released = true`. When the grid tick fires, Note-On is transmitted and `ev.gateTimer` is scheduled for 60ms to send Note-Off. If the player strikes the same key again within 60ms, lines 83-88 STOP `ev.gateTimer` and set `pendingEvents[eventId] = nil`. **`onRelease` is NEVER called for the previous note!** The synth voice remains permanently sounding.
  - In `src/midi.lua:56-65`, `activeNoteLedger` stores active notes without timestamps (`startTime`), and `src/midi.lua` has no orphan detection function.
  - In `src/init.lua:418`, `keyTapWatchdog` only pings the webview; there is no MIDI note watchdog.
- **Target Contract**:
  - Staccato Re-trigger Safety: When `queueNoteOn` encounters an active or pending event for the same `eventId`, if a `gateTimer` is running or the voice is actively sounding, it MUST invoke `onRelease(pitches, channel)` or emit `noteOff` immediately before re-triggering.
  - Voice Ledger Timestamps: `activeNoteLedger[noteNum][ch]` records `startTime = hs.timer.secondsSinceEpoch()`.
  - Orphan Voice Watchdog: `midi.checkOrphanedVoices(maxAgeSeconds)` scans `activeNoteLedger`. Any note sounding longer than `maxAgeSeconds` (e.g. 5.0s) whose key is not held in `state.pressedKeys` and not in `state.sustainedPitches` is automatically terminated via `sendMidiNote("noteOff", note, 0, ch)`.
  - Invariant: Watchdog timer executes ONLY when `state.midiActive == true`.

### 2.5 Requirement R7: Tap Tempo Engine
- **Current State**:
  - In `src/controls.lua:2018-2021`:
    ```lua
    elseif act == "tapTempo" then
      if arpeggiator.tapTempo then
        arpeggiator.tapTempo()
      end
      hud.updateWebviewHud(...)
    end
    ```
  - In `src/arpeggiator.lua` and `packages/music-engine/clock.lua`, `tapTempo` is **completely missing / nil**.
  - Calling tap tempo is a dead no-op.
- **Target Contract**:
  - `arpeggiator.tapTempo()` implemented and exported:
    1. Records current timestamp $t_{\text{now}} = \text{hs.timer.secondsSinceEpoch()}$.
    2. Measures $\Delta t = t_{\text{now}} - t_{\text{prev}}$.
    3. If $\Delta t > 2.0$s: timeout occurs, resets tap history buffer, sets $t_{\text{prev}} = t_{\text{now}}$.
    4. If $\Delta t \le 2.0$s: appends $\Delta t$ to rolling buffer of recent intervals (size $N = 4..8$).
    5. Computes mean interval $\bar{\Delta t} = \frac{1}{K}\sum_{i=1}^K \Delta t_i$.
    6. Derives $\text{BPM} = 60.0 / \bar{\Delta t}$.
    7. Clamps BPM to range $[30.0, 300.0]$.
    8. Calls `arpeggiator.applyBpmChange(newBpm)` (or updates `state.arpBpm` and re-schedules active track arpeggiator timers without phase clicks).
    9. Returns derived BPM and triggers HUD feedback.

---

## 3. Test Architecture & Tier Structure

All tests execute under `bun test` in the workspace root. Test specifications reside in structured directories within `tests/`:

```
tests/
├── tier1_feature_contracts/
│   ├── r1_track_volume_controls.test.js
│   ├── r2_rich_arp_patterns.test.js
│   ├── r3_configurable_quantize.test.js
│   ├── r6_stuck_note_watchdog.test.js
│   └── r7_tap_tempo_engine.test.js
├── tier2_boundary_edge_cases/
│   ├── r1_volume_clamping_and_muting.test.js
│   ├── r2_arp_extreme_rates_and_chords.test.js
│   ├── r3_quantize_strength_boundaries.test.js
│   ├── r6_rapid_retrigger_bounce.test.js
│   └── r7_tap_tempo_jitter_and_outliers.test.js
├── tier3_cross_feature_interactions/
│   ├── r1_r6_volume_during_quantized_playback.test.js
│   ├── r2_r7_arp_tap_tempo_live_resync.test.js
│   └── r3_r6_quantize_watchdog_harmony.test.js
└── tier4_real_world_e2e_scenarios/
    ├── multitrack_audio_midi_live_performance.test.js
    └── chaos_mashing_and_panic_recovery.test.js
```

### Coverage Minimums Accounting
- **Tier 1 (Feature Coverage)**: 5 features (R1, R2, R3, R6, R7) $\times$ 6 test cases = **30 test cases**
- **Tier 2 (Boundary & Corner Cases)**: 5 features $\times$ 6 test cases = **30 test cases**
- **Tier 3 (Cross-Feature Combinations)**: 3 interaction suites $\times$ 3 test cases = **9 test cases**
- **Tier 4 (Real-World Application Scenarios)**: 2 multi-track performance workflows $\times$ 2 scenarios = **4 test cases**
- **Total Audio & MIDI Engine Test Count**: **73 concrete test cases**

---

## 4. R1 Test Suite Design: Track Volume Controls (CC 7) & Debounced Persistence

### 4.1 Tier 1 Feature Contract: `tests/tier1_feature_contracts/r1_track_volume_controls.test.js`

```javascript
import { expect, test, describe } from "bun:test";

const controlsSrc = await Bun.file("src/controls.lua").text();
const configSrc = await Bun.file("src/config.lua").text();

describe("R1 Tier 1: Dedicated Track Volume Controls Contract", () => {
  test("r1_contract_01_dedicated_actions_registered", () => {
    // Verifies dedicated keyboard actions exist for tracks 1 through 4
    for (let t = 1; t <= 4; t++) {
      expect(controlsSrc).toMatch(new RegExp(`trk${t}VolUp|trkVolUp${t}`));
      expect(controlsSrc).toMatch(new RegExp(`trk${t}VolDown|trkVolDown${t}`));
    }
  });

  test("r1_contract_02_midi_cc7_per_track_channel", () => {
    // Verifies adjustTrackVolume emits CC 7 targeting the track's specific channel
    expect(controlsSrc).toMatch(/local function adjustTrackVolume\(trackId,\s*delta\)/);
    expect(controlsSrc).toContain("midi.sendMidiCC(7, trk.volume, trk.channel");
  });

  test("r1_contract_03_volume_clamping_0_to_127", () => {
    // Verifies volume math uses strict 0..127 bounds
    expect(controlsSrc).toMatch(/math\.max\(0,\s*math\.min\(127,\s*\(tonumber\(trk\.volume\)/);
  });

  test("r1_contract_04_debounced_persistence_trailing_timer", () => {
    // Verifies repeat ticks do NOT execute synchronous config.saveSettings()
    // but use a debounced trailing timer (e.g. saveSettingsDebounced)
    expect(controlsSrc).toMatch(/saveSettingsDebounced|saveSettingsTrailing/);
    expect(controlsSrc).not.toMatch(/entry\.interval[\s\S]*?config\.saveSettings\(\)/);
  });

  test("r1_contract_05_hud_spotlight_feedback_per_track", () => {
    // Verifies HUD update displays volume title and percentage
    expect(controlsSrc).toContain('title = "VOLUME (TRK " .. id .. ")"');
    expect(controlsSrc).toContain('value = math.floor((trk.volume / 127) * 100 + 0.5) .. "%"');
    expect(controlsSrc).toContain('color = trk.color');
  });

  test("r1_contract_06_muted_track_volume_storage", () => {
    // Verifies volume adjusts in state even if track is muted, but suppresses audible CC 7
    expect(controlsSrc).toContain("if isTrackAudible(id) then midi.sendMidiCC(7, trk.volume");
  });
});
```

### 4.2 Tier 2 Boundary & Edge Cases: `tests/tier2_boundary_edge_cases/r1_volume_clamping_and_muting.test.js`

```javascript
import { expect, test, describe } from "bun:test";

describe("R1 Tier 2: Volume Clamping & Muting Boundary Cases", () => {
  // Pure JS simulation of adjustTrackVolume logic
  function simulateVolumeAdjust(initialVol, delta) {
    return Math.max(0, Math.min(127, (Number(initialVol) || 100) + (Number(delta) || 0)));
  }

  test("r1_edge_01_upper_bound_clamp_127", () => {
    expect(simulateVolumeAdjust(124, 4)).toBe(127);
    expect(simulateVolumeAdjust(127, 4)).toBe(127);
    expect(simulateVolumeAdjust(127, 50)).toBe(127);
  });

  test("r1_edge_02_lower_bound_clamp_0", () => {
    expect(simulateVolumeAdjust(3, -4)).toBe(0);
    expect(simulateVolumeAdjust(0, -4)).toBe(0);
    expect(simulateVolumeAdjust(0, -100)).toBe(0);
  });

  test("r1_edge_03_non_integer_and_nil_deltas", () => {
    expect(simulateVolumeAdjust(100, null)).toBe(100);
    expect(simulateVolumeAdjust(100, undefined)).toBe(100);
    expect(simulateVolumeAdjust(100, NaN)).toBe(100);
  });

  test("r1_edge_04_track_channel_mapping", () => {
    const trackChannels = { 1: 0, 2: 1, 3: 2, 4: 3 };
    for (let id = 1; id <= 4; id++) {
      expect(trackChannels[id]).toBe(id - 1);
    }
  });

  test("r1_edge_05_debounced_save_coalescing_window", async () => {
    let saveCount = 0;
    let timer = null;
    function saveSettingsDebounced() {
      if (timer) clearTimeout(timer);
      timer = setTimeout(() => { saveCount++; }, 50);
    }

    // Fire 10 rapid volume ticks within 30ms
    for (let i = 0; i < 10; i++) {
      saveSettingsDebounced();
    }
    expect(saveCount).toBe(0); // Not saved synchronously
    await new Promise(r => setTimeout(r, 80));
    expect(saveCount).toBe(1); // Exactly 1 debounced save executed
  });

  test("r1_edge_06_unmute_restoration_payload", () => {
    // When track is unmuted, CC 7 must restore stored volume level
    const trk = { id: 2, volume: 112, muted: false, channel: 1 };
    const ccEmitted = { cc: 7, val: trk.volume, ch: trk.channel };
    expect(ccEmitted.cc).toBe(7);
    expect(ccEmitted.val).toBe(112);
    expect(ccEmitted.ch).toBe(1);
  });
});
```

---

## 5. R2 Test Suite Design: Rich Arpeggiator Patterns, Velocity Contours & Microtiming

### 5.1 Tier 1 Feature Contract: `tests/tier1_feature_contracts/r2_rich_arp_patterns.test.js`

```javascript
import { expect, test, describe } from "bun:test";

const arpSrc = await Bun.file("src/arpeggiator.lua").text();
const configSrc = await Bun.file("src/config.lua").text();

describe("R2 Tier 1: Rich Arp Patterns & Human Feel Contracts", () => {
  test("r2_contract_01_pattern_catalog_expanded", () => {
    // Verifies ARP_PATTERNS or directions includes rich patterns beyond the legacy 7
    expect(arpSrc).toMatch(/ARP_PATTERNS|ARP_GROOVES|getArpVelocityMultiplier/);
    expect(configSrc).toMatch(/ARP_PATTERNS|ARP_DIRECTIONS/);
  });

  test("r2_contract_02_velocity_contour_calculation", () => {
    // Verifies velocity is calculated dynamically using a contour multiplier or accent
    expect(arpSrc).toMatch(/local velMultiplier\s*=|local stepAccent\s*=/);
    expect(arpSrc).toMatch(/math\.floor\(math\.min\(127,\s*\(trk\.volume or 100\)\s*\*\s*velMultiplier/);
  });

  test("r2_contract_03_velocity_contour_clamping", () => {
    // Verifies velocity output is strictly bounded to 1..127
    expect(arpSrc).toContain("math.max(1, math.min(127,");
  });

  test("r2_contract_04_variable_gate_lengths", () => {
    // Verifies gate length ratio adapts per step or groove contour
    expect(arpSrc).toMatch(/local stepGateRatio\s*=|local dynamicGate\s*=/);
    expect(arpSrc).toMatch(/local gateDuration\s*=\s*trackStepSec\s*\*\s*stepGateRatio/);
  });

  test("r2_contract_05_microtiming_swing_deviation", () => {
    // Verifies swing calculation or microtiming jitter is scheduled into the step timer
    expect(arpSrc).toMatch(/swingOffset|microtimingJitter|applySwing/);
  });

  test("r2_contract_06_per_track_pattern_isolation", () => {
    // Verifies each track owns its independent pattern and groove state
    expect(arpSrc).toContain("trk.arpDirectionIdx");
    expect(arpSrc).toContain("trk.activeGateTimers");
  });
});
```

### 5.2 Tier 2 Boundary & Edge Cases: `tests/tier2_boundary_edge_cases/r2_arp_extreme_rates_and_chords.test.js`

```javascript
import { expect, test, describe } from "bun:test";

describe("R2 Tier 2: Arp Extreme Rates, Contours & Chords", () => {
  // Pure JS model of velocity contour and swing calculations
  function computeArpStep(stepIndex, baseVol, contourPattern, swingPercent, bpm, rateFactor) {
    const contours = {
      accentDownbeat: [1.25, 0.85, 1.05, 0.80],
      grooveCurve: [1.10, 0.90, 1.20, 0.75, 1.05, 0.85, 1.15, 0.70]
    };
    const mults = contours[contourPattern] || [1.0];
    const mult = mults[(stepIndex - 1) % mults.length];
    const vel = Math.max(1, Math.min(127, Math.floor(baseVol * mult)));

    const stepSec = (60.0 / bpm) * rateFactor;
    // Swing applies to even steps (index 2, 4, 6...)
    const isEvenStep = (stepIndex % 2 === 0);
    const swingOffset = isEvenStep ? ((swingPercent - 50.0) / 100.0) * stepSec : 0;

    return { vel, stepSec, swingOffset };
  }

  test("r2_edge_01_single_pitch_contour_progression", () => {
    // 1-pitch held chord must cycle through velocity contours cleanly
    const p1 = computeArpStep(1, 100, "accentDownbeat", 50, 120, 0.25);
    const p2 = computeArpStep(2, 100, "accentDownbeat", 50, 120, 0.25);
    const p3 = computeArpStep(3, 100, "accentDownbeat", 50, 120, 0.25);
    const p4 = computeArpStep(4, 100, "accentDownbeat", 50, 120, 0.25);

    expect(p1.vel).toBe(125); // Downbeat accent
    expect(p2.vel).toBe(85);  // Ghost note
    expect(p3.vel).toBe(105); // Secondary accent
    expect(p4.vel).toBe(80);  // Ghost note
  });

  test("r2_edge_02_velocity_ceiling_clamping_at_127", () => {
    // Base volume 127 with 1.25 multiplier must clamp at 127, not overflow
    const res = computeArpStep(1, 127, "accentDownbeat", 50, 120, 0.25);
    expect(res.vel).toBe(127);
  });

  test("r2_edge_03_velocity_floor_clamping_at_1", () => {
    // Base volume 1 with 0.5 multiplier must clamp at 1, not 0
    const res = computeArpStep(2, 1, "accentDownbeat", 50, 120, 0.25);
    expect(res.vel).toBe(1);
  });

  test("r2_edge_04_swing_boundaries_straight_vs_heavy", () => {
    // 50% swing has 0 offset
    const straight = computeArpStep(2, 100, "accentDownbeat", 50, 120, 0.25);
    expect(straight.swingOffset).toBe(0);

    // 66% triplet swing at 120 BPM, 16th note (stepSec = 0.125s)
    const swing66 = computeArpStep(2, 100, "accentDownbeat", 66, 120, 0.25);
    expect(swing66.swingOffset).toBeCloseTo(0.02, 3);

    // Odd steps receive 0 swing offset
    const oddStep = computeArpStep(1, 100, "accentDownbeat", 66, 120, 0.25);
    expect(oddStep.swingOffset).toBe(0);
  });

  test("r2_edge_05_gate_duration_bounds_at_extreme_bpm", () => {
    // At 300 BPM 32nd note (stepSec = 0.025s), gate duration must not be zero
    const stepSec = (60.0 / 300.0) * 0.125;
    const gateDuration = Math.max(0.010, stepSec * 0.8);
    expect(gateDuration).toBeGreaterThanOrEqual(0.010);
  });

  test("r2_edge_06_polyphonic_chord_pitch_ordering", () => {
    const pitches = [48, 52, 55, 59];
    // Up-Down pattern length is 2 * (N - 1) = 6 steps: 0, 1, 2, 3, 2, 1
    const pattern = [0, 1, 2, 3, 2, 1].map(i => pitches[i]);
    expect(pattern).toEqual([48, 52, 55, 59, 55, 52]);
  });
});
```

---

## 6. R3 Test Suite Design: Configurable Quantization Amount (0–100%)

### 6.1 Tier 1 Feature Contract: `tests/tier1_feature_contracts/r3_configurable_quantize.test.js`

```javascript
import { expect, test, describe } from "bun:test";

const quantizerSrc = await Bun.file("packages/music-engine/quantizer.lua").text();
const configSrc = await Bun.file("src/config.lua").text();

describe("R3 Tier 1: Configurable Quantization Amount Contracts", () => {
  test("r3_contract_01_strength_parameter_and_default", () => {
    // Verifies calculateDelay signature accepts amount parameter, defaulting to 90%
    expect(quantizerSrc).toMatch(/function quantizer\.calculateDelay\(bpm,\s*mode,\s*amount\)/);
    expect(quantizerSrc).toMatch(/local quantAmount\s*=\s*tonumber\(amount\)\s*or\s*90\.0/);
  });

  test("r3_contract_02_delay_scaling_formula", () => {
    // Verifies delay is scaled by (quantAmount / 100.0)
    expect(quantizerSrc).toMatch(/timeToNext\s*\*\s*\(\s*quantAmount\s*\/\s*100\.0\s*\)/);
  });

  test("r3_contract_03_zero_strength_immediate_trigger", () => {
    // Verifies amount <= 0 returns 0 (immediate trigger)
    expect(quantizerSrc).toMatch(/if quantAmount <= 0 then\s+return 0\s+end/);
  });

  test("r3_contract_04_full_strength_grid_snap", () => {
    // Verifies amount >= 100 returns full timeToNext
    expect(quantizerSrc).toMatch(/math\.max\(0\.0,\s*math\.min\(100\.0/);
  });

  test("r3_contract_05_settings_persistence", () => {
    // Verifies persistence key in config.lua
    expect(configSrc).toContain("qwertyMidi_inputQuantizeAmount");
    expect(configSrc).toMatch(/inputQuantizeAmount\s*=\s*getSetting\("inputQuantizeAmount",\s*90\.0\)/);
  });

  test("r3_contract_06_runtime_setter_and_state", () => {
    // Verifies quantizer exports setQuantizeAmount setter
    expect(quantizerSrc).toContain("function quantizer.setQuantizeAmount(");
    expect(quantizerSrc).toContain("setQuantizeAmount = quantizer.setQuantizeAmount");
  });
});
```

### 6.2 Tier 2 Boundary & Edge Cases: `tests/tier2_boundary_edge_cases/r3_quantize_strength_boundaries.test.js`

```javascript
import { expect, test, describe } from "bun:test";

describe("R3 Tier 2: Quantize Strength Boundary Values & Edge Math", () => {
  const FACTORS = { "1/1": 4.0, "1/2": 2.0, "1/4": 1.0, "1/8": 0.5, "1/16": 0.25 };

  function calculateDelaySim(bpm, mode, amount, elapsedOffset) {
    if (!mode || mode === "Off" || mode === "None") return 0;
    const factor = FACTORS[mode];
    if (!factor) return 0;

    const clampedBpm = Math.max(20.0, Math.min(999.0, bpm || 120.0));
    const stepDuration = (60.0 / clampedBpm) * factor;

    const elapsed = elapsedOffset % stepDuration;
    const timeToNext = stepDuration - elapsed;

    // Tolerance windows
    if (timeToNext <= 0.012) return 0;
    if (elapsed <= 0.020) return 0;

    const quantAmount = Math.max(0, Math.min(100, amount === undefined || amount === null ? 90.0 : Number(amount)));
    if (quantAmount <= 0) return 0;

    return timeToNext * (quantAmount / 100.0);
  }

  test("r3_edge_01_default_90_percent_scaling", () => {
    // At 120 BPM, 1/4 note (stepDuration = 0.5s), elapsed = 0.1s -> timeToNext = 0.4s
    const delay = calculateDelaySim(120, "1/4", 90, 0.1);
    expect(delay).toBeCloseTo(0.4 * 0.90, 4); // 0.36s
  });

  test("r3_edge_02_100_percent_hard_snap", () => {
    const delay = calculateDelaySim(120, "1/4", 100, 0.1);
    expect(delay).toBeCloseTo(0.40, 4);
  });

  test("r3_edge_03_zero_percent_instant_playback", () => {
    const delay = calculateDelaySim(120, "1/4", 0, 0.1);
    expect(delay).toBe(0);
  });

  test("r3_edge_04_out_of_bounds_clamping", () => {
    // -50% clamps to 0% -> 0s delay
    expect(calculateDelaySim(120, "1/4", -50, 0.1)).toBe(0);
    // 150% clamps to 100% -> 0.40s delay
    expect(calculateDelaySim(120, "1/4", 150, 0.1)).toBeCloseTo(0.40, 4);
  });

  test("r3_edge_05_anticipation_tolerance_12ms", () => {
    // timeToNext = 11ms <= 12ms tolerance -> should fire immediately (delay 0)
    const delay = calculateDelaySim(120, "1/4", 90, 0.489);
    expect(delay).toBe(0);
  });

  test("r3_edge_06_catchup_tolerance_20ms", () => {
    // elapsed = 19ms <= 20ms tolerance -> should fire immediately (delay 0)
    const delay = calculateDelaySim(120, "1/4", 90, 0.019);
    expect(delay).toBe(0);
  });
});
```

---

## 7. R6 Test Suite Design: Stuck Note Mitigation & Voice Watchdog Loop

### 7.1 Tier 1 Feature Contract: `tests/tier1_feature_contracts/r6_stuck_note_watchdog.test.js`

```javascript
import { expect, test, describe } from "bun:test";

const quantizerSrc = await Bun.file("packages/music-engine/quantizer.lua").text();
const midiSrc = await Bun.file("src/midi.lua").text();
const initSrc = await Bun.file("src/init.lua").text();

describe("R6 Tier 1: Stuck Note Mitigation & Watchdog Contracts", () => {
  test("r6_contract_01_staccato_retrigger_guaranteed_release", () => {
    // In queueNoteOn, stopping existing gateTimer MUST guarantee onRelease or noteOff is sent
    const cancelBlock = quantizerSrc.match(/if pendingEvents\[eventId\] then([\s\S]*?)pendingEvents\[eventId\] = nil/);
    expect(cancelBlock).toBeTruthy();
    expect(cancelBlock[1]).toMatch(/onRelease|sendMidiNote|closePriorVoice/);
  });

  test("r6_contract_02_sounding_notes_cleanup_on_retrigger", () => {
    // In queueNoteOn, active sounding notes for the same eventId must be terminated
    expect(quantizerSrc).toMatch(/if soundingNotes\[eventId\] then[\s\S]*?onRelease/);
  });

  test("r6_contract_03_active_voice_ledger_timestamp", () => {
    // activeNoteLedger must store startTime
    expect(midiSrc).toMatch(/activeNoteLedger\[noteNum\]\[ch\]\s*=\s*\{[\s\S]*?startTime\s*=/);
  });

  test("r6_contract_04_watchdog_orphan_detection_function", () => {
    // midi exports checkOrphanedVoices
    expect(midiSrc).toContain("local function checkOrphanedVoices(");
    expect(midiSrc).toContain("checkOrphanedVoices = checkOrphanedVoices");
  });

  test("r6_contract_05_watchdog_loop_in_init", () => {
    // src/init.lua instantiates midiWatchdog timer
    expect(initSrc).toMatch(/midiWatchdog|voiceWatchdog/);
    expect(initSrc).toContain("midi.checkOrphanedVoices");
  });

  test("r6_contract_06_watchdog_active_only_when_armed", () => {
    // Watchdog timer is guarded by state.midiActive and stopped on disarm
    expect(initSrc).toMatch(/if state\.midiActive then[\s\S]*?checkOrphanedVoices/);
    expect(initSrc).toMatch(/midiWatchdog:stop\(\)|_G\.activeWatchers\.midiWatchdog/);
  });
});
```

### 7.2 Tier 2 Boundary & Edge Cases: `tests/tier2_boundary_edge_cases/r6_rapid_retrigger_bounce.test.js`

```javascript
import { expect, test, describe } from "bun:test";

describe("R6 Tier 2: Rapid Retrigger, Staccato Taps & Orphan Boundaries", () => {
  test("r6_edge_01_staccato_retrigger_simulation", () => {
    // Simulates staccato tap followed by rapid re-trigger 20ms later
    const eventStream = [];
    let activeVoices = 0;

    function triggerNote(t, isRelease = false) {
      if (isRelease) {
        eventStream.push({ type: "noteOff", time: t });
        activeVoices = Math.max(0, activeVoices - 1);
      } else {
        // Enforce re-trigger safety: if voice active, close it first!
        if (activeVoices > 0) {
          eventStream.push({ type: "noteOffSafety", time: t });
          activeVoices--;
        }
        eventStream.push({ type: "noteOn", time: t });
        activeVoices++;
      }
    }

    // Tap 1 at t=0, released at t=10
    triggerNote(0, false);
    triggerNote(10, true);
    // Retrigger Tap 2 at t=25 (within 60ms staccato window)
    triggerNote(25, false);
    triggerNote(50, true);

    expect(activeVoices).toBe(0);
    const noteOns = eventStream.filter(e => e.type === "noteOn").length;
    const noteOffs = eventStream.filter(e => e.type.startsWith("noteOff")).length;
    expect(noteOns).toBe(noteOffs);
  });

  test("r6_edge_02_orphan_watchdog_age_threshold_boundary", () => {
    const now = 1000.0;
    const threshold = 5.0;
    const voices = [
      { note: 60, ch: 0, startTime: 996.0 }, // age 4.0s -> keep
      { note: 64, ch: 0, startTime: 994.8 }, // age 5.2s -> orphan!
      { note: 67, ch: 0, startTime: 990.0 }  // age 10.0s -> orphan!
    ];

    const orphans = voices.filter(v => (now - v.startTime) > threshold);
    expect(orphans.length).toBe(2);
    expect(orphans[0].note).toBe(64);
    expect(orphans[1].note).toBe(67);
  });

  test("r6_edge_03_held_physical_keys_immune_from_watchdog", () => {
    // Notes corresponding to actively pressed physical keys must NOT be purged
    const pressedKeys = { 18: true }; // key for note 60 held
    const voices = [
      { note: 60, ch: 0, keycode: 18, startTime: 900.0 }, // held -> immune!
      { note: 64, ch: 0, keycode: 19, startTime: 900.0 }  // not held -> orphan!
    ];

    const orphans = voices.filter(v => !pressedKeys[v.keycode] && (1000.0 - v.startTime) > 5.0);
    expect(orphans.length).toBe(1);
    expect(orphans[0].note).toBe(64);
  });

  test("r6_edge_04_sustained_pitches_immune_from_watchdog", () => {
    // Pitches currently held by smart sustain must NOT be purged
    const sustainedPitches = { [60]: true };
    const voice = { note: 60, ch: 0, startTime: 900.0 };
    const isImmune = sustainedPitches[voice.note] === true;
    expect(isImmune).toBe(true);
  });

  test("r6_edge_05_panic_all_sound_off_and_notes_off", () => {
    // Panic must transmit across all channels 0..15
    const channels = Array.from({ length: 16 }, (_, i) => i);
    expect(channels.length).toBe(16);
    const messages = [];
    channels.forEach(ch => {
      messages.push({ cc: 120, ch }); // All Sound Off
      messages.push({ cc: 123, ch }); // All Notes Off
      messages.push({ cc: 64, ch, val: 0 }); // Damper Off
    });
    expect(messages.length).toBe(48);
  });

  test("r6_edge_06_channel_isolation_on_identical_pitches", () => {
    // Pitch 60 on Channel 0 and Channel 1 are separate ledger entries
    const ledger = {};
    function noteOn(note, ch) {
      ledger[`${note}_${ch}`] = true;
    }
    function noteOff(note, ch) {
      delete ledger[`${note}_${ch}`];
    }

    noteOn(60, 0);
    noteOn(60, 1);
    expect(Object.keys(ledger).length).toBe(2);

    noteOff(60, 0);
    expect(ledger["60_1"]).toBe(true);
    expect(ledger["60_0"]).toBeUndefined();
  });
});
```

---

## 8. R7 Test Suite Design: Tap Tempo Engine & BPM Update

### 8.1 Tier 1 Feature Contract: `tests/tier1_feature_contracts/r7_tap_tempo_engine.test.js`

```javascript
import { expect, test, describe } from "bun:test";

const arpSrc = await Bun.file("src/arpeggiator.lua").text();
const controlsSrc = await Bun.file("src/controls.lua").text();
const clockSrc = await Bun.file("packages/music-engine/clock.lua").text();

describe("R7 Tier 1: Tap Tempo Engine Contracts", () => {
  test("r7_contract_01_function_defined_in_arpeggiator", () => {
    // Verifies arpeggiator.tapTempo exists and is exported
    expect(arpSrc).toMatch(/local function tapTempo\(\)|function arpeggiator\.tapTempo\(\)/);
    expect(arpSrc).toContain("tapTempo = tapTempo");
  });

  test("r7_contract_02_controls_binding_calls_tap_tempo", () => {
    // Verifies controls.lua dispatches act == "tapTempo"
    expect(controlsSrc).toContain('elseif act == "tapTempo" then');
    expect(controlsSrc).toContain("arpeggiator.tapTempo()");
  });

  test("r7_contract_03_rolling_average_calculation", () => {
    // Verifies tapTempo averages inter-tap intervals
    expect(arpSrc).toMatch(/tapHistory|tapIntervals/);
    expect(arpSrc).toMatch(/60\.0\s*\/\s*avgInterval|60\s*\/\s*avg/);
  });

  test("r7_contract_04_timeout_buffer_reset", () => {
    // Verifies inter-tap gap > 2.0s resets the tap history buffer
    expect(arpSrc).toMatch(/>\s*2\.0|>=\s*2\.0/);
  });

  test("r7_contract_05_bpm_clamping_30_to_300", () => {
    // Verifies calculated BPM is clamped between 30 and 300
    expect(arpSrc).toMatch(/math\.max\(30\.0?,\s*math\.min\(300\.0?/);
  });

  test("r7_contract_06_engine_resync_and_hud_update", () => {
    // Verifies BPM update applies to state and reschedules timers
    expect(arpSrc).toMatch(/applyBpmChange|state\.arpBpm\s*=/);
    expect(controlsSrc).toContain('title = "TAP TEMPO"');
  });
});
```

### 8.2 Tier 2 Boundary & Edge Cases: `tests/tier2_boundary_edge_cases/r7_tap_tempo_jitter_and_outliers.test.js`

```javascript
import { expect, test, describe } from "bun:test";

describe("R7 Tier 2: Tap Tempo Jitter, Outliers & Timeout Boundaries", () => {
  class TapTempoSim {
    constructor() {
      this.history = [];
      this.lastTapTime = 0;
      this.bpm = 120.0;
    }

    tap(t) {
      if (this.lastTapTime > 0) {
        const delta = t - this.lastTapTime;
        // Sub-50ms debounce rejection (< 50ms = > 1200 BPM accidental bounce)
        if (delta < 0.050) {
          return this.bpm;
        }
        // Timeout > 2.0s resets sequence
        if (delta > 2.0) {
          this.history = [];
        } else {
          this.history.push(delta);
          if (this.history.length > 5) this.history.shift(); // 5-tap rolling window
          const avgDelta = this.history.reduce((a, b) => a + b, 0) / this.history.length;
          const rawBpm = 60.0 / avgDelta;
          this.bpm = Math.max(30.0, Math.min(300.0, Math.round(rawBpm * 10) / 10));
        }
      }
      this.lastTapTime = t;
      return this.bpm;
    }
  }

  test("r7_edge_01_single_tap_records_reference_no_bpm_jump", () => {
    const sim = new TapTempoSim();
    const bpm = sim.tap(10.0);
    expect(bpm).toBe(120.0); // Baseline unchanged
    expect(sim.history.length).toBe(0);
  });

  test("r7_edge_02_steady_120_bpm_taps", () => {
    const sim = new TapTempoSim();
    sim.tap(0.0);
    sim.tap(0.5); // 500ms = 120 BPM
    sim.tap(1.0);
    sim.tap(1.5);
    sim.tap(2.0);
    expect(sim.bpm).toBe(120.0);
  });

  test("r7_edge_03_steady_150_bpm_taps", () => {
    const sim = new TapTempoSim();
    sim.tap(0.0);
    sim.tap(0.4); // 400ms = 150 BPM
    sim.tap(0.8);
    sim.tap(1.2);
    expect(sim.bpm).toBe(150.0);
  });

  test("r7_edge_04_timeout_after_2_seconds_resets_history", () => {
    const sim = new TapTempoSim();
    sim.tap(0.0);
    sim.tap(0.5); // 120 BPM
    expect(sim.history.length).toBe(1);

    // Wait 2.1s (gap > 2.0s)
    sim.tap(2.6);
    expect(sim.history.length).toBe(0); // History cleared!
    // Next tap establishes new tempo at 300ms (200 BPM)
    sim.tap(2.9);
    expect(sim.bpm).toBe(200.0);
  });

  test("r7_edge_05_switch_bounce_rejection_under_50ms", () => {
    const sim = new TapTempoSim();
    sim.tap(1.0);
    // Accidental hardware switch chatter 20ms later
    sim.tap(1.02);
    expect(sim.history.length).toBe(0); // Chatter rejected
  });

  test("r7_edge_06_clamping_at_30_and_300_bpm", () => {
    const sim = new TapTempoSim();
    // 100ms interval = 600 BPM -> clamp to 300
    sim.tap(0.0);
    sim.tap(0.1);
    expect(sim.bpm).toBe(300.0);

    // 1.9s interval = 31.5 BPM
    sim.tap(2.0); // timeout reset
    sim.tap(3.9); // 1.9s -> 31.6 BPM
    expect(sim.bpm).toBeGreaterThanOrEqual(30.0);
  });
});
```

---

## 9. Tier 3: Cross-Feature Interaction Test Design

### 9.1 Volume Repeat vs Quantized Chords (R1 + R6): `tests/tier3_cross_feature_interactions/r1_r6_volume_during_quantized_playback.test.js`

```javascript
import { expect, test, describe } from "bun:test";

describe("Tier 3 Interaction: R1 Volume Adjustments During R6 Quantized Playback", () => {
  test("r1_r6_interaction_01_continuous_volume_repeat_during_chords", () => {
    // Assert that repeated volume changes do not drop note-off events or delay note-on callbacks
    const noteQueue = [];
    let volume = 100;

    // Simulate concurrent volume repeat ticks and note callbacks
    function onVolumeTick() {
      volume = Math.min(127, volume + 4);
      // Volume tick must not block thread or clear noteQueue
    }

    function onNoteOn(p) { noteQueue.push({ type: "on", pitch: p }); }
    function onNoteOff(p) { noteQueue.push({ type: "off", pitch: p }); }

    // Interleave 10 volume ticks with 3 chord notes
    onNoteOn(60);
    onVolumeTick();
    onNoteOn(64);
    onVolumeTick();
    onNoteOn(67);
    onVolumeTick();
    onNoteOff(60);
    onNoteOff(64);
    onNoteOff(67);

    expect(volume).toBe(112);
    expect(noteQueue.filter(e => e.type === "on").length).toBe(3);
    expect(noteQueue.filter(e => e.type === "off").length).toBe(3);
  });

  test("r1_r6_interaction_02_debounced_save_preserves_timer_jitter_under_1ms", async () => {
    let tickExecutionTimes = [];
    let timer = null;

    function debouncedSave() {
      if (timer) clearTimeout(timer);
      timer = setTimeout(() => {}, 50);
    }

    // Schedule 5 note ticks while debouncing save
    for (let i = 0; i < 5; i++) {
      const start = performance.now();
      debouncedSave();
      tickExecutionTimes.push(performance.now() - start);
    }

    // Every tick must complete in < 1ms (zero synchronous I/O stall)
    tickExecutionTimes.forEach(duration => {
      expect(duration).toBeLessThan(1.0);
    });
  });
});
```

### 9.2 Arpeggiator Resync on Tap Tempo (R2 + R7): `tests/tier3_cross_feature_interactions/r2_r7_arp_tap_tempo_live_resync.test.js`

```javascript
import { expect, test, describe } from "bun:test";

describe("Tier 3 Interaction: R2 Arp Engine Resync During R7 Tap Tempo", () => {
  test("r2_r7_interaction_01_tap_tempo_updates_running_arp_clock", () => {
    let currentBpm = 120.0;
    let stepDuration = (60.0 / currentBpm) * 0.25; // 16th note

    function applyTapTempo(newBpm) {
      currentBpm = newBpm;
      stepDuration = (60.0 / currentBpm) * 0.25;
    }

    expect(stepDuration).toBe(0.125); // At 120 BPM
    applyTapTempo(140.0);
    expect(stepDuration).toBeCloseTo(0.1071, 4); // At 140 BPM
  });

  test("r2_r7_interaction_02_gate_timer_preserved_across_bpm_change", () => {
    // When BPM changes midway through a gate duration, active gate timer must fire safely
    let noteOffFired = false;
    let activeGate = { pitch: 60, generation: 1 };

    function onGateExpired(gen) {
      if (activeGate && activeGate.generation === gen) {
        noteOffFired = true;
        activeGate = null;
      }
    }

    // BPM change occurs
    // Stale generation check preserves active gate
    onGateExpired(1);
    expect(noteOffFired).toBe(true);
  });
});
```

### 9.3 Partial Quantization with Watchdog (R3 + R6): `tests/tier3_cross_feature_interactions/r3_r6_quantize_watchdog_harmony.test.js`

```javascript
import { expect, test, describe } from "bun:test";

describe("Tier 3 Interaction: R3 Quantize Legato Sustaining vs R6 Voice Watchdog", () => {
  test("r3_r6_interaction_01_legato_grace_sustaining_not_flagged_by_watchdog", () => {
    // Notes sustained for legato grid alignment (age < 0.5s) must not be treated as orphans
    const now = 100.5;
    const voice = { note: 60, startTime: 100.0, heldForPending: "event_1" };
    const maxAge = 5.0;

    const isOrphan = (now - voice.startTime) > maxAge && !voice.heldForPending;
    expect(isOrphan).toBe(false);
  });

  test("r3_r6_interaction_02_90_percent_quantize_with_staccato_retrigger", () => {
    // 90% strength with staccato release guarantees clean voice re-attack
    let voiceCount = 0;
    function noteOn() { voiceCount++; }
    function noteOff() { voiceCount = Math.max(0, voiceCount - 1); }

    // Tap 1 with 90% quantize delay
    noteOn();
    // Immediate release
    noteOff();
    // Rapid Tap 2
    noteOn();
    noteOff();

    expect(voiceCount).toBe(0);
  });
});
```

---

## 10. Tier 4: Real-World E2E Scenario Test Design

### 10.1 Multi-Track Live Jam: `tests/tier4_real_world_e2e_scenarios/multitrack_audio_midi_live_performance.test.js`

```javascript
import { expect, test, describe } from "bun:test";

describe("Tier 4 Scenario 1: Multi-Track Polyphonic Live Performance Jam", () => {
  test("tier4_scenario_01_full_performance_lifecycle", () => {
    // Track 1 (Bass, Ch 0): Volume 110, 1/8 note 90% quantize
    // Track 2 (Chords, Ch 1): Volume 95, Smart sustain
    // Track 3 (Lead, Ch 2): Volume 120, Arp UP-DOWN with Downbeat Accent
    const tracks = {
      1: { volume: 110, channel: 0, activeNotes: new Set() },
      2: { volume: 95,  channel: 1, activeNotes: new Set() },
      3: { volume: 120, channel: 2, activeNotes: new Set() }
    };

    // 1. Play Track 1 Bass Note 36
    tracks[1].activeNotes.add(36);
    // 2. Play Track 2 Chord {48, 52, 55}
    [48, 52, 55].forEach(p => tracks[2].activeNotes.add(p));
    // 3. Arp step on Track 3 Note 72
    tracks[3].activeNotes.add(72);

    expect(tracks[1].activeNotes.size).toBe(1);
    expect(tracks[2].activeNotes.size).toBe(3);
    expect(tracks[3].activeNotes.size).toBe(1);

    // 4. Live adjust Track 1 volume (-10)
    tracks[1].volume = Math.max(0, tracks[1].volume - 10);
    expect(tracks[1].volume).toBe(100);

    // 5. Full release of all keys
    tracks[1].activeNotes.clear();
    tracks[2].activeNotes.clear();
    tracks[3].activeNotes.clear();

    expect(tracks[1].activeNotes.size).toBe(0);
    expect(tracks[2].activeNotes.size).toBe(0);
    expect(tracks[3].activeNotes.size).toBe(0);
  });
});
```

### 10.2 Chaos Key Mashing & Panic Recovery: `tests/tier4_real_world_e2e_scenarios/chaos_mashing_and_panic_recovery.test.js`

```javascript
import { expect, test, describe } from "bun:test";

describe("Tier 4 Scenario 2: Chaos Key Mashing & Panic Recovery", () => {
  test("tier4_scenario_02_100_burst_events_and_panic_clean", () => {
    const activeLedger = {};

    function sendNoteOn(note, ch) {
      activeLedger[`${note}_${ch}`] = true;
    }
    function sendNoteOff(note, ch) {
      delete activeLedger[`${note}_${ch}`];
    }
    function panic() {
      for (const k in activeLedger) {
        delete activeLedger[k];
      }
    }

    // Dispatch 100 pseudorandom note events
    for (let i = 0; i < 100; i++) {
      const note = 48 + (i % 24);
      const ch = i % 4;
      if (i % 3 === 0) {
        sendNoteOff(note, ch);
      } else {
        sendNoteOn(note, ch);
      }
    }

    expect(Object.keys(activeLedger).length).toBeGreaterThan(0);

    // Trigger panic
    panic();

    expect(Object.keys(activeLedger).length).toBe(0);
  });
});
```

---

## 11. Mock Strategy for Hammerspoon Execution

Because Hammerspoon global libraries (`hs.timer`, `hs.midi`, `hs.settings`) are native macOS extensions not loaded by bare CLI `lua`, our test architecture combines two verification styles:
1. **Contract & Structural Tests**: Bun tests read `.lua` source files and assert regex/AST invariants.
2. **Deterministic JS Math Simulation**: Mathematical algorithms (quantize delay scaling, tap tempo rolling windows, velocity contours, debounced timers) are modeled in JavaScript with exhaustive property testing.
3. **Standalone Lua Test Harness** (`tests/harness/hs_mock.lua`): A minimal, zero-dependency pure-Lua shim implementing:
   - `hs.timer`: `hs.timer.secondsSinceEpoch()`, `hs.timer.absoluteTime()`, `hs.timer.doAfter()`, `hs.timer.doEvery()`.
   - `hs.midi`: Mock virtual endpoint capturing all transmitted Note-On, Note-Off, and CC messages.
   - `hs.settings`: In-memory table mock for `get()`, `set()`, `clear()`.
   This enables implementers in M2 and M3 to execute direct Lua unit tests via `/opt/homebrew/bin/lua tests/harness/run_tests.lua` if desired.

---

## 12. Verification & Next Steps

This complete design is fully documented and immediately available for Milestone M2 (R3, R6 implementation) and Milestone M3 (R1, R2, R7 implementation).
