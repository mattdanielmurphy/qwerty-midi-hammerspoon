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

---

## AI-OS plan for the current follow-up request

The change should have two independent paths: a **live musical-state reconciliation** path that rebuilds notes from their original inputs, and a **shortcut presentation** path that shows exactly which keys the controller handles or leaves to macOS. Keep Cmd-Shift-M outside the performance event tap so closing the GUI cannot leave keyboard capture armed. This is an implementation plan, not a claim that the code or runtime has been changed.

## Architectural strategy

Treat root, scale, transposition, and selected chord type as inputs to a single note-generation pipeline. A played key or latched arp note should retain its source identity; its MIDI pitches are derived output, not the authoritative record. On a harmonic change, reconcile every affected track against those sources, rather than trying to transpose the pitches already stored in `heldNotes`. This matters because the repository already has separate per-track `heldNotes` and `targetHeldNotes`, and an `updateLatchedArpNotes()` path is called from some root and mode changes; neither fact establishes that sustained direct notes, chord changes, and all transposition entry points use the same refresh path.

Keep MIDI mutation in Lua. The HUD displays state and sends narrowly defined requests; it does not calculate replacement pitches. Preserve four independent arp clocks, channels, mute/solo rules, and the distinction between a selected chord-mode preset and a chord merely detected for display.

Make the shortcut matrix authoritative for both dispatch and display. Add an explicit Cmd preview layer, plus a Cmd-Shift view where Cmd-Shift-M reads “Close GUI.” A reserved cell displays its physical key and the command it is reserved for, but never fires a controller action. Classify **system-reserved** combinations separately from application shortcuts and configurable user conflicts; do not claim that every familiar Cmd shortcut is universally system-reserved.

## Data and interface contracts

The names below are **proposed interfaces** for the implementer to reconcile with current module exports during the initial audit, not assertions that these functions already exist.

| State | Owner and contract |
|---|---|
| `state.harmonyRevision: integer` | Increment once per committed root, mode, transpose, or chord-generation change. Quantized and delayed callbacks capture it and must not emit obsolete notes. |
| `trk.noteSources[sourceId]` | Stores `{kind, physicalCode?, basePitch?, row?, velocity, held, latched}` for each physical, KeyStep, or latched input. A source ID remains stable until that input is released or its latch is cleared. |
| `trk.renderedVoices[sourceId]` | Stores the exact `{channel, pitch, velocity}` outputs currently sounding for that source. Required for correct note-offs, including when chord expansion yields several notes. |
| `trk.heldNotes` / `trk.targetHeldNotes` | Continue as the arp’s derived playback sets; rebuild them from `noteSources` rather than using them as the sole record of source pitches. |
| `state.shortcutLayer` | One of the existing layers plus `cmd` and `cmdShift`, used for display. It is not permission to swallow Cmd events. |
| Shortcut descriptor | `{code, layer, disposition = "action" \| "reserved" \| "passThrough", action?, keyLabel, commandLabel?, reservationScope?}`. The same resolved descriptor feeds dispatch and HUD rendering. |
| `trk.volume` | Existing persisted 0–100 value remains authoritative. A track-card control edits this value; mute/solo audibility remains separate. |

Define these module boundaries:

- `transposer.renderSource(source, harmonyState, track) -> pitch[]`: pure, deterministic pitch generation, including selected chord voicing where applicable. Validate and deduplicate MIDI-range pitches.
- `arpeggiator.rebuildTrackNotes(trk, revision)`: rebuild `heldNotes` and `targetHeldNotes` from that track’s retained sources without restarting its clock or discarding latch ownership.
- `controls.commitHarmonyChange(mutator, reason)`: apply one validated change, increment the revision, reconcile arp and direct/sustained voices across tracks, persist as appropriate, then request one coalesced HUD update. All keyboard, GUI, and external-sync entry points that change these settings must converge here.
- `midi.reconcileSourceVoices(trk, sourceId, desiredPitches, revision)`: compare old and new output voices, issue only required note-offs and note-ons, and update the voice ledger. Shared pitches must use voice/source ownership so releasing one source cannot inadvertently terminate another.
- `controls.setTrackVolume(trackId, percent)`: clamp to 0–100, persist through the existing track settings path, emit CC 7 only when that track is audible, and update its displayed value. On restoration from mute/solo, the existing audibility path must send the current volume, not a stale value.
- `shortcuts.resolve(code, modifiers, context) -> descriptor`: one resolution result for event handling and visual labels. A `reserved` or `passThrough` result never calls `controls.executeAction`.
- `hud.requestClose(reason)`: idempotently disarm keyboard capture before hiding/destroying the GUI. Cmd-Shift-M calls this through one project-owned `hs.hotkey` registration, not through the MIDI key tap. Hammerspoon supports explicit hotkey enable/disable and event-tap stop/status operations.

## Logic flow and edge cases

