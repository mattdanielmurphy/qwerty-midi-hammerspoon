# Dynamic Shift-Key Label Rendering Fix

**Date:** 2026-07-29 11:46  
**Topic:** Dynamic Shift-Key Label Rendering Fix  

## Summary
Updated `renderHud(data)` in `src/web/index.html` to evaluate `data.shiftHeld`. Dynamically toggles `.shift-active-labels` on `#hud-container` and renders `k.shiftNote` on single-label key caps when physical Shift is held down.
