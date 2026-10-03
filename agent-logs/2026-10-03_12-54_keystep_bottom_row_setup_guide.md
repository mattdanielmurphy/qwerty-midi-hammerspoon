# KeyStep Bottom-Row Routing and Connection Setup Guide

## Changes

- Routed KeyStep playable white-note on/off events through the shared QWERTY note lifecycle. KeyStep notes now follow the selected bottom-row track and its channel, arp, volume velocity, mute/solo, chord/sustain, and quantization behavior.
- Released any shared-lifecycle held notes when the hardware disconnects, avoiding hanging notes after cable/power loss.
- Cleared KeyStep's held-pitch and key-highlight maps on disconnect so stale notes cannot leak into chord detection after reconnect.
- Preserved KeyStep black-key modal controls, sequence markers, transport, CC, pitch bend, and mod-strip handling.
- Added a small accessible KeyStep setup card. A fresh connection shows transport setup; an observed hardware MIDI Start/Continue advances to Kbd Play setup; an eligible white note acknowledges that step. Stop restores step one, and disconnect resets the session.
- Limited KeyStep rate/volume synchronization to bottom-row volume.

## Verification

- `bun test`: 39 passed, 0 failed.
- `luac -p` passed for the changed Lua modules and generated `qwerty_midi.lua` bundle.
- `bash bin/bundle_and_reload.sh` rebuilt the bundle, synced `src/ui_html.lua`, and requested a Hammerspoon reload.
- `git diff --check` passed.

## Device Default Configuration

The saved KeyStep manual and Arturia's current Shift-functions FAQ document entering Kbd Play with Shift + Oct+, and the manual documents a separate Kbd Play MIDI channel. The manual discusses a MIDI Control Center setting for Transpose latch behavior, but neither source documents a configurable power-on default for Kbd Play. This does not prove the firmware cannot retain or configure such a default; its availability remains unverified.
