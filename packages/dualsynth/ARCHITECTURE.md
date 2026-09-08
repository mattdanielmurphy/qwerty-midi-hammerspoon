# DualSynth Architecture & Hammerspoon Monorepo Integration

## 1. Executive Summary & Monorepo Context

DualSynth is the third primary input modality in the **Surface Studio Suite** monorepo:

```
                                  [ surface-studio-suite ]
                                             │
      ┌──────────────────────────────┬───────┴──────────────────────┬──────────────────────────────┐
      ▼                              ▼                              ▼                              ▼
[ qwerty-midi ]              [ nanokey-studio ]              [ dualsynth ]                  [ surface-hud ]
QWERTY Keypad                 Korg Hardware MIDI             PS5 DualSense Gamepad           Unified Spatial HUD
Hammerspoon EventTap          Hammerspoon hs.midi            Swift + GameController.framework WebKit / Vite / SwiftUI
      │                              │                              │                              │
      └──────────────────────────────┼──────────────────────────────┴──────────────────────────────┘
                                     ▼
                           [ music-engine ]
                           - Scales & Quantization (harmony.lua / Swift)
                           - Dynamic Chord Generator (Voicings & Inversions)
                           - Master Clock & Dual Arpeggiators
                                     │
                                     ▼
                      [ Virtual CoreMIDI / DAWs ]
                      Logic Pro, Ableton, Reaper, AUM
```

The repository was converted into a **Bun Workspace Monorepo** (`packages/*`), which allows us to keep the shared musical models, HUD definitions, Hammerspoon automation glue, and the native Swift DualSense engine cleanly separated yet versioned and co-located together.

---

## 2. The Core Technical Challenge: Gamepad Hardware vs. Hammerspoon

### Hardware Requirements
The Sony DualSense (Model CFI-ZCT1) is significantly more capable than a standard HID gamepad:
1. **Hall-Effect Triggers (L2 / R2)**: High-resolution continuous analog axes (used for velocity gating and envelope/filter sweeps).
2. **Dual Thumbsticks**: 4 simultaneous analog axes (X/Y pitch bend, modulation, filter cutoff, wet/dry).
3. **6-Axis IMU**: 3-axis gyroscope and 3-axis accelerometer streaming high-frequency spatial reports.
4. **Haptics & Adaptive Triggers**: Voice-coil actuators for tactile metronome pulses and servo motors for programmable physical detents.
5. **Lightbar**: Multi-zone addressable RGB LEDs for state/layer confirmation.

### Runtime Constraints
* **Apple `GameController.framework` & `GCDualSenseGamepad`**: Full hardware access to the DualSense (adaptive trigger detents, lightbar color control, voice-coil haptics, and calibrated IMU data) is **only exposed via Apple's native `GameController.framework`**.
* **Hammerspoon Runtime**: Hammerspoon runs a single-threaded Lua 5.4 event loop. It provides `hs.eventtap` (keyboard/mouse) and `hs.midi` (standard CoreMIDI devices), but has **no native `GameController.framework` bridge**. Polling 60–250 Hz analog axes and IMU data inside Hammerspoon's single Lua thread would introduce jitter to music timing and freeze during garbage collection cycles.

---

## 3. Integration Architectural Patterns

We solve this cleanly via a **dual-layer architecture**: a high-speed native Swift engine handling hardware I/O and CoreMIDI, interfaced with Hammerspoon and the shared Studio Suite.

```
+---------------------------------------------------------------------------------------------------+
|                                     HARDWARE & DRIVER LAYER                                       |
|                                                                                                   |
|  [ PS5 DualSense ]                                                                                |
|         │ Bluetooth 5.1 / USB-C HID                                                               |
|         ▼                                                                                         |
|  [ packages/dualsynth/macos (Swift Engine) ]                                                      |
|    - GameController.framework (GCDualSenseGamepad)                                                |
|    - High-frequency input polling (analog sticks, L2/R2 triggers, IMU)                            |
|    - Momentary shift matrix parser (L1 = Harmony, R1 = Looper, L1+R1 = FX)                        |
|    - Direct CoreMIDI packet generation (MIDISend / MIDISourceCreate)                              |
+---------------------------------------------------------------------------------------------------+
                                   │                          │
        Virtual CoreMIDI Stream    │                          │ Local IPC / WebSocket / OSC
        ("DualSynth Controller")   │                          │ (State & Telemetry)
                                   ▼                          ▼
+----------------------------------------------+   +------------------------------------------------+
|               COREMIDI BUS                   |   |            UI & HUD SUBSYSTEM                  |
|                                              |   |                                                |
|  ┌───────────────────┐ ┌───────────────────┐ |   |  [ packages/surface-hud ]                      |
|  │  DAW Routing      │ │ Hammerspoon       │ |   |  - Spatial Cross (D-Pad)                       |
|  │  Logic Pro        │ │ (hs.midi)         │ |   |  - Spatial Diamond (Face Buttons)              |
|  │  Ableton Live     │ │                   │ |   |  - Progressive disclosure opacity              |
|  │  Reaper           │ │ Listener on       │ |   |  - WebKit webview (Hammerspoon / Vite)         |
|  │  AUM (on iOS)     │ │ Virtual Port      │ |   |    OR Native SwiftUI (iOS handheld mount)      |
|  └───────────────────┘ └─────────┬─────────┘ |   +------------------------------------------------+
+----------------------------------┼-----------+
                                   │
                                   ▼
+---------------------------------------------------------------------------------------------------+
|                                 HAMMERSPOON ORCHESTRATION LAYER                                  |
|                                                                                                   |
|  [ packages/studio-suite / init.lua ]                                                             |
|    - Coordinates QWERTY, nanoKEY, and DualSynth into a synchronized multi-surface studio.         |
|    - Logic Pro UI Scripting & DAW Window Management (automates track selection, solo, record arm).|
|    - System Macro Layer (hotkeys, profile switching, app toggles).                                |
+---------------------------------------------------------------------------------------------------+
```

