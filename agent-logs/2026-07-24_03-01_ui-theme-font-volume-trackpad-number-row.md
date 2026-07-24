## Goal
- Eliminate key text jitter / vibration when keys are played.
- Redesign root, 3rd, and 5th note highlights to be subtle and muted (remove harsh blue/cyan/purple bright colors).
- Support Trackpad Volume scrolling when Shift is held, and Mod Wheel scrolling when Shift is not held.
- Reduce Vol and Mod shift button increments from 16 to 4 for smooth adjustments.
- Add a dedicated Number Row (`1-0, -, =`) to expose secondary controls, plus Transpose (-/+ semitones) capabilities.
- Redesign HUD theme to be dark charcoal neutral (less blue) and adopt the 'Fraunces' serif font.

## User Feedback & Decisions
- User requested warm dark non-blue aesthetic with Fraunces font.
- User wanted trackpad scroll to do Volume when Shift is held.
- User requested smaller step increments for volume & mod shifts.
- User requested a dedicated number row with Transpose +/- function.

## Changes Made
- `qwerty_midi.lua`:
  - Added `@import`/Google Fonts `<link>` for Fraunces font and applied `font-family: 'Fraunces', serif, system-ui`.
  - Replaced cold blue/cyan CSS variables and borders with warm dark charcoal (`rgba(24, 22, 20, 0.96)`) and bronze accents (`#d4a359`).
  - Removed `transform: translateY(2px)` on pressed key pads and implemented inset box-shadow pressed states to eliminate text jitter.
  - Redesigned interval styles (`root-key`, `third-key`, `fifth-key`) to use soft muted tones (`#d4a359`, `#c9bfb3`, `#b8aca0`) and clean `(R)`, `(3rd)`, `(5th)` note labels.
  - Added `transposeShift` state and updated `getTransposedPitch` to apply semitone transposition.
  - Updated `activeWatchers.midiScrollTap` to check `shiftHeld` for Volume CC 7 scroll vs Mod Wheel CC 1 scroll.
  - Reduced `volDown`, `volUp`, `modWheelDown`, `modWheelUp` button step increments to 4.
  - Created `numberRowControls` (`1-0, -, =`) mapped to Top Row Octave, Transpose -/+, Octave -/+, Scale -/+, Panic, Reset, and Zoom -/+.
  - Expanded HUD grid to 4 rows (`number`, `upper`, `home`, `lower`) with frame height 285px.

## What Worked
- Fraunces font loads smoothly via webview head link.
- Key press rendering is completely immobile with zero layout shift or jitter.
- Trackpad scrolling seamlessly toggles between Mod Wheel and Volume when Shift is held.
- Number row cleanly triggers secondary functions and semitone transpose.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- `activeWatchers.midiScrollTap` handles both Mod Wheel (CC 1) and Master Volume (CC 7) using independent accumulators (`modAccumulator`, `volAccumulator`) to preserve sub-integer scroll precision.
