# Agent Work Log: Fix Zoom Snap Glitch on Launch and Modifier Key Press

## Goal
Fix the persistent HUD zoom snap/jump glitch that occurs when the window is first created on screen or when modifier/control keys (like Shift) are pressed.

## Root Cause Discovery
The CSS rule `#hud-container` contained `transition: transform 0.15s cubic-bezier(0.16, 1, 0.3, 1) ...`.
Whenever `updateWebviewHud()` evaluated JS `renderHud(data)` (such as on webview creation or when `flagsChanged` fired for Shift key press), setting `container.style.transform = 'scale(1.4)'` caused WebKit to re-evaluate the CSS transform property and trigger a 150ms animated scale transition snap from 1.0 to 1.4.

## Changes Made
1. **Removed `transform` from CSS transition on `#hud-container`**:
   Updated CSS transition rule from:
   `transition: transform 0.15s cubic-bezier(0.16, 1, 0.3, 1), border-color 0.15s ease, box-shadow 0.15s ease;`
   To:
   `transition: border-color 0.15s ease, box-shadow 0.15s ease;`
2. **Guarded JS `renderHud` transform mutation**:
   Only set `container.style.transform = targetTransform` when `container.style.transform !== targetTransform`.

## What Worked
- Verified syntax cleanly with `luac -p qwerty_midi.lua`.
- Confirmed window frame and scale factor render instantly at exact 1.4 scale on load and key press with 0 transition lag or snap.
