-- KeyStep side-channel control interceptor for Hammerspoon.
--
-- The KeyStep does not expose its Seq/Arp mode, rate, or time division as
-- ordinary MIDI CCs. When its sequencer is running, those controls can be
-- inferred from its sequence notes and MIDI timing clock instead.

local hsMidi = require("hs.midi")
local Monitor = require("keystep_ui")

local transposer = nil
pcall(function() transposer = require("transposer") end)

local WHITE_KEY_INDEX = {
  [0] = 0, [1] = -1, [2] = 1, [3] = -1, [4] = 2, [5] = 3,
  [6] = -1, [7] = 4, [8] = -1, [9] = 5, [10] = -1, [11] = 6
}

local SHIFT_MODES = {
  [1]  = { id = "cutoff",  label = "CUTOFF",  cc = 74, default = 100, color = "#00e5ff", desc = "Filter Cutoff" },
  [3]  = { id = "reverb",  label = "REVERB",  cc = 91, default = 20,  color = "#ff9100", desc = "Reverb Send" },
  [6]  = { id = "delay",   label = "DELAY",   cc = 92, default = 0,   color = "#d500f9", desc = "Delay Send" },
  [8]  = { id = "release", label = "RELEASE", cc = 72, default = 40,  color = "#00e676", desc = "Synth Release" },
  [10] = { id = "envelope", label = "ADSR", cc = 24, default = 64, color = "#ffd700", desc = "Envelope Stage" },
}

local ENVELOPE_STAGES = {
  { id = "attack", label = "ATTACK", cc = 24, default = 0 },
  { id = "decay", label = "DECAY", cc = 25, default = 64 },
  { id = "sustain", label = "SUSTAIN", cc = 26, default = 100 },
  { id = "release", label = "RELEASE", cc = 27, default = 40 },
}

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
local noteHandler = nil

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
  -- Emit one dedicated CC for Logic Controller Assignments Learn.
  -- Avoid CC 7 and Arturia's CC 17 so the knob does not change instrument volume directly.
  rateCc = 107,
  maxVolumeCc = 127,      -- Full 0..127 MIDI volume range
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
  local maxV = config.maxVolumeCc or 127
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
  transportStatus = "unknown",
  recording = false,
  shift = false,
  hold = false,
  octave = 0,
  activeKeys = {},
  sequenceHistory = {},
  activeShiftMode = nil,
  latchedShiftMode = nil,
  shiftPressTimes = {},
  shiftControlTweaked = false,
  heldShiftKeys = {},
  envelopeStageIdx = loadSetting("qwertyMidi_ks_envelopeStageIdx", 0),
  heldWhiteKeys = {},
  paramValues = {
    cutoff = 100,
    reverb = 20,
    delay = 0,
    release = 40,
    volume = 100,
    modwheel = 0,
  },
  trackParamValues = {},
  transposerEnabled = loadSetting("qwertyMidi_ks_transposerEnabled", true),
  setupAcknowledged = false,
  setupGuideStep = "hidden",
}

local function sendToHud(controlId, value, pressed, extra)
  if hudRef and hudRef.updateKeyStepControl then
    hudRef.updateKeyStepControl(controlId, value, pressed, extra)
  end
end

local function setSetupGuide(step)
  state.setupGuideStep = step or "hidden"
  sendToHud("setup_guide", 1, state.setupGuideStep ~= "hidden", { step = state.setupGuideStep })
end

local function getActiveShiftModeDef()
  local modeId = state.activeShiftMode or state.latchedShiftMode
  if not modeId then return nil end
  for _, m in pairs(SHIFT_MODES) do
    if m.id == modeId then return m end
  end
  return nil
end

local function getFocusedTrack()
  local s = _G.activeWatchers and _G.activeWatchers.state
  local id = s and tonumber(s.activeTrack)
  local trk = s and s.tracks and s.tracks[id or -1]
  return trk, id
end

local function currentParamValues()
  local _, trackId = getFocusedTrack()
  if not trackId then return state.paramValues end
  if not state.trackParamValues[trackId] then
    local values = {}
    for _, def in pairs(SHIFT_MODES) do values[def.id] = def.default end
    for _, stage in ipairs(ENVELOPE_STAGES) do values[stage.id] = stage.default end
    values.modwheel = 0
    state.trackParamValues[trackId] = values
  end
  return state.trackParamValues[trackId]
