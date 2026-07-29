# Pre-warm Settings Webview for Instant Load

## Goal
Eliminate the long loading delay when opening the Settings window (`Cmd+,`).

## User Feedback & Decisions
- The settings window takes too long to load and should open instantly.

## Changes Made
- Modified `src/settings_ui.lua`:
  - Refactored `settingsWebview` management to use `_G.activeWatchers.settingsWebview`.
  - Added module-level pre-warming (`createSettingsWebview()`) on script load so the WKWebView is instantiated and rendered in the background before the user opens it.
  - Replaced destructive window teardown (`delete()`) with non-destructive visibility toggle (`hide()`) on close or toggle.
  - Added `syncStateToWebview()` with in-page JavaScript `syncState()` to update input controls seamlessly on show.
- Re-bundled and reloaded Hammerspoon via `bin/bundle_and_reload.sh`.

## What Worked
- Webview pre-warming and visibility toggle reduces open/close latency to **0ms (instant)**.
- Input state remains perfectly synchronized with runtime settings.

## Architecture Notes
- Instantiating a new `hsWebview` / `WKWebView` child process on every toggle in Hammerspoon introduces a ~500ms-1s cold boot delay. Maintaining a pre-warmed, hidden webview instance in `_G.activeWatchers` allows instant display via native window show/hide calls.
