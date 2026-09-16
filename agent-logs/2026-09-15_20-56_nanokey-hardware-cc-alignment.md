# nanoKEY Studio Exact Hardware CC Alignment (Pads, Knobs, Sustain, Touchpad)

**Date:** 2026-09-15 20:56  
**Author:** Antigravity  
**Status:** Completed & Live Verified  

## Overview
The user provided ground-truth controller telemetry screenshot from their pre-assigned hardware scene:
- **Knobs 1..8**: CC 20, 21, 22, 23, 24, 25, 26, 27
- **Sustain Button**: CC 64 (standard MIDI Damper Pedal)
- **KAOSS Touchpad**: Touch X = CC 1 (Modulation), Touch Y = CC 19
- **Pads 1..8**:
  - Top Row (Pads 1..4): Arp Type (CC 43), Arp Range (CC 48), Key Sync (CC 50), Wireless (CC 49)
  - Bottom Row (Pads 5..8): Gate Type - (CC 36), Gate Type + (CC 38), Scale - (CC 42), Scale + (CC 46)

## Changes Implemented

### 1. Hardware Driver (`packages/nanokey-studio/nanokey.lua`)
- **Pads (`KORG_KONTROL_PAD_MAP` & `ccToPadIndex`)**:
  - Direct 1:1 hardware mapping:
    - `[43] = 1` (Arp Type)
    - `[48] = 2` (Arp Range)
    - `[50] = 3` (Key Sync)
    - `[49] = 4` (Wireless)
    - `[36] = 5` (Gate Type -)
    - `[38] = 6` (Gate Type +)
    - `[42] = 7` (Scale -)
    - `[46] = 8` (Scale +)
  - Works on Channel 1 (Global) or any channel. Distinct from Note On/Off commands so keys and pads never collide.
- **Knobs (`resolveKnobIndex` & `activeKnobOffset`)**:
  - Locked to CC 20..27 as primary hardware mapping (`offset = 19`).
  - Knob 1 (Cutoff) = CC 20, Knob 2 (Peak) = CC 21, Knob 3 (Drive) = CC 22, Knob 4 (Volume) = CC 23,
    Knob 5 (Attack) = CC 24, Knob 6 (Decay) = CC 25, Knob 7 (Sustain) = CC 26, Knob 8 (Release) = CC 27.
  - Exempted CC 19 from knob checks to prevent Touchpad Y from being captured as a knob.
- **Sustain Button (`handleMidiEvent`)**:
  - Re-routed primary Sustain check to **CC 64**, completely eliminating the legacy conflict where turning Knob 6 (CC 25) to 0 or 127 could trigger Sustain.
- **KAOSS Touchpad (`handleMidiEvent`)**:
  - Added **CC 19** as Touch Y alongside CC 1 (Touch X).
  - Evaluated before knobs to ensure priority dispatch.

### 2. GUI Webview (`src/web/index.html`)
- Updated initial HTML knob CC badges from CC 17..24 to `CC 20`, `CC 21`, `CC 22`, `CC 23`, `CC 24`, `CC 25`, `CC 26`, `CC 27`.
- Added `data-cc` and `title` attributes on all 8 pad DOM elements (`nk-pad-1`..`8`).
- Added `controlId === 'cc_19'` to the touchpad Y cursor position updater in `updateNanoKeyState`.

### 3. Bundler & Reload
- Bundled into `qwerty_midi.lua` via `python3 bin/hs-bundler --target qwerty-midi`.
- Reloaded Hammerspoon.

## Live Verification Results
1. **Pads (CC 43, 48, 50, 49, 36, 38, 42, 46)**:
   - Injected all 8 CCs: `43->pad_1, 48->pad_2, 50->pad_3, 49->pad_4, 36->pad_5, 38->pad_6, 42->pad_7, 46->pad_8`. All passed.
2. **Knobs (CC 20..27)**:
   - Injected all 8 CCs: `20->knob_1, 21->knob_2, 22->knob_3, 23->knob_4, 24->knob_5, 25->knob_6, 26->knob_7, 27->knob_8`. All passed.
   - Verified Knob 6 (CC 25, val 127) captures as `knob_6` and does NOT toggle `btn_sustain`.
3. **Sustain Button (CC 64)**:
   - Injected CC 64 (val 127): captures as `btn_sustain`. Passed.
4. **Touchpad (CC 1, CC 19)**:
   - Injected CC 1 (val 64) and CC 19 (val 64): captures as `cc_1, cc_19`. Passed.
