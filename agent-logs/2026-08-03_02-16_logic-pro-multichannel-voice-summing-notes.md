# Agent Work Log: Logic Pro Multi-Channel Voice Summing Notes

## Summary
Documented DAW / Logic Pro behavior regarding multi-channel MIDI voice summing when routing multiple channels to a single instrument track.

## Findings & Documentation
- **Top Row**: Transmits on MIDI Channel 1 (`topRowChannel = 0`).
- **Bottom Row**: Transmits on MIDI Channel 2 (`bottomRowChannel = 1`).
- **Arpeggiator**: Transmits on MIDI Channel 3 (`arpChannel = 2`).
- **DAW Single-Track Behavior**: In Logic Pro, when a single software instrument track receives all MIDI channels, its internal synthesizer engine sums incoming MIDI note streams by pitch regardless of MIDI channel index. Sending a `Note-Off` for a specific pitch from one channel terminates the voice for that pitch on the synth.
- **Recommended Setup**: Create separate software instrument tracks in Logic Pro assigned to individual MIDI channels (Channel 1, Channel 2, Channel 3) to achieve full independent polyphony across rows.

## Updated Files
- `AG_CONTEXT.md`
- `DEVELOPMENT_JOURNAL.md`
