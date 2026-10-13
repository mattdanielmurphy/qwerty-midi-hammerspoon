import { expect, test, describe } from "bun:test";
import { TapTempoEngine } from "../harness/contracts.js";

const arpSrc = await Bun.file("src/arpeggiator.lua").text();
const controlsSrc = await Bun.file("src/controls.lua").text();

describe("R7 Tier 1: Tap Tempo Engine Contracts", () => {
  test("r7_contract_01_tap_tempo_engine_interface", () => {
    const engine = new TapTempoEngine();
    expect(typeof engine.tap).toBe("function");
    expect(engine.bpm).toBe(120.0);
  });

  test("[Milestone M3 Implementation Gate: tapTempo function in arpeggiator.lua]", () => {
    expect(arpSrc).toMatch(/local function tapTempo\(\)|function arpeggiator\.tapTempo\(\)/);
  });

  test("r7_contract_02_controls_binding_calls_tap_tempo", () => {
    // Verifies controls.lua dispatches act == "tapTempo"
    expect(controlsSrc).toContain('elseif act == "tapTempo" then');
    expect(controlsSrc).toContain("arpeggiator.tapTempo()");
  });

  test("r7_contract_03_rolling_average_calculation", () => {
    const engine = new TapTempoEngine();
    engine.tap(0.0);
    engine.tap(0.5); // 500ms = 120 BPM
    engine.tap(1.0);
    expect(engine.bpm).toBe(120.0);
  });

  test("r7_contract_04_timeout_buffer_reset", () => {
    const engine = new TapTempoEngine();
    engine.tap(0.0);
    engine.tap(0.5);
    expect(engine.history.length).toBe(1);

    // After > 2.0s gap, buffer resets
    engine.tap(2.6);
    expect(engine.history.length).toBe(0);
  });

  test("r7_contract_05_bpm_clamping_30_to_300", () => {
    const engine = new TapTempoEngine();
    // 50ms interval = 1200 BPM -> clamp to 300
    engine.tap(0.0);
    engine.tap(0.1);
    expect(engine.bpm).toBeLessThanOrEqual(300.0);

    // 2.0s interval -> clamp to >= 30
    engine.tap(10.0);
    engine.tap(11.9);
    expect(engine.bpm).toBeGreaterThanOrEqual(30.0);
  });

  test("r7_contract_06_engine_resync_and_hud_update", () => {
    expect(controlsSrc).toContain('title = "TAP TEMPO"');
  });
});
