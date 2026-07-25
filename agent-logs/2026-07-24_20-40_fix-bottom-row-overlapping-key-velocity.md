## Goal
Fix an issue where pressing a note on the bottom row (which maps to a pitch that is also present on the top row) inherits top row velocity/volume (and split arp top row boost) instead of bottom row velocity.

## User Feedback & Decisions
- The user observed that notes played from the bottom row that share pitch mappings on the top row were being triggered at higher velocity (treating them as top row notes).
- When a key physically located on the bottom row is pressed, it must strictly evaluate to bottom row velocity.

## Changes Made
- Updated key row classification in `src/controls.lua` (`handleKeyDown` and `handleKeyUp`) and `src/arpeggiator.lua` (`arpTick` and note pitch lookup) to use `isTop = lowerRowKeys[code] == nil and upperRowKeys[code] ~= nil`.
- Re-bundled modules into `qwerty_midi.lua` and reloaded Hammerspoon.

## What Worked
- Keys belonging to `lowerRowKeys` (such as `,`, `.`, `/`, `'`) now evaluate to `isTop = false` even if their note pitch overlap exists on `upperRowKeys`.
- Bottom row note presses accurately use `bottomRowVolume` without receiving top row velocity overrides or split-arp top boost.

## Architecture Notes
- `upperRowKeys[code]` checks previously took precedence whenever `upperRowKeys[code] ~= nil` was evaluated. Ensuring `lowerRowKeys[code] == nil` before classifying as `isTop` guarantees strict row-based physical key resolution.
