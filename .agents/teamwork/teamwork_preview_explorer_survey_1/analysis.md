# Audio & MIDI Engine Survey and Technical Analysis

**Working Directory**: `/Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_explorer_survey_1`  
**Project Root**: `/Users/matt/projects/qwerty-midi-hammerspoon`  
**Author**: Survey Explorer 1 (Audio & MIDI Engine)  
**Timestamp**: 2026-10-11T16:48:00Z  

---

## Executive Summary

This investigation explores the core Audio & MIDI Engine of `qwerty-midi-hammerspoon` across requirements **R1** (Track Volume Control Keys), **R2** (Rich Arpeggiator Patterns & Human Feel), **R3** (Configurable Quantization Amount), **R6** (Stuck Note Mitigation & Watchdog Loop), and **R7** (Tap Tempo Functionality).

Key findings:
1. **R1 (Track Volume)**: No dedicated per-track volume keys currently exist. Volume is only adjustable for `state.activeTrack` or row pairs, and is inaccessible on the lower row when KeyStep is disconnected. Synchronous `saveSettings()` disk/IPC writes on every 80ms volume tick create a note-dropping bottleneck.
2. **R2 (Arpeggiator)**: The arpeggiator engine in `src/arpeggiator.lua` uses flat, static velocities (`math.min(127, trk.volume)`), rigid metronomic timers (`hs.timer.doEvery`), and only 7 basic pitch sorting permutations. Zero velocity contours, gate variations, or microtiming deviations are currently implemented.
3. **R3 (Quantization Amount)**: `packages/music-engine/quantizer.lua` only supports hard binary quantization (100% delay to grid line or "Off"). No `amount` or `strength` scaling exists; `state.inputQuantizeAmount` is absent from configuration and UI.
4. **R6 (Stuck Notes & Watchdog)**: Identified a fatal race condition in `packages/music-engine/quantizer.lua`: rapid consecutive key taps on the same key cancel `ev.gateTimer` before `onRelease` is fired, permanently stranding active MIDI notes in the synth voice engine. The existing `keyTapWatchdog` only monitors eventtap presence and webview heartbeats; no note-tracking watchdog exists.
5. **R7 (Tap Tempo)**: `src/controls.lua` line 2019 calls `if arpeggiator.tapTempo then arpeggiator.tapTempo() end`, but `arpeggiator.tapTempo` **was never implemented** in `src/arpeggiator.lua`, resulting in a silent failure and static HUD display.

---

## 1. R1: Track Volume Control Keys

### 1.1 Current Architecture & State Storage
Per-track volume is maintained in:
- `state.tracks[1..4].volume` (integer range `0..127`, default `100`).
- Row mirrors: `state.bottomRowVolume` (tracks 1 & 2) and `state.topRowVolume` (tracks 3 & 4) in `src/config.lua` lines 120–175.
- Persistence: Saved in `hs.settings` under keys `qwertyMidi_track1Volume` through `qwertyMidi_track4Volume`, `qwertyMidi_topRowVolume`, and `qwertyMidi_bottomRowVolume` (`src/config.lua`:224, 277–278).

### 1.2 MIDI CC 7 Handling
- Function `controls.adjustTrackVolume(trackId, delta)` (`src/controls.lua`:495–512):
  ```lua
  local function adjustTrackVolume(trackId, delta)
    local id = math.max(1, math.min(4, math.floor(tonumber(trackId) or 0)))
    local trk = state.tracks and state.tracks[id]
    if not trk then return false end
    trk.volume = math.max(0, math.min(127, (tonumber(trk.volume) or 100) + (tonumber(delta) or 0)))
    if isTrackAudible(id) then midi.sendMidiCC(7, trk.volume, trk.channel or (id - 1)) end
    if id <= 2 and state.bottomRowTrack == id then state.bottomRowVolume = trk.volume end
    if id >= 3 and state.topRowTrack == id then state.topRowVolume = trk.volume end
    config.saveSettings()
    hud.updateWebviewHud(...)
    return true
  end
  ```
