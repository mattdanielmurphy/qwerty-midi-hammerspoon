# 2026-07-25 — UI Reflow, Compact Presets, Text Input Focus Fix, Q Note Reversion & Multi-Key Selection

## Overview
Implemented comprehensive UI/UX fixes for the QWERTY MIDI HUD layout editor:
1. Reverted `Q` key back to standard musical note (keycode 12, baseNote 72).
2. Reflowed keyboard grid in Edit Mode so opening the Action Library drawer scales/compacts the keyboard layout to the left without obscuring any keys (`P`, `[`, `]`, `;`, `'`, `.`, `/`).
3. Made the Layout Preset bar ultra-compact to grant maximum vertical height to the action list.
4. Resolved search box / modal input focus by adding `textInputFocus` IPC message in `src/hud.lua` and bypassing `midiKeyTap` event tap when typing.
5. Added click selection, Shift-click multi-selection, marquee box drag-selection, right-click context menu, and Delete/Backspace hotkey clearing to revert key pads back to musical notes.

## Files Modified
- `src/config.lua`
- `src/init.lua`
- `src/hud.lua`
- `src/web/index.html`
- `src/ui_html.lua`
- `qwerty_midi.lua`
