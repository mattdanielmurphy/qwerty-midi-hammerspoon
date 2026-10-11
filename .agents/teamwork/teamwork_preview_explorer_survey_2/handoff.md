# Handoff Report: HUD & UI Overlay Investigation (R4 & R5)

**Agent**: Survey Explorer 2 (HUD & UI Overlay)  
**Working Directory**: `/Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_explorer_survey_2`  
**Date**: 2026-10-11  
**Milestone**: Survey Phase Completed  
**Handoff Type**: Hard  

---

## 1. Observation

### 1.1 CSS Styling & Text Overflow Observations
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
  `white-space: nowrap;` forbids multi-line wrapping. `.key-pad` has fixed width 58px and no `overflow: hidden`.
- **File**: `src/hud.lua:220`
  `base = { name = "Smart Sus · 2× Off", class = "ctrl-sus", action = "sustain" }` (18 characters long, renders to $\approx 96\text{px}$, overflowing a 58px key by $41\text{px}$).

### 1.2 "Pass Through" Clutter Observations
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
  `COMMAND_LAYER_MAP` defines only 8 keys: codes 46 (M), 12 (Q), 13 (W), 4 (H), 48 (Tab), 49 (Space), 1 (S), 6 (Z).
  All remaining 35+ keys receive `name = "Pass Through"`.

### 1.3 Key Opacity & Muddy Dimming Observations
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
  Setting container-level opacity on `.shortcut-reserved` dims active application shortcuts (Cmd+Q Quit, Cmd+W Close, Cmd+M Minimize) down to 48%, reducing contrast against the dark background (`rgba(18, 18, 18, 0.97)`) to $< 2:1$.

### 1.4 Parameter Telemetry Isolation Observations
- **File**: `src/hud.lua:366-375` (Keys 46: M, 43: `,`)
  `base = { name = "Vol -", class = "ctrl-vol", action = "volDown" }`
  `base = { name = "Vol +", class = "ctrl-vol", action = "volUp" }`
  Control keys display static `"Vol -"` and `"Vol +"`.
- **File**: `src/hud.lua:1192-1193`
  Volume levels are computed (`topVolPercent`, `bottomVolPercent`) but dispatched only to `#vol-fill-top` and `#vol-fill-bottom` edge bars (`src/web/index.html:5612-5621`). Key surfaces for M and `,` never receive or display the active volume percentage.
- **File**: `src/hud.lua:476-495` (Keys 25: 9, 29: 0)
  Display static `"Atk -"`, `"Atk +"`, `"Dec -"`, `"Dec +"`. Attack and decay values (`trk.attack`, `trk.decay`) are nowhere to be seen on the keys.

---

## 2. Logic Chain

1. **Step 1 (Overflow)**: Based on Observation 1.1, `.key-pad` has fixed width 58px and `.key-note` enforces `white-space: nowrap;`. Because text strings like `"Smart Sus · 2× Off"`, `"Minimize Window"`, and `"Pass Through"` exceed 55px rendered width, they cannot wrap and must overflow horizontally past key borders.
2. **Step 2 (Clutter)**: Based on Observation 1.2, `COMMAND_LAYER_MAP` covers only 8 shortcut keys out of ~45 active keyboard keys. Every unassigned key receives `"Pass Through"` as its fallback label. Because of Step 1, 35+ adjacent keys simultaneously overflow their `"Pass Through"` labels by $17\text{px}$, causing wall-to-wall overlapping text collision.
3. **Step 3 (Contrast)**: Based on Observation 1.3, `.shortcut-reserved` and `.shortcut-passthrough` enforce element-level `opacity: 0.48` and `0.40`. Alpha transparency composites the white/gray text into the dark HUD chassis, causing muddy contrast and making active shortcuts appear disabled.
4. **Step 4 (State Visibility)**: Based on Observation 1.4, parameter states are computed in `hud.lua` but only routed to header elements and edge bars. Control keys statically display `"Vol -"`, `"Oct +"`, `"Rate +"`, etc.
5. **Step 5 (ZLS Compliance)**: By constraining `.key-note` to a fixed 20px height with `white-space: pre-line`, `overflow: hidden`, and `font-variant-numeric: tabular-nums`, parameter quantities (e.g. `"80%"`, `"+1"`, `"1/16"`) can be injected as a second line without altering the vertical position of `.key-code` or the geometry of adjacent keys.

---

## 3. Caveats

- **Test Suite Contract**: `tests/shortcut_visibility_and_sustain_off.test.js:30` asserts that `PROPOSED_LAYOUT_MAP` retains `'name = "Pass Through"'` in Lua for Tab (key 48). Therefore, the suppression of redundant "Pass Through" text should occur during the runtime display formatting step (in `hud.lua:performWebviewHudUpdate` or `src/web/index.html:renderHud`), leaving the raw table definitions intact.
- **KeyStep Lower Row Mode**: When Arturia KeyStep is disconnected, lower row keys (Z..M) revert to bottom-row note triggers instead of control keys. Value indicators on keys M and `,` apply when acting as control keys or when dedicated volume keys are pressed.

---

## 4. Conclusion

1. **R4 Fix Architecture**:
   - In `src/web/index.html`: Replace `white-space: nowrap;` on `.key-pad .key-note` with `white-space: pre-line; word-break: normal; height: 20px; max-height: 20px; width: 100%; max-width: 52px; font-size: 8.5px; line-height: 9.5px; font-variant-numeric: tabular-nums; overflow: hidden;`.
   - In `src/web/index.html`: Remove element `opacity: 0.48` from `.shortcut-reserved`. Style active shortcuts with `opacity: 1.0 !important;`, crisp white code, and high-contrast cyan label (`#64d8f0`). Style passthrough keys with subdued backgrounds (`rgba(22, 22, 22, 0.6)`) and gray codes (`#777777`) without container opacity.
   - In `src/hud.lua`: When `activeLayer == "cmd"` or `"cmdShift"`, format unmapped fallback keys to `"—"` (or empty) to eliminate redundant "Pass Through" clutter while highlighting true shortcuts.
2. **R5 Fix Architecture**:
   - In `src/hud.lua`: Dynamically append active parameter quantities to `displayNote` for volume (`"Vol -\n" .. vol .. "%"`), octave (`"Oct -\n" .. oct`), arp rate (`"Rate\n" .. rate`), arp gate (`"Gate\n" .. gate .. "%"`), arp direction (`"Dir\n" .. dir`), attack/decay (`"Atk -\n" .. atk`), root (`"Root -\n" .. root`), mode (`"Mode -\n" .. mode`), and BPM (`"BPM -\n" .. bpm`).
   - The 20px rigid `.key-note` container guarantees Zero Layout Shift (ZLS = 0).

---

## 5. Verification Method

1. **Automated Test Verification**:
   ```bash
   bun test
   ```
   All 77 existing tests must pass without regression, including `tests/chord_display_and_layout_shift.test.js` and `tests/shortcut_visibility_and_sustain_off.test.js`.
2. **Bundle & Compilation Verification**:
   ```bash
   bash bin/bundle_and_reload.sh
   luac -p qwerty_midi.lua
   ```
   Confirms that `src/web/index.html` syncs cleanly into `src/ui_html.lua` and produces valid bundled Lua code.
3. **Visual Invalidation Conditions**:
   - Any key label text spilling beyond 58px key boundaries horizontally.
   - Key code jumping vertically when parameter values increment/decrement.
   - Contrast ratio of active Cmd shortcuts falling below 4.5:1.
   - Repetition of `"Pass Through"` text across unassigned keys in Cmd mode.
