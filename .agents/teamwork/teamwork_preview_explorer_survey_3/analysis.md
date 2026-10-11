# Comprehensive Test Infrastructure, Build Pipeline & Verification Survey

**Author**: Survey Explorer 3 (Test Infra & Verification)  
**Date**: 2026-10-11  
**Project**: `surface-studio-suite` / `qwerty-midi-hammerspoon`  
**Working Directory**: `/Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_explorer_survey_3`

---

## Executive Summary

This survey provides a comprehensive audit of the testing infrastructure, build/bundle pipeline, and verification architecture for `qwerty-midi-hammerspoon`. It analyzes the existing test suite, exposes critical vulnerabilities in the bundling and reload pipeline, and details a complete **4-Tier E2E Testing Architecture** spanning Bun and Lua test harnesses to verify Requirements R1 through R7.

---

## 1. Existing Test Infrastructure & Audit

### 1.1 Project Structure & Configuration
- **Monorepo Architecture**: Defined in root `package.json` with `"workspaces": ["packages/*"]`.
  - Root packages: `packages/qwerty-midi`, `packages/nanokey-studio` (archived in `archive/`), `packages/music-engine`, `packages/surface-hud`, `packages/studio-suite`, `packages/dualsynth`, `packages/keystep-interceptor`.
  - Legacy/active production source resides in `src/` (`config.lua`, `controls.lua`, `arpeggiator.lua`, `hud.lua`, `midi.lua`, `settings_ui.lua`, `sync.lua`, `transposer.lua`, `ui_html.lua`, `web/index.html`).
- **Test Runner**: Tests are executed via `bun test` using `bun:test`.
  - Currently, root `package.json` has scripts for `bundle`, `dev:hud`, `dualsynth:*`, but lacks an explicit `"test": "bun test"` script. Adding `"test": "bun test"` will standardize execution.
  - Test run status: `77 pass, 0 fail, 665 expect() calls across 19 files` completed in **~750ms**.

### 1.2 Inventory of Existing Test Files
All current test files reside in `tests/` and use the `.test.js` extension:

| Test File | Primary Focus | Key Invariants Asserted |
|---|---|---|
| `arpeggiator_timing.test.js` | Arp gate timer & HUD update coalescing | Generation guarding against note termination; deferred `hs.timer.doAfter(0)` fast update |
| `attack_decay_arp_dir_and_legato_quantize.test.js` | Attack/Decay CC routing, Arp Dir, Legato quantize | Keys 25/29 resolve to active track; per-track Arp direction persistence; quantizer `soundingNotes` & legato grace |
| `chord_display_and_layout_shift.test.js` | Chord mode UI isolation & Zero Layout Shift | Dormant chords unlit when chord mode is off; rigid px widths and tabular numbers on all header/row elements |
| `f_key_and_track_colors.test.js` | F key mapping & track visual styling | Key 3 (`F`) is strictly `octaveUp`; assigned track colors; 88-key piano & chord mini-piano markup |
| `hud_close_controls.test.js` | HUD safety lifecycle | Cmd-Shift-M hotkey, right-click close, fail-open event tap teardown, disarmed reload |
| `keyboard_input.test.js` | Event tap note isolation | Mac event-tap keys do not masquerade as KeyStep external notes |
| `keystep_bottom_row_routing.test.js` | KeyStep hardware channel targeting | KeyStep targets `state.bottomRowTrack` (Track 1 or 2) exclusively |
| `keystep_embedded_hud.test.js` | Embedded KeyStep display in HUD | 32-key silhouette, height expansion to 600px, bidirectional WebKit IPC |
| `keystep_gui.test.js` | KeyStep UI wiring | 32 slimkeys (notes 41..72), transport status, modal shift keybed, scale lock |
| `keystep_interceptor.test.js` | Hardware packet parser & DSP timing | PPQN clock pulse median BPM tracking, marker notes C10..G10, Rate CC 107, full ADSR modal shift |
| `logic_names_and_smart_sustain.test.js` | Smart sustain & Logic DAW header sync | All 4 tracks default to `'smart'`; Logic track name parsing without layout shift |
| `per_track_settings_and_keystep_arp.test.js` | Track settings persistence & KeyStep arp | Per-track volume, octave, attack, decay in `hs.settings`; KeyStep bottom track arp illumination |
| `shortcut_visibility_and_sustain_off.test.js` | Shortcut contracts | Tab double-tap sustain off; Ctrl+Tab pass-through; documented global shortcuts |
| `track_arp_rate.test.js` | Arp rate track ownership | Rate selector follows active track; per-track rate timer replacement |
| `track_button_authority.test.js` | Track button state authority | Only authoritative coalesced `renderHud` updates track selection visual state |
| `track_button_layout.test.js` | Track card DOM zones | Independent zones for identity, controls, and status; modifier label fit |
| `track_control_presentation.test.js` | Track card styling presentation | Only number-row track selectors receive `track-card` class |
| `track_mute_solo_daw_integration.test.js` | DAW Mute/Solo CC cutoff | Immediate cutoff via CC 120/123, CC 7, CC 11, Logic CC 108/109; notes registered while muted |
| `track_selection_and_reverse_sustain.test.js` | Track persistence & color binding | Active/bottom/top tracks saved to `hs.settings`; Tab damping; control re-theming |

