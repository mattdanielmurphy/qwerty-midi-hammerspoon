local config = require("config")
local midi = require("midi")
local transposer = require("transposer")
local arpeggiator = require("arpeggiator")
local quantizer = require("quantizer")
local hud = require("hud")

local state = config.state
local SCALES = config.SCALES
local NOTE_NAMES = config.NOTE_NAMES

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
  local prevRateIdx = state.arpRateIdx
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
  state.arpRateIdx = snap.arpRateIdx
  state.arpGatePercent = snap.arpGatePercent
  state.arpBpm = snap.arpBpm
  state.arpTopEnabled = snap.arpTopEnabled
  state.arpBottomEnabled = snap.arpBottomEnabled
  if snap.arpLinked ~= nil then state.arpLinked = snap.arpLinked end
  state.ccStates[1] = snap.modWheel
  
  if snap.sustainActive ~= nil then state.sustainActive = snap.sustainActive end
  if snap.chordModeActive ~= nil then state.chordModeActive = snap.chordModeActive end

  arpeggiator.updateLatchedArpNotes()
  if snap.arpBpm ~= prevBpm or snap.arpRateIdx ~= prevRateIdx then
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
    state.arpRateIdx = rate
    arpeggiator.applyBpmChange()
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
    state.arpLatchActive = not state.arpLatchActive
    if not state.arpLatchActive then
      local newHeld = {}
      for codeKey, pitch in pairs(state.arpHeldNotes) do
        if state.arpKeysCurrentlyHeld[codeKey] then
          newHeld[codeKey] = pitch
        end
      end
      state.arpHeldNotes = newHeld
    end
    hud.updateWebviewHud()
    return
  end

  -- Record state snapshot before mutating controller parameters
  if act == "modeDown" or act == "modeUp" or
     act == "rootDown" or act == "rootUp" or act == "randomScale" or act == "resetAll" or
     act == "arpToggle" or act == "arpTopToggle" or act == "arpBottomToggle" or
     act == "arpLinkToggle" or act == "arpDirDown" or act == "arpDirUp" or act == "arpRateDown" or act == "arpRateUp" or
     act == "arpGateDown" or act == "arpGateUp" or act == "bpmDown" or act == "bpmUp" or
     act == "relDown" or act == "relUp" or act == "releaseDown" or act == "releaseUp" or
     act == "volDown" or act == "volUp" or act == "topVolDown" or act == "topVolUp" or
     act == "modWheelDown" or act == "modWheelUp" or act == "botOctDown" or act == "botOctUp" then
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
    local newO = curO - 12
    local ok, finalT, finalO, finalTop, finalBot = canApplyShifts(curT, newO, curTop, curBot)
    if ok then
      pushStateSnapshot(act)
      state.transposeShift = finalT
      state.octaveShift = finalO
      state.topRowOctaveOffset = finalTop
      state.bottomRowOctaveOffset = finalBot
      arpeggiator.updateLatchedArpNotes()
      local spot = {
        title = "OCTAVE",
        value = (state.octaveShift >= 0 and "+" or "") .. math.floor(state.octaveShift / 12) .. " Oct",
        subtext = "All keys shifted",
        targetId = "octave-indicator-bottom",
        color = "#d4a359"
      }
      hud.updateWebviewHud(spot)
    end
  elseif act == "octaveUp" then
    local curT = tonumber(state.transposeShift) or 0
    local curO = tonumber(state.octaveShift) or 0
    local curTop = tonumber(state.topRowOctaveOffset) or 0
    local curBot = tonumber(state.bottomRowOctaveOffset) or 0
    local newO = curO + 12
    local ok, finalT, finalO, finalTop, finalBot = canApplyShifts(curT, newO, curTop, curBot)
    if ok then
      pushStateSnapshot(act)
      state.transposeShift = finalT
      state.octaveShift = finalO
      state.topRowOctaveOffset = finalTop
      state.bottomRowOctaveOffset = finalBot
      arpeggiator.updateLatchedArpNotes()
      local spot = {
        title = "OCTAVE",
        value = (state.octaveShift >= 0 and "+" or "") .. math.floor(state.octaveShift / 12) .. " Oct",
        subtext = "All keys shifted",
        targetId = "octave-indicator-bottom",
        color = "#d4a359"
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
    state.arpRateIdx = math.random(1, #state.ARP_RATES)
    state.arpGatePercent = math.random(25, 120)
    arpeggiator.applyBpmChange()
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
    state.arpRateIdx = math.random(1, #state.ARP_RATES)
    state.arpGatePercent = math.random(25, 120)
    arpeggiator.updateLatchedArpNotes()
    arpeggiator.applyBpmChange()
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
    midi.panicAllChannels()
    state.sustainActive = false
    state.sustainKeyDownTime = nil
    state.arpLatchActive = false
    state.sustainedPitches = {}
    state.pressedKeys = {}

    arpeggiator.stopArpTimer()
    state.arpHeldNotes = {}
    state.arpKeysCurrentlyHeld = {}
    state.arpSequence = {}

    -- Clear repeats
    stopAllControlRepeats()

    local spot = {
      title = "MIDI PANIC",
      value = "ALL NOTES OFF",
      subtext = "All notes silenced",
      targetId = code and ("key-" .. code) or "header",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
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
    state.sustainKeyDownTime = hs.timer.secondsSinceEpoch()
    state.sustainWasActiveOnPress = state.sustainActive
    if state.sustainActive then
      midi.sendMidiCC(64, 127)

      -- Retroactively sustain all non-arp notes currently being physically held down
      for code, keyInfo in pairs(state.pressedKeys) do
        if type(keyInfo) == "table" and not keyInfo.isControl then
          keyInfo.isSustainedNote = true
          if not keyInfo.isArpNote then
            local pitches = keyInfo.pitches or { keyInfo.pitch }
            local ch = keyInfo.channel or 0
            for _, p in ipairs(pitches) do
              if p then
                state.sustainedPitches = state.sustainedPitches or {}
                table.insert(state.sustainedPitches, { pitch = p, channel = ch })
              end
            end
          end
        end
      end
    end

    local spot = {
      title = "SUSTAIN (CC #64)",
      value = "SUSTAIN ON",
      subtext = "Notes held across release",
      targetId = code and ("key-" .. code) or "key-48",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "arpToggle" then
    arpeggiator.toggleArpPower()
  elseif act == "arpLinkToggle" then
    arpeggiator.toggleArpLink()
  elseif act == "chordToggle" then
    state.chordKeyDownTime = hs.timer.secondsSinceEpoch()
    state.chordWasActiveOnPress = state.chordModeActive
    state.chordModeActive = true
    local spot = {
      title = "CHORD MODE",
      value = state.chordModeActive and "ON" or "OFF",
      subtext = "Chord mode: " .. (state.chordModeActive and "Enabled" or "Disabled"),
      targetId = "header",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "chordUp" then
    state.chordIdx = (state.chordIdx % #state.CHORDS) + 1
    arpeggiator.updateLatchedArpChordNotes()
    local spot = {
      title = "CHORD TYPE",
      value = state.CHORDS[state.chordIdx].name,
      subtext = "Cycle chord type",
      targetId = "header",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)

  elseif act == "chordDown" then
    state.chordIdx = ((state.chordIdx - 2 + #state.CHORDS) % #state.CHORDS) + 1
    arpeggiator.updateLatchedArpChordNotes()
    local spot = {
      title = "CHORD TYPE",
      value = state.CHORDS[state.chordIdx].name,
      subtext = "Cycle chord type",
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
    local spot = {
      title = "TOP ROW VOL",
      value = math.floor((state.topRowVolume / 127) * 100) .. "%",
      subtext = "Upper Keys Level",
      targetId = "vol-indicator-top",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "topVolUp" then
    state.topRowVolume = math.min(127, state.topRowVolume + 4)
    local spot = {
      title = "TOP ROW VOL",
      value = math.floor((state.topRowVolume / 127) * 100) .. "%",
      subtext = "Upper Keys Level",
      targetId = "vol-indicator-top",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "botVolDown" then
    state.bottomRowVolume = math.max(0, state.bottomRowVolume - 4)
    local spot = {
      title = "BOTTOM ROW VOL",
      value = math.floor((state.bottomRowVolume / 127) * 100) .. "%",
      subtext = "Lower Keys Level",
      targetId = "vol-indicator-bottom",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "botVolUp" then
    state.bottomRowVolume = math.min(127, state.bottomRowVolume + 4)
    local spot = {
      title = "BOTTOM ROW VOL",
      value = math.floor((state.bottomRowVolume / 127) * 100) .. "%",
      subtext = "Lower Keys Level",
      targetId = "vol-indicator-bottom",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "volDown" then
    state.topRowVolume = math.max(0, state.topRowVolume - 4)
    state.bottomRowVolume = math.max(0, state.bottomRowVolume - 4)
    local spot = {
      title = "ROW VOLUMES",
      value = "TOP " .. math.floor((state.topRowVolume / 127) * 100) .. "% | BOT " .. math.floor((state.bottomRowVolume / 127) * 100) .. "%",
      subtext = "Dual Row Volume Level",
      targetId = "header",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "volUp" or act == "volume" then
    state.topRowVolume = math.min(127, state.topRowVolume + 4)
    state.bottomRowVolume = math.min(127, state.bottomRowVolume + 4)
    local spot = {
      title = "ROW VOLUMES",
      value = "TOP " .. math.floor((state.topRowVolume / 127) * 100) .. "% | BOT " .. math.floor((state.bottomRowVolume / 127) * 100) .. "%",
      subtext = "Dual Row Volume Level",
      targetId = "header",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "arpTopToggle" then
    state.arpTopEnabled = not state.arpTopEnabled
    if state.arpTopEnabled and state.arpImplicitlyDisabled then
      state.arpImplicitlyDisabled = false
      if not state.arpEnabled then
        arpeggiator.setArpPowerImplicit(true)
      end
    end

    if not state.arpTopEnabled then
      if state.arpEnabled and not state.arpBottomEnabled then
        state.arpImplicitlyDisabled = true
        arpeggiator.setArpPowerImplicit(false)
      else
        if not state.arpLinked then
          arpeggiator.clearRowEngine(true)
        else
          local toRemove = {}
          for c in pairs(state.arpHeldNotes) do
            local rawCode = type(c) == "string" and tonumber(c:match("^(%d+)")) or tonumber(c)
            local noteKey = rawCode and config.getNoteKey(rawCode)
            if noteKey and noteKey.isTop then
              table.insert(toRemove, c)
            end
          end
          for _, c in ipairs(toRemove) do
            state.arpHeldNotes[c] = nil
            if state.arpTargetHeldNotes then state.arpTargetHeldNotes[c] = nil end
          end
          local remaining = 0
          for _ in pairs(state.arpHeldNotes) do remaining = remaining + 1 end
          if remaining == 0 then
            arpeggiator.stopArpTimer()
          end
        end
      end
    end
    local spot = {
      title = "<div class=\"stacked-rows-icon top-active\"><div class=\"rect top\"></div><div class=\"rect bottom\"></div></div>TOP ROW ARP",
      value = state.arpTopEnabled and "TOP ARP: ON" or "TOP ARP: OFF",
      subtext = arpeggiator.getArpRowTargetSubtext(),
      targetId = "arp-top-toggle",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "arpBottomToggle" then
    state.arpBottomEnabled = not state.arpBottomEnabled
    if state.arpBottomEnabled and state.arpImplicitlyDisabled then
      state.arpImplicitlyDisabled = false
      if not state.arpEnabled then
        arpeggiator.setArpPowerImplicit(true)
      end
    end

    if not state.arpBottomEnabled then
      if state.arpEnabled and not state.arpTopEnabled then
        state.arpImplicitlyDisabled = true
        arpeggiator.setArpPowerImplicit(false)
      else
        if not state.arpLinked then
          arpeggiator.clearRowEngine(false)
        else
          local toRemove = {}
          for c in pairs(state.arpHeldNotes) do
            local rawCode = type(c) == "string" and tonumber(c:match("^(%d+)")) or tonumber(c)
            local noteKey = rawCode and config.getNoteKey(rawCode)
            if noteKey and (not noteKey.isTop) then
              table.insert(toRemove, c)
            end
          end
          for _, c in ipairs(toRemove) do
            state.arpHeldNotes[c] = nil
            if state.arpTargetHeldNotes then state.arpTargetHeldNotes[c] = nil end
          end
          local remaining = 0
          for _ in pairs(state.arpHeldNotes) do remaining = remaining + 1 end
          if remaining == 0 then
            arpeggiator.stopArpTimer()
          end
        end
      end
    end
    local spot = {
      title = "<div class=\"stacked-rows-icon bottom-active\"><div class=\"rect top\"></div><div class=\"rect bottom\"></div></div>BOTTOM ROW ARP",
      value = state.arpBottomEnabled and "BOTTOM ARP: ON" or "BOTTOM ARP: OFF",
      subtext = arpeggiator.getArpRowTargetSubtext(),
      targetId = "arp-bottom-toggle",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
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
    state.arpDirectionIdx = ((state.arpDirectionIdx - 2 + #state.ARP_DIRECTIONS) % #state.ARP_DIRECTIONS) + 1
    local spot = {
      title = "ARP DIRECTION",
      value = state.ARP_DIRECTIONS[state.arpDirectionIdx],
      subtext = state.arpEnabled and "Active Pattern" or "Arp Disabled",
      targetId = "arp-dir-select",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "arpDirUp" then
    state.arpDirectionIdx = (state.arpDirectionIdx % #state.ARP_DIRECTIONS) + 1
    local spot = {
      title = "ARP DIRECTION",
      value = state.ARP_DIRECTIONS[state.arpDirectionIdx],
      subtext = state.arpEnabled and "Active Pattern" or "Arp Disabled",
      targetId = "arp-dir-select",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "arpRateDown" then
    state.arpRateIdx = math.max(1, state.arpRateIdx - 1)
    arpeggiator.applyBpmChange()
    local spot = {
      title = "ARP RATE",
      value = state.ARP_RATES[state.arpRateIdx].label,
      subtext = "Note Division",
      targetId = "arp-rate-select",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "arpRateUp" then
    state.arpRateIdx = math.min(#state.ARP_RATES, state.arpRateIdx + 1)
    arpeggiator.applyBpmChange()
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
  elseif act == "relDown" or act == "releaseDown" then
    local currentVal = state.ccStates[72] or 64
    local newVal = math.max(0, currentVal - 4)
    state.ccStates[72] = newVal
    midi.sendMidiCC(72, newVal)
    local spot = {
      title = "SYNTH RELEASE",
      value = math.floor((newVal / 127) * 100) .. "%",
      subtext = "CC #72 Level",
      targetId = "header",
      color = "#cf9ee1"
    }
    hud.updateWebviewHud(spot)
  elseif act == "relUp" or act == "releaseUp" then
    local currentVal = state.ccStates[72] or 64
    local newVal = math.min(127, currentVal + 4)
    state.ccStates[72] = newVal
    midi.sendMidiCC(72, newVal)
    local spot = {
      title = "SYNTH RELEASE",
      value = math.floor((newVal / 127) * 100) .. "%",
      subtext = "CC #72 Level",
      targetId = "header",
      color = "#cf9ee1"
    }
    hud.updateWebviewHud(spot)
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

  -- Master Arp & Track Loop Lock (Consolidated on F)
  elseif act == "lockLoop" then
    state.arpEnabled = true
    state.arpLatchActive = true
    local trkId = state.bottomRowTrack or 1
    if state.tracks and state.tracks[trkId] then
      state.tracks[trkId].locked = true
    end
    hud.updateWebviewHud({ title = "LOOP LOCKED", value = "Track " .. trkId .. " Looping 🔁", subtext = "Continuous background pattern", targetId = "key-3", color = "#ffd700" })
  elseif act == "lockAndSwap" then
    state.arpEnabled = true
    state.arpLatchActive = true
    local curTrk = state.bottomRowTrack or 1
    if state.tracks and state.tracks[curTrk] then
      state.tracks[curTrk].locked = true
    end
    state.bottomRowTrack = (curTrk == 1) and 2 or 1
    local nextTrk = state.tracks and state.tracks[state.bottomRowTrack]
    if nextTrk then
      state.bottomRowChannel = nextTrk.channel
      state.bottomRowVolume = nextTrk.volume or state.bottomRowVolume
    end
    hud.updateWebviewHud({ title = "LOCKED & SWAPPED", value = "Track " .. curTrk .. " Looping 🔁", subtext = "Bottom row now playing Track " .. state.bottomRowTrack .. " (" .. (nextTrk and nextTrk.name or "") .. ")", targetId = "key-3", color = "#ffd700" })
  elseif act == "lockAllTracks" then
    state.arpEnabled = true
    state.arpLatchActive = true
    if state.tracks then
      for _, t in pairs(state.tracks) do t.locked = true end
    end
    hud.updateWebviewHud({ title = "LOCK 4 TRACKS", value = "All Loops Active", subtext = "4-Track Sequence Running", targetId = "key-3", color = "#ffd700" })
  elseif act == "stopLoops" then
    state.arpLatchActive = false
    if state.tracks then
      for _, t in pairs(state.tracks) do t.locked = false end
    end
    arpeggiator.stopArpTimer()
    state.arpHeldNotes = {}
    state.arpKeysCurrentlyHeld = {}
    hud.updateWebviewHud({ title = "LOOPS STOPPED", value = "All Background Arps Silenced", subtext = "Arpeggiator Idle", targetId = "key-3", color = "#ff5555" })
  elseif act == "freezeAll" then
    state.arpLatchActive = true
    hud.updateWebviewHud({ title = "FREEZE ALL", value = "All Patterns Frozen", subtext = "Live Notes Latched", targetId = "key-3", color = "#64d8f0" })

  -- Freed Keys: K (Bottom 1<->2), L (Top 3<->4), ; (Focus/Mixer)
  elseif act == "botTrackToggle" then
    state.bottomRowTrack = (state.bottomRowTrack == 1) and 2 or 1
    local trk = state.tracks and state.tracks[state.bottomRowTrack]
    if trk then
      state.bottomRowChannel = trk.channel
      state.bottomRowVolume = trk.volume or state.bottomRowVolume
      hud.updateWebviewHud({ title = "BOTTOM ROW ROUTING", value = "Track " .. state.bottomRowTrack .. ": " .. trk.name, subtext = "MIDI Channel " .. (trk.channel + 1), targetId = "key-40", color = "#64d8f0" })
    end
  elseif act == "botTrackLock" then
    local trkId = state.bottomRowTrack or 1
    if state.tracks and state.tracks[trkId] then
      state.tracks[trkId].locked = not state.tracks[trkId].locked
      hud.updateWebviewHud({ title = "BOTTOM ROW LOCK", value = "Track " .. trkId .. (state.tracks[trkId].locked and " LOCKED 🔒" or " UNLOCKED 🔓"), subtext = state.tracks[trkId].name, targetId = "key-40", color = "#ffd700" })
    end
  elseif act == "topTrackToggle" then
    state.topRowTrack = (state.topRowTrack == 3) and 4 or 3
    local trk = state.tracks and state.tracks[state.topRowTrack]
    if trk then
      state.topRowChannel = trk.channel
      state.topRowVolume = trk.volume or state.topRowVolume
      hud.updateWebviewHud({ title = "TOP ROW ROUTING", value = "Track " .. state.topRowTrack .. ": " .. trk.name, subtext = "MIDI Channel " .. (trk.channel + 1), targetId = "key-37", color = "#64d8f0" })
    end
  elseif act == "topTrackLock" then
    local trkId = state.topRowTrack or 3
    if state.tracks and state.tracks[trkId] then
      state.tracks[trkId].locked = not state.tracks[trkId].locked
      hud.updateWebviewHud({ title = "TOP ROW LOCK", value = "Track " .. trkId .. (state.tracks[trkId].locked and " LOCKED 🔒" or " UNLOCKED 🔓"), subtext = state.tracks[trkId].name, targetId = "key-37", color = "#ffd700" })
    end
  elseif act == "trackFocusCycle" then
    state.activeTrack = (state.activeTrack % 4) + 1
    local trk = state.tracks and state.tracks[state.activeTrack]
    hud.updateWebviewHud({ title = "TRACK FOCUS", value = "Track " .. state.activeTrack .. ": " .. (trk and trk.name or ""), subtext = "Master Parameter Focus", targetId = "key-41", color = "#64d8f0" })
  elseif act == "allMuteToggle" then
    local anyUnmuted = false
    if state.tracks then
      for _, t in pairs(state.tracks) do
        if not t.muted then anyUnmuted = true; break end
      end
      for _, t in pairs(state.tracks) do t.muted = anyUnmuted end
    end
    hud.updateWebviewHud({ title = "MASTER MIXER", value = anyUnmuted and "ALL TRACKS MUTED 🔇" or "ALL TRACKS UNMUTED 🔊", subtext = "Global Track Mute", targetId = "key-41", color = anyUnmuted and "#ff5555" or "#50fa7b" })
  elseif act == "mixReset" then
    if state.tracks then
      for _, t in pairs(state.tracks) do
        t.muted = false
        t.soloed = false
        t.volume = 100
      end
    end
    state.topRowVolume = 100
    state.bottomRowVolume = 100
    hud.updateWebviewHud({ title = "MIXER RESET", value = "All Volumes 100%", subtext = "All Mutes & Solos Cleared", targetId = "key-41", color = "#50fa7b" })

  -- Dedicated Track 1-4 Actions
  elseif string.match(act, "^trkSelect(%d)$") then
    local id = tonumber(string.match(act, "^trkSelect(%d)$"))
    if id <= 2 then
      state.bottomRowTrack = id
      local trk = state.tracks and state.tracks[id]
      if trk then
        state.bottomRowChannel = trk.channel
        state.bottomRowVolume = trk.volume or state.bottomRowVolume
      end
      hud.updateWebviewHud({ title = "SELECT TRACK " .. id, value = trk and trk.name or "", subtext = "Bottom Row Routed", targetId = "key-" .. ({[1]=18,[2]=19})[id], color = "#64d8f0" })
    else
      state.topRowTrack = id
      local trk = state.tracks and state.tracks[id]
      if trk then
        state.topRowChannel = trk.channel
        state.topRowVolume = trk.volume or state.topRowVolume
      end
      hud.updateWebviewHud({ title = "SELECT TRACK " .. id, value = trk and trk.name or "", subtext = "Top Row Routed", targetId = "key-" .. ({[3]=20,[4]=21})[id], color = "#64d8f0" })
    end
    state.activeTrack = id
  elseif string.match(act, "^trkMute(%d)$") then
    local id = tonumber(string.match(act, "^trkMute(%d)$"))
    local trk = state.tracks and state.tracks[id]
    if trk then
      trk.muted = not trk.muted
      hud.updateWebviewHud({ title = "TRACK " .. id .. " (" .. trk.name .. ")", value = trk.muted and "MUTED 🔇" or "UNMUTED 🔊", subtext = "Mute Toggle", targetId = "key-" .. ({[1]=18,[2]=19,[3]=20,[4]=21})[id], color = trk.muted and "#ff5555" or "#50fa7b" })
    end
  elseif string.match(act, "^trkSolo(%d)$") then
    local id = tonumber(string.match(act, "^trkSolo(%d)$"))
    local trk = state.tracks and state.tracks[id]
    if trk then
      trk.soloed = not trk.soloed
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
    hud.updateWebviewHud({ title = "CLEAR TRACK " .. id, value = "Pattern Cleared", subtext = "Reset Sequence", targetId = "key-" .. ({[1]=18,[2]=19,[3]=20,[4]=21})[id], color = "#ff5555" })
  elseif string.match(act, "^trkFocus(%d)$") then
    local id = tonumber(string.match(act, "^trkFocus(%d)$"))
    state.activeTrack = id
    local trk = state.tracks and state.tracks[id]
    hud.updateWebviewHud({ title = "FOCUS TRACK " .. id, value = trk and trk.name or "", subtext = "Active Track Focus", targetId = "key-" .. ({[1]=18,[2]=19,[3]=20,[4]=21})[id], color = "#64d8f0" })

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
    state.arpDirectionIdx = 7
    hud.updateWebviewHud({ title = "ARP DIRECTION", value = "RANDOM", subtext = "Random Order", targetId = "key-23", color = "#64d8f0" })
  elseif act == "arpDirConverge" then
    state.arpDirectionIdx = 5
    hud.updateWebviewHud({ title = "ARP DIRECTION", value = "CONVERGE", subtext = "Outside-In Order", targetId = "key-23", color = "#64d8f0" })
  elseif act == "arpDirDiverge" then
    state.arpDirectionIdx = 6
    hud.updateWebviewHud({ title = "ARP DIRECTION", value = "DIVERGE", subtext = "Inside-Out Order", targetId = "key-23", color = "#64d8f0" })
  elseif act == "arpDirUpDown" then
    state.arpDirectionIdx = 3
    hud.updateWebviewHud({ title = "ARP DIRECTION", value = "UP / DOWN", subtext = "Up then Down", targetId = "key-23", color = "#64d8f0" })
  elseif act == "arpDirDownUp" then
    state.arpDirectionIdx = 4
    hud.updateWebviewHud({ title = "ARP DIRECTION", value = "DOWN / UP", subtext = "Down then Up", targetId = "key-23", color = "#64d8f0" })
  elseif act == "arpDirReset" then
    state.arpDirectionIdx = 1
    hud.updateWebviewHud({ title = "ARP DIRECTION", value = "UP", subtext = "Default Upward", targetId = "key-23", color = "#64d8f0" })

  -- Arp Rate Presets (Key 6)
  elseif act == "arpRateTriplet" then
    state.arpRateIdx = 15 -- 1/8T
    arpeggiator.applyBpmChange()
    hud.updateWebviewHud({ title = "ARP RATE", value = "1/8T (Triplet)", subtext = "Triplet Feel", targetId = "key-22", color = "#64d8f0" })
  elseif act == "arpRateStraight" then
    state.arpRateIdx = 6 -- 1/8
    arpeggiator.applyBpmChange()
    hud.updateWebviewHud({ title = "ARP RATE", value = "1/8 (Straight)", subtext = "Straight Feel", targetId = "key-22", color = "#64d8f0" })
  elseif act == "arpRate16th" then
    state.arpRateIdx = 7 -- 1/16
    arpeggiator.applyBpmChange()
    hud.updateWebviewHud({ title = "ARP RATE", value = "1/16th", subtext = "Sixteenth Notes", targetId = "key-22", color = "#64d8f0" })
  elseif act == "arpRate8th" then
    state.arpRateIdx = 6 -- 1/8
    arpeggiator.applyBpmChange()
    hud.updateWebviewHud({ title = "ARP RATE", value = "1/8th", subtext = "Eighth Notes", targetId = "key-22", color = "#64d8f0" })
  elseif act == "arpRate32nd" then
    state.arpRateIdx = 8 -- 1/32
    arpeggiator.applyBpmChange()
    hud.updateWebviewHud({ title = "ARP RATE", value = "1/32nd", subtext = "Thirty-Second Notes", targetId = "key-22", color = "#64d8f0" })
  elseif act == "arpRate4th" then
    state.arpRateIdx = 5 -- 1/4
    arpeggiator.applyBpmChange()
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
    relUp = true, relDown = true, releaseUp = true, releaseDown = true,
    arpGateUp = true, arpGateDown = true,
    volUp = true, volDown = true, volume = true,
    topVolUp = true, topVolDown = true,
    botVolUp = true, botVolDown = true,
    modWheelUp = true, modWheelDown = true, modWheel = true
  }
  return repeatingActions[act] == true
end

local function handleKeyDown(code)
  if code == 50 then -- Backtick
    state.modeSelectHeld = true
    state.modeWasSelectedDuringHold = false
    hud.updateWebviewHud()
    return true
  end

  if state.modeSelectHeld then
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
      if state.shiftHeld and k.shiftAction and k.shiftAction ~= "" and k.shiftAction ~= "none" then
        actionToExecute = k.shiftAction
      elseif k.action and k.action ~= "" and k.action ~= "none" then
        actionToExecute = k.action
      end
    end
  end

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

  local noteKey = config.getNoteKey(code)
  if noteKey then
    local isTop = noteKey.isTop
    local trkIdx = isTop and (state.topRowTrack or 3) or (state.bottomRowTrack or 1)
    local trk = state.tracks and state.tracks[trkIdx]
    local ch = trk and trk.channel or (isTop and (state.topRowChannel or 0) or (state.bottomRowChannel or 0))
    local transposedPitch = transposer.getTransposedPitch(noteKey.baseNote, isTop)
    local chordPitches = (state.quoteHeld or state.chordModeActive) and transposer.getChordPitches(noteKey.baseNote, isTop) or { transposedPitch }
    local arpEnabledForRow = isTop and state.arpTopEnabled or (not isTop and state.arpBottomEnabled)
    local arpActive = state.arpEnabled and arpEnabledForRow
    local isArpNote = (not state.arpBypassed) and arpActive and (not state.shiftHeld)

    local sustainPedalHeld = false
    for c, info in pairs(state.pressedKeys) do
      if type(info) == "table" and info.isControl and info.action == "sustain" then
        sustainPedalHeld = true
        break
      end
    end
    local effectiveSustain = (state.shiftHeld and (not (state.sustainActive or sustainPedalHeld))) or ((not state.shiftHeld) and (state.sustainActive or sustainPedalHeld))
    
    state.pressedKeys[code] = { pitches = chordPitches, isArpNote = isArpNote, isSustainedNote = effectiveSustain, channel = ch, track = trkIdx }
    
    if isTrackAudible(trkIdx) then
      if isArpNote then 
        for _, p in ipairs(chordPitches) do arpeggiator.arpAddNote(code .. "_" .. p, p) end
      else 
        local quantMode = state.inputQuantizeMode or "Off"
        local bpm = state.arpBpm or 120.0
        local vel = transposer.getEffectiveRowVelocity(isTop)

        quantizer.queueNoteOn("qwerty_" .. code, chordPitches, vel, ch, bpm, quantMode, function(pitches, v, channel)
          for _, p in ipairs(pitches) do
            midi.sendMidiNote("noteOn", p, v, channel)
          end
        end)
      end
    end
    hud.updateWebviewHud()
    return true
  end

  return true
end

local function handleKeyUp(code)
  if code == 50 then -- Backtick released
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
    hud.updateWebviewHud()
    return true
  end

  if keyInfo and type(keyInfo) == "table" and not keyInfo.isControl and keyInfo.pitches then
    local pitches = keyInfo.pitches
    local isArpNote = keyInfo.isArpNote
    local isSustainedNote = keyInfo.isSustainedNote
    local keyChannel = keyInfo.channel or 0

    if isArpNote then
      for _, p in ipairs(pitches) do arpeggiator.arpRemoveNote(code .. "_" .. p) end
    else
      local sustainPedalHeld = false
      for c, info in pairs(state.pressedKeys) do
        if type(info) == "table" and info.isControl and info.action == "sustain" then
          sustainPedalHeld = true
          break
        end
      end

      quantizer.queueNoteOff("qwerty_" .. code, function(releasedPitches, channel)
        for _, playedPitch in ipairs(releasedPitches or pitches) do
          if isSustainedNote and (state.sustainActive or sustainPedalHeld) then
            state.sustainedPitches = state.sustainedPitches or {}
            table.insert(state.sustainedPitches, { pitch = playedPitch, channel = channel or keyChannel })
          else
            midi.sendMidiNote("noteOff", playedPitch, 0, channel or keyChannel)
          end
        end
      end)
    end
    state.pressedKeys[code] = nil
    hud.updateSingleKeyState(code, false, false)
    hud.updateWebviewHud()
    return true
  end

  local noteKey = config.getNoteKey(code)
  if noteKey then
    -- Fallback if pressedKeys entry was missing
    local isTop = noteKey.isTop
    local chordPitches = transposer.getChordPitches(noteKey.baseNote, isTop)
    local ch = isTop and (state.topRowChannel or 0) or (state.bottomRowChannel or 0)
    for _, pitch in ipairs(chordPitches) do
      midi.sendMidiNote("noteOff", pitch, 0, ch)
    end
    hud.updateSingleKeyState(code, false, false)
    hud.updateWebviewHud()
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

  local function cleanupSustainPitches()
    if state.sustainedPitches then
      for _, item in ipairs(state.sustainedPitches) do
        if type(item) == "table" and item.pitch then
          local pitch = item.pitch
          local channel = item.channel or 0
          local isCurrentlyHeld = false
          for _, kInfo in pairs(state.pressedKeys) do
            if type(kInfo) == "table" and not kInfo.isControl and kInfo.pitches then
              for _, p in ipairs(kInfo.pitches) do
                if p == pitch and (kInfo.channel or 0) == channel then
                  isCurrentlyHeld = true
                  break
                end
              end
              if isCurrentlyHeld then break end
            end
          end
          -- Do NOT issue noteOff if this pitch is currently playing/held in arpeggiator
          local isArpActivePitch = state.arpCurrentPitch and ((type(state.arpCurrentPitch) == "table" and state.arpCurrentPitch.pitch or state.arpCurrentPitch) == pitch)
          if not isCurrentlyHeld and not isArpActivePitch then
            midi.sendMidiNote("noteOff", pitch, 0, channel)
          end
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
    local act = (keyInfo and keyInfo.action) or (state.shiftHeld and ctrlKey.shiftAction or ctrlKey.action)
    
    local holdDuration = state.controlKeyDownTime and state.controlKeyDownTime[code] and (hs.timer.secondsSinceEpoch() - state.controlKeyDownTime[code]) or 0
    if holdDuration > 0.25 and not shouldRepeat(act) and act ~= "bpmEdit" then
      if state.controlKeyDownSnapshots and state.controlKeyDownSnapshots[code] then
        local wasSustain = state.sustainActive
        applyStateSnapshot(state.controlKeyDownSnapshots[code])
        if (wasSustain or act == "sustain") and not state.sustainActive then
          midi.sendSustainCC(0)
          cleanupSustainPitches()
        elseif not wasSustain and state.sustainActive then
          midi.sendSustainCC(127)
        end
        local spot = act == "sustain" and {
          title = "SUSTAIN (CC #64)",
          value = state.sustainActive and "SUSTAIN ON" or "SUSTAIN OFF",
          subtext = state.sustainActive and "Notes held across release" or "Damping enabled",
          targetId = "key-48",
          color = state.sustainActive and "#d4a359" or "#b5aba0"
        } or nil
        hud.updateWebviewHud(spot)
        return true
      end
    end

    if act == "sustain" then
      if state.sustainWasActiveOnPress then
        state.sustainActive = false
        midi.sendSustainCC(0)
        cleanupSustainPitches()

        -- When sustain turns off and latch is disabled, clear any arpeggiator notes that are no longer physically held down
        if not state.arpLatchActive and state.arpTargetHeldNotes then
          local newTarget = {}
          for codeKey, pitch in pairs(state.arpTargetHeldNotes) do
            local baseCode = type(codeKey) == "string" and tonumber(codeKey:match("^(%d+)")) or tonumber(codeKey)
            if baseCode and state.arpKeysCurrentlyHeld[baseCode] then
              newTarget[codeKey] = pitch
            end
          end
          state.arpTargetHeldNotes = newTarget
          state.arpHeldNotes = {}
          for k, v in pairs(state.arpTargetHeldNotes) do state.arpHeldNotes[k] = v end
          if next(state.arpHeldNotes) == nil then
            arpeggiator.stopArpTimer()
          end
        end
      else
        state.sustainActive = true
        midi.sendSustainCC(127)
        -- Retroactively sustain all non-arp notes currently being physically held down
        for c, keyInfo in pairs(state.pressedKeys) do
          if type(keyInfo) == "table" and not keyInfo.isControl then
            keyInfo.isSustainedNote = true
            if not keyInfo.isArpNote then
              local pitches = keyInfo.pitches or { keyInfo.pitch }
              local ch = keyInfo.channel or 0
              for _, p in ipairs(pitches) do
                if p then
                  state.sustainedPitches = state.sustainedPitches or {}
                  table.insert(state.sustainedPitches, { pitch = p, channel = ch })
                end
              end
            end
          end
        end
      end

      local spot = {
        title = "SUSTAIN (CC #64)",
        value = state.sustainActive and "SUSTAIN ON" or "SUSTAIN OFF",
        subtext = state.sustainActive and "Notes held across release" or "Damping enabled",
        targetId = "key-48",
        color = state.sustainActive and "#d4a359" or "#b5aba0"
      }
      hud.updateWebviewHud(spot)
    elseif act == "chordToggle" then
      if state.chordWasActiveOnPress then
        state.chordModeActive = false
      else
        state.chordModeActive = true
      end
      
      local spot = {
        title = "CHORD MODE",
        value = state.chordModeActive and "ON" or "OFF",
        subtext = "Chord mode: " .. (state.chordModeActive and "Enabled" or "Disabled"),
        targetId = "header",
        color = state.chordModeActive and "#d4a359" or "#b5aba0"
      }
      hud.updateWebviewHud(spot)
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
  executeControlAction = executeControlAction,
  handleKeyDown = handleKeyDown,
  handleKeyUp = handleKeyUp,
  stopAllControlRepeats = stopAllControlRepeats
}
