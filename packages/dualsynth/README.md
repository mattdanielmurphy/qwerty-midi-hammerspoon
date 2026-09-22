# @surface-studio/dualsynth

> Handheld software-defined MIDI groovebox, dynamic visual scaffolding HUD, and 3D studio environment powered by Sony DualSense and Apple GameController.framework.

Part of the **Surface Studio Suite** monorepo.

---

## Documentation

- **[Technical Specification & Development Roadmap](file:///Users/matt/projects/qwerty-midi-hammerspoon/packages/dualsynth/DUALSYNTH_SPEC.md)**: Full 5-phase roadmap, problem analysis (Pocket Operator cognitive load vs. visual HUD scaffolding), and hardware specifications.
- **[Architecture & Hammerspoon Integration](file:///Users/matt/projects/qwerty-midi-hammerspoon/packages/dualsynth/ARCHITECTURE.md)**: Deep dive into runtime constraints, Apple `GameController.framework`, virtual CoreMIDI endpoints, Hammerspoon `hs.midi` orchestration, and `surface-hud` layout integration.

---

## Directory Structure

```
packages/dualsynth/
├── README.md               # Package overview and quickstart
├── DUALSYNTH_SPEC.md       # Technical specification and phased roadmap
├── ARCHITECTURE.md         # Monorepo architecture & Hammerspoon integration
├── package.json            # Bun workspace package definition
├── layouts/                # Spatial HUD layout definitions (cross & diamond)
│   └── dualsense.json      # DualSense physical coordinate layout mapping
└── macos/                  # Phase 0: Swift Desktop PoC (GameController + CoreMIDI)
    ├── Package.swift
    └── Sources/
        ├── DualSynthCore/  # Controller listener, MIDI engine, haptics
        └── dualsynth-cli/  # CLI daemon runner
```

---

## Hardware Support

- **Input Device**: Sony PS5 DualSense Wireless Controller (Model CFI-ZCT1)
- **Connection**: Bluetooth 5.1 or USB-C HID
- **Advanced Features**:
  - Continuous Hall-effect triggers: L2 controls expression (CC #11) and cutoff (CC #74); R2 controls FX / reverb send (CC #91)
  - Sound controls target the selected QWERTY Track 1–4 MIDI channel; hold Create + D-Pad to choose the track
  - Hold Options + D-Pad to choose an operating mode; selection occurs on the D-Pad press, never when releasing a trigger
  - Dual analog sticks $\rightarrow$ 4-axis continuous modulation & 3D space traversal
  - 6-axis IMU (Gyro/Accel) $\rightarrow$ Continuous tilt vibrato/pitch/FX
  - Dual voice-coil haptics $\rightarrow$ Metronome pulse & detent crossing
  - Multi-zone RGB lightbar $\rightarrow$ Dynamic modifier confirmation (Base = Green, Harmony = Blue, Looper = Amber)
  - Adaptive triggers $\rightarrow$ Programmatic physical resistance detents
