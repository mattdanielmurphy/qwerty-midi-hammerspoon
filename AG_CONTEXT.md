# Repository Context & Domain Knowledge

## Project Overview
`qwerty-midi-hammerspoon` is a standalone Hammerspoon automation project providing a modal, key-swallowing MIDI controller with a real-time canvas dashboard.

## Key Files
- `src/`: Modular Lua code directory (`config.lua`, `midi.lua`, `transposer.lua`, `arpeggiator.lua`, `hud.lua`, `controls.lua`, `ui_html.lua`).
- `bin/hs-bundler`: Generic Lua bundler for Hammerspoon projects that packs `src/` modules into a single standalone output file.
- `bin/bundle_and_reload.sh`: Trigger script executed by the Launch Agent watcher (`com.matt.agent.qwerty-midi-bundler`).
- `qwerty_midi.lua`: Auto-generated bundled file created by `bin/hs-bundler`.
- `install.sh`: Symlinks `qwerty_midi.lua` into `~/.hammerspoon/modules/qwerty_midi.lua`.

## Development Guidelines & Rules
- **Modular Development**: Edit files inside `src/`. The Launch Agent (`com.matt.agent.qwerty-midi-bundler`) watches `src/` and automatically bundles into `qwerty_midi.lua` and triggers Hammerspoon reload with a macOS notification.
- **Never Restart App**: Do not kill or restart the Hammerspoon process directly.
- **Manual Reload Required**: The watcher is unreliable. After ANY change to `src/`, ALWAYS manually run `bash /Users/matt/projects/qwerty-midi-hammerspoon/bin/bundle_and_reload.sh` to re-bundle and reload Hammerspoon.
- **HUD Layout & Controls**: 4-row webview layout (`number`, `upper`, `home`, `lower`) using Fraunces Google Font and dark neutral theme. Trackpad scroll supports Mod Wheel (normal) and Volume (Shift held).





