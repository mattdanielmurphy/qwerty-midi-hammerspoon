## Goal
Add a debounce mechanism to the `watch_src.sh` file watcher to prevent notification spam when files in `src/` are edited or written rapidly.

## User Feedback & Decisions
- User requested debouncing because rapid multi-file writes during agent operations generated excessive "reloading..." notifications.

## Changes Made
- Updated [bin/watch_src.sh](file:///Users/matt/projects/qwerty-midi-hammerspoon/bin/watch_src.sh) event loop:
  - Added `DEBOUNCE_DELAY=1.5` timeout delay.
  - Implemented event queue draining before and after the sleep interval using non-blocking `read -t 0.1` checks.
- Restarted `com.matt.agent.qwerty-midi-bundler` via `launchctl` to apply changes to active background watcher service.

## What Worked
- Debounce loop buffers rapid file edits into a single bundle and reload invocation after 1.5s of quiet time.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- `fswatch -0` pipe outputs null-terminated string events into `read -d ""`. Draining events with `read -t 0.1` clears queued change notifications accumulated during batch agent writes.
