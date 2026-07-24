local hsWebview = require("hs.webview")
local hsUsercontent = require("hs.webview.usercontent")

local config = require("config")
local midi = require("midi")
local transposer = require("transposer")
local arpeggiator = require("arpeggiator")

local state = config.state
local SCALES = config.SCALES
local NOTE_NAMES = config.NOTE_NAMES
local numberRowControls = config.numberRowControls
local upperRowKeys = config.upperRowKeys
local lowerRowKeys = config.lowerRowKeys
local homeRowControls = config.homeRowControls
local ARP_DIRECTIONS = state.ARP_DIRECTIONS
local ARP_RATES = state.ARP_RATES
local ARP_GATES = state.ARP_GATES

local HTML_UI_CONTENT = require("ui_html")

_G.activeWatchers = _G.activeWatchers or {}

local controlsModule = nil

local function setControlsModule(m)
  controlsModule = m
end

local pendingSpotlightInfo = nil
local pendingActiveArpPitch = nil
local hudUpdateScheduled = false
local lastFrameScale = nil

local function performWebviewHudUpdate(spotlightInfo, activeArpPitch)
  if not _G.activeWatchers.midiWebview then return end

  local baseW, baseH = 980, 330
  local effectiveScale = state.zoomLevel * state.BASE_HUD_SCALE
  local newW = math.floor(baseW * effectiveScale)
  local newH = math.floor(baseH * effectiveScale)

  if lastFrameScale ~= effectiveScale then
    lastFrameScale = effectiveScale
    local curFrame = _G.activeWatchers.midiWebview:frame()
    if curFrame.w ~= newW or curFrame.h ~= newH then
      local screen = hs.screen.mainScreen():frame()
      local cx = curFrame.x + (curFrame.w / 2)
      local cy = curFrame.y + (curFrame.h / 2)
      local nx = math.floor(cx - (newW / 2))
      local ny = math.floor(cy - (newH / 2))
      nx = math.max(screen.x, math.min(screen.x + screen.w - newW, nx))
      ny = math.max(screen.y, math.min(screen.y + screen.h - newH, ny))
      _G.activeWatchers.midiWebview:frame({ x = nx, y = ny, w = newW, h = newH })
      _G.activeWatchers.hudX = nx
      _G.activeWatchers.hudY = ny
      hs.settings.set("qwertyMidi_hudX", nx)
      hs.settings.set("qwertyMidi_hudY", ny)
    end
  end

  hs.settings.set("qwertyMidi_zoomLevel", state.zoomLevel)
  
  local modeFrac = (state.currentScaleIdx - 0.5) / #SCALES
  local modeName = SCALES[state.currentScaleIdx].name
  
  local octStr = (state.octaveShift >= 0 and "+" or "") .. (state.octaveShift / 12) .. " Oct"
  local trnspStr = (state.transposeShift ~= 0) and ("Trnsp: " .. (state.transposeShift >= 0 and "+" or "") .. state.transposeShift .. "st") or ""
  local susStr = state.sustainActive and "SUS: ON" or ""
  local latchStr = state.arpLatchActive and "LATCH: ON" or ""
  local shiftStr = state.shiftHeld and "[SHIFT]" or ""

  local statusParts = {}
  if trnspStr ~= "" then table.insert(statusParts, trnspStr) end
  if susStr ~= "" then table.insert(statusParts, susStr) end
  if latchStr ~= "" then table.insert(statusParts, latchStr) end
  if shiftStr ~= "" then table.insert(statusParts, shiftStr) end
  local statusStr = table.concat(statusParts, "  •  ")

  local topOctaveStr = (state.topRowOctaveOffset >= 0 and "+" or "") .. math.floor(state.topRowOctaveOffset / 12)
  local bottomOctaveStr = (state.octaveShift >= 0 and "+" or "") .. math.floor(state.octaveShift / 12)

  local keyUpdates = {}

  for code, cData in pairs(numberRowControls) do
    local label = state.shiftHeld and (cData.shiftName or cData.name) or cData.name
    local act = state.shiftHeld and (cData.shiftAction or cData.action) or cData.action
    local isArpControl = (act:find("arp") ~= nil) or (act:find("bpm") ~= nil)
    local isMainArp = (code == 50)
    local isTopArp = (code == 18)
    local isBotArp = (code == 19)
    local isArpActive = (isMainArp and state.arpEnabled) or (isTopArp and state.arpTopEnabled) or (isBotArp and state.arpBottomEnabled)
    keyUpdates[tostring(code)] = {
      note = label,
      isControl = true,
      typeClass = isArpControl and "mode-control" or "",
      pressed = (state.pressedKeys[code] ~= nil),
      sustainActive = isArpActive
    }
  end

  for code, kData in pairs(upperRowKeys) do
    local noteNum = transposer.getTransposedPitch(kData.baseNote, true)
    local intervalIdx = transposer.getIntervalInfo(noteNum)
    local noteName = transposer.noteNumToName(noteNum)
    local typeClass = ""

    if intervalIdx == 1 then
      typeClass = "root-key"
    elseif intervalIdx == 3 then
      typeClass = "third-key"
    elseif intervalIdx == 5 then
      typeClass = "fifth-key"
    end

    local isPressed = (state.pressedKeys[code] ~= nil)
    if state.arpEnabled and activeArpPitch and noteNum == activeArpPitch then
      isPressed = true
    end

    keyUpdates[tostring(code)] = {
      note = noteName,
      typeClass = typeClass,
      pressed = isPressed
    }
  end

  for code, kData in pairs(lowerRowKeys) do
    local noteNum = transposer.getTransposedPitch(kData.baseNote, false)
    local intervalIdx = transposer.getIntervalInfo(noteNum)
    local noteName = transposer.noteNumToName(noteNum)
    local typeClass = ""

    if intervalIdx == 1 then
      typeClass = "root-key"
    elseif intervalIdx == 3 then
      typeClass = "third-key"
    elseif intervalIdx == 5 then
      typeClass = "fifth-key"
    end

    local isPressed = (state.pressedKeys[code] ~= nil)
    if state.arpEnabled and activeArpPitch and noteNum == activeArpPitch then
      isPressed = true
    end

    keyUpdates[tostring(code)] = {
      note = noteName,
      typeClass = typeClass,
      pressed = isPressed
    }
  end

  for code, cData in pairs(homeRowControls) do
    local label = state.shiftHeld and cData.shiftName or cData.name
    local act = state.shiftHeld and cData.shiftAction or cData.action
    local isSustain = (code == 48)
    local isLatch = (code == 0)
    local isMode = (act == "modeDown" or act == "modeUp")
    keyUpdates[tostring(code)] = {
      note = label,
      isControl = true,
      typeClass = isMode and "mode-control" or (isLatch and state.arpLatchActive and "latch-active" or ""),
      pressed = (state.pressedKeys[code] ~= nil),
      sustainActive = (isSustain and state.sustainActive) or (isLatch and state.arpLatchActive)
    }
  end

  local modVal = state.ccStates[1] or 0

  local bpmDisplayStr
  if state.bpmInputMode then
    bpmDisplayStr = state.bpmInputBuffer .. "\226\150\140"
  else
    bpmDisplayStr = arpeggiator.formatBpm(state.arpBpm) .. " BPM"
  end

  local payload = {
    rootIdx = state.currentRoot,
    modeName = modeName,
    arpEnabled = state.arpEnabled,
    arpDirectionIdx = state.arpDirectionIdx,
    arpRateIdx = state.arpRateIdx,
    arpGatePercent = math.floor((state.arpGatePercent or 80.0) + 0.5),
    bpmDisplay = bpmDisplayStr,
    bpmEditing = state.bpmInputMode,
    logicSyncEnabled = state.logicSyncEnabled,
    arpTopEnabled = state.arpTopEnabled,
    arpBottomEnabled = state.arpBottomEnabled,
    statusText = statusStr,
    topOctaveStr = topOctaveStr,
    bottomOctaveStr = bottomOctaveStr,
    topVolPercent = math.floor((state.topRowVolume / 127) * 100),
    bottomVolPercent = math.floor((state.bottomRowVolume / 127) * 100),
    effectiveTopVolPercent = math.floor((transposer.getEffectiveRowVelocity(true) / 127) * 100),
    modeFrac = modeFrac,
    modWheel = modVal,
    zoomLevel = effectiveScale,
    spotlight = spotlightInfo,
    keys = keyUpdates
  }

  local jsonStr = hs.json.encode(payload)
  _G.activeWatchers.midiWebview:evaluateJavaScript("renderHud(" .. jsonStr .. ")")
