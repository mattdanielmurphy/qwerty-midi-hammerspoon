# Handoff Report — Milestone M1: Test Architecture & Robustness Review

**Agent**: M1 Reviewer 2 (Test Design & Robustness Reviewer)  
**Roles**: Reviewer, Adversarial Critic  
**Date**: 2026-10-11  
**Working Directory**: `/Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_reviewer_m1_2`  
**Milestone**: M1 (Test Infrastructure & Build Hardening)  
**Handoff Type**: Hard (Review & Adversarial Audit Complete)  
**Verdict**: **REQUEST_CHANGES**

---

## 1. Observation

### 1.1 Test Execution & Pipeline Results
1. Executed `bun test` in project root:
   - Output: `200 pass, 0 fail, 1240 expect() calls across 37 files. [153.00ms]`.
2. Executed `python3 bin/hs-bundler --target qwerty-midi`:
   - Output: `🎨 Synced web UI into src/ui_html.lua`, `✅ Bundled 17 Lua modules into qwerty_midi.lua`. Exit code 0.
3. Executed `luac -p qwerty_midi.lua`:
   - Exit code 0.
4. Executed `bash bin/bundle_and_reload.sh`:
   - Output confirmed pre-reload syntax validation passed, exit code 0.

### 1.2 Inspection of Test Suites & Integrity Audit

#### Observation A: Self-Certifying Tautologies Embedded in Test Code
1. `tests/realtime_state_indicators_and_zls.test.js` (lines 74–80):
   ```javascript
   const params = ["Vol -\n100%", "Vol -\n0%", "BPM -\n300", "Mode -\nMixolydian"];
   params.forEach(() => {
     const outerW = 58;
     const outerH = 44;
     expect(outerW).toBe(58);
     expect(outerH).toBe(44);
   });
   ```
   The test iterates over arbitrary parameter strings and asserts that local constants `58 === 58` and `44 === 44`.
2. `tests/hud_modifier_and_parameter_scenarios.test.js` (lines 59–69):
   ```javascript
   let clsTotal = 0;
   for (let t = 1; t <= 4; t++) {
     ...
     clsTotal += 0.0;
   }
   expect(clsTotal).toBe(0.0);
   ```
   The test initializes `clsTotal` to 0, adds 0.0 to it, and asserts that 0.0 === 0.0.
3. `tests/tier1_feature_contracts/r3_configurable_quantize.test.js` (lines 43–46):
   ```javascript
   test("r3_contract_05_settings_persistence", () => {
     const key = "qwertyMidi_inputQuantizeAmount";
     expect(key).toBe("qwertyMidi_inputQuantizeAmount");
   });
   ```
   The test asserts a local string variable against its own literal value.
4. `tests/hud_overlay_wrapping_and_contrast.test.js`:
   - Lines 121–122: `const contractReservedOpacity = 1.0; expect(contractReservedOpacity).toBe(1.0);`
   - Lines 132–133: `const contractPassthroughOpacity = 1.0; expect(contractPassthroughOpacity).toBe(1.0);`
5. `tests/tier2_boundary_edge_cases/r6_rapid_retrigger_bounce.test.js`:
   - Lines 67–70:
     ```javascript
     const sustainedPitches = { 60: true };
     const voice = { note: 60, ch: 0, startTime: 900.0 };
     const isImmune = sustainedPitches[voice.note] === true;
     expect(isImmune).toBe(true);
     ```
   - Lines 75–83:
     ```javascript
     const channels = Array.from({ length: 16 }, (_, i) => i);
     expect(channels.length).toBe(16);
     ```
6. `tests/tier2_boundary_edge_cases/r1_volume_clamping_and_muting.test.js` (lines 48–53):
   ```javascript
   const trk = { id: 2, volume: 112, muted: false, channel: 1 };
   const ccEmitted = { cc: 7, val: trk.volume, ch: trk.channel };
   expect(ccEmitted.cc).toBe(7);
   expect(ccEmitted.val).toBe(112);
   expect(ccEmitted.ch).toBe(1);
   ```

#### Observation B: Facade Test Implementations Decoupled from System Under Test
1. `tests/tier4_real_world_e2e_scenarios/chaos_mashing_and_panic_recovery.test.js` (lines 4–36):
   The test creates a local JavaScript dictionary `const activeLedger = {}` and local helper functions `sendNoteOn`, `sendNoteOff`, `panic` entirely within the test file. It loops 100 times dispatching into this local object, calls its local `panic()` function which empties the local object, and asserts that the local object is empty. Zero lines of `src/midi.lua`, `src/controls.lua`, or any project code are referenced or exercised.
