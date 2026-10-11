import { expect, test, describe } from "bun:test";
import { TapTempoEngine } from "../harness/contracts.js";

describe("R7 Tier 2: Tap Tempo Jitter, Outliers & Timeout Boundaries", () => {
  test("r7_edge_01_single_tap_records_reference_no_bpm_jump", () => {
    const sim = new TapTempoEngine();
    const bpm = sim.tap(10.0);
    expect(bpm).toBe(120.0); // Baseline unchanged
    expect(sim.history.length).toBe(0);
  });

  test("r7_edge_02_steady_120_bpm_taps", () => {
    const sim = new TapTempoEngine();
    sim.tap(0.0);
    sim.tap(0.5); // 500ms = 120 BPM
    sim.tap(1.0);
    sim.tap(1.5);
    sim.tap(2.0);
    expect(sim.bpm).toBe(120.0);
  });

  test("r7_edge_03_steady_150_bpm_taps", () => {
    const sim = new TapTempoEngine();
    sim.tap(0.0);
    sim.tap(0.4); // 400ms = 150 BPM
    sim.tap(0.8);
    sim.tap(1.2);
    expect(sim.bpm).toBe(150.0);
  });

  test("r7_edge_04_timeout_after_2_seconds_resets_history", () => {
    const sim = new TapTempoEngine();
    sim.tap(0.0);
    sim.tap(0.5); // 120 BPM
    expect(sim.history.length).toBe(1);

    // Wait 2.1s (gap > 2.0s)
    sim.tap(2.6);
    expect(sim.history.length).toBe(0); // History cleared!
    // Next tap establishes new tempo at 300ms (200 BPM)
    sim.tap(2.9);
    expect(sim.bpm).toBe(200.0);
  });

  test("r7_edge_05_switch_bounce_rejection_under_50ms", () => {
    const sim = new TapTempoEngine();
    sim.tap(1.0);
    // Accidental hardware switch chatter 20ms later
    sim.tap(1.02);
    expect(sim.history.length).toBe(0); // Chatter rejected
  });

  test("r7_edge_06_clamping_at_30_and_300_bpm", () => {
    const sim = new TapTempoEngine();
    // 100ms interval = 600 BPM -> clamp to 300
    sim.tap(0.0);
    sim.tap(0.1);
    expect(sim.bpm).toBe(300.0);

    // 1.9s interval = 31.6 BPM
    sim.tap(2.0); // timeout reset
    sim.tap(3.9); // 1.9s -> 31.6 BPM
    expect(sim.bpm).toBeGreaterThanOrEqual(30.0);
    expect(sim.bpm).toBeLessThanOrEqual(300.0);
  });
});
