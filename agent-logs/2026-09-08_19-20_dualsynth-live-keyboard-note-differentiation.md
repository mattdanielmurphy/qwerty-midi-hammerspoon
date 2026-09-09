# DualSynth Live Piano Keyboard Monitor & Real-Time Note Differentiation

**Date:** 2026-09-08 19:20  
**Author:** Antigravity / Gemini  
**Project:** `packages/dualsynth` (`surface-studio-suite`)

## Summary
Designed, integrated, and verified a dynamic 3-octave visual piano keyboard monitor at the bottom of the DualSynth HUD. The monitor renders all active and latched notes in real time with high-contrast visual differentiation between the chord root specifically triggered by the player, harmonic chord extension voicings, and active arpeggiator step notes.

## Architectural Changes

1. **Telemetry & Root Pitch Tracking (`ControllerManager.swift`):**
   - Added `playedRootPitches: [UInt8]` and `activeArpPitch: UInt8?` to `ControllerTelemetry`.
   - Implemented `computeRootPitch(forDegree:)` to accurately calculate the diatonic root pitch of any played scale degree, taking into account `scaleDegreeShift`, `octaveShift`, and held-chord temporary transpositions.
   - Maintained `activeFaceRoots: [Int: UInt8]` alongside `activeFacePitches` in `handleFaceButton` and `revoiceActiveChord()`.
   - Wired `arpeggiatorTick()` and gate-off closures to set and clear `telemetry.activeArpPitch` in real time with immediate telemetry dispatch.

2. **Visual Piano Keyboard Architecture (`DualSenseView.swift`):**
   - Created `keyboardView(s: UIScale)`, `whiteKeyView`, `blackKeyView`, and `keyboardLegendBadge`.
   - Spans 3 dynamic octaves (22 white keys, 15 black keys, 37 notes) centered around `(rootKey + octaveShift)` and clamped to tonic $C$ boundaries.
   - Dynamic octave labeling on all $C$ keys (`C3`, `C4`, `C5`, `C6`).
   - Integrated full visual differentiation hierarchy:
     - **Played Root**: Vibrant Royal Blue fill (`Color.blue`), bright glowing cyan border, white text, and a distinct `ROOT / <Note>` badge.
     - **Chord Voicings / Extensions**: Translucent Cyan fill (`Color.cyan.opacity(0.35)`), accent border, and `• <Note>` dot badge.
     - **Active Arp Note**: Neon Orange fill (`Color.orange`), glowing drop shadow (`.shadow(color: .orange, radius: 6)`), and lightning bolt `⚡` icon.
     - **Idle Keys**: Obsidian/Card dark neutral theme with subtle key seams.

3. **Responsive Scaling & Geometry:**
   - Parameterized entirely with `UIScale` (`s.d()` and `s.f()`) for high-resolution 2x Retina vector graphics.
   - Updated `baseHeight` to 650 and `main.swift` window bounds to $860 \times 740$ (`minSize: 760 \times 600`).

## Verification
- Captured high-resolution screenshot at $1100 \times 850$ ($2200 \times 1700$ Retina pixels) via `_inspect-screen-visually` workflow.
- Verified live with actual controller input: player triggered `CMaj` chord; HUD immediately displayed `C4` as bright Blue `ROOT` and `E4` / `G4` as Cyan `CHORD` extensions with 100% precision.
