## Goal
- Update minimum ARP gate percentage threshold from 1% to 5%.

## User Feedback & Decisions
- Set minimum gate limit to 5%.

## Changes Made
- `src/controls.lua`: Updated `arpGateDown` minimum bound to `5.0`.
- `src/hud.lua`: Updated `dragGate` and `gateDown` minimum bounds to `5.0`.
- Rebundled `qwerty_midi.lua` via `./bin/bundle_and_reload.sh`.

## What Worked
- Rebuilt bundle successfully and verified minimum limit clamp to 5%.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- Minimum gate duration now enforces `5.0%` across keyboard shortcuts, mouse dragging, and button step clicks.
