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
    midi.sendMidiCC(123, 0)
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
  elseif act == "sustain" or act == "latch" then
    state.sustainKeyDownTime = hs.timer.secondsSinceEpoch()
    state.sustainWasActiveOnPress = state.sustainActive
    state.sustainActive = true
    midi.sendMidiCC(64, 127)
    local spot = {
      title = "SUSTAIN / LATCH (CC #64)",
      value = "SUSTAIN ON",
      subtext = "Notes & Arp pattern hold",
      targetId = "key-0",
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

  if lowerRowKeys[code] then
    local kData = lowerRowKeys[code]
    if not state.pressedKeys[code] then
      local transposedPitch = transposer.getTransposedPitch(kData.baseNote, false)
      state.pressedKeys[code] = transposedPitch
      if state.arpEnabled and state.arpBottomEnabled then
        arpeggiator.arpAddNote(code, transposedPitch)
      else
        midi.sendMidiNote("noteOn", transposedPitch, transposer.getEffectiveRowVelocity(false))
      end
      hud.updateWebviewHud()
    end
    return true
  elseif upperRowKeys[code] then
    local kData = upperRowKeys[code]
    if not state.pressedKeys[code] then
      local transposedPitch = transposer.getTransposedPitch(kData.baseNote, true)
      state.pressedKeys[code] = transposedPitch
      if state.arpEnabled and state.arpTopEnabled then
        arpeggiator.arpAddNote(code, transposedPitch)
      else
        midi.sendMidiNote("noteOn", transposedPitch, transposer.getEffectiveRowVelocity(true))
      end
      hud.updateWebviewHud()
    end
    return true
  elseif numberRowControls[code] then
    local cData = numberRowControls[code]
    if not state.pressedKeys[code] then
      state.pressedKeys[code] = true
      executeControlAction(cData.action, code)
    end
    return true
  elseif homeRowControls[code] then
    local cData = homeRowControls[code]
    if not state.pressedKeys[code] then
      state.pressedKeys[code] = true
      local act = state.shiftHeld and cData.shiftAction or cData.action
      executeControlAction(act, code)
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
    local playedPitch = state.pressedKeys[code]
    if playedPitch then
      local isTop = upperRowKeys[code] ~= nil
      local arpEnabledForRow = isTop and state.arpTopEnabled or state.arpBottomEnabled
      if state.arpEnabled and arpEnabledForRow then
        arpeggiator.arpRemoveNote(code)
      else
        if not state.sustainActive then
          midi.sendMidiNote("noteOff", playedPitch, 0)
        end
      end
      state.pressedKeys[code] = nil
    end
    hud.updateWebviewHud()
    return true
  elseif numberRowControls[code] then
    state.pressedKeys[code] = nil
    hud.updateWebviewHud()
    return true
  elseif homeRowControls[code] then
    local cData = homeRowControls[code]
    state.pressedKeys[code] = nil
    local act = state.shiftHeld and cData.shiftAction or cData.action
    if act == "sustain" or act == "latch" then
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

      if not state.sustainActive and state.arpEnabled then
        local numPhysicalHeld = 0
        for _ in pairs(state.arpKeysCurrentlyHeld) do numPhysicalHeld = numPhysicalHeld + 1 end
        if numPhysicalHeld == 0 then
          arpeggiator.stopArpTimer()
          state.arpHeldNotes = {}
        end
      end

      local spot = {
        title = "SUSTAIN / LATCH (CC #64)",
        value = state.sustainActive and "SUSTAIN ON" or "SUSTAIN OFF",
        subtext = state.sustainActive and "Notes & Arp pattern hold" or "Damping enabled",
        targetId = "key-0",
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
