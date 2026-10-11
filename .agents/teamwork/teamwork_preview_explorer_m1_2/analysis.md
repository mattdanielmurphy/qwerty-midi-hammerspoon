# Analysis: HUD & UI Overlay Test Suite Design (R4, R5)

**Agent**: M1 Explorer 2 (HUD & UI Test Suite Design)  
**Working Directory**: `/Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_explorer_m1_2`  
**Date**: 2026-10-11  
**Milestone**: M1 (Test Infrastructure & Pipeline Hardening)  

---

## 1. Executive Summary

This document specifies the concrete test suites for the HUD & UI Overlay requirements (**R4: Key Overlay Legibility & Label Wrapping** and **R5: Real-Time State Indicators on Keys**) of `qwerty-midi-hammerspoon`.

The test suites are designed to execute under `bun test` in headless Node/Bun environments, adhering to the opaque-box, requirement-driven methodology outlined in `TEST_INFRA.md` and `ORIGINAL_REQUEST.md`.

### Core Requirements Covered
1. **R4 (Key Overlay Legibility & Text Wrapping)**:
   - CSS `.key-pad .key-note` styles: `white-space: pre-line`, fixed 20px height, 52px max-width, `overflow: hidden`, and `font-variant-numeric: tabular-nums`.
   - Multi-line wrapping of long labels (e.g. `"Smart Sus · 2× Off"`, `"Minimize Window"`) within 58px key boundaries without horizontal spilling.
   - Suppression of redundant `"Pass Through"` clutter across unmapped keys in Cmd modifier mode.
   - Modifier contrast repair: removal of element-level container opacity (`0.48`/`0.40`) on `.shortcut-reserved` and `.shortcut-passthrough`, establishing crisp high-contrast active shortcuts ($>4.5:1$ contrast ratio).
2. **R5 (Real-Time State Indicators & Zero Layout Shift)**:
   - Injection of 9 active parameter quantities directly into key labels:
     1. Volume (`volDown`/`volUp`, Keys 46, 43): e.g. `"Vol -\n80%"`
     2. Octave (`octaveDown`/`octaveUp`, Keys 2, 3): e.g. `"Oct +\n+1"`
     3. Arp Rate (`arpRateUp`/`arpRateDown`, Key 22): e.g. `"Rate +\n1/16"`
     4. Arp Gate (`arpGateUp`/`arpGateDown`, Key 26): e.g. `"Gate +\n80%"`
     5. Arp Direction (`arpDirUp`/`arpDirDown`, Key 23): e.g. `"Dir +\nUp"`
     6. Attack & Decay (`atkDown`/`atkUp`, `decDown`/`decUp`, Keys 25, 29): e.g. `"Atk -\n10"`, `"Dec -\n64"`
     7. Root Pitch (`rootDown`/`rootUp`, Keys 4, 37): e.g. `"Root -\nC"`
     8. Scale / Mode (`modeDown`/`modeUp`, Keys 5, 41): e.g. `"Mode -\nMajor"`
     9. BPM Tempo (`bpmDown`/`bpmUp`, Keys 27, 24): e.g. `"BPM -\n120"`
   - Zero Layout Shift (**ZLS = 0**): verification that `.key-code` vertical offset and `.key-pad` outer dimensions remain completely invariant regardless of parameter values.

---

## 2. Test Suite Architecture & File Layout

Three dedicated test suites are designed to cover Tiers 1 through 4:

| Test File Path | Scope | Feature Coverage | Planned Test Cases |
|---|---|---|:---:|
| `tests/hud_overlay_wrapping_and_contrast.test.js` | R4: Wrapping, Pass-Through, Contrast | Features 6, 7, 8 (Tiers 1 & 2) | 18 |
| `tests/realtime_state_indicators_and_zls.test.js` | R5: State Injection & ZLS Invariant | Feature 9 (Tiers 1 & 2) | 22 |
| `tests/hud_modifier_and_parameter_scenarios.test.js` | R4 × R5 Cross-Feature & E2E Workflows | Features 6–9 (Tiers 3 & 4) | 10 |
| **Total** | | | **50** |

---

