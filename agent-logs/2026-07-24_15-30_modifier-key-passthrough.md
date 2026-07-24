## Goal
Ensure key combinations involving modifier keys (`Cmd`, `Option`/`Alt`, `Control`) pass through to macOS/system applications without triggering MIDI notes or key-swallowing in QWERTY MIDI mode.

## User Feedback & Decisions
- User requested that holding `Option` or `Cmd` should pass through to the system (allowing system shortcuts like screenshots or app shortcuts) instead of triggering MIDI notes.

## Changes Made
- Inspected [init.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/init.lua#L110-L112) and verified existing modifier key bypass handler (`if flags.cmd or flags.alt or flags.ctrl then return false end`).
- Created task tracker file `.devtool/features/modifier-key-passthrough.md` to document the requirement and state (`status: review`).

## What Worked
- Verified that `midiKeyTap` eventtap in [init.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/init.lua#L110-L112) returns `false` whenever `cmd`, `alt`/`option`, or `ctrl` modifiers are down. Returning `false` in a Hammerspoon eventtap allows macOS to process the event natively (passing through commands like screenshot hotkeys `Cmd+Shift+3` / `Cmd+Shift+4` / `Cmd+Shift+5` or `Opt` key shortcuts).

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- In Hammerspoon's `hs.eventtap`, returning `true` swallows/consumes the key event, while returning `false` passes the key event downstream to the OS or focused application.
