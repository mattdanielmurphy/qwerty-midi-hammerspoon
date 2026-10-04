# HUD Close Shortcut and Context Menu

## Outcome

- Implemented `Cmd+Shift+M` in the active MIDI event tap. It hides only the
  `MIDI Controller HUD`, consumes the matching key-up, and leaves controller
  mode, MIDI routing, held arp state, and background clocks active.
- Added a chassis-only right-click menu with **Close MIDI HUD** and a visible
  `⌘⇧M` hint. Text inputs, textareas, selects, and editable content retain
  WebKit's native context menus.
- HUD visibility is deliberately non-persistent. A reload always opens the
  HUD, preventing a previously closed HUD from looking like a failed app launch.

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
- After a reload, the native `MIDI Controller HUD` window was visible and its
  DOM reached `domReady`; the Hammerspoon process remained alive after the
  shortcut probe. No matching macOS crash report was created.
