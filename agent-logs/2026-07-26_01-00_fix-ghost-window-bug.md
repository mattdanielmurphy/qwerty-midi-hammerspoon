# Fix Ghost Window Bug on Auto-Reopen

## Goal
User reported a "ghost version" of the window being left on screen during reload/respawn, followed by a new window spawning after a delay. This was caused by the new crash recovery logic.

## User Feedback & Decisions
- Extreme delegation mode active, but fix was trivial (2 lines).
- The crash recovery logic we just added correctly detected when the webview closed while `midiActive` was true, and spawned a new one.
- However, when `createMidiWebview()` is called manually (or on auto-reload) and an existing webview exists, it calls `webview:delete()`. This deletion triggers the `"closing"` callback, which then falsely identified it as a crash because `midiActive` was true, and scheduled a duplicate window respawn 500ms later.

## Changes Made
### `src/hud.lua`
- Wrapped the intentional `webview:delete()` call in `createMidiWebview()` with `_G.activeWatchers._respawning = true/false` flags.
- This suppresses the crash-respawn logic in `windowCallback` when we are deliberately deleting the old window to create a new one, preventing the duplicate "ghost" window from spawning.

## What Worked
- Deleting the webview cleanly without triggering a recursive respawn loop.

## What Didn't Work / Known Issues
- None.
