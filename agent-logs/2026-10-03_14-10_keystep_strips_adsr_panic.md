# Work Log: KeyStep Strip Routing, ADSR Controls, and Panic Recovery

**Date:** 2026-10-03
**Task:** Fix selected-track control colors, MIDI panic, Pitch/Mod strip behavior, simultaneous black-key holds, remove Mod-to-Volume, and provide two-control ADSR.

## Changes

- `src/controls.lua`: Selecting a track now requests a full HUD payload so track-dependent controls recolor immediately. Panic stops all track arps, clears pending quantized events, invokes KeyStep panic cleanup, resets sustain and held-note state, and reports whether a MIDI endpoint was available.
- `src/midi.lua`: Panic sends sustain-off, explicit note-offs, CC 123, CC 120, and controller reset on every channel.
- `packages/music-engine/quantizer.lua`: Panic increments a generation, cancels both queued-note and delayed gate timers, and prevents pre-panic callbacks from running afterward.
- `packages/keystep-interceptor/keystep.lua`: Uses Hammerspoon's `pitchWheelChange` command; routes Pitch and Mod to the focused track; stores parameters per track; refreshes both strip assignments and values when the active function or track changes; tracks held black keys by note so one release restores the next held mapping. A♯/B♭ cycles Attack, Decay, Sustain, Release and latches the ADSR edit target. Mod no longer maps to Volume.
- `src/web/index.html`: Displays function assignments on both strips, labels the ADSR selector, and replaces the obsolete Volume modifier styling.
- `AG_CONTEXT.md`, `implementation_plan.md`, `DEVELOPMENT_JOURNAL.md`: Record the new mapping and panic invariant.
- `src/ui_html.lua` and `qwerty_midi.lua`: Regenerated from source with `bin/hs-bundler --target qwerty-midi`.

## Design Decision

Use two control roles: the A♯/B♭ key selects an envelope stage, and the Mod strip edits it. Values remain independent. Defaults are Attack CC 24, Decay CC 25, Sustain CC 26, Release CC 27; these are preset mappings, not universal MIDI ADSR assignments.

## Verification

- The bundler completed and regenerated production outputs.
- Hammerspoon MIDI API docs identify `pitchWheelChange` as the 14-bit pitch-wheel command; prior source used the unsupported `pitchBend` string.
- Test suite and live MIDI-monitor checks were not run. Hardware confirmation is still needed for Pitch Bend, track-channel CC routing, ADSR learn mappings, and panic silence.
