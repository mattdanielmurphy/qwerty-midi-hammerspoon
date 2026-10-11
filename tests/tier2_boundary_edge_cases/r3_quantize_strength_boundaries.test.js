import { expect, test, describe } from "bun:test";
import { R3_CONTRACT } from "../harness/contracts.js";

describe("R3 Tier 2: Quantize Strength Boundary Values & Edge Math", () => {
  test("r3_edge_01_default_90_percent_scaling", () => {
    // At 120 BPM, 1/4 note (stepDuration = 0.5s), elapsed = 0.1s -> timeToNext = 0.4s
    const delay = R3_CONTRACT.calculateDelay(120, "1/4", 90, 0.1);
    expect(delay).toBeCloseTo(0.4 * 0.90, 4); // 0.36s
  });

  test("r3_edge_02_100_percent_hard_snap", () => {
    const delay = R3_CONTRACT.calculateDelay(120, "1/4", 100, 0.1);
    expect(delay).toBeCloseTo(0.40, 4);
  });

  test("r3_edge_03_zero_percent_instant_playback", () => {
    const delay = R3_CONTRACT.calculateDelay(120, "1/4", 0, 0.1);
    expect(delay).toBe(0);
  });

  test("r3_edge_04_out_of_bounds_clamping", () => {
    // -50% clamps to 0% -> 0s delay
    expect(R3_CONTRACT.calculateDelay(120, "1/4", -50, 0.1)).toBe(0);
    // 150% clamps to 100% -> 0.40s delay
    expect(R3_CONTRACT.calculateDelay(120, "1/4", 150, 0.1)).toBeCloseTo(0.40, 4);
  });

  test("r3_edge_05_anticipation_tolerance_12ms", () => {
    // timeToNext = 11ms <= 12ms tolerance -> should fire immediately (delay 0)
    const delay = R3_CONTRACT.calculateDelay(120, "1/4", 90, 0.489);
    expect(delay).toBe(0);
  });

  test("r3_edge_06_catchup_tolerance_20ms", () => {
    // elapsed = 19ms <= 20ms tolerance -> should fire immediately (delay 0)
    const delay = R3_CONTRACT.calculateDelay(120, "1/4", 90, 0.019);
    expect(delay).toBe(0);
  });
});
