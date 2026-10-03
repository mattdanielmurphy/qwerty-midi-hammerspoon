import { expect, test } from 'bun:test';

const source = await Bun.file(new URL('../src/web/index.html', import.meta.url)).text();

test('unknown transport state lights neither transport button', () => {
  expect(source).toContain('class="ks-btn ks-btn-trans ks-btn-stop" id="ks-btn-stop"');
  expect(source).toContain("status === 'stopped'");
  expect(source).toContain("status === 'running'");
});

test('KeyStep 32 hardware silhouette and controls exist in WebKit HUD', () => {
  // Master container and badge
  expect(source).toContain('id="keystep-badge"');
  expect(source).toContain('id="keystep-view"');
  expect(source).toContain('.keystep-view');
  expect(source).toContain('.ks-left-cheek');
  expect(source).toContain('.ks-main-section');
  expect(source).toContain('.ks-top-bar');
  expect(source).toContain('.ks-keybed');

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

test('KeyStep 32 has 32 slimkeys with exact note ranges 41..72 (F to C)', () => {
  // 19 White keys: F(41), G(43), A(45), B(47), C(48), D(50), E(52), F(53), G(55), A(57), B(59), C(60), ... C(72)
  const whiteNotes = [41, 43, 45, 47, 48, 50, 52, 53, 55, 57, 59, 60, 62, 64, 65, 67, 69, 71, 72];
  expect(whiteNotes.length).toBe(19);
  for (const n of whiteNotes) {
    expect(source).toContain(`id="ks-key-${n}"`);
  }

  // 13 Black keys: F#(42), G#(44), A#(46), C#(49), D#(51), F#(54), G#(56), A#(58), C#(61), D#(63), F#(66), G#(68), A#(70)
  const blackNotes = [42, 44, 46, 49, 51, 54, 56, 58, 61, 63, 66, 68, 70];
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

test('KeyStep modal shift keybed, scale lock badge, and shift status pill are wired', () => {
  // Modal shift status pill & Scale lock badge in HUD markup
  expect(source).toContain('id="ks-shift-status-pill"');
  expect(source).toContain('id="ks-scale-lock-badge"');
  expect(source).toContain('SCALE LOCK: ON');

  // Black keys contain data-shift targets and secondary parameter badges
  expect(source).toContain('data-shift="cutoff"');
  expect(source).toContain('data-shift="reverb"');
  expect(source).toContain('data-shift="delay"');
  expect(source).toContain('data-shift="release"');
  expect(source).toContain('data-shift="envelope"');
  expect(source).toContain('<span class="ks-key-sub">CUT</span>');
  expect(source).toContain('<span class="ks-key-sub">REV</span>');
  expect(source).toContain('<span class="ks-key-sub">DLY</span>');
  expect(source).toContain('<span class="ks-key-sub">REL</span>');
  expect(source).toContain('<span class="ks-key-sub">ADSR</span>');

  // Dispatcher handles shift_mode and transposer_enabled
  expect(source).toContain("controlId === 'shift_mode'");
  expect(source).toContain("controlId === 'transposer_enabled'");
  expect(source).toContain("postMidi({ type: 'keystepTransposerToggle' })");
  expect(source).toContain("postMidi({ type: 'keystepShiftMode', mode: 'clear' })");
});
