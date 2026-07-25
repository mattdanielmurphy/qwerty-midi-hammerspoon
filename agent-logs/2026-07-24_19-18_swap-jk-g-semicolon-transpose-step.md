## Goal
Swap keybindings for J/K and G/; home row controls, and update transpose operations (`trnspDown` / `trnspUp`) to step through scale degrees / root note instead of fixed semitones.

## User Feedback & Decisions
- J/K now trigger `Trnsp -` / `Trnsp +` (formerly on G/;).
- G/; now trigger `Mode -` / `Mode +` (formerly on J/K).
- Default transpose action shifted from single-semitone shift to scale-degree step (delegating `trnspDown` and `trnspUp` actions to `rootDown` and `rootUp`).

## Changes Made
- [src/config.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/config.lua): Swapped action mappings for `G` (`[5]`), `J` (`[38]`), `K` (`[40]`), and `;` (`[41]`).
- [src/controls.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/controls.lua): Updated `trnspDown` and `trnspUp` control execution logic to call `rootDown` and `rootUp`.
- Re-bundled standalone `qwerty_midi.lua` via `bin/bundle_and_reload.sh`.

## What Worked
- Key mappings updated smoothly in HUD and controls execution.
- Hammerspoon reloaded cleanly.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- `trnspDown` / `trnspUp` in `src/controls.lua` delegate directly to `rootDown` / `rootUp`, maintaining scale step behavior while preserving action naming compatibility across HUD updates.
