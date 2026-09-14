# Session Log: Korg nanoKEY Studio Pad Channel Realignment & 36..60 Keyboard Octave Range Fix

**Date:** 2026-09-14 14:48  
**Author:** Antigravity  
**Target:** `packages/nanokey-studio/nanokey.lua`, `src/web/index.html`, `src/ui_html.lua`, `qwerty_midi.lua`  

## Problem Statement
1. **Pads lighting up when keys are pressed:** Pressing keys on the physical keyboard lit up the trigger pads in the GUI instead of keys.
2. **Pads not lighting up when struck:** Striking the physical trigger pads did not illuminate the trigger pads in the GUI.
3. **Chord Pad mode ambiguity:** Pads trigger 3–4 note chords when Chord Pad mode is on, and single notes otherwise.
4. **Middle C octave folding collapse:** When pressing the middle C on the physical nanoKEY Studio, the GUI lit up the lower C instead of middle C, and all notes above middle C collapsed into the lower octave.

## Root Cause Analysis
1. **Pad vs. Key MIDI Channel Cross-Wiring:**
   - Physical keys transmit on **MIDI Channel 1 (`ch = 0`)**.
   - Physical trigger pads transmit on **MIDI Channel 2 (`ch = 1`)** with notes 64..71 (E4..B4), or drum channel 10 (`ch = 9`) with notes 36..43.
   - In `nanokey.lua`, `noteToPadIndex(note)` previously checked `note >= 36 and note <= 43` without inspecting `ch`.
   - Because the physical keyboard's factory default note range is notes 36 to 60 (C2 to C4), physical keys 1..8 transmit notes 36..43 on `ch = 0`. This caused `nanokey.lua` to falsely identify keys 1..8 as pads 1..8!
   - Conversely, physical pad strikes on `ch = 1` (notes 64..71) were ignored by `noteToPadIndex`, leaking into the keyboard key handler instead of lighting up pads.
2. **25-Key GUI Range & Octave Folding Mismatch:**
   - On the physical nanoKEY Studio, the 25 keys span notes **36 to 60** (C2 to C4) at default octave:
     - Lowest C (Key 1, `Major`): Note 36 (C2)
     - Middle C (Key 13, `Maj Penta`): Note 48 (C3)
     - High C (Key 25, `5th Interval`): Note 60 (C4)
   - In `src/web/index.html`, the GUI DOM was hardcoded with IDs `nk-key-48` through `nk-key-72`, with octave folding `while (mapped < 48) mapped += 12; while (mapped > 72) mapped -= 12;`.
   - When middle C (note 48) was pressed, `48 < 48` was false, mapping it to `nk-key-48`—which was the lower C of the GUI!
   - When lower C (note 36) was pressed, `36 + 12 = 48`, mapping it to `nk-key-48` as well. Both octaves of the physical keyboard collapsed into the lower octave of the GUI, and the upper half of the GUI (`nk-key-61` to `nk-key-72`) was never reached.

## Implementation Details
1. **`packages/nanokey-studio/nanokey.lua`**:
   - Updated `noteToPadIndex(note, ch)`:
     - `ch == 1 and note >= 64 and note <= 71` -> maps to Pad 1..8 (`note - 63`).
     - `ch == 9 and note >= 36 and note <= 43` -> maps to Pad 1..8 (`note - 35`).
     - `ch == 0` -> returns `nil` (ensures keyboard keys never trigger pads).
   - Added `return true` on pad events to prevent pad hits from leaking into keyboard keys.
   - Added Chord Pad burst detection on `ch == 0`: buffers noteOns within 5ms; if >= 3 notes arrive simultaneously, identifies chord root (`CHORD_ROOT_TO_PAD`) and illuminates the corresponding pad in addition to the chiclet keys.
   - Updated `handleGuiAction`: on pad click, transmits note on channel 1 (`ch = 1`) with note `63 + padIdx`.
   - Updated `macro_scene` keyMacros to octave-fold `macroNote` so Scene key shortcuts work across all octaves.
2. **`src/web/index.html`**:
   - Realigned all 25 chiclet key DOM IDs and data attributes to notes 36..60:
     - White keys: `nk-key-36` (C2), `38` (D2), `40` (E2), `41` (F2), `43` (G2), `45` (A2), `47` (B2), `48` (C3, Middle C), `50` (D3), `52` (E3), `53` (F3), `55` (G3), `57` (A3), `59` (B3), `60` (C4, High C).
     - Black keys: `nk-key-37` (C#2), `39` (D#2), `42` (F#2), `44` (G#2), `46` (A#2), `49` (C#3), `51` (D#3), `54` (F#3), `56` (G#3), `58` (A#3).
   - Updated `updateNanoKeyState`: octave folding window mapped to `36..60` (`while (mapped < 36) mapped += 12; while (mapped > 60) mapped -= 12;`).
3. **Bundling & Synchronization:**
   - Ran `bin/bundle_and_reload.sh` to compile `src/web/index.html` into `src/ui_html.lua` and `qwerty_midi.lua`, followed by live Hammerspoon reload.

## Verification
- Verified via direct DOM inspection:
  - Playing note 48 (Middle C) activates `nk-key-48` (Middle C) and leaves `nk-key-36` inactive (`true | false`).
  - Playing note 36 (Lower C) activates `nk-key-36` (Lower C) and leaves `nk-key-48` inactive (`false | true`).
  - Striking pad 1 on `ch = 1` (note 64) activates `nk-pad-1` and leaves chiclet keys inactive (`true | false`).
  - Striking Chord Pad in Chord mode (notes 48, 52, 55 on `ch = 0`) activates both `nk-pad-1` and all chord keys (`nk-key-48`, `nk-key-52`, `nk-key-55`) (`true | true | true | true`).
- Verified visual alignment via high-resolution window screen capture.
