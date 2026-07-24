# Arpeggiator Bottom Row Default, Latch Transpose Preservation & BPM Hold/Drag Controls

## Goal
Improve arpeggiator behavior, target defaults, latched sequence root/scale transpositions, and BPM UI control responsiveness:
1. Make arpeggiator default target bottom row only (top row off by default).
2. Ensure arpeggiator state toggle clearly announces target scope (e.g. "Arpeggiator: ON (Bottom Row)").
3. Fix arpeggiator sequence reset on root/mode changes in Latch mode: when root note or scale/mode changes while arpeggiator is latched, update held pitch values in place so the sequence continues smoothly in the new scale without resetting sequence index or timer.
4. Accelerate BPM adjustment rate when holding the BPM +/- buttons down continuously.
5. Enable vertical click-and-drag directly on the BPM display to adjust tempo dynamically up and down (with Shift modifier support for fine tuning).

## User Feedback & Decisions
- Default arpeggiator row should be bottom row only.
- Arpeggiator toggle should announce state and target row clearly.
- Root key / scale changes during Latch mode must transpose active arpeggio notes while keeping sequence progression unbroken.
- BPM +/- buttons should accelerate when held down.
- Dragging the BPM text vertically should adjust BPM.

## Changes Made
1. **`qwerty_midi.lua`**:
   - Updated default `arpTopEnabled` to `false` and `arpBottomEnabled` to `true`.
   - Updated `toggleArp()` and `cycleArpMode()` spotlight subtext to announce active target rows (e.g. `ON (Bottom Row Only)`).
   - Added `updateLatchedArpNotes()` function which re-calculates all active latched notes in `arpHeldNotes` using `getTransposedPitch` for their respective base key and row.
   - Integrated `updateLatchedArpNotes()` into scale/mode changes (`modeUp`, `modeDown`, `randomScale`, `setModeIdx`) and root changes (`rootUp`, `rootDown`, `setRoot`).
   - Implemented repeat & acceleration timer logic in JavaScript for `bpm-up` and `bpm-down` buttons (repeats at 80ms, accelerating multiplier after 0.7s, 1.5s, and 3.0s).
   - Implemented vertical drag handler (`mousedown`, `mousemove`, `mouseup`) on `#bpm-value` posting `dragBpm` messages to Lua, updating `arpBpm` seamlessly while keeping click-to-type capability intact when not dragging.

## What Worked
- Defaulting to bottom-row arpeggiator prevents top-row key overlap when arp is toggled.
- Latched arpeggios transpose cleanly when shifting scales or root keys without interrupting playback.
- BPM +/- hold acceleration allows quick tempo sweeps across a wide range.
- Dragging BPM text provides intuitive mouse control over tempo.

## Architecture Notes
- `arpHeldNotes` maps QWERTY keycodes to MIDI pitches. Updating pitches in place preserves keycode associations and current step pointers in `arpStepIndex`.
