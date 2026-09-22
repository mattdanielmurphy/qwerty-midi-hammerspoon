# DualSynth Sound & Track Controls

- Made `Sound & Tracks` the DualSynth default: its continuous controls now target the selected QWERTY track channel (Tracks 1–4 map to MIDI channels 1–4).
- Replaced R2's release-to-select mode menu with a continuous CC #91 FX/reverb-send control and slope-feedback trigger resistance.
- Added immediate held menus: Create + D-Pad selects Tracks 1–4 (left/up/right/down); Options + D-Pad selects Sound & Tracks, Chords, Melodic, or Drums. Releasing either button never commits a different choice.
- Extended distributed-notification synchronization so selecting a track from either the QWERTY controller or DualSynth updates the other surface.
- Verification: `swift build`, `bun run bundle`, and `bun test` all passed.