## 3. Detailed Specification: Suite 1 (`tests/hud_overlay_wrapping_and_contrast.test.js`)

### Tier 1: Feature Coverage (Happy Path & Contracts)

#### Feature 6: Key Overlay Multi-line Wrapping
- **`T1-R4-WRAP-1`**: `CSS .key-pad .key-note enforces rigid multi-line container properties`
  - **Target**: `src/web/index.html` CSS rules.
  - **Input**: Inspect CSS declaration for `.key-pad .key-note`.
  - **Assertions**:
    ```javascript
    expect(htmlSource).toMatch(/\.key-pad\s+\.key-note\s*\{[^}]*white-space:\s*pre-line/);
    expect(htmlSource).toMatch(/\.key-pad\s+\.key-note\s*\{[^}]*height:\s*20px/);
    expect(htmlSource).toMatch(/\.key-pad\s+\.key-note\s*\{[^}]*max-height:\s*20px/);
    expect(htmlSource).toMatch(/\.key-pad\s+\.key-note\s*\{[^}]*max-width:\s*52px/);
    expect(htmlSource).toMatch(/\.key-pad\s+\.key-note\s*\{[^}]*overflow:\s*hidden/);
    expect(htmlSource).toMatch(/\.key-pad\s+\.key-note\s*\{[^}]*font-variant-numeric:\s*tabular-nums/);
    ```
- **`T1-R4-WRAP-2`**: `CSS .key-pad maintains rigid 58px x 44px outer chassis geometry`
  - **Target**: `src/web/index.html` CSS rules.
  - **Input**: Inspect CSS declaration for `.key-pad`.
  - **Assertions**:
    ```javascript
    expect(htmlSource).toMatch(/\.key-pad\s*\{[^}]*width:\s*58px/);
    expect(htmlSource).toMatch(/\.key-pad\s*\{[^}]*height:\s*44px/);
    expect(htmlSource).toMatch(/\.key-pad\s*\{[^}]*flex-shrink:\s*0/);
    ```
- **`T1-R4-WRAP-3`**: `Smart Sus 2x Off label is formatted with newline break to fit 52px container`
  - **Target**: `src/hud.lua` and `src/config.lua` key 48 definition.
  - **Input**: Key 48 (Tab) base action configuration.
  - **Assertions**:
    - Either `name = "Smart Sus\n2× Off"` or runtime display breaks "Smart Sus" and "2× Off" into two lines.
    - Simulated text width of each line $\le 52\text{px}$ (character count $\le 9$).
    - Rendered height consumed $\le 20\text{px}$.
- **`T1-R4-WRAP-4`**: `Cmd modifier Minimize Window label wraps within 52px key note width`
  - **Target**: `COMMAND_LAYER_MAP[46].cmd` in `src/hud.lua`.
  - **Input**: Cmd layer definition for key 46 (M).
  - **Assertions**:
    - Name is `"Minimize Window"` or `"Minimize\nWindow"`.
    - Words break into "Minimize" (8 chars $\approx 42\text{px} < 52\text{px}$) and "Window" (6 chars $\approx 32\text{px} < 52\text{px}$).
    - Total line height for 2 lines at 9.5px is $19\text{px} \le 20\text{px}$.
- **`T1-R4-WRAP-5`**: `Multi-line text rendering does not cause horizontal text overflow or scrollbar`
  - **Target**: Simulated DOM element with `.key-note` styles.
  - **Input**: Set `textContent = "Smart Sus\n2× Off"`.
  - **Assertions**:
    - `scrollWidth <= clientWidth` (or simulated width $\le 52\text{px}$).
    - `scrollHeight <= 20px`.
    - No horizontal spilling past 58px `.key-pad` outer boundary.

#### Feature 7: "Pass Through" Clutter Elimination
- **`T1-R4-PASS-1`**: `Cmd modifier layer suppresses redundant Pass Through on unmapped keys in hud.lua`
  - **Target**: `src/hud.lua` lines 948–971 (`if activeLayer == "cmd" or activeLayer == "cmdShift"`).
  - **Input**: `activeLayer = "cmd"`.
  - **Assertions**:
    - Unmapped keys (not in `COMMAND_LAYER_MAP`) receive `displayNote = ""` or `displayNote = "—"`.
    - Unmapped keys do NOT receive `displayNote = "Pass Through"`.
    - `key.shortcutPassThrough = true` is preserved.
