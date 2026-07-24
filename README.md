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
