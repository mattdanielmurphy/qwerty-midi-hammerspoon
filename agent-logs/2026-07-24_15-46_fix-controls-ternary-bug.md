## Goal
The user reported that the Arpeggiator top row toggle was still not working and the top row was still being arpeggiated, despite the fix in the previous session.

## User Feedback & Decisions
The user stated: "The Arp on/off button for top row also doesnt appear to work (doesn't toggle on/off). It should be off by default though and top row is still being arpeggiated." and "issue is STILL unresolved. Figure out what it is".

## Changes Made
- `src/controls.lua`: Located a second instance of the exact same Lua ternary operator logic bug at line 478 (`local arpEnabledForRow = isTop and state.arpTopEnabled or state.arpBottomEnabled`) inside `handleKeyDown`. It was causing the top row notes to still be processed as arpeggiator notes whenever `arpBottomEnabled` was true, completely overriding the `arpTopEnabled` setting. Changed the line to `local arpEnabledForRow = isTop and state.arpTopEnabled or (not isTop and state.arpBottomEnabled)`.
- Re-bundled the Lua script into `qwerty_midi.lua`.

## What Worked
- Finding the duplicate logic bug in `src/controls.lua`. Now, `isTop and state.arpTopEnabled` properly evaluates without mistakenly adopting the `state.arpBottomEnabled` fallback value.

## What Didn't Work / Known Issues
- None so far.

## Architecture Notes
- The ternary bug `A and B or C` when `B` is false causes the expression to evaluate to `C`. It is essential to be extremely careful with Lua ternary patterns when dealing with boolean variables. This bug existed in both `src/arpeggiator.lua` and `src/controls.lua` (for determining if a key press should be grabbed by the arpeggiator vs played directly). Both have now been secured.
