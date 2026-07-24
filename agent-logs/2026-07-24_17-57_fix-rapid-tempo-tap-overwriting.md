## Goal
Fix bug where tapping tempo increment/decrement buttons quickly in succession dropped step changes or got overwritten by background Logic Pro sync polls.

## User Feedback & Decisions
- Fast consecutive keypresses on increment (`=`) dropped subsequent taps, causing double-taps to only increment once.

## Changes Made
- [src/arpeggiator.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/arpeggiator.lua):
  - Updated `syncLogicBpm()` poll to return early whenever `logicBpmDebounceTimer` is active, preventing background 1-second sync reads from overwriting pending user tempo taps.
  - Added guard check `not logicBpmDebounceTimer` before applying read BPM values.
- Re-bundled modules into `qwerty_midi.lua` via `bin/bundle_and_reload.sh` and reloaded Hammerspoon.

## What Worked
- Every rapid keypress on `-` or `=` increments/decrements `state.arpBpm` immediately, and background Logic Pro sync waits until typing/tapping stops before executing the UI update.

## What Didn't Work / Known Issues
- None.
