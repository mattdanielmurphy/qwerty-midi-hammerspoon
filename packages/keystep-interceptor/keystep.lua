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
  [108] = 1, [109] = 2, [110] = 3, [111] = 4,
  [112] = 5, [113] = 6, [114] = 7, [115] = 8,
}

local DIVISIONS = {
  { label = "1/4",   ratio = 1.0,        ccValue = 1 },
  { label = "1/4T",  ratio = 2 / 3,      ccValue = 2 },
  { label = "1/8",   ratio = 0.5,        ccValue = 3 },
  { label = "1/8T",  ratio = 1 / 3,      ccValue = 4 },
  { label = "1/16",  ratio = 0.25,       ccValue = 5 },
  { label = "1/16T", ratio = 1 / 6,      ccValue = 6 },
  { label = "1/32",  ratio = 0.125,      ccValue = 7 },
  { label = "1/32T", ratio = 1 / 12,     ccValue = 8 },
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

local config = {
  -- Marker notes are channel-agnostic because direct and sequenced notes
  -- share the KeyStep User Channel.
  outputChannel = 0,
  -- MIDI CC data is seven-bit. Override this for a different rate encoding.
  rateCcValue = function(bpm)
    return math.max(0, math.min(127, math.floor(bpm + 0.5)))
  end,
}

local state = {
  mode = 1,
  division = "1/16",
  bpm = 120,
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
  pitchBend = 8192,
  modWheel = 0,
  sustain = 0,
  seqArpMode = "arp",
  playing = false,
  recording = false,
  shift = false,
  hold = false,
  octave = 0,
  activeKeys = {},
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
end

local function clearNoteTiming()
  state.lastSequenceNoteTime = nil
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

local function publishChange()
  print(formatState())
end

local function setMode(mode)
  if state.mode == mode then return end
  state.mode = mode
  sendCC(102, mode)
  publishChange()
  updateMonitor()
  sendToHud("mode", mode, true, { mode = mode, modeName = ARP_MODES[mode] or ("Seq " .. tostring(mode)) })
end

local function setDivision(division)
  if state.division == division.label then return end
  state.division = division.label
  sendCC(103, division.ccValue)
  publishChange()
  updateMonitor()
  sendToHud("division", division.ccValue, true, { division = division.label })
end

local function setBpm(bpm)
  local roundedBpm = math.floor(bpm + 0.5)
  if state.bpm == roundedBpm then return end
  state.bpm = roundedBpm
  sendCC(104, config.rateCcValue(roundedBpm))
  publishChange()
  updateMonitor()
  sendToHud("bpm", roundedBpm, true, { bpm = roundedBpm })
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

local function handleClock(timestamp)
  state.clockPulseCount = state.clockPulseCount + 1
  recordEvent("MIDI clock", timestamp)
  local previous = state.lastClockTime
  state.lastClockTime = timestamp
  if not previous then return end

  local delta = timestamp - previous
  if delta <= 0 or delta > CLOCK_RESET_SECONDS then
    state.clockDeltas = {}
    return
  end

  table.insert(state.clockDeltas, delta)
  if #state.clockDeltas > CLOCK_SAMPLE_LIMIT then
    table.remove(state.clockDeltas, 1)
  end

  local meanDelta = average(state.clockDeltas)
  if meanDelta then
    setBpm(60 / (meanDelta * CLOCK_PULSES_PER_QUARTER))
  end
end

local function handleSequenceNote(note, channel, timestamp)

  recordEvent("Sequence note " .. tostring(note), timestamp)

  local mode = MODE_NOTES[note]
  if mode then setMode(mode) end

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

  if commandType == "systemTimingClock" then
    handleClock(timestamp)
  elseif commandType == "systemStartSequence" or commandType == "systemContinueSequence" then
    state.playing = true
    clearNoteTiming()
    recordEvent(commandType == "systemStartSequence" and "Transport started" or "Transport continued", timestamp)
    sendToHud("transport", 1, true, { action = "play" })
  elseif commandType == "systemStopSequence" then
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
    if MODE_NOTES[metadata.note] and metadata.velocity == SEQUENCE_MARKER_VELOCITY then
      handleSequenceNote(metadata.note, metadata.channel, timestamp)
    else
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
  sendToHud("connection", 1, true, { deviceName = deviceName })
  sendToHud("mode", state.mode, true, { mode = state.mode, modeName = ARP_MODES[state.mode] or ("Seq " .. tostring(state.mode)) })
  sendToHud("division", 5, true, { division = state.division })
  sendToHud("bpm", state.bpm, true, { bpm = state.bpm })
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

function KeyStep.setHud(hudInstance)
  hudRef = hudInstance
  if hudRef and hudRef.updateConnectionStatus then
    hudRef.updateConnectionStatus(inputDevice ~= nil)
  end
  if inputDevice then
    sendToHud("connection", 1, true, { deviceName = state.deviceName })
    sendToHud("mode", state.mode, true, { mode = state.mode, modeName = ARP_MODES[state.mode] or ("Seq " .. tostring(state.mode)) })
    sendToHud("division", 5, true, { division = state.division })
    sendToHud("bpm", state.bpm, true, { bpm = state.bpm })
    sendToHud("seq_arp", state.seqArpMode == "seq" and 1 or 0, true, { mode = state.seqArpMode })
    sendToHud("transport", state.playing and 1 or 0, state.playing, { action = state.playing and "play" or "stop" })
    sendToHud("octave", state.octave, true, { octave = state.octave })
  end
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
    local bpm = tonumber(data.bpm)
    if bpm and bpm >= 30 and bpm <= 240 then
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

return KeyStep
