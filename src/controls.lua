local config = require("config")
local midi = require("midi")
local transposer = require("transposer")
local arpeggiator = require("arpeggiator")
local quantizer = require("quantizer")
local hud = require("hud")

local state = config.state
local SCALES = config.SCALES
local NOTE_NAMES = config.NOTE_NAMES

local function getActiveArpRateIdx()
  local trk = state.tracks and state.tracks[state.activeTrack or 1]
  return (trk and trk.arpRateIdx) or state.arpRateIdx or 5
end

local function setActiveArpRate(rateIdx)
  if arpeggiator.setTrackArpRate then
    return arpeggiator.setTrackArpRate(rateIdx, state.activeTrack or 1)
  end

  state.arpRateIdx = math.max(1, math.min(#state.ARP_RATES, tonumber(rateIdx) or state.arpRateIdx or 5))
  arpeggiator.applyBpmChange()
  return nil, state.arpRateIdx
end

local function getActiveArpDirectionIdx()
  local trk = state.tracks and state.tracks[state.activeTrack or 1]
  return (trk and trk.arpDirectionIdx) or state.arpDirectionIdx or 1
end

local function setActiveArpDirection(dirIdx, targetTrackIdx)
  if arpeggiator.setTrackArpDirection then
    return arpeggiator.setTrackArpDirection(dirIdx, targetTrackIdx or state.activeTrack or 1)
  end

  local trkId = targetTrackIdx or state.activeTrack or 1
  local normalizedDirIdx = math.max(1, math.min(#state.ARP_DIRECTIONS, tonumber(dirIdx) or state.arpDirectionIdx or 1))
  state.arpDirectionIdx = normalizedDirIdx
  local trk = state.tracks and state.tracks[trkId]
  if trk then
    trk.arpDirectionIdx = normalizedDirIdx
    hs.settings.set("qwertyMidi_track" .. trkId .. "ArpDirectionIdx", normalizedDirIdx)
  end
  hs.settings.set("qwertyMidi_arpDirectionIdx", normalizedDirIdx)
  return trk, normalizedDirIdx
end

_G.activeWatchers = _G.activeWatchers or {}

-- Clear any stale repeat timers from a previous module load (Hammerspoon reload safety)
if _G._qmidiRepeatTimers then
  for code, entry in pairs(_G._qmidiRepeatTimers) do
    pcall(function()
      if entry.timer then entry.timer:stop() end
      if entry.interval then entry.interval:stop() end
    end)
  end
end
_G._qmidiRepeatTimers = {}
local controlRepeatTimers = _G._qmidiRepeatTimers

local function stopControlRepeat(code)
  if code and controlRepeatTimers[code] then
    pcall(function()
      if controlRepeatTimers[code].timer then
        controlRepeatTimers[code].timer:stop()
      end
      if controlRepeatTimers[code].interval then
        controlRepeatTimers[code].interval:stop()
      end
    end)
    controlRepeatTimers[code] = nil
  end
end

local function stopAllControlRepeats()
  for code in pairs(controlRepeatTimers) do
    stopControlRepeat(code)
  end
end

local stateUndoStack = {}
local stateRedoStack = {}
local isRestoringControllerState = false

local function captureStateSnapshot(label)
  return {
    label = label or "State Change",
    currentRoot = state.currentRoot,
    currentScaleIdx = state.currentScaleIdx,
    octaveShift = state.octaveShift,
    topRowOctaveOffset = state.topRowOctaveOffset,
    bottomRowOctaveOffset = state.bottomRowOctaveOffset,
    transposeShift = state.transposeShift,
    topRowVolume = state.topRowVolume,
    bottomRowVolume = state.bottomRowVolume,
    arpEnabled = state.arpEnabled,
    arpLatchActive = state.arpLatchActive,
    arpDirectionIdx = state.arpDirectionIdx,
    arpRateIdx = state.arpRateIdx,
    arpGatePercent = state.arpGatePercent,
    arpBpm = state.arpBpm,
    arpTopEnabled = state.arpTopEnabled,
    arpBottomEnabled = state.arpBottomEnabled,
    arpLinked = state.arpLinked,
    modWheel = state.ccStates[1] or 0,
    sustainActive = state.sustainActive,
    chordModeActive = state.chordModeActive
  }
end

local function pushStateSnapshot(label)
  if isRestoringControllerState then return end
  table.insert(stateUndoStack, captureStateSnapshot(label))
  stateRedoStack = {}
end

local function applyStateSnapshot(snap)
  isRestoringControllerState = true

  -- Capture current values before overwriting so we can skip no-op arp restarts
  local prevBpm = state.arpBpm
  local prevGatePercent = state.arpGatePercent

  state.currentRoot = snap.currentRoot
  state.currentScaleIdx = snap.currentScaleIdx
  state.octaveShift = snap.octaveShift
  state.topRowOctaveOffset = snap.topRowOctaveOffset
  state.bottomRowOctaveOffset = snap.bottomRowOctaveOffset or 0
  state.transposeShift = snap.transposeShift
  state.topRowVolume = snap.topRowVolume
  state.bottomRowVolume = snap.bottomRowVolume
  state.arpEnabled = snap.arpEnabled
  state.arpLatchActive = snap.arpLatchActive
  state.arpDirectionIdx = snap.arpDirectionIdx
  setActiveArpRate(snap.arpRateIdx)
  state.arpGatePercent = snap.arpGatePercent
  state.arpBpm = snap.arpBpm
  state.arpTopEnabled = snap.arpTopEnabled
  state.arpBottomEnabled = snap.arpBottomEnabled
  if snap.arpLinked ~= nil then state.arpLinked = snap.arpLinked end
  state.ccStates[1] = snap.modWheel
  
  if snap.sustainActive ~= nil then state.sustainActive = snap.sustainActive end
  if snap.chordModeActive ~= nil then state.chordModeActive = snap.chordModeActive end

  arpeggiator.updateLatchedArpNotes()
  if snap.arpBpm ~= prevBpm then
    arpeggiator.applyBpmChange()
  end
  if snap.arpGatePercent ~= prevGatePercent then
    arpeggiator.applyGatePercentChange()
  end
  midi.sendMidiCC(1, snap.modWheel)

  isRestoringControllerState = false
  config.saveSettings()
end

local function undoControllerState(code)
  if #stateUndoStack == 0 then
    local spot = {
      title = "UNDO STATE",
      value = "NO HISTORY",
      subtext = "Nothing to undo",
      targetId = code and ("key-" .. code) or "header",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
    return
  end

  local cur = captureStateSnapshot("Current")
  table.insert(stateRedoStack, cur)

  local prev = table.remove(stateUndoStack)
  applyStateSnapshot(prev)

  local scaleName = SCALES[state.currentScaleIdx].name
  local rootName = NOTE_NAMES[state.currentRoot + 1]
  local spot = {
    title = "UNDO STATE",
    value = rootName .. " " .. scaleName,
    subtext = "Reverted: " .. (prev.label or "Controller State"),
    targetId = code and ("key-" .. code) or "header",
    color = "#d4a359"
  }
  hud.updateWebviewHud(spot)
end

local function redoControllerState(code)
  if #stateRedoStack == 0 then
    local spot = {
      title = "REDO STATE",
      value = "NO HISTORY",
      subtext = "Nothing to redo",
      targetId = code and ("key-" .. code) or "header",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
    return
  end

  local cur = captureStateSnapshot("Current")
  table.insert(stateUndoStack, cur)

  local nxt = table.remove(stateRedoStack)
  applyStateSnapshot(nxt)

  local scaleName = SCALES[state.currentScaleIdx].name
  local rootName = NOTE_NAMES[state.currentRoot + 1]
  local spot = {
    title = "REDO STATE",
    value = rootName .. " " .. scaleName,
    subtext = "Re-applied: " .. (nxt.label or "Controller State"),
    targetId = code and ("key-" .. code) or "header",
    color = "#d4a359"
  }
  hud.updateWebviewHud(spot)
end

local function canApplyShifts(testT, testO, testTop, testBot)
  local oldT = state.transposeShift
  local oldO = state.octaveShift
  local oldTop = state.topRowOctaveOffset
  local oldBot = state.bottomRowOctaveOffset

  -- Calculate bounds for current state
  local curMinPitch = math.huge
  local curMaxPitch = -math.huge
  for _, kData in pairs(config.getActiveNoteKeysMap()) do
    local pitch = transposer.getTransposedPitch(kData.baseNote, kData.isTop)
    if pitch < curMinPitch then curMinPitch = pitch end
    if pitch > curMaxPitch then curMaxPitch = pitch end
  end

  -- Calculate bounds for test state
  state.transposeShift = testT
  state.octaveShift = testO
  state.topRowOctaveOffset = testTop
  state.bottomRowOctaveOffset = testBot

  local minPitch = math.huge
  local maxPitch = -math.huge
  for _, kData in pairs(config.getActiveNoteKeysMap()) do
    local pitch = transposer.getTransposedPitch(kData.baseNote, kData.isTop)
    if pitch < minPitch then minPitch = pitch end
    if pitch > maxPitch then maxPitch = pitch end
  end

  state.transposeShift = oldT
  state.octaveShift = oldO
  state.topRowOctaveOffset = oldTop
  state.bottomRowOctaveOffset = oldBot

  if minPitch >= 16 and maxPitch <= 113 then
    return true, testT, testO, testTop, testBot
  end

  if curMinPitch < 16 or curMaxPitch > 113 then
    while minPitch < 16 do
      testO = testO + 12
      testTop = testTop + 12
      testBot = testBot + 12
      minPitch = minPitch + 12
      maxPitch = maxPitch + 12
    end
    while maxPitch > 113 do
      testO = testO - 12
      testTop = testTop - 12
      testBot = testBot - 12
      minPitch = minPitch - 12
      maxPitch = maxPitch - 12
    end
    return true, testT, testO, testTop, testBot
  end

  return false, testT, testO, testTop, testBot
end

local function countTableKeys(t)
  if not t then return 0 end
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count
end

local function isTrackAudible(trackIdx)
  if not state.tracks then return true end
  local trk = state.tracks[trackIdx]
  if not trk then return true end
  if trk.muted then return false end
  local anySolo = false
  for _, t in pairs(state.tracks) do
    if t.soloed then anySolo = true; break end
  end
  if anySolo then
    return trk.soloed == true
  end
  return true
end

local function syncTrackAudibility()
  if not state.tracks then return end
  for trkId = 1, 4 do
    local trk = state.tracks[trkId]
    local ch = trk.channel or (trkId - 1)
    local audible = isTrackAudible(trkId)
    if not audible then
      -- 1. Silence audio in DAW / Logic Pro immediately
      if midi and midi.silenceChannel then
        midi.silenceChannel(ch)
      else
        midi.sendMidiCC(64, 0, ch)
        midi.sendMidiCC(120, 0, ch)
        midi.sendMidiCC(123, 0, ch)
      end
      -- Set Channel Volume (CC 7) & Expression (CC 11) to 0 so synth/audio is truly muted
      midi.sendMidiCC(7, 0, ch)
      midi.sendMidiCC(11, 0, ch)

      -- Dedicated DAW Controller Assignment CCs:
      -- CC 108: Track Mute (127 if muted, 0 if unmuted)
      -- CC 109: Track Solo (127 if soloed, 0 if not soloed)
      midi.sendMidiCC(108, trk.muted and 127 or 0, ch)
      midi.sendMidiCC(109, trk.soloed and 127 or 0, ch)

      -- 2. Silence arpeggiator active notes & gate timers on this track
      if arpeggiator and arpeggiator.silenceTrack then
        arpeggiator.silenceTrack(trkId)
      end

      -- 3. Silence any physically held notes on this track
      for code, info in pairs(state.pressedKeys) do
        if type(info) == "table" and not info.isControl and info.track == trkId then
          if info.pitches then
            for _, p in ipairs(info.pitches) do
              midi.sendMidiNote("noteOff", p, 0, info.channel or ch)
            end
          end
        end
      end

      -- 4. Silence any sustained notes on this track's channel
      if trk.sustainedPitches then
        for _, item in ipairs(trk.sustainedPitches) do
          midi.sendMidiNote("noteOff", item.pitch, 0, item.channel or ch)
        end
        trk.sustainedPitches = {}
      end
      if state.sustainedPitches then
        local newSustained = {}
        for _, item in ipairs(state.sustainedPitches) do
          if item.channel == ch then
            midi.sendMidiNote("noteOff", item.pitch, 0, item.channel)
          else
            table.insert(newSustained, item)
          end
        end
        state.sustainedPitches = newSustained
      end
      trk.activeNotesCount = 0
    else
      -- Track became audible!
      -- 1. Restore DAW Controller Assignment CCs:
      midi.sendMidiCC(108, 0, ch) -- Mute off
      midi.sendMidiCC(109, trk.soloed and 127 or 0, ch)

      -- 2. Restore Channel Volume (CC 7) & Expression (CC 11):
      local vol = trk.volume or 100
      local volCc = math.floor(math.min(127, math.max(0, vol * 1.27)))
      midi.sendMidiCC(7, volCc, ch)
      midi.sendMidiCC(11, 127, ch)

      -- 3. Resume physically held non-arp keys
      for code, info in pairs(state.pressedKeys) do
        if type(info) == "table" and not info.isControl and info.track == trkId and not info.isArpNote then
          if info.pitches then
            local vel = transposer.getEffectiveRowVelocity(trkId > 2)
            for _, p in ipairs(info.pitches) do
              midi.sendMidiNote("noteOn", p, vel, info.channel or ch)
            end
            trk.activeNotesCount = (trk.activeNotesCount or 0) + #info.pitches
          end
        end
      end

      -- 4. Resume arpeggiator if active or if notes are held
      if trk.arpEnabled then
        for code, info in pairs(state.pressedKeys) do
          if type(info) == "table" and not info.isControl and info.track == trkId and info.isArpNote then
            if info.pitches and arpeggiator and arpeggiator.arpAddNote then
              for _, p in ipairs(info.pitches) do
                arpeggiator.arpAddNote(code .. "_" .. p, p, trkId)
              end
            end
          end
        end

        local hasHeld = countTableKeys(trk.heldNotes) > 0 or trk.locked
        if hasHeld and not trk.timer and arpeggiator and arpeggiator.startTrackArp then
          arpeggiator.startTrackArp(trk, true)
        end
      end
    end
  end
  if hudModule and hudModule.fastUpdateArp then
    hudModule.fastUpdateArp()
  end
  -- Track-dependent key styling is owned by the full HUD payload. A spotlight
  -- update alone leaves the previous track's CSS variables in place.
  if hudModule and hudModule.updateWebviewHud then
    hudModule.updateWebviewHud(nil, nil, true)
  end

  local ks = _G.activeWatchers and _G.activeWatchers.keystep
  if ks and ks.syncToHud then ks.syncToHud() end
end

local function selectTrack(id)
  local targetId = math.max(1, math.min(4, tonumber(id) or 1))
  if not (state.tracks and state.tracks[targetId]) then return end

  local isBottomTarget = (targetId <= 2)

  -- Clean up only currently physically held note keys on the targeted row
  for code, info in pairs(state.pressedKeys) do
    if type(info) == "table" and not info.isControl then
      local noteKey = config.getNoteKey(code)
      local isTopKey = (noteKey and noteKey.isTop) or (info.track and info.track > 2)
      local shouldClean = isBottomTarget and (not isTopKey) or ((not isBottomTarget) and isTopKey)
      if shouldClean then
        if info.pitches then
          for _, p in ipairs(info.pitches) do
            midi.sendMidiNote("noteOff", p, 0, info.channel or 0)
          end
        end
        state.pressedKeys[code] = nil
        local prevTrkId = info.track or (isTopKey and (state.topRowTrack or 3) or (state.bottomRowTrack or 1))
        local prevTrk = state.tracks and state.tracks[prevTrkId]
        if prevTrk and prevTrk.physicalKeysHeld then
          prevTrk.physicalKeysHeld[code] = nil
        end
      end
    end
  end

  state.activeTrack = targetId
  local trk = state.tracks[targetId]
  state.arpEnabled = trk.arpEnabled == true
  state.arpLatchActive = trk.arpLatchActive == true
  state.arpRateIdx = trk.arpRateIdx or state.arpRateIdx
  state.arpDirectionIdx = trk.arpDirectionIdx or state.arpDirectionIdx or 1
  state.sustainActive = (trk.sustainMode ~= nil and trk.sustainMode ~= "off")
  state.chordModeActive = trk.chordModeActive == true
  if trk.chordIdx then state.chordIdx = trk.chordIdx end

  if targetId <= 2 then
    state.bottomRowTrack = targetId
    state.bottomRowChannel = trk.channel
    state.bottomRowOctaveOffset = trk.octaveOffset or 0
    state.bottomRowVolume = trk.volume or 100
  else
    state.topRowTrack = targetId
    state.topRowChannel = trk.channel
    state.topRowOctaveOffset = trk.octaveOffset or 12
    state.topRowVolume = trk.volume or 100
  end
  config.saveSettings()

  hud.updateWebviewHud({
    title = "SELECT TRACK " .. targetId,
    value = "Track " .. targetId .. ": " .. trk.name .. (trk.locked and " 🔁" or ""),
    subtext = (targetId <= 2 and "Bottom Row • " or "Top Row • ") .. "MIDI Ch " .. (trk.channel + 1) .. (trk.arpEnabled and " • Arp ON" or " • Live Play"),
    targetId = "key-" .. ({[1]=18,[2]=19,[3]=20,[4]=21})[targetId],
    color = trk.color or "#64d8f0"
  })

  local sync = _G.activeWatchers and _G.activeWatchers.sync
  if sync and sync.broadcastState then
    sync.broadcastState(state)
  end

  if hudModule and hudModule.fastUpdateArp then
    hudModule.fastUpdateArp()
  end
  if hudModule and hudModule.updateWebviewHud then
    hudModule.updateWebviewHud(nil, nil, true)
  end
  local ks = _G.activeWatchers and _G.activeWatchers.keystep
  if ks and ks.syncToHud then ks.syncToHud() end
end

local function applyTransposeDelta(deltaSteps, spotTitle)
  local curT = tonumber(state.transposeShift) or 0
  local curO = tonumber(state.octaveShift) or 0
  local curTop = tonumber(state.topRowOctaveOffset) or 0
  local curBot = tonumber(state.bottomRowOctaveOffset) or 0
  local numIntervals = #config.SCALES[state.currentScaleIdx or 1].intervals
  local newT = curT + deltaSteps
  local newO = curO
  while newT < 0 do
    newT = newT + numIntervals
    newO = newO - 12
  end
  while newT >= numIntervals do
    newT = newT - numIntervals
    newO = newO + 12
  end
  local ok, finalT, finalO, finalTop, finalBot = canApplyShifts(newT, newO, curTop, curBot)
  if ok then
    pushStateSnapshot("transpose")
    state.transposeShift = finalT
    state.octaveShift = finalO
    state.topRowOctaveOffset = finalTop
    state.bottomRowOctaveOffset = finalBot
    arpeggiator.updateLatchedArpNotes()
    local degreeNames = {
      [0] = "Degree 1 (Root)",
      [1] = "Degree 2",
      [2] = "Degree 3",
      [3] = "Degree 4",
      [4] = "Degree 5",
      [5] = "Degree 6",
      [6] = "Degree 7 (Subtonic)"
    }
    local degLabel = degreeNames[state.transposeShift] or ("Degree " .. (state.transposeShift + 1))
    local spot = {
      title = spotTitle or "TRANSPOSE",
      value = degLabel,
      subtext = string.format("Scale Degree %d | Octave %+d", state.transposeShift + 1, math.floor(state.octaveShift / 12)),
      targetId = "key-38",
      color = "#64d8f0"
    }
    hud.updateWebviewHud(spot)
  end
end

local function executeControlAction(act, code)
  if act == "undoState" then
    undoControllerState(code)
    return
  elseif act == "redoState" then
    redoControllerState(code)
    return
  elseif string.match(act, "^setArpRate_(%d+)$") then
    local rate = tonumber(string.match(act, "^setArpRate_(%d+)$"))
    setActiveArpRate(rate)
    hud.updateWebviewHud()
    return
  elseif string.match(act, "^setArpDir_(%d+)$") then
    local dir = tonumber(string.match(act, "^setArpDir_(%d+)$"))
    state.arpDirectionIdx = dir
    hud.updateWebviewHud()
    return
  elseif string.match(act, "^setArpQuantize_(.+)$") then
    local quant = string.match(act, "^setArpQuantize_(.+)$")
    state.arpQuantizeMode = quant
    hs.settings.set("qwertyMidi_arpQuantizeMode", quant)
    hud.updateWebviewHud()
    return
  elseif act == "arpLatchToggle" then
    arpeggiator.toggleArpLatch()
    return
  end

  -- Top/Bottom ARP controls target the selected track for that row. The
  -- multi-track engine no longer consumes the legacy row-level flags.
  if act == "arpTopToggle" or act == "arpBottomToggle" then
    local rowName = act == "arpTopToggle" and "TOP" or "BOTTOM"
    local trackId = act == "arpTopToggle" and (state.topRowTrack or 3) or (state.bottomRowTrack or 1)
    local trk = state.tracks and state.tracks[trackId]
    if trk then
      arpeggiator.toggleArpPower(trackId)
      state.arpTopEnabled = (state.tracks[state.topRowTrack or 3].arpEnabled == true)
      state.arpBottomEnabled = (state.tracks[state.bottomRowTrack or 1].arpEnabled == true)
      hud.updateWebviewHud({
        title = rowName .. " ROW ARP (TRACK " .. trackId .. ")",
        value = trk.arpEnabled and (trk.arpLatchActive and "ON • LATCH 🔒" or "ON") or "OFF",
        subtext = trk.name .. " • " .. (trk.arpEnabled and "Arpeggiating" or "Live Play"),
        targetId = act == "arpTopToggle" and "arp-top-toggle" or "arp-bottom-toggle",
        color = trk.color or "#d4a359"
      })
    end
    return
  end

  -- Record state snapshot before mutating controller parameters
  if act == "modeDown" or act == "modeUp" or
     act == "rootDown" or act == "rootUp" or act == "randomScale" or act == "resetAll" or
     act == "arpToggle" or act == "arpTopToggle" or act == "arpBottomToggle" or
     act == "arpLinkToggle" or act == "arpDirDown" or act == "arpDirUp" or act == "arpRateDown" or act == "arpRateUp" or
     act == "arpGateDown" or act == "arpGateUp" or act == "bpmDown" or act == "bpmUp" or
     act == "atkDown" or act == "atkUp" or act == "decDown" or act == "decUp" or
     act == "relDown" or act == "relUp" or act == "releaseDown" or act == "releaseUp" or
     act == "volDown" or act == "volUp" or act == "topVolDown" or act == "topVolUp" or
     act == "botVolDown" or act == "botVolUp" or
     act == "modWheelDown" or act == "modWheelUp" or act == "botOctDown" or act == "botOctUp" or
     act == "octaveDown" or act == "octaveUp" then
    pushStateSnapshot(act)
  end

  if act == "topOctDown" then
    local curT = tonumber(state.transposeShift) or 0
    local curO = tonumber(state.octaveShift) or 0
    local curTop = tonumber(state.topRowOctaveOffset) or 0
    local curBot = tonumber(state.bottomRowOctaveOffset) or 0
    local newTop = curTop - 12
    local ok, finalT, finalO, finalTop, finalBot = canApplyShifts(curT, curO, newTop, curBot)
    if ok then
      pushStateSnapshot(act)
      state.transposeShift = finalT
      state.octaveShift = finalO
      state.topRowOctaveOffset = finalTop
      state.bottomRowOctaveOffset = finalBot
      local topTrk = state.tracks and state.tracks[state.topRowTrack or 3]
      if topTrk then topTrk.octaveOffset = finalTop end
      config.saveSettings()
      arpeggiator.updateLatchedArpNotes()
      local spot = {
        title = "TOP OCTAVE",
        value = ((state.topRowOctaveOffset + 12) >= 0 and "+" or "") .. math.floor((state.topRowOctaveOffset + 12) / 12) .. " Oct",
        subtext = "Top keys shifted",
        targetId = "octave-indicator-top",
        color = "#d4a359"
      }
      hud.updateWebviewHud(spot)
    end
  elseif act == "topOctUp" then
    local curT = tonumber(state.transposeShift) or 0
    local curO = tonumber(state.octaveShift) or 0
    local curTop = tonumber(state.topRowOctaveOffset) or 0
    local curBot = tonumber(state.bottomRowOctaveOffset) or 0
    local newTop = curTop + 12
    local ok, finalT, finalO, finalTop, finalBot = canApplyShifts(curT, curO, newTop, curBot)
    if ok then
      pushStateSnapshot(act)
      state.transposeShift = finalT
      state.octaveShift = finalO
      state.topRowOctaveOffset = finalTop
      state.bottomRowOctaveOffset = finalBot
      local topTrk = state.tracks and state.tracks[state.topRowTrack or 3]
      if topTrk then topTrk.octaveOffset = finalTop end
      config.saveSettings()
      arpeggiator.updateLatchedArpNotes()
      local spot = {
        title = "TOP OCTAVE",
        value = ((state.topRowOctaveOffset + 12) >= 0 and "+" or "") .. math.floor((state.topRowOctaveOffset + 12) / 12) .. " Oct",
        subtext = "Top keys shifted",
        targetId = "octave-indicator-top",
        color = "#d4a359"
      }
      hud.updateWebviewHud(spot)
    end
  elseif act == "botOctDown" then
    local curT = tonumber(state.transposeShift) or 0
    local curO = tonumber(state.octaveShift) or 0
    local curTop = tonumber(state.topRowOctaveOffset) or 0
    local curBot = tonumber(state.bottomRowOctaveOffset) or 0
    local newBot = curBot - 12
    local ok, finalT, finalO, finalTop, finalBot = canApplyShifts(curT, curO, curTop, newBot)
    if ok then
      pushStateSnapshot(act)
      state.transposeShift = finalT
      state.octaveShift = finalO
      state.topRowOctaveOffset = finalTop
      state.bottomRowOctaveOffset = finalBot
      local botTrk = state.tracks and state.tracks[state.bottomRowTrack or 1]
      if botTrk then botTrk.octaveOffset = finalBot end
      config.saveSettings()
      arpeggiator.updateLatchedArpNotes()
      local spot = {
        title = "BOT OCTAVE",
        value = (state.bottomRowOctaveOffset >= 0 and "+" or "") .. math.floor(state.bottomRowOctaveOffset / 12) .. " Oct",
        subtext = "Bottom keys shifted",
        targetId = "octave-indicator-bottom",
        color = "#d4a359"
      }
      hud.updateWebviewHud(spot)
    end
  elseif act == "botOctUp" then
    local curT = tonumber(state.transposeShift) or 0
    local curO = tonumber(state.octaveShift) or 0
    local curTop = tonumber(state.topRowOctaveOffset) or 0
    local curBot = tonumber(state.bottomRowOctaveOffset) or 0
    local newBot = curBot + 12
    local ok, finalT, finalO, finalTop, finalBot = canApplyShifts(curT, curO, curTop, newBot)
    if ok then
      pushStateSnapshot(act)
      state.transposeShift = finalT
      state.octaveShift = finalO
      state.topRowOctaveOffset = finalTop
      state.bottomRowOctaveOffset = finalBot
      local botTrk = state.tracks and state.tracks[state.bottomRowTrack or 1]
      if botTrk then botTrk.octaveOffset = finalBot end
      config.saveSettings()
      arpeggiator.updateLatchedArpNotes()
      local spot = {
        title = "BOT OCTAVE",
        value = (state.bottomRowOctaveOffset >= 0 and "+" or "") .. math.floor(state.bottomRowOctaveOffset / 12) .. " Oct",
        subtext = "Bottom keys shifted",
        targetId = "octave-indicator-bottom",
        color = "#d4a359"
      }
      hud.updateWebviewHud(spot)
    end
  elseif act == "trnspDown" then
    local curT = tonumber(state.transposeShift) or 0
    local curO = tonumber(state.octaveShift) or 0
    local curTop = tonumber(state.topRowOctaveOffset) or 0
    local curBot = tonumber(state.bottomRowOctaveOffset) or 0
    local numIntervals = #config.SCALES[state.currentScaleIdx].intervals
    local newT = curT - 1
    local newO = curO
    if newT <= -numIntervals then
      newT = newT + numIntervals
      newO = newO - 12
    end
    local ok, finalT, finalO, finalTop, finalBot = canApplyShifts(newT, newO, curTop, curBot)
    if ok then
      pushStateSnapshot(act)
      state.transposeShift = finalT
      state.octaveShift = finalO
      state.topRowOctaveOffset = finalTop
      state.bottomRowOctaveOffset = finalBot
      arpeggiator.updateLatchedArpNotes()
      local spot = {
        title = "TRANSPOSE",
        value = (state.transposeShift >= 0 and "+" or "") .. state.transposeShift .. " steps",
        subtext = "Scale notes shifted",
        targetId = "header",
        color = "#d4a359"
      }
      hud.updateWebviewHud(spot)
    end
  elseif act == "trnspUp" then
    local curT = tonumber(state.transposeShift) or 0
    local curO = tonumber(state.octaveShift) or 0
    local curTop = tonumber(state.topRowOctaveOffset) or 0
    local curBot = tonumber(state.bottomRowOctaveOffset) or 0
    local numIntervals = #config.SCALES[state.currentScaleIdx].intervals
    local newT = curT + 1
    local newO = curO
    if newT >= numIntervals then
      newT = newT - numIntervals
      newO = newO + 12
    end
    local ok, finalT, finalO, finalTop, finalBot = canApplyShifts(newT, newO, curTop, curBot)
    if ok then
      pushStateSnapshot(act)
      state.transposeShift = finalT
      state.octaveShift = finalO
      state.topRowOctaveOffset = finalTop
      state.bottomRowOctaveOffset = finalBot
      arpeggiator.updateLatchedArpNotes()
      local spot = {
        title = "TRANSPOSE",
        value = (state.transposeShift >= 0 and "+" or "") .. state.transposeShift .. " steps",
        subtext = "Scale notes shifted",
        targetId = "header",
        color = "#d4a359"
      }
      hud.updateWebviewHud(spot)
    end
  elseif act == "octaveDown" then
    local curT = tonumber(state.transposeShift) or 0
    local curO = tonumber(state.octaveShift) or 0
    local curTop = tonumber(state.topRowOctaveOffset) or 0
    local curBot = tonumber(state.bottomRowOctaveOffset) or 0
    local activeTrkId = state.activeTrack or 1
    local isTop = (activeTrkId > 2)
    local newTop = isTop and (curTop - 12) or curTop
    local newBot = (not isTop) and (curBot - 12) or curBot
    local ok, finalT, finalO, finalTop, finalBot = canApplyShifts(curT, curO, newTop, newBot)
    if ok then
      pushStateSnapshot(act)
      state.topRowOctaveOffset = finalTop
      state.bottomRowOctaveOffset = finalBot
      arpeggiator.updateLatchedArpNotes()
      local actTrk = state.tracks and state.tracks[activeTrkId]
      if actTrk then
        actTrk.octaveOffset = isTop and finalTop or finalBot
      end
      config.saveSettings()
      local octVal = actTrk and actTrk.octaveOffset or (isTop and finalTop or finalBot)
      local spot = {
        title = "OCTAVE (TRK " .. activeTrkId .. ")",
        value = (octVal >= 0 and "+" or "") .. math.floor(octVal / 12) .. " Oct",
        subtext = (actTrk and actTrk.name or ("Track " .. activeTrkId)) .. " Octave Offset",
        targetId = isTop and "octave-indicator-top" or "octave-indicator-bottom",
        color = (actTrk and actTrk.color) or "#00e5ff"
      }
      hud.updateWebviewHud(spot)
    end
  elseif act == "octaveUp" then
    local curT = tonumber(state.transposeShift) or 0
    local curO = tonumber(state.octaveShift) or 0
    local curTop = tonumber(state.topRowOctaveOffset) or 0
    local curBot = tonumber(state.bottomRowOctaveOffset) or 0
    local activeTrkId = state.activeTrack or 1
    local isTop = (activeTrkId > 2)
    local newTop = isTop and (curTop + 12) or curTop
    local newBot = (not isTop) and (curBot + 12) or curBot
    local ok, finalT, finalO, finalTop, finalBot = canApplyShifts(curT, curO, newTop, newBot)
    if ok then
      pushStateSnapshot(act)
      state.topRowOctaveOffset = finalTop
      state.bottomRowOctaveOffset = finalBot
      arpeggiator.updateLatchedArpNotes()
      local actTrk = state.tracks and state.tracks[activeTrkId]
      if actTrk then
        actTrk.octaveOffset = isTop and finalTop or finalBot
      end
      config.saveSettings()
      local octVal = actTrk and actTrk.octaveOffset or (isTop and finalTop or finalBot)
      local spot = {
        title = "OCTAVE (TRK " .. activeTrkId .. ")",
        value = (octVal >= 0 and "+" or "") .. math.floor(octVal / 12) .. " Oct",
        subtext = (actTrk and actTrk.name or ("Track " .. activeTrkId)) .. " Octave Offset",
        targetId = isTop and "octave-indicator-top" or "octave-indicator-bottom",
        color = (actTrk and actTrk.color) or "#00e5ff"
      }
      hud.updateWebviewHud(spot)
    end
  elseif act == "modeDown" then
    state.currentScaleIdx = (state.currentScaleIdx - 2) % #SCALES + 1
    arpeggiator.updateLatchedArpNotes()
    local scaleInfo = SCALES[state.currentScaleIdx]
    local spot = {
      title = "SCALE / MODE",
      value = scaleInfo.name,
      subtext = scaleInfo.brightTag,
      targetId = "mode-thumb",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "modeUp" then
    state.currentScaleIdx = (state.currentScaleIdx % #SCALES) + 1
    arpeggiator.updateLatchedArpNotes()
    local scaleInfo = SCALES[state.currentScaleIdx]
    local spot = {
      title = "SCALE / MODE",
      value = scaleInfo.name,
      subtext = scaleInfo.brightTag,
      targetId = "mode-thumb",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "rootDown" then
    if state.currentRoot == 0 then
      state.currentRoot = 11
      state.octaveShift = math.max(-36, state.octaveShift - 12)
    else
      state.currentRoot = state.currentRoot - 1
    end
    arpeggiator.updateLatchedArpNotes()
    local rootName = NOTE_NAMES[state.currentRoot + 1]
    local spot = {
      title = "ROOT NOTE",
      value = rootName,
      subtext = rootName .. " " .. SCALES[state.currentScaleIdx].name,
      targetId = "root-select",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "rootUp" then
    if state.currentRoot == 11 then
      state.currentRoot = 0
      state.octaveShift = math.min(36, state.octaveShift + 12)
    else
      state.currentRoot = state.currentRoot + 1
    end
    arpeggiator.updateLatchedArpNotes()
    local rootName = NOTE_NAMES[state.currentRoot + 1]
    local spot = {
      title = "ROOT NOTE",
      value = rootName,
      subtext = rootName .. " " .. SCALES[state.currentScaleIdx].name,
      targetId = "root-select",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "randomScale" then
    state.currentRoot = math.random(0, 11)
    state.currentScaleIdx = math.random(1, #SCALES)
    arpeggiator.updateLatchedArpNotes()
    local rootName = NOTE_NAMES[state.currentRoot + 1]
    local scaleInfo = SCALES[state.currentScaleIdx]
    local spot = {
      title = "RANDOM SCALE",
      value = rootName .. " " .. scaleInfo.name,
      subtext = scaleInfo.brightTag,
      targetId = "mode-thumb",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "randomRoot" then
    state.currentRoot = math.random(0, 11)
    arpeggiator.updateLatchedArpNotes()
    local rootName = NOTE_NAMES[state.currentRoot + 1]
    local spot = {
      title = "RANDOM ROOT",
      value = rootName,
      subtext = rootName .. " " .. SCALES[state.currentScaleIdx].name,
      targetId = "root-select",
      color = "#ffd700"
    }
    hud.updateWebviewHud(spot)
  elseif act == "randomMode" then
    state.currentScaleIdx = math.random(1, #SCALES)
    arpeggiator.updateLatchedArpNotes()
    local scaleInfo = SCALES[state.currentScaleIdx]
    local spot = {
      title = "RANDOM MODE",
      value = scaleInfo.name,
      subtext = scaleInfo.brightTag,
      targetId = "mode-thumb",
      color = "#ffd700"
    }
    hud.updateWebviewHud(spot)
  elseif act == "randomRhythm" then
    setActiveArpRate(math.random(1, #state.ARP_RATES))
    state.arpGatePercent = math.random(25, 120)
    arpeggiator.applyGatePercentChange()
    local spot = {
      title = "RANDOM RHYTHM",
      value = state.ARP_RATES[state.arpRateIdx].label .. " (" .. math.floor(state.arpGatePercent) .. "%)",
      subtext = "Rate & Gate Randomized",
      targetId = "arp-rate-select",
      color = "#ffd700"
    }
    hud.updateWebviewHud(spot)
  elseif act == "randomAll" then
    state.currentRoot = math.random(0, 11)
    state.currentScaleIdx = math.random(1, #SCALES)
    state.arpDirectionIdx = math.random(1, #state.ARP_DIRECTIONS)
    setActiveArpRate(math.random(1, #state.ARP_RATES))
    state.arpGatePercent = math.random(25, 120)
    arpeggiator.updateLatchedArpNotes()
    arpeggiator.applyGatePercentChange()
    local rootName = NOTE_NAMES[state.currentRoot + 1]
    local scaleInfo = SCALES[state.currentScaleIdx]
    local spot = {
      title = "RANDOM ALL",
      value = rootName .. " " .. scaleInfo.name,
      subtext = "Root, Mode & Rhythm Randomized",
      targetId = "key-1",
      color = "#ffd700"
    }
    hud.updateWebviewHud(spot)
  elseif act == "arpBypassToggle" then
    state.arpBypassed = not state.arpBypassed
    local spot = {
      title = "ARP BYPASS",
      value = state.arpBypassed and "BYPASS ON (Live Notes)" or "BYPASS OFF (Arp Active)",
      subtext = state.arpBypassed and "Live key presses bypass arpeggiator" or "Keys trigger arpeggiator normally",
      targetId = "key-0",
      color = state.arpBypassed and "#ffd700" or "#50fa7b"
    }
    hud.updateWebviewHud(spot)
  elseif act == "panic" then
    -- Stop producers before sending the MIDI panic sweep so no timer or queued
    -- quantized note can immediately retrigger after the sweep.
    if arpeggiator.stopAllLoops then arpeggiator.stopAllLoops() end
    if quantizer.panic then
      quantizer.panic(function(pitches, channel)
        for _, pitch in ipairs(pitches or {}) do
          midi.sendMidiNote("noteOff", pitch, 0, channel or 0)
        end
      end)
    end
    local ks = _G.activeWatchers and _G.activeWatchers.keystep
    if ks and ks.panic then ks.panic() end
    local midiAvailable = midi.getMidiDevice() ~= nil
    midi.panicAllChannels()
    state.sustainActive = false
    state.sustainKeyDownTime = nil
    state.arpLatchActive = false
    state.sustainedPitches = {}
    state.pressedKeys = {}
    if state.tracks then
      for _, trk in pairs(state.tracks) do
        trk.sustainMode = "off"
        trk.sustainedPitches = {}
        trk.physicalKeysHeld = {}
        trk.activeNotesCount = 0
      end
    end

    arpeggiator.stopArpTimer()
    state.arpHeldNotes = {}
    state.arpKeysCurrentlyHeld = {}
    state.arpSequence = {}

    -- Clear repeats
    stopAllControlRepeats()

    local spot = {
      title = "MIDI PANIC",
      value = midiAvailable and "ALL NOTES OFF" or "STATE CLEARED",
      subtext = midiAvailable and "Panic sent on all MIDI channels" or "MIDI output unavailable; external silence not confirmed",
      targetId = code and ("key-" .. code) or "header",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
    if hudModule and hudModule.updateWebviewHud then
      hudModule.updateWebviewHud(nil, nil, true)
    end
  elseif act == "resetAll" then
    state.octaveShift = 0
    state.topRowOctaveOffset = 0
    state.bottomRowOctaveOffset = 0
    state.transposeShift = 0
    state.topRowVolume = 100
    state.bottomRowVolume = 100
    state.currentRoot = 0
    state.currentScaleIdx = 1
    state.sustainActive = false
    state.ccStates[1] = 0
    _G.activeWatchers.modAccumulator = 0
    arpeggiator.stopArpTimer()
    state.arpHeldNotes = {}
    state.arpKeysCurrentlyHeld = {}
    state.arpEnabled = false
    state.arpLatchActive = false
    state.arpTopEnabled = true
    state.arpBottomEnabled = true
    midi.sendMidiCC(64, 0)
    midi.sendMidiCC(1, 0)
    local spot = {
      title = "RESET ALL",
      value = "DEFAULTS RESTORED",
      subtext = "Everything reset to defaults",
      targetId = code and ("key-" .. code) or "header",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "zoomOut" or act == "zoomDown" then
    state.zoomLevel = math.max(0.5, state.zoomLevel - 0.1)
    local spot = {
      title = "HUD ZOOM",
      value = math.floor(state.zoomLevel * 100) .. "%",
      subtext = "Scale Factor",
      targetId = "header",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "zoomIn" or act == "zoomUp" then
    state.zoomLevel = math.min(2.0, state.zoomLevel + 0.1)
    local spot = {
      title = "HUD ZOOM",
      value = math.floor(state.zoomLevel * 100) .. "%",
      subtext = "Scale Factor",
      targetId = "header",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "sustain" then
    local activeTrkId = state.activeTrack or 1
    local trk = state.tracks and state.tracks[activeTrkId]
    local now = hs.timer.secondsSinceEpoch()
    state.sustainKeyDownTime = now
    state.tabDamping = true
    if trk then
      trk.sustainWasActiveOnPress = (trk.sustainMode == "smart")
      -- A short second Tab press is the explicit, visible sustain-off gesture.
      -- The first tap retains its useful damping behavior.
      if trk.lastSmartSustainTapAt and (now - trk.lastSmartSustainTapAt) <= 0.35 then
        trk.sustainMode = "off"
        trk.lastSmartSustainTapAt = nil
        state.sustainActive = false
        cleanupSustainPitches(activeTrkId)
        config.saveSettings()
        hud.updateWebviewHud({
          title = "SUSTAIN OFF (TRK " .. activeTrkId .. ")",
          value = "OFF",
          subtext = "Double-tap Tab toggles Smart Sustain off",
          targetId = code and ("key-" .. code) or "key-48",
          color = "#b5aba0"
        })
      elseif trk.sustainMode == "off" then
        trk.sustainMode = "smart"
        state.sustainActive = true
        config.saveSettings()
        local spot = {
          title = "SMART SUSTAIN (TRK " .. activeTrkId .. ")",
          value = "SMART ON",
          subtext = "Tap Tab to damp · double-tap Tab to turn off",
          targetId = code and ("key-" .. code) or "key-48",
          color = trk.color or "#00e5ff"
        }
        hud.updateWebviewHud(spot)
      else
        -- Reverse functionality: smart sustain is on, hitting Tab cuts off ringing notes for silence
        local hadNotes = (trk.sustainedPitches and #trk.sustainedPitches > 0)
        cleanupSustainPitches(activeTrkId)
        local spot = {
          title = "DAMP / SILENCE (TRK " .. activeTrkId .. ")",
          value = "CUT OFF",
          subtext = hadNotes and "Silenced ringing notes; double-tap Tab to turn off" or "Silence; Smart Sustain active (2× Tab = off)",
          targetId = code and ("key-" .. code) or "key-48",
          color = trk.color or "#00e5ff"
        }
        hud.updateWebviewHud(spot)
      end
    end
  elseif act == "classicSustain" then
    local activeTrkId = state.activeTrack or 1
    local trk = state.tracks and state.tracks[activeTrkId]
    state.sustainKeyDownTime = hs.timer.secondsSinceEpoch()
    if trk then
      trk.classicWasActiveOnPress = (trk.sustainMode == "classic")
    end
    state.sustainWasActiveOnPress = (trk and trk.sustainMode == "classic") or state.sustainActive
    local isClassic = trk and (trk.sustainMode == "classic")
    local spot = {
      title = "CLASSIC SUSTAIN (TRK " .. activeTrkId .. ")",
      value = isClassic and "CLASSIC ON" or "CLASSIC OFF",
      subtext = isClassic and "Cumulative sustain across releases (can get muddy)" or "Shift+Tab to toggle Classic",
      targetId = code and ("key-" .. code) or "key-48",
      color = trk and trk.color or "#ff9100"
    }
    hud.updateWebviewHud(spot)
  elseif act == "arpToggle" then
    arpeggiator.toggleArpPower()
  elseif act == "arpLinkToggle" then
    arpeggiator.toggleArpLink()
  elseif act == "chordToggle" then
    local activeTrkId = state.activeTrack or 1
    local trk = state.tracks and state.tracks[activeTrkId]
    state.chordKeyDownTime = hs.timer.secondsSinceEpoch()
    if trk then
      trk.chordWasActiveOnPress = (trk.chordModeActive == true)
    end
    state.chordWasActiveOnPress = (trk and trk.chordModeActive) or state.chordModeActive
    local isChord = trk and trk.chordModeActive
    local chordName = state.CHORDS[(trk and trk.chordIdx) or state.chordIdx or 1].name
    local spot = {
      title = "CHORD MODE (TRK " .. activeTrkId .. ")",
      value = isChord and ("ON (" .. chordName .. ")") or "OFF",
      subtext = isChord and ("Track " .. activeTrkId .. " chords enabled") or ("Track " .. activeTrkId .. " single notes"),
      targetId = "header",
      color = isChord and "#d4a359" or "#b5aba0"
    }
    hud.updateWebviewHud(spot)
  elseif act == "chordUp" then
    local activeTrkId = state.activeTrack or 1
    local trk = state.tracks and state.tracks[activeTrkId]
    if trk then
      trk.chordIdx = ((trk.chordIdx or 1) % #state.CHORDS) + 1
      state.chordIdx = trk.chordIdx
    else
      state.chordIdx = (state.chordIdx % #state.CHORDS) + 1
    end
    arpeggiator.updateLatchedArpChordNotes()
    local chordName = state.CHORDS[state.chordIdx].name
    local spot = {
      title = "CHORD TYPE (TRK " .. activeTrkId .. ")",
      value = chordName,
      subtext = "Cycle chord type for Track " .. activeTrkId,
      targetId = "header",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "chordDown" then
    local activeTrkId = state.activeTrack or 1
    local trk = state.tracks and state.tracks[activeTrkId]
    if trk then
      trk.chordIdx = (((trk.chordIdx or 1) - 2 + #state.CHORDS) % #state.CHORDS) + 1
      state.chordIdx = trk.chordIdx
    else
      state.chordIdx = ((state.chordIdx - 2 + #state.CHORDS) % #state.CHORDS) + 1
    end
    arpeggiator.updateLatchedArpChordNotes()
    local chordName = state.CHORDS[state.chordIdx].name
    local spot = {
      title = "CHORD TYPE (TRK " .. activeTrkId .. ")",
      value = chordName,
      subtext = "Cycle chord type for Track " .. activeTrkId,
      targetId = "header",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "modWheelDown" then
    local currentVal = state.ccStates[1] or 0
    local newVal = math.max(0, currentVal - 4)
    state.ccStates[1] = newVal
    _G.activeWatchers.modAccumulator = newVal
    midi.sendMidiCC(1, newVal)
    local spot = {
      title = "MOD WHEEL",
      value = math.floor((newVal / 127) * 100) .. "%",
      subtext = "CC #1 Intensity",
      targetId = "header",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "modWheelUp" or act == "modWheel" then
    local currentVal = state.ccStates[1] or 0
    local newVal = math.min(127, currentVal + 4)
    state.ccStates[1] = newVal
    _G.activeWatchers.modAccumulator = newVal
    midi.sendMidiCC(1, newVal)
    local spot = {
      title = "MOD WHEEL",
      value = math.floor((newVal / 127) * 100) .. "%",
      subtext = "CC #1 Intensity",
      targetId = "header",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "topVolDown" then
    state.topRowVolume = math.max(0, state.topRowVolume - 4)
    local topTrkId = state.topRowTrack or 3
    local trk = state.tracks and state.tracks[topTrkId]
    if trk then
      trk.volume = state.topRowVolume
      if isTrackAudible(topTrkId) then
        midi.sendMidiCC(7, state.topRowVolume, trk.channel or 2)
      end
    end
    config.saveSettings()
    local spot = {
      title = "TOP ROW VOL",
      value = math.floor((state.topRowVolume / 127) * 100) .. "%",
      subtext = (trk and trk.name or "Upper Keys") .. " Level",
      targetId = "vol-indicator-top",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "topVolUp" then
    state.topRowVolume = math.min(127, state.topRowVolume + 4)
    local topTrkId = state.topRowTrack or 3
    local trk = state.tracks and state.tracks[topTrkId]
    if trk then
      trk.volume = state.topRowVolume
      if isTrackAudible(topTrkId) then
        midi.sendMidiCC(7, state.topRowVolume, trk.channel or 2)
      end
    end
    config.saveSettings()
    local spot = {
      title = "TOP ROW VOL",
      value = math.floor((state.topRowVolume / 127) * 100) .. "%",
      subtext = (trk and trk.name or "Upper Keys") .. " Level",
      targetId = "vol-indicator-top",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "botVolDown" then
    state.bottomRowVolume = math.max(0, state.bottomRowVolume - 4)
    local botTrkId = state.bottomRowTrack or 1
    local trk = state.tracks and state.tracks[botTrkId]
    if trk then
      trk.volume = state.bottomRowVolume
      if isTrackAudible(botTrkId) then
        midi.sendMidiCC(7, state.bottomRowVolume, trk.channel or 0)
      end
    end
    config.saveSettings()
    local spot = {
      title = "BOTTOM ROW VOL",
      value = math.floor((state.bottomRowVolume / 127) * 100) .. "%",
      subtext = (trk and trk.name or "Lower Keys") .. " Level",
      targetId = "vol-indicator-bottom",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "botVolUp" then
    state.bottomRowVolume = math.min(127, state.bottomRowVolume + 4)
    local botTrkId = state.bottomRowTrack or 1
    local trk = state.tracks and state.tracks[botTrkId]
    if trk then
      trk.volume = state.bottomRowVolume
      if isTrackAudible(botTrkId) then
        midi.sendMidiCC(7, state.bottomRowVolume, trk.channel or 0)
      end
    end
    config.saveSettings()
    local spot = {
      title = "BOTTOM ROW VOL",
      value = math.floor((state.bottomRowVolume / 127) * 100) .. "%",
      subtext = (trk and trk.name or "Lower Keys") .. " Level",
      targetId = "vol-indicator-bottom",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "volDown" then
    local activeTrkId = state.activeTrack or 1
    local trk = state.tracks and state.tracks[activeTrkId]
    if trk then
      trk.volume = math.max(0, (trk.volume or 100) - 4)
      if isTrackAudible(trk.id) then
        midi.sendMidiCC(7, trk.volume, trk.channel or 0)
      end
      if activeTrkId <= 2 then
        state.bottomRowVolume = trk.volume
      else
        state.topRowVolume = trk.volume
      end
      config.saveSettings()
      local spot = {
        title = "VOLUME (TRK " .. activeTrkId .. ")",
        value = math.floor((trk.volume / 127) * 100) .. "%",
        subtext = (trk.name or ("Track " .. activeTrkId)) .. " Volume (CC #7)",
        targetId = "header",
        color = trk.color or "#00e5ff"
      }
      hud.updateWebviewHud(spot)
    end
  elseif act == "volUp" or act == "volume" then
    local activeTrkId = state.activeTrack or 1
    local trk = state.tracks and state.tracks[activeTrkId]
    if trk then
      trk.volume = math.min(127, (trk.volume or 100) + 4)
      if isTrackAudible(trk.id) then
        midi.sendMidiCC(7, trk.volume, trk.channel or 0)
      end
      if activeTrkId <= 2 then
        state.bottomRowVolume = trk.volume
      else
        state.topRowVolume = trk.volume
      end
      config.saveSettings()
      local spot = {
        title = "VOLUME (TRK " .. activeTrkId .. ")",
        value = math.floor((trk.volume / 127) * 100) .. "%",
        subtext = (trk.name or ("Track " .. activeTrkId)) .. " Volume (CC #7)",
        targetId = "header",
        color = trk.color or "#00e5ff"
      }
      hud.updateWebviewHud(spot)
    end
  elseif act == "chordUp" then
    state.chordIdx = (state.chordIdx % #state.CHORDS) + 1
    arpeggiator.updateLatchedArpChordNotes()
    local chordName = state.CHORDS[state.chordIdx].name
    local spot = {
      title = "CHORD TYPE",
      value = chordName,
      subtext = "Active Chord Modifier Pattern",
      targetId = "header",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "chordDown" then
    state.chordIdx = ((state.chordIdx - 2 + #state.CHORDS) % #state.CHORDS) + 1
    arpeggiator.updateLatchedArpChordNotes()
    local chordName = state.CHORDS[state.chordIdx].name
    local spot = {
      title = "CHORD TYPE",
      value = chordName,
      subtext = "Active Chord Modifier Pattern",
      targetId = "header",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "arpDirDown" then
    local currentDir = getActiveArpDirectionIdx()
    local nextDir = ((currentDir - 2 + #state.ARP_DIRECTIONS) % #state.ARP_DIRECTIONS) + 1
    setActiveArpDirection(nextDir)
    local trk = state.tracks and state.tracks[state.activeTrack or 1]
    local spot = {
      title = "ARP DIRECTION (TRK " .. (state.activeTrack or 1) .. ")",
      value = state.ARP_DIRECTIONS[state.arpDirectionIdx],
      subtext = (trk and trk.name or ("Track " .. (state.activeTrack or 1))) .. " Arp Pattern",
      targetId = "arp-dir-select",
      color = (trk and trk.color) or "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "arpDirUp" then
    local currentDir = getActiveArpDirectionIdx()
    local nextDir = (currentDir % #state.ARP_DIRECTIONS) + 1
    setActiveArpDirection(nextDir)
    local trk = state.tracks and state.tracks[state.activeTrack or 1]
    local spot = {
      title = "ARP DIRECTION (TRK " .. (state.activeTrack or 1) .. ")",
      value = state.ARP_DIRECTIONS[state.arpDirectionIdx],
      subtext = (trk and trk.name or ("Track " .. (state.activeTrack or 1))) .. " Arp Pattern",
      targetId = "arp-dir-select",
      color = (trk and trk.color) or "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "arpRateDown" then
    setActiveArpRate(math.max(1, getActiveArpRateIdx() - 1))
    local spot = {
      title = "ARP RATE",
      value = state.ARP_RATES[state.arpRateIdx].label,
      subtext = "Note Division",
      targetId = "arp-rate-select",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "arpRateUp" then
    setActiveArpRate(math.min(#state.ARP_RATES, getActiveArpRateIdx() + 1))
    local spot = {
      title = "ARP RATE",
      value = state.ARP_RATES[state.arpRateIdx].label,
      subtext = "Note Division",
      targetId = "arp-rate-select",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "arpGateDown" then
    state.arpGatePercent = math.max(5.0, (state.arpGatePercent or 80.0) - 5.0)
    arpeggiator.applyGatePercentChange()
    local spot = {
      title = "ARP NOTE LENGTH",
      value = math.floor(state.arpGatePercent + 0.5) .. "%",
      subtext = "Gate Duration",
      targetId = "gate-value",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "arpGateUp" then
    state.arpGatePercent = math.min(150.0, (state.arpGatePercent or 80.0) + 5.0)
    arpeggiator.applyGatePercentChange()
    local spot = {
      title = "ARP NOTE LENGTH",
      value = math.floor(state.arpGatePercent + 0.5) .. "%",
      subtext = "Gate Duration",
      targetId = "gate-value",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "bpmDown" then
    local step = state.bpmStepSize or 10
    state.arpBpm = math.max(20.0, state.arpBpm - step)
    arpeggiator.applyBpmChange()
    arpeggiator.stepLogicBpm(-step)
    local spot = {
      title = "TEMPO / BPM",
      value = arpeggiator.formatBpm(state.arpBpm) .. " BPM",
      subtext = "Step: " .. step .. " BPM",
      targetId = "bpm-value",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "bpmUp" then
    local step = state.bpmStepSize or 10
    state.arpBpm = math.min(300.0, state.arpBpm + step)
    arpeggiator.applyBpmChange()
    arpeggiator.stepLogicBpm(step)
    local spot = {
      title = "TEMPO / BPM",
      value = arpeggiator.formatBpm(state.arpBpm) .. " BPM",
      subtext = "Step: " .. step .. " BPM",
      targetId = "bpm-value",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "atkDown" then
    local trkId = state.activeTrack or (state.bottomRowTrack or 1)
    local trk = state.tracks and state.tracks[trkId]
    if trk then
      trk.attack = math.max(0, (trk.attack or 0) - 4)
      local ch = trk.channel or (trkId - 1)
      midi.sendMidiCC(24, trk.attack, ch)
      midi.sendMidiCC(73, trk.attack, ch)
      config.saveSettings()
      local spot = {
        title = "ATTACK (TRK " .. trkId .. ")",
        value = math.floor((trk.attack / 127) * 100) .. "%",
        subtext = (trk.name or ("Track " .. trkId)) .. " Envelope Attack",
        targetId = "key-25",
        color = trk.color or "#00e676"
      }
      hud.updateWebviewHud(spot)
    end
  elseif act == "atkUp" then
    local trkId = state.activeTrack or (state.bottomRowTrack or 1)
    local trk = state.tracks and state.tracks[trkId]
    if trk then
      trk.attack = math.min(127, (trk.attack or 0) + 4)
      local ch = trk.channel or (trkId - 1)
      midi.sendMidiCC(24, trk.attack, ch)
      midi.sendMidiCC(73, trk.attack, ch)
      config.saveSettings()
      local spot = {
        title = "ATTACK (TRK " .. trkId .. ")",
        value = math.floor((trk.attack / 127) * 100) .. "%",
        subtext = (trk.name or ("Track " .. trkId)) .. " Envelope Attack",
        targetId = "key-29",
        color = trk.color or "#00e676"
      }
      hud.updateWebviewHud(spot)
    end
  elseif act == "decDown" or act == "relDown" or act == "releaseDown" then
    local trkId = state.activeTrack or (state.bottomRowTrack or 1)
    local trk = state.tracks and state.tracks[trkId]
    if trk then
      trk.decay = math.max(0, (trk.decay or 64) - 4)
      local ch = trk.channel or (trkId - 1)
      midi.sendMidiCC(25, trk.decay, ch)
      midi.sendMidiCC(26, trk.decay, ch)
      midi.sendMidiCC(27, trk.decay, ch)
      midi.sendMidiCC(72, trk.decay, ch)
      config.saveSettings()
      local spot = {
        title = "DECAY & TAIL (TRK " .. trkId .. ")",
        value = math.floor((trk.decay / 127) * 100) .. "%",
        subtext = (trk.name or ("Track " .. trkId)) .. " Envelope Decay / Tail",
        targetId = "key-25",
        color = trk.color or "#ffd700"
      }
      hud.updateWebviewHud(spot)
    end
  elseif act == "decUp" or act == "relUp" or act == "releaseUp" then
    local trkId = state.activeTrack or (state.bottomRowTrack or 1)
    local trk = state.tracks and state.tracks[trkId]
    if trk then
      trk.decay = math.min(127, (trk.decay or 64) + 4)
      local ch = trk.channel or (trkId - 1)
      midi.sendMidiCC(25, trk.decay, ch)
      midi.sendMidiCC(26, trk.decay, ch)
      midi.sendMidiCC(27, trk.decay, ch)
      midi.sendMidiCC(72, trk.decay, ch)
      config.saveSettings()
      local spot = {
        title = "DECAY & TAIL (TRK " .. trkId .. ")",
        value = math.floor((trk.decay / 127) * 100) .. "%",
        subtext = (trk.name or ("Track " .. trkId)) .. " Envelope Decay / Tail",
        targetId = "key-29",
        color = trk.color or "#ffd700"
      }
      hud.updateWebviewHud(spot)
    end
  elseif act == "bpmEdit" then
    state.bpmInputMode = true
    state.bpmBeforeEdit = state.arpBpm
    state.bpmInputBuffer = ""
    local spot = {
      title = "EDIT BPM",
      value = "TYPE TEMPO",
      subtext = "Type digits & press Enter",
      targetId = "bpm-value",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)

  -- Transposition Actions
  elseif act == "trnspStep1Up" then
    applyTransposeDelta(1, "TRNSP +1 STEP")
  elseif act == "trnspStep1Down" then
    applyTransposeDelta(-1, "TRNSP -1 STEP")
  elseif act == "trnspStep2Up" then
    applyTransposeDelta(2, "TRNSP +2 STEPS (3RD)")
  elseif act == "trnspStep2Down" then
    applyTransposeDelta(-2, "TRNSP -2 STEPS (3RD)")
  elseif act == "trnspStep3Up" then
    applyTransposeDelta(3, "TRNSP +3 STEPS (4TH)")
  elseif act == "trnspStep3Down" then
    applyTransposeDelta(-3, "TRNSP -3 STEPS (4TH)")
  elseif act == "trnspNearRootUp" then
    local numIntervals = #config.SCALES[state.currentScaleIdx or 1].intervals
    local rem = (state.transposeShift % numIntervals + numIntervals) % numIntervals
    local delta = (rem == 0) and numIntervals or (numIntervals - rem)
    applyTransposeDelta(delta, "NEAR ROOT ↑")
  elseif act == "trnspNearSubDown" then
    local numIntervals = #config.SCALES[state.currentScaleIdx or 1].intervals
    local subtonic = numIntervals - 1
    local rem = (state.transposeShift % numIntervals + numIntervals) % numIntervals
    local delta = (rem - subtonic + numIntervals) % numIntervals
    if delta == 0 then delta = numIntervals end
    applyTransposeDelta(-delta, "NEAR SUBTONIC ↓")

  -- Mode Actions (Consolidated on G)
  elseif act == "modeStep2Up" then
    state.currentScaleIdx = ((state.currentScaleIdx + 1) % #config.SCALES) + 1
    arpeggiator.updateLatchedArpNotes()
    local sc = config.SCALES[state.currentScaleIdx]
    hud.updateWebviewHud({ title = "MODE +2", value = sc.name, subtext = sc.brightTag, targetId = "key-5", color = "#ffd700" })
  elseif act == "modeStep2Down" then
    state.currentScaleIdx = ((state.currentScaleIdx - 3 + #config.SCALES) % #config.SCALES) + 1
    arpeggiator.updateLatchedArpNotes()
    local sc = config.SCALES[state.currentScaleIdx]
    hud.updateWebviewHud({ title = "MODE -2", value = sc.name, subtext = sc.brightTag, targetId = "key-5", color = "#ffd700" })
  elseif act == "modeSetMajor" then
    state.currentScaleIdx = 2 -- Major / Ionian
    arpeggiator.updateLatchedArpNotes()
    hud.updateWebviewHud({ title = "MODE SNAP", value = config.SCALES[2].name, subtext = config.SCALES[2].brightTag, targetId = "key-5", color = "#50fa7b" })
  elseif act == "modeSetAeolian" then
    state.currentScaleIdx = 5 -- Natural Minor / Aeolian
    arpeggiator.updateLatchedArpNotes()
    hud.updateWebviewHud({ title = "MODE SNAP", value = config.SCALES[5].name, subtext = config.SCALES[5].brightTag, targetId = "key-5", color = "#64d8f0" })
  elseif act == "modeSetLydian" then
    state.currentScaleIdx = 1 -- Lydian
    arpeggiator.updateLatchedArpNotes()
    hud.updateWebviewHud({ title = "MODE SNAP", value = config.SCALES[1].name, subtext = config.SCALES[1].brightTag, targetId = "key-5", color = "#ffb86c" })
  elseif act == "modeSetLocrian" then
    state.currentScaleIdx = 7 -- Locrian
    arpeggiator.updateLatchedArpNotes()
    hud.updateWebviewHud({ title = "MODE SNAP", value = config.SCALES[7].name, subtext = config.SCALES[7].brightTag, targetId = "key-5", color = "#bd93f9" })

  -- Root Actions (Consolidated on H)
  elseif act == "rootFifthUp" then
    state.currentRoot = (state.currentRoot + 7) % 12
    arpeggiator.updateLatchedArpNotes()
    local name = config.NOTE_NAMES[state.currentRoot + 1]
    hud.updateWebviewHud({ title = "ROOT +5TH", value = name, subtext = "Circle of Fifths Clockwise", targetId = "key-4", color = "#ffd700" })
  elseif act == "rootFifthDown" then
    state.currentRoot = (state.currentRoot + 5) % 12
    arpeggiator.updateLatchedArpNotes()
    local name = config.NOTE_NAMES[state.currentRoot + 1]
    hud.updateWebviewHud({ title = "ROOT -5TH", value = name, subtext = "Circle of Fifths Counter-Clockwise", targetId = "key-4", color = "#ffd700" })
  elseif act == "rootSetC" then
    state.currentRoot = 0
    arpeggiator.updateLatchedArpNotes()
    hud.updateWebviewHud({ title = "ROOT SNAP", value = "C", subtext = "Concert Pitch Root", targetId = "key-4", color = "#50fa7b" })
  elseif act == "rootSetA" then
    state.currentRoot = 9
    arpeggiator.updateLatchedArpNotes()
    hud.updateWebviewHud({ title = "ROOT SNAP", value = "A", subtext = "Natural Minor Anchor", targetId = "key-4", color = "#64d8f0" })
  elseif act == "rootOctaveUp" then
    executeControlAction("octaveUp", code)
  elseif act == "rootOctaveDown" then
    executeControlAction("octaveDown", code)

  -- Octave Reset (Consolidated on D)
  elseif act == "octReset" then
    state.octaveShift = 0
    state.topRowOctaveOffset = 0
    state.bottomRowOctaveOffset = 0
    arpeggiator.updateLatchedArpNotes()
    hud.updateWebviewHud({ title = "OCTAVE RESET", value = "0 Oct", subtext = "All Octave Shifts Centered", targetId = "key-2", color = "#50fa7b" })

  -- Master Arp & Track Loop Lock (Consolidated on B)
  elseif act == "lockLoop" then
    local curId = state.activeTrack or 1
    local trk = state.tracks and state.tracks[curId]
    if trk then
      trk.locked = true
      trk.arpEnabled = true
      trk.arpLatchActive = true
      state.arpEnabled = true
      state.arpLatchActive = true
      hud.updateWebviewHud({ title = "LOOP LOCKED", value = "Track " .. curId .. " (" .. trk.name .. ") Looping 🔁", subtext = "Continuous background pattern", targetId = "key-11", color = trk.color or "#ffd700" })
    end
  elseif act == "lockAndSwap" then
    local curId = state.activeTrack or 1
    local curTrk = state.tracks and state.tracks[curId]
    if curTrk then
      curTrk.locked = true
      curTrk.arpEnabled = true
      curTrk.arpLatchActive = true
    end
    local nextId = (curId % 4) + 1
    selectTrack(nextId)
    local nextTrk = state.tracks and state.tracks[nextId]
    hud.updateWebviewHud({ title = "LOCKED & SWAPPED", value = "Track " .. curId .. " Looping 🔁", subtext = "Now playing Track " .. nextId .. " (" .. (nextTrk and nextTrk.name or "") .. ")", targetId = "key-11", color = "#ffd700" })
  elseif act == "lockAllTracks" then
    if state.tracks then
      for _, t in pairs(state.tracks) do
        if countTableKeys(t.heldNotes) > 0 then
          t.locked = true
          t.arpEnabled = true
          t.arpLatchActive = true
        end
      end
    end
    state.arpEnabled = true
    state.arpLatchActive = true
    hud.updateWebviewHud({ title = "LOCK 4 TRACKS", value = "All Active Loops Locked", subtext = "4-Track Sequence Running", targetId = "key-11", color = "#ffd700" })
  elseif act == "stopLoops" then
    arpeggiator.stopAllLoops()
    hud.updateWebviewHud({ title = "LOOPS STOPPED", value = "All Background Arps Silenced", subtext = "Arpeggiator Idle", targetId = "key-45", color = "#ff5555" })
  elseif act == "freezeAll" then
    state.arpLatchActive = true
    if state.tracks then
      for _, t in pairs(state.tracks) do
        if countTableKeys(t.heldNotes) > 0 then t.arpLatchActive = true end
      end
    end
    hud.updateWebviewHud({ title = "FREEZE ALL", value = "All Patterns Frozen", subtext = "Live Notes Latched", targetId = "key-11", color = "#64d8f0" })

  -- Freed Keys: K (Bottom 1<->2), L (Top 3<->4), ; (Focus/Mixer)
  elseif act == "botTrackToggle" then
    local nextId = (state.bottomRowTrack == 1) and 2 or 1
    selectTrack(nextId)
  elseif act == "botTrackLock" then
    local trkId = state.activeTrack or 1
    if trkId > 2 then trkId = 1 end
    if state.tracks and state.tracks[trkId] then
      state.tracks[trkId].locked = not state.tracks[trkId].locked
      hud.updateWebviewHud({ title = "TRACK " .. trkId .. " LOCK", value = "Track " .. trkId .. (state.tracks[trkId].locked and " LOCKED 🔒" or " UNLOCKED 🔓"), subtext = state.tracks[trkId].name, targetId = "key-40", color = "#ffd700" })
    end
  elseif act == "topTrackToggle" then
    local nextId = (state.topRowTrack == 3) and 4 or 3
    selectTrack(nextId)
  elseif act == "topTrackLock" then
    local trkId = state.activeTrack or 3
    if trkId <= 2 then trkId = 3 end
    if state.tracks and state.tracks[trkId] then
      state.tracks[trkId].locked = not state.tracks[trkId].locked
      hud.updateWebviewHud({ title = "TRACK " .. trkId .. " LOCK", value = "Track " .. trkId .. (state.tracks[trkId].locked and " LOCKED 🔒" or " UNLOCKED 🔓"), subtext = state.tracks[trkId].name, targetId = "key-37", color = "#ffd700" })
    end
  elseif act == "trackFocusCycle" then
    local nextId = (state.activeTrack % 4) + 1
    selectTrack(nextId)
  elseif act == "allMuteToggle" then
    local anyUnmuted = false
    if state.tracks then
      for _, t in pairs(state.tracks) do
        if not t.muted then anyUnmuted = true; break end
      end
      for _, t in pairs(state.tracks) do t.muted = anyUnmuted end
      syncTrackAudibility()
    end
    hud.updateWebviewHud({ title = "MASTER MIXER", value = anyUnmuted and "ALL TRACKS MUTED 🔇" or "ALL TRACKS UNMUTED 🔊", subtext = "Global Track Mute", targetId = "key-41", color = anyUnmuted and "#ff5555" or "#50fa7b" })
  elseif act == "mixReset" then
    if state.tracks then
      for _, t in pairs(state.tracks) do
        t.muted = false
        t.soloed = false
        t.volume = 100
      end
      syncTrackAudibility()
    end
    state.topRowVolume = 100
    state.bottomRowVolume = 100
    hud.updateWebviewHud({ title = "MIXER RESET", value = "All Volumes 100%", subtext = "All Mutes & Solos Cleared", targetId = "key-41", color = "#50fa7b" })

  -- Dedicated Track 1-4 Actions
  elseif string.match(act, "^trkSelect(%d)$") then
    local id = tonumber(string.match(act, "^trkSelect(%d)$"))
    selectTrack(id)
  elseif string.match(act, "^trkMute(%d)$") then
    local id = tonumber(string.match(act, "^trkMute(%d)$"))
    local trk = state.tracks and state.tracks[id]
    if trk then
      trk.muted = not trk.muted
      syncTrackAudibility()
      hud.updateWebviewHud({ title = "TRACK " .. id .. " (" .. trk.name .. ")", value = trk.muted and "MUTED 🔇" or "UNMUTED 🔊", subtext = "Mute Toggle", targetId = "key-" .. ({[1]=18,[2]=19,[3]=20,[4]=21})[id], color = trk.muted and "#ff5555" or "#50fa7b" })
    end
  elseif string.match(act, "^trkSolo(%d)$") then
    local id = tonumber(string.match(act, "^trkSolo(%d)$"))
    local trk = state.tracks and state.tracks[id]
    if trk then
      trk.soloed = not trk.soloed
      syncTrackAudibility()
      hud.updateWebviewHud({ title = "TRACK " .. id .. " (" .. trk.name .. ")", value = trk.soloed and "SOLO ON 🌟" or "SOLO OFF", subtext = "Solo Toggle", targetId = "key-" .. ({[1]=18,[2]=19,[3]=20,[4]=21})[id], color = trk.soloed and "#ffd700" or "#64d8f0" })
    end
  elseif string.match(act, "^trkRec(%d)$") then
    local id = tonumber(string.match(act, "^trkRec(%d)$"))
    local trk = state.tracks and state.tracks[id]
    if trk then
      trk.armed = not trk.armed
      hud.updateWebviewHud({ title = "TRACK " .. id .. " (" .. trk.name .. ")", value = trk.armed and "ARMED ⏺" or "DISARMED", subtext = "Record Arm", targetId = "key-" .. ({[1]=18,[2]=19,[3]=20,[4]=21})[id], color = trk.armed and "#ff5555" or "#64d8f0" })
    end
  elseif string.match(act, "^trkLock(%d)$") then
    local id = tonumber(string.match(act, "^trkLock(%d)$"))
    local trk = state.tracks and state.tracks[id]
    if trk then
      trk.locked = not trk.locked
      hud.updateWebviewHud({ title = "TRACK " .. id .. " (" .. trk.name .. ")", value = trk.locked and "LOCKED 🔒" or "UNLOCKED 🔓", subtext = "Pattern Hold", targetId = "key-" .. ({[1]=18,[2]=19,[3]=20,[4]=21})[id], color = "#ffd700" })
    end
  elseif string.match(act, "^trkClear(%d)$") then
    local id = tonumber(string.match(act, "^trkClear(%d)$"))
    arpeggiator.clearTrackArp(id)
    hud.updateWebviewHud({ title = "CLEAR TRACK " .. id, value = "Pattern Cleared", subtext = "Reset Sequence", targetId = "key-" .. ({[1]=18,[2]=19,[3]=20,[4]=21})[id], color = "#ff5555" })
  elseif string.match(act, "^trkFocus(%d)$") then
    local id = tonumber(string.match(act, "^trkFocus(%d)$"))
    selectTrack(id)

  -- Voicing Actions
  elseif act == "voicingUp" then
    state.chordIdx = ((state.chordIdx or 1) % #state.CHORDS) + 1
    arpeggiator.updateLatchedArpChordNotes()
    hud.updateWebviewHud({ title = "CHORD VOICING", value = state.CHORDS[state.chordIdx].name, subtext = "Voicing +", targetId = "key-39", color = "#ffd700" })
  elseif act == "voicingDown" then
    state.chordIdx = (((state.chordIdx or 1) - 2 + #state.CHORDS) % #state.CHORDS) + 1
    arpeggiator.updateLatchedArpChordNotes()
    hud.updateWebviewHud({ title = "CHORD VOICING", value = state.CHORDS[state.chordIdx].name, subtext = "Voicing -", targetId = "key-39", color = "#ffd700" })
  elseif act == "inversionUp" or act == "inversionDown" then
    hud.updateWebviewHud({ title = "INVERSION", value = "Inversion Modified", subtext = "Pitch Inversion", targetId = "key-39", color = "#ffd700" })
  elseif act == "chordPower" then
    state.chordIdx = 4
    arpeggiator.updateLatchedArpChordNotes()
    hud.updateWebviewHud({ title = "CHORD VOICING", value = "Power (1-5)", subtext = "Root + Fifth", targetId = "key-39", color = "#ffd700" })
  elseif act == "chordTriad" then
    state.chordIdx = 1
    arpeggiator.updateLatchedArpChordNotes()
    hud.updateWebviewHud({ title = "CHORD VOICING", value = "Triad", subtext = "Root + 3rd + 5th", targetId = "key-39", color = "#ffd700" })

  -- Arp Direction Presets (Key 5)
  elseif act == "arpDirRandom" then
    setActiveArpDirection(7)
    local trk = state.tracks and state.tracks[state.activeTrack or 1]
    hud.updateWebviewHud({ title = "ARP DIRECTION (TRK " .. (state.activeTrack or 1) .. ")", value = "RANDOM", subtext = "Random Order", targetId = "key-23", color = (trk and trk.color) or "#64d8f0" })
  elseif act == "arpDirConverge" then
    setActiveArpDirection(5)
    local trk = state.tracks and state.tracks[state.activeTrack or 1]
    hud.updateWebviewHud({ title = "ARP DIRECTION (TRK " .. (state.activeTrack or 1) .. ")", value = "CONVERGE", subtext = "Outside-In Order", targetId = "key-23", color = (trk and trk.color) or "#64d8f0" })
  elseif act == "arpDirDiverge" then
    setActiveArpDirection(6)
    local trk = state.tracks and state.tracks[state.activeTrack or 1]
    hud.updateWebviewHud({ title = "ARP DIRECTION (TRK " .. (state.activeTrack or 1) .. ")", value = "DIVERGE", subtext = "Inside-Out Order", targetId = "key-23", color = (trk and trk.color) or "#64d8f0" })
  elseif act == "arpDirUpDown" then
    setActiveArpDirection(3)
    local trk = state.tracks and state.tracks[state.activeTrack or 1]
    hud.updateWebviewHud({ title = "ARP DIRECTION (TRK " .. (state.activeTrack or 1) .. ")", value = "UP / DOWN", subtext = "Up then Down", targetId = "key-23", color = (trk and trk.color) or "#64d8f0" })
  elseif act == "arpDirDownUp" then
    setActiveArpDirection(4)
    local trk = state.tracks and state.tracks[state.activeTrack or 1]
    hud.updateWebviewHud({ title = "ARP DIRECTION (TRK " .. (state.activeTrack or 1) .. ")", value = "DOWN / UP", subtext = "Down then Up", targetId = "key-23", color = (trk and trk.color) or "#64d8f0" })
  elseif act == "arpDirReset" then
    setActiveArpDirection(1)
    local trk = state.tracks and state.tracks[state.activeTrack or 1]
    hud.updateWebviewHud({ title = "ARP DIRECTION (TRK " .. (state.activeTrack or 1) .. ")", value = "UP", subtext = "Default Upward", targetId = "key-23", color = (trk and trk.color) or "#64d8f0" })

  -- Arp Rate Presets (Key 6)
  elseif act == "arpRateTriplet" then
    setActiveArpRate(15) -- 1/8T
    hud.updateWebviewHud({ title = "ARP RATE", value = "1/8T (Triplet)", subtext = "Triplet Feel", targetId = "key-22", color = "#64d8f0" })
  elseif act == "arpRateStraight" then
    setActiveArpRate(6) -- 1/8
    hud.updateWebviewHud({ title = "ARP RATE", value = "1/8 (Straight)", subtext = "Straight Feel", targetId = "key-22", color = "#64d8f0" })
  elseif act == "arpRate16th" then
    setActiveArpRate(7) -- 1/16
    hud.updateWebviewHud({ title = "ARP RATE", value = "1/16th", subtext = "Sixteenth Notes", targetId = "key-22", color = "#64d8f0" })
  elseif act == "arpRate8th" then
    setActiveArpRate(6) -- 1/8
    hud.updateWebviewHud({ title = "ARP RATE", value = "1/8th", subtext = "Eighth Notes", targetId = "key-22", color = "#64d8f0" })
  elseif act == "arpRate32nd" then
    setActiveArpRate(8) -- 1/32
    hud.updateWebviewHud({ title = "ARP RATE", value = "1/32nd", subtext = "Thirty-Second Notes", targetId = "key-22", color = "#64d8f0" })
  elseif act == "arpRate4th" then
    setActiveArpRate(5) -- 1/4
    hud.updateWebviewHud({ title = "ARP RATE", value = "1/4th", subtext = "Quarter Notes", targetId = "key-22", color = "#64d8f0" })

  -- Arp Gate Presets (Key 7)
  elseif act == "arpGateStaccato" then
    state.arpGatePercent = 25.0
    arpeggiator.applyGatePercentChange()
    hud.updateWebviewHud({ title = "ARP GATE", value = "25% (Staccato)", subtext = "Short Plucks", targetId = "key-26", color = "#64d8f0" })
  elseif act == "arpGateLegato" then
    state.arpGatePercent = 100.0
    arpeggiator.applyGatePercentChange()
    hud.updateWebviewHud({ title = "ARP GATE", value = "100% (Legato)", subtext = "Continuous Sustained", targetId = "key-26", color = "#64d8f0" })
  elseif act == "arpGateOverlap" then
    state.arpGatePercent = 120.0
    arpeggiator.applyGatePercentChange()
    hud.updateWebviewHud({ title = "ARP GATE", value = "120% (Overlap)", subtext = "Overlapping Notes", targetId = "key-26", color = "#64d8f0" })
  elseif act == "arpGate80" then
    state.arpGatePercent = 80.0
    arpeggiator.applyGatePercentChange()
    hud.updateWebviewHud({ title = "ARP GATE", value = "80%", subtext = "Standard Gate", targetId = "key-26", color = "#64d8f0" })
  elseif act == "arpGate50" then
    state.arpGatePercent = 50.0
    arpeggiator.applyGatePercentChange()
    hud.updateWebviewHud({ title = "ARP GATE", value = "50%", subtext = "Medium Gate", targetId = "key-26", color = "#64d8f0" })
  elseif act == "arpGateReset" then
    state.arpGatePercent = 80.0
    arpeggiator.applyGatePercentChange()
    hud.updateWebviewHud({ title = "ARP GATE", value = "80%", subtext = "Default Gate Reset", targetId = "key-26", color = "#64d8f0" })

  -- Arp Sync & Clock (Key 8)
  elseif act == "splitArpToggle" then
    state.arpBottomEnabled = not state.arpBottomEnabled
    hud.updateWebviewHud({ title = "SPLIT ARP", value = state.arpBottomEnabled and "BOTTOM ROW ACTIVE" or "BOTTOM ROW MUTED", subtext = "Split Keyboard Arp", targetId = "key-28", color = "#64d8f0" })
  elseif act == "syncBpmToggle" then
    state.logicSyncEnabled = not state.logicSyncEnabled
    hud.updateWebviewHud({ title = "DAW SYNC", value = state.logicSyncEnabled and "ON (Logic Pro)" or "OFF (Internal)", subtext = "BPM Clock Source", targetId = "key-28", color = state.logicSyncEnabled and "#50fa7b" or "#ff5555" })
  elseif act == "freeClockToggle" then
    state.logicSyncEnabled = false
    hud.updateWebviewHud({ title = "DAW SYNC", value = "OFF (Free Clock)", subtext = "Internal Clock Only", targetId = "key-28", color = "#ff5555" })
  elseif act == "topBoostUp" then
    state.splitArpTopBoost = math.min(50, (state.splitArpTopBoost or 20) + 5)
    hud.updateWebviewHud({ title = "TOP BOOST", value = "+" .. state.splitArpTopBoost .. " Vel", subtext = "Split Arp Lead Boost", targetId = "key-28", color = "#64d8f0" })
  elseif act == "topBoostDown" then
    state.splitArpTopBoost = math.max(0, (state.splitArpTopBoost or 20) - 5)
    hud.updateWebviewHud({ title = "TOP BOOST", value = "+" .. state.splitArpTopBoost .. " Vel", subtext = "Split Arp Lead Boost", targetId = "key-28", color = "#64d8f0" })
  elseif act == "clockDiv2" then
    state.arpBpm = math.max(20.0, (state.arpBpm or 120.0) / 2)
    arpeggiator.applyBpmChange()
    hud.updateWebviewHud({ title = "CLOCK /2", value = arpeggiator.formatBpm(state.arpBpm) .. " BPM", subtext = "Half-Time", targetId = "key-28", color = "#64d8f0" })
  elseif act == "clockMul2" then
    state.arpBpm = math.min(300.0, (state.arpBpm or 120.0) * 2)
    arpeggiator.applyBpmChange()
    hud.updateWebviewHud({ title = "CLOCK x2", value = arpeggiator.formatBpm(state.arpBpm) .. " BPM", subtext = "Double-Time", targetId = "key-28", color = "#64d8f0" })

  -- Release Presets (Key 9)
  elseif act == "relMax" then
    state.ccStates[72] = 127
    midi.sendMidiCC(72, 127)
    hud.updateWebviewHud({ title = "SYNTH RELEASE", value = "MAX (100%)", subtext = "CC #72 Level", targetId = "key-25", color = "#cf9ee1" })
  elseif act == "relMin" then
    state.ccStates[72] = 0
    midi.sendMidiCC(72, 0)
    hud.updateWebviewHud({ title = "SYNTH RELEASE", value = "MIN (0%)", subtext = "CC #72 Level", targetId = "key-25", color = "#cf9ee1" })
  elseif act == "relDefault" then
    state.ccStates[72] = 64
    midi.sendMidiCC(72, 64)
    hud.updateWebviewHud({ title = "SYNTH RELEASE", value = "DEFAULT (50%)", subtext = "CC #72 Level", targetId = "key-25", color = "#cf9ee1" })
  elseif act == "rel50" then
    state.ccStates[72] = 64
    midi.sendMidiCC(72, 64)
    hud.updateWebviewHud({ title = "SYNTH RELEASE", value = "50%", subtext = "CC #72 Level", targetId = "key-25", color = "#cf9ee1" })
  elseif act == "rel75" then
    state.ccStates[72] = 96
    midi.sendMidiCC(72, 96)
    hud.updateWebviewHud({ title = "SYNTH RELEASE", value = "75%", subtext = "CC #72 Level", targetId = "key-25", color = "#cf9ee1" })
  elseif act == "rel25" then
    state.ccStates[72] = 32
    midi.sendMidiCC(72, 32)
    hud.updateWebviewHud({ title = "SYNTH RELEASE", value = "25%", subtext = "CC #72 Level", targetId = "key-25", color = "#cf9ee1" })

  -- Volume & Mod Presets (Key 0)
  elseif act == "vol100" then
    state.topRowVolume = 127
    state.bottomRowVolume = 127
    hud.updateWebviewHud({ title = "MASTER VOLUME", value = "100%", subtext = "Full Velocity", targetId = "key-29", color = "#50fa7b" })
  elseif act == "vol75" then
    state.topRowVolume = 95
    state.bottomRowVolume = 95
    hud.updateWebviewHud({ title = "MASTER VOLUME", value = "75%", subtext = "Medium Velocity", targetId = "key-29", color = "#64d8f0" })
  elseif act == "modMax" then
    state.ccStates[1] = 127
    _G.activeWatchers.modAccumulator = 127
    midi.sendMidiCC(1, 127)
    hud.updateWebviewHud({ title = "MOD WHEEL", value = "100% (127)", subtext = "Max CC #1", targetId = "key-29", color = "#ffd700" })
  elseif act == "mod0" then
    state.ccStates[1] = 0
    _G.activeWatchers.modAccumulator = 0
    midi.sendMidiCC(1, 0)
    hud.updateWebviewHud({ title = "MOD WHEEL", value = "0%", subtext = "Min CC #1", targetId = "key-29", color = "#ffd700" })

  -- BPM Presets (Keys - and =)
  elseif act == "bpmDown10" then
    state.arpBpm = math.max(20.0, (state.arpBpm or 120.0) - 10)
    arpeggiator.applyBpmChange()
    hud.updateWebviewHud({ title = "TEMPO -10", value = arpeggiator.formatBpm(state.arpBpm) .. " BPM", subtext = "BPM -10", targetId = "key-27", color = "#64d8f0" })
  elseif act == "bpmDown20" then
    state.arpBpm = math.max(20.0, (state.arpBpm or 120.0) - 20)
    arpeggiator.applyBpmChange()
    hud.updateWebviewHud({ title = "TEMPO -20", value = arpeggiator.formatBpm(state.arpBpm) .. " BPM", subtext = "BPM -20", targetId = "key-27", color = "#64d8f0" })
  elseif act == "bpmUp10" then
    state.arpBpm = math.min(300.0, (state.arpBpm or 120.0) + 10)
    arpeggiator.applyBpmChange()
    hud.updateWebviewHud({ title = "TEMPO +10", value = arpeggiator.formatBpm(state.arpBpm) .. " BPM", subtext = "BPM +10", targetId = "key-24", color = "#64d8f0" })
  elseif act == "bpmUp20" then
    state.arpBpm = math.min(300.0, (state.arpBpm or 120.0) + 20)
    arpeggiator.applyBpmChange()
    hud.updateWebviewHud({ title = "TEMPO +20", value = arpeggiator.formatBpm(state.arpBpm) .. " BPM", subtext = "BPM +20", targetId = "key-24", color = "#64d8f0" })
  elseif act == "bpm120" then
    state.arpBpm = 120.0
    arpeggiator.applyBpmChange()
    hud.updateWebviewHud({ title = "TEMPO", value = "120 BPM", subtext = "Standard Preset", targetId = "key-27", color = "#64d8f0" })
  elseif act == "bpm90" then
    state.arpBpm = 90.0
    arpeggiator.applyBpmChange()
    hud.updateWebviewHud({ title = "TEMPO", value = "90 BPM", subtext = "Lofi / Hip-hop Preset", targetId = "key-27", color = "#64d8f0" })
  elseif act == "bpm70" then
    state.arpBpm = 70.0
    arpeggiator.applyBpmChange()
    hud.updateWebviewHud({ title = "TEMPO", value = "70 BPM", subtext = "Ballad Preset", targetId = "key-27", color = "#64d8f0" })
  elseif act == "bpm140" then
    state.arpBpm = 140.0
    arpeggiator.applyBpmChange()
    hud.updateWebviewHud({ title = "TEMPO", value = "140 BPM", subtext = "Trap / Dubstep Preset", targetId = "key-24", color = "#64d8f0" })
  elseif act == "bpm160" then
    state.arpBpm = 160.0
    arpeggiator.applyBpmChange()
    hud.updateWebviewHud({ title = "TEMPO", value = "160 BPM", subtext = "DnB Preset", targetId = "key-24", color = "#64d8f0" })
  elseif act == "bpmMin" then
    state.arpBpm = 20.0
    arpeggiator.applyBpmChange()
    hud.updateWebviewHud({ title = "TEMPO MIN", value = "20 BPM", subtext = "Minimum Tempo", targetId = "key-27", color = "#64d8f0" })
  elseif act == "bpmMax" then
    state.arpBpm = 300.0
    arpeggiator.applyBpmChange()
    hud.updateWebviewHud({ title = "TEMPO MAX", value = "300 BPM", subtext = "Maximum Tempo", targetId = "key-24", color = "#64d8f0" })
  elseif act == "tapTempo" then
    if arpeggiator.tapTempo then
      arpeggiator.tapTempo()
    end
    hud.updateWebviewHud({ title = "TAP TEMPO", value = arpeggiator.formatBpm(state.arpBpm) .. " BPM", subtext = "Tap rhythm to set tempo", targetId = "key-24", color = "#ffd700" })
  end

  config.saveSettings()
end

local function shouldRepeat(act)
  if not act then return false end
  local repeatingActions = {
    bpmUp = true, bpmDown = true,
    atkUp = true, atkDown = true, decUp = true, decDown = true,
    relUp = true, relDown = true, releaseUp = true, releaseDown = true,
    arpGateUp = true, arpGateDown = true,
    volUp = true, volDown = true, volume = true,
    topVolUp = true, topVolDown = true,
    botVolUp = true, botVolDown = true,
    modWheelUp = true, modWheelDown = true, modWheel = true
  }
  return repeatingActions[act] == true
end

local function handleKeyDown(code, externalNoteKey)
  if code == 50 then -- Backtick
    state.modeSelectHeld = true
    state.modeWasSelectedDuringHold = false
    hud.updateWebviewHud()
    return true
  end

  if not externalNoteKey and state.modeSelectHeld then
    -- Mode Selector is Active!
    if code == 0 then -- 'a' key
      state.currentMode = "ArpAdvanced"
      state.modeWasSelectedDuringHold = true
      -- Release any currently pressed piano keys to prevent stuck notes
      local keysToRelease = {}
      for heldCode, _ in pairs(state.pressedKeys) do
        table.insert(keysToRelease, heldCode)
      end
      for _, heldCode in ipairs(keysToRelease) do
        handleKeyUp(heldCode)
      end
      hud.updateWebviewHud()
      return true
    end
    -- If it's another key, ignore/block it while mode selector is held
    return true 
  end

  if state.pressedKeys[code] then
    return true
  end

  local propDef = hud.getProposedActionDef and hud.getProposedActionDef(code)
  local actionToExecute = propDef and propDef.action

  if not actionToExecute or actionToExecute == "" or actionToExecute == "none" then
    local k = config.getNumberControlKey(code) or config.getControlKey(code)
    if k then
      if (state.shiftHeld or state.altHeld) and k.shiftAction and k.shiftAction ~= "" and k.shiftAction ~= "none" then
        actionToExecute = k.shiftAction
      elseif k.action and k.action ~= "" and k.action ~= "none" then
        actionToExecute = k.action
      end
    end
  end
  if externalNoteKey then actionToExecute = nil end

  if actionToExecute and actionToExecute ~= "" and actionToExecute ~= "none" then
    state.pressedKeys[code] = { isControl = true, action = actionToExecute }
    hud.updateSingleKeyState(code, true, false)
    
    state.controlKeyDownTime = state.controlKeyDownTime or {}
    state.controlKeyDownSnapshots = state.controlKeyDownSnapshots or {}
    state.controlKeyDownTime[code] = hs.timer.secondsSinceEpoch()
    state.controlKeyDownSnapshots[code] = captureStateSnapshot("Pre-hold")

    executeControlAction(actionToExecute, code)
    if shouldRepeat(actionToExecute) then
      stopControlRepeat(code)
      local entry = {}
      controlRepeatTimers[code] = entry
      entry.timer = hs.timer.doAfter(0.35, function()
        if not controlRepeatTimers[code] then return end
        if state.pressedKeys[code] then
          entry.interval = hs.timer.doEvery(0.08, function()
            if not controlRepeatTimers[code] then return end
            local savedFn = pushStateSnapshot
            pushStateSnapshot = function() end
            pcall(executeControlAction, actionToExecute, code)
            pushStateSnapshot = savedFn
          end)
        end
      end)
    else
      stopControlRepeat(code)
    end
    return true
  end

  local noteKey = externalNoteKey or config.getNoteKey(code)
  if noteKey then
    local isTop = noteKey.isTop
    local trkIdx = isTop and (state.topRowTrack or 3) or (state.bottomRowTrack or 1)
    local trk = state.tracks and state.tracks[trkIdx]
    local now = hs.timer.secondsSinceEpoch()

    -- Count physical keys held on this track before registering this key
    local numPhysHeld = 0
    if trk and trk.physicalKeysHeld then
      for _ in pairs(trk.physicalKeysHeld) do
        numPhysHeld = numPhysHeld + 1
      end
    end

    if trk then
      trk.physicalKeysHeld = trk.physicalKeysHeld or {}
      trk.physicalKeysHeld[code] = true
    end
    local ch = trk and trk.channel or (isTop and (state.topRowChannel or 2) or (state.bottomRowChannel or 0))
    local transposedPitch = transposer.getTransposedPitch(noteKey.baseNote, isTop)

    -- Track-independent chord mode
    local isChordActive = (trk and trk.chordModeActive) or state.quoteHeld
    local chordPitches = isChordActive and transposer.getChordPitches(noteKey.baseNote, isTop, true, trk and trk.chordIdx) or { transposedPitch }
    local arpActive = trk and trk.arpEnabled or false
    local isArpNote = (not state.arpBypassed) and arpActive and (not state.shiftHeld)

    -- Track-independent sustain mode
    local susMode = (trk and trk.sustainMode) or "smart"
    if state.tabDamping then
      susMode = "off"
    end
    local sustainPedalHeld = false
    for c, info in pairs(state.pressedKeys) do
      if type(info) == "table" and info.isControl and (info.action == "sustain" or info.action == "classicSustain") then
        sustainPedalHeld = true
        break
      end
    end
    if sustainPedalHeld and susMode == "off" and not state.tabDamping then
      susMode = "smart"
    end

    -- Smart Sustain Auto-Reset Engine
    if trk and susMode == "smart" and not isArpNote then
      local chordWindow = 0.12 -- 120ms grouping window for multi-finger chord strikes
      local isNewChord = (numPhysHeld == 0) or ((now - (trk.chordStartTime or 0)) > chordWindow)
      if isNewChord then
        -- Silence previously sustained pitches on this track that are NOT physically held down right now
        if trk.sustainedPitches then
          for _, item in ipairs(trk.sustainedPitches) do
            local p = item.pitch
            local itemCh = item.channel or ch
            local isStillPhysHeld = false
            for heldCode, _ in pairs(trk.physicalKeysHeld) do
              if heldCode ~= code then
                local kInfo = state.pressedKeys[heldCode]
                if kInfo and kInfo.pitches then
                  for _, hp in ipairs(kInfo.pitches) do
                    if hp == p then isStillPhysHeld = true; break end
                  end
                end
              end
              if isStillPhysHeld then break end
            end
            if not isStillPhysHeld then
              midi.sendMidiNote("noteOff", p, 0, itemCh)
            end
          end
        end
        trk.sustainedPitches = {}
        trk.chordStartTime = now
      end
      -- Latch new pitches into trk.sustainedPitches
      trk.sustainedPitches = trk.sustainedPitches or {}
      for _, p in ipairs(chordPitches) do
        table.insert(trk.sustainedPitches, { pitch = p, channel = ch })
      end
    elseif trk and susMode == "classic" and not isArpNote then
      -- Classic cumulative sustain: append without clearing
      trk.sustainedPitches = trk.sustainedPitches or {}
      for _, p in ipairs(chordPitches) do
        table.insert(trk.sustainedPitches, { pitch = p, channel = ch })
      end
    end

    local effectiveSustain = (susMode ~= "off")
    state.pressedKeys[code] = { pitches = chordPitches, isArpNote = isArpNote, isSustainedNote = effectiveSustain, channel = ch, track = trkIdx, isTop = isTop }
    
    if isArpNote then 
      for _, p in ipairs(chordPitches) do arpeggiator.arpAddNote(code .. "_" .. p, p, trkIdx) end
    else 
      if isTrackAudible(trkIdx) then
        local quantMode = state.inputQuantizeMode or "Off"
        local bpm = state.arpBpm or 120.0
        local vel = transposer.getEffectiveRowVelocity(isTop)

        if trk then trk.activeNotesCount = (trk.activeNotesCount or 0) + #chordPitches end

        quantizer.queueNoteOn("qwerty_" .. code, chordPitches, vel, ch, bpm, quantMode, function(pitches, v, channel)
          for _, p in ipairs(pitches) do
            midi.sendMidiNote("noteOn", p, v, channel)
          end
        end)
      end
    end
    if not externalNoteKey then hud.updateSingleKeyState(code, true, false) end
    if hudModule and hudModule.fastUpdateArp then hudModule.fastUpdateArp() end
    return true
  end

  return true
end

local function handleKeyUp(code, externalNoteKey)
  if not externalNoteKey and code == 50 then -- Backtick released
    stopControlRepeat(code)
    state.modeSelectHeld = false
    if not state.modeWasSelectedDuringHold then
      state.currentMode = "Home"
      local keysToRelease = {}
      for heldCode, _ in pairs(state.pressedKeys) do
        table.insert(keysToRelease, heldCode)
      end
      for _, heldCode in ipairs(keysToRelease) do
        handleKeyUp(heldCode)
      end
    end
    hud.updateWebviewHud()
    return true
  end

  local keyInfo = state.pressedKeys[code]
  if keyInfo and type(keyInfo) == "table" and keyInfo.isProposed then
    state.pressedKeys[code] = nil
    hud.updateSingleKeyState(code, false, false)
    return true
  end

  if keyInfo and type(keyInfo) == "table" and not keyInfo.isControl and keyInfo.pitches then
    local pitches = keyInfo.pitches
    local isArpNote = keyInfo.isArpNote
    local isSustainedNote = keyInfo.isSustainedNote
    local keyChannel = keyInfo.channel or 0
    local isTop = keyInfo.isTop
    local trkId = keyInfo.track or (isTop and (state.topRowTrack or 3) or (state.bottomRowTrack or 1))
    local trk = state.tracks and state.tracks[trkId]
    if trk and trk.physicalKeysHeld then
      trk.physicalKeysHeld[code] = nil
    end
    if trk and not isArpNote then
      trk.activeNotesCount = math.max(0, (trk.activeNotesCount or 0) - #pitches)
    end

    if isArpNote then
      for _, p in ipairs(pitches) do arpeggiator.arpRemoveNote(code .. "_" .. p, trkId) end
    else
      local sustainPedalHeld = false
      for c, info in pairs(state.pressedKeys) do
        if type(info) == "table" and info.isControl and (info.action == "sustain" or info.action == "classicSustain") then
          sustainPedalHeld = true
          break
        end
      end

      local susMode = (trk and trk.sustainMode) or "smart"
      if state.tabDamping then susMode = "off" end
      if sustainPedalHeld and susMode == "off" and not state.tabDamping then susMode = "smart" end
      local isSustained = (not state.tabDamping) and (isSustainedNote or (susMode ~= "off"))

      quantizer.queueNoteOff("qwerty_" .. code, function(releasedPitches, channel)
        for _, playedPitch in ipairs(releasedPitches or pitches) do
          if isSustained and susMode ~= "off" then
            if trk then
              trk.sustainedPitches = trk.sustainedPitches or {}
              local found = false
              for _, item in ipairs(trk.sustainedPitches) do
                if item.pitch == playedPitch and item.channel == (channel or keyChannel) then
                  found = true
                  break
                end
              end
              if not found then
                table.insert(trk.sustainedPitches, { pitch = playedPitch, channel = channel or keyChannel })
              end
            end
          else
            midi.sendMidiNote("noteOff", playedPitch, 0, channel or keyChannel)
          end
        end
      end)
    end
    state.pressedKeys[code] = nil
    if not externalNoteKey then
      hud.updateSingleKeyState(code, false, false)
      hud.updateWebviewHud()
    end
    return true
  end

  local noteKey = externalNoteKey or config.getNoteKey(code)
  if noteKey then
    -- Fallback if pressedKeys entry was missing
    local isTop = noteKey.isTop
    local chordPitches = transposer.getChordPitches(noteKey.baseNote, isTop)
    local ch = isTop and (state.topRowChannel or 0) or (state.bottomRowChannel or 0)
    for _, pitch in ipairs(chordPitches) do
      midi.sendMidiNote("noteOff", pitch, 0, ch)
    end
    hud.updateSingleKeyState(code, false, false)
    return true
  end

  local numCtrlKey = config.getNumberControlKey(code)
  if numCtrlKey then
    stopControlRepeat(code)
      state.pressedKeys[code] = nil
      hud.updateSingleKeyState(code, false, false)
      hud.updateWebviewHud()
      return true
  end

  local function cleanupSustainPitches(targetTrackId)
    local tracksToClean = targetTrackId and { [targetTrackId] = state.tracks and state.tracks[targetTrackId] } or (state.tracks or {})
    for tId, trk in pairs(tracksToClean) do
      if trk and trk.sustainedPitches then
        for _, item in ipairs(trk.sustainedPitches) do
          if type(item) == "table" and item.pitch then
            local pitch = item.pitch
            local channel = item.channel or trk.channel or 0
            local isCurrentlyHeld = false
            for _, kInfo in pairs(state.pressedKeys) do
              if type(kInfo) == "table" and not kInfo.isControl and kInfo.pitches and kInfo.track == tId then
                for _, p in ipairs(kInfo.pitches) do
                  if p == pitch then
                    isCurrentlyHeld = true
                    break
                  end
                end
                if isCurrentlyHeld then break end
              end
            end
            local isArpActivePitch = trk.currentPitch and ((type(trk.currentPitch) == "table" and trk.currentPitch.pitch or trk.currentPitch) == pitch)
            if not isCurrentlyHeld and not isArpActivePitch then
              midi.sendMidiNote("noteOff", pitch, 0, channel)
            end
          end
        end
        trk.sustainedPitches = {}
      end
    end
    if not targetTrackId and state.sustainedPitches then
      for _, item in ipairs(state.sustainedPitches) do
        if type(item) == "table" and item.pitch then
          midi.sendMidiNote("noteOff", item.pitch, 0, item.channel or 0)
        end
      end
      state.sustainedPitches = {}
    end
  end

  local ctrlKey = config.getControlKey(code)
  if ctrlKey then
    stopControlRepeat(code)
    state.pressedKeys[code] = nil
    hud.updateSingleKeyState(code, false, false)
    local act = (keyInfo and keyInfo.action) or ((state.shiftHeld or state.altHeld) and ctrlKey.shiftAction or ctrlKey.action)
    
    local holdDuration = state.controlKeyDownTime and state.controlKeyDownTime[code] and (hs.timer.secondsSinceEpoch() - state.controlKeyDownTime[code]) or 0
    if holdDuration > 0.25 and not shouldRepeat(act) and act ~= "bpmEdit" and act ~= "sustain" and act ~= "classicSustain" then
      if state.controlKeyDownSnapshots and state.controlKeyDownSnapshots[code] then
        applyStateSnapshot(state.controlKeyDownSnapshots[code])
        return true
      end
    end

    if act == "sustain" then
      state.tabDamping = false
      local activeTrkId = state.activeTrack or 1
      local trk = state.tracks and state.tracks[activeTrkId]
      if trk then
        if state.altHeld then
          -- Option + Tab explicitly toggles sustain off / on
          trk.sustainMode = (trk.sustainMode == "off") and "smart" or "off"
          if trk.sustainMode == "off" then
            cleanupSustainPitches(activeTrkId)
          end
        end
        -- Record only short base-layer taps. Holds remain momentary damping,
        -- and Option+Tab keeps its separately displayed behavior.
        if not state.altHeld and holdDuration <= 0.25 and trk.sustainMode ~= "off" then
          trk.lastSmartSustainTapAt = hs.timer.secondsSinceEpoch()
        elseif holdDuration > 0.25 then
          trk.lastSmartSustainTapAt = nil
        end
        state.sustainActive = (trk.sustainMode ~= "off")
        config.saveSettings()
        local isSmart = (trk.sustainMode == "smart")
        local isClassic = (trk.sustainMode == "classic")
        local isSusOn = (trk.sustainMode ~= "off")
        local spot = {
          title = "SMART SUSTAIN (TRK " .. activeTrkId .. ")",
          value = isSmart and "SMART ON" or (isClassic and "CLASSIC ON" or "OFF"),
          subtext = isSmart and "Tap Tab to damp · double-tap Tab to turn off" or (isClassic and "Classic sustain active" or "Sustain disabled"),
          targetId = "key-48",
          color = isSusOn and (trk.color or "#00e5ff") or "#b5aba0"
        }
        hud.updateWebviewHud(spot)
      end
    elseif act == "classicSustain" then
      local activeTrkId = state.activeTrack or 1
      local trk = state.tracks and state.tracks[activeTrkId]
      if trk then
        if trk.classicWasActiveOnPress then
          trk.sustainMode = "smart"
        else
          trk.sustainMode = "classic"
          for c, kInfo in pairs(state.pressedKeys) do
            if type(kInfo) == "table" and not kInfo.isControl and kInfo.track == activeTrkId and not kInfo.isArpNote then
              kInfo.isSustainedNote = true
              local pitches = kInfo.pitches or { kInfo.pitch }
              local ch = kInfo.channel or trk.channel or 0
              for _, p in ipairs(pitches) do
                if p then
                  trk.sustainedPitches = trk.sustainedPitches or {}
                  table.insert(trk.sustainedPitches, { pitch = p, channel = ch })
                end
              end
            end
          end
        end
        state.sustainActive = (trk.sustainMode ~= "off")
        config.saveSettings()
        local isClassic = (trk.sustainMode == "classic")
        local spot = {
          title = "CLASSIC SUSTAIN (TRK " .. activeTrkId .. ")",
          value = isClassic and "CLASSIC ON" or "SMART ON",
          subtext = isClassic and "Cumulative sustain across releases (can get muddy)" or "Smart sustain active",
          targetId = "key-48",
          color = trk.color or "#00e5ff"
        }
        hud.updateWebviewHud(spot)
      end
    elseif act == "chordToggle" then
      local activeTrkId = state.activeTrack or 1
      local trk = state.tracks and state.tracks[activeTrkId]
      if trk then
        if trk.chordWasActiveOnPress then
          trk.chordModeActive = false
        else
          trk.chordModeActive = true
        end
        state.chordModeActive = (trk.chordModeActive == true)
        config.saveSettings()
        local chordName = state.CHORDS[trk.chordIdx or state.chordIdx or 1].name
        local spot = {
          title = "CHORD MODE (TRK " .. activeTrkId .. ")",
          value = trk.chordModeActive and ("ON (" .. chordName .. ")") or "OFF",
          subtext = trk.chordModeActive and ("Chords active on Track " .. activeTrkId .. " (" .. ((trk and trk.name) or "") .. ")") or ("Single notes on Track " .. activeTrkId),
          targetId = "key-39",
          color = trk.chordModeActive and (trk.color or "#00e5ff") or "#b5aba0"
        }
        hud.updateWebviewHud(spot)
      end
    else
      hud.updateWebviewHud()
    end
    return true
  end

  -- Fallback cleanup for unmapped or ignored keys
  if state.pressedKeys[code] then
    state.pressedKeys[code] = nil
  end

  return true
end

return {
  selectTrack = selectTrack,
  executeControlAction = executeControlAction,
  setActiveArpDirection = setActiveArpDirection,
  getActiveArpDirectionIdx = getActiveArpDirectionIdx,
  handleKeyDown = handleKeyDown,
  handleKeyUp = handleKeyUp,
  handleKeyStepNoteOn = function(note, velocity, channel)
    local token = "keystep_" .. tostring(channel or 0) .. "_" .. tostring(note)
    if state.pressedKeys[token] then return end
    handleKeyDown(token, { baseNote = note, isTop = false })
  end,
  handleKeyStepNoteOff = function(note, channel)
    local token = "keystep_" .. tostring(channel or 0) .. "_" .. tostring(note)
    if state.pressedKeys[token] then handleKeyUp(token, { baseNote = note, isTop = false }) end
  end,
  handleKeyStepDisconnect = function()
    local held = {}
    for code in pairs(state.pressedKeys) do
      if type(code) == "string" and code:match("^keystep_") then held[#held + 1] = code end
    end
    for _, code in ipairs(held) do
      if state.pressedKeys[code] then handleKeyUp(code, { isTop = false }) end
    end
  end,
  stopAllControlRepeats = stopAllControlRepeats,
  syncTrackAudibility = syncTrackAudibility,
  isTrackAudible = isTrackAudible
}