- CC 7 transmission uses `midi.sendMidiCC(7, trk.volume, trk.channel)` which sends CoreMIDI Control Change 7 to the track's destination channel (`ch = 0..3`).

### 1.3 Key Mappings & Missing Dedicated Keys
1. **Absence of dedicated individual track volume keys**:
   - Keys 1, 2, 3, 4 (keycodes 18, 19, 20, 21 in `src/hud.lua`:396–435) are mapped across 8 modifier layers to:
     - `base`: `trkSelect1..4`
     - `shift`: `trkMute1..4`
     - `opt`: `trkSolo1..4`
     - `shift_opt`: `trkLock1..4`
     - `ctrl`: `trkRec1..4`
     - `shift_ctrl`: `trkClear1..4`
     - `ctrl_opt`: `trkFocus1..4` (redundant duplicate of `trkSelect1..4` calling `selectTrack(id)`)
     - `ctrl_opt_shift`: `panic`
   - None of the layers on keys 1–4 are mapped to volume.
2. **Current generic volume keys (`volUp` / `volDown`)**:
   - `volUp` / `volDown` in `src/controls.lua`:1316–1360 adjust ONLY `state.activeTrack`.
   - In `src/config.lua`:343–344, Shift+J was `volDown` and Shift+K was `volUp`, but this is **completely shadowed and overridden** by `PROPOSED_LAYOUT_MAP` in `src/hud.lua`:288–307 (where Shift+J is `trnspStep2Down` and Shift+K is `trnspStep2Up`).
   - In `defaultKeyStepLowerRowControls` (`src/config.lua`:733–734), key M is `volDown` and `,` is `volUp`. However, when KeyStep is disconnected, `src/config.lua`:746–770 reverts the lower row to note keys (`baseNote = 60..76`), leaving **no physical keys for volume**.
3. **Note-Dropping Mechanism During Volume Tweaking**:
   - When a user repeats volume adjustments (via `controlRepeatTimers` repeating every 80ms in `src/controls.lua`:2114), `config.saveSettings()` is called synchronously on every 80ms tick.
   - `saveSettings()` makes 25+ consecutive synchronous calls to `hs.settings.set(...)` (writing to CFPreferences/disk) and dispatches `sync.broadcastState(...)` (NSDistributedNotificationCenter IPC).
   - This disk and IPC bottleneck blocks the Hammerspoon runloop, delaying eventtap processing and causing macOS to drop subsequent note-on or note-off events.

### 1.4 Recommendations for R1
1. **Dedicated Key Bindings**:
   - Map `ctrl_opt` (or another dedicated combination) on keys 1, 2, 3, 4 to track volume control:
     - E.g., `trkVolDown1..4` on `ctrl_opt` and `trkVolUp1..4` on another open combination, OR provide dedicated Track 1–4 Volume + / - actions in `ACTION_CATALOG`.
     - Alternatively, map dedicated keys (e.g. number row or macro layer) to `trk1VolUp`/`trk1VolDown`, `trk2VolUp`/`trk2VolDown`, `trk3VolUp`/`trk3VolDown`, `trk4VolUp`/`trk4VolDown`.
2. **Non-Blocking Persistence**:
   - Throttle or debounce `config.saveSettings()` (e.g. 200–300ms debounce timer) during rapid volume repeating, or persist only the modified track setting (`hs.settings.set("qwertyMidi_track" .. id .. "Volume", trk.volume)`), allowing CC 7 to be dispatched immediately without disk lag.

---

## 2. R2: Rich Arpeggiator Patterns & Human Feel

### 2.1 Existing Pattern Engine (`src/arpeggiator.lua`)
- Currently supports 7 pitch sorting directions in `state.ARP_DIRECTIONS` (`src/config.lua`:58):
  1. `UP`: Ascending pitch sort (`(pos % #pitchList) + 1`).
  2. `DOWN`: Descending pitch sort.
  3. `UP-DOWN`: Bounces between endpoints.
  4. `DOWN-UP`: Inverted bounce.
  5. `CONVERGE`: Outer pitches inwards.
  6. `DIVERGE`: Center pitches outwards.
  7. `RANDOM`: Pseudo-random selection (`math.random(1, #pitchList)`).
