## Goal
1. Make Hammerspoon webview window frame dynamically resize with HUD zoom.
2. Ensure window is borderless and transparent so only 14px rounded HUD container is visible.
3. Fix zoom fuzziness by switching from bitmap CSS transform scale to vector-sharp WebKit layout zoom (`document.body.style.zoom`).

## User Feedback & Decisions
- User pointed out window should resize with HUD.
- Window needed rounded corners / transparent background.
- User noted zooming felt "cheap / not as sharp as it should be" (correct intuition: CSS `transform: scale` rasterized canvas bitmap).

## Changes Made
- Updated [qwerty_midi.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/qwerty_midi.lua):
  - Set `wv:windowStyle({"borderless", "utility"})`, `wv:transparent(true)`, `wv:hasShadow(false)` for clean rounded HUD shape.
  - Dynamically recalculate `activeWatchers.midiWebview:frame(...)` in `updateWebviewHud()` when `zoomLevel` changes, keeping HUD centered and window tightly wrapped around it.
  - Switched `renderHud()` to use `document.body.style.zoom = data.zoomLevel`, forcing WebKit to re-calculate vector geometry and render fonts/borders at native Retina resolution.

## What Worked
- Webview window bounds now resize in sync with zoomLevel.
- Background and macOS window chrome are 100% transparent, displaying only the rounded HUD container.
- Text, key outlines, and badges remain sharp and vector-crisp at any zoom level.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- Using WebKit `document.body.style.zoom` triggers engine layout re-calc at Retina DPI rather than GPU texture scaling, delivering native resolution rendering.
