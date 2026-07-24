## Goal
Fix MIDI Panic button so sustained or lingering notes in Logic Pro are completely cleared, even after Hammerspoon reload or lost note-state.

## User Feedback & Decisions
- User requested a proper MIDI panic that truly clears all notes in Logic Pro.

## Changes Made
- Added `panicAllChannels()` in `src/midi.lua`:
  - Loops channels 0..15.
  - Sends CC 64 (0), CC 120 (0), CC 123 (0), CC 121 (0).
  - Sends explicit `noteOff` commands for all 128 pitches across all channels.
- Updated `src/controls.lua`:
  - `panic` action calls `midi.panicAllChannels()` and clears `state.sustainActive`.
- Bundled `qwerty_midi.lua` and reloaded Hammerspoon.

## What Worked
- Full 16-channel sweep + note-off burst successfully forces soft synths (including Logic Pro) to stop all active notes and release sustain.

## Architecture Notes
- Single-channel CC 123 is ignored by multi-channel or multi-timbral synths in DAWs if notes were triggered on a different channel or locked by sustain CC 64. A complete 16-channel sweep with explicit Note Offs resolves this.
