-- KeyStep side-channel control interceptor for Hammerspoon.
--
-- The KeyStep does not expose its Seq/Arp mode, rate, or time division as
-- ordinary MIDI CCs. When its sequencer is running, those controls can be
-- inferred from its sequence notes and MIDI timing clock instead.

local hsMidi = require("hs.midi")
local Monitor = require("keystep_ui")

local KeyStep = {}

local CLOCK_PULSES_PER_QUARTER = 24
local CLOCK_SAMPLE_LIMIT = 24
local CLOCK_RESET_SECONDS = 0.5
local NOTE_RESET_SECONDS = 2.0
local SEQUENCE_MARKER_VELOCITY = 1

local MODE_NOTES = {
  -- C10..G10 (120..127): exact sequencer marker notes emitted by KeyStep 32
  [120] = 1, [121] = 2, [122] = 3, [123] = 4,
  [124] = 5, [125] = 6, [126] = 7, [127] = 8,
  -- Also preserve alternate/legacy octaves (108..115: C8/C9..G8/G9)
  [108] = 1, [109] = 2, [110] = 3, [111] = 4,
  [112] = 5, [113] = 6, [114] = 7, [115] = 8,
}

local DIVISIONS = {
  { label = "1/4",   pulses = 24, ratio = 1.0,        ccValue = 1 },
  { label = "1/8",   pulses = 12, ratio = 0.5,        ccValue = 2 },
  { label = "1/16",  pulses = 6,  ratio = 0.25,       ccValue = 3 },
  { label = "1/32",  pulses = 3,  ratio = 0.125,      ccValue = 4 },
  { label = "1/4T",  pulses = 16, ratio = 2 / 3,      ccValue = 5 },
  { label = "1/8T",  pulses = 8,  ratio = 1 / 3,      ccValue = 6 },
  { label = "1/16T", pulses = 4,  ratio = 1 / 6,      ccValue = 7 },
  { label = "1/32T", pulses = 2,  ratio = 1 / 12,     ccValue = 8 },
}

local inputDevice = nil
local outputDevice = nil
local monitor = nil
local monitorRefreshTimer = nil
local running = false
local hudRef = nil

local ARP_MODES = {
  [1] = "Up",
  [2] = "Down",
  [3] = "Inclusive",
  [4] = "Exclusive",
  [5] = "Random",
  [6] = "Order",
  [7] = "Up x2",
  [8] = "Down x2",
}

-- KeyStep Rate knob physical range is 30 to 240 BPM.
-- Linear mapping: 30 BPM -> Rate 0, ~136-137 BPM -> Rate 64 (halfway), 240 BPM -> Rate 127.
local function bpmToRate(bpm)
  local b = math.max(30, math.min(240, bpm))
  return math.floor(((b - 30) / (240 - 30)) * 127 + 0.5)
end

local function rateToBpm(rateVal)
  local r = math.max(0, math.min(127, rateVal))
  return math.floor(30 + (r / 127) * (240 - 30) + 0.5)
end

local function loadSetting(key, default)
  if hs and hs.settings then
    local v = hs.settings.get(key)
    if v ~= nil then return v end
  end
  return default
end

local function persistSetting(key, val)
  if hs and hs.settings then
    hs.settings.set(key, val)
  end
end

local config = {
  -- Marker notes are channel-agnostic because direct and sequenced notes
  -- share the KeyStep User Channel.
  outputChannel = 0,
  -- Rate knob controls Master Volume:
  -- Arturia plugins map CC 17 to Output Level / Gain / Macro 2 by default.
  -- Standard MIDI maps CC 7 to Channel/Master Volume.
  rateCc = 17,            -- Arturia Macro 2 / Volume CC
  rateStandardCc = 7,     -- Standard MIDI Volume CC
  maxVolumeCc = 100,      -- Cap at 100 (0dB unity gain in Arturia) to prevent fried clipping boost
  minVolumeCc = 0,
  -- 8-position stepped knobs mapped to safe unreserved continuous CCs (105, 106)
  modeCc = 105,
  divCc = 106,
  -- MIDI CC data is seven-bit (0..127) mapped across KeyStep's 30..240 BPM range
  -- with 120 BPM at center (64).
  rateCcValue = function(bpm)
    return bpmToRate(bpm)
  end,
}

local function rateToVolumeCc(rateVal)
  local maxV = config.maxVolumeCc or 100
  local minV = config.minVolumeCc or 0
  local norm = math.max(0, math.min(127, rateVal)) / 127
  return math.floor(minV + norm * (maxV - minV) + 0.5)
end

local MAX_SEQUENCE_HISTORY = 32

