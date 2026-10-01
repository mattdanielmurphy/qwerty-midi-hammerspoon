# KeyStep Marker Note Routing

## Design change

The KeyStep sequences now emit C8–G8 (MIDI 108–115) at velocity 1. This is an
unambiguous sentinel range outside the user's normal performance notes, so the
interceptor no longer relies on MIDI channel or timing heuristics.

## Behavior

- C8–G8 note-ons at velocity 1 map immediately to mode positions 1–8 and are
  never forwarded to the QWERTY/Logic MIDI output.
- Their note-offs are swallowed too.
- All non-marker note-on/note-off events are forwarded unchanged through the
  existing QWERTY MIDI output; derived mode, division, and rate become CC
  102/103/104 on that same output.

## Verification

- `bun test tests/keystep_interceptor.test.js`: 7 passing tests.
- `luac -p` passed for all package Lua sources and the generated standalone
  bundle.
- Direct AppleEvent reload was blocked by macOS Automation permissions; the
  user must evaluate the one-line reload in Hammerspoon Console or grant the
  caller Automation permission.
