# 2026-10-03 18:35 — Attack/Decay Track Colors, Per-Track Arp Direction & Quantizer Legato Mode

## Context & Objectives
User reported three problems:
1. Attack and decay keys never change to the selected track (and their colors should change to reflect the selected track too).
2. Arp direction doesn't change for at least one track.
3. Quantizer results in awkward silent gaps between notes when delaying note playback to align with the grid. Needed a legato mode that sustains the note that was being played (or just let go of) until the quantized note sounds on the beat.

## Implementation Details

### 1. Attack & Decay Dynamic Track Colors & Spotlights (`src/hud.lua`, `src/controls.lua`)
- **Key Binding & Track Resolution**:
  - In `src/hud.lua`, added key codes `25` (key `9`: `atkDown`/`decDown`) and `29` (key `0`: `atkUp`/`decUp`) to `resolveAssignedTrackId(cNum)` returning `activeTrkId`.
  - Keys 25 and 29 now dynamically receive `assignedTrackId`, `assignedTrackColor`, and `assignedTrackRgb`, activating the `.per-track-ctrl` CSS styling across both base and modifier layers.
  - The border and text colors of keys 9 and 0 now immediately change to reflect the active track color (Ch 1 Cyan `#00e5ff`, Ch 2 Amber `#ff9100`, Ch 3 Emerald `#00e676`, Ch 4 Magenta `#d500f9`).
- **Spotlight Feedback & Control Routing**:
  - In `src/controls.lua`, updated `atkDown`, `atkUp`, `decDown`, `decUp` to target `key-25` and `key-29` with `trk.color` instead of static green/gold, highlighting the actual key pressed.
  - Corrected `botTrackToggle` and `topTrackToggle` in `src/controls.lua` to toggle based on `state.bottomRowTrack` and `state.topRowTrack` respectively.
  - Added a fallback action dispatcher in `src/hud.lua` (`uc:setCallback`) to forward GUI action clicks directly to `controlsModule.executeControlAction(body.type)`.

### 2. Per-Track Arp Direction Ownership & Persistence (`src/config.lua`, `src/controls.lua`, `src/hud.lua`, `src/arpeggiator.lua`)
- **Config & State**:
  - Added `arpDirectionIdx = getSetting("track" .. i .. "ArpDirectionIdx", getSetting("arpDirectionIdx", 1))` to each track in `src/config.lua`.
  - Updated `config.saveSettings()` to persist `qwertyMidi_track{1..4}ArpDirectionIdx`.
- **Direction Synchronization & Engine Control**:
  - Added `setActiveArpDirection(dirIdx, targetTrackIdx)` and `getActiveArpDirectionIdx()` in `src/controls.lua` and `src/arpeggiator.lua`.
  - Wired `arpDirDown`, `arpDirUp`, and all preset directions (`arpDirRandom`, `arpDirConverge`, `arpDirDiverge`, `arpDirUpDown`, `arpDirDownUp`, `arpDirReset`) to update the active track's `trk.arpDirectionIdx` and `state.arpDirectionIdx`.
  - In `src/controls.lua:selectTrack(id)`, synced `state.arpDirectionIdx = trk.arpDirectionIdx or state.arpDirectionIdx or 1`.
  - In `src/hud.lua`, rendered `arpDirectionIdx = (activeTrk and activeTrk.arpDirectionIdx) or state.arpDirectionIdx or 1` so the header dropdown (`#arp-dir-select`) accurately reflects the active track upon track selection.

### 3. Quantizer Legato Mode (Zero-Gap Anticipation Sustaining) (`packages/music-engine/quantizer.lua`)
- **Legato Sustain Architecture**:
  - Introduced `soundingNotes` registry tracking active pitches, MIDI channels, key release states, and grace timers.
  - When `queueNoteOn` encounters a positive quantization delay (`delay > 0`), all sounding notes on that channel (whether held or in grace) are bound to `sEntry.heldForPending = eventId`, sustaining playback throughout the delay.
  - When the grid tick timer fires:
    1. Compares incoming pitches with sustained notes. For identical pitches, sends `noteOff` immediately prior to `noteOn` to ensure synth voices cleanly retrigger.
    2. Sounds the new quantized note via `onTrigger(pitches, vel, ch)`.
    3. Releases differing sustained notes via `onRelease(sEntry.pitches, sEntry.channel)`, achieving smooth legato crossfading without gaps.
  - When `queueNoteOff` is invoked while a quantized note is pending, release is deferred until the new note triggers. If no note is currently pending, a release grace window (`math.min(0.120, math.max(0.050, stepSec * 0.75))`) holds the voice so near-simultaneous subsequent strikes transition seamlessly.
  - Enhanced `quantizer.panic()` to cancel all grace and gate timers and release all sounding voices across channels.

## Verification & Testing
- Bun test suite: All 61 tests passed across 15 test files (`bun test`).
  - Added test suite `tests/attack_decay_arp_dir_and_legato_quantize.test.js` validating key coloring, track arp direction persistence, and quantizer legato mechanics.
- Bundler & syntax:
  - Bundled release via `bash bin/bundle_and_reload.sh`.
  - Syntax validated with `luac -p qwerty_midi.lua` (0 errors).
  - Hammerspoon reloaded and verified live: `domReady=true webview=true`.
  - State confirmed live: `activeTrack=1 arpDir=6 trk1Dir=6 trk4Dir=6`.