- **`T1-R4-PASS-2`**: `Explicit shortcuts in COMMAND_LAYER_MAP retain descriptive action labels`
  - **Target**: `COMMAND_LAYER_MAP` in `src/hud.lua`.
  - **Input**: Inspect all 8 mapped keys (codes 46, 12, 13, 4, 48, 49, 1, 6).
  - **Assertions**:
    - Key 46 (M): `"Minimize Window"`
    - Key 12 (Q): `"Quit App"`
    - Key 13 (W): `"Close Window"`
    - Key 4 (H): `"Hide App"`
    - Key 48 (Tab): `"Switch App"`
    - Key 49 (Space): `"Spotlight"`
    - Key 1 (S): `"Save in App"`
    - Key 6 (Z): `"Undo in App"`
    - Each has `reserved = true` or `class = "ctrl-window"` / `"shortcut-reserved"`.
- **`T1-R4-PASS-3`**: `Webview renderHud renders blank or em-dash on unmapped passthrough keys`
  - **Target**: `renderHud(data)` in `src/web/index.html`.
  - **Input**: `data.keys` with `shortcutPassThrough = true` and `displayNote = ""`.
  - **Assertions**:
    - `noteEl.textContent` renders empty string `""` or `"—"`.
    - `el.classList.contains('shortcut-passthrough')` is true.
    - Total count of keys displaying `"Pass Through"` in Cmd mode is 0.
- **`T1-R4-PASS-4`**: `Control+Tab contract preserves Pass Through in non-Cmd modifier layer`
  - **Target**: `PROPOSED_LAYOUT_MAP[48].ctrl` in `src/hud.lua`.
  - **Input**: Key 48 in `ctrl` layer.
  - **Assertions**:
    - Retains `name = "Pass Through"`.
    - Retains `action = "none"`.
    - Complies with `tests/shortcut_visibility_and_sustain_off.test.js`.
- **`T1-R4-PASS-5`**: `Cmd modifier mode isolates shortcut visual density without wall-to-wall clutter`
  - **Target**: Keyboard overlay in Cmd mode.
  - **Input**: Calculate ratio of keys with visible labels vs total keys.
  - **Assertions**:
    - Labeled keys $\le 10$ out of 45+ keys ($\le 22\%$ visual density).
    - Eliminates $78\%+$ visual clutter across unmapped key surfaces.

#### Feature 8: Modifier Contrast & Opacity
- **`T1-R4-CONT-1`**: `CSS removes element-level opacity 0.48 from .shortcut-reserved`
  - **Target**: `src/web/index.html` CSS rules.
  - **Input**: Inspect `.shortcut-reserved` rule.
  - **Assertions**:
    ```javascript
    expect(htmlSource).not.toMatch(/\.shortcut-reserved\s*\{[^}]*opacity:\s*0\.48/);
    expect(htmlSource).toMatch(/\.shortcut-reserved\s*\{[^}]*opacity:\s*1(?:\.0)?/);
    ```
- **`T1-R4-CONT-2`**: `CSS removes element-level opacity 0.40 from .shortcut-passthrough`
  - **Target**: `src/web/index.html` CSS rules.
  - **Input**: Inspect `.shortcut-passthrough` rule.
  - **Assertions**:
    ```javascript
    expect(htmlSource).not.toMatch(/\.shortcut-passthrough\s*\{[^}]*opacity:\s*0\.4(?:0)?/);
    ```
- **`T1-R4-CONT-3`**: `Active shortcut keys feature high-contrast text and border styling`
  - **Target**: `src/web/index.html` CSS rules for `.shortcut-reserved`.
  - **Input**: Inspect text color and border properties.
  - **Assertions**:
    - Color is high contrast cyan (`#64d8f0` or `#00e5ff`) or white (`#ffffff`).
    - Border is dashed with contrast accent.
