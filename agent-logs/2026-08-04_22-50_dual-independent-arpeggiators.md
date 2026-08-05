# Dual Independent Arpeggiators (Top/Bottom Row)

## Summary
Refactored the single arpeggiator engine into a dual-engine system supporting independent top-row and bottom-row arp patterns. Added an "Arp Link" toggle (Shift+7) to switch between linked (unified, original behavior) and split (independent patterns) modes.

## Changes

### src/arpeggiator.lua (major refactor)
- Added `newArpEngine()` factory for per-row state (heldNotes, stepIndex, stepDirection, pos, currentPitch, beatPosition, activeGateTimers, etc.)
- Added `state.arpEngineTop` and `state.arpEngineBottom` engine instances
- Added `stopEngineState(eng)` helper for cleanly stopping a single engine
- Added `arpTickEngine(eng, isTopRow)` — per-row tick function that mirrors unified arpTick but operates on an engine table
- Modified `arpTick()` to dispatch to per-row engines when `state.arpLinked == false`
- Modified `arpAddNote()`/`arpRemoveNote()` to route notes to correct engine when unlinked
- Modified `applyGatePercentChange()`, `updateLatchedArpNotes()`, `updateLatchedArpChordNotes()` for per-row handling
- Modified `toggleArpPower()` to clear both engines when turning off
- Added `toggleArpLink()` function: flips `state.arpLinked`, merges/splits note pools, shows HUD spotlight

### src/config.lua
- Added `arpLinked` state field (default: `true`, persisted)
- Added `arpLinkToggle` to ACTION_CATALOG under Arpeggiator category
- Changed Shift+7 mapping from `modeDown` → `arpLinkToggle`
- Changed Shift+8 mapping from `modeUp` → `botVolDown`

### src/controls.lua
- Added `arpLinkToggle` case in `executeControlAction()` → calls `arpeggiator.toggleArpLink()`
- Added `arpLinked` to `captureStateSnapshot()` and `applyStateSnapshot()` for undo/redo
- Added `arpLinkToggle` to the pushStateSnapshot action list

### src/hud.lua
- Added `arpLinked` to the HUD state payload

## Key Bindings
- **Shift+7**: Toggle Arp Link (LINKED ↔ SPLIT)
- **Shift+8**: Bottom Row Volume Down