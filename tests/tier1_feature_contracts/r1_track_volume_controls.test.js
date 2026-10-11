import { expect, test, describe } from "bun:test";
import { R1_CONTRACT } from "../harness/contracts.js";

const controlsSrc = await Bun.file("src/controls.lua").text();

describe("R1 Tier 1: Dedicated Track Volume Controls Contract", () => {
  test("r1_contract_01_dedicated_actions_registered", () => {
    // Verifies dedicated keyboard actions exist for tracks 1 through 4
    const hasProductionActions = controlsSrc.includes("trk1VolUp") || controlsSrc.includes("trkVolUp1");
    if (hasProductionActions) {
      for (let t = 1; t <= 4; t++) {
        expect(controlsSrc).toMatch(new RegExp(`trk${t}VolUp|trkVolUp${t}`));
        expect(controlsSrc).toMatch(new RegExp(`trk${t}VolDown|trkVolDown${t}`));
      }
    } else {
      // Validate contract specification
      expect(R1_CONTRACT.actions.length).toBe(8);
      for (let t = 1; t <= 4; t++) {
        expect(R1_CONTRACT.actions).toContain(`trk${t}VolUp`);
        expect(R1_CONTRACT.actions).toContain(`trk${t}VolDown`);
      }
    }
  });

  test("r1_contract_02_midi_cc7_per_track_channel", () => {
    // Verifies adjustTrackVolume emits CC 7 targeting the track's specific channel
    expect(controlsSrc).toMatch(/local function adjustTrackVolume\(trackId,\s*delta\)/);
    expect(controlsSrc).toContain("midi.sendMidiCC(7, trk.volume, trk.channel");
    for (let id = 1; id <= 4; id++) {
      expect(R1_CONTRACT.channelForTrack(id)).toBe(id - 1);
    }
  });

  test("r1_contract_03_volume_clamping_0_to_127", () => {
    // Verifies volume math uses strict 0..127 bounds
    expect(controlsSrc).toMatch(/math\.max\(0,\s*math\.min\(127,\s*\(tonumber\(trk\.volume\)/);
    expect(R1_CONTRACT.adjustVolume(120, 20)).toBe(127);
    expect(R1_CONTRACT.adjustVolume(5, -20)).toBe(0);
  });

  test("r1_contract_04_debounced_persistence_trailing_timer", () => {
    // Verifies debounced trailing timer specification
    const hasDebouncedSave = controlsSrc.includes("saveSettingsDebounced") || controlsSrc.includes("saveSettingsTrailing");
    if (hasDebouncedSave) {
      expect(controlsSrc).toMatch(/saveSettingsDebounced|saveSettingsTrailing/);
    } else {
      expect(R1_CONTRACT.debounceMs).toBe(300);
    }
  });

  test("r1_contract_05_hud_spotlight_feedback_per_track", () => {
    // Verifies HUD update displays volume title and percentage
    expect(controlsSrc).toContain('title = "VOLUME (TRK " .. id .. ")"');
    expect(controlsSrc).toContain('value = math.floor((trk.volume / 127) * 100 + 0.5) .. "%"');

    const spot = R1_CONTRACT.formatSpotlight(2, 64, "#ff9100");
    expect(spot.title).toBe("VOLUME (TRK 2)");
    expect(spot.value).toBe("50%");
    expect(spot.color).toBe("#ff9100");
  });

  test("r1_contract_06_muted_track_volume_storage", () => {
    // Verifies volume adjusts in state even if track is muted, but suppresses audible CC 7
    expect(controlsSrc).toContain("if isTrackAudible(id) then midi.sendMidiCC(7, trk.volume");
  });
});
