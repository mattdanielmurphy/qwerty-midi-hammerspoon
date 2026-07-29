# Fix Focused Window Keyboard Bypass Logic

## Goal
Resolve intermittent keyboard input cutoff caused by `app:name() == "Hammerspoon"` matching the HUD webview window when focused.

## User Feedback & Decisions
- Input stopped working mysteriously and then resumed when focus shifted.
- Issue was traced to `app:name() == "Hammerspoon"` matching HUD webview focus.

## Changes Made
- Updated [init.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/init.lua#L108-L115) eventtap listener exception logic.
- Restricted the passthrough check strictly to windows with titles containing `"Inspector"` or `"DevTools"` rather than any Hammerspoon app window.

## What Worked
- Rebuilt bundle with `bundle_and_reload.sh` and reloaded Hammerspoon.
