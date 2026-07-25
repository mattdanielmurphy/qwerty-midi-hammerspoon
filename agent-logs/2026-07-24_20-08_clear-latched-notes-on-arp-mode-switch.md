## Goal
Ensure changing Arp mode from `ARP: LATCH` to `ARP: ON` immediately clears latched notes that are no longer physically held down by the user.

## User Feedback & Decisions
- "changing from `ARP: latch` to just `ARP: no latch` shall clear the latched notes; it's very confusing otherwise."

## Changes Made
- Updated [src/arpeggiator.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/arpeggiator.lua): In `toggleArpPower()`, when transitioning from `state.arpLatchActive` (`ARP: LATCH`) to `ARP: ON`, filter `state.arpHeldNotes` to retain only keys present in `state.arpKeysCurrentlyHeld`. If no keys are physically held down, stop the arpeggiator timer and send noteOff for any active arp pitch.
- Updated [FEATURES.md](file:///Users/matt/projects/qwerty-midi-hammerspoon/FEATURES.md) to document the latch mode clearing behavior on mode transition.

## What Worked
- Bundled Lua modules via `bin/bundle_and_reload.sh` and reloaded Hammerspoon via AppleScript successfully.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- `state.arpHeldNotes` holds pitches actively feeding the arpeggiator (whether latched or physically held). `state.arpKeysCurrentlyHeld` tracks physical keypresses. Comparing the two on transition from `ARP: LATCH` to `ARP: ON` allows cleanly discarding latched keys that have been physically released.
