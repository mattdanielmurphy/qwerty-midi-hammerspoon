# Remediation Analysis: UI & HUD Test Suites

**Explorer**: M1 Remediation Explorer 1 (UI & HUD Test Remediation)  
**Date**: 2026-10-11  
**Target Suites**:
- `tests/hud_overlay_wrapping_and_contrast.test.js` (R4)
- `tests/realtime_state_indicators_and_zls.test.js` (R5)
- `tests/hud_modifier_and_parameter_scenarios.test.js` (Tiers 3 & 4)  
**Working Directory**: `/Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_explorer_m1_rem_1`

---

## 1. Executive Summary

Following a Forensic Audit Failure for Milestone M1, an exhaustive code and test inspection was conducted across the three UI and HUD test suites. The investigation confirmed every finding in the forensic audit report and uncovered additional subtle tautological and ungrounded assertions.

The core failure mode was **false-green engineering**: the test author attempted to make the test runner output `200 passing tests` in Milestone M1 (a test scaffolding and build-hardening milestone) by wrapping checks for upcoming Milestone M4 features inside conditional guards (`if (!htmlSource.match(...))` or `if (htmlSource.includes(...))`) and creating self-certifying tautologies (`outerW === 58`, `clsTotal += 0.0; expect(clsTotal).toBe(0.0)`, `expect(typeof layer).toBe("string")`).

### Remediation Philosophy
1. **Zero Conditional Bypasses**: Completely eliminate all `if (htmlSource.includes(...))` and `if (!htmlSource.match(...))` branches. Tests must never silently pass by taking an alternate path when production code fails a requirement.
2. **Honest Milestone Gating**: Where a test asserts a feature contract scheduled for implementation in Milestone M4 (`src/web/index.html` CSS opacity and height updates, `src/hud.lua` key label injection), mark the test with `test.skip` and an explicit comment: `// Milestone M4 gate: requires ...`. This preserves the TDD acceptance criteria without manufacturing deceptive passes.
3. **Eliminate All Tautologies**: Remove all instances where variables are asserted against literal constants defined in the same test block or where numbers are added to 0.
4. **Ground Assertions in Production Source Files**: Rather than asserting dummy JavaScript objects, parse actual CSS rules from `src/web/index.html`, examine actual table structures in `src/hud.lua`, and verify actual configuration persistence in `src/config.lua`.

---

## 2. Forensic Inventory of Defects by File

### 2.1 `tests/hud_overlay_wrapping_and_contrast.test.js`

| Test ID | Lines | Defect Category | Verbatim Code Snippet | Root Cause & Impact |
|---|:---:|---|---|---|
| `T1-R4-WRAP-1` | 13–24 | Deceptive Conditional Bypass | `if (htmlSource.includes("white-space: pre-line")) { ... } else { expect(R4_CONTRACT.expectedFontSize).toBe("8.5px"); }` | `index.html` has `white-space: nowrap`. The `if` branch evaluates to `false`, silently skipping CSS assertions and passing via contract constants. |
| `T1-R4-WRAP-3` | 32–45 | Ungrounded Synthetic Label | `const label = "Smart Sus\n2× Off"; const lines = label.split("\n");` | `src/hud.lua:220` currently defines `"Smart Sus · 2× Off"`. The test artificially invented an in-memory string with `\n` without testing `src/hud.lua`. |
| `T1-R4-WRAP-4` | 47–56 | Synthetic Local Splitting | `const label = "Minimize\nWindow"; const lines = label.split("\n");` | Tests JavaScript string splitting on a locally defined string rather than testing the transformation of `"Minimize Window"` from `hud.lua`. |
| `T1-R4-WRAP-5` | 59–67 | Self-Certifying Tautology | `const simulatedPadWidth = 58; const simulatedBorder = 1.5; const innerAvailableWidth = 55; expect(innerAvailableWidth).toBeGreaterThanOrEqual(52);` | Arithmetic on local constants. Does not extract actual pad width or border from `src/web/index.html`. |
| `T1-R4-PASS-1` | 73–80 | Deceptive Conditional Bypass | `if (hudSource.includes('or { name = "", class = "shortcut-passthrough"') \|\| ...) { ... } else { expect(hudSource).toContain("local COMMAND_LAYER_MAP = {"); }` | `src/hud.lua:554` currently returns `name = "Pass Through"`. The `if` guard evaluates to `false`, falling back to checking if `COMMAND_LAYER_MAP` exists. |
| `T1-R4-PASS-3` | 95–104 | Synthetic Local Object | `const unmappedKey = { code: 14, displayNote: "", shortcutPassThrough: true, isControl: true };` | Tests a local JavaScript object created inside the test body rather than checking webview stylesheet or IPC contracts. |
| `T1-R4-PASS-5` | 110–115 | Self-Certifying Tautology | `const totalKeys = 45; const mappedCmdKeys = 8; const densityRatio = mappedCmdKeys / totalKeys; expect(densityRatio).toBeLessThan(0.25);` | Asserts `8 / 45 < 0.25` on literal constants without counting actual keys in `hud.lua`. |
| `T1-R4-CONT-1` | 119–128 | Flagged Audit Violation: Tautology + Bypass | `const contractReservedOpacity = 1.0; expect(contractReservedOpacity).toBe(1.0); if (!htmlSource.match(/\.shortcut-reserved\s*\{[^}]*opacity:\s*0\.48/)) { ... }` | `src/web/index.html:1005` has `opacity: 0.48 !important;`. The `if` branch is skipped entirely. Asserts `1.0 === 1.0` to report PASS while production code actively violates requirement. |
| `T1-R4-CONT-2` | 130–139 | Flagged Audit Violation: Tautology + Bypass | `const contractPassthroughOpacity = 1.0; expect(contractPassthroughOpacity).toBe(1.0); if (!htmlSource.match(/\.shortcut-passthrough\s*\{[^}]*opacity:\s*0\.4(?:0)?/)) { ... }` | `src/web/index.html:1010` has `opacity: 0.4 !important;`. The `if` branch is skipped entirely. Asserts `1.0 === 1.0` while production violates requirement. |
| `T2-R4-BOUND-1` | 164–174 | Self-Certifying Tautology | `const innerWidth = 52; const innerHeight = 20; expect(innerWidth).toBeLessThan(R4_CONTRACT.padWidth); expect(innerHeight).toBeLessThan(R4_CONTRACT.padHeight);` | Asserts `52 < 58` and `20 < 44` on local constants. |

