local config = require("config")
local midi = require("midi")
local transposer = require("transposer")
local arpeggiator = require("arpeggiator")
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
    modWheel = state.ccStates[1] or 0
  }
end

local function pushStateSnapshot(label)
  if isRestoringControllerState then return end
  table.insert(stateUndoStack, captureStateSnapshot(label))
  stateRedoStack = {}
end

local function applyStateSnapshot(snap)
  isRestoringControllerState = true

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
  state.ccStates[1] = snap.modWheel

  arpeggiator.updateLatchedArpNotes()
  arpeggiator.applyBpmChange()
  arpeggiator.applyGatePercentChange()
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

local function executeControlAction(act, code)
  if act == "undoState" then
    undoControllerState(code)
    return
  elseif act == "redoState" then
    redoControllerState(code)
    return
  end

  -- Record state snapshot before mutating controller parameters
  if act == "modeDown" or act == "modeUp" or
     act == "rootDown" or act == "rootUp" or act == "randomScale" or act == "resetAll" or
     act == "arpToggle" or act == "arpTopToggle" or act == "arpBottomToggle" or
     act == "arpDirDown" or act == "arpDirUp" or act == "arpRateDown" or act == "arpRateUp" or
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
        value = (state.topRowOctaveOffset >= 0 and "+" or "") .. math.floor(state.topRowOctaveOffset / 12) .. " Oct",
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
        value = (state.topRowOctaveOffset >= 0 and "+" or "") .. math.floor(state.topRowOctaveOffset / 12) .. " Oct",
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
  elseif act == "zoomOut" then
    state.zoomLevel = math.max(0.5, state.zoomLevel - 0.1)
    local spot = {
      title = "HUD ZOOM",
      value = math.floor(state.zoomLevel * 100) .. "%",
      subtext = "Scale Factor",
      targetId = "header",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "zoomIn" then
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
    state.sustainActive = true
    midi.sendMidiCC(64, 127)

    -- Retroactively sustain all non-arp notes currently being physically held down
    for code, keyInfo in pairs(state.pressedKeys) do
      if type(keyInfo) == "table" then
        keyInfo.isSustainedNote = true
        if not keyInfo.isArpNote and keyInfo.pitch then
          state.sustainedPitches = state.sustainedPitches or {}
          state.sustainedPitches[keyInfo.pitch] = true
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
    if not state.arpTopEnabled then
      for code in pairs(state.arpHeldNotes) do
        local noteKey = config.getNoteKey(code)
        if noteKey and noteKey.isTop then
          state.arpHeldNotes[code] = nil
          state.arpKeysCurrentlyHeld[code] = nil
        end
      end
    end
    local spot = {
      title = "TOP ROW ARP",
      value = state.arpTopEnabled and "TOP ARP: ON" or "TOP ARP: OFF",
      subtext = arpeggiator.getArpRowTargetSubtext(),
      targetId = "arp-top-toggle",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "arpBottomToggle" then
    state.arpBottomEnabled = not state.arpBottomEnabled
    if not state.arpBottomEnabled then
      for code in pairs(state.arpHeldNotes) do
        local noteKey = config.getNoteKey(code)
        if noteKey and not noteKey.isTop then
          state.arpHeldNotes[code] = nil
          state.arpKeysCurrentlyHeld[code] = nil
        end
      end
    end
    local spot = {
      title = "BOTTOM ROW ARP",
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
  end

  config.saveSettings()
end

local function handleKeyDown(code)
  if state.pressedKeys[code] then
    return true
  end



  if state.shiftHeld then
    local k = config.getNumberControlKey(code) or config.getControlKey(code)
    if k and k.shiftAction and k.shiftAction ~= "" and k.shiftAction ~= "none" then
      state.pressedKeys[code] = { isControl = true, action = k.shiftAction }
      executeControlAction(k.shiftAction, code)
      if k.shiftAction ~= "sustain" then
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
              pcall(executeControlAction, k.shiftAction, code)
              pushStateSnapshot = savedFn
            end)
          end
        end)
      end
      return true
    end
  end

  local k = config.getNumberControlKey(code) or config.getControlKey(code)
  if k and k.action and k.action ~= "" and k.action ~= "none" then
    state.pressedKeys[code] = { isControl = true, action = k.action }
    hud.updateSingleKeyState(code, true, false)
    executeControlAction(k.action, code)
    if k.action ~= "sustain" and k.action ~= "chordMod" then
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
            pcall(executeControlAction, k.action, code)
            pushStateSnapshot = savedFn
          end)
        end
      end)
    end
    return true
  end

  local noteKey = config.getNoteKey(code)
  if noteKey then
    local isTop = noteKey.isTop
    local transposedPitch = transposer.getTransposedPitch(noteKey.baseNote, isTop)
    local chordPitches = (state.quoteHeld or state.chordModeActive) and transposer.getChordPitches(noteKey.baseNote, isTop) or { transposedPitch }
    local arpEnabledForRow = isTop and state.arpTopEnabled or (not isTop and state.arpBottomEnabled)
    local arpActive = state.arpEnabled and arpEnabledForRow
    local sustainActive = state.sustainActive
    local isArpNote = state.shiftHeld and (not arpActive) or arpActive
    local isSustainedNote = state.shiftHeld and (not sustainActive) or sustainActive
    local ch = isTop and (state.topRowChannel or 0) or (state.bottomRowChannel or 0)
    
    state.pressedKeys[code] = { pitches = chordPitches, isArpNote = isArpNote, isSustainedNote = isSustainedNote, channel = ch }
    
    if isArpNote then 
      for _, p in ipairs(chordPitches) do arpeggiator.arpAddNote(code .. "_" .. p, p) end
    else 
      for _, p in ipairs(chordPitches) do
        midi.sendMidiNote("noteOn", p, transposer.getEffectiveRowVelocity(isTop), ch)
      end
    end
    hud.updateWebviewHud()
    return true
  end

  return true
