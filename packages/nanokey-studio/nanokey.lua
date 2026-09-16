local macros = require("macros")
local midi = nil
pcall(function() midi = require("midi") end)
local harmony = nil
pcall(function() harmony = require("harmony") end)
local quantizer = nil
pcall(function() quantizer = require("quantizer") end)
local config = nil
pcall(function() config = require("config") end)

local nanoKey = {}
local midiDevice = nil
local activeLayer = "base"
local sustainHeld = false
local sceneHeld = false
local hudRef = nil
local onStateChangeCallback = nil
local activePadChords = {}


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

-- Map pad MIDI note numbers:
-- Pre-assigned Korg nanoKEY Studio hardware Pad map:
-- Row 1 (Top: Pads 1..4): Arp Type (43), Arp Range (48), Key Sync (50), Wireless (49)
-- Row 2 (Bottom: Pads 5..8): Gate Type - (36), Gate Type + (38), Scale - (42), Scale + (46)
local KORG_KONTROL_PAD_MAP = {
  [43] = 1, [48] = 2, [50] = 3, [49] = 4,
  [36] = 5, [38] = 6, [42] = 7, [46] = 8
}

local function noteToPadIndex(note, ch)
  if not note then return nil end
  -- Channel 1 (ch = 0) is strictly reserved for keyboard keys — NEVER trigger pads via note
  if ch == 0 then return nil end

  if ch == 9 or ch == 1 then
    if KORG_KONTROL_PAD_MAP[note] then
      return KORG_KONTROL_PAD_MAP[note]
    elseif note >= 36 and note <= 43 then
      return note - 35
    elseif note >= 64 and note <= 71 then
      return note - 63
    end
  end
  return nil
end

-- Support CC-mapped pads on any channel (including Global / Channel 1):
-- Hardware pre-assigned CCs: 43 (Pad 1), 48 (Pad 2), 50 (Pad 3), 49 (Pad 4),
--                            36 (Pad 5), 38 (Pad 6), 42 (Pad 7), 46 (Pad 8)
-- Contiguous fallback ranges: CC 80..87, CC 102..109, CC 112..119
local function ccToPadIndex(cc)
  if not cc then return nil end
  if KORG_KONTROL_PAD_MAP[cc] then
    return KORG_KONTROL_PAD_MAP[cc]
  end
  if cc >= 80 and cc <= 87 then
    return cc - 79
  elseif cc >= 102 and cc <= 109 then
    return cc - 101
  elseif cc >= 112 and cc <= 119 then
    return cc - 111
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

-- Pre-assigned knob base offset: CC 20..27 (20->Knob 1 .. 27->Knob 8)
local activeKnobOffset = 19

local function resolveKnobIndex(cc)
  if not cc or cc == 19 then return nil end
  -- Pre-assigned hardware default (CC 20..27):
  if cc >= 20 and cc <= 27 then
    activeKnobOffset = 19
    return cc - 19
  end

  -- Auto-detect alternative hardware offsets if explicitly using them:
  if cc >= 16 and cc <= 18 then
    activeKnobOffset = 15
    return cc - 15
  elseif cc >= 14 and cc <= 15 then
    activeKnobOffset = 13
    return cc - 13
  end

  local idx = cc - activeKnobOffset
  if idx >= 1 and idx <= 8 then
    return idx
  end
  return nil
end

