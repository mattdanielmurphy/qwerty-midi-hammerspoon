import { expect, test } from "bun:test";

const htmlSource = await Bun.file(
  new URL("../src/web/index.html", import.meta.url),
).text();

const hudLuaSource = await Bun.file(
  new URL("../src/hud.lua", import.meta.url),
).text();

const keystepLuaSource = await Bun.file(
  new URL("../packages/keystep-interceptor/keystep.lua", import.meta.url),
).text();

const bundlerSource = await Bun.file(
  new URL("../bin/hs-bundler", import.meta.url),
).text();

test("KeyStep 32 controller display is embedded within QWERTY HUD container", () => {
  expect(htmlSource).toContain('id="hud-container"');
  expect(htmlSource).toContain('class="keystep-view" id="keystep-view"');
  expect(htmlSource).toContain('#hud-container.keystep-connected');
  expect(htmlSource).toContain('height: 600px !important');
});

test("renders authentic KeyStep 32 hardware silhouette and controls", () => {
  // Brand & title
  expect(htmlSource).toContain('ARTURIA');
  expect(htmlSource).toContain('KeyStep 32');
  expect(htmlSource).toContain('id="ks-status-dot"');

  // Master Control Bay: Knobs & Switch
  expect(htmlSource).toContain('id="ks-switch-seq-arp"');
  expect(htmlSource).toContain('id="ks-knob-mode"');
  expect(htmlSource).toContain('id="ks-knob-div"');
  expect(htmlSource).toContain('id="ks-knob-rate"');
  expect(htmlSource).toContain('id="ks-rate-led"');

  // Transport & function buttons
  expect(htmlSource).toContain('id="ks-btn-stop"');
  expect(htmlSource).toContain('id="ks-btn-play"');
  expect(htmlSource).toContain('id="ks-btn-rec"');
  expect(htmlSource).toContain('id="ks-btn-tap"');
  expect(htmlSource).toContain('id="ks-btn-shift"');
  expect(htmlSource).toContain('id="ks-btn-hold"');
  expect(htmlSource).toContain('id="ks-btn-oct-down"');
  expect(htmlSource).toContain('id="ks-btn-oct-up"');
  expect(htmlSource).toContain('id="ks-oct-val"');

  // Pitch bend and mod touch strips
  expect(htmlSource).toContain('id="ks-pitch-strip"');
  expect(htmlSource).toContain('id="ks-pitch-thumb"');
  expect(htmlSource).toContain('id="ks-mod-strip"');
  expect(htmlSource).toContain('id="ks-mod-fill"');
});

test("embeds 32 slim keys spanning notes 48 (C3) through 79 (G5)", () => {
  // 19 White keys
  const whiteNotes = [48, 50, 52, 53, 55, 57, 59, 60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79];
  for (const n of whiteNotes) {
    expect(htmlSource).toContain(`id="ks-key-${n}" data-note="${n}"`);
  }

  // 13 Black keys
  const blackNotes = [49, 51, 54, 56, 58, 61, 63, 66, 68, 70, 73, 75, 78];
  for (const n of blackNotes) {
    expect(htmlSource).toContain(`id="ks-key-${n}" data-note="${n}"`);
  }

  expect(whiteNotes.length + blackNotes.length).toBe(32);
});

test("updates embedded KeyStep display only when KeyStep is connected", () => {
  expect(hudLuaSource).toContain("isKeyStepConnected()");
  expect(hudLuaSource).toContain("local function isKeyStepConnected()");
  expect(hudLuaSource).toContain("return isKeyStepConnected() and 600 or 280");
  expect(hudLuaSource).toContain("window.setKeyStepConnected");
  expect(htmlSource).toContain("window.setKeyStepConnected = function(connected)");
  expect(htmlSource).toContain("ksView.style.display = connected ? 'flex' : 'none'");
});

test("routes GUI interactions from embedded KeyStep controls to Hammerspoon", () => {
  expect(htmlSource).toContain("keystepKey");
  expect(htmlSource).toContain("keystepPitch");
  expect(htmlSource).toContain("keystepMod");
  expect(htmlSource).toContain("keystepTransport");
  expect(htmlSource).toContain("keystepHold");
  expect(htmlSource).toContain("keystepShift");
  expect(htmlSource).toContain("keystepOctave");
  expect(htmlSource).toContain("keystepMode");
  expect(htmlSource).toContain("keystepDivision");
  expect(htmlSource).toContain("keystepSeqArp");
  expect(htmlSource).toContain("keystepRate");

  expect(hudLuaSource).toContain("body.type == \"keystepKey\"");
  expect(hudLuaSource).toContain("body.type == \"keystepPitch\"");
  expect(hudLuaSource).toContain("body.type == \"keystepTransport\"");
  expect(keystepLuaSource).toContain("function KeyStep.handleGuiAction(actionType, data)");
});

test("preserves nanoKey archive and bundling preset", () => {
  expect(bundlerSource).toContain('"nanokey-studio"');
  expect(bundlerSource).toContain('"archive/nanokey-studio/packages/nanokey-studio"');
});
