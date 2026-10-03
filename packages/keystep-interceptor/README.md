# Arturia KeyStep Interceptor

This standalone Hammerspoon module infers KeyStep controls that are not sent as
ordinary MIDI CCs while its sequencer is playing:

- Marker notes C8 through G8 (108–115) at velocity 1 map to mode positions
  1–8 and emit CC 102.
- MIDI timing clock is averaged over 24 pulses and converted to BPM, emitting
  one dedicated CC 107 value over the full seven-bit range. This is intended
  for Logic Controller Assignments Learn and does not directly alter CC 7
  channel volume or Arturia's CC 17 Macro 2.
- The gap between sequence notes is compared with the measured quarter-note
  duration and quantized to straight or triplet divisions, emitting CC 103.

The C8–G8/velocity-1 marker rule makes sequence events distinct from played
notes even when both share a MIDI channel. Marker notes and their note-offs are
swallowed; every other played note is forwarded to the already-configured
QWERTY MIDI output that Logic should listen to. Device discovery accepts
`KeyStep` and Arturia KeyStep product-name suffixes, including `Arturia KeyStep 32`.

## Hammerspoon usage

Bundle it with:

```sh
python3 bin/hs-bundler --target keystep-interceptor
```

Then load `dist/keystep_interceptor.lua` from `init.lua` and start it:

```lua
local keyStep = dofile(hs.configdir .. "/modules/keystep_interceptor.lua")
keyStep.start({ outputChannel = 0 })
```

`start()` opens the **KeyStep Monitor** window by default. It shows matching
device status, the last MIDI event, sequence channel, decoded mode/division,
and BPM. Use `keyStep.toggleMonitor()` to hide or restore it. To run headless,
pass `showMonitor = false` to `start()`.

Disable the physical `Arturia KeyStep 32` input in Logic, and leave the QWERTY
MIDI output enabled. `stop()` removes the input callback and clears all timing
state; transport stop and stale timing gaps are also safe.
