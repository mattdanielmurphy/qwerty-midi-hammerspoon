# qwerty-midi-hammerspoon Features

- **Modal QWERTY MIDI Controller**: Swallows keys in active mode to trigger CoreMIDI noteOn/noteOff and CC commands.
- **HTML/CSS Canvas HUD**: Floating, zoomable HUD (`Cmd + Alt + M`) displaying scale, root note, active notes, and control statuses.
- **Fraunces Typography & Dark Neutral Theme**: Warm charcoal aesthetic (`rgba(24, 22, 20, 0.96)`) using the Inter/Fraunces typography.
- **Interactive UI Key Clicks**: Clicking on-screen keys (notes or controls) triggers native MIDI notes and parameter adjustments.
- **Dropdown Root Selection**: Clickable `<select>` badge in HUD header to select root note (C through B) directly from a styled dropdown.
- **Draggable Mode Slider**: Interactive scale mode slider in HUD header allowing direct drag and click selection across all 9 modes/scales.
- **Built-in Arpeggiator**: Integrated arpeggiator engine with multiple modes (UP, DOWN, UP-DOWN, RANDOM), selectable BPM speeds, and real-time visual key highlights on active arpeggiated notes.
- **Jitter-Free Key Rendering**: Fixed-size key pads with non-shifting inset shadow press states to eliminate DOM layout shifts during fast playing.
- **Subtle Interval Indicators**: Root, 3rd, and 5th intervals highlighted with soft muted tones (`#d4a359`, `#c9bfb3`, `#b8aca0`) rather than bright colors.
- **Trackpad Volume & Mod Wheel Control**:
  - 2-finger scroll adjusts Mod Wheel (CC 1) by default.
  - Holding **Shift** while scrolling adjusts Master Volume (CC 7).
- **Fine Increment Button Controls**: Vol - / Vol + and Mod - / Mod + buttons use smooth 4-step adjustments.
- **Dedicated Number Row & Transpose Controls**:
  - Permanently visible Top Row (`1-0, -, =`) exposing Top Octave, Transpose (-/+ semitones), Global Octave, Scale Mode, Panic, Reset, and Zoom.
