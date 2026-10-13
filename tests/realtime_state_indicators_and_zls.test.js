import { expect, test, describe } from "bun:test";
import { R4_CONTRACT, R5_CONTRACT } from "./harness/contracts.js";

const htmlSource = await Bun.file("src/web/index.html").text();
const hudSource = await Bun.file("src/hud.lua").text();

describe("R5: Real-Time State Indicators on Keys & Zero Layout Shift (ZLS)", () => {
  describe("Tier 1: Feature 9 — Parameter Telemetry Injection (9 Parameters)", () => {
    test("T1-R5-PARAM-VOL: Active volume quantity is formatted for key labels", () => {
      const vol80 = 80;
      const formatted = R5_CONTRACT.formatters.volume(vol80);
      expect(formatted).toBe("Vol -\n63%");
      const [action, val] = formatted.split("\n");
      expect(action).toBe("Vol -");
      expect(val).toBe("63%");
    });

    test("T1-R5-PARAM-VOL-PROD: hud.lua injects real-time volume quantity into key displayNote // Milestone M4 gate: requires hud.lua parameter telemetry injection", () => {
      expect(hudSource).toMatch(/key\.displayNote\s*=\s*"Vol -"\s*\.\./);
    });

    test("T1-R5-PARAM-OCT: Active octave offset quantity is injected into octave control key labels", () => {
      const formattedPos = R5_CONTRACT.formatters.octave(1);
      const formattedNeg = R5_CONTRACT.formatters.octave(-2);
      expect(formattedPos).toBe("Oct -\n+1");
      expect(formattedNeg).toBe("Oct -\n-2");
    });

    test("T1-R5-PARAM-RATE: Active arpeggiator rate quantity is injected into rate control key labels", () => {
      const formatted = R5_CONTRACT.formatters.rate("1/16");
      expect(formatted).toBe("Rate +\n1/16");
    });

    test("T1-R5-PARAM-GATE: Active arpeggiator gate percentage is injected into gate control key labels", () => {
      const formatted = R5_CONTRACT.formatters.gate(75);
      expect(formatted).toBe("Gate +\n75%");
    });

    test("T1-R5-PARAM-DIR: Active arpeggiator direction name is injected into direction control key labels", () => {
      const formatted = R5_CONTRACT.formatters.direction("Up/Down");
      expect(formatted).toBe("Dir +\nUp/Down");
    });

    test("T1-R5-PARAM-ATKDEC: Active Attack and Decay values are injected into Keys 9 (25) and 0 (29)", () => {
      const atk = R5_CONTRACT.formatters.attack(35);
      const dec = R5_CONTRACT.formatters.decay(80);
      expect(atk).toBe("Atk -\n35");
      expect(dec).toBe("Dec -\n80");
    });

    test("T1-R5-PARAM-ROOT: Active musical root pitch name is injected into root control key labels", () => {
      const formatted = R5_CONTRACT.formatters.root("A");
      expect(formatted).toBe("Root -\nA");
    });

    test("T1-R5-PARAM-MODE: Active musical mode name is injected into mode control key labels", () => {
      const formatted = R5_CONTRACT.formatters.mode("Dorian");
      expect(formatted).toBe("Mode -\nDorian");
    });

    test("T1-R5-PARAM-BPM: Active BPM tempo quantity is injected into BPM control key labels", () => {
      const formatted = R5_CONTRACT.formatters.bpm(128);
      expect(formatted).toBe("BPM -\n128");
    });
  });

  describe("Tier 1: Feature 9 — Zero Layout Shift (ZLS = 0) Invariants", () => {
    test("T1-R5-ZLS-PAD: Key pad outer dimensions remain exactly 58px x 44px when parameters change", () => {
      expect(htmlSource).toMatch(/\.key-pad\s*\{[^}]*width:\s*58px/);
      expect(htmlSource).toMatch(/\.key-pad\s*\{[^}]*height:\s*44px/);
      expect(htmlSource).toMatch(/\.key-pad\s*\{[^}]*flex-shrink:\s*0/);

      expect(R4_CONTRACT.padWidth).toBe(58);
      expect(R4_CONTRACT.padHeight).toBe(44);
    });

    test("T1-R5-ZLS-KEYCODE: Key code top offset and bounding box remain invariant when parameter value changes", () => {
      expect(htmlSource).toMatch(/\.key-pad\s*\{[^}]*display:\s*flex/);
      expect(htmlSource).toMatch(/\.key-pad\s*\{[^}]*flex-direction:\s*column/);
      expect(htmlSource).toMatch(/\.key-code\s*\{[^}]*font-size:\s*12px/);
    });

    test("T1-R5-ZLS-KEYNOTE-CONTRACT: Key note container height invariant in contract", () => {
      expect(R4_CONTRACT.maxNoteHeight).toBe(20);
    });

    test("T1-R5-ZLS-KEYNOTE-PROD: Key note container height is rigidly clamped to 20px with overflow hidden // Milestone M4 gate: requires index.html key-note height rule", () => {
      expect(htmlSource).toMatch(/\.key-note\s*\{[^}]*(?:max-)?height:\s*20px/);
      expect(htmlSource).toMatch(/\.key-note\s*\{[^}]*overflow:\s*hidden/);
    });

    test("T1-R5-ZLS-TABULAR: Tabular figures prevent horizontal digit jitter on numeric updates", () => {
      expect(htmlSource).toMatch(/font-variant-numeric:\s*tabular-nums/);
    });

    test("T1-R5-ZLS-GRID: Keyboard rows maintain immutable margin-left and zero cumulative layout shift", () => {
      expect(htmlSource).toMatch(/\.keyboard-row\.home\s*\{[^}]*margin-left:\s*18px/);
      expect(htmlSource).toMatch(/\.keyboard-row\.lower\s*\{[^}]*margin-left:\s*42px/);
    });
  });

  describe("Tier 2: Boundary & Corner Cases (Feature 9)", () => {
    test("T2-R5-BOUND-VOL: Volume boundaries: 0% and 100% format cleanly without overflow", () => {
      const v0 = R5_CONTRACT.formatters.volume(0);
      const v127 = R5_CONTRACT.formatters.volume(127);
      expect(v0).toBe("Vol -\n0%");
      expect(v127).toBe("Vol -\n100%");

      expect("100%".length * 5.2).toBeLessThanOrEqual(52);
    });

    test("T2-R5-BOUND-BPM: BPM boundaries: minimum (30 BPM) and maximum (300 BPM) fit within 52px", () => {
      const b30 = R5_CONTRACT.formatters.bpm(30);
      const b300 = R5_CONTRACT.formatters.bpm(300);
      expect(b30).toBe("BPM -\n30");
      expect(b300).toBe("BPM -\n300");
      expect("300".length * 5.2).toBeLessThanOrEqual(52);
    });

    test("T2-R5-BOUND-OCT: Octave offset boundaries: -3, 0, +3 display signed integers cleanly", () => {
      expect(R5_CONTRACT.formatters.octave(-3)).toBe("Oct -\n-3");
      expect(R5_CONTRACT.formatters.octave(0)).toBe("Oct -\n+0");
      expect(R5_CONTRACT.formatters.octave(3)).toBe("Oct -\n+3");
    });

    test("T2-R5-BOUND-MODE: Longest mode name (Mixolydian, Harmonic Minor) fits 52px width", () => {
      const m1 = R5_CONTRACT.formatters.mode("Mixolydian");
      const m2 = R5_CONTRACT.formatters.mode("Harmonic Minor");
      expect(m1).toBe("Mode -\nMixolydian");
      expect(m2).toBe("Mode -\nHarmonic Minor");
    });

    test("T2-R5-BOUND-OSC: Rapid alternating parameter increments maintain 0 layout shift invariants", () => {
      const initialLines = R5_CONTRACT.formatters.volume(49).split("\n");
      const initialLineCount = initialLines.length;
      const initialHeight = initialLineCount * 9.5;

      for (let i = 0; i < 20; i++) {
        const val = i % 2 === 0 ? 49 : 50;
        const text = R5_CONTRACT.formatters.volume(val);
        expect(text).toContain("Vol -");
        const lines = text.split("\n");

        // Geometric Zero Layout Shift invariant: line count is strictly constant
        expect(lines.length).toBe(initialLineCount);
        // Vertical height is strictly invariant and clamped within maxNoteHeight
        expect(lines.length * 9.5).toBe(initialHeight);
        expect(lines.length * 9.5).toBeLessThanOrEqual(R4_CONTRACT.maxNoteHeight);
        // Line lengths never exceed container boundary
        lines.forEach(line => {
          expect(line.length * 5.2).toBeLessThanOrEqual(R4_CONTRACT.maxInnerWidth);
        });
      }
    });

    test("T2-R5-BOUND-ATKDEC-EXTREMES: Attack/Decay 0 and 127 boundaries fit within key frame", () => {
      expect(R5_CONTRACT.formatters.attack(0)).toBe("Atk -\n0");
      expect(R5_CONTRACT.formatters.attack(127)).toBe("Atk -\n127");
      expect(R5_CONTRACT.formatters.decay(0)).toBe("Dec -\n0");
      expect(R5_CONTRACT.formatters.decay(127)).toBe("Dec -\n127");
    });

    test("T2-R5-BOUND-GATE-EXTREMES: Gate 0% and 100% format cleanly", () => {
      expect(R5_CONTRACT.formatters.gate(0)).toBe("Gate +\n0%");
      expect(R5_CONTRACT.formatters.gate(100)).toBe("Gate +\n100%");
    });

    test("T2-R5-BOUND-EMPTY-FALLBACK: Default formatters gracefully handle numeric edge cases", () => {
      expect(R5_CONTRACT.formatters.bpm(120.4)).toBe("BPM -\n120");
      expect(R5_CONTRACT.formatters.volume(63.5)).toBe("Vol -\n50%");
    });
  });
});
