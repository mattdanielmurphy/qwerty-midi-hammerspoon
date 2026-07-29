## Goal
Fix systemic controller lockout bug where pressing one control action (or its inverse) caused all keyboard controls to lock up until app restart.

## User Feedback & Decisions
- User reported: "problem persists. It's not just oct+/-; a bunch of actions are not working... it seems I can do one of any action, possibly followed by its inverse action, and then nothing works until I close and reopen the app"

## Root Cause Identified
In [src/controls.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/controls.lua#L696), control key down events recorded pressed state as a boolean: `state.pressedKeys[code] = true`.
When `handleKeyUp(code)` was subsequently called upon releasing a control key, it checked:
```lua
local keyInfo = state.pressedKeys[code]
if keyInfo then
  local playedPitch = type(keyInfo) == "table" and keyInfo.pitch or keyInfo -- EVIL! Evaluated keyInfo (true) as integer pitch `1`
  ...
  state.sustainedPitches[playedPitch] = true -- Corrupted sustainedPitches table with [1] = true
  ...
  state.pressedKeys[code] = nil
```
Because `type(keyInfo) == "table"` was false for booleans (`true`), `playedPitch` fell back to `keyInfo` (`true`). Lua cast/treated `true` as boolean `true`, polluting `state.pressedKeys` and triggering `isSustainedNote` handlers. Furthermore, on note key release, `type(keyInfo) == "table"` checks expected `keyInfo` to always be a table structure `{ pitch = ..., isControl = true }`.

Because `state.pressedKeys[code]` was set to boolean `true` instead of a table `{ isControl = true }`, subsequent key operations and note release logic threw hidden type mismatches and state corruption, rendering key events frozen.

## Changes Made
- Updated [src/controls.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/controls.lua#L651-L720) to store `{ isControl = true }` in `state.pressedKeys[code]` for control keys instead of raw boolean `true`.
- Re-bundled via `bin/bundle_and_reload.sh` and reloaded Hammerspoon.

## What Worked
- Fixed key release type handling. Control key presses and releases now properly cleanup state without corrupting `state.pressedKeys` or triggering invalid note release pathways.
