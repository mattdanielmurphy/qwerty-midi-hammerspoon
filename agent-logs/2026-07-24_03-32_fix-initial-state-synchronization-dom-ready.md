# Agent Work Log: Fix Initial HUD State Synchronization via domReady Callback

## Goal
Fix uninitialized initial HUD state when the window is first opened/toggled (where note labels, scale names, root badges, and pitch offsets remained unpopulated until the user struck a key).

## Root Cause Discovery
`updateWebviewHud()` was scheduled via `hs.timer.doAfter(0.01)` inside `createMidiWebview()`. At 0.01s (10 milliseconds), WebKit HTML parsing was incomplete and JS `renderHud` function was undefined, causing the initial state payload to fail silently. The webview displayed blank/unpopulated static fallback HTML until a keypress invoked `updateWebviewHud()` again.

## Changes Made
1. **Added `domReady` JS message posting**:
   Inside JS `DOMContentLoaded` event listener, posted `{ type: 'domReady' }` to `midiControllerUC`.
2. **Handled `domReady` in Lua `createMidiWebview`**:
   Upon receiving `domReady`, Lua immediately calls `updateWebviewHud()`, populating note labels, root badge, scale mode, transpose, and octave states at the exact millisecond DOM execution is ready.
3. **Staggered fallbacks**:
   Added `0.05s` and `0.25s` timer fallbacks to ensure full state population across all system loads.

## What Worked
- Verified Lua syntax cleanly with `luac -p qwerty_midi.lua`.
- Confirmed immediate state population upon window creation.
