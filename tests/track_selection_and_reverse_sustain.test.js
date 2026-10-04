import { describe, test, expect } from "bun:test";
import fs from "fs";
import path from "path";

const configPath = path.resolve(__dirname, "../src/config.lua");
const hudPath = path.resolve(__dirname, "../src/hud.lua");
const controlsPath = path.resolve(__dirname, "../src/controls.lua");
const initPath = path.resolve(__dirname, "../src/init.lua");
const htmlPath = path.resolve(__dirname, "../src/web/index.html");

const configSource = fs.readFileSync(configPath, "utf-8");
const hudSource = fs.readFileSync(hudPath, "utf-8");
const controlsSource = fs.readFileSync(controlsPath, "utf-8");
const initSource = fs.readFileSync(initPath, "utf-8");
const htmlSource = fs.readFileSync(htmlPath, "utf-8");

describe("Selected Track Persistence & Smart Sustain Defaults", () => {
  test("activeTrack, bottomRowTrack, and topRowTrack are loaded from and saved to hs.settings", () => {
    // Config loads activeTrack from hs.settings
    expect(configSource).toContain('activeTrack = getSetting("activeTrack", 1)');
    expect(configSource).toContain('bottomRowTrack = getSetting("bottomRowTrack"');
    expect(configSource).toContain('topRowTrack = getSetting("topRowTrack"');

    // saveSettings persists activeTrack and track row routing
    expect(configSource).toContain('hs.settings.set("qwertyMidi_activeTrack", state.activeTrack or 1)');
    expect(configSource).toContain('hs.settings.set("qwertyMidi_bottomRowTrack", state.bottomRowTrack or 1)');
    expect(configSource).toContain('hs.settings.set("qwertyMidi_topRowTrack", state.topRowTrack or 3)');

    // selectTrack persists selection immediately
    expect(controlsSource).toContain('state.activeTrack = targetId');
    expect(controlsSource).toContain('config.saveSettings()');

    // init.lua restores selected track on startup / toggle
    expect(initSource).toContain('controls.selectTrack(state.activeTrack or 1)');
  });

  test("Tracks default to Smart Sustain ON and persist sustainMode per track", () => {
    // All 4 tracks default to 'smart'
    expect(configSource).toContain('sustainMode = getSetting("track1SustainMode", "smart")');
    expect(configSource).toContain('sustainMode = getSetting("track2SustainMode", "smart")');
    expect(configSource).toContain('sustainMode = getSetting("track3SustainMode", "smart")');
    expect(configSource).toContain('sustainMode = getSetting("track4SustainMode", "smart")');

    // saveSettings persists track-specific sustainMode
    expect(configSource).toContain('hs.settings.set("qwertyMidi_track" .. i .. "SustainMode", trk.sustainMode or "smart")');
  });

  test("Reverse Smart Sustain functionality: Tab damps ringing notes and respects track-color", () => {
    // KeyDown on sustain triggers reverse damping for silence when sustain is on
    expect(controlsSource).toContain('state.tabDamping = true');
    expect(controlsSource).toContain('cleanupSustainPitches(activeTrkId)');
    expect(controlsSource).toContain('DAMP / SILENCE (TRK');

    // Damping suppresses note latching while Tab is held
    expect(controlsSource).toContain('if state.tabDamping then');

    // Spot color uses active track color
    expect(controlsSource).toContain('color = trk.color or "#00e5ff"');
  });

  test("All controls change to active track except Transpose, Root, and Scale", () => {
    // resolveAssignedTrackId preserves track selectors (18..21)
    expect(hudSource).toContain("if cNum == 18 or (ksConnected and cNum == 6) then return 1 end");
    expect(hudSource).toContain("if cNum == 19 or (ksConnected and cNum == 7) then return 2 end");
    expect(hudSource).toContain("if cNum == 20 or (ksConnected and cNum == 8) then return 3 end");
    expect(hudSource).toContain("if cNum == 21 or (ksConnected and cNum == 9) then return 4 end");

    // Exceptions that affect ALL tracks return nil:
    // Transpose: 38 (J), 40 (K)
    // Root: 4 (H), 37 (L)
    // Scale / Mode: 5 (G), 41 (;)
    // Random / Panic: 1 (S)
    expect(hudSource).toContain("if cNum == 38 or cNum == 40 or cNum == 4 or cNum == 37 or cNum == 5 or cNum == 41 or cNum == 1 then");
    expect(hudSource).toContain("return nil");

    // EVERYTHING ELSE returns activeTrkId
    expect(hudSource).toContain("return activeTrkId");
  });

  test("Key 48 and per-track controls use assigned track color and remove hardcoded yellow", () => {
    // Key 48 latch-active must NOT hardcode #ffd700
    expect(htmlSource).not.toContain("#key-48.latch-active {\n    background: rgba(255, 215, 0");
    expect(htmlSource).toContain("#key-48.latch-active,");
    expect(htmlSource).toContain("var(--assigned-track-color, var(--active-track-color, #00e5ff))");

    // Per-track-ctrl must have prominent background, border, and glow
    expect(htmlSource).toContain(".key-pad.per-track-ctrl");
    expect(htmlSource).toContain("rgba(var(--assigned-track-rgb, var(--active-track-rgb, 0, 229, 255)), 0.65) !important");

    // trk-tag-sus must use var(--trk-color) and var(--trk-rgb)
    expect(htmlSource).toContain("color: var(--trk-color, #00e5ff);");
  });
});
