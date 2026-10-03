# Work Log: F Key Octave Assignment, Track-Colored Controls, Graphical Indicators & KeyStep Lower-Row Reversion

**Date:** 2026-10-03 17:05  
**Author:** Antigravity / Gemini 3.8 Flash (Low)

## 1. Objectives & Context
Addressed 4 key improvements and behavioral fixes across the multimodal Hammerspoon MIDI controller:
1. **F Key Octave Assignment (`octaveUp`)**:
   - Completely removed legacy ARP latch binding (`arpLatchToggle`) and loop lock overlays that interfered with physical key F (code 3).
   - Ensured F is dedicated to `octaveUp` (`Oct +`) on base layer, with `topVolUp` on Shift.
   - Migrated legacy custom layout presets in `src/config.lua` replacing any saved F `arpLatchToggle`/`lockLoop` with `octaveUp`.
   - Moved loop lock spotlight target in `src/controls.lua` from key 3 to key 11 (`B`).
   - Removed old `propCode == 3` latch overlay in `src/hud.lua`.

2. **Track-Colored Controls**:
   - Replaced boolean `isPerTrack: true` metadata with resolved `assignedTrackId`, `assignedTrackColor`, and `assignedTrackRgb` in `src/hud.lua`.
   - Bottom-row controls resolve to active bottom track (Track 1 or 2); top-row controls resolve to active top track (Track 3 or 4); track selectors point to their respective tracks.
   - Updated `.key-pad.per-track-ctrl` CSS and `renderHud` in `src/web/index.html` to dynamically assign and render `--assigned-track-color` and `--assigned-track-rgb` with glowing borders and high-contrast text.

3. **Graphical Performance Indicators**:
   - **88-Key Performance Piano Diagram (Footer)**: Added a compact 88-key piano diagram spanning MIDI notes 21 to 108 (A0–C8) at the bottom of `#performance-view`. Implemented `activeNoteLedger` in `src/midi.lua` at the MIDI emission boundary tracking active voices by channel/pitch/track, notifying the webview via `updatePianoNote`, clearing on panic, and rendering real-time voice track colors without layout jitter.
   - **Selected Chord Type Mini-Piano (Header)**: Added `#chord-mini-piano` inside `#chord-display-badge` displaying the 12 chromatic semitones (8 white keys, 5 black keys) of the selected chord type (and detected chords), highlighting root in active track color and chord tones in illuminated white.

4. **KeyStep Disconnected Lower-Row Reversion**:
   - When KeyStep is disconnected, the lower row (Z..M, codes 6..44) automatically reverts to bottom note input (tracks 1/2 note triggers) in `src/config.lua` and `src/hud.lua`.
   - When KeyStep is connected, the lower row functions as KeyStep hardware controls.
   - Home row (codes 48, 0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39) remains strictly identical in both configurations.
   - Key event resolution in `src/controls.lua` guards `getProposedActionDef` so keystrokes fall through to note handling when KeyStep is disconnected.

## 2. Changes Made
- [`src/config.lua`](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/config.lua): Added track `rgb` fields; added layout migration for F key; added dynamic `isKsConnected()` check in note/control maps; exported `isKeyStepConnected`.
- [`src/controls.lua`](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/controls.lua): Updated spotlight targets from `key-3` to `key-11` (`B`) and `key-45` (`N`).
- [`src/midi.lua`](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/midi.lua): Implemented `activeNoteLedger`, real-time `updatePianoNote` invocation, `getActiveNoteLedger()`, and `clearActiveNotes()`.
- [`src/hud.lua`](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/hud.lua): Guarded `getProposedActionDef` and spotlight for disconnected lower row; removed F key latch overlay; implemented `resolveAssignedTrackId`; exported `updatePianoNote` and `clearPianoNotes`.
- [`src/web/index.html`](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/web/index.html): Added CSS and markup for `.chord-mini-piano` and `.performance-piano-88-wrap`; implemented `initChordMiniPiano`, `updateChordMiniPiano`, `initPerformancePiano88`, `updatePianoNote`, `clearPianoNotes`, `syncActivePianoNotes`; updated `renderHud` key iteration.
- [`src/ui_html.lua`](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/ui_html.lua) & [`qwerty_midi.lua`](file:///Users/matt/projects/qwerty-midi-hammerspoon/qwerty_midi.lua): Rebuilt and bundled via `bin/hs-bundler`.
- [`tests/keystep_interceptor.test.js`](file:///Users/matt/projects/qwerty-midi-hammerspoon/tests/keystep_interceptor.test.js) & [`tests/keystep_gui.test.js`](file:///Users/matt/projects/qwerty-midi-hammerspoon/tests/keystep_gui.test.js): Updated assertions to match Envelope/ADSR shift mode.
- [`tests/f_key_and_track_colors.test.js`](file:///Users/matt/projects/qwerty-midi-hammerspoon/tests/f_key_and_track_colors.test.js): Created comprehensive test suite for all 4 objectives.
- [`AG_CONTEXT.md`](file:///Users/matt/projects/qwerty-midi-hammerspoon/AG_CONTEXT.md): Updated architectural documentation.

## 3. Verification
- `bun test`: All 47 tests passed across 11 test files (0 failures).
- `luac -p qwerty_midi.lua src/*.lua`: All Lua source and bundled files syntax validated with 0 errors.
- Hammerspoon reload triggered via `bin/bundle_and_reload.sh`.
