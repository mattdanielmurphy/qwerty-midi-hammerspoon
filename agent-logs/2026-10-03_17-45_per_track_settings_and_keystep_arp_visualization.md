# 2026-10-03 17:45 — Per-Track Settings, Full-Range 2-Control ADSR, KeyStep Arp Visualizer & Bottom Track Authority

## Context & Objectives
Matt requested:
1. Make these settings per-track: `Octave`, `Volume`, `Attack`, `Decay`.
2. Get rid of `Release`, and make `Attack` and `Decay` cover the full range of ADSR like on the KeyStep.
3. The KeyStep visualizer in the HUD must show the arpeggiating notes in real time.
4. The KeyStep must always control the selected bottom track.

## Implementation Details

### 1. Per-Track Settings (`src/config.lua`, `src/controls.lua`, `src/hud.lua`)
- **Per-Track Config & State**:
  - `state.tracks[1..4]` each initialize with independent `volume`, `octaveOffset`, `attack`, and `decay` loaded from `hs.settings` (`qwertyMidi_track{1..4}{Volume,OctaveOffset,Attack,Decay}`).
  - `config.saveSettings()` persists each track's settings to `hs.settings` and syncs active row variables (`state.bottomRowVolume`, `state.topRowVolume`, `state.bottomRowOctaveOffset`, `state.topRowOctaveOffset`).
  - Track selection (`selectTrack(id)`) in `src/controls.lua` synchronizes row-level properties so HUD volume bars, octave badges, and key offsets immediately reflect the chosen track.
- **Controls & MIDI CCs**:
  - Octave changes (`topOctDown/Up`, `botOctDown/Up`, `octaveDown/Up`) mutate `trk.octaveOffset` and call `saveSettings()`.
  - Volume changes (`topVolDown/Up`, `botVolDown/Up`, `volDown/Up`) mutate `trk.volume`, transmit MIDI CC 7 on the track's channel, and call `saveSettings()`.
  - Added `atkDown` / `atkUp`: mutates `trk.attack` (0..127) and sends CC 24 and CC 73 on the track channel.
  - Added `decDown` / `decUp`: mutates `trk.decay` (0..127) and sends CC 25, CC 26, CC 27, and CC 72 across the full envelope range, aliasing legacy `relDown` / `relUp`.
  - Number row key 25 (`9`) mapped to `atkDown` / `decDown` ("Atk -" / "Dec -"), and key 29 (`0`) mapped to `atkUp` / `decUp` ("Atk +" / "Dec +"). KeyStep lower row key 47 (`.`) and key 44 (`/`) shifted actions mapped to `decDown` / `decUp`.

### 2. Full-Range Two-Control ADSR on KeyStep (`packages/keystep-interceptor/keystep.lua`)
- Replaced the multi-stage cycling envelope and standalone Release mode with direct, dedicated controls:
  - Black key 8: `attack` (CC 24 / 73, label "ATTACK").
  - Black key 10: `decay` (CC 25, 26, 27, 72, label "DECAY").
- Created `dispatchShiftCC(shiftDef, ccVal)` helper that updates `trk.attack` / `trk.decay` and sends all constituent CCs across the track channel.
- Removed `ENVELOPE_STAGES` and `envelopeStageIdx` cycling from note-offs and GUI clicks.

### 3. KeyStep Bottom Track Authority
- In `packages/keystep-interceptor/keystep.lua`, `getFocusedTrack()` was tightened to strictly return `s.bottomRowTrack or 1`.
- Playable white notes, Rate/Vol knob adjustments, Mod strip actions, pitch bend, and CC dispatches always target the active bottom track (Track 1 or Track 2).

### 4. Real-Time Arp Visualization on KeyStep (`src/hud.lua`, `src/web/index.html`)
- In `src/hud.lua`, `fastUpdateArpNow()` extracts active arpeggio note pitches for the selected bottom track (`currentArpPitches[botTrkId]`) and forwards them via `window.updateArpPitches(activeCodes, heldCodes, bottomArpPitches)`.
- In `src/web/index.html`:
  - `window.updateArpPitches` folds each pitch into the KeyStep 41..72 range (notes F2 to C5) and applies `.active.arp-step` styling to both white and black slim keys.
  - Added distinct styling for `.ks-key-w.arp-step` and `.ks-key-b.arp-step` with glowing amber pulse indicators.
  - Shift class cleanup in `window.updateKeyStepState` updated to support `ks-shift-attack` and `ks-shift-decay`.

## Verification & Testing
- Bun test suite: All 53 tests passed across 13 test files (`bun test`).
  - Added new regression suite `tests/per_track_settings_and_keystep_arp.test.js` validating persistence, two-control ADSR CC emission, bottom-track routing authority, and KeyStep arp DOM classes.
- Bundler & syntax:
  - Bundled via `bash bin/bundle_and_reload.sh`.
  - Syntax verified with `luac -p qwerty_midi.lua` (0 errors).
  - Hammerspoon successfully reloaded.
