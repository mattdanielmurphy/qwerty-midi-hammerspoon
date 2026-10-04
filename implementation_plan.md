# QWERTY MIDI: Contextual Controls and Chord-Safe Arpeggiation

## Current runtime status

On 2026-10-03, the missing HUD was caused by the Hammerspoon application not
running, not by a failing Lua load or WebKit render. A clean launch created the
`MIDI Controller HUD`, reached `domReady`, and returned heartbeat pings. The
HUD was visually confirmed at 960 x 323 points. There are duplicate watcher
processes; inspect and consolidate those separately before changing watcher
behavior, so a healthy automatic reloader is not accidentally removed.

The UI recovery contract for the work below is:

- a close action hides the MIDI HUD only; it must not panic, stop a latched
  arpeggio, unload MIDI, or close settings;
- an unexpected WebKit closure still uses the existing guarded respawn path;
- every new transient gesture is cancelled on HUD close, focus loss, mode exit,
  panic, and reload.

## Goals

1. Restore `Cmd-Shift-M` as the keyboard shortcut to close the MIDI HUD and
   add an owned right-click **Close** item to that HUD.
2. Add selected-track volume down/up controls plus per-track delay and reverb
   controller values.
3. Make a small, visible Cmd/Cmd-Shift macro layer without taking standard
   macOS shortcuts that need to pass through.
4. When an arpeggiated source was entered in chord mode, changing *that
   track's* selected chord reshapes the running pattern on the next step.
5. Replace chord-type cycling with a hold-to-choose chord palette, and build
   the palette as a reusable tap/double-tap/hold mechanism.

## Findings that drive the design

- `src/init.lua` currently passes every Cmd event through to macOS. It needs a
  narrow, allowlisted exception rather than a general Cmd capture layer.
- The HUD is the `MIDI Controller HUD` webview created in `src/hud.lua`; its
  `windowCallback` currently treats every close as unexpected and respawns it.
  An intentional-hide path must be represented explicitly.
- Tracks already own `volume`, `chordModeActive`, `chordIdx`, arp state, and a
  MIDI channel. Existing volume values are CC-style 0..127 values despite the
  percent HUD display.
- The KeyStep surface already uses CC 91 for reverb and CC 92 for delay. Use
  those controller assignments consistently for QWERTY; label them as
  controller/send values because a Logic instrument or plug-in must map them
  to audible effects.
- `controls.lua` calls `arpeggiator.updateLatchedArpChordNotes()` after chord
  changes. Its current implementation iterates all tracks and derives intent
  from held pitches, so it cannot preserve the crucial fact that a source was
  originally entered in chord mode.

## Binding contract to audit before implementation

Candidate bindings are intentionally limited to active MIDI mode. The source
audit must confirm each is not already claimed by an allowed foreground-app
command; if it is, choose another Cmd-layer key and document the replacement.

| Binding | Action | Scope |
| --- | --- | --- |
| Cmd-Shift-M | Close MIDI HUD | HUD only |
| Cmd-9 / Cmd-0 | Volume - / + | selected track |
| Cmd-7 / Cmd-8 | Delay - / + (CC 92) | selected track |
| Cmd-Shift-7 / Cmd-Shift-8 | Reverb - / + (CC 91) | selected track |
| Cmd-Shift-9 | Restore selected-track volume default | selected track |
| Cmd-Shift-0 | Set delay and reverb to zero | selected track |

Do not capture Cmd-Q, Cmd-W, Cmd-H, Cmd-Tab, Cmd-comma, Cmd-Space, or ordinary
editing shortcuts. Base and Shift layers keep their existing musical bindings.
Every captured shortcut must appear in the HUD’s shortcut/help presentation.

## Data and API design

### Track parameters

Extend each track with persisted `delaySend` and `reverbSend` values in the
same 0..127 domain as `volume`. Add one authoritative selected-track parameter
path, shared by keys, HUD actions, and future hardware:

```text
setTrackParameter(trackId, parameter, value) -> clampedValue
adjustTrackParameter(trackId, parameter, delta) -> clampedValue
```

The path validates the track and parameter, persists the value, sends CC 7, 91,
or 92 on that track’s channel, and refreshes the HUD. A mute must retain a
requested volume without sending an audible CC 7 value until the track becomes
audible again.

### Chord provenance

Keep existing derived arp pitch tables, but add source records per track:

```text
arpSources[sourceId] = {
  physicalKeyCode, baseNote, row, origin, chordAtEntry,
  isPhysicallyHeld, isLatched
}
```

`origin` is `single`, `chordMode`, or `momentaryChord`. A chord-mode source is
recorded before it expands into pitches. `setTrackChord(trackId, chordIdx,
reason)` becomes the only chord setter: it updates the selected track, updates
the active-track compatibility mirror, persists where appropriate, asks the
arpeggiator to rebuild that track’s eligible chord-mode sources atomically, and
refreshes the HUD. All keyboard, webview, and sync-originated chord changes
must call it.