1. **Register inputs.** On note-down, create or update a stable source entry on its owning track and derive pitches from the current harmony. Send direct voices through the MIDI voice ledger or register the derived notes with that track’s arp. On note-up, release by source ID—not by recomputing its pitch under the *new* root. Sustain and latch retain their source entries until their existing release rules clear them.
2. **Commit a harmonic change.** Validate the proposed root/mode/transpose/chord state first. After incrementing `harmonyRevision`, rebuild all four tracks’ arp note sets from retained sources. Reconcile sounding direct and sustained voices by turning off pitches no longer desired and turning on newly required pitches. Cancel or invalidate stale gate/quantizer callbacks before they can act on the previous generation.
3. **Preserve timing.** Do not restart an arp timer on a pitch-only change. If a gate is sounding an obsolete pitch, end that gate safely; its replacement plays on the next scheduled step. Preserve step position and direction where possible, normalizing the index if chord expansion changes the pattern length. A muted track still rebuilds its notes, but emits no new audible note until it becomes audible.
4. **Route Cmd safely.** On Cmd flag change, update the preview layer without consuming the modifier event. In the performance key tap, pass Cmd-modified key-down and key-up through unless an explicitly audited, safe binding owns the combination. Cmd-Shift-M belongs exclusively to the separate hotkey: its callback schedules an idempotent close, immediately disarms the performance tap on the close path, and cannot re-arm it while the GUI is hidden or unhealthy. The event tap API explicitly distinguishes stopping a tap from inspecting whether it is enabled.
5. **Render reserved holes.** For each physical key in the Cmd and Cmd-Shift views, render its key label plus either its controller action, or a distinct reserved treatment with a short command label—for example, a verified macOS-reserved combination would show the key and its actual macOS command. Leave unverified, application-specific conflicts labeled accordingly rather than silently marking them “system.” A reserved cell has no click action or controller dispatch.

Guard the transitions that can otherwise produce hung notes: root wrap and octave shift; repeated changes during a gate; two sources yielding the same pitch; chord voicings that change voice count; note releases during a pending quantization window; latch replacement; and panic. Panic must invalidate pending callbacks and clear source/output ledgers as well as the current arp state. Keep the chord badge’s existing off-mode behavior: live chord detection must not activate a dormant chord preset.

## Implementation steps

1. **Audit and baseline.** Capture Git status and baseline before edits; read `skills/custom-skills/scope-and-verification/SKILL.md`. Inventory every harmony mutation in `src/controls.lua`, `src/hud.lua`, `src/sync.lua`, and applicable package entry points. Trace source pitches through `src/transposer.lua`, `src/arpeggiator.lua`, `src/midi.lua`, and the quantizer. Inventory the actual keyboard dispatch, modifier precedence, hotkey registrations, and shortcut-rendering code. Resolve conflicting or legacy mappings before assigning a Cmd cell; do not infer the effective mapping solely from `layouts/default.json`, whose indexed labels differ from current `src/config.lua` mappings.
2. **`src/config.lua`.** Add only the minimum source/revision and shortcut-descriptor state needed; keep existing persisted track-volume keys and ranges unchanged. Define Cmd/Cmd-Shift descriptors and verified reservation labels centrally. If a shared package owns the canonical state or shortcut map, edit that source of truth and make the `src/` integration consume it—do not maintain divergent copies.
3. **`src/transposer.lua` and `src/arpeggiator.lua`** (and `packages/music-engine/arpeggiator.lua` if it is the canonical bundled implementation). Implement pure source-to-pitch derivation and per-track rebuilding. Replace or subsume `updateLatchedArpNotes()` only after auditing its callers and preserving its existing latch semantics.
4. **`src/midi.lua` and `src/controls.lua`.** Add source-owned direct/sustained voice reconciliation and generation guards. Route every root, scale, transpose, and selected-chord mutation through the commit function. Integrate volume edits with existing CC 7, persistence, and mute/solo restoration; ensure zero volume does not silently change the track’s mute setting.
5. **`src/init.lua` and the actual event-tap owner.** Register exactly one Cmd-Shift-M hotkey, clean it up on module teardown/reload, and make close disarm capture before GUI teardown. Keep Cmd shortcut preview observation separate from Cmd-key consumption. Avoid duplicate project bindings in Studio Suite and standalone modes: Hammerspoon notes that competing enabled bindings for the same combination displace one another.
6. **`src/hud.lua` and `src/web/index.html`.** Include four per-track volume values in the coalesced payload. Add compact `− / percent / +` controls to each track card, preserving fixed bounds, track colors, and the card’s selector and mute/solo hit areas. Add distinct Cmd and Cmd-Shift visuals and labeled reserved-hole styling; ensure key and command labels fit at supported zoom levels. Treat `src/ui_html.lua` as generated output from the production UI sync, not a separately edited source.
7. **Tests and activation.** Add targeted Bun/Lua tests for source retention, live changes to running and latched arps, sustained chord replacement, same-pitch ownership, stale callbacks, muted-track restoration, per-track volume persistence, shortcut/render parity, reserved-key pass-through, and close/reopen lifecycle. Then bundle, run `luac -p qwerty_midi.lua`, execute the project reload script on the target Mac, and observe the intended module and real keyboard/MIDI behavior. Web HMR alone does not verify Lua changes. Stage only task-owned paths or isolated hunks; commit and push after checks. If live Hammerspoon observation, a check, publication, or same-file ownership cannot be resolved, report that specific item as a blocker rather than marking implementation complete.
