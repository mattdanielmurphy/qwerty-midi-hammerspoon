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

local function sendMidiNote(cmd, noteNum, vel)
  local dev = getMidiDevice()
  if dev then
    dev:sendCommand(cmd, { note = noteNum, velocity = vel, channel = 0 })
  end
end

local function sendMidiCC(controllerNum, val)
  local dev = getMidiDevice()
  if dev then
    dev:sendCommand("controlChange", { controllerNumber = controllerNum, controllerValue = val, channel = 0 })
  end
end

return {
  getMidiDevice = getMidiDevice,
  sendMidiNote = sendMidiNote,
  sendMidiCC = sendMidiCC
}
