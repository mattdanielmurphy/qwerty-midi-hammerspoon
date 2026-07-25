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
  local sensitivity    = state.scrollSensitivity or 0.15
  local momentumScale  = state.scrollMomentumScale or 0.3

  -- Build BPM step selected states
  local bpmSel = { ["1"]="", ["5"]="", ["10"]="", ["25"]="" }
  bpmSel[tostring(bpmStep)] = "selected"

  -- Build zoom selected states
  local zoomSel = {}
  for _, v in ipairs({0.8, 1.0, 1.2, 1.4}) do
    zoomSel[tostring(v)] = math.abs(zoom - v) < 0.05 and "selected" or ""
  end

  -- Format floats nicely for slider defaults
  local sensFmt    = string.format("%.2f", sensitivity)
  local momentFmt  = string.format("%.2f", momentumScale)

  return string.format([[
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Fraunces:ital,opsz,wght@0,9..144,400;0,9..144,700&display=swap" rel="stylesheet">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; user-select: none; -webkit-user-select: none; }

    body {
      font-family: 'Fraunces', Georgia, serif;
      background: #18140f;
      color: #e2d5c0;
      font-size: 13px;
      overflow: hidden;
      border-radius: 14px;
    }

    #panel {
      background: linear-gradient(160deg, #1e1a13 0%%, #151108 100%%);
      border: 1.5px solid rgba(212, 163, 89, 0.4);
      border-radius: 14px;
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
      padding: 12px 16px 10px;
      border-bottom: 1px solid rgba(212, 163, 89, 0.2);
      cursor: move;
      -webkit-app-region: drag;
      flex-shrink: 0;
    }

    #titlebar-label {
      font-weight: 700;
      font-size: 13px;
      letter-spacing: 1.5px;
      text-transform: uppercase;
      color: #d4a359;
      text-shadow: 0 0 12px rgba(212,163,89,0.4);
    }

    #close-btn {
      background: rgba(212,163,89,0.12);
      border: 1px solid rgba(212,163,89,0.35);
      color: #d4a359;
      width: 22px; height: 22px;
      border-radius: 50%%;
      font-size: 11px;
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
      padding: 14px 16px 16px;
    }

    /* ── Section ── */
    .section {
      margin-bottom: 16px;
    }
    .section-title {
      font-size: 9px;
      font-weight: 700;
      letter-spacing: 2px;
      text-transform: uppercase;
      color: rgba(212,163,89,0.55);
      margin-bottom: 10px;
      padding-bottom: 5px;
      border-bottom: 1px solid rgba(212,163,89,0.12);
    }

    /* ── Row ── */
    .row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 12px;
    }
    .row:last-child { margin-bottom: 0; }

    .row-label { flex: 1; min-width: 0; }
    .row-label strong { font-weight: 700; font-size: 12px; color: #e2d5c0; display: block; }
    .row-label span { font-size: 10px; color: rgba(200,185,160,0.55); display: block; margin-top: 1px; }

    /* ── Select ── */
    select {
      background: rgba(20,16,10,0.9);
      border: 1px solid rgba(212,163,89,0.35);
      color: #d4a359;
      padding: 5px 8px;
      border-radius: 6px;
      outline: none;
      font-size: 11px;
      font-family: inherit;
      font-weight: 700;
      flex-shrink: 0;
      appearance: none;
      -webkit-appearance: none;
      cursor: pointer;
      min-width: 90px;
      text-align: center;
    }
    select:focus { border-color: rgba(212,163,89,0.7); }
    select option { background: #1a1508; color: #d4a359; }

    /* ── Toggle ── */
    .toggle-wrap {
      display: flex;
      align-items: center;
      gap: 8px;
      flex-shrink: 0;
    }
    .toggle {
      position: relative;
      width: 40px; height: 22px;
    }
    .toggle input { opacity: 0; width: 0; height: 0; }
    .toggle-track {
      position: absolute;
      inset: 0;
      background: rgba(30,24,14,0.9);
      border: 1px solid rgba(212,163,89,0.3);
      border-radius: 11px;
      cursor: pointer;
      transition: background 0.2s, border-color 0.2s;
    }
    .toggle-thumb {
      position: absolute;
      top: 3px; left: 3px;
      width: 14px; height: 14px;
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
      transform: translateX(18px);
      background: #d4a359;
    }

    /* ── Slider ── */
    .slider-row {
      display: flex;
      align-items: center;
      gap: 10px;
      flex-shrink: 0;
      width: 160px;
    }
    input[type=range] {
      -webkit-appearance: none;
      appearance: none;
      flex: 1;
      height: 4px;
      background: rgba(212,163,89,0.18);
      border-radius: 2px;
      outline: none;
      cursor: pointer;
    }
    input[type=range]::-webkit-slider-thumb {
      -webkit-appearance: none;
      width: 14px; height: 14px;
      border-radius: 50%%;
      background: #d4a359;
      border: 1px solid rgba(0,0,0,0.4);
      box-shadow: 0 0 6px rgba(212,163,89,0.5);
      cursor: pointer;
    }
    .slider-val {
      font-size: 11px;
      font-weight: 700;
      color: #d4a359;
      min-width: 32px;
      text-align: right;
      font-variant-numeric: tabular-nums;
    }

    /* ── Number input ── */
    input[type=number] {
      background: rgba(20,16,10,0.9);
      border: 1px solid rgba(212,163,89,0.35);
      color: #d4a359;
      padding: 5px 8px;
      border-radius: 6px;
      outline: none;
      font-size: 11px;
      font-family: inherit;
      font-weight: 700;
      width: 70px;
      text-align: center;
    }
    input[type=number]:focus { border-color: rgba(212,163,89,0.7); }

    /* ── Divider ── */
    .divider { height: 1px; background: rgba(212,163,89,0.1); margin: 4px 0 16px; }
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
          <strong>Mod Wheel Sensitivity</strong>
          <span>Speed of mod wheel change per scroll tick</span>
        </div>
        <div class="slider-row">
          <input type="range" id="sensitivitySlider" min="0.02" max="0.5" step="0.01"
            value="%s"
            oninput="onSensitivity(this.value)">
          <div class="slider-val" id="sensitivityVal">%s</div>
        </div>
      </div>

      <div class="row">
        <div class="row-label">
          <strong>Momentum Scale</strong>
          <span>Inertia strength after finger lifts (0 = none)</span>
        </div>
        <div class="slider-row">
          <input type="range" id="momentumSlider" min="0" max="1" step="0.05"
            value="%s"
            oninput="onMomentum(this.value)">
          <div class="slider-val" id="momentumVal">%s</div>
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
    webkit.messageHandlers.settingsHandler.postMessage({ type: type, value: value });
  }
  function onSensitivity(v) {
    document.getElementById('sensitivityVal').textContent = parseFloat(v).toFixed(2);
    send('setSensitivity', parseFloat(v));
  }
  function onMomentum(v) {
    document.getElementById('momentumVal').textContent = parseFloat(v).toFixed(2);
    send('setMomentum', parseFloat(v));
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

local function toggleSettingsWindow()
  if settingsWebview then
    settingsWebview:delete()
    settingsWebview = nil
    return
  end

  local uc = hsUsercontent.new("settingsUserContent")
  uc:injectScript({
    source = "window.settingsHandler = webkit.messageHandlers.settingsHandler;",
    injectionPoint = "documentStart"
  })

  uc:setCallback(function(message)
    local body = message.body
    if not body or not body.type then return end

    if body.type == "setBpmStep" then
      state.bpmStepSize = body.value
      hs.settings.set("qwertyMidi_bpmStepSize", body.value)
    elseif body.type == "setLogicSync" then
      state.logicSyncEnabled = body.value
      hs.settings.set("qwertyMidi_logicSyncEnabled", body.value)
    elseif body.type == "setGate" then
      state.arpGatePercent = math.max(5, math.min(150, body.value))
    elseif body.type == "setZoom" then
      state.zoomLevel = body.value
      hs.settings.set("qwertyMidi_zoomLevel", body.value)
    elseif body.type == "setSensitivity" then
      state.scrollSensitivity = body.value
      hs.settings.set("qwertyMidi_scrollSensitivity", body.value)
    elseif body.type == "setMomentum" then
      state.scrollMomentumScale = body.value
      hs.settings.set("qwertyMidi_scrollMomentumScale", body.value)
    elseif body.type == "close" then
      if settingsWebview then
        settingsWebview:delete()
        settingsWebview = nil
      end
      return
    end

    local hud = require("hud")
    hud.updateWebviewHud()
  end)

  local screen = hs.screen.mainScreen():frame()
  local w, h = 440, 510
  local x = math.floor(screen.x + (screen.w - w) / 2)
  local y = math.floor(screen.y + (screen.h - h) / 2)

  settingsWebview = hsWebview.new({ x = x, y = y, w = w, h = h }, { developerExtras = false }, uc)
  settingsWebview:windowTitle("QWERTY MIDI Settings")
  -- Borderless floating panel that sits above the HUD webview
  settingsWebview:windowStyle({ "borderless", "nonactivating" })
  settingsWebview:level(hs.drawing.windowLevels.floating + 1)
  settingsWebview:allowTextEntry(true)
  settingsWebview:html(generateSettingsHTML())
  settingsWebview:show()
end

return {
  toggleSettingsWindow = toggleSettingsWindow
}
