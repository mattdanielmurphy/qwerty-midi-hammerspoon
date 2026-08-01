local HTML_UI_CONTENT = [[
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
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
    background: rgba(24, 22, 20, 0.96);
    border: 2px solid rgba(70, 64, 58, 0.7);
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
    background: rgba(30, 26, 20, 0.96);
    border: 1.5px solid #d4a359;
    border-radius: 8px;
    padding: 6px 20px;
    box-shadow: 0 0 0 1px rgba(212, 163, 89, 0.4), 0 0 12px rgba(212, 163, 89, 0.35);
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
    color: #b5aba0;
    text-transform: uppercase;
    margin-bottom: 0;
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
    color: #d4a359;
    white-space: nowrap;
  }

  /* Dynamic Mod Wheel Glow — always driven by --mod-intensity (0.00–1.00) */
  #hud-container {
    box-shadow:
      0 0 calc(var(--mod-intensity) * 18px) rgba(212, 163, 89, calc(var(--mod-intensity) * 0.6)),
      inset 0 0 calc(var(--mod-intensity) * 24px) rgba(212, 163, 89, calc(var(--mod-intensity) * 0.35));
    border-color: rgba(212, 163, 89, calc(0.25 + var(--mod-intensity) * 0.6));
    transition: box-shadow 0.08s ease, border-color 0.08s ease, height 0.25s cubic-bezier(0.16, 1, 0.3, 1);
    border-radius: 14px;
  }
  #hud-container.edit-mode-active {
    height: 460px;
  }

  .mod-gradient-overlay {
    position: absolute;
    top: 0; left: 0; right: 0; bottom: 0;
    border-radius: inherit;
    overflow: hidden;
    pointer-events: none;
    background: linear-gradient(
      180deg,
      rgba(212, 163, 89, calc(var(--mod-intensity) * var(--mod-intensity) * 0.28)) 0%,
      rgba(200, 140, 60, 0) 60%
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

  .arp-btn.arp-latch {
    background: rgba(212, 163, 89, 0.6);
    box-shadow: 0 0 12px rgba(212, 163, 89, 0.8), inset 0 0 4px rgba(212, 163, 89, 0.3);
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
    background: rgba(200, 190, 180, 0.08);
    border-color: rgba(100, 95, 90, 0.6);
  }
  .key-pad.control-pad:active, .key-pad.control-pad.pressed {
    background: rgba(200, 190, 180, 0.2);
  }

  .key-pad.control-pad .key-note {
    color: #a09588;
    font-size: 9.5px;
  }

  /* Correlated Control Pairs & Special Controls */
  .key-pad.ctrl-trnsp { border-color: rgba(94, 162, 235, 0.45); }
  .key-pad.ctrl-trnsp .key-note { color: #8abef2; font-weight: 600; }

  .key-pad.ctrl-root { border-color: rgba(220, 120, 100, 0.45); }
  .key-pad.ctrl-root .key-note { color: #e69d90; font-weight: 600; }

  .key-pad.ctrl-mode { border-color: rgba(212, 163, 89, 0.45); }
  .key-pad.ctrl-mode .key-note { color: #d4a359; font-weight: 600; }

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

  .key-pad.ctrl-arp, .key-pad.ctrl-arptop, .key-pad.ctrl-arpbot { border-color: rgba(212, 163, 89, 0.45); }
  .key-pad.ctrl-arp .key-note, .key-pad.ctrl-arptop .key-note, .key-pad.ctrl-arpbot .key-note { color: #d4a359; font-weight: 600; }

  .key-pad.ctrl-bpmedit, .key-pad.ctrl-rand, .key-pad.ctrl-panic, .key-pad.ctrl-reset { border-color: rgba(150, 140, 130, 0.4); }
  .key-pad.ctrl-bpmedit .key-note, .key-pad.ctrl-rand .key-note, .key-pad.ctrl-panic .key-note, .key-pad.ctrl-reset .key-note { color: #b5aba0; font-weight: 500; }

  .key-pad.dummy-pad {
    opacity: 0.45;
    cursor: default;
    background: rgba(20, 18, 16, 0.7);
    border-color: rgba(50, 44, 38, 0.6);
  }

  .key-pad.sustain-active {
    background: rgba(212, 163, 89, 0.25);
    border-color: #d4a359;
  }

  .key-pad.sustain-active .key-note {
    color: #d4a359;
    font-weight: 600;
  }

  .key-pad {
    position: relative;
  }

  /* Latched key: just a subtle border hint — background removed so root/3rd/5th colors remain visible */
  .key-pad.latched-key {
    border-color: rgba(94, 162, 235, 0.35) !important;
  }

  .key-pad.latched-key:active, .key-pad.latched-key.pressed {
    background: rgba(212, 163, 89, 0.35) !important;
    border-color: rgba(240, 190, 90, 1.0) !important;
    box-shadow: 0 0 12px rgba(240, 190, 90, 0.6), inset 0 0 8px rgba(240, 190, 90, 0.3);
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

  #hud-container.edit-mode-active .keyboard-grid {
    max-width: calc(980px - 272px);
    transition: max-width 0.25s cubic-bezier(0.16, 1, 0.3, 1);
    gap: 4px;
  }

  #hud-container.edit-mode-active .keyboard-row {
    gap: 4px;
  }

  #hud-container.edit-mode-active .key-pad {
    transition: width 0.25s cubic-bezier(0.16, 1, 0.3, 1), 
                height 0.25s cubic-bezier(0.16, 1, 0.3, 1),
                font-size 0.25s cubic-bezier(0.16, 1, 0.3, 1);
  }

  /* Compact key pads when drawer is open */
  #hud-container.edit-mode-active .key-pad {
    width: 48px;
    min-width: 48px;
    flex-shrink: 0;
    height: 44px;
    gap: 0;
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

  /* Hide split halves by default in single-label performance mode */
  .key-pad .key-half {
    display: none;
  }

  /* ===== DUAL-STACKED KEY RENDERING (EDIT MODE & STACKED PERFORMANCE MODE) ===== */
  #hud-container.edit-mode-active .key-pad:not(.dummy-pad),
  #hud-container.stacked-labels-active .key-pad:not(.dummy-pad) {
    display: flex;
    flex-direction: column;
    justify-content: stretch;
    align-items: stretch;
    overflow: hidden;
    padding: 0;
    position: relative;
  }
  /* Hide original single center key-note label in key pads when stacked */
  #hud-container.edit-mode-active .key-pad:not(.dummy-pad) > .key-note,
  #hud-container.stacked-labels-active .key-pad:not(.dummy-pad) > .key-note {
    display: none;
  }
  #hud-container.edit-mode-active .key-pad:not(.dummy-pad) > .key-code,
  #hud-container.stacked-labels-active .key-pad:not(.dummy-pad) > .key-code {
    position: absolute;
    top: 2px;
    left: 3px;
    z-index: 3;
    font-size: 8px;
    font-weight: 700;
    color: rgba(242, 234, 225, 0.75);
    background: rgba(0, 0, 0, 0.5);
    padding: 0 3px;
    border-radius: 3px;
    pointer-events: none;
  }
  #hud-container.edit-mode-active .key-pad:not(.dummy-pad) > .key-row-icon,
  #hud-container.stacked-labels-active .key-pad:not(.dummy-pad) > .key-row-icon {
    display: none !important;
  }
  #hud-container.edit-mode-active .key-pad .key-half,
  #hud-container.stacked-labels-active .key-pad .key-half {
    display: flex;
    flex: 1;
    align-items: center;
    justify-content: center;
    width: 100%;
    min-height: 0;
    position: relative;
    padding: 0 2px;
    box-sizing: border-box;
  }
  .key-pad .key-half-top {
    border-bottom: 1px solid rgba(212, 163, 89, 0.15);
    background: rgba(138, 190, 242, 0.06);
  }
  .key-pad .key-half-top .key-note {
    color: #8abef2;
    font-size: 7.5px;
    font-weight: 600;
    line-height: 1.1;
    margin: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 95%;
    pointer-events: none;
  }
  .key-pad .key-half-bottom {
    background: rgba(242, 234, 225, 0.02);
  }
  .key-pad .key-half-bottom .key-note {
    color: #f2eae1;
    font-size: 8px;
    font-weight: 600;
    line-height: 1.1;
    margin: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 95%;
    pointer-events: none;
  }
  .key-pad .key-half .half-label {
    font-size: 5.5px;
    font-weight: 700;
    letter-spacing: 0.5px;
    text-transform: uppercase;
    position: absolute;
    right: 2px;
    bottom: 1px;
    color: rgba(140, 130, 115, 0.4);
    pointer-events: none;
  }
  .key-pad .key-half-top .half-label {
    color: rgba(138, 190, 242, 0.4);
    bottom: auto;
    top: 1px;
    left: auto;
    right: 2px;
  }
  /* Shift Key Illumination / Highlight */
  #hud-container.shift-active-labels .key-half-top,
  #hud-container.shift-top-highlight .key-half-top,
  .key-pad.shift-top-highlight .key-half-top {
    background: rgba(138, 190, 242, 0.25) !important;
    box-shadow: inset 0 0 8px rgba(138, 190, 242, 0.4);
  }
  #hud-container.shift-active-labels .key-half-top .key-note,
  #hud-container.shift-top-highlight .key-half-top .key-note,
  .key-pad.shift-top-highlight .key-half-top .key-note {
    color: #ffffff !important;
    text-shadow: 0 0 6px rgba(138, 190, 242, 0.9);
    font-weight: 700;
  }
  /* Highlight for drop targets on halves */
  #hud-container.edit-mode-active .key-half.drag-over-target {
    background: rgba(212, 163, 89, 0.35) !important;
    box-shadow: inset 0 0 12px #d4a359 !important;
    border-radius: 4px;
    z-index: 99 !important;
  }
  #hud-container.edit-mode-active.shift-assign-active .key-half-top {
    background: rgba(94, 162, 235, 0.12);
    border-bottom: 1px solid rgba(94, 162, 235, 0.4);
  }
  #hud-container.edit-mode-active.shift-assign-active .key-half-top .key-note {
    color: #8abef2;
  }

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
      <button id="arp-power-btn" class="arp-btn">ARP: OFF</button>
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
      <div id="gate-editor" class="bpm-editor" title="Arp Note Length / Gate">
        <button id="gate-down" class="bpm-arrow-btn">&#9662;</button>
        <span id="gate-value" class="bpm-display">80%</span>
        <button id="gate-up" class="bpm-arrow-btn">&#9652;</button>
      </div>
      <div id="bpm-editor" class="bpm-editor">
        <button id="bpm-down" class="bpm-arrow-btn">&#9662;</button>
        <span id="bpm-value" class="bpm-display">120 BPM</span>
        <button id="bpm-up" class="bpm-arrow-btn">&#9652;</button>
      </div>
      <button id="logic-sync-btn" class="badge-small" title="Sync BPM to active Logic Pro session">SYNC: ON</button>
      <button id="edit-mode-btn" class="badge-small edit-btn" title="Toggle Drag & Drop Key Layout Editor">EDIT KEYS</button>
      <div id="mod-wheel-widget">
        <div id="mod-wheel-track"><div id="mod-wheel-fill"></div></div>
        <div id="mod-wheel-label">MOD 0</div>
      </div>
      <div id="status-text" class="status-info"></div>
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

    <!-- Slide-Out Action Library Drawer for Layout Editor -->
    <div id="action-library-drawer" class="drawer-panel">
      <div id="drawer-header" class="drawer-header">
        <div class="drawer-title">
          <span>ACTION LIBRARY</span>
          <span class="drawer-subtitle">Drag action to key slot or swap keys</span>
        </div>
        <div class="drawer-header-actions">
          <!-- shift mode toggle removed -->
          <button id="undo-layout-btn" class="drawer-icon-btn disabled" title="Undo (Cmd+Z)">&#x21A9;</button>
          <button id="redo-layout-btn" class="drawer-icon-btn disabled" title="Redo (Cmd+Shift+Z)">&#x21AA;</button>
          <button id="close-drawer-btn" class="drawer-close-btn" title="Close Drawer">&times;</button>
        </div>
      </div>

      <!-- Layout Presets Toolbar -->
      <div id="preset-bar-container" class="preset-bar">
        <div class="preset-label-row">
          <span class="preset-bar-title">LAYOUT PRESET</span>
          <span id="preset-modified-badge" class="preset-modified-badge hidden">• Modified</span>
        </div>
        <div class="preset-controls-row">
          <select id="preset-select" class="preset-dropdown" title="Select Layout Preset"></select>
          <button id="preset-save-as-btn" class="drawer-icon-btn" title="Save As New Preset" style="font-size:9px;padding:1px 4px;">+ Save</button>
          <button id="preset-rename-btn" class="drawer-icon-btn" title="Rename Preset">✏️</button>
          <button id="preset-duplicate-btn" class="drawer-icon-btn" title="Duplicate Preset">📋</button>
          <button id="preset-delete-btn" class="drawer-icon-btn" title="Delete Preset">🗑️</button>
        </div>
      </div>

      <input type="text" id="drawer-search-input" class="drawer-search-input" placeholder="Search actions..." />
      <div id="drawer-categories-container" class="drawer-content"></div>
      <div class="drawer-footer">
        <button id="save-layout-btn" class="drawer-action-btn primary disabled">Save</button>
        <button id="reset-layout-btn" class="drawer-action-btn warning">Reset</button>
        <button id="cancel-layout-btn" class="drawer-action-btn secondary">Cancel</button>
      </div>
    </div>
  </div>

  <!-- Selection Marquee Box -->
  <div id="selection-marquee"></div>

  <!-- Right-Click Context Menu for Selected Keys -->
  <div id="key-context-menu">
    <div class="ctx-item" data-action="revert-note">
      <span class="ctx-icon">🎵</span> Revert to Note (Clear Action)
    </div>
    <div class="ctx-separator"></div>
    <div class="ctx-item danger" data-action="deselect-all">
      <span class="ctx-icon">✕</span> Deselect All
    </div>
  </div>

  <!-- Preset Modal Dialog Overlay -->
  <div id="preset-modal-overlay" class="preset-modal-overlay hidden">
    <div class="preset-modal-card">
      <div id="preset-modal-title" class="preset-modal-title">Save Preset As</div>
      <input type="text" id="preset-modal-input" class="preset-modal-input" placeholder="Preset name..." />
      <div class="preset-modal-actions">
        <button id="preset-modal-cancel" class="drawer-action-btn secondary">Cancel</button>
        <button id="preset-modal-confirm" class="drawer-action-btn primary">Save</button>
      </div>
    </div>
  </div>

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
      { code: 18, keyLabel: "1", isControl: true, noteLabel: "Top Arp" },
      { code: 19, keyLabel: "2", isControl: true, noteLabel: "Bot Arp" },
      { code: 20, keyLabel: "3", isControl: true, noteLabel: "Dir -" },
      { code: 21, keyLabel: "4", isControl: true, noteLabel: "Dir +" },
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

  // ===== TEXT INPUT FOCUS FIX =====
  function postTextInputFocus(focused) {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
      window.webkit.messageHandlers.midiControllerUC.postMessage({ type: 'textInputFocus', focused: focused });
    }
  }

  // ===== END KEY SELECTION VARS =====

  function initGrid(layout) {
    try {
      const l = (layout && (layout.number || layout.upper || layout.home || layout.lower)) ? layout : LAYOUT_DATA;
      ['number', 'upper', 'home', 'lower'].forEach(rowName => {
        const rowEl = document.getElementById('row-' + rowName);
        if (!rowEl) return;
        if (l[rowName] && Array.isArray(l[rowName]) && l[rowName].length > 0) {
          rowEl.textContent = '';
          l[rowName].forEach(k => {
            const pad = document.createElement('div');
            pad.id = 'key-' + k.code;
            pad.className = 'key-pad ' + (k.isControl ? 'control-pad' : '') + (k.isDummy ? ' dummy-pad' : '');
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

            // ===== VERTICAL SPLIT HALVES for Edit Mode =====
            const builtIn = typeof getBuiltInKey !== 'undefined' ? getBuiltInKey(k.code) || {} : {};
            const halfTop = document.createElement('div');
            halfTop.className = 'key-half key-half-top';
            halfTop.dataset.half = 'shift';
            const noteTop = document.createElement('span');
            noteTop.className = 'key-note';
            noteTop.textContent = k.shiftLabel || builtIn.shiftLabel || k.noteLabel || k.keyLabel || '';
            const labelTop = document.createElement('span');
            labelTop.className = 'half-label';
            labelTop.textContent = '⇧';
            halfTop.appendChild(noteTop);
            halfTop.appendChild(labelTop);
            pad.appendChild(halfTop);

            const halfBottom = document.createElement('div');
            halfBottom.className = 'key-half key-half-bottom';
            halfBottom.dataset.half = 'normal';
            const noteBot = document.createElement('span');
            noteBot.className = 'key-note';
            noteBot.textContent = k.noteLabel || builtIn.noteLabel || k.keyLabel || '';
            const labelBot = document.createElement('span');
            labelBot.className = 'half-label';
            labelBot.textContent = '⇥';
            halfBottom.appendChild(noteBot);
            halfBottom.appendChild(labelBot);
            pad.appendChild(halfBottom);

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
              actionName: currentActionName
            };
            e.dataTransfer.setData('application/json', JSON.stringify(payload));
            e.dataTransfer.setData('text/plain', JSON.stringify(payload));
            draggedItemData = payload;
            pad.classList.add('dragging-source');
          });

          pad.addEventListener('dragend', () => {
            pad.classList.remove('dragging-source');
            draggedItemData = null;
            document.querySelectorAll('.key-half.drag-over-target, .key-pad.drag-over-target').forEach(el => el.classList.remove('drag-over-target'));
          });

          // Helper to add dragover/dragleave/drop to a half
          function setupDropHandlers(halfEl, isShift) {
            halfEl.addEventListener('dragover', (e) => {
              if (!isEditMode || k.isDummy) return;
              e.preventDefault();
              e.dataTransfer.dropEffect = 'move';
              if (!halfEl.classList.contains('drag-over-target')) {
                halfEl.classList.add('drag-over-target');
              }
            });

            halfEl.addEventListener('dragleave', () => {
              halfEl.classList.remove('drag-over-target');
            });

            halfEl.addEventListener('drop', (e) => {
              if (!isEditMode || k.isDummy) return;
              e.preventDefault();
              e.stopPropagation();
              halfEl.classList.remove('drag-over-target');

              let rawData = e.dataTransfer.getData('application/json') || e.dataTransfer.getData('text/plain');
              let data = null;
              if (rawData) {
                try { data = JSON.parse(rawData); } catch(err) {}
              }
              if (!data && draggedItemData) data = draggedItemData;
              if (!data) return;

              if (data.type === 'action') {
                assignActionToKey(k.code, data.action, isShift);
                pad.classList.add('just-updated-glow');
                setTimeout(() => pad.classList.remove('just-updated-glow'), 600);
                showSpotlight({
                  title: 'KEY ASSIGNED',
                  val: 'Key [' + k.keyLabel + '] (' + (isShift ? 'Shift' : 'Normal') + ') → ' + data.action.name,
                  sub: 'Unsaved changes'
                });
                setHasUnsavedChanges(true);
              } else if (data.type === 'keyslot') {
                if (data.code !== k.code) {
                  swapKeyBindings(data.code, k.code);
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
          }

          setupDropHandlers(halfTop, true);   // shift half
          setupDropHandlers(halfBottom, false); // normal half

          rowEl.appendChild(pad);
        });
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
          const noteEl = pad.querySelector(':scope > .key-note');
          if (noteEl) {
            // If shift mode active, show shift name; fall back to normal name if no shift defined
            noteEl.textContent = isShift
              ? (binding.shiftName || binding.shiftAction || binding.name || '')
              : (binding.name || binding.shiftName || binding.shiftAction || '');
          }
          // Update vertical split halves
          const builtIn = typeof getBuiltInKey !== 'undefined' ? getBuiltInKey(code) || {} : {};
          const halfTop = pad.querySelector('.key-half-top .key-note');
          if (halfTop) halfTop.textContent = binding.shiftName || binding.shiftAction || builtIn.shiftLabel || builtIn.noteLabel || builtIn.keyLabel || '';
          const halfBottom = pad.querySelector('.key-half-bottom .key-note');
          if (halfBottom) halfBottom.textContent = binding.name || binding.action || builtIn.noteLabel || builtIn.keyLabel || '';
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
      if (editBtn) editBtn.classList.add('active');
      if (drawer) drawer.classList.add('active');

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
      if (drawer) drawer.classList.remove('active');

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
          if (halfTop) halfTop.textContent = binding.shiftName || binding.shiftAction || builtIn.shiftLabel || '';
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
      const noteEl = pad.querySelector(':scope > .key-note');
      if (!isShift) {
        if (!shiftModeActive && noteEl) noteEl.textContent = actionObj.name;
        pad.className = 'key-pad control-pad ' + (actionObj.typeClass || '');
      } else if (shiftModeActive) {
        if (noteEl) noteEl.textContent = actionObj.name;
      }
      // Update vertical split halves
      const builtIn = typeof getBuiltInKey !== 'undefined' ? getBuiltInKey(code) || {} : {};
      const halfTop = pad.querySelector('.key-half-top .key-note');
      if (halfTop) halfTop.textContent = currentWorkingLayout[code] && (currentWorkingLayout[code].shiftName || currentWorkingLayout[code].shiftAction) || builtIn.shiftLabel || '';
      const halfBottom = pad.querySelector('.key-half-bottom .key-note');
      if (halfBottom) halfBottom.textContent = currentWorkingLayout[code] && (currentWorkingLayout[code].name || currentWorkingLayout[code].action) || builtIn.noteLabel || builtIn.keyLabel || '';
      // Always set bottom note when assigning normal action
      if (!isShift && halfBottom) halfBottom.textContent = actionObj.name;
      // Always set top note when assigning shift action
      if (isShift && halfTop) halfTop.textContent = actionObj.name;
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

    const select = document.getElementById('preset-select');
    if (!select) return;

    select.textContent = '';
    activePresetsList.forEach(p => {
      const opt = document.createElement('option');
      opt.value = p.id;
      opt.textContent = p.name + (p.isBuiltin ? ' (Default)' : '');
      if (p.id === currentActivePresetId) opt.selected = true;
      select.appendChild(opt);
    });

    const activePreset = activePresetsList.find(p => p.id === currentActivePresetId);
    const isBuiltin = activePreset ? activePreset.isBuiltin : (currentActivePresetId === 'default');

    const renameBtn = document.getElementById('preset-rename-btn');
    const deleteBtn = document.getElementById('preset-delete-btn');

    if (renameBtn) {
      renameBtn.disabled = isBuiltin;
      renameBtn.classList.toggle('disabled', isBuiltin);
    }
    if (deleteBtn) {
      deleteBtn.disabled = isBuiltin;
      deleteBtn.classList.toggle('disabled', isBuiltin);
    }
  }

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
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiController) {
          window.webkit.messageHandlers.midiController.postMessage({ type: 'hoverScrollable', state: true });
        }
      });
      drawerContainer.addEventListener('mouseleave', function() {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiController) {
          window.webkit.messageHandlers.midiController.postMessage({ type: 'hoverScrollable', state: false });
        }
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

    // Gate Editor handlers
    let isGateDragging = false;
    let gateDragStartY = 0;
    let gateDragAccum = 0;
    let gateBtnTimer = null;
    let gateBtnInterval = null;
    let gateBtnDirection = 0;

    const gateValue = document.getElementById('gate-value');
    if (gateValue) {
      gateValue.style.cursor = 'ns-resize';
      gateValue.addEventListener('mousedown', (e) => {
        e.stopPropagation();
        e.preventDefault();
        isGateDragging = true;
        gateDragStartY = e.clientY;
        gateDragAccum = 0;
      });
    }

    function stopGateRepeat() {
      if (gateBtnTimer) { clearTimeout(gateBtnTimer); gateBtnTimer = null; }
      if (gateBtnInterval) { clearInterval(gateBtnInterval); gateBtnInterval = null; }
      gateBtnDirection = 0;
    }

    function startGateRepeat(direction) {
      stopGateRepeat();
      gateBtnDirection = direction;
      const sendStep = () => {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.midiControllerUC) {
          window.webkit.messageHandlers.midiControllerUC.postMessage({
            type: gateBtnDirection > 0 ? 'gateUp' : 'gateDown'
          });
        }
      };
      sendStep();

      gateBtnTimer = setTimeout(() => {
        gateBtnInterval = setInterval(() => {
          sendStep();
        }, 80);
      }, 350);
    }

    ['gate-up', 'gate-down'].forEach(id => {
      const btn = document.getElementById(id);
      if (btn) {
        const dir = id === 'gate-up' ? 1 : -1;
        btn.addEventListener('mousedown', (e) => {
          e.stopPropagation();
          e.preventDefault();
          startGateRepeat(dir);
        });
        btn.addEventListener('mouseup', stopGateRepeat);
        btn.addEventListener('mouseleave', stopGateRepeat);
      }
    });

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
        setEditMode(false);
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

    titleEl.textContent = spotlight.title || '';
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
            arpPowerBtn.textContent = 'ARP: LATCH';
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

      if (data.arpGatePercent !== undefined) {
        const gateVal = document.getElementById('gate-value');
        if (gateVal) gateVal.textContent = data.arpGatePercent + '%';
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

      if (data.keys) {
        for (const [code, k] of Object.entries(data.keys)) {
          const el = document.getElementById('key-' + code);
          if (el) {
            const noteEl = el.querySelector(':scope > .key-note');
            if (noteEl) {
              if (shiftModeActive && (currentWorkingLayout || {})[code]) {
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
            el.className = 'key-pad ' + (k.isControl ? 'control-pad ' : '') + (k.typeClass || '');
            if (k.latched) el.classList.add('latched-key');
            if (k.pressed) el.classList.add('pressed');
            if (k.sustainActive) el.classList.add('sustain-active');
            // Arp dot indicators: arp-held = pitch is in pool, arp-playing = actively sounding
            if (k.arpHeld) el.classList.add('arp-held');
            if (k.arpPlaying) el.classList.add('arp-playing');

            const isShift = data.shiftHeld || shiftModeActive;
            const effAction = isShift ? (k.shiftAction || k.action) : k.action;

            const iconEl = el.querySelector('.key-row-icon');
            if (iconEl) {
              iconEl.classList.remove('top-active', 'bottom-active', 'both-active');
              if (effAction === 'topOctDown' || effAction === 'topOctUp' || effAction === 'topVolDown' || effAction === 'topVolUp' || effAction === 'arpTopToggle') {
                iconEl.classList.add('top-active');
              } else if (effAction === 'botVolDown' || effAction === 'botVolUp' || effAction === 'arpBottomToggle' || effAction === 'botOctDown' || effAction === 'botOctUp') {
                iconEl.classList.add('bottom-active');
              } else if (effAction === 'octaveDown' || effAction === 'octaveUp' || effAction === 'volDown' || effAction === 'volUp') {
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
window.updateKeyState = function(code, pressed, latched) {
  const el = document.getElementById('key-' + code);
  if (el) {
    if (pressed) el.classList.add('pressed');
    else el.classList.remove('pressed');
    if (latched) el.classList.add('latched-key');
    else el.classList.remove('latched-key');
  }
};

</script>
</body>
</html>

]]

return HTML_UI_CONTENT
