## Goal
Ensure activating Sustain while holding notes retroactively sustains all currently held notes when they are released.

## User Feedback & Decisions
- Pressing `Sustain` while keys are already physically down should sustain those held notes.

## Changes Made
1. **`src/controls.lua`**:
   - In `executeControlAction` for `sustain`/`latch`, added retroactive note tagging: iterates over `state.pressedKeys` and sets `isSustainedNote = true` and populates `state.sustainedPitches` for all physically held notes.
   - In `handleKeyUp`, checked `if isSustainedNote or state.sustainActive` to guarantee any key released while sustain is active gets tracked as a sustained note instead of releasing immediately.
2. Re-bundled via `./bin/bundle_and_reload.sh`.

## What Worked
- Holding down a chord and pressing `Sustain` (`Tab` / `A`) now latches/sustains the held notes when you let go of the keys.
- Toggling `Sustain` OFF afterwards releases all sustained notes cleanly.

## Architecture Notes
- `isSustainedNote` was previously captured only at `keyDown` time based on whether `sustainActive` was `true` at that moment. Activating sustain while notes were already down required retroactively updating the state of held keys.