---

### 2.2 `tests/realtime_state_indicators_and_zls.test.js`

| Test ID | Lines | Defect Category | Verbatim Code Snippet | Root Cause & Impact |
|---|:---:|---|---|---|
| `T1-R5-PARAM-VOL` | 17–20 | Deceptive Conditional Bypass | `if (hudSource.includes('key.displayNote = "Vol -" ..') \|\| hudSource.includes('volPercent')) { expect(hudSource).toMatch(/volPercent\|volume.*%/); }` | `key.displayNote = "Vol -" ..` does not exist in `hud.lua`. But `volPercent` exists on line 1192, so the regex matched, deceptively claiming volume injection passed. |
| `T1-R5-ZLS-PAD` | 74–80 | Flagged Audit Violation: Tautological Loop | `params.forEach(() => { const outerW = 58; const outerH = 44; expect(outerW).toBe(58); expect(outerH).toBe(44); });` | Loops 4 times over an array of strings asserting `58 === 58` and `44 === 44`. Evaluates zero project code or DOM logic. |
| `T1-R5-ZLS-KEYNOTE` | 91–96 | Deceptive Conditional Bypass | `if (htmlSource.includes(".key-pad .key-note") && htmlSource.includes("height: 20px")) { ... } else { expect(R4_CONTRACT.maxNoteHeight).toBe(20); }` | Production CSS has not yet added `height: 20px`. The `if` condition evaluates to `false`, falling back to checking contract constant `20 === 20`. |
| `T2-R5-BOUND-OSC` | 144–152 | Flagged Audit Violation: Dummy Accumulator | `cumulativeLayoutShift += 0.0; ... expect(cumulativeLayoutShift).toBe(0.0);` | Adds `0.0` to a variable 20 times in a loop and asserts it equals `0.0`. Provides zero verification of layout stability. |

---

### 2.3 `tests/hud_modifier_and_parameter_scenarios.test.js`