- All 7 patterns manipulate solely the pitch sort order. There are **zero rhythm patterns, zero octave-cycling patterns, and zero melodic templates**.

### 2.2 Velocity Contours
- Current velocity assignment in `src/arpeggiator.lua`:419:
  ```lua
  local vel = math.floor(math.min(127, (trk.volume or 100) * 1.0))
  ```
- Every step is emitted at an identical static velocity.
- There are no velocity accents on downbeats, no crest/valley contour curves, no groove accenting (e.g. strong beat 1, soft offbeats), and no human velocity variance.

### 2.3 Gate Lengths
- Current gate calculation in `src/arpeggiator.lua`:418, 441:
  ```lua
  local gateRatio = (trk.arpGatePercent or state.arpGatePercent or 80.0) / 100.0
  local gateDuration = trackStepSec * gateRatio
  ```
- Every note has a fixed, uniform gate duration. No alternating staccato/tenuto patterns or organic gate fluctuations exist.

### 2.4 Timing Deviations & Microtiming
- The arpeggiator clock timer is created in `src/arpeggiator.lua`:502–504:
  ```lua
  trk.timer = hs.timer.doEvery(intervalSeconds, function()
    arpTickTrack(trk)
  end)
  ```
- `hs.timer.doEvery` runs strictly on metronomic, rigid ticks.
- There is zero swing/shuffle, zero microtiming deviation, and zero human feel.

### 2.5 Clean Implementation Strategy for R2
1. **Diverse Arp Patterns**:
   - Expand beyond simple pitch permutations by adding rhythmic and octave patterns:
     - `Octave Cycle (+12)`: Notes cycle through original octave, then +12 semitones.
     - `Thumb / Pedal Bass`: Alternates lowest bass note with melody notes (e.g., Bass, Note 1, Bass, Note 2...).
     - `Pinky / Top Pedal`: Holds highest note as anchor while lower voices arpeggiate.
     - `Euclidean / Syncopated Pulse`: Rhythmic gate patterns (e.g., 3-3-2 syncopation, Euclidean (3,8) and (5,8)).
2. **Dynamic Velocity Contours**:
   - Provide selectable velocity contours:
     - *Downbeat Accent*: Beat 1 accented by $+18$ vel, offbeats $-10$ vel.
     - *Groove Pulse*: Beats 1 & 3 accented, 2 & 4 natural.
     - *Crescendo/Decrescendo Curve*: Dynamic wave modulating over 4 or 8 bars.
     - *Human Feel Velocity*: Gaussian or bounded random jitter $\pm 5..10$ velocity.
3. **Dynamic Microtiming & Human Feel Engine**:
   - Replace rigid `hs.timer.doEvery` with chained dynamic scheduling:
     ```lua
     local function scheduleNextArpTick(trk)
       local baseStepSec = (60.0 / state.arpBpm) * rateFactor
       local timingOffset = calculateHumanMicrotiming(trk) -- Swing offset + human jitter
       local nextInterval = math.max(0.020, baseStepSec + timingOffset)
       trk.timer = hs.timer.doAfter(nextInterval, function()
         arpTickTrack(trk)
         if trk.arpEnabled then scheduleNextArpTick(trk) end
       end)
     end
     ```
   - Microtiming components:
     - *Swing*: Delays even eighth/sixteenth steps by configurable swing factor ($50\%$ to $70\%$).
     - *Microtiming Jitter*: Microsecond-scale organic fluctuation ($\pm 2..6\text{ms}$), delivering authentic human feel without drifting off master tempo.

---

## 3. R3: Configurable Quantization Amount

### 3.1 Grid Alignment Mechanism (`packages/music-engine/quantizer.lua`)
- In `quantizer.calculateDelay(bpm, mode)` (lines 36–64):
  ```lua
  local quarterSec = 60.0 / clampedBpm
  local stepDuration = quarterSec * factor
  local now = hs.timer.absoluteTime() / 1e9
  local elapsed = (now - gridReferenceTime) % stepDuration
  local timeToNext = stepDuration - elapsed

  if timeToNext <= 0.012 then return 0 end
  if elapsed <= 0.020 then return 0 end
  return timeToNext
  ```
