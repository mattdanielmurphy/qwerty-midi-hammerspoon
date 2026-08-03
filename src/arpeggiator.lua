local config = require("config")
local midi = require("midi")
local transposer = require("transposer")

local state = config.state
local upperRowKeys = config.upperRowKeys
local lowerRowKeys = config.lowerRowKeys
local ARP_DIRECTIONS = state.ARP_DIRECTIONS
local ARP_RATES = state.ARP_RATES
local ARP_GATES = state.ARP_GATES
local DIGIT_KEYCODES = state.DIGIT_KEYCODES


local function countTableKeys(t)
  local count = 0
  for _ in pairs(t or {}) do count = count + 1 end
  return count
end

local hudModule = nil

local function setHudModule(m)
  hudModule = m
end

local function updateHud(spotlightInfo, activeArpPitch)
  if hudModule and hudModule.updateWebviewHud then
    hudModule.updateWebviewHud(spotlightInfo, activeArpPitch)
  end
end

local function stopArpTimer()
  state.arpBeatPosition = 0
  if state.arpActiveGateTimers then
    for pitchInfo, entry in pairs(state.arpActiveGateTimers) do
      if entry and entry.timer then entry.timer:stop() end
      local pitch = type(pitchInfo) == "table" and pitchInfo.pitch or pitchInfo
      local ch = entry and entry.channel or 0
      midi.sendMidiNote("noteOff", pitch, 0, ch)
    end
    state.arpActiveGateTimers = {}
  end
  if state.arpGateTimer then
    state.arpGateTimer:stop()
    state.arpGateTimer = nil
  end
  if state.arpTimer then
    state.arpTimer:stop()
    state.arpTimer = nil
  end
  if state.arpCurrentPitch then
    local p = type(state.arpCurrentPitch) == "table" and state.arpCurrentPitch.pitch or state.arpCurrentPitch
    local c = type(state.arpCurrentPitch) == "table" and state.arpCurrentPitch.channel or 0
    midi.sendMidiNote("noteOff", p, 0, c)
    state.arpCurrentPitch = nil
  end
  state.arpStepIndex = 1
  state.arpStepDirection = 1
  state.arpPos = 0
end

local function getArpIntervalSeconds()
  local rateFactor = ARP_RATES[state.arpRateIdx] and ARP_RATES[state.arpRateIdx].factor or 0.5
  return (60.0 / state.arpBpm) * rateFactor
end

