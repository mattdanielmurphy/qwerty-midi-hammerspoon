# KeyStep Rate Knob Isolated for Logic Controller Learn

## Problem

The Rate control was emitting three CCs for each inferred rate update: CC 17,
CC 7, and CC 104. Logic's Learn mode stays active until explicitly turned off,
so its incoming-message field kept changing during a single Rate knob turn.
CC 17 also directly controls Arturia Macro 2 on some plugins.

## Change

- The Rate knob now emits only CC 107, using the full 0..127 range.
- Removed the direct CC 7, CC 17, and CC 104 emissions from Rate updates.
- Kept internal QWERTY row-volume synchronization and its unity-gain cap intact.
- Updated the KeyStep knob tooltip, package README, and project context.

## Verification

- Rebuilt `qwerty_midi.lua` and reloaded Hammerspoon.
- Queried the live KeyStep watcher; it reports `rateCc: 107`.
- No test suite was run.
