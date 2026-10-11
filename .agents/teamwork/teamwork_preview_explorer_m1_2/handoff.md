# Handoff Report: HUD & UI Overlay Test Suite Design (R4, R5)

**Agent**: M1 Explorer 2 (HUD & UI Test Suite Design)  
**Working Directory**: `/Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_explorer_m1_2`  
**Date**: 2026-10-11  
**Milestone**: M1 (Test Infrastructure & Pipeline Hardening)  
**Handoff Type**: Hard  

---

## 1. Observation

### 1.1 CSS Geometry & Text Overflow
- **File**: `src/web/index.html:701-740`
  ```css
  .key-pad {
    width: 58px;
    height: 44px;
    background: rgba(25, 25, 25, 0.98);
    border: 1.5px solid rgba(55, 55, 55, 1.0);
    border-radius: 8px;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    transition: none;
    cursor: pointer;
    flex-shrink: 0;
    -webkit-app-region: no-drag;
    position: relative;
  }
  .key-pad .key-code {
    font-size: 12px;
    font-weight: 700;
    color: #f0f0f0;
    text-shadow: 0 1px 2px rgba(0, 0, 0, 0.8);
    pointer-events: none;
  }
  .key-pad .key-note {
    font-size: 9.5px;
    font-weight: 500;
    color: rgba(200, 200, 200, 0.9);
    margin-top: 1px;
    white-space: nowrap;
    text-shadow: 0 1px 2px rgba(0, 0, 0, 0.8);
    pointer-events: none;
  }
  ```
  `.key-note` enforces `white-space: nowrap;`, has no fixed height, no `max-width`, and no `overflow: hidden`.
- **File**: `src/hud.lua:220`
  `base = { name = "Smart Sus · 2× Off", class = "ctrl-sus", action = "sustain" }` (18 characters long, rendered width $\approx 96\text{px}$, exceeding the 55px inner pad width by $41\text{px}$).

### 1.2 "Pass Through" Clutter Under Cmd Modifier
- **File**: `src/hud.lua:948-971`
  ```lua
  if activeLayer == "cmd" or activeLayer == "cmdShift" then
    for code in pairs(COMMAND_LAYER_MAP) do
      if not keyUpdates[tostring(code)] then keyUpdates[tostring(code)] = { isControl = true, pressed = false } end
    end
    for code = 0, 127 do
      if config.getNoteKey and config.getNoteKey(code) and not keyUpdates[tostring(code)] then
        keyUpdates[tostring(code)] = { isControl = true, pressed = false }
      end
    end
    for codeStr, key in pairs(keyUpdates) do
      local code = tonumber(codeStr)
      local command = COMMAND_LAYER_MAP[code]
      local layerDef = command and command[activeLayer]
        or { name = "Pass Through", class = "shortcut-passthrough", action = "none", passThrough = true }
      key.displayNote = layerDef.name
      key.note = layerDef.name
      key.action = layerDef.action
      key.shiftAction = layerDef.action
      key.typeClass = layerDef.class or ""
      key.shortcutReserved = layerDef.reserved == true
      key.shortcutPassThrough = layerDef.passThrough == true
      key.isControl = true
    end
  end
  ```
- **File**: `src/hud.lua:520-532`
  `COMMAND_LAYER_MAP` defines only 8 keys: codes 46 (M), 12 (Q), 13 (W), 4 (H), 48 (Tab), 49 (Space), 1 (S), 6 (Z). All remaining 35+ keys receive `name = "Pass Through"`, filling the entire keyboard grid with redundant collision-prone labels.

### 1.3 Key Opacity & Contrast Degradation
- **File**: `src/web/index.html:1004-1012`
  ```css
  .shortcut-reserved {
    opacity: 0.48 !important;
    border-style: dashed !important;
    background-image: repeating-linear-gradient(135deg, transparent 0 5px, rgba(255,255,255,0.045) 5px 8px) !important;
  }
  .shortcut-passthrough {
    opacity: 0.4 !important;
    border-style: dotted !important;
  }
  ```
  Element-level opacity 0.48/0.40 dims active shortcuts against the dark chassis (`rgba(18, 18, 18, 0.97)`), lowering contrast below 2:1.