local function arpTick()
  local rateFactor = ARP_RATES[state.arpRateIdx] and ARP_RATES[state.arpRateIdx].factor or 0.5
  local prevBeat = math.floor(state.arpBeatPosition or 0)
  local prevBar = math.floor((state.arpBeatPosition or 0) / 4)
  state.arpBeatPosition = (state.arpBeatPosition or 0) + rateFactor
  
  local currentBeat = math.floor(state.arpBeatPosition)
  local currentBar = math.floor(state.arpBeatPosition / 4)
  
  local doSync = false
  if state.arpQuantizeMode == "Beat" and currentBeat > prevBeat then
    doSync = true
  elseif state.arpQuantizeMode == "Bar" and currentBar > prevBar then
    doSync = true
  end

  if doSync then
    state.arpHeldNotes = {}
    if state.arpTargetHeldNotes then
      for k,v in pairs(state.arpTargetHeldNotes) do state.arpHeldNotes[k] = v end
    end
    if countTableKeys(state.arpHeldNotes) == 0 then
      stopArpTimer()
      updateHud()
      return
    end
  end

  local pitchList = {}
  for code, pitch in pairs(state.arpHeldNotes) do
    local rawCode = type(code) == "string" and tonumber(code:match("^(%d+)")) or tonumber(code)
    local noteKey = rawCode and config.getNoteKey(rawCode)
    local isTop = noteKey and noteKey.isTop or false
    local rowArpEnabled = isTop and state.arpTopEnabled or (not isTop and state.arpBottomEnabled)
    if rowArpEnabled and pitch then
      table.insert(pitchList, pitch)
    end
  end
  table.sort(pitchList)

  if #pitchList == 0 then
    if state.arpActiveGateTimers then
      for pitch, entry in pairs(state.arpActiveGateTimers) do
        if entry and entry.timer then entry.timer:stop() end
        local ch = entry and entry.channel or 0
        midi.sendMidiNote("noteOff", pitch, 0, ch)
      end
      state.arpActiveGateTimers = {}
    end
    if state.arpGateTimer then
      state.arpGateTimer:stop()
      state.arpGateTimer = nil
    end
    if state.arpCurrentPitch then
      local p = type(state.arpCurrentPitch) == "table" and state.arpCurrentPitch.pitch or state.arpCurrentPitch
      local c = type(state.arpCurrentPitch) == "table" and state.arpCurrentPitch.channel or 0
      midi.sendMidiNote("noteOff", p, 0, c)
      state.arpCurrentPitch = nil
      updateHud()
    end
    return
  end

  if state.arpDirectionIdx == 1 then -- UP
    local pos = (state.arpPos % #pitchList) + 1
    state.arpStepIndex = pos
  elseif state.arpDirectionIdx == 2 then -- DOWN
    local pos = (state.arpPos % #pitchList) + 1
    state.arpStepIndex = #pitchList - pos + 1
  elseif state.arpDirectionIdx == 3 then -- UP-DOWN
    if state.arpStepIndex > #pitchList then
      state.arpStepIndex = math.max(1, #pitchList - 1)
      state.arpStepDirection = -1
    elseif state.arpStepIndex < 1 then
      state.arpStepIndex = math.min(#pitchList, 2)
      state.arpStepDirection = 1
    end
  elseif state.arpDirectionIdx == 4 then -- DOWN-UP
    if state.arpStepIndex > #pitchList or state.arpStepIndex < 1 then
      state.arpStepIndex = math.max(1, #pitchList - 1)
      state.arpStepDirection = -1
    end
  elseif state.arpDirectionIdx == 5 then -- CONVERGE (Outside -> In)
    local pos = (state.arpPos % #pitchList) + 1
    local idx
    if pos % 2 == 1 then
      idx = math.floor(pos / 2) + 1
    else
      idx = #pitchList - math.floor(pos / 2) + 1
    end
    state.arpStepIndex = math.max(1, math.min(#pitchList, idx))
  elseif state.arpDirectionIdx == 6 then -- DIVERGE (Inside -> Out)
    local pos = (state.arpPos % #pitchList) + 1
    local mid = math.floor((#pitchList + 1) / 2)
    local idx
    if pos == 1 then
      idx = mid
    elseif pos % 2 == 0 then
      idx = mid + math.floor(pos / 2)
    else
      idx = mid - math.floor(pos / 2)
    end
    if idx < 1 or idx > #pitchList then
      idx = ((pos - 1) % #pitchList) + 1
    end
    state.arpStepIndex = idx
  elseif state.arpDirectionIdx == 7 then -- RANDOM
    state.arpStepIndex = math.random(1, #pitchList)
  end

  state.arpStepIndex = math.max(1, math.min(#pitchList, state.arpStepIndex or 1))
  local nextPitch = pitchList[state.arpStepIndex]

  if state.arpDirectionIdx == 3 then -- UP-DOWN
    if #pitchList == 1 then
      state.arpStepIndex = 1
      state.arpStepDirection = 1
    else
      state.arpStepIndex = state.arpStepIndex + state.arpStepDirection
      if state.arpStepIndex > #pitchList then
        state.arpStepIndex = math.max(1, #pitchList - 1)
        state.arpStepDirection = -1
      elseif state.arpStepIndex < 1 then
        state.arpStepIndex = math.min(#pitchList, 2)
        state.arpStepDirection = 1
      end
    end
  elseif state.arpDirectionIdx == 4 then -- DOWN-UP
    if #pitchList == 1 then
      state.arpStepIndex = 1
      state.arpStepDirection = -1
    else
      state.arpStepIndex = state.arpStepIndex + state.arpStepDirection
      if state.arpStepIndex < 1 then
        state.arpStepIndex = math.min(#pitchList, 2)
        state.arpStepDirection = 1
      elseif state.arpStepIndex > #pitchList then
        state.arpStepIndex = math.max(1, #pitchList - 1)
        state.arpStepDirection = -1
      end
    end
  elseif state.arpDirectionIdx == 1 or state.arpDirectionIdx == 2 or state.arpDirectionIdx == 5 or state.arpDirectionIdx == 6 then
    state.arpPos = (state.arpPos or 0) + 1
  end

  local gateRatio = (state.arpGatePercent or 80.0) / 100.0
  local isTopRowArpNote = false
  for code, p in pairs(state.arpHeldNotes) do
    if p == nextPitch then
      local rawCode = type(code) == "string" and tonumber(code:match("^(%d+)")) or tonumber(code)
      local noteKey = config.getNoteKey(rawCode)
      if noteKey and noteKey.isTop then
        isTopRowArpNote = true
        break
      end
    end
  end
  local vel = transposer.getEffectiveRowVelocity(isTopRowArpNote)
  local rowCh = isTopRowArpNote and (state.topRowChannel or 0) or (state.bottomRowChannel or 0)
  local ch = (state.arpChannel ~= nil) and state.arpChannel or rowCh
  
  if gateRatio <= 1.0 and state.arpCurrentPitch then
    local oldP = type(state.arpCurrentPitch) == "table" and state.arpCurrentPitch.pitch or state.arpCurrentPitch
    local oldCh = type(state.arpCurrentPitch) == "table" and state.arpCurrentPitch.channel or 0
    if state.arpActiveGateTimers and state.arpActiveGateTimers[oldP] then
      if state.arpActiveGateTimers[oldP].timer and type(state.arpActiveGateTimers[oldP].timer.stop) == "function" then
        state.arpActiveGateTimers[oldP].timer:stop()
      end
      state.arpActiveGateTimers[oldP] = nil
    end
    midi.sendMidiNote("noteOff", oldP, 0, oldCh)
    state.arpCurrentPitch = nil
  end

  midi.sendMidiNote("noteOn", nextPitch, vel, ch)
  state.arpCurrentPitch = { pitch = nextPitch, channel = ch }

  updateHud(nil, nextPitch)

  local gateDuration = getArpIntervalSeconds() * gateRatio
  local pitchToRelease = nextPitch
  local releaseCh = ch
  local timer = hs.timer.doAfter(gateDuration, function()
    midi.sendMidiNote("noteOff", pitchToRelease, 0, releaseCh)
    if state.arpCurrentPitch and (type(state.arpCurrentPitch) == "table" and state.arpCurrentPitch.pitch or state.arpCurrentPitch) == pitchToRelease then
      state.arpCurrentPitch = nil
    end
    if state.arpActiveGateTimers then state.arpActiveGateTimers[pitchToRelease] = nil end
  end)

  state.arpActiveGateTimers = state.arpActiveGateTimers or {}
  if state.arpActiveGateTimers[pitchToRelease] then
    if state.arpActiveGateTimers[pitchToRelease].timer and type(state.arpActiveGateTimers[pitchToRelease].timer.stop) == "function" then
      state.arpActiveGateTimers[pitchToRelease].timer:stop()
    end
    state.arpActiveGateTimers[pitchToRelease] = nil
  end
  state.arpActiveGateTimers[pitchToRelease] = { timer = timer, channel = releaseCh }
  state.arpGateTimer = timer
end

local function startArpTimer(preserveState)
  if state.arpTimer then return end
  local intervalSeconds = getArpIntervalSeconds()
  if not preserveState then
    if state.arpDirectionIdx == 4 then
      state.arpStepIndex = 999 -- Force DOWN-UP to start at the top note (#pitchList)
      state.arpStepDirection = -1
    else
      state.arpStepIndex = 1
      state.arpStepDirection = 1
    end
    state.arpPos = 0
    arpTick()
  end
  state.arpTimer = hs.timer.doEvery(intervalSeconds, arpTick)
end

local function arpAddNote(code, pitch)
  local numPhysicalHeld = countTableKeys(state.arpKeysCurrentlyHeld)

  if state.arpLatchActive then
    if numPhysicalHeld == 0 or not state.arpLatchClearedForNewChord then
      state.arpTargetHeldNotes = {}
      state.arpLatchClearedForNewChord = true
      if state.arpCurrentPitch and (not state.arpQuantizeMode or state.arpQuantizeMode == "None") then
        local p = type(state.arpCurrentPitch) == "table" and state.arpCurrentPitch.pitch or state.arpCurrentPitch
        local c = type(state.arpCurrentPitch) == "table" and state.arpCurrentPitch.channel or 0
        midi.sendMidiNote("noteOff", p, 0, c)
        state.arpCurrentPitch = nil
      end
    end
  end

  state.arpKeysCurrentlyHeld[code] = true
  state.arpTargetHeldNotes = state.arpTargetHeldNotes or {}
  state.arpTargetHeldNotes[code] = pitch

  if not state.arpTimer or state.arpQuantizeMode == "None" or not state.arpQuantizeMode then
    state.arpHeldNotes = {}
    for k,v in pairs(state.arpTargetHeldNotes) do state.arpHeldNotes[k] = v end
    if not state.arpTimer then
      startArpTimer()
    end
  end
end

local function arpRemoveNote(code)
  state.arpKeysCurrentlyHeld[code] = nil

  local numPhysicalHeld = countTableKeys(state.arpKeysCurrentlyHeld)

  if state.arpLatchActive then
    if numPhysicalHeld == 0 then
      state.arpLatchClearedForNewChord = false
    end
    -- In latch mode, we DO keep the notes for the held chord.
  else
    if state.arpTargetHeldNotes then
      state.arpTargetHeldNotes[code] = nil
    end
  end

  if not state.arpTimer or state.arpQuantizeMode == "None" or not state.arpQuantizeMode then
    state.arpHeldNotes = {}
    if state.arpTargetHeldNotes then
      for k,v in pairs(state.arpTargetHeldNotes) do state.arpHeldNotes[k] = v end
    end
    if countTableKeys(state.arpHeldNotes) == 0 then
      stopArpTimer()
      updateHud()
    end
  end
end

local function formatBpm(bpm)
  if bpm == math.floor(bpm) then
    return tostring(math.floor(bpm))
  else
    return string.format("%.1f", bpm)
  end
end

local function applyBpmChange()
  if state.arpTimer then
    state.arpTimer:stop()
    state.arpTimer = nil
    startArpTimer(true)
  end
end

local function applyGatePercentChange()
  if state.arpTimer then
    local gateRatio = (state.arpGatePercent or 80.0) / 100.0
    if state.arpActiveGateTimers then
      if gateRatio <= 1.0 then
        for pitch, entry in pairs(state.arpActiveGateTimers) do
          local curPitchNum = type(state.arpCurrentPitch) == "table" and state.arpCurrentPitch.pitch or state.arpCurrentPitch
          if pitch ~= curPitchNum then
            if entry and entry.timer then entry.timer:stop() end
            local ch = entry and entry.channel or 0
            midi.sendMidiNote("noteOff", pitch, 0, ch)
            state.arpActiveGateTimers[pitch] = nil
          end
        end
      end
    end
  end
end

local function updateLatchedArpNotes()
  if not state.arpEnabled or next(state.arpHeldNotes) == nil then return end

  -- Rebuild arpTargetHeldNotes / arpHeldNotes using base keycodes
  local uniqueBaseCodes = {}
  local keysToRemove = {}
  for code, _ in pairs(state.arpHeldNotes) do
    local rawCode = type(code) == "string" and tonumber(code:match("^(%d+)")) or tonumber(code)
    if rawCode then
      uniqueBaseCodes[rawCode] = true
      table.insert(keysToRemove, code)
    end
  end

  for _, code in ipairs(keysToRemove) do
    state.arpHeldNotes[code] = nil
  end

  for rawCode, _ in pairs(uniqueBaseCodes) do
    local noteKey = config.getNoteKey(rawCode)
    if noteKey then
      local isChord = state.quoteHeld or state.chordModeActive
      if isChord then
        local newPitches = transposer.getChordPitches(noteKey.baseNote, noteKey.isTop)
        for _, p in ipairs(newPitches) do
          state.arpHeldNotes[tostring(rawCode) .. "_" .. tostring(p)] = p
        end
      else
        local newPitch = transposer.getTransposedPitch(noteKey.baseNote, noteKey.isTop)
        state.arpHeldNotes[tostring(rawCode) .. "_" .. tostring(newPitch)] = newPitch
      end
    end
  end
  if state.arpTargetHeldNotes then
    state.arpTargetHeldNotes = {}
    for k, v in pairs(state.arpHeldNotes) do
      state.arpTargetHeldNotes[k] = v
    end
  end
end

-- Rebuild arp held notes for all latched keys using the current chord (after chord type change).
-- This replaces compound key entries (e.g. "45_60", "45_64") with new pitches from the new chord.
local function updateLatchedArpChordNotes()
  if not state.arpEnabled or not state.arpLatchActive or next(state.arpHeldNotes) == nil then return end

  -- Collect unique base keycodes and all existing keys to remove (two-pass to avoid mutating during iteration)
  local uniqueBaseCodes = {}
  local keysToRemove = {}
  for code, _ in pairs(state.arpHeldNotes) do
    local rawCode = type(code) == "string" and tonumber(code:match("^(%d+)")) or tonumber(code)
    if rawCode then
      uniqueBaseCodes[rawCode] = true
      table.insert(keysToRemove, code)
    end
  end

  -- Remove all existing entries safely (outside the iteration)
  for _, code in ipairs(keysToRemove) do
    state.arpHeldNotes[code] = nil
  end

  -- Re-add entries using the new chord pitches
  for rawCode, _ in pairs(uniqueBaseCodes) do
    local noteKey = config.getNoteKey(rawCode)
    if noteKey then
      local newPitches = transposer.getChordPitches(noteKey.baseNote, noteKey.isTop)
      for _, p in ipairs(newPitches) do
        state.arpHeldNotes[tostring(rawCode) .. "_" .. tostring(p)] = p
      end
    end
  end
end

local function getArpRowTargetSubtext()
  if state.arpTopEnabled and state.arpBottomEnabled then
    return "Top & Bottom Rows"
  elseif state.arpTopEnabled then
    return "Top Row Only"
  elseif state.arpBottomEnabled then
    return "Bottom Row Only"
  else
    return "No Rows Active"
  end
end

local function toggleArpPower()
  -- Cycle: Off → Latch+On → On (no latch) → Off
  if not state.arpEnabled then
    state.arpEnabled = true
    state.arpLatchActive = true
    state.arpLatchClearedForNewChord = false
  elseif state.arpLatchActive then
    state.arpLatchActive = false
    -- Transitioning from latch to non-latch: keep physically held keys, clear latched released keys
    local newHeld = {}
    for code, pitch in pairs(state.arpHeldNotes) do
      if state.arpKeysCurrentlyHeld[code] then
        newHeld[code] = pitch
      end
    end
    state.arpHeldNotes = newHeld
    
    local count = countTableKeys(state.arpHeldNotes)
    if count == 0 then
      stopArpTimer()
      if state.arpCurrentPitch then
        local p = type(state.arpCurrentPitch) == "table" and state.arpCurrentPitch.pitch or state.arpCurrentPitch
        local c = type(state.arpCurrentPitch) == "table" and state.arpCurrentPitch.channel or 0
        midi.sendMidiNote("noteOff", p, 0, c)
        state.arpCurrentPitch = nil
      end
    end
  else
    state.arpEnabled = false
    state.arpLatchActive = false
    stopArpTimer()
    state.arpHeldNotes = {}
    state.arpKeysCurrentlyHeld = {}
  end

  local valStr = "ARP: OFF"
  local subStr = "Arp Disabled"
  if state.arpEnabled then
    if state.arpLatchActive then
      valStr = "ARP: LATCH"
      subStr = "LATCH (" .. getArpRowTargetSubtext() .. ") • " .. formatBpm(state.arpBpm) .. " BPM"
    else
      valStr = "ARP: ON"
      subStr = "ON (" .. getArpRowTargetSubtext() .. ") • " .. formatBpm(state.arpBpm) .. " BPM"
    end
  end

  local spot = {
    title = "ARPEGGIATOR",
    value = valStr,
    subtext = subStr,
    targetId = "arp-power-btn",
    color = "#d4a359"
  }
  updateHud(spot)
  config.saveSettings()
end

local function toggleArp()
  toggleArpPower()
end

local function handleBpmInput(code, flags)
  if code == 53 then -- Escape
    state.arpBpm = state.bpmBeforeEdit
    state.bpmInputMode = false
    state.bpmInputBuffer = ""
    updateHud()
    config.saveSettings()
    return true
  elseif code == 36 then -- Return
    if state.bpmInputBuffer ~= "" then
      local val = tonumber(state.bpmInputBuffer)
      if val and val >= 20 and val <= 300 then
        state.arpBpm = val
      end
    end
    local prevBpm = state.bpmBeforeEdit
    state.bpmInputMode = false
    state.bpmInputBuffer = ""
    applyBpmChange()
    setLogicBpmTarget(state.arpBpm, prevBpm)
    updateHud()
    config.saveSettings()
    return true
  elseif code == 126 then -- Arrow Up
    local delta = 1
    if flags.shift then delta = 10
    elseif flags.alt then delta = 0.1 end
    state.arpBpm = math.min(300, state.arpBpm + delta)
    state.bpmInputBuffer = ""
    applyBpmChange()
    updateHud()
    return true
  elseif code == 125 then -- Arrow Down
    local delta = 1
    if flags.shift then delta = 10
    elseif flags.alt then delta = 0.1 end
    state.arpBpm = math.max(20, state.arpBpm - delta)
    state.bpmInputBuffer = ""
    applyBpmChange()
    updateHud()
    return true
  elseif code == 51 then -- Backspace
    if #state.bpmInputBuffer > 0 then
      state.bpmInputBuffer = state.bpmInputBuffer:sub(1, -2)
    end
    local spot = {
      title = "EDIT BPM",
      value = state.bpmInputBuffer ~= "" and (state.bpmInputBuffer .. " BPM") or "TYPE TEMPO",
      subtext = "Type digits & press Enter",
      targetId = "bpm-value",
      color = "#d4a359"
    }
    updateHud(spot)
    return true
  elseif DIGIT_KEYCODES[code] then
    state.bpmInputBuffer = state.bpmInputBuffer .. DIGIT_KEYCODES[code]
    local spot = {
      title = "EDIT BPM",
      value = state.bpmInputBuffer .. " BPM",
      subtext = "Type digits & press Enter",
      targetId = "bpm-value",
      color = "#d4a359"
    }
    updateHud(spot)
    return true
  elseif code == 47 then -- Period "."
    if not state.bpmInputBuffer:find("%.") then
      state.bpmInputBuffer = state.bpmInputBuffer .. "."
    end
    local spot = {
      title = "EDIT BPM",
      value = state.bpmInputBuffer .. " BPM",
      subtext = "Type digits & press Enter",
      targetId = "bpm-value",
      color = "#d4a359"
    }
    updateHud(spot)
    return true
  end

  state.bpmInputMode = false
  state.bpmInputBuffer = ""
  updateHud()
  return false
end

local isSyncingLogicBpm = false
local logicBpmTask = nil
local logicBpmDebounceTimer = nil

local function setLogicBpmTarget(targetBpm)
  if not state.logicSyncEnabled then return end

  if logicBpmDebounceTimer then
    logicBpmDebounceTimer:stop()
    logicBpmDebounceTimer = nil
  end

  logicBpmDebounceTimer = hs.timer.doAfter(0.20, function()
    logicBpmDebounceTimer = nil
    if logicBpmTask then
      logicBpmTask:terminate()
      logicBpmTask = nil
    end

    isSyncingLogicBpm = true

    local script = string.format([[
      property minBPM : 5
      property maxBPM : 990

      on setExactBPM(targetBPM)
        set targetBPM to targetBPM as integer
        
        if targetBPM < minBPM then set targetBPM to minBPM
        if targetBPM > maxBPM then set targetBPM to maxBPM
        
        tell application "System Events"
          tell process "Logic Pro"
            set tempoSlider to missing value
            set allSliders to sliders of group 1 of group 1 of window 1
            repeat with s in allSliders
              if description of s is "Tempo" then
                set tempoSlider to s
                exit repeat
              end if
            end repeat
            
            if tempoSlider is missing value then return targetBPM
            
            repeat 20 times
              set currentBPM to (value of tempoSlider) as integer
              set deltaBPM to targetBPM - currentBPM
              
              if deltaBPM = 0 then return currentBPM
              
              if deltaBPM > 0 then
                set goingUp to true
                set amountLeft to deltaBPM
              else
                set goingUp to false
                set amountLeft to -deltaBPM
              end if
              
              set tenSteps to amountLeft div 10
              repeat tenSteps times
                if goingUp then
                  perform action "AXIncrement" of tempoSlider
                else
                  perform action "AXDecrement" of tempoSlider
                end if
              end repeat
              
              set oneSteps to amountLeft mod 10
              repeat oneSteps times
                if goingUp then
                  set value of tempoSlider to maxBPM
                else
                  set value of tempoSlider to minBPM
                end if
              end repeat
            end repeat
          end tell
        end tell
      end setExactBPM

      setExactBPM(%d)
    ]], math.floor(targetBpm + 0.5))

    logicBpmTask = hs.task.new("/usr/bin/osascript", function(exitCode, stdOut, stdErr)
      isSyncingLogicBpm = false
      logicBpmTask = nil
    end, { "-e", script })
    logicBpmTask:start()
  end)
end

local function stepLogicBpm(delta)
  setLogicBpmTarget(state.arpBpm)
end

local function syncLogicBpm()
  if state.bpmInputMode or not state.logicSyncEnabled or isSyncingLogicBpm or logicBpmDebounceTimer then return end
  isSyncingLogicBpm = true

  local script = [[
    var bpm = null;
    try {
      var se = Application('System Events');
      var logic = se.processes['Logic Pro'];
      if (logic && logic.exists()) {
        var win = logic.windows[0];
        if (win && win.exists()) {
          var grp = win.groups[0];
          if (grp && grp.exists()) {
            var ctrlBar = grp.uiElements[0];
            if (ctrlBar && ctrlBar.exists()) {
              var elems = ctrlBar.uiElements();
              for (var i = 0; i < elems.length; i++) {
                if (elems[i].description() === 'Tempo') {
                  bpm = parseFloat(elems[i].value());
                  break;
                }
              }
            }
          }
        }
      }
    } catch(e) {}
    bpm;
  ]]

  local task = hs.task.new("/usr/bin/osascript", function(exitCode, stdOut, stdErr)
    isSyncingLogicBpm = false
    if exitCode == 0 and stdOut then
      local val = tonumber(stdOut:match("^%s*(.-)%s*$"))
      if val and val >= 20 and val <= 300 and math.abs(state.arpBpm - val) > 0.01 and not logicBpmDebounceTimer then
        state.arpBpm = val
        applyBpmChange()
        updateHud()
      end
    end
  end, { "-l", "JavaScript", "-e", script })
  task:start()
end

local function toggleLogicSync()
  state.logicSyncEnabled = not state.logicSyncEnabled
  if state.logicSyncEnabled then
    syncLogicBpm()
  end
  local spot = {
    title = "LOGIC PRO SYNC",
    value = state.logicSyncEnabled and "SYNC: ON" or "SYNC: OFF",
    subtext = state.logicSyncEnabled and ("Synced to Logic (" .. formatBpm(state.arpBpm) .. " BPM)") or "Manual BPM Mode",
    targetId = "bpm-val",
    color = "#d4a359"
  }
  updateHud(spot)
end

local function initLogicSync()
  if not _G.activeWatchers.logicSyncTimer then
    _G.activeWatchers.logicSyncTimer = hs.timer.doEvery(1.0, syncLogicBpm)
  end
  syncLogicBpm()
end

initLogicSync()

return {
  setHudModule = setHudModule,
  stopArpTimer = stopArpTimer,
  getArpIntervalSeconds = getArpIntervalSeconds,
  startArpTimer = startArpTimer,
  arpAddNote = arpAddNote,
  arpRemoveNote = arpRemoveNote,
  formatBpm = formatBpm,
  applyBpmChange = applyBpmChange,
  applyGatePercentChange = applyGatePercentChange,
  updateLatchedArpNotes = updateLatchedArpNotes,
  updateLatchedArpChordNotes = updateLatchedArpChordNotes,
  getArpRowTargetSubtext = getArpRowTargetSubtext,
  toggleArpPower = toggleArpPower,
  toggleArp = toggleArp,
  handleBpmInput = handleBpmInput,
  toggleLogicSync = toggleLogicSync,
  syncLogicBpm = syncLogicBpm,
  stepLogicBpm = stepLogicBpm,
  setLogicBpmTarget = setLogicBpmTarget
}

