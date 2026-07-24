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
local sustainActive = false      -- Toggle state for sustain pedal (CC64)
local sustainKeyDownTime = 0     -- Timestamp when sustain key was pressed down
local sustainWasActiveOnPress = false
local shiftHeld = false          -- Shift key active state
local zoomLevel = 1.0            -- HUD Zoom Scale Factor (0.5 to 2.0)

local ccStates = {
  [1] = 0,   -- Mod Wheel default 0
  [7] = 100  -- Volume default 100
}

local function getTransposedPitch(basePitch, isTopRow)
  local effectivePitch = basePitch + (isTopRow and topRowOctaveOffset or 0)
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

-- ── Key Mappings (SWAPPED: Oct +/- on D/F, Mod +/- on J/K) ─────────────────
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
  [5]  = { key = "G",   name = "Vol -",   action = "volDown",     shiftAction = "volDown",     shiftName = "Vol -" },
  [4]  = { key = "H",   name = "Root -",  action = "rootDown",    shiftAction = "topOctDown", shiftName = "TopOct -" },
  [38] = { key = "J",   name = "Mod -",   action = "modWheelDown",shiftAction = "modeDown",   shiftName = "Mode -" },
  [40] = { key = "K",   name = "Mod +",   action = "modWheelUp",  shiftAction = "modeUp",     shiftName = "Mode +" },
  [37] = { key = "L",   name = "Root +",  action = "rootUp",      shiftAction = "topOctUp",   shiftName = "TopOct +" },
  [41] = { key = ";",   name = "Vol +",   action = "volUp",       shiftAction = "volUp",       shiftName = "Vol +" }
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

