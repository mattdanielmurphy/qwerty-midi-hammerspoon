import { expect, test, describe } from "bun:test";
import { R6_CONTRACT, MidiVoiceTracker } from "../harness/contracts.js";

describe("R6 Tier 2: Rapid Retrigger, Staccato Taps & Orphan Boundaries", () => {
  test("r6_edge_01_staccato_retrigger_simulation", () => {
    // Simulates staccato tap followed by rapid re-trigger 25ms later using MidiVoiceTracker
    const tracker = new MidiVoiceTracker();

    // Tap 1 at t=0, released at t=10
    tracker.noteOn(60, 0, 100, 1, 0.0, 18);
    tracker.noteOff(60, 0, 0.010);

    // Retrigger Tap 2 at t=25 (within 60ms staccato window)
    tracker.noteOn(60, 0, 100, 1, 0.025, 18);
    tracker.noteOff(60, 0, 0.050);

    expect(tracker.activeVoices.size).toBe(0);
    const noteOns = tracker.sentMessages.filter(e => e.type === "noteOn").length;
    const noteOffs = tracker.sentMessages.filter(e => e.type === "noteOff").length;
    expect(noteOns).toBe(2);
    expect(noteOffs).toBe(2);
  });

  test("r6_edge_02_orphan_watchdog_age_threshold_boundary", () => {
    const now = 1000.0;
    const threshold = 5.0;
    const voices = [
      { note: 60, channel: 0, startTime: 996.0 }, // age 4.0s -> keep
      { note: 64, channel: 0, startTime: 994.8 }, // age 5.2s -> orphan!
      { note: 67, channel: 0, startTime: 990.0 }  // age 10.0s -> orphan!
    ];

    const orphans = voices.filter(v => R6_CONTRACT.isVoiceOrphaned(v, now, threshold));
    expect(orphans.length).toBe(2);
    expect(orphans[0].note).toBe(64);
    expect(orphans[1].note).toBe(67);
  });

  test("r6_edge_03_held_physical_keys_immune_from_watchdog", () => {
    // Notes corresponding to actively pressed physical keys must NOT be purged
    const state = { pressedKeys: { 18: true } }; // key for note 60 held
    const sustainedVoice = { note: 60, channel: 0, keycode: 18, startTime: 900.0 };
    const orphanedVoice = { note: 64, channel: 0, keycode: 19, startTime: 900.0 };

    expect(R6_CONTRACT.isVoiceOrphaned(sustainedVoice, 1000.0, 5.0, state)).toBe(false);
    expect(R6_CONTRACT.isVoiceOrphaned(orphanedVoice, 1000.0, 5.0, state)).toBe(true);
  });

  test("r6_edge_04_sustained_pitches_immune_from_watchdog", async () => {
    const controlsSrc = await Bun.file("src/controls.lua").text();
    expect(controlsSrc).toMatch(/trk\.sustainedPitches|state\.sustainedPitches/);

    const currentTime = 1000.0;
    const threshold = R6_CONTRACT.maxOrphanAgeSec; // 5.0s
    const state = {
      sustainedPitches: { 60: true },
      pressedKeys: {}
    };

    const sustainedVoice = { note: 60, channel: 0, startTime: 900.0, keycode: 18 };
    const orphanedVoice = { note: 64, channel: 0, startTime: 900.0, keycode: 19 };

    expect(R6_CONTRACT.isVoiceOrphaned(sustainedVoice, currentTime, threshold, state)).toBe(false);
    expect(R6_CONTRACT.isVoiceOrphaned(orphanedVoice, currentTime, threshold, state)).toBe(true);
  });

  test("r6_edge_05_panic_all_sound_off_and_notes_off", async () => {
    const midiSrc = await Bun.file("src/midi.lua").text();

    // 1. Production code inspection in src/midi.lua
    expect(midiSrc).toContain("local function panicAllChannels()");
    expect(midiSrc).toContain("clearActiveNotes()");
    expect(midiSrc).toMatch(/for ch = 0, 15 do/);
    expect(midiSrc).toMatch(/controllerNumber = 64,\s*controllerValue = 0/);
    expect(midiSrc).toMatch(/controllerNumber = 120,\s*controllerValue = 0/);
    expect(midiSrc).toMatch(/controllerNumber = 123,\s*controllerValue = 0/);
    expect(midiSrc).toMatch(/controllerNumber = 121,\s*controllerValue = 0/);
    expect(midiSrc).toMatch(/pitchWheelChange.*8192/);

    // 2. Machine-executable contract validation
    const messages = R6_CONTRACT.generatePanicMessages();
    expect(messages.length).toBe(16 * 5); // 80 total panic messages
    for (let ch = 0; ch < 16; ch++) {
      const chMsgs = messages.filter(m => m.channel === ch);
      expect(chMsgs.length).toBe(5);
      expect(chMsgs.some(m => m.controller === 64 && m.value === 0)).toBe(true);
      expect(chMsgs.some(m => m.controller === 120 && m.value === 0)).toBe(true);
      expect(chMsgs.some(m => m.controller === 123 && m.value === 0)).toBe(true);
    }
  });

  test("r6_edge_06_channel_isolation_on_identical_pitches", () => {
    // Pitch 60 on Channel 0 and Channel 1 are separate ledger entries
    const tracker = new MidiVoiceTracker();

    tracker.noteOn(60, 0, 100, 1, 0.0);
    tracker.noteOn(60, 1, 100, 2, 0.0);
    expect(tracker.activeVoices.size).toBe(2);

    tracker.noteOff(60, 0, 0.1);
    expect(tracker.activeVoices.has("60_1")).toBe(true);
    expect(tracker.activeVoices.has("60_0")).toBe(false);
  });
});
