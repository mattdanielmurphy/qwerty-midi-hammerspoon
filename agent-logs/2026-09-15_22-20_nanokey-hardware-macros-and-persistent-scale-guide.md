# Agent Work Log: nanoKEY Studio Hardware Macros & Persistent Scale Guide

**Date:** 2026-09-15 22:20  
**Conversation ID:** c34a5878-de60-410b-a2d4-74b349e62f07  
**Commit Range:** b53ed1c7 -> HEAD  

## 1. Objectives & Context
1. Clarify that the physical hardware controller button is `Scale Guide`, and that it cannot be read or controlled directly over MIDI/BLE (inert GPIO).
2. Enable Scale Guide via the GUI and via hardware macros using the shift-style keys we can read (`Sustain` and `Scene`), designating `Sustain` as the main Shift key.
3. Ensure Scale Guide is enabled by default (`true`).
4. Resolve why the nanoKEY Studio key LEDs were off despite Scale Guide being enabled in the GUI:
   - Identify that nanoKEY Studio hardware out of the box has its LED illumination mode set to **Internal** (local keypresses & local DSP only), ignoring external MIDI `Note-On` unless configured to **External** via Korg Kontrol Editor.
   - Fix `src/init.lua` lifecycle where `nanokey.connect()` was only invoked on QWERTY HUD opening and was disconnected when the HUD window closed.

## 2. Changes Made
- `packages/nanokey-studio/macros.lua`:
  - Added `["Toggle Scale Guide"]` macro handler: toggles `config.state.scaleGuideEnabled`, persists settings to `hs.settings`, calls `nanokey.syncScaleGuideLeds()`, refreshes `hud.updateWebviewHud()`, and fires a prominent Hammerspoon on-screen HUD alert (`🎹 Scale Guide: ON / OFF`).
  - Updated `macros.execute()` to prevent double alerts when toggling Scale Guide.
- `packages/nanokey-studio/nanokey.lua`:
  - Added 2-key chord detection between shift keys: pressing `Scene` while `Sustain` is held (or pressing `Sustain` while `Scene` is held) immediately executes `"Toggle Scale Guide"`.
  - Mapped Pad 8 to `"Toggle Scale Guide"` in `padSustainMacros` (when `Sustain` is held as main Shift key) and in `padSceneMacros` (when `Scene` is held).
  - Updated `handleGuiAction("guide", ...)` to toggle state, notify webview HUD, and show on-screen status alert.
- `src/init.lua`:
  - Added `nanokey.connect("nanoKEY Studio")` during initial module evaluation so the hardware controller driver connects immediately upon Hammerspoon launch/reload without requiring the QWERTY HUD window to be open.
  - Removed `nanokey.disconnect()` from `_G.toggleMidiMode(false)`, ensuring the hardware MIDI connection, macros, and live playing remain active continuously even when the QWERTY MIDI HUD window is closed.
- `src/web/index.html` & `src/ui_html.lua`:
  - Renamed the button cap from `GUIDE` to `SCALE GUIDE` with dedicated CSS (`min-width: 46px; font-size: 6px; padding: 0 3px; white-space: nowrap;`).
  - Added tooltip: `"Scale Guide Mode (Sustain+Scene or Sustain+Pad 8 to toggle)"`.

## 3. Verification & Testing
- Simulated hardware `Sustain + Scene` chord in Hammerspoon: verified `qwertyMidi_scaleGuideEnabled` toggled smoothly (`true -> false -> true`).
- Simulated hardware `Sustain + Pad 8` hit in Hammerspoon: verified `qwertyMidi_scaleGuideEnabled` toggled smoothly (`true -> false -> true`).
- Verified `nanokey.isConnected()` returns `true` immediately upon reload, even when QWERTY MIDI HUD is closed.
- Bundled via `bash bin/bundle_and_reload.sh` without warnings.
