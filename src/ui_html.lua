local HTML_UI_CONTENT = [[
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  :root {
    --action-bg-hsl: 0, 0%, 18%;
    --action-bg-opacity: 0.85;
    --action-border-opacity: 0.4;
    --active-track-color: #00e5ff;
    --active-track-rgb: 0, 229, 255;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; user-select: none; -webkit-user-select: none; -webkit-font-smoothing: antialiased; -moz-osx-font-smoothing: grayscale; text-rendering: optimizeLegibility; }
  input, textarea, [contenteditable] { user-select: auto; -webkit-user-select: auto; }
  html, body {
    background: transparent;
    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', system-ui, sans-serif;
    width: 100%;
    height: 100%;
    overflow: visible;
    position: relative;
    display: flex;
    flex-direction: column;
    justify-content: flex-end;
    align-items: center;
    border-radius: 14px;
    padding-bottom: 6px;
  }

  #notification-zone {
    position: absolute;
    top: 6px;
    left: 0; right: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 99999;
    pointer-events: none;
  }

  #hud-container {
    width: 980px;
    height: 280px;
    background: rgba(18, 18, 18, 0.97);
    border: 2px solid rgba(55, 55, 55, 0.7);
    border-radius: 14px;
    overflow: hidden;
    box-shadow: 0 10px 30px rgba(0,0,0,0.6), inset 0 0 20px rgba(0, 0, 0, 0.6);
    display: flex;
    flex-direction: column;
    padding: 12px 14px 14px 14px;
    position: relative;
    transform-origin: bottom center;
    transform: scale(1.4);
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
  }

  /* Top Header Spotlight Notification Card */
  .spotlight-card {
    position: relative;
    background: rgba(26, 26, 26, 0.98);
    border: 1.5px solid rgba(255, 255, 255, 0.25);
    border-radius: 8px;
    padding: 6px 20px;
    box-shadow: 0 0 0 1px rgba(255, 255, 255, 0.1), 0 0 12px rgba(0, 0, 0, 0.5);
    display: flex;
    flex-direction: row;
    align-items: center;
    justify-content: center;
    gap: 10px;
    z-index: 9999;
    pointer-events: none;
    opacity: 1;
    white-space: nowrap;
    margin: 0 auto;
  }

  .spotlight-card.hidden {
    opacity: 0;
    display: none;
  }

  .spotlight-title {
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 1.5px;
    color: #999999;
    text-transform: uppercase;
    margin-bottom: 0;
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .spotlight-val {
    font-size: 20px;
    font-weight: 700;
    color: #ffffff;
    text-shadow: 0 1px 4px rgba(0,0,0,0.6);
    margin-bottom: 0;
    white-space: nowrap;
  }

  .spotlight-sub {
    font-size: 12px;
    font-weight: 600;
    color: var(--active-track-color, #00e5ff);
    white-space: nowrap;
  }

  /* Dynamic Mod Wheel Glow — driven by --mod-intensity (0.00–1.00) */
  #hud-container {
    box-shadow:
      0 0 calc(var(--mod-intensity) * 18px) rgba(255, 255, 255, calc(var(--mod-intensity) * 0.3)),
      inset 0 0 calc(var(--mod-intensity) * 24px) rgba(255, 255, 255, calc(var(--mod-intensity) * 0.15));
    border-color: rgba(255, 255, 255, calc(0.2 + var(--mod-intensity) * 0.4));
    transition: box-shadow 0.08s ease, border-color 0.08s ease, height 0.25s cubic-bezier(0.16, 1, 0.3, 1);
    border-radius: 14px;
  }
  #hud-container.edit-mode-active {
    height: 460px;
  }
  body.mode-select-active #hud-container {
    opacity: 0.7;
    filter: blur(1px);
    transition: all 0.2s;
  }

  .mod-gradient-overlay {
    position: absolute;
    top: 0; left: 0; right: 0; bottom: 0;
    border-radius: inherit;
    overflow: hidden;
    pointer-events: none;
    background: linear-gradient(
      180deg,
      rgba(255, 255, 255, calc(var(--mod-intensity) * var(--mod-intensity) * 0.12)) 0%,
      rgba(255, 255, 255, 0) 60%
    );
    transition: background 0.08s ease;
  }


  /* Mod Wheel Bar */
  #mod-wheel-widget {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 2px;
    flex-shrink: 0;
    -webkit-app-region: no-drag;
    min-width: 68px;
  }

  #mod-wheel-track {
    width: 68px;
    height: 8px;
    background: rgba(30, 26, 22, 0.9);
    border: 1px solid rgba(212, 163, 89, 0.35);
    border-radius: 4px;
    position: relative;
    overflow: hidden;
  }

  #mod-wheel-fill {
    position: absolute;
    left: 0; top: 0; bottom: 0;
    width: 0%;
    background: linear-gradient(90deg, #8a5c1a 0%, #c88c28 50%, #f0b83c 100%);
    border-radius: 4px;
    transition: width 0.05s linear, box-shadow 0.05s linear;
  }

  #mod-wheel-fill.hot {
    box-shadow: 0 0 6px rgba(240, 184, 60, 0.8), 0 0 12px rgba(212, 163, 89, 0.4);
  }

  #mod-wheel-label {
    font-size: 9px;
    font-weight: 700;
    color: rgba(212, 163, 89, 0.6);
    letter-spacing: 0.5px;
    white-space: nowrap;
    transition: color 0.1s ease;
  }

  #mod-wheel-widget.active #mod-wheel-label {
    color: #f0b83c;
  }


  /* Header Bar */
  #header {
    height: 48px;
    background: rgba(28, 28, 28, 0.95);
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
    background: rgba(255, 255, 255, 0.08);
    border: 1.5px solid rgba(255, 255, 255, 0.22);
    color: #e5e5e5;
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
    background: rgba(255, 255, 255, 0.06);
    border: 1.5px solid rgba(255, 255, 255, 0.2);
    color: #e5e5e5;
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
    background: #181818;
    color: #e5e5e5;
  }

  #layout-select {
    max-width: 140px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    text-align: left;
    text-align-last: left;
    padding-left: 6px;
    padding-right: 6px;
  }

  .badge option {
    background: #181818;
    color: #e5e5e5;
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
    background: linear-gradient(90deg, #666 0%, #555 40%, #3a3a3a 70%, #222 100%);
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
    color: #d0d0d0;
    letter-spacing: 0.5px;
    margin-top: 3px;
    white-space: nowrap;
    text-shadow: 0 1px 2px rgba(0,0,0,0.6);
  }

  .arp-btn {
    background: rgba(255, 255, 255, 0.08);
    border: 1.5px solid rgba(255, 255, 255, 0.22);
    color: #d0d0d0;
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
    background: rgba(255, 255, 255, 0.15);
  }

  .arp-btn.arp-active {
    background: rgba(0, 229, 255, 0.22);
    border-color: #00e5ff;
    color: #00e5ff;
    box-shadow: 0 0 8px rgba(0, 229, 255, 0.5);
  }

  .arp-btn.arp-latch {
    background: rgba(0, 229, 255, 0.4);
    border-color: #00e5ff;
    box-shadow: 0 0 12px rgba(0, 229, 255, 0.8), inset 0 0 4px rgba(0, 229, 255, 0.3);
    color: #fff;
  }

  .bpm-editor {
    display: flex;
    align-items: center;
    gap: 2px;
    -webkit-app-region: no-drag;
    flex-shrink: 0;
  }

  .bpm-arrow-btn {
    background: rgba(255, 255, 255, 0.08);
    border: 1px solid rgba(255, 255, 255, 0.2);
    color: #d0d0d0;
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
    background: rgba(255, 255, 255, 0.18);
  }

  .bpm-display {
    font-size: 11px;
    font-weight: 700;
    color: #e5e5e5;
    padding: 3px 6px;
    border-radius: 4px;
    cursor: text;
    min-width: 60px;
    text-align: center;
    transition: background 0.15s ease, box-shadow 0.15s ease;
    white-space: nowrap;
  }

  .bpm-display:hover {
    background: rgba(255, 255, 255, 0.08);
  }

  .bpm-display.editing {
    background: rgba(255, 255, 255, 0.15);
    box-shadow: 0 0 6px rgba(255, 255, 255, 0.3);
    outline: 1.5px solid #ffffff;
  }

  .row-controls {
    display: flex;
    flex-direction: row;
    align-items: center;
    gap: 6px;
    flex-shrink: 0;
    margin-left: 8px;
    height: 44px;
  }

  .stacked-rows-icon {
    width: 14px;
    height: 14px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    flex-shrink: 0;
  }
  .stacked-rows-icon .rect {
    width: 14px;
    height: 5.5px;
    border: 1px solid #706558;
    border-radius: 1.5px;
    background: transparent;
    transition: all 0.15s ease;
  }
  .stacked-rows-icon.top-active .rect.top {
    background: #d4a359;
    border-color: #d4a359;
    box-shadow: 0 0 4px rgba(212, 163, 89, 0.5);
  }
  .stacked-rows-icon.bottom-active .rect.bottom {
    background: #d4a359;
    border-color: #d4a359;
    box-shadow: 0 0 4px rgba(212, 163, 89, 0.5);
  }
  .stacked-rows-icon.both-active .rect.top,
  .stacked-rows-icon.both-active .rect.bottom {
    background: #d4a359;
    border-color: #d4a359;
    box-shadow: 0 0 4px rgba(212, 163, 89, 0.5);
  }

  .key-pad .key-row-icon {
    position: absolute;
    top: 3px;
    left: 4px;
    width: 10px;
    height: 10px;
    display: none;
    pointer-events: none;
  }
  .key-pad .key-row-icon .rect {
    width: 10px;
    height: 3.8px;
    border-radius: 1px;
  }
  .key-pad .key-row-icon.top-active,
  .key-pad .key-row-icon.bottom-active,
  .key-pad .key-row-icon.both-active {
    display: flex;
  }

  .compact-oct-badge {
    font-size: 10px;
    font-weight: 700;
    color: #d4a359;
    background: rgba(212, 163, 89, 0.12);
    border: 1px solid rgba(212, 163, 89, 0.35);
    border-radius: 4px;
    padding: 2px 5px;
    letter-spacing: 0.5px;
    white-space: nowrap;
    height: 22px;
    display: flex;
    align-items: center;
    gap: 4px;
    cursor: ns-resize;
  }

  .vol-bar-container {
    width: 6px;
    height: 22px;
    background: rgba(30, 26, 22, 0.9);
    border: 1px solid rgba(212, 163, 89, 0.3);
    border-radius: 3px;
    position: relative;
    overflow: hidden;
    flex-shrink: 0;
  }
  .vol-bar-fill {
    position: absolute;
    bottom: 0; left: 0; right: 0;
    height: 79%;
    background: linear-gradient(0deg, #8a5c1a 0%, #c88c28 60%, #f0b83c 100%);
    border-radius: 1px;
    transition: height 0.08s ease;
  }

  .arp-row-toggle {
    font-size: 10px;
    font-weight: 700;
    color: #706558;
    background: transparent;
    border: none;
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
    text-shadow: 0 0 4px rgba(212, 163, 89, 0.4);
  }

  .arp-row-toggle:hover {
    color: #f2eae1;
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
    flex-shrink: 0;
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
    font-size: 10px;
    font-weight: 600;
    color: #a09588;
    background: transparent;
    border: none;
    padding: 2px 4px;
    letter-spacing: 0.5px;
    white-space: nowrap;
    height: 24px;
    display: flex;
    align-items: center;
  }

  .keyboard-row.number { margin-left: 0px; }
  .keyboard-row.upper { margin-left: 0px; }
  .keyboard-row.home { margin-left: 18px; }
  .keyboard-row.lower { margin-left: 42px; }

  .key-pad {
    width: 58px;
    height: 44px;
    background: rgba(25, 25, 25, 0.98);
    border: 1.5px solid rgba(55, 55, 55, 1.0);
    border-radius: 8px;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    transition: background 0.05s ease, border-color 0.05s ease;
    cursor: pointer;
    flex-shrink: 0;
    -webkit-app-region: no-drag;
    position: relative;
  }

  .key-pad:active, .key-pad.pressed {
    background: rgba(45, 45, 45, 1.0);
    border-color: rgba(90, 90, 90, 1.0);
    box-shadow: inset 0 2px 4px rgba(0,0,0,0.5);
  }

  .key-pad .key-code {
    font-size: 12px;
    font-weight: 700;
    color: #f0f0f0;
    text-shadow: 0 1px 2px rgba(0, 0, 0, 0.8);
    pointer-events: none;
  }

  .key-pad .key-note {
    font-size: 9.5px;
    font-weight: 500;
    color: rgba(200, 200, 200, 0.9);
    margin-top: 1px;
    white-space: nowrap;
    text-shadow: 0 1px 2px rgba(0, 0, 0, 0.8);
    pointer-events: none;
  }

  /* Note Keys: Colors strictly driven by Active Track */
  .key-pad:not(.control-pad):not(.dummy-pad) .key-note {
    color: var(--active-track-color, #00e5ff);
  }

  /* Glowing Outlines for Note Intervals */
  .key-pad.root-key:not(.control-pad) {
    border-color: var(--active-track-color, #00e5ff) !important;
    box-shadow: 0 0 10px rgba(var(--active-track-rgb, 0, 229, 255), 0.5), inset 0 0 6px rgba(var(--active-track-rgb, 0, 229, 255), 0.25) !important;
  }
  .key-pad.root-key:not(.control-pad) .key-note {
    color: #ffffff !important;
    font-weight: 700;
    text-shadow: 0 0 6px var(--active-track-color, #00e5ff);
  }
  .key-pad.root-key:not(.control-pad):active, .key-pad.root-key:not(.control-pad).pressed {
    background: rgba(var(--active-track-rgb, 0, 229, 255), 0.3) !important;
  }

  .key-pad.third-key:not(.control-pad) {
    border: 1.5px dashed rgba(var(--active-track-rgb, 0, 229, 255), 0.75) !important;
    box-shadow: 0 0 6px rgba(var(--active-track-rgb, 0, 229, 255), 0.3), inset 0 0 4px rgba(var(--active-track-rgb, 0, 229, 255), 0.15) !important;
  }
  .key-pad.third-key:not(.control-pad) .key-note {
    color: var(--active-track-color, #00e5ff) !important;
    font-weight: 600;
  }
  .key-pad.third-key:not(.control-pad):active, .key-pad.third-key:not(.control-pad).pressed {
    background: rgba(var(--active-track-rgb, 0, 229, 255), 0.2) !important;
  }

  .key-pad.fifth-key:not(.control-pad) {
    border-color: rgba(var(--active-track-rgb, 0, 229, 255), 0.5) !important;
    box-shadow: 0 0 4px rgba(var(--active-track-rgb, 0, 229, 255), 0.2) !important;
  }
  .key-pad.fifth-key:not(.control-pad) .key-note {
    color: rgba(var(--active-track-rgb, 0, 229, 255), 0.85) !important;
    font-weight: 500;
  }
  .key-pad.fifth-key:not(.control-pad):active, .key-pad.fifth-key:not(.control-pad).pressed {
    background: rgba(var(--active-track-rgb, 0, 229, 255), 0.15) !important;
  }

  /* Physical & Arp Press on Note Keys */
  .key-pad:not(.control-pad).pressed, .key-pad:not(.control-pad):active {
    background: rgba(var(--active-track-rgb, 0, 229, 255), 0.25) !important;
    border-color: var(--active-track-color, #00e5ff) !important;
    box-shadow: 0 0 10px rgba(var(--active-track-rgb, 0, 229, 255), 0.5), inset 0 2px 4px rgba(0,0,0,0.5) !important;
  }

  .key-pad.control-pad {
    background: hsla(var(--action-bg-hsl), var(--action-bg-opacity));
    border-color: hsla(var(--action-bg-hsl), var(--action-border-opacity));
  }
  .key-pad.control-pad:active, .key-pad.control-pad.pressed {
    background: hsla(var(--action-bg-hsl), calc(var(--action-bg-opacity) + 0.15));
  }

  .key-pad.control-pad .key-note {
    color: #999999;
    font-size: 9.5px;
  }

  /* Correlated Control Pairs & Special Controls */
  .key-pad.ctrl-trnsp { border-color: rgba(94, 162, 235, 0.45); }
  .key-pad.ctrl-trnsp .key-note { color: #8abef2; font-weight: 600; }

  .key-pad.ctrl-root { border-color: rgba(220, 120, 100, 0.45); }
  .key-pad.ctrl-root .key-note { color: #e69d90; font-weight: 600; }

  .key-pad.ctrl-mode { border-color: rgba(255, 255, 255, 0.3); }
  .key-pad.ctrl-mode .key-note { color: #d0d0d0; font-weight: 600; }

  .key-pad.ctrl-oct { border-color: rgba(82, 180, 150, 0.45); }
  .key-pad.ctrl-oct .key-note { color: #78c9ad; font-weight: 600; }

  .key-pad.ctrl-topoct { border-color: rgba(160, 130, 220, 0.45); }
  .key-pad.ctrl-topoct .key-note { color: #beaaeb; font-weight: 600; }

  .key-pad.ctrl-modw { border-color: rgba(220, 140, 180, 0.45); }
  .key-pad.ctrl-modw .key-note { color: #e3a0c0; font-weight: 600; }

  .key-pad.ctrl-vol { border-color: rgba(200, 170, 100, 0.45); }
  .key-pad.ctrl-vol .key-note { color: #d8c280; font-weight: 600; }

  .key-pad.ctrl-arpdir { border-color: rgba(100, 175, 210, 0.45); }
  .key-pad.ctrl-arpdir .key-note { color: #8ec3df; font-weight: 600; }

  .key-pad.ctrl-arprate { border-color: rgba(180, 170, 100, 0.45); }
  .key-pad.ctrl-arprate .key-note { color: #c9c382; font-weight: 600; }

  .key-pad.ctrl-arpgate { border-color: rgba(120, 185, 130, 0.45); }
  .key-pad.ctrl-arpgate .key-note { color: #9ed4a8; font-weight: 600; }

  .key-pad.ctrl-rel { border-color: rgba(195, 135, 205, 0.45); }
  .key-pad.ctrl-rel .key-note { color: #cf9ee1; font-weight: 600; }

  .key-pad.ctrl-bpm { border-color: rgba(215, 145, 110, 0.45); }
  .key-pad.ctrl-bpm .key-note { color: #e2ab90; font-weight: 600; }

  .key-pad.ctrl-zoom { border-color: rgba(130, 165, 195, 0.45); }
  .key-pad.ctrl-zoom .key-note { color: #a4c0d8; font-weight: 600; }

  .key-pad.ctrl-arp, .key-pad.ctrl-arptop, .key-pad.ctrl-arpbot { border-color: rgba(0, 229, 255, 0.4); }
  .key-pad.ctrl-arp .key-note, .key-pad.ctrl-arptop .key-note, .key-pad.ctrl-arpbot .key-note { color: #00e5ff; font-weight: 600; }

  .key-pad.ctrl-bpmedit, .key-pad.ctrl-rand, .key-pad.ctrl-panic, .key-pad.ctrl-reset { border-color: rgba(120, 120, 120, 0.4); }
  .key-pad.ctrl-bpmedit .key-note, .key-pad.ctrl-rand .key-note, .key-pad.ctrl-panic .key-note, .key-pad.ctrl-reset .key-note { color: #b5aba0; font-weight: 500; }

  /* Row-specific track coloring */
  #row-upper {
    --active-track-color: var(--top-track-color, #00e676);
    --active-track-rgb: var(--top-track-rgb, 0, 230, 118);
  }
  #row-home, #row-lower {
    --active-track-color: var(--bottom-track-color, #00e5ff);
    --active-track-rgb: var(--bottom-track-rgb, 0, 229, 255);
  }

  /* Track selector cards retain their identity across every modifier layer. */
  #key-18 { --trk-color: #00e5ff; --trk-rgb: 0, 229, 255; }
  #key-19 { --trk-color: #ff9100; --trk-rgb: 255, 145, 0; }
  #key-20 { --trk-color: #00e676; --trk-rgb: 0, 230, 118; }
  #key-21 { --trk-color: #d500f9; --trk-rgb: 213, 0, 249; }

  .key-pad.track-card {
    border-color: rgba(var(--trk-rgb, 255, 255, 255), 0.35);
    position: relative;
    display: block;
  }
  .key-pad.track-card .key-code {
    color: var(--trk-color, #e0e0e0);
    position: absolute;
    top: 4px;
    left: 5px;
    font-size: 10px;
    line-height: 10px;
    text-align: left;
  }
  .key-pad.track-card .key-note {
    display: block;
    position: absolute;
    top: 18px;
    left: 3px;
    right: 3px;
    margin: 0;
    color: #d8d8d8;
    font-size: 7.5px;
    font-weight: 800;
    line-height: 9px;
    letter-spacing: 0.45px;
    overflow: hidden;
    text-align: center;
    text-overflow: ellipsis;
    text-transform: uppercase;
  }
  .key-pad.track-card .key-row-icon {
    display: none !important;
  }
  .trk-role {
    position: absolute;
    top: 4px;
    right: 4px;
    left: auto;
    min-width: 20px;
    height: 10px;
    padding: 0;
    border: 0;
    color: var(--trk-color);
    background: transparent;
    font-size: 6.5px;
    font-weight: 800;
    line-height: 10px;
    text-align: center;
    letter-spacing: 0.45px;
    text-shadow: 0 0 4px rgba(var(--trk-rgb), 0.5);
    pointer-events: none;
  }
  .key-pad.track-card .stacked-rows-icon.top-active .rect.top {
    background: var(--trk-color, #d4a359);
    border-color: var(--trk-color, #d4a359);
    box-shadow: 0 0 4px rgba(var(--trk-rgb, 212, 163, 89), 0.6);
  }
  .key-pad.track-card .stacked-rows-icon.bottom-active .rect.bottom {
    background: var(--trk-color, #d4a359);
    border-color: var(--trk-color, #d4a359);
    box-shadow: 0 0 4px rgba(var(--trk-rgb, 212, 163, 89), 0.6);
  }

  /* Selected Track: Active track for its row */
  .key-pad.track-card.trk-selected {
    border-color: var(--trk-color) !important;
    background: rgba(var(--trk-rgb), 0.22) !important;
    box-shadow: 0 0 10px rgba(var(--trk-rgb), 0.55), inset 0 0 6px rgba(var(--trk-rgb), 0.25) !important;
  }
  .key-pad.track-card.trk-selected .key-note {
    color: #ffffff !important;
    text-shadow: 0 0 6px var(--trk-color) !important;
    font-weight: 700 !important;
  }

  /* Discrete Clickable Mute & Solo Badges */
  .trk-ms-badges {
    position: absolute;
    right: 3px;
    bottom: 3px;
    display: flex;
    gap: 2px;
    z-index: 5;
  }
  .trk-badge {
    box-sizing: border-box;
    width: 10px;
    height: 10px;
    font-size: 8px;
    font-weight: 800;
    line-height: 8px;
    text-align: center;
    border-radius: 2px;
    cursor: pointer;
    user-select: none;
    transition: all 0.1s ease;
    border: 1px solid rgba(255, 255, 255, 0.15);
    background: rgba(255, 255, 255, 0.07);
    color: rgba(255, 255, 255, 0.45);
  }
  .trk-badge:hover {
    background: rgba(255, 255, 255, 0.22);
    color: #ffffff;
  }
  .trk-badge.trk-badge-m.active {
    background: #ff3b30 !important;
    color: #ffffff !important;
    border-color: #ff3b30 !important;
    box-shadow: 0 0 6px rgba(255, 59, 48, 0.8) !important;
  }
  .trk-badge.trk-badge-s.active {
    background: #ffd60a !important;
    color: #000000 !important;
    border-color: #ffd60a !important;
    box-shadow: 0 0 6px rgba(255, 214, 10, 0.8) !important;
  }

  /* Muted and Soloed Track Key Styling */
  .key-pad.track-card.trk-muted:not(.trk-selected) {
    border-color: rgba(var(--trk-rgb), 0.18);
  }
  .key-pad.track-card.trk-soloed {
    box-shadow: 0 0 8px rgba(255, 214, 10, 0.4);
  }

  /* Human Note Press: Tactile Pad Surface Glow (Subtle Invariant) */
  .key-pad.track-card.trk-human-active {
    background: rgba(var(--trk-rgb), 0.38) !important;
    box-shadow: inset 0 0 10px rgba(var(--trk-rgb), 0.7), 0 0 6px rgba(var(--trk-rgb), 0.4) !important;
  }

  /* Arpeggiator Stepping: Subtle Rhythmic Tempo Flash (Subtle Invariant) */
  .key-pad.track-card.trk-arp-step {
    border-color: #ffffff !important;
    box-shadow: 0 0 10px var(--trk-color, #00e5ff) !important;
  }

  /* Waveform Bars Overlay on Track Buttons */
  .trk-waveform {
    position: absolute;
    bottom: 2px;
    left: 4px;
    right: 4px;
    height: 10px;
    display: flex;
    align-items: flex-end;
    justify-content: center;
    gap: 2px;
    pointer-events: none;
    opacity: 0.18;
    transition: opacity 0.15s ease;
  }
  .trk-waveform .wbar {
    width: 3px;
    height: 2px;
    background: var(--trk-color, #888);
    border-radius: 1px;
    transition: height 0.08s ease;
  }
  .key-pad.trk-audio-active .trk-waveform {
    opacity: 1;
  }
  .key-pad.trk-audio-active .trk-waveform .wbar {
    background: var(--trk-color, #00e5ff);
    box-shadow: 0 0 4px var(--trk-color, #00e5ff);
    animation: trkWaveform 0.5s infinite ease-in-out alternate;
  }
  .key-pad.trk-audio-active .trk-waveform .wbar.b1 { animation-delay: 0.0s; }
  .key-pad.trk-audio-active .trk-waveform .wbar.b2 { animation-delay: 0.12s; }
  .key-pad.trk-audio-active .trk-waveform .wbar.b3 { animation-delay: 0.24s; }
  .key-pad.trk-audio-active .trk-waveform .wbar.b4 { animation-delay: 0.08s; }
  .key-pad.trk-audio-active .trk-waveform .wbar.b5 { animation-delay: 0.18s; }

  @keyframes trkWaveform {
    0% { height: 2px; }
    50% { height: 9px; }
    100% { height: 4px; }
  }

  /* K, L, and ; are track actions, not track cards: their labels stay visible. */
  .key-pad.ctrl-track:not(.track-card) {
    border-color: rgba(105, 190, 215, 0.5);
    background: rgba(35, 65, 74, 0.3);
  }
  .key-pad.ctrl-track:not(.track-card) .key-note {
    color: #8ed7ec;
    font-weight: 700;
  }
  .key-pad.track-card.ctrl-mute .key-note {
    color: #ff9da3;
  }
  .key-pad.track-card.ctrl-solo .key-note {
    color: #ffe174;
  }
  .key-pad.track-card.ctrl-lock .key-note {
    color: #d8c280;
  }

  .key-pad.ctrl-lock { border-color: rgba(255, 180, 50, 0.55); }
  .key-pad.ctrl-lock .key-note { color: #ffb833; font-weight: 600; }

  .key-pad.ctrl-mute { border-color: rgba(235, 90, 100, 0.5); }
  .key-pad.ctrl-mute .key-note { color: #f0707a; font-weight: 600; }

  .key-pad.ctrl-solo { border-color: rgba(255, 215, 0, 0.55); }
  .key-pad.ctrl-solo .key-note { color: #ffd700; font-weight: 600; }

  .key-pad.dummy-pad {
    opacity: 0.45;
    cursor: default;
    background: rgba(20, 20, 20, 0.7);
    border-color: rgba(45, 45, 45, 0.6);
  }

  .key-pad.sustain-active {
    background: rgba(0, 229, 255, 0.2);
    border-color: #00e5ff;
  }

  .key-pad.sustain-active .key-note {
    color: #00e5ff;
    font-weight: 600;
  }

  .key-pad.latch-active {
    background: rgba(0, 229, 255, 0.25) !important;
    border-color: #00e5ff !important;
    box-shadow: 0 0 8px rgba(0, 229, 255, 0.45), inset 0 0 6px rgba(0, 229, 255, 0.2) !important;
  }
  .key-pad.latch-active .key-note {
    color: #ffffff !important;
    font-weight: 700 !important;
  }

  .key-pad.latch-mode-active {
    background: rgba(0, 229, 255, 0.22) !important;
    border-color: #00e5ff !important;
    box-shadow: 0 0 10px rgba(0, 229, 255, 0.5), inset 0 0 8px rgba(0, 229, 255, 0.25) !important;
  }
  .key-pad.latch-mode-active .key-note {
    color: #00e5ff !important;
    font-weight: 700 !important;
  }

  /* Key 48 Smart Sustain & Classic Sustain Styles */
  #key-48:not(.latch-active):not(.latch-mode-active),
  #key-48.ctrl-sus,
  .key-pad.ctrl-sus,
  .key-pad.ctrl-sustain {
    background: #141417 !important;
    border-color: rgba(212, 163, 89, 0.22) !important;
    box-shadow: none !important;
  }
  #key-48:not(.latch-active):not(.latch-mode-active) .key-note,
  #key-48.ctrl-sus .key-note,
  .key-pad.ctrl-sus .key-note,
  .key-pad.ctrl-sustain .key-note {
    color: #8a7a58 !important;
    font-weight: 500 !important;
    text-shadow: none !important;
  }
  #key-48:not(.latch-active):not(.latch-mode-active) .key-code,
  #key-48.ctrl-sus .key-code,
  .key-pad.ctrl-sus .key-code,
  .key-pad.ctrl-sustain .key-code {
    color: #63636e !important;
  }

  #key-48.latch-active {
    background: rgba(255, 215, 0, 0.22) !important;
    border-color: #ffd700 !important;
    box-shadow: 0 0 10px rgba(255, 215, 0, 0.5), inset 0 0 6px rgba(255, 215, 0, 0.2) !important;
  }
  #key-48.latch-active .key-note {
    color: #ffd700 !important;
    font-weight: 700 !important;
    text-shadow: 0 0 6px rgba(255, 215, 0, 0.6);
  }

  #key-48.latch-mode-active {
    background: rgba(255, 145, 0, 0.22) !important;
    border-color: #ff9100 !important;
    box-shadow: 0 0 12px rgba(255, 145, 0, 0.55), inset 0 0 6px rgba(255, 145, 0, 0.25) !important;
  }
  #key-48.latch-mode-active .key-note {
    color: #ff9100 !important;
    font-weight: 700 !important;
    text-shadow: 0 0 6px rgba(255, 145, 0, 0.6);
  }

  /* Track Status Mode Tags: SUS and CHD */
  .trk-mode-tags {
    position: absolute;
    bottom: 3px;
    left: 3px;
    display: flex;
    gap: 2px;
    pointer-events: none;
    z-index: 4;
  }
  .trk-tag-sus, .trk-tag-chd {
    box-sizing: border-box;
    width: 9px;
    height: 9px;
    padding: 0;
    font-size: 7px;
    font-weight: 800;
    line-height: 9px;
    border-radius: 2px;
    display: none;
    letter-spacing: 0.2px;
    text-align: center;
  }
  .trk-tag-sus.active {
    display: inline-block;
    background: rgba(255, 215, 0, 0.25);
    color: #ffd700;
    border: 1px solid rgba(255, 215, 0, 0.5);
  }
  .trk-tag-sus.classic.active {
    background: rgba(255, 145, 0, 0.25);
    color: #ff9100;
    border: 1px solid rgba(255, 145, 0, 0.5);
  }
  .trk-tag-chd.active {
    display: inline-block;
    background: rgba(0, 229, 255, 0.25);
    color: #00e5ff;
    border: 1px solid rgba(0, 229, 255, 0.5);
  }

  /* Latched key: subtle border hint */
  .key-pad.latched-key {
    border-color: rgba(var(--active-track-rgb, 0, 229, 255), 0.4) !important;
  }

  .key-pad.latched-key:active, .key-pad.latched-key.pressed {
    background: rgba(var(--active-track-rgb, 0, 229, 255), 0.35) !important;
    border-color: var(--active-track-color, #00e5ff) !important;
    box-shadow: 0 0 12px rgba(var(--active-track-rgb, 0, 229, 255), 0.6), inset 0 0 8px rgba(var(--active-track-rgb, 0, 229, 255), 0.3);
  }

  /* Arp indicator dot — always in DOM for smooth opacity transitions */
  .key-pad .latch-dot {
    position: absolute;
    top: 3px;
    right: 5px;
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background-color: #5ea2eb;
    box-shadow: none;
    opacity: 0;
    /* Slow fade-out so the dot lingers as the note decays */
    transition: opacity 0.32s ease-out, box-shadow 0.32s ease-out, background-color 0.32s ease-out;
    pointer-events: none;
  }

  /* Playback telemetry is intentionally disabled until its signal is reliable. */
  .trk-waveform { display: none !important; }

  /* Pressed the key that triggered this latch chord — very faint dot */
  .key-pad.latched-key .latch-dot {
    opacity: 0.18;
  }

  /* Key's MIDI pitch is in the arp pool (all chord notes, not just pressed key) */
  .key-pad.arp-held .latch-dot {
    opacity: 0.38;
    box-shadow: 0 0 4px rgba(94, 162, 235, 0.65);
  }

  /* Key is the note currently being arpeggiated — bright, snappy on */
  .key-pad.arp-playing .latch-dot {
    opacity: 1.0;
    background-color: #aad6ff;
    box-shadow: 0 0 8px #5ea2eb, 0 0 18px rgba(94, 162, 235, 0.5);
    /* Fast attack so the dot snaps on with each arp step */
    transition: opacity 0.04s ease-in, box-shadow 0.04s ease-in, background-color 0.04s ease-in;
  }

  /* Edit Mode & Action Library Drawer Styling */
  #hud-container.shift-active-labels .arp-btn.arp-active {
    background: rgba(200, 100, 100, 0.3);
    border-color: rgba(200, 100, 100, 0.6);
    box-shadow: 0 0 8px rgba(200, 100, 100, 0.4);
    color: #fcc;
  }
  #hud-container.shift-active-labels .arp-row-toggle.active {
    color: #f88;
    text-shadow: 0 0 4px rgba(200, 100, 100, 0.4);
  }
  #hud-container.shift-active-labels .key-pad.arp-held .latch-dot,
  #hud-container.shift-active-labels .key-pad.arp-playing .latch-dot {
    opacity: 0.1 !important;
  }
  .edit-btn {
    background: rgba(212, 163, 89, 0.2);
    border: 1.5px solid #d4a359;
    color: #d4a359;
    transition: all 0.2s ease;
  }
  .edit-btn:hover {
    background: rgba(212, 163, 89, 0.4);
    box-shadow: 0 0 8px rgba(212, 163, 89, 0.5);
  }
  .edit-btn.active {
    background: #d4a359;
    color: #141210;
    font-weight: 800;
    box-shadow: 0 0 12px rgba(212, 163, 89, 0.8);
  }

  .drawer-panel {
    position: absolute;
    top: 0;
    right: 0;
    width: 270px;
    height: 100%;
    background: rgba(20, 18, 16, 0.97);
    backdrop-filter: blur(16px);
    -webkit-backdrop-filter: blur(16px);
    border-left: 2px solid #d4a359;
    box-shadow: -10px 0 30px rgba(0,0,0,0.85);
    z-index: 9900;
    display: flex;
    flex-direction: column;
    padding: 8px;
    transform: translateX(100%);
    transition: transform 0.25s cubic-bezier(0.16, 1, 0.3, 1), opacity 0.2s ease;
    opacity: 0;
    pointer-events: none;
    -webkit-app-region: no-drag;
  }

  .drawer-panel.active {
    transform: translateX(0);
    opacity: 1;
    pointer-events: auto;
  }

  .drawer-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding-bottom: 4px;
    border-bottom: 1px solid rgba(120, 105, 90, 0.3);
    margin-bottom: 4px;
  }

  .drawer-title {
    display: flex;
    flex-direction: column;
  }

  .drawer-title span:first-child {
    font-size: 12px;
    font-weight: 800;
    color: #d4a359;
    letter-spacing: 1px;
  }

  .drawer-subtitle {
    font-size: 9px;
    color: #a0958a;
    font-weight: 500;
  }

  .drawer-header-actions {
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .drawer-icon-btn {
    background: rgba(212, 163, 89, 0.12);
    border: 1px solid rgba(212, 163, 89, 0.4);
    color: #d4a359;
    font-size: 11px;
    font-weight: 700;
    padding: 1px 5px;
    border-radius: 4px;
    cursor: pointer;
    line-height: 1.2;
    transition: all 0.15s ease;
    height: 22px;
    display: flex;
    align-items: center;
  }

  .drawer-icon-btn:hover:not(.disabled) {
    background: rgba(212, 163, 89, 0.35);
    box-shadow: 0 0 8px rgba(212, 163, 89, 0.5);
  }

  .drawer-icon-btn.disabled {
    opacity: 0.35;
    cursor: not-allowed;
    border-color: rgba(120, 105, 90, 0.3);
    color: #a0958a;
  }

  .drawer-shift-btn {
    min-width: 52px;
  }
  .drawer-shift-btn.shift-active {
    background: #d4a359;
    color: #141210;
    font-weight: 800;
    box-shadow: 0 0 10px rgba(212, 163, 89, 0.7);
    border-color: #f0c27b;
  }
  .drawer-header.shifting .drawer-subtitle::after {
    content: ' • SHIFT MODE: drops assign Shift action';
    color: #f0c27b;
    font-weight: 700;
  }
  #hud-container.shift-assign-active .key-pad:not(.dummy-pad) {
    border-color: rgba(94, 162, 235, 0.6) !important;
  }
  #hud-container.shift-assign-active .key-pad.drag-over-target {
    background: rgba(94, 162, 235, 0.35) !important;
    border-color: #5ea2eb !important;
    box-shadow: 0 0 16px #5ea2eb, inset 0 0 10px rgba(94, 162, 235, 0.5) !important;
  }

  .drawer-close-btn {
    background: transparent;
    border: none;
    color: #d4a359;
    font-size: 20px;
    font-weight: 700;
    cursor: pointer;
    line-height: 1;
    padding: 0 4px;
    border-radius: 4px;
    transition: background 0.15s ease;
  }

  .drawer-close-btn:hover {
    background: rgba(212, 163, 89, 0.2);
  }

  .drawer-search-input {
    width: 100%;
    background: rgba(36, 32, 28, 0.8);
    border: 1px solid rgba(120, 105, 90, 0.5);
    border-radius: 5px;
    padding: 3px 6px;
    color: #ffffff;
    font-size: 11px;
    outline: none;
    margin-bottom: 4px;
    font-family: inherit;
  }
  .drawer-search-input:focus {
    border-color: #d4a359;
    box-shadow: 0 0 6px rgba(212, 163, 89, 0.4);
  }

  .drawer-content {
    flex: 1;
    overflow-y: auto;
    padding-right: 4px;
    margin-bottom: 4px;
  }

  .drawer-content::-webkit-scrollbar {
    width: 4px;
  }
  .drawer-content::-webkit-scrollbar-thumb {
    background: rgba(212, 163, 89, 0.4);
    border-radius: 2px;
  }

  .drawer-category-title {
    font-size: 9px;
    font-weight: 700;
    color: #d4a359;
    text-transform: uppercase;
    letter-spacing: 0.6px;
    margin: 4px 0 2px 0;
  }
  .drawer-category-title:first-child {
    margin-top: 0;
  }

  .drawer-item {
    background: rgba(36, 32, 28, 0.85);
    border: 1px solid rgba(100, 88, 75, 0.5);
    border-radius: 5px;
    padding: 3px 6px;
    margin-bottom: 3px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    cursor: grab;
    user-select: none;
    -webkit-user-select: none;
    transition: all 0.15s ease;
  }
  .drawer-item:hover {
    border-color: #d4a359;
    background: rgba(54, 46, 38, 0.95);
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.4);
  }
  .drawer-item:active {
    cursor: grabbing;
  }
  .drawer-item.dragging {
    opacity: 0.4;
    border: 1px dashed #d4a359;
  }

  .item-label {
    font-size: 11px;
    font-weight: 600;
    color: #e5dec9;
  }

  .item-badge {
    font-size: 9px;
    font-weight: 700;
    background: rgba(212, 163, 89, 0.15);
    color: #d4a359;
    padding: 1px 4px;
    border-radius: 4px;
    border: 1px solid rgba(212, 163, 89, 0.3);
  }

  .drawer-footer {
    display: flex;
    gap: 4px;
    padding-top: 4px;
    border-top: 1px solid rgba(120, 105, 90, 0.3);
  }

  /* Layout Presets Toolbar Styles — Ultra-Compact */
  .preset-bar {
    background: rgba(28, 25, 22, 0.85);
    border: 1px solid rgba(120, 105, 90, 0.4);
    border-radius: 4px;
    padding: 3px 6px;
    margin-bottom: 4px;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .preset-label-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .preset-bar-title {
    font-size: 8px;
    font-weight: 800;
    color: #d4a359;
    letter-spacing: 0.6px;
  }
  .preset-modified-badge {
    font-size: 8px;
    color: #f0c27b;
    font-weight: 700;
  }
  .preset-modified-badge.hidden {
    display: none;
  }
  .preset-controls-row {
    display: flex;
    align-items: center;
    gap: 3px;
  }
  .preset-dropdown {
    flex: 1;
    background: rgba(18, 16, 14, 0.9);
    border: 1px solid rgba(120, 105, 90, 0.5);
    border-radius: 3px;
    color: #f0f0f0;
    font-size: 9px;
    font-weight: 600;
    padding: 2px 4px;
    outline: none;
    font-family: inherit;
    height: 22px;
  }
  .preset-dropdown:focus {
    border-color: #d4a359;
  }

  /* Preset Modal Dialog */
  .preset-modal-overlay {
    position: absolute;
    top: 0; left: 0; right: 0; bottom: 0;
    background: rgba(10, 8, 6, 0.82);
    backdrop-filter: blur(4px);
    z-index: 1000;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .preset-modal-overlay.hidden {
    display: none;
  }
  .preset-modal-card {
    background: #1c1916;
    border: 1px solid #d4a359;
    box-shadow: 0 8px 32px rgba(0,0,0,0.8), 0 0 16px rgba(212,163,89,0.3);
    border-radius: 8px;
    padding: 14px 16px;
    width: 270px;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .preset-modal-title {
    font-size: 11px;
    font-weight: 800;
    color: #d4a359;
    letter-spacing: 0.8px;
    text-transform: uppercase;
  }
  .preset-modal-input {
    background: rgba(36, 32, 28, 0.9);
    border: 1px solid rgba(120, 105, 90, 0.6);
    border-radius: 5px;
    padding: 5px 8px;
    color: #ffffff;
    font-size: 12px;
    outline: none;
    font-family: inherit;
  }
  .preset-modal-input:focus {
    border-color: #d4a359;
    box-shadow: 0 0 6px rgba(212, 163, 89, 0.4);
  }
  .preset-modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: 6px;
  }

  .drawer-action-btn {
    flex: 1;
    padding: 6px 4px;
    border-radius: 6px;
    font-size: 10px;
    font-weight: 700;
    cursor: pointer;
    border: none;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    transition: all 0.15s ease;
  }

  .drawer-action-btn.primary {
    background: #d4a359;
    color: #141210;
  }
  .drawer-action-btn.primary:hover:not(.disabled) {
    background: #e8b668;
    box-shadow: 0 0 10px rgba(212, 163, 89, 0.6);
  }
  .drawer-action-btn.primary.disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .drawer-action-btn.warning {
    background: rgba(180, 70, 60, 0.25);
    color: #ff8877;
    border: 1px solid rgba(200, 80, 70, 0.5);
  }
  .drawer-action-btn.warning:hover {
    background: rgba(200, 80, 70, 0.45);
  }

  .drawer-action-btn.secondary {
    background: rgba(60, 54, 48, 0.7);
    color: #a0958a;
    border: 1px solid rgba(90, 80, 70, 0.5);
  }
  .drawer-action-btn.secondary:hover {
    background: rgba(80, 72, 64, 0.9);
    color: #ffffff;
  }

  /* Edit Mode Key Pads and Target Zone Highlights */
  #hud-container.edit-mode-active .key-pad:not(.dummy-pad) {
    cursor: grab;
    border-style: dashed !important;
    border-color: rgba(212, 163, 89, 0.6) !important;
  }

  #hud-container.edit-mode-active .key-pad:not(.dummy-pad):hover {
    border-color: #d4a359 !important;
    background: rgba(212, 163, 89, 0.15) !important;
    box-shadow: 0 0 8px rgba(212, 163, 89, 0.4);
  }

  .key-pad.drag-over-target {
    background: rgba(212, 163, 89, 0.35) !important;
    border: 2px solid #ffffff !important;
    box-shadow: 0 0 16px #d4a359, inset 0 0 10px #ffffff !important;
    transform: scale(1.08) !important;
    z-index: 99 !important;
  }

  .key-pad.dragging-source {
    opacity: 0.35 !important;
    border: 2px dashed #d4a359 !important;
  }

  @keyframes pulseGlow {
    0% { box-shadow: 0 0 20px #ffffff; border-color: #ffffff; }
    50% { box-shadow: 0 0 24px #d4a359; border-color: #d4a359; }
    100% { box-shadow: none; }
  }

  .key-pad.just-updated-glow {
    animation: pulseGlow 0.6s ease-out;
  }

  /* === UI REFLOW: Keyboard shrinks when drawer is open === */
  #hud-container.edit-mode-active #performance-view {
    /* The drawer is 270px, with 2px border = 272px total. Shrink main content to fit. */
    width: calc(980px - 272px);
    transition: width 0.25s cubic-bezier(0.16, 1, 0.3, 1);
  }

  /* Constrain width only if drawer is open */
  #hud-container.drawer-open .keyboard-grid,
  #hud-container.drawer-open #performance-view {
    max-width: calc(980px - 272px);
    transition: max-width 0.25s cubic-bezier(0.16, 1, 0.3, 1);
  }

  .keyboard-grid {
    gap: 6px;
    flex: 1;
    transition: max-width 0.25s cubic-bezier(0.16, 1, 0.3, 1);
  }

  #hud-container.edit-mode-active .keyboard-row {
    gap: 4px;
  }

  #hud-container.edit-mode-active .key-pad {
    transition: width 0.25s cubic-bezier(0.16, 1, 0.3, 1), 
                height 0.25s cubic-bezier(0.16, 1, 0.3, 1),
                font-size 0.25s cubic-bezier(0.16, 1, 0.3, 1);
  }

  /* Remove height/width overrides in Edit Mode to allow natural sizing */
  #hud-container.edit-mode-active .key-pad {
    transition: font-size 0.25s cubic-bezier(0.16, 1, 0.3, 1);
  }
  #hud-container.edit-mode-active .key-pad .key-code {
    font-size: 8px;
  }
  #hud-container.edit-mode-active .key-pad .key-note {
    font-size: 7.5px;
  }
  #hud-container.edit-mode-active .key-pad[draggable]:not(.dummy-pad) {
    cursor: grab;
  }
  /* Keep Tab/special keys proportionally smaller */
  #hud-container.edit-mode-active .key-pad[style*="width"] {
    width: auto !important;
    max-width: 70px;
  }

  /* === SELECTED KEY STYLE === */

  /* === SELECTED KEY STYLE === */
  .key-pad.selected-key {
    outline: 2.5px solid #5ea2eb !important;
    outline-offset: 1px;
    border-color: #5ea2eb !important;
    box-shadow: 0 0 12px rgba(94, 162, 235, 0.6), inset 0 0 8px rgba(94, 162, 235, 0.2) !important;
    z-index: 100;
  }

  /* === MARQUEE SELECTION BOX === */
  #selection-marquee {
    position: absolute;
    top: 0; left: 0;
    width: 0; height: 0;
    background: rgba(94, 162, 235, 0.12);
    border: 1.5px solid rgba(94, 162, 235, 0.7);
    border-radius: 4px;
    pointer-events: none;
    z-index: 9998;
    display: none;
  }
  #hud-container.edit-mode-active #selection-marquee {
    display: block;
  }

  /* === CONTEXT MENU === */
  #key-context-menu {
    position: absolute;
    z-index: 9999;
    background: rgba(28, 25, 22, 0.98);
    border: 1px solid rgba(212, 163, 89, 0.5);
    border-radius: 6px;
    padding: 4px 0;
    min-width: 180px;
    box-shadow: 0 6px 20px rgba(0,0,0,0.7);
    display: none;
    overflow: hidden;
  }
  #key-context-menu .ctx-item {
    padding: 6px 14px;
    font-size: 11px;
    font-weight: 600;
    color: #e5dec9;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 8px;
    transition: background 0.1s ease;
  }
  #key-context-menu .ctx-item:hover {
    background: rgba(212, 163, 89, 0.2);
    color: #ffffff;
  }
  #key-context-menu .ctx-item .ctx-icon {
    font-size: 13px;
    width: 16px;
    text-align: center;
  }
  #key-context-menu .ctx-separator {
    height: 1px;
    background: rgba(120, 105, 90, 0.3);
    margin: 3px 0;
  }
  #key-context-menu .ctx-item.danger {
    color: #ff8877;
  }
  #key-context-menu .ctx-item.danger:hover {
    background: rgba(200, 80, 70, 0.3);
  }

  /* ── Surface Switcher ── */
  .surface-switcher {
    display: inline-flex;
    background: rgba(20, 18, 16, 0.85);
    border: 1px solid rgba(212, 163, 89, 0.4);
    border-radius: 6px;
    padding: 2px;
    gap: 2px;
    margin-left: 6px;
    -webkit-app-region: no-drag;
  }
  .surface-btn {
    background: transparent;
    border: none;
    color: #a0958a;
    font-size: 11px;
    font-weight: 700;
    padding: 3px 8px;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.15s ease;
  }
  .surface-btn:hover {
    color: #fff;
    background: rgba(212, 163, 89, 0.15);
  }
  .surface-btn.active {
    background: #d4a359;
    color: #141210;
    font-weight: 800;
    box-shadow: 0 0 8px rgba(212, 163, 89, 0.6);
  }

  /* ── Arturia KeyStep 32 Hardware Silhouette & Styles ── */
  #hud-container.keystep-connected,
  #hud-container.nanokey-connected {
    height: 600px !important;
  }
  .keystep-view {
    width: 100%;
    height: 310px;
    min-height: 310px;
    display: flex;
    flex-direction: row;
    gap: 10px;
    background: linear-gradient(180deg, #f7f8fa 0%, #e5e8ed 100%);
    border-radius: 10px;
    padding: 10px 12px;
    border: 1px solid #c4cad3;
    box-shadow: 0 14px 40px rgba(0, 0, 0, 0.65), inset 0 1px 0 rgba(255, 255, 255, 0.95), inset 0 -2px 4px rgba(0, 0, 0, 0.15);
    position: relative;
    user-select: none;
    box-sizing: border-box;
    flex-shrink: 0;
    margin-top: 8px;
    color: #1a1c20;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  }

  /* ── Left Cheek: Hold, Shift, Octave, Touch Strips ── */
  .ks-left-cheek {
    width: 124px;
    min-width: 124px;
    max-width: 124px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    padding-right: 8px;
    border-right: 1.5px solid #d1d5db;
    box-sizing: border-box;
  }

  .ks-cheek-header {
    display: flex;
    flex-direction: column;
    gap: 1px;
    margin-bottom: 4px;
  }
  .ks-brand-title {
    font-size: 13px;
    font-weight: 900;
    letter-spacing: 1.4px;
    color: #1e293b;
    line-height: 1;
  }
  .ks-brand-sub {
    font-size: 6.5px;
    font-weight: 800;
    letter-spacing: 0.6px;
    color: #64748b;
    text-transform: uppercase;
  }

  .ks-cheek-btn-row {
    display: flex;
    gap: 6px;
    align-items: flex-start;
    margin-bottom: 2px;
  }
  .ks-cheek-btn-wrap {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
  }
  .ks-cheek-reset-label {
    font-size: 6.5px;
    font-weight: 700;
    color: #94a3b8;
    text-align: center;
    letter-spacing: 0.5px;
    margin: -1px 0 3px 0;
  }

  .ks-btn {
    width: 100%;
    height: 24px;
    background: linear-gradient(180deg, #ffffff 0%, #e2e8f0 100%);
    border: 1px solid #94a3b8;
    border-bottom: 2px solid #64748b;
    border-radius: 4px;
    color: #1e293b;
    font-size: 8px;
    font-weight: 800;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 4px;
    cursor: pointer;
    box-shadow: 0 1px 3px rgba(0,0,0,0.15), inset 0 1px 0 #ffffff;
    transition: all 0.08s ease;
    user-select: none;
    box-sizing: border-box;
    padding: 0 2px;
  }
  .ks-btn:hover {
    background: #ffffff;
    border-color: #64748b;
  }
  .ks-btn:active {
    transform: translateY(1px);
    border-bottom-width: 1px;
    box-shadow: inset 0 1px 2px rgba(0,0,0,0.2);
  }
  .ks-btn-led {
    width: 4px;
    height: 4px;
    border-radius: 50%;
    background: #cbd5e1;
    flex-shrink: 0;
  }
  .ks-btn.active .ks-btn-led {
    background: #0284c7;
    box-shadow: 0 0 6px #0284c7;
  }
  .ks-btn-sublabel {
    font-size: 6.5px;
    font-weight: 700;
    color: #64748b;
    text-align: center;
    letter-spacing: 0.2px;
    line-height: 1;
  }

  .ks-btn-shift {
    border-color: #0284c7;
    color: #0369a1;
  }
  .ks-btn-shift.active {
    background: linear-gradient(180deg, #e0f2fe 0%, #bae6fd 100%);
    border-color: #0284c7;
    color: #0c4a6e;
  }
  .ks-btn-shift.active .ks-btn-led {
    background: #0284c7;
    box-shadow: 0 0 6px #0284c7;
  }
  .ks-btn-hold.active {
    background: linear-gradient(180deg, #fef3c7 0%, #fde68a 100%);
    border-color: #d97706;
    color: #92400e;
  }
  .ks-btn-hold.active .ks-btn-led {
    background: #d97706;
    box-shadow: 0 0 6px #d97706;
  }

  /* Strips Section */
  .ks-cheek-strips {
    display: flex;
    gap: 8px;
    height: 145px;
    background: #0d0f12;
    padding: 6px;
    border-radius: 6px;
    border: 1px solid #272a30;
    box-shadow: inset 0 2px 5px rgba(0,0,0,0.8);
    box-sizing: border-box;
  }
  .ks-strip-col {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 3px;
  }
  .ks-touch-well {
    flex: 1;
    background: #121418;
    border-radius: 3px;
    border: 1px solid #22262e;
    position: relative;
    cursor: pointer;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    align-items: center;
    padding: 2px 0;
    box-sizing: border-box;
  }
  .ks-strip-arrow {
    font-size: 6px;
    color: #475569;
    user-select: none;
    pointer-events: none;
    line-height: 1;
  }
  .ks-pitch-center-line {
    position: absolute;
    top: 50%;
    left: 0;
    right: 0;
    height: 1px;
    background: rgba(255,255,255,0.2);
  }
  .ks-pitch-thumb {
    position: absolute;
    left: 2px;
    right: 2px;
    top: 50%;
    transform: translateY(-50%);
    height: 6px;
    background: #38bdf8;
    border-radius: 3px;
    box-shadow: 0 0 8px rgba(56, 189, 248, 0.9);
    pointer-events: none;
    transition: top 0.05s ease-out;
  }
  .ks-mod-fill {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: 0%;
    background: linear-gradient(180deg, #38bdf8 0%, rgba(2, 132, 199, 0.4) 100%);
    border-top: 2px solid #38bdf8;
    box-shadow: 0 -2px 8px rgba(56, 189, 248, 0.6);
    pointer-events: none;
    transition: height 0.05s ease-out;
  }
  .ks-strip-footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 7px;
    font-weight: 800;
    color: #94a3b8;
    text-transform: uppercase;
    padding: 0 1px;
  }
  .ks-strip-name {
    color: #cbd5e1;
  }
  .ks-strip-val {
    color: #38bdf8;
    font-family: monospace;
    font-size: 7px;
  }

  /* ── Main Section: Top Bar + Silkscreen + Keybed ── */
  .ks-main-section {
    flex: 1;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    overflow: hidden;
  }

  /* Top Bar */
  .ks-top-bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 10px;
    height: 82px;
    margin-bottom: 2px;
  }

  /* Knobs Inset (Light silver recessed bay) */
  .ks-knobs-inset {
    display: flex;
    align-items: center;
    gap: 12px;
    background: linear-gradient(180deg, #e5e8ed 0%, #d5d9e0 100%);
    padding: 6px 10px;
    border-radius: 6px;
    border: 1px solid #b8bec8;
    box-shadow: inset 0 1px 3px rgba(0,0,0,0.18), 0 1px 0 rgba(255,255,255,0.8);
  }

  /* Seq / Arp Toggle Switch */
  .ks-switch-unit {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1px;
    cursor: pointer;
  }
  .ks-switch-lbl {
    font-size: 7.5px;
    font-weight: 800;
    color: #475569;
    text-transform: uppercase;
    line-height: 1;
  }
  .ks-switch-track {
    width: 14px;
    height: 32px;
    background: #0f1115;
    border-radius: 4px;
    border: 1px solid #334155;
    position: relative;
    padding: 1px;
    box-sizing: border-box;
    display: flex;
    flex-direction: column;
    justify-content: flex-end;
  }
  .ks-switch-thumb {
    width: 10px;
    height: 14px;
    background: linear-gradient(180deg, #94a3b8 0%, #475569 100%);
    border-radius: 2px;
    box-shadow: 0 1px 2px rgba(0,0,0,0.8), inset 0 1px 0 rgba(255,255,255,0.4);
    transition: transform 0.15s ease;
  }
  .ks-switch-track.seq .ks-switch-thumb {
    transform: translateY(-16px);
    background: linear-gradient(180deg, #38bdf8 0%, #0284c7 100%);
  }

  /* Knob Unit */
  .ks-knob-unit {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1px;
    cursor: pointer;
    min-width: 62px;
    position: relative;
  }
  .ks-knob-dial {
    width: 34px;
    height: 34px;
    border-radius: 50%;
    background: linear-gradient(135deg, #333842 0%, #1a1c22 100%);
    border: 2px solid #525a68;
    box-shadow: 0 2px 5px rgba(0,0,0,0.5), inset 0 1px 1px rgba(255,255,255,0.3);
    position: relative;
    transition: transform 0.1s ease-out;
  }
  .ks-knob-notch {
    position: absolute;
    top: 2px;
    left: 50%;
    transform: translateX(-50%);
    width: 2.5px;
    height: 10px;
    background: #38bdf8;
    border-radius: 2px;
    box-shadow: 0 0 5px rgba(56, 189, 248, 0.9);
  }
  .ks-knob-title {
    font-size: 7.5px;
    font-weight: 800;
    letter-spacing: 0.3px;
    color: #334155;
    text-transform: uppercase;
    white-space: nowrap;
    line-height: 1;
    margin-top: 2px;
  }
  .ks-knob-val {
    font-size: 8px;
    font-weight: 700;
    color: #0369a1;
    white-space: nowrap;
    text-align: center;
    max-width: 70px;
    overflow: hidden;
    text-overflow: ellipsis;
    line-height: 1;
  }
  .ks-rate-led {
    width: 5px;
    height: 5px;
    border-radius: 50%;
    background: #94a3b8;
    margin-bottom: 1px;
    transition: background-color 0.05s ease, box-shadow 0.05s ease;
  }
  .ks-rate-led.flash {
    background: #0284c7 !important;
    box-shadow: 0 0 8px #0284c7, 0 0 14px rgba(2, 132, 199, 0.8) !important;
  }

  /* Transport Buttons Section */
  .ks-transport-section {
    display: flex;
    gap: 8px;
    align-items: flex-start;
  }
  .ks-trans-btn-wrap {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
  }
  .ks-btn-trans {
    width: 32px;
    height: 30px;
    font-size: 9px;
  }
  .ks-trans-sub {
    font-size: 6.5px;
    font-weight: 700;
    color: #64748b;
    text-align: center;
    white-space: nowrap;
  }
  .ks-btn-stop.active {
    border-color: #ea580c;
    color: #9a3412;
    background: linear-gradient(180deg, #ffedd5 0%, #fed7aa 100%);
  }
  .ks-btn-stop.active .ks-btn-led {
    background: #ea580c;
    box-shadow: 0 0 6px #ea580c;
  }
  .ks-btn-play.active {
    border-color: #16a34a;
    color: #14532d;
    background: linear-gradient(180deg, #dcfce7 0%, #bbf7d0 100%);
  }
  .ks-btn-play.active .ks-btn-led {
    background: #16a34a;
    box-shadow: 0 0 6px #16a34a;
  }
  .ks-btn-rec.active {
    border-color: #dc2626;
    color: #7f1d1d;
    background: linear-gradient(180deg, #fee2e2 0%, #fecaca 100%);
  }
  .ks-btn-rec.active .ks-btn-led {
    background: #dc2626;
    box-shadow: 0 0 6px #dc2626;
  }

  /* Arturia Brand */
  .ks-arturia-brand {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 2px;
  }
  .ks-arturia-row {
    display: flex;
    align-items: center;
    gap: 5px;
  }
  .ks-arturia-badge {
    background: #1e293b;
    color: #ffffff;
    font-weight: 900;
    font-size: 10px;
    padding: 1px 4px;
    border-radius: 3px;
    line-height: 1;
  }
  .ks-arturia-wordmark {
    font-size: 13px;
    font-weight: 900;
    letter-spacing: 1.5px;
    color: #1e293b;
  }
  .ks-arturia-slogan {
    font-size: 6.5px;
    font-weight: 800;
    letter-spacing: 0.6px;
    color: #64748b;
    text-transform: uppercase;
  }
  .ks-status-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: #22c55e;
    box-shadow: 0 0 8px rgba(34, 197, 94, 0.8);
  }
  .ks-oct-badge {
    background: #1e293b;
    border: 1px solid #334155;
    border-radius: 3px;
    font-size: 8px;
    font-weight: 800;
    color: #f8fafc;
    padding: 1px 6px;
    white-space: nowrap;
    text-align: center;
    margin-top: 2px;
  }

  /* Silkscreen Legend Bar (directly above keys) */
  .ks-silkscreen-bar {
    display: flex;
    align-items: center;
    height: 18px;
    background: #eef1f5;
    border: 1px solid #cbd5e1;
    border-bottom: none;
    border-radius: 4px 4px 0 0;
    padding: 0 4px;
    box-sizing: border-box;
    font-size: 7px;
    font-weight: 800;
    color: #475569;
    text-transform: uppercase;
    user-select: none;
  }
  .ks-silk-group {
    display: flex;
    align-items: center;
    gap: 4px;
    overflow: hidden;
  }
  .ks-silk-header {
    color: #0284c7;
    font-weight: 900;
    white-space: nowrap;
    margin-right: 2px;
  }
  .ks-silk-midi-ch {
    flex: 16;
  }
  .ks-silk-gate {
    flex: 5;
    border-left: 1px solid #cbd5e1;
    padding-left: 4px;
  }
  .ks-silk-swing {
    flex: 11;
    border-left: 1px solid #cbd5e1;
    padding-left: 4px;
  }
  .ks-silk-items-16, .ks-silk-items-gate, .ks-silk-items-swing {
    display: flex;
    width: 100%;
    justify-content: space-around;
    font-size: 6.5px;
    color: #64748b;
  }

  /* Keybed Container */
  .ks-keybed-container {
    height: 190px;
    position: relative;
    display: flex;
    background: #ffffff;
    border: 1px solid #b0b8c4;
    border-radius: 0 0 6px 6px;
    box-shadow: 0 4px 8px rgba(0,0,0,0.15);
    user-select: none;
    overflow: hidden;
    box-sizing: border-box;
  }
  .ks-white-keys {
    display: flex;
    width: 100%;
    height: 100%;
  }
  .ks-key-w {
    flex: 1;
    height: 100%;
    background: linear-gradient(180deg, #ffffff 0%, #f1f4f8 85%, #dce2ea 100%);
    border-right: 1px solid #b0b8c4;
    border-bottom: 3.5px solid #8e98a6;
    border-radius: 0 0 4px 4px;
    box-shadow: inset 0 1px 0 #ffffff;
    display: flex;
    flex-direction: column;
    justify-content: flex-end;
    align-items: center;
    padding-bottom: 6px;
    cursor: pointer;
    box-sizing: border-box;
    position: relative;
    transition: transform 0.05s ease, background 0.08s ease;
  }
  .ks-key-w:last-child {
    border-right: none;
  }
  .ks-key-w:hover {
    background: linear-gradient(180deg, #ffffff 0%, #e2e8f0 100%);
  }
  .ks-key-w.active {
    transform: translateY(3px);
    background: linear-gradient(180deg, #e0f2fe 0%, #bae6fd 60%, #38bdf8 100%) !important;
    border-color: #0284c7 !important;
    border-bottom-width: 1px !important;
    box-shadow: 0 0 12px rgba(56, 189, 248, 0.7), inset 0 1px 2px rgba(255,255,255,0.8) !important;
  }
  .ks-key-w .ks-key-name {
    font-size: 7.5px;
    font-weight: 800;
    color: #64748b;
    pointer-events: none;
  }
  .ks-key-w.active .ks-key-name {
    color: #0369a1 !important;
    font-weight: 900 !important;
  }

  /* Black Keys */
  .ks-black-keys {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 60%;
    pointer-events: none;
  }
  .ks-key-b {
    position: absolute;
    width: 3.4%;
    height: 100%;
    background: linear-gradient(180deg, #2a2d34 0%, #151619 80%, #08090a 100%);
    border: 1px solid #111215;
    border-bottom: 2.5px solid #000000;
    border-radius: 0 0 3px 3px;
    box-shadow: 0 3px 6px rgba(0,0,0,0.6), inset 0 1px 1px rgba(255,255,255,0.25);
    display: flex;
    flex-direction: column;
    justify-content: flex-end;
    align-items: center;
    padding-bottom: 4px;
    cursor: pointer;
    pointer-events: auto;
    box-sizing: border-box;
    z-index: 3;
    transition: transform 0.05s ease, background 0.08s ease;
  }
  .ks-key-b:hover {
    background: linear-gradient(180deg, #373b45 0%, #1c1d22 100%);
  }
  .ks-key-b.active {
    transform: translateY(2.5px);
    background: linear-gradient(180deg, #0369a1 0%, #0284c7 60%, #38bdf8 100%) !important;
    border-color: #38bdf8 !important;
    border-bottom-width: 1px !important;
    box-shadow: 0 0 14px rgba(56, 189, 248, 0.9), inset 0 1px 2px rgba(255,255,255,0.8) !important;
  }
  .ks-key-b .ks-key-name {
    font-size: 6.5px;
    font-weight: 800;
    color: #94a3b8;
    pointer-events: none;
  }
  .ks-key-b.active .ks-key-name {
    color: #ffffff !important;
    font-weight: 900 !important;
  }

  /* Scale Guide Key Highlights */
  .keystep-view.scale-guide-active .ks-key-root .ks-key-name {
    color: #eab308 !important;
    font-weight: 900 !important;
    text-shadow: 0 0 6px rgba(234, 179, 8, 0.6);
  }
  .keystep-view.scale-guide-active .ks-key-w.ks-key-root::before {
    content: '';
    position: absolute;
    top: 4px;
    left: 50%;
    transform: translateX(-50%);
    width: 4px;
    height: 4px;
    border-radius: 50%;
    background: #eab308;
    box-shadow: 0 0 4px #eab308;
    pointer-events: none;
  }
  .keystep-view.scale-guide-active .ks-key-out-of-scale {
    opacity: 0.65;
  }

  /* KeyStep Modal Shift & Performance Styling */
  .ks-cheek-header-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    margin-bottom: 2px;
  }
  .ks-shift-status-pill {
    font-size: 8px;
    font-weight: 800;
    padding: 2px 6px;
    border-radius: 8px;
    background: rgba(255, 255, 255, 0.08);
    color: #94a3b8;
    border: 1px solid rgba(255, 255, 255, 0.15);
    letter-spacing: 0.5px;
    transition: all 0.15s ease;
  }
  .ks-shift-status-pill.active {
    font-weight: 900;
    box-shadow: 0 0 10px currentColor;
  }
  .ks-key-sub {
    font-size: 5.5px;
    font-weight: 800;
    color: #64748b;
    pointer-events: none;
    line-height: 1;
    margin-top: 1px;
    letter-spacing: 0.2px;
  }
  .ks-key-b:hover .ks-key-sub {
    color: #94a3b8;
  }
  .ks-key-b.ks-shift-cutoff {
    border-color: rgba(0, 229, 255, 0.7) !important;
    background: linear-gradient(180deg, #083344 0%, #0e7490 60%, #00e5ff 100%) !important;
    box-shadow: 0 0 12px rgba(0, 229, 255, 0.8), inset 0 1px 1px #ffffff !important;
  }
  .ks-key-b.ks-shift-reverb {
    border-color: rgba(255, 145, 0, 0.7) !important;
    background: linear-gradient(180deg, #451a03 0%, #c2410c 60%, #ff9100 100%) !important;
    box-shadow: 0 0 12px rgba(255, 145, 0, 0.8), inset 0 1px 1px #ffffff !important;
  }
  .ks-key-b.ks-shift-delay {
    border-color: rgba(213, 0, 249, 0.7) !important;
    background: linear-gradient(180deg, #3b0764 0%, #a21caf 60%, #d500f9 100%) !important;
    box-shadow: 0 0 12px rgba(213, 0, 249, 0.8), inset 0 1px 1px #ffffff !important;
  }
  .ks-key-b.ks-shift-release {
    border-color: rgba(0, 230, 118, 0.7) !important;
    background: linear-gradient(180deg, #022c22 0%, #047857 60%, #00e676 100%) !important;
    box-shadow: 0 0 12px rgba(0, 230, 118, 0.8), inset 0 1px 1px #ffffff !important;
  }
  .ks-key-b.ks-shift-volume {
    border-color: rgba(255, 215, 0, 0.7) !important;
    background: linear-gradient(180deg, #422006 0%, #b45309 60%, #ffd700 100%) !important;
    box-shadow: 0 0 12px rgba(255, 215, 0, 0.8), inset 0 1px 1px #ffffff !important;
  }
  .ks-scale-lock-badge {
    font-size: 7.5px;
    font-weight: 800;
    color: #38bdf8;
    background: rgba(56, 189, 248, 0.12);
    border: 1px solid rgba(56, 189, 248, 0.35);
    border-radius: 3px;
    padding: 1px 4px;
    cursor: pointer;
    user-select: none;
    transition: all 0.15s ease;
    margin-right: 6px;
  }
  .ks-scale-lock-badge:hover {
    background: rgba(56, 189, 248, 0.25);
  }
  .ks-scale-lock-badge.off {
    color: #64748b;
    border-color: rgba(100, 116, 139, 0.3);
    background: transparent;
  }
</style>
</head>
<body style="--mod-intensity: 0;">
  <div id="notification-zone">
    <div id="spotlight-card" class="spotlight-card hidden">
      <div id="spotlight-title" class="spotlight-title"></div>
      <div id="spotlight-val" class="spotlight-val"></div>
      <div id="spotlight-sub" class="spotlight-sub"></div>
    </div>
  </div>
  <div id="hud-container">
    <div class="mod-gradient-overlay"></div>
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
      <select id="arp-dir-select" class="badge-small" title="Arp Direction">
        <option value="1">UP</option>
        <option value="2">DOWN</option>
        <option value="3">UP-DN</option>
        <option value="4">DN-UP</option>
        <option value="5">CONV</option>
        <option value="6">DIV</option>
        <option value="7">RND</option>
      </select>
      <select id="arp-rate-select" class="badge-small" title="Arp Time Division">
        <option value="1">4</option>
        <option value="2">2</option>
        <option value="3">1</option>
        <option value="4">1/2</option>
        <option value="5" selected>1/4</option>
        <option value="6">1/8</option>
        <option value="7">1/16</option>
        <option value="8">1/32</option>
        <option value="9">1/64</option>
        <option value="10">4T</option>
        <option value="11">2T</option>
        <option value="12">1T</option>
        <option value="13">1/2T</option>
        <option value="14">1/4T</option>
        <option value="15">1/8T</option>
        <option value="16">1/16T</option>
        <option value="17">1/32T</option>
        <option value="18">1/64T</option>
      </select>
      <select id="arp-quantize-select" class="badge-small" title="Arp Note Change Quantization">
        <option value="None">ARP SYNC: OFF</option>
        <option value="Beat">ARP SYNC: BEAT</option>
        <option value="Bar">ARP SYNC: BAR</option>
      </select>
      <select id="input-quantize-select" class="badge-small" title="Real-Time Input Quantization Grid">
        <option value="Off">QUANT: OFF</option>
        <option value="1/1">QUANT: 1/1</option>
        <option value="1/2">QUANT: 1/2</option>
        <option value="1/4">QUANT: 1/4</option>
        <option value="1/8">QUANT: 1/8</option>
        <option value="1/16">QUANT: 1/16</option>
        <option value="1/32">QUANT: 1/32</option>
      </select>
      <div id="bpm-editor" class="bpm-editor">
        <button id="bpm-down" class="bpm-arrow-btn">&#9662;</button>
        <span id="bpm-value" class="bpm-display">120 BPM</span>
        <button id="bpm-up" class="bpm-arrow-btn">&#9652;</button>
      </div>
      <button id="logic-sync-btn" class="badge-small" title="Sync BPM to active Logic Pro session">SYNC: ON</button>
      <select id="layout-select" class="badge-small" title="Select Keyboard Layout"></select>
      <div id="keystep-badge" class="badge-small" style="display: none; align-items: center; gap: 5px; color: #38bdf8; border-color: rgba(56, 189, 248, 0.4);" title="Arturia KeyStep 32 Connected">
        <span style="width: 6px; height: 6px; border-radius: 50%; background: #38bdf8; box-shadow: 0 0 6px rgba(56, 189, 248, 0.8); display: inline-block;"></span>
        <span>🎹 KeyStep 32</span>
      </div>
      <div id="mod-wheel-widget">
        <div id="mod-wheel-track"><div id="mod-wheel-fill"></div></div>
        <div id="mod-wheel-label">MOD 0</div>
      </div>
      <div id="status-text" class="status-info"></div>
      <div id="mode-indicator" style="color: #ffcc00; font-weight: bold; margin-left: 10px;"></div>
    </div>

    <div class="keyboard-grid" id="performance-view">
      <div id="row-number" class="keyboard-row number"></div>
      <div class="row-with-controls">
        <div id="row-upper" class="keyboard-row upper"></div>
        <div class="row-controls">
          <button id="arp-top-toggle" class="arp-row-toggle">ARP</button>
          <div id="octave-indicator-top" class="compact-oct-badge draggable-octave" data-row="top" title="Drag up/down to shift top row octave">
            <span id="top-oct-text">TOP +1</span>
          </div>
          <div id="vol-indicator-top" class="vol-bar-container" title="Top Row Volume">
            <div id="vol-fill-top" class="vol-bar-fill"></div>
          </div>
        </div>
      </div>
      <div id="row-home" class="keyboard-row home"></div>
      <div class="row-with-controls">
        <div id="row-lower" class="keyboard-row lower"></div>
        <div class="row-controls">
          <button id="arp-bottom-toggle" class="arp-row-toggle active">ARP</button>
          <div id="octave-indicator-bottom" class="compact-oct-badge draggable-octave" data-row="bottom" title="Drag up/down to shift bottom row octave">
            <span id="bottom-oct-text">BOT +0</span>
          </div>
          <div id="vol-indicator-bottom" class="vol-bar-container" title="Bottom Row Volume">
            <div id="vol-fill-bottom" class="vol-bar-fill"></div>
          </div>
        </div>
      </div>
    </div>

    <!-- Arturia KeyStep 32 Authentic Hardware View -->
    <div class="keystep-view" id="keystep-view" style="display: none;">
      <!-- LEFT CHEEK: Model branding, Hold/Shift, Oct-/Oct+, Capacitive Pitch & Mod Strips -->
      <div class="ks-left-cheek ks-control-bay">
        <div class="ks-cheek-header">
          <div class="ks-cheek-header-top">
            <span class="ks-brand-title">KEYSTEP</span>
            <div class="ks-shift-status-pill" id="ks-shift-status-pill" title="Active Black-Key Control Target">MOD · CC1</div>
          </div>
          <span class="ks-brand-sub">KeyStep 32 · MODAL SYNTH MATRIX</span>
        </div>

        <!-- Row 1: Hold (Chord) & Shift -->
        <div class="ks-cheek-btn-row">
          <div class="ks-cheek-btn-wrap">
            <button class="ks-btn ks-btn-hold" id="ks-btn-hold" title="Hold / Sustain">
              <span class="ks-btn-led"></span>HOLD
            </button>
            <span class="ks-btn-sublabel">Chord</span>
          </div>
          <div class="ks-cheek-btn-wrap">
            <button class="ks-btn ks-btn-shift" id="ks-btn-shift" title="Shift Function Modifier">
              <span class="ks-btn-led"></span>SHIFT
            </button>
          </div>
        </div>

        <!-- Row 2: Oct - (Transpose) & Oct + (Kbd Play) -->
        <div class="ks-cheek-btn-row">
          <div class="ks-cheek-btn-wrap">
            <button class="ks-btn" id="ks-btn-oct-down" title="Octave Down">OCT -</button>
            <span class="ks-btn-sublabel">Transpose</span>
          </div>
          <div class="ks-cheek-btn-wrap">
            <button class="ks-btn" id="ks-btn-oct-up" title="Octave Up">OCT +</button>
            <span class="ks-btn-sublabel">Kbd Play</span>
          </div>
        </div>
        <div class="ks-cheek-reset-label">- Reset -</div>

        <!-- Capacitive Touch Strips: Pitch Bend & Mod Wheel -->
        <div class="ks-cheek-strips">
          <div class="ks-strip-col">
            <div class="ks-touch-well" id="ks-pitch-strip" title="Pitch Bend Touch Strip">
              <span class="ks-strip-arrow">▲</span>
              <div class="ks-pitch-center-line"></div>
              <div class="ks-pitch-thumb" id="ks-pitch-thumb"></div>
              <span class="ks-strip-arrow">▼</span>
            </div>
            <div class="ks-strip-footer">
              <span class="ks-strip-name">Pitch</span>
              <span class="ks-strip-val" id="ks-pitch-val">±0</span>
            </div>
          </div>
          <div class="ks-strip-col">
            <div class="ks-touch-well" id="ks-mod-strip" title="Modulation Touch Strip (CC #1)">
              <span class="ks-strip-arrow">▲</span>
              <div class="ks-mod-fill" id="ks-mod-fill"></div>
              <span class="ks-strip-arrow">▼</span>
            </div>
            <div class="ks-strip-footer">
              <span class="ks-strip-name" id="ks-mod-name">Mod</span>
              <span class="ks-strip-val" id="ks-mod-val">0</span>
            </div>
          </div>
        </div>
      </div>

      <!-- MAIN SECTION: Top Control Bar + Silkscreen Annotations + 32-Key Bed -->
      <div class="ks-main-section ks-keybed-bay">
        <!-- Top Bar: Recessed Knobs Inset + Transport Buttons + Arturia Brand -->
        <div class="ks-top-bar">
          <!-- Silver Recessed Knobs Inset -->
          <div class="ks-knobs-inset">
            <!-- Seq / Arp Toggle Switch -->
            <div class="ks-switch-unit" id="ks-switch-seq-arp" title="Click to toggle Seq / Arp Mode">
              <span class="ks-switch-lbl">Seq</span>
              <div class="ks-switch-track" id="ks-switch-track">
                <div class="ks-switch-thumb"></div>
              </div>
              <span class="ks-switch-lbl">Arp</span>
            </div>

            <!-- Knob 1: Seq / Arp Mode (Settings 1-8) -->
            <div class="ks-knob-unit" id="ks-knob-mode-unit" title="Seq / Arp Mode (8 Positions, CC 102 & CC 105)">
              <div class="ks-knob-dial" id="ks-knob-mode"><div class="ks-knob-notch"></div></div>
              <span class="ks-knob-title">Seq / Arp Mode</span>
              <span class="ks-knob-val" id="ks-knob-val-mode">1: Up</span>
            </div>

            <!-- Knob 2: Time Div (1/4 -> 1/32, then 1/4T -> 1/32T) -->
            <div class="ks-knob-unit" id="ks-knob-div-unit" title="Time Div (8 Positions, CC 103 & CC 106)">
              <div class="ks-knob-dial" id="ks-knob-div"><div class="ks-knob-notch"></div></div>
              <span class="ks-knob-title">Time Div</span>
              <span class="ks-knob-val" id="ks-knob-val-div">1/16</span>
            </div>

            <!-- Knob 3: Rate / Logic Learn (single CC 107) -->
            <div class="ks-knob-unit" id="ks-knob-rate-unit" title="Rate / Logic Controller Learn CC #107">
              <div class="ks-rate-led" id="ks-rate-led" title="Tempo Pulse"></div>
              <div class="ks-knob-dial" id="ks-knob-rate"><div class="ks-knob-notch"></div></div>
              <span class="ks-knob-title">Rate / CC107</span>
              <span class="ks-knob-val" id="ks-knob-val-rate">Vol 50% (120 BPM)</span>
            </div>
          </div>

          <!-- Transport Buttons -->
          <div class="ks-transport-section">
            <div class="ks-trans-btn-wrap">
              <button class="ks-btn ks-btn-trans ks-btn-tap" id="ks-btn-tap" title="Tap Tempo">
                <span class="ks-btn-led"></span>TAP
              </button>
              <span class="ks-trans-sub">Rest / Tie</span>
            </div>
            <div class="ks-trans-btn-wrap">
              <button class="ks-btn ks-btn-trans ks-btn-rec" id="ks-btn-rec" title="Record">
                <span class="ks-btn-led"></span>●
              </button>
              <span class="ks-trans-sub">Append</span>
            </div>
            <div class="ks-trans-btn-wrap">
              <button class="ks-btn ks-btn-trans ks-btn-stop active" id="ks-btn-stop" title="Stop">
                <span class="ks-btn-led"></span>■
              </button>
              <span class="ks-trans-sub">Clear Last</span>
            </div>
            <div class="ks-trans-btn-wrap">
              <button class="ks-btn ks-btn-trans ks-btn-play" id="ks-btn-play" title="Play / Pause">
                <span class="ks-btn-led"></span>▶/||
              </button>
              <span class="ks-trans-sub">Restart</span>
            </div>
          </div>

          <!-- Arturia Brand -->
          <div class="ks-arturia-brand">
            <div class="ks-arturia-row">
              <span class="ks-arturia-badge">A</span>
              <span class="ks-arturia-wordmark">ARTURIA</span>
              <div class="ks-status-dot" id="ks-status-dot" title="KeyStep 32 Connected"></div>
            </div>
            <span class="ks-arturia-slogan">YOUR EXPERIENCE · YOUR SOUND</span>
            <div style="display: flex; align-items: center; justify-content: flex-end; margin-top: 2px;">
              <div class="ks-scale-lock-badge" id="ks-scale-lock-badge" title="KeyStep White-Key Harmonic Transposer Lock (Click to toggle)">SCALE LOCK: ON</div>
              <div class="ks-oct-badge" id="ks-oct-val">OCT 0</div>
            </div>
          </div>
        </div>

        <!-- Silkscreen Legend Bar (directly above the 32 keys) -->
        <div class="ks-silkscreen-bar">
          <div class="ks-silk-group ks-silk-midi-ch">
            <span class="ks-silk-header">Keyboard MIDI CH</span>
            <div class="ks-silk-items-16">
              <span>1</span><span>2</span><span>3</span><span>4</span><span>5</span><span>6</span><span>7</span><span>8</span>
              <span>9</span><span>10</span><span>11</span><span>12</span><span>13</span><span>14</span><span>15</span><span>16</span>
            </div>
          </div>
          <div class="ks-silk-group ks-silk-gate">
            <span class="ks-silk-header">Gate</span>
            <div class="ks-silk-items-gate">
              <span>10%</span><span>25%</span><span>50%</span><span>75%</span><span>90%</span>
            </div>
          </div>
          <div class="ks-silk-group ks-silk-swing">
            <span class="ks-silk-header">Swing</span>
            <div class="ks-silk-items-swing">
              <span>Off</span><span>53%</span><span>55%</span><span>57%</span><span>59%</span><span>61%</span><span>64%</span><span>67%</span><span>70%</span><span>73%</span><span>75%</span>
            </div>
          </div>
        </div>

        <!-- 32-Key Slimkey Keybed (Starts on F, ends on C) -->
        <div class="ks-keybed-container">
          <!-- 19 White Keys -->
          <div class="ks-white-keys">
            <div class="ks-key-w" id="ks-key-41" data-note="41"><span class="ks-key-name">F</span></div>
            <div class="ks-key-w" id="ks-key-43" data-note="43"><span class="ks-key-name">G</span></div>
            <div class="ks-key-w" id="ks-key-45" data-note="45"><span class="ks-key-name">A</span></div>
            <div class="ks-key-w" id="ks-key-47" data-note="47"><span class="ks-key-name">B</span></div>
            <div class="ks-key-w" id="ks-key-48" data-note="48"><span class="ks-key-name">C</span></div>
            <div class="ks-key-w" id="ks-key-50" data-note="50"><span class="ks-key-name">D</span></div>
            <div class="ks-key-w" id="ks-key-52" data-note="52"><span class="ks-key-name">E</span></div>
            <div class="ks-key-w" id="ks-key-53" data-note="53"><span class="ks-key-name">F</span></div>
            <div class="ks-key-w" id="ks-key-55" data-note="55"><span class="ks-key-name">G</span></div>
            <div class="ks-key-w" id="ks-key-57" data-note="57"><span class="ks-key-name">A</span></div>
            <div class="ks-key-w" id="ks-key-59" data-note="59"><span class="ks-key-name">B</span></div>
            <div class="ks-key-w" id="ks-key-60" data-note="60"><span class="ks-key-name">C</span></div>
            <div class="ks-key-w" id="ks-key-62" data-note="62"><span class="ks-key-name">D</span></div>
            <div class="ks-key-w" id="ks-key-64" data-note="64"><span class="ks-key-name">E</span></div>
            <div class="ks-key-w" id="ks-key-65" data-note="65"><span class="ks-key-name">F</span></div>
            <div class="ks-key-w" id="ks-key-67" data-note="67"><span class="ks-key-name">G</span></div>
            <div class="ks-key-w" id="ks-key-69" data-note="69"><span class="ks-key-name">A</span></div>
            <div class="ks-key-w" id="ks-key-71" data-note="71"><span class="ks-key-name">B</span></div>
            <div class="ks-key-w" id="ks-key-72" data-note="72"><span class="ks-key-name">C</span></div>
          </div>

          <!-- 13 Black Keys -->
          <div class="ks-black-keys">
            <div class="ks-key-b" id="ks-key-42" data-note="42" data-shift="delay" style="left: calc((1 * 100% / 19) - 1.7%);"><span class="ks-key-name">F#</span><span class="ks-key-sub">DLY</span></div>
            <div class="ks-key-b" id="ks-key-44" data-note="44" data-shift="release" style="left: calc((2 * 100% / 19) - 1.7%);"><span class="ks-key-name">G#</span><span class="ks-key-sub">REL</span></div>
            <div class="ks-key-b" id="ks-key-46" data-note="46" data-shift="volume" style="left: calc((3 * 100% / 19) - 1.7%);"><span class="ks-key-name">A#</span><span class="ks-key-sub">VOL</span></div>

            <div class="ks-key-b" id="ks-key-49" data-note="49" data-shift="cutoff" style="left: calc((5 * 100% / 19) - 1.7%);"><span class="ks-key-name">C#</span><span class="ks-key-sub">CUT</span></div>
            <div class="ks-key-b" id="ks-key-51" data-note="51" data-shift="reverb" style="left: calc((6 * 100% / 19) - 1.7%);"><span class="ks-key-name">D#</span><span class="ks-key-sub">REV</span></div>

            <div class="ks-key-b" id="ks-key-54" data-note="54" data-shift="delay" style="left: calc((8 * 100% / 19) - 1.7%);"><span class="ks-key-name">F#</span><span class="ks-key-sub">DLY</span></div>
            <div class="ks-key-b" id="ks-key-56" data-note="56" data-shift="release" style="left: calc((9 * 100% / 19) - 1.7%);"><span class="ks-key-name">G#</span><span class="ks-key-sub">REL</span></div>
            <div class="ks-key-b" id="ks-key-58" data-note="58" data-shift="volume" style="left: calc((10 * 100% / 19) - 1.7%);"><span class="ks-key-name">A#</span><span class="ks-key-sub">VOL</span></div>

            <div class="ks-key-b" id="ks-key-61" data-note="61" data-shift="cutoff" style="left: calc((12 * 100% / 19) - 1.7%);"><span class="ks-key-name">C#</span><span class="ks-key-sub">CUT</span></div>
            <div class="ks-key-b" id="ks-key-63" data-note="63" data-shift="reverb" style="left: calc((13 * 100% / 19) - 1.7%);"><span class="ks-key-name">D#</span><span class="ks-key-sub">REV</span></div>

            <div class="ks-key-b" id="ks-key-66" data-note="66" data-shift="delay" style="left: calc((15 * 100% / 19) - 1.7%);"><span class="ks-key-name">F#</span><span class="ks-key-sub">DLY</span></div>
            <div class="ks-key-b" id="ks-key-68" data-note="68" data-shift="release" style="left: calc((16 * 100% / 19) - 1.7%);"><span class="ks-key-name">G#</span><span class="ks-key-sub">REL</span></div>
            <div class="ks-key-b" id="ks-key-70" data-note="70" data-shift="volume" style="left: calc((17 * 100% / 19) - 1.7%);"><span class="ks-key-name">A#</span><span class="ks-key-sub">VOL</span></div>
          </div>
        </div>
      </div>
    </div>
  </div> <!-- #hud-container -->

<script>
  // Anti-Suspension Web Audio Sentinel: Keeps WebKit ProcessThrottler active as Foreground Media
  try {
    const AudioCtx = window.AudioContext || window.webkitAudioContext;
    if (AudioCtx) {
      const actx = new AudioCtx();
      const osc = actx.createOscillator();
      const gain = actx.createGain();
      gain.gain.value = 0.00001; // Silent
      osc.connect(gain);
      gain.connect(actx.destination);
      osc.start();
      if (actx.state === 'suspended') {
        document.addEventListener('click', () => actx.resume(), { once: true });
        document.addEventListener('keydown', () => actx.resume(), { once: true });
      }
    }
  } catch (e) {
    console.warn('AudioContext anti-suspension init:', e);
  }

  let renderCount = 0;
  function getBuiltInKey(code) {
    if (typeof LAYOUT_DATA === 'undefined') return null;
    for (const row in LAYOUT_DATA) {
      const keys = LAYOUT_DATA[row];
      for (let i = 0; i < keys.length; i++) {
        if (keys[i].code == code) return keys[i];
      }
    }
    return null;
  }
  const LAYOUT_DATA = {
    number: [
      { code: 50, keyLabel: "`", isControl: true, noteLabel: "Arp" },
      { code: 18, keyLabel: "1", isControl: true, noteLabel: "Trk 1: Bass", extraClass: "ctrl-track" },
      { code: 19, keyLabel: "2", isControl: true, noteLabel: "Trk 2: Chords", extraClass: "ctrl-track" },
      { code: 20, keyLabel: "3", isControl: true, noteLabel: "Trk 3: Lead", extraClass: "ctrl-track" },
      { code: 21, keyLabel: "4", isControl: true, noteLabel: "Trk 4: Arp", extraClass: "ctrl-track" },
      { code: 23, keyLabel: "5", isControl: true, noteLabel: "Rate -", shiftLabel: "BotOct -", extraClass: "ctrl-oct" },
      { code: 22, keyLabel: "6", isControl: true, noteLabel: "Rate +", shiftLabel: "BotOct +", extraClass: "ctrl-oct" },
      { code: 26, keyLabel: "7", isControl: true, noteLabel: "Gate -" },
      { code: 28, keyLabel: "8", isControl: true, noteLabel: "Gate +" },
      { code: 25, keyLabel: "9", isControl: true, noteLabel: "Rel -" },
      { code: 29, keyLabel: "0", isControl: true, noteLabel: "Rel +" },
      { code: 27, keyLabel: "-", isControl: true, noteLabel: "BPM -" },
      { code: 24, keyLabel: "=", isControl: true, noteLabel: "BPM +" }
    ],
    upper: [
      { code: 48, keyLabel: "Tab", isControl: true, noteLabel: "Sustain", width: 85 },
      { code: 12, keyLabel: "Q" }, { code: 13, keyLabel: "W" }, { code: 14, keyLabel: "E" },
      { code: 15, keyLabel: "R" }, { code: 17, keyLabel: "T" }, { code: 16, keyLabel: "Y" },
      { code: 32, keyLabel: "U" }, { code: 34, keyLabel: "I" }, { code: 31, keyLabel: "O" }, { code: 35, keyLabel: "P" },
      { code: 33, keyLabel: "[" }, { code: 30, keyLabel: "]" }
    ],
    home: [
      { code: 57, keyLabel: "Caps", isDummy: true, width: 95 },
      { code: 0,  keyLabel: "A", isControl: true, noteLabel: "Arp" },
      { code: 1,  keyLabel: "S", isControl: true, noteLabel: "Random" },
      { code: 2,  keyLabel: "D", isControl: true, noteLabel: "Oct -" },
      { code: 3,  keyLabel: "F", isControl: true, noteLabel: "Oct +" },
      { code: 5,  keyLabel: "G", isControl: true, noteLabel: "Mode -" },
      { code: 4,  keyLabel: "H", isControl: true, noteLabel: "Root -" },
      { code: 38, keyLabel: "J", isControl: true, noteLabel: "Trnsp -" },
      { code: 40, keyLabel: "K", isControl: true, noteLabel: "Trnsp +" },
      { code: 37, keyLabel: "L", isControl: true, noteLabel: "Root +" },
      { code: 41, keyLabel: ";", isControl: true, noteLabel: "Mode +" },
      { code: 39, keyLabel: "\'", isControl: true, noteLabel: "Chord" }
    ],
    lower: [
      { code: 56, keyLabel: "Shift", isDummy: true, width: 120 },
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

  // ===== KEY SELECTION, MULTI-SELECT, DELETE, CONTEXT MENU =====
  let selectedKeys = new Set();
  let isMarqueeSelecting = false;
  let marqueeStartX = 0, marqueeStartY = 0;

  function clearSelection() {
    document.querySelectorAll('.key-pad.selected-key').forEach(el => el.classList.remove('selected-key'));
    selectedKeys.clear();
  }

  function selectKey(code, addToSet) {
    const el = document.getElementById('key-' + code);
    if (!el || el.classList.contains('dummy-pad')) return;
    if (!addToSet) clearSelection();
    if (selectedKeys.has(code)) {
      el.classList.remove('selected-key');
      selectedKeys.delete(code);
    } else {
      el.classList.add('selected-key');
      selectedKeys.add(code);
    }
  }

  function selectKeysInRange(fromCode, toCode) {
    // Build ordered key list from layout
    const allKeys = [];
    ['number', 'upper', 'home', 'lower'].forEach(rowName => {
      const row = LAYOUT_DATA[rowName];
      if (row) row.forEach(k => { if (!k.isDummy) allKeys.push(k.code); });
    });
    const idxA = allKeys.indexOf(fromCode);
    const idxB = allKeys.indexOf(toCode);
    if (idxA === -1 || idxB === -1) return;
    const start = Math.min(idxA, idxB);
    const end = Math.max(idxA, idxB);
    clearSelection();
    for (let i = start; i <= end; i++) {
      const code = allKeys[i];
      const el = document.getElementById('key-' + code);
      if (el && !el.classList.contains('dummy-pad')) {
        el.classList.add('selected-key');
        selectedKeys.add(code);
      }
    }
  }

  function revertSelectedKeysToNotes() {
    const codesToRevert = Array.from(selectedKeys);
    if (codesToRevert.length === 0) return;
    recordSnapshot('Revert ' + codesToRevert.length + ' keys');

    codesToRevert.forEach(code => {
      if (currentWorkingLayout[code]) {
        delete currentWorkingLayout[code];
        if (Object.keys(currentWorkingLayout[code] || {}).length === 0) {
          delete currentWorkingLayout[code];
        }
      }
      const pad = document.getElementById('key-' + code);
      if (pad) {
        pad.className = 'key-pad';
        const noteEl = pad.querySelector(':scope > .key-note');
        if (noteEl) noteEl.textContent = '';
        // Clear vertical split halves
        const halfTopNote = pad.querySelector('.key-half-top .key-note');
        if (halfTopNote) halfTopNote.textContent = '';
        const halfBottomNote = pad.querySelector('.key-half-bottom .key-note');
        if (halfBottomNote) halfBottomNote.textContent = '';
        pad.classList.remove('selected-key');
      }
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
        window.webkit.messageHandlers.midiControllerUC.postMessage({
          type: 'updateKeyMapping',
          code: code,
          binding: { action: 'none' }
        });
      }
    });

    showSpotlight({
      title: "KEYS REVERTED",
      val: codesToRevert.length + " key" + (codesToRevert.length > 1 ? "s" : "") + " reverted to notes",
      sub: "Actions cleared"
    });
    selectedKeys.clear();
    setHasUnsavedChanges(true);
  }

  function showContextMenu(e) {
    e.preventDefault();
    e.stopPropagation();
    const menu = document.getElementById('key-context-menu');
    if (!menu) return;
    
    // Position near the mouse, clamped to container
    const container = document.getElementById('hud-container');
    const cr = container.getBoundingClientRect();
    let mx = e.clientX - cr.left;
    let my = e.clientY - cr.top;
    const mw = 180;
    const mh = menu.scrollHeight || 100;
    if (mx + mw > cr.width) mx = cr.width - mw - 8;
    if (my + mh > cr.height) my = cr.height - mh - 8;
    if (mx < 8) mx = 8;
    if (my < 8) my = 8;
    
    menu.style.left = mx + 'px';
    menu.style.top = my + 'px';
    menu.style.display = 'block';
  }

  function hideContextMenu() {
    const menu = document.getElementById('key-context-menu');
    if (menu) menu.style.display = 'none';
  }

  // ===== CALL HAMMERSPOON HELPER =====
  window.callHammerspoon = function(action, data) {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
      if (typeof action === 'string') {
        const muteMatch = action.match(/^trkMute(\d)$/);
        if (muteMatch) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'trkMute', trackId: parseInt(muteMatch[1], 10) });
          return;
        }
        const soloMatch = action.match(/^trkSolo(\d)$/);
        if (soloMatch) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'trkSolo', trackId: parseInt(soloMatch[1], 10) });
          return;
        }
        const selMatch = action.match(/^trkSelect(\d)$/);
        if (selMatch) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'selectTrack', trackId: parseInt(selMatch[1], 10) });
          return;
        }
      }
      window.webkit.messageHandlers.midiControllerUC.postMessage(data || { type: action });
    }
  };

  // ===== TEXT INPUT FOCUS FIX =====
  function postTextInputFocus(focused) {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
      window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'textInputFocus', focused: focused });
    }
  }

  // ===== END KEY SELECTION VARS =====

  const TRACK_ROLES = {
    1: { letter: 'B', name: 'Bass' },
    2: { letter: 'C', name: 'Chords' },
    3: { letter: 'L', name: 'Lead' },
    4: { letter: 'A', name: 'Arp' }
  };

  function initGrid(layout) {
    try {
      const l = (layout && (layout.number || layout.upper || layout.home || layout.lower)) ? layout : LAYOUT_DATA;
      ['number', 'upper', 'home', 'lower'].forEach(rowName => {
        const rowEl = document.getElementById('row-' + rowName);
        if (!rowEl) return;
        // Render Shift Row + Normal Row
        if (l[rowName] && Array.isArray(l[rowName]) && l[rowName].length > 0) {
          rowEl.textContent = '';
          
          // Render Shift Row
          if (isEditMode) {
            const shiftRowEl = document.createElement('div');
            shiftRowEl.className = 'keyboard-row shift-row';
            l[rowName].forEach(k => {
              const pad = document.createElement('div');
              pad.id = 'key-' + k.code + '-shift';
              const isTrackCard = k.code >= 18 && k.code <= 21;
              pad.className = 'key-pad shift-pad ' + (k.isControl ? 'control-pad' : '') + (isTrackCard ? ' track-card' : '') + (k.isDummy ? ' dummy-pad' : '');
              if (k.width) pad.style.width = k.width + 'px';
              pad.setAttribute('data-is-shift', 'true');
              pad.setAttribute('draggable', k.isDummy ? 'false' : 'true');

              const codeSpan = document.createElement('span');
              codeSpan.className = 'key-code';
              codeSpan.textContent = '⇧' + k.keyLabel;

              const iconSpan = document.createElement('div');
              iconSpan.className = 'key-row-icon stacked-rows-icon';
              iconSpan.innerHTML = '<div class="rect top"></div><div class="rect bottom"></div>';

              const builtIn = typeof getBuiltInKey !== 'undefined' ? getBuiltInKey(k.code) || {} : {};
              const noteSpan = document.createElement('span');
              noteSpan.className = 'key-note';
              noteSpan.textContent = k.shiftLabel || builtIn.shiftLabel || builtIn.noteLabel || k.noteLabel || '';

              const dotSpan = document.createElement('span');
              dotSpan.className = 'latch-dot';

              pad.appendChild(iconSpan);
              pad.appendChild(codeSpan);
              pad.appendChild(noteSpan);
              pad.appendChild(dotSpan);
              if (k.code >= 18 && k.code <= 21) {
                const trkNum = k.code - 17;
                const role = TRACK_ROLES[trkNum];
                const roleBadge = document.createElement('span');
                roleBadge.className = 'trk-role';
                roleBadge.textContent = role.name.toUpperCase();
                roleBadge.title = role.name;
                pad.appendChild(roleBadge);
                const msBadges = document.createElement('div');
                msBadges.className = 'trk-ms-badges';
                const mBadge = document.createElement('span');
                mBadge.className = 'trk-badge trk-badge-m';
                mBadge.dataset.trk = trkNum;
                mBadge.textContent = 'M';
                mBadge.title = 'Mute Track ' + trkNum;
                mBadge.addEventListener('mousedown', (e) => {
                  e.stopPropagation();
                  e.preventDefault();
                  if (window.callHammerspoon) window.callHammerspoon('trkMute' + trkNum);
                });
                const sBadge = document.createElement('span');
                sBadge.className = 'trk-badge trk-badge-s';
                sBadge.dataset.trk = trkNum;
                sBadge.textContent = 'S';
                sBadge.title = 'Solo Track ' + trkNum;
                sBadge.addEventListener('mousedown', (e) => {
                  e.stopPropagation();
                  e.preventDefault();
                  if (window.callHammerspoon) window.callHammerspoon('trkSolo' + trkNum);
                });
                msBadges.appendChild(mBadge);
                msBadges.appendChild(sBadge);
                pad.appendChild(msBadges);

                const modeTags = document.createElement('div');
                modeTags.className = 'trk-mode-tags';
                const susTag = document.createElement('span');
                susTag.className = 'trk-tag-sus';
                susTag.textContent = 'S';
                susTag.title = 'Sustain active';
                const chdTag = document.createElement('span');
                chdTag.className = 'trk-tag-chd';
                chdTag.textContent = 'C';
                chdTag.title = 'Chord mode active';
                modeTags.appendChild(susTag);
                modeTags.appendChild(chdTag);
                pad.appendChild(modeTags);

                const waveDiv = document.createElement('div');
                waveDiv.className = 'trk-waveform';
                waveDiv.innerHTML = '<span class="wbar b1"></span><span class="wbar b2"></span><span class="wbar b3"></span><span class="wbar b4"></span><span class="wbar b5"></span>';
                pad.appendChild(waveDiv);
              }
              shiftRowEl.appendChild(pad);
            });
            rowEl.appendChild(shiftRowEl);
          }

          // Render Normal Row
          const normalRowEl = document.createElement('div');
          normalRowEl.className = 'keyboard-row';
          l[rowName].forEach(k => {
            const pad = document.createElement('div');
            pad.id = 'key-' + k.code;
            const isTrackCard = k.code >= 18 && k.code <= 21;
            pad.className = 'key-pad ' + (k.isControl ? 'control-pad ' : '') + (isTrackCard ? 'track-card ' : '') + (k.extraClass ? k.extraClass + ' ' : '') + (k.isDummy ? ' dummy-pad' : '');
            if (k.width) {
              pad.style.width = k.width + 'px';
            }

            if (isEditMode && !k.isDummy) {
              pad.setAttribute('draggable', 'true');
            } else {
              pad.setAttribute('draggable', 'false');
            }

            const codeSpan = document.createElement('span');
            codeSpan.className = 'key-code';
            codeSpan.textContent = k.keyLabel;

            const iconSpan = document.createElement('div');
            iconSpan.className = 'key-row-icon stacked-rows-icon';
            iconSpan.innerHTML = '<div class="rect top"></div><div class="rect bottom"></div>';

            const noteSpan = document.createElement('span');
            noteSpan.className = 'key-note';
            noteSpan.textContent = k.noteLabel || '';

            const dotSpan = document.createElement('span');
            dotSpan.className = 'latch-dot';

            pad.appendChild(iconSpan);
            pad.appendChild(codeSpan);
            pad.appendChild(noteSpan);
            pad.appendChild(dotSpan);
            if (k.code >= 18 && k.code <= 21) {
              const trkNum = k.code - 17;
              const role = TRACK_ROLES[trkNum];
              const roleBadge = document.createElement('span');
              roleBadge.className = 'trk-role';
              roleBadge.textContent = role.name.toUpperCase();
              roleBadge.title = role.name;
              pad.appendChild(roleBadge);
              const msBadges = document.createElement('div');
              msBadges.className = 'trk-ms-badges';
              const mBadge = document.createElement('span');
              mBadge.className = 'trk-badge trk-badge-m';
              mBadge.dataset.trk = trkNum;
              mBadge.textContent = 'M';
              mBadge.title = 'Mute Track ' + trkNum;
              mBadge.addEventListener('mousedown', (e) => {
                e.stopPropagation();
                e.preventDefault();
                if (window.callHammerspoon) window.callHammerspoon('trkMute' + trkNum);
              });
              const sBadge = document.createElement('span');
              sBadge.className = 'trk-badge trk-badge-s';
              sBadge.dataset.trk = trkNum;
              sBadge.textContent = 'S';
              sBadge.title = 'Solo Track ' + trkNum;
              sBadge.addEventListener('mousedown', (e) => {
                e.stopPropagation();
                e.preventDefault();
                if (window.callHammerspoon) window.callHammerspoon('trkSolo' + trkNum);
              });
              msBadges.appendChild(mBadge);
              msBadges.appendChild(sBadge);
              pad.appendChild(msBadges);

              const modeTags = document.createElement('div');
              modeTags.className = 'trk-mode-tags';
              const susTag = document.createElement('span');
              susTag.className = 'trk-tag-sus';
              susTag.textContent = 'S';
              susTag.title = 'Sustain active';
              const chdTag = document.createElement('span');
              chdTag.className = 'trk-tag-chd';
              chdTag.textContent = 'C';
              chdTag.title = 'Chord mode active';
              modeTags.appendChild(susTag);
              modeTags.appendChild(chdTag);
              pad.appendChild(modeTags);

              const waveDiv = document.createElement('div');
              waveDiv.className = 'trk-waveform';
              waveDiv.innerHTML = '<span class="wbar b1"></span><span class="wbar b2"></span><span class="wbar b3"></span><span class="wbar b4"></span><span class="wbar b5"></span>';
              pad.appendChild(waveDiv);
            }



          pad.addEventListener('mousedown', (e) => {
            if (isEditMode) {
              // Key selection in edit mode
              try { window.getSelection().removeAllRanges(); } catch(_eSel) {}
              if (e.shiftKey && e.button === 0) {
                // Shift-click range select
                e.preventDefault();
                e.stopPropagation();
                const lastSelected = selectedKeys.size > 0 ? Array.from(selectedKeys)[selectedKeys.size - 1] : null;
                if (lastSelected !== null && lastSelected !== k.code) {
                  selectKeysInRange(lastSelected, k.code);
                } else {
                  selectKey(k.code, false);
                }
                return;
              }
              if (e.button === 0) {
                // Plain click or Ctrl/Cmd-click for toggle
                selectKey(k.code, e.metaKey || e.ctrlKey);
                // Focus container so subsequent Delete/Backspace works
                const hudContainer = document.getElementById('hud-container');
                if (hudContainer) hudContainer.focus();
              }
              return;
            }
            e.stopPropagation();
            try { window.getSelection().removeAllRanges(); } catch(_eSel2) {}
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

          // Drag & Drop handlers for layout editor
          pad.addEventListener('dragstart', (e) => {
            if (!isEditMode || k.isDummy) {
              e.preventDefault();
              return;
            }
            e.stopPropagation();
            const currentActionName = noteSpan.textContent || '';
            const payload = {
              type: 'keyslot',
              code: k.code,
              keyLabel: k.keyLabel,
              rowName: rowName,
              actionName: currentActionName,
              isShift: pad.classList.contains('shift-pad')
            };
            e.dataTransfer.setData('application/json', JSON.stringify(payload));
            e.dataTransfer.setData('text/plain', JSON.stringify(payload));
            draggedItemData = payload;
            pad.classList.add('dragging-source');
          });

          pad.addEventListener('dragend', () => {
            pad.classList.remove('dragging-source');
            draggedItemData = null;
            document.querySelectorAll('.key-pad.drag-over-target').forEach(el => el.classList.remove('drag-over-target'));
          });

          pad.addEventListener('dragover', (e) => {
            if (!isEditMode || k.isDummy) return;
            e.preventDefault();
            e.dataTransfer.dropEffect = 'move';
            pad.classList.add('drag-over-target');
          });

          pad.addEventListener('dragleave', () => {
            pad.classList.remove('drag-over-target');
          });

          pad.addEventListener('drop', (e) => {
            if (!isEditMode || k.isDummy) return;
            e.preventDefault();
            e.stopPropagation();
            pad.classList.remove('drag-over-target');

            let rawData = e.dataTransfer.getData('application/json') || e.dataTransfer.getData('text/plain');
            let data = null;
            if (rawData) {
              try { data = JSON.parse(rawData); } catch(err) {}
            }
            if (!data && draggedItemData) data = draggedItemData;
            if (!data) return;

            const isShiftTarget = pad.classList.contains('shift-pad');

            if (data.type === 'action') {
              assignActionToKey(k.code, data.action, isShiftTarget);
              pad.classList.add('just-updated-glow');
              setTimeout(() => pad.classList.remove('just-updated-glow'), 600);
              showSpotlight({
                title: 'KEY ASSIGNED',
                val: 'Key [' + k.keyLabel + '] (' + (isShiftTarget ? 'Shift' : 'Normal') + ') → ' + data.action.name,
                sub: 'Unsaved changes'
              });
              setHasUnsavedChanges(true);
            } else if (data.type === 'keyslot') {
              if (data.code !== k.code || data.isShift !== isShiftTarget) {
                swapKeyBindings(data.code, k.code, data.isShift, isShiftTarget);
                pad.classList.add('just-updated-glow');
                const srcPad = document.getElementById('key-' + data.code);
                if (srcPad) {
                  srcPad.classList.add('just-updated-glow');
                  setTimeout(() => srcPad.classList.remove('just-updated-glow'), 600);
                }
                setTimeout(() => pad.classList.remove('just-updated-glow'), 600);
                showSpotlight({
                  title: 'KEYS SWAPPED',
                  val: 'Key [' + data.keyLabel + '] ↔ Key [' + k.keyLabel + ']',
                  sub: 'Unsaved changes'
                });
                setHasUnsavedChanges(true);
              }
            }
          });




            normalRowEl.appendChild(pad);
          });
          rowEl.appendChild(normalRowEl);
        }
        

    });
  } catch (err) {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
      window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'log', message: '[ERROR] initGrid exception: ' + (err.stack || err) });
    }
  }
}

  // Layout Editor & Action Library Controller Logic
  let isEditMode = false;
  let hasUnsavedChanges = false;
  let currentWorkingLayout = {};
  let draggedItemData = null;
  let shiftModeActive = false;

  function updateAllKeyLabels() {
    const isShift = shiftModeActive;
    const hudContainer = document.getElementById('hud-container');
    if (hudContainer) {
      if (isShift) hudContainer.classList.add('shift-active-labels');
      else hudContainer.classList.remove('shift-active-labels');
    }
    // Update customized keys with shift/normal labels
    for (const [codeStr, binding] of Object.entries(currentWorkingLayout)) {
      const code = parseInt(codeStr);
      if (!isNaN(code) && binding) {
        const pad = document.getElementById('key-' + code);
        if (pad) {
          const noteEl = pad.querySelector('.key-note');
          if (noteEl) {
            // If shift mode active, show shift name; fall back to normal name if no shift defined
            noteEl.textContent = isShift
              ? (binding.shiftName || binding.shiftAction || binding.name || '')
              : (binding.name || binding.shiftName || binding.shiftAction || '');
          }
        }
      }
    }
  }

  function toggleShiftMode() {
    shiftModeActive = !shiftModeActive;
    const btn = document.getElementById('shift-mode-toggle-btn');
    const hudContainer = document.getElementById('hud-container');
    const header = document.getElementById('drawer-header');
    if (shiftModeActive) {
      if (btn) btn.classList.add('shift-active');
      if (hudContainer) hudContainer.classList.add('shift-assign-active');
      if (header) header.classList.add('shifting');
    } else {
      if (btn) btn.classList.remove('shift-active');
      if (hudContainer) hudContainer.classList.remove('shift-assign-active');
      if (header) header.classList.remove('shifting');
    }
    updateAllKeyLabels();
  }

  const DEFAULT_ACTION_CATALOG = [
    {
      category: "Arpeggiator",
      actions: [
        { id: "arpToggle", name: "Arp On/Off", typeClass: "ctrl-arp", description: "Toggle arpeggiator engine" },
        { id: "arpTopToggle", name: "Top Arp", typeClass: "ctrl-arptop", description: "Toggle top row arpeggiator" },
        { id: "arpBottomToggle", name: "Bot Arp", typeClass: "ctrl-arpbot", description: "Toggle bottom row arpeggiator" },
        { id: "arpDirUp", name: "Arp Dir +", typeClass: "ctrl-arpdir", description: "Cycle arpeggiator direction up" },
        { id: "arpDirDown", name: "Arp Dir -", typeClass: "ctrl-arpdir", description: "Cycle arpeggiator direction down" },
        { id: "arpRateUp", name: "Arp Rate +", typeClass: "ctrl-arprate", description: "Increase arpeggiator speed" },
        { id: "arpRateDown", name: "Arp Rate -", typeClass: "ctrl-arprate", description: "Decrease arpeggiator speed" },
        { id: "arpGateUp", name: "Arp Gate +", typeClass: "ctrl-arpgate", description: "Lengthen arpeggiator gate" },
        { id: "arpGateDown", name: "Arp Gate -", typeClass: "ctrl-arpgate", description: "Shorten arpeggiator gate" }
      ]
    },
    {
      category: "Scale & Pitch",
      actions: [
        { id: "rootUp", name: "Root +", typeClass: "ctrl-root", description: "Shift root note up" },
        { id: "rootDown", name: "Root -", typeClass: "ctrl-root", description: "Shift root note down" },
        { id: "modeUp", name: "Mode +", typeClass: "ctrl-mode", description: "Cycle scale/mode forward" },
        { id: "modeDown", name: "Mode -", typeClass: "ctrl-mode", description: "Cycle scale/mode backward" },
        { id: "trnspUp", name: "Trnsp +", typeClass: "ctrl-trnsp", description: "Transpose semitone up" },
        { id: "trnspDown", name: "Trnsp -", typeClass: "ctrl-trnsp", description: "Transpose semitone down" },
        { id: "octaveUp", name: "Main Oct +", typeClass: "ctrl-oct", description: "Shift main octave up" },
        { id: "octaveDown", name: "Main Oct -", typeClass: "ctrl-oct", description: "Shift main octave down" },
        { id: "botOctUp", name: "Bot Oct +", typeClass: "ctrl-oct", description: "Shift bottom octave up" },
        { id: "botOctDown", name: "Bot Oct -", typeClass: "ctrl-oct", description: "Shift bottom octave down" },
        { id: "topOctUp", name: "Top Oct +", typeClass: "ctrl-topoct", description: "Shift top row octave up" },
        { id: "topOctDown", name: "Top Oct -", typeClass: "ctrl-topoct", description: "Shift top row octave down" },
        { id: "randomScale", name: "Random Scale", typeClass: "ctrl-rand", description: "Pick random scale & root" }
      ]
    },
    {
      category: "Volume & CC",
      actions: [
        { id: "sustain", name: "Sustain", typeClass: "latch-active", description: "Sustain pedal CC64 toggle/hold" },
        { id: "volUp", name: "Vol +", typeClass: "ctrl-vol", description: "Increase bottom row velocity" },
        { id: "volDown", name: "Vol -", typeClass: "ctrl-vol", description: "Decrease bottom row velocity" },
        { id: "topVolUp", name: "Top Vol +", typeClass: "ctrl-vol", description: "Increase top row velocity" },
        { id: "topVolDown", name: "Top Vol -", typeClass: "ctrl-vol", description: "Decrease top row velocity" },
        { id: "modWheelUp", name: "Mod +", typeClass: "ctrl-modw", description: "Increase modulation wheel CC1" },
        { id: "modWheelDown", name: "Mod -", typeClass: "ctrl-modw", description: "Decrease modulation wheel CC1" },
        { id: "panic", name: "Panic!", typeClass: "ctrl-panic", description: "Send all-notes-off MIDI panic" }
      ]
    },
    {
      category: "Tempo & View",
      actions: [
        { id: "undoState", name: "Undo", typeClass: "ctrl-reset", description: "Undo last controller state change (scale, pitch, octave, etc.)" },
        { id: "redoState", name: "Redo", typeClass: "ctrl-reset", description: "Redo previous controller state change" },
        { id: "bpmUp", name: "BPM +", typeClass: "ctrl-bpm", description: "Increase tempo" },
        { id: "bpmDown", name: "BPM -", typeClass: "ctrl-bpm", description: "Decrease tempo" },
        { id: "relUp", name: "Release +", typeClass: "ctrl-rel", description: "Increase release length" },
        { id: "relDown", name: "Release -", typeClass: "ctrl-rel", description: "Decrease release length" },
        { id: "zoomIn", name: "Zoom +", typeClass: "ctrl-zoom", description: "Zoom in HUD size" },
        { id: "zoomOut", name: "Zoom -", typeClass: "ctrl-zoom", description: "Zoom out HUD size" },
        { id: "resetAll", name: "Reset All", typeClass: "ctrl-reset", description: "Reset settings to defaults" },
        { id: "none", name: "Unassigned", typeClass: "", description: "Unassign key" }
      ]
    }
  ];

  let currentActionCatalog = DEFAULT_ACTION_CATALOG;

  function setEditMode(active) {
    isEditMode = active;
    const container = document.getElementById('hud-container');
    const editBtn = document.getElementById('edit-mode-btn');
    const drawer = document.getElementById('action-library-drawer');

    if (isEditMode) {
      container.classList.add('edit-mode-active');
      container.classList.add('drawer-open');
      if (editBtn) editBtn.classList.add('active');
      if (drawer) drawer.classList.add('active');

      initGrid(LAYOUT_DATA);
      if (typeof updateAllKeyLabels === 'function') updateAllKeyLabels();

      document.querySelectorAll('.key-pad:not(.dummy-pad)').forEach(pad => {
        pad.setAttribute('draggable', 'true');
      });

      // Focus the container so keyboard events (Delete/Backspace) reach the webview
      container.setAttribute('tabindex', '-1');
      container.focus();

      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
        window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'getLayoutConfig' });
      }

      // Ensure dropdown has at least a fallback entry immediately
      const presetSelect = document.getElementById('preset-select');
      if (presetSelect && presetSelect.options.length === 0) {
        const opt = document.createElement('option');
        opt.value = 'default';
        opt.textContent = 'Default Layout (Default)';
        opt.selected = true;
        presetSelect.appendChild(opt);
      }

      renderDrawerCategories(currentActionCatalog);
      showSpotlight({
        title: "LAYOUT EDIT MODE",
        val: "Drag action cards to keys or swap key positions",
        sub: "Click Save when done"
      });
      // Notify Hammerspoon to double the window height
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
        window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'toggleEditMode', active: true });
      }
    } else {
      container.classList.remove('edit-mode-active');
      if (editBtn) editBtn.classList.remove('active');
      if (drawer) {
        drawer.classList.remove('active');
      }
      container.classList.remove('drawer-open');

      initGrid(LAYOUT_DATA);
      if (typeof updateAllKeyLabels === 'function') updateAllKeyLabels();

      // Reset shift mode on edit exit
      if (shiftModeActive) toggleShiftMode();

      document.querySelectorAll('.key-pad').forEach(pad => {
        pad.setAttribute('draggable', 'false');
        pad.classList.remove('dragging-source', 'drag-over-target');
      });
      // Clear any half-level drag highlights
      document.querySelectorAll('.key-half.drag-over-target').forEach(el => el.classList.remove('drag-over-target'));

      showSpotlight({
        title: "EDIT MODE EXITED",
        val: "Standard performance mode active",
        sub: ""
      });
      // Notify Hammerspoon to restore the window height
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
        window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'toggleEditMode', active: false });
      }
    }
  }

  function renderDrawerCategories(catalog, searchQuery) {
    const container = document.getElementById('drawer-categories-container');
    if (!container) return;
    container.textContent = '';

    const query = (searchQuery || '').toLowerCase().trim();
    const cats = catalog || DEFAULT_ACTION_CATALOG;

    cats.forEach(cat => {
      const matchingActions = cat.actions.filter(act => {
        if (!query) return true;
        return (act.name && act.name.toLowerCase().includes(query)) ||
               (act.id && act.id.toLowerCase().includes(query)) ||
               (act.description && act.description.toLowerCase().includes(query));
      });

      if (matchingActions.length === 0) return;

      const catTitle = document.createElement('div');
      catTitle.className = 'drawer-category-title';
      catTitle.textContent = cat.category;
      container.appendChild(catTitle);

      matchingActions.forEach(act => {
        const item = document.createElement('div');
        item.className = 'drawer-item';
        item.setAttribute('draggable', 'true');

        const label = document.createElement('span');
        label.className = 'item-label';
        if (act.id === 'undoState') {
          label.textContent = '\u21A9 ' + act.name;
        } else if (act.id === 'redoState') {
          label.textContent = '\u21AA ' + act.name;
        } else {
          label.textContent = act.name;
        }

        const badge = document.createElement('span');
        badge.className = 'item-badge';
        badge.textContent = act.typeClass ? act.typeClass.replace('ctrl-', '').toUpperCase() : 'ACT';

        item.appendChild(label);
        item.appendChild(badge);

        if (act.description) {
          item.title = act.description;
        }

        // Do NOT call preventDefault() here — in WebKit/Blink that cancels the
        // HTML5 dragstart gesture entirely. user-select:none via CSS already
        // prevents text selection; if any stray range appears, clear it.
        item.addEventListener('mousedown', (e) => {
          try { window.getSelection().removeAllRanges(); } catch(_e) {}
        });

        item.addEventListener('dragstart', (e) => {
          e.stopPropagation();
          const payload = { type: 'action', action: act };
          e.dataTransfer.setData('application/json', JSON.stringify(payload));
          e.dataTransfer.setData('text/plain', JSON.stringify(payload));
          draggedItemData = payload;
          item.classList.add('dragging');
        });

        item.addEventListener('dragend', () => {
          item.classList.remove('dragging');
          draggedItemData = null;
          document.querySelectorAll('.key-half.drag-over-target, .key-pad.drag-over-target').forEach(el => el.classList.remove('drag-over-target'));
        });

        container.appendChild(item);
      });
    });
  }

  let undoStack = [];
  let redoStack = [];
  let isRestoringHistory = false;

  function updateUndoRedoButtons() {
    const undoBtn = document.getElementById('undo-layout-btn');
    const redoBtn = document.getElementById('redo-layout-btn');
    if (undoBtn) {
      if (undoStack.length > 0) undoBtn.classList.remove('disabled');
      else undoBtn.classList.add('disabled');
    }
    if (redoBtn) {
      if (redoStack.length > 0) redoBtn.classList.remove('disabled');
      else redoBtn.classList.add('disabled');
    }
  }

  function recordSnapshot(label) {
    if (isRestoringHistory) return;
    undoStack.push({
      layout: JSON.parse(JSON.stringify(currentWorkingLayout)),
      label: label || 'Action'
    });
    redoStack = [];
    updateUndoRedoButtons();
  }

  function applyLayoutSnapshot(snapshot) {
    isRestoringHistory = true;
    currentWorkingLayout = JSON.parse(JSON.stringify(snapshot.layout));

    initGrid(LAYOUT_DATA);

    for (const [codeStr, binding] of Object.entries(currentWorkingLayout)) {
      const code = parseInt(codeStr);
      if (!isNaN(code) && binding) {
        const pad = document.getElementById('key-' + code);
        if (pad) {
          const noteEl = pad.querySelector(':scope > .key-note');
          if (noteEl) {
            noteEl.textContent = shiftModeActive ? (binding.shiftName || binding.shiftAction || binding.name || '') : (binding.name || binding.shiftName || binding.shiftAction || '');
          }
          pad.className = 'key-pad control-pad ' + (binding.typeClass || '');
          // Update vertical split halves
          const builtIn = typeof getBuiltInKey !== 'undefined' ? getBuiltInKey(code) || {} : {};
          const halfTop = pad.querySelector('.key-half-top .key-note');
          if (halfTop) halfTop.textContent = binding.shiftName || binding.shiftAction || builtIn.shiftLabel || builtIn.noteLabel || builtIn.keyLabel || '';
          const halfBottom = pad.querySelector('.key-half-bottom .key-note');
          if (halfBottom) halfBottom.textContent = binding.name || binding.action || builtIn.noteLabel || builtIn.keyLabel || '';
        }
      }
    }

    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
      window.webkit.messageHandlers.midiControllerUC.postMessage({
        type: 'saveCustomLayout',
        layout: currentWorkingLayout
      });
    }

    setHasUnsavedChanges(true);
    isRestoringHistory = false;
    updateUndoRedoButtons();
  }

  function performUndo() {
    if (undoStack.length === 0) return;
    const currentState = {
      layout: JSON.parse(JSON.stringify(currentWorkingLayout)),
      label: 'Current'
    };
    redoStack.push(currentState);
    const previousState = undoStack.pop();
    applyLayoutSnapshot(previousState);
    showSpotlight({
      title: "UNDO",
      val: "Reverted: " + (previousState.label || 'Layout Change'),
      sub: "Unsaved changes"
    });
  }

  function performRedo() {
    if (redoStack.length === 0) return;
    const currentState = {
      layout: JSON.parse(JSON.stringify(currentWorkingLayout)),
      label: 'Current'
    };
    undoStack.push(currentState);
    const nextState = redoStack.pop();
    applyLayoutSnapshot(nextState);
    showSpotlight({
      title: "REDO",
      val: "Re-applied: " + (nextState.label || 'Layout Change'),
      sub: "Unsaved changes"
    });
  }

  function setHasUnsavedChanges(changed) {
    hasUnsavedChanges = changed;
    const saveBtn = document.getElementById('save-layout-btn');
    if (saveBtn) {
      if (hasUnsavedChanges) {
        saveBtn.classList.remove('disabled');
      } else {
        saveBtn.classList.add('disabled');
      }
    }
    const badge = document.getElementById('preset-modified-badge');
    if (badge) {
      badge.classList.toggle('hidden', !hasUnsavedChanges);
    }
  }

  function assignActionToKey(code, actionObj, isShift) {
    recordSnapshot('Assign ' + actionObj.name + (isShift ? ' (Shift)' : ''));

    if (!currentWorkingLayout[code]) {
      currentWorkingLayout[code] = {};
    }

    if (isShift) {
      currentWorkingLayout[code].shiftAction = actionObj.id;
      currentWorkingLayout[code].shiftName = actionObj.name;
    } else {
      currentWorkingLayout[code].action = actionObj.id;
      currentWorkingLayout[code].name = actionObj.name;
      currentWorkingLayout[code].typeClass = actionObj.typeClass;
    }
    setHasUnsavedChanges(true);

    const pad = document.getElementById('key-' + code);
    if (pad) {
      const noteEl = pad.querySelector('.key-note');
      if (noteEl) {
        noteEl.textContent = actionObj.name;
      }
      pad.className = 'key-pad control-pad ' + (actionObj.typeClass || '');
      pad.classList.add('just-updated-glow');
      setTimeout(() => pad.classList.remove('just-updated-glow'), 600);
    }

    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
      window.webkit.messageHandlers.midiControllerUC.postMessage({
        type: 'updateKeyMapping',
        code: code,
        binding: currentWorkingLayout[code]
      });
    }
  }

  function swapKeyBindings(codeA, codeB) {
    const padA = document.getElementById('key-' + codeA);
    const padB = document.getElementById('key-' + codeB);
    if (!padA || !padB) return;

    recordSnapshot('Swap Keys');
    setHasUnsavedChanges(true);

    const noteA = padA.querySelector(':scope > .key-note');
    const noteB = padB.querySelector(':scope > .key-note');
    const halfTopA = padA.querySelector('.key-half-top .key-note');
    const halfBotA = padA.querySelector('.key-half-bottom .key-note');
    const halfTopB = padB.querySelector('.key-half-top .key-note');
    const halfBotB = padB.querySelector('.key-half-bottom .key-note');

    const textA = noteA ? noteA.textContent : '';
    const textB = noteB ? noteB.textContent : '';

    const classA = padA.className;
    const classB = padB.className;

    if (noteA) noteA.textContent = textB;
    if (noteB) noteB.textContent = textA;

    padA.className = classB;
    padB.className = classA;

    const bindingA = currentWorkingLayout[codeA] || { name: textA };
    const bindingB = currentWorkingLayout[codeB] || { name: textB };

    currentWorkingLayout[codeA] = bindingB;
    currentWorkingLayout[codeB] = bindingA;

    // Re-render labels based on shiftModeActive
    if (shiftModeActive) {
      if (noteA) noteA.textContent = bindingB.shiftName || bindingB.shiftAction || '';
      if (noteB) noteB.textContent = bindingA.shiftName || bindingA.shiftAction || '';
    } else {
      if (noteA) noteA.textContent = bindingB.name || '';
      if (noteB) noteB.textContent = bindingA.name || '';
    }
    // Update vertical split halves
    if (halfTopA) halfTopA.textContent = bindingB.shiftName || bindingB.shiftAction || bindingB.name || '';
    if (halfBotA) halfBotA.textContent = bindingB.name || bindingB.shiftName || bindingB.shiftAction || '';
    if (halfTopB) halfTopB.textContent = bindingA.shiftName || bindingA.shiftAction || bindingA.name || '';
    if (halfBotB) halfBotB.textContent = bindingA.name || bindingA.shiftName || bindingA.shiftAction || '';

    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
      window.webkit.messageHandlers.midiControllerUC.postMessage({
        type: 'updateKeyMapping',
        code: codeA,
        binding: bindingB
      });
      window.webkit.messageHandlers.midiControllerUC.postMessage({
        type: 'updateKeyMapping',
        code: codeB,
        binding: bindingA
      });
    }
  }

  let activePresetsList = [];
  let currentActivePresetId = 'default';

  function updatePresetDropdown(presets, activeId) {
    activePresetsList = presets || [];
    currentActivePresetId = activeId || 'default';

    const select = document.getElementById('layout-select');
    if (!select) return;

    select.textContent = '';
    activePresetsList.forEach(p => {
      const opt = document.createElement('option');
      opt.value = p.id;
      opt.textContent = p.name;
      if (p.id === currentActivePresetId) opt.selected = true;
      select.appendChild(opt);
    });
  }

  document.addEventListener('DOMContentLoaded', () => {
    const layoutSelectEl = document.getElementById('layout-select');
    if (layoutSelectEl) {
      layoutSelectEl.addEventListener('change', (e) => {
        const selectedId = e.target.value;
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiController) {
          window.webkit.messageHandlers.midiController.postMessage({
            type: 'selectPreset',
            id: selectedId
          });
        }
      });
    }
  });

  function openPresetModal(mode) {
    const overlay = document.getElementById('preset-modal-overlay');
    const titleEl = document.getElementById('preset-modal-title');
    const inputEl = document.getElementById('preset-modal-input');
    if (!overlay || !titleEl || !inputEl) return;

    overlay.dataset.mode = mode;
    overlay.classList.remove('hidden');

    const activePreset = activePresetsList.find(p => p.id === currentActivePresetId) || { name: 'Preset' };

    if (mode === 'saveAs') {
      titleEl.textContent = 'Save Preset As';
      inputEl.value = activePreset.name + ' Copy';
    } else if (mode === 'rename') {
      titleEl.textContent = 'Rename Preset';
      inputEl.value = activePreset.name;
    } else if (mode === 'duplicate') {
      titleEl.textContent = 'Duplicate Preset';
      inputEl.value = activePreset.name + ' Copy';
    }
    requestAnimationFrame(() => {
      inputEl.focus();
      inputEl.select();
    });
  }

  function closePresetModal() {
    const overlay = document.getElementById('preset-modal-overlay');
    if (overlay) overlay.classList.add('hidden');
  }

  function handlePresetModalConfirm() {
    const overlay = document.getElementById('preset-modal-overlay');
    const inputEl = document.getElementById('preset-modal-input');
    if (!overlay || !inputEl) return;

    const mode = overlay.dataset.mode;
    const name = inputEl.value.trim();
    if (!name) return;

    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
      if (mode === 'saveAs') {
        window.webkit.messageHandlers.midiControllerUC.postMessage({
          type: 'savePreset',
          name: name,
          layout: currentWorkingLayout
        });
        showSpotlight({
          title: "PRESET CREATED",
          val: name,
          sub: "New layout preset saved"
        });
      } else if (mode === 'rename') {
        window.webkit.messageHandlers.midiControllerUC.postMessage({
          type: 'renamePreset',
          id: currentActivePresetId,
          newName: name
        });
        showSpotlight({
          title: "PRESET RENAMED",
          val: name,
          sub: ""
        });
      } else if (mode === 'duplicate') {
        window.webkit.messageHandlers.midiControllerUC.postMessage({
          type: 'duplicatePreset',
          id: currentActivePresetId,
          newName: name
        });
        showSpotlight({
          title: "PRESET DUPLICATED",
          val: name,
          sub: "Cloned layout preset"
        });
      }
    }

    if (mode === 'saveAs' || mode === 'duplicate') {
      currentWorkingLayout = JSON.parse(JSON.stringify(currentWorkingLayout || {}));
    }
    setHasUnsavedChanges(false);
    closePresetModal();
  }

  window.onLayoutConfigLoaded = function(configData) {
    if (!configData) return;
    if (typeof initGrid === 'function' && typeof LAYOUT_DATA !== 'undefined') {
      initGrid(LAYOUT_DATA);
    }
    if (configData.actionCatalog) {
      currentActionCatalog = configData.actionCatalog;
      // Preserve current search query when re-rendering after config load
      const searchInput = document.getElementById('drawer-search-input');
      const currentQuery = searchInput ? searchInput.value : '';
      renderDrawerCategories(currentActionCatalog, currentQuery);
    }
    if (configData.customLayout) {
      currentWorkingLayout = configData.customLayout;
    }
    if (typeof updateAllKeyLabels === 'function') updateAllKeyLabels();
    if (configData.presets) {
      updatePresetDropdown(configData.presets, configData.activePresetId);
    }
  };

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
        if (isEditMode && (e.target.closest('.drawer-panel') || e.target.closest('.key-pad') || e.target.closest('[draggable="true"]') || e.target.closest('.preset-modal-overlay'))) return;

        // Marquee selection start on empty area in edit mode
        if (isEditMode && e.button === 0 && !e.target.closest('.drawer-panel') && !e.target.closest('select') && !e.target.closest('button') && !e.target.closest('.key-pad')) {
          hideContextMenu();
          const perfView = document.getElementById('performance-view') || container;
          const pr = perfView.getBoundingClientRect();
          marqueeStartX = e.clientX - pr.left;
          marqueeStartY = e.clientY - pr.top;
          const marquee = document.getElementById('selection-marquee');
          if (marquee) {
            marquee.style.left = marqueeStartX + 'px';
            marquee.style.top = marqueeStartY + 'px';
            marquee.style.width = '0px';
            marquee.style.height = '0px';
          }
          isMarqueeSelecting = true;
          return;
        }

        if (e.target.closest('.key-pad') || e.target.closest('select') || e.target.closest('button') || e.target.closest('.mode-center-block') || e.target.closest('.bpm-editor') || (e.target.closest('.drawer-panel') && !e.target.closest('.drawer-header'))) return;

        // Click on empty space: clear selection and hide context menu
        if (isEditMode) {
          clearSelection();
          hideContextMenu();
        }

        isDragging = true;
        dragStartX = e.screenX;
        dragStartY = e.screenY;
      });
    }

    // Context menu on key pads
    container && container.addEventListener('contextmenu', (e) => {
      const keyPad = e.target.closest('.key-pad:not(.dummy-pad)');
      if (keyPad && isEditMode) {
        const code = parseInt(keyPad.id.replace('key-', ''));
        if (!isNaN(code)) {
          if (!selectedKeys.has(code)) {
            selectKey(code, false);
          }
          showContextMenu(e);
        }
      } else {
        hideContextMenu();
      }
    });

    // Context menu button actions
    document.addEventListener('click', (e) => {
      const ctxItem = e.target.closest('.ctx-item');
      if (ctxItem) {
        const action = ctxItem.dataset.action;
        if (action === 'revert-note') {
          revertSelectedKeysToNotes();
        } else if (action === 'deselect-all') {
          clearSelection();
        }
        hideContextMenu();
        e.stopPropagation();
        e.preventDefault();
      } else if (!e.target.closest('#key-context-menu')) {
        hideContextMenu();
      }
    });

    // Global keydown for Delete/Backspace to revert selected keys
    window.addEventListener('keydown', (e) => {
      if (!isEditMode) return;
      if (e.key === 'Delete' || e.key === 'Backspace') {
        if (selectedKeys.size > 0 && !e.target.closest('input, textarea')) {
          e.preventDefault();
          e.stopPropagation();
          revertSelectedKeysToNotes();
        }
      }
    });

    // ===== TEXT INPUT FOCUS FIX: post focus/blur to Lua host =====
    function addTextFocusListeners(el) {
      if (!el) return;
      el.addEventListener('focus', function() { postTextInputFocus(true); });
      el.addEventListener('blur', function() { postTextInputFocus(false); });
    }
    addTextFocusListeners(document.getElementById('drawer-search-input'));
    addTextFocusListeners(document.getElementById('preset-modal-input'));
    const drawerContainer = document.getElementById('drawer-categories-container');
    if (drawerContainer) {
      drawerContainer.addEventListener('mouseenter', function() {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'hoverScrollable', state: true });
        }
      });
      drawerContainer.addEventListener('mouseleave', function() {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'hoverScrollable', state: false });
        }
      });
    }

    // Delegate hover state to any scrollable element
    document.body.addEventListener('mouseenter', function(e) {
      if (e.target.matches('.drawer-content')) {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'hoverScrollable', state: true });
        }
      }
    }, true);
    document.body.addEventListener('mouseleave', function(e) {
      if (e.target.matches('.drawer-content')) {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'hoverScrollable', state: false });
        }
      }
    }, true);



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

    // Gate Editor handlers
    let isGateDragging = false;
    let gateDragStartY = 0;
    let gateDragAccum = 0;
    let gateBtnTimer = null;
    let gateBtnInterval = null;
    let gateBtnDirection = 0;

    const arpQuantizeSelect = document.getElementById('arp-quantize-select');
    if (arpQuantizeSelect) {
      arpQuantizeSelect.addEventListener('change', (e) => {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({
            type: 'setArpQuantize',
            value: e.target.value
          });
        }
      });
    }

    const inputQuantizeSelect = document.getElementById('input-quantize-select');
    if (inputQuantizeSelect) {
      inputQuantizeSelect.addEventListener('change', (e) => {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({
            type: 'setInputQuantize',
            value: e.target.value
          });
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
      bpmValue.addEventListener('mouseup', (e) => {
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
        btn.addEventListener('mouseup', stopBpmRepeat);
        btn.addEventListener('mouseleave', stopBpmRepeat);
      }
    });

    const logicSyncBtn = document.getElementById('logic-sync-btn');
    if (logicSyncBtn) {
      logicSyncBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'toggleLogicSync' });
        }
      });
    }

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

    // Layout Editor Drawer Buttons
    const editBtn = document.getElementById('edit-mode-btn');
    if (editBtn) {
      editBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        setEditMode(!isEditMode);
      });
    }

    const undoBtn = document.getElementById('undo-layout-btn');
    if (undoBtn) {
      undoBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        performUndo();
      });
    }

    const redoBtn = document.getElementById('redo-layout-btn');
    if (redoBtn) {
      redoBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        performRedo();
      });
    }

    const shiftToggleBtn = document.getElementById('shift-mode-toggle-btn');
    if (shiftToggleBtn) {
      shiftToggleBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        toggleShiftMode();
      });
    }

    window.addEventListener('keydown', (e) => {
      if (!isEditMode) return;
      const isCmd = e.metaKey || e.ctrlKey;
      if (isCmd && (e.key === 'z' || e.key === 'Z')) {
        e.preventDefault();
        e.stopPropagation();
        if (e.shiftKey) {
          performRedo();
        } else {
          performUndo();
        }
      }
    });

    const closeDrawerBtn = document.getElementById('close-drawer-btn');
    if (closeDrawerBtn) {
      closeDrawerBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        const drawer = document.getElementById('action-library-drawer');
        if (drawer) {
          drawer.classList.remove('active');
          document.getElementById('hud-container').classList.remove('drawer-open');
        }
      });
    }
    
    const toggleDrawerBtn = document.getElementById('toggle-drawer-btn');
    if (toggleDrawerBtn) {
      toggleDrawerBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        const drawer = document.getElementById('action-library-drawer');
        if (drawer) {
          drawer.classList.toggle('active');
          document.getElementById('hud-container').classList.toggle('drawer-open');
        }
      });
    }

    const searchInput = document.getElementById('drawer-search-input');
    if (searchInput) {
      searchInput.addEventListener('input', (e) => {
        renderDrawerCategories(currentActionCatalog, e.target.value);
      });
    }

    // Preset Toolbar Event Handlers
    const presetSelect = document.getElementById('preset-select');
    if (presetSelect) {
      presetSelect.addEventListener('change', (e) => {
        const selectedId = e.target.value;
        if (selectedId && selectedId !== currentActivePresetId) {
          if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
            window.webkit.messageHandlers.midiControllerUC.postMessage({
              type: 'selectPreset',
              id: selectedId
            });
          }
          setHasUnsavedChanges(false);
          const selOpt = e.target.options[e.target.selectedIndex];
          showSpotlight({
            title: "PRESET LOADED",
            val: selOpt ? selOpt.textContent : selectedId,
            sub: "Switched layout preset"
          });
        }
      });
    }

    const presetSaveAsBtn = document.getElementById('preset-save-as-btn');
    if (presetSaveAsBtn) {
      presetSaveAsBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        openPresetModal('saveAs');
      });
    }

    const presetRenameBtn = document.getElementById('preset-rename-btn');
    if (presetRenameBtn) {
      presetRenameBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        const activePreset = activePresetsList.find(p => p.id === currentActivePresetId);
        if (activePreset && activePreset.isBuiltin) return;
        openPresetModal('rename');
      });
    }

    const presetDuplicateBtn = document.getElementById('preset-duplicate-btn');
    if (presetDuplicateBtn) {
      presetDuplicateBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        const activePreset = activePresetsList.find(p => p.id === currentActivePresetId);
        if (activePreset && activePreset.isBuiltin) return;
        openPresetModal('duplicate');
      });
    }

    const presetDeleteBtn = document.getElementById('preset-delete-btn');
    if (presetDeleteBtn) {
      presetDeleteBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        const activePreset = activePresetsList.find(p => p.id === currentActivePresetId);
        if (activePreset && activePreset.isBuiltin) return;
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({
            type: 'deletePreset',
            id: currentActivePresetId
          });
          showSpotlight({
            title: "PRESET DELETED",
            val: activePreset ? activePreset.name : "Preset",
            sub: "Reverted to Default Preset"
          });
        }
      });
    }

    const presetModalCancel = document.getElementById('preset-modal-cancel');
    if (presetModalCancel) {
      presetModalCancel.addEventListener('click', (e) => {
        e.stopPropagation();
        closePresetModal();
      });
    }

    const presetModalConfirm = document.getElementById('preset-modal-confirm');
    if (presetModalConfirm) {
      presetModalConfirm.addEventListener('click', (e) => {
        e.stopPropagation();
        handlePresetModalConfirm();
      });
    }

    const presetModalInput = document.getElementById('preset-modal-input');
    if (presetModalInput) {
      presetModalInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
          e.preventDefault();
          e.stopPropagation();
          handlePresetModalConfirm();
        } else if (e.key === 'Escape') {
          e.preventDefault();
          e.stopPropagation();
          closePresetModal();
        }
      });
    }

    const saveBtn = document.getElementById('save-layout-btn');
    if (saveBtn) {
      saveBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        if (!hasUnsavedChanges) return;

        const activePreset = activePresetsList.find(p => p.id === currentActivePresetId);
        if (activePreset && activePreset.isBuiltin) {
          openPresetModal('saveAs');
          return;
        }

        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({
            type: 'saveCustomLayout',
            layout: currentWorkingLayout
          });
        }
        setHasUnsavedChanges(false);
        showSpotlight({
          title: "LAYOUT SAVED",
          val: activePreset ? activePreset.name : "Custom Layout",
          sub: "Preset updated"
        });
      });
    }

    const resetBtn = document.getElementById('reset-layout-btn');
    if (resetBtn) {
      resetBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'resetLayout' });
        }
        currentWorkingLayout = {};
        setHasUnsavedChanges(false);
        initGrid(LAYOUT_DATA);
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'getLayoutConfig' });
        }
        showSpotlight({
          title: "LAYOUT RESET",
          val: "Reverted to default key bindings",
          sub: ""
        });
      });
    }

    const cancelBtn = document.getElementById('cancel-layout-btn');
    if (cancelBtn) {
      cancelBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        setEditMode(false);
      });
    }
  });

  window.addEventListener('mousemove', (e) => {
    if (isMarqueeSelecting && isEditMode) {
      const perfView = document.getElementById('performance-view') || document.getElementById('hud-container');
      if (!perfView) return;
      const pr = perfView.getBoundingClientRect();
      const cx = e.clientX - pr.left;
      const cy = e.clientY - pr.top;
      const marquee = document.getElementById('selection-marquee');
      if (marquee) {
        const left = Math.min(marqueeStartX, cx);
        const top = Math.min(marqueeStartY, cy);
        const w = Math.abs(cx - marqueeStartX);
        const h = Math.abs(cy - marqueeStartY);
        marquee.style.left = left + 'px';
        marquee.style.top = top + 'px';
        marquee.style.width = w + 'px';
        marquee.style.height = h + 'px';

        // Select keys within the marquee rectangle
        const allKeys = [];
        ['number', 'upper', 'home', 'lower'].forEach(rowName => {
          const row = LAYOUT_DATA[rowName];
          if (row) row.forEach(k => { if (!k.isDummy) allKeys.push(k); });
        });
        clearSelection();
        allKeys.forEach(k => {
          const el = document.getElementById('key-' + k.code);
          if (!el) return;
          const r = el.getBoundingClientRect();
          const relLeft = r.left - pr.left;
          const relTop = r.top - pr.top;
          const relRight = r.right - pr.left;
          const relBottom = r.bottom - pr.top;
          // Check if the key rect overlaps the marquee rect
          if (relLeft < left + w && relRight > left && relTop < top + h && relBottom > top) {
            el.classList.add('selected-key');
            selectedKeys.add(k.code);
          }
        });
      }
      return;
    }
    if (isGateDragging) {
      const dy = gateDragStartY - e.clientY;
      gateDragAccum += dy;
      gateDragStartY = e.clientY;
      const stepThreshold = e.shiftKey ? 2 : 6;
      if (Math.abs(gateDragAccum) >= stepThreshold) {
        const steps = Math.trunc(gateDragAccum / stepThreshold);
        gateDragAccum %= stepThreshold;
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({
            type: 'dragGate',
            delta: steps
          });
        }
      }
      return;
    }
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
    isMarqueeSelecting = false;
    octaveDragTarget = null;
    isBpmDragging = false;
    isGateDragging = false;
    const marquee = document.getElementById('selection-marquee');
    if (marquee) { marquee.style.width = '0px'; marquee.style.height = '0px'; }
    stopBpmRepeat();
    stopGateRepeat();
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

    titleEl.innerHTML = spotlight.title || '';
    // Accept both 'value' (Lua convention) and 'val' (JS convention)
    const valText = spotlight.value !== undefined ? spotlight.value : spotlight.val;
    valEl.textContent = valText !== undefined ? valText : '';
    const subText = spotlight.subtext !== undefined ? spotlight.subtext : spotlight.sub;
    subEl.textContent = subText !== undefined ? subText : '';

    const color = spotlight.color || '#d4a359';
    card.style.borderColor = color;
    card.style.boxShadow = '0 0 0 1px ' + color + '66, 0 0 12px ' + color + '55';
    subEl.style.color = color;

    card.classList.remove('hidden');
    card.style.transition = 'none';
    card.style.opacity = '1';
    card.style.transform = 'translateY(0) scale(1.0)';
    card.style.left = '';
    card.style.top = '';

    card.offsetHeight;

    card.style.transition = 'opacity 0.4s ease, transform 0.4s ease';

    spotlightTimer1 = setTimeout(() => {
      card.style.opacity = '0';
      card.style.transform = 'translateY(-10px) scale(0.85)';

      spotlightTimer2 = setTimeout(() => {
        card.classList.add('hidden');
      }, 400);
    }, 1000);
  }

  function renderHud(data) {
    if (document.querySelectorAll('.key-pad').length === 0) {
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
        window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'log', message: '[AUTO-REPAIR] renderHud detected 0 key-pads in DOM! Rebuilding grid from LAYOUT_DATA' });
      }
      initGrid(LAYOUT_DATA);
    }
    const t0 = performance.now();
    try {
      if (!data) return;

      if (data.keystepConnected !== undefined) {
        if (typeof setKeyStepConnected === 'function') setKeyStepConnected(data.keystepConnected);
      } else if (data.nanokeyConnected !== undefined) {
        if (typeof setKeyStepConnected === 'function') setKeyStepConnected(data.nanokeyConnected);
      }
      if (data.keystepState && typeof window.syncFullKeyStepState === 'function') {
        window.syncFullKeyStepState(data.keystepState);
      }

      renderCount++;
      if (renderCount >= 100) {
        renderCount = 0;
      }

      const container = document.getElementById('hud-container');
      if (container) {
        if (shiftModeActive || data.shiftHeld) {
          container.classList.add('shift-active-labels');
        } else {
          container.classList.remove('shift-active-labels');
        }

        if (data.stackedKeyLabelsInPerformanceMode !== undefined) {
          if (data.stackedKeyLabelsInPerformanceMode) {
            container.classList.add('stacked-labels-active');
          } else {
            container.classList.remove('stacked-labels-active');
          }
        }
      }

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
        const modeEl = document.getElementById('mode-name');
        if (modeEl) modeEl.textContent = data.modeName;
      }

      if (data.modeSelectHeld !== undefined) {
        if (data.modeSelectHeld) {
          document.body.classList.add('mode-select-active');
        } else {
          document.body.classList.remove('mode-select-active');
        }
      }

      if (data.currentMode !== undefined) {
        const modeIndicator = document.getElementById('mode-indicator');
        if (modeIndicator) {
          modeIndicator.textContent = data.currentMode === "Home" ? "" : "MODE: " + data.currentMode;
        }
      }

      if (data.arpEnabled !== undefined) {
        const arpPowerBtn = document.getElementById('arp-power-btn');
        if (arpPowerBtn) {
          const latch = data.arpLatchActive;
          const isShift = data.shiftHeld || shiftModeActive;
          if (!data.arpEnabled) {
            arpPowerBtn.textContent = 'ARP: OFF';
            arpPowerBtn.classList.remove('arp-active', 'arp-latch');
          } else if (isShift) {
            arpPowerBtn.textContent = 'ARP: BYPASS';
            arpPowerBtn.classList.add('arp-active');
            arpPowerBtn.classList.remove('arp-latch');
          } else if (latch) {
            arpPowerBtn.textContent = 'ARP: LATCH 🔒';
            arpPowerBtn.classList.add('arp-active', 'arp-latch');
          } else {
            arpPowerBtn.textContent = 'ARP: ON';
            arpPowerBtn.classList.add('arp-active');
            arpPowerBtn.classList.remove('arp-latch');
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

      if (data.arpQuantizeMode !== undefined) {
        const arpQuantSelect = document.getElementById('arp-quantize-select');
        if (arpQuantSelect) arpQuantSelect.value = data.arpQuantizeMode;
      }

      if (data.inputQuantizeMode !== undefined) {
        const inQuantSelect = document.getElementById('input-quantize-select');
        if (inQuantSelect) inQuantSelect.value = data.inputQuantizeMode;
      }

      if (data.scaleGuide) {
        const guide = data.scaleGuide;
        const isEnabled = (data.scaleGuideEnabled !== false);
        const ksView = document.getElementById('keystep-view');
        if (ksView) {
          ksView.classList.toggle('scale-guide-active', isEnabled);
        }

        const pitches = guide.pitches || (guide.scaleInfo && guide.scaleInfo.pitches);
        if (pitches) {
          for (const pStr in pitches) {
            const p = parseInt(pStr, 10);
            const info = pitches[pStr];
            const keyEl = document.getElementById('ks-key-' + p);
            if (keyEl) {
              keyEl.classList.toggle('ks-key-root', isEnabled && !!info.isRoot);
              keyEl.classList.toggle('ks-key-in-scale', isEnabled && !!info.inScale);
              keyEl.classList.toggle('ks-key-out-of-scale', isEnabled && !info.inScale);
            }
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

      if (data.logicSyncEnabled !== undefined) {
        const syncBtn = document.getElementById('logic-sync-btn');
        if (syncBtn) {
          syncBtn.textContent = data.logicSyncEnabled ? 'SYNC: ON' : 'SYNC: OFF';
          if (data.logicSyncEnabled) syncBtn.style.color = '#d4a359';
          else syncBtn.style.color = '#7a7067';
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
        const st = document.getElementById('status-text');
        if (st) st.textContent = data.statusText;
      }

      if (data.topOctaveStr !== undefined) {
        const topTxt = document.getElementById('top-oct-text');
        if (topTxt) topTxt.textContent = 'TOP ' + data.topOctaveStr;
      }

      if (data.bottomOctaveStr !== undefined) {
        const botTxt = document.getElementById('bottom-oct-text');
        if (botTxt) botTxt.textContent = 'BOT ' + data.bottomOctaveStr;
      }

      if (data.topVolPercent !== undefined) {
        const topVolFill = document.getElementById('vol-fill-top');
        const effVol = (data.effectiveTopVolPercent !== undefined) ? data.effectiveTopVolPercent : data.topVolPercent;
        if (topVolFill) topVolFill.style.height = Math.min(100, Math.max(0, effVol)) + '%';
      }

      if (data.bottomVolPercent !== undefined) {
        const botVolFill = document.getElementById('vol-fill-bottom');
        if (botVolFill) botVolFill.style.height = Math.min(100, Math.max(0, data.bottomVolPercent)) + '%';
      }

      if (data.modeFrac !== undefined && !isModeDragging) {
        const thumb = document.getElementById('mode-thumb');
        if (thumb) thumb.style.left = (data.modeFrac * 100) + '%';
      }

      if (data.modWheel !== undefined) {
        const intensity = (data.modWheel / 127.0).toFixed(2);
        document.body.style.setProperty('--mod-intensity', intensity);
        const container = document.getElementById('hud-container');
        const fillEl = document.getElementById('mod-wheel-fill');
        const labelEl = document.getElementById('mod-wheel-label');
        const widgetEl = document.getElementById('mod-wheel-widget');
        if (container && widgetEl) {
          if (data.modWheel > 0) {
            container.classList.add('mod-active');
            widgetEl.classList.add('active');
          } else {
            container.classList.remove('mod-active');
            widgetEl.classList.remove('active');
          }
        }
        if (fillEl) {
          fillEl.style.width = (intensity * 100) + '%';
          if (data.modWheel >= 80) fillEl.classList.add('hot');
          else fillEl.classList.remove('hot');
        }
        if (labelEl) labelEl.textContent = 'MOD ' + data.modWheel;
      }

      if (data.uiActionKeyHue !== undefined) {
        document.documentElement.style.setProperty('--action-bg-hsl', `${data.uiActionKeyHue}, ${data.uiActionKeySat}%, ${data.uiActionKeyLight}%`);
        document.documentElement.style.setProperty('--action-bg-opacity', data.uiActionKeyOpacity);
        document.documentElement.style.setProperty('--action-border-opacity', data.uiActionKeyBorderOpacity);
      }

      const trackRgbMap = {
        1: '0, 229, 255',
        2: '255, 145, 0',
        3: '0, 230, 118',
        4: '213, 0, 249'
      };
      const trkCodeMap = { 1: 18, 2: 19, 3: 20, 4: 21 };

      if (data.activeTrackColor) {
        document.documentElement.style.setProperty('--active-track-color', data.activeTrackColor);
        const rgb = trackRgbMap[data.activeTrack] || '0, 229, 255';
        document.documentElement.style.setProperty('--active-track-rgb', rgb);
      }
      if (data.topTrackColor) {
        document.documentElement.style.setProperty('--top-track-color', data.topTrackColor);
        const rgb = trackRgbMap[data.topRowTrack] || '0, 230, 118';
        document.documentElement.style.setProperty('--top-track-rgb', rgb);
      }
      if (data.bottomTrackColor) {
        document.documentElement.style.setProperty('--bottom-track-color', data.bottomTrackColor);
        const rgb = trackRgbMap[data.bottomRowTrack] || '0, 229, 255';
        document.documentElement.style.setProperty('--bottom-track-rgb', rgb);
      }

      if (data.tracks) {
        for (let id = 1; id <= 4; id++) {
          const t = data.tracks[id] || {};
          const el = document.getElementById('key-' + trkCodeMap[id]);
          if (el) {
            el.classList.remove('sustain-active');
            el.classList.toggle('trk-selected', !!t.selected);
            el.classList.toggle('trk-muted', !!t.muted);
            el.classList.toggle('trk-soloed', !!t.soloed);
            el.classList.toggle('trk-audio-active', !!t.activeAudio);
            el.classList.toggle('trk-human-active', !!t.humanActive);
            el.classList.toggle('trk-arp-step', !!t.arpStep);
            const mBadge = el.querySelector('.trk-badge-m');
            if (mBadge) mBadge.classList.toggle('active', !!t.muted);
            const sBadge = el.querySelector('.trk-badge-s');
            if (sBadge) sBadge.classList.toggle('active', !!t.soloed);
          }
        }
      }

      if (data.keys) {
        for (const [code, k] of Object.entries(data.keys)) {
          const el = document.getElementById('key-' + code);
          if (el) {
            const numCode = parseInt(code, 10);
            const isTrackCard = numCode >= 18 && numCode <= 21;
            const isTrkBtn = isTrackCard;
            if (isTrackCard) {
              k.sustainActive = false;
            }

            const noteEl = el.querySelector(':scope > .key-note');
            if (noteEl) {
              if (k.displayNote !== undefined && k.displayNote !== '') {
                noteEl.textContent = k.displayNote;
              } else if (shiftModeActive && (currentWorkingLayout || {})[code]) {
                const binding = currentWorkingLayout[code];
                noteEl.textContent = binding.shiftName || binding.shiftAction || binding.name || k.note || '';
              } else if (data.shiftHeld && k.shiftNote !== undefined) {
                noteEl.textContent = k.shiftNote;
              } else if (k.note !== undefined) {
                noteEl.textContent = k.note;
              }
            }

            const builtIn = typeof getBuiltInKey !== 'undefined' ? getBuiltInKey(code) || {} : {};
            const halfTop = el.querySelector('.key-half-top .key-note');
            const halfBottom = el.querySelector('.key-half-bottom .key-note');
            if (halfTop) {
              if ((currentWorkingLayout || {})[code]) {
                const binding = currentWorkingLayout[code];
                halfTop.textContent = binding.shiftName || binding.shiftAction || k.shiftNote || k.shiftAction || builtIn.shiftLabel || k.note || builtIn.noteLabel || builtIn.keyLabel || '';
              } else {
                halfTop.textContent = k.shiftNote || k.shiftAction || builtIn.shiftLabel || k.note || builtIn.noteLabel || builtIn.keyLabel || '';
              }
            }
            if (halfBottom) {
              if ((currentWorkingLayout || {})[code]) {
                const binding = currentWorkingLayout[code];
                halfBottom.textContent = binding.name || binding.action || k.note || builtIn.noteLabel || builtIn.keyLabel || '';
              } else {
                halfBottom.textContent = k.note || builtIn.noteLabel || builtIn.keyLabel || '';
              }
            }
            const baseClass = 'key-pad ' + (k.isControl ? 'control-pad ' : '') + (isTrackCard ? 'track-card ' : '') + (k.typeClass || '');
            if (el.dataset.baseClass !== baseClass) {
              const currentStatusClasses = Array.from(el.classList).filter(c =>
                ['latched-key', 'pressed', 'sustain-active', 'arp-held', 'arp-playing', 'trk-selected', 'trk-muted', 'trk-soloed', 'trk-audio-active', 'trk-human-active', 'trk-arp-step'].includes(c)
              );
              el.className = baseClass + (currentStatusClasses.length ? ' ' + currentStatusClasses.join(' ') : '');
              el.dataset.baseClass = baseClass;
            }

            const isLatchedNote = !k.isControl && (
              !!k.latched || 
              (data.arpHeldNotes && (
                !!data.arpHeldNotes[code] || 
                !!data.arpHeldNotes[code + "_"]
              ))
            );
            el.classList.toggle('latched-key', !!isLatchedNote);
            el.classList.toggle('pressed', !!k.pressed);
            el.classList.toggle('sustain-active', isTrkBtn ? false : !!k.sustainActive);
            el.classList.toggle('arp-held', !!k.arpHeld);
            el.classList.toggle('arp-playing', !!k.arpPlaying);

            if (isTrkBtn) {
              if (k.trkSelected !== undefined) el.classList.toggle('trk-selected', !!k.trkSelected);
              if (k.trkMuted !== undefined) {
                el.classList.toggle('trk-muted', !!k.trkMuted);
                const m = el.querySelector('.trk-badge-m');
                if (m) m.classList.toggle('active', !!k.trkMuted);
              }
              if (k.trkSoloed !== undefined) {
                el.classList.toggle('trk-soloed', !!k.trkSoloed);
                const s = el.querySelector('.trk-badge-s');
                if (s) s.classList.toggle('active', !!k.trkSoloed);
              }
              if (k.trkAudioActive !== undefined) el.classList.toggle('trk-audio-active', !!k.trkAudioActive);
              if (k.trkHumanActive !== undefined) el.classList.toggle('trk-human-active', !!k.trkHumanActive);
              if (k.trkArpStep !== undefined) el.classList.toggle('trk-arp-step', !!k.trkArpStep);
              if (k.trkSustainMode !== undefined) {
                const susTag = el.querySelector('.trk-tag-sus');
                if (susTag) {
                  const isSus = k.trkSustainMode !== 'off';
                  susTag.classList.toggle('active', isSus);
                  susTag.classList.toggle('classic', k.trkSustainMode === 'classic');
                  susTag.textContent = 'S';
                }
              }
              if (k.trkChordMode !== undefined) {
                const chdTag = el.querySelector('.trk-tag-chd');
                if (chdTag) {
                  chdTag.classList.toggle('active', !!k.trkChordMode);
                }
              }
            }

            const isShift = data.shiftHeld || shiftModeActive;
            const effAction = isShift ? (k.shiftAction || k.action) : k.action;

            const iconEl = el.querySelector('.key-row-icon');
            if (iconEl) {
              iconEl.classList.remove('top-active', 'bottom-active', 'both-active');

              let rowTarget = k.rowActive || null;
              const curNote = (k.displayNote || k.note || '').trim();

              if (!rowTarget && curNote) {
                if (/^Top(Oct| Vol| 3⇄4| Lock|\b)/i.test(curNote)) {
                  rowTarget = 'top';
                } else if (/^Bot(Oct| Vol| 1⇄2| Lock|\b)/i.test(curNote)) {
                  rowTarget = 'bottom';
                } else if (/^(Oct [+\-]|Oct Reset|Vol [+\-]|Mix Reset)/i.test(curNote)) {
                  rowTarget = 'both';
                }
              }

              if (!rowTarget && effAction) {
                if (
                  effAction === 'topOctDown' || effAction === 'topOctUp' ||
                  effAction === 'topVolDown' || effAction === 'topVolUp' ||
                  effAction === 'arpTopToggle' || effAction === 'topTrackToggle' ||
                  effAction === 'topTrackLock' || effAction === 'topBoostUp' || effAction === 'topBoostDown' ||
                  String(effAction).match(/^trk(Select|Mute|Solo|Lock|Rec|Clear|Focus)[34]$/)
                ) {
                  rowTarget = 'top';
                } else if (
                  effAction === 'botVolDown' || effAction === 'botVolUp' ||
                  effAction === 'arpBottomToggle' || effAction === 'botOctDown' || effAction === 'botOctUp' ||
                  effAction === 'botTrackToggle' || effAction === 'botTrackLock' ||
                  String(effAction).match(/^trk(Select|Mute|Solo|Lock|Rec|Clear|Focus)[12]$/)
                ) {
                  rowTarget = 'bottom';
                } else if (
                  effAction === 'octaveDown' || effAction === 'octaveUp' || effAction === 'octReset' ||
                  effAction === 'volDown' || effAction === 'volUp' || effAction === 'mixReset' ||
                  effAction === 'arpLinkToggle' || effAction === 'splitArpToggle'
                ) {
                  rowTarget = 'both';
                }
              }

              if (!rowTarget && isTrkBtn) {
                rowTarget = (numCode <= 19) ? 'bottom' : 'top';
              }

              if (rowTarget === 'top') {
                iconEl.classList.add('top-active');
              } else if (rowTarget === 'bottom') {
                iconEl.classList.add('bottom-active');
              } else if (rowTarget === 'both') {
                iconEl.classList.add('both-active');
              }
            }
          }
        }
      }

      if (data.arpHeldNotes) {
        for (const [code, isHeld] of Object.entries(data.arpHeldNotes)) {
          const el = document.getElementById('key-' + code);
          if (el && isHeld) {
            el.classList.add('latched-key');
          }
        }
      }

      const renderTime = performance.now() - t0;
      if ((renderTime > 15 || renderCount === 0) && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
        window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'log', message: 'renderHud completed in ' + renderTime.toFixed(2) + 'ms' });
      }
    } catch (err) {
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
        window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'log', message: 'CRITICAL renderHud ERROR: ' + (err.stack || err) });
      }
    }
  }

  // Immediate init execution in case DOM ready state passed
  const t0 = performance.now();
  initGrid(LAYOUT_DATA);
  const t1 = performance.now();
  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
      window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'log', message: 'initGrid took ' + (t1 - t0) + ' ms' });
  }

  // Heartbeat: let Lua detect if the web content process silently dies
  let hbCount = 0;
  setInterval(() => {
    hbCount++;
    if (hbCount >= 10) {
       hbCount = 0;
       if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'log', message: 'heartbeat tick' });
       }
    }
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
      window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'heartbeat' });
    }
  }, 2000);

  window.pingHudController = function() {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
      window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'pong', timestamp: Date.now() });
    }
  };

