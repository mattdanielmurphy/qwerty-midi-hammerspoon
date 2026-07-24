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
    width: 855px;
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

  .badge-small {
    background: rgba(212, 163, 89, 0.15);
    border: 1.5px solid #d4a359;
    color: #d4a359;
    font-weight: 700;
    font-size: 11px;
    padding: 3px 4px;
    border-radius: 6px;
    display: flex;
    align-items: center;
    justify-content: center;
    white-space: nowrap;
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

  .badge-small option {
    background: #181614;
    color: #d4a359;
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
    flex-direction: row;
    align-items: center;
    gap: 4px;
    flex-shrink: 0;
    margin-left: auto;
    height: 44px;
  }

  .arp-row-toggle {
    font-size: 8.5px;
    font-weight: 700;
    color: #706558;
    background: rgba(36, 32, 28, 0.8);
    border: 1px solid rgba(112, 101, 88, 0.4);
    border-radius: 4px;
    padding: 3px 6px;
    cursor: pointer;
    outline: none;
    font-family: inherit;
    letter-spacing: 0.5px;
    transition: all 0.15s ease;
    -webkit-app-region: no-drag;
    height: 24px;
    display: flex;
    align-items: center;
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

  .row-with-controls {
    display: flex;
    align-items: center;
    width: 100%;
    height: 44px;
  }

  .octave-row-badge {
    font-size: 9.5px;
    font-weight: 700;
    color: #d4a359;
    background: rgba(36, 32, 28, 0.95);
    border: 1.5px solid rgba(212, 163, 89, 0.4);
    border-radius: 5px;
    padding: 2px 6px;
    letter-spacing: 0.3px;
    white-space: nowrap;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.3);
    height: 24px;
    display: flex;
    align-items: center;
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
      <button id="arp-power-btn" class="arp-btn">ARP: OFF</button>
      <select id="arp-dir-select" class="badge-small" title="Arp Direction">
        <option value="1">UP</option>
        <option value="2">DOWN</option>
        <option value="3">UP-DN</option>
        <option value="4">RND</option>
      </select>
      <select id="arp-rate-select" class="badge-small" title="Arp Time Division">
        <option value="1">1/4</option>
        <option value="2" selected>1/8</option>
        <option value="3">1/16</option>
        <option value="4">1/32</option>
        <option value="5">1/8T</option>
        <option value="6">1/16T</option>
      </select>
      <select id="arp-gate-select" class="badge-small" title="Arp Note Length / Gate">
        <option value="1">25%</option>
        <option value="2">50%</option>
        <option value="3" selected>80%</option>
        <option value="4">100%</option>
      </select>
      <div id="bpm-editor" class="bpm-editor">
        <button id="bpm-down" class="bpm-arrow-btn">&#9662;</button>
        <span id="bpm-value" class="bpm-display">120 BPM</span>
        <button id="bpm-up" class="bpm-arrow-btn">&#9652;</button>
      </div>
      <div id="status-text" class="status-info"></div>
    </div>
    
    <div class="keyboard-grid">
      <div id="row-number" class="keyboard-row number"></div>
      <div class="row-with-controls">
        <div id="row-upper" class="keyboard-row upper"></div>
        <div class="row-controls">
          <button id="arp-top-toggle" class="arp-row-toggle">ARP</button>
          <div id="octave-indicator-top" class="octave-row-badge draggable-octave" data-row="top">TOP +1</div>
          <div id="vol-indicator-top" class="octave-row-badge" title="Top Row Volume">VOL 79%</div>
        </div>
      </div>
      <div id="row-home" class="keyboard-row home"></div>
      <div class="row-with-controls">
        <div id="row-lower" class="keyboard-row lower"></div>
        <div class="row-controls">
          <button id="arp-bottom-toggle" class="arp-row-toggle active">ARP</button>
          <div id="octave-indicator-bottom" class="octave-row-badge draggable-octave" data-row="bottom">OCT 0</div>
          <div id="vol-indicator-bottom" class="octave-row-badge" title="Bottom Row Volume">VOL 79%</div>
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

    const arpPowerBtn = document.getElementById('arp-power-btn');
    if (arpPowerBtn) {
      arpPowerBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'toggleArpPower' });
        }
      });
    }

    const arpDirSelect = document.getElementById('arp-dir-select');
    if (arpDirSelect) {
      arpDirSelect.addEventListener('change', (e) => {
        const val = parseInt(e.target.value);
        if (!isNaN(val) && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'setArpDirection', directionIdx: val });
        }
      });
      arpDirSelect.addEventListener('mousedown', (e) => e.stopPropagation());
    }

    const arpRateSelect = document.getElementById('arp-rate-select');
    if (arpRateSelect) {
      arpRateSelect.addEventListener('change', (e) => {
        const val = parseInt(e.target.value);
        if (!isNaN(val) && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'setArpRate', rateIdx: val });
        }
      });
      arpRateSelect.addEventListener('mousedown', (e) => e.stopPropagation());
    }

    const arpGateSelect = document.getElementById('arp-gate-select');
    if (arpGateSelect) {
      arpGateSelect.addEventListener('change', (e) => {
        const val = parseInt(e.target.value);
        if (!isNaN(val) && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'setArpGate', gateIdx: val });
        }
      });
      arpGateSelect.addEventListener('mousedown', (e) => e.stopPropagation());
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

    if (data.arpEnabled !== undefined) {
      const arpPowerBtn = document.getElementById('arp-power-btn');
      if (arpPowerBtn) {
        arpPowerBtn.textContent = data.arpEnabled ? 'ARP: ON' : 'ARP: OFF';
        if (data.arpEnabled) {
          arpPowerBtn.classList.add('arp-active');
        } else {
          arpPowerBtn.classList.remove('arp-active');
        }
      }
    }

    if (data.arpDirectionIdx !== undefined) {
      const arpDirSelect = document.getElementById('arp-dir-select');
      if (arpDirSelect) arpDirSelect.value = data.arpDirectionIdx;
    }

    if (data.arpRateIdx !== undefined) {
      const arpRateSelect = document.getElementById('arp-rate-select');
      if (arpRateSelect) arpRateSelect.value = data.arpRateIdx;
    }

    if (data.arpGateIdx !== undefined) {
      const arpGateSelect = document.getElementById('arp-gate-select');
      if (arpGateSelect) arpGateSelect.value = data.arpGateIdx;
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

    if (data.topVolPercent !== undefined) {
      const topVolEl = document.getElementById('vol-indicator-top');
      if (topVolEl) {
        if (data.effectiveTopVolPercent !== undefined && data.effectiveTopVolPercent !== data.topVolPercent) {
          topVolEl.textContent = 'VOL ' + data.effectiveTopVolPercent + '% (🚀)';
        } else {
          topVolEl.textContent = 'VOL ' + data.topVolPercent + '%';
        }
      }
    }

    if (data.bottomVolPercent !== undefined) {
      const botVolEl = document.getElementById('vol-indicator-bottom');
      if (botVolEl) botVolEl.textContent = 'VOL ' + data.bottomVolPercent + '%';
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

return HTML_UI_CONTENT