### 1.3 How Existing Tests Function
- **Source-Level Contracts**: Existing tests read source files directly using `await Bun.file("src/...").text()` and verify structural, algorithmic, and stylistic invariants via regex, substring checks, and AST pattern matching.
- **Mathematical Simulation**: In files like `keystep_interceptor.test.js`, tests implement twin JavaScript models of Lua mathematical functions (e.g., `bpmToRate`, `rateToBpm`, `rateToVolumeCc`) to verify algorithm correctness across the entire range (0..127, 30..240 BPM).
- **DOM & CSS Invariant Checks**: Tests inspect `src/web/index.html` for CSS bounding box definitions, `tabular-nums`, `flex-shrink: 0`, and specific class interactions.

---

## 2. Build & Bundle Pipeline Deep-Dive

### 2.1 The Pipeline Flow
1. **Source Sync**: `src/web/index.html` (WebKit HUD UI) is synced into `src/ui_html.lua` via Python `bin/hs-bundler`.
2. **Module Collection & Rewriting**: `bin/hs-bundler` scans source directories (`packages/music-engine`, `packages/keystep-interceptor`, `src`), reads all `.lua` files, and transforms `require("mod")` calls into `__require("mod")`.
3. **Bundled Emission**: Modules are wrapped into closures `__modules["modname"] = function() ... end` and emitted into `qwerty_midi.lua`.
4. **Hammerspoon Reload**: `bin/bundle_and_reload.sh` triggers `hs -c "hs.reload()"` or osascript to reload Hammerspoon.

### 2.2 Critical Vulnerabilities & Pipeline Gaps Identified

#### G1: Missing Syntax Validation Before Reload (`luac -p`)
- **Observed Behavior**: `bin/bundle_and_reload.sh` executes:
  ```bash
  python3 "$PROJECT_DIR/bin/hs-bundler" --target qwerty-midi
  if [ $? -eq 0 ]; then
    hs -c "hs.reload()"
  ```
  If Python generates `qwerty_midi.lua` without an unhandled exception, `bundle_and_reload.sh` immediately triggers `hs.reload()`.
- **Vulnerability**: `bin/bundle_and_reload.sh` does **not** run `luac -p qwerty_midi.lua` before reloading! If any module introduced a Lua syntax error (e.g., mismatched `end`, syntax error in template string), Hammerspoon reloads a corrupted bundle, causing Hammerspoon to crash or hang.
- **Resolution**: Insert `luac -p "$PROJECT_DIR/qwerty_midi.lua" || exit 1` immediately following the bundler step in `bin/bundle_and_reload.sh`.

#### G2: Non-Deterministic Module Bundling Order (`os.walk` sorting)
- **Observed Behavior**: In `bin/hs-bundler`:
  ```python
  for root, _, files in os.walk(abs_src_dir):
      for file in files:
          if file.endswith(".lua"):
              ...
              modules[mod_name] = content
  ```
  `os.walk()` order is filesystem-dependent. On macOS APFS, directory iteration order can vary after file creation or git checkout.
