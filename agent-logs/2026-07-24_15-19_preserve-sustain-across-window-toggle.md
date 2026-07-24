## Goal
Preserve active sustain state and held/latched notes when closing and reopening the MIDI controller window.

## User Feedback & Decisions
- Closing the MIDI controller should allow sustained notes to remain ringing in the DAW.
- Reopening the MIDI controller window must visually reflect that Sustain is still ON.
- Toggling/disabling sustain after reopening must release all held sustained notes properly.

## Changes Made
1. **`src/init.lua`**:
   - Removed state wipes (`state.sustainActive = false`, clearing `sustainedPitches`, CC #64 = 0, CC #123 = 0) from `toggleMidiMode` when hiding/closing the modal window.
   - When reopening the window, the HUD renders `state.sustainActive` (e.g. `SUS: ON` badge and gold active styling on `Tab`/`A` keys) correctly.
2. Re-bundled via `./bin/bundle_and_reload.sh`.

## What Worked
- Closing the window while sustain is active leaves notes sounding in the DAW.
- Reopening the window preserves `sustainActive = true` and UI indicator highlights.
- Pressing `Sustain` (`Tab` / `A`) after reopening toggles sustain OFF, sending `noteOff` for all tracked pitches and `CC #64 = 0` / `CC #123 = 0` to immediately stop the notes.

## Architecture Notes
- Closing the webview window should only suspend window visibility and key listeners; it must not clear active toggle states or send parameter reset MIDI messages unless explicitly triggered by Panic or Reset All controls.
