# DevTools Keyboard Passthrough Exception

## Goal
Allow normal keyboard typing in DevTools / Web Inspector when inspecting the Hammerspoon HUD webview, rather than having QWERTY MIDI intercept keypresses as musical notes or controls.

## User Feedback & Decisions
- Add an exception specifically for DevTools/Web Inspector windows so keys pass through natively when typing in the inspector window.

## Changes Made
- Modified [init.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/init.lua#L105-L117) eventtap listener (`_G.activeWatchers.midiKeyTap`).
- Checks `hs.window.focusedWindow()`. If the focused application is `Hammerspoon` or the window title contains `"Inspector"` or `"DevTools"`, the tap handler immediately returns `false` (allowing all keypresses to pass through directly to macOS/WebKit without triggering MIDI controls).

## What Worked
- Rebuilt bundle with `bundle_and_reload.sh` and verified syntax and execution.