- **Vulnerability**: When iterating `for mod_name, code in modules.items():`, modules are emitted in arbitrary order. Running `hs-bundler` can generate a 10,000+ line git diff on `qwerty_midi.lua` without a single line of logic changing!
- **Resolution**: Change iteration to `sorted(files)` and sort `modules.keys()` or `sorted(modules.items())` when writing `qwerty_midi.lua`.

#### G3: Web UI Ingestion Escaping Vulnerability (`sync_ui_html`)
- **Observed Behavior**: `bin/hs-bundler` lines 61-64:
  ```python
  lua_module_content = f'local HTML_UI_CONTENT = [[\n{html_content}\n]]\n\nreturn HTML_UI_CONTENT\n'
  ```
- **Vulnerability**: Lua multiline literal `[[ ... ]]` does not permit internal `]]`. If any JavaScript regular expression, array literal, or CSS rule in `src/web/index.html` contains `]]`, the Lua string literal terminates prematurely, invalidating the bundle.
- **Resolution**: Use Lua long brackets with level delimiters: `[===[` and `]===]`, or sanitize `]]`.

#### G4: Module Shadowing and Duplication
- **Observed Behavior**: `packages/music-engine/arpeggiator.lua` (1018 lines) and `src/arpeggiator.lua` (1676 lines) both produce `mod_name = "arpeggiator"`. `src/init.lua` and `packages/music-engine/init.lua` both produce `mod_name = "init"`.
- **Mechanism**: In `TARGET_PRESETS["qwerty-midi"]`, `src_dirs` lists `["packages/music-engine", "packages/keystep-interceptor", "src"]`. Because `src` is listed last, `src/arpeggiator.lua` silently clobbers `packages/music-engine/arpeggiator.lua`.
- **Resolution**: Clearly isolate package module namespaces or retire shadowed duplicate files.

---

## 3. Analysis & Strategy for Requirements R1–R7

### R1. Track Volume Control Keys (CC 7 & Event Preservation)
- **Problem & Current State**:
  - `controls.adjustTrackVolume(trackId, delta)` exists (lines 495-512 of `src/controls.lua`), modifying `trk.volume` (0..127) and emitting MIDI CC 7 (`midi.sendMidiCC(7, trk.volume, trk.channel)`).
  - Web UI buttons trigger it, but there are **no dedicated keyboard shortcuts/bindings** for individual track volume adjustment (Tracks 1–4). Current keyboard controls only have generic `topVolUp`/`topVolDown` and `botVolUp`/`botVolDown` or active track `volUp`/`volDown`.
  - Rapid volume adjustments must not block the event loop or drop active/sounding note events.
- **Testing Approach**:
  - **Tier 1 (Contract)**: Verify dedicated key action definitions (e.g. `trk1VolUp`, `trk1VolDown` .. `trk4VolUp`, `trk4VolDown`) in `config.lua` and `controls.lua`. Verify MIDI CC 7 payload values (0..127).
  - **Tier 2 (Boundary)**: Volume clamping at 0 and 127; rapid repeated adjustments (+4, +8...); volume changes on muted tracks (CC 7 suppressed while muted, restored upon unmute).
  - **Tier 3 (Interactions)**: Concurrently streaming note-on/note-off events while firing volume adjustments; assert zero dropped note events.

### R2. Rich Arpeggiator Patterns, Velocity Contours & Microtiming
- **Problem & Current State**:
  - `src/config.lua:58` only defines 7 basic directions: `{"UP", "DOWN", "UP-DOWN", "DOWN-UP", "CONVERGE", "DIVERGE", "RANDOM"}`.
  - In `src/arpeggiator.lua:418-420`, velocity is completely static (`vel = math.floor(math.min(127, (trk.volume or 100) * 1.0))`), and gate length is static (`gateDuration = trackStepSec * gateRatio`).
  - No velocity contours (e.g., accent on downbeats, crescendo, decrescendo, swing, bounce) or microtiming humanization exist.
- **Testing Approach**:
  - **Tier 1 (Contract)**: Verify pattern dictionary expansion in `config.lua` / `clock.lua` / `arpeggiator.lua`. Verify velocity contour calculation (accent multipliers $v_i \in [0.6, 1.3]$ clamped to 1..127) and microtiming jitter ($\delta \in [-12\text{ms}, +12\text{ms}]$).
  - **Tier 2 (Boundary)**: Single-note held, polyphonic chords (1 to 10 pitches), extreme BPMs (30 BPM vs 240+ BPM), 0% gate vs 100% gate.
  - **Tier 3 (Interactions)**: Multi-track arpeggiators running independently with distinct patterns (e.g. Track 1 with Sub-Bass Up/Down vs Track 3 with Triplet Diverge); verify non-colliding gate generations and timers.

