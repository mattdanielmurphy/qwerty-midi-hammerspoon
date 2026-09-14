# Korg nanoKEY Studio Knobs & Keyboard Alignment

**Date**: 2026-09-14 13:15
**Author**: Antigravity Orchestrator
**Scope**: `packages/nanokey-studio/nanokey.lua`, `src/web/index.html`, `src/ui_html.lua`, `qwerty_midi.lua`, `src/hud.lua`

---

## 1. Context & User Directives
Matt connected the physical **Korg nanoKEY Studio** controller and identified three critical issues during real-world hardware verification:
1. **Knob Labeling & Positions**: Knobs were mapped to incorrect positions and only two knobs responded. Matt requested labeling all 8 knobs according to default **Korg Gadget** parameters:
   - **Row 1 (left to right)**: `CUTOFF`, `PEAK`, `DRIVE`, `VOLUME`
   - **Row 2 (left to right)**: `ATTACK`, `DECAY`, `SUSTAIN`, `RELEASE` (ADSR)
2. **Knob CC Offsets**: Matt determined hardware CC transmission:
   - Top-left knob starts at CC 17 (or 16..23 offset by +2 from previous 14..21).
   - Last knob is CC 23 (or 24).
3. **Key Visualizer**: Physical keyboard keys were not illuminating on the hardware GUI when pressed, caused by note number hijacking in `noteToPadIndex` and fixed-range chiclet element IDs.

---

## 2. Root Cause Analysis & Implementations

### A. Rotary Knobs Alignment (`packages/nanokey-studio/nanokey.lua`)
- **Root Cause**: The previous handler strictly checked `cc >= 14 and cc <= 21` and calculated `knobIdx = cc - 13`. Knobs transmitting CC 22–27 were completely ignored, and CC 20/21 collided with Knobs 7 and 8 instead of Knobs 1 and 2 (or 4/5).
- **Implementation**:
  - Implemented an adaptive resolver `resolveKnobIndex(cc)`:
    - **17..24 Mode (default)**: `CC 17` -> Knob 1 (`Cutoff`), `CC 18` -> Knob 2 (`Peak`), `CC 19` -> Knob 3 (`Drive`), `CC 20` -> Knob 4 (`Volume`), `CC 21` -> Knob 5 (`Attack`), `CC 22` -> Knob 6 (`Decay`), `CC 23` -> Knob 7 (`Sustain`), `CC 24` -> Knob 8 (`Release`).
    - **16..23 Mode**: Auto-detects on `CC 16` input and switches base offset to 15 (`CC 16..23` -> Knobs 1..8).
    - **20..27 Mode**: Auto-detects Korg Gadget factory scene presets (`CC 20..27` -> Knobs 1..8).
  - Added real-time telemetry logging to both `tmp/qwerty_midi_debug.log` and `tmp/nanokey_probe.log` showing `Knob <idx> [<Name>] (CC #<cc>) = <val>`.
  - Disambiguated CC 25: Momentary values (0/127) toggle the physical Sustain macro layer, while continuous CC values safely route to Knob 6 (`Decay`).

### B. Authentic Korg Gadget Hardware UI (`src/web/index.html`)
- Updated the 8 rotary knob elements with official Korg Gadget parameter nomenclature:
  - Row 1: `CUTOFF` (CC 17), `PEAK` (CC 18), `DRIVE` (CC 19), `VOLUME` (CC 20)
  - Row 2: `ATTACK` (CC 21), `DECAY` (CC 22), `SUSTAIN` (CC 23), `RELEASE` (CC 24)
- Added `.nk-knob-cc` telemetry badges displaying the live active CC number directly beneath each rotary dial.
- Updated `window.updateNanoKeyState` to dynamically update angle, numeric value, and CC badges upon incoming control changes.

### C. Physical Keyboard Chiclet Visualizer (`packages/nanokey-studio/nanokey.lua` & `src/web/index.html`)
- **Root Cause**:
  1. `noteToPadIndex` had previously mapped notes 60..67 as trigger pads instead of passing them to melodic keys.
  2. The 25 physical chiclet keys (`nk-key-48` through `nk-key-72`) failed to match note numbers when the physical controller's OCTAVE -/+ buttons transposed notes into octaves 1, 2, 4, or 5.
- **Fix**:
  1. Stripped the `60..67` pad hijack from `noteToPadIndex`. Pads now strictly respond to standard drum notes `36..43`.
  2. Added octave folding in `updateNanoKeyState`: any note outside `48..72` is wrapped into the 25-key physical span, ensuring visual illumination regardless of hardware octave shift.
  3. Linked `updateKeyState` so playing notes via QWERTY keyboard also lights up the chiclet keys in real time.

---

## 3. Verification & Reload
- **Bundler**: Ran `bin/bundle_and_reload.sh` to compile 15 Lua modules into `qwerty_midi.lua` and sync HTML into `src/ui_html.lua`.
- **Syntax**: `luac -p qwerty_midi.lua` passed with 0 errors.
- **Reload**: Triggered via Hammerspoon AppleScript IPC.