-- ── HTML UI Engine ─────────────────────────────────────────────────────────────
local HTML_UI_CONTENT = [[
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; user-select: none; -webkit-user-select: none; -webkit-font-smoothing: antialiased; }
  html, body {
    background: transparent;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    width: 100%;
    height: 100%;
    overflow: hidden;
    display: flex;
    justify-content: center;
    align-items: center;
  }
  
  #hud-container {
    width: 760px;
    height: 230px;
    background: rgba(20, 24, 33, 0.95);
    border: 2px solid rgba(50, 65, 90, 0.8);
    border-radius: 14px;
    box-shadow: 0 10px 30px rgba(0,0,0,0.5), inset 0 0 20px rgba(0, 0, 0, 0.5);
    display: flex;
    flex-direction: column;
    padding: 10px 14px 14px 14px;
    position: relative;
    transform-origin: center center;
    transition: transform 0.15s cubic-bezier(0.16, 1, 0.3, 1), border-color 0.15s ease, box-shadow 0.15s ease;
  }

  /* Central Spotlight Popup */
  .spotlight-card {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%) scale(1.4);
    background: rgba(16, 22, 34, 0.96);
    border: 2px solid #e6b432;
    border-radius: 12px;
    padding: 14px 24px;
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.85);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    pointer-events: none;
    opacity: 1;
    backdrop-filter: blur(10px);
    -webkit-backdrop-filter: blur(10px);
  }

  .spotlight-card.hidden {
    opacity: 0;
    display: none;
  }

  .spotlight-title {
    font-size: 11px;
    font-weight: 800;
    letter-spacing: 1.5px;
    color: #9ab0c7;
    text-transform: uppercase;
    margin-bottom: 4px;
  }

  .spotlight-val {
    font-size: 26px;
    font-weight: 900;
    color: #ffffff;
    text-shadow: 0 2px 8px rgba(0,0,0,0.6);
    margin-bottom: 4px;
    white-space: nowrap;
  }

  .spotlight-sub {
    font-size: 12px;
    font-weight: 600;
    color: #e6b432;
    white-space: nowrap;
  }
  
  /* Dynamic Mod Wheel Glow */
  #hud-container.mod-active {
    box-shadow: 0 0 calc(10px + var(--mod-intensity) * 25px) rgba(255, 140, 0, calc(0.3 + var(--mod-intensity) * 0.5)),
                inset 0 0 calc(15px + var(--mod-intensity) * 30px) rgba(255, 140, 0, calc(0.2 + var(--mod-intensity) * 0.4));
    border-color: rgba(255, 160, 50, calc(0.5 + var(--mod-intensity) * 0.5));
  }

  .mod-gradient-overlay {
    position: absolute;
    top: 0; left: 0; right: 0; bottom: 0;
    border-radius: 12px;
    pointer-events: none;
    background: linear-gradient(180deg, rgba(255, 140, 0, calc(var(--mod-intensity) * 0.3)) 0%, rgba(255, 90, 0, 0) 100%);
    opacity: 0;
    transition: opacity 0.15s ease;
  }

  #hud-container.mod-active .mod-gradient-overlay {
    opacity: 1;
  }

  /* Header Bar */
  #header {
    height: 32px;
    background: rgba(30, 38, 52, 0.9);
    border-radius: 8px;
    display: flex;
    align-items: center;
    padding: 0 10px;
    margin-bottom: 10px;
    cursor: move;
    -webkit-app-region: drag;
  }

  .badge {
    background: rgba(230, 180, 50, 0.25);
    border: 1.5px solid #e6b432;
    color: #e6b432;
    font-weight: 700;
    font-size: 13px;
    padding: 2px 12px;
    border-radius: 6px;
    margin-right: 12px;
    display: flex;
    align-items: center;
    gap: 4px;
    white-space: nowrap;
  }

  .mode-slider-track {
    flex: 1;
    height: 8px;
    background: linear-gradient(90deg, #ffd700 0%, #ff8c00 30%, #4682b4 70%, #2f4f4f 100%);
    border-radius: 4px;
    position: relative;
    margin: 0 12px;
  }

  .mode-slider-thumb {
    width: 8px;
    height: 14px;
    background: #ffffff;
    border: 1px solid #333;
    border-radius: 3px;
    position: absolute;
    top: -3px;
    left: 50%;
    transform: translateX(-50%);
    box-shadow: 0 1px 4px rgba(0,0,0,0.6);
    transition: left 0.15s ease;
  }

  .status-info {
    font-size: 12px;
    color: #9ab0c7;
    font-weight: 600;
    margin-left: 10px;
    white-space: nowrap;
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
    gap: 6px;
  }

  .keyboard-row.upper { margin-left: 0px; }
  .keyboard-row.home { margin-left: 18px; }
  .keyboard-row.lower { margin-left: 42px; }

  .key-pad {
    width: 66px;
    height: 46px;
    background: rgba(30, 38, 50, 0.95);
    border: 1.5px solid rgba(50, 65, 80, 1.0);
    border-radius: 8px;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    transition: background 0.05s ease, border-color 0.05s ease, transform 0.05s ease;
    cursor: pointer;
  }

  .key-pad:active, .key-pad.pressed {
    transform: translateY(2px);
  }

  .key-pad .key-code {
    font-size: 13px;
    font-weight: 700;
    color: rgba(160, 180, 205, 0.9);
  }

  .key-pad .key-note {
    font-size: 11px;
    font-weight: 600;
    color: rgba(120, 145, 175, 0.8);
    margin-top: 2px;
    white-space: nowrap;
  }

  /* Key Color Accents */
  .key-pad.root-key { border-color: #e6b432; }
  .key-pad.root-key .key-note { color: #e6b432; font-weight: 700; }
  .key-pad.root-key.pressed { background: rgba(230, 180, 50, 0.35); }

  .key-pad.third-key { border-color: #32b4cc; }
  .key-pad.third-key .key-note { color: #32b4cc; font-weight: 700; }
  .key-pad.third-key.pressed { background: rgba(50, 180, 204, 0.35); }

  .key-pad.fifth-key { border-color: #9b80cc; }
  .key-pad.fifth-key .key-note { color: #9b80cc; font-weight: 700; }
  .key-pad.fifth-key.pressed { background: rgba(155, 128, 204, 0.35); }

  .key-pad.control-pad {
    background: rgba(38, 46, 60, 0.95);
    border-color: rgba(65, 80, 100, 1.0);
  }

  .key-pad.control-pad .key-note {
    color: #b0c4de;
    font-size: 10.5px;
  }

  .key-pad.sustain-active {
    background: rgba(230, 180, 50, 0.3);
    border-color: #e6b432;
  }

  .key-pad.sustain-active .key-note {
    color: #e6b432;
    font-weight: 700;
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
      <div id="root-badge" class="badge">♩ C</div>
      <div class="mode-slider-track">
        <div id="mode-thumb" class="mode-slider-thumb"></div>
      </div>
      <div id="status-text" class="status-info">Major / Ionian  •  +0 Oct  •  Top: +1 Oct  •  SUS: OFF</div>
    </div>
    
    <div class="keyboard-grid">
      <div id="row-upper" class="keyboard-row upper"></div>
      <div id="row-home" class="keyboard-row home"></div>
      <div id="row-lower" class="keyboard-row lower"></div>
    </div>
  </div>

<script>
  let spotlightTimer1 = null;
  let spotlightTimer2 = null;

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

    const color = spotlight.color || '#e6b432';
    card.style.borderColor = color;
    card.style.boxShadow = '0 12px 40px rgba(0,0,0,0.85), 0 0 25px ' + color + '66';
    subEl.style.color = color;

    card.classList.remove('hidden');
    card.style.transition = 'none';
    card.style.left = '50%';
    card.style.top = '50%';
    card.style.transform = 'translate(-50%, -50%) scale(1.4)';
    card.style.opacity = '1';

    card.offsetHeight; // Force layout reflow

    card.style.transition = 'transform 0.45s cubic-bezier(0.16, 1, 0.3, 1), opacity 0.4s ease, left 0.45s cubic-bezier(0.16, 1, 0.3, 1), top 0.45s cubic-bezier(0.16, 1, 0.3, 1)';

    spotlightTimer1 = setTimeout(() => {
      let targetX = '50%';
      let targetY = '50%';
      let targetScale = 'scale(0.35)';

      if (spotlight.targetId) {
        const targetEl = document.getElementById(spotlight.targetId);
        const container = document.getElementById('hud-container');
        if (targetEl && container) {
          const tRect = targetEl.getBoundingClientRect();
          const cRect = container.getBoundingClientRect();
          const tCenterX = tRect.left + tRect.width / 2 - cRect.left;
          const tCenterY = tRect.top + tRect.height / 2 - cRect.top;
          targetX = tCenterX + 'px';
          targetY = tCenterY + 'px';
          targetScale = 'scale(0.25)';
        }
      }

      card.style.left = targetX;
      card.style.top = targetY;
      card.style.transform = 'translate(-50%, -50%) ' + targetScale;
      card.style.opacity = '0';

      spotlightTimer2 = setTimeout(() => {
        card.classList.add('hidden');
      }, 450);
    }, 350);
  }

  function renderHud(data) {
    if (!data) return;

    if (data.zoomLevel !== undefined) {
      document.getElementById('hud-container').style.transform = 'scale(' + data.zoomLevel + ')';
    }

    if (data.spotlight) {
      showSpotlight(data.spotlight);
    }
    
    if (data.rootNote) {
      document.getElementById('root-badge').textContent = '♩ ' + data.rootNote;
    }
    
    if (data.statusText) {
      document.getElementById('status-text').textContent = data.statusText;
    }

    if (data.modeFrac !== undefined) {
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

  function initGrid(layout) {
    ['upper', 'home', 'lower'].forEach(rowName => {
      const rowEl = document.getElementById('row-' + rowName);
      if (!rowEl) return;
      rowEl.innerHTML = '';
      if (layout[rowName]) {
        layout[rowName].forEach(k => {
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

          pad.addEventListener('mousedown', () => {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiApp) {
              window.webkit.messageHandlers.midiApp.postMessage({ type: 'keyDown', code: k.code });
            }
          });
          pad.addEventListener('mouseup', () => {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiApp) {
              window.webkit.messageHandlers.midiApp.postMessage({ type: 'keyUp', code: k.code });
            }
          });

          rowEl.appendChild(pad);
        });
      }
    });
  }
</script>
</body>
</html>
]]

local function updateWebviewHud(spotlightInfo)
  if not activeWatchers.midiWebview then return end

  -- Dynamically resize window frame to match zoom level for crisp rendering
  local baseW, baseH = 760, 230
  local newW = math.floor(baseW * zoomLevel)
  local newH = math.floor(baseH * zoomLevel)
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
  end
  
  local modeBrightness = SCALES[currentScaleIdx].brightness or 3
  local modeFrac = 1.0 - (modeBrightness / 6.0)
  
  local octStr = (octaveShift >= 0 and "+" or "") .. (octaveShift / 12) .. " Oct"
  local topOctVal = (topRowOctaveOffset / 12) + 1
  local topOctStr = "Top: +" .. topOctVal .. " Oct"
  local shiftStr = shiftHeld and "  •  [SHIFT]" or ""
  local modVal = ccStates[1] or 0
  local statusStr = SCALES[currentScaleIdx].name .. "  •  " .. octStr .. "  •  " .. topOctStr .. "  •  SUS: " .. (sustainActive and "ON" or "OFF") .. shiftStr

  local keyUpdates = {}

  for code, kData in pairs(upperRowKeys) do
    local noteNum = getTransposedPitch(kData.baseNote, true)
    local intervalIdx = getIntervalInfo(noteNum)
    local noteName = noteNumToName(noteNum)
    local noteLabel = noteName
    local typeClass = ""

    if intervalIdx == 1 then
      noteLabel = "★ " .. noteName .. " (R)"
      typeClass = "root-key"
    elseif intervalIdx == 3 then
      noteLabel = noteName .. " (3rd)"
      typeClass = "third-key"
    elseif intervalIdx == 5 then
      noteLabel = noteName .. " (5th)"
      typeClass = "fifth-key"
    end

    keyUpdates[tostring(code)] = {
      note = noteLabel,
      typeClass = typeClass,
      pressed = (pressedKeys[code] ~= nil)
    }
  end

  for code, kData in pairs(lowerRowKeys) do
    local noteNum = getTransposedPitch(kData.baseNote, false)
    local intervalIdx = getIntervalInfo(noteNum)
    local noteName = noteNumToName(noteNum)
    local noteLabel = noteName
    local typeClass = ""

    if intervalIdx == 1 then
      noteLabel = "★ " .. noteName .. " (R)"
      typeClass = "root-key"
    elseif intervalIdx == 3 then
      noteLabel = noteName .. " (3rd)"
      typeClass = "third-key"
    elseif intervalIdx == 5 then
      noteLabel = noteName .. " (5th)"
      typeClass = "fifth-key"
    end

    keyUpdates[tostring(code)] = {
      note = noteLabel,
      typeClass = typeClass,
      pressed = (pressedKeys[code] ~= nil)
    }
  end

  for code, cData in pairs(homeRowControls) do
    local label = shiftHeld and cData.shiftName or cData.name
    local isSustain = (code == 0 or code == 48)
    keyUpdates[tostring(code)] = {
      note = label,
      isControl = true,
      pressed = (pressedKeys[code] ~= nil),
      sustainActive = isSustain and sustainActive
    }
  end

  local payload = {
    rootNote = NOTE_NAMES[currentRoot + 1],
    statusText = statusStr,
    modeFrac = modeFrac,
    modWheel = modVal,
    zoomLevel = zoomLevel,
    spotlight = spotlightInfo,
    keys = keyUpdates
  }

  local jsonStr = hs.json.encode(payload)
  activeWatchers.midiWebview:evaluateJavaScript("renderHud(" .. jsonStr .. ")")
end

local function buildLayoutJson()
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
    { code = 38, keyLabel = "J", isControl = true, noteLabel = "Mod -" },
    { code = 40, keyLabel = "K", isControl = true, noteLabel = "Mod +" },
    { code = 37, keyLabel = "L", isControl = true, noteLabel = "Root +" },
    { code = 41, keyLabel = ";", isControl = true, noteLabel = "Vol +" }
  }

  local lowerList = {
    { code = 6,  keyLabel = "Z" }, { code = 7,  keyLabel = "X" }, { code = 8,  keyLabel = "C" },
    { code = 9,  keyLabel = "V" }, { code = 11, keyLabel = "B" }, { code = 45, keyLabel = "N" },
    { code = 46, keyLabel = "M" }, { code = 43, keyLabel = "," }, { code = 47, keyLabel = "." }, { code = 44, keyLabel = "/" }
  }

  return hs.json.encode({ upper = upperList, home = homeList, lower = lowerList })
end

local function createMidiWebview()
  if activeWatchers.midiWebview then
    activeWatchers.midiWebview:delete()
    activeWatchers.midiWebview = nil
  end

  local screen = hs.screen.mainScreen():frame()
  local width = math.floor(760 * zoomLevel)
  local height = math.floor(230 * zoomLevel)
  local hudX = activeWatchers.hudX or math.floor(screen.x + (screen.w - width) / 2)
  local hudY = activeWatchers.hudY or math.floor(screen.y + screen.h - height - 60)

  local uc = hsUsercontent.new("midiControllerUC")
  uc:setCallback(function(msg)
    if not msg or not msg.body then return end
    local body = msg.body
    if body.type == "keyDown" and body.code then
      -- Click simulation
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

  -- Initialize layout after webview loads
  hs.timer.doAfter(0.2, function()
    if activeWatchers.midiWebview then
      local layoutJson = buildLayoutJson()
      activeWatchers.midiWebview:evaluateJavaScript("initGrid(" .. layoutJson .. ")")
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
    if activeWatchers.midiWebview then
      activeWatchers.midiWebview:hide()
    end
  end
  hs.alert.show("🎹 MIDI Mode: " .. (midiActive and "ON" or "OFF"))
end

-- ── Trackpad 2-Finger Scroll Mod Wheel Listener ──────────────────────────────
activeWatchers.midiScrollTap = hs.eventtap.new({ hs.eventtap.event.types.scrollWheel }, function(event)
  if not midiActive then return false end

  -- Inspect scroll wheel event properties
  local deltaY = event:getProperty(hs.eventtap.event.properties.scrollWheelEventDeltaAxis1) or 0
  if deltaY == 0 then
    deltaY = event:getProperty(hs.eventtap.event.properties.scrollWheelEventPointDeltaAxis1) or 0
  end

  if deltaY ~= 0 then
    local currentMod = ccStates[1] or 0
    -- Scroll up (positive deltaY) increases mod wheel, scroll down decreases
    local step = deltaY * 3
    local newMod = math.max(0, math.min(127, math.floor(currentMod + step)))
    if newMod ~= currentMod then
      ccStates[1] = newMod
      sendMidiCC(1, newMod)
      local spot = {
        title = "MOD WHEEL (CC #1)",
        value = tostring(newMod),
        subtext = math.floor((newMod / 127) * 100) .. "% Intensity",
        targetId = "hud-container",
        color = "#ff8c00"
      }
      updateWebviewHud(spot)
    end
    return true -- Swallow scroll event so window doesn't scroll underneath
  end

  return false
end)

-- ── Key Event Tap Handler ─────────────────────────────────────────────────────

activeWatchers.midiKeyTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp, hs.eventtap.event.types.flagsChanged }, function(event)
  if not midiActive then return false end

  local flags = event:getFlags()
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

  -- 1. Check Lower Row Note Keys
  if lowerRowKeys[code] then
    local kData = lowerRowKeys[code]
    if isDown then
      if not pressedKeys[code] then
        local transposedPitch = getTransposedPitch(kData.baseNote, false)
        pressedKeys[code] = transposedPitch
        sendMidiNote("noteOn", transposedPitch, 100)
        updateWebviewHud()
      end
    else
      local playedPitch = pressedKeys[code]
      if playedPitch then
        sendMidiNote("noteOff", playedPitch, 0)
        pressedKeys[code] = nil
      end
      updateWebviewHud()
    end
    return true
  end

  -- 2. Check Upper Row Note Keys
  if upperRowKeys[code] then
    local kData = upperRowKeys[code]
    if isDown then
      if not pressedKeys[code] then
        local transposedPitch = getTransposedPitch(kData.baseNote, true)
        pressedKeys[code] = transposedPitch
        sendMidiNote("noteOn", transposedPitch, 100)
        updateWebviewHud()
      end
    else
      local playedPitch = pressedKeys[code]
      if playedPitch then
        sendMidiNote("noteOff", playedPitch, 0)
        pressedKeys[code] = nil
      end
      updateWebviewHud()
    end
    return true
  end

  -- 3. Check Zoom Keys (+ / = is 24, - is 27, Numpad + is 69, Numpad - is 78)
  if code == 24 or code == 69 then
    if isDown then
      zoomLevel = math.min(2.0, zoomLevel + 0.1)
      local spot = {
        title = "HUD ZOOM",
        value = math.floor(zoomLevel * 100) .. "%",
        subtext = "Press + or - to adjust scale",
        targetId = "hud-container",
        color = "#32b4cc"
      }
      updateWebviewHud(spot)
    end
    return true
  elseif code == 27 or code == 78 then
    if isDown then
      zoomLevel = math.max(0.5, zoomLevel - 0.1)
      local spot = {
        title = "HUD ZOOM",
        value = math.floor(zoomLevel * 100) .. "%",
        subtext = "Press + or - to adjust scale",
        targetId = "hud-container",
        color = "#32b4cc"
      }
      updateWebviewHud(spot)
    end
    return true
  end

  -- 4. Check Home Row Controls
  if homeRowControls[code] then
    local cData = homeRowControls[code]
    if isDown then
      if not pressedKeys[code] then
        pressedKeys[code] = true

        local act = shiftHeld and cData.shiftAction or cData.action

        if act == "sustain" then
          sustainKeyDownTime = hs.timer.secondsSinceEpoch()
          sustainWasActiveOnPress = sustainActive
          sustainActive = true
          sendMidiCC(64, 127)
          local spot = {
            title = "SUSTAIN PEDAL (CC #64)",
            value = "SUSTAIN ON",
            subtext = "Notes latch & hold",
            targetId = "key-0",
            color = "#e6b432"
          }
          updateWebviewHud(spot)
        elseif act == "octaveDown" then
          octaveShift = math.max(-36, octaveShift - 12)
          local lowerOct = 4 + math.floor(octaveShift / 12)
          local upperOct = 5 + math.floor((octaveShift + topRowOctaveOffset) / 12)
          local spot = {
            title = "GLOBAL OCTAVE",
            value = (octaveShift >= 0 and "+" or "") .. math.floor(octaveShift / 12) .. " Oct",
            subtext = "Lower: Oct " .. lowerOct .. " (C" .. lowerOct .. ")  •  Upper: Oct " .. upperOct .. " (C" .. upperOct .. ")",
            targetId = "status-text",
            color = "#32b4cc"
          }
          updateWebviewHud(spot)
        elseif act == "octaveUp" then
          octaveShift = math.min(36, octaveShift + 12)
          local lowerOct = 4 + math.floor(octaveShift / 12)
          local upperOct = 5 + math.floor((octaveShift + topRowOctaveOffset) / 12)
          local spot = {
            title = "GLOBAL OCTAVE",
            value = (octaveShift >= 0 and "+" or "") .. math.floor(octaveShift / 12) .. " Oct",
            subtext = "Lower: Oct " .. lowerOct .. " (C" .. lowerOct .. ")  •  Upper: Oct " .. upperOct .. " (C" .. upperOct .. ")",
            targetId = "status-text",
            color = "#32b4cc"
          }
          updateWebviewHud(spot)
        elseif act == "topOctDown" then
          topRowOctaveOffset = math.max(-36, topRowOctaveOffset - 12)
          local upperOct = 5 + math.floor((octaveShift + topRowOctaveOffset) / 12)
          local spot = {
            title = "UPPER ROW OCTAVE",
            value = (topRowOctaveOffset >= 0 and "+" or "") .. math.floor(topRowOctaveOffset / 12) .. " Oct",
            subtext = "Upper Row Pitch: Oct " .. upperOct .. " (C" .. upperOct .. ")",
            targetId = "status-text",
            color = "#9b80cc"
          }
          updateWebviewHud(spot)
        elseif act == "topOctUp" then
          topRowOctaveOffset = math.min(36, topRowOctaveOffset + 12)
          local upperOct = 5 + math.floor((octaveShift + topRowOctaveOffset) / 12)
          local spot = {
            title = "UPPER ROW OCTAVE",
            value = (topRowOctaveOffset >= 0 and "+" or "") .. math.floor(topRowOctaveOffset / 12) .. " Oct",
            subtext = "Upper Row Pitch: Oct " .. upperOct .. " (C" .. upperOct .. ")",
            targetId = "status-text",
            color = "#9b80cc"
          }
          updateWebviewHud(spot)
        elseif act == "rootDown" then
          currentRoot = (currentRoot - 1) % 12
          local rootName = NOTE_NAMES[currentRoot + 1]
          local spot = {
            title = "ROOT NOTE",
            value = "♩ " .. rootName,
            subtext = "Key: " .. rootName .. " " .. SCALES[currentScaleIdx].name,
            targetId = "root-badge",
            color = "#e6b432"
          }
          updateWebviewHud(spot)
        elseif act == "rootUp" then
          currentRoot = (currentRoot + 1) % 12
          local rootName = NOTE_NAMES[currentRoot + 1]
          local spot = {
            title = "ROOT NOTE",
            value = "♩ " .. rootName,
            subtext = "Key: " .. rootName .. " " .. SCALES[currentScaleIdx].name,
            targetId = "root-badge",
            color = "#e6b432"
          }
          updateWebviewHud(spot)
        elseif act == "modeDown" then
          currentScaleIdx = (currentScaleIdx - 2) % #SCALES + 1
          local scaleInfo = SCALES[currentScaleIdx]
          local spot = {
            title = "SCALE / MODE",
            value = scaleInfo.name,
            subtext = scaleInfo.brightTag,
            targetId = "mode-thumb",
            color = "#ff8c00"
          }
          updateWebviewHud(spot)
        elseif act == "modeUp" then
          currentScaleIdx = (currentScaleIdx % #SCALES) + 1
          local scaleInfo = SCALES[currentScaleIdx]
          local spot = {
            title = "SCALE / MODE",
            value = scaleInfo.name,
            subtext = scaleInfo.brightTag,
            targetId = "mode-thumb",
            color = "#ff8c00"
          }
          updateWebviewHud(spot)
        elseif act == "randomScale" then
          currentRoot = math.random(0, 11)
          currentScaleIdx = math.random(1, #SCALES)
          local rootName = NOTE_NAMES[currentRoot + 1]
          local scaleInfo = SCALES[currentScaleIdx]
          local spot = {
            title = "RANDOM SCALE",
            value = rootName .. " " .. scaleInfo.name,
            subtext = scaleInfo.brightTag,
            targetId = "mode-thumb",
            color = "#ff8c00"
          }
          updateWebviewHud(spot)
        elseif act == "resetAll" then
          octaveShift = 0
          topRowOctaveOffset = 0
          currentRoot = 0
          currentScaleIdx = 1
          sustainActive = false
          ccStates[1] = 0
          sendMidiCC(64, 0)
          sendMidiCC(1, 0)
          local spot = {
            title = "RESET ALL",
            value = "DEFAULTS RESTORED",
            subtext = "Octave 0  •  C Major  •  Mod 0",
            targetId = "hud-container",
            color = "#e6b432"
          }
          updateWebviewHud(spot)
        elseif act == "panic" then
          sendMidiCC(123, 0)
          pressedKeys = {}
          local spot = {
            title = "MIDI PANIC",
            value = "ALL NOTES OFF",
            subtext = "Reset active notes",
            targetId = "hud-container",
            color = "#ff4444"
          }
          updateWebviewHud(spot)
        elseif act == "modWheelDown" then
          local currentVal = ccStates[1] or 0
          local newVal = math.max(0, currentVal - 16)
          ccStates[1] = newVal
          sendMidiCC(1, newVal)
          local spot = {
            title = "MOD WHEEL (CC #1)",
            value = tostring(newVal),
            subtext = math.floor((newVal / 127) * 100) .. "% Intensity",
            targetId = "hud-container",
            color = "#ff8c00"
          }
          updateWebviewHud(spot)
        elseif act == "modWheelUp" or act == "modWheel" then
          local currentVal = ccStates[1] or 0
          local newVal = math.min(127, currentVal + 16)
          ccStates[1] = newVal
          sendMidiCC(1, newVal)
          local spot = {
            title = "MOD WHEEL (CC #1)",
            value = tostring(newVal),
            subtext = math.floor((newVal / 127) * 100) .. "% Intensity",
            targetId = "hud-container",
            color = "#ff8c00"
          }
          updateWebviewHud(spot)
        elseif act == "volDown" then
          local currentVal = ccStates[7] or 100
          local newVal = math.max(0, currentVal - 16)
          ccStates[7] = newVal
          sendMidiCC(7, newVal)
          local spot = {
            title = "MASTER VOLUME (CC #7)",
            value = tostring(newVal),
            subtext = math.floor((newVal / 127) * 100) .. "% Level",
            targetId = "hud-container",
            color = "#32b4cc"
          }
          updateWebviewHud(spot)
        elseif act == "volUp" or act == "volume" then
          local currentVal = ccStates[7] or 100
          local newVal = math.min(127, currentVal + 16)
          ccStates[7] = newVal
          sendMidiCC(7, newVal)
          local spot = {
            title = "MASTER VOLUME (CC #7)",
            value = tostring(newVal),
            subtext = math.floor((newVal / 127) * 100) .. "% Level",
            targetId = "hud-container",
            color = "#32b4cc"
          }
          updateWebviewHud(spot)
        end
      end
    else
      pressedKeys[code] = nil

      local act = shiftHeld and cData.shiftAction or cData.action
      if act == "sustain" then
        local holdDuration = hs.timer.secondsSinceEpoch() - sustainKeyDownTime
        if holdDuration > 0.25 then
          sustainActive = false
          sendMidiCC(64, 0)
        else
          if sustainWasActiveOnPress then
            sustainActive = false
            sendMidiCC(64, 0)
          else
            sustainActive = true
            sendMidiCC(64, 127)
          end
        end
        local spot = {
          title = "SUSTAIN PEDAL (CC #64)",
          value = sustainActive and "SUSTAIN ON" or "SUSTAIN OFF",
          subtext = sustainActive and "Notes latch & hold" or "Damping enabled",
          targetId = "key-0",
          color = sustainActive and "#e6b432" or "#9ab0c7"
        }
        updateWebviewHud(spot)
      else
        updateWebviewHud()
      end
    end
    return true
  end

  return false
end)

-- Toggle MIDI Mode hotkey (Cmd + Option + M)
activeWatchers.midiToggleHotkey = hs.hotkey.bind({ "cmd", "alt" }, "M", function()
  _G.toggleMidiMode()
end)
