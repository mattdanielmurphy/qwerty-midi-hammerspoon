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
  local sensitivity = state.scrollSensitivity or 0.15
  local acceleration = state.scrollAcceleration or 1.0
  local initGain = state.scrollInertiaInitial or 1.0
  local decay = state.scrollInertiaDecay or 0.85
  local curveExp = state.scrollCurveExponent or 1.0

  -- Build BPM step selected states
  local bpmSel = { ["1"]="", ["5"]="", ["10"]="", ["25"]="" }
  bpmSel[tostring(bpmStep)] = "selected"

  -- Build input quantize selected states
  local inputQuant = state.inputQuantizeMode or "Off"
  local quantSel = { ["Off"]="", ["1/1"]="", ["1/2"]="", ["1/4"]="", ["1/8"]="", ["1/16"]="" }
  quantSel[inputQuant] = "selected"

  -- Build zoom selected states
  local zoomSel = {}
  for _, v in ipairs({0.8, 1.0, 1.2, 1.4}) do
    zoomSel[tostring(v)] = math.abs(zoom - v) < 0.05 and "selected" or ""
  end

  -- Format floats nicely for slider defaults
  local sensFmt    = string.format("%.2f", sensitivity)
  local accFmt     = string.format("%.2f", acceleration)
  local initFmt    = string.format("%.2f", initGain)
  local decayFmt   = string.format("%.2f", decay)
  local curveFmt   = string.format("%.1f", curveExp)

  return string.format([[
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; user-select: none; -webkit-user-select: none; }

    html, body {
      width: 100%%;
      height: 100%%;
      background: transparent !important;
      overflow: hidden;
    }

    body {
      font-family: Georgia, serif;
      color: #e2d5c0;
      font-size: 15px;
    }

    #panel {
      position: relative;
      background: linear-gradient(160deg, #1e1a13 0%%, #151108 100%%);
      border: 1.5px solid rgba(212, 163, 89, 0.4);
      border-radius: 16px;
      box-shadow: 0 8px 40px rgba(0,0,0,0.7), inset 0 1px 0 rgba(212,163,89,0.08);
      padding: 0;
      width: 100%%;
      height: 100%%;
      display: flex;
      flex-direction: column;
      overflow: hidden;
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
      min-height: 0;
      padding: 18px 20px 20px;
      -webkit-overflow-scrolling: touch;
    }

    #scroll-area::-webkit-scrollbar {
      width: 8px;
    }
    #scroll-area::-webkit-scrollbar-track {
      background: rgba(20, 16, 10, 0.4);
      border-radius: 4px;
    }
    #scroll-area::-webkit-scrollbar-thumb {
      background: rgba(212, 163, 89, 0.35);
      border-radius: 4px;
    }
    #scroll-area::-webkit-scrollbar-thumb:hover {
      background: rgba(212, 163, 89, 0.65);
    }

    /* ── Window Resizers ── */
    #resize-grip {
      position: absolute;
      right: 4px;
      bottom: 4px;
      width: 20px;
      height: 20px;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: nwse-resize;
      opacity: 0.55;
      transition: opacity 0.15s;
      z-index: 999;
      -webkit-app-region: no-drag;
      pointer-events: auto;
    }
    #resize-grip:hover {
      opacity: 1;
    }
    #resize-edge-r {
      position: absolute;
      top: 16px;
      right: 0;
      bottom: 16px;
      width: 6px;
      cursor: ew-resize;
      z-index: 998;
      -webkit-app-region: no-drag;
    }
    #resize-edge-b {
      position: absolute;
      left: 16px;
      right: 16px;
      bottom: 0;
      height: 6px;
      cursor: ns-resize;
      z-index: 998;
      -webkit-app-region: no-drag;
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
          <strong>Base Sensitivity</strong>
          <span>Baseline 1:1 speed multiplier for standard finger movements (0.02 - 2.00)</span>
        </div>
        <div class="slider-row">
          <input type="range" id="sensitivitySlider" min="0.02" max="2.00" step="0.01"
            value="%s"
            oninput="onSensitivity(this.value)">
          <div class="slider-val" id="sensitivityVal">%s</div>
        </div>
      </div>

      <div class="row">
        <div class="row-label">
          <strong>Speed / Acceleration</strong>
          <span>Active velocity multiplier while your fingers move on the glass (0.10 - 3.00)</span>
        </div>
        <div class="slider-row">
          <input type="range" id="accelerationSlider" min="0.10" max="3.00" step="0.10"
            value="%s"
            oninput="onAcceleration(this.value)">
          <div class="slider-val" id="accelerationVal">%s</div>
        </div>
      </div>

      <div class="row">
        <div class="row-label">
          <strong>Inertia Initial Kick</strong>
          <span>Initial impulse strength when fingers break contact (0.00 = hard stop)</span>
        </div>
        <div class="slider-row">
          <input type="range" id="initSlider" min="0.00" max="2.00" step="0.01"
            value="%s"
            oninput="onInit(this.value)">
          <div class="slider-val" id="initVal">%s</div>
        </div>
      </div>

      <div class="row">
        <div class="row-label">
          <strong>Friction / Decay Rate</strong>
          <span>Deceleration rate after lift-off (0.10 = instant stop, 0.95 = long glide)</span>
        </div>
        <div class="slider-row">
          <input type="range" id="decaySlider" min="0.10" max="0.99" step="0.01"
            value="%s"
            oninput="onDecay(this.value)">
          <div class="slider-val" id="decayVal">%s</div>
        </div>
      </div>

      <div class="row">
        <div class="row-label">
          <strong>Max Inertia Duration</strong>
          <span>Hard cap on momentum duration (50ms = sharp stop, 500ms = long coast)</span>
        </div>
        <input type="number" id="maxInertiaMs" value="%d" min="50" max="600" step="10"
          onchange="send('setMaxInertia', parseInt(this.value))">
      </div>

      <div class="row">
        <div class="row-label">
          <strong>Low Velocity Cutoff</strong>
          <span>Cuts off the slow unpredictable tail at the end of momentum</span>
        </div>
        <div class="slider-row">
          <input type="range" id="inertiaCutoffSlider" min="0.1" max="2.0" step="0.1"
            value="%s"
            oninput="onCutoff(this.value)">
          <div class="slider-val" id="inertiaCutoffVal">%s</div>
        </div>
      </div>

      <div class="row">
        <div class="row-label">
          <strong>Velocity Curve Exponent</strong>
          <span>Gesture curve shape (1.0 = linear, 2.0 = exponential ramp-up/down)</span>
        </div>
        <div class="slider-row">
          <input type="range" id="curveSlider" min="0.5" max="3.0" step="0.1"
            value="%s"
            oninput="onCurve(this.value)">
          <div class="slider-val" id="curveVal">%s</div>
        </div>
      </div>
      <div style="margin-top: 15px;">
        <canvas id="physicsCanvas" width="460" height="140" style="background:rgba(20,16,10,0.6); border:1px solid rgba(212,163,89,0.3); border-radius:8px; cursor:crosshair;"></canvas>
        <div style="font-size: 0.72rem; color: rgba(212,163,89,0.7); margin-top: 6px; display: flex; justify-content: space-between;"><span>── Solid: Response Curve</span><span>- - Dashed: Coasting Tail (with Hard Cutoff)</span><span>Scroll box to test</span></div>
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
          <strong>Input Quantization</strong>
          <span>Real-time snapping for keys &amp; pads</span>
        </div>
        <select id="inputQuantize" onchange="send('setInputQuantize', this.value)">
          <option value="Off" %s>OFF (Instant)</option>
          <option value="1/1" %s>1/1 (Whole Note)</option>
          <option value="1/2" %s>1/2 (Half Note)</option>
          <option value="1/4" %s>1/4 (Quarter Note)</option>
          <option value="1/8" %s>1/8 (Eighth Note)</option>
          <option value="1/16" %s>1/16 (Sixteenth Note)</option>
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

    <!-- UI Styling -->
    <div class="section">
      <div class="section-title">UI Styling</div>

      <div class="row">
        <div class="row-label">
          <strong>Action Key Hue</strong>
          <span>Base color tone (0-360)</span>
        </div>
        <div class="slider-row">
          <input type="range" min="0" max="360" step="1" value="%d"
            oninput="document.getElementById('hueVal').textContent=this.value"
            onchange="send('setUiActionKeyHue', parseInt(this.value))">
          <div class="slider-val" id="hueVal">%d</div>
        </div>
      </div>

      <div class="row">
        <div class="row-label">
          <strong>Action Key Saturation</strong>
          <span>Color intensity (0-100%%)</span>
        </div>
        <div class="slider-row">
          <input type="range" min="0" max="100" step="1" value="%d"
            oninput="document.getElementById('satVal').textContent=this.value+'%%'"
            onchange="send('setUiActionKeySat', parseInt(this.value))">
          <div class="slider-val" id="satVal">%d%%</div>
        </div>
      </div>

      <div class="row">
        <div class="row-label">
          <strong>Action Key Lightness</strong>
          <span>Brightness (0-100%%)</span>
        </div>
        <div class="slider-row">
          <input type="range" min="0" max="100" step="1" value="%d"
            oninput="document.getElementById('lightVal').textContent=this.value+'%%'"
            onchange="send('setUiActionKeyLight', parseInt(this.value))">
          <div class="slider-val" id="lightVal">%d%%</div>
        </div>
      </div>

      <div class="row">
        <div class="row-label">
          <strong>Action Key Opacity</strong>
          <span>Background transparency (0.0 - 1.0)</span>
        </div>
        <div class="slider-row">
          <input type="range" min="0.0" max="1.0" step="0.01" value="%.2f"
            oninput="document.getElementById('opVal').textContent=this.value"
            onchange="send('setUiActionKeyOpacity', parseFloat(this.value))">
          <div class="slider-val" id="opVal">%.2f</div>
        </div>
      </div>

      <div class="row">
        <div class="row-label">
          <strong>Border Opacity</strong>
          <span>Border transparency (0.0 - 1.0)</span>
        </div>
        <div class="slider-row">
          <input type="range" min="0.0" max="1.0" step="0.01" value="%.2f"
            oninput="document.getElementById('bOpVal').textContent=this.value"
            onchange="send('setUiActionKeyBorderOpacity', parseFloat(this.value))">
          <div class="slider-val" id="bOpVal">%.2f</div>
        </div>
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
  <div id="resize-edge-r"></div>
  <div id="resize-edge-b"></div>
  <div id="resize-grip" title="Drag to resize">
    <svg width="12" height="12" viewBox="0 0 12 12">
      <line x1="10" y1="2" x2="2" y2="10" stroke="rgba(212,163,89,0.6)" stroke-width="1.5" stroke-linecap="round"/>
      <line x1="10" y1="6" x2="6" y2="10" stroke="rgba(212,163,89,0.6)" stroke-width="1.5" stroke-linecap="round"/>
      <line x1="10" y1="10" x2="10" y2="10" stroke="rgba(212,163,89,0.6)" stroke-width="1.5" stroke-linecap="round"/>
    </svg>
  </div>
