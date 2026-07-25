# 2026-07-24 - Fix BPM Direct Typing Input and Overlay Guidance

## Goal
Fix BPM text editing where clicking to type a number did not provide visual feedback or prompt guidance for key presses.

## User Feedback & Decisions
- Direct typing into BPM input mode should show interactive spotlight feedback ("EDIT BPM", "TYPE TEMPO", "Type digits & press Enter") when triggered by clicking the BPM display.

## Changes Made
- Updated [hud.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/hud.lua#L354-L365) `enterBpmEdit` message handler to publish a spotlight card on entry.
- Updated [arpeggiator.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/arpeggiator.lua#L372-L393) `handleBpmInput` to refresh spotlight card with current typed digits buffer and decimal point as keys are pressed.
- Bundled changes into `qwerty_midi.lua` and reloaded Hammerspoon.

## What Worked
- Clicking the BPM readout triggers BPM edit mode with immediate visual spotlight feedback ("TYPE TEMPO" / "Type digits & press Enter").
- Typing digits/backspace updates both the HUD input display and spotlight card in real-time.
- Pressing Return commits the tempo change and updates arpeggiator/Logic sync; pressing Escape cancels back to original BPM.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- `state.bpmInputMode` routes keypresses through `arpeggiator.handleBpmInput()` in `src/init.lua` before normal shortcut evaluations.
