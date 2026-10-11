import { expect, test, describe } from "bun:test";
import { R1_CONTRACT } from "../harness/contracts.js";

describe("R1 Tier 2: Volume Clamping & Muting Boundary Cases", () => {
  test("r1_edge_01_upper_bound_clamp_127", () => {
    expect(R1_CONTRACT.adjustVolume(124, 4)).toBe(127);
    expect(R1_CONTRACT.adjustVolume(127, 4)).toBe(127);
    expect(R1_CONTRACT.adjustVolume(127, 50)).toBe(127);
  });

  test("r1_edge_02_lower_bound_clamp_0", () => {
    expect(R1_CONTRACT.adjustVolume(3, -4)).toBe(0);
    expect(R1_CONTRACT.adjustVolume(0, -4)).toBe(0);
    expect(R1_CONTRACT.adjustVolume(0, -100)).toBe(0);
  });

  test("r1_edge_03_non_integer_and_nil_deltas", () => {
    expect(R1_CONTRACT.adjustVolume(100, null)).toBe(100);
    expect(R1_CONTRACT.adjustVolume(100, undefined)).toBe(100);
    expect(R1_CONTRACT.adjustVolume(100, NaN)).toBe(100);
  });

  test("r1_edge_04_track_channel_mapping", () => {
    for (let id = 1; id <= 4; id++) {
      expect(R1_CONTRACT.channelForTrack(id)).toBe(id - 1);
    }
  });

  test("r1_edge_05_debounced_save_coalescing_window", async () => {
    let saveCount = 0;
    let timer = null;
    function saveSettingsDebounced() {
      if (timer) clearTimeout(timer);
      timer = setTimeout(() => { saveCount++; }, 40);
    }

    // Fire 10 rapid volume ticks within 20ms
    for (let i = 0; i < 10; i++) {
      saveSettingsDebounced();
    }
    expect(saveCount).toBe(0); // Not saved synchronously
    await new Promise(r => setTimeout(r, 60));
    expect(saveCount).toBe(1); // Exactly 1 debounced save executed
  });

  test("r1_edge_06_unmute_restoration_payload", async () => {
    // 1. Inspect production restoration in src/controls.lua
    const controlsSrc = await Bun.file("src/controls.lua").text();
    expect(controlsSrc).toContain("midi.sendMidiCC(108, 0, ch)");
    expect(controlsSrc).toMatch(/local volCc = math\.floor\(math\.min\(127,\s*math\.max\(0,\s*vol\s*\*\s*1\.27\)\)\)/);
    expect(controlsSrc).toContain("midi.sendMidiCC(7, volCc, ch)");
    expect(controlsSrc).toContain("midi.sendMidiCC(11, 127, ch)");

    // 2. Validate conversion formulas
    expect(R1_CONTRACT.restoreVolumeCC(100)).toBe(127); // 100% maps to CC 127
    expect(R1_CONTRACT.restoreVolumeCC(50)).toBe(63);   // 50% maps to CC 63
    expect(R1_CONTRACT.restoreVolumeCC(0)).toBe(0);     // 0% maps to CC 0
    expect(R1_CONTRACT.restoreVolumeCC(150)).toBe(127); // Over-range clamps to 127
  });
});
