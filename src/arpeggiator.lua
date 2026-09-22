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

local function newArpEngine()
  return {
    heldNotes = {},
    targetHeldNotes = {},
    keysCurrentlyHeld = {},
    stepIndex = 1,
    stepDirection = 1,
    pos = 0,
    currentPitch = nil,
    beatPosition = 0,
    activeGateTimers = {},
    gateGeneration = 0,
    latchClearedForNewChord = false,
  }
end

state.arpEngineTop = newArpEngine()
state.arpEngineBottom = newArpEngine()
state.arpEngineLinked = newArpEngine()

local function setHudModule(m)
  hudModule = m
end

local function updateHud(spotlightInfo, activeArpPitch)
  if hudModule and hudModule.updateWebviewHud then
    hudModule.updateWebviewHud(spotlightInfo, activeArpPitch)
  end
end

local function stopEngineState(eng)
  eng.beatPosition = 0
  if eng.activeGateTimers then
    for pitchInfo, entry in pairs(eng.activeGateTimers) do
      if entry and entry.timer then entry.timer:stop() end
      local pitch = type(pitchInfo) == "table" and pitchInfo.pitch or pitchInfo
      local ch = entry and entry.channel or 0
      midi.sendMidiNote("noteOff", pitch, 0, ch)
    end
    eng.activeGateTimers = {}
  end
  if eng.currentPitch then
    local p = type(eng.currentPitch) == "table" and eng.currentPitch.pitch or eng.currentPitch
    local c = type(eng.currentPitch) == "table" and eng.currentPitch.channel or 0
    midi.sendMidiNote("noteOff", p, 0, c)
    eng.currentPitch = nil
  end
  eng.stepIndex = 1
  eng.stepDirection = 1
  eng.pos = 0
end

local function stopArpTimer()
  stopEngineState(state.arpEngineTop)
  stopEngineState(state.arpEngineBottom)
  stopEngineState(state.arpEngineLinked)
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

