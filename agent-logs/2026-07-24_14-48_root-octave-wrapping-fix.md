## Goal
Ensure that pressing `Root -` (`H`) when `currentRoot` is set to C (0) wraps around to B (11) and drops `octaveShift` by 12 semitones (-1 Octave) so that the actual note drops down (e.g., C4 to B3). Similarly, wrapping `Root +` (`L`) from B (11) to C (0) shifts `octaveShift` up by 12 semitones (+1 Octave).

## User Feedback & Decisions
- When pressing `Root -` on C4, `currentRoot` wrapping to B should drop the octave so the pitch goes to B3 instead of jumping up to B4.

## Changes Made
- Modified `act == "rootDown"` in [qwerty_midi.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/qwerty_midi.lua#L1586): if `currentRoot == 0`, set `currentRoot = 11` and `octaveShift = math.max(-36, octaveShift - 12)`.
- Modified `act == "rootUp"` in [qwerty_midi.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/qwerty_midi.lua#L1598): if `currentRoot == 11`, set `currentRoot = 0` and `octaveShift = math.min(36, octaveShift + 12)`.

## What Worked
- Root down from C to B now smoothly drops the base pitch down by 1 semitone (dropping octave by -1) rather than wrapping up within the same octave.
- Reloaded Hammerspoon configuration seamlessly.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- `currentRoot` is a 0..11 integer representing root semitone offsets within the scale.
- `octaveShift` is added in pitch calculation `((octave + 1) * 12) + currentRoot + targetInterval + octaveShift`.
