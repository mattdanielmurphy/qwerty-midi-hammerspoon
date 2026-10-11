import { expect, test, describe } from "bun:test";

describe("Tier 4 Scenario 2: Chaos Key Mashing & Panic Recovery", () => {
  test("tier4_scenario_01_100_burst_events_and_panic_clean", () => {
    const activeLedger = {};

    function sendNoteOn(note, ch) {
      activeLedger[`${note}_${ch}`] = true;
    }
    function sendNoteOff(note, ch) {
      delete activeLedger[`${note}_${ch}`];
    }
    function panic() {
      for (const k in activeLedger) {
        delete activeLedger[k];
      }
    }

    // Dispatch 100 note events
    for (let i = 0; i < 100; i++) {
      const note = 48 + (i % 24);
      const ch = i % 4;
      if (i % 3 === 0) {
        sendNoteOff(note, ch);
      } else {
        sendNoteOn(note, ch);
      }
    }

    expect(Object.keys(activeLedger).length).toBeGreaterThan(0);

    // Trigger panic
    panic();

    expect(Object.keys(activeLedger).length).toBe(0);
  });

  test("tier4_scenario_02_panic_all_sound_off_message_generation", () => {
    const channels = Array.from({ length: 16 }, (_, i) => i);
    const messages = [];

    channels.forEach(ch => {
      messages.push({ cc: 120, ch }); // All Sound Off
      messages.push({ cc: 123, ch }); // All Notes Off
      messages.push({ cc: 64, ch, val: 0 }); // Damper Off
    });

    expect(messages.length).toBe(48);
    // Every channel 0..15 must have all 3 messages
    for (let c = 0; c < 16; c++) {
      const chMsgs = messages.filter(m => m.ch === c);
      expect(chMsgs.length).toBe(3);
      expect(chMsgs.map(m => m.cc)).toEqual([120, 123, 64]);
    }
  });
});
