# Agent Log: Track States, Row Split Isolation, Functional Muting/Soloing, and 4 Independent Arpeggiators

**Date**: 2026-09-16 23:34
**Author**: Antigravity

## Context
The user requested four major enhancements to qwerty-midi-hammerspoon:
1. Visualizing 6 distinct track states without overlap/interference: Muted, Soloed, Active, Audio Occurring, Human Note Press, and Arp Stepping.
2. Subtle aesthetic constraint: NO text badges for human keypress or arp notes. Badges for Mute (`[M]`) and Solo (`[S]`) are approved, but human keypress and arp notes must remain subtle and intuitive (pad surface glow and rhythmic tempo border pulse).
3. Row Split Isolation: Tracks 1 & 2 are strictly for the Bottom Row (Home & Lower rows); Tracks 3 & 4 are strictly for the Top Row (Upper row). Switching tracks on one row must not alter the other row. Top and bottom rows must be playable simultaneously across separate MIDI channels.
4. Functional Mute and Solo: Mute and Solo must silence held notes, sustained pitches, and arp gates immediately in real-time.
5. 4 Independent Arpeggiators: Each track runs its own arpeggiator clock timer, rate, gate, and direction independently.

## Changes Made
- `src/config.lua`:
  - Added `physicalKeysHeld = {}` and `arpIsPlaying = false` to all 4 track definitions in `state.tracks`.
- `src/arpeggiator.lua`:
  - Implemented `isTrackAudible(trkId)` considering global solo status and per-track mute/solo states.
  - Implemented `silenceTrack(trkId)` to cleanly send `noteOff` for active gates, current pitches, and cancel gate timers.
  - Replaced single monolithic timer with per-track timers (`trk.timer`) via `startTrackArp(trk)` and `stopTrackArp(trk)`.
  - Updated `arpTickTrack(trk)` with per-track interval timing, `trk.arpIsPlaying = true/false` state management, and real-time audibility gate.
  - Updated `applyBpmChange` to dynamically adjust all active per-track timers.
  - Updated `toggleArpPower` and `toggleArpLatch` to operate on `trk`.
- `src/controls.lua`:
  - Implemented `syncTrackAudibility()` to silence inaudible tracks and resume keys upon unmuting.
  - Updated `selectTrack(id)` to isolate rows: 1-2 for bottom row, 3-4 for top row.
  - Hooked `syncTrackAudibility()` into `trkMute`, `trkSolo`, `allMuteToggle`, and `mixReset`.
  - Updated `handleKeyDown` and `handleKeyUp` to route note keys by `noteKey.isTop` (`state.topRowTrack` vs `state.bottomRowTrack`), tracking `physicalKeysHeld` per track.
- `src/hud.lua`:
  - Updated note keys loop in `performWebviewHudUpdate` to evaluate each note against its row's track.
  - Updated track button loop to provide dual selection, mute, solo, audio active, human active, and arp stepping telemetry.
  - Updated payload with `topRowTrack`, `bottomRowTrack`, `topTrackColor`, `bottomTrackColor`, and full 6-state `tracks` table.
  - Updated `fastUpdateArp()` to compute 4-track note states and pass `trkStates` to `updateArpPitches`.
  - Added message handlers for `trkMute`, `trkSolo`, and `selectTrack` with integer conversion.
- `src/web/index.html`:
  - Configured row-specific CSS variables: `--top-track-color` on `#row-upper` and `--bottom-track-color` on `#row-home, #row-lower`.
  - Replaced old destructive MUTE overlay with discrete, clickable `[M]` and `[S]` top-right badges.
  - Implemented subtle pad surface glow for `.trk-human-active` and rhythmic pulse for `.trk-arp-step`.
  - Added `window.callHammerspoon` helper for WebKit IPC messages.
  - Updated `initGrid` to create M/S badges on keys 18–21 with click listeners.
  - Updated `renderHud` and `window.updateArpPitches` to toggle all 6 states in real-time.
- Bundled and reloaded via `bin/bundle_and_reload.sh`.

## Verification
- Verified dual row selection (`bot=1, top=3`, `selectTrack(2) -> bot=2, top=3`, `selectTrack(4) -> bot=2, top=4`).
- Verified functional real-time mute and solo audibility via `hs -c`.
- Verified simultaneous key triggers across Channel 0 (Bottom row) and Channel 2 (Top row).
- Verified independent per-track arp timers (`t1Running=true, t3Running=true`, stopping t1 leaves t3 running).
- Verified WebKit DOM badges and IPC clicks via `callHammerspoon('trkMute1')`.