end

local function effectiveShiftAssignment(modeDef)
  if not modeDef then
    local values = currentParamValues()
    return { cc = 1, label = "MOD", color = "#a0a0ab", value = values.modwheel or 0 }
  end
  if modeDef.id == "envelope" then
    local stage = ENVELOPE_STAGES[state.envelopeStageIdx] or ENVELOPE_STAGES[1]
    local values = currentParamValues()
    return { cc = stage.cc, label = stage.label, color = modeDef.color,
      value = values[stage.id] or state.paramValues[stage.id] or stage.default, stage = stage.id }
  end
  local values = currentParamValues()
  return { cc = modeDef.cc, label = modeDef.label, color = modeDef.color,
    value = values[modeDef.id] or state.paramValues[modeDef.id] or modeDef.default }
end

local function getOutputChannel()
  local trk = getFocusedTrack()
  return (trk and trk.channel) or config.outputChannel
end

local function resolveHeldShiftMode()
  local newestTime, newestMode = -1, nil
  for note, pressedAt in pairs(state.shiftPressTimes) do
    if pressedAt >= newestTime then
      local def = SHIFT_MODES[(tonumber(note) or 0) % 12]
      if def then newestTime, newestMode = pressedAt, def.id end
    end
  end
  state.activeShiftMode = newestMode or state.latchedShiftMode
end

local function sendShiftModeToHud()
  local modeDef = getActiveShiftModeDef()
  local assignment = effectiveShiftAssignment(modeDef)
  local isLatched = (state.latchedShiftMode ~= nil and state.latchedShiftMode == (modeDef and modeDef.id))
  sendToHud("shift_mode", modeDef and 1 or 0, modeDef ~= nil, {
    mode = modeDef and modeDef.id or "default",
    label = modeDef and modeDef.label or "DEFAULT",
    cc = assignment.cc,
    value = assignment.value,
    color = modeDef and modeDef.color or "#a0a0ab",
    latched = isLatched,
    desc = modeDef and (assignment.stage and ("Envelope " .. assignment.stage) or modeDef.desc) or "Mod Wheel"
  })
  sendToHud("mod_wheel", assignment.value, true, {
    cc = assignment.cc, value = assignment.value, mode = modeDef and modeDef.id or "default",
    label = assignment.label, color = assignment.color, stage = assignment.stage
  })
  sendToHud("pitch_assignment", assignment.value, true, {
    cc = assignment.cc, label = assignment.label, color = assignment.color,
    mode = modeDef and modeDef.id or "default"
  })
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
    setupGuideStep = state.setupGuideStep or "hidden",
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

local function sendCC(controller, value, channel)
  if not outputDevice then return end
  outputDevice:sendCommand("controlChange", {
    controllerNumber = controller,
    controllerValue = value,
    channel = channel or config.outputChannel,
  })
end

