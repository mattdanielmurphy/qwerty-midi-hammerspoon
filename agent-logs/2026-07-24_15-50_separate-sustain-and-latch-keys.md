## Goal
Separate MIDI CC #64 Sustain and Arpeggiator Latch control into two distinct dedicated keys.

## User Feedback & Decisions
- Assigned `Tab` key exclusively to Sustain (CC #64) and added `Tab` to the on-screen visual keyboard UI grid.
- Assigned `A` key exclusively to Arp Latch.

## Changes Made
- [src/config.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/config.lua): Added `arpLatchActive`, `arpLatchKeyDownTime`, and `arpLatchWasActiveOnPress` to `state`. Reassigned `A` (code 0) to `action = "latch"` with label `"Latch"`.
- [src/arpeggiator.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/arpeggiator.lua): Updated `arpAddNote` and `arpRemoveNote` to inspect `state.arpLatchActive` instead of `state.sustainActive`.
- [src/controls.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/controls.lua): Separated `act == "sustain"` and `act == "latch"` logic in both `executeControlAction` and `handleKeyUp`.
- [src/hud.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/hud.lua): Added `LATCH: ON` status indicator alongside `SUS: ON` in the top bar. Updated key display classes for key `A` and `Tab`.
- [src/ui_html.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/ui_html.lua): Added `Tab` pad (`Sustain`) to upper row layout data and updated `A` note label to `"Latch"`.

## What Worked
- `Tab` now exclusively controls MIDI CC #64 Sustain.
- `A` now exclusively controls Arpeggiator pattern Latch mode.
- Visual key grid displays both `Tab` (`Sustain`) and `A` (`Latch`).

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- `state.sustainActive` handles CC #64 and standard pitch damping.
- `state.arpLatchActive` handles pattern latching for arpeggiated note chords.
