## Goal
- Fix key rendering issue caused by a JavaScript syntax error in `ui_html.lua`.

## User Feedback & Decisions
- Keys stopped rendering after previous commit due to JS parse error.

## Changes Made
- `src/ui_html.lua`: Fixed string escaping bug at line 1119 (`+ '%;` -> `+ '%'`).
- Rebundled `qwerty_midi.lua` via `./bin/bundle_and_reload.sh`.

## What Worked
- JavaScript evaluation succeeded, restoring full keyboard grid & HUD rendering.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- Unescaped trailing slashes in JavaScript strings evaluated by `hs.webview:evaluateJavaScript` break execution silencly, halting further DOM updates.
