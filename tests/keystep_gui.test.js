import { expect, test } from 'bun:test';

const source = await Bun.file(new URL('../src/web/index.html', import.meta.url)).text();

test('KeyStep 32 hardware silhouette and controls exist in WebKit HUD', () => {
  // Master container and badge
  expect(source).toContain('id="keystep-badge"');
  expect(source).toContain('id="keystep-view"');
  expect(source).toContain('.keystep-view');
  expect(source).toContain('.ks-control-bay');
  expect(source).toContain('.ks-keybed-bay');

  // Brand header & connection status dot
  expect(source).toContain('ARTURIA');
  expect(source).toContain('KeyStep 32');
  expect(source).toContain('id="ks-status-dot"');

  // Knobs & Switch
  expect(source).toContain('id="ks-switch-seq-arp"');
  expect(source).toContain('id="ks-knob-mode-unit"');
  expect(source).toContain('id="ks-knob-div-unit"');
  expect(source).toContain('id="ks-knob-rate-unit"');
  expect(source).toContain('id="ks-rate-led"');

  // Transport & Function buttons
  expect(source).toContain('id="ks-btn-stop"');
  expect(source).toContain('id="ks-btn-play"');
  expect(source).toContain('id="ks-btn-rec"');
  expect(source).toContain('id="ks-btn-tap"');
  expect(source).toContain('id="ks-btn-shift"');
  expect(source).toContain('id="ks-btn-hold"');
  expect(source).toContain('id="ks-btn-oct-down"');
  expect(source).toContain('id="ks-btn-oct-up"');
  expect(source).toContain('id="ks-oct-val"');

  // Touch Strips
  expect(source).toContain('id="ks-pitch-strip"');
  expect(source).toContain('id="ks-pitch-thumb"');
  expect(source).toContain('id="ks-pitch-val"');
  expect(source).toContain('id="ks-mod-strip"');
  expect(source).toContain('id="ks-mod-fill"');
  expect(source).toContain('id="ks-mod-val"');
});

test('KeyStep 32 has 32 slimkeys with exact note ranges 48..79', () => {
  // 19 White keys: C3(48), D3(50), E3(52), F3(53), G3(55), A3(57), B3(59), C4(60), ... G5(79)
  const whiteNotes = [48, 50, 52, 53, 55, 57, 59, 60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79];
  expect(whiteNotes.length).toBe(19);
  for (const n of whiteNotes) {
    expect(source).toContain(`id="ks-key-${n}"`);
  }

  // 13 Black keys: C#3(49), D#3(51), F#3(54), G#3(56), A#3(58), C#4(61), ... F#5(78)
  const blackNotes = [49, 51, 54, 56, 58, 61, 63, 66, 68, 70, 73, 75, 78];
  expect(blackNotes.length).toBe(13);
  for (const n of blackNotes) {
    expect(source).toContain(`id="ks-key-${n}"`);
  }
});

test('Dynamic stacking expands HUD container to 600px when connected', () => {
  expect(source).toContain('#hud-container.keystep-connected');
  expect(source).toContain('height: 600px !important;');
  expect(source).toContain('window.setKeyStepConnected = function(connected)');
});

test('KeyStep state dispatcher and bidirectional key illumination are wired', () => {
  expect(source).toContain('window.updateKeyStepState = function(controlId, value, pressed, extra)');
  expect(source).toContain("controlId === 'pitch_bend'");
  expect(source).toContain("controlId === 'mod_wheel'");
  expect(source).toContain("controlId === 'bpm'");
  expect(source).toContain("controlId === 'mode'");
  expect(source).toContain("controlId === 'division'");
  expect(source).toContain("controlId === 'seq_arp'");
  expect(source).toContain("controlId === 'transport'");
  expect(source).toContain("controlId === 'record'");
  expect(source).toContain("controlId === 'hold'");
  expect(source).toContain("controlId === 'shift'");
  expect(source).toContain("controlId === 'octave'");

  // QWERTY and Arp illumination on KeyStep keys
  expect(source).toContain("document.querySelectorAll('.ks-key-w, .ks-key-b')");
  expect(source).toContain('.ks-key-w.arp-step');
});
