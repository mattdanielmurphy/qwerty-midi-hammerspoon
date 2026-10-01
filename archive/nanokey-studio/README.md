# Korg nanoKEY Studio Archive

This directory archives the Korg nanoKEY Studio implementation, hardware tools, and binaries following the transition to the Arturia KeyStep 32 controller.

## Contents

- `packages/nanokey-studio/`:
  - `init.lua`: Public module facade for nanoKEY Studio.
  - `nanokey.lua`: Full hardware driver (Chiclet keys, Pads, Knobs, Touchpad, CC #25 Sustain, Native SysEx Scene holding, dynamic Scale Guide LED sync).
  - `macros.lua`: Hold-to-reveal macro layer mapping.
  - `probe.lua`: SysEx and BLE packet probing.
  - `layouts/nanokey_studio.json`: Hardware visualizer and layout definition.
- `bin/`:
  - `nanokey-button-sniffer`: Compiled Swift CLI tool for sniffing hardware GPIO buttons.
  - `sniff`: Shell wrapper script for `nanokey-button-sniffer`.
  - `test-nanokey-leds`: Compiled Swift CLI tool for testing and cycling hardware LED backlight states over MIDI.
- `tools/`:
  - `nanokey-sniffer/main.swift`: Swift source for the Bluetooth/CoreMIDI button packet sniffer.
  - `nanokey-led-tester/main.swift`: Swift source for testing key LEDs.

## Bundling the Archive

The standalone nanoKEY Studio bundle can still be generated via:

```sh
python3 bin/hs-bundler --target nanokey-studio
```
Output: `dist/nanokey_studio.lua`.
