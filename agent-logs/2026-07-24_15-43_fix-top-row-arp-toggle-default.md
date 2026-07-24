# Agent Log: Fix Top Row Arp Toggle & Set Off By Default

## Goal
Fix top-row Arpeggiator toggle button responsiveness and set Top Row Arp to `OFF` by default so playing the top row triggers un-arpeggiated lead notes while bottom row handles arpeggiated patterns.

## User Feedback & Decisions
- The top row Arp on/off toggle button was not toggling state when clicked.
- Top row Arp should be `OFF` by default so top row notes are played as standard un-arpeggiated lead pitches while bottom row is arpeggiated.

## Changes Made
- `src/hud.lua`: Removed invalid conditional checks (`if state.arpTopEnabled or not state.arpBottomEnabled`) in `toggleArpTop` and `toggleArpBottom` message handlers that prevented toggling top row arp back on once disabled. Added spotlight notifications (`TOP ROW ARP: ON/OFF`, `BOTTOM ROW ARP: ON/OFF`).
- `src/config.lua`: Updated default `arpTopEnabled` setting from `true` to `false`.
- `src/controls.lua`: Updated `resetAll` default `state.arpTopEnabled` to `false`.
- `src/ui_html.lua`: Removed default `active` class from top row arp toggle button `<button id="arp-top-toggle">` template.
- `qwerty_midi.lua`: Re-bundled standalone script with `bin/bundle_and_reload.sh`.

## What Worked
- Top row Arp is now disabled by default on startup and after Reset All.
- Top row Arp toggle button now cleanly toggles between ON and OFF with interactive HUD spotlight cards.
- Bottom row plays arpeggiated notes while top row plays lead notes un-arpeggiated by default.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- `isSplitArp` automatically activates when `arpEnabled` and `arpBottomEnabled` are true while `arpTopEnabled` is false, boosting top row velocity by `+20` for solo lead playing alongside bottom row arpeggiation.
