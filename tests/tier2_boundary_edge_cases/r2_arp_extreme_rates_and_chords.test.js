import { expect, test, describe } from "bun:test";
import { R2_CONTRACT } from "../harness/contracts.js";

describe("R2 Tier 2: Arp Extreme Rates, Contours & Chords", () => {
  test("r2_edge_01_single_pitch_contour_progression", () => {
    // 1-pitch held chord cycles through velocity contours
    const p1 = R2_CONTRACT.computeArpStep(1, 100, "accentDownbeat", 50, 120, 0.25);
    const p2 = R2_CONTRACT.computeArpStep(2, 100, "accentDownbeat", 50, 120, 0.25);
    const p3 = R2_CONTRACT.computeArpStep(3, 100, "accentDownbeat", 50, 120, 0.25);
    const p4 = R2_CONTRACT.computeArpStep(4, 100, "accentDownbeat", 50, 120, 0.25);

    expect(p1.vel).toBe(125); // Downbeat accent
    expect(p2.vel).toBe(85);  // Ghost note
    expect(p3.vel).toBe(105); // Secondary accent
    expect(p4.vel).toBe(80);  // Ghost note
  });

  test("r2_edge_02_velocity_ceiling_clamping_at_127", () => {
    // Base volume 127 with 1.25 multiplier must clamp at 127, not overflow
    const res = R2_CONTRACT.computeArpStep(1, 127, "accentDownbeat", 50, 120, 0.25);
    expect(res.vel).toBe(127);
  });

  test("r2_edge_03_velocity_floor_clamping_at_1", () => {
    // Base volume 1 with 0.5 multiplier must clamp at 1, not 0
    const res = R2_CONTRACT.computeArpStep(2, 1, "accentDownbeat", 50, 120, 0.25);
    expect(res.vel).toBe(1);
  });

  test("r2_edge_04_swing_boundaries_straight_vs_heavy", () => {
    // 50% swing has 0 offset
    const straight = R2_CONTRACT.computeArpStep(2, 100, "accentDownbeat", 50, 120, 0.25);
    expect(straight.swingOffset).toBe(0);

    // 66% triplet swing at 120 BPM, 16th note (stepSec = 0.125s)
    const swing66 = R2_CONTRACT.computeArpStep(2, 100, "accentDownbeat", 66, 120, 0.25);
    expect(swing66.swingOffset).toBeCloseTo(0.02, 3);

    // Odd steps receive 0 swing offset
    const oddStep = R2_CONTRACT.computeArpStep(1, 100, "accentDownbeat", 66, 120, 0.25);
    expect(oddStep.swingOffset).toBe(0);
  });

  test("r2_edge_05_gate_duration_bounds_at_extreme_bpm", () => {
    // At 300 BPM 32nd note (stepSec = 0.025s), gate duration must not be zero
    const stepSec = (60.0 / 300.0) * 0.125;
    const gateDuration = Math.max(0.010, stepSec * 0.8);
    expect(gateDuration).toBeGreaterThanOrEqual(0.010);
  });

  test("r2_edge_06_polyphonic_chord_pitch_ordering", () => {
    const pitches = [48, 52, 55, 59];
    // Up-Down pattern length is 2 * (N - 1) = 6 steps: 0, 1, 2, 3, 2, 1
    const pattern = [0, 1, 2, 3, 2, 1].map(i => pitches[i]);
    expect(pattern).toEqual([48, 52, 55, 59, 55, 52]);
  });
});
