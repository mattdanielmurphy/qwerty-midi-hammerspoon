local hsWebview = require("hs.webview")
local hsUsercontent = require("hs.webview.usercontent")
local config = require("config")
local state = config.state

local settingsWebview = nil

local function generateSettingsHTML()
  local bpmStep        = state.bpmStepSize or 10
  local logicSync      = state.logicSyncEnabled
  local gate           = state.arpGatePercent or 80
  local zoom           = state.zoomLevel or 1.0
  local acceleration  = state.scrollAcceleration or 0.15
  local decay         = state.scrollFrictionalDecay or 0.85

  -- Build BPM step selected states
  local bpmSel = { ["1"]="", ["5"]="", ["10"]="", ["25"]="" }
  bpmSel[tostring(bpmStep)] = "selected"

  -- Build zoom selected states
  local zoomSel = {}
  for _, v in ipairs({0.8, 1.0, 1.2, 1.4}) do
    zoomSel[tostring(v)] = math.abs(zoom - v) < 0.05 and "selected" or ""
  end

  -- Format floats nicely for slider defaults
  local accFmt     = string.format("%.2f", acceleration)
  local decayFmt   = string.format("%.2f", decay)

  return string.format([[
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; user-select: none; -webkit-user-select: none; }

    body {
      font-family: Georgia, serif;
      background: #18140f;
      color: #e2d5c0;
      font-size: 15px;
      overflow: hidden;
      border-radius: 16px;
    }

    #panel {
      background: linear-gradient(160deg, #1e1a13 0%%, #151108 100%%);
      border: 1.5px solid rgba(212, 163, 89, 0.4);
      border-radius: 16px;
      box-shadow: 0 8px 40px rgba(0,0,0,0.7), inset 0 1px 0 rgba(212,163,89,0.08);
      padding: 0;
      height: 100vh;
      display: flex;
      flex-direction: column;
    }

    /* ── Title bar ── */
    #titlebar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 14px 20px 12px;
      border-bottom: 1px solid rgba(212, 163, 89, 0.2);
      cursor: move;
      -webkit-app-region: drag;
      flex-shrink: 0;
    }

    #titlebar-label {
      font-weight: 700;
      font-size: 15px;
      letter-spacing: 1.8px;
      text-transform: uppercase;
      color: #d4a359;
      text-shadow: 0 0 12px rgba(212,163,89,0.4);
    }

    #close-btn {
      background: rgba(212,163,89,0.12);
      border: 1px solid rgba(212,163,89,0.35);
      color: #d4a359;
      width: 26px; height: 26px;
      border-radius: 50%%;
      font-size: 13px;
      cursor: pointer;
      display: flex; align-items: center; justify-content: center;
      transition: background 0.15s, box-shadow 0.15s;
      -webkit-app-region: no-drag;
      flex-shrink: 0;
      font-family: inherit;
      outline: none;
    }
    #close-btn:hover {
      background: rgba(212,163,89,0.28);
      box-shadow: 0 0 8px rgba(212,163,89,0.3);
    }

    /* ── Scroll area ── */
    #scroll-area {
      overflow-y: auto;
      flex: 1;
      padding: 18px 20px 20px;
    }

    /* ── Section ── */
    .section {
      margin-bottom: 20px;
    }
    .section-title {
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 2.2px;
      text-transform: uppercase;
      color: rgba(212,163,89,0.55);
      margin-bottom: 12px;
      padding-bottom: 6px;
      border-bottom: 1px solid rgba(212,163,89,0.12);
    }

    /* ── Row ── */
    .row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 14px;
      margin-bottom: 14px;
    }
    .row:last-child { margin-bottom: 0; }

    .row-label { flex: 1; min-width: 0; }
    .row-label strong { font-weight: 700; font-size: 14px; color: #e2d5c0; display: block; }
    .row-label span { font-size: 12px; color: rgba(200,185,160,0.55); display: block; margin-top: 2px; }

    /* ── Select ── */
    select {
      background: rgba(20,16,10,0.9);
      border: 1px solid rgba(212,163,89,0.35);
      color: #d4a359;
      padding: 6px 10px;
      border-radius: 8px;
      outline: none;
      font-size: 13px;
      font-family: inherit;
      font-weight: 700;
      flex-shrink: 0;
      appearance: none;
      -webkit-appearance: none;
      cursor: pointer;
      min-width: 105px;
      text-align: center;
    }
    select:focus { border-color: rgba(212,163,89,0.7); }
    select option { background: #1a1508; color: #d4a359; }

    /* ── Toggle ── */
    .toggle-wrap {
      display: flex;
      align-items: center;
      gap: 10px;
      flex-shrink: 0;
    }
    .toggle {
      position: relative;
      width: 48px; height: 26px;
    }
    .toggle input { opacity: 0; width: 0; height: 0; }
    .toggle-track {
      position: absolute;
      inset: 0;
      background: rgba(30,24,14,0.9);
      border: 1px solid rgba(212,163,89,0.3);
      border-radius: 13px;
      cursor: pointer;
      transition: background 0.2s, border-color 0.2s;
    }
    .toggle-thumb {
      position: absolute;
      top: 3px; left: 3px;
      width: 18px; height: 18px;
      background: rgba(212,163,89,0.45);
      border-radius: 50%%;
      transition: transform 0.2s, background 0.2s;
      pointer-events: none;
    }
    .toggle input:checked ~ .toggle-track {
      background: rgba(212,163,89,0.18);
      border-color: rgba(212,163,89,0.7);
    }
    .toggle input:checked ~ .toggle-thumb {
      transform: translateX(22px);
      background: #d4a359;
    }

    /* ── Slider ── */
    .slider-row {
      display: flex;
      align-items: center;
      gap: 12px;
      flex-shrink: 0;
      width: 190px;
    }
    input[type=range] {
      -webkit-appearance: none;
      appearance: none;
      flex: 1;
      height: 5px;
      background: rgba(212,163,89,0.18);
      border-radius: 3px;
      outline: none;
      cursor: pointer;
    }
    input[type=range]::-webkit-slider-thumb {
      -webkit-appearance: none;
      width: 16px; height: 16px;
      border-radius: 50%%;
      background: #d4a359;
      border: 1px solid rgba(0,0,0,0.4);
      box-shadow: 0 0 6px rgba(212,163,89,0.5);
      cursor: pointer;
    }
    .slider-val {
      font-size: 13px;
      font-weight: 700;
      color: #d4a359;
      min-width: 38px;
      text-align: right;
      font-variant-numeric: tabular-nums;
    }

    /* ── Number input ── */
    input[type=number] {
      background: rgba(20,16,10,0.9);
      border: 1px solid rgba(212,163,89,0.35);
      color: #d4a359;
      padding: 6px 10px;
      border-radius: 8px;
      outline: none;
      font-size: 13px;
      font-family: inherit;
      font-weight: 700;
      width: 84px;
      text-align: center;
    }
    input[type=number]:focus { border-color: rgba(212,163,89,0.7); }

    /* ── Divider ── */
    .divider { height: 1px; background: rgba(212,163,89,0.1); margin: 6px 0 20px; }
  </style>
</head>
<body>
<div id="panel">
  <div id="titlebar">
    <div id="titlebar-label">⚙ Settings</div>
    <button id="close-btn" onclick="send('close')">✕</button>
  </div>

  <div id="scroll-area">

    <!-- Scroll / Trackpad -->
    <div class="section">
      <div class="section-title">Trackpad / Scroll</div>

      <div class="row">
        <div class="row-label">
          <strong>Scroll Acceleration</strong>
          <span>Speed/curve of active scrolling</span>
        </div>
        <div class="slider-row">
          <input type="range" id="accelerationSlider" min="0.01" max="0.50" step="0.01"
            value="%s"
            oninput="onAcceleration(this.value)">
          <div class="slider-val" id="accelerationVal">%s</div>
        </div>
      </div>

      <div class="row">
        <div class="row-label">
          <strong>Post-Release Coasting</strong>
          <span>Friction (0 = stop, 0.98 = long glide)</span>
        </div>
        <div class="slider-row">
          <input type="range" id="decaySlider" min="0.00" max="0.98" step="0.01"
            value="%s"
            oninput="onDecay(this.value)">
          <div class="slider-val" id="decayVal">%s</div>
        </div>
      </div>
    </div>

    <!-- Tempo & Sync -->
    <div class="section">
      <div class="section-title">Tempo &amp; Sync</div>

      <div class="row">
        <div class="row-label">
          <strong>BPM Step Size</strong>
          <span>Change per increment / decrement key</span>
        </div>
        <select id="bpmStepSize" onchange="send('setBpmStep', parseInt(this.value))">
          <option value="1" %s>1 BPM</option>
          <option value="5" %s>5 BPM</option>
          <option value="10" %s>10 BPM</option>
          <option value="25" %s>25 BPM</option>
        </select>
      </div>

      <div class="row">
        <div class="row-label">
          <strong>Sync to Logic Pro</strong>
          <span>Auto-match BPM with active session</span>
        </div>
        <label class="toggle">
          <input type="checkbox" id="logicSync" %s onchange="send('setLogicSync', this.checked)">
          <div class="toggle-track"></div>
          <div class="toggle-thumb"></div>
        </label>
      </div>
    </div>

    <!-- Arpeggiator -->
    <div class="section">
      <div class="section-title">Arpeggiator</div>
      <div class="row">
        <div class="row-label">
          <strong>Default Gate Length</strong>
          <span>Note duration as %% of step interval</span>
        </div>
        <input type="number" id="gatePercent" value="%d" min="10" max="150" step="5"
          onchange="send('setGate', parseInt(this.value))">
      </div>
    </div>

    <!-- Display -->
    <div class="section">
      <div class="section-title">Display</div>
      <div class="row">
        <div class="row-label">
          <strong>HUD Zoom Level</strong>
          <span>Scale factor for the status dashboard</span>
        </div>
        <select id="zoomLevel" onchange="send('setZoom', parseFloat(this.value))">
          <option value="0.8" %s>80%%</option>
          <option value="1.0" %s>100%% (Default)</option>
          <option value="1.2" %s>120%%</option>
          <option value="1.4" %s>140%%</option>
        </select>
      </div>
    </div>

  </div><!-- /scroll-area -->
</div><!-- /panel -->

<script>
  function send(type, value) {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.settingsUserContent) {
      window.webkit.messageHandlers.settingsUserContent.postMessage({ type: type, value: value });
    }
  }
  function onAcceleration(v) {
    document.getElementById('accelerationVal').textContent = parseFloat(v).toFixed(2);
    send('setAcceleration', parseFloat(v));
  }
  function onDecay(v) {
    document.getElementById('decayVal').textContent = parseFloat(v).toFixed(2);
    send('setDecay', parseFloat(v));
  }
  function syncState(s) {
    if (!s) return;
    if (s.bpmStepSize !== undefined) {
      var el = document.getElementById('bpmStepSize');
      if (el) el.value = String(s.bpmStepSize);
    }
    if (s.logicSyncEnabled !== undefined) {
      var el = document.getElementById('logicSync');
      if (el) el.checked = !!s.logicSyncEnabled;
    }
    if (s.arpGatePercent !== undefined) {
      var el = document.getElementById('gatePercent');
      if (el) el.value = s.arpGatePercent;
    }
    if (s.zoomLevel !== undefined) {
      var el = document.getElementById('zoomLevel');
      if (el) el.value = String(s.zoomLevel);
    }
    if (s.scrollAcceleration !== undefined) {
      var el = document.getElementById('accelerationSlider');
      if (el) el.value = s.scrollAcceleration;
      var valEl = document.getElementById('accelerationVal');
      if (valEl) valEl.textContent = parseFloat(s.scrollAcceleration).toFixed(2);
    }
    if (s.scrollFrictionalDecay !== undefined) {
      var el = document.getElementById('decaySlider');
      if (el) el.value = s.scrollFrictionalDecay;
      var valEl = document.getElementById('decayVal');
      if (valEl) valEl.textContent = parseFloat(s.scrollFrictionalDecay).toFixed(2);
    }
  }
</script>
</body>
</html>
]],
    -- sensitivity slider
    sensFmt, sensFmt,
    -- momentum slider
    momentFmt, momentFmt,
    -- bpm step selects
    bpmSel["1"], bpmSel["5"], bpmSel["10"], bpmSel["25"],
    -- logic sync checked
    logicSync and "checked" or "",
    -- gate
    math.floor(gate),
    -- zoom selects
    zoomSel["0.8"], zoomSel["1.0"], zoomSel["1.2"], zoomSel["1.4"]
  )
