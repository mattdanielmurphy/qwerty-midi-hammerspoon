local hsMidi = require("hs.midi")
local hsWebview = require("hs.webview")
local hsUsercontent = require("hs.webview.usercontent")

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

-- ── Scale Transposer Engine ──────────────────────────────────────────────────
local SCALES = {
  { name = "Lydian",                  intervals = { 0, 2, 4, 6, 7, 9, 11 }, brightness = 6, brightTag = "BRIGHTEST ☀️" },
  { name = "Major / Ionian",          intervals = { 0, 2, 4, 5, 7, 9, 11 }, brightness = 5, brightTag = "BRIGHT 🌤" },
  { name = "Mixolydian",              intervals = { 0, 2, 4, 5, 7, 9, 10 }, brightness = 4, brightTag = "WARM ⛅" },
  { name = "Dorian",                  intervals = { 0, 2, 3, 5, 7, 9, 10 }, brightness = 3, brightTag = "NEUTRAL ☁️" },
  { name = "Natural Minor / Aeolian", intervals = { 0, 2, 3, 5, 7, 8, 10 }, brightness = 2, brightTag = "DARK 🌧" },
  { name = "Phrygian",                intervals = { 0, 1, 3, 5, 7, 8, 10 }, brightness = 1, brightTag = "DARKER 🌩" },
  { name = "Locrian",                 intervals = { 0, 1, 3, 5, 6, 8, 10 }, brightness = 0, brightTag = "DARKEST 🌑" },
  { name = "Harmonic Minor",          intervals = { 0, 2, 3, 5, 7, 8, 11 }, brightness = 2, brightTag = "EXOTIC 🔮" },
  { name = "Melodic Minor",           intervals = { 0, 2, 3, 5, 7, 9, 11 }, brightness = 3, brightTag = "JAZZY 🎷" }
}

local NOTE_NAMES = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }

local WHITE_KEY_INDEX = {
  [0] = 0, [1] = -1, [2] = 1, [3] = -1, [4] = 2, [5] = 3,
  [6] = -1, [7] = 4, [8] = -1, [9] = 5, [10] = -1, [11] = 6
}

-- Transposer & Control State
local currentRoot = 0            -- 0 = C (0..11)
local currentScaleIdx = 1        -- 1 = Major / Ionian
local octaveShift = 0            -- Global Octave offset in semitones (-36 to +36)
local topRowOctaveOffset = 0     -- Independent Top Row Octave Offset
local transposeShift = 0         -- Transpose offset in semitones (-12 to +12)
local sustainActive = false      -- Sustain / Latch mode toggle state (CC64)
local sustainKeyDownTime = 0     -- Timestamp when sustain key was pressed down
local sustainWasActiveOnPress = false
local shiftHeld = false          -- Shift key active state
local zoomLevel = hs.settings.get("qwertyMidi_zoomLevel") or 1.0  -- HUD Zoom Scale Factor (1.0 = 100%)
local BASE_HUD_SCALE = 1.4                                         -- 100% zoom maps to 1.4x baseline scale factor

-- Arpeggiator & Latch State
local arpMode = 0                -- 0: OFF, 1: UP, 2: DOWN, 3: UP-DOWN, 4: RANDOM
local ARP_MODES = { "OFF", "UP", "DOWN", "UP-DOWN", "RANDOM" }
local arpBpm = 120.0             -- Free-form BPM value (20.0-300.0)
local arpTimer = nil
local arpHeldNotes = {}          -- [code] = pitch (latched or physically held)
local arpKeysCurrentlyHeld = {}  -- [code] = true (physically down)
local arpCurrentPitch = nil
local arpStepIndex = 1
local arpStepDirection = 1
local lastArpMode = 1            -- Last non-OFF arp mode (for toggle restore)
local arpTopEnabled = false      -- Whether top row feeds arpeggiator (Default: OFF / Bottom row only)
local arpBottomEnabled = true    -- Whether bottom row feeds arpeggiator

-- BPM Input Mode State
local bpmInputMode = false       -- When true, keyboard routes to BPM editor
local bpmInputBuffer = ""        -- Text buffer for typing BPM value
local bpmBeforeEdit = 120.0      -- Value before entering edit mode (for cancel)

local DIGIT_KEYCODES = {
  [29] = "0", [18] = "1", [19] = "2", [20] = "3", [21] = "4",
  [23] = "5", [22] = "6", [26] = "7", [28] = "8", [25] = "9"
}

local ccStates = {
  [1] = 0,   -- Mod Wheel default 0
  [7] = 100  -- Volume default 100
}

local function getTransposedPitch(basePitch, isTopRow)
  local effectivePitch = basePitch + (isTopRow and topRowOctaveOffset or 0) + transposeShift
  local octave = math.floor(effectivePitch / 12) - 1
  local noteInOctave = effectivePitch % 12
  local scaleIndex = WHITE_KEY_INDEX[noteInOctave]

  if scaleIndex and scaleIndex ~= -1 then
    local intervals = SCALES[currentScaleIdx].intervals
    local targetInterval = intervals[scaleIndex + 1]
    local newPitch = ((octave + 1) * 12) + currentRoot + targetInterval + octaveShift
    if newPitch >= 0 and newPitch <= 127 then
      return newPitch
    end
  end
  local fallbackPitch = effectivePitch + currentRoot + octaveShift
  return math.max(0, math.min(127, fallbackPitch))
end

local function noteNumToName(noteNum)
  local octave = math.floor(noteNum / 12) - 1
  local noteName = NOTE_NAMES[(noteNum % 12) + 1]
  return noteName .. octave
end

-- ── Key Mappings ─────────────────────────────────────────────────────────────
local numberRowControls = {
  [18] = { key = "1", name = "TopOct -", action = "topOctDown" },
  [19] = { key = "2", name = "TopOct +", action = "topOctUp" },
  [20] = { key = "3", name = "Trnsp -",  action = "trnspDown" },
  [21] = { key = "4", name = "Trnsp +",  action = "trnspUp" },
  [23] = { key = "5", name = "Oct -",    action = "octaveDown" },
  [22] = { key = "6", name = "Oct +",    action = "octaveUp" },
  [26] = { key = "7", name = "Mode -",   action = "modeDown" },
  [28] = { key = "8", name = "Mode +",   action = "modeUp" },
  [25] = { key = "9", name = "Panic",    action = "panic" },
  [29] = { key = "0", name = "Reset",    action = "resetAll" },
  [27] = { key = "-", name = "Zoom -",   action = "zoomOut" },
  [24] = { key = "=", name = "Zoom +",   action = "zoomIn" }
}

local lowerRowKeys = {
  [6]  = { key = "Z", baseNote = 60 },
  [7]  = { key = "X", baseNote = 62 },
  [8]  = { key = "C", baseNote = 64 },
  [9]  = { key = "V", baseNote = 65 },
  [11] = { key = "B", baseNote = 67 },
  [45] = { key = "N", baseNote = 69 },
  [46] = { key = "M", baseNote = 71 },
  [43] = { key = ",", baseNote = 72 },
  [47] = { key = ".", baseNote = 74 },
  [44] = { key = "/", baseNote = 76 }
}

local upperRowKeys = {
  [12] = { key = "Q", baseNote = 72 },
  [13] = { key = "W", baseNote = 74 },
  [14] = { key = "E", baseNote = 76 },
  [15] = { key = "R", baseNote = 77 },
  [17] = { key = "T", baseNote = 79 },
  [16] = { key = "Y", baseNote = 81 },
  [32] = { key = "U", baseNote = 83 },
  [34] = { key = "I", baseNote = 84 },
  [31] = { key = "O", baseNote = 86 },
  [35] = { key = "P", baseNote = 88 }
}

local homeRowControls = {
  [48] = { key = "Tab", name = "Sustain", action = "sustain",     shiftAction = "resetAll",   shiftName = "Reset" },
  [0]  = { key = "A",   name = "Sustain", action = "sustain",     shiftAction = "resetAll",   shiftName = "Reset" },
  [1]  = { key = "S",   name = "Random",  action = "randomScale", shiftAction = "panic",      shiftName = "Panic!" },
  [2]  = { key = "D",   name = "Oct -",   action = "octaveDown",  shiftAction = "topOctDown", shiftName = "TopOct -" },
  [3]  = { key = "F",   name = "Oct +",   action = "octaveUp",    shiftAction = "topOctUp",   shiftName = "TopOct +" },
  [5]  = { key = "G",   name = "Vol -",   action = "volDown",     shiftAction = "volDown",    shiftName = "Vol -" },
  [4]  = { key = "H",   name = "Root -",  action = "rootDown",    shiftAction = "topOctDown", shiftName = "TopOct -" },
  [38] = { key = "J",   name = "Mode -",  action = "modeDown",    shiftAction = "modWheelDown", shiftName = "Mod -" },
  [40] = { key = "K",   name = "Mode +",  action = "modeUp",      shiftAction = "modWheelUp",   shiftName = "Mod +" },
  [37] = { key = "L",   name = "Root +",  action = "rootUp",      shiftAction = "topOctUp",   shiftName = "TopOct +" },
  [41] = { key = ";",   name = "Vol +",   action = "volUp",       shiftAction = "volUp",      shiftName = "Vol +" }
}

local pressedKeys = {}

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

local function getIntervalInfo(noteNum)
  local noteInOctave = noteNum % 12
  local semitonesFromRoot = (noteInOctave - currentRoot + 12) % 12
  local intervals = SCALES[currentScaleIdx].intervals

  for idx, interval in ipairs(intervals) do
    if interval == semitonesFromRoot then
      return idx, semitonesFromRoot
    end
  end
  return nil, semitonesFromRoot
end

-- Forward declaration of updateWebviewHud
local updateWebviewHud

-- ── Arpeggiator Engine ───────────────────────────────────────────────────────
local function stopArpTimer()
  if arpTimer then
    arpTimer:stop()
    arpTimer = nil
  end
  if arpCurrentPitch then
    sendMidiNote("noteOff", arpCurrentPitch, 0)
    arpCurrentPitch = nil
  end
  arpStepIndex = 1
  arpStepDirection = 1
end

