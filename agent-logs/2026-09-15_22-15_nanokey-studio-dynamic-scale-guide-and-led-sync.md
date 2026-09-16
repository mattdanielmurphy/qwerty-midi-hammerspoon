# Session Log: Korg nanoKEY Studio Dynamic Scale Guide & Hardware LED Synchronization

**Date:** 2026-09-15 22:15  
**Author:** Antigravity  
**Target:** `packages/music-engine/harmony.lua`, `src/transposer.lua`, `src/config.lua`, `src/hud.lua`, `src/web/index.html`, `packages/nanokey-studio/nanokey.lua`, `bin/test-nanokey-leds`, `tools/nanokey-led-tester/main.swift`, `AG_CONTEXT.md`

## Problem & Objective
The built-in **Scale Guide** function on the **Korg nanoKEY Studio** is executed entirely inside the hardware MCU firmware with a static root note (defaulting to C). It never updates to follow software tracks, DAW harmony, or Hammerspoon transpositions unless physically re-transposed on the hardware using `[Shift/Tap]` + `[Octave +/-]`.
The objective was to verify external LED control via MIDI, design a software-defined Scale Guide in Hammerspoon, render dynamic scale degrees and root notes on the 25-key chiclet HUD, and synchronize real-time key backlight LEDs on the physical controller via MIDI `Note-On`/`Note-Off`.

## Reverse Engineering & Discoveries
1. **Hardware Scale Guide Isolation:**
   - The hardware MCU stores root and scale parameters locally in Scene RAM.
   - The controller does not detect incoming software musical keys passively.
   - However, the hardware exposes a CoreMIDI destination endpoint (`nanoKEY Studio Bluetooth` / `nanoKEY Studio`) capable of receiving standard MIDI messages (`0x90` Note-On / `0x80` Note-Off) on Channel 1 (`ch = 0`, notes 48..72) and Korg Native Mode SysEx frames.
2. **Korg External Feedback Model:**
   - Transmitting `Note-On` (velocity 127) to notes 48..72 targets the physical chiclet key backlights.
   - Transmitting `Note-Off` (velocity 0) extinguishes the backlight.

## Changes Implemented
1. **Harmony Engine (`packages/music-engine/harmony.lua`, `src/transposer.lua`):**
   - Added `getScaleGuideInfo(root, scaleIdx, minPitch, maxPitch)`: calculates `inScale`, `isRoot`, `degree` (1..7), diatonic roman numeral (`I`..`vii°`), and note names for pitches 48 to 72.
2. **Configuration (`src/config.lua`):**
   - Added `scaleGuideEnabled` state flag (default `true`) persisted via `qwertyMidi_scaleGuideEnabled` in `hs.settings`.
3. **HUD Controller & Sync Orchestration (`src/hud.lua`):**
   - Bundles `scaleGuide` metadata into `performWebviewHudUpdate`.
   - Added automated state detection comparing `lastSyncedRoot`, `lastSyncedScaleIdx`, and `lastSyncedScaleGuideEnabled` to automatically dispatch LED updates to the physical controller on any key/scale change.
   - Handled `nanokeyGuide` and `toggleScaleGuide` user content callbacks.
4. **Webview HUD Visualizer (`src/web/index.html`):**
   - Unlocked interactive `#nk-btn-scale-guide` (`GUIDE`) button with active gold styling (`#ffd700`).
   - Added dynamic CSS classes `.nk-key-root` (glowing gold border and `ROOT` degree), `.nk-key-in-scale` (illuminated white backlight and roman numeral), and `.nk-key-out-of-scale` (dimmed opacity 0.32).
   - Dynamically re-labels all 25 chiclet keys in real time when root note or scale transposes.
5. **nanoKEY Studio Hardware Driver (`packages/nanokey-studio/nanokey.lua`):**
   - Added `nanoKey.syncScaleGuideLeds(state, force)`: sends MIDI `noteOn` (vel 127) for in-scale pitches and `noteOff` (vel 0) for out-of-scale pitches across Channel 1 ($48 \dots 72$).
   - Hooks into `connect` (syncs on connect), `disconnect` (clears LEDs), and `handleGuiAction` (`guide` action).
6. **Hardware LED Testing Utility (`bin/test-nanokey-leds`, `tools/nanokey-led-tester/main.swift`):**
   - High-performance compiled Swift CLI providing interactive test sweeps: Scale Guide simulation (C Major, D Dorian), chromatic LED sweep (48..72), all-on/all-off, and Native Mode SysEx flash.

## Verification
- Rebuilt bundle with `bash bin/bundle_and_reload.sh`:
  - Web UI compiled cleanly into `src/ui_html.lua`.
  - 16 Lua modules bundled into `qwerty_midi.lua`.
  - Hammerspoon reloaded cleanly via AppleScript.
- Compiled `tools/nanokey-led-tester/main.swift` into `bin/test-nanokey-leds`.
- Verified git status and staged diffs.
