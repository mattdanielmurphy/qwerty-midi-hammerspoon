import { expect, test } from "bun:test";

const init = await Bun.file(new URL("../src/init.lua", import.meta.url)).text();
const hud = await Bun.file(new URL("../src/hud.lua", import.meta.url)).text();
const html = await Bun.file(new URL("../src/web/index.html", import.meta.url)).text();

test("Cmd-Shift-M is passed through until a crash-safe shortcut path exists", () => {
  expect(init).not.toContain("code == 46 and flags.cmd and flags.shift");
  expect(init).not.toContain("consumedCommandShortcutKeyUps");
  expect(hud).toContain("local function hideMidiWebview()");
  expect(hud).toContain("wv:hide()");
  expect(hud).toContain("hideMidiWebview = hideMidiWebview");
  expect(hud).not.toContain("qwertyMidi_hudIntentionallyHidden");
  expect(hud).not.toContain("state.midiActive = false");
});

test("the HUD chassis has an explicit right-click Close action while inputs keep native menus", () => {
  expect(html).toContain("hud-close-context-menu");
  expect(html).toContain("Close MIDI HUD");
  expect(html).not.toContain("⌘⇧M");
  expect(html).toContain("window.callHammerspoon('closeMidiHud')");
  expect(html).toContain("e.target.closest('input, textarea, select, [contenteditable=\"true\"]')");
  expect(hud).toContain('body.type == "closeMidiHud"');
  expect(hud).toContain('_G.closeMidiHud("HUD close menu")');
});

test("a dead event tap or unresponsive HUD fails open instead of restarting interception", () => {
  expect(init).toContain("local function failOpenMidiInput(reason)");
  expect(init).toContain("midiKeyTap:stop()");
  expect(init).toContain("midiScrollTap:stop()");
  expect(init).toContain("local function disarmMidiInput(reason)");
  expect(init).toContain('failOpenMidiInput("keyboard event tap stopped")');
  expect(init).toContain('failOpenMidiInput("HUD webview stopped responding")');
  expect(init).not.toContain("Watchdog detected dead keyTap, restarting");
});

test("capture requires a responsive visible HUD and close stops capture first", () => {
  expect(init).toContain("if not hud.isMidiWebviewHealthy() then return false end");
  expect(init).toContain("function _G.closeMidiHud(reason)");
  expect(init).toContain('disarmMidiInput(reason or "HUD closed")');
  expect(init).toContain("if _G.activeWatchers.midiKeyTap then _G.activeWatchers.midiKeyTap:stop() end");
  expect(hud).toContain("local function isMidiWebviewHealthy()");
  expect(hud).toContain("return (os.time() - lastHeartbeat) < 5");
});

test("an automatic reload remains disarmed until the user explicitly opens the HUD", () => {
  expect(init).toContain("function _G.toggleMidiMode(newState)");
  expect(init).toContain("hud.showMidiWebview()");
  expect(init).toContain("if not isAutoReload then");
  expect(init).not.toContain("local wasOpen = hs.settings.get(\"qwertyMidi_wasOpen\")");
  expect(hud).toContain("local function showMidiWebview()");
});
