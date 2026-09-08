# Project DualSynth: Technical Specification & Development Roadmap

---

## 1. Overview

DualSynth is a handheld, software-defined MIDI controller, multi-track groovebox, and interactive 3D studio environment. It utilizes standard consumer gamepad hardware (Sony DualSense) paired with a host device (macOS, iOS, or iPadOS) running a dedicated UI engine and CoreMIDI routing layer.

```
+------------------+         Bluetooth / USB-C         +----------------------+
|  PS5 DualSense   | ────────────────────────────────► |  Host (macOS / iOS)  |
|  (Input Device)  |                                   |  - Engine & Parser   |
+------------------+                                   |  - Dynamic HUD       |
         ▲                                             |  - CoreMIDI Output   |
         │                                             +----------------------+
         │ Haptics / Lightbar / Adaptive Trigger Data             │
         └────────────────────────────────────────────────────────┘
```

---

## 2. Hardware Justification: Gamepad vs. Legacy Inputs

Standard MIDI keyboards require flat surfaces, prioritize linear keyboard geography (C-Major diatonic bias), and limit concurrent continuous modulation. 

The Sony DualSense provides high input density, low latency, and continuous modulation channels in an ergonomic chassis:

| Component | Hardware Specification | Functional Mapping |
| :--- | :--- | :--- |
| **Triggers (L2, R2)** | 2× continuous analog Hall-effect axes | Continuous velocity gating, dynamic envelope/filter control |
| **Thumbsticks** | 2× dual-axis potentiometers (4 analog axes) | 4-channel continuous modulation (X/Y pitch, cutoff, panning, wet/dry) |
| **Shoulder Bumpers (L1, R1)** | 2× tactile digital switches | Momentary layer/shift modifiers |
| **Face Buttons / D-Pad** | 8× digital switches | Scale degrees, chord triggers, track routing |
| **Motion Sensor** | 6-axis IMU (3-axis gyro + 3-axis accelerometer) | Continuous tilt-based parameter modulation (pitch, vibrato, FX) |
| **Haptics** | Dual voice-coil actuators | Programmable metronome clicks, spatial threshold crossings |
| **Adaptive Triggers** | Dual geared servo motors | Programmed physical detents, variable resistance profiles |
| **Lightbar** | Multi-zone addressable RGB LED | State and modifier layer visualization |

---

## 3. Problem Analysis: Portable Hardware Limitations vs. Visual Scaffolding

### A. The Pocket Operator Failure Mode
Devices such as the Teenage Engineering Pocket Operator validate the demand for ultra-compact, high-density music production hardware, but introduce a critical usability flaw: **excessive cognitive load caused by blind modifier states.**

```
[Blind Hardware Architecture]
User Action ──► Modifier Pressed (No Visual Feedback) ──► Cryptic Parameter Shift ──► High Error Rate
```

* **Lack of State Persistence:** Functions rely on unlabelled combinations (e.g., `Hold Button X + Knob Y`).
* **High Attrition Rate:** Without persistent visual feedback, users experience rapid skill decay after periods of non-use.
* **Toggled State Hazards:** Mode-locks occur without clear notification, causing unintended data loss or destructive edits.

### B. The Solution: Dynamic Visual Scaffolding
DualSynth relies on a mandatory, low-latency visual anchor (a smartphone clipped to the controller or a nearby host monitor):

```
[DualSynth Architecture]
User Action ──► Modifier Pressed (L1/R1) ──► Instant HUD State Shift ──► Zero-Memorization Actuation
```

* **Spatial UI Geometry:** Holding a modifier displays an on-screen cross (D-Pad) and diamond (face buttons) matching the physical controller layout. Text menus are eliminated in favor of direct spatial association.
* **Progressive Disclosure:** Input intervals are monitored. High-latency inputs display explicit button labels; low-latency inputs (indicating muscle memory) trigger dynamic fading of textual scaffolding, replacing it with telemetry (oscilloscope, parameter values).
* **Peripheral State Confirmation:** Modifier presses simultaneously change the host UI theme and the physical controller lightbar color (e.g., Base = Green, Harmony = Blue, Looper = Amber).

---

## 4. Input Architecture & Control Scheme

To prevent state desynchronization, all major modifier keys are **momentary**, not toggle-based. Releasing the modifier immediately reverts the system to Base Play Mode.

