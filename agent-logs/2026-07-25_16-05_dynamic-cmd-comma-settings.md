# Fix: Dynamic `Cmd-,` Settings Capture in MIDI Mode

## Summary
Updated `Cmd-,` handling so that it is handled dynamically within `midiKeyTap` (`hs.eventtap`):

1. **MIDI Mode Active (`midiActive == true`):** Pressing `Cmd-,` opens the QWERTY MIDI settings window and swallows the keystroke.
2. **MIDI Mode Disabled (`midiActive == false`):** `midiKeyTap` is stopped, and no OS-level Carbon hotkey is registered in `hs.hotkey.bind`. `Cmd-,` passes through natively to open preferences in whatever Mac app is currently focused.

## Implementation Details
- Removed global `hs.hotkey.bind` for `Cmd-,`.
- Added keycode check (`code == 43`) inside `midiKeyTap` when `flags.cmd` is true (without `alt` or `ctrl`).
- Re-bundled and reloaded Hammerspoon via `bin/bundle_and_reload.sh`.
