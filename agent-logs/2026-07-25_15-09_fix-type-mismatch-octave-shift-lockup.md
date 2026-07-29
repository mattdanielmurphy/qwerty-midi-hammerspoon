## Goal
Investigate and resolve the root cause of octave shift (`oct+/-`) and control key lockup issues where actions failed or stopped working.

## Root Cause Identified
In Hammerspoon settings (`hs.settings` / macOS `defaults`), certain numeric values like `qwertyMidi_octaveShift` had been saved as string representations (e.g. `"-24"`).
1. When `getSetting("octaveShift", 0)` read `qwertyMidi_octaveShift`, it returned string `"-24"`.
2. `state.octaveShift` was thus set to string `"-24"`.
3. In Lua 5.3+, expressions like `state.octaveShift >= 0` throw an unhandled Lua runtime error (`attempt to compare string with number`).
4. When `hud.updateWebviewHud()` evaluated `state.octaveShift >= 0` or when `octaveDown`/`octaveUp` ran, Lua threw an unhandled error inside the eventtap key callback.
5. This error interrupted key event processing mid-flight, leaving `state.pressedKeys` in an invalid state and locking up subsequent keyboard actions until app restart.

## Changes Made
1. **[src/config.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/config.lua#L1-L15)**: Updated `getSetting` to convert numeric string values to numbers via `tonumber()` when default is a number, and boolean strings to booleans when default is a boolean.
2. **[src/config.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/config.lua#L102-L130)**: Updated `saveSettings()` to strictly coerce state variables (`state.octaveShift`, `state.topRowOctaveOffset`, `state.transposeShift`, etc.) to numbers/booleans before persisting to `hs.settings`.
3. **[src/hud.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/hud.lua#L64-L78)**: Guarded `octaveShift`, `topRowOctaveOffset`, and `transposeShift` with `tonumber()` before applying `>= 0` relational comparisons.
4. **[src/controls.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/controls.lua#L160-L220)**: Added explicit `tonumber()` coercion in `octaveDown`, `octaveUp`, `topOctDown`, `topOctUp`, `trnspDown`, and `trnspUp` handlers.
5. **[src/settings_ui.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/settings_ui.lua#L431-L447)**: Converted all webview message payload values to proper types before assigning to `state` and `hs.settings`.
6. **Hammerspoon Reload**: Ran `bin/bundle_and_reload.sh` to bundle into `qwerty_midi.lua` and reload Hammerspoon.

## Verification
- Verified module build & AppleScript Hammerspoon reload completed cleanly with 0 errors.
- Verified numeric setting storage and safe string-to-number type coercion in event tap handlers.
