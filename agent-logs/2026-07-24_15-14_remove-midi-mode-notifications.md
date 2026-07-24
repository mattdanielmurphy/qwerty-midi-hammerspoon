## Goal
Remove redundant `hs.alert.show` notifications when toggling MIDI Mode ON/OFF since the floating webview HUD visibility already clearly indicates state.

## User Feedback & Decisions
- The user requested removing the `MIDI mode: ON/OFF` notifications as unnecessary since the floating UI appearance/disappearance provides immediate feedback.

## Changes Made
- `src/init.lua`: Removed `hs.alert.show("🎹 MIDI Mode: " .. (state.midiActive and "ON" or "OFF"))` from `toggleMidiMode`.
- Re-bundled module into `qwerty_midi.lua` via `bin/bundle_and_reload.sh`.
- `FEATURES.md`: Documented clean HUD toggle feedback without OS-level alerts.
- `.devtool/features/remove-midi-mode-notifications.md`: Created and set to `status: "review"`.

## What Worked
- Removed the `hs.alert.show` line in `src/init.lua`.
- Bundled into `qwerty_midi.lua` cleanly.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- `toggleMidiMode` handles both HUD webview showing/hiding and eventtap listener registration without needing native Hammerspoon alert popups.
