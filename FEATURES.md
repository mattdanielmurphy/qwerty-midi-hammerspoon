# qwerty-midi-hammerspoon Features

- **Modal QWERTY MIDI Controller**: Swallows keys in active mode to trigger CoreMIDI noteOn/noteOff and CC commands.
- **HTML/CSS Canvas HUD**: Floating, zoomable HUD (`Cmd + Alt + M`) displaying scale, root note, active notes, and control statuses.
- **Fraunces Typography & Dark Neutral Theme**: Warm charcoal aesthetic (`rgba(24, 22, 20, 0.96)`) using the Fraunces Google Font.
- **Jitter-Free Key Rendering**: Fixed-size key pads with non-shifting inset shadow press states to eliminate DOM layout shifts during fast playing.
- **Subtle Interval Indicators**: Root, 3rd, and 5th intervals highlighted with soft muted tones (`#d4a359`, `#c9bfb3`, `#b8aca0`) rather than bright colors.
- **Trackpad Volume & Mod Wheel Control**:
  - 2-finger scroll adjusts Mod Wheel (CC 1) by default.
  - Holding **Shift** while scrolling adjusts Master Volume (CC 7).
- **Fine Increment Button Controls**: Vol - / Vol + and Mod - / Mod + buttons use smooth 4-step adjustments.
- **Dedicated Number Row & Transpose Controls**:
  - Permanently visible Top Row (`1-0, -, =`) exposing Top Octave, Transpose (-/+ semitones), Global Octave, Scale Mode, Panic, Reset, and Zoom.
