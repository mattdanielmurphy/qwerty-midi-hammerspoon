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
- **Modular Development**: Edit files inside `src/` (Lua) or `src/web/index.html` (UI HTML/CSS/JS).
- **Watcher Daemon**: The `watch_src.sh` daemon watches `src/` for Lua changes and auto-reloads. `src/web/` is explicitly excluded from `watch_src.sh` so web edits don't trigger full Hammerspoon reloads.
- **Manual Reload Required for Lua**: After changing any Lua module in `src/`, run `bash /Users/matt/projects/qwerty-midi-hammerspoon/bin/bundle_and_reload.sh`.
- **Web UI HMR (No Reload Needed)**: Run `bun x vite` from the project root to start the dev server (`http://localhost:5173`). When running, `src/hud.lua` connects directly to Vite. Edits to `src/web/index.html` (CSS/JS/HTML) hot-reload instantly in the webview without touching Hammerspoon or destroying MIDI state!
- **UI Production Build**: Running `bin/bundle_and_reload.sh` automatically syncs `src/web/index.html` into `src/ui_html.lua` for offline production distribution.
- **HUD Layout & Controls**: 4-row webview layout (`number`, `upper`, `home`, `lower`) using Fraunces Google Font and dark neutral theme. Trackpad scroll supports Mod Wheel (normal) and Volume (Shift held).
