## Goal
Add `[` and `]` note keys to upper row and `'` note key to lower/home row extending natural scale pitches.

## User Feedback & Decisions
- Top row extended with `[` (code 33, base note 89 / F) and `]` (code 30, base note 91 / G).
- Home row extended at the right end with `'` (code 39, base note 77 / F).

## Changes Made
- [src/config.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/config.lua): Added `[` and `]` to `upperRowKeys` and `'` to `lowerRowKeys`.
- [src/ui_html.lua](file:///Users/matt/projects/qwerty-midi-hammerspoon/src/ui_html.lua): Added `[`, `]`, and `'` keypads to `LAYOUT_DATA`. Updated home row control labels (`Trnsp -` / `Trnsp +` / `Mode -` / `Mode +`) to match recent swap.
- Re-bundled standalone `qwerty_midi.lua` via `bin/bundle_and_reload.sh`.

## What Worked
- New note keys send correct transposed MIDI pitches.
- Visual HUD layout correctly displays `[`, `]`, and `'` pads.
- Hammerspoon reloaded cleanly.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- `'` (keycode 39) is registered in `lowerRowKeys` so `isTop` resolves to `false` (sharing the lower row octave offset and volume), while positioned at the end of the home row in HTML `LAYOUT_DATA` to visually match physical keyboard layout.