local state = {
  mode = loadSetting("qwertyMidi_ks_mode", 1),
  division = loadSetting("qwertyMidi_ks_division", "1/16"),
  bpm = loadSetting("qwertyMidi_ks_bpm", 120),
  rate = loadSetting("qwertyMidi_ks_rate", 64),
  smoothBpm = loadSetting("qwertyMidi_ks_bpm", 120),
  clockHistory = {},
  connected = false,
  deviceName = nil,
  lastEvent = nil,
  lastEventAt = nil,
  clockPulseCount = 0,
  lastRawNote = nil,
  lastRawNoteChannel = nil,
  outputDeviceName = nil,
  lastClockTime = nil,
  clockDeltas = {},
  lastSequenceNoteTime = nil,
  clocksSinceLastNote = 0,
  pitchBend = 8192,
  modWheel = 0,
  sustain = 0,
  seqArpMode = loadSetting("qwertyMidi_ks_seqArpMode", "arp"),
  playing = false,
  recording = false,
  shift = false,
  hold = false,
  octave = 0,
  activeKeys = {},
  sequenceHistory = {},
}

local function sendToHud(controlId, value, pressed, extra)
  if hudRef and hudRef.updateKeyStepControl then
    hudRef.updateKeyStepControl(controlId, value, pressed, extra)
  end
end

local function nowSeconds()
  return hs.timer.absoluteTime() / 1000000000
end

local function monitorState()
  local age = nil
  if state.lastEventAt then
    age = math.max(0, math.floor(nowSeconds() - state.lastEventAt))
  end
  return {
    mode = state.mode,
    division = state.division,
    bpm = state.bpm,
    connected = state.connected,
    deviceName = state.deviceName,
    lastEvent = state.lastEvent,
    eventAge = age,
    clockPulseCount = state.clockPulseCount,
    lastRawNote = state.lastRawNote,
    lastRawNoteChannel = state.lastRawNoteChannel,
    outputDeviceName = state.outputDeviceName,
  }
end

local function updateMonitor()
  if monitor then monitor:update(monitorState()) end
end

local function ensureMonitorRefreshTimer()
  if monitorRefreshTimer then return end
  monitorRefreshTimer = hs.timer.doEvery(1, updateMonitor)
end

local function recordEvent(event, timestamp)
  state.lastEvent = event
  state.lastEventAt = timestamp or nowSeconds()
  updateMonitor()
end

local function average(values)
  if #values == 0 then return nil end
  local total = 0
  for _, value in ipairs(values) do total = total + value end
  return total / #values
end

local function clearClockTiming()
  state.lastClockTime = nil
  state.clockDeltas = {}
  state.clockHistory = {}
  state.clocksSinceLastNote = 0
  state.clockWindowStart = nil
  state.clockWindowCount = 0
end

local function clearNoteTiming()
  state.lastSequenceNoteTime = nil
  state.clocksSinceLastNote = 0
end

local function getQwertyOutput()
  local active = _G.activeWatchers and _G.activeWatchers.midiDevice
  if active then return active end

  for _, deviceName in ipairs(hsMidi.devices() or {}) do
    if deviceName:match("IAC") or deviceName:match("Bus") then
      return hsMidi.new(deviceName)
    end
  end
  for _, sourceName in ipairs(hsMidi.virtualSources() or {}) do
    if sourceName:match("IAC") or sourceName:match("Bus") then
      return hsMidi.newVirtualSource(sourceName)
    end
  end
  return nil
end

local function sendCC(controller, value)
  if not outputDevice then return end
  outputDevice:sendCommand("controlChange", {
    controllerNumber = controller,
    controllerValue = value,
    channel = config.outputChannel,
  })
end

local function forwardNote(commandType, metadata)
  if not outputDevice then return end
  outputDevice:sendCommand(commandType, {
    note = metadata.note,
    velocity = metadata.velocity or 0,
    channel = metadata.channel or 0,
  })
end

local function formatState()
  return string.format(
    "[KeyStep] Mode: %s | Div: %s | Rate: %s BPM",
    state.mode or "?",
    state.division or "?",
    state.bpm or "?"
  )
end

local lastPublishAt = 0
local function publishChange(force)
  local now = nowSeconds()
  if force or (now - lastPublishAt >= 0.5) then
    lastPublishAt = now
    print(formatState())
  end
end

local function setMode(mode)
  if state.mode == mode then return end
  state.mode = mode
  persistSetting("qwertyMidi_ks_mode", mode)
  -- 8-position knob: map 1..8 across full 0..127 CC range
  local modeCcVal = math.floor(((mode - 1) / 7) * 127 + 0.5)
  if config.modeCc then sendCC(config.modeCc, modeCcVal) end
  sendCC(102, mode)
  publishChange(true)
  updateMonitor()
  local modeName = state.seqArpMode == "seq" and ("Seq " .. tostring(mode)) or (ARP_MODES[mode] or ("Mode " .. tostring(mode)))
  sendToHud("mode", mode, true, { mode = mode, modeName = modeName, cc = config.modeCc, ccValue = modeCcVal })
