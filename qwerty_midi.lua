-- ~/.hammerspoon/modules/qwerty_midi.lua
-- QWERTY Keyboard MIDI Controller module for Hammerspoon
-- Visual Layout: Interactive On-Screen Piano & CC Dashboard HUD
--
-- ── Global Anchoring Convention ─────────────────────────────────────────────────
-- All persistent watchers, event taps, hotkeys, and canvas elements are anchored
-- to `_G.activeWatchers` so Lua's garbage collector never reclaims them.
-- ────────────────────────────────────────────────────────────────────────────────

local hsMidi = require("hs.midi")
local hsCanvas = require("hs.canvas")

_G.activeWatchers = _G.activeWatchers or {}

local midiActive = false

-- Connect to IAC Driver destination endpoint or first available physical/virtual destination
local function getMidiDevice()
  if activeWatchers.midiDevice then return activeWatchers.midiDevice end

  local devices = hsMidi.devices() or {}
  local virtualSources = hsMidi.virtualSources() or {}

  for _, devName in ipairs(devices) do
    if string.find(devName, "IAC") or string.find(devName, "Bus") then
      activeWatchers.midiDevice = hsMidi.new(devName)
      return activeWatchers.midiDevice
    end
  end

  for _, devName in ipairs(virtualSources) do
    if string.find(devName, "IAC") or string.find(devName, "Bus") then
      activeWatchers.midiDevice = hsMidi.newVirtualSource(devName)
      return activeWatchers.midiDevice
    end
  end

  if #devices > 0 then
    activeWatchers.midiDevice = hsMidi.new(devices[1])
  elseif #virtualSources > 0 then
    activeWatchers.midiDevice = hsMidi.newVirtualSource(virtualSources[1])
  end

  return activeWatchers.midiDevice
end

-- Keycode mappings with explicit row, key label, note name, and canvas element index
-- Home Row: Base Octave (C4 = 60 to E5 = 76)
local homeRowKeys = {
  [0]  = { key = "A", name = "C4", note = 60 },
  [1]  = { key = "S", name = "D4", note = 62 },
  [2]  = { key = "D", name = "E4", note = 64 },
  [3]  = { key = "F", name = "F4", note = 65 },
  [5]  = { key = "G", name = "G4", note = 67 },
  [4]  = { key = "H", name = "A4", note = 69 },
  [38] = { key = "J", name = "B4", note = 71 },
  [40] = { key = "K", name = "C5", note = 72 },
  [37] = { key = "L", name = "D5", note = 74 },
  [41] = { key = ";", name = "E5", note = 76 }
}

-- Upper Row: +2 Octaves (C6 = 84 to E7 = 100)
local upperRowKeys = {
  [12] = { key = "Q", name = "C6", note = 84 },
  [13] = { key = "W", name = "D6", note = 86 },
  [14] = { key = "E", name = "E6", note = 88 },
  [15] = { key = "R", name = "F6", note = 89 },
  [17] = { key = "T", name = "G6", note = 91 },
  [16] = { key = "Y", name = "A6", note = 93 },
  [32] = { key = "U", name = "B6", note = 95 },
  [34] = { key = "I", name = "C7", note = 96 },
  [31] = { key = "O", name = "D7", note = 98 },
  [35] = { key = "P", name = "E7", note = 100 }
}

-- Bottom Row: MIDI Control Change (CC) messages
-- Z = Momentary Sustain (CC64 127 on down / 0 on release)
-- X & C = Mod Wheel Adjust (X decreases CC1, C increases CC1)
-- V & B = Volume Adjust (V decreases CC7, B increases CC7)
local bottomRowCC = {
  [6] = { key = "Z", name = "Sustain", type = "momentary", controller = 64, onVal = 127, offVal = 0 },
  [7] = { key = "X", name = "Mod -",   type = "step",      controller = 1,  step = -16 },
  [8] = { key = "C", name = "Mod +",   type = "step",      controller = 1,  step = 16 },
  [9] = { key = "V", name = "Vol -",   type = "step",      controller = 7,  step = -16 },
  [11]= { key = "B", name = "Vol +",   type = "step",      controller = 7,  step = 16 }
}

-- Active continuous state values (0 - 127)
local ccStates = {
  [1] = 0,   -- Mod Wheel default 0
  [7] = 100  -- Volume default 100
}

-- Pressed key state map and canvas element reference map
local pressedKeys = {}
local keyElementMap = {}

-- ── Canvas HUD Creation ─────────────────────────────────────────────────────────

