# Work Log: Multi-Track Matrix, Degree Transposition & Arp Bypass Implementation

**Timestamp**: 2026-09-16 22:45
**Author**: Antigravity Main Orchestrator

## Overview
Implemented the full backend execution engine for the consolidated 8-layer key matrix in `qwerty-midi-hammerspoon`, wired multi-track MIDI routing, resolved the shift-press arpeggiator inversion bug, and ensured continuous arpeggio playback even when the HUD window is closed.

## Key Changes
1. **Shift-Press Arpeggiator Fix**:
   - Fixed `isArpNote` calculation in `src/controls.lua`:
     ```lua
     local isArpNote = (not state.arpBypassed) and arpActive and (not state.shiftHeld)
     ```
   - Enforced that holding Shift acts strictly as an Arpeggiator Bypass modifier when the arpeggiator is active. When the arpeggiator is OFF for that row, Shift-pressing notes no longer activates arpeggiator-enabled notes.
2. **Consolidated 8-Layer Key Matrix**:
   - Wired `handleKeyDown` in `src/controls.lua` to dynamically check `hud.getProposedActionDef(code)` across all modifier combinations: `Base`, `Shift`, `Option`, `Shift+Option`, `Control`, `Shift+Control`, `Control+Option`, `Control+Option+Shift`.
   - Connected all key action branches in `executeControlAction`:
     - **Transposition (`J`)**: $\pm 1$ step (`base`/`shift`), $\pm 2$ steps / 3rd (`opt`/`shift_opt`), $\pm 3$ steps / 4th (`ctrl_opt`/`ctrl_opt_shift`), Snap up to nearest Root (`ctrl`), Snap down to nearest Subtonic (`shift_ctrl`).
     - **Mode (`G`)**: $\pm 1$ step, $\pm 2$ steps, instant mode snaps (Major, Aeolian, Lydian, Locrian).
     - **Root (`H`)**: $\pm 1$ semitone, $\pm 5$th (Circle of Fifths), instant snaps to C and A, and octave jumps.
     - **Octave (`D`)**: $\pm 1$ main octave, top/bottom row octave offsets, and instant `octReset`.
     - **Master Arp & Loops (`F`)**: Arp latch toggle, loop lock, lock & swap (`lockAndSwap`), lock all 4 tracks, stop all loops (`stopLoops`), and freeze.
     - **Bottom Row Track Focus (`K`)**: Track 1⇄2 toggle, bottom row lock, mutes, solos, and record arms.
     - **Top Row Track Focus (`L`)**: Track 3⇄4 toggle, top row lock, mutes, solos, and record arms.
     - **Master Focus & Mix (`;`)**: Focus cycle, all tracks mute toggle, volume trim, and mixer reset.
     - **Dedicated Track Strips (`1`–`4`)**: Direct selection, individual mutes, solos, record arms, locks, and sequence clears.
     - **Performance Parameter Presets**: Arp direction presets on `5`, rate divisions on `6`, gate presets on `7`, sync & clock on `8`, synth release ADSR presets on `9`, volume & mod wheel on `0`, and tempo presets on `-` / `=`.
3. **Multi-Track Audio Engine & Audibility**:
   - Added 4-track channel routing in `src/config.lua` (Tracks 1: Bass Ch 0, 2: Chords Ch 1, 3: Lead Ch 2, 4: Arp Ch 3).
   - Added `isTrackAudible(trkIdx)` gating in `src/controls.lua` and `src/arpeggiator.lua` respecting track mute and solo states for live notes and background arpeggios.
4. **Continuous Background Playback**:
   - Decoupled arpeggiator timer from window lifecycle in `src/init.lua`, allowing locked loop sequences to continue streaming MIDI in the background when the HUD is closed or hidden.

## Verification
- Built and reloaded Hammerspoon cleanly via `bin/bundle_and_reload.sh`.
- Executed programmatic test suites via `hs -c`:
  - Verified `isArpNote` returns false when arp is OFF and Shift is held (live notes play, arp does not start).
  - Verified `isArpNote` returns false when arp is ON and Shift is held (arp bypass active).
  - Verified all 8 modifier layers on key `J` resolve to their respective transposition actions.
  - Verified transposition degree progression ($0 \to 1 \to 3 \to 6 \to 0$) via `executeControlAction`.
  - Verified track 1⇄2 and 3⇄4 toggling, channel reassignment, and loop lock/swap logic.
