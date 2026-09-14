-- packages/nanokey-studio/nanokey.lua
-- Hardware driver and layer manager for Korg nanoKEY Studio in Hammerspoon.

local macros = require("macros")

local nanoKey = {}
local midiDevice = nil
local activeLayer = "base"
local sustainHeld = false
local sceneHeld = false
local hudRef = nil
local onStateChangeCallback = nil

local function log(msg)
  local line = os.date("%H:%M:%S") .. " [nanoKEY Studio]: " .. tostring(msg)
  print(line)
  local f = io.open("/Users/matt/projects/qwerty-midi-hammerspoon/tmp/qwerty_midi_debug.log", "a")
  if f then
    f:write(line .. "\n")
    f:close()
  end
  local f2 = io.open("/Users/matt/projects/qwerty-midi-hammerspoon/tmp/nanokey_probe.log", "a")
  if f2 then
    f2:write(line .. "\n")
    f2:close()
  end
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

local function computeActiveLayer()
  local prevLayer = activeLayer
  if sustainHeld and sceneHeld then
    activeLayer = "macro_both"
  elseif sustainHeld then
    activeLayer = "macro_sustain"
  elseif sceneHeld then
    activeLayer = "macro_scene"
  else
    activeLayer = "base"
  end

  if activeLayer ~= prevLayer then
    log("Switched active layer to: " .. activeLayer)
    if hudRef and hudRef.updateNanoKeyControl then
      hudRef.updateNanoKeyControl("layer", nil, false, activeLayer, { layer = activeLayer })
    end
    if onStateChangeCallback then
      onStateChangeCallback({ layer = activeLayer, sustainHeld = sustainHeld, sceneHeld = sceneHeld })
    end
  end
end

function nanoKey.setLayer(newLayer)
  if activeLayer ~= newLayer then
    activeLayer = newLayer
    log("Manually set active layer to: " .. activeLayer)
    if hudRef and hudRef.updateNanoKeyControl then
      hudRef.updateNanoKeyControl("layer", nil, false, activeLayer, { layer = activeLayer })
    end
    if onStateChangeCallback then
      onStateChangeCallback({ layer = activeLayer })
    end
  end
end

-- Map pad MIDI note numbers (36..43 standard drum notes) to 1..8
local function noteToPadIndex(note)
  if note and note >= 36 and note <= 43 then
    return note - 35
  end
  return nil
end

local KNOB_NAMES = {
  [1] = "Cutoff",
  [2] = "Peak",
  [3] = "Drive",
  [4] = "Volume",
  [5] = "Attack",
  [6] = "Decay",
  [7] = "Sustain",
  [8] = "Release"
}

-- Adaptive knob base offset (defaults to 16, so CC 17 -> Knob 1, CC 24 -> Knob 8)
local activeKnobOffset = 16

local function resolveKnobIndex(cc)
  if not cc then return nil end
  -- Auto-detect hardware offset:
  if cc == 16 then
    -- Hardware is using 16..23 (offset +2 from 14..21): 16->1, 17->2, ..., 23->8
    activeKnobOffset = 15
    return 1
  elseif cc >= 25 and cc <= 27 then
    -- Hardware is using Korg Gadget factory scene (20..27): 20->1, ..., 27->8
    activeKnobOffset = 19
    return cc - 19
  end

  local idx = cc - activeKnobOffset
  if idx >= 1 and idx <= 8 then
    return idx
  end

  -- Fallback heuristics:
  if cc >= 17 and cc <= 24 then
    return cc - 16
  elseif cc >= 16 and cc <= 23 then
    return cc - 15
  elseif cc >= 20 and cc <= 27 then
    return cc - 19
  elseif cc >= 14 and cc <= 21 then
    return cc - 13
  end
  return nil
end

