## Goal
Fix physical keycode mappings for number row BPM controls (`-` decrement, `=` increment) so keypresses swallow properly and perform the correct increment/decrement actions on arpeggiator speed.

## User Feedback & Decisions
- `=` key was not being captured (passthrough to system).
- `-` key incremented instead of decrementing.

## Changes Made
- `src/config.lua`: Fixed `numberRowControls` keycode definitions:
  - Keycode `27` (`-` key) mapped to `action = "bpmDown"`.
  - Keycode `24` (`=` key) mapped to `action = "bpmUp"`.
- `src/ui_html.lua`: Updated `LAYOUT_DATA.number` table to reflect keycode `27` (`-`, `BPM -`) and keycode `24` (`=`, `BPM +`).
- Bundled modules via `bin/bundle_and_reload.sh`.

## What Worked
- Pressing `-` now decrements controller BPM.
- Pressing `=` (keycode 24) is now swallowed and increments controller BPM.

## What Didn't Work / Known Issues
- macOS UI Accessibility does not support writing back to Logic Pro's Tempo text slider; BPM sync operates in read-only mode from Logic Pro -> Controller.
