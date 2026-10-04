# HUD Close Shortcut and Context Menu

## Outcome

- `Cmd+Shift+M` has been deliberately removed after it was reported to crash
  the live controller. The Studio Suite's separate binding was also removed.
- Added a chassis-only right-click menu with **Close MIDI HUD** and a visible
  action. Text inputs, textareas, selects, and editable content retain WebKit's
  native context menus.
- HUD visibility is deliberately non-persistent. Automatic reloads remain
  disarmed, preventing a failed or closed HUD from silently reclaiming keys.
- Keyboard and scroll taps now fail open: a close action, callback error,
  stopped tap, missing/invisible HUD, or expired heartbeat disables capture;
  the watchdog no longer restarts a failed tap. Automatic reloads stay disarmed.

## Files

- `src/init.lua`
- `src/hud.lua`
- `src/web/index.html`
- generated `src/ui_html.lua` and `qwerty_midi.lua`
- `tests/hud_close_controls.test.js`

## Verification

- `bun test`: 72 passed, 0 failed (626 assertions).
- `luac -p qwerty_midi.lua src/*.lua`: passed.
- Live Hammerspoon trace reached `domReady` and heartbeat pings after the
  bundle. Browser-side contextmenu dispatch reported `close-menu-visible=true`.
- The safety patch was bundled and parsed while Hammerspoon remained stopped.
  Live activation is intentionally deferred so ordinary typing remains safe.