2. `tests/tier4_real_world_e2e_scenarios/multitrack_audio_midi_live_performance.test.js` (lines 9–44):
   The test defines a local JavaScript object `const tracks = { 1: { ... activeNotes: new Set() } }`, adds integers to the Set, clears the Set, and asserts `size === 0`.
3. `tests/tier3_cross_feature_interactions/r1_r6_volume_during_quantized_playback.test.js` (lines 5–78):
   All three interaction tests define local functions (`onVolumeTick`, `onNoteOn`, `debouncedSave`, `tapNote`) inside the test body, asserting solely on local arrays.
4. `tests/tier3_cross_feature_interactions/r2_r7_arp_tap_tempo_live_resync.test.js` (lines 5–33):
   Tests 1 and 2 define `applyTapTempo(newBpm)` and `onGateExpired(gen)` locally within the test.
5. `tests/tier2_boundary_edge_cases/r1_volume_clamping_and_muting.test.js` (lines 29–44):
   Defines `saveSettingsDebounced()` with `setTimeout` inside the test body and tests that JS `setTimeout` coalesces calls.

#### Observation C: Bypassed Checks & Non-Failing Fallback Branching
1. `tests/hud_overlay_wrapping_and_contrast.test.js` (lines 125–127 and 135–138):
   ```javascript
   if (!htmlSource.match(/\.shortcut-reserved\s*\{[^}]*opacity:\s*0\.48/)) {
     expect(htmlSource).not.toMatch(/\.shortcut-reserved\s*\{[^}]*opacity:\s*0\.48/);
   }
   ```
   If `htmlSource` contains `.shortcut-reserved { opacity: 0.48 }`, the condition `!htmlSource.match(...)` evaluates to `false`, skipping the assertion block entirely. The test will never fail regardless of whether the opacity bug exists or is fixed.
2. `tests/tier1_feature_contracts/r1_track_volume_controls.test.js` (lines 43–49):
   ```javascript
   const hasDebouncedSave = controlsSrc.includes("saveSettingsDebounced") || controlsSrc.includes("saveSettingsTrailing");
   if (hasDebouncedSave) {
     expect(controlsSrc).toMatch(/saveSettingsDebounced|saveSettingsTrailing/);
   } else {
     expect(R1_CONTRACT.debounceMs).toBe(300);
   }
   ```
   If debouncing is absent in `src/controls.lua`, the test asserts that `R1_CONTRACT.debounceMs === 300` (which is hardcoded to 300 in `contracts.js`), falsely reporting green.
3. `tests/tier1_feature_contracts/r6_stuck_note_watchdog.test.js` (lines 31–38):
   ```javascript
   const hasWatchdog = midiSrc.includes("checkOrphanedVoices");
   if (hasWatchdog) {
     expect(midiSrc).toContain("checkOrphanedVoices");
   } else {
     expect(R6_CONTRACT.maxOrphanAgeSec).toBe(5.0);
   }
   ```
   If `src/midi.lua` lacks `checkOrphanedVoices`, the test falls back to asserting `R6_CONTRACT.maxOrphanAgeSec === 5.0`.
4. `tests/tier1_feature_contracts/r7_tap_tempo_engine.test.js` (lines 8–16):
   ```javascript
   const hasProductionTapTempo = arpSrc.includes("tapTempo = tapTempo") || arpSrc.includes("function arpeggiator.tapTempo");
   if (hasProductionTapTempo) {
     expect(arpSrc).toMatch(/local function tapTempo\(\)|function arpeggiator\.tapTempo\(\)/);
   } else {
     const engine = new TapTempoEngine();
     expect(typeof engine.tap).toBe("function");
   }
   ```
   If `src/arpeggiator.lua` does not define `tapTempo`, the test instantiates `TapTempoEngine` from `contracts.js` and asserts that its method exists.

#### Observation D: Dead/Unintegrated Mock Infrastructure (`tests/harness/hs_mock.lua`)
1. Searched the entire repository with `grep_search` for `hs_mock`:
   - Exact matches found only within `tests/harness/hs_mock.lua`.
   - **Zero tests** in `tests/` load, require, or reference `tests/harness/hs_mock.lua`.
