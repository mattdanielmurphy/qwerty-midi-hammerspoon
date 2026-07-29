# 2026-07-25 - Remap BPM Set Keys to Synth Release Controls (MIDI CC #72)

## Goal
Remap number row keys `9` and `0` from "BPM Set" (`bpmEdit`) to Synth Release - and Release + controls using standard MIDI CC 72 (Sound Controller 3 / Release Time).

## User Feedback & Decisions
- BPM set keys on `9` and `0` were not desired by the user.
- Replaced keys `9` and `0` with Synth Release controls using standard MIDI CC 72 (`Rel -` / `Rel +`).

## Changes Made
- `src/config.lua`: Replaced `bpmEdit` action on key 9 (`[25]`) and key 0 (`[29]`) with `relDown` (`Rel -`) and `relUp` (`Rel +`). Added default CC 72 initialization to `state.ccStates`.
- `src/controls.lua`: Added `relDown` and `relUp` action handlers to decrement/increment MIDI CC 72 (in 4-step increments from 0 to 127), sending MIDI CC messages and updating the spotlight HUD card with "SYNTH RELEASE" percentage and "CC #72 Level".
- `src/hud.lua`: Added `relDown` / `relUp` / `releaseDown` / `releaseUp` mapping to `ctrl-rel` CSS class in `ctrlClassMap`.
- `src/ui_html.lua` & `src/web/index.html`: Updated `LAYOUT_DATA.number` to label keys `9` and `0` as `Rel -` and `Rel +`. Added `.key-pad.ctrl-rel` CSS styles with purple highlight.
- `FEATURES.md`: Updated number row documentation and key pair color styling sections.

## What Worked
- Tapping or holding `9` (`Rel -`) or `0` (`Rel +`) decrements/increments Synth Release Time via MIDI CC #72 with smooth key-repeat support and real-time HUD spotlight feedback.

## Architecture Notes
- Standard General MIDI CC 72 is Sound Controller 3 (Release Time), universally supported by software synthesizers (Logic Pro, Kontakt, Ableton, Serum, Vital, etc.).
