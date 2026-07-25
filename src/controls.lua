local config = require("config")
local midi = require("midi")
local transposer = require("transposer")
local arpeggiator = require("arpeggiator")
local hud = require("hud")

local state = config.state
local SCALES = config.SCALES
local NOTE_NAMES = config.NOTE_NAMES
local numberRowControls = config.numberRowControls
local upperRowKeys = config.upperRowKeys
local lowerRowKeys = config.lowerRowKeys
local homeRowControls = config.homeRowControls

_G.activeWatchers = _G.activeWatchers or {}

local controlRepeatTimers = {}

local function stopControlRepeat(code)
  if controlRepeatTimers[code] then
    if controlRepeatTimers[code].timer then controlRepeatTimers[code].timer:stop() end
    if controlRepeatTimers[code].interval then controlRepeatTimers[code].interval:stop() end
    controlRepeatTimers[code] = nil
  end
end

local function executeControlAction(act, code)
  if act == "topOctDown" then
    state.topRowOctaveOffset = math.max(-36, state.topRowOctaveOffset - 12)
    local spot = {
      title = "TOP ROW OCTAVE",
      value = (state.topRowOctaveOffset >= 0 and "+" or "") .. math.floor(state.topRowOctaveOffset / 12) .. " Oct",
      subtext = "Upper Row Pitch",
      targetId = "octave-indicator-top",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "topOctUp" then
    state.topRowOctaveOffset = math.min(36, state.topRowOctaveOffset + 12)
    local spot = {
      title = "TOP ROW OCTAVE",
      value = (state.topRowOctaveOffset >= 0 and "+" or "") .. math.floor(state.topRowOctaveOffset / 12) .. " Oct",
      subtext = "Upper Row Pitch",
      targetId = "octave-indicator-top",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "trnspDown" then
    state.transposeShift = math.max(-12, state.transposeShift - 1)
    local spot = {
      title = "TRANSPOSE",
      value = (state.transposeShift >= 0 and "+" or "") .. state.transposeShift .. " st",
      subtext = "Semitone Shift",
      targetId = "status-text",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "trnspUp" then
    state.transposeShift = math.min(12, state.transposeShift + 1)
    local spot = {
      title = "TRANSPOSE",
      value = (state.transposeShift >= 0 and "+" or "") .. state.transposeShift .. " st",
      subtext = "Semitone Shift",
      targetId = "status-text",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "octaveDown" then
    state.octaveShift = math.max(-36, state.octaveShift - 12)
    local spot = {
      title = "GLOBAL OCTAVE",
      value = (state.octaveShift >= 0 and "+" or "") .. math.floor(state.octaveShift / 12) .. " Oct",
      subtext = "Global Pitch Offset",
      targetId = "octave-indicator-bottom",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "octaveUp" then
    state.octaveShift = math.min(36, state.octaveShift + 12)
    local spot = {
      title = "GLOBAL OCTAVE",
      value = (state.octaveShift >= 0 and "+" or "") .. math.floor(state.octaveShift / 12) .. " Oct",
      subtext = "Global Pitch Offset",
      targetId = "octave-indicator-bottom",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
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
    state.pressedKeys = {}
    arpeggiator.stopArpTimer()
    state.arpHeldNotes = {}
    state.arpKeysCurrentlyHeld = {}
    local spot = {
      title = "MIDI PANIC",
      value = "ALL NOTES OFF",
      subtext = "Reset Active Notes",
      targetId = code and ("key-" .. code) or "header",
      color = "#d4a359"
    }
    hud.updateWebviewHud(spot)
  elseif act == "resetAll" then
    state.octaveShift = 0
    state.topRowOctaveOffset = 0
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
    state.arpTopEnabled = false
    state.arpBottomEnabled = true
    midi.sendMidiCC(64, 0)
    midi.sendMidiCC(1, 0)
    local spot = {
      title = "RESET ALL",
      value = "DEFAULTS RESTORED",
      subtext = "All Parameters Reset",
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
  elseif act == "arpToggle" then
    arpeggiator.toggleArpPower()
  elseif act == "arpTopToggle" then
    state.arpTopEnabled = not state.arpTopEnabled
    if not state.arpTopEnabled then
      for code in pairs(state.arpHeldNotes) do
        if upperRowKeys[code] then
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
        if lowerRowKeys[code] then
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
end

local function handleKeyDown(code)
  if code == 50 then -- Backtick
    if not state.pressedKeys[code] then
      state.pressedKeys[code] = true
      arpeggiator.toggleArp()
    end
    return true
  end

  if lowerRowKeys[code] or upperRowKeys[code] then
    local isTop = upperRowKeys[code] ~= nil
    local kData = isTop and upperRowKeys[code] or lowerRowKeys[code]
    if not state.pressedKeys[code] then
      local transposedPitch = transposer.getTransposedPitch(kData.baseNote, isTop)
      local arpEnabledForRow = isTop and state.arpTopEnabled or (not isTop and state.arpBottomEnabled)
      local arpActive = state.arpEnabled and arpEnabledForRow
      local sustainActive = state.sustainActive

      local isArpNote = false
      local isSustainedNote = false

      if state.shiftHeld then
        -- Holding Shift bypasses any active mode (Arp or Sustain), forcing a normal un-sustained note tap
        isArpNote = false
        isSustainedNote = false
      else
        isArpNote = arpActive
        isSustainedNote = sustainActive
      end

      state.pressedKeys[code] = {
        pitch = transposedPitch,
        isArpNote = isArpNote,
        isSustainedNote = isSustainedNote
      }

      if isArpNote then
        arpeggiator.arpAddNote(code, transposedPitch)
      else
        midi.sendMidiNote("noteOn", transposedPitch, transposer.getEffectiveRowVelocity(isTop))
      end
      hud.updateWebviewHud()
    end
    return true
  elseif numberRowControls[code] then
    local cData = numberRowControls[code]
    if not state.pressedKeys[code] then
      state.pressedKeys[code] = true
      local act = state.shiftHeld and cData.shiftAction or cData.action
      executeControlAction(act, code)
      stopControlRepeat(code)
      controlRepeatTimers[code] = {
        timer = hs.timer.doAfter(0.35, function()
          if state.pressedKeys[code] then
            controlRepeatTimers[code].interval = hs.timer.doEvery(0.08, function()
              if state.pressedKeys[code] then
                local currentAct = state.shiftHeld and cData.shiftAction or cData.action
                executeControlAction(currentAct, code)
              else
                stopControlRepeat(code)
              end
            end)
          end
        end)
      }
    end
    return true
  elseif homeRowControls[code] then
    local cData = homeRowControls[code]
    if not state.pressedKeys[code] then
      state.pressedKeys[code] = true
      local act = state.shiftHeld and cData.shiftAction or cData.action
      executeControlAction(act, code)
      if act ~= "sustain" then
        stopControlRepeat(code)
        controlRepeatTimers[code] = {
          timer = hs.timer.doAfter(0.35, function()
            if state.pressedKeys[code] then
              controlRepeatTimers[code].interval = hs.timer.doEvery(0.08, function()
                if state.pressedKeys[code] then
                  local currentAct = state.shiftHeld and cData.shiftAction or cData.action
                  executeControlAction(currentAct, code)
                else
                  stopControlRepeat(code)
                end
              end)
            end
          end)
        }
      end
    end
    return true
  end
  return false
end

local function handleKeyUp(code)
  if code == 50 then -- Backtick
    state.pressedKeys[code] = nil
    hud.updateWebviewHud()
    return true
  end

  if lowerRowKeys[code] or upperRowKeys[code] then
    local keyInfo = state.pressedKeys[code]
    if keyInfo then
      local playedPitch = type(keyInfo) == "table" and keyInfo.pitch or keyInfo
      local isArpNote = type(keyInfo) == "table" and keyInfo.isArpNote
      local isSustainedNote = type(keyInfo) == "table" and keyInfo.isSustainedNote

      if isArpNote then
        arpeggiator.arpRemoveNote(code)
      else
        if isSustainedNote then
          state.sustainedPitches = state.sustainedPitches or {}
          state.sustainedPitches[playedPitch] = true
        else
          midi.sendMidiNote("noteOff", playedPitch, 0)
        end
      end
      state.pressedKeys[code] = nil
    end
    hud.updateWebviewHud()
    return true
  elseif numberRowControls[code] then
    stopControlRepeat(code)
    state.pressedKeys[code] = nil
    hud.updateWebviewHud()
    return true
  elseif homeRowControls[code] then
    local cData = homeRowControls[code]
    stopControlRepeat(code)
    state.pressedKeys[code] = nil
    local act = state.shiftHeld and cData.shiftAction or cData.action
    if act == "sustain" then
      local holdDuration = hs.timer.secondsSinceEpoch() - state.sustainKeyDownTime
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
            midi.sendMidiNote("noteOff", pitch, 0)
          end
          state.sustainedPitches = {}
        end
        midi.sendMidiCC(123, 0)
      end

      local spot = {
        title = "SUSTAIN (CC #64)",
        value = state.sustainActive and "SUSTAIN ON" or "SUSTAIN OFF",
        subtext = state.sustainActive and "Notes held across release" or "Damping enabled",
        targetId = "key-48",
        color = state.sustainActive and "#d4a359" or "#b5aba0"
      }
      hud.updateWebviewHud(spot)
    else
      hud.updateWebviewHud()
    end
    return true
  end
  return false
end

return {
  executeControlAction = executeControlAction,
  handleKeyDown = handleKeyDown,
  handleKeyUp = handleKeyUp
}