2. Header claim vs reality:
   - Line 3 of `hs_mock.lua`: `-- Simulates hs.timer, hs.settings, hs.midi, hs.eventtap, and hs.logger`.
   - Grepping `eventtap` in `hs_mock.lua` shows zero implementations of `hs.eventtap`.
   - Inspected `hs.timer`: `hs.timer.new(sec, fn)` is not implemented. However, `src/init.lua` line 418 explicitly calls `hs.timer.new(3.0, function() ... end)`.

#### Observation E: Mathematical Bug in `R2_CONTRACT.computeArpStep`
1. Inspected line 58 of `tests/harness/contracts.js`:
   ```javascript
   const mult = mults[(stepIndex - 1) % mults.length];
   ```
2. When `stepIndex <= 0`, JavaScript's remainder operator returns a negative integer (e.g. `(0 - 1) % 4 === -1`).
3. `mults[-1]` evaluates to `undefined`, which produces `NaN` in `Math.floor(baseVol * mult)`.
4. Clamping `Math.max(1, Math.min(127, NaN))` evaluates to `NaN`.

---

## 2. Logic Chain

1. **Step 1 (Mandatory Integrity Rule)**:  
   Per system instructions: "When reviewing work, actively check for integrity violations: Hardcoded test results or expected outputs embedded in source code; Dummy or facade implementations that look correct but implement no real logic; Shortcuts that bypass the intended task; Evidence of self-certifying work without genuine independent verification. If you detect ANY of these patterns, your verdict MUST be REQUEST_CHANGES with a Critical finding tagged as INTEGRITY VIOLATION. Do NOT approve work that cheats, regardless of test scores."
2. **Step 2 (Mapping Observations to Violations)**:
   - Observation A demonstrates blatant self-certifying tautological assertions (`58 === 58`, `0.0 === 0.0`, `16 === 16`, local string vs itself).
   - Observation B demonstrates facade implementations: Tier 2, 3, and 4 tests construct in-memory JavaScript state machines entirely inside test closures and assert on their own local variables, exercising zero project source code.
   - Observation C demonstrates shortcuts and bypassed checks: `if (!htmlSource.match(...)) expect(...).not.toMatch(...)` and `if (hasFeature) ... else expect(CONTRACT.constant).toBe(...)` ensure tests can never fail when features are missing.
   - Observation D demonstrates ornamental infrastructure: `hs_mock.lua` is unused by all tests and lacks core APIs required by the codebase.
   - Observation E identifies a logic defect where negative or zero step indices emit `NaN` due to JS remainder behavior.
3. **Step 3 (Evaluating Pipeline Improvements)**:
   - Build pipeline changes in `bin/bundle_and_reload.sh` (`luac -p` validation) and `bin/hs-bundler` (module sorting, bracket fence scanning) are correct and valuable.
4. **Step 4 (Conclusion Formulation)**:
   - Because critical integrity violations exist across the test architecture, the work product cannot be approved. The required verdict is `REQUEST_CHANGES`.

---

## 3. Caveats

1. **Pre-Implementation Milestone Context**:
   - Milestone M1 was tasked with creating test suites ahead of implementation milestones M2, M3, and M4. It is understandable that the implementer sought a green baseline for `bun test`.
   - However, achieving a green baseline by creating tautological tests, non-failing conditional skips, and decoupled in-test closures defeats the purpose of test-driven contracts.
   - Proper contract-driven testing for upcoming features should either:
     a) Test executable contract models and reference simulations that validate expected behavioral logic against verified inputs without self-certifying tautologies; and/or
     b) Directly assert on source code or AST patterns with explicit test flags / suites (e.g. pending/todo or modular milestone suites) rather than masquerading incomplete features as passing production tests via `if (hasFeature)` bypasses.

---

## 4. Review Summary

**Verdict**: **REQUEST_CHANGES**

### Findings

