# Fix Arp Rate Controls and Expand Arp Directions

## Goal
Fix arp rate controls changing the gate instead of tempo division, and expand arpeggiator direction patterns with UP, DOWN, UP-DOWN, DOWN-UP, CONVERGE, DIVERGE, and RANDOM options.

## User Feedback & Decisions
- User reported arp rate controls were changing gate duration instead of arp rate.
- User requested additional arp direction patterns.

## Changes Made
- `src/arpeggiator.lua`:
  - Updated `applyBpmChange()` to properly reset and restart `arpTimer` using `getArpIntervalSeconds()`, fixing rate changes while arp is actively running.
  - Expanded `arpTick()` to support 7 arp directions: UP, DOWN, UP-DOWN, DOWN-UP, CONVERGE, DIVERGE, RANDOM.
- `src/config.lua`:
  - Updated `state.ARP_DIRECTIONS` array and comments to include the new directions.
- `src/ui_html.lua`:
  - Updated `<select id="arp-dir-select">` HTML options to `UP`, `DOWN`, `UP-DN`, `DN-UP`, `CONV`, `DIV`, `RND`.
- Re-bundled `qwerty_midi.lua` via `bundle_and_reload.sh`.

## What Worked
- Arp rate controls now instantly change the time division rate of the running arpeggiator timer.
- Added 3 new direction patterns: `DOWN-UP`, `CONVERGE`, and `DIVERGE`.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- `applyBpmChange()` is shared by BPM edits, BPM dragging/buttons, and Arp Rate adjustments. Stopping and restarting `hs.timer.doEvery` with `startArpTimer(true)` ensures rate changes apply immediately while preserving pattern state.
