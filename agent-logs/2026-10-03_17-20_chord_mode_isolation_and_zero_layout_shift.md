# Agent Work Log: Chord Mode Isolation & Global Zero-Layout-Shift (ZLS) Invariant

**Date:** 2026-10-03  
**Time:** 17:20  
**Context:** User reported confusion with the top-right chord display / mini-piano showing chord mode presets ("Triad") even when Chord Mode was disabled, while simultaneously fighting with currently held live chord detection. In addition, the user identified a common AI GUI bug: flexible containers in flex/grid rows shifting and reflowing whenever an element's text or state changes.

---

## 1. Problem Analysis & Root Cause

1. **Chord Display / Mini-Piano State Contamination**:
   - In `src/hud.lua`, `selectedChordInfo` was always being generated from `harmony.chordTypes[cIdx]` regardless of whether `chordModeActive` was true on the active track or quote was held.
   - In `src/web/index.html`, `renderHud` evaluated `if (data.selectedChord !== undefined)` which was always truthy, forcing `#chord-display-badge` to display "Triad" and lighting C-E-G keys on `.chord-mini-piano` when the keyboard was idle.
   - When keys were pressed, `updateKeyState` called `window.updateChordDisplay(chordName)` with live detected chord strings, but without `pitchClasses`, causing keys to flicker or get wiped on the next 30ms `renderHud` tick.

2. **Cumulative Layout Shift (CLS) / Row Reflow**:
   - Dynamic UI elements across `#header` and `.row-controls` used flexible or auto widths (`width: auto`, dynamic text).
   - Changing text from `—` (10px) to `C# min7(b5)` (80px), or from `120 BPM` to `90 BPM`, pushed every subsequent sibling element along the row.
   - Variable digit widths without `tabular-nums` caused micro-jitter (1–2px) during playback or value dragging.

---

## 2. Changes Made

1. **Backend Chord State & Flagging (`src/hud.lua`)**:
   - Computed `isChordModeActive = (activeTrk and activeTrk.chordModeActive == true) or state.quoteHeld == true`.
   - Passed `chordModeActive` in the WebKit payload and added `active = isChordModeActive` into `selectedChordInfo`.
   - Updated `updateChordDisplay()` in `src/hud.lua` to pass `isChordModeActive` to JavaScript:
     ```lua
     safeEvaluateJS(string.format("if (window.updateChordDisplay) window.updateChordDisplay(%s, null, %s);", chordParam, isChordModeActive and "true" or "false"))
     ```

2. **Frontend Chord Display Separation (`src/web/index.html`)**:
   - Updated `renderHud`:
     - If `data.chordModeActive` is true: displays `CHORD: <Type>` and highlights chord type pitch classes on `.chord-mini-piano`.
     - If `data.chordModeActive` is false: checks `data.detectedChord`. If a live polyphonic chord is currently held, displays the detected chord name (e.g. `C Maj`, `F# min7`). If no chord is held, displays `—` and invokes `updateChordMiniPiano(null)` to completely unlight the mini-piano.
   - Updated `window.updateChordDisplay(chordName, chordData, isChordModeActive)`:
     - Stores and respects `window._isChordModeActive`.
     - Clamps display text to max 80px with `overflow: hidden; text-overflow: ellipsis; white-space: nowrap`.
     - Clears mini-piano keys whenever chord mode is inactive and no live chord is detected.
   - Updated `window.updateKeyState`:
     - Only updates chord badge if chord mode is NOT active (`if (!window._isChordModeActive)`), preventing keypresses from corrupting the active chord mode display.

3. **Global Zero-Layout-Shift (ZLS) Pattern Applied**:
   - Locked all dynamic controls in `#header` and `.row-controls` with immutable rigid bounding boxes:
     - `.chord-display-badge`: `width: 154px; min-width: 154px; max-width: 154px; height: 26px; box-sizing: border-box; flex-shrink: 0; overflow: hidden;`
     - `.bpm-editor`: `width: 102px; min-width: 102px; max-width: 102px; box-sizing: border-box; flex-shrink: 0;` with `.bpm-display` at `56px` and `font-variant-numeric: tabular-nums;`
     - `#root-select`: `width: 48px; min-width: 48px; max-width: 48px; flex-shrink: 0;`
     - `#arp-dir-select`: `width: 66px; min-width: 66px; max-width: 66px; flex-shrink: 0;`
     - `#arp-rate-select`: `width: 52px; min-width: 52px; max-width: 52px; flex-shrink: 0;`
     - `#arp-quantize-select`: `width: 114px; min-width: 114px; max-width: 114px; flex-shrink: 0;`
     - `#input-quantize-select`: `width: 98px; min-width: 98px; max-width: 98px; flex-shrink: 0;`
     - `#logic-sync-btn`: `width: 74px; min-width: 74px; max-width: 74px; flex-shrink: 0;`
     - `#layout-select`: `width: 90px; min-width: 90px; max-width: 90px; flex-shrink: 0; overflow: hidden; text-overflow: ellipsis;`
     - `#keystep-badge`: `width: 106px; min-width: 106px; max-width: 106px; flex-shrink: 0;`
     - `.compact-oct-badge`: `width: 58px; min-width: 58px; max-width: 58px; box-sizing: border-box; flex-shrink: 0; font-variant-numeric: tabular-nums;`
     - `.vol-bar-container`: `width: 6px; min-width: 6px; max-width: 6px; box-sizing: border-box; flex-shrink: 0;`
     - `.arp-row-toggle`: `width: 38px; min-width: 38px; max-width: 38px; box-sizing: border-box; flex-shrink: 0;`
   - All flex children use `flex-shrink: 0` or `flex: 1 1 0; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;`.

4. **Testing & Verification**:
   - Created `tests/chord_display_and_layout_shift.test.js` validating chord mode separation and ZLS CSS rules.
   - Built offline production bundle `src/ui_html.lua` and `qwerty_midi.lua` via `bin/bundle_and_reload.sh`.
   - Syntax checked Lua bundle: `luac -p qwerty_midi.lua src/*.lua` passed with 0 errors.
   - Ran `bun test`: All 49 tests across 12 files passed (453 assertions).
