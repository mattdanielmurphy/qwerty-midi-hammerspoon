# 2026-07-25 — Disable Auto-Show MIDI Controller on Reload

## Problem
On script reload (`hs.reload()` or after `bin/bundle_and_reload.sh`), `src/init.lua` called `_G.toggleMidiMode(true)` automatically. This popped up the HUD window and grabbed keyboard focus every time Hammerspoon reloaded or an agent finished a feature.

## Solution
Removed `_G.toggleMidiMode(true)` from top-level startup in `src/init.lua`. Hammerspoon now reloads silently in the background without stealing focus or displaying the HUD window until manually activated via `Cmd+Alt+M`.