- If a note is struck within 12ms before the beat or 20ms after, it triggers immediately (`delay = 0`). Otherwise, it is delayed by `timeToNext` to align with the next grid tick.

### 3.2 Current Configuration & Missing Amount Parameter
- `src/config.lua` lines 84, 262 only defines `inputQuantizeMode` (`"Off"`, `"1/1"`, `"1/2"`, `"1/4"`, `"1/8"`, `"1/16"`, `"1/32"`).
- Quantization is currently **all-or-nothing**: either 100% hard delay to the grid line, or 0% (when mode is "Off").
- There is **no quantization amount or strength parameter** in `quantizer.lua`, `config.lua`, `controls.lua`, or `settings_ui.lua`.

### 3.3 Implementation Blueprint for 0–100% (Default 90%)
1. **Config & State**:
   - Add `inputQuantizeAmount = getSetting("inputQuantizeAmount", 90)` in `src/config.lua`.
   - Persist in `saveSettings()`: `hs.settings.set("qwertyMidi_inputQuantizeAmount", state.inputQuantizeAmount)`.
2. **Delay Calculation with Quantize Strength**:
   - In `quantizer.calculateDelay(bpm, mode, amount)`:
     ```lua
     local strength = math.max(0.0, math.min(1.0, (amount ~= nil and tonumber(amount) or 90.0) / 100.0))
     if strength <= 0.0 then return 0 end
     
     -- Pull note towards grid tick proportional to strength
     local effectiveDelay = timeToNext * strength
     if effectiveDelay <= 0.012 then return 0 end
     return effectiveDelay
     ```
   - At 100%, delay equals `timeToNext` (hard quantization).
   - At 90% (default), delay equals $0.90 \times \text{timeToNext}$, pulling notes 90% towards the beat while preserving 10% of player microtiming.
   - At 0%, delay is 0 (instant unquantized playback).
3. **Dispatch & UI**:
   - Pass `state.inputQuantizeAmount` from `controls.handleKeyDown` into `quantizer.queueNoteOn`.
   - Expose quantize strength selector in HUD header / Settings UI.

---

## 4. R6: Stuck Note Mitigation & Watchdog Loop

### 4.1 Diagnosis of Note-Off Drops Under Quantization
During rapid consecutive key playback under input quantization, note-offs are dropped due to three distinct failure points:

#### Root Cause 1: Fatal Cancellation of `ev.gateTimer` in `quantizer.lua` (Lines 84–88 & 235–255)
When a user plays staccato keys under quantization:
1. Key Down: `queueNoteOn("qwerty_" .. code, ...)` schedules grid delay timer `ev.timer`.
2. Key Up (fast tap): `queueNoteOff` marks `ev.released = true` and stores `ev.onRelease`.
3. `ev.timer` expires: it sends Note-On to MIDI, and schedules staccato release timer `ev.gateTimer = hs.timer.doAfter(gateTime, ...)` to send Note-Off after 60ms.
4. Second Key Down (rapid re-trigger before 60ms): `queueNoteOn("qwerty_" .. code, ...)` runs. Lines 84–88 execute:
   ```lua
   if pendingEvents[eventId] then
     if pendingEvents[eventId].timer then pcall(function() pendingEvents[eventId].timer:stop() end) end
     if pendingEvents[eventId].gateTimer then pcall(function() pendingEvents[eventId].gateTimer:stop() end) end
     pendingEvents[eventId] = nil
   end
   ```
5. **The bug**: `gateTimer` is stopped without calling `ev.onRelease`! The Note-On had already fired on the synthesizer in step 3, but its Note-Off timer is killed.
6. The synthesizer voice never receives a Note-Off message and rings indefinitely.

