# KeyStep Channel Diagnostics and Logic Routing

## Evidence

- The Arturia MIDI Control Center screenshot shows `User Channel` set to `3`.
- The live Hammerspoon monitor was previously listening on zero-based channel 0
  (MIDI channel 1), so it could legitimately ignore a channel-3 sequence.

## Changes

- Added `setSequenceChannel(channel)` and raw incoming note/channel telemetry.
- Reloaded the live Hammerspoon interceptor with `sequenceChannel = 2`, which
  is MIDI channel 3 in one-based UI terms.
- The monitor now exposes the last raw note and its channel, allowing the exact
  sequencer channel to be verified while the device is playing.

## Routing constraint

`hs.midi` receives a copy of CoreMIDI input; it cannot prevent Logic Pro from
receiving the KeyStep's original physical note events. Logic must filter Notes
from its direct input or be configured to receive only a routed virtual/IAC
destination when the desired result is CC-only control.
