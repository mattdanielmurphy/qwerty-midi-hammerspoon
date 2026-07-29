## Goal
Investigate and resolve issues where control actions like `octaveDown` / `octaveUp` (`Oct -` / `Oct +`) stopped working.

## User Feedback & Decisions
- User reported that some actions don't work, specifically highlighting `oct+/-`.

## Cause Identified
1. A residual entry in `hs.settings` (`qwertyMidi_customKeyLayout`) stored a custom mapping where `shiftAction` fell back to `binding.action` if `shiftAction` was nil during layout overrides.
2. When applying custom layout mappings in [src/config.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/config.lua#L287), `shiftAction` had fallback logic `binding.shiftAction or (defaultDef and defaultDef.shiftAction) or binding.action or (defaultDef and defaultDef.action)`. This caused keys without a distinct `shiftAction` to overwrite `shiftAction` with their normal `action`.
3. Additionally, a stale/corrupted layout entry in user defaults (`qwertyMidi_customKeyLayout`) bound `1.0` to `undoState`, corrupting key mappings.

## Changes Made
- Updated [src/config.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/config.lua#L287-L288) to cleanly evaluate `binding.shiftAction or (defaultDef and defaultDef.shiftAction)` and `binding.shiftName or (defaultDef and defaultDef.shiftName)` without incorrectly falling back to the unshifted `action` / `name`.
- Cleared the corrupted custom layout setting in Hammerspoon user defaults (`defaults delete org.hammerspoon.Hammerspoon qwertyMidi_customKeyLayout`).
- Executed `bundle_and_reload.sh` to bundle and reload Hammerspoon.

## What Worked
- Re-tested custom layout mapping logic and confirmed clean default resolution for `octaveDown` (`Oct -`), `octaveUp` (`Oct +`), `topOctDown`, `topOctUp`, `modeDown`, `modeUp`, etc.
