# Restore Mac QWERTY Input

## Incident

Mac keyboard functions and musical keys appeared completely unresponsive in QWERTY MIDI mode.

## Live evidence

- The loaded module was the project bundle via `~/.hammerspoon/modules/qwerty_midi.lua`.
- `luac -p` passed, Hammerspoon was running, and the KeyStep HUD was live.
- The Hammerspoon Console showed a repeated keydown failure at bundled `harmony.getTransposedPitch()`: `attempt to perform arithmetic on a nil value (local 'basePitch')`.
- Secure Input was disabled.
- After reload, MIDI mode initially restored disabled; enabling it yielded `midiActive=true`, `keyTapPresent=true`, `keyTapEnabled=true`, and `textInputActive=false`.

## Cause and repair

The KeyStep routing work extended `controls.handleKeyDown(code, externalNoteKey)`. The Mac event tap in `src/init.lua` still called it as `handleKeyDown(code, flags)`. That modifier table was therefore treated as an external note key, whose absent `baseNote` caused the transposer failure for every Mac keydown.

The event tap now calls `controls.handleKeyDown(code)` for Mac keyboard events. KeyStep callbacks remain the only callers that pass an external note object. `tests/keyboard_input.test.js` prevents the modifier table from being reintroduced as that argument.

## Verification

- `bun test`: 41 passing, 0 failing.
- Generated `qwerty_midi.lua` passed `luac -p`.
- Reloaded the verified bundle and enabled MIDI mode.
- The live Console remained free of the prior `basePitch` exception after reload.
