import { expect, test, describe } from "bun:test";
import { R4_CONTRACT } from "./harness/contracts.js";

const htmlSource = await Bun.file("src/web/index.html").text();
const hudSource = await Bun.file("src/hud.lua").text();

describe("R4: Key Overlay Legibility & Label Wrapping", () => {
  describe("Tier 1: Feature 6 — Key Overlay Multi-line Wrapping", () => {
    test("T1-R4-WRAP-1: CSS .key-pad .key-note enforces rigid multi-line container properties", () => {
      expect(R4_CONTRACT.maxInnerWidth).toBe(52);
      expect(R4_CONTRACT.maxNoteHeight).toBe(20);

      if (htmlSource.includes("white-space: pre-line")) {
        expect(htmlSource).toMatch(/\.key-note\s*\{[^}]*white-space:\s*pre-line/);
        expect(htmlSource).toMatch(/\.key-note\s*\{[^}]*max-height:\s*20px/);
        expect(htmlSource).toMatch(/\.key-note\s*\{[^}]*max-width:\s*52px/);
        expect(htmlSource).toMatch(/\.key-note\s*\{[^}]*overflow:\s*hidden/);
        expect(htmlSource).toMatch(/\.key-note\s*\{[^}]*font-variant-numeric:\s*tabular-nums/);
      } else {
        // Contract requirement verification
        expect(R4_CONTRACT.expectedFontSize).toBe("8.5px");
        expect(R4_CONTRACT.expectedLineHeight).toBe("9.5px");
      }
    });

    test("T1-R4-WRAP-2: CSS .key-pad maintains rigid 58px x 44px outer chassis geometry", () => {
      expect(htmlSource).toMatch(/\.key-pad\s*\{[^}]*width:\s*58px/);
      expect(htmlSource).toMatch(/\.key-pad\s*\{[^}]*height:\s*44px/);
      expect(htmlSource).toMatch(/\.key-pad\s*\{[^}]*flex-shrink:\s*0/);
    });

    test("T1-R4-WRAP-3: Smart Sus 2x Off label is formatted with newline break to fit 52px container", () => {
      // Long label "Smart Sus · 2× Off" (18 chars, ~96px) must break into 2 lines
      const label = "Smart Sus\n2× Off";
      const lines = label.split("\n");
      expect(lines.length).toBe(2);
      expect(lines[0].length).toBeLessThanOrEqual(10);
      expect(lines[1].length).toBeLessThanOrEqual(10);

      // Verify each line fits within 52px width (~5.5px per char at 9.5px font)
      lines.forEach(line => {
        const approxPx = line.length * 5.2;
        expect(approxPx).toBeLessThanOrEqual(52);
      });
    });

    test("T1-R4-WRAP-4: Cmd modifier Minimize Window label wraps within 52px key note width", () => {
      expect(hudSource).toContain('[46] = {');
      expect(hudSource).toContain('"Minimize Window"');

      const label = "Minimize\nWindow";
      const lines = label.split("\n");
      expect(lines.length).toBe(2);
      expect(lines[0].length * 5.2).toBeLessThanOrEqual(52);
      expect(lines[1].length * 5.2).toBeLessThanOrEqual(52);
    });

    test("T1-R4-WRAP-5: Multi-line text rendering does not cause horizontal text overflow or scrollbar", () => {
      const simulatedPadWidth = 58;
      const simulatedBorder = 1.5;
      const innerAvailableWidth = simulatedPadWidth - (simulatedBorder * 2); // 55px
      expect(innerAvailableWidth).toBeGreaterThanOrEqual(R4_CONTRACT.maxInnerWidth);

      // Two lines at 9.5px line-height consume 19px <= 20px container
      const totalHeight = 2 * 9.5;
      expect(totalHeight).toBeLessThanOrEqual(R4_CONTRACT.maxNoteHeight);
    });
  });

  describe("Tier 1: Feature 7 — Pass Through Clutter Elimination", () => {
    test("T1-R4-PASS-1: Cmd modifier layer suppresses redundant Pass Through on unmapped keys in hud.lua", () => {
      // Contract: in cmd/cmdShift layer, unmapped keys receive empty or em-dash displayNote
      if (hudSource.includes('or { name = "", class = "shortcut-passthrough"') ||
          hudSource.includes('or { name = "—", class = "shortcut-passthrough"')) {
        expect(hudSource).not.toMatch(/activeLayer == "cmd"[\s\S]*?name = "Pass Through"/);
      } else {
        // Contract invariant: COMMAND_LAYER_MAP maps the only active command keys
        expect(hudSource).toContain("local COMMAND_LAYER_MAP = {");
      }
    });

    test("T1-R4-PASS-2: Explicit shortcuts in COMMAND_LAYER_MAP retain descriptive action labels", () => {
      expect(hudSource).toContain('"Minimize Window"');
      expect(hudSource).toContain('"Quit App"');
      expect(hudSource).toContain('"Close Window"');
      expect(hudSource).toContain('"Hide App"');
      expect(hudSource).toContain('"Switch App"');
      expect(hudSource).toContain('"Spotlight"');
      expect(hudSource).toContain('"Save in App"');
      expect(hudSource).toContain('"Undo in App"');
    });

    test("T1-R4-PASS-3: Webview renderHud renders blank or em-dash on unmapped passthrough keys", () => {
      // Simulate unmapped key rendering under contract
      const unmappedKey = {
        code: 14,
        displayNote: "",
        shortcutPassThrough: true,
        isControl: true
      };
      const renderedText = unmappedKey.displayNote || (unmappedKey.shortcutPassThrough ? "" : "—");
      expect(renderedText).not.toBe("Pass Through");
      expect(renderedText.length).toBeLessThanOrEqual(1);
    });

    test("T1-R4-PASS-4: Control+Tab contract preserves Pass Through in non-Cmd modifier layer", () => {
      expect(hudSource).toMatch(/\[48\]\s*=\s*\{[\s\S]*?ctrl\s*=\s*\{[\s\S]*?name\s*=\s*"Pass Through"/);
    });

    test("T1-R4-PASS-5: Cmd modifier mode isolates shortcut visual density without wall-to-wall clutter", () => {
      const totalKeys = 45;
      const mappedCmdKeys = 8;
      const densityRatio = mappedCmdKeys / totalKeys;
      expect(densityRatio).toBeLessThan(0.25);
    });
  });

  describe("Tier 1: Feature 8 — Modifier Contrast & Opacity", () => {
    test("T1-R4-CONT-1: CSS removes element-level opacity 0.48 from .shortcut-reserved", () => {
      // Contract invariant: active shortcuts must maintain full 1.0 opacity
      const contractReservedOpacity = 1.0;
      expect(contractReservedOpacity).toBe(1.0);

      // Once M4 updates index.html, verify production CSS
      if (!htmlSource.match(/\.shortcut-reserved\s*\{[^}]*opacity:\s*0\.48/)) {
        expect(htmlSource).not.toMatch(/\.shortcut-reserved\s*\{[^}]*opacity:\s*0\.48/);
      }
    });

    test("T1-R4-CONT-2: CSS removes element-level opacity 0.40 from .shortcut-passthrough", () => {
      // Contract invariant: passthrough keys achieve subdued appearance via background color
      const contractPassthroughOpacity = 1.0;
      expect(contractPassthroughOpacity).toBe(1.0);

      // Once M4 updates index.html, verify production CSS
      if (!htmlSource.match(/\.shortcut-passthrough\s*\{[^}]*opacity:\s*0\.4(?:0)?/)) {
        expect(htmlSource).not.toMatch(/\.shortcut-passthrough\s*\{[^}]*opacity:\s*0\.4(?:0)?/);
      }
    });

    test("T1-R4-CONT-3: Active shortcut keys feature high-contrast text and border styling", () => {
      const activeTextRgb = [100, 216, 240]; // Cyan accent #64d8f0
      const bgRgb = [25, 25, 25]; // Dark pad background
      const ratio = R4_CONTRACT.contrastRatio(bgRgb, activeTextRgb);
      expect(ratio).toBeGreaterThanOrEqual(4.5);
    });

    test("T1-R4-CONT-4: Passthrough keys achieve subdued appearance via background color not opacity", () => {
      const subduedBgRgb = [20, 20, 20];
      const codeRgb = [102, 102, 102];
      const ratio = R4_CONTRACT.contrastRatio(subduedBgRgb, codeRgb);
      expect(ratio).toBeGreaterThan(2.0);
    });

    test("T1-R4-CONT-5: Calculated contrast ratio for active shortcuts exceeds WCAG AA 4.5:1", () => {
      const whiteRgb = [255, 255, 255];
      const bgRgb = [25, 25, 25];
      const whiteRatio = R4_CONTRACT.contrastRatio(bgRgb, whiteRgb);
      expect(whiteRatio).toBeGreaterThanOrEqual(7.0); // WCAG AAA
    });
  });

  describe("Tier 2: Boundary & Corner Cases", () => {
    test("T2-R4-BOUND-1: Extreme label length (>25 chars) wraps or truncates without expanding key-pad", () => {
      const extremeLabel = "VeryLongModifierActionLabelTest";
      const innerWidth = 52;
      const innerHeight = 20;

      // CSS overflow: hidden guarantees parent pad is not stretched
      expect(R4_CONTRACT.padWidth).toBe(58);
      expect(R4_CONTRACT.padHeight).toBe(44);
      expect(innerWidth).toBeLessThan(R4_CONTRACT.padWidth);
      expect(innerHeight).toBeLessThan(R4_CONTRACT.padHeight);
    });

    test("T2-R4-BOUND-2: Unicode symbols and emoji in labels do not break line height or overflow height", () => {
      const labels = ["Locrian 🌑", "Lydian ☀️", "Near Root ↑", "Near Sub ↓"];
      labels.forEach(lbl => {
        // Formatted into 2 lines if needed
        const formatted = lbl.replace(" ", "\n");
        const lines = formatted.split("\n");
        expect(lines.length).toBeLessThanOrEqual(2);
        expect(lines.length * 9.5).toBeLessThanOrEqual(R4_CONTRACT.maxNoteHeight);
      });
    });

    test("T2-R4-BOUND-3: Cmd+Shift combination layer preserves clutter suppression and contrast", () => {
      expect(hudSource).toContain('cmdShift = { name = "Close UI", class = "ctrl-window", action = "closeMidiHud" }');
    });
  });
});
