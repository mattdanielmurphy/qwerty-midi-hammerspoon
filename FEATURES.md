# qwerty-midi-hammerspoon Features

- **Modal QWERTY MIDI Controller**: Swallows keys in active mode to trigger CoreMIDI noteOn/noteOff and CC commands.
- **HTML/CSS Canvas HUD**: Floating, zoomable HUD (`Cmd + Alt + M`) displaying scale, root note, active notes, and control statuses.
- **Fraunces Typography & Dark Neutral Theme**: Warm charcoal aesthetic (`rgba(24, 22, 20, 0.96)`) using the Inter/Fraunces typography.
- **Interactive UI Key Clicks**: Clicking on-screen keys (notes or controls) triggers native MIDI notes and parameter adjustments.
- **Dropdown Root Selection**: Clickable `<select>` badge in HUD header to select root note (C through B) directly from a styled dropdown.
- **Draggable Mode Slider**: Interactive scale mode slider in HUD header allowing direct drag and click selection across all 9 modes/scales.
- **Unified Dual-Action Sustain / Latch**: Single Sustain key (`Tab` / `A`) that controls both CC #64 sustain and arpeggiator pattern latching simultaneously. Features dual action: **Tap** to toggle latch ON/OFF, or **Hold** for momentary sustain/latching while held down.
- **Built-in Arpeggiator**: Integrated arpeggiator engine with separate ON/OFF toggle, dropdown direction selector (UP, DOWN, UP-DOWN, RANDOM), time division rate dropdown (1/4 to 1/16T), note length gate duration dropdown (25% to 100%), selectable BPM speeds (freeform text input, arrow adjustments), per-row ARP filters, and real-time visual key highlights on active arpeggiated notes.
- **Jitter-Free Key Rendering**: Fixed-size key pads with non-shifting inset shadow press states to eliminate DOM layout shifts during fast playing.
- **Subtle Interval Indicators**: Root, 3rd, and 5th intervals highlighted with soft muted tones (`#d4a359`, `#c9bfb3`, `#b8aca0`) rather than bright colors.
- **Trackpad Volume & Mod Wheel Control**:
  - 2-finger scroll adjusts Mod Wheel (CC 1) by default.
  - Holding **Shift** while scrolling adjusts Top and Bottom Row Volumes simultaneously.
- **Separate Row Volume Controls & Split Arp Volume Boost**:
  - Independent volume levels for Top Row (upper keys Q..P) and Bottom Row (lower keys Z../).
  - Automatic default volume boost (+20 velocity) for Top Row when entering Split Arp mode (bottom row arp active, top row non-arp synth).
  - Dedicated VOL HUD badges displaying row volume levels and split-arp boost status.
- **Fine Increment Button Controls**: Vol - / Vol + and Mod - / Mod + buttons use smooth 4-step adjustments.
- **Modular Architecture & Generic `hs-bundler`**: Code split into `src/` modules (`config`, `midi`, `transposer`, `arpeggiator`, `hud`, `controls`, `ui_html`) with a generic Python bundler (`bin/hs-bundler`).
- **Auto-Bundle Launch Agent Watcher**: System Launch Agent (`com.matt.agent.qwerty-midi-bundler`) watches `src/` files and automatically reloads Hammerspoon with macOS notifications on file save.
- **Shift Key Sustain & Arpeggiator Bypass**: Holding **Shift** when tapping any note key inverts both current Arpeggiator and Sustain states for that note (e.g. bypasses active Arp/Sustain to play a direct un-sustained note, or triggers an Arp/Sustained note when Arp/Sustain are disabled) across both upper and lower keyboard rows.