end

local function setDivision(division)
  if not division then return end
  if state.division == division.label then return end
  state.division = division.label
  persistSetting("qwertyMidi_ks_division", division.label)
  -- 8-position knob: map 1..8 across full 0..127 CC range
  local divCcVal = math.floor(((division.ccValue - 1) / 7) * 127 + 0.5)
  if config.divCc then sendCC(config.divCc, divCcVal) end
  sendCC(103, division.ccValue)
  publishChange(true)
  updateMonitor()
  sendToHud("division", division.ccValue, true, { division = division.label, cc = config.divCc, ccValue = divCcVal })
end

local function setBpm(bpm)
  local roundedBpm = math.max(30, math.min(240, math.floor(bpm + 0.5)))
  if state.bpm == roundedBpm then return end
  state.bpm = roundedBpm
  state.smoothBpm = roundedBpm
  persistSetting("qwertyMidi_ks_bpm", roundedBpm)
  local rateVal = config.rateCcValue(roundedBpm)
  state.rate = rateVal
  persistSetting("qwertyMidi_ks_rate", rateVal)
  local volCcVal = rateToVolumeCc(rateVal)
  -- Rate knob controls Master Volume: emit Arturia Macro 2 (CC 17) and standard MIDI Volume (CC 7)
  if config.rateCc then sendCC(config.rateCc, volCcVal) end
  if config.rateStandardCc then sendCC(config.rateStandardCc, volCcVal) end
  sendCC(104, config.rateCcValue(roundedBpm))
  -- Synchronize Master Volume with QWERTY MIDI engine
  if _G.activeWatchers and _G.activeWatchers.state then
    _G.activeWatchers.state.topRowVolume = volCcVal
    _G.activeWatchers.state.bottomRowVolume = volCcVal
  end
  if _G.activeWatchers and _G.activeWatchers.hud and _G.activeWatchers.hud.updateWebviewHud then
    _G.activeWatchers.hud.updateWebviewHud()
  end
  publishChange(false)
  updateMonitor()
  sendToHud("rate", rateVal, true, { rate = rateVal, bpm = roundedBpm, volume = volCcVal, cc = config.rateCc or 17, ccValue = volCcVal })
  sendToHud("bpm", roundedBpm, true, { rate = rateVal, bpm = roundedBpm, volume = volCcVal, cc = config.rateCc or 17, ccValue = volCcVal })
end

local function setRate(rateVal)
  local roundedRate = math.max(0, math.min(127, math.floor(rateVal + 0.5)))
  if state.rate == roundedRate then return end
  state.rate = roundedRate
  persistSetting("qwertyMidi_ks_rate", roundedRate)
  local bpm = rateToBpm(roundedRate)
  state.bpm = bpm
  state.smoothBpm = bpm
  persistSetting("qwertyMidi_ks_bpm", bpm)
  local volCcVal = rateToVolumeCc(roundedRate)
  -- Rate knob controls Master Volume: emit Arturia Macro 2 (CC 17) and standard MIDI Volume (CC 7)
  if config.rateCc then sendCC(config.rateCc, volCcVal) end
  if config.rateStandardCc then sendCC(config.rateStandardCc, volCcVal) end
  sendCC(104, roundedRate)
  -- Synchronize Master Volume with QWERTY MIDI engine
  if _G.activeWatchers and _G.activeWatchers.state then
    _G.activeWatchers.state.topRowVolume = volCcVal
    _G.activeWatchers.state.bottomRowVolume = volCcVal
  end
  if _G.activeWatchers and _G.activeWatchers.hud and _G.activeWatchers.hud.updateWebviewHud then
    _G.activeWatchers.hud.updateWebviewHud()
  end
  publishChange()
  updateMonitor()
  sendToHud("rate", roundedRate, true, { rate = roundedRate, bpm = bpm, volume = volCcVal, cc = config.rateCc or 17, ccValue = volCcVal })
  sendToHud("bpm", bpm, true, { rate = roundedRate, bpm = bpm, volume = volCcVal, cc = config.rateCc or 17, ccValue = volCcVal })
end

local function nearestDivision(ratio)
  local nearest = nil
  local nearestError = math.huge
  for _, division in ipairs(DIVISIONS) do
    local error = math.abs(ratio - division.ratio)
    if error < nearestError then
      nearest = division
      nearestError = error
    end
  end
  return nearest
end

