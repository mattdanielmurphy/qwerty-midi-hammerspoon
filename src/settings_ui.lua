local hsWebview = require("hs.webview")
local hsUsercontent = require("hs.webview.usercontent")
local config = require("config")
local arpeggiator = require("arpeggiator")
local state = config.state

local settingsWebview = nil

local function generateSettingsHTML()
  local bpmStep = state.bpmStepSize or 10
  local logicSync = state.logicSyncEnabled
  local gate = state.arpGatePercent or 80
  local zoom = math.floor((state.zoomLevel or 1.0) * 100)

  return string.format([[
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <style>
    :root {
      --bg: #121316;
      --card-bg: #1a1c23;
      --accent: #d4a359;
      --accent-hover: #e0b46a;
      --text: #e2e4e9;
      --text-muted: #8b90a0;
      --border: #282a36;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; user-select: none; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: var(--bg);
      color: var(--text);
      padding: 20px;
      font-size: 13px;
    }
    .header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 20px;
      padding-bottom: 10px;
      border-bottom: 1px solid var(--border);
    }
    .title {
      font-weight: 700;
      font-size: 16px;
      letter-spacing: 0.5px;
      color: var(--accent);
    }
    .close-btn {
      background: transparent;
      border: none;
      color: var(--text-muted);
      cursor: pointer;
      font-size: 16px;
    }
    .close-btn:hover { color: var(--text); }
    .group {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 14px;
      margin-bottom: 14px;
    }
    .group-title {
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 1px;
      color: var(--text-muted);
      margin-bottom: 12px;
    }
    .row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 10px;
    }
    .row:last-child { margin-bottom: 0; }
    label { font-weight: 500; }
    select, input[type="number"] {
      background: #0f1013;
      border: 1px solid var(--border);
      color: var(--text);
      padding: 6px 10px;
      border-radius: 6px;
      outline: none;
      font-size: 13px;
    }
    select:focus, input[type="number"]:focus {
      border-color: var(--accent);
    }
    .toggle {
      position: relative;
      display: inline-block;
      width: 38px;
      height: 20px;
    }
    .toggle input { opacity: 0; width: 0; height: 0; }
    .slider {
      position: absolute;
      cursor: pointer;
      top: 0; left: 0; right: 0; bottom: 0;
      background-color: #2c2e3b;
      transition: .2s;
      border-radius: 20px;
    }
    .slider:before {
      position: absolute;
      content: "";
      height: 14px; width: 14px;
      left: 3px; bottom: 3px;
      background-color: var(--text-muted);
      transition: .2s;
      border-radius: 50%%;
    }
    input:checked + .slider { background-color: var(--accent); }
    input:checked + .slider:before {
      transform: translateX(18px);
      background-color: #121316;
    }
    .hint {
      font-size: 11px;
      color: var(--text-muted);
      margin-top: 4px;
    }
  </style>
</head>
<body>
  <div class="header">
    <div class="title">🎹 QWERTY MIDI Settings</div>
    <button class="close-btn" onclick="closeSettings()">✕</button>
  </div>

  <div class="group">
    <div class="group-title">Tempo & Sync</div>
    <div class="row">
      <div>
        <label>BPM Step Size</label>
        <div class="hint">BPM change per increment/decrement key</div>
      </div>
      <select id="bpmStepSize" onchange="updateBpmStep(this.value)">
        <option value="1" %s>1 BPM</option>
        <option value="5" %s>5 BPM</option>
        <option value="10" %s>10 BPM</option>
        <option value="25" %s>25 BPM</option>
      </select>
    </div>
    <div class="row" style="margin-top: 12px;">
      <div>
        <label>Sync to Logic Pro</label>
        <div class="hint">Auto-sync BPM with active Logic Pro project</div>
      </div>
      <label class="toggle">
        <input type="checkbox" id="logicSync" %s onchange="toggleLogicSync(this.checked)">
        <span class="slider"></span>
      </label>
    </div>
  </div>

  <div class="group">
    <div class="group-title">Arpeggiator</div>
    <div class="row">
      <div>
        <label>Default Gate Length</label>
        <div class="hint">Arp note duration percentage</div>
      </div>
      <input type="number" id="gatePercent" value="%d" min="10" max="150" step="5" style="width: 70px;" onchange="updateGate(this.value)">
    </div>
  </div>

  <div class="group">
    <div class="group-title">Display & Interface</div>
    <div class="row">
      <div>
        <label>HUD Zoom Level</label>
        <div class="hint">Scale factor for status dashboard</div>
      </div>
      <select id="zoomLevel" onchange="updateZoom(this.value)">
        <option value="0.8" %s>80%%</option>
        <option value="1.0" %s>100%% (Default)</option>
        <option value="1.2" %s>120%%</option>
        <option value="1.4" %s>140%%</option>
      </select>
    </div>
  </div>

  <script>
    function updateBpmStep(val) {
      webkit.messageHandlers.settingsHandler.postMessage({ type: "setBpmStep", value: parseInt(val) });
    }
    function toggleLogicSync(val) {
      webkit.messageHandlers.settingsHandler.postMessage({ type: "setLogicSync", value: val });
    }
    function updateGate(val) {
      webkit.messageHandlers.settingsHandler.postMessage({ type: "setGate", value: parseInt(val) });
    }
    function updateZoom(val) {
      webkit.messageHandlers.settingsHandler.postMessage({ type: "setZoom", value: parseFloat(val) });
    }
    function closeSettings() {
      webkit.messageHandlers.settingsHandler.postMessage({ type: "close" });
    }
  </script>
</body>
</html>
  ]],
    bpmStep == 1 and "selected" or "",
    bpmStep == 5 and "selected" or "",
    bpmStep == 10 and "selected" or "",
    bpmStep == 25 and "selected" or "",
    logicSync and "checked" or "",
    math.floor(gate),
    math.abs(state.zoomLevel - 0.8) < 0.05 and "selected" or "",
    math.abs(state.zoomLevel - 1.0) < 0.05 and "selected" or "",
    math.abs(state.zoomLevel - 1.2) < 0.05 and "selected" or "",
    math.abs(state.zoomLevel - 1.4) < 0.05 and "selected" or ""
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
    elseif body.type == "close" then
      if settingsWebview then
        settingsWebview:delete()
        settingsWebview = nil
      end
    end

    local hud = require("hud")
    hud.updateWebviewHud()
  end)

  local screen = hs.screen.mainScreen():frame()
  local w, h = 420, 480
  local x = math.floor(screen.x + (screen.w - w) / 2)
  local y = math.floor(screen.y + (screen.h - h) / 2)

  settingsWebview = hsWebview.new({ x = x, y = y, w = w, h = h }, { developerExtras = true }, uc)
  settingsWebview:windowTitle("QWERTY MIDI Settings")
  settingsWebview:windowStyle({ "titled", "closable", "utility", "nonactivating" })
  settingsWebview:html(generateSettingsHTML())
  settingsWebview:show()
end

return {
  toggleSettingsWindow = toggleSettingsWindow
}
