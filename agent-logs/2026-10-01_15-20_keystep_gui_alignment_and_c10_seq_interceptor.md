# KeyStep 32 Physical Layout Alignment & C10 Sequencer Interception

**Date**: 2026-10-01 15:20  
**Workspace**: `/Users/matt/projects/qwerty-midi-hammerspoon`  
**Status**: Completed & Verified  

## Summary
Resolved KeyStep 32 sequencer note interception and aligned the WebKit HUD GUI to match the physical hardware controller photo (`media_1790888932478.jpg`) and MIDI telemetry screenshot (`media_1790888655497.png`).

1. **Sequencer Marker Note Interception (C10 / C#10)**:
   - Diagnostic MIDI telemetry confirmed the KeyStep hardware emits sequencer position marker notes on Channel 3 starting at note 120 (C10, `146 120 1`) for Sequence 1 and 121 (C#10) for Sequence 2.
   - Updated `packages/keystep-interceptor/keystep.lua` so `MODE_NOTES` maps 120..127 to sequencer modes 1..8 (while retaining backward compatibility for 108..115 on older firmware).
   - Ensured sequencer marker notes switch `state.mode` to `'seq'`, swallow internal note-on and note-off events cleanly, and prevent them from leaking into the musical audio stream.

2. **Knob Order & Label Alignment**:
   - Knob 1 (`Seq / Arp Mode`): 8 settings ("1: Up" through "8: Dwn x2" in Arp; "Seq 1" through "Seq 8" in Seq).
   - Knob 2 (`Time Div`): Aligned to hardware progression: Straight divisions first (`1/4`, `1/8`, `1/16`, `1/32`), followed by Triplet divisions (`1/4T`, `1/8T`, `1/16T`, `1/32T`).
   - Knob 3 (`Rate`): Smooth continuous rotary wheel supporting full 0..127 MIDI resolution and vertical mouse drag with blinking tempo LED.

3. **Authentic Hardware Silhouette & 32-Key Bed**:
   - Rebuilt `.keystep-view` in `src/web/index.html` to mirror the physical layout:
     - **Left Cheek**: KeyStep branding title & subtitle, Hold (Chord) button, Shift button, Oct - (Transpose) and Oct + (Kbd Play) with `- Reset -`, and vertical capacitive Pitch Bend & Modulation touch strips.
     - **Top Bar**: Recessed silver panel housing the Seq/Arp toggle switch, 3 rotary dials (Seq/Arp Mode, Time Div, Rate with tempo LED), 4 transport buttons (Tap [Rest/Tie], Rec [Append], Stop [Clear Last], Play/Pause [Restart]), and Arturia logo.
     - **Silkscreen Bar**: Exact hardware function markings aligned directly above the slimkeys (MIDI Ch 1–16, Gate 10%–90%, Swing Off–75%).
     - **32-Key Slimkey Keybed**: Starts on **F** (note 41) and ends on **C** (note 72) with 19 white keys and 13 black keys grouped naturally (3-2-3-2-3), replacing the generic C-starting octave mockup.

4. **Testing & Bundling**:
   - All 26 tests across 8 test suites pass via `bun test`.
   - Bundled all targets (`qwerty-midi`, `studio-suite`, `keystep-interceptor`) with updated `src/ui_html.lua`.
