# Agent Work Log: Selected Track Persistence, Reverse Smart Sustain & Track-Colored Controls

**Date:** 2026-10-03 18:45  
**Topic:** Selected Track Persistence, Smart Sustain Default ON, Reverse Tab Damping & Global Track Color Theming  
**Files Modified:**
- `src/config.lua`: Added `hs.settings` loading and persistence for `activeTrack`, `bottomRowTrack`, `topRowTrack`, and per-track `track{n}SustainMode` defaulting to `"smart"`.
- `src/controls.lua`: Added instant `config.saveSettings()` on `selectTrack(targetId)`; implemented reverse sustain damping in `handleKeyDown` and `handleKeyUp` for `act == "sustain"` (Tab immediately damps ringing notes on active track, hold damps incoming note releases staccato, Option+Tab toggles sustain mode); updated `octaveDown`/`octaveUp` and `volDown`/`volUp` to mutate active track and present HUD spotlights in the track's color.
- `src/hud.lua`: Updated `resolveAssignedTrackId(cNum)` so that track selectors map to 1..4, global exceptions (Transpose 38/40, Root 4/37, Scale 5/41, Random 1) return `nil`, and all other controls return `activeTrkId`.
- `src/init.lua`: Restored saved `state.activeTrack` on startup and on `_G.toggleMidiMode(true)` via `controls.selectTrack`.
- `src/web/index.html`: Completely eliminated static gold `#ffd700` styling on `#key-48.latch-active`, `.key-pad.per-track-ctrl`, and `.trk-tag-sus.active`, theming them dynamically with `var(--assigned-track-color)` and `var(--assigned-track-rgb)` with glowing borders and luminous backgrounds.
- `src/ui_html.lua` & `qwerty_midi.lua`: Synchronized production offline bundle via `bin/bundle_and_reload.sh`.
- `tests/track_selection_and_reverse_sustain.test.js`: Added 5 unit tests covering persistence, reverse damping, global control exceptions vs track-assigned controls, and dynamic CSS styling.

---

### Key Implementations & Architectural Decisions

1. **Selected Track Persistence Across Reloads**:
   - `activeTrack`, `bottomRowTrack`, and `topRowTrack` are now loaded from `hs.settings.get("qwertyMidi_activeTrack")` during initialization and saved during `saveSettings()`.
   - `controls.selectTrack(targetId)` immediately invokes `config.saveSettings()`, ensuring that any track selection in the GUI or via keys (18..21) is persisted across Hammerspoon reloads.
   - On startup and whenever MIDI mode is re-entered via `_G.toggleMidiMode(true)`, `controls.selectTrack(state.activeTrack or 1)` is called to re-hydrate the selected track state and apply its properties.

2. **Default Smart Sustain ON**:
   - Each track in `config.lua` defaults `trk.sustainMode` to `getSetting("track" .. i .. "SustainMode", "smart")` instead of `"off"`.
   - Tracks 1..4 now boot with Smart Sustain active out of the box.

3. **Reverse Smart Sustain Functionality (Tab to Damp / Silence)**:
   - When Smart Sustain is active, striking `Tab` (Key 48) now acts as a panic/damping cutoff for the active track: `cleanupSustainPitches(activeTrkId)` is called immediately to silence ringing sustained notes, showing a HUD spotlight `DAMP / SILENCE (TRK X)` in the track's color.
   - While `Tab` is held down (`state.tabDamping = true`), notes played release immediately upon key release (staccato damping) rather than latching into sustain.
   - Releasing `Tab` resets `state.tabDamping = false`.
   - Hold snapshot restoration in `controls.lua` was explicitly exempted for `act == "sustain"` and `act == "classicSustain"` so holding Tab does not trigger snapshot reversion.
   - `Option+Tab` explicitly toggles sustain mode between `"smart"` and `"off"`.

4. **Dynamic Track-Colored Controls & Global Exceptions**:
   - When a track is selected, all controls change to that track and adopt that track's color (`--assigned-track-color` / `--assigned-track-rgb`).
   - The only exceptions affecting all tracks globally are:
     - Transpose +/- (J: 38, K: 40)
     - Root +/- (H: 4, L: 37)
     - Scale/Mode +/- (G: 5, ;: 41)
     - Random (S: 1)
   - In `hud.lua`, `resolveAssignedTrackId(cNum)` returns `nil` for these global controls, while all other control keys (Octave, Volume, Attack, Decay, Sustain, Chords, etc.) resolve directly to `activeTrkId`.
   - In `src/web/index.html`, `#key-48` and `.per-track-ctrl` elements are styled predominantly in the track's color with `0.16` opacity background, `0.65` opacity border, and dual glows.

---

### Verification & Testing
- Bun test suite: Ran all 66 tests across 16 test files; 100% passed (`tests/track_selection_and_reverse_sustain.test.js` included).
- Lua syntax validation: Executed `luac -p qwerty_midi.lua` with 0 errors.
- Hammerspoon reload: Rebuilt and reloaded successfully via `bin/bundle_and_reload.sh`.