local function nearestDivisionByPulses(pulses)
  local nearest = nil
  local nearestError = math.huge
  for _, division in ipairs(DIVISIONS) do
    local err = math.abs(pulses - division.pulses)
    if err < nearestError then
      nearest = division
      nearestError = err
    end
  end
  return nearest
end

local CLOCK_HISTORY_MAX = 24
local TARGET_WINDOW_SECONDS = 0.20
local MIN_WINDOW_PULSES = 4
local MAX_WINDOW_PULSES = 16

local function handleClock(timestamp)
  state.clockPulseCount = state.clockPulseCount + 1
  state.clocksSinceLastNote = (state.clocksSinceLastNote or 0) + 1
  recordEvent("MIDI clock", timestamp)

  local previous = state.lastClockTime
  state.lastClockTime = timestamp
  local delta = previous and (timestamp - previous) or 0
  if delta > CLOCK_RESET_SECONDS then
    state.clockHistory = {}
    state.clockWindowStart = timestamp
    state.clockWindowCount = 0
  end

  local history = state.clockHistory or {}
  table.insert(history, timestamp)
  while #history > CLOCK_HISTORY_MAX do
    table.remove(history, 1)
  end
  state.clockHistory = history

  local count = #history
  if count >= MIN_WINDOW_PULSES then
    -- Adaptive sliding window: span at least TARGET_WINDOW_SECONDS (200ms) or up to MAX_WINDOW_PULSES
    local k = MIN_WINDOW_PULSES - 1
    while k < (count - 1) and k < MAX_WINDOW_PULSES and (timestamp - history[count - k]) < TARGET_WINDOW_SECONDS do
      k = k + 1
    end

    local elapsed = timestamp - history[count - k]
    if elapsed > 0.03 then
      -- 24 PPQN: instant BPM derived from sliding window of k pulses over elapsed seconds.
      -- If k == CLOCK_PULSES_PER_QUARTER (24 pulses), this evaluates directly to 60 / elapsed.
      local instantBpm = (60 * k) / (CLOCK_PULSES_PER_QUARTER * elapsed)

      -- Valid KeyStep BPM range: 30 to 240
      if instantBpm >= 25 and instantBpm <= 255 then
        local currentBpm = state.smoothBpm or state.bpm or 120
        local diff = math.abs(instantBpm - currentBpm)

        -- Dynamic slew rate: snap immediately on fast knob turns, smooth in steady-state
        local alpha
        if diff > 8.0 then
          alpha = 0.85
        elseif diff > 3.0 then
          alpha = 0.55
        elseif diff > 1.2 then
          alpha = 0.25
        else
          alpha = 0.10
        end

        currentBpm = currentBpm * (1.0 - alpha) + instantBpm * alpha
        state.smoothBpm = currentBpm

        -- Deadband / hysteresis to prevent 1-BPM jitter flickering in steady state
        local lastBpm = state.bpm or 120
        if math.abs(currentBpm - lastBpm) >= 0.65 then
          local roundedBpm = math.floor(currentBpm + 0.5)
          roundedBpm = math.max(30, math.min(240, roundedBpm))
          setBpm(roundedBpm)
        end
      end
    end
  end
end

local function handleSequenceNote(note, channel, timestamp)
  recordEvent("Sequence note " .. tostring(note), timestamp)

  local pulses = state.clocksSinceLastNote or 0
  state.clocksSinceLastNote = 0

  table.insert(state.sequenceHistory, {
    note = note,
    channel = channel,
    time = timestamp,
    pulses = pulses
  })
  while #state.sequenceHistory > MAX_SEQUENCE_HISTORY do
    table.remove(state.sequenceHistory, 1)
  end

  local mode = MODE_NOTES[note]
  if mode then
    if state.seqArpMode ~= "seq" then
      state.seqArpMode = "seq"
      persistSetting("qwertyMidi_ks_seqArpMode", "seq")
      sendToHud("seq_arp", 1, true, { mode = "seq" })
    end
    setMode(mode)
  end

  -- If MIDI clock pulses are running, pulse count between sequence notes is exact
  -- and completely independent of the Rate knob.
  if pulses and pulses >= 2 and pulses <= 36 then
    local div = nearestDivisionByPulses(pulses)
    if div then
      setDivision(div)
      return
    end
  end

  local previous = state.lastSequenceNoteTime
  state.lastSequenceNoteTime = timestamp
  if not previous or not state.bpm then return end

  local noteDelta = timestamp - previous
  if noteDelta <= 0 or noteDelta > NOTE_RESET_SECONDS then return end

  local quarterNoteSeconds = 60 / state.bpm
  local ratio = noteDelta / quarterNoteSeconds
  setDivision(nearestDivision(ratio))
end