- **`T1-R4-CONT-4`**: `Passthrough keys achieve subdued appearance via background color not opacity`
  - **Target**: `src/web/index.html` CSS rules for `.shortcut-passthrough`.
  - **Input**: Inspect background and code color properties.
  - **Assertions**:
    - Subdued dark background (e.g. `rgba(22, 22, 22, 0.6)`).
    - Subdued gray code color (`#777777` or `#666666`).
    - No container-level `opacity: 0.4` washing out child elements.
- **`T1-R4-CONT-5`**: `Calculated contrast ratio for active shortcuts exceeds WCAG AA 4.5:1`
  - **Target**: Contrast formula evaluation.
  - **Input**: Background RGB `[25, 25, 25]` vs active shortcut text RGB `[100, 216, 240]` (or `[255, 255, 255]`).
  - **Assertions**:
    - Contrast ratio $\ge 4.5:1$.

---

### Tier 2: Boundary & Corner Cases

- **`T2-R4-BOUND-1`**: `Extreme label length (>25 chars) wraps or truncates without expanding key-pad`
  - **Input**: Synthetic key label: `"VeryLongModifierActionLabelTest"`.
  - **Assertions**: `.key-pad` width remains 58px, height 44px; `.key-note` max-width 52px, height 20px, `overflow: hidden`.
- **`T2-R4-BOUND-2`**: `Unicode symbols and emoji in labels do not break line height or overflow height`
  - **Input**: Labels with emojis/symbols: `"Locrian 🌑"`, `"Lydian ☀️"`, `"Near Root ↑"`, `"Near Sub ↓"`.
  - **Assertions**: Total height of container remains $\le 20\text{px}$; no vertical expansion or overflow.
- **`T2-R4-BOUND-3`**: `Cmd+Shift combination layer preserves clutter suppression and contrast`
  - **Input**: `activeLayer = "cmdShift"`.
  - **Assertions**: Key 46 displays `"Close UI"`; unmapped keys have `displayNote = ""`; opacity remains 1.0.

---

## 4. Detailed Specification: Suite 2 (`tests/realtime_state_indicators_and_zls.test.js`)

### Tier 1: Feature Coverage (All 9 Active Parameters + ZLS Contract)

#### Active Parameter Telemetry Injection (9 Parameters)
- **`T1-R5-PARAM-VOL`**: `Active volume quantity is injected into volume control key labels`
  - **Target**: Keys 46 (M) and 43 (,) in `src/hud.lua` payload.
  - **Input**: Track volume = 80 (63% scale).
  - **Assertions**:
    - Key 46 `displayNote`: contains `"Vol -"` and `"63%"`.
    - Key 43 `displayNote`: contains `"Vol +"` and `"63%"`.
    - Format is `"Vol -\n63%"` and `"Vol +\n63%"`.
- **`T1-R5-PARAM-OCT`**: `Active octave offset quantity is injected into octave control key labels`
  - **Target**: Keys 2 (D) and 3 (F) in `src/hud.lua` payload.
  - **Input**: Active track `octaveOffset = 1`.
  - **Assertions**:
    - Key 2 `displayNote`: `"Oct -\n+1"` (or `"Oct -\n1"`).
    - Key 3 `displayNote`: `"Oct +\n+1"` (or `"Oct +\n1"`).
- **`T1-R5-PARAM-RATE`**: `Active arpeggiator rate quantity is injected into rate control key labels`
  - **Target**: Key 22 (6) in `src/hud.lua` payload.
  - **Input**: `state.arpRateIdx = 3` (resolving to `"1/16"`).
  - **Assertions**:
    - Key 22 `displayNote`: `"Rate +\n1/16"` (and Shift: `"Rate -\n1/16"`).
- **`T1-R5-PARAM-GATE`**: `Active arpeggiator gate percentage is injected into gate control key labels`
  - **Target**: Key 26 (7) in `src/hud.lua` payload.
  - **Input**: `state.arpGatePercent = 75`.
  - **Assertions**:
    - Key 26 `displayNote`: `"Gate +\n75%"` (and Shift: `"Gate -\n75%"`).