window.updateArpPitches = function(activeCodes, heldCodes) {
  document.querySelectorAll('.key-pad.arp-playing').forEach(el => {
    el.classList.remove('arp-playing');
    if (!el.dataset.physicallyPressed) el.classList.remove('pressed');
  });
  document.querySelectorAll('.key-pad.arp-held').forEach(el => el.classList.remove('arp-held'));

  // Clear temporary arp stepping highlights on KeyStep
  document.querySelectorAll('.ks-key-w.arp-step, .ks-key-b.arp-step').forEach(k => {
    k.classList.remove('arp-step', 'active');
  });

  if (Array.isArray(activeCodes)) {
    activeCodes.forEach(code => {
      const el = document.getElementById('key-' + code);
      if (el && !el.classList.contains('control-pad')) {
        el.classList.add('arp-playing', 'pressed');

        // Illuminate on KeyStep
        const noteEl = el.querySelector(':scope > .key-note') || el.querySelector('.key-note');
        if (noteEl && noteEl.textContent) {
          const noteTxt = noteEl.textContent.trim();
          document.querySelectorAll('.ks-key-w, .ks-key-b').forEach(k => {
            const nameEl = k.querySelector('.ks-key-name');
            if (nameEl && nameEl.textContent.trim() === noteTxt) {
              k.classList.add('active', 'arp-step');
            }
          });
        }
      }
    });
  }
  if (Array.isArray(heldCodes)) {
    heldCodes.forEach(code => {
      const el = document.getElementById('key-' + code);
      if (el && !el.classList.contains('control-pad')) {
        el.classList.add('arp-held', 'latched-key');
      }
    });
  }
};