### R3. Configurable Quantization Amount (0–100%, Default 90%)
- **Problem & Current State**:
  - `packages/music-engine/quantizer.lua:36-64` calculates `calculateDelay` as an all-or-nothing step delay (`timeToNext = stepDuration - elapsed`).
  - There is no strength factor or amount parameter; quantization is either 100% or 0% (`"Off"`).
  - R3 requires configurable strength $S \in [0, 100]\%$, defaulting to 90%, where applied delay scales with strength: $\text{delay}_{\text{applied}} = \text{timeToNext} \times (S / 100)$.
- **Testing Approach**:
  - **Tier 1 (Contract)**: Verify `quantizeStrength` parameter in `config.lua` (default 90) and `quantizer.lua`. Verify settings persistence (`qwertyMidi_quantizeStrength`).
  - **Tier 2 (Boundary)**: 0% strength produces 0ms delay (immediate trigger); 100% strength produces full `timeToNext`; 90% strength applies 0.90 correction factor; negative or >100 values clamped.
  - **Tier 3 (Interactions)**: Legato sustain with partial quantization; notes released during anticipation grace window trigger smoothly on scaled beat.

### R4. Key Overlay Legibility & Label Text Wrapping
- **Problem & Current State**:
  - In `src/web/index.html:737`, `.key-pad .key-note` is styled with `white-space: nowrap;`. Within a 58px wide key, text longer than 6–8 characters (e.g. "Smart Sus · 2× Off", "Degree 7 (Subtonic)") overflows and collides with neighbouring keys.
  - In `src/hud.lua:948-970`, when Cmd is held, every unmapped key in 0..127 receives `{ name = "Pass Through", class = "shortcut-passthrough" }`, covering the entire keyboard in redundant "Pass Through" clutter.
  - In `src/web/index.html:1010`, `.shortcut-passthrough` has `opacity: 0.4 !important;`, causing muddy dimming.
- **Testing Approach**:
  - **Tier 1 (Contract)**: Check CSS rules in `src/web/index.html`: `.key-note` must have `white-space: normal` (or `pre-wrap` with word-break), bounded container height/width, and line-height.
  - **Tier 2 (Boundary)**: Unmapped keys under Cmd modifier must either omit "Pass Through" or suppress redundant labels so only mapped shortcuts stand out with clear high-contrast opacity ($\ge 0.85$).
  - **Tier 3 (Layout Invariant)**: Invariant check that key bounding boxes (`width: 58px; height: 44px;`) and grid columns do not expand or reflow (ZLS) when long labels wrap into 2 lines.

### R5. Real-Time State Indicators on Key Surfaces
- **Problem & Current State**:
  - In `src/hud.lua:850-910`, only Key A (Arp/Latch) and Key Tab (Sustain) have dynamic surface overlays.
  - Parameter keys like Attack (9), Decay (0), Volume, Octave (+/-), Transpose (+/-), BPM (+/-), Quantize show only static action names ("Atk -", "Atk +", "Oct +") without indicating the active numeric value or quantity controlled.
- **Testing Approach**:
  - **Tier 1 (Contract)**: Verify that `hud.lua` key update payloads include value badges/labels (e.g. `subtext` or dynamic label string showing `Vol 80%`, `Atk 64`, `Dec 32`, `Oct 0`, `Trnsp +2`, `Q 90%`).
  - **Tier 2 (Boundary)**: Min/max values (e.g., Atk 0 vs 127, Oct -3 vs +3, Vol 0% vs 100%); check formatting with tabular numerals.
  - **Tier 3 (Real-Time Update)**: When a key action executes, verify the corresponding key surface updates its displayed quantity without requiring a full webview reload.

### R6. Stuck Note Mitigation & Watchdog Loop
- **Problem & Current State**:
  - Rapid key taps under quantization can overwrite `pendingEvents[eventId]` while the previous voice is sounding in `soundingNotes[eventId]`, dropping subsequent Note Off commands.
  - Currently, `keyTapWatchdog` in `init.lua:418` only checks webview heartbeat; **no watchdog exists for MIDI notes**. If a note-off packet is lost, the synth drones forever.
