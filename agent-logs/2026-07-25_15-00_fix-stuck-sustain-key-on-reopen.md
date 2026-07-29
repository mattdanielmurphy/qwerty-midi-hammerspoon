## Goal
Fix bug where toggling sustain ON, closing the MIDI controller window, and reopening it causes the sustain key (`Tab`) to become stuck in an ON state.

## User Feedback & Decisions
- Sustain status must be togglable upon reopening without getting stuck in an active state.

## Changes Made
1. `src/init.lua`: Added `state.sustainKeyDownTime = nil` in `toggleMidiMode` when hiding/closing the MIDI mode controller window.
2. `src/controls.lua`: Updated `handleKeyUp` sustain handler to guard `holdDuration` against `nil` timestamps (`local holdDuration = state.sustainKeyDownTime and (hs.timer.secondsSinceEpoch() - state.sustainKeyDownTime) or 0`).
3. Ran `bin/bundle_and_reload.sh` to update `qwerty_midi.lua` and reload Hammerspoon.

## What Worked
- Toggling sustain ON, closing the window, and reopening it now allows `Tab` key to properly turn sustain OFF when tapped.

## Architecture Notes
- When closing the controller window, key state references in `state.pressedKeys` are reset, but `sustainKeyDownTime` was previously left set with a historical timestamp.
- On reopening the window and pressing `Tab` (sustain key), `handleKeyUp` calculated `holdDuration` using the old `sustainKeyDownTime` from before the window was closed, which exceeded `0.25s` and forced the toggle branch to keep sustain set to `false = false` / `active = true`, causing sustain to lock ON.
