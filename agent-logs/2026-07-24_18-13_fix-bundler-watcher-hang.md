## Goal
The bundler watcher failed to reload the Hammerspoon config when changes were made to `src/` files after the first save. The user reported that subsequent edits were silently ignored.

## User Feedback & Decisions
- User identified the symptom: config changes not applied after the first bundler run.
- Fix confirmed working by restarting the Launch Agent with the corrected script.

## Changes Made
- **`bin/watch_src.sh`**: Replaced the broken `read -d "" -t timeout` drain loops with `fswatch --latency` for built-in event coalescing. Also switched from null-delimiter (`-d ""`) pipe reading to standard line-based `IFS= read -r` for bash 3.2 compatibility.

## What Worked
- Root cause identified: bash 3.2 (macOS system bash at `/bin/bash`) has a known bug where `read -d "" -t <timeout>` (null delimiter + timeout) ignores the timeout and blocks indefinitely when the pipe has been drained. This permanently hung the watcher's `while` loop after the first event.
- Fix: `fswatch --latency 1.5` handles event batching natively. The shell loop now uses standard line-delimited `IFS= read -r` which works correctly in all bash versions.
- Added a secondary time-guard (`LAST_TRIGGER` check) to absorb any remaining rapid-fire events at the shell level without relying on the broken drain pattern.
- Launch Agent restarted successfully via `launchctl unload/load`.

## What Didn't Work / Known Issues
- No Homebrew bash 5.x available at `/opt/homebrew/bin/bash`; fix needed to stay within bash 3.2 constraints.
- The `--latency` flag in fswatch means changes are batched over 1.5s before the first event fires. This is acceptable for a dev reload workflow but slightly increases time-to-reload from the previous theoretical 0.1s (which was never actually working).

## Architecture Notes
- `watch_src.sh` is run by the `com.matt.agent.qwerty-midi-bundler` Launch Agent via `tmux-agent-wrapper.sh`.
- The plist has `KeepAlive: true` + `ThrottleInterval: 2`, so if the watcher script exits it will restart after 2s. The bug was a hang (not an exit), so the keepalive didn't help.
- The `fswatch --latency` flag sets the minimum coalescing window in seconds — all filesystem events within that window are buffered before any line is written to stdout.
