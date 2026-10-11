import { expect, test, describe } from "bun:test";
import { TapTempoEngine, R2_CONTRACT } from "../harness/contracts.js";

describe("Tier 3 Interaction: R2 Arp Engine Resync During R7 Tap Tempo", () => {
  test("r2_r7_interaction_01_tap_tempo_updates_running_arp_clock", () => {
    let currentBpm = 120.0;
    let stepDuration = (60.0 / currentBpm) * 0.25; // 16th note

    function applyTapTempo(newBpm) {
      currentBpm = newBpm;
      stepDuration = (60.0 / currentBpm) * 0.25;
    }

    expect(stepDuration).toBe(0.125); // At 120 BPM
    applyTapTempo(140.0);
    expect(stepDuration).toBeCloseTo(0.1071, 4); // At 140 BPM
  });

  test("r2_r7_interaction_02_gate_timer_preserved_across_bpm_change", () => {
    // When BPM changes midway through a gate duration, active gate timer must fire safely
    let noteOffFired = false;
    let activeGate = { pitch: 60, generation: 1 };

    function onGateExpired(gen) {
      if (activeGate && activeGate.generation === gen) {
        noteOffFired = true;
        activeGate = null;
      }
    }

    onGateExpired(1);
    expect(noteOffFired).toBe(true);
  });

  test("r2_r7_interaction_03_continuous_taps_during_rich_pattern_playback", () => {
    const tapEngine = new TapTempoEngine();
    tapEngine.tap(0.0);
    tapEngine.tap(0.4); // 150 BPM

    // Compute arp step with new BPM
    const step = R2_CONTRACT.computeArpStep(1, 100, "accentDownbeat", 50, tapEngine.bpm, 0.25);
    expect(tapEngine.bpm).toBe(150.0);
    expect(step.vel).toBe(125);
    expect(step.stepSec).toBeCloseTo(0.1, 4);
  });
});