end

local function updateWebviewHud(spotlightInfo, activeArpPitch, forceImmediate)
  if spotlightInfo ~= nil then pendingSpotlightInfo = spotlightInfo end
  if activeArpPitch ~= nil then pendingActiveArpPitch = activeArpPitch end

  if forceImmediate then
    performWebviewHudUpdate(pendingSpotlightInfo, pendingActiveArpPitch)
    pendingSpotlightInfo = nil
    return
  end

  if not hudUpdateScheduled then
    hudUpdateScheduled = true
    hs.timer.doAfter(0.016, function()
      hudUpdateScheduled = false
      local s = pendingSpotlightInfo
      local a = pendingActiveArpPitch
      pendingSpotlightInfo = nil
      performWebviewHudUpdate(s, a)
    end)
  end
end

local function createMidiWebview()
  if _G.activeWatchers.midiWebview then
    _G.activeWatchers.midiWebview:delete()
    _G.activeWatchers.midiWebview = nil
  end

  local screen = hs.screen.mainScreen():frame()
  local effectiveScale = state.zoomLevel * state.BASE_HUD_SCALE
  local width = math.floor(980 * effectiveScale)
  local height = math.floor(330 * effectiveScale)
  local savedX = hs.settings.get("qwertyMidi_hudX")
  local savedY = hs.settings.get("qwertyMidi_hudY")
  local hudX = savedX or _G.activeWatchers.hudX or math.floor(screen.x + (screen.w - width) / 2)
  local hudY = savedY or _G.activeWatchers.hudY or math.floor(screen.y + screen.h - height - 60)

  local uc = hsUsercontent.new("midiControllerUC")
  uc:setCallback(function(msg)
    if not msg or not msg.body then return end
    local body = msg.body
    if body.type == "domReady" then
      updateWebviewHud()
    elseif body.type == "keyDown" and body.code then
      if controlsModule then controlsModule.handleKeyDown(body.code) end
    elseif body.type == "keyUp" and body.code then
      if controlsModule then controlsModule.handleKeyUp(body.code) end
    elseif body.type == "setRoot" and body.root ~= nil then
      state.currentRoot = math.max(0, math.min(11, body.root))
      arpeggiator.updateLatchedArpNotes()
      local rootName = NOTE_NAMES[state.currentRoot + 1]
      local spot = {
        title = "ROOT NOTE",
        value = rootName,
        subtext = rootName .. " " .. SCALES[state.currentScaleIdx].name,
        targetId = "root-select",
        color = "#d4a359"
      }
      updateWebviewHud(spot)
    elseif body.type == "setModeIdx" and body.modeIdx ~= nil then
      state.currentScaleIdx = math.max(1, math.min(#SCALES, body.modeIdx))
      arpeggiator.updateLatchedArpNotes()
      local scaleInfo = SCALES[state.currentScaleIdx]
      local spot = {
        title = "SCALE / MODE",
        value = scaleInfo.name,
        subtext = scaleInfo.brightTag,
        targetId = "mode-thumb",
        color = "#d4a359"
      }
      updateWebviewHud(spot)
    elseif body.type == "toggleArpPower" then
      arpeggiator.toggleArpPower()
    elseif body.type == "setArpDirection" and body.directionIdx ~= nil then
      state.arpDirectionIdx = math.max(1, math.min(#ARP_DIRECTIONS, body.directionIdx))
      local spot = {
        title = "ARP DIRECTION",
        value = ARP_DIRECTIONS[state.arpDirectionIdx],
        subtext = state.arpEnabled and "Active Pattern" or "Arp Disabled",
        targetId = "arp-dir-select",
        color = "#d4a359"
      }
      updateWebviewHud(spot)
    elseif body.type == "setArpRate" and body.rateIdx ~= nil then
      state.arpRateIdx = math.max(1, math.min(#ARP_RATES, body.rateIdx))
      arpeggiator.applyBpmChange()
      local spot = {
        title = "ARP RATE",
        value = ARP_RATES[state.arpRateIdx].label,
        subtext = "Note Division",
        targetId = "arp-rate-select",
        color = "#d4a359"
      }
      updateWebviewHud(spot)
    elseif body.type == "dragGate" and body.delta ~= nil then
      state.arpGatePercent = math.max(5.0, math.min(150.0, (state.arpGatePercent or 80.0) + body.delta))
      local spot = {
        title = "ARP NOTE LENGTH",
        value = math.floor(state.arpGatePercent + 0.5) .. "%",
        subtext = "Gate Duration",
        targetId = "gate-value",
        color = "#d4a359"
      }
      updateWebviewHud(spot)
    elseif body.type == "gateUp" then
      state.arpGatePercent = math.min(150.0, (state.arpGatePercent or 80.0) + 5.0)
      local spot = {
        title = "ARP NOTE LENGTH",
        value = math.floor(state.arpGatePercent + 0.5) .. "%",
        subtext = "Gate Duration",
        targetId = "gate-value",
        color = "#d4a359"
      }
      updateWebviewHud(spot)
    elseif body.type == "gateDown" then
      state.arpGatePercent = math.max(5.0, (state.arpGatePercent or 80.0) - 5.0)
      local spot = {
        title = "ARP NOTE LENGTH",
        value = math.floor(state.arpGatePercent + 0.5) .. "%",
        subtext = "Gate Duration",
        targetId = "gate-value",
        color = "#d4a359"
      }
      updateWebviewHud(spot)
    elseif body.type == "enterBpmEdit" then
      state.bpmInputMode = true
      state.bpmBeforeEdit = state.arpBpm
      state.bpmInputBuffer = ""
      updateWebviewHud()
    elseif body.type == "bpmUp" then
      local step = state.bpmStepSize or 10
      state.arpBpm = math.min(300, state.arpBpm + step)
      arpeggiator.applyBpmChange()
      arpeggiator.stepLogicBpm(step)
      updateWebviewHud()
    elseif body.type == "bpmDown" then
      local step = state.bpmStepSize or 10
      state.arpBpm = math.max(20, state.arpBpm - step)
      arpeggiator.applyBpmChange()
      arpeggiator.stepLogicBpm(-step)
      updateWebviewHud()
    elseif body.type == "toggleLogicSync" then
      arpeggiator.toggleLogicSync()
    elseif body.type == "dragBpm" and body.delta ~= nil then
      state.arpBpm = math.max(20.0, math.min(300.0, state.arpBpm + body.delta))
      arpeggiator.applyBpmChange()
      updateWebviewHud()
    elseif body.type == "toggleArpTop" then
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
      updateWebviewHud(spot)
    elseif body.type == "toggleArpBottom" then
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
      updateWebviewHud(spot)
    elseif body.type == "dragOctave" and body.row and body.direction then
      if body.row == "top" then
        state.topRowOctaveOffset = math.max(-36, math.min(36, state.topRowOctaveOffset + (body.direction * 12)))
      else
        state.octaveShift = math.max(-36, math.min(36, state.octaveShift + (body.direction * 12)))
      end
      updateWebviewHud()
    elseif body.type == "dragWindow" and body.dx and body.dy then
      if _G.activeWatchers.midiWebview then
        local frame = _G.activeWatchers.midiWebview:frame()
        local newX = math.floor(frame.x + body.dx)
        local newY = math.floor(frame.y + body.dy)
        _G.activeWatchers.midiWebview:frame({ x = newX, y = newY, w = frame.w, h = frame.h })
        _G.activeWatchers.hudX = newX
        _G.activeWatchers.hudY = newY
        hs.settings.set("qwertyMidi_hudX", newX)
        hs.settings.set("qwertyMidi_hudY", newY)
      end
    end
  end)

  local rect = { x = hudX, y = hudY, w = width, h = height }
  local wv = hsWebview.new(rect, { developerExtrasEnabled = false }, uc)
  wv:windowTitle("MIDI Controller HUD")
  wv:windowStyle({ "borderless", "utility" })
  wv:transparent(true)
  wv:html(HTML_UI_CONTENT)
  wv:level(hs.canvas.windowLevels.floating)
  wv:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
  wv:show()

  wv:windowCallback(function(action, webview)
    if action == "closing" then
      _G.activeWatchers.midiWebview = nil
    end
  end)

  _G.activeWatchers.midiWebview = wv

  hs.timer.doAfter(0.05, function()
    if _G.activeWatchers.midiWebview then
      updateWebviewHud()
    end
  end)
  hs.timer.doAfter(0.25, function()
    if _G.activeWatchers.midiWebview then
      updateWebviewHud()
    end
  end)

  return wv
end

return {
  setControlsModule = setControlsModule,
  updateWebviewHud = updateWebviewHud,
  createMidiWebview = createMidiWebview
}
