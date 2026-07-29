## Goal
The user noted that the loading screen was popping up after the interface was already loaded and ready.

## User Feedback & Decisions
- Remove the loading overlay since the webview loads instantaneously from inline HTML memory strings without network delay.

## Changes Made
1. **`src/web/index.html`**:
   - Removed `#loading-overlay` CSS styles and HTML element.
   - Removed overlay dismissal check inside `renderHud()`.
2. **Rebundled**:
   - Executed `bin/bundle_and_reload.sh` to update `src/ui_html.lua` and `qwerty_midi.lua`.

## What Worked
- Webview interface now loads cleanly and instantly on launch without displaying an unnecessary overlay.
