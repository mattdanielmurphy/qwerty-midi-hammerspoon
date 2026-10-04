import { expect, test } from "bun:test";

const init = await Bun.file(new URL("../src/init.lua", import.meta.url)).text();
const hud = await Bun.file(new URL("../src/hud.lua", import.meta.url)).text();
const html = await Bun.file(new URL("../src/web/index.html", import.meta.url)).text();

test("Cmd-Shift-M hides only the MIDI HUD and consumes its matching key-up", () => {
  expect(init).toContain("code == 46 and flags.cmd and flags.shift");
  expect(init).toContain("state.consumedCommandShortcutKeyUps");
  expect(init).toContain("hs.timer.doAfter(0, function()");
  expect(init).toContain("pcall(hud.hideMidiWebview)");
  expect(init).toContain("keyboardEventAutorepeat");
  expect(hud).toContain("local function hideMidiWebview()");
  expect(hud).toContain("wv:hide()");
  expect(hud).toContain("hideMidiWebview = hideMidiWebview");
  expect(hud).not.toContain("qwertyMidi_hudIntentionallyHidden");
  expect(hud).not.toContain("state.midiActive = false");
});

test("the HUD chassis has an explicit right-click Close action while inputs keep native menus", () => {
  expect(html).toContain("hud-close-context-menu");
  expect(html).toContain("Close MIDI HUD");
  expect(html).toContain("window.callHammerspoon('closeMidiHud')");
  expect(html).toContain("e.target.closest('input, textarea, select, [contenteditable=\"true\"]')");
  expect(hud).toContain('body.type == "closeMidiHud"');
});

test("an active controller always restores its HUD after a reload", () => {
  expect(init).toContain("function _G.toggleMidiMode(newState)");
  expect(init).toContain("hud.showMidiWebview()");
  expect(init).toContain("_G.toggleMidiMode(true)");
  expect(hud).toContain("local function showMidiWebview()");
});