#### Root Cause 2: Sounding Notes Identity Exclusion (Lines 95 & 143)
- In `queueNoteOn`, active release checks filter with `if sEntry.channel == ch and sId ~= eventId then`.
- If the exact same key (`sId == eventId`) is re-triggered while in `graceTimer`, it is excluded from release handling and bypassed, leaving the voice orphaned in `soundingNotes`.

#### Root Cause 3: Smart Sustain Multi-Note Grouping Window (`src/controls.lua`:2175–2200)
- In Smart Sustain mode, `isNewChord = (numPhysHeld == 0) or ((now - chordStartTime) > 0.12)`.
- If rapid consecutive notes are struck with overlapping fingerings within 120ms under quantize delay, previous sustained notes are not cleared, causing voice accumulation.

### 4.2 Current Watchdog Status
- Current `keyTapWatchdog` (`src/init.lua`:418–445):
  - Ticks every 3.0 seconds.
  - ONLY verifies that `midiKeyTap:isEnabled()` is true and checks webview heartbeat (`lastSeen < 5s`).
  - **Does NOT inspect active MIDI notes, does NOT inspect `activeNoteLedger`, and does NOT perform stuck note cleanup.**

### 4.3 Clean Implementation Strategy for R6
1. **Fix `quantizer.lua` Note-Off Guarantee**:
   - In `queueNoteOn`, before stopping or replacing `pendingEvents[eventId]`:
     ```lua
     if pendingEvents[eventId] and pendingEvents[eventId].onFired and not pendingEvents[eventId].releasedDone then
       if pendingEvents[eventId].onRelease then
         pendingEvents[eventId].onRelease(pendingEvents[eventId].pitches, pendingEvents[eventId].channel)
       end
     end
     ```
   - Handle `sId == eventId` in `soundingNotes` to ensure re-triggered keys properly release prior sounding pitches before starting new attacks.
2. **Automatic Stuck Note Watchdog Loop**:
   - Integrate into the existing `keyTapWatchdog` lifecycle in `src/init.lua` (which already adheres to the **Zero Idle Event Taps & Timers Invariant**: starts in `toggleMidiMode(true)` and stops in `disarmMidiInput()`):
   - At each 3-second watchdog tick:
     1. Inspect `activeNoteLedger` from `src/midi.lua`:
     2. Identify any sounding voice `(noteNum, ch)` where:
        - No physical key in `state.pressedKeys` is held.
        - Arpeggiator is not actively playing the note (`trk.currentPitch ~= noteNum`).
        - Track sustain is not holding it (or controller is disarmed/idle).
        - No pending quantizer event holds it.
        - Voice has been active longer than max threshold ($> 6\text{s}$).
     3. If an orphaned voice is detected, dispatch `midi.sendMidiNote("noteOff", noteNum, 0, ch)` and remove from `activeNoteLedger`.
     4. Log the auto-recovery event to `~/.hammerspoon/qwerty_midi_watchdog.log`.

---

## 5. R7: Tap Tempo Functionality

### 5.1 Diagnosis of Failure
In `src/controls.lua`:2018–2023:
```lua
elseif act == "tapTempo" then
  if arpeggiator.tapTempo then
    arpeggiator.tapTempo()
  end
  hud.updateWebviewHud({ title = "TAP TEMPO", value = arpeggiator.formatBpm(state.arpBpm) .. " BPM", subtext = "Tap rhythm to set tempo", targetId = "key-24", color = "#ffd700" })
```
- A grep across `src/arpeggiator.lua` and `packages/music-engine/` confirms that `tapTempo` **does not exist anywhere in the codebase**.
- Because `arpeggiator.tapTempo` is `nil`, triggering the key action (Key `=` with Ctrl modifier, code 24) performs a silent no-op.
- The HUD simply displays whatever `state.arpBpm` happened to be previously without calculating a new BPM.

### 5.2 Tap Tempo Engine Architecture
To accurately track tap intervals and calculate BPM, `src/arpeggiator.lua` requires a dedicated tap tempo engine:
1. **Timestamp History**:
   - Store timestamps of recent taps using `hs.timer.absoluteTime() / 1e9` (nanosecond-precision converted to seconds).
   - If interval between current tap and previous tap exceeds $2.0$ seconds ($< 30$ BPM), discard history and treat current tap as the first beat of a new sequence.
