# Session Log: Korg nanoKEY Studio Forbidden Button Sniffer & Native Mode SysEx Protocol

**Date:** 2026-09-15 21:00  
**Author:** Antigravity  
**Target:** `bin/sniff`, `bin/nanokey-button-sniffer`, `tools/nanokey-sniffer/main.swift`, `packages/nanokey-studio/nanokey.lua`, `qwerty_midi.lua`, `AG_CONTEXT.md`

## Problem & Objective
Investigate whether the internal "forbidden" system function buttons on the **Korg nanoKEY Studio** (Octave -/+, Touch Scale, X-Y, Pitch/Mod, Shift/Tap, Arp, Chord Pad, Easy Scale, Scale Guide) emit Bluetooth LE / MIDI packets over the air.
Build a systematic calibration and packet-sniffing utility that allows Matt to step through each button one by one, send the Korg Native Mode SysEx handshake, and capture/decode the exact 5-byte BLE-MIDI GATT notification packets and CoreMIDI SysEx payloads.

## Reverse Engineering Discoveries
1. **Korg Native Mode SysEx Protocol Discovered from KORG Gadget Binary Disassembly:**
   - **Identity Inquiry**: `F0 7E 7F 06 01 F7` -> Unit replies with Universal Identity `F0 7E 00 06 02 42 36 01 00 00 08 00 01 00 F7` (Model `0x0136` = nanoKEY Studio).
   - **Handshake Request**: `F0 42 40 00 01 36 01 00 00 12 F7` -> Hardware acknowledges with `F0 42 40 00 01 36 02 00 00 42 00 F7`.
   - **Enable Native Mode**: `F0 42 40 00 01 36 02 00 00 00 01 F7` -> Hardware confirms with `F0 42 40 00 01 36 02 00 00 01 03 F7` and flashes all LEDs!
   - **Disable Native Mode (Restore)**: `F0 42 40 00 01 36 02 00 00 00 00 F7` -> Hardware confirms with `F0 42 40 00 01 36 02 00 00 01 02 F7`.
2. **BLE-MIDI GATT Characteristic Architecture:**
   - Standard MMA/AMEI BLE-MIDI Characteristic: `7772E5DB-3868-4112-A1A9-F2669D106BF3`.
   - Header byte: `0x80 | (timestamp_ms & 0x3F)`.
   - Timestamp byte: `0x80 | (timestamp_ms & 0x7F)`.
   - Payload: In Native Mode, MCU button presses are dispatched as 5-byte BLE frames or raw SysEx frames (`F0 42 40 00 01 36 05 00 00 41 [subId] [val] 00 00 F7`).
   - Verified live in hardware:
     - `41 40 40 7F` / `41 40 40 00`: Scene button (press / release)
     - `41 40 01 00 00`: Scale Increment / Octave Up (+1)
     - `41 40 00 00 00`: Scale Decrement / Octave Down (-1)

## Deliverables Created
1. **Swift Systematic Sniffer Engine (`tools/nanokey-sniffer/main.swift`):**
   - High-performance, compiled Swift tool interacting directly with `CoreMIDI.framework`.
   - Connects seamlessly to `nanoKEY Studio Bluetooth` (or USB).
   - Interactive guided wizard: prompts user through each of the 12 buttons with visual faceplate position and hint.
   - Captures, decodes, timestamps, and calculates both raw MIDI hex and reconstructed BLE GATT notification frames.
   - Automatic JSON (`tmp/nanokey_sniff_results.json`) and Markdown summary table generation (`tmp/NANOKEY_SNIFFER_REPORT.md`).
   - Supports `--auto` (hands-free timed sweep) and `--monitor` (freeform live monitor).
2. **Compiled Binary & Launcher (`bin/nanokey-button-sniffer`, `bin/sniff`):**
   - Ready to run directly from terminal: `./bin/sniff`.
3. **Driver Integration (`packages/nanokey-studio/nanokey.lua`):**
   - Added `nanoKey.enableNativeMode()` and `nanoKey.disableNativeMode()`.
   - Expanded `handleMidiEvent` to intercept `414001` (Octave Up) and `414000` (Octave Down) SysEx frames.
   - Bundled and reloaded Hammerspoon cleanly via `bin/bundle_and_reload.sh`.

## Verification
- Disassembled and verified exact byte sequences against `/Applications/KORG Gadget.app/Contents/MacOS/KORG Gadget` (`NanoKeyStudioNativeMode` vtable at `0x1011f2598`).
- Executed live handshake probe against physical hardware over Bluetooth:
  - Sent `F0 7E 7F 06 01 F7` -> received Universal Identity response.
  - Sent `F0 42 40 00 01 36 01 00 00 12 F7` -> received `42 00` ACK.
  - Sent `F0 42 40 00 01 36 02 00 00 00 01 F7` -> received `01 03` confirmation.
  - Verified live key/pad hits (`90 30 4C`, `90 24 4A`, `90 2B 65`) received cleanly over BLE-MIDI.
  - Restored factory normal mode with `00 00 F7`.