The rebuild preserves the track’s timer, rate, direction, phase, and unrelated
single-note sources. It releases currently gated pitches no longer in the new
pool with the existing generation-safe gate logic, then lets the next arp tick
play the new shape. A Track 2 change must never alter Track 1’s pool, channel,
or clock.

### Reusable contextual gesture

Add one non-persisted gesture state and descriptor table, preferably in a
small `src/gestures.lua` module wired before ordinary control/note dispatch:

```text
contextGesture = {
  selectorId, selectorKeyCode, trackId, pressedAt,
  phase, holdTimer, tapTimer, choiceActionId, consumedKeyUps
}

descriptor = {
  selectorKeyCode, tapAction, doubleTapAction,
  holdThresholdMs, doubleTapWindowMs, choices, scopeResolver
}
```

The chord descriptor maps every entry in `state.CHORDS` to one visibly labeled
choice key. If chord types outgrow the available choice keys, introduce a
labeled page rather than silently omitting a type.

On selector down, snapshot the track and start the hold timer. A release before
the threshold performs the existing tap action once (or waits only when that
specific descriptor offers a double-tap action). At the threshold, cancel a
pending tap and reveal choices. A choice’s key-down commits one action; both it
and its later key-up are consumed, so no note or ordinary control fires. The
menu remains until selector release; release without a choice cancels it.

The selector’s current chord-cycle action must be deferred until release. A
hold must never cycle the chord before it opens the palette.

## Presentation and window behavior

- Put `closeKeyboardWindow()` behind both the Cmd shortcut and one allowlisted
  webview IPC action. It hides the MIDI webview idempotently and marks that
  hide as intentional so `windowCallback` does not respawn it.
- Add a custom browser `contextmenu` only on the HUD chassis/background. It
  offers **Close**, dismisses on Escape/outside click/hide, and leaves native
  text-input context menus intact.
- Include `contextMenu` state in the HUD payload: selector, captured track,
  active choice, and choice labels. The frontend lights available choices and
  dims non-choices without changing any fixed dimensions or reintroducing
  layout shift.
- `Cmd-Shift-M` and the context menu both call the same Lua close action.

## File-by-file implementation order

1. **Inventory and safety tests** — inspect `config.lua`, `controls.lua`,
   `arpeggiator.lua`, `midi.lua`, `hud.lua`, `sync.lua`, `web/index.html`, and
   existing tests. Produce the binding-collision table before fixing key names.
2. **Track parameter core** — update `src/config.lua`, `src/controls.lua`, and
   `src/midi.lua` with parameter initialization, persistence, selected-track
   setters, CC 7/91/92 emission, mute-safe recall, and focused tests.
3. **Chord-safe arp rebuild** — update `src/controls.lua`,
   `src/arpeggiator.lua`, and `src/sync.lua` to record source provenance,
   funnel all chord changes through `setTrackChord`, and rebuild only the
   owning track.
4. **Gesture router and macros** — add `src/gestures.lua` or a clearly bounded
   equivalent in `controls.lua`; wire it into `src/init.lua` before normal
   performance dispatch. Add only the audited Cmd/Cmd-Shift bindings.
5. **HUD close/context menu/palette** — update `src/hud.lua` and
   `src/web/index.html`; regenerate `src/ui_html.lua` and `qwerty_midi.lua`
   only through the bundler.
6. **Verification and live activation** — run focused tests and full `bun
   test`, bundle, run `luac -p qwerty_midi.lua src/*.lua`, reload Hammerspoon,
   then verify the live HUD and one MIDI monitor/Logic route where available.

## Acceptance tests

- A short chord-selector tap retains its current one-tap behavior exactly once.
  A hold past the threshold changes nothing until a lit choice is pressed.
- Choice key-down commits exactly one chord; its key-up cannot play a note.
  Releasing the selector first, key repeat, focus loss, reload, panic, and mode
  exit leave no pending timers, dimmed overlay, consumed-key record, or stuck
  note.
- A physically held or latched chord-mode arp source on Track 1 follows only
  Track 1’s new chord. Track 2 remains byte-for-byte unchanged in pool,
  channel, and clock. Single-note sources remain single after chord changes.
- Volume, delay, and reverb clamp to 0..127, persist independently by track,
  emit only on that track’s channel, and respect muted-track audibility.
- Cmd-Shift-M and right-click **Close** hide the same HUD, clean up transient
  gestures, do not close settings, and preserve intentional latched playback.
- Existing UI liveness checks still reach DOM-ready and heartbeat after a
  normal reload. An intentional close does not schedule a webview respawn.

## Definition of done

Attach the binding collision table, persistence migration decision (if any),
focused and full test output, `luac -p` result, and a short live verification
record showing: both close paths, selected-track CC output, and a running
chord-mode arp changing only when its owning track’s chord changes.