local function findDevice(targetName)
  for _, deviceName in ipairs(hsMidi.devices() or {}) do
    local lowered = string.lower(deviceName)
    if lowered == "keystep" or lowered:match("^arturia keystep") then
      return deviceName
    end
    if targetName and lowered == string.lower(targetName) then
      return deviceName
    end
  end
  return nil
end

function KeyStep.handleMidiEvent(commandType, _, metadata, timestamp)
  if not running and not inputDevice then return end
  metadata = metadata or {}
  timestamp = timestamp or nowSeconds()

  local hex = (metadata.data and type(metadata.data) == "string") and metadata.data:lower() or ""
  local isClock = (commandType == "systemTimingClock") or (commandType == "systemMessage" and hex:match("f8") ~= nil)
  local isStart = (commandType == "systemStartSequence" or commandType == "systemContinueSequence") or
                  (commandType == "systemMessage" and (hex:match("fa") ~= nil or hex:match("fb") ~= nil))
  local isStop = (commandType == "systemStopSequence") or (commandType == "systemMessage" and hex:match("fc") ~= nil)

  if isClock then
    handleClock(timestamp)
  elseif isStart then
    state.playing = true
    clearNoteTiming()
    recordEvent("Transport started", timestamp)
    sendToHud("transport", 1, true, { action = "play" })
  elseif isStop then
    state.playing = false
    clearClockTiming()
    clearNoteTiming()
    recordEvent("Transport stopped", timestamp)
    sendToHud("transport", 0, false, { action = "stop" })
  elseif commandType == "pitchBend" then
    local pitchVal = metadata.pitchChange or 8192
    state.pitchBend = pitchVal
    if outputDevice then
      outputDevice:sendCommand("pitchBend", { pitchChange = pitchVal, channel = metadata.channel or config.outputChannel })
    end
    sendToHud("pitch_bend", pitchVal, true, { pitch = pitchVal })
    recordEvent("Pitch bend " .. tostring(pitchVal), timestamp)
  elseif commandType == "controlChange" then
    local ccNum = metadata.controllerNumber
    local ccVal = metadata.controllerValue or 0
    if ccNum == 1 then
      state.modWheel = ccVal
      if outputDevice then
        outputDevice:sendCommand("controlChange", { controllerNumber = 1, controllerValue = ccVal, channel = metadata.channel or config.outputChannel })
      end
      sendToHud("mod_wheel", ccVal, true, { cc = 1, value = ccVal })
      recordEvent("Mod wheel " .. tostring(ccVal), timestamp)
    elseif ccNum == 64 then
      state.sustain = ccVal
      if outputDevice then
        outputDevice:sendCommand("controlChange", { controllerNumber = 64, controllerValue = ccVal, channel = metadata.channel or config.outputChannel })
      end
      sendToHud("sustain", ccVal, ccVal >= 64, { cc = 64, value = ccVal })
      recordEvent("Sustain " .. tostring(ccVal), timestamp)
    else
      if outputDevice then
        outputDevice:sendCommand("controlChange", { controllerNumber = ccNum, controllerValue = ccVal, channel = metadata.channel or config.outputChannel })
      end
    end
  elseif commandType == "polyphonicKeyPressure" or commandType == "channelPressure" then
    local pressure = metadata.pressure or metadata.value or 0
    sendToHud("aftertouch", pressure, true, { note = metadata.note, pressure = pressure })
  elseif commandType == "noteOn" and (metadata.velocity or 0) > 0 then
    state.lastRawNote = metadata.note
    state.lastRawNoteChannel = metadata.channel
    recordEvent("Note " .. tostring(metadata.note) .. " on MIDI " .. tostring((metadata.channel or 0) + 1), timestamp)
    if MODE_NOTES[metadata.note] and (metadata.velocity <= SEQUENCE_MARKER_VELOCITY or metadata.note >= 120) then
      handleSequenceNote(metadata.note, metadata.channel, timestamp)
    else
      if state.playing then
        local pulses = state.clocksSinceLastNote or 0
        state.clocksSinceLastNote = 0
        table.insert(state.sequenceHistory, {
          note = metadata.note,
          channel = metadata.channel,
          time = timestamp,
          pulses = pulses
        })
        while #state.sequenceHistory > MAX_SEQUENCE_HISTORY do
          table.remove(state.sequenceHistory, 1)
        end
        if pulses and pulses >= 2 and pulses <= 36 then
          local div = nearestDivisionByPulses(pulses)
          if div then setDivision(div) end
        end
      end
      forwardNote("noteOn", metadata)
      state.activeKeys[metadata.note] = metadata.velocity
      sendToHud("key_" .. tostring(metadata.note), metadata.velocity, true, {
        note = metadata.note,
        velocity = metadata.velocity,
        channel = metadata.channel
      })
    end
  elseif commandType == "noteOff" or (commandType == "noteOn" and (metadata.velocity or 0) == 0) then
    -- Marker note-offs must be swallowed too, so they cannot affect Logic.
    if not MODE_NOTES[metadata.note] then forwardNote("noteOff", metadata) end
    if not MODE_NOTES[metadata.note] then
      state.activeKeys[metadata.note] = nil
      sendToHud("key_" .. tostring(metadata.note), 0, false, {
        note = metadata.note,
        channel = metadata.channel
      })
    end
  end