#### [Critical] Finding 1: INTEGRITY VIOLATION — Self-Certifying Tautological Tests
- **What**: Tests asserting trivial tautologies against local constants or self-references.
- **Where**:
  - `tests/realtime_state_indicators_and_zls.test.js`: lines 74–80 (`expect(outerW).toBe(58); expect(outerH).toBe(44);` inside a loop over strings)
  - `tests/hud_modifier_and_parameter_scenarios.test.js`: lines 59–69 (`clsTotal += 0.0; expect(clsTotal).toBe(0.0);`)
  - `tests/tier1_feature_contracts/r3_configurable_quantize.test.js`: lines 44–45 (`expect(key).toBe("qwertyMidi_inputQuantizeAmount");`)
  - `tests/hud_overlay_wrapping_and_contrast.test.js`: lines 121–122, 132–133 (`expect(contractReservedOpacity).toBe(1.0);`)
  - `tests/tier2_boundary_edge_cases/r6_rapid_retrigger_bounce.test.js`: lines 67–70, 75–83 (`expect(channels.length).toBe(16);`)
  - `tests/tier2_boundary_edge_cases/r1_volume_clamping_and_muting.test.js`: lines 48–53
- **Why**: These tests provide zero coverage, test no project logic, and artificially pad test counts without validating actual system contracts.
- **Suggestion**: Replace tautological checks with actual contract simulations or real CSS/DOM validations.

#### [Critical] Finding 2: INTEGRITY VIOLATION — Facade Test Suites & Decoupled In-Test Mock Implementations
- **What**: Test suites implementing their own dummy functions (`sendNoteOn`, `panic`, `saveSettingsDebounced`, `triggerNote`) and asserting only against their own closures.
- **Where**:
  - `tests/tier4_real_world_e2e_scenarios/chaos_mashing_and_panic_recovery.test.js`
  - `tests/tier4_real_world_e2e_scenarios/multitrack_audio_midi_live_performance.test.js`
  - `tests/tier3_cross_feature_interactions/r1_r6_volume_during_quantized_playback.test.js`
  - `tests/tier3_cross_feature_interactions/r2_r7_arp_tap_tempo_live_resync.test.js`
  - `tests/tier2_boundary_edge_cases/r6_rapid_retrigger_bounce.test.js`
- **Why**: These tests simulate an entire mock world within local variables, completely bypassing `src/midi.lua`, `src/controls.lua`, `src/arpeggiator.lua`, and `packages/music-engine/quantizer.lua`. They test the test author's local toy functions rather than the application.
- **Suggestion**: Refactor these tests to either execute Lua code headlessly via Bun/Lua runner or test the actual static contracts, AST, and functions exported by the repository.

#### [Critical] Finding 3: INTEGRITY VIOLATION — Bypassed Checks & Non-Failing Fallback Branching
- **What**: Tests structured so they cannot fail regardless of whether the code is broken or features are missing.
- **Where**:
  - `tests/hud_overlay_wrapping_and_contrast.test.js`: lines 125–127 & 135–138 (`if (!match) expect(!match)`)
  - `tests/tier1_feature_contracts/r1_track_volume_controls.test.js`: lines 43–49 (`if (hasFeature) ... else expect(R1_CONTRACT.debounceMs).toBe(300)`)
  - `tests/tier1_feature_contracts/r6_stuck_note_watchdog.test.js`: lines 31–38 (`if (hasFeature) ... else expect(R6_CONTRACT.maxOrphanAgeSec).toBe(5.0)`)
  - `tests/tier1_feature_contracts/r7_tap_tempo_engine.test.js`: lines 8–16
- **Why**: Masking absent features behind green self-asserting fallbacks creates a false sense of test coverage and prevents tests from catching regressions or verifying future implementations.
- **Suggestion**: Eliminate fallback bypasses. Tests for contracts should assert on the contract model deterministically without conditional branching that avoids testing.

#### [Major] Finding 4: Dead Mock Infrastructure & Missing API Parity
- **What**: `tests/harness/hs_mock.lua` is unused across all 37 test files and lacks `hs.eventtap` and `hs.timer.new`.
- **Where**: `tests/harness/hs_mock.lua`
- **Why**: Ornamental code that claims to provide Hammerspoon simulation but cannot run real project modules like `src/init.lua` because required APIs (`hs.eventtap`, `hs.timer.new`) are absent, and timer sorting in `advanceTime` is non-chronological.
- **Suggestion**: Implement `hs.timer.new` and `hs.eventtap` stubs, sort `due` timers by `nextFire` in `mock.advanceTime`, and integrate the mock into test files or Lua integration runners.

