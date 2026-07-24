## Goal
Fix unreliable tempo adjustments caused by rapid or repeated pressing of BPM increment/decrement buttons (`-` and `=`) when Logic Pro BPM sync is enabled.

## User Feedback & Decisions
- Adjusting tempo was unreliable when pressing increment/decrement buttons quickly or holding them down.

## Changes Made
- [src/arpeggiator.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/arpeggiator.lua):
  - Added debouncing (`0.15s`) to `setLogicBpmTarget()` AppleScript calls so key repeat and rapid button presses update the local arpeggiator state instantly while collapsing background Logic Pro UI automation into a single final target update.
  - Added task cancellation (`logicBpmTask:terminate()`) to cancel stale AppleScript processes when new tempo steps arrive before a previous automation call completes.
- Re-bundled modules into `qwerty_midi.lua` via `bin/bundle_and_reload.sh` and reloaded Hammerspoon.

## What Worked
- Rapidly pressing or holding `-`/`=` immediately updates local BPM and HUD display, while queuing a single debounced AppleScript call to sync Logic Pro without process collisions or script lockups.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- `setLogicBpmTarget()` launches background `osascript` tasks to automate Logic Pro UI accessibility controls (`slider 1 of group 1 of group 1 of window 1`). Rapid key repeating spawned concurrent AppleScript processes competing for System Events UI actions. Debouncing and terminating prior tasks stabilizes UI synchronization.