### Pattern A: The Zero-Overhead Virtual MIDI Bus (Primary Performance Path)
1. The Swift engine boots as a lightweight daemon or app.
2. It initializes a virtual CoreMIDI source named **`"DualSynth Virtual Out"`** and destination **`"DualSynth Virtual In"`**.
3. Button presses, analog trigger sweeps, and stick gestures are converted directly into MIDI Note-On/Off, CC, and Pitch Bend messages in Swift with **sub-2ms latency**.
4. Local DAWs (Logic Pro, Ableton) connect directly to this virtual endpoint without any intermediate proxy.

### Pattern B: Hammerspoon as Studio Conductor (`hs.midi` Bridge)
1. Hammerspoon's `hs.midi` connects as a listener to `"DualSynth Virtual Out"`.
2. Hammerspoon intercepts non-musical control messages (e.g. specialized CCs or reserved notes assigned to modifier combos like `Share`, `Options`, or `PS Button`):
   - **DAW Scripting**: Automatically trigger AppleScript UI automation in Logic Pro (track bouncing, window positioning, mixer toggles) using scripts like `test_logic_ui.scpt`.
   - **Multi-Surface Coordination**: Switch active scales or root keys simultaneously across QWERTY, nanoKEY Studio, and DualSynth.

### Pattern C: Dynamic Visual Scaffolding via `surface-hud`
DualSynth's core usability principle is **spatial visual scaffolding** to prevent "blind modifier mode" cognitive overload:
* When `L1` (Momentary Harmony Shift) is held down:
  - The HUD immediately renders the **D-Pad Cross** (Root note / Octave selection) and **Face-Button Diamond** (Chord voicings: Maj7, Min7, Dom7, Dim, Sus4).
  - The physical DualSense lightbar immediately switches to **Blue**.
* When `R1` (Momentary Looper Shift) is held down:
  - The HUD displays the 4-track loop status (Track 1–4 Record/Overdub/Mute).
  - The physical lightbar switches to **Amber**.
* When released, the HUD reverts to Base Play Mode and the lightbar turns **Green**.

Because `packages/surface-hud` is already decoupled with JSON-driven layouts, we can model `layouts/dualsense.json` with coordinate anchors for the spatial cross and diamond!

---

## 4. Phase 0: Desktop Proof of Concept (macOS)

### Objective
Verify input latency, Bluetooth polling stability, and CoreMIDI virtual port creation on macOS 14+ using a Sony DualSense controller.

### Concrete Scaffolding in `packages/dualsynth/macos`
A lightweight Swift Package Manager (SPM) project:
* `Package.swift`: Targets macOS 14+, links `GameController` and `CoreMIDI`.
* `Sources/DualSynthCore/`:
  - `ControllerManager.swift`: Discovers and connects to `GCController`, attaches handlers to `GCDualSenseGamepad`.
  - `MIDIEngine.swift`: Wraps `MIDISourceCreate` and formats `MIDIPacketList` / `MIDIEventList` (MIDI 1.0 & 2.0).
  - `InputMapper.swift`: Maps Face Buttons ($\triangle, \bigcirc, \times, \square$) to scale degrees, `R2` trigger to dynamic velocity/gate, and `L2` trigger to filter CC #74.
  - `HapticsEngine.swift`: Generates transient voice-coil metronome pulses via `CHHapticEngine`.
* `Sources/dualsynth-cli/`: Command-line daemon entry point with real-time CLI terminal telemetry.

---

## 5. Long-Term Roadmap & Monorepo Alignment

| Phase | Target Platform | Monorepo Role & Technologies |
| :--- | :--- | :--- |
| **Phase 0** | macOS Desktop | `packages/dualsynth/macos`: Swift CLI/Daemon + CoreMIDI + GameController |
| **Phase 1** | iOS / iPadOS | `packages/dualsynth/ios`: SwiftUI spatial HUD for iPhone mounted on DualSense |
| **Phase 2** | Multi-Track Groovebox | Polyphonic chord engine + 4-track MIDI looper + DualSense haptic clicks |
| **Phase 3** | Gestural Tracking | 6-axis IMU tilt pitch/vibrato + adaptive trigger resistance steps |
| **Phase 4** | 3D Studio World | `packages/dualsynth/godot`: Godot 4 Metal 3D studio environment navigated via sticks |
| **Phase 5** | Standalone Hardware | Electro-Smith Daisy Seed MCU backpack with VL53L1X laser ToF sensor |

DualSynth seamlessly extends the **Surface Studio Suite** from desktop automation into handheld physical performance and future 3D environments.
