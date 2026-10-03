# Decouple Note Rendering and Include KeyStep Chords

## Context

Continued the Oct 3 Gemini handoff. The earlier work identified that QWERTY
note press/release events forced a full HUD render, and that physical KeyStep
notes were missing from the live chord detector.

## Changes

- Replaced the full HUD render on QWERTY note keydown and keyup with the existing
  single-key state update, which updates pad lighting and the active chord.
- Included held, transposed KeyStep white-key pitches in chord detection.
- Updated the chord badge directly for KeyStep note events and from normal HUD
  renders, including after root or scale changes.

## Verification

- `git diff --check` passed.
- Rebuilt the generated Lua bundle and reloaded Hammerspoon.
- Did not run the test suite.
- The remaining visual-blur task stays on the project board pending live user
  confirmation that keypress/release redraws are resolved.