local function arpTick()
  local pitchList = {}
  for code, pitch in pairs(arpHeldNotes) do
    table.insert(pitchList, pitch)
  end
  table.sort(pitchList)

  if #pitchList == 0 then
    if arpCurrentPitch then
      sendMidiNote("noteOff", arpCurrentPitch, 0)
      arpCurrentPitch = nil
      if updateWebviewHud then updateWebviewHud() end
    end
    return
  end

  if arpMode == 1 then -- UP
    arpStepIndex = ((arpStepIndex - 1) % #pitchList) + 1
  elseif arpMode == 2 then -- DOWN
    arpStepIndex = ((arpStepIndex - 2 + #pitchList) % #pitchList) + 1
  elseif arpMode == 3 then -- UP-DOWN
    if arpStepIndex > #pitchList then
      arpStepIndex = math.max(1, #pitchList - 1)
      arpStepDirection = -1
    elseif arpStepIndex < 1 then
      arpStepIndex = math.min(#pitchList, 2)
      arpStepDirection = 1
    end
  elseif arpMode == 4 then -- RANDOM
    arpStepIndex = math.random(1, #pitchList)
  end

  local nextPitch = pitchList[arpStepIndex]

  if arpMode == 3 then
    if #pitchList == 1 then
      arpStepIndex = 1
      arpStepDirection = 1
    else
      arpStepIndex = arpStepIndex + arpStepDirection
      if arpStepIndex > #pitchList then
        arpStepIndex = math.max(1, #pitchList - 1)
        arpStepDirection = -1
      elseif arpStepIndex < 1 then
        arpStepIndex = math.min(#pitchList, 2)
        arpStepDirection = 1
      end
    end
  elseif arpMode == 1 then
    arpStepIndex = arpStepIndex + 1
  elseif arpMode == 2 then
    arpStepIndex = arpStepIndex - 1
  end

  if arpCurrentPitch and arpCurrentPitch ~= nextPitch then
    sendMidiNote("noteOff", arpCurrentPitch, 0)
  end

  sendMidiNote("noteOn", nextPitch, 100)
  arpCurrentPitch = nextPitch

  if updateWebviewHud then
    updateWebviewHud(nil, nextPitch)
  end
end

local function startArpTimer()
  if arpTimer then return end
  local intervalSeconds = (60.0 / arpBpm) / 2.0 -- 8th notes
  arpStepIndex = 1
  arpStepDirection = 1
  arpTick()
  arpTimer = hs.timer.doEvery(intervalSeconds, arpTick)
end

local function arpAddNote(code, pitch)
  -- Count active physical/UI held keys
  local numPhysicalHeld = 0
  for _ in pairs(arpKeysCurrentlyHeld) do numPhysicalHeld = numPhysicalHeld + 1 end

  -- If Sustain / Latch Mode is ON and starting a new chord (0 keys were down), clear previous latched pattern
  if sustainActive and numPhysicalHeld == 0 then
    arpHeldNotes = {}
    if arpCurrentPitch then
      sendMidiNote("noteOff", arpCurrentPitch, 0)
      arpCurrentPitch = nil
    end
  end

  arpKeysCurrentlyHeld[code] = true
  arpHeldNotes[code] = pitch

  if not arpTimer then
    startArpTimer()
  end
end

local function arpRemoveNote(code)
  arpKeysCurrentlyHeld[code] = nil

  -- In Sustain / Latch mode, releasing keys does not clear the arpeggiated note set
  if sustainActive then
    return
  end

  arpHeldNotes[code] = nil
  local count = 0
  for _ in pairs(arpHeldNotes) do count = count + 1 end
  if count == 0 then
    stopArpTimer()
    if updateWebviewHud then updateWebviewHud() end
  end
end

local function formatBpm(bpm)
  if bpm == math.floor(bpm) then
    return tostring(math.floor(bpm))
  else
    return string.format("%.1f", bpm)
  end
end

local function applyBpmChange()
  if arpTimer then
    stopArpTimer()
    if next(arpHeldNotes) ~= nil then
      startArpTimer()
    end
  end
end

local function updateLatchedArpNotes()
  if arpMode == 0 or next(arpHeldNotes) == nil then return end
  for code, _ in pairs(arpHeldNotes) do
    if lowerRowKeys[code] then
      arpHeldNotes[code] = getTransposedPitch(lowerRowKeys[code].baseNote, false)
    elseif upperRowKeys[code] then
      arpHeldNotes[code] = getTransposedPitch(upperRowKeys[code].baseNote, true)
    end
  end
end

local function getArpRowTargetSubtext()
  if arpTopEnabled and arpBottomEnabled then
    return "Top & Bottom Rows"
  elseif arpTopEnabled then
    return "Top Row Only"
  elseif arpBottomEnabled then
    return "Bottom Row Only"
  else
    return "No Rows Active"
  end
end

local function cycleArpMode()
  if arpMode > 0 then lastArpMode = arpMode end
  arpMode = (arpMode + 1) % #ARP_MODES
  if arpMode == 0 then
    stopArpTimer()
    arpHeldNotes = {}
    arpKeysCurrentlyHeld = {}
  end
  local spot = {
    title = "ARPEGGIATOR",
    value = "MODE: " .. ARP_MODES[arpMode + 1],
    subtext = arpMode > 0 and (formatBpm(arpBpm) .. " BPM • " .. getArpRowTargetSubtext()) or "Arp Disabled",
    targetId = "arp-btn",
    color = "#d4a359"
  }
  if updateWebviewHud then updateWebviewHud(spot) end
end

local function toggleArp()
  if arpMode == 0 then
    arpMode = lastArpMode > 0 and lastArpMode or 1
  else
    lastArpMode = arpMode
    arpMode = 0
    stopArpTimer()
    arpHeldNotes = {}
    arpKeysCurrentlyHeld = {}
  end
  local spot = {
    title = "ARPEGGIATOR",
    value = arpMode > 0 and ("MODE: " .. ARP_MODES[arpMode + 1]) or "ARP OFF",
    subtext = arpMode > 0 and ("ON (" .. getArpRowTargetSubtext() .. ") • " .. formatBpm(arpBpm) .. " BPM") or "Arp Disabled",
    targetId = "arp-btn",
    color = "#d4a359"
  }
  if updateWebviewHud then updateWebviewHud(spot) end
end

local function handleBpmInput(code, flags)
  if code == 53 then -- Escape: cancel
    arpBpm = bpmBeforeEdit
    bpmInputMode = false
    bpmInputBuffer = ""
    updateWebviewHud()
    return true
  elseif code == 36 then -- Return: commit
    if bpmInputBuffer ~= "" then
      local val = tonumber(bpmInputBuffer)
      if val and val >= 20 and val <= 300 then
        arpBpm = val
      end
    end
    bpmInputMode = false
    bpmInputBuffer = ""
    applyBpmChange()
    updateWebviewHud()
    return true
  elseif code == 126 then -- Arrow Up
    local delta = 1
    if flags.shift then delta = 10
    elseif flags.alt then delta = 0.1 end
    arpBpm = math.min(300, arpBpm + delta)
    bpmInputBuffer = ""
    applyBpmChange()
    updateWebviewHud()
    return true
  elseif code == 125 then -- Arrow Down
    local delta = 1
    if flags.shift then delta = 10
    elseif flags.alt then delta = 0.1 end
    arpBpm = math.max(20, arpBpm - delta)
    bpmInputBuffer = ""
    applyBpmChange()
    updateWebviewHud()
    return true
  elseif code == 51 then -- Backspace
    if #bpmInputBuffer > 0 then
      bpmInputBuffer = bpmInputBuffer:sub(1, -2)
    end
    updateWebviewHud()
    return true
  elseif DIGIT_KEYCODES[code] then
    bpmInputBuffer = bpmInputBuffer .. DIGIT_KEYCODES[code]
    updateWebviewHud()
    return true
  elseif code == 47 then -- Period "."
    if not bpmInputBuffer:find("%.") then
      bpmInputBuffer = bpmInputBuffer .. "."
    end
    updateWebviewHud()
    return true
  end
  -- Any other key: exit BPM mode and pass through
  bpmInputMode = false
  bpmInputBuffer = ""
  updateWebviewHud()
  return false
end

-- ── HTML UI Engine ─────────────────────────────────────────────────────────────
local HTML_UI_CONTENT = [[
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; user-select: none; -webkit-user-select: none; -webkit-font-smoothing: antialiased; }
  html, body {
    background: transparent;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'SF Pro Text', system-ui, sans-serif;
    width: 100%;
    height: 100%;
    overflow: hidden;
    display: flex;
    justify-content: center;
    align-items: center;
  }
  
  #hud-container {
    width: 810px;
    height: 330px;
    background: rgba(24, 22, 20, 0.96);
    border: 2px solid rgba(70, 64, 58, 0.7);
    border-radius: 14px;
    overflow: visible;
    box-shadow: 0 10px 30px rgba(0,0,0,0.6), inset 0 0 20px rgba(0, 0, 0, 0.6);
    display: flex;
    flex-direction: column;
    padding: 12px 14px 14px 14px;
    position: relative;
    transform-origin: center center;
    transform: scale(1.4);
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
  }

  /* Top Header Spotlight Notification Card */
  .spotlight-card {
    position: absolute;
    top: -5px;
    left: 50%;
    transform: translate(-50%, -100%) scale(1.0);
    background: rgba(20, 18, 16, 0.98);
    border: 1.5px solid #d4a359;
    border-radius: 8px;
    padding: 5px 18px;
    box-shadow: 0 6px 24px rgba(0, 0, 0, 0.9);
    display: flex;
    flex-direction: row;
    align-items: center;
    justify-content: center;
    gap: 10px;
    z-index: 9999;
    pointer-events: none;
    opacity: 1;
    backdrop-filter: blur(10px);
    -webkit-backdrop-filter: blur(10px);
    white-space: nowrap;
  }

  .spotlight-card.hidden {
    opacity: 0;
    display: none;
  }

  .spotlight-title {
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 1px;
    color: #b5aba0;
    text-transform: uppercase;
    margin-bottom: 0;
  }

  .spotlight-val {
    font-size: 15px;
    font-weight: 700;
    color: #ffffff;
    text-shadow: 0 1px 4px rgba(0,0,0,0.6);
    margin-bottom: 0;
    white-space: nowrap;
  }

  .spotlight-sub {
    font-size: 11px;
    font-weight: 600;
    color: #d4a359;
    white-space: nowrap;
  }
  
  /* Dynamic Mod Wheel Glow */
  #hud-container.mod-active {
    box-shadow: 0 0 calc(8px + var(--mod-intensity) * 18px) rgba(212, 163, 89, calc(0.2 + var(--mod-intensity) * 0.25)),
                inset 0 0 calc(10px + var(--mod-intensity) * 15px) rgba(212, 163, 89, calc(0.08 + var(--mod-intensity) * 0.12));
    border-color: rgba(212, 163, 89, calc(0.4 + var(--mod-intensity) * 0.35));
  }

  .mod-gradient-overlay {
    position: absolute;
    top: 0; left: 0; right: 0; bottom: 0;
    border-radius: 14px;
    overflow: hidden;
    pointer-events: none;
    background: linear-gradient(180deg, rgba(212, 163, 89, calc(var(--mod-intensity) * 0.08)) 0%, rgba(200, 140, 60, 0) 100%);
    opacity: 0;
    transition: opacity 0.15s ease;
  }

  #hud-container.mod-active .mod-gradient-overlay {
    opacity: 1;
  }

  /* Header Bar */
  #header {
    height: 48px;
    background: rgba(36, 32, 28, 0.9);
    border-radius: 8px;
    display: flex;
    align-items: center;
    padding: 0 12px;
    margin-bottom: 12px;
    cursor: move;
    -webkit-app-region: drag;
    gap: 10px;
  }

  .badge {
    background: rgba(212, 163, 89, 0.18);
    border: 1.5px solid #d4a359;
    color: #d4a359;
    font-weight: 700;
    font-size: 14px;
    padding: 3px 6px;
    border-radius: 6px;
    display: flex;
    align-items: center;
    justify-content: center;
    white-space: nowrap;
    width: 52px;
    flex-shrink: 0;
    appearance: none;
    -webkit-appearance: none;
    outline: none;
    text-align: center;
    text-align-last: center;
    font-family: inherit;
    -webkit-app-region: no-drag;
    cursor: pointer;
  }
  
  .badge option {
    background: #181614;
    color: #d4a359;
    font-weight: 600;
  }

  .mode-center-block {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    width: 210px;
    flex-shrink: 0;
    -webkit-app-region: no-drag;
  }

  .mode-slider-track {
    width: 190px;
    height: 10px;
    background: linear-gradient(90deg, #d4a359 0%, #b8860b 40%, #706558 70%, #3a342e 100%);
    border-radius: 5px;
    position: relative;
    cursor: pointer;
  }

  .mode-slider-thumb {
    width: 10px;
    height: 16px;
    background: #f2eae1;
    border: 1px solid #333;
    border-radius: 3px;
    position: absolute;
    top: -3px;
    left: 0%;
    transform: translateX(-50%);
    box-shadow: 0 1px 4px rgba(0,0,0,0.6);
    transition: left 0.08s ease;
    pointer-events: none;
  }

  .mode-name-label {
    font-size: 11px;
    font-weight: 700;
    color: #d4a359;
    letter-spacing: 0.5px;
    margin-top: 3px;
    white-space: nowrap;
    text-shadow: 0 1px 2px rgba(0,0,0,0.6);
  }

  .arp-btn {
    background: rgba(212, 163, 89, 0.15);
    border: 1.5px solid #d4a359;
    color: #d4a359;
    font-weight: 700;
    font-size: 11px;
    padding: 4px 8px;
    border-radius: 6px;
    white-space: nowrap;
    flex-shrink: 0;
    cursor: pointer;
    outline: none;
    font-family: inherit;
    -webkit-app-region: no-drag;
    transition: background 0.15s ease, box-shadow 0.15s ease;
  }
  
  .arp-btn:hover {
    background: rgba(212, 163, 89, 0.3);
  }
  
  .arp-btn.arp-active {
    background: rgba(212, 163, 89, 0.45);
    box-shadow: 0 0 8px rgba(212, 163, 89, 0.6);
  }

  .bpm-editor {
    display: flex;
    align-items: center;
    gap: 2px;
    -webkit-app-region: no-drag;
    flex-shrink: 0;
  }

  .bpm-arrow-btn {
    background: rgba(212, 163, 89, 0.12);
    border: 1px solid rgba(212, 163, 89, 0.4);
    color: #d4a359;
    font-size: 10px;
    padding: 2px 5px;
    border-radius: 4px;
    cursor: pointer;
    outline: none;
    font-family: inherit;
    line-height: 1;
    transition: background 0.15s ease;
    -webkit-app-region: no-drag;
  }

  .bpm-arrow-btn:hover {
    background: rgba(212, 163, 89, 0.3);
  }

  .bpm-display {
    font-size: 11px;
    font-weight: 700;
    color: #d4a359;
    padding: 3px 6px;
    border-radius: 4px;
    cursor: text;
    min-width: 60px;
    text-align: center;
    transition: background 0.15s ease, box-shadow 0.15s ease;
    white-space: nowrap;
  }

  .bpm-display:hover {
    background: rgba(212, 163, 89, 0.1);
  }

  .bpm-display.editing {
    background: rgba(212, 163, 89, 0.2);
    box-shadow: 0 0 6px rgba(212, 163, 89, 0.4);
    outline: 1.5px solid #d4a359;
  }

  .row-controls {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 3px;
    flex-shrink: 0;
  }

  .arp-row-toggle {
    font-size: 8px;
    font-weight: 700;
    color: #706558;
    background: rgba(36, 32, 28, 0.8);
    border: 1px solid rgba(112, 101, 88, 0.4);
    border-radius: 4px;
    padding: 1px 6px;
    cursor: pointer;
    outline: none;
    font-family: inherit;
    letter-spacing: 0.5px;
    transition: all 0.15s ease;
    -webkit-app-region: no-drag;
  }

  .arp-row-toggle.active {
    color: #d4a359;
    border-color: rgba(212, 163, 89, 0.6);
    background: rgba(212, 163, 89, 0.15);
    box-shadow: 0 0 4px rgba(212, 163, 89, 0.2);
  }

  .arp-row-toggle:hover {
    background: rgba(212, 163, 89, 0.25);
  }

  .draggable-octave {
    cursor: ns-resize;
    user-select: none;
    -webkit-user-select: none;
  }

  .status-info {
    font-size: 12px;
    color: #b5aba0;
    font-weight: 600;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    flex: 1;
    min-width: 0;
    text-align: right;
  }

  /* Keyboard Grid */
  .keyboard-grid {
    display: flex;
    flex-direction: column;
    gap: 6px;
    flex: 1;
  }

  .keyboard-row {
    display: flex;
    gap: 5px;
  }

  .row-with-indicator {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
  }

  .octave-row-badge {
    font-size: 10.5px;
    font-weight: 700;
    color: #d4a359;
    background: rgba(36, 32, 28, 0.95);
    border: 1.5px solid rgba(212, 163, 89, 0.4);
    border-radius: 6px;
    padding: 3px 8px;
    letter-spacing: 0.5px;
    white-space: nowrap;
    box-shadow: 0 2px 6px rgba(0, 0, 0, 0.4);
  }

  .keyboard-row.number { margin-left: 0px; }
  .keyboard-row.upper { margin-left: 12px; }
  .keyboard-row.home { margin-left: 32px; }
  .keyboard-row.lower { margin-left: 56px; }

  .key-pad {
    width: 58px;
    height: 44px;
    background: rgba(26, 23, 20, 0.98);
    border: 1.5px solid rgba(65, 58, 50, 1.0);
    border-radius: 8px;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    transition: background 0.05s ease, border-color 0.05s ease;
    cursor: pointer;
    flex-shrink: 0;
    -webkit-app-region: no-drag;
  }

  .key-pad:active, .key-pad.pressed {
    background: rgba(55, 48, 40, 1.0);
    border-color: rgba(100, 88, 75, 1.0);
    box-shadow: inset 0 2px 4px rgba(0,0,0,0.5);
  }

  .key-pad .key-code {
    font-size: 12px;
    font-weight: 700;
    color: #f2eae1;
    text-shadow: 0 1px 2px rgba(0, 0, 0, 0.8);
    pointer-events: none;
  }

  .key-pad .key-note {
    font-size: 9.5px;
    font-weight: 500;
    color: rgba(200, 190, 175, 0.95);
    margin-top: 1px;
    white-space: nowrap;
    text-shadow: 0 1px 2px rgba(0, 0, 0, 0.8);
    pointer-events: none;
  }

  /* Glowing Outlines for Note Intervals */
  .key-pad.root-key {
    border-color: rgba(212, 163, 89, 0.9);
    box-shadow: 0 0 10px rgba(212, 163, 89, 0.45), inset 0 0 6px rgba(212, 163, 89, 0.2);
  }
  .key-pad.root-key .key-note { color: #f0c27b; font-weight: 700; }
  .key-pad.root-key:active, .key-pad.root-key.pressed { background: rgba(212, 163, 89, 0.3); }

  .key-pad.third-key {
    border: 1.5px dashed rgba(212, 163, 89, 0.75);
    box-shadow: 0 0 6px rgba(212, 163, 89, 0.25), inset 0 0 4px rgba(212, 163, 89, 0.1);
  }
  .key-pad.third-key .key-note { color: rgba(212, 163, 89, 0.9); font-weight: 600; }
  .key-pad.third-key:active, .key-pad.third-key.pressed { background: rgba(212, 163, 89, 0.2); }

  .key-pad.fifth-key {
    border-color: rgba(212, 163, 89, 0.45);
    box-shadow: 0 0 4px rgba(212, 163, 89, 0.15);
  }
  .key-pad.fifth-key .key-note { color: rgba(212, 163, 89, 0.75); font-weight: 500; }
  .key-pad.fifth-key:active, .key-pad.fifth-key.pressed { background: rgba(212, 163, 89, 0.15); }

  .key-pad.control-pad {
    background: rgba(30, 26, 23, 0.95);
    border-color: rgba(55, 48, 42, 1.0);
  }

  .key-pad.control-pad .key-note {
    color: #a09588;
    font-size: 9.5px;
  }

  .key-pad.mode-control {
    background: rgba(45, 38, 30, 0.95);
    border-color: rgba(212, 163, 89, 0.55);
  }

  .key-pad.mode-control .key-note {
    color: #d4a359;
    font-weight: 600;
  }

  .key-pad.sustain-active {
    background: rgba(212, 163, 89, 0.25);
    border-color: #d4a359;
  }

  .key-pad.sustain-active .key-note {
    color: #d4a359;
    font-weight: 600;
  }
</style>
</head>
<body style="--mod-intensity: 0;">
  <div id="hud-container">
    <div class="mod-gradient-overlay"></div>
    <div id="spotlight-card" class="spotlight-card hidden">
      <div id="spotlight-title" class="spotlight-title"></div>
      <div id="spotlight-val" class="spotlight-val"></div>
      <div id="spotlight-sub" class="spotlight-sub"></div>
    </div>
    <div id="header">
      <select id="root-select" class="badge">
        <option value="0">C</option>
        <option value="1">C#</option>
        <option value="2">D</option>
        <option value="3">D#</option>
        <option value="4">E</option>
        <option value="5">F</option>
        <option value="6">F#</option>
        <option value="7">G</option>
        <option value="8">G#</option>
        <option value="9">A</option>
        <option value="10">A#</option>
        <option value="11">B</option>
      </select>
      <div class="mode-center-block">
        <div id="mode-track" class="mode-slider-track">
          <div id="mode-thumb" class="mode-slider-thumb"></div>
        </div>
        <div id="mode-name" class="mode-name-label">Major / Ionian</div>
      </div>
      <button id="arp-btn" class="arp-btn">ARP: OFF</button>
      <div id="bpm-editor" class="bpm-editor">
        <button id="bpm-down" class="bpm-arrow-btn">&#9662;</button>
        <span id="bpm-value" class="bpm-display">120 BPM</span>
        <button id="bpm-up" class="bpm-arrow-btn">&#9652;</button>
      </div>
      <div id="status-text" class="status-info"></div>
    </div>
    
    <div class="keyboard-grid">
      <div id="row-number" class="keyboard-row number"></div>
      <div class="row-with-indicator">
        <div id="row-upper" class="keyboard-row upper"></div>
        <div class="row-controls">
          <button id="arp-top-toggle" class="arp-row-toggle active">ARP</button>
          <div id="octave-indicator-top" class="octave-row-badge draggable-octave" data-row="top">TOP +1</div>
        </div>
      </div>
      <div id="row-home" class="keyboard-row home"></div>
      <div class="row-with-indicator">
        <div id="row-lower" class="keyboard-row lower"></div>
        <div class="row-controls">
          <button id="arp-bottom-toggle" class="arp-row-toggle active">ARP</button>
          <div id="octave-indicator-bottom" class="octave-row-badge draggable-octave" data-row="bottom">OCT 0</div>
        </div>
      </div>
    </div>
  </div>

<script>
  const LAYOUT_DATA = {
    number: [
      { code: 18, keyLabel: "1", isControl: true, noteLabel: "TopOct -" },
      { code: 19, keyLabel: "2", isControl: true, noteLabel: "TopOct +" },
      { code: 20, keyLabel: "3", isControl: true, noteLabel: "Trnsp -" },
      { code: 21, keyLabel: "4", isControl: true, noteLabel: "Trnsp +" },
      { code: 23, keyLabel: "5", isControl: true, noteLabel: "Oct -" },
      { code: 22, keyLabel: "6", isControl: true, noteLabel: "Oct +" },
      { code: 26, keyLabel: "7", isControl: true, noteLabel: "Mode -" },
      { code: 28, keyLabel: "8", isControl: true, noteLabel: "Mode +" },
      { code: 25, keyLabel: "9", isControl: true, noteLabel: "Panic" },
      { code: 29, keyLabel: "0", isControl: true, noteLabel: "Reset" },
      { code: 27, keyLabel: "-", isControl: true, noteLabel: "Zoom -" },
      { code: 24, keyLabel: "=", isControl: true, noteLabel: "Zoom +" }
    ],
    upper: [
      { code: 12, keyLabel: "Q" }, { code: 13, keyLabel: "W" }, { code: 14, keyLabel: "E" },
      { code: 15, keyLabel: "R" }, { code: 17, keyLabel: "T" }, { code: 16, keyLabel: "Y" },
      { code: 32, keyLabel: "U" }, { code: 34, keyLabel: "I" }, { code: 31, keyLabel: "O" }, { code: 35, keyLabel: "P" }
    ],
    home: [
      { code: 0,  keyLabel: "A", isControl: true, noteLabel: "Sustain" },
      { code: 1,  keyLabel: "S", isControl: true, noteLabel: "Random" },
      { code: 2,  keyLabel: "D", isControl: true, noteLabel: "Oct -" },
      { code: 3,  keyLabel: "F", isControl: true, noteLabel: "Oct +" },
      { code: 5,  keyLabel: "G", isControl: true, noteLabel: "Vol -" },
      { code: 4,  keyLabel: "H", isControl: true, noteLabel: "Root -" },
      { code: 38, keyLabel: "J", isControl: true, noteLabel: "Mode -" },
      { code: 40, keyLabel: "K", isControl: true, noteLabel: "Mode +" },
      { code: 37, keyLabel: "L", isControl: true, noteLabel: "Root +" },
      { code: 41, keyLabel: ";", isControl: true, noteLabel: "Vol +" }
    ],
    lower: [
      { code: 6,  keyLabel: "Z" }, { code: 7,  keyLabel: "X" }, { code: 8,  keyLabel: "C" },
      { code: 9,  keyLabel: "V" }, { code: 11, keyLabel: "B" }, { code: 45, keyLabel: "N" },
      { code: 46, keyLabel: "M" }, { code: 43, keyLabel: "," }, { code: 47, keyLabel: "." }, { code: 44, keyLabel: "/" }
    ]
  };

  let spotlightTimer1 = null;
  let spotlightTimer2 = null;

  let isDragging = false;
  let dragStartX = 0;
  let dragStartY = 0;

  const activeClickedPads = new Set();
  
  let octaveDragTarget = null;
  let octaveDragStartY = 0;
  let octaveDragAccum = 0;

  let bpmBtnTimer = null;
  let bpmBtnInterval = null;
  let bpmBtnStartTime = 0;
  let bpmBtnDirection = 0;

  let isBpmDragging = false;
  let bpmDragStartY = 0;
  let bpmDragAccum = 0;

  function initGrid(layout) {
    const l = layout || LAYOUT_DATA;
    ['number', 'upper', 'home', 'lower'].forEach(rowName => {
      const rowEl = document.getElementById('row-' + rowName);
      if (!rowEl) return;
      rowEl.innerHTML = '';
      if (l[rowName]) {
        l[rowName].forEach(k => {
          const pad = document.createElement('div');
          pad.id = 'key-' + k.code;
          pad.className = 'key-pad ' + (k.isControl ? 'control-pad' : '');
          
          const codeSpan = document.createElement('span');
          codeSpan.className = 'key-code';
          codeSpan.textContent = k.keyLabel;
          
          const noteSpan = document.createElement('span');
          noteSpan.className = 'key-note';
          noteSpan.textContent = k.noteLabel || '';
          
          pad.appendChild(codeSpan);
          pad.appendChild(noteSpan);

          pad.addEventListener('mousedown', (e) => {
            e.stopPropagation();
            activeClickedPads.add(k.code);
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
              window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'keyDown', code: k.code });
            }
          });

          const releasePad = (e) => {
            if (activeClickedPads.has(k.code)) {
              activeClickedPads.delete(k.code);
              if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
                window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'keyUp', code: k.code });
              }
            }
          };

          pad.addEventListener('mouseup', releasePad);
          pad.addEventListener('mouseleave', releasePad);

          rowEl.appendChild(pad);
        });
      }
    });
  }

  let isModeDragging = false;
  const SCALES_COUNT = 9;

  function handleModeSliderEvent(e) {
    const modeTrack = document.getElementById('mode-track');
    if (!modeTrack) return;
    const rect = modeTrack.getBoundingClientRect();
    let frac = (e.clientX - rect.left) / rect.width;
    frac = Math.max(0, Math.min(1, frac));
    
    const modeIdx = Math.min(SCALES_COUNT, Math.max(1, Math.floor(frac * SCALES_COUNT) + 1));
    
    const snappedFrac = (modeIdx - 0.5) / SCALES_COUNT;
    const thumb = document.getElementById('mode-thumb');
    if (thumb) thumb.style.left = (snappedFrac * 100) + '%';
    
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
      window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'setModeIdx', modeIdx: modeIdx });
    }
  }

  // Auto-initialize grid instantly on document load and notify Lua host
  window.addEventListener('DOMContentLoaded', () => {
    initGrid(LAYOUT_DATA);

    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
      window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'domReady' });
    }

    const container = document.getElementById('hud-container');
    if (container) {
      container.addEventListener('mousedown', (e) => {
        if (e.target.closest('.key-pad') || e.target.closest('select') || e.target.closest('button') || e.target.closest('.mode-center-block') || e.target.closest('.bpm-editor')) return;
        isDragging = true;
        dragStartX = e.screenX;
        dragStartY = e.screenY;
      });
    }

    const rootSelect = document.getElementById('root-select');
    if (rootSelect) {
      rootSelect.addEventListener('change', (e) => {
        const val = parseInt(e.target.value);
        if (!isNaN(val) && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'setRoot', root: val });
        }
      });
      rootSelect.addEventListener('mousedown', (e) => e.stopPropagation());
    }

    const modeTrack = document.getElementById('mode-track');
    if (modeTrack) {
      modeTrack.addEventListener('mousedown', (e) => {
        e.stopPropagation();
        isModeDragging = true;
        handleModeSliderEvent(e);
      });
    }

    const arpBtn = document.getElementById('arp-btn');
    if (arpBtn) {
      arpBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'cycleArpMode' });
        }
      });
    }

    // BPM Editor handlers
    let hasBpmDragged = false;
    const bpmValue = document.getElementById('bpm-value');
    if (bpmValue) {
      bpmValue.style.cursor = 'ns-resize';
      bpmValue.addEventListener('mousedown', (e) => {
        e.stopPropagation();
        e.preventDefault();
        isBpmDragging = true;
        hasBpmDragged = false;
        bpmDragStartY = e.clientY;
        bpmDragAccum = 0;
      });
      bpmValue.addEventListener('click', (e) => {
        e.stopPropagation();
        if (!hasBpmDragged) {
          if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
            window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'enterBpmEdit' });
          }
        }
      });
    }

    function stopBpmRepeat() {
      if (bpmBtnTimer) { clearTimeout(bpmBtnTimer); bpmBtnTimer = null; }
      if (bpmBtnInterval) { clearInterval(bpmBtnInterval); bpmBtnInterval = null; }
      bpmBtnDirection = 0;
    }

    function startBpmRepeat(direction) {
      stopBpmRepeat();
      bpmBtnDirection = direction;
      bpmBtnStartTime = Date.now();
      const sendStep = () => {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({
            type: bpmBtnDirection > 0 ? 'bpmUp' : 'bpmDown'
          });
        }
      };
      sendStep();

      bpmBtnTimer = setTimeout(() => {
        bpmBtnInterval = setInterval(() => {
          const elapsed = Date.now() - bpmBtnStartTime;
          let repeats = 1;
          if (elapsed > 3000) repeats = 5;
          else if (elapsed > 1500) repeats = 3;
          else if (elapsed > 700) repeats = 2;

          for (let i = 0; i < repeats; i++) {
            sendStep();
          }
        }, 80);
      }, 350);
    }

    ['bpm-up', 'bpm-down'].forEach(id => {
      const btn = document.getElementById(id);
      if (btn) {
        const dir = id === 'bpm-up' ? 1 : -1;
        btn.addEventListener('mousedown', (e) => {
          e.stopPropagation();
          e.preventDefault();
          startBpmRepeat(dir);
        });
        btn.addEventListener('mouseleave', stopBpmRepeat);
      }
    });

    // Arp Row Toggle handlers
    const arpTopToggle = document.getElementById('arp-top-toggle');
    if (arpTopToggle) {
      arpTopToggle.addEventListener('click', (e) => {
        e.stopPropagation();
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'toggleArpTop' });
        }
      });
    }
    const arpBottomToggle = document.getElementById('arp-bottom-toggle');
    if (arpBottomToggle) {
      arpBottomToggle.addEventListener('click', (e) => {
        e.stopPropagation();
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'toggleArpBottom' });
        }
      });
    }

    // Draggable Octave Indicators
    document.querySelectorAll('.draggable-octave').forEach(el => {
      el.addEventListener('mousedown', (e) => {
        e.stopPropagation();
        e.preventDefault();
        octaveDragTarget = el.dataset.row;
        octaveDragStartY = e.clientY;
        octaveDragAccum = 0;
      });
    });
  });

  window.addEventListener('mousemove', (e) => {
    if (isBpmDragging) {
      const dy = bpmDragStartY - e.clientY;
      bpmDragAccum += dy;
      bpmDragStartY = e.clientY;
      const stepThreshold = e.shiftKey ? 3 : 8;
      if (Math.abs(bpmDragAccum) >= stepThreshold) {
        hasBpmDragged = true;
        const steps = Math.trunc(bpmDragAccum / stepThreshold);
        bpmDragAccum %= stepThreshold;
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({
            type: 'dragBpm',
            delta: steps
          });
        }
      }
      return;
    }
    if (octaveDragTarget) {
      const dy = octaveDragStartY - e.clientY;
      octaveDragAccum += dy;
      octaveDragStartY = e.clientY;
      if (Math.abs(octaveDragAccum) >= 30) {
        const direction = octaveDragAccum > 0 ? 1 : -1;
        octaveDragAccum = 0;
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({
            type: 'dragOctave',
            row: octaveDragTarget,
            direction: direction
          });
        }
      }
      return;
    }
    if (isModeDragging) {
      handleModeSliderEvent(e);
      return;
    }
    if (!isDragging) return;
    const dx = e.screenX - dragStartX;
    const dy2 = e.screenY - dragStartY;
    dragStartX = e.screenX;
    dragStartY = e.screenY;
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
      window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'dragWindow', dx: dx, dy: dy2 });
    }
  });

  window.addEventListener('mouseup', () => {
    isDragging = false;
    isModeDragging = false;
    octaveDragTarget = null;
    isBpmDragging = false;
    stopBpmRepeat();
  });

  function showSpotlight(spotlight) {
    if (!spotlight) return;
    const card = document.getElementById('spotlight-card');
    const titleEl = document.getElementById('spotlight-title');
    const valEl = document.getElementById('spotlight-val');
    const subEl = document.getElementById('spotlight-sub');
    if (!card || !valEl) return;

    if (spotlightTimer1) clearTimeout(spotlightTimer1);
    if (spotlightTimer2) clearTimeout(spotlightTimer2);

    titleEl.textContent = spotlight.title || '';
    valEl.textContent = spotlight.value || '';
    subEl.textContent = spotlight.subtext || '';

    const color = spotlight.color || '#d4a359';
    card.style.borderColor = color;
    card.style.boxShadow = '0 4px 20px rgba(0,0,0,0.85), 0 0 15px ' + color + '66';
    subEl.style.color = color;

    card.classList.remove('hidden');
    card.style.transition = 'none';
    card.style.opacity = '1';
    card.style.transform = 'translate(-50%, -100%) scale(1.0)';
    card.style.left = '50%';
    card.style.top = '-5px';

    card.offsetHeight;

    card.style.transition = 'opacity 0.4s ease, transform 0.4s ease';

    spotlightTimer1 = setTimeout(() => {
      card.style.opacity = '0';
      card.style.transform = 'translate(-50%, -100%) scale(0.85)';

      spotlightTimer2 = setTimeout(() => {
        card.classList.add('hidden');
      }, 400);
    }, 1000);
  }

  function renderHud(data) {
    if (!data) return;

    if (data.zoomLevel !== undefined) {
      const container = document.getElementById('hud-container');
      if (container) {
        const targetTransform = 'scale(' + data.zoomLevel + ')';
        if (container.style.transform !== targetTransform) {
          container.style.transform = targetTransform;
        }
      }
    }

    if (data.spotlight) {
      showSpotlight(data.spotlight);
    }
    
    if (data.rootIdx !== undefined) {
      const rootSelect = document.getElementById('root-select');
      if (rootSelect) rootSelect.value = data.rootIdx;
    }
    
    if (data.modeName) {
      document.getElementById('mode-name').textContent = data.modeName;
    }

    if (data.arpModeStr !== undefined) {
      const arpBtn = document.getElementById('arp-btn');
      if (arpBtn) {
        arpBtn.textContent = 'ARP: ' + data.arpModeStr;
        if (data.arpModeStr !== 'OFF') {
          arpBtn.classList.add('arp-active');
        } else {
          arpBtn.classList.remove('arp-active');
        }
      }
    }

    if (data.bpmDisplay !== undefined) {
      const bpmVal = document.getElementById('bpm-value');
      if (bpmVal) {
        bpmVal.textContent = data.bpmDisplay;
        if (data.bpmEditing) {
          bpmVal.classList.add('editing');
        } else {
          bpmVal.classList.remove('editing');
        }
      }
    }

    if (data.arpTopEnabled !== undefined) {
      const topToggle = document.getElementById('arp-top-toggle');
      if (topToggle) {
        if (data.arpTopEnabled) topToggle.classList.add('active');
        else topToggle.classList.remove('active');
      }
    }

    if (data.arpBottomEnabled !== undefined) {
      const botToggle = document.getElementById('arp-bottom-toggle');
      if (botToggle) {
        if (data.arpBottomEnabled) botToggle.classList.add('active');
        else botToggle.classList.remove('active');
      }
    }

    if (data.statusText !== undefined) {
      document.getElementById('status-text').textContent = data.statusText;
    }

    if (data.topOctaveStr !== undefined) {
      const topEl = document.getElementById('octave-indicator-top');
      if (topEl) topEl.textContent = 'TOP ' + data.topOctaveStr;
    }

    if (data.bottomOctaveStr !== undefined) {
      const botEl = document.getElementById('octave-indicator-bottom');
      if (botEl) botEl.textContent = 'OCT ' + data.bottomOctaveStr;
    }

    if (data.modeFrac !== undefined && !isModeDragging) {
      document.getElementById('mode-thumb').style.left = (data.modeFrac * 100) + '%';
    }

    if (data.modWheel !== undefined) {
      const intensity = (data.modWheel / 127.0).toFixed(2);
      document.body.style.setProperty('--mod-intensity', intensity);
      const container = document.getElementById('hud-container');
      if (data.modWheel > 0) {
        container.classList.add('mod-active');
      } else {
        container.classList.remove('mod-active');
      }
    }

    if (data.keys) {
      for (const [code, k] of Object.entries(data.keys)) {
        const el = document.getElementById('key-' + code);
        if (el) {
          const noteEl = el.querySelector('.key-note');
          if (noteEl && k.note !== undefined) {
            noteEl.textContent = k.note;
          }
          
          el.className = 'key-pad ' + (k.isControl ? 'control-pad ' : '') + (k.typeClass || '');
          if (k.pressed) el.classList.add('pressed');
          if (k.sustainActive) el.classList.add('sustain-active');
        }
      }
    }
  }

  // Immediate init execution in case DOM ready state passed
  initGrid(LAYOUT_DATA);
