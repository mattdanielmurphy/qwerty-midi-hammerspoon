# Compact Track-Key Layout

- Replaced full track labels inside Keys 1–4 with fixed layout zones: B/C/L/A role glyph, centered track number, M/S buttons, and compact sustain/chord state badges.
- Preserved full role names as hover titles and retained the existing track-state classes and Hammerspoon action routes.
- Added `tests/track_button_layout.test.js`; `bun test` passed 5 tests and `bun run bundle` regenerated `src/ui_html.lua` and `qwerty_midi.lua` before reloading Hammerspoon.
