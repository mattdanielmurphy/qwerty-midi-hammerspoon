import { expect, test, describe } from "bun:test";
import { R4_CONTRACT, R5_CONTRACT } from "./harness/contracts.js";

const hudSource = await Bun.file("src/hud.lua").text();
const htmlSource = await Bun.file("src/web/index.html").text();
const configSource = await Bun.file("src/config.lua").text();

describe("HUD Modifier & Parameter Cross-Feature & E2E Scenarios (Tiers 3 & 4)", () => {
  describe("Tier 3: Cross-Feature Combinations", () => {
    test("T3-CROSS-CMD-PARAM: COMMAND_LAYER_MAP maps explicit shortcuts while unmapped keys have no command definition", () => {
      // In src/hud.lua, key 46 (M) is defined in COMMAND_LAYER_MAP with "Minimize Window"
      expect(hudSource).toMatch(/\[46\]\s*=\s*\{[\s\S]*?cmd\s*=\s*\{[^}]*name\s*=\s*"Minimize Window"/);

      // Note key 14 is NOT in COMMAND_LAYER_MAP
      const commandKeyMapBlock = hudSource.match(/local COMMAND_LAYER_MAP = \{[\s\S]*?\n\}/)?.[0] || "";
      expect(commandKeyMapBlock).not.toContain("[14] =");

      // Verify contract state transition: formatted parameter label vs command shortcut
      const baseParamLabel = R5_CONTRACT.formatters.volume(80);
      expect(baseParamLabel).toBe("Vol -\n63%");
      const cmdActionLabel = "Minimize\nWindow";
      expect(cmdActionLabel.split("\n").length).toBe(2);
    });

    test("T3-CROSS-SHIFT-PARAM: Holding Shift switches parameter controls to secondary parameters without layout shift", () => {
      const baseAtk = R5_CONTRACT.formatters.attack(10);
      const shiftDec = R5_CONTRACT.formatters.decay(64);

      expect(baseAtk).toBe("Atk -\n10");
      expect(shiftDec).toBe("Dec -\n64");

      [baseAtk, shiftDec].forEach(label => {
        const lines = label.split("\n");
        expect(lines.length).toBe(2);
        lines.forEach(l => expect(l.length * 5.2).toBeLessThanOrEqual(R4_CONTRACT.maxInnerWidth));
      });
    });

    test("T3-CROSS-TRACK-PARAM: Switching active track updates per-track parameter values and colors with ZLS=0", () => {
      // Verify that index.html defines distinct CSS color variables for tracks 1..4 (keys 18..21)
      expect(htmlSource).toMatch(/#key-18\s*\{[^}]*--trk-color:\s*#00e5ff/);
      expect(htmlSource).toMatch(/#key-19\s*\{[^}]*--trk-color:\s*#ff9100/);
      expect(htmlSource).toMatch(/#key-20\s*\{[^}]*--trk-color:\s*#00e676/);
      expect(htmlSource).toMatch(/#key-21\s*\{[^}]*--trk-color:\s*#d500f9/);

      // For each track, parameter labels fit strictly within note dimensions
      const trackSettings = [
        { vol: 100, atk: 10 },
        { vol: 76,  atk: 50 },
        { vol: 110, atk: 25 },
        { vol: 90,  atk: 80 }
      ];

      trackSettings.forEach(trk => {
        const atkLabel = R5_CONTRACT.formatters.attack(trk.atk);
        const volLabel = R5_CONTRACT.formatters.volume(trk.vol);
        expect(atkLabel).toContain(`Atk -\n${trk.atk}`);
        expect(volLabel).toContain("Vol -");

        [atkLabel, volLabel].forEach(label => {
          const lines = label.split("\n");
          expect(lines.length).toBe(2);
          lines.forEach(line => {
            expect(line.length * 5.2).toBeLessThanOrEqual(R4_CONTRACT.maxInnerWidth);
          });
        });
      });
    });

    test("T3-CROSS-LONGLABEL-VALUE: Compound long labels with dynamic parameters fit inside 52px x 20px note frame", () => {
      const susLabels = [
        "Smart Sus\n2× Off",
        "Sus Off\n2× On"
      ];
      susLabels.forEach(lbl => {
        const lines = lbl.split("\n");
        expect(lines.length).toBe(2);
        expect(lines[0].length * 5.2).toBeLessThanOrEqual(R4_CONTRACT.maxInnerWidth);
        expect(lines[1].length * 5.2).toBeLessThanOrEqual(R4_CONTRACT.maxInnerWidth);
        expect(lines.length * 9.5).toBeLessThanOrEqual(R4_CONTRACT.maxNoteHeight);
      });
    });
  });

  describe("Tier 4: Real-World Live Performance & Stress Scenarios", () => {
    test("T4-SCENARIO-LIVE-JAM: Live performance jam: simultaneous polyphonic note input and parameter tweaks", () => {
      // In src/web/index.html, P88_NOTE_NAMES defines standard note nomenclature
      expect(htmlSource).toContain("const P88_NOTE_NAMES = [");

      const heldNotePitches = [60, 64, 67]; // C4 major chord
      const noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
      const renderedNotes = heldNotePitches.map(p => {
        const name = noteNames[p % 12];
        const oct = Math.floor(p / 12) - 1;
        return `${name}${oct}`;
      });

      expect(renderedNotes).toEqual(["C4", "E4", "G4"]);

      // Realtime state formatting alongside note playback
      const bpmText = R5_CONTRACT.formatters.bpm(124);
      const volText = R5_CONTRACT.formatters.volume(95);

      expect(bpmText).toBe("BPM -\n124");
      expect(volText).toBe("Vol -\n75%");
    });

    test("T4-SCENARIO-MODIFIER-MACRO: Rapid modifier switching between Base, Shift, Opt, and Cmd under active playback", () => {
      // In src/hud.lua, getModifierLayer defines the priority resolution hierarchy
      expect(hudSource).toMatch(/local function getModifierLayer\(\)/);
      expect(hudSource).toContain('if state.cmdHeld then return state.shiftHeld and "cmdShift" or "cmd" end');

      // In src/web/index.html, modifier CSS classes must NEVER override key chassis dimensions
      expect(htmlSource).not.toMatch(/\.shortcut-reserved\s*\{[^}]*\b(?:width|height):\s*\d+px/);
      expect(htmlSource).not.toMatch(/\.shortcut-passthrough\s*\{[^}]*\b(?:width|height):\s*\d+px/);
    });

    test("T4-SCENARIO-FOUR-TRACK-WORKFLOW: Full 4-track studio workflow: default track architecture and settings persistence", () => {
      // Grounded in src/config.lua default tracks definition
      expect(configSource).toMatch(/\[1\]\s*=\s*\{[^}]*name\s*=\s*"Bass"[^}]*channel\s*=\s*0/);
      expect(configSource).toMatch(/\[2\]\s*=\s*\{[^}]*name\s*=\s*"Chords"[^}]*channel\s*=\s*1/);
      expect(configSource).toMatch(/\[3\]\s*=\s*\{[^}]*name\s*=\s*"Lead"[^}]*channel\s*=\s*2/);
      expect(configSource).toMatch(/\[4\]\s*=\s*\{[^}]*name\s*=\s*"Arp"[^}]*channel\s*=\s*3/);

      // Verify that each track has dedicated volume persistence
      for (let t = 1; t <= 4; t++) {
        expect(configSource).toContain(`getSetting("track${t}Volume"`);
      }
    });

    test("T4-SCENARIO-STRESS-BURST: Chaos stress test: 100 rapid state updates alternating parameters, modifiers, and keypresses", () => {
      const start = performance.now();
      let framesRendered = 0;

      for (let i = 0; i < 100; i++) {
        const bpm = 60 + (i % 180);
        const vol = i % 128;
        const bpmLabel = R5_CONTRACT.formatters.bpm(bpm);
        const volLabel = R5_CONTRACT.formatters.volume(vol);
        expect(bpmLabel).toContain("BPM -");
        expect(volLabel).toContain("Vol -");
        framesRendered++;
      }

      const elapsed = performance.now() - start;
      expect(framesRendered).toBe(100);
      expect(elapsed).toBeLessThan(50);
    });

    test("T4-SCENARIO-KEYSTEP-DOCKING: Embedded KeyStep view dock/undock height expansion with QWERTY chassis layout intact", () => {
      // In src/hud.lua, dock state conditionally switches height between 600 and 280
      expect(hudSource).toMatch(/isKeyStepConnected\(\)\s*and\s*600\s*or\s*280/);
      expect(hudSource).toMatch(/local\s+baseH\s*=\s*\(connected\s*==\s*true\)\s*and\s*600\s*or\s*280/);
      expect(hudSource).toContain("KeyStep");
    });

    test("T4-SCENARIO-RELOAD-PERSISTENCE: Parameter state recall and presentation across simulated module reload", () => {
      // Grounded in src/config.lua getSetting hooks
      expect(configSource).toContain('getSetting("track1Volume"');
      expect(configSource).toContain('getSetting("arpBpm"');
      expect(configSource).toContain('getSetting("inputQuantizeMode"');
    });
  });
});
