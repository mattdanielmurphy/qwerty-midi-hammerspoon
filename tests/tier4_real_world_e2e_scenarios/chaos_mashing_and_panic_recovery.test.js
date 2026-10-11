import { expect, test, describe } from "bun:test";
import { R6_CONTRACT, MidiVoiceTracker } from "../harness/contracts.js";

const midiSrc = await Bun.file("src/midi.lua").text();
const controlsSrc = await Bun.file("src/controls.lua").text();

describe("Tier 4 Scenario 2: Chaos Key Mashing & Panic Recovery", () => {
  test("tier4_scenario_01_100_burst_events_and_panic_clean", () => {
    const tracker = new MidiVoiceTracker();

    // Dispatch 100 chaotic note events across 4 channels
    for (let i = 0; i < 100; i++) {
      const pitch = 36 + (i % 24);
      const ch = i % 4;
      if (i % 3 === 0) {
        tracker.noteOff(pitch, ch, i * 0.01);
      } else {
        tracker.noteOn(pitch, ch, 100, (ch + 1), i * 0.01, 18 + (i % 10));
      }
    }

    expect(tracker.activeVoices.size).toBeGreaterThan(0);

    // Trigger panic
    const panicMsgs = tracker.panic();

    expect(tracker.activeVoices.size).toBe(0);
    expect(panicMsgs.length).toBe(16 * 5); // 80 messages across all 16 channels

    // Verify production panic integration
    expect(midiSrc).toContain("local function panicAllChannels()");
    expect(controlsSrc).toMatch(/elseif act == "panic" then[\s\S]*?midi\.panicAllChannels\(\)/);
  });

  test("tier4_scenario_02_panic_all_sound_off_message_generation", () => {
    const messages = R6_CONTRACT.generatePanicMessages();

    // Verify all 16 MIDI channels receive full panic sweep
    for (let ch = 0; ch < 16; ch++) {
      const chMsgs = messages.filter(m => m.channel === ch);
      expect(chMsgs.length).toBe(5);
      expect(chMsgs.map(m => m.controller).filter(c => c !== undefined)).toEqual([64, 120, 123, 121]);
      expect(chMsgs.some(m => m.type === "pitchWheel" && m.value === 8192)).toBe(true);
    }
  });
});