- **Testing Approach**:
  - **Tier 1 (Contract)**: Implement and assert a MIDI Watchdog loop in `src/init.lua` / `src/midi.lua`: periodically inspects `activeNoteLedger`. If any voice has been active for longer than safety threshold (or active without physical key held in `state.pressedKeys`), emits `noteOff` and cleans the ledger.
  - **Tier 2 (Boundary)**: Rapid double-tap on same physical key (5ms interval); release before grid tick; panic command clearing all 16 MIDI channels simultaneously.
  - **Tier 3 (Interactions)**: Watchdog does not prematurely release legitimate sustained notes (e.g., held arpeggio or smart sustain).

### R7. Tap Tempo Functionality
- **Problem & Current State**:
  - `src/controls.lua:2018-2021` attempts to call `arpeggiator.tapTempo()`, but `arpeggiator.tapTempo` is **completely undefined** in `src/arpeggiator.lua` and `packages/music-engine/clock.lua`.
  - Tapping tempo does absolutely nothing!
- **Testing Approach**:
  - **Tier 1 (Contract)**: Verify `arpeggiator.tapTempo` implementation: records tap timestamps (`hs.timer.absoluteTime()`), calculates $\Delta t$ between consecutive taps, computes $\text{BPM} = 60 / \Delta t$, averages recent taps (sliding buffer of 4 taps), and updates `state.arpBpm`.
  - **Tier 2 (Boundary)**: First tap establishes reference (no BPM jump); taps > 2.0s apart reset buffer; taps < 60ms (< 1000 BPM) or > 3.0s (> 20 BPM) are rejected/clamped.
  - **Tier 3 (Interactions)**: Tapping tempo dynamically shifts active arpeggiator clock frequency without resetting step index or cutting off ringing gate notes.

---

## 4. 4-Tier E2E Testing Suite Architecture

To provide robust, multi-layer verification for all requirements, we structure tests across 4 tiers combining fast Bun contract/simulation tests with standalone Lua execution tests.

```
tests/
├── tier1_feature_contracts/
│   ├── r1_track_volume_controls.test.js
│   ├── r2_rich_arp_patterns.test.js
│   ├── r3_configurable_quantize.test.js
│   ├── r4_key_overlay_wrapping.test.js
│   ├── r5_realtime_key_indicators.test.js
│   ├── r6_stuck_note_watchdog.test.js
│   └── r7_tap_tempo_engine.test.js
├── tier2_boundary_edge_cases/
│   ├── volume_clamping_and_muting.test.js
│   ├── arp_extreme_rates_and_chords.test.js
│   ├── quantize_strength_boundaries.test.js
│   ├── label_wrapping_stress.test.js
│   ├── tap_tempo_jitter_and_outliers.test.js
│   └── rapid_retrigger_bounce.test.js
├── tier3_cross_feature_interactions/
│   ├── volume_during_quantized_playback.test.js
│   ├── arp_tap_tempo_live_resync.test.js
│   ├── quantize_watchdog_harmony.test.js
│   └── modifier_layer_state_indicators.test.js
├── tier4_real_world_e2e_scenarios/
│   ├── multitrack_live_performance_flow.test.js
│   └── chaos_mashing_and_panic_recovery.test.js
└── harness/
    ├── hs_mock.lua           # Mock environment for Hammerspoon runtime
    ├── run_lua_tests.js      # Bun test runner bridge spawning Lua harnesses
    └── fixtures/
        └── midi_event_stream.json
```

### Detailed Tier Breakdown

#### Tier 1: Feature Coverage (Unit / Contract Level)
Validates individual modules and isolated function contracts:
1. **R1**: Dedicated volume keys for Tracks 1–4, MIDI CC 7 emission, persistence in `hs.settings`.
2. **R2**: Arp pattern definitions, velocity contour tables, microtiming random jitter calculation.
3. **R3**: Quantize strength 0–100% parameter, default 90%, scaled delay formula.
4. **R4**: CSS `white-space`, word wrapping within key bounds, removal of redundant "Pass Through" labels, high-contrast modifier opacity.
5. **R5**: Key surface value indicators for Volume, Attack, Decay, Octave, Transpose, BPM, and Quantize.
6. **R6**: MIDI watchdog timer creation, active note ledger scanning, stale note detection.
7. **R7**: Tap tempo timestamp recording, sliding buffer averaging, BPM calculation formula.

