# KeyStep Manual Note Isolation

## Problem

The MIDI Control Center User Channel is 3, but direct physical key presses on
that channel were being decoded as sequencer notes. Channel filtering therefore
cannot distinguish the two streams.

## Solution

The interceptor now defaults to automatic cadence recognition. It only accepts
a C3–G3 mode note after three consecutive occurrences of the same pitch on the
same channel within a plausible sequencer step gap. Direct notes remain visible
as raw monitor input and candidates but cannot mutate Mode or Time Division.

## Verification

- Reloaded the standalone KeyStep bundle into running Hammerspoon in auto mode.
- `bun test tests/keystep_interceptor.test.js`: 7 passing tests.
- `luac -p` passed for all KeyStep modules and generated bundle.
