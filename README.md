# QWERTY MIDI Controller (Hammerspoon Module)

A modular, key-swallowing QWERTY keyboard MIDI controller and graphical canvas dashboard built with Hammerspoon.

## Features
- **Zero Drivers**: Communicates natively via macOS CoreMIDI destination endpoints (IAC Driver).
- **Mode Toggle**: Activated/deactivated globally with `Cmd + Option + M`.
- **Key Swallowing**: Blocks intercepted keys from typing text or triggering app shortcuts while active.
- **Graphical Canvas HUD**: Floating vector UI dashboard highlighting pressed pitch notes and control change parameters.

## Directory & Setup Structure
- Dedicated project repository: `~/projects/qwerty-midi-hammerspoon`
- Symlinked target: `~/.hammerspoon/modules/qwerty_midi.lua`
- Entry point require in `~/.hammerspoon/init.lua`: `require("modules.qwerty_midi")`

## Installation
```bash
./install.sh
```


## TO DO

this has changed a lot recently, which is good and bad. lots of shit is broken, lots to do
fix:
- no way to control top arp vs bottom arp
- when you press any key, the track keys invert in an odd way (if tracks 1 and 3 are selected, pressing a note on the bottom row, which is track 1, causes track 2 to become lit up and tracks 1 and 3 dim, and track 2 shows a waveform even though there's no audio)
- we need per track everything including volume, etc

## once stable
- we need better arp gate patterns (bring in korg's defaults) and more scales
- maybe dedicated oct + AND - keys
- some way to put the tracks up OR down
- especially with just 4 tracks, we don't need 4 keys to switch, especially with the constraint we currently have where a row can only hold 2 tracks