## Goal
Expand Arpeggiator HUD controls with separate power button, direction dropdown, time division, and note length gate.

## User Feedback & Decisions
- User requested separate arp on/off and direction buttons, direction dropdown, and basic settings like note length.

## Changes Made
- Split arpMode into arpEnabled and arpDirectionIdx.
- Added arpRateIdx (1/4 to 1/16T) and arpGateIdx (25% to 100%).
- Implemented step note-off timer in arpTick.
- Added UI dropdown controls in HTML header.
- Updated FEATURES.md and task file.

## What Worked
- Reloaded config successfully.
