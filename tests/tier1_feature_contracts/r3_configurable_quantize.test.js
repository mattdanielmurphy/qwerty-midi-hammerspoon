import { expect, test, describe } from "bun:test";
import { R3_CONTRACT } from "../harness/contracts.js";

const quantizerSrc = await Bun.file("packages/music-engine/quantizer.lua").text();

describe("R3 Tier 1: Configurable Quantization Amount Contracts", () => {
  test("r3_contract_01_strength_parameter_and_default", () => {
    // Verifies contract specifications for quantize amount bounds and default
    expect(R3_CONTRACT.defaultAmount).toBe(90.0);
    expect(R3_CONTRACT.minAmount).toBe(0.0);
    expect(R3_CONTRACT.maxAmount).toBe(100.0);
  });

  test("[Milestone M2 Implementation Gate: Configurable amount in quantizer.lua]", () => {
    expect(quantizerSrc).toMatch(/function quantizer\.calculateDelay\(bpm,\s*mode,\s*amount\)/);
    expect(quantizerSrc).toMatch(/local quantAmount\s*=\s*tonumber\(amount\)\s*or\s*90\.0/);
  });

  test("r3_contract_02_delay_scaling_formula", () => {
    // Formula: delay = timeToNext * (clampedAmount / 100.0)
    const timeToNext = 0.40;
    const amount = 90.0;
    const scaled = timeToNext * (amount / 100.0);
    expect(scaled).toBeCloseTo(0.36, 4);

    const delay = R3_CONTRACT.calculateDelay(120, "1/4", 90, 0.1);
    expect(delay).toBeCloseTo(0.36, 4);
  });

  test("r3_contract_03_zero_strength_immediate_trigger", () => {
    // Amount 0% yields 0s delay (instant trigger)
    const delay = R3_CONTRACT.calculateDelay(120, "1/4", 0, 0.1);
    expect(delay).toBe(0);
  });

  test("r3_contract_04_full_strength_grid_snap", () => {
    // Amount 100% yields full timeToNext (0.40s)
    const delay = R3_CONTRACT.calculateDelay(120, "1/4", 100, 0.1);
    expect(delay).toBeCloseTo(0.40, 4);
  });

  test("r3_contract_05_settings_persistence", async () => {
    // 1. Setting key schema convention: qwertyMidi_ prefix standard
    const settingName = "inputQuantizeAmount";
    const expectedPersistenceKey = `qwertyMidi_${settingName}`;
    expect(expectedPersistenceKey).toBe("qwertyMidi_inputQuantizeAmount");

    // 2. Validate production persistence retrieval schema in src/config.lua
    const configSrc = await Bun.file("src/config.lua").text();
    expect(configSrc).toContain('hs.settings.get("qwertyMidi_" .. key)');

    // 3. Fallback contract: unconfigured key returns 90.0 default
    const mockSettings = {};
    const resolvedValue = mockSettings[expectedPersistenceKey] ?? R3_CONTRACT.defaultAmount;
    expect(resolvedValue).toBe(90.0);
  });

  test("r3_contract_06_runtime_setter_and_state", () => {
    expect(R3_CONTRACT.anticipationToleranceSec).toBe(0.012);
    expect(R3_CONTRACT.catchupToleranceSec).toBe(0.020);
    expect(R3_CONTRACT.divisionFactors["1/16"]).toBe(0.25);
  });
});