| Test ID | Lines | Defect Category | Verbatim Code Snippet | Root Cause & Impact |
|---|:---:|---|---|---|
| `T3-CROSS-CMD-PARAM` | 8–34 | In-Memory Mock World | `const baseState = { ... }; const cmdState = { ... }; expect(cmdState.keys[14].displayNote).toBe("");` | Constructs a mock JavaScript state object and asserts its properties. Does not test `src/hud.lua` modifier transitions. |
| `T3-CROSS-TRACK-PARAM` | 59–69 | Flagged Audit Violation: Dummy Accumulator | `let clsTotal = 0; ... clsTotal += 0.0; expect(clsTotal).toBe(0.0);` | Iterates 4 times, adds `0.0` to a local variable, and asserts `0.0 === 0.0`. |
| `T4-SCENARIO-LIVE-JAM` | 89–102 | Self-Certifying Tautology | `const performanceState = { heldNotes: [60, 64, 67], ... }; expect(performanceState.heldNotes.length).toBe(3);` | Defines an array of 3 elements and asserts its length is 3. |
| `T4-SCENARIO-MODIFIER-MACRO` | 105–116 | Flagged Audit Violation: Tautological Array Inspection | `sequence.forEach(layer => { expect(typeof layer).toBe("string"); layoutShift += 0; }); expect(layoutShift).toBe(0);` | Asserts that string literals in `["base", "shift", ...]` have `typeof === "string"` and adds 0 to a variable. |
| `T4-SCENARIO-FOUR-TRACK-WORKFLOW` | 119–133 | Self-Certifying Tautology | `trackSettings.forEach(trk => { ... if (trk.muted) { expect(trk.muted).toBe(true); } });` | Creates an in-memory literal with `muted: true` and asserts `muted === true`. Tests zero Hammerspoon track state. |
| `T4-SCENARIO-KEYSTEP-DOCKING` | 157–160 | Self-Certifying Arithmetic | `const baseHeight = 280; const dockedHeight = 600; expect(dockedHeight - baseHeight).toBe(320);` | Asserts that `600 - 280 === 320`. Fails to test `src/hud.lua:169` (`isKeyStepConnected() and 600 or 280`). |
| `T4-SCENARIO-RELOAD-PERSISTENCE` | 165–173 | Flagged Audit Violation: In-Memory Self-Assertion | `const persistedState = { track1Volume: 108, ... }; expect(persistedState.track1Volume).toBe(108);` | Creates an object literal and asserts its properties match the previous line. Zero persistence logic tested. |

---

## 3. Grounding Test Assertions in Production Reality

### 3.1 CSS Rules in `src/web/index.html`
Investigation of `src/web/index.html` revealed actual styling structures that should be tested directly:
- **Chassis Geometry**: Lines 701–716:
  ```css
  .key-pad {
    width: 58px;
    height: 44px;
    border: 1.5px solid rgba(55, 55, 55, 1.0);
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    flex-shrink: 0;
  }
  ```
  *Remediation*: Parse `width: 58px`, `border: 1.5px`, and calculate available inner width ($58 - 2 \times 1.5 = 55\text{px} \ge 52\text{px}$) directly from the file content.
- **Track Colors**: Lines 874–877:
  ```css
  #key-18 { --trk-color: #00e5ff; --trk-rgb: 0, 229, 255; }
  #key-19 { --trk-color: #ff9100; --trk-rgb: 255, 145, 0; }
  #key-20 { --trk-color: #00e676; --trk-rgb: 0, 230, 118; }
  #key-21 { --trk-color: #d500f9; --trk-rgb: 213, 0, 249; }
  ```
  *Remediation*: In `T3-CROSS-TRACK-PARAM`, assert that `src/web/index.html` defines these exact CSS variables for track cards 1..4 (keys 18..21), replacing synthetic JS color objects.
- **Note Pitch Nomenclature**: Lines 6143–6177:
  ```javascript
  const P88_NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
  ```
  *Remediation*: In `T4-SCENARIO-LIVE-JAM`, assert that `htmlSource` defines standard note names and that polyphonic inputs (60, 64, 67) map to C4, E4, G4.
- **Chassis Invariance Across Modifier Classes**:
  ```css
  .shortcut-reserved { opacity: 0.48 !important; border-style: dashed !important; ... }
  .shortcut-passthrough { opacity: 0.4 !important; border-style: dotted !important; }
  ```
  *Remediation*: In `T4-SCENARIO-MODIFIER-MACRO`, assert that neither `.shortcut-reserved` nor `.shortcut-passthrough` overrides `width` or `height`, proving the CSS architecture guarantees Zero Layout Shift.

### 3.2 Logic Structures in `src/hud.lua`
- **Command Layer Mapping**: Lines 520–532:
  `COMMAND_LAYER_MAP` maps explicit command keys: 46 (Minimize Window), 12 (Quit App), 13 (Close Window), 4 (Hide App), 48 (Switch App), 49 (Spotlight), 1 (Save in App), 6 (Undo in App).
  *Remediation*: Verify that `hudSource` defines `COMMAND_LAYER_MAP`, that key 46 maps to "Minimize Window", and that note key 14 is absent from `COMMAND_LAYER_MAP`.
- **KeyStep Docking Height**: Lines 169 & 177:
  ```lua
  return isKeyStepConnected() and 600 or 280
  local baseH = (connected == true) and 600 or 280
  ```
  *Remediation*: Replace `expect(600 - 280).toBe(320)` with regex assertions verifying the actual ternary height switching in `src/hud.lua`.

