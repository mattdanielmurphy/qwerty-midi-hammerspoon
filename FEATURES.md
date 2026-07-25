# qwerty-midi-hammerspoon Features

- **Modal QWERTY MIDI Controller**: Swallows keys in active mode to trigger CoreMIDI noteOn/noteOff and CC commands.
- **HTML/CSS Canvas HUD**: Floating, zoomable HUD (`Cmd + Alt + M`) displaying scale, root note, active notes, and control statuses.
- **Fraunces Typography & Dark Neutral Theme**: Warm charcoal aesthetic (`rgba(24, 22, 20, 0.96)`) using the Inter/Fraunces typography.
- **Interactive UI Key Clicks**: Clicking on-screen keys (notes or controls) triggers native MIDI notes and parameter adjustments.
- **Dropdown Root Selection**: Clickable `<select>` badge in HUD header to select root note (C through B) directly from a styled dropdown.
- **Draggable Mode Slider**: Interactive scale mode slider in HUD header allowing direct drag and click selection across all 9 modes/scales.
- **Dedicated Sustain & Arp Latch Keys**:
  - **Sustain (`Tab`)**: Dedicated control for MIDI CC #64. Features dual action: **Tap** to toggle sustain ON/OFF, or **Hold** (>0.25s) for momentary pedal sustain. Shown on the upper row of the visual keyboard grid.
  - **Arp Latch (`A`)**: Dedicated control for Arpeggiator pattern latching. Features dual action: **Tap** to toggle latch ON/OFF, or **Hold** (>0.25s) for momentary pattern latching.
- **Built-in Arpeggiator**: Integrated arpeggiator engine with separate ON/OFF toggle, dropdown direction selector (UP, DOWN, UP-DOWN, RANDOM), time division rate dropdown (1/4 to 1/16T), note length gate duration dropdown (25% to 100%), selectable BPM speeds (freeform text input, arrow adjustments), per-row ARP filters, and real-time visual key highlights on active arpeggiated notes.
- **Jitter-Free Key Rendering**: Fixed-size key pads with non-shifting inset shadow press states to eliminate DOM layout shifts during fast playing.
- **Subtle Interval Indicators**: Root, 3rd, and 5th intervals highlighted with soft muted tones (`#d4a359`, `#c9bfb3`, `#b8aca0`) rather than bright colors.
- **Trackpad Volume & Mod Wheel Control**:
  - 2-finger scroll adjusts Mod Wheel (CC 1) by default.
  - Holding **Shift** while scrolling adjusts Top and Bottom Row Volumes simultaneously.
- **Separate Row Volume Controls & Split Arp Volume Boost**:
  - Independent volume levels for Top Row (upper keys Q..P) and Bottom Row (lower keys Z../).
  - Explicit row distinction for overlapping key notes ensuring bottom row key presses accurately resolve to bottom row velocity.
  - Automatic default volume boost (+20 velocity) for Top Row when entering Split Arp mode (bottom row arp active, top row non-arp synth).
  - Dedicated VOL HUD badges displaying row volume levels and split-arp boost status.
- **Fine Increment Button Controls**: Vol - / Vol + and Mod - / Mod + buttons use smooth 4-step adjustments.
- **Modular Architecture & Generic `hs-bundler`**: Code split into `src/` modules (`config`, `midi`, `transposer`, `arpeggiator`, `hud`, `controls`, `ui_html`) with a generic Python bundler (`bin/hs-bundler`).
- **Auto-Bundle Launch Agent Watcher**: System Launch Agent (`com.matt.agent.qwerty-midi-bundler`) watches `src/` files and automatically reloads Hammerspoon with macOS notifications on file save.
- **Shift Key Sustain & Arpeggiator Bypass**: Holding **Shift** when tapping any note key inverts both current Arpeggiator and Sustain states for that note (e.g. bypasses active Arp/Sustain to play a direct un-sustained note, or triggers an Arp/Sustained note when Arp/Sustain are disabled) across both upper and lower keyboard rows.
- **Dedicated Number Row Arp Controls**: Number keys `1` through `=` mapped to comprehensive Arp & BPM controls (`1`: Arp On/Off, `2`: Top Arp, `3`: Bot Arp, `4`/`5`: Dir -/+, `6`/`7`: Rate -/+, `8`/`9`: Gate -/+, `0`: BPM Set, `-`/`=`: BPM -/+). Holding **Shift** accesses alternate controls (Panic, Transpose, Octave, Mode, Zoom, Reset).
- **Arp Latch Chord Transition & Mode Switch Clearing**: Improved latch mode chord recognition so transitioning between chords seamlessly replaces the prior chord without restricting subsequent note polyphony or dropping notes. Switching Arp mode from `ARP: LATCH` to `ARP: ON` immediately clears latched released notes so only physically held keys remain active.
- **Logic Pro Session BPM Sync**: Real-time auto-synchronization between active Logic Pro session BPM and the Arpeggiator engine via non-blocking background AppleScript task with an interactive header `SYNC: ON/OFF` toggle button.
- **Ultra-Low Latency & 60 FPS Batched HUD Rendering**: Decoupled instant CoreMIDI note transmission from WebKit IPC visual updates. Visual HUD rendering is batched at ~60 FPS (16ms throttle) to eliminate main thread stalls and hiccupping during rapid note playing or fast arpeggio ticks.
- **Correlated Control Key Pair Styling**: Related control keys (e.g. `J`/`K` Transpose, `H`/`L` Root, `G`/`;` Mode, `D`/`F` Octave, `3`/`4` Dir, `5`/`6` Rate, `7`/`8` Gate, `-`/`=` BPM) share cohesive, understated color accents matching the warm dark HUD theme for effortless visual grouping without dominating note keys.


- **Instant BPM Type-Tempo Mode & Drag Persistence**: Clicking the BPM display immediately opens 'Type tempo' input mode on mouse release. Dragging the BPM up/down dynamically adjusts tempo and commits the target BPM to both the Arpeggiator and active Logic Pro session on mouse release.