- **`T1-R5-PARAM-DIR`**: `Active arpeggiator direction name is injected into direction control key labels`
  - **Target**: Key 23 (5) in `src/hud.lua` payload.
  - **Input**: `state.arpDirectionIdx = 3` (`"Up/Down"`).
  - **Assertions**:
    - Key 23 `displayNote`: `"Dir +\nUp/Down"` (or compact `"Up/Dn"`).
- **`T1-R5-PARAM-ATKDEC`**: `Active Attack and Decay values are injected into Keys 9 (25) and 0 (29)`
  - **Target**: Keys 25 (9) and 29 (0) in `src/hud.lua` payload.
  - **Input**: Active track `attack = 35`, `decay = 80`.
  - **Assertions**:
    - Key 25 base: `"Atk -\n35"`, Shift: `"Dec -\n80"`.
    - Key 29 base: `"Atk +\n35"`, Shift: `"Dec +\n80"`.
- **`T1-R5-PARAM-ROOT`**: `Active musical root pitch name is injected into root control key labels`
  - **Target**: Keys 4 (H) and 37 (L) in `src/hud.lua` payload.
  - **Input**: `state.currentRoot = 9` (A) or `0` (C).
  - **Assertions**:
    - Key 4 `displayNote`: `"Root -\nA"`.
    - Key 37 `displayNote`: `"Root +\nA"`.
- **`T1-R5-PARAM-MODE`**: `Active musical mode name is injected into mode control key labels`
  - **Target**: Keys 5 (G) and 41 (;) in `src/hud.lua` payload.
  - **Input**: `state.currentModeIdx = 2` (`"Dorian"`).
  - **Assertions**:
    - Key 5 `displayNote`: `"Mode -\nDorian"`.
    - Key 41 `displayNote`: `"Mode +\nDorian"`.
- **`T1-R5-PARAM-BPM`**: `Active BPM tempo quantity is injected into BPM control key labels`
  - **Target**: Keys 27 (-) and 24 (=) in `src/hud.lua` payload.
  - **Input**: `state.arpBpm = 128`.
  - **Assertions**:
    - Key 27 `displayNote`: `"BPM -\n128"`.
    - Key 24 `displayNote`: `"BPM +\n128"`.

#### Zero Layout Shift (ZLS = 0) Invariant Contracts
- **`T1-R5-ZLS-PAD`**: `Key pad outer dimensions remain exactly 58px x 44px when parameters change`
  - **Target**: `.key-pad` geometry.
  - **Input**: Mutate parameter values from minimums to maximums.
  - **Assertions**: Width $\equiv 58\text{px}$, Height $\equiv 44\text{px}$ ($\Delta W = 0, \Delta H = 0$).
- **`T1-R5-ZLS-KEYCODE`**: `Key code top offset and bounding box remain invariant when parameter value changes`
  - **Target**: `.key-code` position inside `.key-pad`.
  - **Input**: Compare key with no parameter label vs key with 2-line parameter label.
  - **Assertions**: Vertical offset from pad top is invariant ($\Delta Y = 0$).
- **`T1-R5-ZLS-KEYNOTE`**: `Key note container height is rigidly clamped to 20px with overflow hidden`
  - **Target**: `.key-note` container.
  - **Input**: Inspect computed height.
  - **Assertions**: `height: 20px; max-height: 20px; overflow: hidden;`.
- **`T1-R5-ZLS-TABULAR`**: `Tabular figures prevent horizontal digit jitter on numeric updates`
  - **Target**: `.key-note` font settings.
  - **Input**: Inspect `font-variant-numeric`.
  - **Assertions**: `font-variant-numeric: tabular-nums` is present.
- **`T1-R5-ZLS-GRID`**: `Keyboard rows maintain immutable margin-left and zero cumulative layout shift`
  - **Target**: `.keyboard-row` styles.
  - **Input**: Row alignment rules.
  - **Assertions**: `.number` 0px, `.upper` 0px, `.home` 18px, `.lower` 42px. Cumulative Layout Shift (CLS) = 0.

---

### Tier 2: Boundary & Corner Cases (Feature 9)

- **`T2-R5-BOUND-VOL`**: `Volume boundaries: 0% and 100% format cleanly without overflow`
  - **Input**: Volume = 0 and Volume = 127.
  - **Assertions**: Formats `"0%"` and `"100%"`; width $\le 25\text{px} \ll 52\text{px}$.