end

function KeyStep.connect(targetName)
  local deviceName = findDevice(targetName)
  if not deviceName then
    print("[KeyStep] Not detected. Waiting for KeyStep or Arturia KeyStep.")
    return false
  end

  if not outputDevice then
    outputDevice = getQwertyOutput()
    state.outputDeviceName = outputDevice and outputDevice:name() or nil
  end

  if inputDevice and inputDevice:name() == deviceName then return true end

  inputDevice = hsMidi.new(deviceName)
  if not inputDevice then
    print("[KeyStep] Failed to open MIDI input: " .. deviceName)
    return false
  end

  running = true
  inputDevice:callback(function(_, _, commandType, description, metadata)
    KeyStep.handleMidiEvent(commandType, description, metadata)
  end)
  state.connected = true
  state.deviceName = deviceName
  recordEvent("Listening for MIDI", nowSeconds())
  print("[KeyStep] Listening on " .. deviceName)
  if hudRef and hudRef.updateConnectionStatus then
    hudRef.updateConnectionStatus(true)
  end
  local modeName = state.seqArpMode == "seq" and ("Seq " .. tostring(state.mode)) or (ARP_MODES[state.mode] or ("Mode " .. tostring(state.mode)))
  sendToHud("connection", 1, true, { deviceName = deviceName })
  sendToHud("mode", state.mode, true, { mode = state.mode, modeName = modeName })
  sendToHud("division", 3, true, { division = state.division })
  sendToHud("rate", state.rate or 64, true, { rate = state.rate or 64, bpm = state.bpm })
  sendToHud("bpm", state.bpm, true, { rate = state.rate or 64, bpm = state.bpm })
  sendToHud("seq_arp", state.seqArpMode == "seq" and 1 or 0, true, { mode = state.seqArpMode })
  sendToHud("transport", state.playing and 1 or 0, state.playing, { action = state.playing and "play" or "stop" })
  sendToHud("octave", state.octave, true, { octave = state.octave })
  return true
end

function KeyStep.disconnect()
  if inputDevice then inputDevice:callback(nil) end
  inputDevice = nil
  state.connected = false
  state.deviceName = nil
  clearClockTiming()
  clearNoteTiming()
  recordEvent("MIDI device disconnected", nowSeconds())
  if hudRef and hudRef.updateConnectionStatus then
    hudRef.updateConnectionStatus(false)
  end
  sendToHud("connection", 0, false, { deviceName = nil })
end

function KeyStep.isConnected()
  return inputDevice ~= nil
end