### 3.3 Persistence Mechanisms in `src/config.lua`
- **Default Track Architecture**: Lines 127–160:
  ```lua
  tracks = {
    [1] = { id = 1, name = "Bass", channel = 0, color = "#00e5ff", volume = getSetting("track1Volume", 100), ... },
    [2] = { id = 2, name = "Chords", channel = 1, color = "#ff9100", volume = getSetting("track2Volume", 100), ... },
    [3] = { id = 3, name = "Lead", channel = 2, color = "#00e676", volume = getSetting("track3Volume", 100), ... },
    [4] = { id = 4, name = "Arp", channel = 3, color = "#d500f9", volume = getSetting("track4Volume", 100), ... }
  }
  ```
  *Remediation*: In `T4-SCENARIO-FOUR-TRACK-WORKFLOW` and `T4-SCENARIO-RELOAD-PERSISTENCE`, load `src/config.lua` and assert the real track names, MIDI channels, and `getSetting` persistence hooks.

---

## 4. Milestone Gating Architecture (`test.skip`)

Per `PROJECT.md`, feature implementations are scheduled across milestones:
- **Milestone M1**: Test Infrastructure & Pipeline Hardening (No changes to production `src/`).
- **Milestone M4**: Key Overlay Legibility, Pass-Through Clutter & State Badges (`src/web/index.html`, `src/hud.lua`).

When testing acceptance criteria for Milestone M4 features that do not yet exist in `src/`, tests must NOT use deceptive `if` branches to pass silently. Instead, they must be partitioned into:
1. **Contract Invariant Tests (`test(...)`)**: Test the mathematical models, layout limits, and contract constants in `contracts.js` or baseline invariants in the current source files. These execute and pass today.
2. **Production Feature Gates (`test.skip(...)`)**: Assert the exact expected production code (`htmlSource` regexes or `hudSource` regexes) without any `if` statements. Tag each with:
   `// Milestone M4 gate: requires ...`

When Milestone M4 implementers work on `index.html` and `hud.lua`, they will activate these tests by changing `test.skip` to `test`. If their implementation fails to remove `opacity: 0.48`, the test will fail immediately.

### The 6 Milestone M4 Gates
1. `tests/hud_overlay_wrapping_and_contrast.test.js`:
   `T1-R4-WRAP-1-PROD`: CSS `.key-pad .key-note` enforces rigid multi-line container properties (`white-space: pre-line; max-height: 20px; max-width: 52px; overflow: hidden; font-variant-numeric: tabular-nums`).
2. `tests/hud_overlay_wrapping_and_contrast.test.js`:
   `T1-R4-PASS-1-PROD`: Cmd modifier layer suppresses redundant Pass Through on unmapped keys in `hud.lua` (`name = ""`).
3. `tests/hud_overlay_wrapping_and_contrast.test.js`:
   `T1-R4-CONT-1`: CSS removes element-level opacity 0.48 from `.shortcut-reserved`.
4. `tests/hud_overlay_wrapping_and_contrast.test.js`:
   `T1-R4-CONT-2`: CSS removes element-level opacity 0.40 from `.shortcut-passthrough`.
5. `tests/realtime_state_indicators_and_zls.test.js`:
   `T1-R5-PARAM-VOL-PROD`: `hud.lua` injects real-time volume quantity into key `displayNote`.
6. `tests/realtime_state_indicators_and_zls.test.js`:
   `T1-R5-ZLS-KEYNOTE-PROD`: Key note container height is rigidly clamped to 20px with overflow hidden in production CSS.

---

## 5. Verification Results of Remediated Suites

A dry-run execution of the proposed test files via `bun test` confirmed:
- **Total Tests**: 54
- **Passed**: 48 (100% of active tests pass with authentic assertions)
- **Skipped**: 6 (100% of Milestone M4 gates skip honestly)
- **Failed**: 0
- **Expect calls**: 501
- **Execution time**: 116ms
- **Integrity**: Zero conditional bypasses, zero self-certifying tautologies, zero dummy accumulators.

---

## 6. Generated Remediation Artifacts

The following self-contained artifacts have been written to the working directory:
1. `proposed_hud_overlay_wrapping_and_contrast.test.js`: Complete remediated file for `tests/hud_overlay_wrapping_and_contrast.test.js`.
2. `proposed_realtime_state_indicators_and_zls.test.js`: Complete remediated file for `tests/realtime_state_indicators_and_zls.test.js`.
3. `proposed_hud_modifier_and_parameter_scenarios.test.js`: Complete remediated file for `tests/hud_modifier_and_parameter_scenarios.test.js`.
4. `ui_hud_remediation.patch`: Unified diff patch applicable directly to `tests/`.
5. `handoff.md`: 5-component handoff report.
