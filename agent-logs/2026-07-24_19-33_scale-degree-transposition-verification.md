## Goal
Verify and finalize the scale-degree transposition implementation in `src/transposer.lua` where transposing shifts base notes by scale degrees rather than a fixed semitone offset.

## User Feedback & Decisions
- Transposing should push every note down/up by one degree of the current active scale.
- For example, in C Major (`C D E F# G...`), +1 degree transpose transforms C D E F# to D E F# G.

## Changes Made
- [src/transposer.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/transposer.lua): Updated `getTransposedPitch` calculation. Scale degree offsets map `scaleIndex + state.transposeShift` to the target scale interval and recalculate octave wrapping cleanly.
- Bundled and reloaded Hammerspoon via [bin/bundle_and_reload.sh](file:///Users/matt/projects/qwerty-midi-hammerspoon/bin/bundle_and_reload.sh).

## What Worked
- Evaluated transposition math in Lua environment: verified that `C4` (pitch 60) with `transposeShift = 1` in C Major correctly returns `D4` (pitch 62).
- verified clean execution of Hammerspoon reload without errors.

## What Didn't Work / Known Issues
- `hs -c` required explicit package path addition for standalone execution; resolved by passing path in test snippet.

## Architecture Notes
- `WHITE_KEY_INDEX` maps semitone offsets in an octave (`0..11`) to natural scale degree positions (`0..6`). Scale intervals are retrieved dynamically from `SCALES[state.currentScaleIdx].intervals`.