```
                                [ INPUT MATRIX ]

             [ L1: Momentary Shift ]                [ R1: Momentary Shift ]
             Harmony / Chord Quality                 Track / Looper Control
                      \                                     /
             +-------------------------------------------------------+
             |   (D-PAD)             [ HOST HUD ]          (A B X Y) |
             |   Octave / Root       Dynamic Cross         Scale Note|
             |   Selection           Diamond Hotbar        Execution |
             |                                                       |
             |      (L-STICK)                             (R-STICK)  |
             |   Pitch / Mod XY                         Filter / FX  |
             +-------------------------------------------------------+
                      /                                     \
             [ L2: Analog Axis ]                   [ R2: Analog Axis ]
             Filter / Envelope Sweep               Dynamic Velocity / Gate
```

### Functional Domains

1. **Performance & Harmony:** Diatonic scale quantizer, polyphonic chord generator (triads, 7ths, suspensions, custom voicings), strum/arpeggiation engine.
2. **Arpeggiator / Latch:** Clock-synchronized rhythmic arpeggiation; latch toggled via `L3` (stick click).
3. **Multi-Track Looper:** 4-track real-time MIDI looper supporting overdub, mute/solo, track clearing, and non-destructive undo.
4. **Sound Engine / Synthesis:** Direct CC mapping for Cutoff, Resonance, Attack, Decay, Sustain, Release, and FX parameters.
5. **Transport / Master Clock:** Internal/external BPM sync, tap tempo (`R3`), and silent haptic metronome pulses.

---

## 5. Spatial & Gestural Tracking Architecture

To decouple the instrument from flat surfaces without relying strictly on internal IMU dead reckoning, DualSynth supports external spatial referencing:

```
                  +--------------------------------+
                  |  DualSense Controller          |
                  +--------------------------------+
                                  │
                                  ▼ (Downward Optical / ToF Reference)
      ┌───────────────────────────────────────────────────────────────┐
      │ [ Zone 1: Octave -1 ]   [ Zone 2: Base ]   [ Zone 3: Octave +1 ] │
      └───────────────────────────────────────────────────────────────┘
```

* **Height Axis (Z):** A downward-facing Time-of-Flight (ToF) sensor or camera tracking link computes distance to surface ($4\text{ cm} - 2\text{ m}$), outputting a continuous 7-bit or 14-bit MIDI CC value (acting as a virtual Theremin).
* **Lateral Axis (X/Y):** Movement across calibrated surface zones triggers global state, key, or octave transitions.
* **Haptic Thresholds:** Crossing designated spatial boundaries triggers a localized voice-coil transient pulse to provide physical feedback for virtual thresholds.

---

## 6. 3D Environment Architecture

Rather than a static timeline-based GUI, the interface can project into a real-time 3D space:

```
+-------------------------------------------------------------+
|                      3D STUDIO ENVIRONMENT                  |
|                                                             |
|       [ Node 1: Drums ]             [ Node 2: Lead Synth ]  |
|                                                             |
|                       [ Listener Node ]                     |
|                               ▲                             |
|                               │ Navigated via Left Stick    |
|                                                             |
|                       [ Node 3: Bass ]                      |
+-------------------------------------------------------------+
```

* **Dual-State Engine Navigation:**
  * **Explore Mode:** Left thumbstick controls 3D avatar/camera translation; right thumbstick controls orientation. Spatial audio nodes modulate wet/dry reverb balances based on geometry.
  * **Perform Mode:** Engaging an instrument node locks the camera to that station and rebinds controller inputs to the Performance Domain.
* **Fast-Travel Hotbar:** Holding `R1` displays an instantaneous radial selector, bypassing physical traversal to prevent workflow latency.
* **Audio-Reactive Telemetry:** Real-time Fast Fourier Transform (FFT) analysis maps audio output directly to 3D environment shaders and meshes.

---

## 7. Phased Implementation Roadmap

```
Phase 0 ──► Phase 1 ──► Phase 2 ──► Phase 3 ──► Phase 4 ──► Phase 5
(Mac PoC)   (iOS HUD)   (Groovebox) (Gestures)  (3D World)  (Embedded HW)
```