</script>
</body>
</html>
]]

local function executeControlAction(act, code)
  if act == "topOctDown" then
    topRowOctaveOffset = math.max(-36, topRowOctaveOffset - 12)
    local spot = {
      title = "TOP ROW OCTAVE",
      value = (topRowOctaveOffset >= 0 and "+" or "") .. math.floor(topRowOctaveOffset / 12) .. " Oct",
      subtext = "Upper Row Pitch",
      targetId = "octave-indicator-top",
      color = "#d4a359"
    }
    updateWebviewHud(spot)
  elseif act == "topOctUp" then
    topRowOctaveOffset = math.min(36, topRowOctaveOffset + 12)
    local spot = {
      title = "TOP ROW OCTAVE",
      value = (topRowOctaveOffset >= 0 and "+" or "") .. math.floor(topRowOctaveOffset / 12) .. " Oct",
      subtext = "Upper Row Pitch",
      targetId = "octave-indicator-top",
      color = "#d4a359"
    }
    updateWebviewHud(spot)
  elseif act == "trnspDown" then
    transposeShift = math.max(-12, transposeShift - 1)
    local spot = {
      title = "TRANSPOSE",
      value = (transposeShift >= 0 and "+" or "") .. transposeShift .. " st",
      subtext = "Semitone Shift",
      targetId = "status-text",
      color = "#d4a359"
    }
    updateWebviewHud(spot)
  elseif act == "trnspUp" then
    transposeShift = math.min(12, transposeShift + 1)
    local spot = {
      title = "TRANSPOSE",
      value = (transposeShift >= 0 and "+" or "") .. transposeShift .. " st",
      subtext = "Semitone Shift",
      targetId = "status-text",
      color = "#d4a359"
    }
    updateWebviewHud(spot)
  elseif act == "octaveDown" then
    octaveShift = math.max(-36, octaveShift - 12)
    local spot = {
      title = "GLOBAL OCTAVE",
      value = (octaveShift >= 0 and "+" or "") .. math.floor(octaveShift / 12) .. " Oct",
      subtext = "Global Pitch Offset",
      targetId = "octave-indicator-bottom",
      color = "#d4a359"
    }
    updateWebviewHud(spot)
  elseif act == "octaveUp" then
    octaveShift = math.min(36, octaveShift + 12)
    local spot = {
      title = "GLOBAL OCTAVE",
      value = (octaveShift >= 0 and "+" or "") .. math.floor(octaveShift / 12) .. " Oct",
      subtext = "Global Pitch Offset",
      targetId = "octave-indicator-bottom",
      color = "#d4a359"
    }
    updateWebviewHud(spot)
  elseif act == "modeDown" then
    currentScaleIdx = (currentScaleIdx - 2) % #SCALES + 1
    updateLatchedArpNotes()
    local scaleInfo = SCALES[currentScaleIdx]
    local spot = {
      title = "SCALE / MODE",
      value = scaleInfo.name,
      subtext = scaleInfo.brightTag,
      targetId = "mode-thumb",
      color = "#d4a359"
    }
    updateWebviewHud(spot)
  elseif act == "modeUp" then
    currentScaleIdx = (currentScaleIdx % #SCALES) + 1
    updateLatchedArpNotes()
    local scaleInfo = SCALES[currentScaleIdx]
    local spot = {
      title = "SCALE / MODE",
      value = scaleInfo.name,
      subtext = scaleInfo.brightTag,
      targetId = "mode-thumb",
      color = "#d4a359"
    }
    updateWebviewHud(spot)
  elseif act == "rootDown" then
    currentRoot = (currentRoot - 1) % 12
    updateLatchedArpNotes()
    local rootName = NOTE_NAMES[currentRoot + 1]
    local spot = {
      title = "ROOT NOTE",
      value = rootName,
      subtext = rootName .. " " .. SCALES[currentScaleIdx].name,
      targetId = "root-select",
      color = "#d4a359"
    }
    updateWebviewHud(spot)
  elseif act == "rootUp" then
    currentRoot = (currentRoot + 1) % 12
    updateLatchedArpNotes()
    local rootName = NOTE_NAMES[currentRoot + 1]
    local spot = {
      title = "ROOT NOTE",
      value = rootName,
      subtext = rootName .. " " .. SCALES[currentScaleIdx].name,
      targetId = "root-select",
      color = "#d4a359"
    }
    updateWebviewHud(spot)
  elseif act == "randomScale" then
    currentRoot = math.random(0, 11)
    currentScaleIdx = math.random(1, #SCALES)
    updateLatchedArpNotes()
    local rootName = NOTE_NAMES[currentRoot + 1]
    local scaleInfo = SCALES[currentScaleIdx]
    local spot = {
      title = "RANDOM SCALE",
      value = rootName .. " " .. scaleInfo.name,
      subtext = scaleInfo.brightTag,
      targetId = "mode-thumb",
      color = "#d4a359"
    }
    updateWebviewHud(spot)
  elseif act == "panic" then
    sendMidiCC(123, 0)
    pressedKeys = {}
    stopArpTimer()
    arpHeldNotes = {}
    arpKeysCurrentlyHeld = {}
    local spot = {
      title = "MIDI PANIC",
      value = "ALL NOTES OFF",
      subtext = "Reset Active Notes",
      targetId = code and ("key-" .. code) or "header",
      color = "#d4a359"
    }
    updateWebviewHud(spot)
  elseif act == "resetAll" then
    octaveShift = 0
    topRowOctaveOffset = 0
    transposeShift = 0
    currentRoot = 0
    currentScaleIdx = 1
    sustainActive = false
    ccStates[1] = 0
    activeWatchers.modAccumulator = 0
    stopArpTimer()
    arpHeldNotes = {}
    arpKeysCurrentlyHeld = {}
    arpMode = 0
    sendMidiCC(64, 0)
    sendMidiCC(1, 0)
    local spot = {
      title = "RESET ALL",
      value = "DEFAULTS RESTORED",
      subtext = "All Parameters Reset",
      targetId = code and ("key-" .. code) or "header",
      color = "#d4a359"
    }
    updateWebviewHud(spot)
  elseif act == "zoomOut" then
    zoomLevel = math.max(0.5, zoomLevel - 0.1)
    local spot = {
      title = "HUD ZOOM",
      value = math.floor(zoomLevel * 100) .. "%",
      subtext = "Scale Factor",
      targetId = "header",
      color = "#d4a359"
    }
    updateWebviewHud(spot)
  elseif act == "zoomIn" then
    zoomLevel = math.min(2.0, zoomLevel + 0.1)
    local spot = {
      title = "HUD ZOOM",
      value = math.floor(zoomLevel * 100) .. "%",
      subtext = "Scale Factor",
      targetId = "header",
      color = "#d4a359"
    }
    updateWebviewHud(spot)
  elseif act == "sustain" or act == "latch" then
    sustainKeyDownTime = hs.timer.secondsSinceEpoch()
    sustainWasActiveOnPress = sustainActive
    sustainActive = true
    sendMidiCC(64, 127)
    local spot = {
      title = "SUSTAIN / LATCH (CC #64)",
      value = "SUSTAIN ON",
      subtext = "Notes & Arp pattern hold",
      targetId = "key-0",
      color = "#d4a359"
    }
    updateWebviewHud(spot)
  elseif act == "modWheelDown" then
    local currentVal = ccStates[1] or 0
    local newVal = math.max(0, currentVal - 4)
    ccStates[1] = newVal
    activeWatchers.modAccumulator = newVal
    sendMidiCC(1, newVal)
    local spot = {
      title = "MOD WHEEL",
      value = math.floor((newVal / 127) * 100) .. "%",
      subtext = "CC #1 Intensity",
      targetId = "header",
      color = "#d4a359"
    }
    updateWebviewHud(spot)
  elseif act == "modWheelUp" or act == "modWheel" then
    local currentVal = ccStates[1] or 0
    local newVal = math.min(127, currentVal + 4)
    ccStates[1] = newVal
    activeWatchers.modAccumulator = newVal
    sendMidiCC(1, newVal)
    local spot = {
      title = "MOD WHEEL",
      value = math.floor((newVal / 127) * 100) .. "%",
      subtext = "CC #1 Intensity",
      targetId = "header",
      color = "#d4a359"
    }
    updateWebviewHud(spot)
  elseif act == "volDown" then
    local currentVal = ccStates[7] or 100
    local newVal = math.max(0, currentVal - 4)
    ccStates[7] = newVal
    sendMidiCC(7, newVal)
    local spot = {
      title = "MASTER VOLUME",
      value = math.floor((newVal / 127) * 100) .. "%",
      subtext = "CC #7 Level",
      targetId = "header",
      color = "#d4a359"
    }
    updateWebviewHud(spot)
  elseif act == "volUp" or act == "volume" then
    local currentVal = ccStates[7] or 100
    local newVal = math.min(127, currentVal + 4)
    ccStates[7] = newVal
    sendMidiCC(7, newVal)
    local spot = {
      title = "MASTER VOLUME",
      value = math.floor((newVal / 127) * 100) .. "%",
      subtext = "CC #7 Level",
      targetId = "header",
      color = "#d4a359"
    }
    updateWebviewHud(spot)
  end
end

local function handleKeyDown(code)
  -- Backtick: Arp toggle
  if code == 50 then
    if not pressedKeys[code] then
      pressedKeys[code] = true
      toggleArp()
    end
    return true
  end

  if lowerRowKeys[code] then
    local kData = lowerRowKeys[code]
    if not pressedKeys[code] then
      local transposedPitch = getTransposedPitch(kData.baseNote, false)
      pressedKeys[code] = transposedPitch
      if arpMode > 0 and arpBottomEnabled then
        arpAddNote(code, transposedPitch)
      else
        sendMidiNote("noteOn", transposedPitch, 100)
      end
      updateWebviewHud()
    end
    return true
  elseif upperRowKeys[code] then
    local kData = upperRowKeys[code]
    if not pressedKeys[code] then
      local transposedPitch = getTransposedPitch(kData.baseNote, true)
      pressedKeys[code] = transposedPitch
      if arpMode > 0 and arpTopEnabled then
        arpAddNote(code, transposedPitch)
      else
        sendMidiNote("noteOn", transposedPitch, 100)
      end
      updateWebviewHud()
    end
    return true
  elseif numberRowControls[code] then
    local cData = numberRowControls[code]
    if not pressedKeys[code] then
      pressedKeys[code] = true
      executeControlAction(cData.action, code)
    end
    return true
  elseif homeRowControls[code] then
    local cData = homeRowControls[code]
    if not pressedKeys[code] then
      pressedKeys[code] = true
      local act = shiftHeld and cData.shiftAction or cData.action
      executeControlAction(act, code)
    end
    return true
  end
  return false
end

local function handleKeyUp(code)
  -- Backtick
  if code == 50 then
    pressedKeys[code] = nil
    updateWebviewHud()
    return true
  end

  if lowerRowKeys[code] or upperRowKeys[code] then
    local playedPitch = pressedKeys[code]
    if playedPitch then
      local isTop = upperRowKeys[code] ~= nil
      local arpEnabledForRow = isTop and arpTopEnabled or arpBottomEnabled
      if arpMode > 0 and arpEnabledForRow then
        arpRemoveNote(code)
      else
        if not sustainActive then
          sendMidiNote("noteOff", playedPitch, 0)
        end
      end
      pressedKeys[code] = nil
    end
    updateWebviewHud()
    return true
  elseif numberRowControls[code] then
    pressedKeys[code] = nil
    updateWebviewHud()
    return true
  elseif homeRowControls[code] then
    local cData = homeRowControls[code]
    pressedKeys[code] = nil
    local act = shiftHeld and cData.shiftAction or cData.action
    if act == "sustain" or act == "latch" then
      local holdDuration = hs.timer.secondsSinceEpoch() - sustainKeyDownTime
      if holdDuration > 0.25 then
        -- Momentary release when held > 0.25s
        sustainActive = false
        sendMidiCC(64, 0)
      else
        -- Quick tap toggle
        if sustainWasActiveOnPress then
          sustainActive = false
          sendMidiCC(64, 0)
        else
          sustainActive = true
          sendMidiCC(64, 127)
        end
      end

      if not sustainActive and arpMode > 0 then
        local numPhysicalHeld = 0
        for _ in pairs(arpKeysCurrentlyHeld) do numPhysicalHeld = numPhysicalHeld + 1 end
        if numPhysicalHeld == 0 then
          stopArpTimer()
          arpHeldNotes = {}
        end
      end

      local spot = {
        title = "SUSTAIN / LATCH (CC #64)",
        value = sustainActive and "SUSTAIN ON" or "SUSTAIN OFF",
        subtext = sustainActive and "Notes & Arp pattern hold" or "Damping enabled",
        targetId = "key-0",
        color = sustainActive and "#d4a359" or "#b5aba0"
      }
      updateWebviewHud(spot)
    else
      updateWebviewHud()
    end
    return true
  end
  return false
end

updateWebviewHud = function(spotlightInfo, activeArpPitch)
  if not activeWatchers.midiWebview then return end

  -- Dynamically resize window frame to match zoom level for crisp rendering
  local baseW, baseH = 810, 330
  local effectiveScale = zoomLevel * BASE_HUD_SCALE
  local newW = math.floor(baseW * effectiveScale)
  local newH = math.floor(baseH * effectiveScale)
  local curFrame = activeWatchers.midiWebview:frame()

  if curFrame.w ~= newW or curFrame.h ~= newH then
    local screen = hs.screen.mainScreen():frame()
    local cx = curFrame.x + (curFrame.w / 2)
    local cy = curFrame.y + (curFrame.h / 2)
    local nx = math.floor(cx - (newW / 2))
    local ny = math.floor(cy - (newH / 2))
    nx = math.max(screen.x, math.min(screen.x + screen.w - newW, nx))
    ny = math.max(screen.y, math.min(screen.y + screen.h - newH, ny))
    activeWatchers.midiWebview:frame({ x = nx, y = ny, w = newW, h = newH })
    activeWatchers.hudX = nx
    activeWatchers.hudY = ny
    hs.settings.set("qwertyMidi_hudX", nx)
    hs.settings.set("qwertyMidi_hudY", ny)
  end

  hs.settings.set("qwertyMidi_zoomLevel", zoomLevel)
  
  local modeFrac = (currentScaleIdx - 0.5) / #SCALES
  local modeName = SCALES[currentScaleIdx].name
  
  local octStr = (octaveShift >= 0 and "+" or "") .. (octaveShift / 12) .. " Oct"
  local trnspStr = (transposeShift ~= 0) and ("Trnsp: " .. (transposeShift >= 0 and "+" or "") .. transposeShift .. "st") or ""
  local susStr = sustainActive and "SUS: ON" or ""
  local shiftStr = shiftHeld and "[SHIFT]" or ""

  local statusParts = {}
  if trnspStr ~= "" then table.insert(statusParts, trnspStr) end
  if susStr ~= "" then table.insert(statusParts, susStr) end
  if shiftStr ~= "" then table.insert(statusParts, shiftStr) end
  local statusStr = table.concat(statusParts, "  •  ")

  local topOctaveStr = (topRowOctaveOffset >= 0 and "+" or "") .. math.floor(topRowOctaveOffset / 12)
  local bottomOctaveStr = (octaveShift >= 0 and "+" or "") .. math.floor(octaveShift / 12)

  local keyUpdates = {}

  for code, cData in pairs(numberRowControls) do
    local isMode = (cData.action == "modeDown" or cData.action == "modeUp")
    keyUpdates[tostring(code)] = {
      note = cData.name,
      isControl = true,
      typeClass = isMode and "mode-control" or "",
      pressed = (pressedKeys[code] ~= nil)
    }
  end

  for code, kData in pairs(upperRowKeys) do
    local noteNum = getTransposedPitch(kData.baseNote, true)
    local intervalIdx = getIntervalInfo(noteNum)
    local noteName = noteNumToName(noteNum)
    local typeClass = ""

    if intervalIdx == 1 then
      typeClass = "root-key"
    elseif intervalIdx == 3 then
      typeClass = "third-key"
    elseif intervalIdx == 5 then
      typeClass = "fifth-key"
    end

    local isPressed = (pressedKeys[code] ~= nil)
    if arpMode > 0 and activeArpPitch and noteNum == activeArpPitch then
      isPressed = true
    end

    keyUpdates[tostring(code)] = {
      note = noteName,
      typeClass = typeClass,
      pressed = isPressed
    }
  end

  for code, kData in pairs(lowerRowKeys) do
    local noteNum = getTransposedPitch(kData.baseNote, false)
    local intervalIdx = getIntervalInfo(noteNum)
    local noteName = noteNumToName(noteNum)
    local typeClass = ""

    if intervalIdx == 1 then
      typeClass = "root-key"
    elseif intervalIdx == 3 then
      typeClass = "third-key"
    elseif intervalIdx == 5 then
      typeClass = "fifth-key"
    end

    local isPressed = (pressedKeys[code] ~= nil)
    if arpMode > 0 and activeArpPitch and noteNum == activeArpPitch then
      isPressed = true
    end

    keyUpdates[tostring(code)] = {
      note = noteName,
      typeClass = typeClass,
      pressed = isPressed
    }
  end

  for code, cData in pairs(homeRowControls) do
    local label = shiftHeld and cData.shiftName or cData.name
    local act = shiftHeld and cData.shiftAction or cData.action
    local isSustain = (code == 0 or code == 48)
    local isMode = (act == "modeDown" or act == "modeUp")
    keyUpdates[tostring(code)] = {
      note = label,
      isControl = true,
      typeClass = isMode and "mode-control" or "",
      pressed = (pressedKeys[code] ~= nil),
      sustainActive = isSustain and sustainActive
    }
  end

  local modVal = ccStates[1] or 0

  local bpmDisplayStr
  if bpmInputMode then
    bpmDisplayStr = bpmInputBuffer .. "\226\150\140"
  else
    bpmDisplayStr = formatBpm(arpBpm) .. " BPM"
  end

  local payload = {
    rootIdx = currentRoot,
    modeName = modeName,
    arpModeStr = ARP_MODES[arpMode + 1],
    bpmDisplay = bpmDisplayStr,
    bpmEditing = bpmInputMode,
    arpTopEnabled = arpTopEnabled,
    arpBottomEnabled = arpBottomEnabled,
    statusText = statusStr,
    topOctaveStr = topOctaveStr,
    bottomOctaveStr = bottomOctaveStr,
    modeFrac = modeFrac,
    modWheel = modVal,
    zoomLevel = effectiveScale,
    spotlight = spotlightInfo,
    keys = keyUpdates
  }

  local jsonStr = hs.json.encode(payload)
  activeWatchers.midiWebview:evaluateJavaScript("renderHud(" .. jsonStr .. ")")
end

local function buildLayoutJson()
  local numberList = {
    { code = 18, keyLabel = "1", isControl = true, noteLabel = "TopOct -" },
    { code = 19, keyLabel = "2", isControl = true, noteLabel = "TopOct +" },
    { code = 20, keyLabel = "3", isControl = true, noteLabel = "Trnsp -" },
    { code = 21, keyLabel = "4", isControl = true, noteLabel = "Trnsp +" },
    { code = 23, keyLabel = "5", isControl = true, noteLabel = "Oct -" },
    { code = 22, keyLabel = "6", isControl = true, noteLabel = "Oct +" },
    { code = 26, keyLabel = "7", isControl = true, noteLabel = "Mode -" },
    { code = 28, keyLabel = "8", isControl = true, noteLabel = "Mode +" },
    { code = 25, keyLabel = "9", isControl = true, noteLabel = "Panic" },
    { code = 29, keyLabel = "0", isControl = true, noteLabel = "Reset" },
    { code = 27, keyLabel = "-", isControl = true, noteLabel = "Zoom -" },
    { code = 24, keyLabel = "=", isControl = true, noteLabel = "Zoom +" }
  }

  local upperList = {
    { code = 12, keyLabel = "Q" }, { code = 13, keyLabel = "W" }, { code = 14, keyLabel = "E" },
    { code = 15, keyLabel = "R" }, { code = 17, keyLabel = "T" }, { code = 16, keyLabel = "Y" },
    { code = 32, keyLabel = "U" }, { code = 34, keyLabel = "I" }, { code = 31, keyLabel = "O" }, { code = 35, keyLabel = "P" }
  }

  local homeList = {
    { code = 0,  keyLabel = "A", isControl = true, noteLabel = "Sustain" },
    { code = 1,  keyLabel = "S", isControl = true, noteLabel = "Random" },
    { code = 2,  keyLabel = "D", isControl = true, noteLabel = "Oct -" },
    { code = 3,  keyLabel = "F", isControl = true, noteLabel = "Oct +" },
    { code = 5,  keyLabel = "G", isControl = true, noteLabel = "Vol -" },
    { code = 4,  keyLabel = "H", isControl = true, noteLabel = "Root -" },
    { code = 38, keyLabel = "J", isControl = true, noteLabel = "Mode -" },
    { code = 40, keyLabel = "K", isControl = true, noteLabel = "Mode +" },
    { code = 37, keyLabel = "L", isControl = true, noteLabel = "Root +" },
    { code = 41, keyLabel = ";", isControl = true, noteLabel = "Vol +" }
  }

  local lowerList = {
    { code = 6,  keyLabel = "Z" }, { code = 7,  keyLabel = "X" }, { code = 8,  keyLabel = "C" },
    { code = 9,  keyLabel = "V" }, { code = 11, keyLabel = "B" }, { code = 45, keyLabel = "N" },
    { code = 46, keyLabel = "M" }, { code = 43, keyLabel = "," }, { code = 47, keyLabel = "." }, { code = 44, keyLabel = "/" }
  }

  return hs.json.encode({ number = numberList, upper = upperList, home = homeList, lower = lowerList })
end

local function createMidiWebview()
  if activeWatchers.midiWebview then
    activeWatchers.midiWebview:delete()
    activeWatchers.midiWebview = nil
  end

  local screen = hs.screen.mainScreen():frame()
  local effectiveScale = zoomLevel * BASE_HUD_SCALE
  local width = math.floor(810 * effectiveScale)
  local height = math.floor(330 * effectiveScale)
  local savedX = hs.settings.get("qwertyMidi_hudX")
  local savedY = hs.settings.get("qwertyMidi_hudY")
  local hudX = savedX or activeWatchers.hudX or math.floor(screen.x + (screen.w - width) / 2)
  local hudY = savedY or activeWatchers.hudY or math.floor(screen.y + screen.h - height - 60)

  local uc = hsUsercontent.new("midiControllerUC")
  uc:setCallback(function(msg)
    if not msg or not msg.body then return end
    local body = msg.body
    if body.type == "domReady" then
      updateWebviewHud()
    elseif body.type == "keyDown" and body.code then
      handleKeyDown(body.code)
    elseif body.type == "keyUp" and body.code then
      handleKeyUp(body.code)
    elseif body.type == "setRoot" and body.root ~= nil then
      currentRoot = math.max(0, math.min(11, body.root))
      updateLatchedArpNotes()
      local rootName = NOTE_NAMES[currentRoot + 1]
      local spot = {
        title = "ROOT NOTE",
        value = rootName,
        subtext = rootName .. " " .. SCALES[currentScaleIdx].name,
        targetId = "root-select",
        color = "#d4a359"
      }
      updateWebviewHud(spot)
    elseif body.type == "setModeIdx" and body.modeIdx ~= nil then
      currentScaleIdx = math.max(1, math.min(#SCALES, body.modeIdx))
      updateLatchedArpNotes()
      local scaleInfo = SCALES[currentScaleIdx]
      local spot = {
        title = "SCALE / MODE",
        value = scaleInfo.name,
        subtext = scaleInfo.brightTag,
        targetId = "mode-thumb",
        color = "#d4a359"
      }
      updateWebviewHud(spot)
    elseif body.type == "cycleArpMode" then
      cycleArpMode()
    elseif body.type == "enterBpmEdit" then
      bpmInputMode = true
      bpmBeforeEdit = arpBpm
      bpmInputBuffer = ""
      updateWebviewHud()
    elseif body.type == "bpmUp" then
      arpBpm = math.min(300, arpBpm + 1)
      applyBpmChange()
      updateWebviewHud()
    elseif body.type == "bpmDown" then
      arpBpm = math.max(20, arpBpm - 1)
      applyBpmChange()
      updateWebviewHud()
    elseif body.type == "dragBpm" and body.delta ~= nil then
      arpBpm = math.max(20.0, math.min(300.0, arpBpm + body.delta))
      applyBpmChange()
      updateWebviewHud()
    elseif body.type == "toggleArpTop" then
      if arpTopEnabled or not arpBottomEnabled then
        arpTopEnabled = not arpTopEnabled
      end
      updateWebviewHud()
    elseif body.type == "toggleArpBottom" then
      if arpBottomEnabled or not arpTopEnabled then
        arpBottomEnabled = not arpBottomEnabled
      end
      updateWebviewHud()
    elseif body.type == "dragOctave" and body.row and body.direction then
      if body.row == "top" then
        topRowOctaveOffset = math.max(-36, math.min(36, topRowOctaveOffset + (body.direction * 12)))
      else
        octaveShift = math.max(-36, math.min(36, octaveShift + (body.direction * 12)))
      end
      updateWebviewHud()
    elseif body.type == "dragWindow" and body.dx and body.dy then
      if activeWatchers.midiWebview then
        local frame = activeWatchers.midiWebview:frame()
        local newX = math.floor(frame.x + body.dx)
        local newY = math.floor(frame.y + body.dy)
        activeWatchers.midiWebview:frame({ x = newX, y = newY, w = frame.w, h = frame.h })
        activeWatchers.hudX = newX
        activeWatchers.hudY = newY
        hs.settings.set("qwertyMidi_hudX", newX)
        hs.settings.set("qwertyMidi_hudY", newY)
      end
    end
  end)

  local rect = { x = hudX, y = hudY, w = width, h = height }
  local wv = hsWebview.new(rect, { developerExtrasEnabled = false }, uc)
  wv:windowTitle("MIDI Controller HUD")
  wv:windowStyle({ "borderless", "utility" })
  wv:transparent(true)
  wv:html(HTML_UI_CONTENT)
  wv:level(hs.canvas.windowLevels.floating)
  wv:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
  wv:show()

  wv:windowCallback(function(action, webview)
    if action == "closing" then
      activeWatchers.midiWebview = nil
    end
  end)

  activeWatchers.midiWebview = wv

  -- Staggered fallbacks in case DOM ready fires before/after callback setup
  hs.timer.doAfter(0.05, function()
    if activeWatchers.midiWebview then
      updateWebviewHud()
    end
  end)
  hs.timer.doAfter(0.25, function()
    if activeWatchers.midiWebview then
      updateWebviewHud()
    end
  end)

  return wv
end

-- ── MIDI Mode State Toggle ───────────────────────────────────────────────────

function _G.toggleMidiMode(newState)
  if newState == nil then
    midiActive = not midiActive
  else
    midiActive = newState
  end

  if midiActive then
    activeWatchers.midiKeyTap:start()
    activeWatchers.midiScrollTap:start()
    local hud = createMidiWebview()
    hud:show()
  else
    activeWatchers.midiKeyTap:stop()
    activeWatchers.midiScrollTap:stop()
    pressedKeys = {}
    stopArpTimer()
    arpHeldNotes = {}
    arpKeysCurrentlyHeld = {}
    if activeWatchers.midiWebview then
      activeWatchers.midiWebview:hide()
    end
  end
  hs.alert.show("🎹 MIDI Mode: " .. (midiActive and "ON" or "OFF"))
end

-- ── Trackpad 2-Finger Scroll Handler (Mod Wheel / Volume when Shift held) ────
activeWatchers.midiScrollTap = hs.eventtap.new({ hs.eventtap.event.types.scrollWheel }, function(event)
  if not midiActive then return false end

  local deltaY = event:getProperty(hs.eventtap.event.properties.scrollWheelEventDeltaAxis1) or 0
  if deltaY == 0 then
    deltaY = event:getProperty(hs.eventtap.event.properties.scrollWheelEventPointDeltaAxis1) or 0
  end

  if deltaY ~= 0 then
    if shiftHeld then
      -- Volume Scroll when Shift is held
      local currentVol = ccStates[7] or 100
      activeWatchers.volAccumulator = activeWatchers.volAccumulator or currentVol
      local sensitivity = 0.25
      activeWatchers.volAccumulator = math.max(0, math.min(127, activeWatchers.volAccumulator - (deltaY * sensitivity)))
      local newVol = math.floor(activeWatchers.volAccumulator + 0.5)

      if newVol ~= ccStates[7] then
        ccStates[7] = newVol
        sendMidiCC(7, newVol)
        local spot = {
          title = "MASTER VOLUME (CC #7)",
          value = tostring(newVol),
          subtext = math.floor((newVol / 127) * 100) .. "% Level",
          targetId = "header",
          color = "#d4a359"
        }
        updateWebviewHud(spot)
      end
    else
      -- Mod Wheel Scroll when Shift is not held
      local currentMod = ccStates[1] or 0
      activeWatchers.modAccumulator = activeWatchers.modAccumulator or currentMod
      local sensitivity = 0.15
      activeWatchers.modAccumulator = math.max(0, math.min(127, activeWatchers.modAccumulator - (deltaY * sensitivity)))
      local newMod = math.floor(activeWatchers.modAccumulator + 0.5)

      if newMod ~= ccStates[1] then
        ccStates[1] = newMod
        sendMidiCC(1, newMod)
        local spot = {
          title = "MOD WHEEL (CC #1)",
          value = tostring(newMod),
          subtext = math.floor((newMod / 127) * 100) .. "% Intensity",
          targetId = "header",
          color = "#d4a359"
        }
        updateWebviewHud(spot)
      end
    end
    return true -- Swallow scroll event
  end

  return false
end)

-- ── Key Event Tap Handler ─────────────────────────────────────────────────────

activeWatchers.midiKeyTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp, hs.eventtap.event.types.flagsChanged }, function(event)
  if not midiActive then return false end

  local flags = event:getFlags()

  -- BPM Input Mode: intercept keys before modifier filtering
  if bpmInputMode then
    if event:getType() == hs.eventtap.event.types.flagsChanged then
      return false
    end
    if flags.cmd or flags.ctrl then return false end
    local code = event:getProperty(hs.eventtap.event.properties.keyboardEventKeycode)
    local isDown = (event:getType() == hs.eventtap.event.types.keyDown)
    if isDown then
      return handleBpmInput(code, flags)
    end
    return true -- swallow key ups during BPM mode
  end

  if flags.cmd or flags.alt or flags.ctrl then
    return false
  end

  local isShiftNow = flags.shift
  if isShiftNow ~= shiftHeld then
    shiftHeld = isShiftNow
    updateWebviewHud()
  end

  if event:getType() == hs.eventtap.event.types.flagsChanged then
    return false
  end

  local code = event:getProperty(hs.eventtap.event.properties.keyboardEventKeycode)
  local isDown = (event:getType() == hs.eventtap.event.types.keyDown)

  if isDown then
    return handleKeyDown(code)
  else
    return handleKeyUp(code)
  end
end)

-- Toggle MIDI Mode hotkey (Cmd + Option + M)
activeWatchers.midiToggleHotkey = hs.hotkey.bind({ "cmd", "alt" }, "M", function()
  _G.toggleMidiMode()
end)
