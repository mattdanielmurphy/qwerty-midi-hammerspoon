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
local ARP_DIRECTIONS = state.ARP_DIRECTIONS
local ARP_RATES = state.ARP_RATES
local ARP_GATES = state.ARP_GATES

local HTML_UI_CONTENT = require("ui_html")
local webviewGeneration = 0
local lastHeartbeat = 0
local evalFailCount = 0
local lastPongTime = 0
local lastLatencyMs = 0
local pendingPingTime = 0

local function hudLog(msg)
  print("QWERTY MIDI HUD: " .. msg)
  local f = io.open("/tmp/midi_startup.log", "a")
  if f then
    f:write(os.date("%H:%M:%S") .. " [HUD]: " .. tostring(msg) .. "\n")
    f:close()
  end
end

_G.activeWatchers = _G.activeWatchers or {}


local controlsModule = nil

local function setControlsModule(m)
  controlsModule = m
end

state.textInputActive = false

local pendingSpotlightInfo = nil
local pendingActiveArpPitch = nil
local hudUpdateScheduled = false
local lastFrameScale = nil
local _savedNormalHeight = nil

local function safeEvaluateJS(js)
  if not _G.activeWatchers.midiWebview then return end
  local ok, err = pcall(function()
    _G.activeWatchers.midiWebview:evaluateJavaScript(js)
  end)
  if not ok then
    hudLog("evaluateJavaScript error: " .. tostring(err))
  end
  return ok
end


