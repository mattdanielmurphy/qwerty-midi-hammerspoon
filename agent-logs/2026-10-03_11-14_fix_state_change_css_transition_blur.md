# Agent Log: Fix State Change CSS Transition Blur & Layout Shift

- **Date:** 2026-10-03 11:14
- **Author:** Antigravity

## Context & Root Cause
Whenever MIDI or UI state changes occurred (octave shift, track toggle, note strike, clock pulse), WebKit treated `#hud-container` (rendered under `transform: scale(1.4..1.54)`) as an animated compositing layer. Child and container CSS transitions running for ~200–250ms caused WebKit to temporarily disable physical pixel snapping and font hinting, applying bilinear GPU texture interpolation across fractional subpixel coordinates. All 1px borders, grid lines, and text became blurred and shifted slightly by fractional pixels until the transition completed ~200ms later and snapped back to sharp.

In addition:
1. `body.mode-select-active #hud-container` had explicit `filter: blur(1px); transition: all 0.2s;`.
2. `.keyboard-grid`, `#performance-view`, and `#hud-container` had `transition: max-width 0.25s ...` and `height 0.25s ...`.
3. `.key-pad` and `.key-row-icon .rect` had transitions running on every state update.
4. `showSpotlight()` forced a synchronous layout reflow with `card.offsetHeight;` while animating `scale(0.85)` over 400ms on every single state change.
5. In `packages/keystep-interceptor/keystep.lua`, `setBpm()` called `_G.activeWatchers.hud.updateWebviewHud()` unconditionally even when volume was unchanged, causing full HUD JSON re-renders on clock jitter.

## Changes Made
1. **Web HTML & CSS Optimization (`src/web/index.html` & `packages/surface-hud/src/web/index.html`):**
   - Stripped container transitions on `#hud-container`, `.keyboard-grid`, `#performance-view`, `.key-pad`, `.stacked-rows-icon .rect`, `.arp-row-toggle`, and `.trk-badge`, setting them to `transition: none;`.
   - Added hardware rasterization stabilization: `-webkit-font-smoothing: antialiased; -webkit-backface-visibility: hidden; backface-visibility: hidden; transform-style: flat;`.
   - Replaced `filter: blur(1px); transition: all 0.2s;` in mode select active state with crisp `opacity: 0.75; transition: none;`.
   - Optimized `showSpotlight`: Removed `card.offsetHeight;` reflow and transform scaling; converted to pure opacity fade.
2. **KeyStep Clock Pulse Hardening (`packages/keystep-interceptor/keystep.lua`):**
   - Added guard in `setBpm()` so `updateWebviewHud()` only fires if master volume actually changed (`volChanged`).
   - Widened BPM deadband in `clockHandler` from `0.65` to `1.2` to eliminate steady-state clock pulse re-render fluttering.
3. **Bundling & Synchronization:**
   - Bundled all targets via `python3 bin/hs-bundler` into `qwerty_midi.lua`, `dist/surface_hud.lua`, `dist/keystep_interceptor.lua`, and `dist/studio_suite.lua`.
   - Synced `ui_html.lua` in both packages.

## Verification
- Ran `bun test`: All 36 tests pass across 8 test suites.
- Reloaded Hammerspoon and verified live webview.
- Executed control actions (`topOctUp`, `modeUp`, `rootUp`, `selectTrack1`) via `hs -c`.
- Captured live screenshots (`./tmp/hud_window_live.png`, `./tmp/hud_window_after_rapid.png`) and verified razor-sharp 1px lines, zero blur, and zero layout shift during state changes.
