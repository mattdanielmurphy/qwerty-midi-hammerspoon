## Goal
- Trigger a MIDI panic on module load to clear previous active MIDI notes.
- Auto-show the MIDI keyboard window whenever the Hammerspoon config reloads.
- Expand gate increments to be finer (5% steps) with range spanning from 1% to 150%.

## User Feedback & Decisions
- Auto-popup UI on config reload during active development.
- Finer gate steps with 1%-150% range support.

## Changes Made
- `src/config.lua`: Updated `ARP_GATES` to include options from 1% to 150% in 5% steps. Default `arpGateIdx` set to index 20 (95%).
- `src/init.lua`: Added `midi.panicAllChannels()` and `_G.toggleMidiMode(true)` on module load.
- Rebundled `qwerty_midi.lua` via `./bin/bundle_and_reload.sh`.

## What Worked
- Module loaded, sent MIDI panic to all channels, auto-opened the HUD window, and expanded gate controls cleanly.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- Initializing `_G.toggleMidiMode(true)` at module startup triggers `activeWatchers.midiKeyTap` and opens the webview UI automatically on reload.
