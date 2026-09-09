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

local function sendMidiNote(cmd, noteNum, vel, channel)
  if type(noteNum) == "table" then
    channel = channel or noteNum.channel
    noteNum = noteNum.pitch
  end
  if not noteNum or type(noteNum) ~= "number" or noteNum < 0 or noteNum > 127 then return end
  local dev = getMidiDevice()
  if dev then
    local ch = channel or 0
    if cmd == "noteOff" or (cmd == "noteOn" and vel == 0) then
      dev:sendCommand("noteOff", { note = noteNum, velocity = 0, channel = ch })
      dev:sendCommand("noteOn", { note = noteNum, velocity = 0, channel = ch })
    else
      dev:sendCommand("noteOn", { note = noteNum, velocity = vel, channel = ch })
    end
  end

  if _G.activeWatchers and _G.activeWatchers.sync and _G.activeWatchers.sync.broadcastNotes then
    local isNoteOn = (cmd == "noteOn" and (vel or 0) > 0)
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
  if not dev then return end

  for ch = 0, 15 do
    -- Turn off sustain, all sound, all notes, and reset controllers across all channels
    dev:sendCommand("controlChange", { controllerNumber = 64, controllerValue = 0, channel = ch })
    dev:sendCommand("controlChange", { controllerNumber = 120, controllerValue = 0, channel = ch })
    dev:sendCommand("controlChange", { controllerNumber = 123, controllerValue = 0, channel = ch })
    dev:sendCommand("controlChange", { controllerNumber = 121, controllerValue = 0, channel = ch })
    -- Send Note Off for all 128 pitches on each channel to ensure synths ignore/bypass CC #64 or CC #123 release held notes
    for note = 0, 127 do
      dev:sendCommand("noteOff", { note = note, velocity = 0, channel = ch })
    end
  end
end

return {
  getMidiDevice = getMidiDevice,
  sendMidiNote = sendMidiNote,
  sendMidiCC = sendMidiCC,
  sendSustainCC = sendSustainCC,
  panicAllChannels = panicAllChannels
}

