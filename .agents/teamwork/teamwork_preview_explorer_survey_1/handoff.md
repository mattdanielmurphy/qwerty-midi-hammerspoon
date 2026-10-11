# Handoff Report: Audio & MIDI Engine Survey (R1, R2, R3, R6, R7)

**Agent**: Survey Explorer 1 (Audio & MIDI Engine)  
**Working Directory**: `/Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_explorer_survey_1`  
**Target Recipient**: Parent Orchestrator / Implementer Agents  
**Timestamp**: 2026-10-11T16:50:00Z  

---

## 1. Observation

### 1.1 R1: Track Volume Control Keys & CC 7 Handling
- **File**: `src/config.lua` lines 127–176, 224:
  Per-track volume is stored in `state.tracks[i].volume` (default 100, range 0..127) and persisted via `hs.settings.set("qwertyMidi_track" .. i .. "Volume", trk.volume or 100)`.
- **File**: `src/controls.lua` lines 495–512:
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
- **File**: `src/hud.lua` lines 395–435 (`PROPOSED_LAYOUT_MAP`):
  Keys 1, 2, 3, 4 (keycodes 18, 19, 20, 21) are mapped to: `base = trkSelect1..4`, `shift = trkMute1..4`, `opt = trkSolo1..4`, `shift_opt = trkLock1..4`, `ctrl = trkRec1..4`, `shift_ctrl = trkClear1..4`, `ctrl_opt = trkFocus1..4`, `ctrl_opt_shift = panic`.
  No volume actions are mapped on keys 1–4.
- **File**: `src/controls.lua` lines 1316–1360:
  `volUp` and `volDown` modify only `state.activeTrack` (`activeTrkId = state.activeTrack or 1`).
- **File**: `src/controls.lua` lines 2110–2122:
  Volume adjustments repeating via `controlRepeatTimers` run `hs.timer.doEvery(0.08, ...)` where every 80ms tick calls `saveSettings()`. In `src/config.lua`:197–285, `saveSettings()` performs 25+ calls to `hs.settings.set()` and `sync.broadcastState()`.

### 1.2 R2: Rich Arpeggiator Patterns & Human Feel
- **File**: `src/arpeggiator.lua` line 419:
  ```lua
  local vel = math.floor(math.min(127, (trk.volume or 100) * 1.0))
  ```
  Every arpeggiator step executes with static, flat velocity. No downbeat accents, contours, or human velocity variances exist.
- **File**: `src/arpeggiator.lua` lines 418, 441:
  ```lua
  local gateRatio = (trk.arpGatePercent or state.arpGatePercent or 80.0) / 100.0
  local gateDuration = trackStepSec * gateRatio
  ```
  Gate length is uniformly fixed across all steps.
- **File**: `src/arpeggiator.lua` lines 502–504:
  ```lua
  trk.timer = hs.timer.doEvery(intervalSeconds, function()
    arpTickTrack(trk)
  end)
  ```
  Clock intervals are metronomic and unvarying. Zero microtiming jitter or swing deviations exist.
- **File**: `src/config.lua` line 58:
  ```lua
  ARP_DIRECTIONS = { "UP", "DOWN", "UP-DOWN", "DOWN-UP", "CONVERGE", "DIVERGE", "RANDOM" }
  ```
  All 7 patterns strictly manipulate pitch sorting order. Zero rhythm or octave templates exist.

### 1.3 R3: Configurable Quantization Amount
- **File**: `packages/music-engine/quantizer.lua` lines 36–64:
  `quantizer.calculateDelay(bpm, mode)` computes `timeToNext = stepDuration - elapsed`. If `timeToNext <= 0.012` or `elapsed <= 0.020`, it returns 0. Otherwise, it returns full `timeToNext`.
- **File**: `src/config.lua` lines 84, 262:
  `inputQuantizeMode = getSetting("inputQuantizeMode", "Off")`.
  No parameter or setting exists for quantization amount/strength. Notes are either delayed 100% to the grid or 0% ("Off").

### 1.4 R6: Stuck Note Mitigation & Watchdog Loop
- **File**: `packages/music-engine/quantizer.lua` lines 84–88:
  ```lua
  if pendingEvents[eventId] then
    if pendingEvents[eventId].timer then pcall(function() pendingEvents[eventId].timer:stop() end) end
    if pendingEvents[eventId].gateTimer then pcall(function() pendingEvents[eventId].gateTimer:stop() end) end
    pendingEvents[eventId] = nil
  end
  ```
- **File**: `packages/music-engine/quantizer.lua` lines 235–255:
  When a staccato key is released before the quantize delay arrives, `ev.released = true` is flagged. When `ev.timer` fires, `onTrigger` sends Note-On to MIDI, and schedules `ev.gateTimer = hs.timer.doAfter(gateTime, function() ... ev.onRelease(pitches, ch) end)`.
  If the key is re-triggered during `gateTime`, `queueNoteOn` halts `pendingEvents[eventId].gateTimer` in line 86 without calling `ev.onRelease`.
  The active MIDI note remains sounding forever.
- **File**: `src/init.lua` lines 418–445:
  `_G.activeWatchers.keyTapWatchdog` ticks every 3.0s, but only checks `midiKeyTap:isEnabled()` and webview heartbeat. It does not inspect `activeNoteLedger` or clear orphaned notes.

