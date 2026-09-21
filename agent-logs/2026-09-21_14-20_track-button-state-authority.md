# Agent Log: Track Button State Authority

**Date**: 2026-09-21

## Problem

Track buttons could appear selected or unselected unpredictably while keys were pressed and released. The playback waveform also produced unreliable visual noise.

## Root Cause

`renderHud()` and the fast arpeggiator callback both mutated the same track-button DOM classes. In addition, the generic immediate key-state callback applied `.pressed` to track buttons. Those independent writers could arrive in a different order than the coalesced full state render.

## Fix

- Restrict `fastUpdateArp()` / `updateArpPitches()` to note-key arp animation only.
- Retain selection, mute, solo, human-key, and arp-step rendering exclusively in the authoritative full HUD payload.
- Ignore generic immediate keypress updates for keys 18–21.
- Disable track waveform telemetry and hide its overlay.
- Add `tests/track_button_authority.test.js` to prevent a second fast-path track-state writer from returning.

## Verification

- `bun test tests/track_button_authority.test.js` — 2 passed.
- `luac -p` passed for all `src/*.lua` modules.
- `bin/bundle_and_reload.sh` rebuilt the generated HUD bundle and reloaded Hammerspoon.
- `git diff --check` passed.
