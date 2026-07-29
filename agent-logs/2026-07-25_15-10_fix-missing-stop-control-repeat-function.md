## Goal
Fix single-action lockup where pressing any control action worked ONCE on app open, after which all actions stopped responding until app restart.

## Root Cause Identified
In [src/controls.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/controls.lua#L705), auto-repeat logic and keyUp handlers invoked `stopControlRepeat(code)` upon control key press and release. However, `stopControlRepeat` was never defined in `controls.lua`, leaving it as a `nil` global function.

As a result:
1. When any control key was pressed, the action executed first, but immediately afterward `stopControlRepeat(code)` threw an uncaught Lua runtime error (`attempt to call global 'stopControlRepeat' (a nil value)`).
2. The uncaught error aborted the eventtap callback prematurely.
3. `state.pressedKeys[code]` remained populated because key cleanup was bypassed.
4. On subsequent key presses, `if not state.pressedKeys[code]` evaluated to `false`, silently ignoring all future control inputs until app restart.

## Changes Made
1. Defined `stopControlRepeat(code)` helper in [src/controls.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/controls.lua#L15-L25) to safely stop and clean up `timer` and `interval` instances in `controlRepeatTimers[code]`.
2. Executed `bin/bundle_and_reload.sh` to update `qwerty_midi.lua` and reload Hammerspoon.

## Verification
- Verified `stopControlRepeat` function definition in `src/controls.lua` and bundled output.
- Verified Hammerspoon reload completed cleanly with 0 errors.