function nanoKey.handleMidiEvent(commandType, description, metadata)
  metadata = metadata or {}
  local cc = metadata.controllerNumber
  local val = metadata.controllerValue
  local note = metadata.noteNumber
  local vel = metadata.velocity
  local ch = metadata.channel
  local dataHex = metadata.data or ""
  local sysexDataHex = metadata.sysexData or ""

  -- Telemetry logging for all MIDI events
  if commandType == "controlChange" then
    log(string.format("MIDI CC: #%s = %s (ch=%s)", tostring(cc), tostring(val), tostring(ch)))
  elseif commandType == "noteOn" or commandType == "noteOff" then
    log(string.format("MIDI %s: note=%s vel=%s (ch=%s)", commandType, tostring(note), tostring(vel), tostring(ch)))
  elseif commandType == "systemExclusive" then
    log(string.format("MIDI SysEx: len=%d data=%s", #dataHex, dataHex))
  end

  -- 1. Check for Sustain Button (CC #25 default, or CC #54 / CC #64 fallback)
  -- Sustain button is momentary (127 on press, 0 on release), typically on channel 15
  if commandType == "controlChange" and (cc == 25 or cc == 54 or cc == 64) then
    local isMomentary = (val == 0 or val == 127)
    if (cc == 54 or cc == 64) or (cc == 25 and isMomentary) then
      if val and val > 0 then
        sustainHeld = true
        computeActiveLayer()
        if hudRef and hudRef.updateNanoKeyControl then
          hudRef.updateNanoKeyControl("btn_sustain", val, true, activeLayer)
        end
      else
        sustainHeld = false
        computeActiveLayer()
        if hudRef and hudRef.updateNanoKeyControl then
          hudRef.updateNanoKeyControl("btn_sustain", 0, false, activeLayer)
        end
      end
      return true
    end
  end

  -- 2. Check for Scene Button via Native Korg SysEx (f0 42 40 00 01 36 05 00 00 41 40 40 7f/00 00 f7)
  if commandType == "systemExclusive" then
    local fullHex = string.lower(dataHex .. sysexDataHex)
    if string.find(fullHex, "4140407f") then
      sceneHeld = true
      computeActiveLayer()
      if hudRef and hudRef.updateNanoKeyControl then
        hudRef.updateNanoKeyControl("btn_scene", 127, true, activeLayer)
      end
      return true
    elseif string.find(fullHex, "41404000") then
      sceneHeld = false
      computeActiveLayer()
      if hudRef and hudRef.updateNanoKeyControl then
        hudRef.updateNanoKeyControl("btn_scene", 0, false, activeLayer)
      end
      return true
    end
  end

  -- 3. Rotary Knobs (8 knobs labelled by Korg Gadget defaults: Cutoff, Peak, Drive, Volume, ADSR)
  if commandType == "controlChange" and cc then
    local knobIdx = resolveKnobIndex(cc)
    if knobIdx and knobIdx >= 1 and knobIdx <= 8 then
      local knobName = KNOB_NAMES[knobIdx] or ("Knob " .. knobIdx)
      log(string.format("Knob %d [%s] (CC #%d) = %d [offset=%d]", knobIdx, knobName, cc, val or 0, activeKnobOffset))
      if hudRef and hudRef.updateNanoKeyControl then
        hudRef.updateNanoKeyControl("knob_" .. knobIdx, val, true, activeLayer, {
          cc = cc,
          value = val,
          knob = knobIdx,
          name = knobName
        })
      end
      return false
    end
  end

  -- 4. KAOSS Touchpad (Touch X = CC #1 or CC #28; Touch Y = CC #2 or CC #29)
  if commandType == "controlChange" and cc then
    if cc == 1 or cc == 28 or cc == 2 or cc == 29 then
      if hudRef and hudRef.updateNanoKeyControl then
        hudRef.updateNanoKeyControl("cc_" .. cc, val, true, activeLayer, { cc = cc, value = val })
      end
      return false
    end
  end

  -- 5. Pad Triggers (Channel 1 or notes 36..43)
  local padIdx = noteToPadIndex(note)
  if padIdx then
    local isDown = (commandType == "noteOn" and vel and vel > 0)
    local isUp = (commandType == "noteOff" or (commandType == "noteOn" and vel == 0))

    if isDown then
      -- Macro Layer 1: Sustain Held -> Transport & Window Management
      if activeLayer == "macro_sustain" or activeLayer == "macro_both" then
        local padSustainMacros = {
          [1] = "Play/Pause", [2] = "Record", [3] = "Rewind", [4] = "Forward",
          [5] = "Left Half", [6] = "Right Half", [7] = "Maximize", [8] = "Restore Win"
        }
        local mName = padSustainMacros[padIdx]
        if mName then
          macros.execute(mName)
          if hudRef and hudRef.updateNanoKeyControl then
            hudRef.updateNanoKeyControl("pad_" .. padIdx, vel, true, activeLayer, { macro = mName })
          end
          return true
        end
      -- Macro Layer 2: Scene Held -> Presets & System Tools
      elseif activeLayer == "macro_scene" then
        local padSceneMacros = {
          [1] = "Preset 1", [2] = "Preset 2", [3] = "Preset 3", [4] = "Preset 4",
          [5] = "Scale Cycle", [6] = "Browser", [7] = "Logic Pro", [8] = "Panic All"
        }
        local mName = padSceneMacros[padIdx]
        if mName then
          macros.execute(mName)
          if hudRef and hudRef.updateNanoKeyControl then
            hudRef.updateNanoKeyControl("pad_" .. padIdx, vel, true, activeLayer, { macro = mName })
          end
          return true
        end
      else
        -- Base Performance mode pad hit
        if hudRef and hudRef.updateNanoKeyControl then
          hudRef.updateNanoKeyControl("pad_" .. padIdx, vel, true, activeLayer, { note = note, velocity = vel })
        end
        return false
      end
    elseif isUp then
      if hudRef and hudRef.updateNanoKeyControl then
        hudRef.updateNanoKeyControl("pad_" .. padIdx, 0, false, activeLayer, { note = note })
      end
      return (activeLayer ~= "base")
    end
  end

  -- 6. Keyboard Keys (Notes 48 to 72 = C3 to C5, or shifted)
  if note and note >= 24 and note <= 108 then
    local isDown = (commandType == "noteOn" and vel and vel > 0)
    local isUp = (commandType == "noteOff" or (commandType == "noteOn" and vel == 0))

    if isDown then
      -- If Scene is held, keys can also trigger shortcuts
      if activeLayer == "macro_scene" and note >= 48 and note <= 72 then
        local keyMacros = {
          [48] = "Preset 1", [49] = "Preset 2", [50] = "Preset 3", [51] = "Preset 4",
          [52] = "Preset 5", [53] = "Preset 6", [54] = "Preset 7", [55] = "Preset 8",
          [56] = "Browser", [57] = "Terminal", [58] = "Editor", [59] = "Logic Pro",
          [60] = "Mute Mic", [61] = "Screenshot", [62] = "Volume -", [63] = "Volume +",
          [64] = "Center Win", [65] = "Prev Track", [66] = "Next Track", [67] = "Undo",
          [68] = "Redo", [69] = "Save Project", [70] = "Export Audio", [71] = "Metronome",
          [72] = "Panic All"
        }
        local mName = keyMacros[note]
        if mName then
          macros.execute(mName)
          if hudRef and hudRef.updateNanoKeyControl then
            hudRef.updateNanoKeyControl("key_" .. note, vel, true, activeLayer, { macro = mName })
          end
          return true
        end
      end

      -- Base performance key down
      if hudRef and hudRef.updateNanoKeyControl then
        hudRef.updateNanoKeyControl("key_" .. note, vel, true, activeLayer, { note = note, velocity = vel })
      end
      return false
    elseif isUp then
      if hudRef and hudRef.updateNanoKeyControl then
        hudRef.updateNanoKeyControl("key_" .. note, 0, false, activeLayer, { note = note })
      end
      return false
    end
  end

  return false
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
    log("nanoKEY Studio not detected in connected devices. Will auto-connect when plugged in.")
    return false
  end

  if midiDevice and midiDevice:name() == foundName then
    return true
  end

  log("Connecting to: " .. foundName)
  midiDevice = hs.midi.new(foundName)
  if not midiDevice then
    log("Failed to open MIDI port for: " .. foundName)
    return false
  end

  _G.activeWatchers = _G.activeWatchers or {}
  _G.activeWatchers.nanoKeyMidiDevice = midiDevice

  midiDevice:callback(function(obj, devName, cmdType, desc, metadata)
    nanoKey.handleMidiEvent(cmdType, desc, metadata)
  end)

  log("Connected! Listening for nanoKEY Studio performance, CC #25 Sustain, and Scene SysEx.")
  if hudRef and hudRef.updateNanoKeyControl then
    hudRef.updateNanoKeyControl("connection", 1, true, activeLayer, { deviceName = foundName })
  end
  return true
end

function nanoKey.disconnect()
  if midiDevice then
    _G.activeWatchers = _G.activeWatchers or {}
    _G.activeWatchers.nanoKeyMidiDevice = nil
    midiDevice = nil
    log("Disconnected.")
    if hudRef and hudRef.updateNanoKeyControl then
      hudRef.updateNanoKeyControl("connection", 0, false, activeLayer, { deviceName = nil })
    end
  end
end

function nanoKey.isConnected()
  return midiDevice ~= nil
end

-- Auto-reconnect watcher
_G.activeWatchers = _G.activeWatchers or {}
_G.activeWatchers.nanokeyDeviceWatcher = hs.midi.deviceCallback(function(devName, hasConnected)
  if devName and string.find(string.lower(devName), "nanokey") then
    if hasConnected then
      log("Hardware connected: " .. devName)
      nanoKey.connect(devName)
    else
      log("Hardware disconnected: " .. devName)
      nanoKey.disconnect()
    end
  end
end)

return nanoKey
