## Goal
Split `qwerty_midi.lua` into logical modules in `src/`, create a generic Hammerspoon Lua project bundler (`bin/hs-bundler`), and configure a Launch Agent watcher daemon (`com.matt.agent.qwerty-midi-bundler`) to auto-bundle on changes and trigger Hammerspoon reload with macOS notifications.

## User Feedback & Decisions
- Split monolithic file into clean modules.
- Create reusable `hs-bundler` CLI tool for bundling Hammerspoon Lua projects.
- Setup a system Launch Agent (`com.matt.agent.qwerty-midi-bundler`) following host environment rules (`WatchPaths`).
- When changes are detected in `src/`, auto-bundle and trigger `hs.reload()` with a macOS notification.

## Changes Made
- Created `src/config.lua`: State variables, scale definitions, key mappings.
- Created `src/midi.lua`: CoreMIDI device connection and MIDI command dispatch functions.
- Created `src/transposer.lua`: Pitch transposition, scale interval matching, and velocity calculations.
- Created `src/arpeggiator.lua`: Arpeggiator timing loop, note latching, rate/gate/pattern state, and BPM editor handlers.
- Created `src/ui_html.lua`: HTML/CSS string template for HUD webview.
- Created `src/hud.lua`: Webview initialization, window geometry/zoom management, and JavaScript bridge execution.
- Created `src/controls.lua`: Keydown, keyup, and control action handlers.
- Created `src/init.lua`: Main entrypoint orchestrating event tap listeners and module wiring.
- Created `bin/hs-bundler`: Generic Python script that recursively resolves `require` calls and bundles `src/` files into a single distribution `.lua` file.
- Created `bin/bundle_and_reload.sh`: Executable script for bundling and firing macOS notification + `hs.reload()`.
- Created `~/Library/LaunchAgents/com.matt.agent.qwerty-midi-bundler.plist`: Launch Agent configured with `WatchPaths` on `src/`.
- Updated `AG_CONTEXT.md` and `FEATURES.md`.

## What Worked
- `hs-bundler` cleanly resolved module dependencies and outputted a working `qwerty_midi.lua`.
- Launch Agent `com.matt.agent.qwerty-midi-bundler` successfully monitors `src/` and automatically rebuilds `qwerty_midi.lua` and reloads Hammerspoon upon saving any module file.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- `hs-bundler` replaces `require("module")` with `__require("module")` for local modules inside `src/` while preserving standard `require(...)` calls for Hammerspoon system APIs (`hs.midi`, `hs.webview`).
