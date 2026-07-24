# Agent Log: Dedicated Number Row Arpeggiator Controls

## Goal
Remap the number row keys (1 through =) from redundant duplicates of home row controls to dedicated Arpeggiator and BPM controls.

## User Feedback & Decisions
- The user preferred number keys to control Arpeggiator parameters rather than repeating Octave, Mode, Panic, and Reset controls that are already on the Home row.

## Changes Made
- `src/config.lua`: Re-mapped `numberRowControls` table:
  - `1`: Arp On/Off (`arpToggle`) (Shift: `Panic!`)
  - `2`: Top Row Arp toggle (`arpTopToggle`) (Shift: `Trnsp -`)
  - `3`: Bottom Row Arp toggle (`arpBottomToggle`) (Shift: `Trnsp +`)
  - `4` / `5`: Arp Direction -/+ (`arpDirDown` / `arpDirUp`) (Shift: `TopOct -/+`)
  - `6` / `7`: Arp Rate -/+ (`arpRateDown` / `arpRateUp`) (Shift: `Oct -/+`)
  - `8` / `9`: Arp Gate -/+ (`arpGateDown` / `arpGateUp`) (Shift: `Mode -/+`)
  - `0`: BPM Text Edit (`bpmEdit`) (Shift: `Reset`)
  - `-` / `=`: BPM -/+ (`bpmDown` / `bpmUp`) (Shift: `Zoom -/+`)
- `src/controls.lua`: Added action execution handlers in `executeControlAction` for all Arp and BPM actions (`arpToggle`, `arpTopToggle`, `arpBottomToggle`, `arpDirDown`, `arpDirUp`, `arpRateDown`, `arpRateUp`, `arpGateDown`, `arpGateUp`, `bpmDown`, `bpmUp`, `bpmEdit`). Updated `handleKeyDown` to honor `shiftHeld` for number row keys.
- `src/hud.lua`: Updated `numberRowControls` render loop in `updateWebviewHud` to dynamically compute labels and apply Arp gold styling when active.
- `src/ui_html.lua`: Updated `LAYOUT_DATA.number` initial key pad labels in the HTML template.
- `qwerty_midi.lua`: Re-bundled standalone script with `bin/bundle_and_reload.sh`.
- `FEATURES.md`: Documented the new dedicated number row Arp controls capability.

## What Worked
- Tapping number keys 1 through = directly adjusts Arp power, top/bottom arp toggles, pattern direction, rate division, gate duration, and BPM tempo.
- Holding Shift on number keys provides quick access to Panic, Transpose, Octave, Mode, Zoom, and Reset without taking up main key taps.
- HUD spotlight cards show instant feedback for all Arp parameter adjustments made via number keys.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- `numberRowControls` uses `shiftAction` and `shiftName` properties just like `homeRowControls`, allowing seamless dual-mode key mapping depending on `state.shiftHeld`.