### 1.4 Parameter Telemetry Disconnected from Key Surfaces
- **File**: `src/hud.lua:366-375` (Keys 46: M, 43: `,`)
  Display static `"Vol -"` and `"Vol +"`.
- **File**: `src/hud.lua:1192-1201`
  Volume levels are computed (`topVolPercent`, `bottomVolPercent`) but dispatched only to `#vol-fill-top` and `#vol-fill-bottom` edge bars. Keys M and `,` never receive or display the active volume percentage.
- **File**: `src/hud.lua:250-515`
  Octave (Keys 2, 3), Rate (Key 22), Gate (Key 26), Dir (Key 23), Attack/Decay (Keys 25, 29), Root (Keys 4, 37), Mode (Keys 5, 41), and BPM (Keys 27, 24) all display static strings without active quantities.

### 1.5 Existing Test Patterns
- **File**: `tests/chord_display_and_layout_shift.test.js:35-59`
  Verifies ZLS using regex assertions for fixed dimensions (`width: 154px; min-width: 154px; max-width: 154px;`, `tabular-nums`).
- **File**: `tests/shortcut_visibility_and_sustain_off.test.js:28-36`
  Asserts that `PROPOSED_LAYOUT_MAP[48].ctrl` contains `'name = "Pass Through"'`.

---

## 2. Logic Chain

1. **Step 1 (Overflow Root Cause)**: Based on Observation 1.1, `.key-pad` inner width is 55px (58px outer minus 2x1.5px borders), but `.key-note` enforces `white-space: nowrap;` and lacks `max-width` and `overflow: hidden`. As observed in `src/hud.lua:220`, `"Smart Sus · 2× Off"` is 18 characters long ($\approx 96\text{px}$), causing horizontal overflow by $41\text{px}$.
2. **Step 2 (Clutter Escalation)**: Based on Observation 1.2, in Cmd modifier mode, 35+ unmapped keys simultaneously receive `"Pass Through"`. Combined with Step 1, adjacent 58px keys overlap their `"Pass Through"` text across borders, producing illegible clutter.
3. **Step 3 (Contrast Failure)**: Based on Observation 1.3, container-level `opacity: 0.48` on `.shortcut-reserved` and `0.40` on `.shortcut-passthrough` dims foreground text along with the container, producing a $<2:1$ contrast ratio against the dark background.
4. **Step 4 (Missing State Telemetry)**: Based on Observation 1.4, parameter states exist in memory and payload but are not appended to `displayNote` on keypads.
5. **Step 5 (ZLS Architecture Solution)**: By enforcing rigid bounds on `.key-note` (`white-space: pre-line; height: 20px; max-height: 20px; max-width: 52px; overflow: hidden; font-variant-numeric: tabular-nums;`), labels can receive two-line parameter formatting (`"{Action}\n{Value}"`) without altering `.key-code` vertical offset or `.key-pad` outer dimensions, achieving Cumulative Layout Shift = 0 (**ZLS = 0**).

---

## 3. Caveats

1. **Preservation of Non-Cmd Tab Pass-Through**:
   `tests/shortcut_visibility_and_sustain_off.test.js:30` tests `PROPOSED_LAYOUT_MAP[48].ctrl` for `name = "Pass Through"`. The suppression of redundant "Pass Through" labels must occur specifically when `activeLayer == "cmd"` or `"cmdShift"` (or in display formatting), leaving the `ctrl` layout table intact.
2. **KeyStep Lower-Row Reversion**:
   When KeyStep is disconnected, lower-row keys (codes 6..44, including Volume keys M and `,`) revert to note inputs. The volume telemetry assertions apply when KeyStep is connected or when dedicated volume keys are active.
3. **Headless Execution Environment**:
   All test suites execute in `bun test` without requiring native WebKit or Hammerspoon windowing. Geometric bounding and CSS rules are validated through direct source analysis, CSS parsing, and simulated DOM/canvas metrics.

---

## 4. Conclusion

The test suite design for R4 and R5 is fully specified across three test files comprising **50 concrete test cases** spanning Tiers 1 through 4:

1. **`tests/hud_overlay_wrapping_and_contrast.test.js` (18 test cases)**:
   - **Tier 1 (15 cases)**:
     - Feature 6: Wrapping CSS properties, 58x44 outer chassis, Smart Sus 2x Off line breaking, Minimize Window wrapping, text overflow prevention.
     - Feature 7: Cmd mode unmapped label suppression, mapped shortcut preservation in `COMMAND_LAYER_MAP`, webview empty/em-dash rendering, non-Cmd Ctrl+Tab contract preservation, visual density ratio $\le 0.25$.
     - Feature 8: Removal of `opacity: 0.48` on `.shortcut-reserved`, removal of `opacity: 0.40` on `.shortcut-passthrough`, active shortcut cyan/white high contrast, passthrough subdued background styling, WCAG AA contrast $\ge 4.5:1$.
   - **Tier 2 (3 cases)**:
     - Extreme label length ($>25$ chars) truncation/wrapping within 52px.
     - Emoji and Unicode symbols (`"Locrian 🌑"`, `"Lydian ☀️"`, `"Near Root ↑"`) preserving 20px container height.
     - Cmd+Shift layer clutter suppression.
2. **`tests/realtime_state_indicators_and_zls.test.js` (22 test cases)**:
   - **Tier 1 (14 cases)**:
     - Feature 9 (Parameter Telemetry): All 9 parameters tested (Volume, Octave, Arp Rate, Arp Gate, Arp Direction, Attack/Decay, Musical Root, Scale/Mode, BPM Tempo).
     - Feature 9 (ZLS Contracts): Key pad outer dimensions 58px x 44px invariant, Key code vertical offset invariant ($\Delta Y = 0$), Key note container rigidly clamped to 20px with overflow hidden, tabular figures preventing digit jitter, row margin-left invariants.
   - **Tier 2 (8 cases)**:
     - Volume boundaries (0% vs 100%), BPM boundaries (30 vs 300 BPM), Octave offset boundaries (-3, 0, +3), longest mode names (`"Mixolydian"`), oscillation stress testing under parameter jitter.
3. **`tests/hud_modifier_and_parameter_scenarios.test.js` (10 test cases)**:
   - **Tier 3 (4 cases)**:
     - Cmd modifier engagement suppressing unmapped keys while active parameters remain on mapped keys.
     - Shift hold switching parameter controls from primary to secondary (Atk -> Dec, Main Vol -> Bot Vol) with ZLS=0.
     - Active track switching (1->2->3->4) updating colors and parameter states with ZLS=0.
     - Compound long labels under dynamic parameter changes.
   - **Tier 4 (6 cases)**:
     - Live jam performance: simultaneous polyphonic note input, arp clocking, and parameter tweaks with zero text overflow and zero layout shift.
     - Rapid modifier macro cycling (`base` -> `shift` -> `cmd` -> `cmdShift` -> `base`).
     - 4-Track studio workflow: independent parameter recall and track card isolation.
     - Chaos stress test: 100 rapid state updates alternating parameters, modifiers, and keypresses in $<5\text{ms}$ per frame with CLS = 0.

---

## 5. Verification Method

1. **Automated Test Execution**:
   ```bash
   bun test
   ```
   All existing 77 tests must continue to pass without regression.
2. **New Test Suite Execution (when implemented in M4)**:
   ```bash
   bun test tests/hud_overlay_wrapping_and_contrast.test.js
   bun test tests/realtime_state_indicators_and_zls.test.js
   bun test tests/hud_modifier_and_parameter_scenarios.test.js
   ```
   All 50 test cases must exit with status 0.
3. **Build & Bundle Verification**:
   ```bash
   bash bin/bundle_and_reload.sh
   luac -p qwerty_midi.lua
   ```
   Ensures that `src/web/index.html` syncs to `src/ui_html.lua` and compiles cleanly into `qwerty_midi.lua`.
4. **Visual Invalidation Conditions**:
   - Any key label text spilling beyond 58px key boundaries horizontally.
   - `.key-code` moving vertically when parameter values change.
   - Repetition of `"Pass Through"` text across unmapped keys in Cmd modifier mode.
   - Active Cmd shortcuts rendered with $< 4.5:1$ contrast against the dark HUD chassis.