local function performWebviewHudUpdate(spotlightInfo, activeArpPitch)
  if not _G.activeWatchers.midiWebview or not _G.activeWatchers.domIsReady then return end

  local baseW, baseH = 980, 280
  local effectiveScale = state.zoomLevel * state.BASE_HUD_SCALE
  local NOTIF_BAND = math.floor(50 * effectiveScale)
  local newW = math.floor(baseW * effectiveScale)
  local newH = math.floor(baseH * effectiveScale) + NOTIF_BAND

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
  
  local currentScaleIdx = tonumber(state.currentScaleIdx) or 1
  local modeFrac = (currentScaleIdx - 0.5) / #SCALES
  local modeName = SCALES[currentScaleIdx].name
  
  local octVal = tonumber(state.octaveShift) or 0
  local topOctVal = tonumber(state.topRowOctaveOffset) or 0
  local trnspVal = tonumber(state.transposeShift) or 0
  local trnspStr = (trnspVal ~= 0) and ("Trnsp: " .. (trnspVal >= 0 and "+" or "") .. trnspVal .. "st") or ""
  local susStr = state.sustainActive and "SUS: ON" or ""
  local shiftStr = state.shiftHeld and "[SHIFT]" or ""

  local statusParts = {}
  if trnspStr ~= "" then table.insert(statusParts, trnspStr) end
  if susStr ~= "" then table.insert(statusParts, susStr) end
  if state.arpEnabled then table.insert(statusParts, state.arpLatchActive and "ARP: LATCH" or "ARP: ON") end
  if shiftStr ~= "" then table.insert(statusParts, shiftStr) end
  local statusStr = table.concat(statusParts, "  •  ")

  local topOctaveStr = (topOctVal >= 0 and "+" or "") .. math.floor(topOctVal / 12)
  local bottomOctaveStr = (octVal >= 0 and "+" or "") .. math.floor(octVal / 12)

  local keyUpdates = {}

  local actionTypeClass = {
    -- Home row pairs
    trnspDown = "ctrl-trnsp", trnspUp = "ctrl-trnsp",
    rootDown = "ctrl-root", rootUp = "ctrl-root",
    modeDown = "ctrl-mode", modeUp = "ctrl-mode",
    octaveDown = "ctrl-oct", octaveUp = "ctrl-oct",
    topOctDown = "ctrl-topoct", topOctUp = "ctrl-topoct",
    topVolDown = "ctrl-vol", topVolUp = "ctrl-vol",
    modWheelDown = "ctrl-modw", modWheelUp = "ctrl-modw",
    volDown = "ctrl-vol", volUp = "ctrl-vol",
    
    -- Number row pairs
    arpDirDown = "ctrl-arpdir", arpDirUp = "ctrl-arpdir",
    arpRateDown = "ctrl-arprate", arpRateUp = "ctrl-arprate",
    arpGateDown = "ctrl-arpgate", arpGateUp = "ctrl-arpgate",
    relDown = "ctrl-rel", relUp = "ctrl-rel", releaseDown = "ctrl-rel", releaseUp = "ctrl-rel",
    bpmDown = "ctrl-bpm", bpmUp = "ctrl-bpm",
    zoomOut = "ctrl-zoom", zoomIn = "ctrl-zoom",
    
    -- Singletons / Toggles
    arpToggle = "ctrl-arp", arpTopToggle = "ctrl-arptop", arpBottomToggle = "ctrl-arpbot",
    bpmEdit = "ctrl-bpmedit", randomScale = "ctrl-rand", panic = "ctrl-panic", resetAll = "ctrl-reset",
    undoState = "ctrl-reset", redoState = "ctrl-reset",
    chordToggle = "ctrl-mode", chordMod = "ctrl-mode", chordUp = "ctrl-mode", chordDown = "ctrl-mode"
  }

  for code, cData in pairs(numberRowControls) do
    local isMainArp = (cData.action == "arpToggle")
    local isTopArp = (cData.action == "arpTopToggle")
    local isBotArp = (cData.action == "arpBottomToggle")
    local isArpActive = not state.shiftHeld and ((isMainArp and state.arpEnabled) or (isTopArp and state.arpTopEnabled) or (isBotArp and state.arpBottomEnabled))
    local activeAct = state.shiftHeld and (cData.shiftAction or cData.action) or cData.action
    local pairedClass = actionTypeClass[activeAct] or actionTypeClass[cData.action] or ""
    local isActiveToggle = (isMainArp and state.arpEnabled) or (isTopArp and state.arpTopEnabled) or (isBotArp and state.arpBottomEnabled)
    keyUpdates[tostring(code)] = {
      note = cData.name,
      action = cData.action,
      shiftNote = cData.shiftName or cData.name,
      shiftAction = cData.shiftAction,
      isControl = true,
      typeClass = isActiveToggle and "latch-active" or pairedClass,
      pressed = (state.pressedKeys[code] ~= nil),
      sustainActive = isActiveToggle
    }
  end

  for code, kData in pairs(config.getActiveNoteKeysMap()) do
    local noteNum = transposer.getTransposedPitch(kData.baseNote, kData.isTop)
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
      local currentArpPitch = activeArpPitch or (type(state.arpCurrentPitch) == "table" and state.arpCurrentPitch.pitch or state.arpCurrentPitch)
      if state.arpEnabled and currentArpPitch and noteNum == currentArpPitch then
        isPressed = true
      end

    local isLatched = state.arpEnabled and state.arpLatchActive and (state.arpHeldNotes[code] ~= nil)

    keyUpdates[tostring(code)] = {
      note = noteName,
      action = kData.action,
      shiftNote = kData.shiftName or noteName,
      shiftAction = kData.shiftAction,
      typeClass = typeClass,
      pressed = isPressed,
      latched = isLatched,
      outOfBounds = (noteNum < 0 or noteNum > 127)
    }
  end

  for code, cData in pairs(config.getActiveControlKeysMap()) do
    local isSustain = (cData.action == "sustain" or cData.shiftAction == "sustain")
    local isChordToggle = (cData.action == "chordToggle" or cData.shiftAction == "chordToggle")
    local activeAct = state.shiftHeld and (cData.shiftAction or cData.action) or cData.action
    local pairedClass = actionTypeClass[activeAct] or actionTypeClass[cData.action] or ""
    
    local isActiveToggle = false
    if isSustain and state.sustainActive then isActiveToggle = true end
    if isChordToggle and state.chordModeActive then isActiveToggle = true end

    keyUpdates[tostring(code)] = {
      note = cData.name,
      action = cData.action,
      shiftNote = cData.shiftName or cData.name,
      shiftAction = cData.shiftAction,
      isControl = true,
      typeClass = isActiveToggle and "latch-active" or pairedClass,
      pressed = (state.pressedKeys[code] ~= nil),
      sustainActive = isActiveToggle
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
    stackedKeyLabelsInPerformanceMode = state.stackedKeyLabelsInPerformanceMode == true,
    shiftHeld = state.shiftHeld,
    rootIdx = state.currentRoot,
    modeName = modeName,
    arpEnabled = state.arpEnabled,
    arpLatchActive = state.arpLatchActive,
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
  local ok, err = pcall(function()
    _G.activeWatchers.midiWebview:evaluateJavaScript("renderHud(" .. jsonStr .. ")")
  end)
  if ok then
    evalFailCount = 0
  else
    evalFailCount = evalFailCount + 1
    if evalFailCount >= 3 then
      hudLog("webview appears dead (" .. evalFailCount .. " consecutive evaluateJS failures) — recreating")
      evalFailCount = 0
      hs.timer.doAfter(0.1, function()
        if state.midiActive then
          local rok, rerr = pcall(function()
            local h = createMidiWebview()
            h:show()
          end)
          if not rok then
            hudLog("webview recreate failed: " .. tostring(rerr))
          end
        end
      end)
    end
  end
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
  hudLog("createMidiWebview")
  webviewGeneration = webviewGeneration + 1
  lastHeartbeat = os.time()
  evalFailCount = 0
  _G.activeWatchers.domIsReady = false
  local myGen = webviewGeneration
  if _G.activeWatchers.midiWebview then
    -- Clear callback BEFORE delete to prevent async race nuking new webview ref
    _G.activeWatchers.midiWebview:windowCallback(nil)
    _G.activeWatchers.midiWebview:delete()
    _G.activeWatchers.midiWebview = nil
  end

  local screen = hs.screen.mainScreen():frame()
  local effectiveScale = state.zoomLevel * state.BASE_HUD_SCALE
  local NOTIF_BAND = math.floor(50 * effectiveScale)
  local width = math.floor(980 * effectiveScale)
  local height = math.floor(280 * effectiveScale) + NOTIF_BAND
  local savedX = hs.settings.get("qwertyMidi_hudX")
  local savedY = hs.settings.get("qwertyMidi_hudY")
  local hudX = savedX or _G.activeWatchers.hudX or math.floor(screen.x + (screen.w - width) / 2)
  local hudY = savedY or _G.activeWatchers.hudY or math.floor(screen.y + screen.h - height - 60)

  local uc = hsUsercontent.new("midiControllerUC")
  uc:setCallback(function(msg)
    if not msg or not msg.body then return end
    local body = msg.body
    if body.type == "domReady" then
      hudLog("domReady")
      _G.activeWatchers.domIsReady = true
      lastHeartbeat = os.time()
      evalFailCount = 0
      updateWebviewHud()
    elseif body.type == "pong" then
      lastPongTime = os.time()
      lastHeartbeat = os.time()
      if pendingPingTime > 0 then
        lastLatencyMs = math.max(0, math.floor((hs.timer.absoluteTime() - pendingPingTime) / 1000000))
        pendingPingTime = 0
      end
    elseif body.type == "ping" then
      safeEvaluateJS("if (window.pingHudController) window.pingHudController();")
    elseif body.type == "heartbeat" then
      lastHeartbeat = os.time()
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
      arpeggiator.applyGatePercentChange()
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
      arpeggiator.applyGatePercentChange()
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
      arpeggiator.applyGatePercentChange()
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
      local spot = {
        title = "EDIT BPM",
        value = "TYPE TEMPO",
        subtext = "Type digits & press Enter",
        targetId = "bpm-value",
        color = "#d4a359"
      }
      updateWebviewHud(spot)
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
      if arpeggiator.setLogicBpmTarget then arpeggiator.setLogicBpmTarget(state.arpBpm) end
      updateWebviewHud()
    elseif body.type == "toggleArpTop" then
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
      updateWebviewHud(spot)
    elseif body.type == "toggleArpBottom" then
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
      updateWebviewHud(spot)
    elseif body.type == "dragOctave" and body.row and body.direction then
      if body.row == "top" then
        state.topRowOctaveOffset = math.max(-48, math.min(36, state.topRowOctaveOffset + (body.direction * 12)))
        hs.settings.set("qwertyMidi_topRowOctaveOffset", state.topRowOctaveOffset)
      else
        state.bottomRowOctaveOffset = math.max(-48, math.min(36, state.bottomRowOctaveOffset + (body.direction * 12)))
        hs.settings.set("qwertyMidi_bottomRowOctaveOffset", state.bottomRowOctaveOffset)
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
    elseif body.type == "toggleEditMode" then
      if _G.activeWatchers.midiWebview then
        local wv = _G.activeWatchers.midiWebview
        local frame = wv:frame()
        local effectiveScale = state.zoomLevel * state.BASE_HUD_SCALE
        local editH = math.floor(460 * effectiveScale)
        if body.active then
          _savedNormalHeight = frame.h
          local diffH = editH - frame.h
          wv:frame({ x = frame.x, y = frame.y - diffH, w = frame.w, h = editH })
        else
          local restoreH = _savedNormalHeight or math.floor(330 * effectiveScale)
          local diffH = frame.h - restoreH
          _savedNormalHeight = nil
          wv:frame({ x = frame.x, y = frame.y + diffH, w = frame.w, h = restoreH })
        end
      end
    elseif body.type == "getLayoutConfig" then
      if _G.activeWatchers.midiWebview then
        local cfgJson = hs.json.encode(config.getLayoutConfig())
        safeEvaluateJS("if (window.onLayoutConfigLoaded) window.onLayoutConfigLoaded(" .. cfgJson .. ");")
      end
    elseif body.type == "saveCustomLayout" then
      config.saveCustomLayout(body.layout or body.data)
      updateWebviewHud(nil, nil, true)
      if _G.activeWatchers.midiWebview then
        local cfgJson = hs.json.encode(config.getLayoutConfig())
        safeEvaluateJS("if (window.onLayoutConfigLoaded) window.onLayoutConfigLoaded(" .. cfgJson .. ");")
      end
    elseif body.type == "selectPreset" then
      config.selectPreset(body.id)
      updateWebviewHud(nil, nil, true)
      if _G.activeWatchers.midiWebview then
        local cfgJson = hs.json.encode(config.getLayoutConfig())
        safeEvaluateJS("if (window.onLayoutConfigLoaded) window.onLayoutConfigLoaded(" .. cfgJson .. ");")
      end
    elseif body.type == "savePreset" then
      config.savePreset(body.id, body.name, body.layout or body.data)
      updateWebviewHud(nil, nil, true)
      if _G.activeWatchers.midiWebview then
        local cfgJson = hs.json.encode(config.getLayoutConfig())
        safeEvaluateJS("if (window.onLayoutConfigLoaded) window.onLayoutConfigLoaded(" .. cfgJson .. ");")
      end
    elseif body.type == "renamePreset" then
      config.renamePreset(body.id, body.newName)
      if _G.activeWatchers.midiWebview then
        local cfgJson = hs.json.encode(config.getLayoutConfig())
        safeEvaluateJS("if (window.onLayoutConfigLoaded) window.onLayoutConfigLoaded(" .. cfgJson .. ");")
      end
    elseif body.type == "deletePreset" then
      config.deletePreset(body.id)
      updateWebviewHud(nil, nil, true)
      if _G.activeWatchers.midiWebview then
        local cfgJson = hs.json.encode(config.getLayoutConfig())
        safeEvaluateJS("if (window.onLayoutConfigLoaded) window.onLayoutConfigLoaded(" .. cfgJson .. ");")
      end
    elseif body.type == "duplicatePreset" then
      config.duplicatePreset(body.id, body.newName)
      updateWebviewHud(nil, nil, true)
      if _G.activeWatchers.midiWebview then
        local cfgJson = hs.json.encode(config.getLayoutConfig())
        safeEvaluateJS("if (window.onLayoutConfigLoaded) window.onLayoutConfigLoaded(" .. cfgJson .. ");")
      end
    elseif body.type == "resetLayout" then
      config.resetLayout()
      updateWebviewHud(nil, nil, true)
      if _G.activeWatchers.midiWebview then
        local cfgJson = hs.json.encode(config.getLayoutConfig())
        safeEvaluateJS("if (window.onLayoutConfigLoaded) window.onLayoutConfigLoaded(" .. cfgJson .. ");")
      end
    elseif body.type == "updateKeyMapping" then
      if body.code and body.binding then
        config.updateKeyMapping(body.code, body.binding)
        updateWebviewHud(nil, nil, true)
      end
    elseif body.type == "textInputFocus" then
      state.textInputActive = (body.focused == true)
    elseif body.type == "log" then
      if body.message then
        local f = io.open("/tmp/wv_js.log", "a")
        if f then f:write(tostring(body.message) .. "\n"); f:close() end
      end
    elseif body.type == "hoverScrollable" then
      _G.activeWatchers.isHoveringScrollable = body.state
      -- Safer file logging replacing os.execute
      if body.message then
        local f = io.open("/tmp/wv_js.log", "a")
        if f then
          f:write(tostring(body.message) .. "\n")
          f:close()
        end
      end
    end
    config.saveSettings()
  end)

  local rect = { x = hudX, y = hudY, w = width, h = height }
  local wv = hsWebview.new(rect, { developerExtrasEnabled = true }, uc)
  wv:windowTitle("MIDI Controller HUD")
  wv:windowStyle({ "borderless", "utility" })
  wv:transparent(true)

  wv:html(HTML_UI_CONTENT)
  wv:level(hs.canvas.windowLevels.floating)
  wv:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
  wv:show()

  wv:windowCallback(function(action, webview)
    if action == "closing" then
      hudLog("webview teardown (generation " .. myGen .. ")")
      -- Ignore stale callbacks from old webview generations
      if myGen ~= webviewGeneration then return end
      _G.activeWatchers.midiWebview = nil
      -- If midiActive is still true, the webview crashed unexpectedly — auto-respawn
      if state.midiActive then
        hudLog("webview closed unexpectedly — respawning in 0.5s")
        hs.timer.doAfter(0.5, function()
          if state.midiActive and myGen == webviewGeneration then
            local ok, err = pcall(function()
              local h = createMidiWebview()
              h:show()
            end)
            if not ok then
              hudLog("webview respawn failed: " .. tostring(err))
            end
          end
        end)
      end
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
  hs.timer.doAfter(1.0, function()
    if _G.activeWatchers.midiWebview and myGen == webviewGeneration then
      updateWebviewHud()
    end
  end)

  return wv
end

local function pingWebview()
  if not _G.activeWatchers.midiWebview then return false end
  hudLog("ping")
  pendingPingTime = hs.timer.absoluteTime()
  safeEvaluateJS("if (window.pingHudController) window.pingHudController();")
  return true
end

local function pongWebview()
    hudLog("pong")
end

local function dumpMidiLogs()
  local output = {}
  table.insert(output, "=== QWERTY MIDI DIAGNOSTICS & LOGS ===")
  table.insert(output, "Time: " .. os.date("%Y-%m-%d %H:%M:%S"))
  table.insert(output, "Webview Gen: " .. tostring(webviewGeneration))
  table.insert(output, "Last Heartbeat: " .. tostring(os.time() - lastHeartbeat) .. "s ago")
  table.insert(output, "Last Pong: " .. tostring(os.time() - lastPongTime) .. "s ago (Latency: " .. lastLatencyMs .. "ms)")
  table.insert(output, "Eval Failures: " .. tostring(evalFailCount))
  table.insert(output, "\n--- /tmp/midi_startup.log (last 20 lines) ---")
  local f = io.open("/tmp/midi_startup.log", "r")
  if f then
    local lines = {}
    for line in f:lines() do table.insert(lines, line) end
    f:close()
    for i = math.max(1, #lines - 20), #lines do table.insert(output, lines[i]) end
  end
  table.insert(output, "\n--- /tmp/wv_js.log (last 20 lines) ---")
  local fjs = io.open("/tmp/wv_js.log", "r")
  if fjs then
    local lines = {}
    for line in fjs:lines() do table.insert(lines, line) end
    fjs:close()
    for i = math.max(1, #lines - 20), #lines do table.insert(output, lines[i]) end
  end
  local res = table.concat(output, "\n")
  print(res)
  hs.pasteboard.setContents(res)
  hs.alert.show("Diagnostics Log Copied to Clipboard", 2)
  return res
end

local function pingController()
  pingWebview()
  hs.timer.doAfter(0.15, function()
    local now = os.time()
    if (now - lastPongTime) < 2 then
      hs.alert.show(string.format("🟢 QWERTY MIDI UI Responsive (Latency: %dms)", lastLatencyMs), 2)
    else
      hs.alert.show("🔴 QWERTY MIDI UI Unresponsive", 2)
    end
  end)
  return (os.time() - lastPongTime) < 2
end

local function reloadMidiWebview()
  lastFrameScale = nil
  if _G.activeWatchers.midiWebview then
    pcall(function()
      _G.activeWatchers.midiWebview:windowCallback(nil)
      _G.activeWatchers.midiWebview:delete()
    end)
    _G.activeWatchers.midiWebview = nil
  end
  _G.activeWatchers.domIsReady = false
  return createMidiWebview()
end

return {
  setControlsModule = setControlsModule,
  updateWebviewHud = updateWebviewHud,
  createMidiWebview = createMidiWebview,
  reloadMidiWebview = reloadMidiWebview,
  getLastHeartbeat = function() return lastHeartbeat end,
  pingWebview = pingWebview,
  pingController = pingController,
  getLastPongTime = function() return lastPongTime end,
  getLastLatencyMs = function() return lastLatencyMs end,
  dumpMidiLogs = dumpMidiLogs
}
