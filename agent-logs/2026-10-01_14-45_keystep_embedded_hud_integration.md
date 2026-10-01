# KeyStep 32 Embedded HUD Integration & NanoKey Archive Preservation

## Summary of Changes

1. **Embedded KeyStep 32 HUD Display**:
   - Integrated the authentic Arturia KeyStep 32 controller display into the QWERTY HUD (`src/web/index.html` and `src/hud.lua`), rendering dynamically below the QWERTY keyboard HUD only while a detected KeyStep is connected.
   - Designed authentic hardware silhouette with Master Control Bay (Arturia branding, status LED, Seq/Arp mode switch, Pattern knob 1..8, Time Div knob 1..8, Rate knob with blinking tempo LED, Stop/Play/Rec/Tap transport buttons, Shift/Hold buttons, Octave +/- buttons & badge, Pitch bend & Modulation touch strips) and 32 slim keys (notes 48 to 79: C3 to G5) with silkscreen markings.
   - Dynamic height resizing: expands from 280px to 600px when connected (`#hud-container.keystep-connected`), repositions on macOS screen cleanly, and contracts back to 280px when disconnected.
   - Live state synchronization: notes, pitch bend, mod wheel, rate/BPM, pattern/mode, time division, transport, record, hold, shift, and octave synchronize from `packages/keystep-interceptor/keystep.lua` to HUD webview via `window.updateKeyStepState`.
   - Bidirectional IPC: mouse clicks and touch strip drags on the embedded controller emit MIDI events back to Hammerspoon via `midiControllerUC`.

2. **Preserved Korg nanoKEY Studio Archive**:
   - Preserved full nanoKEY Studio codebase and tools in `archive/nanokey-studio/`:
     - `archive/nanokey-studio/packages/nanokey-studio/` (hardware driver, layouts, macros, probe).
     - `archive/nanokey-studio/bin/` (sniffer, test tools, shell scripts).
     - `archive/nanokey-studio/tools/` (Swift sources for BLE/CoreMIDI sniffer and LED tester).
   - Preserved `nanokey-studio` bundling preset in `bin/hs-bundler` targeting `archive/nanokey-studio/packages/nanokey-studio`.

3. **Validation & Verification**:
   - Added focused Bun unit test suite: `tests/keystep_embedded_hud.test.js`.
   - All 26 Bun unit tests across 8 suites passed (`bun test`).
   - All 4 bundling presets (`qwerty-midi`, `studio-suite`, `nanokey-studio`, `keystep-interceptor`) bundled cleanly.
   - Verified all Lua sources and generated bundles with `luac -p`.
   - Live verified in running Hammerspoon environment: confirmed `_G.activeWatchers.keystep.isConnected()` returns `true` for detected KeyStep 32 hardware, and `_G.toggleMidiMode(true)` expands the embedded HUD view cleanly.
