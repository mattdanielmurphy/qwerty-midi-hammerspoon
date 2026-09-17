# Work Log: Arpeggiator Latch Auto-Reset Fix & Smart Sustain Inactive Styling

- **Timestamp**: 2026-09-17 16:43
- **Task**: Fix Arp latch note accumulation bug and darken inactive Smart Sustain button
- **Files Modified**:
  - `src/arpeggiator.lua`: Restored `numPhysicalHeld` calculation in `arpAddNote` and `arpRemoveNote`, restored `trk.keysCurrentlyHeld[code] = nil` cleanup in `arpRemoveNote`, decoupled track-isolated latch checks from global `state.arpLatchActive` / `state.sustainActive`, and ensured `trk.targetHeldNotes` is synced during latch toggle.
  - `src/config.lua`: Updated `sustain` and `classicSustain` actions to default to base `typeClass = "ctrl-sus"` rather than active classes `latch-active` / `latch-mode-active`.
  - `src/hud.lua`: Updated `PROPOSED_LAYOUT_MAP[48]` static class to `"ctrl-sus"` and added dynamic overlay for Key 48 (Tab) so it dynamically acquires `.latch-active` (gold `#ffd700`) only when Smart Sustain is ON, `.latch-mode-active` (orange `#ff9100`) when Classic Sustain is ON, and `.ctrl-sus` when inactive.
  - `src/web/index.html`: Added inactive CSS styling for `#key-48:not(.latch-active):not(.latch-mode-active)`, `.key-pad.ctrl-sus`, and `.key-pad.ctrl-sustain` using dark chassis background `#141417`, subtle border `rgba(212, 163, 89, 0.22)`, and muted text `#8a7a58` with no glow.
  - `src/ui_html.lua` & `qwerty_midi.lua`: Re-bundled via `bin/bundle_and_reload.sh`.
  - `README.md`: Marked TO DO item as resolved.

## Root Cause Analysis
1. In a previous commit refactoring `isLatched`, `local numPhysicalHeld = countTableKeys(trk.keysCurrentlyHeld)` was accidentally deleted in `arpAddNote`, and both `trk.keysCurrentlyHeld[code] = nil` and `numPhysicalHeld` were accidentally deleted in `arpRemoveNote`.
2. As a result, `numPhysicalHeld` evaluated to `nil` (`nil == 0` is false) and `keysCurrentlyHeld` was never pruned on key release. Consequently, `trk.latchClearedForNewChord` remained `true` indefinitely and never reset to `false` when all fingers were taken off the keyboard.
3. Every subsequent note press was treated as an additional voice to an existing chord, causing latched arpeggios to grow indefinitely.
4. Furthermore, Key 48 (Tab: Sustain) was statically given `class = "latch-active"` in `PROPOSED_LAYOUT_MAP` and `config.lua`, which matched the `.latch-active` gold glow CSS regardless of whether sustain was active.

## Verification
- Wrote and executed automated tests in Hammerspoon (`hs -c`) confirming:
  - Releasing a latched note resets `latchClearedForNewChord` to `false` while preserving the latched loop in `targetHeldNotes`.
  - Pressing a subsequent note properly clears previous latched notes and starts a clean new single-note/chord loop.
  - Multi-note held chords continue to add voices while keys are held, and correctly lock upon release.
  - Key 48 dynamically updates `typeClass = "ctrl-sus"` with dark appearance when inactive, `.latch-active` when Smart Sustain is ON, and `.latch-mode-active` when Classic Sustain is ON.
- Bundled and reloaded Hammerspoon cleanly via `bin/bundle_and_reload.sh`.
