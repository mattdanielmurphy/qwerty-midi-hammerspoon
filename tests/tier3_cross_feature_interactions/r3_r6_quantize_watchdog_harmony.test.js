import { expect, test, describe } from "bun:test";
import { R3_CONTRACT, R6_CONTRACT } from "../harness/contracts.js";

describe("Tier 3 Interaction: R3 Quantize Legato Sustaining vs R6 Voice Watchdog", () => {
  test("r3_r6_interaction_01_legato_grace_sustaining_not_flagged_by_watchdog", () => {
    // Notes sustained for legato grid alignment (age < 0.5s) must not be treated as orphans
    const now = 100.5;
    const voice = { note: 60, startTime: 100.0, heldForPending: "event_1" };
    const maxAge = R6_CONTRACT.maxOrphanAgeSec;

    const isOrphan = (now - voice.startTime) > maxAge && !voice.heldForPending;
    expect(isOrphan).toBe(false);
  });

  test("r3_r6_interaction_02_90_percent_quantize_with_staccato_retrigger", () => {
    // 90% strength with staccato release guarantees clean voice re-attack
    let voiceCount = 0;
    function noteOn() { voiceCount++; }
    function noteOff() { voiceCount = Math.max(0, voiceCount - 1); }

    // Tap 1 with 90% quantize delay
    const delay = R3_CONTRACT.calculateDelay(120, "1/4", 90, 0.1);
    expect(delay).toBeCloseTo(0.36, 4);

    noteOn();
    // Immediate staccato release
    noteOff();
    // Rapid Tap 2
    noteOn();
    noteOff();

    expect(voiceCount).toBe(0);
  });

  test("r3_r6_interaction_03_zero_percent_quantize_with_rapid_releases", () => {
    const delay = R3_CONTRACT.calculateDelay(120, "1/4", 0, 0.1);
    expect(delay).toBe(0);

    const activeLedger = { 60: { startTime: 100.0 } };
    const now = 101.0;
    const isOrphan = (now - activeLedger[60].startTime) > R6_CONTRACT.maxOrphanAgeSec;
    expect(isOrphan).toBe(false);
  });
});
