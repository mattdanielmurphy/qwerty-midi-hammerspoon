# Agent Log: Per-Track Row ARP Controls and Track Telemetry Fix

**Date**: 2026-09-21

## Context

The README reported two regressions: Top/Bottom ARP controls did not affect the new independent track engines, and pressing a Bottom Row note could make the wrong track appear selected or show a false waveform.

## Changes

- Updated `src/controls.lua` so `arpTopToggle` targets `state.topRowTrack` and `arpBottomToggle` targets `state.bottomRowTrack` through `arpeggiator.toggleArpPower(trackId)`.
- Updated `src/hud.lua` webview callbacks to use the same control path instead of mutating legacy row-level ARP state directly.
- Added live `isTrackAudioActive(trackId)` telemetry derived from current pressed keys, sustained pitches, current arp pitch, and active arp gates; applied it to full and fast HUD payloads.
- Rebundled `qwerty_midi.lua` and reloaded Hammerspoon.

## Verification

- `luac -p` passed for every Lua module in `src/`.
- `bin/bundle_and_reload.sh` completed successfully.
- `git diff --check` passed.
