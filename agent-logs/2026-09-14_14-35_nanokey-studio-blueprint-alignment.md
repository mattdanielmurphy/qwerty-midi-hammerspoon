# Session Log: Korg nanoKEY Studio Blueprint Alignment & Note Illumination Fix

**Date:** 2026-09-14 14:35  
**Author:** Antigravity  
**Target:** `packages/nanokey-studio`, `src/web/index.html`, `src/hud.lua`  

## Problem Statement
1. The Korg nanoKEY Studio visualizer in the Hammerspoon HUD only displayed knob rotations; physical key presses and trigger pad strikes were not illuminating or registering in the GUI.
2. The function button layout did not match the physical controller blueprint:
   - On the physical unit, the buttons sit under the 8 knobs on the left and under the 8 pads on the right, arranged in two distinct groups of three with a gap in between.
   - Internal functions (`Octave -/+`, `Touch Scale`, `X-Y`, `Pitch / Mod`, `Shift / Tap`, `Arp`, `Chord Pad`, `Easy Scale`, `Scale Guide`) cannot be controlled by the host and were erroneously interactive or misplaced.
   - Host-controllable buttons (`Sustain` CC #25 and `Scene` SysEx) needed interactive styling and bidirectional IPC.

## Root Cause Analysis
- **Hammerspoon `hs.midi` schema mismatch:** In `packages/nanokey-studio/nanokey.lua`, the MIDI callback was attempting to read `metadata.noteNumber`. In Hammerspoon, the note field is `metadata.note`. Because `metadata.noteNumber` was `nil`, note events were silently ignored.
- **UI Architecture:** The original `#nanokey-view` DOM positioned all buttons in a single row across the center instead of grouping them beneath the left knobs and right trigger pads.

## Implementation Details
1. **`packages/nanokey-studio/nanokey.lua`**:
   - Updated MIDI event parsing to `local note = metadata.note or metadata.noteNumber or metadata.pitch`.
   - Added `nanoKey.handleGuiAction(actionType, data)` to handle bidirectional GUI interaction for notes, pads, sustain toggles, and scene toggles.
2. **`src/hud.lua`**:
   - Added user content message handlers in `uc:setCallback` for `nanokeyKey`, `nanokeyPad`, `nanokeySustain`, and `nanokeyScene`.
3. **`src/web/index.html`**:
   - Restructured `#nanokey-view` into three vertical sections:
     - **Left Column:** 8 Knobs + Left Button Row (Group 1: `Octave -`, `Octave +`, `Sustain`; Gap; Group 2: `Touch Scale`, `X-Y`, `Pitch / Mod`).
     - **Center Column:** Full-height Kaoss Touchpad with live readout and reticle.
     - **Right Column:** 8 Trigger Pads with silkscreen function headers + Right Button Row (Group 3: `Scene`, `Shift / Tap`, `Arp`; Gap; Group 4: `Chord Pad`, `Easy Scale`, `Scale Guide`).
     - **Keyboard Section:** 25 chiclet keys with authentic factory scale labels (`Major`, `Lydian`, `Minor`, etc.) and Roman numerals.
   - Added `.nk-btn-inert` with `pointer-events: none;`, recessed dark matte styling, and muted text.
   - Added `.nk-btn-interactive` with active glowing hover/pressed styles for Sustain (`#5ea2eb`) and Scene (`#c084fc`).
   - Added active note reference tracking (`window._activeNanoKeyNotes`) to eliminate race conditions on chords.
4. **Bundling & Sync:**
   - Ran `bin/bundle_and_reload.sh` to update `src/ui_html.lua` and `qwerty_midi.lua`.

## Verification
- Verified syntax via `luac -p qwerty_midi.lua`.
- Confirmed live incoming noteOn/noteOff illumination across chiclet keys and trigger pads via hardware testing and screen capture.
- Confirmed non-clickable inert styling on internal function buttons.
