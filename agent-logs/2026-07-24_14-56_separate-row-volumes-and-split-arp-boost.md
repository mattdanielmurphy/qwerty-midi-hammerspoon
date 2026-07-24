# Separate Row Volume Controls and Split Arp Volume Boost

## Goal
Implement separate volume controls for the top row (upper keys Q..P) and bottom row (lower keys Z../), and provide an automatic default volume boost (+20 velocity) for the top row when in split arp mode (where bottom row is arpeggiating and top row is playing standard non-arp notes).

## User Feedback & Decisions
- Split arp mode default behavior: top row should have a boost in volume relative to the arpeggiated bottom row.

## Changes Made
- Added `topRowVolume` and `bottomRowVolume` state variables (default 100).
- Added `splitArpTopBoost` offset (+20 velocity, capped at 127).
- Created `getEffectiveRowVelocity(isTopRow)` helper function to evaluate top vs bottom row velocity, automatically adding the +20 boost to top row notes when `arpEnabled` and `arpBottomEnabled` are true while `arpTopEnabled` is false.
- Updated `handleKeyDown` and `arpTick` noteOn velocity parameters to use `getEffectiveRowVelocity`.
- Updated control actions `volUp`, `volDown`, `topVolUp`, `topVolDown`, `botVolUp`, `botVolDown`, and `resetAll` to manage row volumes.
- Updated trackpad scroll when Shift is held to adjust both top and bottom row volumes simultaneously.
- Added `VOL` HUD badges next to top and bottom octave indicators in `qwerty_midi.lua`, displaying active volume levels and boost status (`🚀`).

## What Worked
- Split arp mode automatically boosts top row note velocity (+20).
- Row volumes can be inspected on the HUD and controlled separately or simultaneously.
- Hammerspoon config reloaded cleanly without errors.
