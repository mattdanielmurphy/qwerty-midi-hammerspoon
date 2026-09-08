# DualSynth: Pitch Bend, Dual-Stick Expression, Multi-Note Arp Pooling & 5-Stage Discrete Haptics

**Date**: 2026-09-08 15:05  
**Author**: Antigravity Orchestrator  
**Components Modified**:
- `packages/dualsynth/macos/Sources/DualSynthCore/ControllerManager.swift`
- `packages/dualsynth/macos/Sources/DualSynthCore/MIDIEngine.swift`
- `packages/dualsynth/macos/Sources/dualsynth-gui/main.swift`
- `packages/dualsynth/macos/Sources/dualsynth-cli/main.swift`
- `packages/dualsynth/macos/Sources/dualsynth-gui/DualSenseView.swift`

---

## 1. Issues Resolved
1. **Left Stick (Pitch Bend & Negative Mod)**:
   - Left stick X was previously unhandled and never forwarded to CoreMIDI pitch bend. Added `pitchBendChanged(value: UInt16)` across `DualSynthDelegate`, `AppDelegate`, and `DualSynthCoordinator`, sending standard 14-bit pitch bend (`0..16383`, centered at `8192`) via `0xE0` channel voice messages.
   - Pushing Left Stick UP modulates CC #1 (Mod Wheel, $0 \to 127$); pulling DOWN ($yVal < -0.05$) dynamically sweeps Filter Cutoff (CC #74) and Breath Filter (CC #2) downwards ($127 \to 0$), auto-resetting to neutral on stick release.
2. **Right Stick Dynamics & Expression**:
   - Right Stick X sends Stereo Pan (CC #10, $0 \dots 127$) with automatic center return (64) upon release.
   - Right Stick Y pushes upwards for Resonance (CC #71) + Brightness (CC #74), and pulls downwards for Expression Ducking (CC #11, $127 \to 20$) and Cutoff dip ($127 \to 10$), giving immediate, dramatic audible feedback on all Logic Pro software instruments.
3. **Multi-Button Arpeggiator Pooling**:
   - Previously, pressing a second button in Arp mode either triggered an octave extension or overwrote the single chord buffer.
   - Implemented `activeFaceButtons: Set<Int>` and `activeFacePitches: [Int: [UInt8]]`. Pressing multiple notes/chords simultaneously pools all distinct pitches across all held buttons into `latchedPitches`, dynamically cycling all notes in sequence. Releasing one button seamlessly updates the pool to the remaining held notes.
4. **Gyro Tilt Heavy EMA Smoothing & Rest Deadband**:
   - Replaced noisy instantaneous tilt calculations with an Exponential Moving Average filter ($\alpha = 0.08$).
   - Added a hard 4.5° table-rest deadband so placing the controller flat produces strictly $0.0^\circ$ and $0\%$ Mod Wheel, completely eliminating table jitter and 1%–2% flickering.
5. **5-Stage Discrete Haptic Pulses (No Drone Vibration)**:
   - Replaced constant continuous vibration with 5 discrete stage thresholds across Mod Wheel $1 \dots 127$:
     - Stage 0 (Resting / MW = 0): Silent.
     - Stage 1 (MW 1–25): 1 subtle pulse (intensity 0.25).
     - Stage 2 (MW 26–50): 1 solid pulse (intensity 0.40).
     - Stage 3 (MW 51–75): 2 pulses (intensity 0.55).
     - Stage 4 (MW 76–101): 2 strong pulses (intensity 0.70).
     - Stage 5 (MW 102–127): 3 maximum strength pulses! (intensity 0.85).
   - Pulses are triggered exclusively upon crossing into higher stage thresholds.

---

## 2. Verification
- `swift build` passes with 0 warnings, 0 errors.
- Background process reloaded (`bun run dualsynth:gui`, PID `60575`).
- Bundled and verified Hammerspoon reload.
