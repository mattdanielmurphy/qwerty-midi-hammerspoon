# Repository Context & Domain Knowledge

## Project Overview
`qwerty-midi-hammerspoon` is a standalone Hammerspoon automation project providing a modal, key-swallowing MIDI controller with a real-time canvas dashboard.

## Key Files
- `qwerty_midi.lua`: Core module containing event tap key-swallowing logic, CoreMIDI output bindings, and `hs.canvas` HUD elements.
- `install.sh`: Symlinks `qwerty_midi.lua` into `~/.hammerspoon/modules/qwerty_midi.lua`.
