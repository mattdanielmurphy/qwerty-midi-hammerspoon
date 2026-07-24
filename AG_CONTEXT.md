# Repository Context & Domain Knowledge

## Project Overview
`qwerty-midi-hammerspoon` is a standalone Hammerspoon automation project providing a modal, key-swallowing MIDI controller with a real-time canvas dashboard.

## Key Files
- `qwerty_midi.lua`: Core module containing event tap key-swallowing logic, CoreMIDI output bindings, and `hs.canvas` HUD elements.
- `install.sh`: Symlinks `qwerty_midi.lua` into `~/.hammerspoon/modules/qwerty_midi.lua`.

## Development Guidelines & Rules
- **Reloading Config**: Whenever modifying `qwerty_midi.lua` or any Hammerspoon Lua file, display a macOS notification starting the reload and trigger the reload asynchronously:
  `osascript -e 'display notification "Reloading Hammerspoon Config..." with title "Hammerspoon"' && (hs -c "hs.reload()" >/dev/null 2>&1 &)`
- **Never Restart App**: Do not kill or restart the Hammerspoon process directly.
- **HUD Layout & Controls**: 4-row webview layout (`number`, `upper`, `home`, `lower`) using Fraunces Google Font and dark neutral theme. Trackpad scroll supports Mod Wheel (normal) and Volume (Shift held).





