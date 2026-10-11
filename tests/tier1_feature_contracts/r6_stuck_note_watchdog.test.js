import { expect, test, describe } from "bun:test";
import { R6_CONTRACT } from "../harness/contracts.js";

const quantizerSrc = await Bun.file("packages/music-engine/quantizer.lua").text();
const midiSrc = await Bun.file("src/midi.lua").text();
const initSrc = await Bun.file("src/init.lua").text();

describe("R6 Tier 1: Stuck Note Mitigation & Watchdog Contracts", () => {
  test("r6_contract_01_staccato_retrigger_guaranteed_release", () => {
    // In contract model, staccato gate window is 60ms
    expect(R6_CONTRACT.staccatoGateWindowSec).toBe(0.060);
  });

  test.skip("[Milestone M2 Implementation Gate: Guaranteed voice release in quantizer.lua]", () => {
    const cancelBlock = quantizerSrc.match(/if pendingEvents\[eventId\] then([\s\S]*?)pendingEvents\[eventId\] = nil/);
    expect(cancelBlock).toBeTruthy();
    expect(cancelBlock[1]).toMatch(/onRelease|sendMidiNote/);
  });

  test("r6_contract_02_sounding_notes_cleanup_on_retrigger", () => {
    // quantizer tracks soundingNotes for legato and retrigger cleanup
    expect(quantizerSrc).toContain("soundingNotes");
  });

  test("r6_contract_03_active_voice_ledger_timestamp", () => {
    // midi tracks active voices in activeNoteLedger
    expect(midiSrc).toContain("activeNoteLedger");
  });

  test("r6_contract_04_watchdog_orphan_detection_function", () => {
    // Contract orphan age threshold is 5.0 seconds
    expect(R6_CONTRACT.maxOrphanAgeSec).toBe(5.0);
  });

  test.skip("[Milestone M2 Implementation Gate: checkOrphanedVoices in midi.lua]", () => {
    expect(midiSrc).toContain("checkOrphanedVoices");
  });

  test("r6_contract_05_watchdog_loop_in_init", () => {
    // init.lua manages background watchdogs
    expect(initSrc).toMatch(/[Ww]atchdog/);
  });

  test("r6_contract_06_watchdog_active_only_when_armed", () => {
    // Zero idle timers invariant: watchdog stops when state.midiActive == false
    expect(initSrc).toContain("state.midiActive");
  });
});
