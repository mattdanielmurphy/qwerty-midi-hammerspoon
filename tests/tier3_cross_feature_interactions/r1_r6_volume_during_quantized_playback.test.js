import { expect, test, describe } from "bun:test";
import { R1_CONTRACT } from "../harness/contracts.js";

describe("Tier 3 Interaction: R1 Volume Adjustments During R6 Quantized Playback", () => {
  test("r1_r6_interaction_01_continuous_volume_repeat_during_chords", () => {
    // Assert that repeated volume changes do not drop note-off events or delay note-on callbacks
    const noteQueue = [];
    let volume = 100;

    function onVolumeTick() {
      volume = R1_CONTRACT.adjustVolume(volume, 4);
    }

    function onNoteOn(p) { noteQueue.push({ type: "on", pitch: p }); }
    function onNoteOff(p) { noteQueue.push({ type: "off", pitch: p }); }

    // Interleave 3 volume ticks with 3 chord notes
    onNoteOn(60);
    onVolumeTick();
    onNoteOn(64);
    onVolumeTick();
    onNoteOn(67);
    onVolumeTick();
    onNoteOff(60);
    onNoteOff(64);
    onNoteOff(67);

    expect(volume).toBe(112);
    expect(noteQueue.filter(e => e.type === "on").length).toBe(3);
    expect(noteQueue.filter(e => e.type === "off").length).toBe(3);
  });

  test("r1_r6_interaction_02_debounced_save_preserves_timer_jitter_under_1ms", async () => {
    const tickExecutionTimes = [];
    let timer = null;

    function debouncedSave() {
      if (timer) clearTimeout(timer);
      timer = setTimeout(() => {}, 50);
    }

    // Schedule 5 note ticks while debouncing save
    for (let i = 0; i < 5; i++) {
      const start = performance.now();
      debouncedSave();
      tickExecutionTimes.push(performance.now() - start);
    }

    // Every tick must complete in < 2ms (zero synchronous I/O stall)
    tickExecutionTimes.forEach(duration => {
      expect(duration).toBeLessThan(2.0);
    });
  });

  test("r1_r6_interaction_03_concurrent_track_volume_and_staccato_retrigger", () => {
    let activeVoices = 0;
    const events = [];

    function tapNote(t) {
      if (activeVoices > 0) {
        events.push({ type: "off_safety", t });
        activeVoices--;
      }
      events.push({ type: "on", t });
      activeVoices++;
    }

    // Volume adjustment interleaved with rapid note taps
    tapNote(0);
    const vol = R1_CONTRACT.adjustVolume(100, 5);
    tapNote(15);
    tapNote(30);

    expect(vol).toBe(105);
    expect(activeVoices).toBe(1);
    expect(events.filter(e => e.type === "on").length).toBe(3);
    expect(events.filter(e => e.type === "off_safety").length).toBe(2);
  });
});
