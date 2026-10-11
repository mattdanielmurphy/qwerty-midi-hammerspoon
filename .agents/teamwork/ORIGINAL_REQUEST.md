# Original User Request

## 2026-10-11T16:37:51Z

Comprehensive fix and enhancement suite for qwerty-midi-hammerspoon addressing track volume controls, rich arpeggiator patterns with humanized timing, configurable quantize strength, visual overlay readability/wrapping, real-time control state indicators, stuck-note mitigation loops, and tap tempo repair.

Working directory: /Users/matt/projects/qwerty-midi-hammerspoon
Integrity mode: development

## Requirements

### R1. Track Volume Control Keys
Implement dedicated key bindings to control volume levels (e.g. MIDI CC 7 / volume controls) for each track individually.

### R2. Rich Arpeggiator Patterns & Human Feel
Add diverse arpeggiator patterns with distinct velocity contours, gate lengths, and microtiming/human-feel idiosyncrasies.

### R3. Configurable Quantization Amount
Support adjustable quantization strength with a default setting of 90%.

### R4. Key Overlay Legibility & Label Text Wrapping
Resolve visual overlay rendering issues under modifier keys (like Cmd): prevent text overflow by wrapping key labels within key boundaries, eliminate overlapping "Pass Through" clutter, and fix key opacity/dimming so labels are clearly legible.

### R5. Real-Time State Indicator on Keys
Display the active state / current quantity of the parameter or value controlled by each key directly on the key surface for at-a-glance visibility.

### R6. Stuck Note Mitigation & Watchdog Loop
Fix note-off drops occurring during rapid consecutive key playback under quantization, and implement an automatic watchdog loop that detects and clears stuck/orphaned MIDI notes.

### R7. Tap Tempo Functionality
Diagnose and repair the tap tempo engine to accurately track tap intervals and update BPM.

## Acceptance Criteria

### Audio & MIDI Engine
- [ ] Track volume controls adjust individual track volumes reliably without dropping note events.
- [ ] Quantization amount parameter can be configured between 0% and 100%, defaulting to 90%.
- [ ] Arpeggiator supports multiple distinct rhythm, velocity, and gate patterns with humanized microtiming deviations.
- [ ] Stuck notes are eliminated during rapid consecutive keypresses, and a watchdog safety loop releases orphaned active notes.
- [ ] Tap tempo accurately calculates BPM from consecutive tap inputs.

### UI & Overlay Display
- [ ] Key label text wraps neatly within key boundaries without exceeding key frames or clipping.
- [ ] Modifier mode (Cmd hold) maintains clear, readable text contrast and opacity without muddy dimming.
- [ ] Overlapping "Pass Through" labels are cleanly formatted or suppressed when redundant.
- [ ] Key labels dynamically reflect the current quantity/value of the assigned control state.
