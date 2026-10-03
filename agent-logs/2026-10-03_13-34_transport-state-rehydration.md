# KeyStep Transport State Rehydration

## Change

- A newly connected KeyStep now reports transport status as `unknown`; it no longer presents an unobserved stopped state after a Hammerspoon restart.
- Explicit MIDI Start/Continue marks transport running, and explicit Stop marks it stopped. MIDI clock pulses update tempo but do not determine transport state: the KeyStep can use an external clock source, so clock activity alone is not reliable evidence that its sequencer transport is running.
- The HUD snapshot carries `transportStatus`. Unknown lights neither Play nor Stop, so Clear Last's stopped indicator cannot falsely imply a confirmed stop. The existing HUD ready handshake continues to deliver the current driver snapshot.
- Bundled Lua and synced UI through `bin/hs-bundler`; did not reload Hammerspoon.

## Verification

- `git diff --check` passed.
- Tests were not run.
- After a software restart, transport remains unknown until a fresh Start/Continue or Stop message arrives. The current MIDI protocol path has no query for the KeyStep's already-running transport state.