- **`T2-R5-BOUND-BPM`**: `BPM boundaries: minimum (30 BPM) and maximum (300 BPM) fit within 52px`
  - **Input**: BPM = 30 and BPM = 300.
  - **Assertions**: Formats `"30"` and `"300"`; width $\le 25\text{px} \ll 52\text{px}$.
- **`T2-R5-BOUND-OCT`**: `Octave offset boundaries: -3, 0, +3 display signed integers cleanly`
  - **Input**: Octave offsets -3, 0, +3.
  - **Assertions**: Formats `"-3"`, `"0"`, `"+3"`.
- **`T2-R5-BOUND-MODE`**: `Longest mode name (e.g. Mixolydian, Harmonic Minor) fits 52px width`
  - **Input**: Mode = `"Mixolydian"`, `"Harmonic Minor"`.
  - **Assertions**: Formatted string fits within 52px or wraps to 2 lines without exceeding 20px height.
- **`T2-R5-BOUND-OSC`**: `Rapid alternating parameter increments maintain 0 layout shift`
  - **Input**: 20 consecutive state payload updates oscillating volume between 49% and 50%.
  - **Assertions**: Cumulative Layout Shift (CLS) = 0.

---

## 5. Detailed Specification: Suite 3 (`tests/hud_modifier_and_parameter_scenarios.test.js`)

### Tier 3: Cross-Feature Combinations (Pairwise Interactions)

- **`T3-CROSS-CMD-PARAM`**: `Engaging Cmd modifier suppresses unmapped keys while active parameters remain visible on mapped keys`
  - **Preconditions**: Volume = 80%, Octave = +1, Arp Rate = 1/16 active in Base layer.
  - **Action**: Hold Cmd (`activeLayer = "cmd"`).
  - **Assertions**:
    - Unmapped keys become blank (`displayNote = ""`, no `"Pass Through"` clutter).
    - Cmd shortcuts (Cmd+M, Cmd+Q) display crisp labels with opacity 1.0.
    - Releasing Cmd immediately restores parameter quantities (`"Vol -\n80%"`).
- **`T3-CROSS-SHIFT-PARAM`**: `Holding Shift switches parameter controls to secondary parameters without layout shift`
  - **Preconditions**: Base layer displaying Attack (`"Atk -\n10"`).
  - **Action**: Hold Shift (`state.shiftHeld = true`).
  - **Assertions**:
    - Keys 25/29 switch from Attack to Decay (`"Dec -\n64"`).
    - Keys 46/43 switch from Main Vol to Bottom Vol (`"BotVol -\n63%"`).
    - Keypad bounding box remains exactly 58px x 44px ($\Delta = 0$).
- **`T3-CROSS-TRACK-PARAM`**: `Switching active track (1->2->3->4) updates per-track parameter values and colors with ZLS=0`
  - **Preconditions**: Track 1 selected (Cyan `#00e5ff`, Vol 80%, Atk 10).
  - **Action**: Switch to Track 2 (Amber `#ff9100`, Vol 60%, Atk 50).
  - **Assertions**:
    - Attack key label updates from 10 to 50.
    - Assigned track color updates to `#ff9100`.
    - Zero layout reflow or element jitter occurs.
- **`T3-CROSS-LONGLABEL-VALUE`**: `Compound long labels with dynamic parameters fit inside 52px x 20px note frame`
  - **Preconditions**: Tab key (48) with Smart Sustain state.
  - **Action**: Double tap Tab to toggle sustain off.
  - **Assertions**:
    - Label updates between `"Smart Sus\n2× Off"` and `"Sus Off\n2× On"`.
    - Both lines fit within 52px width and 20px height.

### Tier 4: Real-World Application Scenarios

- **`T4-SCENARIO-LIVE-JAM`**: `Live performance jam: simultaneous polyphonic note input, arpeggiator clocking, and parameter tweaks`
  - **Scenario**:
    - 3 simultaneous held notes (C4, E4, G4).
    - Arpeggiator running at 120 BPM, 1/16 rate, 80% gate.
    - Continuous volume and BPM keypress increments.
  - **Assertions**:
    - Real-time notes render playing glow.
    - Parameter keys display live BPM and Volume values.
    - Zero horizontal text overflow across all keys.
    - Zero layout shift during live playing.