</div><!-- /panel -->

<script>
  function send(type, value) {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.settingsUserContent) {
      window.webkit.messageHandlers.settingsUserContent.postMessage({ type: type, value: value });
    }
  }

  // Hover detection for native scroll passthrough
  document.addEventListener('mouseenter', () => send('hoverSettings', true));
  document.addEventListener('mouseleave', () => send('hoverSettings', false));

  // Interactive Window Resizing
  function setupResizers() {
    const handleDrag = (startEv, mode) => {
      startEv.preventDefault();
      startEv.stopPropagation();
      const startX = startEv.screenX;
      const startY = startEv.screenY;
      const startW = window.innerWidth;
      const startH = window.innerHeight;

      document.body.style.cursor = mode === 'corner' ? 'nwse-resize' : (mode === 'x' ? 'ew-resize' : 'ns-resize');

      const onMove = (ev) => {
        let newW = startW;
        let newH = startH;
        if (mode === 'corner' || mode === 'x') {
          newW = Math.max(460, Math.min(1200, startW + (ev.screenX - startX)));
        }
        if (mode === 'corner' || mode === 'y') {
          newH = Math.max(400, Math.min(1100, startH + (ev.screenY - startY)));
        }
        send('resizeWindow', { w: Math.round(newW), h: Math.round(newH) });
      };

      const onUp = () => {
        document.body.style.cursor = '';
        window.removeEventListener('mousemove', onMove);
        window.removeEventListener('mouseup', onUp);
        send('saveWindowSize', { w: window.innerWidth, h: window.innerHeight });
      };

      window.addEventListener('mousemove', onMove);
      window.addEventListener('mouseup', onUp);
    };

    const grip = document.getElementById('resize-grip');
    if (grip) grip.addEventListener('mousedown', (e) => handleDrag(e, 'corner'));
    const edgeR = document.getElementById('resize-edge-r');
    if (edgeR) edgeR.addEventListener('mousedown', (e) => handleDrag(e, 'x'));
    const edgeB = document.getElementById('resize-edge-b');
    if (edgeB) edgeB.addEventListener('mousedown', (e) => handleDrag(e, 'y'));
  }
  setupResizers();

  window.addEventListener('resize', () => {
    const canvasWrap = canvas.parentElement;
    if (canvasWrap) {
      canvas.width = canvasWrap.clientWidth;
      drawPhysicsCanvas();
    }
  });
  function onSensitivity(v) {
    document.getElementById('sensitivityVal').textContent = parseFloat(v).toFixed(2);
    send('setSensitivity', parseFloat(v));
    drawPhysicsCanvas();
  }
  function onAcceleration(v) {
    document.getElementById('accelerationVal').textContent = parseFloat(v).toFixed(2);
    send('setAcceleration', parseFloat(v));
    drawPhysicsCanvas();
  }
  function onDecay(v) {
    document.getElementById('decayVal').textContent = parseFloat(v).toFixed(2);
    send('setDecay', parseFloat(v));
    drawPhysicsCanvas();
  }
  function onInit(v) {
    document.getElementById('initVal').textContent = parseFloat(v).toFixed(2);
    send('setInit', parseFloat(v));
    drawPhysicsCanvas();
  }
  function onCutoff(v) {
    document.getElementById('inertiaCutoffVal').textContent = parseFloat(v).toFixed(1);
    send('setCutoff', parseFloat(v));
    drawPhysicsCanvas();
  }
  function onCurve(v) {
    document.getElementById('curveVal').textContent = parseFloat(v).toFixed(1);
    send('setCurve', parseFloat(v));
    drawPhysicsCanvas();
  }

  const canvas = document.getElementById('physicsCanvas');
  const ctx = canvas.getContext('2d');
  let lastX = 0, lastY = 0;

  function drawPhysicsCanvas() {
    const w = canvas.width, h = canvas.height;
    const sensitivity = parseFloat(document.getElementById('sensitivitySlider').value);
    const acceleration = parseFloat(document.getElementById('accelerationSlider').value);
    const initGain = parseFloat(document.getElementById('initSlider').value);
    const decay = parseFloat(document.getElementById('decaySlider').value);
    const curveExp = parseFloat(document.getElementById('curveSlider').value);

    ctx.clearRect(0, 0, w, h);
    ctx.strokeStyle = 'rgba(212,163,89,0.3)';
    ctx.lineWidth = 1;
    for(let i=0; i<w; i+=40) { ctx.beginPath(); ctx.moveTo(i,0); ctx.lineTo(i,h); ctx.stroke(); }
    for(let i=0; i<h; i+=40) { ctx.beginPath(); ctx.moveTo(0,i); ctx.lineTo(w,i); ctx.stroke(); }

    ctx.beginPath();
    ctx.strokeStyle = '#d4a359';
    ctx.lineWidth = 2;
    for(let x=0; x<w; x++) {
      let vel = (x / w);
      let output = Math.pow(vel, curveExp) * sensitivity * acceleration;
      let y = h - (output * h * 2);
      if(x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
    }
    ctx.stroke();

    ctx.beginPath();
    ctx.strokeStyle = 'rgba(212,163,89,0.6)';
    ctx.setLineDash([5, 5]);
    const maxInertia = parseFloat(document.getElementById('maxInertiaMs').value);
    for(let x=0; x<w; x++) {
      let time = x / w;
      if (time * 1000 > maxInertia) {
        ctx.lineTo(x, h * 0.8);
        continue;
      }
      let y = (h * 0.8) - (initGain * Math.pow(decay, time * 10) * h * 0.5);
      if(x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
    }
    ctx.stroke();
    ctx.setLineDash([]);
  }

  canvas.addEventListener('wheel', (e) => {
    e.preventDefault();
    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    
    ctx.fillStyle = '#d4a359';
    ctx.beginPath();
    ctx.arc(x, y, 4, 0, Math.PI*2);
    ctx.fill();
    setTimeout(drawPhysicsCanvas, 200);
  });

  drawPhysicsCanvas();

  function syncState(s) {
    if (!s) return;
    if (s.bpmStepSize !== undefined) {
      var el = document.getElementById('bpmStepSize');
      if (el) el.value = String(s.bpmStepSize);
    }
    if (s.inputQuantizeMode !== undefined) {
      var el = document.getElementById('inputQuantize');
      if (el) el.value = String(s.inputQuantizeMode);
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
    if (s.scrollSensitivity !== undefined) {
      var el = document.getElementById('sensitivitySlider');
      if (el) el.value = s.scrollSensitivity;
      var valEl = document.getElementById('sensitivityVal');
      if (valEl) valEl.textContent = parseFloat(s.scrollSensitivity).toFixed(2);
    }
    if (s.scrollAcceleration !== undefined) {
      var el = document.getElementById('accelerationSlider');
      if (el) el.value = s.scrollAcceleration;
      var valEl = document.getElementById('accelerationVal');
      if (valEl) valEl.textContent = parseFloat(s.scrollAcceleration).toFixed(2);
    }
    if (s.scrollInertiaInitial !== undefined) {
      var el = document.getElementById('initSlider');
      if (el) el.value = s.scrollInertiaInitial;
      var valEl = document.getElementById('initVal');
      if (valEl) valEl.textContent = parseFloat(s.scrollInertiaInitial).toFixed(2);
    }
    if (s.scrollInertiaDecay !== undefined) {
      var el = document.getElementById('decaySlider');
      if (el) el.value = s.scrollInertiaDecay;
      var valEl = document.getElementById('decayVal');
      if (valEl) valEl.textContent = parseFloat(s.scrollInertiaDecay).toFixed(2);
    }
    if (s.scrollMaxInertiaMs !== undefined) {
      var el = document.getElementById('maxInertiaMs');
      if (el) el.value = s.scrollMaxInertiaMs;
    }
    if (s.scrollInertiaCutoff !== undefined) {
      var el = document.getElementById('inertiaCutoffSlider');
      if (el) el.value = s.scrollInertiaCutoff;
      var valEl = document.getElementById('inertiaCutoffVal');
      if (valEl) valEl.textContent = parseFloat(s.scrollInertiaCutoff).toFixed(1);
    }
    if (s.scrollCurveExponent !== undefined) {
      var el = document.getElementById('curveSlider');
      if (el) el.value = s.scrollCurveExponent;
      var valEl = document.getElementById('curveVal');
      if (valEl) valEl.textContent = parseFloat(s.scrollCurveExponent).toFixed(1);
    }
    drawPhysicsCanvas();
  }
</script>
</body>
</html>
]],
    -- sensitivity slider
    sensFmt, sensFmt,
    -- acceleration slider
    accFmt, accFmt,
    initFmt, initFmt,
    decayFmt, decayFmt,
    math.floor(state.scrollMaxInertiaMs or 250),
    string.format("%.1f", state.scrollInertiaCutoff or 0.5), string.format("%.1f", state.scrollInertiaCutoff or 0.5),
    curveFmt, curveFmt,
    -- bpm step selects
    bpmSel["1"], bpmSel["5"], bpmSel["10"], bpmSel["25"],
    -- input quantize selects
    quantSel["Off"], quantSel["1/1"], quantSel["1/2"], quantSel["1/4"], quantSel["1/8"], quantSel["1/16"],
    -- logic sync checked
    logicSync and "checked" or "",
    -- ui
    state.uiActionKeyHue or 30, state.uiActionKeyHue or 30,
    state.uiActionKeySat or 20, state.uiActionKeySat or 20,
    state.uiActionKeyLight or 75, state.uiActionKeyLight or 75,
    state.uiActionKeyOpacity or 0.08, state.uiActionKeyOpacity or 0.08,
    state.uiActionKeyBorderOpacity or 0.6, state.uiActionKeyBorderOpacity or 0.6,
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
    local act = body.type
    local val = body.value

    if act == "setBpmStep" then
      local val = tonumber(body.value) or 10
      state.bpmStepSize = val
      hs.settings.set("qwertyMidi_bpmStepSize", val)
    elseif act == "setInputQuantize" then
      local val = tostring(body.value or "Off")
      state.inputQuantizeMode = val
      hs.settings.set("qwertyMidi_inputQuantizeMode", val)
      pcall(function() require("hud").updateWebviewHud() end)
    elseif act == "setGatePercent" then
      state.arpGatePercent = val
      hs.settings.set("qwertyMidi_arpGatePercent", val)
      if state.arpEnabled then
        require("arpeggiator").applyGatePercentChange()
      end
    elseif act == "setUiActionKeyHue" then
      state.uiActionKeyHue = val
      hs.settings.set("qwertyMidi_uiActionKeyHue", val)
      require("hud").updateWebviewHud()
    elseif act == "setUiActionKeySat" then
      state.uiActionKeySat = val
      hs.settings.set("qwertyMidi_uiActionKeySat", val)
      require("hud").updateWebviewHud()
    elseif act == "setUiActionKeyLight" then
      state.uiActionKeyLight = val
      hs.settings.set("qwertyMidi_uiActionKeyLight", val)
      require("hud").updateWebviewHud()
    elseif act == "setUiActionKeyOpacity" then
      state.uiActionKeyOpacity = val
      hs.settings.set("qwertyMidi_uiActionKeyOpacity", val)
      require("hud").updateWebviewHud()
    elseif act == "setUiActionKeyBorderOpacity" then
      state.uiActionKeyBorderOpacity = val
      hs.settings.set("qwertyMidi_uiActionKeyBorderOpacity", val)
      require("hud").updateWebviewHud()
    elseif act == "setLogicSync" then
      local val = (body.value == true or body.value == "true" or body.value == 1)
      state.logicSyncEnabled = val
      hs.settings.set("qwertyMidi_logicSyncEnabled", val)
    elseif act == "setGate" then
      local val = tonumber(body.value) or 80.0
      state.arpGatePercent = math.max(5.0, math.min(150.0, val))
    elseif act == "setZoom" then
      local val = tonumber(body.value) or 1.0
      state.zoomLevel = val
      hs.settings.set("qwertyMidi_zoomLevel", val)
    elseif body.type == "setSensitivity" then
      local val = tonumber(body.value) or 0.15
      state.scrollSensitivity = val
      hs.settings.set("qwertyMidi_scrollSensitivity", val)
    elseif body.type == "setAcceleration" then
      local val = tonumber(body.value) or 1.0
      state.scrollAcceleration = val
      hs.settings.set("qwertyMidi_scrollAcceleration", val)
    elseif body.type == "setInit" then
      local val = tonumber(body.value) or 1.0
      state.scrollInertiaInitial = val
      hs.settings.set("qwertyMidi_scrollInertiaInitial", val)
    elseif body.type == "setDecay" then
      local val = tonumber(body.value) or 0.85
      state.scrollInertiaDecay = math.max(0.1, math.min(0.99, val))
      hs.settings.set("qwertyMidi_scrollInertiaDecay", val)
    elseif body.type == "setCurve" then
      local val = tonumber(body.value) or 1.0
      state.scrollCurveExponent = math.max(0.5, math.min(3.0, val))
      hs.settings.set("qwertyMidi_scrollCurveExponent", val)
    elseif body.type == "setMaxInertia" then
      local val = tonumber(body.value) or 250
      state.scrollMaxInertiaMs = math.max(50, math.min(600, val))
      hs.settings.set("qwertyMidi_scrollMaxInertiaMs", val)
    elseif body.type == "setCutoff" then
      local val = tonumber(body.value) or 0.5
      state.scrollInertiaCutoff = math.max(0.1, math.min(2.0, val))
      hs.settings.set("qwertyMidi_scrollInertiaCutoff", val)
    elseif body.type == "hoverSettings" then
      _G.activeWatchers.isHoveringSettings = (val == true)
      return
    elseif body.type == "resizeWindow" then
      if _G.activeWatchers.settingsWebview and type(val) == "table" then
        local curFrame = _G.activeWatchers.settingsWebview:frame()
        local newW = math.max(460, math.min(1200, tonumber(val.w) or curFrame.w))
        local newH = math.max(400, math.min(1100, tonumber(val.h) or curFrame.h))
        _G.activeWatchers.settingsWebview:frame({ x = curFrame.x, y = curFrame.y, w = newW, h = newH })
      end
      return
    elseif body.type == "saveWindowSize" then
      if type(val) == "table" then
        hs.settings.set("qwertyMidi_settingsW", tonumber(val.w))
        hs.settings.set("qwertyMidi_settingsH", tonumber(val.h))
      end
      return
    elseif body.type == "close" then
      if _G.activeWatchers.settingsWebview then
        _G.activeWatchers.settingsWebview:hide()
      end
      _G.activeWatchers.isHoveringSettings = false
      return
    end

    config.saveSettings()
    local hud = require("hud")
    hud.updateWebviewHud()
  end)

  local savedW = hs.settings.get("qwertyMidi_settingsW") or 528
  local savedH = hs.settings.get("qwertyMidi_settingsH") or 640
  local w = math.max(460, math.min(1200, tonumber(savedW) or 528))
  local h = math.max(400, math.min(1100, tonumber(savedH) or 640))

  local screen = hs.screen.mainScreen():frame()
  local x = math.floor(screen.x + (screen.w - w) / 2)
  local y = math.floor(screen.y + (screen.h - h) / 2)

  local wv = hsWebview.new({ x = x, y = y, w = w, h = h }, { developerExtrasEnabled = true }, uc)
  wv:windowTitle("QWERTY MIDI Settings")
  -- Borderless transparent floating panel with rounded corners and resize capability
  wv:windowStyle({ "borderless", "resizable", "nonactivating" })
  wv:transparent(true)
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
    inputQuantizeMode = state.inputQuantizeMode or "Off",
    logicSyncEnabled = state.logicSyncEnabled,
    arpGatePercent = state.arpGatePercent or 80,
    zoomLevel = state.zoomLevel or 1.0,
    scrollSensitivity = state.scrollSensitivity or 0.15,
    scrollAcceleration = state.scrollAcceleration or 1.0,
    scrollInertiaInitial = state.scrollInertiaInitial or 1.0,
    scrollInertiaDecay = state.scrollInertiaDecay or 0.85,
    scrollCurveExponent = state.scrollCurveExponent or 1.0,
    scrollMaxInertiaMs = state.scrollMaxInertiaMs or 250,
    scrollInertiaCutoff = state.scrollInertiaCutoff or 0.5
  }
  local jsonStr = hs.json.encode(s)
  _G.activeWatchers.settingsWebview:evaluateJavaScript("syncState(" .. jsonStr .. ");")
end

local function toggleSettingsWindow()
  local wv = createSettingsWebview()

  if wv:isVisible() then
    wv:hide()
    _G.activeWatchers.isHoveringSettings = false
  else
    local curFrame = wv:frame()
    local screen = hs.screen.mainScreen():frame()
    local savedW = hs.settings.get("qwertyMidi_settingsW") or curFrame.w or 528
    local savedH = hs.settings.get("qwertyMidi_settingsH") or curFrame.h or 640
    local w = math.max(460, math.min(1200, tonumber(savedW) or 528))
    local h = math.max(400, math.min(1100, tonumber(savedH) or 640))
    local x = curFrame.x
    local y = curFrame.y
    if x < screen.x or x > screen.x + screen.w - 50 or y < screen.y or y > screen.y + screen.h - 50 then
      x = math.floor(screen.x + (screen.w - w) / 2)
      y = math.floor(screen.y + (screen.h - h) / 2)
    end
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
