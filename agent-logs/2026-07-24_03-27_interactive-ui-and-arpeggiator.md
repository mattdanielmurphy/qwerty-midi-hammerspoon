## Goal
1. Fix UI key click behavior so clicking keys on the canvas HUD triggers native MIDI notes and control actions.
2. Enable dragging the scale mode slider to set modes directly.
3. Enable selecting root notes directly from a styled dropdown menu on the root badge.
4. Add a simple built-in arpeggiator engine (UP, DOWN, UP-DOWN, RANDOM modes and BPM speed selector).

## User Feedback & Decisions
- UI key clicks should trigger MIDI sound and control functions seamlessly.
- Root note selection should be a dropdown selector built directly into the root badge.
- Mode slider should support mouse dragging/clicking.
- Arpeggiator should have simple, intuitive controls and clear visual feedback.

## Changes Made
- `qwerty_midi.lua`:
  - Implemented `handleKeyDown(code)` and `handleKeyUp(code)` functions shared by both QWERTY hardware eventtap and WebKit webview `postMessage` handlers.
  - Added `-webkit-app-region: no-drag` to interactive header elements (`#root-select`, `.mode-center-block`, `#arp-btn`, `#arp-rate-btn`) so clicking and dragging interactive controls doesn't trigger window movements.
  - Converted `#root-badge` to `<select id="root-select">` with styled options (C through B) and added `setRoot` message handler in Lua.
  - Added drag and click handlers to `#mode-track` with `setModeIdx` message handler in Lua.
  - Implemented Arpeggiator engine in Lua with modes (OFF, UP, DOWN, UP-DOWN, RANDOM), timer loop using `hs.timer.doEvery`, note stacking, speed cycling (90..200 BPM), and real-time active note key highlights on the UI canvas.
  - Added `ARP: OFF` and `120 BPM` toggle buttons in the HUD header bar.

## What Worked
- Webview clicks now trigger noteOn/noteOff and control actions reliably.
- Root dropdown allows instant selection of any root note (0..11) and updates in sync with hardware hotkeys.
- Mode slider dragging updates scale modes smoothly in real time.
- Arpeggiator steps cleanly through held notes and highlights active notes on the HUD canvas.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- `-webkit-app-region: drag` on container headers prevents pointer events on interactive children unless `-webkit-app-region: no-drag` is explicitly added to child elements.