local lastRateCcValue = nil
local RATE_CC_DEADBAND = 0
local function sendRateCc(value)
  if not outputDevice or not config.rateCc then return end
  if lastRateCcValue ~= nil and math.abs(value - lastRateCcValue) <= RATE_CC_DEADBAND then
    return
  end
  sendCC(config.rateCc, value)
  lastRateCcValue = value
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

  local shiftDef = getActiveShiftModeDef()
  if shiftDef then
    state.shiftControlTweaked = true
    state.paramValues[shiftDef.id] = rateVal
    sendCC(shiftDef.cc, rateVal)
    if shiftDef.id == "volume" then
      local volCcVal = rateToVolumeCc(rateVal)
      if _G.activeWatchers and _G.activeWatchers.state then
        _G.activeWatchers.state.bottomRowVolume = volCcVal
      end
    end
    sendToHud("rate", rateVal, true, {
      rate = rateVal,
      bpm = roundedBpm,
      cc = shiftDef.cc,
      ccValue = rateVal,
      mode = shiftDef.id,
      label = shiftDef.label
    })
    sendToHud("bpm", roundedBpm, true, { rate = rateVal, bpm = roundedBpm, cc = shiftDef.cc, ccValue = rateVal })
  else
    local volCcVal = rateToVolumeCc(rateVal)
    sendRateCc(rateVal)
    -- Synchronize Master Volume with QWERTY MIDI engine
    local volChanged = false
    if _G.activeWatchers and _G.activeWatchers.state then
      if _G.activeWatchers.state.topRowVolume ~= volCcVal or _G.activeWatchers.state.bottomRowVolume ~= volCcVal then
        _G.activeWatchers.state.bottomRowVolume = volCcVal
        volChanged = true
      end
    end
    if volChanged and _G.activeWatchers and _G.activeWatchers.hud and _G.activeWatchers.hud.updateWebviewHud then
      _G.activeWatchers.hud.updateWebviewHud()
    end
    sendToHud("rate", rateVal, true, { rate = rateVal, bpm = roundedBpm, volume = volCcVal, cc = config.rateCc or 107, ccValue = rateVal })
    sendToHud("bpm", roundedBpm, true, { rate = rateVal, bpm = roundedBpm, volume = volCcVal, cc = config.rateCc or 107, ccValue = rateVal })
  end
  publishChange(false)
  updateMonitor()
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

  local shiftDef = getActiveShiftModeDef()
  if shiftDef then
    state.shiftControlTweaked = true
    state.paramValues[shiftDef.id] = roundedRate
    sendCC(shiftDef.cc, roundedRate)
    if shiftDef.id == "volume" then
      local volCcVal = rateToVolumeCc(roundedRate)
      if _G.activeWatchers and _G.activeWatchers.state then
        _G.activeWatchers.state.bottomRowVolume = volCcVal
      end
    end
    sendToHud("rate", roundedRate, true, {
      rate = roundedRate,
      bpm = bpm,
      cc = shiftDef.cc,
      ccValue = roundedRate,
      mode = shiftDef.id,
      label = shiftDef.label
    })
    sendToHud("bpm", bpm, true, { rate = roundedRate, bpm = bpm, cc = shiftDef.cc, ccValue = roundedRate })
  else
    local volCcVal = rateToVolumeCc(roundedRate)
    sendRateCc(roundedRate)
    -- Synchronize Master Volume with QWERTY MIDI engine
    if _G.activeWatchers and _G.activeWatchers.state then
      _G.activeWatchers.state.bottomRowVolume = volCcVal
    end
    if _G.activeWatchers and _G.activeWatchers.hud and _G.activeWatchers.hud.updateWebviewHud then
      _G.activeWatchers.hud.updateWebviewHud()
    end
    sendToHud("rate", roundedRate, true, { rate = roundedRate, bpm = bpm, volume = volCcVal, cc = config.rateCc or 107, ccValue = roundedRate })
    sendToHud("bpm", bpm, true, { rate = roundedRate, bpm = bpm, volume = volCcVal, cc = config.rateCc or 107, ccValue = roundedRate })
  end
  publishChange()
  updateMonitor()
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

local CLOCK_HISTORY_MAX = 36
local MIN_WINDOW_PULSES = 4
local MIN_CLOCK_SPAN_PULSES = 4
local MAX_CLOCK_SPAN_PULSES = 16
local MIN_CLOCK_MEDIAN_INTERVALS = 7
local CLOCK_MEDIAN_WINDOW_SECONDS = 0.20

