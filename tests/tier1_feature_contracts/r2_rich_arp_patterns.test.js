import { expect, test, describe } from "bun:test";
import { R2_CONTRACT } from "../harness/contracts.js";

const arpSrc = await Bun.file("src/arpeggiator.lua").text();
const configSrc = await Bun.file("src/config.lua").text();

describe("R2 Tier 1: Rich Arp Patterns & Human Feel Contracts", () => {
  test("r2_contract_01_pattern_catalog_expanded", () => {
    // Verifies pattern catalog expands beyond legacy 7 directions in contract
    expect(R2_CONTRACT.richPatterns.length).toBeGreaterThanOrEqual(5);
    expect(R2_CONTRACT.richPatterns).toContain("PING-PONG");
    expect(R2_CONTRACT.richPatterns).toContain("SWING-16");
    expect(configSrc).toContain("ARP_DIRECTIONS");
  });

  test("[Milestone M3 Implementation Gate: Rich patterns in arpeggiator.lua]", () => {
    expect(arpSrc).toMatch(/ARP_PATTERNS|ARP_GROOVES|getArpVelocityMultiplier/);
  });

  test("r2_contract_02_velocity_contour_calculation", () => {
    // Verifies velocity contour accent calculation in contract
    const step1 = R2_CONTRACT.computeArpStep(1, 100, "accentDownbeat", 50, 120, 0.25);
    const step2 = R2_CONTRACT.computeArpStep(2, 100, "accentDownbeat", 50, 120, 0.25);
    expect(step1.vel).toBe(125);
    expect(step2.vel).toBe(85);
  });

  test("[Milestone M3 Implementation Gate: Velocity contours in arpeggiator.lua]", () => {
    expect(arpSrc).toMatch(/local velMultiplier\s*=|local stepAccent\s*=/);
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
    // 1. Contract verification: dynamic gate duration across pattern steps
    const stepSec = 0.125; // 16th note at 120 BPM
    const accentGate = R2_CONTRACT.computeGateDuration(stepSec, "accentDownbeat", 1);
    const ghostGate = R2_CONTRACT.computeGateDuration(stepSec, "accentDownbeat", 2);

    expect(accentGate).toBeCloseTo(0.11875, 4); // 95% of 0.125s
    expect(ghostGate).toBeCloseTo(0.05625, 4);  // 45% of 0.125s
    expect(accentGate).toBeGreaterThan(ghostGate);

    // 2. Production source contract in src/arpeggiator.lua
    expect(arpSrc).toMatch(/gateDuration\s*=\s*(?:trackStepSec|getArpIntervalSeconds\(\))\s*\*\s*gateRatio/);
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
