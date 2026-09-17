# Work Log: Track-Independent Sustain & Chord Mode with Smart Sustain Engine

- **Date**: 2026-09-17 11:45
- **Task**: Track-Independent Sustain & Chord Mode with Smart Sustain Engine
- **Files Modified**:
  - `src/config.lua`
  - `src/controls.lua`
  - `src/hud.lua`
  - `src/transposer.lua`
  - `packages/music-engine/harmony.lua`
  - `src/web/index.html`
  - `src/ui_html.lua`
  - `qwerty_midi.lua`
  - `DEVELOPMENT_JOURNAL.md`

## Summary of Changes
1. **Per-Track State Architecture (`config.lua`)**:
   - Added `sustainMode = "off"`, `sustainedPitches = {}`, `chordStartTime = 0`, `chordModeActive = false`, and `chordIdx = 1` to each track table in `state.tracks[1..4]`.
   - Updated Key 48 (Tab) to map `action = "sustain"` (Smart Sustain) and `shiftAction = "classicSustain"`.
   - Added `classicSustain` to `ACTION_CATALOG`.

2. **Smart Sustain Gesture Engine (`controls.lua`)**:
   - Implemented 120ms grouping window (`chordWindow = 0.12s`) for multi-finger chord strikes.
   - When in `sustainMode == "smart"`: notes remain latched across key release. When a new chord gesture begins (no physical keys held, or time > 0.12s), all previously sustained notes on that track that are not physically held down receive `noteOff` immediately, eliminating muddiness.
   - Preserves physically held notes (e.g. drone bass notes held with a pinky) while striking new chords.
   - Implemented Classic Sustain (`sustainMode == "classic"`) triggered via `Shift + Tab` or `Opt + Tab` where notes accumulate cumulatively.

3. **Track-Independent Chord Mode (`controls.lua`, `transposer.lua`, `harmony.lua`)**:
   - Chords evaluate `trk.chordModeActive` and `trk.chordIdx` for that specific track.
   - Bottom row (Tracks 1 & 2) can play full chords while Top row (Tracks 3 & 4) plays single-note leads or arpeggios simultaneously across dedicated MIDI channels.
   - Tap `'` (Key 39) toggles Chord Mode on the active track; `Shift + '` cycles chord voicing.

4. **HUD & Visual Telemetry (`hud.lua`, `index.html`)**:
   - Key 48 (Tab) displays `Smart Sus` (amber/gold glow) or `Classic Sus` (orange/cyan glow) or `Sustain` (off).
   - Key 39 (`'`) displays chord voicing and active state for the active track.
   - Track buttons (Keys 18–21) surface subtle `.trk-mode-tags` (`SUS` and `CHD`) so each track's mode is visible at a glance.
   - Wired `fastUpdateArp` and `renderHud` to stream `sustainMode` and `chordMode` in real time.

5. **Verification**:
   - Tested in Hammerspoon CLI (`hs -c`): verified track sustain isolation, Smart Sustain chord auto-reset, classic cumulative sustain, and simultaneous multi-track playing.