### Phase 0: Desktop Proof of Concept (macOS)
* **Target:** Verification of input latency, Bluetooth polling rates, and CoreMIDI reliability.
* **Deliverables:**
  * Native Swift project using `GameController.framework` and `CoreMIDI.framework`.
  * Basic mapping: Face buttons $\rightarrow$ diatonic notes; `R2` $\rightarrow$ velocity/gate; `L2` $\rightarrow$ CC #74.
  * Virtual MIDI endpoint creation routable to local DAWs.
* **Completion Criteria:** Stable Bluetooth input with under $5\text{ ms}$ processing latency; continuous trigger-to-CC output.

### Phase 1: Mobile HUD & Handheld Integration (iOS / iPadOS)
* **Target:** Untethering from desktop displays via a mounted smartphone interface.
* **Deliverables:**
  * Universal iOS/macOS multiplatform target in Xcode utilizing SwiftUI.
  * Spatial HUD engine rendering D-Pad cross and Face-Button diamond geometries.
  * Adaptive scaffolding logic: heuristic velocity/accuracy tracking controlling element opacity.
  * CoreMIDI background session handling for routing to external iOS synths (AUM, GarageBand).
* **Completion Criteria:** Functional standalone operation on iPhone clipped to DualSense via a mechanical mount, emitting virtual MIDI in background.

### Phase 2: Groovebox Engine, Multi-Tracking & Haptics
* **Target:** Self-contained multi-track sequencing and physical feedback integration.
* **Deliverables:**
  * Momentary shift logic for `L1` (Harmony), `R1` (Tracks), and `L1+R1` (Synth parameters).
  * Polyphonic chord generation engine with inversion and voicing selection.
  * 4-track loop engine (Record, Overdub, Play/Stop, Undo, Clear).
  * DualSense haptic implementation: quarter-note metronome pulse, boundary notifications.
* **Completion Criteria:** Execution of a complete 4-track looped musical arrangement exclusively using gamepad controls.

### Phase 3: Spatial & Gestural Tracking
* **Target:** Multi-axis physical motion integration.
* **Deliverables:**
  * 6-axis IMU parsing: continuous Pitch/Roll mapping to mod-wheel and auxiliary CCs.
  * DualSense adaptive trigger profiling: programmatic resistance steps and feedback detents.
  * Optical/ToF spatial tracking integration: distance-to-surface measurement via camera tracking or auxiliary ToF sensor.
* **Completion Criteria:** Successful modulation of audio parameters through physical spatial translation of the controller.

### Phase 4: 3D Virtual Studio Environment
* **Target:** Spatial gamification of the production environment.
* **Deliverables:**
  * Godot 4 implementation targeting macOS and iOS.
  * Dual-mode interaction architecture: Explore Mode (spatial traversal) and Perform Mode (camera-locked performance).
  * Fast-travel radial menu mapped to `R1` shortcuts.
  * FFT audio analysis pipeline feeding real-time vertex shaders and volumetric lights.
* **Completion Criteria:** Full track creation and parameter manipulation executed within a functional, audio-reactive 3D space.

### Phase 5: Standalone Hardware Autonomy (Optional)
* **Target:** Complete computing independence from commercial host phones/computers.
* **Deliverables:**
  * Snap-on modular backpack chassis housing an embedded audio MCU (Electro-Smith Daisy Seed, ARM Cortex-M7 @ 480 MHz) acting as USB Host.
  * Central 2.4-inch SPI/I2C IPS color display driven by the LVGL embedded graphics library.
  * Integrated VL53L1X laser distance sensor for dedicated height-axis tracking.
  * Direct 3.5 mm low-impedance analog headphone output.
* **Completion Criteria:** Sub-$500\text{ ms}$ cold-boot to audio performance without external host computation.

---

## 8. Technical Stack

* **Host Platform:** macOS 14+, iOS 17+, iPadOS 17+
* **Primary Language:** Swift
* **Core Frameworks:**
  * `GameController` (Input parsing, haptics, lightbar, adaptive triggers)
  * `CoreMIDI` (Virtual endpoints, packet transmission, clock synchronization)
  * `SwiftUI` (Dynamic 2D HUD rendering)
  * `Vision` / `AVFoundation` (Camera-based optical spatial tracking)
* **3D Subsystem:** Godot 4 (GDScript / C++) running Metal via MoltenVK/native driver
* **Target Input Hardware:** Sony DualSense Wireless Controller (Model CFI-ZCT1) via Bluetooth 5.1 or USB-C HID report mode