local function createMidiHud()
  if activeWatchers.midiCanvas then
    activeWatchers.midiCanvas:delete()
    activeWatchers.midiCanvas = nil
  end

  keyElementMap = {}

  local screen = hs.screen.mainScreen():frame()
  local width = 640
  local height = 240
  local rect = {
    x = (screen.w - width) / 2,
    y = screen.h - height - 60,
    w = width,
    h = height
  }

  local canvas = hsCanvas.new(rect)
  canvas:level(hsCanvas.windowLevels.floating)
  canvas:behavior(hsCanvas.windowBehaviors.canJoinAllSpaces)

  local elemIdx = 0

  -- 1: Background Glassmorphism Panel
  elemIdx = elemIdx + 1
  canvas[elemIdx] = {
    type = "rectangle",
    action = "fill",
    fillColor = { red = 0.07, green = 0.08, blue = 0.12, alpha = 0.94 },
    roundedRectRadii = { xRadius = 16, yRadius = 16 }
  }

  -- 2: Outer Border
  elemIdx = elemIdx + 1
  canvas[elemIdx] = {
    type = "rectangle",
    action = "stroke",
    strokeColor = { red = 0.25, green = 0.35, blue = 0.50, alpha = 0.6 },
    strokeWidth = 1.5,
    roundedRectRadii = { xRadius = 16, yRadius = 16 }
  }

  -- 3: Header Badge Background
  elemIdx = elemIdx + 1
  canvas[elemIdx] = {
    type = "rectangle",
    action = "fill",
    fillColor = { red = 0.12, green = 0.16, blue = 0.24, alpha = 0.8 },
    frame = { x = 16, y = 14, w = width - 32, h = 32 },
    roundedRectRadii = { xRadius = 8, yRadius = 8 }
  }

  -- 4: Header Title Text
  elemIdx = elemIdx + 1
  canvas[elemIdx] = {
    type = "text",
    text = "🎹 QWERTY MIDI CONTROLLER",
    textColor = { red = 0.40, green = 0.75, blue = 1.0, alpha = 1.0 },
    textFont = ".AppleSystemUIFontBold",
    textSize = 13,
    textAlignment = "left",
    frame = { x = 28, y = 21, w = 260, h = 20 }
  }

  -- 5: Mode Indicator & Endpoint Text
  local dev = getMidiDevice()
  local devName = dev and dev:name() or "IAC Driver"
  elemIdx = elemIdx + 1
  canvas[elemIdx] = {
    type = "text",
    text = "ACTIVE  •  " .. devName,
    textColor = { red = 0.3, green = 0.85, blue = 0.5, alpha = 1.0 },
    textFont = ".AppleSystemUIFontSemibold",
    textSize = 12,
    textAlignment = "right",
    frame = { x = width - 320, y = 21, w = 292, h = 20 }
  }

  -- ── UPPER ROW (+2 OCTAVES) KEY PADS ──────────────────────────────────────────
  local upperKeysOrder = { 12, 13, 14, 15, 17, 16, 32, 34, 31, 35 }
  local startX = 20
  local padW = 54
  local padH = 42
  local gap = 6
  local upperY = 56

  for i, code in ipairs(upperKeysOrder) do
    local kData = upperRowKeys[code]
    local xPos = startX + (i - 1) * (padW + gap)

    elemIdx = elemIdx + 1
    local bgIdx = elemIdx
    canvas[bgIdx] = {
      type = "rectangle",
      action = "fill",
      fillColor = { red = 0.14, green = 0.18, blue = 0.26, alpha = 0.9 },
      frame = { x = xPos, y = upperY, w = padW, h = padH },
      roundedRectRadii = { xRadius = 6, yRadius = 6 }
    }

    elemIdx = elemIdx + 1
    local strokeIdx = elemIdx
    canvas[strokeIdx] = {
      type = "rectangle",
      action = "stroke",
      strokeColor = { red = 0.28, green = 0.35, blue = 0.48, alpha = 0.5 },
      strokeWidth = 1,
      frame = { x = xPos, y = upperY, w = padW, h = padH },
      roundedRectRadii = { xRadius = 6, yRadius = 6 }
    }

    elemIdx = elemIdx + 1
    canvas[elemIdx] = {
      type = "text",
      text = kData.key,
      textColor = { red = 0.9, green = 0.95, blue = 1.0, alpha = 0.9 },
      textFont = ".AppleSystemUIFontBold",
      textSize = 13,
      textAlignment = "center",
      frame = { x = xPos, y = upperY + 6, w = padW, h = 18 }
    }

    elemIdx = elemIdx + 1
    canvas[elemIdx] = {
      type = "text",
      text = kData.name,
      textColor = { red = 0.4, green = 0.65, blue = 0.9, alpha = 0.8 },
      textFont = ".AppleSystemUIFont",
      textSize = 10,
      textAlignment = "center",
      frame = { x = xPos, y = upperY + 24, w = padW, h = 14 }
    }

    keyElementMap[code] = { bg = bgIdx, stroke = strokeIdx }
  end

  -- ── HOME ROW (BASE OCTAVE) KEY PADS ──────────────────────────────────────────
  local homeKeysOrder = { 0, 1, 2, 3, 5, 4, 38, 40, 37, 41 }
  local homeY = 106

  for i, code in ipairs(homeKeysOrder) do
    local kData = homeRowKeys[code]
    local xPos = startX + (i - 1) * (padW + gap)

    elemIdx = elemIdx + 1
    local bgIdx = elemIdx
    canvas[bgIdx] = {
      type = "rectangle",
      action = "fill",
      fillColor = { red = 0.18, green = 0.22, blue = 0.32, alpha = 0.9 },
      frame = { x = xPos, y = homeY, w = padW, h = padH },
      roundedRectRadii = { xRadius = 6, yRadius = 6 }
    }

    elemIdx = elemIdx + 1
    local strokeIdx = elemIdx
    canvas[strokeIdx] = {
      type = "rectangle",
      action = "stroke",
      strokeColor = { red = 0.35, green = 0.45, blue = 0.60, alpha = 0.6 },
      strokeWidth = 1,
      frame = { x = xPos, y = homeY, w = padW, h = padH },
      roundedRectRadii = { xRadius = 6, yRadius = 6 }
    }

    elemIdx = elemIdx + 1
    canvas[elemIdx] = {
      type = "text",
      text = kData.key,
      textColor = { red = 1.0, green = 1.0, blue = 1.0, alpha = 0.95 },
      textFont = ".AppleSystemUIFontBold",
      textSize = 14,
      textAlignment = "center",
      frame = { x = xPos, y = homeY + 5, w = padW, h = 18 }
    }

    elemIdx = elemIdx + 1
    canvas[elemIdx] = {
      type = "text",
      text = kData.name,
      textColor = { red = 0.35, green = 0.8, blue = 1.0, alpha = 0.9 },
      textFont = ".AppleSystemUIFontSemibold",
      textSize = 10,
      textAlignment = "center",
      frame = { x = xPos, y = homeY + 24, w = padW, h = 14 }
    }

    keyElementMap[code] = { bg = bgIdx, stroke = strokeIdx }
  end

  -- ── BOTTOM ROW (CC CONTROLS) KEY PADS ────────────────────────────────────────
  local bottomKeysOrder = { 6, 7, 8, 9, 11 }
  local ccPadW = 112
  local ccGap = 8
  local bottomY = 156
  local ccStartX = 20

  for i, code in ipairs(bottomKeysOrder) do
    local kData = bottomRowCC[code]
    local xPos = ccStartX + (i - 1) * (ccPadW + ccGap)

    elemIdx = elemIdx + 1
    local bgIdx = elemIdx
    canvas[bgIdx] = {
      type = "rectangle",
      action = "fill",
      fillColor = { red = 0.12, green = 0.15, blue = 0.22, alpha = 0.9 },
      frame = { x = xPos, y = bottomY, w = ccPadW, h = padH },
      roundedRectRadii = { xRadius = 6, yRadius = 6 }
    }

    elemIdx = elemIdx + 1
    local strokeIdx = elemIdx
    canvas[strokeIdx] = {
      type = "rectangle",
      action = "stroke",
      strokeColor = { red = 0.25, green = 0.32, blue = 0.45, alpha = 0.5 },
      strokeWidth = 1,
      frame = { x = xPos, y = bottomY, w = ccPadW, h = padH },
      roundedRectRadii = { xRadius = 6, yRadius = 6 }
    }

    elemIdx = elemIdx + 1
    local textIdx = elemIdx
    canvas[textIdx] = {
      type = "text",
      text = kData.key .. "  •  " .. kData.name,
      textColor = { red = 0.9, green = 0.75, blue = 0.4, alpha = 0.95 },
      textFont = ".AppleSystemUIFontBold",
      textSize = 11,
      textAlignment = "center",
      frame = { x = xPos, y = bottomY + 12, w = ccPadW, h = 20 }
    }

    keyElementMap[code] = { bg = bgIdx, stroke = strokeIdx, text = textIdx, isCC = true }
  end

  -- ── FOOTER HINT ──────────────────────────────────────────────────────────────
  elemIdx = elemIdx + 1
  canvas[elemIdx] = {
    type = "text",
    text = "Press Cmd + Option + M to Toggle OFF  |  Z: Sustain  |  X/C: Mod Wheel  |  V/B: Volume",
    textColor = { red = 0.45, green = 0.52, blue = 0.62, alpha = 0.75 },
    textFont = ".AppleSystemUIFont",
    textSize = 10,
    textAlignment = "center",
    frame = { x = 16, y = 208, w = width - 32, h = 18 }
  }

  activeWatchers.midiCanvas = canvas
  return canvas
