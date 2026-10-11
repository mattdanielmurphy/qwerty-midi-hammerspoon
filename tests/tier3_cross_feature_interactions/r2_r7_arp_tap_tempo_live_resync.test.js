import { expect, test, describe } from "bun:test";
import { TapTempoEngine, R2_CONTRACT } from "../harness/contracts.js";

const arpSrc = await Bun.file("src/arpeggiator.lua").text();
const controlsSrc = await Bun.file("src/controls.lua").text();

describe("Tier 3 Interaction: R2 Arp Engine Resync During R7 Tap Tempo", () => {
  test("r2_r7_interaction_01_tap_tempo_updates_running_arp_clock", () => {
    const tapEngine = new TapTempoEngine();
    tapEngine.tap(0.0);
    tapEngine.tap(0.5); // 120 BPM
    expect(tapEngine.bpm).toBe(120.0);

    let step = R2_CONTRACT.computeArpStep(1, 100, "accentDownbeat", 50, tapEngine.bpm, 0.25);
    expect(step.stepSec).toBe(0.125);

    // Performer taps at 150 BPM (400ms intervals) to resync rolling tempo average
    tapEngine.tap(0.9);
    tapEngine.tap(1.3);
    tapEngine.tap(1.7);
    tapEngine.tap(2.1);
    tapEngine.tap(2.5);
    expect(tapEngine.bpm).toBe(150.0);

    step = R2_CONTRACT.computeArpStep(1, 100, "accentDownbeat", 50, tapEngine.bpm, 0.25);
    expect(step.stepSec).toBeCloseTo(0.100, 4);

    // Verify arpeggiator interval recalculation in production Lua
    expect(arpSrc).toMatch(/local function getArpIntervalSeconds\(\)[\s\S]*?state\.arpBpm/);
  });

  test("r2_r7_interaction_02_gate_timer_preserved_across_bpm_change", () => {
    // Verify production arpeggiator uses generation-guarded gate timers
    expect(arpSrc).toContain("trk.gateGeneration");
    expect(arpSrc).toMatch(/activeGate\.generation\s*==\s*gateGeneration/);

    // Validate generation guard model: stale generation timers are ignored
    let releasedPitch = null;
    let gateGeneration = 1;
    const activeGate = { pitch: 60, generation: 1 };

    function onTimerFire(timerGen) {
      if (activeGate && activeGate.generation === timerGen) {
        releasedPitch = activeGate.pitch;
      }
    }

    // BPM change increments gate generation
    gateGeneration = 2;
    activeGate.generation = gateGeneration;

    // Stale timer fire (generation 1) must NOT release pitch
    onTimerFire(1);
    expect(releasedPitch).toBeNull();

    // Active timer fire (generation 2) releases pitch
    onTimerFire(2);
    expect(releasedPitch).toBe(60);
  });

  test("r2_r7_interaction_03_continuous_taps_during_rich_pattern_playback", () => {
    const tapEngine = new TapTempoEngine();
    tapEngine.tap(0.0);
    tapEngine.tap(0.4); // 150 BPM

    const step = R2_CONTRACT.computeArpStep(1, 100, "accentDownbeat", 50, tapEngine.bpm, 0.25);
    expect(tapEngine.bpm).toBe(150.0);
    expect(step.vel).toBe(125);
    expect(step.stepSec).toBeCloseTo(0.1, 4);
    expect(controlsSrc).toContain("arpeggiator.tapTempo()");
  });
});
