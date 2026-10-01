# Arturia KeyStep Side-Channel Interceptor

## Delivered

- Added `packages/keystep-interceptor/keystep.lua` as an isolated Hammerspoon
  driver and `init.lua` as its public facade.
- The driver connects only to exact `KeyStep` or `Arturia KeyStep` device names,
  creates the `KeyStep Interceptor` virtual source, and emits CC 102 (mode),
  CC 103 (division), and CC 104 (rounded BPM, seven-bit constrained).
- It maps sequence notes 48–55 to positions 1–8, averages the latest 24 MIDI
  timing-clock gaps at 24 PPQN, and selects the closest straight/triplet
  division from note-to-note timing.
- Transport stop, start/continue, stale clock gaps, and stale note gaps reset
  timing references so playback can pause and resume without nil arithmetic.

## Verification

- `luac -p packages/keystep-interceptor/keystep.lua packages/keystep-interceptor/init.lua`
- `bun test tests/keystep_interceptor.test.js` — 4 passing tests
- `python3 bin/hs-bundler --target keystep-interceptor`
- `luac -p dist/keystep_interceptor.lua`

## Integration decision

The driver remains a standalone bundle target rather than being auto-loaded by
the existing QWERTY/nanoKEY application. This prevents a second physical MIDI
callback from altering currently active controller behavior and lets the user
enable the KeyStep explicitly from their Hammerspoon configuration.