end

-- ── Key Highlight State Updater ──────────────────────────────────────────────

local function setKeyVisualState(code, isPressed)
  local map = keyElementMap[code]
  if not map or not activeWatchers.midiCanvas then return end

  local canvas = activeWatchers.midiCanvas
  if isPressed then
    if map.isCC then
      canvas[map.bg].fillColor = { red = 0.9, green = 0.55, blue = 0.1, alpha = 0.95 }
      canvas[map.stroke].strokeColor = { red = 1.0, green = 0.8, blue = 0.3, alpha = 1.0 }
    else
      canvas[map.bg].fillColor = { red = 0.1, green = 0.75, blue = 0.4, alpha = 0.95 }
      canvas[map.stroke].strokeColor = { red = 0.4, green = 1.0, blue = 0.6, alpha = 1.0 }
    end
  else
    if homeRowKeys[code] then
      canvas[map.bg].fillColor = { red = 0.18, green = 0.22, blue = 0.32, alpha = 0.9 }
      canvas[map.stroke].strokeColor = { red = 0.35, green = 0.45, blue = 0.60, alpha = 0.6 }
    elseif upperRowKeys[code] then
      canvas[map.bg].fillColor = { red = 0.14, green = 0.18, blue = 0.26, alpha = 0.9 }
      canvas[map.stroke].strokeColor = { red = 0.28, green = 0.35, blue = 0.48, alpha = 0.5 }
    elseif bottomRowCC[code] then
      canvas[map.bg].fillColor = { red = 0.12, green = 0.15, blue = 0.22, alpha = 0.9 }
      canvas[map.stroke].strokeColor = { red = 0.25, green = 0.32, blue = 0.45, alpha = 0.5 }
    end
  end
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

