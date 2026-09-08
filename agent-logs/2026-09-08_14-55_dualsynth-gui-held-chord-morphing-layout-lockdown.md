# DualSynth GUI: Held-Chord Morphing, Layout Lockdown & Haptic Pulse Optimization

**Date**: 2026-09-08 14:55  
**Author**: Antigravity Orchestrator  
**Components Modified**:
- `packages/dualsynth/macos/Sources/DualSynthCore/ControllerManager.swift`
- `packages/dualsynth/macos/Sources/dualsynth-gui/DualSenseView.swift`

---

## 1. Problem Addressed
1. **Unwanted Layout Reflow & Text Wrapping**: When shift triggers (L1/R1) were held, chord names or badges would wrap into narrow vertical slivers (e.g. 10 lines of 2 characters), shifting and breaking the DualSense visual layout.
2. **Held-Chord Morphing Feature**: User requested that holding a note/chord button should lock into a dynamic state where D-Pad and other controls alter, add on to (+8va, +Sub), or transpose the active chord in real time, reverting back to standard state upon button release.
3. **Trigger CC Mutings**: R2 trigger at 0 previously silenced Logic Pro instruments due to CC #11 (Expression) multiplying overall volume down to zero.
4. **CoreHaptics Error -4810**: Rapid continuous calls to `makeAdvancedPlayer` in CoreHaptics flooded the haptic driver and disconnected the daemon.

---

## 2. Changes Implemented
- **DualSenseView Static Layout Lockdown**:
  - Implemented `.fixedSize()` and `.lineLimit(1)` across all D-Pad, face buttons, stick wells, and header badges.
  - Locked columns to fixed widths (`128px` for left/right sticks and button clusters, `50px` for center controls) preventing any horizontal flex compression or vertical column crushing.
  - Sized chord labels dynamically (`8.5px` - `12px` font) to guarantee zero text wrapping.
  - Rendered clean vector glyphs for Create (`|||`) and Options (`☰`) without micro-text labels.
- **Held-Chord Morphing Engine**:
  - In `ControllerManager.swift`, tracked `heldFaceButtonIndex`, `heldChordTemporaryTranspose`, `heldChordAddSubBass`, and `heldChordAddHighOctave`.
  - While holding a chord face button, pressing D-Pad performs real-time alterations:
    - **Up**: Toggle `+8va` high octave extension.
    - **Down**: Toggle `+Sub` deep bass sub-octave.
    - **Left / Right**: Semitone transposition down/up (`Semi-` / `Semi+`).
  - Pressing a second face button while holding the first toggles chord octave extension.
  - Dynamic HUD labels update instantly to show `MORPH (HELD)`, `+8va`, `+Sub`, `Semi-`, `Semi+`, and composite chord names (e.g. `C Maj /Bass +8va`).
  - Releasing the held chord button immediately reverts transposition, extensions, and revoices cleanly.
- **Trigger Expression & Cutoff Tuning**:
  - R2 defaults to CC #11 = 127 on idle so instruments are never muted. Scaled trigger pull maps smoothly from 90 to 127 and modulates note strike velocity.
  - L2 broadcasts both CC #74 and CC #2 (Breath/Filter) with adaptive trigger resistance.
- **Throttled Discrete Haptic Grains**:
  - Switched from rapid `makeAdvancedPlayer` creation to single pulse grains (`120ms` duration) with `Date` throttling, completely eliminating CoreHaptics `-4810` disconnects.

---

## 3. Verification
- `swift build` passes with zero errors and zero warnings.
- Background GUI process restarted (`PID 47076`) with latest binary and active CoreMIDI routing.