function nanoKey.handleMidiEvent(commandType, description, metadata)
  metadata = metadata or {}
  local cc = metadata.controllerNumber
  local val = metadata.controllerValue or metadata.value or 0
  local note = metadata.note or metadata.noteNumber or metadata.pitch
  local vel = metadata.velocity or 0
  local ch = metadata.channel or 0
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

  -- 1. Check for Sustain Button (CC #64 pre-assigned/standard, or CC #54 fallback, or CC #25 on channel 15)
  -- Sustain button is momentary (127 on press, 0 on release). CC #64 avoids collision with Knob 6 (CC #25).
  if commandType == "controlChange" and (cc == 64 or cc == 54 or (cc == 25 and ch == 15 and (val == 0 or val == 127))) then
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

  -- 2. Check for Scene Button and Function Buttons via Native Korg SysEx (f0 42 40 00 01 36 05 00 00 41 ...)
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
    elseif string.find(fullHex, "414001") then
      log("SysEx Native Button: Octave Up / Scale Increment (+1)")
      if hudRef and hudRef.updateNanoKeyControl then
        hudRef.updateNanoKeyControl("btn_oct_up", 127, true, activeLayer)
      end
      return true
    elseif string.find(fullHex, "414000") then
      log("SysEx Native Button: Octave Down / Scale Decrement (-1)")
      if hudRef and hudRef.updateNanoKeyControl then
        hudRef.updateNanoKeyControl("btn_oct_down", 127, true, activeLayer)
      end
      return true
    end
  end

  -- 3. KAOSS Touchpad (Touch X = CC #1 or CC #28; Touch Y = CC #19 or CC #2 or CC #29)
  if commandType == "controlChange" and cc then
    if cc == 1 or cc == 28 or cc == 19 or cc == 2 or cc == 29 then
      if hudRef and hudRef.updateNanoKeyControl then
        hudRef.updateNanoKeyControl("cc_" .. cc, val, true, activeLayer, { cc = cc, value = val })
      end
      return false
    end
  end

  -- 4. Rotary Knobs (8 knobs labelled by Korg Gadget defaults: Cutoff, Peak, Drive, Volume, ADSR)
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

  -- 5. Pad Triggers (Control Change on any channel e.g. CC 80..87, or Note on Ch 2 / Ch 10)
  local padIdx = nil
  local isDown = false
  local isUp = false
  local padVel = 100

  if commandType == "controlChange" and cc then
    padIdx = ccToPadIndex(cc)
    if padIdx then
      isDown = (val and val > 0)
      isUp = (val == 0 or val == nil)
      padVel = (val and val > 0) and val or 100
    end
  elseif (commandType == "noteOn" or commandType == "noteOff") and note then
    padIdx = noteToPadIndex(note, ch)
    if padIdx then
      isDown = (commandType == "noteOn" and vel and vel > 0)
      isUp = (commandType == "noteOff" or (commandType == "noteOn" and vel == 0))
      padVel = vel or 100
    end
  end

  if padIdx then
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
            hudRef.updateNanoKeyControl("pad_" .. padIdx, padVel, true, activeLayer, { macro = mName, cc = cc, note = note })
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
            hudRef.updateNanoKeyControl("pad_" .. padIdx, padVel, true, activeLayer, { macro = mName, cc = cc, note = note })
          end
          return true
        end
      else
        -- Base Performance mode pad hit: Send Diatonic Chord to MIDI output
        local st = config and config.state or {}
        local chordInfo = harmony and harmony.getDiatonicPadChord(padIdx, st) or { pitches = { 48, 52, 55 }, name = "Chord " .. padIdx, roman = "I" }
        local ch = st.bottomRowChannel or 0
        local bpm = st.arpBpm or 120.0
        local quantMode = st.inputQuantizeMode or "Off"

        activePadChords[padIdx] = { pitches = chordInfo.pitches, channel = ch }

        if quantizer and quantMode and quantMode ~= "Off" and quantMode ~= "None" then
          quantizer.queueNoteOn("nk_pad_" .. padIdx, chordInfo.pitches, padVel, ch, bpm, quantMode, function(pitches, vel, channel)
            if midi then
              for _, p in ipairs(pitches) do
                midi.sendMidiNote("noteOn", p, vel, channel)
              end
            end
            if hudRef and hudRef.updateNanoKeyControl then
              for _, p in ipairs(pitches) do
                hudRef.updateNanoKeyControl("key_" .. p, vel, true, activeLayer, { fromPad = padIdx })
              end
            end
          end)
        else
          if midi then
            for _, p in ipairs(chordInfo.pitches) do
              midi.sendMidiNote("noteOn", p, padVel, ch)
            end
          end
          if hudRef and hudRef.updateNanoKeyControl then
            for _, p in ipairs(chordInfo.pitches) do
              hudRef.updateNanoKeyControl("key_" .. p, padVel, true, activeLayer, { fromPad = padIdx })
            end
          end
        end

        if hudRef and hudRef.updateNanoKeyControl then
          hudRef.updateNanoKeyControl("pad_" .. padIdx, padVel, true, activeLayer, {
            note = note,
            cc = cc,
            velocity = padVel,
            chord = chordInfo.name,
            roman = chordInfo.roman,
            pitches = chordInfo.pitches
          })
        end
      end
      return true
    elseif isUp then
      if activeLayer == "base" then
        local saved = activePadChords[padIdx]
        local pitchesToRelease = saved and saved.pitches or {}
        local ch = saved and saved.channel or (config and config.state and config.state.bottomRowChannel or 0)
        local st = config and config.state or {}
        local quantMode = st.inputQuantizeMode or "Off"

        if quantizer and quantMode and quantMode ~= "Off" and quantMode ~= "None" then
          quantizer.queueNoteOff("nk_pad_" .. padIdx, function(pitches, channel)
            if midi then
              for _, p in ipairs(pitches) do
                midi.sendMidiNote("noteOff", p, 0, channel)
              end
            end
            if hudRef and hudRef.updateNanoKeyControl then
              for _, p in ipairs(pitches) do
                hudRef.updateNanoKeyControl("key_" .. p, 0, false, activeLayer, { fromPad = padIdx })
              end
            end
          end)
        else
          if midi then
            for _, p in ipairs(pitchesToRelease) do
              midi.sendMidiNote("noteOff", p, 0, ch)
            end
          end
          if hudRef and hudRef.updateNanoKeyControl then
            for _, p in ipairs(pitchesToRelease) do
              hudRef.updateNanoKeyControl("key_" .. p, 0, false, activeLayer, { fromPad = padIdx })
            end
          end
        end
        activePadChords[padIdx] = nil
      end

      if hudRef and hudRef.updateNanoKeyControl then
        hudRef.updateNanoKeyControl("pad_" .. padIdx, 0, false, activeLayer, { note = note, cc = cc })
      end
      return true
    end
  end

  -- 6. Keyboard Keys on Channel 1 (ch == 0, Notes 24 to 108 = C1 to C8, octave-folded in GUI)
  if ch == 0 and note and note >= 24 and note <= 108 then
    local isDown = (commandType == "noteOn" and vel and vel > 0)
    local isUp = (commandType == "noteOff" or (commandType == "noteOn" and vel == 0))

    if isDown then
      -- If Scene is held, keys can also trigger shortcuts
      if activeLayer == "macro_scene" then
        local macroNote = note
        while macroNote < 48 do macroNote = macroNote + 12 end
        while macroNote > 72 do macroNote = macroNote - 12 end
        local keyMacros = {
          [48] = "Preset 1", [49] = "Preset 2", [50] = "Preset 3", [51] = "Preset 4",
          [52] = "Preset 5", [53] = "Preset 6", [54] = "Preset 7", [55] = "Preset 8",
          [56] = "Browser", [57] = "Terminal", [58] = "Editor", [59] = "Logic Pro",
          [60] = "Mute Mic", [61] = "Screenshot", [62] = "Volume -", [63] = "Volume +",
          [64] = "Center Win", [65] = "Prev Track", [66] = "Next Track", [67] = "Undo",
          [68] = "Redo", [69] = "Save Project", [70] = "Export Audio", [71] = "Metronome",
          [72] = "Panic All"
        }
        local mName = keyMacros[macroNote]
        if mName then
          macros.execute(mName)
          if hudRef and hudRef.updateNanoKeyControl then
            hudRef.updateNanoKeyControl("key_" .. note, vel, true, activeLayer, { macro = mName })
          end
          return true
        end
      end

      -- Base performance key down
      local st = config and config.state or {}
      local quantMode = st.inputQuantizeMode or "Off"

      if quantMode and quantMode ~= "Off" and quantMode ~= "None" and quantizer then
        local bpm = st.arpBpm or 120.0
        quantizer.queueNoteOn("nk_key_" .. note, { note }, vel, ch, bpm, quantMode, function(pitches, v, c)
          if midi then
            midi.sendMidiNote("noteOn", pitches[1], v, c)
          end
          if hudRef and hudRef.updateNanoKeyControl then
            hudRef.updateNanoKeyControl("key_" .. pitches[1], v, true, activeLayer, { note = pitches[1], velocity = v })
          end
        end)
        return true -- Intercept hardware note to fire quantized on beat
      else
        if hudRef and hudRef.updateNanoKeyControl then
          hudRef.updateNanoKeyControl("key_" .. note, vel, true, activeLayer, { note = note, velocity = vel })
        end
        return false -- Native hardware pass-through
      end
    elseif isUp then
      local st = config and config.state or {}
      local quantMode = st.inputQuantizeMode or "Off"

      if quantMode and quantMode ~= "Off" and quantMode ~= "None" and quantizer then
        quantizer.queueNoteOff("nk_key_" .. note, function(pitches, c)
          if midi then
            midi.sendMidiNote("noteOff", pitches[1], 0, c)
          end
          if hudRef and hudRef.updateNanoKeyControl then
            hudRef.updateNanoKeyControl("key_" .. pitches[1], 0, false, activeLayer, { note = pitches[1] })
          end
        end)
        return true
      else
        if hudRef and hudRef.updateNanoKeyControl then
          hudRef.updateNanoKeyControl("key_" .. note, 0, false, activeLayer, { note = note })
        end
        return false
      end
    end
  end

  return false
end

function nanoKey.handleGuiAction(actionType, data)
  data = data or {}
  if actionType == "key" then
    local note = tonumber(data.note)
    local isDown = (data.pressed == true)
    if note and midi then
      midi.sendMidiNote(isDown and "noteOn" or "noteOff", note, isDown and 100 or 0, 0)
    end
    if hudRef and hudRef.updateNanoKeyControl and note then
      hudRef.updateNanoKeyControl("key_" .. note, isDown and 100 or 0, isDown, activeLayer, { note = note })
    end
  elseif actionType == "pad" then
    local padIdx = tonumber(data.pad)
    local isDown = (data.pressed == true)
    if padIdx and padIdx >= 1 and padIdx <= 8 then
      if isDown then
        if activeLayer == "macro_sustain" or activeLayer == "macro_both" then
          local padSustainMacros = {
            [1] = "Play/Pause", [2] = "Record", [3] = "Rewind", [4] = "Forward",
            [5] = "Left Half", [6] = "Right Half", [7] = "Maximize", [8] = "Restore Win"
          }
          local mName = padSustainMacros[padIdx]
          if mName then macros.execute(mName) end
        elseif activeLayer == "macro_scene" then
          local padSceneMacros = {
            [1] = "Preset 1", [2] = "Preset 2", [3] = "Preset 3", [4] = "Preset 4",
            [5] = "Scale Cycle", [6] = "Browser", [7] = "Logic Pro", [8] = "Panic All"
          }
          local mName = padSceneMacros[padIdx]
          if mName then macros.execute(mName) end
        else
          local st = config and config.state or {}
          local chordInfo = harmony and harmony.getDiatonicPadChord(padIdx, st) or { pitches = { 48, 52, 55 }, name = "Chord " .. padIdx, roman = "I" }
          local ch = st.bottomRowChannel or 0
          activePadChords[padIdx] = { pitches = chordInfo.pitches, channel = ch }
          if midi then
            for _, p in ipairs(chordInfo.pitches) do
              midi.sendMidiNote("noteOn", p, 100, ch)
            end
          end
          if hudRef and hudRef.updateNanoKeyControl then
            for _, p in ipairs(chordInfo.pitches) do
              hudRef.updateNanoKeyControl("key_" .. p, 100, true, activeLayer, { fromPad = padIdx })
            end
          end
        end
      else
        if activeLayer == "base" then
          local saved = activePadChords[padIdx]
          local pitchesToRelease = saved and saved.pitches or {}
          local ch = saved and saved.channel or (config and config.state and config.state.bottomRowChannel or 0)
          if midi then
            for _, p in ipairs(pitchesToRelease) do
              midi.sendMidiNote("noteOff", p, 0, ch)
            end
          end
          if hudRef and hudRef.updateNanoKeyControl then
            for _, p in ipairs(pitchesToRelease) do
              hudRef.updateNanoKeyControl("key_" .. p, 0, false, activeLayer, { fromPad = padIdx })
            end
          end
          activePadChords[padIdx] = nil
        end
      end
      if hudRef and hudRef.updateNanoKeyControl then
        hudRef.updateNanoKeyControl("pad_" .. padIdx, isDown and 100 or 0, isDown, activeLayer)
      end
    end
  elseif actionType == "sustain" then
    if data.toggle then
      sustainHeld = not sustainHeld
    elseif data.pressed ~= nil then
      sustainHeld = (data.pressed == true)
    end
    computeActiveLayer()
    if midi then
      midi.sendSustainCC(sustainHeld and 127 or 0)
    end
    if hudRef and hudRef.updateNanoKeyControl then
      hudRef.updateNanoKeyControl("btn_sustain", sustainHeld and 127 or 0, sustainHeld, activeLayer)
    end
  elseif actionType == "scene" then
    if data.toggle then
      sceneHeld = not sceneHeld
    elseif data.pressed ~= nil then
      sceneHeld = (data.pressed == true)
    end
    computeActiveLayer()
    if hudRef and hudRef.updateNanoKeyControl then
      hudRef.updateNanoKeyControl("btn_scene", sceneHeld and 127 or 0, sceneHeld, activeLayer)
    end
  elseif actionType == "guide" then
    local st = config and config.state or {}
    if data.toggle then
      st.scaleGuideEnabled = not st.scaleGuideEnabled
    elseif data.enabled ~= nil then
      st.scaleGuideEnabled = (data.enabled == true)
    end
    if config and config.saveSettings then config.saveSettings() end
    nanoKey.syncScaleGuideLeds(st, true)
    if hudRef and hudRef.updateNanoKeyControl then
      hudRef.updateNanoKeyControl("btn_guide", st.scaleGuideEnabled and 127 or 0, st.scaleGuideEnabled, activeLayer)
    end
  end
end

local lastLitScalePitches = {}

function nanoKey.syncScaleGuideLeds(st, force)
  st = st or (config and config.state) or {}
  if not midiDevice then return end

  local enabled = st.scaleGuideEnabled ~= false
  local root = st.currentRoot or 0
  local scaleIdx = st.currentScaleIdx or 1

  if not enabled then
    for p, _ in pairs(lastLitScalePitches) do
      pcall(function()
        midiDevice:sendCommand("noteOff", { note = tonumber(p), velocity = 0, channel = 0 })
      end)
    end
    lastLitScalePitches = {}
    return
  end

  local guideInfo = harmony and harmony.getScaleGuideInfo and harmony.getScaleGuideInfo(root, scaleIdx, 48, 72)
  if not guideInfo or not guideInfo.pitches then return end

  local newLitPitches = {}
  for pStr, info in pairs(guideInfo.pitches) do
    local p = tonumber(pStr)
    if info.inScale then
      newLitPitches[p] = true
      if force or not lastLitScalePitches[p] then
        pcall(function()
          midiDevice:sendCommand("noteOn", { note = p, velocity = 127, channel = 0 })
        end)
      end
    else
      if lastLitScalePitches[p] then
        pcall(function()
          midiDevice:sendCommand("noteOff", { note = p, velocity = 0, channel = 0 })
        end)
      end
    end
  end
  lastLitScalePitches = newLitPitches
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
  nanoKey.syncScaleGuideLeds(nil, true)
  if hudRef and hudRef.updateNanoKeyControl then
    hudRef.updateNanoKeyControl("connection", 1, true, activeLayer, { deviceName = foundName })
  end
  return true
end

function nanoKey.disconnect()
  if midiDevice then
    nanoKey.syncScaleGuideLeds({ scaleGuideEnabled = false }, true)
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

function nanoKey.enableNativeMode()
  if midiDevice and midiDevice.sendSysex then
    log("Sending Korg Native Mode SysEx Handshake...")
    midiDevice:sendSysex("f07e7f0601f7")
    hs.timer.doAfter(0.1, function()
      if midiDevice and midiDevice.sendSysex then
        midiDevice:sendSysex("f0424000013601000012f7")
      end
    end)
    hs.timer.doAfter(0.25, function()
      if midiDevice and midiDevice.sendSysex then
        midiDevice:sendSysex("f042400001360200000001f7")
        log("Native Mode SysEx Handshake dispatched.")
      end
    end)
    return true
  end
  return false
end

function nanoKey.disableNativeMode()
  if midiDevice and midiDevice.sendSysex then
    midiDevice:sendSysex("f042400001360200000000f7")
    log("Restored factory normal mode.")
    return true
  end
  return false
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
