# Keyboard Input Incident Plan

## Goal

Restore Mac QWERTY input to the Hammerspoon MIDI controller without breaking ordinary typing, shortcuts, text fields, or intentional KeyStep mappings.

## Diagnose before changing code

Capture one observation at each boundary, in order:

1. Confirm whether ordinary typing fails globally or only QWERTY-MIDI input fails. If global typing fails, prioritize macOS keyboard or Secure Input investigation.
2. Preserve Hammerspoon Console startup errors and callback traces before rebuilding or reloading.
3. In the Hammerspoon Console, inspect:

   ```lua
   local w = _G.activeWatchers
   return {
     watchersPresent = w ~= nil,
     midiActive = w and w.state and w.state.midiActive,
     textInputActive = w and w.state and w.state.textInputActive,
     keyTapPresent = w and w.midiKeyTap ~= nil,
     keyTapEnabled = w and w.midiKeyTap and w.midiKeyTap:isEnabled(),
     secureInputEnabled = hs.eventtap.isSecureInputEnabled()
   }
   ```

4. Verify the installed artifact: resolve `~/.hammerspoon/init.lua` and its QWERTY-MIDI module target, compare it with this checkout, and run `luac -p` on the loaded bundle.
5. Check Hammerspoon in macOS **Privacy & Security** under both **Input Monitoring** and **Accessibility**. Do not reset TCC permissions blindly. If Secure Input is active, identify and close the app or password field holding it, then restart Hammerspoon and retest.
6. Test with a normal DAW window focused—not a HUD text field, Inspector, or DevTools. Record whether `textInputActive` is stale.
7. Test one known control and one known note, observing separately: tap reception, HUD/control-state response, binding dispatch, and MIDI output. Do not use `Z` alone when a KeyStep is connected; that row is intentionally remapped to controls.

## Decision tree

| First failed gate | Repair branch |
| --- | --- |
| Module does not load or bundle differs | Repair only the install/symlink/bundle provenance; regenerate from source, parse the generated Lua, then reload. |
| Tap missing or disabled while `midiActive=true` | Diagnose permissions, Secure Input, mode startup, and saved `qwertyMidi_wasOpen` state before modifying mappings. |
| Tap enabled but `textInputActive=true` without a field | Repair the HUD focus lifecycle on blur, close, and webview recreation. |
| Event is admitted but unbound or handler errors | Repair the smallest dispatch/configuration defect and expose a bounded diagnostic. |
| HUD reacts but no sound | Investigate MIDI endpoint, channel/track route, mute/solo state, and DAW input—not macOS capture. |

## Proposed implementation (only after diagnosis)

1. In `src/init.lua`, change only the failed load/tap/admission gate. Add a read-only keyboard status snapshot and bounded last-error reporting. Unrecognized keys, text-entry contexts, exempt windows, and callback failures must fail open to macOS.
2. In `src/hud.lua`, make `textInputFocus` symmetric: clear it on blur, close, and webview recreation. Ensure HUD labels are based on the same resolved binding as dispatcher behavior.
3. In `src/config.lua`, correct the independently identified cache flaw: note and control maps share `_cachedKsConnected`, so one getter can make the other stale after KeyStep connect/disconnect. Use independent generations or invalidate both maps atomically.
4. Add focused tests for admission/pass-through, stale text focus, key-down/up pairing through focus or connection changes, each KeyStep transition with either getter order, lower-row connected/disconnected behavior, and HUD/dispatch binding parity.
5. Touch bundling/install scripts only if the installed-artifact check proves a provenance defect. Do not edit generated `qwerty_midi.lua` as the source of truth.

## Acceptance checks

1. Ordinary typing and macOS shortcuts remain usable.
2. The intended and newly generated bundles both pass `luac -p`.
3. Existing Bun tests plus focused keyboard-path tests pass.
4. After bundle and reload: `midiActive=true`, tap present and enabled, and Secure Input disabled during testing.
5. With a normal DAW window focused, verify a control and note-on/note-off; separately verify MIDI output.
6. Verify text-field and Inspector/DevTools pass-through, both KeyStep connection transitions, and no stuck notes after a focus change.

## Safety invariants

- A handled key-down must retain enough information to release the same note on key-up even if focus, modifiers, mode, or connection changes.
- Do not hide recurring callback errors with a broad `pcall`.
- On failure, release only notes owned by the keyboard path; preserve intentional latched/background behavior.