2. **Rolling Window & Averaging**:
   - Maintain a rolling window of the last $N = 4..8$ taps.
   - For $N \ge 2$, calculate inter-tap intervals: $\Delta t_i = t_i - t_{i-1}$.
   - Reject outlier intervals ($> 1.8\times$ or $< 0.5\times$ median) if $N \ge 4$.
   - Calculate average interval $\overline{\Delta t} = \frac{1}{k} \sum \Delta t_i$.
3. **BPM Calculation & Propagation**:
   - $\text{bpm} = \frac{60.0}{\overline{\Delta t}}$.
   - Clamp BPM to valid range $[20.0, 300.0]$.
   - Round to nearest 0.5 or 1.0 BPM: `math.floor(bpm + 0.5)`.
   - Update `state.arpBpm = bpm`.
   - Call `applyBpmChange()` (already implemented in `src/arpeggiator.lua`:738) to immediately update running arpeggiator clock intervals.
   - Save settings via `config.saveSettings()`.
   - Export `arpeggiator.tapTempo` in module return table.

---

## 6. Synthesis and Conflict Resolution

| Component | Consensus Finding | Dissent / Alternative | Resolution |
|---|---|---|---|
| **R1 (Volume Keys)** | Dedicated volume keys are missing; synchronous `saveSettings` drops notes during repeat. | Should volume keys be on Number Row (Keys 1–4) or dedicated hotkeys? | Reclaim redundant `ctrl_opt` on Keys 1–4 (`trkFocus1..4`) for track volume control, or provide dedicated keys in `ACTION_CATALOG`. Debounce `saveSettings()`. |
| **R2 (Arpeggiator)** | Velocities are flat, gates are static, timers are metronomic `hs.timer.doEvery`. | Is human feel achieved via swing or microtiming jitter? | Both: implement swing factor ($50..70\%$) on even steps + bounded microtiming jitter ($\pm 2..6\text{ms}$) via dynamic `doAfter` rescheduling. |
| **R3 (Quantize Amount)** | `quantizer.lua` only supports binary 100% or Off. | Should 90% pull early and late notes symmetrically? | Scale `timeToNext * (amount / 100)` so notes land 90% closer to the beat, preserving 10% player timing. Default to 90%. |
| **R6 (Stuck Notes)** | Rapid re-trigger stops `ev.gateTimer` without calling `onRelease`, causing hung notes. | Rely only on Panic key vs Automatic Watchdog loop? | Both: fix root cause in `quantizer.lua` to guarantee `onRelease` execution, AND add active note watchdog in `keyTapWatchdog` running strictly when `state.midiActive == true`. |
| **R7 (Tap Tempo)** | `arpeggiator.tapTempo` is missing and never existed. | Fixed 4-tap average vs outlier-rejected rolling window? | Outlier-rejected rolling window ($N = 4..8$, 2.0s timeout), rounded to integer BPM, calling `applyBpmChange()`. |

---

## 7. Next Steps for Implementers

1. **R1**: Implement `adjustTrackVolume` debounce; map dedicated per-track volume controls on modifier layers or action catalog.
2. **R2**: Implement rhythm templates, velocity contours, and dynamic `doAfter` human microtiming in `src/arpeggiator.lua`.
3. **R3**: Add `inputQuantizeAmount` (default 90%) in `src/config.lua` and scale `calculateDelay` in `packages/music-engine/quantizer.lua`.
4. **R4 & R5** (UI Explorer): Verify key label wrapping under Cmd modifier, suppress overlapping pass-through labels, and bind real-time parameter state to key surfaces.
5. **R6**: Patch `ev.gateTimer` cancellation in `quantizer.lua` and add orphaned note detection to `keyTapWatchdog` in `src/init.lua`.
6. **R7**: Implement `arpeggiator.tapTempo` in `src/arpeggiator.lua` with interval averaging and `applyBpmChange()`.
