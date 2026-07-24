## Goal
Fix visual keyboard UI alignment so `Tab`, `A`, and `Z` sit in their authentic physical QWERTY row positions without shifting note keys down.

## User Feedback & Decisions
- `Tab` must not replace or push `Q`.
- The physical keyboard layout must be preserved starting from `Tab`, `A`, and `Z` with proper key widths.

## Changes Made
- [src/ui_html.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/ui_html.lua):
  - Added wider key styling (`width: 85px` for `Tab`, `width: 75px` for `Caps`) to replicate authentic keyboard offsets.
  - Placed `Tab` before `Q` in the upper row and added a visual `Caps` pad before `Z` in the lower row.
  - Reset artificial `.keyboard-row` margins to `0px` so row offsets are naturally driven by the key widths.

## What Worked
- Note keys `Q` through `P` are in their correct positions.
- `Tab` (`Sustain`) sits to the left of `Q`.
- `A` (`Latch`) sits under `Tab`.
- `Z` sits under `A` (preceded by `Caps`).

## What Didn't Work / Known Issues
- None.
