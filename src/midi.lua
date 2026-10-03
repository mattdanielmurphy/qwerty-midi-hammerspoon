local hsMidi = require("hs.midi")

_G.activeWatchers = _G.activeWatchers or {}

local function getMidiDevice()
  if _G.activeWatchers.midiDevice then return _G.activeWatchers.midiDevice end

  local devices = hsMidi.devices() or {}
  local virtualSources = hsMidi.virtualSources() or {}

  for _, devName in ipairs(devices) do
    if string.find(devName, "IAC") or string.find(devName, "Bus") then
      _G.activeWatchers.midiDevice = hsMidi.new(devName)
      return _G.activeWatchers.midiDevice
    end
  end

  for _, devName in ipairs(virtualSources) do
    if string.find(devName, "IAC") or string.find(devName, "Bus") then
      _G.activeWatchers.midiDevice = hsMidi.newVirtualSource(devName)
      return _G.activeWatchers.midiDevice
    end
  end

  if #devices > 0 then
    _G.activeWatchers.midiDevice = hsMidi.new(devices[1])
  elseif #virtualSources > 0 then
    _G.activeWatchers.midiDevice = hsMidi.newVirtualSource(virtualSources[1])
  end

  return _G.activeWatchers.midiDevice
end

local activeNoteLedger = {} -- [noteNum] = { [channel] = { track = trackId, color = color, vel = vel } }

local function getTrackForChannel(channel)
  local state = _G.activeWatchers and _G.activeWatchers.state
  if not state then
    pcall(function()
      local config = require("config")
      state = config and config.state
    end)
  end
  if state and state.tracks then
    for trkId, trk in pairs(state.tracks) do
      if trk.channel == channel then
        return trkId, trk.color or "#00e5ff"
      end
    end
  end
  local fallbackColors = { [1] = "#00e5ff", [2] = "#ff9100", [3] = "#00e676", [4] = "#d500f9" }
  local trkId = ((channel or 0) % 4) + 1
  return trkId, fallbackColors[trkId] or "#00e5ff"
end

local function getActiveNoteLedger()
  local snapshot = {}
  for note, voices in pairs(activeNoteLedger) do
    for ch, voice in pairs(voices) do
      snapshot[tostring(note)] = { note = note, channel = ch, track = voice.track, color = voice.color }
      break
    end
  end
  return snapshot
end

local function clearActiveNotes()
  activeNoteLedger = {}
  if _G.activeWatchers and _G.activeWatchers.hud and _G.activeWatchers.hud.clearPianoNotes then
    _G.activeWatchers.hud.clearPianoNotes()
  end
end

local function sendMidiNote(cmd, noteNum, vel, channel)
  if type(noteNum) == "table" then
    channel = channel or noteNum.channel
    noteNum = noteNum.pitch
  end
  if not noteNum or type(noteNum) ~= "number" or noteNum < 0 or noteNum > 127 then return end
  local dev = getMidiDevice()
  local ch = channel or 0
  local isNoteOn = (cmd == "noteOn" and (vel or 0) > 0)
  local isNoteOff = (cmd == "noteOff" or (cmd == "noteOn" and (vel or 0) == 0))
  local trkId, trkColor = getTrackForChannel(ch)

  if dev then
    if isNoteOff then
      dev:sendCommand("noteOff", { note = noteNum, velocity = 0, channel = ch })
      dev:sendCommand("noteOn", { note = noteNum, velocity = 0, channel = ch })
    else
      dev:sendCommand("noteOn", { note = noteNum, velocity = vel, channel = ch })
    end
  end

  -- Update active note ledger & real-time piano visualizer
  if isNoteOn then
    activeNoteLedger[noteNum] = activeNoteLedger[noteNum] or {}
    activeNoteLedger[noteNum][ch] = { track = trkId, color = trkColor, vel = vel }
    if _G.activeWatchers and _G.activeWatchers.hud and _G.activeWatchers.hud.updatePianoNote then
      _G.activeWatchers.hud.updatePianoNote(noteNum, true, trkId, trkColor)
    end
  elseif isNoteOff then
    if activeNoteLedger[noteNum] then
      activeNoteLedger[noteNum][ch] = nil
      if next(activeNoteLedger[noteNum]) == nil then
        activeNoteLedger[noteNum] = nil
      end
    end
    local stillActive = (activeNoteLedger[noteNum] ~= nil)
    local remainingTrkId = 0
    local remainingColor = ""
    if stillActive then
      for _, voice in pairs(activeNoteLedger[noteNum]) do
        remainingTrkId = voice.track
        remainingColor = voice.color
        break
      end
    end
    if _G.activeWatchers and _G.activeWatchers.hud and _G.activeWatchers.hud.updatePianoNote then
      _G.activeWatchers.hud.updatePianoNote(noteNum, stillActive, remainingTrkId, remainingColor)
    end
  end

  if _G.activeWatchers and _G.activeWatchers.sync and _G.activeWatchers.sync.broadcastNotes then
    _G.activeWatchers.sync.broadcastNotes(noteNum, isNoteOn)
  end
end

local function sendSustainCC(val)
  local dev = getMidiDevice()
  if not dev then return end
  for ch = 0, 15 do
    dev:sendCommand("controlChange", { controllerNumber = 64, controllerValue = val, channel = ch })
  end
end

local function sendMidiCC(controllerNum, val, channel)
  local dev = getMidiDevice()
  if dev then
    dev:sendCommand("controlChange", { controllerNumber = controllerNum, controllerValue = val, channel = channel or 0 })
  end
end

local function panicAllChannels()
  local dev = getMidiDevice()
  clearActiveNotes()
  if not dev then return end

  for ch = 0, 15 do
    -- Release sustain before explicit note-offs; send the channel-mode fallback
    -- after individual releases so synths receive both forms of note cleanup.
    dev:sendCommand("controlChange", { controllerNumber = 64, controllerValue = 0, channel = ch })
    for note = 0, 127 do
      dev:sendCommand("noteOff", { note = note, velocity = 0, channel = ch })
    end
    dev:sendCommand("controlChange", { controllerNumber = 123, controllerValue = 0, channel = ch })
    dev:sendCommand("controlChange", { controllerNumber = 120, controllerValue = 0, channel = ch })
    dev:sendCommand("controlChange", { controllerNumber = 121, controllerValue = 0, channel = ch })
    dev:sendCommand("pitchWheelChange", { pitchChange = 8192, channel = ch })
  end
end

return {
  getMidiDevice = getMidiDevice,
  sendMidiNote = sendMidiNote,
  sendMidiCC = sendMidiCC,
  sendSustainCC = sendSustainCC,
  panicAllChannels = panicAllChannels,
  getActiveNoteLedger = getActiveNoteLedger,
  clearActiveNotes = clearActiveNotes,
  getTrackForChannel = getTrackForChannel
}
