# Session Log: Fix Quantization Mode Duplicate Note Bug

**Date:** 2026-09-15 22:58  
**Author:** Antigravity  
**Target:** `packages/nanokey-studio/nanokey.lua`, `qwerty_midi.lua`

## Problem & Root Cause
- **Symptom:** In input quantization mode, pressing a key played the note immediately and then played a duplicate second note when the grid timer arrived.
- **Root Cause:**
  - Unlike QWERTY keystrokes (which are intercepted by `hs.eventtap` with `return true` to prevent macOS input and synthesized exclusively into MIDI), hardware MIDI controllers like the **Korg nanoKEY Studio** transmit physical `Note On` and `Note Off` messages directly to macOS CoreMIDI / DAW (Logic Pro) at the OS driver level.
  - In `packages/nanokey-studio/nanokey.lua`, the chiclet key callback was returning `true` assuming it would intercept the hardware event from reaching the DAW, while simultaneously calling `quantizer.queueNoteOn(...)`.
  - When the grid timer fired, `quantizer` executed `midi.sendMidiNote("noteOn", pitches[1], v, c)`, sending a second note-on event to the DAW virtual bus. Because Logic Pro listens to both direct hardware and virtual MIDI by default, the musician heard:
    1. The immediate raw hardware note-on.
    2. The delayed quantized note-on from Hammerspoon.

## Fix
- In `packages/nanokey-studio/nanokey.lua`:
  - Removed `midi.sendMidiNote` from the nanoKEY physical chiclet keys callback (`nk_key_`).
  - Allowed hardware keys to pass through natively (`return false`) to CoreMIDI / DAW without injecting duplicate notes.
  - Preserved QWERTY input quantization in `src/controls.lua`, where `hs.eventtap` genuinely suppresses the keystroke before emitting the quantized MIDI note.
- Rebuilt bundle with `bash bin/bundle_and_reload.sh`.