end

local function handleKeyUp(code)


  if code == 50 then -- Backtick
    stopControlRepeat(code)
    state.pressedKeys[code] = nil
    hud.updateSingleKeyState(code, false, false)
    hud.updateWebviewHud()
    return true
  end

  local noteKey = config.getNoteKey(code)
  if noteKey then
    local keyInfo = state.pressedKeys[code]
    if keyInfo then
      local pitches = type(keyInfo) == "table" and keyInfo.pitches or { keyInfo.pitch }
      local isArpNote = type(keyInfo) == "table" and keyInfo.isArpNote
      local isSustainedNote = type(keyInfo) == "table" and keyInfo.isSustainedNote

      local keyChannel = type(keyInfo) == "table" and keyInfo.channel or 0
      if isArpNote then
        for _, p in ipairs(pitches) do arpeggiator.arpRemoveNote(code .. "_" .. p) end
      else
        for _, playedPitch in ipairs(pitches) do
          if isSustainedNote and state.sustainActive then
            state.sustainedPitches = state.sustainedPitches or {}
            state.sustainedPitches[playedPitch] = { channel = keyChannel }
          else
            midi.sendMidiNote("noteOff", playedPitch, 0, keyChannel)
          end
        end
      end
      state.pressedKeys[code] = nil
      hud.updateSingleKeyState(code, false, false)
    end
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

  local ctrlKey = config.getControlKey(code)
  if ctrlKey then
    stopControlRepeat(code)
    state.pressedKeys[code] = nil
    hud.updateSingleKeyState(code, false, false)
    local act = state.shiftHeld and ctrlKey.shiftAction or ctrlKey.action
    if act == "sustain" then
      local holdDuration = state.sustainKeyDownTime and (hs.timer.secondsSinceEpoch() - state.sustainKeyDownTime) or 0
      if holdDuration > 0.25 then
        state.sustainActive = false
        midi.sendMidiCC(64, 0)
      else
        if state.sustainWasActiveOnPress then
          state.sustainActive = false
          midi.sendMidiCC(64, 0)
        else
          state.sustainActive = true
          midi.sendMidiCC(64, 127)
        end
      end

      if not state.sustainActive then
        midi.sendMidiCC(64, 0)
        if state.sustainedPitches then
          for pitch in pairs(state.sustainedPitches) do
            local isCurrentlyHeld = false
            for _, keyInfo in pairs(state.pressedKeys) do
              if type(keyInfo) == "table" and keyInfo.pitch == pitch then
                isCurrentlyHeld = true
                break
              end
            end
            if not isCurrentlyHeld then
              midi.sendMidiNote("noteOff", pitch, 0)
            end
          end
          state.sustainedPitches = {}
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
      local holdDuration = state.chordKeyDownTime and (hs.timer.secondsSinceEpoch() - state.chordKeyDownTime) or 0
      if holdDuration > 0.25 then
        state.chordModeActive = false
      else
        if state.chordWasActiveOnPress then
          state.chordModeActive = false
        else
          state.chordModeActive = true
        end
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
