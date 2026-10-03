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

---

# QWERTY MIDI Controller Fixes

## Architecture

- Keep selected track and active function state authoritative. MIDI routing and HUD labels, values, and colors derive from that state.
- Keep controller state and assignment resolution in `src/controls.lua` and `src/config.lua`, MIDI delivery in `src/midi.lua`, and presentation in `src/hud.lua` / `src/web/index.html`.
- Use a two-control ADSR workflow: the A♯/B♭ black key selects Attack, Decay, Sustain, Release in sequence; the Mod strip edits the selected stage. Preserve four independent values. Use configurable CC mappings, defaulting to 24–27.
- Keep Pitch as 14-bit pitch bend by default and route it to the active function assignment while a black key is held. Keep the dedicated Rate/Vol route; remove the Mod-strip Volume assignment.

## Implementation

1. Trace track focus/row selection, black-key holds and latches, Mod/Pitch IPC, note ownership, and panic callers. Preserve existing uncommitted KeyStep changes.
2. Add per-track controller values and envelope values; represent simultaneously held function keys independently and restore the next held assignment on release.
3. On assignment or track changes, refresh the HUD from the newly active control's stored value and selected track color without emitting a MIDI value.
4. Route Mod CC and Pitch Bend on the focused track's MIDI channel. Recenter Pitch Bend on release.
5. Coordinate panic: stop arpeggiator/quantizer producers, clear held and sustained note ownership, stop timers, release notes, reset sustain, and send CC 123/120 across channels.
6. Update the web HUD and bundled outputs from source; record architectural decisions and implementation details in project context and logs.

## Acceptance

- Track-dependent controls use the selected track's color and recalled per-track values.
- Mod assignment changes show the target's stored value immediately and do not send CC until adjusted.
- Pitch sends 14-bit bend by default, follows active function assignments, and recenters; ADSR stages are independently editable through stage selection plus Mod strip.
- Releasing one of multiple held black keys reveals the remaining held function.
- Panic clears producers and held-note registries as well as MIDI channel state.
- Hardware MIDI-monitor verification is unavailable unless a connected monitor/device is present; report that limitation explicitly.
- Do not hide recurring callback errors with a broad `pcall`.
- On failure, release only notes owned by the keyboard path; preserve intentional latched/background behavior.