### 1.5 R7: Tap Tempo Functionality
- **File**: `src/controls.lua` lines 2018–2023:
  ```lua
  elseif act == "tapTempo" then
    if arpeggiator.tapTempo then
      arpeggiator.tapTempo()
    end
    hud.updateWebviewHud({ title = "TAP TEMPO", value = arpeggiator.formatBpm(state.arpBpm) .. " BPM", subtext = "Tap rhythm to set tempo", targetId = "key-24", color = "#ffd700" })
  ```
- **Tool Search**: Grep for `tapTempo` across `src/arpeggiator.lua` returned zero results. `arpeggiator.tapTempo` is completely missing from the module.

---

## 2. Logic Chain

1. **R1**:
   - From 1.1, `adjustTrackVolume(trackId, delta)` exists and sends MIDI CC 7 correctly, but has no key bindings in `PROPOSED_LAYOUT_MAP`.
   - `volUp`/`volDown` only change `activeTrack`, and lower row volume keys disappear when KeyStep is disconnected.
   - Synchronous `config.saveSettings()` on every 80ms volume repeat blocks the event thread, directly causing dropped note events under rapid playback.
   - Therefore, dedicated key bindings for tracks 1–4 are required, and `saveSettings()` must be debounced during active volume adjustment.
2. **R2**:
   - From 1.2, `arpeggiator.lua` uses a fixed `vel` and a rigid `hs.timer.doEvery`.
   - Because `hs.timer.doEvery` enforces strict periodic intervals, microtiming deviations and swing are mathematically impossible without dynamic step scheduling.
   - Therefore, dynamic `hs.timer.doAfter` scheduling with swing offset and microtiming jitter, coupled with velocity contour templates (downbeat accent, groove pulse, human variance), must be added.
3. **R3**:
   - From 1.3, `calculateDelay` computes `timeToNext` without any scaling factor.
   - Music production standard quantization strength scales the shift distance towards the grid tick by `amount / 100`.
   - Therefore, adding `inputQuantizeAmount` (default 90) and multiplying `timeToNext * (amount / 100)` provides configurable 0–100% quantization.
4. **R6**:
   - From 1.4, when a note has already fired (`ev.onFired == true`) and is waiting for `ev.gateTimer` to release, canceling `ev.gateTimer` without executing `ev.onRelease` permanently leaks an active MIDI voice.
   - The lack of active note ledger inspection in `keyTapWatchdog` allows orphaned voices to ring indefinitely until panic.
   - Therefore, `queueNoteOn` must guarantee `onRelease` before overwriting pending events, and `keyTapWatchdog` must monitor `activeNoteLedger` when armed and release orphaned notes.
5. **R7**:
   - From 1.5, `controls.lua` checks `if arpeggiator.tapTempo then arpeggiator.tapTempo() end`.
   - Because `arpeggiator.tapTempo` is nil, the call fails silently.
   - Therefore, implementing `arpeggiator.tapTempo` with a rolling interval buffer (2s timeout, median/average calculation) and calling `applyBpmChange()` fixes tap tempo.

---

## 3. Caveats

- **Key Step Hardware Disconnect**: Testing must verify behavior both when KeyStep hardware is attached (where lower row is control keys) and disconnected (where lower row reverts to notes).
- **Zero Idle Event Taps Invariant**: The stuck note watchdog MUST NOT run while `state.midiActive == false`. It must be tied to the lifecycle of `keyTapWatchdog` (started on `toggleMidiMode(true)` and stopped on `disarmMidiInput()`).
- **Web UI Rendering**: Key label text wrapping and state indicators (R4 & R5) belong to the UI layer (`src/web/index.html` and `src/hud.lua`), investigated by peer Survey Explorer 2.

---

## 4. Conclusion

The Audio & MIDI Engine has a solid architectural core (`midi.lua`, `quantizer.lua`, `arpeggiator.lua`, `controls.lua`), but suffers from five distinct gaps:
1. **R1**: Lacks dedicated per-track volume keys; repeat triggers cause synchronous I/O note drops.
2. **R2**: Arpeggiator lacks dynamic velocity contours, variable gate lengths, and microtiming/swing.
3. **R3**: Quantizer lacks strength scaling; only supports binary 100% or Off.
4. **R6**: Staccato quantize re-trigger kills release gate timers, causing stuck notes. Existing watchdog does not inspect active voices.
5. **R7**: Tap tempo is a silent no-op due to missing `arpeggiator.tapTempo` implementation.

All five root causes are cleanly localized and resolvable with targeted changes.

---

## 5. Verification Method

To independently verify these findings:
1. **Run Project Test Suite**:
   ```bash
   bun test
   ```
   (Expected: all 77 tests pass, establishing baseline stability).
2. **Inspect Specific Source Locations**:
   - `src/controls.lua:2018–2023` to verify `arpeggiator.tapTempo` is unhandled.
   - `packages/music-engine/quantizer.lua:84–88` to verify `gateTimer` cancellation without `onRelease`.
   - `src/hud.lua:396–435` to verify lack of volume actions on keys 1–4.
   - `src/arpeggiator.lua:419, 502–504` to verify flat velocity and metronomic `doEvery`.
3. **Invalidation Conditions**:
   - If `arpeggiator.tapTempo` is found in another module, R7 analysis must be updated.
   - If `saveSettings()` is already asynchronous, R1 performance analysis must be revised.
