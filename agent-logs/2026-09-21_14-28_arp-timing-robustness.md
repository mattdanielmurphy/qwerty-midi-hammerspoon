# Arp Timing Robustness

## Root cause

- Gate callbacks were keyed only by pitch. A callback that had already been queued could emit a late note-off after that pitch had been retriggered.
- Every note-on and gate-off performed a synchronous WebKit arp visual update on the real-time scheduling path.

## Changes

- Added a monotonic per-track gate generation. Only the timer generation currently owning a pitch may send its note-off or clear playback state.
- Coalesced arp visual updates through a zero-delay scheduler, preserving the latest visual state while avoiding duplicate WebKit work within the same Hammerspoon turn.
- Added `tests/arpeggiator_timing.test.js`; updated the existing HUD authority test for the renamed internal renderer.

## Verification

- `bun test` passed: 4 tests, 0 failures.
- `bash bin/bundle_and_reload.sh` regenerated `qwerty_midi.lua` and requested a Hammerspoon reload.