local function arpTickEngine(eng, isTopRow)
  local rateFactor = ARP_RATES[state.arpRateIdx] and ARP_RATES[state.arpRateIdx].factor or 0.5
  local prevBeat = math.floor(eng.beatPosition or 0)
  local prevBar = math.floor((eng.beatPosition or 0) / 4)
  eng.beatPosition = (eng.beatPosition or 0) + rateFactor
  local currentBeat = math.floor(eng.beatPosition)
  local currentBar = math.floor(eng.beatPosition / 4)
  local doSync = false
  if state.arpQuantizeMode == "Beat" and currentBeat > prevBeat then doSync = true
  elseif state.arpQuantizeMode == "Bar" and currentBar > prevBar then doSync = true end
  if doSync then
    eng.heldNotes = {}
    if eng.targetHeldNotes then
      for k,v in pairs(eng.targetHeldNotes) do eng.heldNotes[k] = v end
    end
    local otherEng = (eng == state.arpEngineTop) and state.arpEngineBottom or state.arpEngineTop
      if countTableKeys(eng.heldNotes) == 0 and countTableKeys(otherEng.heldNotes) == 0 then
      stopEngineState(eng)
      if countTableKeys(state.arpEngineTop.heldNotes) == 0 and countTableKeys(state.arpEngineBottom.heldNotes) == 0 then
        if state.arpTimer then state.arpTimer:stop(); state.arpTimer = nil end
      end
      updateHud()
      return
    end
  end
  local pitchList = {}
  for code, pitch in pairs(eng.heldNotes) do
    if pitch then table.insert(pitchList, pitch) end
  end
  table.sort(pitchList)
  if #pitchList == 0 then
    if eng.activeGateTimers then
      for pitch, entry in pairs(eng.activeGateTimers) do
        if entry and entry.timer then entry.timer:stop() end
        local ch = entry and entry.channel or 0
        midi.sendMidiNote("noteOff", pitch, 0, ch)
      end
      eng.activeGateTimers = {}
    end
    if eng.currentPitch then
      local p = type(eng.currentPitch) == "table" and eng.currentPitch.pitch or eng.currentPitch
      local c = type(eng.currentPitch) == "table" and eng.currentPitch.channel or 0
      midi.sendMidiNote("noteOff", p, 0, c)
      eng.currentPitch = nil
      updateHud()
    end
    return
  end
  if state.arpDirectionIdx == 1 then
    eng.stepIndex = (eng.pos % #pitchList) + 1
  elseif state.arpDirectionIdx == 2 then
    local pos = (eng.pos % #pitchList) + 1
    eng.stepIndex = #pitchList - pos + 1
  elseif state.arpDirectionIdx == 3 then
    if eng.stepIndex > #pitchList then
      eng.stepIndex = math.max(1, #pitchList - 1); eng.stepDirection = -1
    elseif eng.stepIndex < 1 then
      eng.stepIndex = math.min(#pitchList, 2); eng.stepDirection = 1
    end
  elseif state.arpDirectionIdx == 4 then
    if eng.stepIndex > #pitchList or eng.stepIndex < 1 then
      eng.stepIndex = math.max(1, #pitchList - 1); eng.stepDirection = -1
    end
  elseif state.arpDirectionIdx == 5 then
    local pos = (eng.pos % #pitchList) + 1
    local idx
    if pos % 2 == 1 then idx = math.floor(pos / 2) + 1
    else idx = #pitchList - math.floor(pos / 2) + 1 end
    eng.stepIndex = math.max(1, math.min(#pitchList, idx))
  elseif state.arpDirectionIdx == 6 then
    local pos = (eng.pos % #pitchList) + 1
    local mid = math.floor((#pitchList + 1) / 2)
    local idx
    if pos == 1 then idx = mid
    elseif pos % 2 == 0 then idx = mid + math.floor(pos / 2)
    else idx = mid - math.floor(pos / 2) end
    if idx < 1 or idx > #pitchList then idx = ((pos - 1) % #pitchList) + 1 end
    eng.stepIndex = idx
  elseif state.arpDirectionIdx == 7 then
    eng.stepIndex = math.random(1, #pitchList)
  end
  eng.stepIndex = math.max(1, math.min(#pitchList, eng.stepIndex or 1))
  local nextPitch = pitchList[eng.stepIndex]
  if state.arpDirectionIdx == 3 then
    if #pitchList == 1 then eng.stepIndex = 1; eng.stepDirection = 1
    else
      eng.stepIndex = eng.stepIndex + eng.stepDirection
      if eng.stepIndex > #pitchList then eng.stepIndex = math.max(1, #pitchList - 1); eng.stepDirection = -1
      elseif eng.stepIndex < 1 then eng.stepIndex = math.min(#pitchList, 2); eng.stepDirection = 1 end
    end
  elseif state.arpDirectionIdx == 4 then
    if #pitchList == 1 then eng.stepIndex = 1; eng.stepDirection = -1
    else
      eng.stepIndex = eng.stepIndex + eng.stepDirection
      if eng.stepIndex < 1 then eng.stepIndex = math.min(#pitchList, 2); eng.stepDirection = 1
      elseif eng.stepIndex > #pitchList then eng.stepIndex = math.max(1, #pitchList - 1); eng.stepDirection = -1 end
    end
  elseif state.arpDirectionIdx == 1 or state.arpDirectionIdx == 2 or state.arpDirectionIdx == 5 or state.arpDirectionIdx == 6 then
    eng.pos = (eng.pos or 0) + 1
  end
  local success, err = pcall(function()
    local gateRatio = (state.arpGatePercent or 80.0) / 100.0
    local vel = transposer.getEffectiveRowVelocity(isTopRow)
    local rowCh = isTopRow and (state.topRowChannel or 0) or (state.bottomRowChannel or 0)
    local ch = (state.arpChannel ~= nil) and state.arpChannel or rowCh
    if gateRatio <= 1.0 and eng.currentPitch then
      local oldP = type(eng.currentPitch) == "table" and eng.currentPitch.pitch or eng.currentPitch
      local oldCh = type(eng.currentPitch) == "table" and eng.currentPitch.channel or 0
      if eng.activeGateTimers and eng.activeGateTimers[oldP] then
        if eng.activeGateTimers[oldP].timer then eng.activeGateTimers[oldP].timer:stop() end
        eng.activeGateTimers[oldP] = nil
      end
      midi.sendMidiNote("noteOff", oldP, 0, oldCh)
      eng.currentPitch = nil
    end
    local isAudible = true
    if state.tracks then
      local trkId = 4
      for id, t in pairs(state.tracks) do
        if t.channel == ch then
          trkId = id
          break
        end
      end
      local trk = state.tracks[trkId]
      if trk and trk.muted then isAudible = false end
      local anySolo = false
      for _, t in pairs(state.tracks) do
        if t.soloed then anySolo = true; break end
      end
      if anySolo and trk and not trk.soloed then isAudible = false end
    end

    if isAudible then
      midi.sendMidiNote("noteOn", nextPitch, vel, ch)
      eng.currentPitch = { pitch = nextPitch, channel = ch }

      local gateDuration = getArpIntervalSeconds() * gateRatio
      local pitchToRelease = nextPitch
      local releaseCh = ch
      local timer = hs.timer.doAfter(gateDuration, function()
        local ok, e = pcall(function()
          midi.sendMidiNote("noteOff", pitchToRelease, 0, releaseCh)
          if eng.currentPitch and (type(eng.currentPitch) == "table" and eng.currentPitch.pitch or eng.currentPitch) == pitchToRelease then
            eng.currentPitch = nil
          end
          if eng.activeGateTimers then eng.activeGateTimers[pitchToRelease] = nil end
        end)
        if not ok then print("[Arp Gate Error] " .. tostring(e)) end
      end)
      eng.activeGateTimers = eng.activeGateTimers or {}
      if eng.activeGateTimers[pitchToRelease] then
        if eng.activeGateTimers[pitchToRelease].timer then eng.activeGateTimers[pitchToRelease].timer:stop() end
        eng.activeGateTimers[pitchToRelease] = nil
      end
      eng.activeGateTimers[pitchToRelease] = { timer = timer, channel = releaseCh }
    end
  end)
  if not success then print("[Arp Engine Error] " .. tostring(err)) end
  return nextPitch
end

local function isTrackAudible(trkId)
  if not state.tracks then return true end
  local trk = state.tracks[trkId]
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

local function silenceTrack(trkId)
  local trk = state.tracks and state.tracks[trkId]
  if not trk then return end
  if trk.activeGateTimers then
    for pitch, entry in pairs(trk.activeGateTimers) do
      if entry and entry.timer then entry.timer:stop() end
      local ch = entry and entry.channel or trk.channel or 0
      midi.sendMidiNote("noteOff", pitch, 0, ch)
    end
    trk.activeGateTimers = {}
  end
  if trk.currentPitch then
    local p = type(trk.currentPitch) == "table" and trk.currentPitch.pitch or trk.currentPitch
    local c = type(trk.currentPitch) == "table" and trk.currentPitch.channel or trk.channel or 0
    midi.sendMidiNote("noteOff", p, 0, c)
    trk.currentPitch = nil
  end
  trk.arpIsPlaying = false
  trk.activeNotesCount = 0
  if hudModule and hudModule.fastUpdateArp then
    hudModule.fastUpdateArp()
  end
end

local function arpTickTrack(trk)
  if not trk then return nil end
  local rateFactor = ARP_RATES[trk.arpRateIdx or state.arpRateIdx] and ARP_RATES[trk.arpRateIdx or state.arpRateIdx].factor or 0.5
  local prevBeat = math.floor(trk.beatPosition or 0)
  local prevBar = math.floor((trk.beatPosition or 0) / 4)
  trk.beatPosition = (trk.beatPosition or 0) + rateFactor
  local currentBeat = math.floor(trk.beatPosition)
  local currentBar = math.floor(trk.beatPosition / 4)
  local doSync = false
  if state.arpQuantizeMode == "Beat" and currentBeat > prevBeat then doSync = true
  elseif state.arpQuantizeMode == "Bar" and currentBar > prevBar then doSync = true end
  if doSync then
    trk.heldNotes = {}
    if trk.targetHeldNotes then
      for k,v in pairs(trk.targetHeldNotes) do trk.heldNotes[k] = v end
    end
    if countTableKeys(trk.heldNotes) == 0 and not trk.locked then
      stopEngineState(trk)
      return nil
    end
  end

  local pitchList = {}
  for code, pitch in pairs(trk.heldNotes or {}) do
    if pitch then table.insert(pitchList, pitch) end
  end
  table.sort(pitchList)

  if #pitchList == 0 then
    if trk.activeGateTimers then
      for pitch, entry in pairs(trk.activeGateTimers) do
        if entry and entry.timer then entry.timer:stop() end
        local ch = entry and entry.channel or trk.channel or 0
        midi.sendMidiNote("noteOff", pitch, 0, ch)
      end
      trk.activeGateTimers = {}
    end
    if trk.currentPitch then
      local p = type(trk.currentPitch) == "table" and trk.currentPitch.pitch or trk.currentPitch
      local c = type(trk.currentPitch) == "table" and trk.currentPitch.channel or trk.channel or 0
      midi.sendMidiNote("noteOff", p, 0, c)
      trk.currentPitch = nil
    end
    trk.arpIsPlaying = false
    return nil
  end

  local dirIdx = trk.arpDirectionIdx or state.arpDirectionIdx or 1
  if dirIdx == 1 then
    trk.stepIndex = (trk.pos % #pitchList) + 1
  elseif dirIdx == 2 then
    local pos = (trk.pos % #pitchList) + 1
    trk.stepIndex = #pitchList - pos + 1
  elseif dirIdx == 3 then
    if trk.stepIndex > #pitchList then
      trk.stepIndex = math.max(1, #pitchList - 1); trk.stepDirection = -1
    elseif trk.stepIndex < 1 then
      trk.stepIndex = math.min(#pitchList, 2); trk.stepDirection = 1
    end
  elseif dirIdx == 4 then
    if trk.stepIndex > #pitchList or trk.stepIndex < 1 then
      trk.stepIndex = math.max(1, #pitchList - 1); trk.stepDirection = -1
    end
  elseif dirIdx == 5 then
    local pos = (trk.pos % #pitchList) + 1
    local idx
    if pos % 2 == 1 then idx = math.floor(pos / 2) + 1
    else idx = #pitchList - math.floor(pos / 2) + 1 end
    trk.stepIndex = math.max(1, math.min(#pitchList, idx))
  elseif dirIdx == 6 then
    local pos = (trk.pos % #pitchList) + 1
    local mid = math.floor((#pitchList + 1) / 2)
    local idx
    if pos == 1 then idx = mid
    elseif pos % 2 == 0 then idx = mid + math.floor(pos / 2)
    else idx = mid - math.floor(pos / 2) end
    if idx < 1 or idx > #pitchList then idx = ((pos - 1) % #pitchList) + 1 end
    trk.stepIndex = idx
  elseif dirIdx == 7 then
    trk.stepIndex = math.random(1, #pitchList)
  end
  trk.stepIndex = math.max(1, math.min(#pitchList, trk.stepIndex or 1))
  local nextPitch = pitchList[trk.stepIndex]

  if dirIdx == 3 then
    if #pitchList == 1 then trk.stepIndex = 1; trk.stepDirection = 1
    else
      trk.stepIndex = trk.stepIndex + trk.stepDirection
      if trk.stepIndex > #pitchList then trk.stepIndex = math.max(1, #pitchList - 1); trk.stepDirection = -1
      elseif trk.stepIndex < 1 then trk.stepIndex = math.min(#pitchList, 2); trk.stepDirection = 1 end
    end
  elseif dirIdx == 4 then
    if #pitchList == 1 then trk.stepIndex = 1; trk.stepDirection = -1
    else
      trk.stepIndex = trk.stepIndex + trk.stepDirection
      if trk.stepIndex < 1 then trk.stepIndex = math.min(#pitchList, 2); trk.stepDirection = 1
      elseif trk.stepIndex > #pitchList then trk.stepIndex = math.max(1, #pitchList - 1); trk.stepDirection = -1 end
    end
  elseif dirIdx == 1 or dirIdx == 2 or dirIdx == 5 or dirIdx == 6 then
    trk.pos = (trk.pos or 0) + 1
  end

  local success, err = pcall(function()
    local gateRatio = (trk.arpGatePercent or state.arpGatePercent or 80.0) / 100.0
    local vel = math.floor(math.min(127, (trk.volume or 100) * 1.0))
    local ch = trk.channel or 0

    if gateRatio <= 1.0 and trk.currentPitch then
      local oldP = type(trk.currentPitch) == "table" and trk.currentPitch.pitch or trk.currentPitch
      local oldCh = type(trk.currentPitch) == "table" and trk.currentPitch.channel or ch
      if trk.activeGateTimers and trk.activeGateTimers[oldP] then
        if trk.activeGateTimers[oldP].timer then trk.activeGateTimers[oldP].timer:stop() end
        trk.activeGateTimers[oldP] = nil
      end
      midi.sendMidiNote("noteOff", oldP, 0, oldCh)
      trk.currentPitch = nil
    end

    local isAudible = isTrackAudible(trk.id)
    if isAudible then
      midi.sendMidiNote("noteOn", nextPitch, vel, ch)
      trk.currentPitch = { pitch = nextPitch, channel = ch }
      trk.arpIsPlaying = true

      local trackRateFactor = ARP_RATES[trk.arpRateIdx or 5] and ARP_RATES[trk.arpRateIdx or 5].factor or 0.25
      local trackStepSec = (60.0 / (state.arpBpm or 120.0)) * trackRateFactor
      local gateDuration = trackStepSec * gateRatio
      local pitchToRelease = nextPitch
      local releaseCh = ch
      trk.activeGateTimers = trk.activeGateTimers or {}
      local priorGate = trk.activeGateTimers[pitchToRelease]
      if priorGate and priorGate.timer then priorGate.timer:stop() end
      local gateGeneration = (trk.gateGeneration or 0) + 1
      trk.gateGeneration = gateGeneration
      local timer = hs.timer.doAfter(gateDuration, function()
        local ok, e = pcall(function()
          local activeGate = trk.activeGateTimers and trk.activeGateTimers[pitchToRelease]
          if activeGate and activeGate.generation == gateGeneration then
            midi.sendMidiNote("noteOff", pitchToRelease, 0, releaseCh)
            if trk.currentPitch and (type(trk.currentPitch) == "table" and trk.currentPitch.pitch or trk.currentPitch) == pitchToRelease then
              trk.currentPitch = nil
            end
            trk.arpIsPlaying = false
            trk.activeGateTimers[pitchToRelease] = nil
          end
          if hudModule and hudModule.fastUpdateArp then hudModule.fastUpdateArp() end
        end)
        if not ok then print("[Arp Gate Error] " .. tostring(e)) end
      end)
      trk.activeGateTimers[pitchToRelease] = { timer = timer, channel = releaseCh, generation = gateGeneration }
      if hudModule and hudModule.fastUpdateArp then hudModule.fastUpdateArp() end
    else
      trk.arpIsPlaying = false
    end
  end)
  if not success then print("[Arp Track Error] " .. tostring(err)) end
  return nextPitch
end

local function stopTrackArp(trk)
  if not trk then return end
  if trk.timer then
    trk.timer:stop()
    trk.timer = nil
  end
  silenceTrack(trk.id)
end

local function startTrackArp(trk, preserveState)
  if not trk then return end
  if trk.timer then
    trk.timer:stop()
    trk.timer = nil
  end
  local rateFactor = ARP_RATES[trk.arpRateIdx or 5] and ARP_RATES[trk.arpRateIdx or 5].factor or 0.25
  local intervalSeconds = (60.0 / (state.arpBpm or 120.0)) * rateFactor
  if not preserveState then
    if trk.arpDirectionIdx == 4 then
      trk.stepIndex = 999 
      trk.stepDirection = -1
    else
      trk.stepIndex = 1
      trk.stepDirection = 1
    end
    trk.pos = 0
    arpTickTrack(trk)
  end
  trk.timer = hs.timer.doEvery(intervalSeconds, function()
    arpTickTrack(trk)
  end)
end

local function isAnyTrackArpActive()
  if not state.tracks then return false end
  for _, trk in pairs(state.tracks) do
    if trk.arpEnabled and (countTableKeys(trk.heldNotes) > 0 or trk.locked) then
      return true
    end
  end
  return false
end

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

local function arpTick()
  local start = hs.timer.absoluteTime()
  local activeP = nil

  if state.tracks then
    for i = 1, 4 do
      local trk = state.tracks[i]
      if trk and trk.arpEnabled and (countTableKeys(trk.heldNotes) > 0 or trk.locked) then
        local p = arpTickTrack(trk)
        if i == (state.activeTrack or 1) then
          activeP = p
        end
      end
    end
  else
    if not state.arpLinked then
      local p1 = arpTickEngine(state.arpEngineTop, true)
      local p2 = arpTickEngine(state.arpEngineBottom, false)
      activeP = p1 or p2
    else
      activeP = arpTickEngine(state.arpEngineTop, false)
    end
  end

  if hudModule and hudModule.fastUpdateArp then
    hudModule.fastUpdateArp()
  else
    updateHud(nil, activeP)
  end
  
  local durationMs = (hs.timer.absoluteTime() - start) / 1000000
  if durationMs > 15 then print(string.format("[Arp Perf Warning] arpTick took %.2f ms", durationMs)) end
end

local function sendHudPayload(payload)
  local jsonStr = hs.json.encode(payload)
  safeEvaluateJS("renderHud(" .. jsonStr .. ")")
end

local function startArpTimer(preserveState)
  if state.arpTimer then return end
  local intervalSeconds = getArpIntervalSeconds()
  if not preserveState then
    if state.arpDirectionIdx == 4 then
      state.arpStepIndex = 999 
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

local function arpAddNote(code, pitch, trackIdx)
  local rawCode = type(code) == "string" and tonumber(code:match("^(%d+)")) or tonumber(code)
  local noteKey = rawCode and config.getNoteKey(rawCode)
  local isTop = noteKey and noteKey.isTop or false
  local defaultTrk = isTop and (state.topRowTrack or 3) or (state.bottomRowTrack or 1)
  local trkId = trackIdx or defaultTrk
  local trk = state.tracks and state.tracks[trkId]
  if trk then
    trk.keysCurrentlyHeld = trk.keysCurrentlyHeld or {}
    local numPhysicalHeld = countTableKeys(trk.keysCurrentlyHeld)
    local isLatched = (trk.arpLatchActive == true) or (trk.sustainMode and trk.sustainMode ~= "off")
    if isLatched then
      if numPhysicalHeld == 0 or not trk.latchClearedForNewChord then
        trk.targetHeldNotes = {}
        trk.latchClearedForNewChord = true
        if trk.currentPitch and (not state.arpQuantizeMode or state.arpQuantizeMode == "None") then
          local p = type(trk.currentPitch) == "table" and trk.currentPitch.pitch or trk.currentPitch
          local c = type(trk.currentPitch) == "table" and trk.currentPitch.channel or trk.channel or 0
          midi.sendMidiNote("noteOff", p, 0, c)
          trk.currentPitch = nil
        end
      end
    end
    trk.keysCurrentlyHeld[code] = true
    trk.targetHeldNotes = trk.targetHeldNotes or {}
    trk.targetHeldNotes[code] = pitch
    if not trk.timer or state.arpQuantizeMode == "None" or not state.arpQuantizeMode then
      trk.heldNotes = {}
      for k,v in pairs(trk.targetHeldNotes) do trk.heldNotes[k] = v end
      if not trk.timer and (trk.arpEnabled or state.arpEnabled) then
        startTrackArp(trk)
      end
    end
    return
  end

  local eng = state.arpLinked and state.arpEngineLinked or (isTop and state.arpEngineTop or state.arpEngineBottom)
  local numPhysicalHeld = countTableKeys(eng.keysCurrentlyHeld)
  if state.arpLatchActive then
    if numPhysicalHeld == 0 or not eng.latchClearedForNewChord then
      eng.targetHeldNotes = {}
      eng.latchClearedForNewChord = true
      if eng.currentPitch and (not state.arpQuantizeMode or state.arpQuantizeMode == "None") then
        local p = type(eng.currentPitch) == "table" and eng.currentPitch.pitch or eng.currentPitch
        local c = type(eng.currentPitch) == "table" and eng.currentPitch.channel or 0
        midi.sendMidiNote("noteOff", p, 0, c)
        eng.currentPitch = nil
      end
    end
  end
  eng.keysCurrentlyHeld[code] = true
  eng.targetHeldNotes = eng.targetHeldNotes or {}
  eng.targetHeldNotes[code] = pitch
  if not state.arpTimer or state.arpQuantizeMode == "None" or not state.arpQuantizeMode then
    eng.heldNotes = {}
    for k,v in pairs(eng.targetHeldNotes) do eng.heldNotes[k] = v end
    if not state.arpTimer then
      startArpTimer()
    end
  end

  if state.arpLinked then
    state.arpHeldNotes = state.arpEngineLinked.heldNotes
    state.arpTargetHeldNotes = state.arpEngineLinked.targetHeldNotes
    state.arpKeysCurrentlyHeld = state.arpEngineLinked.keysCurrentlyHeld
  end
end

local function arpRemoveNote(code, trackIdx)
  local rawCode = type(code) == "string" and tonumber(code:match("^(%d+)")) or tonumber(code)
  local noteKey = rawCode and config.getNoteKey(rawCode)
  local isTop = noteKey and noteKey.isTop or false
  local defaultTrk = isTop and (state.topRowTrack or 3) or (state.bottomRowTrack or 1)
  local trkId = trackIdx or defaultTrk
  local trk = state.tracks and state.tracks[trkId]
  if trk then
    if trk.keysCurrentlyHeld then
      trk.keysCurrentlyHeld[code] = nil
    end
    local numPhysicalHeld = countTableKeys(trk.keysCurrentlyHeld)
    local isLatched = (trk.arpLatchActive == true) or (trk.sustainMode and trk.sustainMode ~= "off")
    if isLatched then
      if numPhysicalHeld == 0 then
        trk.latchClearedForNewChord = false
      end
    else
      if trk.targetHeldNotes then
        trk.targetHeldNotes[code] = nil
      end
    end
    if not trk.timer or state.arpQuantizeMode == "None" or not state.arpQuantizeMode then
      trk.heldNotes = {}
      if trk.targetHeldNotes then
        for k,v in pairs(trk.targetHeldNotes) do trk.heldNotes[k] = v end
      end
      if countTableKeys(trk.heldNotes) == 0 and not trk.locked then
        stopTrackArp(trk)
        updateHud()
      end
    end
    return
  end

  local rawCode = type(code) == "string" and tonumber(code:match("^(%d+)")) or tonumber(code)
  local noteKey = rawCode and config.getNoteKey(rawCode)
  local isTop = noteKey and noteKey.isTop or false
  local eng = state.arpLinked and state.arpEngineLinked or (isTop and state.arpEngineTop or state.arpEngineBottom)
  eng.keysCurrentlyHeld[code] = nil
  local numPhysicalHeld = countTableKeys(eng.keysCurrentlyHeld)
  if state.arpLatchActive or state.sustainActive then
    if numPhysicalHeld == 0 then
      eng.latchClearedForNewChord = false
    end
  else
    if eng.targetHeldNotes then
      eng.targetHeldNotes[code] = nil
    end
  end
  if not state.arpTimer or state.arpQuantizeMode == "None" or not state.arpQuantizeMode then
    eng.heldNotes = {}
    if eng.targetHeldNotes then
      for k,v in pairs(eng.targetHeldNotes) do eng.heldNotes[k] = v end
    end
    if state.arpLinked then
      if countTableKeys(eng.heldNotes) == 0 then
        stopEngineState(eng)
        stopArpTimer()
        updateHud()
      end
    else
      local otherEng = (eng == state.arpEngineTop) and state.arpEngineBottom or state.arpEngineTop
      if countTableKeys(eng.heldNotes) == 0 and countTableKeys(otherEng.heldNotes) == 0 then
        stopEngineState(eng)
        stopArpTimer()
        updateHud()
      end
    end
  end

  if state.arpLinked then
    state.arpHeldNotes = state.arpEngineLinked.heldNotes
    state.arpTargetHeldNotes = state.arpEngineLinked.targetHeldNotes
    state.arpKeysCurrentlyHeld = state.arpEngineLinked.keysCurrentlyHeld
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
  if state.tracks then
    for i = 1, 4 do
      local trk = state.tracks[i]
      if trk and trk.timer then
        trk.timer:stop()
        local rateFactor = ARP_RATES[trk.arpRateIdx or 5] and ARP_RATES[trk.arpRateIdx or 5].factor or 0.25
        local newInterval = (60.0 / (state.arpBpm or 120.0)) * rateFactor
        trk.timer = hs.timer.doEvery(newInterval, function() arpTickTrack(trk) end)
      end
    end
  end
  if state.arpTimer then
    state.arpTimer:stop()
    local newInterval = getArpIntervalSeconds()
    state.arpTimer = hs.timer.doEvery(newInterval, arpTick)
  end
end

-- Tracks own their timing.  The header and rate keys control the focused track
-- so a rate change immediately replaces that track's running clock interval.
local function setTrackArpRate(rateIdx, targetTrackIdx)
  local normalizedRateIdx = math.max(1, math.min(#ARP_RATES, tonumber(rateIdx) or state.arpRateIdx or 5))
  state.arpRateIdx = normalizedRateIdx

  local trackId = targetTrackIdx or state.activeTrack or 1
  local trk = state.tracks and state.tracks[trackId]
  if not trk then
    if state.arpTimer then applyBpmChange() end
    return nil, normalizedRateIdx
  end

  trk.arpRateIdx = normalizedRateIdx
  if trk.id then
    hs.settings.set("qwertyMidi_track" .. trk.id .. "ArpRateIdx", normalizedRateIdx)
  end
  if trk.timer then
    trk.timer:stop()
    local rateFactor = ARP_RATES[normalizedRateIdx] and ARP_RATES[normalizedRateIdx].factor or 0.25
    local intervalSeconds = (60.0 / (state.arpBpm or 120.0)) * rateFactor
    trk.timer = hs.timer.doEvery(intervalSeconds, function()
      arpTickTrack(trk)
    end)
  end

  return trk, normalizedRateIdx
end

local function applyGatePercentChange()
  if state.arpTimer then
    local gateRatio = (state.arpGatePercent or 80.0) / 100.0
    if not state.arpLinked then
      if gateRatio <= 1.0 then
        for _, eng in ipairs({state.arpEngineTop, state.arpEngineBottom}) do
          if eng.activeGateTimers then
            for pitch, entry in pairs(eng.activeGateTimers) do
              local curPitchNum = type(eng.currentPitch) == "table" and eng.currentPitch.pitch or eng.currentPitch
              if pitch ~= curPitchNum then
                if entry and entry.timer then entry.timer:stop() end
                local ch = entry and entry.channel or 0
                midi.sendMidiNote("noteOff", pitch, 0, ch)
                eng.activeGateTimers[pitch] = nil
              end
            end
          end
        end
      end
      return
    end
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

local function rebuildNoteTable(noteTable)
  local baseCodeCounts = {}
  local uniqueBaseCodes = {}
  local keysToRemove = {}
  for code, _ in pairs(noteTable) do
    local rawCode = type(code) == "string" and tonumber(code:match("^(%d+)")) or tonumber(code)
    if rawCode then
      baseCodeCounts[rawCode] = (baseCodeCounts[rawCode] or 0) + 1
      uniqueBaseCodes[rawCode] = true
      table.insert(keysToRemove, code)
    end
  end

  for _, code in ipairs(keysToRemove) do
    noteTable[code] = nil
  end

  for rawCode, _ in pairs(uniqueBaseCodes) do
    local noteKey = config.getNoteKey(rawCode)
    if noteKey then
      local wasChord = (baseCodeCounts[rawCode] or 1) > 1
      local isChord = state.quoteHeld or state.chordModeActive or wasChord
      if isChord then
        local newPitches = transposer.getChordPitches(noteKey.baseNote, noteKey.isTop, true)
        for _, p in ipairs(newPitches) do
          noteTable[tostring(rawCode) .. "_" .. tostring(p)] = p
        end
      else
        local newPitch = transposer.getTransposedPitch(noteKey.baseNote, noteKey.isTop)
        noteTable[tostring(rawCode) .. "_" .. tostring(newPitch)] = newPitch
      end
    end
  end
end

local function updateLatchedArpNotes()
  if not state.arpEnabled then return end

  if not state.arpLinked then
    for _, eng in ipairs({state.arpEngineTop, state.arpEngineBottom}) do
      if next(eng.heldNotes) ~= nil then
        rebuildNoteTable(eng.heldNotes)
      end
      if eng.targetHeldNotes and next(eng.targetHeldNotes) ~= nil then
        rebuildNoteTable(eng.targetHeldNotes)
      end
    end
    return
  end

  if state.tracks then
    for _, trk in pairs(state.tracks) do
      if trk.heldNotes and next(trk.heldNotes) ~= nil then
        rebuildNoteTable(trk.heldNotes)
      end
      if trk.targetHeldNotes and next(trk.targetHeldNotes) ~= nil then
        rebuildNoteTable(trk.targetHeldNotes)
      end
    end
  end

  if next(state.arpHeldNotes) ~= nil then
    rebuildNoteTable(state.arpHeldNotes)
  end
  if state.arpTargetHeldNotes and next(state.arpTargetHeldNotes) ~= nil then
    rebuildNoteTable(state.arpTargetHeldNotes)
  end
end

local function updateLatchedArpChordNotes()
  if state.tracks then
    for _, trk in pairs(state.tracks) do
      if trk.heldNotes and next(trk.heldNotes) ~= nil then
        local uniqueBaseCodes = {}
        local keysToRemove = {}
        for code, _ in pairs(trk.heldNotes) do
          local rawCode = type(code) == "string" and tonumber(code:match("^(%d+)")) or tonumber(code)
          if rawCode then
            uniqueBaseCodes[rawCode] = true
            table.insert(keysToRemove, code)
          end
        end
        for _, code in ipairs(keysToRemove) do trk.heldNotes[code] = nil end
        for rawCode, _ in pairs(uniqueBaseCodes) do
          local noteKey = config.getNoteKey(rawCode)
          if noteKey then
            local newPitches = transposer.getChordPitches(noteKey.baseNote, noteKey.isTop)
            for _, p in ipairs(newPitches) do
              trk.heldNotes[tostring(rawCode) .. "_" .. tostring(p)] = p
            end
          end
        end
      end
    end
  end

  if not state.arpEnabled or not state.arpLatchActive then return end

  if not state.arpLinked then
    for _, eng in ipairs({state.arpEngineTop, state.arpEngineBottom}) do
      if next(eng.heldNotes) ~= nil then
        local uniqueBaseCodes = {}
        local keysToRemove = {}
        for code, _ in pairs(eng.heldNotes) do
          local rawCode = type(code) == "string" and tonumber(code:match("^(%d+)")) or tonumber(code)
          if rawCode then
            uniqueBaseCodes[rawCode] = true
            table.insert(keysToRemove, code)
          end
        end
        for _, code in ipairs(keysToRemove) do eng.heldNotes[code] = nil end
        for rawCode, _ in pairs(uniqueBaseCodes) do
          local noteKey = config.getNoteKey(rawCode)
          if noteKey then
            local newPitches = transposer.getChordPitches(noteKey.baseNote, noteKey.isTop)
            for _, p in ipairs(newPitches) do
              eng.heldNotes[tostring(rawCode) .. "_" .. tostring(p)] = p
            end
          end
        end
      end
    end
    return
  end

  if next(state.arpHeldNotes) == nil then return end

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
      local newPitches = transposer.getChordPitches(noteKey.baseNote, noteKey.isTop)
      for _, p in ipairs(newPitches) do
        state.arpHeldNotes[tostring(rawCode) .. "_" .. tostring(p)] = p
      end
    end
  end
end

local function getArpRowTargetSubtext()
  if state.tracks then
    local trk = state.tracks[state.activeTrack or 1]
    return trk and ("Track " .. trk.id .. ": " .. trk.name) or "Active Track"
  end
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

local function toggleArpPower(targetTrackIdx)
  local trkId = targetTrackIdx or state.activeTrack or 1
  local trk = state.tracks and state.tracks[trkId]
  if trk then
    if not trk.arpEnabled then
      trk.arpEnabled = true
      trk.arpLatchActive = true
      trk.latchClearedForNewChord = false
    elseif trk.arpLatchActive then
      trk.arpLatchActive = false
      local newHeld = {}
      for code, pitch in pairs(trk.heldNotes or {}) do
        if trk.keysCurrentlyHeld[code] then
          newHeld[code] = pitch
        end
      end
      trk.heldNotes = newHeld
      trk.targetHeldNotes = {}
      for k, v in pairs(newHeld) do trk.targetHeldNotes[k] = v end
      if countTableKeys(trk.heldNotes) == 0 then
        stopTrackArp(trk)
      end
    else
      trk.arpEnabled = false
      trk.arpLatchActive = false
      stopTrackArp(trk)
      trk.heldNotes = {}
      trk.keysCurrentlyHeld = {}
    end

    state.arpEnabled = trk.arpEnabled
    state.arpLatchActive = trk.arpLatchActive

    local valStr = "ARP: OFF"
    local subStr = "Track " .. trkId .. " Arp Disabled"
    if trk.arpEnabled then
      if trk.arpLatchActive then
        valStr = "ARP: LATCH 🔒"
        subStr = "Track " .. trkId .. " (" .. trk.name .. ") LATCH 🔒 • " .. formatBpm(state.arpBpm) .. " BPM"
      else
        valStr = "ARP: ON"
        subStr = "Track " .. trkId .. " (" .. trk.name .. ") ON • " .. formatBpm(state.arpBpm) .. " BPM"
      end
    end

    local spot = {
      title = "TRACK " .. trkId .. " ARP",
      value = valStr,
      subtext = subStr,
      targetId = "key-0",
      color = trk.color or "#64d8f0"
    }
    updateHud(spot)
    config.saveSettings()
    return
  end

  if not state.arpEnabled then
    state.arpEnabled = true
    state.arpLatchActive = true
    state.arpLatchClearedForNewChord = false
  elseif state.arpLatchActive then
    state.arpLatchActive = false
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
    state.arpEngineTop = newArpEngine()
    state.arpEngineBottom = newArpEngine()
  end

  local valStr = "ARP: OFF"
  local subStr = "Arp Disabled"
  if state.arpEnabled then
    if not state.arpTopEnabled and not state.arpBottomEnabled then
      valStr = "ARP: ON (MUTED)"
      subStr = "⚠️ Top & Bottom rows are both disabled"
    elseif state.arpLatchActive then
      valStr = "ARP: LATCH 🔒"
      subStr = "LATCH 🔒 (" .. getArpRowTargetSubtext() .. ") • " .. formatBpm(state.arpBpm) .. " BPM"
    else
      valStr = "ARP: ON"
      subStr = "ON (" .. getArpRowTargetSubtext() .. ") • " .. formatBpm(state.arpBpm) .. " BPM"
    end
  end

  local spot = {
    title = "ARP POWER",
    value = valStr,
    subtext = subStr,
    targetId = "key-0",
    color = "#d4a359"
  }
  updateHud(spot)
  config.saveSettings()
end

local function toggleArpLatch(targetTrackIdx)
  local trkId = targetTrackIdx or state.activeTrack or 1
  local trk = state.tracks and state.tracks[trkId]
  local curLatch = (trk and trk.arpLatchActive) or (state.arpLatchActive == true)
  local targetLatch = not curLatch

  if trk then
    trk.arpLatchActive = targetLatch
    if targetLatch then
      trk.arpEnabled = true
      trk.latchClearedForNewChord = false
      -- If notes are currently physically held on the keyboard for this track, latch them now
      for code, info in pairs(state.pressedKeys) do
        if type(info) == "table" and not info.isControl and info.pitches then
          for _, p in ipairs(info.pitches) do
            local keyId = code .. "_" .. p
            trk.heldNotes[keyId] = p
            trk.targetHeldNotes[keyId] = p
            trk.keysCurrentlyHeld[keyId] = true
          end
        end
      end
      if countTableKeys(trk.heldNotes) > 0 then
        startTrackArp(trk)
      end
    else
      local newHeld = {}
      for code, pitch in pairs(trk.heldNotes or {}) do
        local rawCode = type(code) == "string" and tonumber(code:match("^(%d+)")) or tonumber(code)
        if trk.keysCurrentlyHeld[code] or (rawCode and state.pressedKeys[rawCode]) then
          newHeld[code] = pitch
        end
      end
      trk.heldNotes = newHeld
      trk.targetHeldNotes = {}
      for k, v in pairs(newHeld) do trk.targetHeldNotes[k] = v end
      if countTableKeys(trk.heldNotes) == 0 then
        stopTrackArp(trk)
      end
    end
  else
    state.arpLatchActive = targetLatch
    if targetLatch then
      state.arpEnabled = true
      state.arpLatchClearedForNewChord = false
    else
      local newHeld = {}
      for code, pitch in pairs(state.arpHeldNotes or {}) do
        if state.arpKeysCurrentlyHeld[code] or state.pressedKeys[code] then
          newHeld[code] = pitch
        end
      end
      state.arpHeldNotes = newHeld
      if countTableKeys(state.arpHeldNotes) == 0 then
        stopArpTimer()
      end
    end
  end

  state.arpLatchActive = targetLatch
  if targetLatch then
    state.arpEnabled = true
  end

  config.saveSettings()

  local spot = {
    title = "TRACK " .. trkId .. " LATCH",
    value = targetLatch and "LATCH 🔒 ON" or "LATCH OFF",
    subtext = "Track " .. trkId .. " (" .. (trk and trk.name or "Track") .. ") • Latch " .. (targetLatch and "Active 🔒 (held notes loop)" or "Disabled (momentary)"),
    targetId = "key-0",
    color = (trk and trk.color) or "#64d8f0"
  }
  updateHud(spot)
  return targetLatch
end

local function clearTrackArp(trackId)
  local trkId = trackId or state.activeTrack or 1
  local trk = state.tracks and state.tracks[trkId]
  if trk then
    stopEngineState(trk)
    trk.heldNotes = {}
    trk.targetHeldNotes = {}
    trk.keysCurrentlyHeld = {}
    trk.latchClearedForNewChord = false
    trk.arpEnabled = false
    trk.arpLatchActive = false
    trk.locked = false
    if not isAnyTrackArpActive() then
      stopArpTimer()
    end
    if trkId == state.activeTrack then
      state.arpEnabled = false
      state.arpLatchActive = false
    end
    updateHud()
  end
end

local function stopAllLoops()
  if state.tracks then
    for _, trk in pairs(state.tracks) do
      stopEngineState(trk)
      trk.heldNotes = {}
      trk.targetHeldNotes = {}
      trk.keysCurrentlyHeld = {}
      trk.arpEnabled = false
      trk.arpLatchActive = false
      trk.locked = false
    end
  end
  stopArpTimer()
  state.arpEnabled = false
  state.arpLatchActive = false
  updateHud()
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

  logicBpmDebounceTimer = hs.timer.doAfter(0.40, function()
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

local function clearRowEngine(isTop)
  local eng = isTop and state.arpEngineTop or state.arpEngineBottom
  stopEngineState(eng)
  eng.heldNotes = {}
  eng.targetHeldNotes = {}
  eng.keysCurrentlyHeld = {}
  eng.latchClearedForNewChord = false
  local otherEng = isTop and state.arpEngineBottom or state.arpEngineTop
  if countTableKeys(otherEng.heldNotes) == 0 then
    if state.arpTimer then
      state.arpTimer:stop()
      state.arpTimer = nil
    end
  end
end

local function setArpPowerImplicit(enabled)
  state.arpEnabled = enabled
  if not enabled then
    stopArpTimer()
    if state.arpCurrentPitch then
      local p = type(state.arpCurrentPitch) == "table" and state.arpCurrentPitch.pitch or state.arpCurrentPitch
      local c = type(state.arpCurrentPitch) == "table" and state.arpCurrentPitch.channel or 0
      midi.sendMidiNote("noteOff", p, 0, c)
      state.arpCurrentPitch = nil
    end
    stopEngineState(state.arpEngineTop)
    stopEngineState(state.arpEngineBottom)
  else
    if countTableKeys(state.arpHeldNotes) > 0 or countTableKeys(state.arpEngineTop.heldNotes) > 0 or countTableKeys(state.arpEngineBottom.heldNotes) > 0 then
      if not state.arpTimer then startArpTimer() end
    end
  end
  updateHud()
end

local function toggleArpLink()
  state.arpLinked = not state.arpLinked
  if state.arpLinked then
    state.arpHeldNotes = {}
    state.arpTargetHeldNotes = state.arpTargetHeldNotes or {}
    state.arpKeysCurrentlyHeld = {}
    for k, v in pairs(state.arpEngineTop.heldNotes) do state.arpHeldNotes[k] = v end
    for k, v in pairs(state.arpEngineBottom.heldNotes) do state.arpHeldNotes[k] = v end
    for k, v in pairs(state.arpEngineTop.targetHeldNotes or {}) do state.arpTargetHeldNotes[k] = v end
    for k, v in pairs(state.arpEngineBottom.targetHeldNotes or {}) do state.arpTargetHeldNotes[k] = v end
    for k, v in pairs(state.arpEngineTop.keysCurrentlyHeld) do state.arpKeysCurrentlyHeld[k] = v end
    for k, v in pairs(state.arpEngineBottom.keysCurrentlyHeld) do state.arpKeysCurrentlyHeld[k] = v end
    stopEngineState(state.arpEngineTop)
    stopEngineState(state.arpEngineBottom)
    state.arpStepIndex = 1
    state.arpStepDirection = 1
    state.arpPos = 0
    state.arpBeatPosition = 0
    if countTableKeys(state.arpHeldNotes) == 0 and state.arpTimer then
      stopArpTimer()
    end
  else
    state.arpEngineTop = newArpEngine()
    state.arpEngineBottom = newArpEngine()
    for code, pitch in pairs(state.arpHeldNotes) do
      local rawCode = type(code) == "string" and tonumber(code:match("^(%d+)")) or tonumber(code)
      local noteKey = rawCode and config.getNoteKey(rawCode)
      local isTop = noteKey and noteKey.isTop or false
      local eng = isTop and state.arpEngineTop or state.arpEngineBottom
      eng.heldNotes[code] = pitch
    end
    for code, pitch in pairs(state.arpTargetHeldNotes or {}) do
      local rawCode = type(code) == "string" and tonumber(code:match("^(%d+)")) or tonumber(code)
      local noteKey = rawCode and config.getNoteKey(rawCode)
      local isTop = noteKey and noteKey.isTop or false
      local eng = isTop and state.arpEngineTop or state.arpEngineBottom
      eng.targetHeldNotes[code] = pitch
    end
    for code, v in pairs(state.arpKeysCurrentlyHeld) do
      local rawCode = type(code) == "string" and tonumber(code:match("^(%d+)")) or tonumber(code)
      local noteKey = rawCode and config.getNoteKey(rawCode)
      local isTop = noteKey and noteKey.isTop or false
      local eng = isTop and state.arpEngineTop or state.arpEngineBottom
      eng.keysCurrentlyHeld[code] = v
    end
    if state.arpCurrentPitch then
      local p = type(state.arpCurrentPitch) == "table" and state.arpCurrentPitch.pitch or state.arpCurrentPitch
      local c = type(state.arpCurrentPitch) == "table" and state.arpCurrentPitch.channel or 0
      midi.sendMidiNote("noteOff", p, 0, c)
      state.arpCurrentPitch = nil
    end
    if state.arpActiveGateTimers then
      for pitch, entry in pairs(state.arpActiveGateTimers) do
        if entry and entry.timer then entry.timer:stop() end
        local ch = entry and entry.channel or 0
        midi.sendMidiNote("noteOff", pitch, 0, ch)
      end
      state.arpActiveGateTimers = {}
    end
    state.arpHeldNotes = {}
    state.arpKeysCurrentlyHeld = {}
    state.arpTargetHeldNotes = {}
    if countTableKeys(state.arpEngineTop.heldNotes) == 0 and countTableKeys(state.arpEngineBottom.heldNotes) == 0 and state.arpTimer then
      stopArpTimer()
    end
  end
  local spot = {
    title = "ARP LINK",
    value = state.arpLinked and "LINKED" or "SPLIT",
    subtext = state.arpLinked and "Top & Bottom share one pattern" or "Top & Bottom run independently",
    targetId = "header",
    color = "#d4a359"
  }
  updateHud(spot)
  config.saveSettings()
end

return {
  setHudModule = setHudModule,
  stopArpTimer = stopArpTimer,
  getArpIntervalSeconds = getArpIntervalSeconds,
  startArpTimer = startArpTimer,
  startTrackArp = startTrackArp,
  stopTrackArp = stopTrackArp,
  silenceTrack = silenceTrack,
  isTrackAudible = isTrackAudible,
  arpTickTrack = arpTickTrack,
  arpAddNote = arpAddNote,
  arpRemoveNote = arpRemoveNote,
  formatBpm = formatBpm,
  applyBpmChange = applyBpmChange,
  setTrackArpRate = setTrackArpRate,
  applyGatePercentChange = applyGatePercentChange,
  updateLatchedArpNotes = updateLatchedArpNotes,
  updateLatchedArpChordNotes = updateLatchedArpChordNotes,
  getArpRowTargetSubtext = getArpRowTargetSubtext,
  toggleArpPower = toggleArpPower,
  toggleArpLatch = toggleArpLatch,
  isAnyTrackArpActive = isAnyTrackArpActive,
  toggleArp = toggleArp,
  handleBpmInput = handleBpmInput,
  toggleLogicSync = toggleLogicSync,
  syncLogicBpm = syncLogicBpm,
  stepLogicBpm = stepLogicBpm,
  setLogicBpmTarget = setLogicBpmTarget,
  toggleArpLink = toggleArpLink,
  clearRowEngine = clearRowEngine,
  clearTrackArp = clearTrackArp,
  stopAllLoops = stopAllLoops,
  setArpPowerImplicit = setArpPowerImplicit
}
