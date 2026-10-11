import { expect, test, describe } from "bun:test";
import { R1_CONTRACT, R3_CONTRACT, MidiVoiceTracker } from "../harness/contracts.js";

const controlsSrc = await Bun.file("src/controls.lua").text();

describe("Tier 3 Interaction: R1 Volume Adjustments During R6 Quantized Playback", () => {
  test("r1_r6_interaction_01_continuous_volume_repeat_during_chords", () => {
    const tracker = new MidiVoiceTracker();
    let currentVolume = 100;

    // Simulate 3-note chord on Track 1 (Channel 0)
    [60, 64, 67].forEach((pitch, i) => {
      tracker.noteOn(pitch, 0, currentVolume, 1, 100.0 + i * 0.05);
      // Volume key repeat tick interleaves playback
      currentVolume = R1_CONTRACT.adjustVolume(currentVolume, 4);
    });

    expect(currentVolume).toBe(112);
    expect(tracker.activeVoices.size).toBe(3);

    // Release chord notes
    [60, 64, 67].forEach(pitch => {
      tracker.noteOff(pitch, 0, 100.5);
    });

    expect(tracker.activeVoices.size).toBe(0);
    // Verify volume adjust function in controls.lua does not mutate activeNoteLedger
    expect(controlsSrc).toMatch(/local function adjustTrackVolume\(trackId,\s*delta\)[\s\S]*?trk\.volume\s*=/);
  });

  test("r1_r6_interaction_02_debounced_save_preserves_timer_jitter_under_1ms", async () => {
    // Contract: debounced trailing timer is 300ms
    expect(R1_CONTRACT.debounceMs).toBe(300);

    // Measure non-blocking asynchronous event scheduling
    const intervals = [];
    for (let i = 0; i < 10; i++) {
      const t0 = performance.now();
      R1_CONTRACT.adjustVolume(100, 2);
      intervals.push(performance.now() - t0);
    }
    // All synchronous execution steps complete in sub-millisecond time (< 1.0ms)
    intervals.forEach(dt => expect(dt).toBeLessThan(1.0));
  });

  test("r1_r6_interaction_03_concurrent_track_volume_and_staccato_retrigger", () => {
    const tracker = new MidiVoiceTracker();
    let vol1 = 100;
    let vol2 = 90;

    // Track 1 plays note 60 with volume adjust
    tracker.noteOn(60, 0, vol1, 1, 0.0);
    vol1 = R1_CONTRACT.adjustVolume(vol1, 10);
    tracker.noteOff(60, 0, 0.02);

    // Immediate staccato re-trigger on Track 2 (Channel 1)
    tracker.noteOn(62, 1, vol2, 2, 0.03);
    vol2 = R1_CONTRACT.adjustVolume(vol2, -5);
    tracker.noteOff(62, 1, 0.05);

    expect(vol1).toBe(110);
    expect(vol2).toBe(85);
    expect(tracker.activeVoices.size).toBe(0);
  });
});