function KeyStep.analyzeSequenceAndInferKnobs()
  -- 1. Rate Knob from recent clock pulses
  if state.clockHistory and #state.clockHistory >= MIN_WINDOW_PULSES then
    local now = nowSeconds()
    local lastClock = state.clockHistory[#state.clockHistory]
    if (now - lastClock) <= 1.5 then
      local currentBpm = state.smoothBpm or state.bpm
      if currentBpm and math.abs(currentBpm - (state.bpm or 120)) >= 0.65 then
        local roundedBpm = math.max(30, math.min(240, math.floor(currentBpm + 0.5)))
        setBpm(roundedBpm)
      end
    end
  end

  -- 2. Mode Knob from most recent sequence marker note
  if state.sequenceHistory and #state.sequenceHistory > 0 then
    for i = #state.sequenceHistory, 1, -1 do
      local item = state.sequenceHistory[i]
      local markerMode = MODE_NOTES[item.note]
      if markerMode then
        if state.seqArpMode ~= "seq" then
          state.seqArpMode = "seq"
          persistSetting("qwertyMidi_ks_seqArpMode", "seq")
          sendToHud("seq_arp", 1, true, { mode = "seq" })
        end
        if state.mode ~= markerMode then
          setMode(markerMode)
        end
        break
      end
    end

    -- 3. Time Division Knob from recent note pulse deltas
    local pulseDeltas = {}
    for i = 1, #state.sequenceHistory do
      local p = state.sequenceHistory[i].pulses
      if p and p >= 2 and p <= 48 then
        table.insert(pulseDeltas, p)
      end
    end

    if #pulseDeltas > 0 then
      local minP = math.huge
      for _, p in ipairs(pulseDeltas) do
        if p < minP then minP = p end
      end
      local div = nearestDivisionByPulses(minP)
      if div and div.label ~= state.division then
        setDivision(div)
      end
    end
  end
end

function KeyStep.getFullState()
  local modeName = state.seqArpMode == "seq" and ("Seq " .. tostring(state.mode)) or (ARP_MODES[state.mode] or ("Mode " .. tostring(state.mode)))
  local divIdx = 3
  for i, d in ipairs(DIVISIONS) do
    if d.label == state.division then
      divIdx = i
      break
    end
  end
  return {
    connected = state.connected,
    deviceName = state.deviceName,
    mode = state.mode,
    modeName = modeName,
    division = state.division,
    divIdx = divIdx,
    rate = state.rate or 64,
    bpm = state.bpm or 120,
    seqArp = state.seqArpMode or "arp",
    playing = state.playing == true,
    recording = state.recording == true,
    hold = state.hold == true,
    shift = state.shift == true,
    octave = state.octave or 0,
    pitchBend = state.pitchBend or 8192,
    modWheel = state.modWheel or 0,
    rateCc = config.rateCc or 7,
    modeCc = config.modeCc or 16,
    divCc = config.divCc or 17,
  }
end

function KeyStep.syncToHud()
  KeyStep.analyzeSequenceAndInferKnobs()

  if not hudRef then return end
  local s = KeyStep.getFullState()
  sendToHud("connection", s.connected and 1 or 0, s.connected, { deviceName = s.deviceName })
  sendToHud("mode", s.mode, true, { mode = s.mode, modeName = s.modeName, cc = config.modeCc, ccValue = math.floor(((s.mode - 1) / 7) * 127 + 0.5) })
  sendToHud("division", s.divIdx, true, { division = s.division, cc = config.divCc, ccValue = math.floor(((s.divIdx - 1) / 7) * 127 + 0.5) })
  sendToHud("rate", s.rate, true, { rate = s.rate, bpm = s.bpm, cc = config.rateCc or 7, ccValue = s.rate })
  sendToHud("bpm", s.bpm, true, { rate = s.rate, bpm = s.bpm, cc = config.rateCc or 7, ccValue = s.rate })
  sendToHud("seq_arp", s.seqArp == "seq" and 1 or 0, true, { mode = s.seqArp })
  sendToHud("transport", s.playing and 1 or 0, s.playing, { action = s.playing and "play" or "stop" })
  sendToHud("octave", s.octave, true, { octave = s.octave })
  sendToHud("hold", s.hold and 127 or 0, s.hold, { hold = s.hold })
  sendToHud("shift", s.shift and 1 or 0, s.shift, { shift = s.shift })
  sendToHud("pitch_bend", s.pitchBend, true, { pitch = s.pitchBend })
  sendToHud("mod_wheel", s.modWheel, true, { cc = 1, value = s.modWheel })
end

function KeyStep.setHud(hudInstance)
  hudRef = hudInstance
  if hudRef and hudRef.updateConnectionStatus then
    hudRef.updateConnectionStatus(inputDevice ~= nil)
  end
  KeyStep.syncToHud()
end

function KeyStep.handleGuiAction(actionType, data)
  data = data or {}
  if not outputDevice then
    outputDevice = getQwertyOutput()
  end
  if actionType == "key" then
    local note = tonumber(data.note)
    local isDown = (data.pressed == true)
    local vel = tonumber(data.velocity) or 100
    local ch = tonumber(data.channel) or config.outputChannel or 0
    if note then
      if outputDevice then
        outputDevice:sendCommand(isDown and "noteOn" or "noteOff", { note = note, velocity = isDown and vel or 0, channel = ch })
      end
      sendToHud("key_" .. tostring(note), isDown and vel or 0, isDown, { note = note, velocity = vel, channel = ch })
    end
  elseif actionType == "pitch" then
    local pitchVal = tonumber(data.value) or 8192
    state.pitchBend = pitchVal
    if outputDevice then
      outputDevice:sendCommand("pitchBend", { pitchChange = pitchVal, channel = config.outputChannel })
    end
    sendToHud("pitch_bend", pitchVal, true, { pitch = pitchVal })
  elseif actionType == "mod" then
    local modVal = tonumber(data.value) or 0
    state.modWheel = modVal
    if outputDevice then
      outputDevice:sendCommand("controlChange", { controllerNumber = 1, controllerValue = modVal, channel = config.outputChannel })
    end
    sendToHud("mod_wheel", modVal, true, { cc = 1, value = modVal })
  elseif actionType == "transport" then
    local act = tostring(data.action or "play")
    if act == "play" or act == "play_pause" then
      state.playing = not state.playing
      sendToHud("transport", state.playing and 1 or 0, state.playing, { action = state.playing and "play" or "stop" })
    elseif act == "stop" then
      state.playing = false
      sendToHud("transport", 0, false, { action = "stop" })
    elseif act == "rec" then
      state.recording = not state.recording
      sendToHud("record", state.recording and 1 or 0, state.recording, { recording = state.recording })
    elseif act == "tap" then
      sendToHud("tap", 1, true, {})
    end
  elseif actionType == "hold" then
    state.hold = not state.hold
    if outputDevice then
      outputDevice:sendCommand("controlChange", { controllerNumber = 64, controllerValue = state.hold and 127 or 0, channel = config.outputChannel })
    end
    sendToHud("hold", state.hold and 127 or 0, state.hold, { hold = state.hold })
  elseif actionType == "shift" then
    state.shift = not state.shift
    sendToHud("shift", state.shift and 1 or 0, state.shift, { shift = state.shift })
  elseif actionType == "octave" then
    local dir = tonumber(data.dir) or 0
    state.octave = math.max(-2, math.min(2, (state.octave or 0) + dir))
    sendToHud("octave", state.octave, true, { octave = state.octave })
  elseif actionType == "mode" then
    local m = tonumber(data.mode)
    if m and m >= 1 and m <= 8 then
      setMode(m)
    end
  elseif actionType == "division" then
    local d = tonumber(data.division)
    if d and d >= 1 and d <= 8 then
      setDivision(DIVISIONS[d])
    end
  elseif actionType == "seq_arp" or actionType == "seqarp" then
    state.seqArpMode = (data.mode == "seq" or data.mode == "arp") and data.mode or (state.seqArpMode == "arp" and "seq" or "arp")
    sendToHud("seq_arp", state.seqArpMode == "seq" and 1 or 0, true, { mode = state.seqArpMode })
  elseif actionType == "rate" then
    local rateVal = tonumber(data.rate)
    local bpm = tonumber(data.bpm)
    if rateVal and rateVal >= 0 and rateVal <= 127 then
      setRate(rateVal)
    elseif bpm and bpm >= 30 and bpm <= 240 then
      setBpm(bpm)
    end
  end
end

function KeyStep.start(options)
  options = options or {}
  if options.outputChannel ~= nil then config.outputChannel = options.outputChannel end
  if options.rateCcValue then config.rateCcValue = options.rateCcValue end

  running = true
  if options.showMonitor ~= false then
    KeyStep.showMonitor()
    ensureMonitorRefreshTimer()
  end
  outputDevice = options.outputDevice or getQwertyOutput()
  state.outputDeviceName = outputDevice and outputDevice:name() or nil
  if not outputDevice then print("[KeyStep] QWERTY MIDI output was not found; notes and CCs cannot be forwarded.") end
  KeyStep.connect(options.deviceName)
  updateMonitor()
  return KeyStep
end

function KeyStep.stop()
  running = false
  KeyStep.disconnect()
  outputDevice = nil
  state.outputDeviceName = nil
  if monitor then monitor:hide() end
  if monitorRefreshTimer then monitorRefreshTimer:stop() end
  monitorRefreshTimer = nil
end

function KeyStep.checkConnection()
  local available = findDevice()
  if available and not inputDevice then
    return KeyStep.connect(available)
  elseif not available and inputDevice then
    KeyStep.disconnect()
  end
  return inputDevice ~= nil
end

function KeyStep.getState()
  return monitorState()
end

function KeyStep.resetTiming()
  clearClockTiming()
  clearNoteTiming()
end


function KeyStep.showMonitor()
  monitor = monitor or Monitor.new()
  monitor:show(monitorState())
  ensureMonitorRefreshTimer()
end

function KeyStep.hideMonitor()
  if monitor then monitor:hide() end
end

function KeyStep.toggleMonitor()
  monitor = monitor or Monitor.new()
  monitor:toggle(monitorState())
end

-- Device callbacks are global in hs.midi, so retain one watcher for the
-- process lifetime and gate its work through the running flag.
_G.activeWatchers = _G.activeWatchers or {}
_G.activeWatchers.keyStepController = KeyStep
if not _G.activeWatchers.keyStepDeviceWatcherRegistered then
  _G.activeWatchers.keyStepDeviceWatcherRegistered = true
  hsMidi.deviceCallback(function()
    local controller = _G.activeWatchers.keyStepController
    if controller then controller.checkConnection() end
  end)
end

KeyStep.bpmToRate = bpmToRate
KeyStep.rateToBpm = rateToBpm
KeyStep.rateToVolumeCc = rateToVolumeCc
KeyStep.getFullState = KeyStep.getFullState
KeyStep.syncToHud = KeyStep.syncToHud
KeyStep.analyzeSequenceAndInferKnobs = KeyStep.analyzeSequenceAndInferKnobs

return KeyStep
