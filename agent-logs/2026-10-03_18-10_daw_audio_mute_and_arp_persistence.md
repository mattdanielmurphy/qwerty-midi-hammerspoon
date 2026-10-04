# 2026-10-03 18:10 — Logic Pro DAW Audio Mute/Solo Cutoff & Arpeggiator Persistence

## Context & User Problem
The user reported that muting and soloing were only controlling MIDI note transport rather than actually muting audio in Logic Pro:
1. When muting a track with instruments having long release envelopes or reverb/delay effects, the synth voice continued to ring out audibly instead of being truly muted.
2. When muting and then unmuting a track with a running arpeggiator, the arpeggiator failed to sound again upon unmute. Furthermore, notes struck while a track was muted were dropped completely instead of being captured into the arpeggiator sequence.

## Root Cause Analysis
1. **Audio Silence Void**: `syncTrackAudibility()` previously only issued Note-Off messages to physically held notes in `state.pressedKeys` and sustained notes. Because instruments with long release stages (or infinite release drones) only trigger their release envelope on Note-Off, the audio sound generator continued vibrating at full fader volume. No MIDI CC 7 (Volume), CC 11 (Expression), CC 120 (All Sound Off), or CC 123 (All Notes Off) messages were being transmitted to Logic Pro.
2. **Arp Note Ingestion Gate**: In `src/controls.lua`, `handleKeyDown` wrapped both arpeggiator note additions (`arpAddNote`) and direct note triggers within `if isTrackAudible(trkIdx)`. When a track was muted, `isTrackAudible` evaluated to `false`, causing all arpeggiated note strikes to be dropped without entering `trk.heldNotes` or `trk.targetHeldNotes`.
3. **Missing Arp Timer Resume**: If an arpeggiator timer had been interrupted or was waiting for retrigger, `syncTrackAudibility()` explicitly skipped `isArpNote` keys when unmuting, leaving the arpeggiator dormant.

## Architectural Changes & Implementation
1. **`src/midi.lua`**:
   - Implemented `silenceChannel(channel)`: Transmits CC 64 (Damper Release = 0), CC 120 (All Sound Off), and CC 123 (All Notes Off), and iterates over `activeNoteLedger` to issue explicit Note-Offs for every active voice registered on that channel.
   - Exported `silenceChannel` from `midi.lua`.

2. **`src/controls.lua`**:
   - Enhanced `syncTrackAudibility()`:
     - **On Inaudible (Mute or Inactive Solo)**: Immediately silences the channel via `midi.silenceChannel(ch)`, drops Channel Volume (CC 7) and Expression (CC 11) to 0, and transmits dedicated Logic Controller Assignment CCs: CC 108 (Track Mute = 127) and CC 109 (Track Solo = 127 if soloed, 0 otherwise). Silences active gate timers while preserving `trk.heldNotes` and `trk.targetHeldNotes`.
     - **On Audible (Unmute or Active Solo)**: Emits CC 108 = 0 (Mute OFF), restores Channel Volume (CC 7) to `math.floor(trk.volume * 1.27)` and Expression (CC 11) to 127. Resumes physically held notes, re-registers held arpeggiator notes, and restarts `startTrackArp(trk, true)` if notes are held.
   - Added `countTableKeys(t)` utility locally to `src/controls.lua`.
   - Updated `handleKeyDown`: Extracted `arpeggiator.arpAddNote` from `isTrackAudible(trkIdx)` so arp patterns and latched chords are tracked continuously even when muted.
   - Guarded `volDown`, `volUp`, `topVolDown`, `topVolUp`, `botVolDown`, `botVolUp`: Only transmit CC 7 if `isTrackAudible(trk.id)` to avoid breaking active mutes.
   - Exported `syncTrackAudibility` and `isTrackAudible`.

3. **`src/arpeggiator.lua`**:
   - Updated `silenceTrack(trkId)`: Added channel parameter resolution and hooked `midi.silenceChannel(ch)`.

4. **`src/init.lua`**:
   - Hooked `controls.syncTrackAudibility()` into startup initialization following `midi.panicAllChannels()` to calibrate Logic faders and mute CCs on launch.

5. **`tests/track_mute_solo_daw_integration.test.js`**:
   - Added unit test suite verifying `midi.silenceChannel`, `syncTrackAudibility` CC 7/11/120/123/108/109 transmission, arp persistence across mute/unmute, and note registration while muted.

## Verification
- Ran `bun test`: All 57 tests passed across 14 test suites.
- Ran `python3 bin/hs-bundler --target qwerty-midi`: Successfully bundled 16 Lua modules into `qwerty_midi.lua`.
- Validated Lua bundle with `luac -p qwerty_midi.lua`: 0 syntax errors.
- Reloaded Hammerspoon via `hs.reload()`. Verified live state `midiActive: true, domReady: true`.
- Executed live Hammerspoon integration test verifying `before(timer=true, held=1) -> muted(muted=true, timer=true, held=1) -> unmuted(muted=false, timer=true, held=1)` and `whileMutedHeld=1, afterUnmuteHeld=1, timerRunning=true`.