window.updateKeyState = function(code, pressed, latched) {
  const isTrackButton = code >= 18 && code <= 21;
  if (isTrackButton) return;
  const el = document.getElementById('key-' + code);
  if (el) {
    if (pressed) el.dataset.physicallyPressed = 'true';
    else delete el.dataset.physicallyPressed;
    el.classList.toggle('pressed', !!pressed || (el.classList.contains('arp-playing')));
    el.classList.toggle('latched-key', !!latched);

    // Also illuminate key on KeyStep 32 view
    const noteEl = el.querySelector(':scope > .key-note') || el.querySelector('.key-note');
    if (noteEl && noteEl.textContent) {
      const noteTxt = noteEl.textContent.trim();
      const ksKeys = document.querySelectorAll('.ks-key-w, .ks-key-b');
      let foundExact = false;
      for (let i = 0; i < ksKeys.length; i++) {
        const nameEl = ksKeys[i].querySelector('.ks-key-name');
        if (nameEl && nameEl.textContent.trim() === noteTxt) {
          ksKeys[i].classList.toggle('active', !!pressed);
          foundExact = true;
          break;
        }
      }
      // If not exact match, fold octave into 3..5 range
      if (!foundExact) {
        const match = noteTxt.match(/^([A-G][#b]?)(-?\d+)$/);
        if (match) {
          const pitchClass = match[1];
          let oct = parseInt(match[2], 10);
          while (oct < 3) oct += 1;
          while (oct > 5) oct -= 1;
          const foldedName = pitchClass + oct;
          for (let i = 0; i < ksKeys.length; i++) {
            const nameEl = ksKeys[i].querySelector('.ks-key-name');
            if (nameEl && nameEl.textContent.trim() === foldedName) {
              ksKeys[i].classList.toggle('active', !!pressed);
              break;
            }
          }
        }
      }
    }
  }
};

/* ── Arturia KeyStep 32 Hardware Connection & Dynamic Surface Stacking ── */
window.keystepConnected = false;
window._activeKeyStepNotes = {};
window._ksInternalState = {
  mode: 1,
  seqArp: 'arp',
  division: '1/16',
  bpm: 120,
  rate: 64,
  playing: false,
  recording: false,
  hold: false,
  shift: false,
  octave: 0,
  pitchBend: 8192,
  modWheel: 0,
};
try {
  const savedKs = localStorage.getItem('qwertyMidi_ks_state');
  if (savedKs) {
    const parsed = JSON.parse(savedKs);
    Object.assign(window._ksInternalState, parsed);
  }
} catch(e) {}

window.setKeyStepConnected = function(connected) {
  window.keystepConnected = !!connected;
  const ksView = document.getElementById('keystep-view');
  const hudContainer = document.getElementById('hud-container');
  const badge = document.getElementById('keystep-badge') || document.getElementById('nanokey-badge');

  if (ksView) {
    ksView.style.display = connected ? 'flex' : 'none';
  }
  if (hudContainer) {
    if (connected) {
      hudContainer.classList.add('keystep-connected');
      hudContainer.style.height = '600px';
    } else {
      hudContainer.classList.remove('keystep-connected');
      hudContainer.style.height = '280px';
    }
  }
  if (badge) {
    badge.style.display = connected ? 'inline-flex' : 'none';
  }
};
window.setNanokeyConnected = window.setKeyStepConnected;

const ARP_MODE_NAMES = ["1: Up", "2: Down", "3: Inc", "4: Exc", "5: Rand", "6: Order", "7: Up x2", "8: Dwn x2"];
const DIVISION_NAMES = ["1/4", "1/8", "1/16", "1/32", "1/4T", "1/8T", "1/16T", "1/32T"];

// Bpm tempo LED blinking interval
let _ksBpmTimer = null;
function startKsBpmLed(bpm) {
  if (_ksBpmTimer) clearInterval(_ksBpmTimer);
  bpm = bpm || 120;
  const interval = (60 / bpm) * 1000;
  const led = document.getElementById('ks-rate-led');
  if (!led) return;
  _ksBpmTimer = setInterval(() => {
    led.classList.add('flash');
    setTimeout(() => led.classList.remove('flash'), Math.min(100, interval * 0.3));
  }, interval);
}

window.updateKeyStepState = function(controlId, value, pressed, extra) {
  extra = extra || {};
  const ksView = document.getElementById('keystep-view');
  if (!ksView) return;

  if (controlId === 'connection') {
    window.setKeyStepConnected(!!pressed);
    return;
  }

  // Keys: key_<note> (spanning 32 keys 41..72: F to C)
  if (typeof controlId === 'string' && controlId.indexOf('key_') === 0) {
    const rawNote = parseInt(controlId.replace('key_', ''), 10);
    if (!isNaN(rawNote)) {
      if (pressed) {
        window._activeKeyStepNotes[rawNote] = true;
      } else {
        delete window._activeKeyStepNotes[rawNote];
      }

      // Map rawNote into 41..72 window (F to C)
      let mapped = rawNote;
      while (mapped < 41) mapped += 12;
      while (mapped > 72) mapped -= 12;

      let isStillActive = false;
      for (const nStr in window._activeKeyStepNotes) {
        let n = parseInt(nStr, 10);
        while (n < 41) n += 12;
        while (n > 72) n -= 12;
        if (n === mapped) {
          isStillActive = true;
          break;
        }
      }

      const keyEl = document.getElementById('ks-key-' + mapped);
      if (keyEl) {
        keyEl.classList.toggle('active', isStillActive);
      }
    }
    return;
  }

  // Pitch bend
  if (controlId === 'pitch_bend') {
    const pitchVal = value !== null && value !== undefined ? value : 8192;
    window._ksInternalState.pitchBend = pitchVal;
    const thumb = document.getElementById('ks-pitch-thumb');
    const valEl = document.getElementById('ks-pitch-val');
    // pitchVal 0..16383, 8192 is center
    const norm = (16383 - pitchVal) / 16383; // 0 to 1
    if (thumb) thumb.style.top = (norm * 100).toFixed(1) + '%';
    const stDiff = ((pitchVal - 8192) / 8192 * 2).toFixed(1);
    if (valEl) valEl.textContent = (pitchVal === 8192 ? '±0' : (stDiff > 0 ? '+' + stDiff : stDiff));
    return;
  }

  // Modal Shift Mode
  if (controlId === 'shift_mode') {
    const mode = (extra && extra.mode) || 'default';
    const label = (extra && extra.label) || 'DEFAULT';
    const isLatched = !!(extra && extra.latched);
    const color = (extra && extra.color) || '#94a3b8';
    const isActive = mode !== 'default';

    window._ksInternalState.shiftMode = mode;
    window._ksInternalState.shiftLatched = isLatched;

    const pill = document.getElementById('ks-shift-status-pill');
    if (pill) {
      if (!isActive) {
        pill.textContent = 'MOD · CC1';
        pill.className = 'ks-shift-status-pill';
        pill.style.color = '#94a3b8';
        pill.style.borderColor = 'rgba(255, 255, 255, 0.15)';
        pill.style.background = 'rgba(255, 255, 255, 0.08)';
        pill.style.boxShadow = 'none';
      } else {
        pill.textContent = (isLatched ? '🔒 LATCH: ' : 'HOLD: ') + label;
        pill.className = 'ks-shift-status-pill active';
        pill.style.color = color;
        pill.style.borderColor = color;
        pill.style.background = 'rgba(0, 0, 0, 0.5)';
        pill.style.boxShadow = `0 0 10px ${color}`;
      }
    }

    const modNameEl = document.getElementById('ks-mod-name');
    if (modNameEl) {
      modNameEl.textContent = isActive ? label : 'Mod';
      modNameEl.style.color = isActive ? color : '';
    }

    document.querySelectorAll('.ks-key-b').forEach(bKey => {
      const shiftTarget = bKey.dataset.shift;
      const shiftClass = 'ks-shift-' + shiftTarget;
      if (isActive && shiftTarget === mode) {
        bKey.classList.add(shiftClass);
      } else {
        bKey.classList.remove('ks-shift-cutoff', 'ks-shift-reverb', 'ks-shift-delay', 'ks-shift-release', 'ks-shift-volume');
      }
    });
    return;
  }

  // White-Key Harmonic Transposer Lock
  if (controlId === 'transposer_enabled') {
    const isLocked = (value === 1 || value === true || pressed === true);
    window._ksInternalState.transposerEnabled = isLocked;
    const lockBadge = document.getElementById('ks-scale-lock-badge');
    if (lockBadge) {
      lockBadge.textContent = isLocked ? 'SCALE LOCK: ON' : 'SCALE LOCK: OFF';
      lockBadge.classList.toggle('off', !isLocked);
    }
    return;
  }

  // Modulation Wheel (CC 1)
  if (controlId === 'mod_wheel') {
    const modVal = value !== null && value !== undefined ? value : 0;
    window._ksInternalState.modWheel = modVal;
    const fill = document.getElementById('ks-mod-fill');
    const valEl = document.getElementById('ks-mod-val');
    const pct = (modVal / 127 * 100).toFixed(1);
    if (fill) fill.style.height = pct + '%';
    if (valEl) valEl.textContent = modVal;
    if (extra && extra.label) {
      const modNameEl = document.getElementById('ks-mod-name');
      if (modNameEl) {
        modNameEl.textContent = extra.label;
        if (extra.color) modNameEl.style.color = extra.color;
      }
    }
    return;
  }

  // Rate (smooth 0-127) & BPM (30..240 BPM, ~137 BPM at halfway 64)
  if (controlId === 'rate' || controlId === 'bpm') {
    const ksBpmToRate = (b) => {
      const clamped = Math.max(30, Math.min(240, b));
      return Math.round(((clamped - 30) / (240 - 30)) * 127);
    };
    const ksRateToBpm = (r) => {
      const clamped = Math.max(0, Math.min(127, r));
      return Math.round(30 + (clamped / 127) * (240 - 30));
    };

    let rate = extra.rate !== undefined ? extra.rate : (controlId === 'rate' ? value : null);
    let bpm = extra.bpm !== undefined ? extra.bpm : (controlId === 'bpm' ? value : null);
    if (rate === null && bpm !== null) {
      rate = ksBpmToRate(bpm);
    } else if (bpm === null && rate !== null) {
      bpm = ksRateToBpm(rate);
    }
    rate = rate !== null ? rate : 64;
    bpm = bpm !== null ? bpm : 120;
    window._ksInternalState.rate = rate;
    window._ksInternalState.bpm = bpm;
    const valEl = document.getElementById('ks-knob-val-rate');
    const knob = document.getElementById('ks-knob-rate');
    const volPercent = Math.round((rate / 127) * 100);
    if (valEl) valEl.textContent = `Vol ${volPercent}% (${bpm} BPM)`;
    if (knob) {
      const angle = -135 + (rate / 127) * 270;
      knob.style.transform = `rotate(${angle.toFixed(1)}deg)`;
    }
    startKsBpmLed(bpm);
    return;
  }

  // Mode (1..8)
  if (controlId === 'mode') {
    const modeIdx = value !== null && value !== undefined ? value : 1;
    window._ksInternalState.mode = modeIdx;
    const valEl = document.getElementById('ks-knob-val-mode');
    const knob = document.getElementById('ks-knob-mode');
    const isSeq = window._ksInternalState.seqArp === 'seq';
    const name = isSeq ? `Seq ${modeIdx}` : (ARP_MODE_NAMES[modeIdx - 1] || `${modeIdx}`);
    if (valEl) valEl.textContent = name;
    if (knob) {
      const angle = -135 + ((modeIdx - 1) / 7) * 270;
      knob.style.transform = `rotate(${angle.toFixed(1)}deg)`;
    }
    return;
  }

  // Division (1..8: 1/4 -> 1/32, then 1/4T -> 1/32T)
  if (controlId === 'division') {
    const divIdx = value !== null && value !== undefined ? value : 3;
    const valEl = document.getElementById('ks-knob-val-div');
    const knob = document.getElementById('ks-knob-div');
    const name = extra.division || DIVISION_NAMES[divIdx - 1] || '1/16';
    if (valEl) valEl.textContent = name;
    if (knob) {
      const angle = -135 + ((divIdx - 1) / 7) * 270;
      knob.style.transform = `rotate(${angle.toFixed(1)}deg)`;
    }
    return;
  }

  // Seq / Arp Toggle
  if (controlId === 'seq_arp') {
    const isSeq = (extra.mode === 'seq' || value === 1);
    window._ksInternalState.seqArp = isSeq ? 'seq' : 'arp';
    const track = document.getElementById('ks-switch-track');
    if (track) track.classList.toggle('seq', isSeq);
    const modeValEl = document.getElementById('ks-knob-val-mode');
    if (modeValEl) {
      modeValEl.textContent = isSeq ? `Seq ${window._ksInternalState.mode}` : (ARP_MODE_NAMES[window._ksInternalState.mode - 1] || '1: Up');
    }
    return;
  }

  // Transport
  if (controlId === 'transport') {
    const isPlaying = (value === 1 || extra.action === 'play');
    window._ksInternalState.playing = isPlaying;
    const btnPlay = document.getElementById('ks-btn-play');
    const btnStop = document.getElementById('ks-btn-stop');
    if (btnPlay) btnPlay.classList.toggle('active', isPlaying);
    if (btnStop) btnStop.classList.toggle('active', !isPlaying);
    return;
  }

  // Record
  if (controlId === 'record') {
    const isRec = !!pressed;
    window._ksInternalState.recording = isRec;
    const btnRec = document.getElementById('ks-btn-rec');
    if (btnRec) btnRec.classList.toggle('active', isRec);
    return;
  }

  // Hold
  if (controlId === 'hold' || controlId === 'sustain') {
    const isHold = !!pressed;
    window._ksInternalState.hold = isHold;
    const btnHold = document.getElementById('ks-btn-hold');
    if (btnHold) btnHold.classList.toggle('active', isHold);
    return;
  }

  // Shift
  if (controlId === 'shift') {
    const isShift = !!pressed;
    window._ksInternalState.shift = isShift;
    const btnShift = document.getElementById('ks-btn-shift');
    if (btnShift) btnShift.classList.toggle('active', isShift);
    return;
  }

  // Octave
  if (controlId === 'octave') {
    const oct = value !== null && value !== undefined ? value : 0;
    window._ksInternalState.octave = oct;
    const octEl = document.getElementById('ks-oct-val');
    if (octEl) octEl.textContent = 'OCT ' + (oct > 0 ? '+' + oct : oct);
    const btnDown = document.getElementById('ks-btn-oct-down');
    const btnUp = document.getElementById('ks-btn-oct-up');
    if (btnDown) btnDown.classList.toggle('active', oct < 0);
    if (btnUp) btnUp.classList.toggle('active', oct > 0);
    return;
  }

  try {
    localStorage.setItem('qwertyMidi_ks_state', JSON.stringify(window._ksInternalState));
  } catch(e) {}
};
window.updateNanoKeyState = window.updateKeyStepState;

window.syncFullKeyStepState = function(stateObj) {
  if (!stateObj) return;
  if (stateObj.mode !== undefined) window.updateKeyStepState('mode', stateObj.mode);
  if (stateObj.division !== undefined) {
    const divIdx = stateObj.divIdx || (DIVISION_NAMES.indexOf(stateObj.division) + 1) || 3;
    window.updateKeyStepState('division', divIdx, true, { division: stateObj.division });
  }
  if (stateObj.rate !== undefined || stateObj.bpm !== undefined) {
    window.updateKeyStepState('rate', stateObj.rate, true, { rate: stateObj.rate, bpm: stateObj.bpm });
  }
  if (stateObj.seqArp !== undefined) {
    window.updateKeyStepState('seq_arp', stateObj.seqArp === 'seq' ? 1 : 0, true, { mode: stateObj.seqArp });
  }
  if (stateObj.octave !== undefined) window.updateKeyStepState('octave', stateObj.octave);
  if (stateObj.pitchBend !== undefined) window.updateKeyStepState('pitch_bend', stateObj.pitchBend);
  if (stateObj.modWheel !== undefined) window.updateKeyStepState('mod_wheel', stateObj.modWheel);
  if (stateObj.playing !== undefined) window.updateKeyStepState('transport', stateObj.playing ? 1 : 0, stateObj.playing, { action: stateObj.playing ? 'play' : 'stop' });
  if (stateObj.hold !== undefined) window.updateKeyStepState('hold', stateObj.hold ? 127 : 0, stateObj.hold);
  if (stateObj.shift !== undefined) window.updateKeyStepState('shift', stateObj.shift ? 1 : 0, stateObj.shift);
  if (stateObj.transposerEnabled !== undefined) {
    window.updateKeyStepState('transposer_enabled', stateObj.transposerEnabled ? 1 : 0, stateObj.transposerEnabled);
  }
  if (stateObj.shiftModeDef !== undefined || stateObj.activeShiftMode !== undefined || stateObj.latchedShiftMode !== undefined) {
    const def = stateObj.shiftModeDef;
    const isLatched = !!stateObj.latchedShiftMode;
    window.updateKeyStepState('shift_mode', def ? 1 : 0, def !== null, {
      mode: def ? def.id : 'default',
      label: def ? def.label : 'DEFAULT',
      color: def ? def.color : '#94a3b8',
      latched: isLatched
    });
  }
  if (stateObj.connected !== undefined) window.setKeyStepConnected(stateObj.connected);
};

// Interactive event handlers for KeyStep 32 hardware GUI
document.addEventListener('DOMContentLoaded', () => {
  if (window.syncFullKeyStepState && window._ksInternalState) {
    window.syncFullKeyStepState(window._ksInternalState);
  }

  const postMidi = (msg) => {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
      window.webkit.messageHandlers.midiControllerUC.postMessage(msg);
    }
  };

  // 1. Keys interaction (19 white, 13 black)
  document.querySelectorAll('.ks-key-w, .ks-key-b').forEach(key => {
    const noteNum = parseInt(key.dataset.note, 10);
    const trigger = (down) => {
      key.classList.toggle('active', down);
      postMidi({ type: 'keystepKey', note: noteNum, pressed: down, velocity: down ? 100 : 0 });
    };
    key.addEventListener('mousedown', (e) => { e.preventDefault(); trigger(true); });
    key.addEventListener('mouseup', (e) => { e.preventDefault(); trigger(false); });
    key.addEventListener('mouseleave', () => { if (key.classList.contains('active')) trigger(false); });
  });

  // 2. Pitch Strip interaction
  const pitchStrip = document.getElementById('ks-pitch-strip');
  if (pitchStrip) {
    let pitchDragging = false;
    const handlePitch = (e) => {
      const rect = pitchStrip.getBoundingClientRect();
      const clientY = e.clientY || (e.touches && e.touches[0].clientY);
      const norm = Math.max(0, Math.min(1, (clientY - rect.top) / rect.height)); // 0 top (high), 1 bot (low)
      const pitchVal = Math.round(16383 * (1 - norm));
      window.updateKeyStepState('pitch_bend', pitchVal, true);
      postMidi({ type: 'keystepPitch', value: pitchVal });
    };
    pitchStrip.addEventListener('mousedown', (e) => {
      pitchDragging = true;
      handlePitch(e);
      const onMove = (me) => { if (pitchDragging) handlePitch(me); };
      const onUp = () => {
        pitchDragging = false;
        window.removeEventListener('mousemove', onMove);
        window.removeEventListener('mouseup', onUp);
        // Spring back to center
        window.updateKeyStepState('pitch_bend', 8192, true);
        postMidi({ type: 'keystepPitch', value: 8192 });
      };
      window.addEventListener('mousemove', onMove);
      window.addEventListener('mouseup', onUp);
    });
  }

  // 3. Mod Strip interaction
  const modStrip = document.getElementById('ks-mod-strip');
  if (modStrip) {
    let modDragging = false;
    const handleMod = (e) => {
      const rect = modStrip.getBoundingClientRect();
      const clientY = e.clientY || (e.touches && e.touches[0].clientY);
      const norm = Math.max(0, Math.min(1, (rect.bottom - clientY) / rect.height)); // 0 bot, 1 top
      const modVal = Math.round(norm * 127);
      window.updateKeyStepState('mod_wheel', modVal, true);
      postMidi({ type: 'keystepMod', value: modVal });
    };
    modStrip.addEventListener('mousedown', (e) => {
      modDragging = true;
      handleMod(e);
      const onMove = (me) => { if (modDragging) handleMod(me); };
      const onUp = () => {
        modDragging = false;
        window.removeEventListener('mousemove', onMove);
        window.removeEventListener('mouseup', onUp);
      };
      window.addEventListener('mousemove', onMove);
      window.addEventListener('mouseup', onUp);
    });
  }

  // 4. Buttons: Play, Stop, Rec, Tap, Hold, Shift, Oct-, Oct+
  const btnPlay = document.getElementById('ks-btn-play');
  if (btnPlay) btnPlay.addEventListener('click', () => postMidi({ type: 'keystepTransport', action: 'play' }));

  const btnStop = document.getElementById('ks-btn-stop');
  if (btnStop) btnStop.addEventListener('click', () => postMidi({ type: 'keystepTransport', action: 'stop' }));

  const btnRec = document.getElementById('ks-btn-rec');
  if (btnRec) btnRec.addEventListener('click', () => postMidi({ type: 'keystepTransport', action: 'rec' }));

  const btnTap = document.getElementById('ks-btn-tap');
  if (btnTap) btnTap.addEventListener('click', () => postMidi({ type: 'keystepTransport', action: 'tap' }));

  const btnHold = document.getElementById('ks-btn-hold');
  if (btnHold) btnHold.addEventListener('click', () => postMidi({ type: 'keystepHold' }));

  const btnShift = document.getElementById('ks-btn-shift');
  if (btnShift) btnShift.addEventListener('click', () => postMidi({ type: 'keystepShift' }));

  const btnOctDown = document.getElementById('ks-btn-oct-down');
  if (btnOctDown) btnOctDown.addEventListener('click', () => postMidi({ type: 'keystepOctave', dir: -1 }));

  const btnOctUp = document.getElementById('ks-btn-oct-up');
  if (btnOctUp) btnOctUp.addEventListener('click', () => postMidi({ type: 'keystepOctave', dir: 1 }));

  const scaleLockBadge = document.getElementById('ks-scale-lock-badge');
  if (scaleLockBadge) {
    scaleLockBadge.addEventListener('click', () => {
      postMidi({ type: 'keystepTransposerToggle' });
    });
  }

  const shiftStatusPill = document.getElementById('ks-shift-status-pill');
  if (shiftStatusPill) {
    shiftStatusPill.addEventListener('click', () => {
      postMidi({ type: 'keystepShiftMode', mode: 'clear' });
    });
  }

  // 5. Knobs and Switch
  const switchSeqArp = document.getElementById('ks-switch-seq-arp');
  if (switchSeqArp) switchSeqArp.addEventListener('click', () => postMidi({ type: 'keystepSeqArp' }));

  const knobMode = document.getElementById('ks-knob-mode-unit');
  if (knobMode) {
    knobMode.addEventListener('click', () => {
      let nextMode = (window._ksInternalState.mode % 8) + 1;
      postMidi({ type: 'keystepMode', mode: nextMode });
    });
    knobMode.addEventListener('wheel', (e) => {
      e.preventDefault();
      let delta = e.deltaY < 0 ? 1 : -1;
      let curMode = window._ksInternalState.mode || 1;
      let nextMode = ((curMode - 1 + delta + 8) % 8) + 1;
      postMidi({ type: 'keystepMode', mode: nextMode });
    }, { passive: false });
  }

  const knobDiv = document.getElementById('ks-knob-div-unit');
  if (knobDiv) {
    knobDiv.addEventListener('click', () => {
      let curIdx = DIVISION_NAMES.indexOf(document.getElementById('ks-knob-val-div')?.textContent) + 1;
      if (curIdx < 1) curIdx = 1;
      let nextDiv = (curIdx % 8) + 1;
      postMidi({ type: 'keystepDivision', division: nextDiv });
    });
    knobDiv.addEventListener('wheel', (e) => {
      e.preventDefault();
      let delta = e.deltaY < 0 ? 1 : -1;
      let curIdx = DIVISION_NAMES.indexOf(document.getElementById('ks-knob-val-div')?.textContent) + 1;
      if (curIdx < 1) curIdx = 3;
      let nextDiv = ((curIdx - 1 + delta + 8) % 8) + 1;
      postMidi({ type: 'keystepDivision', division: nextDiv });
    }, { passive: false });
  }

  // Smooth Rate 0-127 knob with wheel & drag
  const knobRate = document.getElementById('ks-knob-rate-unit');
  if (knobRate) {
    let rateDragging = false;
    let startY = 0;
    let startRate = 64;

    const ksRateToBpm = (r) => {
      const clamped = Math.max(0, Math.min(127, r));
      return Math.round(30 + (clamped / 127) * (240 - 30));
    };

    const setSmoothRate = (newRate) => {
      const clampedRate = Math.max(0, Math.min(127, Math.round(newRate)));
      const bpm = ksRateToBpm(clampedRate);
      window.updateKeyStepState('rate', clampedRate, true, { rate: clampedRate, bpm: bpm });
      postMidi({ type: 'keystepRate', rate: clampedRate, bpm: bpm });
    };

    knobRate.addEventListener('wheel', (e) => {
      e.preventDefault();
      const delta = e.deltaY < 0 ? (e.shiftKey ? 5 : 2) : (e.shiftKey ? -5 : -2);
      const curRate = window._ksInternalState.rate !== undefined ? window._ksInternalState.rate : 64;
      setSmoothRate(curRate + delta);
    }, { passive: false });

    knobRate.addEventListener('mousedown', (e) => {
      rateDragging = true;
      startY = e.clientY;
      startRate = window._ksInternalState.rate !== undefined ? window._ksInternalState.rate : 64;
      const onMove = (me) => {
        if (!rateDragging) return;
        const diff = (startY - me.clientY) * 0.8;
        setSmoothRate(startRate + diff);
      };
      const onUp = () => {
        rateDragging = false;
        window.removeEventListener('mousemove', onMove);
        window.removeEventListener('mouseup', onUp);
      };
      window.addEventListener('mousemove', onMove);
      window.addEventListener('mouseup', onUp);
    });
  }
});
</script>
</body>
</html>

]]

return HTML_UI_CONTENT