- **`T4-SCENARIO-MODIFIER-MACRO`**: `Rapid modifier switching between Base, Shift, Opt, and Cmd under active playback`
  - **Scenario**: Cycle `base` -> `shift` -> `cmd` -> `cmdShift` -> `base` at 50ms intervals.
  - **Assertions**:
    - Cmd mode shows zero `"Pass Through"` clutter; active shortcuts have 1.0 opacity.
    - Base mode shows live parameter quantities.
    - Transitions are instantaneous with zero DOM reflow.
- **`T4-SCENARIO-FOUR-TRACK-WORKFLOW`**: `Full 4-track studio workflow: track isolation, mute/solo toggling, and independent parameter recall`
  - **Scenario**: Set up distinct parameters for all 4 tracks (Bass, Chords, Lead, Arp).
  - **Assertions**:
    - Track buttons (18–21) maintain dedicated zones without text collisions.
    - Switching active track instantly recalls that track's volume, octave, and attack/decay on the keys.
- **`T4-SCENARIO-STRESS-BURST`**: `Chaos stress test: 100 rapid state updates alternating parameters, modifiers, and keypresses`
  - **Scenario**: Dispatch 100 consecutive `renderHud(data)` calls with varying parameters and modifier flags.
  - **Assertions**:
    - 100 frames execute cleanly without errors.
    - Frame time $< 5\text{ms}$.
    - Cumulative Layout Shift (CLS) = 0.

---

## 6. Implementation Guidance & Non-Destructive Invariants

To guarantee that implementation in Milestone M4 succeeds and passes these tests:

1. **In `src/web/index.html`**:
   - Update `.key-pad .key-note`:
     ```css
     .key-pad .key-note {
       font-size: 8.5px;
       line-height: 9.5px;
       font-weight: 500;
       color: rgba(200, 200, 200, 0.9);
       margin-top: 1px;
       white-space: pre-line;
       word-break: normal;
       text-align: center;
       height: 20px;
       max-height: 20px;
       width: 100%;
       max-width: 52px;
       overflow: hidden;
       font-variant-numeric: tabular-nums;
       text-shadow: 0 1px 2px rgba(0, 0, 0, 0.8);
       pointer-events: none;
       box-sizing: border-box;
     }
     ```
   - Update `.shortcut-reserved` and `.shortcut-passthrough`:
     ```css
     .shortcut-reserved {
       opacity: 1.0 !important;
       border-style: dashed !important;
       border-color: rgba(100, 216, 240, 0.6) !important;
       background-image: repeating-linear-gradient(135deg, transparent 0 5px, rgba(255,255,255,0.045) 5px 8px) !important;
     }
     .shortcut-reserved .key-note {
       color: #64d8f0 !important;
       font-weight: 700 !important;
     }
     .shortcut-passthrough {
       border-style: dotted !important;
       border-color: rgba(80, 80, 80, 0.5) !important;
       background: rgba(20, 20, 20, 0.7) !important;
     }
     .shortcut-passthrough .key-code {
       color: #666666 !important;
     }
     ```
2. **In `src/hud.lua`**:
   - In `performWebviewHudUpdate`:
     - When `activeLayer == "cmd"` or `"cmdShift"`: set unmapped fallback keys to `name = ""` (or `"—"`), suppressing `"Pass Through"` clutter.
     - For active parameter keys (Volume, Octave, Rate, Gate, Direction, Attack, Decay, Root, Mode, BPM), dynamically append the active quantity to `displayNote`:
       ```lua
       -- Example for volume:
       key.displayNote = "Vol -\n" .. volPercent .. "%"
       ```
3. **Preserve Legacy Invariants**:
   - Keep `PROPOSED_LAYOUT_MAP[48].ctrl` name as `"Pass Through"` to prevent breaking existing test `tests/shortcut_visibility_and_sustain_off.test.js`.