#### Tier 2: Boundary & Edge Cases
Validates extreme parameters, zero conditions, and timing anomalies:
1. **Volume Extremes**: Value 0 vs 127; rapid volume changes during mute/unmute transitions.
2. **Arp Limits**: Single-note loop, 12-note chord, 30 BPM vs 300 BPM, 5% gate vs 100% gate.
3. **Quantize Limits**: 0% strength (instant pass-through), 100% strength (hard grid snap), 90% strength (10% human slack). Notes pressed 1ms before grid tick vs 1ms after.
4. **Label Length Stress**: Longest possible action labels (e.g. "Smart Sus · 2× Off", "Degree 7 (Subtonic)") inside 58px keys with 0 text overflow.
5. **Tap Tempo Anomaly**: Solitary taps, taps separated by > 2.5 seconds (session reset), rapid key bounce (< 40ms).
6. **Rapid Retrigger**: Striking same key 20 times in 500ms; validating that no note-off is lost or dropped.

#### Tier 3: Cross-Feature Interactions
Validates concurrent subsystems running in unison:
1. **Volume + Rapid Playback (R1 + R6)**: Adjusting track volumes while mashing keys does not interrupt active notes or delay note-offs.
2. **Arp + Quantize + Tap Tempo (R2 + R3 + R7)**: Tapping tempo updates running arpeggiators across Tracks 1 and 3 in real time without cutting off sounding gate timers or causing voice clicks.
3. **Quantize + Watchdog (R3 + R6)**: Watchdog does not flag or terminate legitimate notes held during quantize anticipation or legato grace windows.
4. **Modifier Layers + Indicators (R4 + R5)**: Holding Cmd, Shift, or Option displays correct wrapped labels with live parameter indicators without cumulative layout shift.

#### Tier 4: Real-World E2E Scenarios
End-to-end performance simulations:
1. **Scenario 1: Live Multi-Track Performance Session**:
   - Track 1 Bass (bottom row) playing quantized chords.
   - Track 3 Lead (upper row) running 16th-note arpeggiator with human velocity contours.
   - Live adjustments to Track 1 volume (-12 dB) and Track 3 volume (+6 dB).
   - Tap tempo adjusted from 120 to 128 BPM.
   - Hold Cmd to view shortcuts.
   - Full release: zero hung notes, 100% clean note ledger.
2. **Scenario 2: Stress / Chaos Key Mashing & Panic Recovery**:
   - 100 simulated asynchronous keydown and keyup events dispatched in 1.5 seconds.
   - Random modifier transitions (Cmd, Shift, Ctrl, Opt).
   - Immediate Panic triggered.
   - Verification: All CoreMIDI channels receive All Notes Off (CC 123) and Damper Off (CC 64); active voice ledger count is exactly 0.

---

## 5. Implementation Roadmap for Verification Harness

To execute this architecture effortlessly:
1. **Add Test Script to `package.json`**:
   ```json
   "scripts": {
     "test": "bun test",
     "test:tier1": "bun test tests/tier1*",
     "test:tier2": "bun test tests/tier2*",
     "test:tier3": "bun test tests/tier3*",
     "test:tier4": "bun test tests/tier4*"
   }
   ```
2. **Enhance `bin/hs-bundler` Determinism**:
   - Sort file lists in `os.walk` and sort `modules.keys()` before bundle output.
   - Use `[===[ ... ]===]` long brackets in `sync_ui_html`.
3. **Harden `bin/bundle_and_reload.sh`**:
   - Add `luac -p qwerty_midi.lua || { echo "❌ Lua syntax error"; exit 1; }` before Hammerspoon reload.
4. **Create Hammerspoon Mock Harness (`tests/harness/hs_mock.lua`)**:
   - Lightweight pure-Lua mock for `hs.timer`, `hs.midi`, `hs.settings`, `hs.json`.
   - Allows running actual Lua modules via `/opt/homebrew/bin/lua` directly in CI and local testing.
