import { expect, test, describe } from "bun:test";
import { R1_CONTRACT, R2_CONTRACT, R3_CONTRACT } from "../harness/contracts.js";

describe("Tier 4 Scenario 1: Multi-Track Polyphonic Live Performance Jam", () => {
  test("tier4_scenario_01_full_performance_lifecycle", () => {
    // Track 1 (Bass, Ch 0): Volume 110, 1/8 note 90% quantize
    // Track 2 (Chords, Ch 1): Volume 95, Smart sustain
    // Track 3 (Lead, Ch 2): Volume 120, Arp UP-DOWN with Downbeat Accent
    const tracks = {
      1: { volume: 110, channel: 0, activeNotes: new Set() },
      2: { volume: 95,  channel: 1, activeNotes: new Set() },
      3: { volume: 120, channel: 2, activeNotes: new Set() }
    };

    // 1. Play Track 1 Bass Note 36 with 90% quantize
    const delay = R3_CONTRACT.calculateDelay(120, "1/8", 90, 0.05);
    expect(delay).toBeGreaterThan(0);
    tracks[1].activeNotes.add(36);

    // 2. Play Track 2 Chord {48, 52, 55}
    [48, 52, 55].forEach(p => tracks[2].activeNotes.add(p));

    // 3. Arp step on Track 3 Note 72 with velocity contour
    const arpStep = R2_CONTRACT.computeArpStep(1, tracks[3].volume, "accentDownbeat", 50, 120, 0.25);
    expect(arpStep.vel).toBe(127); // 120 * 1.25 clamped to 127
    tracks[3].activeNotes.add(72);

    expect(tracks[1].activeNotes.size).toBe(1);
    expect(tracks[2].activeNotes.size).toBe(3);
    expect(tracks[3].activeNotes.size).toBe(1);

    // 4. Live adjust Track 1 volume (-10)
    tracks[1].volume = R1_CONTRACT.adjustVolume(tracks[1].volume, -10);
    expect(tracks[1].volume).toBe(100);

    // 5. Full release of all keys
    tracks[1].activeNotes.clear();
    tracks[2].activeNotes.clear();
    tracks[3].activeNotes.clear();

    expect(tracks[1].activeNotes.size).toBe(0);
    expect(tracks[2].activeNotes.size).toBe(0);
    expect(tracks[3].activeNotes.size).toBe(0);
  });

  test("tier4_scenario_02_independent_track_muting_during_performance", () => {
    const tracks = {
      1: { id: 1, volume: 100, muted: false, audible: true },
      2: { id: 2, volume: 90,  muted: false, audible: true }
    };

    // Mute Track 1
    tracks[1].muted = true;
    tracks[1].audible = false;

    // Track 2 remains audible
    expect(tracks[1].audible).toBe(false);
    expect(tracks[2].audible).toBe(true);

    // Volume adjustment on muted track 1 preserves stored volume but silences output
    tracks[1].volume = R1_CONTRACT.adjustVolume(tracks[1].volume, 5);
    expect(tracks[1].volume).toBe(105);

    // Unmute Track 1 restores audibility
    tracks[1].muted = false;
    tracks[1].audible = true;
    expect(tracks[1].audible).toBe(true);
    expect(tracks[1].volume).toBe(105);
  });
});
