## Goal
User wanted the `A` key (and the arp button) to cycle through three states: **On → Latch → Off**, instead of the prior behavior where `A` was a separate tap-vs-hold Latch key independent of the arp on/off state.

## User Feedback & Decisions
- User's exact words: "I don't want A to be latch on/off. I want the arp button to cycle through On/Latch/Off."
- `A` on the home row should trigger the same cycle as pressing the `ARP` button in the HUD.
- Latch is now a middle state, not a separate toggle.

## Changes Made

### `src/config.lua`
- Removed `arpLatchKeyDownTime` and `arpLatchWasActiveOnPress` state vars (no longer needed; tap-vs-hold latch logic removed).
- Updated `homeRowControls` key `A` (code 0): action changed from `"latch"` to `"arpToggle"` (same action as backtick key).

### `src/arpeggiator.lua`
- Rewrote `toggleArpPower()` to cycle: **Off → On → Latch → Off**.
  - First press: `arpEnabled = true`, `arpLatchActive = false`.
  - Second press: `arpLatchActive = true` (latch state, arp still running).
  - Third press: `arpEnabled = false`, `arpLatchActive = false`, stop arp timer & clear held notes.
- HUD spotlight notification now shows "ARP: OFF", "ARP: ON", or "ARP: LATCH" accordingly.

### `src/controls.lua`
- Replaced `elseif act == "latch"` handler in `executeControlAction` with `elseif act == "arpToggle"` → calls `arpeggiator.toggleArpPower()`.
- Removed `"latch"` exemption from the home row key-repeat guard (`if act ~= "sustain"` only now).
- Removed entire `elseif act == "latch"` block from `handleKeyUp` (no more tap-vs-hold logic).
- Added `state.arpLatchActive = false` to `resetAll`.

### `src/hud.lua`
- `latchStr` removed; replaced status bar entry with `"ARP: ON"` or `"ARP: LATCH"` when `state.arpEnabled` is true.
- Key `A` (`isLatch`) now lights up (`sustainActive = true`) when `state.arpEnabled` is true (any arp state).
- `typeClass = "latch-active"` on key A when either `arpEnabled` or `arpLatchActive` is true.
- Added `arpLatchActive` to HUD payload so JS can distinguish ON vs LATCH state.

### `src/ui_html.lua`
- Added `.arp-btn.arp-latch` CSS class: brighter amber glow (`box-shadow: 0 0 12px ...`) with white text.
- Updated `renderHud()` JS to render 3-state arp button: removes `arp-latch` on OFF, adds both `arp-active arp-latch` on LATCH, only `arp-active` on ON.

## What Worked
- Full 3-state cycle functional: Off → On → Latch → Off.
- `A` key and HUD arp button both drive the same `toggleArpPower()` cycle.
- Visual distinction: OFF (dim), ON (amber glow), LATCH (bright amber glow + white text).

## What Didn't Work / Known Issues
- None identified.

## Architecture Notes
- `arpLatchActive` can only be `true` when `arpEnabled` is also `true` — these are no longer independent states.
- The old tap-vs-hold distinction for latch has been fully removed; the cycle is now instantaneous on keydown.
- `arpToggle` action is shared between backtick (code 50, number row) and `A` (code 0, home row).
