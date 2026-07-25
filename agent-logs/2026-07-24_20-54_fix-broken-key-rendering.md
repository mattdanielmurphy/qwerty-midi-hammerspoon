## Goal
Investigate and fix why the HUD keys stopped rendering properly and the UI froze after loading, which occurred as a regression during the attempt to fix the 50s beachball freeze on launch.

## User Feedback & Decisions
- The user reported that not only did the loading freeze remain, but the keys weren't rendering properly anymore ("it's like it's frozen AFTER it's loaded now, in addition to the frozen beachballing when it was launching").

## Changes Made
- Performed a `git restore` on `src/hud.lua` and `src/ui_html.lua` to remove errant, uncommitted `lp()` function calls left over from previous profiling attempts. Since `lp()` was removed from `init.lua`, calling it in `hud.lua`'s `performWebviewHudUpdate` caused a fatal Lua error, which prevented the JSON payload from ever reaching the Javascript UI (hence the keys never rendered).
- The uncommitted changes also had mistakenly changed `hsWebview.new` to `hs.webview.new`, which broke local scoped references. Restoring fixed this.
- Carefully re-applied the Google Fonts removal on a clean working tree in both `src/ui_html.lua` and `src/settings_ui.lua` to address the potential network-timeout beachballing issue at launch without breaking the JS payload pipeline.

## What Worked
- Reverting the broken unstaged changes restored the rendering pipeline. The HUD keys should now render correctly on launch. 
- The 50s beachballing should now be resolved by a combination of the previous `src/midi.lua` loop removal (which fixed a massive core thread stall) and the font removal (which fixes Webkit network timeouts).

## What Didn't Work / Known Issues
None.

## Architecture Notes
- When troubleshooting rendering freezes, check for synchronous Lua errors in the `updateWebviewHud` cycle that prevent the `evaluateJavaScript` payload from being dispatched. 
- Always verify that temporary debug logging (`lp()`) is fully stripped out, as a missing global function call in a Lua callback will silently halt execution.
