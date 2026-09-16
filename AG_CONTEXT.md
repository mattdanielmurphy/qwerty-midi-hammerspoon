# Repository Context & Domain Knowledge

## Project Overview & Monorepo Structure
`surface-studio-suite` (formerly `qwerty-midi-hammerspoon`) is a Bun workspace monorepo (`packages/*`) unifying multimodal MIDI performance surfaces with a shared music engine and spatial HUD:
- `packages/qwerty-midi/`: Modular QWERTY keyboard MIDI controller for Hammerspoon.
- `packages/nanokey-studio/`: Korg nanoKEY Studio hardware driver with CC #25 Sustain & native SysEx Scene dual hold-to-reveal macro layers, 8 rotary dials mapped to Korg Gadget defaults (Cutoff, Peak, Drive, Volume, ADSR) with adaptive offset resolution (CC 17..24, 16..23, 20..27), KAOSS touchpad, 8 velocity trigger pads, 25 chiclet keys with octave-folding real-time visualizer, and dynamic surface switcher.
  - **Hammerspoon `hs.midi` Note Schema**: Note callbacks must inspect `metadata.note` (not `metadata.noteNumber`).
  - **Hardware Blueprint & Button Layout**: Left section contains 8 Knobs over two 3-button groups (`Octave -/+`, `Sustain` [SUS]; `Touch Scale` [SCALE], `X-Y`, `Pitch / Mod` [P/M]); Center section contains full-height Kaoss touchpad; Right section contains 8 Pads over two 3-button groups (`Scene` [SCENE], `Shift / Tap` [SHIFT], `Arp` [ARP]; `Chord Pad` [CHORD], `Easy Scale` [EASY], `Scale Guide` [GUIDE]).
  - **Inert vs. Interactive Invariant**: Internal firmware functions (`Octave -/+`, `Touch Scale`, `X-Y`, `Pitch / Mod`, `Shift / Tap`, `Arp`, `Chord Pad`, `Easy Scale`, `Scale Guide`) cannot be triggered by the host and must remain visible on the faceplate with inert, recessed styling (`.nk-btn-inert`, `pointer-events: none;`). Only `Keys`, `Pads`, `Knobs`, `Sustain` (CC #25), and `Scene` (SysEx) are interactive.
  - **Physical Keyboard Note Range**: 25 physical keys transmit on Channel 1 (`ch = 0`) spanning notes 48 to 72 (C3 to C5) at factory default, with middle C at note 60 (C4) and high C at note 72 (C5). Octave folding in the GUI maps into the 48..72 window.
  - **Preferences Window Invariant**: `settingsWebview` uses `wv:transparent(true)` and `wv:windowStyle({ "borderless", "resizable", "nonactivating" })` with corner grip & border dragging in HTML. `_G.activeWatchers.midiScrollTap` bypasses Mod/Vol interception when hovering `settingsWebview`, permitting native scrolling.
- `packages/music-engine/`: Core musical intelligence (harmony, scale quantizer, chord voicings, master clock, arpeggiator).
- `packages/surface-hud/`: Framework-agnostic Vite/WebKit HUD with 30fps coalescing and Web Audio anti-suspension sentinels.
- `packages/studio-suite/`: Master multi-controller orchestrator (QWERTY Ch 1 + nanoKEY Ch 2).
- `packages/dualsynth/`: Handheld software-defined MIDI groovebox & 3D studio environment using Sony PS5 DualSense (`GameController.framework`, virtual CoreMIDI endpoint, native SwiftUI HUD with light/dark appearance, 6-axis gyro tilt-to-ModWheel CC#1, CoreHaptics vibration, and built-in Chord/Latch/Arp engine).
  - **DualSense Motion & Rest Angle**: Bluetooth motion on macOS streams only via `motion.acceleration` (not `gravity`). Table rest is $a_y \approx +0.174$; ceiling tilt decreases $a_y$ towards $-1.0$.
  - **CoreHaptics Driver Invariant**: Rapid parallel `makeAdvancedPlayer` triggers cause error `-4810` and daemon teardown. Use discrete pulse grains (120ms) with `Date` throttling.
  - **Logic Pro CC #11**: MIDI CC #11 (Expression) acts as a gain multiplier; idle value must default to 127 to avoid muting instruments.
  - **Held-Chord Morphing**: Holding any chord face button allows D-Pad to dynamically alter, add on to (+8va, +Sub), or transpose harmonies in real time with automatic reversion upon release.
  - **Trigger Roles & Adaptive Haptics**: Left Trigger (L2) drives continuous velocity and dynamic expression with progressive slope resistance (`setModeSlopeFeedback`); Right Trigger (R2) acts as the modal menu selector with weapon-style detent feedback (`setModeWeaponWithStartPosition`).
  - **Zero-Latency IPC Sync**: DualSense and Hammerspoon sync bidirectionally without ports or sockets via macOS native `NSDistributedNotificationCenter` (`DistributedNotificationCenter.default()` in Swift and `hs.distributednotifications` in Lua), synchronizing musical key, scale, BPM, octave, and real-time played notes.

## Key Files
- `packages/`: Monorepo packages directory.
- `src/`: Legacy/active QWERTY Lua source (`config.lua`, `midi.lua`, `transposer.lua`, `arpeggiator.lua`, `hud.lua`, `controls.lua`, `ui_html.lua`).
- `bin/hs-bundler`: Multi-target Lua bundler supporting presets (`qwerty-midi`, `studio-suite`, `surface-hud`, `nanokey-studio`).
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