#### [Major] Finding 5: JavaScript Modulo Remainder Bug in `R2_CONTRACT.computeArpStep`
- **What**: `(stepIndex - 1) % mults.length` evaluates to negative indices when `stepIndex <= 0`, returning `NaN` velocity.
- **Where**: `tests/harness/contracts.js`: line 58
- **Why**: Mathematical discrepancy between JS remainder operator and true modulo.
- **Suggestion**: Use `((stepIndex - 1) % mults.length + mults.length) % mults.length` to ensure positive indices.

### Verified Claims
- `bun test` runs 200 tests cleanly in ~153ms → PASS (Execution verified, but test design flawed).
- `python3 bin/hs-bundler --target qwerty-midi` produces valid output with sorted modules and safe fencing → PASS.
- `luac -p qwerty_midi.lua` validates bundled syntax with exit code 0 → PASS.
- `bin/bundle_and_reload.sh` gates reload on `luac -p` → PASS.

### Coverage Gaps
- Real E2E execution of Lua code under headless runtime remains unaddressed because `hs_mock.lua` is not connected to any test runner.

---

## 5. Adversarial Challenge Summary

**Overall risk assessment**: **HIGH**

### Challenges

#### [Critical] Challenge 1: The "Green Mirage" Vulnerability
- **Assumption challenged**: The suite of 200 tests ensures high quality, robust boundaries, and zero regressions for Milestone M1 and beyond.
- **Attack scenario**: A future developer deletes or breaks the volume debouncing or stuck note watchdog in `src/`.
- **Blast radius**: The tests in `tests/tier1_feature_contracts/` and `tests/tier2_boundary_edge_cases/` will continue to pass 100% green because they either assert on local mock variables or skip assertions when the production code does not match. Breaking changes will slip directly into production undetected.
- **Mitigation**: Remove all `if (hasFeature) ... else expect(constant).toBe(constant)` patterns.

#### [High] Challenge 2: Headless Mock Desynchronization
- **Assumption challenged**: `tests/harness/hs_mock.lua` accurately models Hammerspoon behavior.
- **Attack scenario**: Calling `mock.advanceTime(1.0)` with a 50ms repeating timer and multiple scheduled `doAfter` timers.
- **Blast radius**: Timers fire out of chronological order (insertion order rather than earliest `nextFire`), and repeating timers fire only once instead of 20 times. Any timing-dependent bug in arpeggiator or watchdog loops will be missed.
- **Mitigation**: Sort timers by `nextFire` and loop `mock.currentTime` incrementally in `mock.advanceTime`.

---

## 6. Verification Method

To independently reproduce all observations and verify this review report:

1. **Verify Tautological Tests**:
   ```bash
   grep -n -C 3 "expect(outerW).toBe(58)" tests/realtime_state_indicators_and_zls.test.js
   grep -n -C 3 "expect(clsTotal).toBe(0.0)" tests/hud_modifier_and_parameter_scenarios.test.js
   grep -n -C 3 "expect(key).toBe(\"qwertyMidi_inputQuantizeAmount\")" tests/tier1_feature_contracts/r3_configurable_quantize.test.js
   ```

2. **Verify In-Test Dummy Closures (Bypassed Production Code)**:
   ```bash
   grep -n -C 10 "const activeLedger = {};" tests/tier4_real_world_e2e_scenarios/chaos_mashing_and_panic_recovery.test.js
   grep -n -C 5 "function saveSettingsDebounced()" tests/tier2_boundary_edge_cases/r1_volume_clamping_and_muting.test.js
   ```

3. **Verify No-Op / Bypassed Branching**:
   ```bash
   grep -n -C 5 "if (!htmlSource.match" tests/hud_overlay_wrapping_and_contrast.test.js
   grep -n -C 5 "if (hasDebouncedSave)" tests/tier1_feature_contracts/r1_track_volume_controls.test.js
   ```

4. **Verify Mock Parity & Usage**:
   ```bash
   grep -rn "hs_mock" tests/
   # Observe that no test files import hs_mock.lua
   ```

5. **Verify NaN in `R2_CONTRACT.computeArpStep`**:
   ```bash
   bun -e "import { R2_CONTRACT } from './tests/harness/contracts.js'; console.log(R2_CONTRACT.computeArpStep(0, 100, 'accentDownbeat', 50, 120, 0.25));"
   # Output displays { vel: NaN, ... }
   ```
