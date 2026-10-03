# KeyStep Rate CC Jitter Filter

## Problem

With the physical Rate knob stationary, host timestamp variation in MIDI clock
events still moved the estimated BPM and CC 107 value. A 2 ms debounce would be
shorter than a single KeyStep clock interval and would not filter this source.

## Change

- Estimate clock tempo from a median interval window spanning at least 200 ms
  (minimum seven pulse intervals), adapting the interval count to tempo.
- Add a two-value deadband to CC 107 so small estimate fluctuations do
  not reach Logic.
- Preserve the existing adaptive BPM slew and internal QWERTY volume sync.

## Verification

- Rebuilt the Hammerspoon bundle and reloaded the active configuration.
- Confirmed the live KeyStep watcher continues to report `rateCc: 107`.
- No test suite was run.
