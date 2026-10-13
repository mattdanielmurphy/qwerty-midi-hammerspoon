# Agent Work Log: Watchdog Event Tap Self-Healing & Latency Optimization

**Timestamp:** 2026-10-12 19:35  
**Issue:** QWERTY MIDI keyboard interception repeatedly disabled itself with `"disabling keyboard interception — keyboard event tap stopped"`, causing everything to stop working during normal play.

## Root Cause Analysis
1. **Aggressive Fail-Open Watchdog**: In `src/init.lua`, the 3-second watchdog timer checked `_G.activeWatchers.midiKeyTap:isEnabled()`. If `false` for even a single tick, it immediately invoked `failOpenMidiInput("keyboard event tap stopped")`, tearing down the controller.
2. **Missing Secure Input Tolerance**: macOS systematically disables all global `CGEventTap` keyboard hooks while Secure Input is active (password fields, 1Password, terminal sudo, Spotlight). The watchdog did not inspect `hs.eventtap.isSecureInputEnabled()`, misidentifying expected OS security behavior as a fatal crash.
3. **Synchronous AX IPC in Keystroke Callbacks**: In `_G.activeWatchers.midiKeyTap`, `hs.window.focusedWindow()` was queried on every key down, key up, and modifier change to check for DevTools. Accessibility IPC calls across process boundaries can take 5ms–100ms+; when the system is busy, the callback exceeds macOS's CoreGraphics event tap latency threshold, causing macOS to automatically disable the tap (`kCGEventTapDisabledByTimeout`).
4. **Runaway Logic Pro Track Name Scan**: In `src/logic_names.lua`, `pollTimer` ran every 2.0s. If the direct window path failed, it traversed the entire Logic Pro AX tree up to depth 8, freezing the Hammerspoon main runloop for seconds and causing pending CoreGraphics taps to time out.

## Solutions Applied
1. **Self-Healing Watchdog with Secure Input Immunity**:
   - In `src/init.lua`, guarded the watchdog with `hs.eventtap.isSecureInputEnabled()`. When Secure Input is engaged, the watchdog sleeps peacefully without failing open.
   - When an event tap is transiently disabled while Secure Input is inactive, the watchdog automatically calls `start()` to re-enable it (up to 3 retry attempts over 9s) and logs the attempt.
   - Only persistent, unrecoverable failures (>3 attempts with Secure Input off) trigger `failOpenMidiInput("keyboard event tap stopped")`.
   - Applied identical retry self-healing to `midiScrollTap`.
2. **Eliminated Keystroke IPC**:
   - In `src/init.lua`, guarded the `hs.window.focusedWindow()` check inside `midiKeyTap` so it only executes when `frontApp:bundleID() == "org.hammerspoon.Hammerspoon"`. For DAWs and normal apps, zero AX queries occur during playing.
   - Deferred modifier HUD renders (`hud.updateWebviewHud()`) via `hs.timer.doAfter(0)` to keep keystroke callbacks microsecond-fast.
3. **Bounded Logic Pro AX Traversal**:
   - In `src/logic_names.lua`, capped `findHeader` tree walk to `depth <= 4` and max 60 elements visited.
   - Increased polling interval to 3.0s.
4. **Unit & Integration Verification**:
   - Created `tests/watchdog_self_healing.test.js` validating Secure Input immunity, tap re-enable retries, counter resets, and bounded AX traversal.
   - Passed all 222 Bun tests across 39 suites.
   - Passed all 4 pure Lua test suites in `tests/lua/runner.lua`.
   - Bundled with `bin/bundle_and_reload.sh` and verified syntax with `luac -p`.
   - Verified live in Hammerspoon: simulated tap disable is automatically caught and healed within 3 seconds (`tapReEnabled = true`, `failureCount = 0`, `midiActive = true`).
