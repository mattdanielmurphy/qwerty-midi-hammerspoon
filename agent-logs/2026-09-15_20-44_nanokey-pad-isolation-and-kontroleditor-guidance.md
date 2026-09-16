# Session Log: nanoKEY Studio Pad Isolation & KORG KONTROL Editor Channel Realignment

**Date:** 2026-09-15 20:44  
**Author:** Antigravity  
**Target:** `packages/nanokey-studio/nanokey.lua`, `AG_CONTEXT.md`, `DEVELOPMENT_JOURNAL.md`

## Problem Statement
- **Keyboard notes illuminating pads & vice versa:** Whenever keys were pressed on the keyboard, pads in the GUI illuminated, and vice versa.
- **Root Cause Identified from KORG KONTROL Editor:**
  1. The nanoKEY Studio factory Scene 1 sets the 8 trigger pads' `MIDI Channel` to `Global` (which is Channel 1).
  2. The physical keyboard keys also transmit on Channel 1 (`ch = 0`).
  3. The pads were assigned to white-key pitches (C2, D2, F#2, A#2, G2, C3, D3, C#3), directly overlapping keyboard notes.
  4. In `nanokey.lua`, Section 6 (`Chord Pad Burst Detection on Channel 1`) was monitoring Channel 1 notes and lighting up pads whenever multiple keys were played.
  5. Because both the keyboard and the pads were on Channel 1 with overlapping note numbers, incoming MIDI messages were bit-for-bit indistinguishable between keys and pads.

## Solution & Architectural Separation
1. **Software-Side Isolation (`packages/nanokey-studio/nanokey.lua`):**
   - Completely stripped out Section 6 (`Chord Pad Burst Detection on Channel 1`), ensuring keyboard notes on Channel 1 (`ch = 0`) never trigger pad highlights.
   - Restricted Section 6/7 keyboard key handling strictly to `ch == 0`:
     `if ch == 0 and note and note >= 24 and note <= 108 then`
   - Updated `noteToPadIndex(note, ch)`:
     - Explicitly ignores `ch == 0` (`if ch == 0 then return nil end`).
     - Listens exclusively on dedicated pad channels: **Channel 10 (`ch = 9`, GM Drum Standard)** or **Channel 2 (`ch = 1`)**.
     - Added full support for Korg Kontrol Editor's default GM drum note mapping:
       `[36] = 1, [38] = 2, [42] = 3, [46] = 4, [43] = 5, [48] = 6, [50] = 7, [49] = 8`
       as well as sequential drum notes (`36..43`) and Korg factory scene notes (`64..71`).
2. **Hardware Configuration Guidance for Matt in KORG KONTROL Editor:**
   - Change the `MIDI Channel` of the 8 pads from `Global` to **10** (the universal GM Drum Channel) or **2**.
   - Write the scene to the nanoKEY Studio hardware via `Communication -> Write Scene Data`.
   - Once saved to the hardware, keys (Ch 1) and pads (Ch 10 or 2) will be permanently, cleanly isolated MIDI streams. In Logic Pro or any DAW, keyboard tracks and drum/pad tracks can be played simultaneously without interference.
