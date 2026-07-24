## Goal
1. Allow the webview HUD window to be dragged anywhere on screen to reposition it.
2. Reverse 2-finger trackpad scroll direction for mod wheel control and drastically reduce sensitivity for fine adjustment.
3. Reposition change notifiers (spotlight card) to the top header bar area so they never obscure any keys on the virtual keyboard.

## User Feedback & Decisions
- Draggable window by clicking and dragging on non-key regions (header / container background).
- Reversed scroll direction with ~0.15 sensitivity accumulator (20x lower step rate).
- Notifiers moved from screen center over keyboard keys to top header area (`top: 26px`).

## Changes Made
- `qwerty_midi.lua`:
  - Added JS `mousedown`, `mousemove`, `mouseup` event listeners to `#hud-container` to calculate drag deltas (`dx`, `dy`) and post `dragWindow` messages to `midiControllerUC`.
  - Updated `uc:setCallback` to handle `dragWindow` and move the `hs.webview` window frame dynamically while persisting `activeWatchers.hudX` / `activeWatchers.hudY`.
  - Updated `activeWatchers.midiScrollTap` to invert `deltaY` and use floating accumulator `activeWatchers.modAccumulator` with `0.15` sensitivity step multiplier.
  - Re-styled `.spotlight-card` CSS as a sleek horizontal pill centered in the top header bar (`top: 26px`), keeping it completely clear of all keyboard keys.
  - Updated `targetId` references for mod wheel, volume, panic, reset, and zoom notifications to target `#header`.

## What Worked
- Webview window drags smoothly across the desktop.
- Mod wheel trackpad scrolling is reversed and allows fine-grained, smooth 0-127 adjustment.
- Notification spotlight card pops up in top header bar without covering any of the 30 keyboard pads.

## Architecture Notes
- WKWebView requires explicitly passing drag deltas to `hs.webview:frame()` via user content bridge (`midiControllerUC`) rather than CSS `-webkit-app-region: drag`.
