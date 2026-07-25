## Goal
Investigate and fix why Hammerspoon reloading was taking ~50 seconds instead of the usual 5-10 seconds.

## User Feedback & Decisions
N/A

## Changes Made
- Modified `panicAllChannels` in `src/midi.lua`. Removed a nested loop that was iterating over all 16 channels and all 128 notes per channel to explicitly send `noteOff` (2048 synchronous `sendCommand` calls).
- Retained the standard MIDI panic control change messages (CC 64, 120, 121, 123 - All Notes Off/All Sound Off) which efficiently handle hanging notes.

## What Worked
- Removing the massive loop returned the Hammerspoon reload process back to its nearly instantaneous speed. The reload no longer blocks the main thread.

## What Didn't Work / Known Issues
None.

## Architecture Notes
- Hammerspoon executes Lua on a single main thread. Apple's CoreMIDI `MIDISend` function, when called thousands of times consecutively without yielding, will cause a massive stall. 
- Avoid iterating over all possible notes across all channels in a single synchronous pass. Standard MIDI CC panic messages are widely supported and avoid this overhead.
