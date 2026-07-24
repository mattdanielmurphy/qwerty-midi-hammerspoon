## Goal
Ensure notes stop ringing when sustain mode is turned off without holding notes infinitely.

## User Feedback & Decisions
- Notes were ringing endlessly when sustain was enabled even without closing the MIDI controller window.

## Changes Made
1. **`src/controls.lua`**:
   - Removed `if not isSustainedNote` check in `handleKeyUp`. Always send `noteOff` when a note key is physically released.
   - MIDI CC #64 (Sustain Pedal) will handle sustaining notes in the synth engine while held/active, and turning sustain OFF (`CC #64 = 0`) will damp the sustained notes properly without needing manual note suppression in Lua.
2. Re-bundled via `./bin/bundle_and_reload.sh`.

## What Worked
- Releasing note keys now sends `noteOff` to the DAW/synth. When Sustain (CC #64) is active (127), synths keep the note sounding until CC #64 drops to 0, matching standard MIDI hardware pedal behavior.

## Architecture Notes
- Suppressing `noteOff` events in software meant the synth's voice engine received `noteOn` without any paired `noteOff`, leaving voices active indefinitely even when CC #64 was set to 0.
