# Single-Channel nanoKEY Studio CC-Mapped Pad Support

**Date:** 2026-09-15 20:55  
**Author:** Antigravity  
**Status:** Completed & Live Verified  

## Problem & Context
The user raised an architectural point regarding MIDI channel economy:
- Dedicating a second MIDI channel (e.g. Channel 2 or Channel 10) solely for the 8 trigger pads on a small controller wastes a full channel that could otherwise be routed to distinct synth tracks, instruments, or DAW channels.
- In MIDI 1.0, a single channel possesses 128 Note numbers AND 128 Control Change (CC) numbers. Note On/Off (`0x90` / `0x80`) and Control Change (`0xB0`) utilize completely distinct MIDI status bytes.
- By configuring pads in KORG KONTROL Editor as Control Changes (e.g., CC 80..87) instead of Notes, keys and pads can operate on **Channel 1 (Global)** simultaneously with zero cross-triggering or voice-stealing collisions.

## Key Changes
1. **Added `ccToPadIndex(cc)` in `packages/nanokey-studio/nanokey.lua`:**
   - Supports the following CC blocks automatically:
     - `CC 80..87`: General Purpose Controllers 5–8 and Undefined CCs (Standard Recommended Block).
     - `CC 102..109`: Undefined MIDI CC range.
     - `CC 112..119`: Undefined MIDI CC range.
     - `CC 36..43`: Matching GM drum note numbers as CCs.
2. **Integrated CC Pad Handling in `handleMidiEvent`:**
   - Listens for `commandType == "controlChange"` where `cc` resolves via `ccToPadIndex`.
   - Maps `val > 0` to pad down and `val == 0` to pad up (momentary).
   - Passes pad state to `hudRef.updateNanoKeyControl` (`pad_1` .. `pad_8`) and executes macro layers (Sustain + Pad for transport/window management, Scene + Pad for presets/launchers).
   - Preserves dedicated channel note handling (`noteToPadIndex`) for Channel 2 / Channel 10 setups for backwards compatibility.
3. **Bundled & Reloaded:**
   - Bundled via `python3 bin/hs-bundler --target qwerty-midi` and reloaded via AppleScript.
4. **Live Verification in Hammerspoon:**
   - Executed Lua test injections for CC 80 press (`val=127`, returned `true`), CC 80 release (`val=0`, returned `true`).
   - Verified contiguous iteration across all 8 pads (`CC 80..87` and `CC 102..109`, both returning `true`).
   - Verified unassigned CCs (e.g. CC 70) return `false` (ignored).
   - Verified keyboard Note 48 on Channel 1 returns `false` from pad handling and routes cleanly to chiclet keys without triggering pads.

## Hardware Configuration Guide for User (KORG KONTROL Editor)
1. In KORG KONTROL Editor, select each Pad (Pad 1 through Pad 8).
2. Set **Assign Type** = `Control Change` (instead of `Note`).
3. Set **MIDI Channel** = `Global` (Channel 1).
4. Set **Control Change Number**:
   - Pad 1 = `80`
   - Pad 2 = `81`
   - Pad 3 = `82`
   - Pad 4 = `83`
   - Pad 5 = `84`
   - Pad 6 = `85`
   - Pad 7 = `86`
   - Pad 8 = `87`
5. Set **Pad Behavior** = `Momentary` (sends 127 on press, 0 on release).
6. Set **Off Value** = `0`, **On Value** = `127`.
7. Go to **Communication -> Write Scene Data** to flash the settings to the nanoKEY Studio.