end

_G.activeWatchers = _G.activeWatchers or {}

local function createSettingsWebview()
  if _G.activeWatchers.settingsWebview then
    return _G.activeWatchers.settingsWebview
  end

  local uc = hsUsercontent.new("settingsUserContent")

  uc:setCallback(function(message)
    local body = message.body
    if not body or not body.type then return end

    if body.type == "setBpmStep" then
      local val = tonumber(body.value) or 10
      state.bpmStepSize = val
      hs.settings.set("qwertyMidi_bpmStepSize", val)
    elseif body.type == "setLogicSync" then
      local val = (body.value == true or body.value == "true" or body.value == 1)
      state.logicSyncEnabled = val
      hs.settings.set("qwertyMidi_logicSyncEnabled", val)
    elseif body.type == "setGate" then
      local val = tonumber(body.value) or 80.0
      state.arpGatePercent = math.max(5.0, math.min(150.0, val))
    elseif body.type == "setZoom" then
      local val = tonumber(body.value) or 1.0
      state.zoomLevel = val
      hs.settings.set("qwertyMidi_zoomLevel", val)
    elseif body.type == "setAcceleration" then
      local val = tonumber(body.value) or 0.15
      state.scrollAcceleration = val
      hs.settings.set("qwertyMidi_scrollAcceleration", val)
    elseif body.type == "setDecay" then
      local val = tonumber(body.value) or 0.85
      state.scrollFrictionalDecay = math.max(0, math.min(0.98, val))
      hs.settings.set("qwertyMidi_scrollFrictionalDecay", val)
    elseif body.type == "close" then
      if _G.activeWatchers.settingsWebview then
        _G.activeWatchers.settingsWebview:hide()
      end
      return
    end

    config.saveSettings()
    local hud = require("hud")
    hud.updateWebviewHud()
  end)

  local screen = hs.screen.mainScreen():frame()
  local w, h = 528, 612
  local x = math.floor(screen.x + (screen.w - w) / 2)
  local y = math.floor(screen.y + (screen.h - h) / 2)

  local wv = hsWebview.new({ x = x, y = y, w = w, h = h }, { developerExtrasEnabled = true }, uc)
  wv:windowTitle("QWERTY MIDI Settings")
  -- Borderless floating panel that sits above the HUD webview
  wv:windowStyle({ "borderless", "nonactivating" })
  wv:level(hs.drawing.windowLevels.floating + 1)
  wv:allowTextEntry(true)
  wv:html(generateSettingsHTML())

  _G.activeWatchers.settingsWebview = wv
  return wv
