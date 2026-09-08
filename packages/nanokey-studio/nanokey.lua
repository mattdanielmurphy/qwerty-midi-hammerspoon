-- packages/nanokey-studio/nanokey.lua
-- Hardware driver and layer manager for Korg nanoKEY Studio in Hammerspoon.

local macros = require("macros")

local nanoKey = {}
local midiDevice = nil
local activeLayer = "base"
local hudRef = nil
local onStateChangeCallback = nil

local SUSTAIN_MACRO_CC = 54 -- User remapped Sustain CC

local function log(msg)
  print("[nanoKEY Studio]: " .. tostring(msg))
end

function nanoKey.setHud(hudInstance)
  hudRef = hudInstance
end

function nanoKey.setOnStateChange(cb)
  onStateChangeCallback = cb
end

function nanoKey.getLayer()
  return activeLayer
end

function nanoKey.setLayer(newLayer)
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

function nanoKey.handleMidiEvent(commandType, description, metadata)
  metadata = metadata or {}
  local cc = metadata.controllerNumber
  local val = metadata.controllerValue
  local note = metadata.noteNumber
  local vel = metadata.velocity

  -- 1. Check for Sustain Macro Key (CC=54)
  if commandType == "controlChange" and cc == SUSTAIN_MACRO_CC then
    if val and val > 0 then
      nanoKey.setLayer("macro")
      if hudRef and hudRef.updateControlState then
        hudRef:updateControlState("btn_sustain", true, true, "macro-active")
      end
    else
      nanoKey.setLayer("base")
      if hudRef and hudRef.updateControlState then
        hudRef:updateControlState("btn_sustain", false, false, nil)
      end
    end
    return true
  end

  -- 2. If in Macro Mode, intercept triggers to run macros
  if activeLayer == "macro" then
    if commandType == "noteOn" and vel and vel > 0 then
      -- Search pad or key macro
      local macroName = nil
      if note >= 36 and note <= 43 then
        local padMacros = {
          [36] = "Play/Pause", [37] = "Record", [38] = "Rewind", [39] = "Forward",
          [40] = "Left Half", [41] = "Right Half", [42] = "Maximize", [43] = "Restore Win"
        }
        macroName = padMacros[note]
      elseif note >= 48 and note <= 72 then
        local keyMacros = {
          [48] = "Preset 1", [49] = "Preset 2", [50] = "Preset 3", [51] = "Preset 4",
          [52] = "Preset 5", [53] = "Preset 6", [54] = "Preset 7", [55] = "Preset 8",
          [56] = "Browser", [57] = "Terminal", [58] = "Editor", [59] = "Logic Pro",
          [60] = "Mute Mic", [61] = "Screenshot", [62] = "Volume -", [63] = "Volume +",
          [64] = "Center Win", [65] = "Prev Track", [66] = "Next Track", [67] = "Undo",
          [68] = "Redo", [69] = "Save Project", [70] = "Export Audio", [71] = "Metronome",
          [72] = "Panic All"
        }
        macroName = keyMacros[note]
      end

      if macroName then
        macros.execute(macroName)
        if hudRef and hudRef.updateControlState then
          hudRef:updateControlState("note_" .. note, true, true, "macro-fired")
        end
        return true
      end
    elseif commandType == "noteOff" or (commandType == "noteOn" and vel == 0) then
      if hudRef and hudRef.updateControlState then
        hudRef:updateControlState("note_" .. note, false, false, nil)
      end
      return true
    end
  end

  -- 3. Live Feedback to HUD during Performance Mode
  if hudRef and hudRef.updateControlState then
    if commandType == "noteOn" and vel and vel > 0 then
      hudRef:updateControlState("note_" .. note, true, true, nil)
    elseif commandType == "noteOff" or (commandType == "noteOn" and vel == 0) then
      hudRef:updateControlState("note_" .. note, false, false, nil)
    elseif commandType == "controlChange" and cc then
      hudRef:updateControlState("cc_" .. cc, true, false, "cc-val-" .. tostring(val))
    end
  end

  return false -- Not consumed, pass through to DAW or music engine
end

function nanoKey.connect(targetName)
  targetName = targetName or "nanoKEY Studio"
  local devices = hs.midi.devices()
  local foundName = nil

  for _, name in ipairs(devices) do
    if string.find(string.lower(name), string.lower(targetName)) then
      foundName = name
      break
    end
  end

  if not foundName then
    log("nanoKEY Studio not detected. Will auto-connect when plugged in.")
    return false
  end

  log("Connecting to: " .. foundName)
  midiDevice = hs.midi.new(foundName)
  if not midiDevice then
    log("Failed to open MIDI port for: " .. foundName)
    return false
  end

  midiDevice:callback(function(obj, devName, cmdType, desc, metadata)
    nanoKey.handleMidiEvent(cmdType, desc, metadata)
  end)

  log("Connected and listening for CC=54 Sustain macro events!")
  return true
end

function nanoKey.disconnect()
  if midiDevice then
    midiDevice = nil
    log("Disconnected.")
  end
end

return nanoKey
