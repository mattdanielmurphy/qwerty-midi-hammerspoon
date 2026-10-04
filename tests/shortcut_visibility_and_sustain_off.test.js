import { expect, test } from "bun:test";

const configSource = await Bun.file(
  new URL("../src/config.lua", import.meta.url),
).text();
const controlsSource = await Bun.file(
  new URL("../src/controls.lua", import.meta.url),
).text();
const hudSource = await Bun.file(
  new URL("../src/hud.lua", import.meta.url),
).text();
const initSource = await Bun.file(
  new URL("../src/init.lua", import.meta.url),
).text();
const htmlSource = await Bun.file(
  new URL("../src/web/index.html", import.meta.url),
).text();

test("Tab visibly advertises the double-tap sustain-off gesture", () => {
  expect(configSource).toContain('name = "Smart Sus · 2× Off"');
  expect(hudSource).toContain('base            = { name = "Smart Sus · 2× Off"');
  expect(controlsSource).toContain("lastSmartSustainTapAt");
  expect(controlsSource).toContain('title = "SUSTAIN OFF (TRK " .. activeTrkId .. ")"');
  expect(controlsSource).toContain("Double-tap Tab toggles Smart Sustain off");
});

test("Control+Tab is explicitly visible as pass-through and can never reset or panic", () => {
  const tabBindingBlock = hudSource.match(/\[48\] = \{ -- Tab([\s\S]*?)\n  \},\n  \[0\]/)?.[1];
  expect(tabBindingBlock).toBeDefined();
  expect(tabBindingBlock).toContain('name = "Pass Through"');
  expect(tabBindingBlock).toContain('action = "none"');
  expect(tabBindingBlock).not.toContain('action = "panic"');
  expect(tabBindingBlock).not.toContain('action = "resetAll"');
  expect(initSource).toContain("if (flags.cmd or flags.ctrl) and code == 48 then");
  expect(initSource).toContain("return false");
});

test("the only global controller shortcut is visibly documented", () => {
  expect(initSource).toContain('hs.hotkey.bind({ "cmd", "shift" }, "M"');
  expect(initSource).toContain("midiHudToggleHotkey");
  expect(htmlSource).toContain("⌘⇧M");
  expect(initSource).toContain('retiredHotkey]:delete()');
  expect(initSource).not.toContain("Handle Cmd-, for QWERTY MIDI settings");
  expect(configSource).toContain('shiftAction = "arpLatchToggle", shiftName = "Latch"');
  expect(htmlSource).toContain('noteLabel: "Arp Mode + A"');
});
