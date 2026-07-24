## Goal
Enable bi-directional tempo synchronization so that changing the BPM from the MIDI controller (via digit key entry, arrow keys, or UI drag) automatically updates the tempo in the active Logic Pro session.

## User Feedback & Decisions
- Tempo changes made on the controller should immediately reflect inside Logic Pro.
- Preserve non-blocking asynchronous AppleScript execution (`hs.task.new`) so HUD performance and arpeggiator timing remain 100% fluid.

## Changes Made
- `src/arpeggiator.lua`:
  - Added `pushBpmToLogic(newBpm)` using JSA with `AXIncrement` / `AXDecrement` accessibility actions to step Logic Pro's tempo element up/down to match `newBpm`.
  - Added `isPushingBpmToLogic` guard flag to prevent feedback loops where polling overwrites incoming user adjustments before Logic updates.
  - Updated `applyBpmChange(userInitiated)` to trigger `pushBpmToLogic` when BPM is altered by user actions.
- `src/controls.lua` & `src/hud.lua`: Updated BPM adjustment handlers (digit entry, arrow keys, click-and-drag) to pass `userInitiated = true`.
- Bundled modules via `bin/bundle_and_reload.sh`.

## What Worked
- Changing BPM via any controller method (e.g. typing a new BPM, pressing `0`/`-`/`=`, or dragging tempo display) automatically changes the session tempo inside Logic Pro.
- Guards prevent sync loop feedback while maintaining sub-second polling responsiveness when Logic's tempo is adjusted from within Logic.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- macOS Accessibility allows performing `AXIncrement` and `AXDecrement` actions on Logic Pro's `Tempo` UI element, modifying Logic's session BPM without interrupting playhead execution.
