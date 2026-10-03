# Work Log: Per-Track Colors, Vim Inc/Dec Keys, Scale Guide Subtlety, Real-Time Chord Detection

**Date:** 2026-10-03 11:41
**Task:** 
1. Track per-track controls dynamic theming (Arp, Sustain, Chord, Rate, Gate) to active track color.
2. Restore dedicated Vim inc/dec keys on Home row (no Shift required) and free Lower row (ZXCVB...) for control keys when KeyStep is connected.
3. Make out-of-scale key styling subtle without dimming (keeping all keys pressable).
4. Logic Pro-style real-time chord detection LCD badge.
5. Identify root cause of keypress/release CSS redraw blur & add investigation task to Project Board.

## Key Changes
- **Project Board (`/Users/matt/projects/ai-os/PROJECT_BOARD.md`)**:
  - Added `- [ ] Investigate and eliminate remaining keypress/release CSS transition blur and WebKit redrawing in QWERTY HUD [project:: qwerty-midi-hammerspoon] [assignee:: agent]`.
- **Chord Detection Engine (`packages/music-engine/harmony.lua` & `src/transposer.lua`)**:
  - Implemented `detectChord(pitches, root, scaleIdx)` matching triads, sevenths, ninths, power chords, suspended chords, and slash chord inversions with diatonic preference.
  - Exported through `transposer.detectChord`.
- **Config & Layout (`src/config.lua` & `src/hud.lua`)**:
  - Restored Vim keys on Home row: `D`/`F` (Oct -/+), `G`/`;` (Mode -/+), `H`/`L` (Root -/+), `J`/`K` (Trnsp -/+).
  - Added lower row control layout mapping (`Z`-`V`: Tracks 1-4, `B`: Lock Loop, `N`: Stop Loops, `M`/`,`: Vol -/+, `.`/`/`: Mod -/+) when `state.keystepConnected` is active.
  - Tagged per-track controls (`isPerTrack = true`) on keys 0 (`A`), 48 (`Tab`), 39 (`'`), 23 (`5`), 22 (`6`), 26 (`7`), 28 (`8`).
- **Web UI (`src/web/index.html` & `src/ui_html.lua`)**:
  - Replaced key dimming (`opacity: 0.65`) with subtle in-scale dot accents and solid tactile key surfaces.
  - Added `.per-track-ctrl` CSS dynamic styling bound to `var(--active-track-color)`.
  - Added `#chord-display-badge` LCD badge styling.
  - Removed `0.32s` transition delays on `.latch-dot`.
- **IPC Optimization (`src/hud.lua`)**:
  - Updated `updateSingleKeyState` to pass real-time active chord string to WebKit JS without triggering full HUD re-render.
