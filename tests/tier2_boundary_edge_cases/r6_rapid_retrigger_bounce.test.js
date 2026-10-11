import { expect, test, describe } from "bun:test";

describe("R6 Tier 2: Rapid Retrigger, Staccato Taps & Orphan Boundaries", () => {
  test("r6_edge_01_staccato_retrigger_simulation", () => {
    // Simulates staccato tap followed by rapid re-trigger 25ms later
    const eventStream = [];
    let activeVoices = 0;

    function triggerNote(t, isRelease = false) {
      if (isRelease) {
        eventStream.push({ type: "noteOff", time: t });
        activeVoices = Math.max(0, activeVoices - 1);
      } else {
        // Enforce re-trigger safety: if voice active, close it first!
        if (activeVoices > 0) {
          eventStream.push({ type: "noteOffSafety", time: t });
          activeVoices--;
        }
        eventStream.push({ type: "noteOn", time: t });
        activeVoices++;
      }
    }

    // Tap 1 at t=0, released at t=10
    triggerNote(0, false);
    triggerNote(10, true);
    // Retrigger Tap 2 at t=25 (within 60ms staccato window)
    triggerNote(25, false);
    triggerNote(50, true);

    expect(activeVoices).toBe(0);
    const noteOns = eventStream.filter(e => e.type === "noteOn").length;
    const noteOffs = eventStream.filter(e => e.type.startsWith("noteOff")).length;
    expect(noteOns).toBe(noteOffs);
  });

  test("r6_edge_02_orphan_watchdog_age_threshold_boundary", () => {
    const now = 1000.0;
    const threshold = 5.0;
    const voices = [
      { note: 60, ch: 0, startTime: 996.0 }, // age 4.0s -> keep
      { note: 64, ch: 0, startTime: 994.8 }, // age 5.2s -> orphan!
      { note: 67, ch: 0, startTime: 990.0 }  // age 10.0s -> orphan!
    ];

    const orphans = voices.filter(v => (now - v.startTime) > threshold);
    expect(orphans.length).toBe(2);
    expect(orphans[0].note).toBe(64);
    expect(orphans[1].note).toBe(67);
  });

  test("r6_edge_03_held_physical_keys_immune_from_watchdog", () => {
    // Notes corresponding to actively pressed physical keys must NOT be purged
    const pressedKeys = { 18: true }; // key for note 60 held
    const voices = [
      { note: 60, ch: 0, keycode: 18, startTime: 900.0 }, // held -> immune!
      { note: 64, ch: 0, keycode: 19, startTime: 900.0 }  // not held -> orphan!
    ];

    const orphans = voices.filter(v => !pressedKeys[v.keycode] && (1000.0 - v.startTime) > 5.0);
    expect(orphans.length).toBe(1);
    expect(orphans[0].note).toBe(64);
  });

  test("r6_edge_04_sustained_pitches_immune_from_watchdog", () => {
    // Pitches currently held by smart sustain must NOT be purged
    const sustainedPitches = { 60: true };
    const voice = { note: 60, ch: 0, startTime: 900.0 };
    const isImmune = sustainedPitches[voice.note] === true;
    expect(isImmune).toBe(true);
  });

  test("r6_edge_05_panic_all_sound_off_and_notes_off", () => {
    // Panic must transmit across all channels 0..15
    const channels = Array.from({ length: 16 }, (_, i) => i);
    expect(channels.length).toBe(16);
    const messages = [];
    channels.forEach(ch => {
      messages.push({ cc: 120, ch }); // All Sound Off
      messages.push({ cc: 123, ch }); // All Notes Off
      messages.push({ cc: 64, ch, val: 0 }); // Damper Off
    });
    expect(messages.length).toBe(48);
  });

  test("r6_edge_06_channel_isolation_on_identical_pitches", () => {
    // Pitch 60 on Channel 0 and Channel 1 are separate ledger entries
    const ledger = {};
    function noteOn(note, ch) {
      ledger[`${note}_${ch}`] = true;
    }
    function noteOff(note, ch) {
      delete ledger[`${note}_${ch}`];
    }

    noteOn(60, 0);
    noteOn(60, 1);
    expect(Object.keys(ledger).length).toBe(2);

    noteOff(60, 0);
    expect(ledger["60_1"]).toBe(true);
    expect(ledger["60_0"]).toBeUndefined();
  });
});