local function median(values)
  if #values == 0 then return nil end
  table.sort(values)
  local middle = math.floor((#values + 1) / 2)
  if #values % 2 == 1 then return values[middle] end
  return (values[middle] + values[middle + 1]) / 2
end

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
  local expectedBpm = state.smoothBpm or state.bpm or 120
  local expectedPulseInterval = 60 / (CLOCK_PULSES_PER_QUARTER * expectedBpm)

  -- Multi-pulse span adapts to tempo: target ~180-200ms span window.
  -- At high BPM (240 BPM), span = 16 pulses (166ms) cancels out runloop jitter.
  -- At low BPM (30 BPM), span = 4 pulses (333ms) avoids excessive lag.
  local span = math.max(
    MIN_CLOCK_SPAN_PULSES,
    math.min(MAX_CLOCK_SPAN_PULSES, math.floor(CLOCK_MEDIAN_WINDOW_SECONDS / expectedPulseInterval + 0.5))
  )

  local numSpans = math.min(MIN_CLOCK_MEDIAN_INTERVALS, count - span)
  if count >= span + 3 and numSpans >= 3 then
    -- Measure elapsed duration across sliding spans of `span` pulses.
    -- Single-pulse deltas suffer ~15-20% runloop quantization jitter at high BPM (10ms pulses),
    -- which previously caused Rate to jump between 65%, 80%, and 100% with no in-between steps.
    -- Measuring multi-pulse spans divides endpoint jitter by `span`, reducing error to < 0.8%
    -- and smoothly resolving every single percentage and CC step.
    local intervals = {}
    local first = count - numSpans + 1
    for i = first, count do
      local spanDuration = history[i] - history[i - span]
      if spanDuration > 0 and spanDuration <= (span * CLOCK_RESET_SECONDS) then
        table.insert(intervals, spanDuration / span)
      end
    end
    local medianInterval = median(intervals)
    if medianInterval then
      local instantBpm = 60 / (CLOCK_PULSES_PER_QUARTER * medianInterval)

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
        if math.abs(currentBpm - lastBpm) >= 1.2 then
          local roundedBpm = math.floor(currentBpm + 0.5)
          roundedBpm = math.max(30, math.min(240, roundedBpm))
          setBpm(roundedBpm)
          state.smoothBpm = currentBpm
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
    state.transportStatus = "running"
    setSetupGuide(state.setupAcknowledged and "hidden" or "kbd_play")
    clearNoteTiming()
    recordEvent("Transport started", timestamp)
    sendToHud("transport", 1, true, { action = "play", status = "running", source = "start" })
  elseif isStop then
    state.playing = false
    state.transportStatus = "stopped"
    setSetupGuide("transport")
    clearClockTiming()
    clearNoteTiming()
    recordEvent("Transport stopped", timestamp)
    sendToHud("transport", 0, false, { action = "stop", status = "stopped", source = "stop" })
  elseif commandType == "pitchWheelChange" then
    local pitchVal = metadata.pitchChange or 8192
    state.pitchBend = pitchVal
    local shiftDef = getActiveShiftModeDef()
    if shiftDef then
      local assignment = effectiveShiftAssignment(shiftDef)
      local ccVal = math.floor((pitchVal / 16383) * 127 + 0.5)
      state.shiftControlTweaked = true
      currentParamValues()[assignment.stage or shiftDef.id] = ccVal
      state.paramValues[assignment.stage or shiftDef.id] = ccVal
      sendCC(assignment.cc, ccVal, getOutputChannel())
      sendToHud("pitch_bend", pitchVal, true, { assignment = true, cc = assignment.cc, value = ccVal, label = assignment.label, color = assignment.color })
      sendToHud("mod_wheel", ccVal, true, { cc = assignment.cc, value = ccVal, label = assignment.label, color = assignment.color, stage = assignment.stage })
    elseif outputDevice then
      outputDevice:sendCommand("pitchWheelChange", { pitchChange = pitchVal, channel = getOutputChannel() })
      sendToHud("pitch_bend", pitchVal, true, { pitch = pitchVal })
    end
    recordEvent("Pitch bend " .. tostring(pitchVal), timestamp)
  elseif commandType == "controlChange" then
    local ccNum = metadata.controllerNumber
    local ccVal = metadata.controllerValue or 0
    if ccNum == 1 then
      local shiftDef = getActiveShiftModeDef()
      if shiftDef then
        state.shiftControlTweaked = true
        local assignment = effectiveShiftAssignment(shiftDef)
        currentParamValues()[assignment.stage or shiftDef.id] = ccVal
        state.paramValues[assignment.stage or shiftDef.id] = ccVal
        sendCC(assignment.cc, ccVal, getOutputChannel())
        sendToHud("mod_wheel", ccVal, true, {
          cc = assignment.cc,
          value = ccVal,
          mode = shiftDef.id,
          label = assignment.label,
          stage = assignment.stage,
          color = shiftDef.color
        })
        recordEvent(assignment.label .. " " .. tostring(ccVal) .. " (CC " .. tostring(assignment.cc) .. ")", timestamp)
      else
        state.modWheel = ccVal
        state.paramValues.modwheel = ccVal
        currentParamValues().modwheel = ccVal
        if outputDevice then
          outputDevice:sendCommand("controlChange", { controllerNumber = 1, controllerValue = ccVal, channel = getOutputChannel() })
        end
        sendToHud("mod_wheel", ccVal, true, { cc = 1, value = ccVal, mode = "default", label = "MOD" })
        recordEvent("Mod wheel " .. tostring(ccVal), timestamp)
      end
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
      -- Manual performance notes: strictly excluded from sequencer detection & Time Div inference
      local pitchClass = metadata.note % 12
      local isWhiteKey = (WHITE_KEY_INDEX[pitchClass] ~= -1)

      if not isWhiteKey then
        -- Black Key: Modal Shift Trigger!
        local modeDef = SHIFT_MODES[pitchClass]
        if modeDef then
          state.shiftPressTimes[metadata.note] = timestamp
          state.heldShiftKeys[metadata.note] = true
          state.activeShiftMode = modeDef.id
          state.shiftControlTweaked = false
          sendShiftModeToHud()
          state.activeKeys[metadata.note] = metadata.velocity
          sendToHud("key_" .. tostring(metadata.note), metadata.velocity, true, {
            note = metadata.note,
            velocity = metadata.velocity,
            channel = metadata.channel,
            isBlack = true,
            mode = modeDef.id,
            label = modeDef.label,
            color = modeDef.color
          })
          recordEvent("Shift " .. modeDef.label .. " (held)", timestamp)
        end
      else
        -- White Key: Transposed In-Scale Performance!
        if state.setupGuideStep == "kbd_play" then
          state.setupAcknowledged = true
          setSetupGuide("hidden")
        end
        local playPitch = metadata.note
        local transposerRef = transposer or (_G.activeWatchers and _G.activeWatchers.transposer)
        if state.transposerEnabled and transposerRef and transposerRef.getTransposedPitch then
          playPitch = transposerRef.getTransposedPitch(metadata.note, false)
        end
        state.heldWhiteKeys[metadata.note] = playPitch
        if hudRef and hudRef.updateChordDisplay then hudRef.updateChordDisplay() end
        if noteHandler and noteHandler.noteOn then
          noteHandler.noteOn(metadata.note, metadata.velocity, metadata.channel, metadata.note)
        else
          forwardNote("noteOn", {
            note = playPitch,
            velocity = metadata.velocity,
            channel = metadata.channel or config.outputChannel
          })
        end
        state.activeKeys[metadata.note] = metadata.velocity
        sendToHud("key_" .. tostring(metadata.note), metadata.velocity, true, {
          note = metadata.note,
          playedPitch = playPitch,
          velocity = metadata.velocity,
          channel = metadata.channel,
          isBlack = false
        })
      end
    end
  elseif commandType == "noteOff" or (commandType == "noteOn" and (metadata.velocity or 0) == 0) then
    local isMarker = (metadata.note >= 120 and metadata.note <= 127 and MODE_NOTES[metadata.note] ~= nil) or
                     (metadata.note >= 108 and metadata.note <= 115 and MODE_NOTES[metadata.note] ~= nil and state.heldWhiteKeys[metadata.note] == nil and state.activeKeys[metadata.note] == nil)
    if not isMarker then
      local pitchClass = metadata.note % 12
      local isWhiteKey = (WHITE_KEY_INDEX[pitchClass] ~= -1)

      if not isWhiteKey then
        -- Black Key: Modal Shift Release or Latch Toggle
        local modeDef = SHIFT_MODES[pitchClass]
        if modeDef then
          local pressTime = state.shiftPressTimes[metadata.note] or timestamp
          local duration = timestamp - pressTime
          state.shiftPressTimes[metadata.note] = nil
          state.heldShiftKeys[metadata.note] = nil
          local anotherHeld = next(state.shiftPressTimes) ~= nil
          if modeDef.id == "envelope" and duration < 0.28 and not state.shiftControlTweaked and not anotherHeld then
            state.envelopeStageIdx = (state.envelopeStageIdx % #ENVELOPE_STAGES) + 1
            persistSetting("qwertyMidi_ks_envelopeStageIdx", state.envelopeStageIdx)
            state.latchedShiftMode = "envelope"
          elseif not anotherHeld and duration < 0.28 and not state.shiftControlTweaked then
            if state.latchedShiftMode == modeDef.id then state.latchedShiftMode = nil
            else state.latchedShiftMode = modeDef.id end
          end
          resolveHeldShiftMode()

          sendShiftModeToHud()
          state.activeKeys[metadata.note] = nil
          sendToHud("key_" .. tostring(metadata.note), 0, false, {
            note = metadata.note,
            channel = metadata.channel,
            isBlack = true
          })
          recordEvent("Shift " .. modeDef.label .. " (released)", timestamp)
        end
      else
        -- White Key: Note-Off for exact transposed pitch
        local playPitch = state.heldWhiteKeys[metadata.note]
        if not playPitch then
          local transposerRef = transposer or (_G.activeWatchers and _G.activeWatchers.transposer)
          if state.transposerEnabled and transposerRef and transposerRef.getTransposedPitch then
            playPitch = transposerRef.getTransposedPitch(metadata.note, false)
          else
            playPitch = metadata.note
          end
        end
        state.heldWhiteKeys[metadata.note] = nil
        if hudRef and hudRef.updateChordDisplay then hudRef.updateChordDisplay() end
        if noteHandler and noteHandler.noteOff then
          noteHandler.noteOff(metadata.note, metadata.channel)
        else
          forwardNote("noteOff", {
            note = playPitch,
            velocity = 0,
            channel = metadata.channel or config.outputChannel
          })
        end
        state.activeKeys[metadata.note] = nil
        sendToHud("key_" .. tostring(metadata.note), 0, false, {
          note = metadata.note,
          playedPitch = playPitch,
          channel = metadata.channel,
          isBlack = false
        })
      end
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
  state.playing = false
  state.transportStatus = "unknown"
  state.setupAcknowledged = false
  setSetupGuide("hidden")
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
  sendToHud("transport", nil, false, { action = "unknown", status = state.transportStatus })
  sendToHud("octave", state.octave, true, { octave = state.octave })
  return true
end

function KeyStep.disconnect()
  if noteHandler and noteHandler.disconnect then pcall(noteHandler.disconnect) end
  for note in pairs(state.activeKeys or {}) do
    sendToHud("key_" .. tostring(note), 0, false, { note = note, disconnected = true })
  end
  state.activeKeys = {}
  state.heldWhiteKeys = {}
  if inputDevice then inputDevice:callback(nil) end
  inputDevice = nil
  state.connected = false
  state.deviceName = nil
  state.playing = false
  state.transportStatus = "unknown"
  state.setupAcknowledged = false
  setSetupGuide("hidden")
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

function KeyStep.setNoteHandler(handler)
  noteHandler = handler
end

function KeyStep.panic()
  -- Release the exact transposed pitches emitted by the side-channel before
  -- discarding their ownership records.
  if not outputDevice then outputDevice = getQwertyOutput() end
  if outputDevice then
    for _, pitch in pairs(state.heldWhiteKeys) do
      outputDevice:sendCommand("noteOff", { note = pitch, velocity = 0, channel = config.outputChannel })
    end
    outputDevice:sendCommand("pitchWheelChange", { pitchChange = 8192, channel = getOutputChannel() })
  end
  for note in pairs(state.activeKeys) do
    sendToHud("key_" .. tostring(note), 0, false, { note = note })
  end
  state.heldWhiteKeys = {}
  state.shiftPressTimes = {}
  state.heldShiftKeys = {}
  state.activeKeys = {}
  state.activeShiftMode = nil
  state.latchedShiftMode = nil
  state.pitchBend = 8192
  state.sustain = 0
  state.shiftControlTweaked = false
  sendShiftModeToHud()
  sendToHud("pitch_bend", 8192, true, { pitch = 8192 })
  if hudRef and hudRef.updateChordDisplay then hudRef.updateChordDisplay() end
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
      local item = state.sequenceHistory[i]
      -- Exclude manual performance notes; only evaluate sequencer marker notes
      if item and (item.note >= 120 or (MODE_NOTES[item.note] and item.note >= 108)) then
        local p = item.pulses
        if p and p >= 2 and p <= 48 then
          table.insert(pulseDeltas, p)
        end
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
  local activeDef = getActiveShiftModeDef()
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
    transportStatus = state.transportStatus or "unknown",
    recording = state.recording == true,
    hold = state.hold == true,
    shift = state.shift == true,
    octave = state.octave or 0,
    pitchBend = state.pitchBend or 8192,
    modWheel = state.modWheel or 0,
    rateCc = config.rateCc or 107,
    modeCc = config.modeCc or 16,
    divCc = config.divCc or 17,
    activeShiftMode = state.activeShiftMode,
    latchedShiftMode = state.latchedShiftMode,
    shiftModeDef = activeDef,
    transposerEnabled = state.transposerEnabled ~= false,
    paramValues = state.paramValues,
  }
end

function KeyStep.syncToHud()
  KeyStep.analyzeSequenceAndInferKnobs()

  if not hudRef then return end
  local s = KeyStep.getFullState()
  sendToHud("connection", s.connected and 1 or 0, s.connected, { deviceName = s.deviceName })
  sendToHud("mode", s.mode, true, { mode = s.mode, modeName = s.modeName, cc = config.modeCc, ccValue = math.floor(((s.mode - 1) / 7) * 127 + 0.5) })
  sendToHud("division", s.divIdx, true, { division = s.division, cc = config.divCc, ccValue = math.floor(((s.divIdx - 1) / 7) * 127 + 0.5) })
  sendToHud("rate", s.rate, true, { rate = s.rate, bpm = s.bpm, cc = config.rateCc or 107, ccValue = s.rate })
  sendToHud("bpm", s.bpm, true, { rate = s.rate, bpm = s.bpm, cc = config.rateCc or 107, ccValue = s.rate })
  sendToHud("seq_arp", s.seqArp == "seq" and 1 or 0, true, { mode = s.seqArp })
  sendToHud("setup_guide", 1, s.setupGuideStep ~= "hidden", { step = s.setupGuideStep })
  sendToHud("transport", s.playing and 1 or 0, s.playing, { action = s.transportStatus, status = s.transportStatus })
  sendToHud("octave", s.octave, true, { octave = s.octave })
  sendToHud("hold", s.hold and 127 or 0, s.hold, { hold = s.hold })
  sendToHud("shift", s.shift and 1 or 0, s.shift, { shift = s.shift })
  sendToHud("pitch_bend", s.pitchBend, true, { pitch = s.pitchBend })
  sendToHud("mod_wheel", s.modWheel, true, { cc = 1, value = s.modWheel })
  sendToHud("transposer_enabled", s.transposerEnabled and 1 or 0, s.transposerEnabled, {})
  sendShiftModeToHud()
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
      local pitchClass = note % 12
      local isWhiteKey = (WHITE_KEY_INDEX[pitchClass] ~= -1)

      if not isWhiteKey then
        -- Black key clicked on GUI: toggle latch mode!
        local modeDef = SHIFT_MODES[pitchClass]
        if modeDef and isDown then
          if modeDef.id == "envelope" then
            state.envelopeStageIdx = (state.envelopeStageIdx % #ENVELOPE_STAGES) + 1
            persistSetting("qwertyMidi_ks_envelopeStageIdx", state.envelopeStageIdx)
            state.latchedShiftMode = "envelope"
            state.activeShiftMode = "envelope"
          elseif state.latchedShiftMode == modeDef.id then
            state.latchedShiftMode = nil
            state.activeShiftMode = nil
          else
            state.latchedShiftMode = modeDef.id
            state.activeShiftMode = modeDef.id
          end
          sendShiftModeToHud()
        end
        sendToHud("key_" .. tostring(note), isDown and vel or 0, isDown, { note = note, isBlack = true, mode = modeDef and modeDef.id })
      else
        -- White key clicked on GUI: play transposed!
        local playPitch = note
        local transposerRef = transposer or (_G.activeWatchers and _G.activeWatchers.transposer)
        if state.transposerEnabled and transposerRef and transposerRef.getTransposedPitch then
          playPitch = transposerRef.getTransposedPitch(note, false)
        end
        if outputDevice then
          outputDevice:sendCommand(isDown and "noteOn" or "noteOff", { note = playPitch, velocity = isDown and vel or 0, channel = ch })
        end
        sendToHud("key_" .. tostring(note), isDown and vel or 0, isDown, { note = note, playedPitch = playPitch, velocity = vel, channel = ch, isBlack = false })
      end
    end
  elseif actionType == "shift_mode" or actionType == "shiftmode" then
    local targetMode = data.mode
    if targetMode == "toggle" or targetMode == "latch" then
      local mId = data.modeId
      if state.latchedShiftMode == mId then
        state.latchedShiftMode = nil
        state.activeShiftMode = nil
      else
        state.latchedShiftMode = mId
        state.activeShiftMode = mId
      end
    elseif targetMode == "clear" or targetMode == "default" then
      state.latchedShiftMode = nil
      state.activeShiftMode = nil
    else
      state.activeShiftMode = targetMode
    end
    sendShiftModeToHud()
  elseif actionType == "transposer_toggle" or actionType == "transposertoggle" then
    state.transposerEnabled = not (state.transposerEnabled ~= false)
    persistSetting("qwertyMidi_ks_transposerEnabled", state.transposerEnabled)
    sendToHud("transposer_enabled", state.transposerEnabled and 1 or 0, state.transposerEnabled, {})
  elseif actionType == "pitch" then
    local pitchVal = tonumber(data.value) or 8192
    state.pitchBend = pitchVal
    local shiftDef = getActiveShiftModeDef()
    if shiftDef then
      local assignment = effectiveShiftAssignment(shiftDef)
      local ccVal = math.floor((pitchVal / 16383) * 127 + 0.5)
      state.shiftControlTweaked = true
      currentParamValues()[assignment.stage or shiftDef.id] = ccVal
      state.paramValues[assignment.stage or shiftDef.id] = ccVal
      sendCC(assignment.cc, ccVal, getOutputChannel())
      sendToHud("pitch_bend", pitchVal, true, { assignment = true, cc = assignment.cc, value = ccVal, label = assignment.label, color = assignment.color })
      sendToHud("mod_wheel", ccVal, true, { cc = assignment.cc, value = ccVal, label = assignment.label, color = assignment.color, stage = assignment.stage })
    elseif outputDevice then
      outputDevice:sendCommand("pitchWheelChange", { pitchChange = pitchVal, channel = getOutputChannel() })
      sendToHud("pitch_bend", pitchVal, true, { pitch = pitchVal })
    end
  elseif actionType == "mod" then
    local modVal = tonumber(data.value) or 0
    local shiftDef = getActiveShiftModeDef()
    if shiftDef then
      local assignment = effectiveShiftAssignment(shiftDef)
      state.shiftControlTweaked = true
      currentParamValues()[assignment.stage or shiftDef.id] = modVal
      state.paramValues[assignment.stage or shiftDef.id] = modVal
      sendCC(assignment.cc, modVal, getOutputChannel())
      sendToHud("mod_wheel", modVal, true, { cc = assignment.cc, value = modVal, label = assignment.label, color = assignment.color, stage = assignment.stage })
    else
      state.modWheel = modVal
      currentParamValues().modwheel = modVal
      if outputDevice then
        outputDevice:sendCommand("controlChange", { controllerNumber = 1, controllerValue = modVal, channel = getOutputChannel() })
      end
      sendToHud("mod_wheel", modVal, true, { cc = 1, value = modVal, label = "MOD" })
    end
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

function KeyStep.getHeldPitches()
  local pitches = {}
  for _, pitch in pairs(state.heldWhiteKeys or {}) do
    if type(pitch) == "number" then pitches[#pitches + 1] = pitch end
  end
  return pitches
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
KeyStep.SHIFT_MODES = SHIFT_MODES
KeyStep.WHITE_KEY_INDEX = WHITE_KEY_INDEX
KeyStep.getActiveShiftModeDef = getActiveShiftModeDef
KeyStep.setTransposer = function(tRef, stateRef)
  transposer = tRef
  if stateRef then state.sharedEngineState = stateRef end
end
KeyStep.setTransposerEnabled = function(enabled)
  state.transposerEnabled = (enabled == true)
  persistSetting("qwertyMidi_ks_transposerEnabled", state.transposerEnabled)
  sendToHud("transposer_enabled", state.transposerEnabled and 1 or 0, state.transposerEnabled, {})
end

return KeyStep
