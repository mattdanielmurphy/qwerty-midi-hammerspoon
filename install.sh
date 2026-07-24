#!/bin/bash
# install.sh - Symlinks qwerty_midi.lua into ~/.hammerspoon/modules/
mkdir -p ~/.hammerspoon/modules
ln -sf "$(pwd)/qwerty_midi.lua" ~/.hammerspoon/modules/qwerty_midi.lua
echo "✅ Symlinked qwerty_midi.lua -> ~/.hammerspoon/modules/qwerty_midi.lua"
