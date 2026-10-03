import { expect, test } from "bun:test";

const hudSource = await Bun.file(
  new URL("../src/hud.lua", import.meta.url),
).text();
const htmlSource = await Bun.file(
  new URL("../src/web/index.html", import.meta.url),
).text();
const bundledSource = await Bun.file(
  new URL("../qwerty_midi.lua", import.meta.url),
).text();

test("Chord mode separation: dormant chord preset is not displayed as active when chord mode is off", () => {
  // hud.lua tracks chordModeActive and sets active flag in selectedChordInfo
  expect(hudSource).toContain("local isChordModeActive = (activeTrk and activeTrk.chordModeActive == true) or state.quoteHeld == true");
  expect(hudSource).toContain("active = isChordModeActive");
  expect(hudSource).toContain("chordModeActive = isChordModeActive");

  // updateChordDisplay in lua sends isChordModeActive
  expect(hudSource).toContain("safeEvaluateJS(string.format(\"if (window.updateChordDisplay) window.updateChordDisplay(%s, null, %s);\"");

  // index.html evaluates chordModeActive in renderHud
  expect(htmlSource).toContain("if (data.chordModeActive) {");
  expect(htmlSource).toContain("window.updateChordDisplay('CHORD: ' + (data.selectedChord ? data.selectedChord.name : 'ON'), data.selectedChord, true);");
  expect(htmlSource).toContain("window.updateChordDisplay('—', null, false);");

  // updateChordDisplay clears mini-piano when chord mode is off and no live chord is detected
  expect(htmlSource).toContain("updateChordMiniPiano(null);");
  expect(htmlSource).toContain("window._isChordModeActive");

  // updateKeyState guards against clobbering active chord mode display
  expect(htmlSource).toContain("if (!window._isChordModeActive) {");
});

test("Zero Layout Shift (ZLS) invariant: rigid bounding boxes and tabular digits prevent reflow", () => {
  // Header badges must have strict immutable widths, min-widths, and max-widths
  expect(htmlSource).toContain(".chord-display-badge {");
  expect(htmlSource).toMatch(/\.chord-display-badge\s*\{[^}]*width:\s*154px;\s*min-width:\s*154px;\s*max-width:\s*154px;/);
  expect(htmlSource).toMatch(/\.chord-display-badge\s*\{[^}]*flex-shrink:\s*0;/);

  // BPM editor must have fixed width and tabular-nums
  expect(htmlSource).toMatch(/\.bpm-editor\s*\{[^}]*width:\s*102px;\s*min-width:\s*102px;\s*max-width:\s*102px;/);
  expect(htmlSource).toMatch(/\.bpm-display\s*\{[^}]*font-variant-numeric:\s*tabular-nums;/);

  // Header select controls must have immutable widths and flex-shrink: 0
  expect(htmlSource).toMatch(/#root-select\s*\{[^}]*width:\s*48px;\s*min-width:\s*48px;\s*max-width:\s*48px;/);
  expect(htmlSource).toMatch(/#arp-dir-select\s*\{[^}]*width:\s*66px;\s*min-width:\s*66px;\s*max-width:\s*66px;/);
  expect(htmlSource).toMatch(/#arp-rate-select\s*\{[^}]*width:\s*52px;\s*min-width:\s*52px;\s*max-width:\s*52px;/);
  expect(htmlSource).toMatch(/#arp-quantize-select\s*\{[^}]*width:\s*114px;\s*min-width:\s*114px;\s*max-width:\s*114px;/);
  expect(htmlSource).toMatch(/#input-quantize-select\s*\{[^}]*width:\s*98px;\s*min-width:\s*98px;\s*max-width:\s*98px;/);
  expect(htmlSource).toMatch(/#layout-select\s*\{[^}]*width:\s*90px;\s*min-width:\s*90px;\s*max-width:\s*90px;/);
  expect(htmlSource).toMatch(/#keystep-badge\s*\{[^}]*width:\s*106px;\s*min-width:\s*106px;\s*max-width:\s*106px;/);

  // Row controls must have fixed widths and tabular-nums
  expect(htmlSource).toMatch(/\.compact-oct-badge\s*\{[^}]*width:\s*58px;\s*min-width:\s*58px;\s*max-width:\s*58px;/);
  expect(htmlSource).toMatch(/\.compact-oct-badge\s*\{[^}]*font-variant-numeric:\s*tabular-nums;/);
  expect(htmlSource).toMatch(/\.vol-bar-container\s*\{[^}]*width:\s*6px;\s*min-width:\s*6px;\s*max-width:\s*6px;/);
  expect(htmlSource).toMatch(/\.arp-row-toggle\s*\{[^}]*width:\s*38px;\s*min-width:\s*38px;\s*max-width:\s*38px;/);
});
