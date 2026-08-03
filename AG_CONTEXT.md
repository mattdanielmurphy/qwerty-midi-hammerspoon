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

## DAW & Logic Pro Multi-Channel Note Interruption Behavior
- **Logic Pro Track Routing Note**: In Logic Pro, when multiple MIDI channels (e.g. Channel 1 Top Row, Channel 2 Bottom Row, Channel 3 Arp) are routed to a single track/instrument synth, Logic Pro's internal voice engine sums incoming MIDI notes across channels per pitch voice. If the same pitch is played simultaneously on both Top and Bottom rows and then released on one row, Logic's synth voice terminates upon receiving the Note-Off command regardless of channel.
- **Workaround / Setup Recommendation**: To prevent overlapping pitch cutoffs across Top and Bottom rows or Arp, assign separate, distinct instrument tracks in Logic Pro targeting individual MIDI channels (e.g., Track 1 listening on Channel 1, Track 2 listening on Channel 2, Track 3 listening on Channel 3) rather than routing all channels to a single instrument instance.
