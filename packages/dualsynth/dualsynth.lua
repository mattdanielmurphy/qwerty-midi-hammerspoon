-- packages/dualsynth/dualsynth.lua
-- Hammerspoon bridge driver for DualSynth (PS5 DualSense via GameController.framework & CoreMIDI)

local dualSynth = {}
local midiDevice = nil
local activeLayer = "base"
local hudRef = nil
local onStateChangeCallback = nil

local VIRTUAL_DEVICE_NAME = "DualSynth Virtual Out"

local function log(msg)
  print("[DualSynth]: " .. tostring(msg))
end

function dualSynth.setHud(hudInstance)
  hudRef = hudInstance
end

function dualSynth.setOnStateChange(cb)
  onStateChangeCallback = cb
end

function dualSynth.getLayer()
  return activeLayer
end

function dualSynth.setLayer(newLayer)
  if activeLayer ~= newLayer then
    activeLayer = newLayer
    log("Switched active layer to: " .. activeLayer)
    if hudRef and hudRef.setLayer then
      hudRef:setLayer(activeLayer)
    end
    if onStateChangeCallback then
      onStateChangeCallback({ layer = activeLayer })
    end
  end
end

function dualSynth.handleMidiEvent(commandType, description, metadata)
  metadata = metadata or {}
  local cc = metadata.controllerNumber
  local val = metadata.controllerValue
  local note = metadata.noteNumber
  local vel = metadata.velocity

  if commandType == "noteOn" and vel and vel > 0 then
    log(string.format("Note ON: %d (Vel: %d)", note, vel))
    if hudRef and hudRef.updateKeyTrigger then
      hudRef:updateKeyTrigger(note, true, vel)
    end
  elseif commandType == "noteOff" or (commandType == "noteOn" and vel == 0) then
    log(string.format("Note OFF: %d", note))
    if hudRef and hudRef.updateKeyTrigger then
      hudRef:updateKeyTrigger(note, false, 0)
    end
  elseif commandType == "controlChange" then
    log(string.format("CC #%d: %d", cc, val))
  end
end

function dualSynth.connect(name)
  name = name or VIRTUAL_DEVICE_NAME
  local devices = hs.midi.devices()
  local found = false

  for _, devName in ipairs(devices) do
    if string.find(devName, name, 1, true) then
      found = true
      break
    end
  end

  if not found then
    log("Virtual CoreMIDI endpoint '" .. name .. "' not found. Is dualsynth-cli running?")
    return false
  end

  if midiDevice then
    dualSynth.disconnect()
  end

  midiDevice = hs.midi.new(name)
  if midiDevice then
    midiDevice:callback(function(object, devName, commandType, description, metadata)
      dualSynth.handleMidiEvent(commandType, description, metadata)
    end)
    log("Connected to " .. name)
    return true
  end

  return false
end

function dualSynth.disconnect()
  if midiDevice then
    midiDevice:callback(nil)
    midiDevice = nil
    log("Disconnected")
  end
end

function dualSynth.isConnected()
  return midiDevice ~= nil
end

return dualSynth
