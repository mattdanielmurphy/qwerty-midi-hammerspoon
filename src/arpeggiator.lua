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
  if state.arpGateTimer then
    state.arpGateTimer:stop()
    state.arpGateTimer = nil
  end
  if state.arpTimer then
    state.arpTimer:stop()
    state.arpTimer = nil
  end
  if state.arpCurrentPitch then
    midi.sendMidiNote("noteOff", state.arpCurrentPitch, 0)
    state.arpCurrentPitch = nil
  end
  state.arpStepIndex = 1
  state.arpStepDirection = 1
end

local function getArpIntervalSeconds()
  local rateFactor = ARP_RATES[state.arpRateIdx] and ARP_RATES[state.arpRateIdx].factor or 0.5
  return (60.0 / state.arpBpm) * rateFactor
end

local function arpTick()
  local pitchList = {}
  for code, pitch in pairs(state.arpHeldNotes) do
    table.insert(pitchList, pitch)
  end
  table.sort(pitchList)

  if #pitchList == 0 then
    if state.arpGateTimer then
      state.arpGateTimer:stop()
      state.arpGateTimer = nil
    end
    if state.arpCurrentPitch then
      midi.sendMidiNote("noteOff", state.arpCurrentPitch, 0)
      state.arpCurrentPitch = nil
      updateHud()
    end
    return
  end

  if state.arpDirectionIdx == 1 then -- UP
    state.arpStepIndex = ((state.arpStepIndex - 1) % #pitchList) + 1
  elseif state.arpDirectionIdx == 2 then -- DOWN
    state.arpStepIndex = ((state.arpStepIndex - 2 + #pitchList) % #pitchList) + 1
  elseif state.arpDirectionIdx == 3 then -- UP-DOWN
    if state.arpStepIndex > #pitchList then
      state.arpStepIndex = math.max(1, #pitchList - 1)
      state.arpStepDirection = -1
    elseif state.arpStepIndex < 1 then
      state.arpStepIndex = math.min(#pitchList, 2)
      state.arpStepDirection = 1
    end
  elseif state.arpDirectionIdx == 4 then -- RANDOM
    state.arpStepIndex = math.random(1, #pitchList)
  end

  local nextPitch = pitchList[state.arpStepIndex]

  if state.arpDirectionIdx == 3 then
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
  elseif state.arpDirectionIdx == 1 then
    state.arpStepIndex = state.arpStepIndex + 1
  elseif state.arpDirectionIdx == 2 then
    state.arpStepIndex = state.arpStepIndex - 1
  end

  if state.arpGateTimer then
    state.arpGateTimer:stop()
    state.arpGateTimer = nil
  end

  if state.arpCurrentPitch then
    midi.sendMidiNote("noteOff", state.arpCurrentPitch, 0)
  end

  local isTopRowArpNote = false
  for code, p in pairs(state.arpHeldNotes) do
    if p == nextPitch and upperRowKeys[code] then
      isTopRowArpNote = true
      break
    end
  end
  local vel = transposer.getEffectiveRowVelocity(isTopRowArpNote)
  midi.sendMidiNote("noteOn", nextPitch, vel)
  state.arpCurrentPitch = nextPitch

  updateHud(nil, nextPitch)

  local gateRatio = ARP_GATES[state.arpGateIdx] and ARP_GATES[state.arpGateIdx].ratio or 0.80
  if gateRatio < 1.00 then
    local gateDuration = getArpIntervalSeconds() * gateRatio
    state.arpGateTimer = hs.timer.doAfter(gateDuration, function()
      if state.arpCurrentPitch == nextPitch then
        midi.sendMidiNote("noteOff", state.arpCurrentPitch, 0)
        state.arpCurrentPitch = nil
        updateHud()
      end
      state.arpGateTimer = nil
    end)
  end
end

local function startArpTimer(preserveState)
  if state.arpTimer then return end
  local intervalSeconds = getArpIntervalSeconds()
  if not preserveState then
    state.arpStepIndex = 1
    state.arpStepDirection = 1
    arpTick()
  end
  state.arpTimer = hs.timer.doEvery(intervalSeconds, arpTick)
end

local function arpAddNote(code, pitch)
  local numPhysicalHeld = 0
  for _ in pairs(state.arpKeysCurrentlyHeld) do numPhysicalHeld = numPhysicalHeld + 1 end

  if state.sustainActive and numPhysicalHeld == 0 then
    state.arpHeldNotes = {}
    if state.arpCurrentPitch then
      midi.sendMidiNote("noteOff", state.arpCurrentPitch, 0)
      state.arpCurrentPitch = nil
    end
  end

  state.arpKeysCurrentlyHeld[code] = true
  state.arpHeldNotes[code] = pitch

  if not state.arpTimer then
    startArpTimer()
  end
end

local function arpRemoveNote(code)
  state.arpKeysCurrentlyHeld[code] = nil

  if state.sustainActive then
    return
  end

  state.arpHeldNotes[code] = nil
  local count = 0
  for _ in pairs(state.arpHeldNotes) do count = count + 1 end
  if count == 0 then
    stopArpTimer()
    updateHud()
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
    state.arpTimer:setNextTrigger(getArpIntervalSeconds())
  end
end

local function updateLatchedArpNotes()
  if not state.arpEnabled or next(state.arpHeldNotes) == nil then return end
  for code, _ in pairs(state.arpHeldNotes) do
    if lowerRowKeys[code] then
      state.arpHeldNotes[code] = transposer.getTransposedPitch(lowerRowKeys[code].baseNote, false)
    elseif upperRowKeys[code] then
      state.arpHeldNotes[code] = transposer.getTransposedPitch(upperRowKeys[code].baseNote, true)
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
  state.arpEnabled = not state.arpEnabled
  if not state.arpEnabled then
    stopArpTimer()
    state.arpHeldNotes = {}
    state.arpKeysCurrentlyHeld = {}
  end
  local spot = {
    title = "ARPEGGIATOR",
    value = state.arpEnabled and "ARP: ON" or "ARP: OFF",
    subtext = state.arpEnabled and ("ON (" .. getArpRowTargetSubtext() .. ") • " .. formatBpm(state.arpBpm) .. " BPM") or "Arp Disabled",
    targetId = "arp-power-btn",
    color = "#d4a359"
  }
  updateHud(spot)
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
    return true
  elseif code == 36 then -- Return
    if state.bpmInputBuffer ~= "" then
      local val = tonumber(state.bpmInputBuffer)
      if val and val >= 20 and val <= 300 then
        state.arpBpm = val
      end
    end
    state.bpmInputMode = false
    state.bpmInputBuffer = ""
    applyBpmChange()
    updateHud()
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
    updateHud()
    return true
  elseif DIGIT_KEYCODES[code] then
    state.bpmInputBuffer = state.bpmInputBuffer .. DIGIT_KEYCODES[code]
    updateHud()
    return true
  elseif code == 47 then -- Period "."
    if not state.bpmInputBuffer:find("%.") then
      state.bpmInputBuffer = state.bpmInputBuffer .. "."
    end
    updateHud()
    return true
  end

  state.bpmInputMode = false
  state.bpmInputBuffer = ""
  updateHud()
  return false
end

return {
  setHudModule = setHudModule,
  stopArpTimer = stopArpTimer,
  getArpIntervalSeconds = getArpIntervalSeconds,
  startArpTimer = startArpTimer,
  arpAddNote = arpAddNote,
  arpRemoveNote = arpRemoveNote,
  formatBpm = formatBpm,
  applyBpmChange = applyBpmChange,
  updateLatchedArpNotes = updateLatchedArpNotes,
  getArpRowTargetSubtext = getArpRowTargetSubtext,
  toggleArpPower = toggleArpPower,
  toggleArp = toggleArp,
  handleBpmInput = handleBpmInput
}
