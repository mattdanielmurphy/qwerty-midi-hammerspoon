# 2026-09-14 09:27 - Korg nanoKEY Studio Authentic Hardware GUI & Dual Macro Layer Integration

## Overview
Implemented complete end-to-end integration and an authentic hardware visualizer GUI for the physical **Korg nanoKEY Studio** MIDI controller within `qwerty-midi-hammerspoon`.

## Accomplishments
1. **Live Hardware Protocol Reverse-Engineering & Driver (`packages/nanokey-studio/nanokey.lua`):**
   - Discovered through live hardware sniffing that the unit's **Sustain** button sends `CC #25` (value 127 pressed, 0 released) on Channel 15.
   - Identified that the physical **Scene** button transmits native Korg SysEx (`0xf0 42 40 00 01 36 05 00 00 41 40 40 7f 00 f7` on press, `...00 00 f7` on release).
   - Upgraded `nanokey.lua` to manage dual hold-to-reveal macro layers:
     - `macro_sustain`: Holding Sustain exposes Transport (Play/Pause, Record, Rewind, Forward) and macOS Window Management (Left Half, Right Half, Maximize, Restore Win) on trigger pads 1–8.
     - `macro_scene`: Holding Scene exposes Presets (1–8), System Launchers (Terminal, Logic Pro, Browser), Scale Cycle, Audio Mute, and MIDI Panic across the 8 trigger pads and 25 chiclet keys.
   - Integrated auto-reconnect via `hs.midi.deviceCallback`.

2. **Macro Dispatch Engine (`packages/nanokey-studio/macros.lua`):**
   - Added handlers for window tiling, screen restores, scale cycling, and system shortcuts with native macOS HUD notifications (`hs.alert`).

3. **Hammerspoon HUD Integration (`src/hud.lua`, `src/init.lua`):**
   - Added `updateNanoKeyControl` for real-time WebKit telemetry dispatching.
   - Added `setSurfaceView(surface)` to dynamically transition window height between 280px (QWERTY layout) and 380px (nanoKEY Studio layout) with coordinate preservation.
   - Wired WebKit IPC `switchSurface` message handlers.

4. **Authentic Hardware Webview UI (`src/web/index.html`):**
   - Extracted authentic geometric silhouette and proportions directly from official Korg Blueprint (PDF page 7).
   - Added `#surface-switcher` button pair in `#header` (`💻 QWERTY` vs `🎹 nanoKEY`).
   - Implemented `#nanokey-view` DOM:
     - **8 Rotary Knobs (2x4)** with dynamic CSS rotation angles mapped to CC #14–21.
     - **KAOSS Touchpad** with cyan grid display, coordinate telemetry readout, and crosshair positioning.
     - **8 Trigger Pads (2x4)** with velocity hit animation and dynamic label swapping between chords and macro functions.
     - **Middle Control Buttons** for Octave -/+, Scale Guide, Easy Scale, Touch Scale, Chord Pad, Arp, Scene, and Sustain.
     - **25 Chiclet Keys** (15 white keys, 10 black keys centered with `transform: translateX(-50%)`) covering C3 to C5 with Roman numeral scale degrees.
   - Implemented `window.setSurface`, `window.onSurfaceChanged`, and `window.updateNanoKeyState`.

5. **Build & Bundler Preset (`bin/hs-bundler`):**
   - Added `packages/nanokey-studio` to the default `qwerty-midi` bundling target.
   - Bundled all 15 modules into `qwerty_midi.lua` and `~/.hammerspoon/modules/qwerty_midi.lua`.
   - Verified clean syntax via `luac -p qwerty_midi.lua`.
