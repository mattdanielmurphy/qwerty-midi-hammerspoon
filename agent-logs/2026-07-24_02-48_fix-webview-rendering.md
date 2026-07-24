## Goal
Fix webview rendering failure caused by body zoom property conflict and restore clean transparent rounded window bounds.

## User Feedback & Decisions
- Webview was not rendering after previous change.

## Changes Made
- Fixed [qwerty_midi.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/qwerty_midi.lua):
  - Restored `#hud-container` `transform: scale(zoomLevel)` with `-webkit-font-smoothing: antialiased`.
  - Kept dynamic window frame resizing `wv:frame({ w = 760 * zoomLevel, h = 230 * zoomLevel })`.
  - Configured `wv:transparent(true)` and `wv:windowStyle({"borderless", "utility"})` with explicit `wv:show()` call so macOS WebKit renders cleanly.

## What Worked
- Webview renders properly again on config reload.
- Rounded corners and borderless transparent window display cleanly.
- Window bounds resize with HUD zoom.

## What Didn't Work / Known Issues
- `document.body.style.zoom` caused WebKit layout collapse with `100vw/100vh` styling; reverted to element transform scale within matched window bounds.
