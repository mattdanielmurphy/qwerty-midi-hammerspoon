## Goal
The user requested a visual loading state while the script/webview is first loading and isn't quite ready yet.

## User Feedback & Decisions
- Show a clear, elegant loading overlay during initial webview/script initialization that smoothly fades out as soon as the first HUD data payload arrives from Lua.

## Changes Made
1. **`src/web/index.html`**:
   - Added `#loading-overlay` styling with a semi-transparent dark blurred backdrop, centered gold spinning indicator (`.loading-spinner`), and `INITIALIZING QWERTY MIDI...` text.
   - Inserted `<div id="loading-overlay">` inside `#hud-container`.
   - Updated `renderHud(data)` JavaScript function to append the `.loaded` class to `#loading-overlay`, fading out and disabling pointer events as soon as the initial Lua state sync is performed.
2. **Synced HTML into `src/ui_html.lua` & `qwerty_midi.lua`**:
   - Ran `bin/bundle_and_reload.sh` to sync the HTML template into `ui_html.lua`, rebuild `qwerty_midi.lua`, and reload Hammerspoon.

## What Worked
- Webview now displays a styled loading spinner and text overlay upon creation, which smoothly transitions away as soon as `renderHud` receives its initial payload from Lua host.

## Architecture Notes
- The `#loading-overlay` starts visible on initial HTML parse and relies on the first `renderHud()` payload invocation (triggered either directly on webview show or via the `domReady` IPC callback) to add `.loaded` class, triggering a smooth 0.3s CSS opacity fade-out.