-- Key tap event handler for intercepting system-wide keystrokes
activeWatchers.midiKeyTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp }, function(event)
  if not midiActive then return false end

  local code = event:getProperty(hs.eventtap.event.properties.keyboardEventKeycode)
  local isDown = (event:getType() == hs.eventtap.event.types.keyDown)

  -- Check Home Row Notes
  if homeRowKeys[code] then
    local data = homeRowKeys[code]
    if isDown then
      if not pressedKeys[code] then
        pressedKeys[code] = true
        sendMidiNote("noteOn", data.note, 100)
        setKeyVisualState(code, true)
      end
    else
      pressedKeys[code] = nil
      sendMidiNote("noteOff", data.note, 0)
      setKeyVisualState(code, false)
    end
    return true -- Swallow keypress
  end

  -- Check Upper Row Notes (+2 Octaves)
  if upperRowKeys[code] then
    local data = upperRowKeys[code]
    if isDown then
      if not pressedKeys[code] then
        pressedKeys[code] = true
        sendMidiNote("noteOn", data.note, 100)
        setKeyVisualState(code, true)
      end
    else
      pressedKeys[code] = nil
      sendMidiNote("noteOff", data.note, 0)
      setKeyVisualState(code, false)
    end
    return true -- Swallow keypress
  end

  -- Check Bottom Row CC Controls
  if bottomRowCC[code] then
    local data = bottomRowCC[code]
    if isDown then
      if not pressedKeys[code] then
        pressedKeys[code] = true
        setKeyVisualState(code, true)

        if data.type == "momentary" then
          sendMidiCC(data.controller, data.onVal)
        elseif data.type == "step" then
          local currentVal = ccStates[data.controller] or 0
          local newVal = math.max(0, math.min(127, currentVal + data.step))
          ccStates[data.controller] = newVal
          sendMidiCC(data.controller, newVal)
        end
      end
    else
      pressedKeys[code] = nil
      setKeyVisualState(code, false)

      if data.type == "momentary" then
        sendMidiCC(data.controller, data.offVal)
      end
    end
    return true -- Swallow keypress
  end

  return false -- Pass through unmapped keys
end)

-- Toggle MIDI Mode hotkey (Cmd + Option + M)
activeWatchers.midiToggleHotkey = hs.hotkey.bind({ "cmd", "alt" }, "M", function()
  midiActive = not midiActive
  if midiActive then
    activeWatchers.midiKeyTap:start()
    local hud = createMidiHud()
    hud:show()
  else
    activeWatchers.midiKeyTap:stop()
    pressedKeys = {}
    if activeWatchers.midiCanvas then
      activeWatchers.midiCanvas:hide()
    end
  end
  hs.alert.show("🎹 MIDI Mode: " .. (midiActive and "ON" or "OFF"))
end)
