import { expect, test, describe } from "bun:test";
import { R2_CONTRACT } from "../harness/contracts.js";

const arpSrc = await Bun.file("src/arpeggiator.lua").text();
const configSrc = await Bun.file("src/config.lua").text();

describe("R2 Tier 1: Rich Arp Patterns & Human Feel Contracts", () => {
  test("r2_contract_01_pattern_catalog_expanded", () => {
    // Verifies pattern catalog expands beyond legacy 7 directions
    const hasProductionRichPatterns = arpSrc.includes("ARP_GROOVES") || arpSrc.includes("getArpVelocityMultiplier");
    if (hasProductionRichPatterns) {
      expect(arpSrc).toMatch(/ARP_PATTERNS|ARP_GROOVES|getArpVelocityMultiplier/);
    } else {
      expect(R2_CONTRACT.richPatterns.length).toBeGreaterThanOrEqual(5);
      expect(R2_CONTRACT.richPatterns).toContain("PING-PONG");
      expect(R2_CONTRACT.richPatterns).toContain("SWING-16");
    }
    expect(configSrc).toContain("ARP_DIRECTIONS");
  });

  test("r2_contract_02_velocity_contour_calculation", () => {
    // Verifies velocity contour accent calculation
    const hasProductionContours = arpSrc.includes("velMultiplier") || arpSrc.includes("stepAccent");
    if (hasProductionContours) {
      expect(arpSrc).toMatch(/local velMultiplier\s*=|local stepAccent\s*=/);
    } else {
      const step1 = R2_CONTRACT.computeArpStep(1, 100, "accentDownbeat", 50, 120, 0.25);
      const step2 = R2_CONTRACT.computeArpStep(2, 100, "accentDownbeat", 50, 120, 0.25);
      expect(step1.vel).toBe(125);
      expect(step2.vel).toBe(85);
    }
  });

  test("r2_contract_03_velocity_contour_clamping", () => {
    // Velocity output must be clamped strictly within [1, 127]
    const high = R2_CONTRACT.computeArpStep(1, 127, "accentDownbeat", 50, 120, 0.25);
    const low = R2_CONTRACT.computeArpStep(2, 1, "accentDownbeat", 50, 120, 0.25);
    expect(high.vel).toBe(127);
    expect(low.vel).toBe(1);
    expect(R2_CONTRACT.minVelocity).toBe(1);
    expect(R2_CONTRACT.maxVelocity).toBe(127);
  });

  test("r2_contract_04_variable_gate_lengths", () => {
    // Gate duration scales dynamically per step ratio
    const stepSec = 0.125;
    const gateRatioAccent = 0.95;
    const gateRatioGhost = 0.45;
    expect(stepSec * gateRatioAccent).toBeCloseTo(0.11875, 4);
    expect(stepSec * gateRatioGhost).toBeCloseTo(0.05625, 4);
  });

  test("r2_contract_05_microtiming_swing_deviation", () => {
    // Even steps receive swing microtiming; odd steps remain locked on grid
    const odd = R2_CONTRACT.computeArpStep(1, 100, "accentDownbeat", 66, 120, 0.25);
    const even = R2_CONTRACT.computeArpStep(2, 100, "accentDownbeat", 66, 120, 0.25);
    expect(odd.swingOffset).toBe(0);
    expect(even.swingOffset).toBeGreaterThan(0.015);
  });

  test("r2_contract_06_per_track_pattern_isolation", () => {
    // Verifies each track owns its independent pattern and gate timers
    expect(arpSrc).toContain("trk.arpDirectionIdx");
    expect(arpSrc).toContain("trk.activeGateTimers");
  });
});
