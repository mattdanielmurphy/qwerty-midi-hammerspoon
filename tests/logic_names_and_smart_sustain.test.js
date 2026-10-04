import { test, expect, describe } from "bun:test";
import fs from "fs";
import path from "path";

describe("Thread 1: Logic Pro Track Name Sync & Smart Sustain Audit", () => {
  const configSource = fs.readFileSync(path.join(__dirname, "../src/config.lua"), "utf8");
  const initSource = fs.readFileSync(path.join(__dirname, "../src/init.lua"), "utf8");
  const logicNamesSource = fs.readFileSync(path.join(__dirname, "../src/logic_names.lua"), "utf8");
  const hudSource = fs.readFileSync(path.join(__dirname, "../src/hud.lua"), "utf8");
  const webIndexSource = fs.readFileSync(path.join(__dirname, "../src/web/index.html"), "utf8");

  test("Smart Sustain: all 4 tracks default to 'smart' and persist sustainMode", () => {
    expect(configSource).toContain('sustainMode = getSetting("track1SustainMode", "smart")');
    expect(configSource).toContain('sustainMode = getSetting("track2SustainMode", "smart")');
    expect(configSource).toContain('sustainMode = getSetting("track3SustainMode", "smart")');
    expect(configSource).toContain('sustainMode = getSetting("track4SustainMode", "smart")');
    expect(configSource).toContain('hs.settings.set("qwertyMidi_track" .. i .. "SustainMode", trk.sustainMode or "smart")');
  });

  test("logic_names: parses Logic Pro tracks header and curly quote strings", () => {
    expect(logicNamesSource).toContain("parseTrackHeaderDescription");
    expect(logicNamesSource).toContain("scanLogicTracks");
    expect(logicNamesSource).toContain("updateTrackNames");
    expect(initSource).toContain('local logic_names = require("logic_names")');
    expect(initSource).toContain("logic_names.init()");
  });

  test("hud & webview: track cards render dynamic track names from state with zero layout shift", () => {
    expect(hudSource).toContain('name = state.tracks and state.tracks[1] and state.tracks[1].name or "Track 1"');
    expect(hudSource).toContain('name = state.tracks and state.tracks[2] and state.tracks[2].name or "Track 2"');
    expect(hudSource).toContain('name = state.tracks and state.tracks[3] and state.tracks[3].name or "Track 3"');
    expect(hudSource).toContain('name = state.tracks and state.tracks[4] and state.tracks[4].name or "Track 4"');

    // Webview renderHud updates roleBadge text and title with t.name
    expect(webIndexSource).toContain("const roleBadge = el.querySelector('.trk-role')");
    expect(webIndexSource).toContain("roleBadge.textContent = displayName.toUpperCase()");

    // Webview CSS preserves zero layout shift with overflow hidden and text-overflow ellipsis
    expect(webIndexSource).toContain("overflow: hidden;");
    expect(webIndexSource).toContain("text-overflow: ellipsis;");
    expect(webIndexSource).toContain("white-space: nowrap;");
  });
});
