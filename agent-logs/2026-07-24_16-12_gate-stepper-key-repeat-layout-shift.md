## Goal
- Replace the ARP Gate dropdown with a numeric stepper & vertical drag control (matching BPM editor styling).
- Fix accuracy so gate percentage shows exact percentage (1% to 150%) without arbitrary capping.
- Re-map backtick (`) to Arp On/Off and shift all number row controls rightward so 1 is Top Arp, 2 is Bot Arp, etc.
- Enable automatic key repeat for all non-note control keys when held down.

## User Feedback & Decisions
- Gate UI control should be a draggable stepper displaying actual percentage.
- Backtick key (` ` `) activates Arp On/Off, removing duplicate Arp toggle from key 1.
- Holding control keys continuously adjusts settings.

## Changes Made
- `src/config.lua`:
  - Changed `arpGateIdx` to `arpGatePercent = 80.0`.
  - Shifted `numberRowControls` mapping starting with `` ` `` for `arpToggle`.
- `src/arpeggiator.lua`: Updated gate ratio calculation to `(state.arpGatePercent or 80.0) / 100.0`.
- `src/controls.lua`:
  - Added timer repeat mechanics (`controlRepeatTimers`) in `handleKeyDown` and `handleKeyUp` for number and home row control keys.
  - Updated `arpGateDown` / `arpGateUp` actions to adjust `state.arpGatePercent` directly (range: 1.0 to 150.0).
- `src/hud.lua`: Updated payload to supply `arpGatePercent` and handled `dragGate`, `gateUp`, and `gateDown` WebSockets messages.
- `src/ui_html.lua`:
  - Replaced `<select id="arp-gate-select">` with `<div id="gate-editor" class="bpm-editor">`.
  - Added drag and hold repeat handlers for `gate-value`, `gate-up`, and `gate-down`.
  - Shifted `LAYOUT_DATA.number` key labels to match `config.lua`.

## What Worked
- Rebuilt bundle, verified continuous key repeats on held control keys, verified gate numeric stepper display & vertical drag functionality, confirmed updated number row layout.
