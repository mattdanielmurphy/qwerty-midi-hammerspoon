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
    local isTop = upperRowKeys[code] ~= nil
    local rowArpEnabled = isTop and state.arpTopEnabled or (not isTop and state.arpBottomEnabled)
    if rowArpEnabled then
      table.insert(pitchList, pitch)
    end
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
  elseif state.arpDirectionIdx == 4 then -- DOWN-UP
    if state.arpStepIndex > #pitchList then
      state.arpStepIndex = math.max(1, #pitchList - 1)
      state.arpStepDirection = -1
    elseif state.arpStepIndex < 1 then
      state.arpStepIndex = math.min(#pitchList, 2)
      state.arpStepDirection = 1
    end
  elseif state.arpDirectionIdx == 5 then -- CONVERGE (Outside -> In: 1, N, 2, N-1, 3, N-2, ...)
    local pos = ((state.arpStepIndex - 1) % #pitchList) + 1
    local idx
    if pos % 2 == 1 then
      idx = math.floor(pos / 2) + 1
    else
      idx = #pitchList - math.floor(pos / 2) + 1
    end
    state.arpStepIndex = math.max(1, math.min(#pitchList, idx))
  elseif state.arpDirectionIdx == 6 then -- DIVERGE (Inside -> Out: Middle, Middle+1, Middle-1, Middle+2, ...)
    local pos = ((state.arpStepIndex - 1) % #pitchList) + 1
    local mid = math.floor((#pitchList + 1) / 2)
    local idx
    if pos == 1 then
      idx = mid
    elseif pos % 2 == 0 then
      local offset = math.floor(pos / 2)
      idx = mid + offset
    else
      local offset = math.floor(pos / 2)
      idx = mid - offset
    end
    if idx < 1 or idx > #pitchList then
      -- Fallback modulo bounce to stay inside valid range
      idx = ((pos - 1) % #pitchList) + 1
    end
    state.arpStepIndex = idx
  elseif state.arpDirectionIdx == 7 then -- RANDOM
    state.arpStepIndex = math.random(1, #pitchList)
  end

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
  elseif state.arpDirectionIdx == 1 or state.arpDirectionIdx == 5 or state.arpDirectionIdx == 6 then
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

  local gateRatio = (state.arpGatePercent or 80.0) / 100.0
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

  if state.arpLatchActive then
    if numPhysicalHeld == 0 or not state.arpLatchClearedForNewChord then
      state.arpHeldNotes = {}
      state.arpLatchClearedForNewChord = true
      if state.arpCurrentPitch then
        midi.sendMidiNote("noteOff", state.arpCurrentPitch, 0)
        state.arpCurrentPitch = nil
      end
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

  local numPhysicalHeld = 0
  for _ in pairs(state.arpKeysCurrentlyHeld) do numPhysicalHeld = numPhysicalHeld + 1 end

  if state.arpLatchActive then
    if numPhysicalHeld == 0 then
      state.arpLatchClearedForNewChord = false
    end
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
    state.arpTimer:stop()
    state.arpTimer = nil
    startArpTimer(true)
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
    local prevBpm = state.bpmBeforeEdit
    state.bpmInputMode = false
    state.bpmInputBuffer = ""
    applyBpmChange()
    setLogicBpmTarget(state.arpBpm, prevBpm)
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

local isSyncingLogicBpm = false

local function setLogicBpmTarget(targetBpm, prevBpm)
  if not state.logicSyncEnabled then return end
  if isSyncingLogicBpm then return end
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
          set tempoSlider to slider 1 of group 1 of group 1 of window 1
          
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

  local task = hs.task.new("/usr/bin/osascript", function(exitCode, stdOut, stdErr)
    isSyncingLogicBpm = false
  end, { "-e", script })
  task:start()
end

local function stepLogicBpm(delta)
  -- delta is the BPM change (e.g. +5 or -5), each AXIncrement/Decrement = 1 BPM
  setLogicBpmTarget(state.arpBpm, state.arpBpm - delta)
end

local function syncLogicBpm()
  if not state.logicSyncEnabled or isSyncingLogicBpm then return end
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
      if val and val >= 20 and val <= 300 and math.abs(state.arpBpm - val) > 0.01 then
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
  updateLatchedArpNotes = updateLatchedArpNotes,
  getArpRowTargetSubtext = getArpRowTargetSubtext,
  toggleArpPower = toggleArpPower,
  toggleArp = toggleArp,
  handleBpmInput = handleBpmInput,
  toggleLogicSync = toggleLogicSync,
  syncLogicBpm = syncLogicBpm,
  stepLogicBpm = stepLogicBpm,
  setLogicBpmTarget = setLogicBpmTarget
}

