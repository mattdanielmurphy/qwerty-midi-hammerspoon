# Fix Track Button Icons, Arp Latch State, Shift+A Binding & Modifier Octave Alignment

**Date**: 2026-09-16 23:20  
**Context**: Fixing UI row icon discrepancies on track buttons and modifier layer octave options, restoring the lock icon on the 3-state Arp button in Latch mode, and implementing functional Shift+A Latch toggling across the multi-track arpeggiator engine.

---

### Objectives & Root Causes
1. **Track Button Top/Bottom Row Icons**:
   - *Problem*: Track buttons 1–4 (keys `18`–`21`) were missing the stacked-row indicators distinguishing Bottom Row tracks (Tracks 1 & 2: Bass and Chords) from Top Row tracks (Tracks 3 & 4: Lead and Arp).
   - *Root Cause*: `renderHud` in `src/web/index.html` checked only legacy hardcoded action strings (`effAction === 'topOctDown' ...`) and had no handlers for `trkSelect1`..`trkSelect4` or track button keycodes.
   - *Fix*: In `src/hud.lua`, explicitly set `rowActive = (trkId <= 2) and "bottom" or "top"` in `keyUpdates[strCode]`. In `src/web/index.html`, added `rowTarget` resolution evaluating `k.rowActive`, regex track action matching, and keycode fallback. Styled `.key-pad.ctrl-track` row icons with matching track colors (`var(--trk-color)`).

2. **3-State Arp Button Missing Lock Icon in Latch Mode**:
   - *Problem*: In Latch mode, the 3-state Arp button (`A`, keycode 0) showed `Arp` without the lock icon `🔒`.
   - *Root Cause*: `PROPOSED_LAYOUT_MAP` unconditionally overwrote `keyUpdates["0"].displayNote = "Arp"` and `typeClass = "ctrl-arp"` on every update, wiping out the `Arp 🔒` and `.latch-mode-active` state set during key generation.
   - *Fix*: Added dynamic state evaluation in `PROPOSED_LAYOUT_MAP` in `src/hud.lua`: when active track arp latch is active, displays `Arp 🔒` (base layer) or `Latch 🔒` (shift layer) with `.latch-mode-active` and `.sustain-active`. Updated spotlight notification and `toggleArpPower` in `src/arpeggiator.lua` to display `ARP: LATCH 🔒`.

3. **Shift+A for Latch Did Nothing**:
   - *Problem*: Pressing `Shift+A` displayed "Latch" but pressing it did not latch notes or start the arp.
   - *Root Cause*: `executeControlAction` in `src/controls.lua` toggled legacy `state.arpLatchActive` and filtered unused `state.arpHeldNotes`, but never interacted with the multi-track engine (`state.tracks[state.activeTrack]`), never set `trk.arpEnabled`, and never started the arpeggiator clock.
   - *Fix*: Implemented `toggleArpLatch(targetTrackIdx)` in `src/arpeggiator.lua` and wired `act == "arpLatchToggle"` in `src/controls.lua`. When toggling Latch ON: activates `trk.arpEnabled`, `trk.arpLatchActive`, latches all currently physically held notes from `state.pressedKeys` into `trk.heldNotes`, and starts the clock timer. When toggling OFF: retains only physically held keys. Displays spotlight card targeting `key-0` with track color.

4. **Modifier Layer Octave Icons vs Key Labels Mismatch**:
   - *Problem*: Holding Option (showing "TopOct +") showed both rows active; holding Shift+Ctrl (showing "BotOct -") showed top row active.
   - *Root Cause*: `PROPOSED_LAYOUT_MAP` in `src/hud.lua` updated `displayNote` to `layerDef.name`, but never updated `keyUpdates[strCode].action` or `shiftAction` to `layerDef.action`. In JS, `effAction` resolved using the stale default actions (`octaveDown` on base, `topVolDown` on shift), producing completely mismatched row icons.
   - *Fix*: `PROPOSED_LAYOUT_MAP` in `src/hud.lua` now assigns `keyUpdates[strCode].action = layerDef.action`, `keyUpdates[strCode].shiftAction = layerDef.action`, and sets `rowActive = "top"`, `"bottom"`, or `"both"` depending on the action. `renderHud` in JS matches `rowActive` and evaluates label regexes (`TopOct`, `BotOct`, `Oct +/-`).

---

### Verification
- Tested via Hammerspoon CLI (`hs -c`) live in the running instance:
  - Track 1 (`#key-18`): `bottom-active` with cyan illumination.
  - Track 2 (`#key-19`): `bottom-active` with amber illumination.
  - Track 3 (`#key-20`): `top-active` with emerald illumination.
  - Track 4 (`#key-21`): `top-active` with magenta illumination.
  - Key D (`#key-2`):
    - Base layer ("Oct +"): `both-active`.
    - Shift layer ("Oct -"): `both-active`.
    - Option layer ("TopOct +"): `top-active`.
    - Shift+Option layer ("TopOct -"): `top-active`.
    - Control layer ("BotOct +"): `bottom-active`.
    - Shift+Control layer ("BotOct -"): `bottom-active`.
  - Shift+A (`arpLatchToggle`): toggles active track latch ON (`Latch 🔒`) and OFF cleanly with multi-track arpeggiator sync.
  - Key A 3-state Arp button: displays `Arp 🔒` with `.latch-mode-active` when in latch mode.
