import { expect, test, describe } from "bun:test";
import { R3_CONTRACT, R6_CONTRACT, MidiVoiceTracker } from "../harness/contracts.js";

describe("Tier 3 Interaction: R3 Quantize Legato Sustaining vs R6 Voice Watchdog", () => {
  test("r3_r6_interaction_01_legato_grace_sustaining_not_flagged_by_watchdog", () => {
    // Notes sustained for legato grid alignment (age < 0.5s or heldForPending) must not be treated as orphans
    const now = 100.5;
    const voice = { note: 60, channel: 0, startTime: 100.0, heldForPending: "event_1" };
    const maxAge = R6_CONTRACT.maxOrphanAgeSec;

    const isOrphan = R6_CONTRACT.isVoiceOrphaned(voice, now, maxAge);
    expect(isOrphan).toBe(false);
  });

  test("r3_r6_interaction_02_90_percent_quantize_with_staccato_retrigger", () => {
    // 90% strength with staccato release guarantees clean voice re-attack via MidiVoiceTracker
    const tracker = new MidiVoiceTracker();

    // Tap 1 with 90% quantize delay
    const delay = R3_CONTRACT.calculateDelay(120, "1/4", 90, 0.1);
    expect(delay).toBeCloseTo(0.36, 4);

    tracker.noteOn(60, 0, 100, 1, 100.0 + delay);
    // Immediate staccato release
    tracker.noteOff(60, 0, 100.0 + delay + 0.05);
    // Rapid Tap 2
    tracker.noteOn(60, 0, 100, 1, 100.5);
    tracker.noteOff(60, 0, 100.55);

    expect(tracker.activeVoices.size).toBe(0);
    expect(tracker.sentMessages.length).toBe(4);
  });

  test("r3_r6_interaction_03_zero_percent_quantize_with_rapid_releases", () => {
    const delay = R3_CONTRACT.calculateDelay(120, "1/4", 0, 0.1);
    expect(delay).toBe(0);

    const tracker = new MidiVoiceTracker();
    tracker.noteOn(60, 0, 100, 1, 100.0);
    const now = 101.0;
    const voice = tracker.activeVoices.get("60_0");
    const isOrphan = R6_CONTRACT.isVoiceOrphaned(voice, now, R6_CONTRACT.maxOrphanAgeSec);
    expect(isOrphan).toBe(false);
    tracker.noteOff(60, 0, 101.0);
    expect(tracker.activeVoices.size).toBe(0);
  });
});
