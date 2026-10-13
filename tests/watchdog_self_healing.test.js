import { test, expect, describe } from "bun:test";
import fs from "fs";
import path from "path";

describe("Watchdog Self-Healing and Secure Input Handling", () => {
  const initSource = fs.readFileSync(path.join(__dirname, "../src/init.lua"), "utf8");
  const logicNamesSource = fs.readFileSync(path.join(__dirname, "../src/logic_names.lua"), "utf8");

  test("watchdog checks Secure Input before failing open", () => {
    expect(initSource).toContain("hs.eventtap.isSecureInputEnabled()");
    expect(initSource).toContain("keyTapFailureCount");
    expect(initSource).toContain("scrollTapFailureCount");
  });

  test("watchdog attempts to re-enable disabled keyTap before failing open", () => {
    expect(initSource).toContain("_G.activeWatchers.midiKeyTap:start()");
    expect(initSource).toContain('_G.activeWatchers.keyTapFailureCount <= 3');
    expect(initSource).toContain('failOpenMidiInput("keyboard event tap stopped")');
  });

  test("watchdog attempts to re-enable disabled scrollTap before failing open", () => {
    expect(initSource).toContain("_G.activeWatchers.midiScrollTap:start()");
    expect(initSource).toContain('_G.activeWatchers.scrollTapFailureCount <= 3');
    expect(initSource).toContain('failOpenMidiInput("scroll event tap stopped")');
  });

  test("disarm and toggleMidiMode reset watchdog failure counters", () => {
    expect(initSource).toContain("_G.activeWatchers.keyTapFailureCount = 0");
    expect(initSource).toContain("_G.activeWatchers.scrollTapFailureCount = 0");
  });

  test("midiKeyTap guards focusedWindow with Hammerspoon bundleID check", () => {
    expect(initSource).toContain('local frontApp = hs.application.frontmostApplication()');
    expect(initSource).toContain('frontApp:bundleID() == "org.hammerspoon.Hammerspoon"');
  });

  test("logic_names bounds AX tree search to prevent runloop stall", () => {
    expect(logicNamesSource).toContain("depth > 4 or visited > 60");
  });
});
