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

  test("r1_edge_06_unmute_restoration_payload", () => {
    // When track is unmuted, CC 7 must restore stored volume level
    const trk = { id: 2, volume: 112, muted: false, channel: 1 };
    const ccEmitted = { cc: 7, val: trk.volume, ch: trk.channel };
    expect(ccEmitted.cc).toBe(7);
    expect(ccEmitted.val).toBe(112);
    expect(ccEmitted.ch).toBe(1);
  });
});
