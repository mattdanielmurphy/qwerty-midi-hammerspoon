import { expect, test, describe } from "bun:test";
import { R1_CONTRACT, R2_CONTRACT, R3_CONTRACT, MidiVoiceTracker } from "../harness/contracts.js";

const controlsSrc = await Bun.file("src/controls.lua").text();

describe("Tier 4 Scenario 1: Multi-Track Polyphonic Live Performance Jam", () => {
  test("tier4_scenario_01_full_performance_lifecycle", () => {
    const tracker = new MidiVoiceTracker();

    // Track 1: Bass (Channel 0), Volume 110, 90% Quantize
    const delayTrk1 = R3_CONTRACT.calculateDelay(120, "1/8", 90, 0.05);
    expect(delayTrk1).toBeGreaterThan(0);
    tracker.noteOn(36, 0, 110, 1, 100.0 + delayTrk1);

    // Track 2: Polyphonic Chord {48, 52, 55} (Channel 1), Volume 95
    [48, 52, 55].forEach(pitch => {
      tracker.noteOn(pitch, 1, 95, 2, 100.1);
    });

    // Track 3: Arp Lead Note 72 (Channel 2), Volume 120, Accent Downbeat
    const arpStep = R2_CONTRACT.computeArpStep(1, 120, "accentDownbeat", 50, 120, 0.25);
    expect(arpStep.vel).toBe(127); // 120 * 1.25 clamped to 127
    tracker.noteOn(72, 2, arpStep.vel, 3, 100.125);

    // Assert multi-track polyphonic voice counts across channels
    expect(tracker.activeVoices.size).toBe(5);
    expect(Array.from(tracker.activeVoices.values()).filter(v => v.channel === 0).length).toBe(1);
    expect(Array.from(tracker.activeVoices.values()).filter(v => v.channel === 1).length).toBe(3);
    expect(Array.from(tracker.activeVoices.values()).filter(v => v.channel === 2).length).toBe(1);

    // Live volume adjustment on Track 1
    const newVol1 = R1_CONTRACT.adjustVolume(110, -10);
    expect(newVol1).toBe(100);

    // Release all notes
    tracker.noteOff(36, 0, 101.0);
    [48, 52, 55].forEach(pitch => tracker.noteOff(pitch, 1, 101.0));
    tracker.noteOff(72, 2, 101.0);

    expect(tracker.activeVoices.size).toBe(0);
  });

  test("tier4_scenario_02_independent_track_muting_during_performance", () => {
    // Assert production track muting architecture in src/controls.lua
    expect(controlsSrc).toMatch(/trk\.muted\s*=\s*not trk\.muted/);
    expect(controlsSrc).toContain("midi.sendMidiCC(108, trk.muted and 127 or 0, ch)");

    // Test channel-specific volume restoration
    const restoredCC = R1_CONTRACT.restoreVolumeCC(100);
    expect(restoredCC).toBe(127);
  });
});