end

local function syncStateToWebview()
  if not _G.activeWatchers.settingsWebview then return end
  local s = {
    bpmStepSize = state.bpmStepSize or 10,
    logicSyncEnabled = state.logicSyncEnabled,
    arpGatePercent = state.arpGatePercent or 80,
    zoomLevel = state.zoomLevel or 1.0,
    scrollAcceleration = state.scrollAcceleration or 0.15,
    scrollFrictionalDecay = state.scrollFrictionalDecay or 0.85
  }
  local jsonStr = hs.json.encode(s)
  _G.activeWatchers.settingsWebview:evaluateJavaScript("syncState(" .. jsonStr .. ");")
end

local function toggleSettingsWindow()
  local wv = createSettingsWebview()

  if wv:isVisible() then
    wv:hide()
  else
    local screen = hs.screen.mainScreen():frame()
    local w, h = 528, 612
    local x = math.floor(screen.x + (screen.w - w) / 2)
    local y = math.floor(screen.y + (screen.h - h) / 2)
    wv:frame({ x = x, y = y, w = w, h = h })

    syncStateToWebview()
    wv:show()
  end
end

-- Cleanup old instance on reload and pre-warm new settings webview
if _G.activeWatchers.settingsWebview then
  _G.activeWatchers.settingsWebview:delete()
  _G.activeWatchers.settingsWebview = nil
end
createSettingsWebview()

return {
  toggleSettingsWindow = toggleSettingsWindow
}
