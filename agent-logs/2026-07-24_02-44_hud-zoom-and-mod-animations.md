## Goal
Implement zoom in/out with `+`/`-` keys, central spotlight animation for modifier parameter changes (octave, root, scale, mod wheel, volume, sustain, zoom) that shrink and fly back to their HUD element position, and remove top-right MOD readout to prevent layout shift.

## User Feedback & Decisions
- `+` and `-` keys zoom in/out the HUD interface.
- Modifier key press (or value change) triggers central spotlight card showing changed value & detail (e.g. Lower Octave 4 / Upper Octave 5), holds briefly, then smoothly shrinks and moves back to its HUD target position.
- Removed top-right `MOD: <val>` text readout to prevent layout width shift jitter of header elements to the left.

## Changes Made
- Modified [qwerty_midi.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/qwerty_midi.lua):
  - Added `zoomLevel` state variable with key bindings for `+`/`=` (keycode 24, 69) and `-` (keycode 27, 78).
  - Expanded webview window dimensions to 1200x400 to allow smooth CSS scale transforms without border clipping.
  - Implemented CSS spotlight card with glassmorphism and JS `showSpotlight(spotlightInfo)` animation sequence (center pop -> 350ms hold -> shrink & fly back to target ID).
  - Removed `MOD: ...` from top-right status text string.
  - Attached spotlight info payloads to all control key actions (`octaveDown/Up`, `topOctDown/Up`, `rootDown/Up`, `modeDown/Up`, `randomScale`, `modWheelDown/Up`, 2-finger trackpad scroll, `volDown/Up`, `sustain`, `resetAll`, `panic`, `zoom`).

## What Worked
- Zoom in/out via `+` and `-` keys seamlessly scales HUD element bounds.
- Spotlight card pops up large in center of HUD and smoothly shrinks back toward target UI element.
- Header width stability preserved by removing variable-width `MOD: <val>` readout.

## What Didn't Work / Known Issues
- None observed.

## Architecture Notes
- Webview evaluates JSON payload containing `zoomLevel` and `spotlight` object in `renderHud()`.
- Smooth CSS transition `transform 0.45s cubic-bezier(0.16, 1, 0.3, 1)` animates spotlight scale and coordinate movement relative to bounding rects of `#hud-container` elements.
