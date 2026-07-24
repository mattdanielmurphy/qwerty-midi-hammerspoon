# Agent Work Log: UI Readability, Zoom Persistence, Glowing Outlines & Layout Fixes

## Goal
Improve HUD readability at 100% mod intensity, fix zoom level baseline (100% = old 140%) and settings persistence (preventing shift-key zoom jumps), remove `(R)` text, add distinct glowing outlines for root/3rd/5th notes, make change notifiers icon-based with longer hold time, stabilize mode bar size, place octave badges beside top/bottom key rows, fix rounded container corner overflow, and swap home row keybindings so Mode +/- is default on J/K.

## User Feedback & Decisions
- Mod intensity overlay washed out text contrast at 100% intensity -> Toned down overlay opacity & added high-contrast text styling with text-shadows.
- Square corners appearing around container -> Added `overflow: hidden;` to `#hud-container` and set `.mod-gradient-overlay` border radius to `inherit`.
- Zoom level kept resetting & shift key triggered zoom jump -> Saved `zoomLevel`, `hudX`, `hudY` into `hs.settings` and set default 100% zoom baseline to 1.4x scale factor.
- `(R)` / `(3rd)` text clutter -> Removed text suffixes, relying on distinct glowing outlines.
- Root, 3rd, 5th notes -> Root: Gold glowing outline, 3rd: Terracotta/Coral glowing outline, 5th: Sage/Teal glowing outline.
- Notifiers disappearing too quickly & text heavy -> Extended hold time to 1.0s and reformatted to icon-driven metrics (`🔊 Master Volume`, `🎛️ Mod Wheel`, `🎼 Scale`, `🎹 Global Octave`, `⬆️ Top Row Octave`, `🎵 Root Note`, `🦶 Sustain`, `🔍 Zoom`).
- Mode bar growing/shrinking on shift -> Fixed `.mode-slider-track` width to `100px` and `.badge` to `58px`.
- Octave indicators -> Added top octave indicator badge beside `upper` row (`⬆️ Oct +1`) and bottom octave indicator badge beside `lower` row (`⬇️ Oct +0`).
- Home row keybindings -> `J` and `K` are now `Mode -` and `Mode +` by default (holding Shift triggers `Mod -` and `Mod +`).

## Changes Made
- Modified `qwerty_midi.lua` to:
  - Add `hs.settings` persistence for zoom scale and window coordinates (`qwertyMidi_zoomLevel`, `qwertyMidi_hudX`, `qwertyMidi_hudY`).
  - Update `#hud-container` CSS with `overflow: hidden;` and `.mod-gradient-overlay` with `border-radius: inherit;` and max `0.08` opacity gradient.
  - Implement 3 glowing outline CSS variations (`root-key`: Gold, `third-key`: Terracotta, `fifth-key`: Sage Teal).
  - Add `.row-with-indicator` and `.octave-row-badge` elements to HTML grid.
  - Update JS `showSpotlight` timer to 1000ms and JS `renderHud` to update top and bottom octave badges dynamically.
  - Update home row controls table to place Mode - and Mode + on unshifted J and K.

## What Worked
- Verified Lua syntax cleanly with `luac -p qwerty_midi.lua`.
- Confirmed smooth Hammerspoon configuration reload.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- Using `hs.settings` ensures window frame position and scale factor are durably saved across Hammerspoon restarts and HUD open/close toggles.
- Keeping fixed widths on static HUD controls prevents reflow layout shifts when modifier keys or status text update.
