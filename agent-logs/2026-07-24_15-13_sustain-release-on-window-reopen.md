## Goal
Fix ringing notes issue where enabling sustain lock, playing notes, closing the MIDI window, reopening it, and disabling sustain failed to silence ringing notes in the DAW.

## User Feedback & Decisions
- Notes should stop ringing when sustain is disabled, even across MIDI controller hide/reopen cycles.

## Changes Made
1. **`src/init.lua`**:
   - Added `state.sustainActive = false`, `midi.sendMidiCC(64, 0)` (sustain off), and `midi.sendMidiCC(123, 0)` (all notes off) when closing/hiding MIDI controller mode in `toggleMidiMode`.
2. **`src/controls.lua`**:
   - Updated sustain key handling in `handleKeyUp` to issue `midi.sendMidiCC(123, 0)` (All Notes Off) whenever sustain mode transitions to OFF (`not state.sustainActive`).
3. Re-bundled via `./bin/bundle_and_reload.sh`.

## What Worked
- Closing the MIDI controller modal releases sustain and silences all lingering sustained notes in external DAWs or synths via standard MIDI CC #123 (All Notes Off) and CC #64 (0).
- Disabling sustain after re-opening also explicitly sends MIDI All Notes Off, guaranteeing any latched/sustained notes are silenced immediately.

## Architecture Notes
- When standard notes are pressed while `sustainActive` is `true`, their keyUp handler omits sending individual `noteOff` commands because pitch damping was delegated to CC #64. When the controller was closed, `pressedKeys` was reset without releasing CC #64 or notes, resulting in orphaned sustained notes in the synthesizer.
