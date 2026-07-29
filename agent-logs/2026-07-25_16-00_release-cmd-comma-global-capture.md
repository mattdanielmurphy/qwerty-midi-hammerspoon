# Fix: Release `Cmd-,` Global Capture in Hammerspoon

## Summary
`Cmd-,` was intercepted system-wide across macOS because `_G.activeWatchers.settingsHotkey` registered `hs.hotkey.bind({"cmd"}, ",")`. In macOS, `Cmd-,` is the universal application Preferences shortcut, causing Hammerspoon to swallow `Cmd-,` globally in all applications (Finder, Safari, VS Code, Slack, etc.).

## Solution
- Updated `settingsHotkey` in `src/init.lua` to use `{"cmd", "alt"}, ","` (`Cmd+Alt+,`), matching the `Cmd+Alt+M` convention used for `midiToggleHotkey`.
- Re-bundled `qwerty_midi.lua` via `bin/bundle_and_reload.sh` and reloaded Hammerspoon.
- `Cmd-,` is now completely uncaptured by Hammerspoon, restoring native preferences functionality across all Mac apps.
