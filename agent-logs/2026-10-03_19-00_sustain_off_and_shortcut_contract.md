# Work Log: Visible Sustain-Off Gesture and Shortcut Contract

**Date:** 2026-10-03

## Outcome

- Made the Tab key self-documenting as `Smart Sus · 2× Off`.
- Preserved the established single-tap damping and hold-to-damp behavior; a second short Tab press within 350ms now switches the active track’s Smart or Classic Sustain mode to `off`, releases sustained pitches, saves settings, and shows an OFF notification.
- Removed the dangerous Tab modifier routes: all Ctrl+Tab variants now render `Pass Through` and are handed back to macOS before controller dispatch. They cannot invoke Panic or Reset All.
- Removed the unadvertised global Cmd+Shift+M toggle, four-modifier reload binding, and Cmd+, settings interception. Reload cleanup deletes old live instances of the retired hotkeys so existing Hammerspoon globals cannot retain them.
- Clarified the backtick key as `Arp Mode + A`, matching its visible two-key mode-selector behavior.

## Files

- `src/config.lua`, `src/controls.lua`, `src/hud.lua`, `src/init.lua`
- `src/web/index.html`, generated `src/ui_html.lua`, generated `qwerty_midi.lua`
- `tests/shortcut_visibility_and_sustain_off.test.js`, `FEATURES.md`, `AG_CONTEXT.md`, `DEVELOPMENT_JOURNAL.md`

## Verification

- `bun test`: 69 passed, 0 failed.
- `luac -p qwerty_midi.lua src/config.lua src/controls.lua src/hud.lua src/init.lua`: passed.
- Rebundled and reloaded with `bin/bundle_and_reload.sh`.
- Live Hammerspoon status: `midiActive=true`, key event tap enabled, HUD webview present, Secure Input disabled.
