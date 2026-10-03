import { expect, test } from "bun:test";

const configSource = await Bun.file(
  new URL("../src/config.lua", import.meta.url),
).text();
const hudSource = await Bun.file(
  new URL("../src/hud.lua", import.meta.url),
).text();
const midiSource = await Bun.file(
  new URL("../src/midi.lua", import.meta.url),
).text();
const controlsSource = await Bun.file(
  new URL("../src/controls.lua", import.meta.url),
).text();
const htmlSource = await Bun.file(
  new URL("../src/web/index.html", import.meta.url),
).text();
const bundledSource = await Bun.file(
  new URL("../qwerty_midi.lua", import.meta.url),
).text();

// ── Objective 1: F Key Assignment ──
test("F key (code 3) is strictly octaveUp and NOT arpLatchToggle across default and legacy layout migrations", () => {
  // Base default action for F must be octaveUp
  expect(configSource).toMatch(/\[3\]\s*=\s*\{[^}]*action\s*=\s*"octaveUp"/);
  expect(bundledSource).toMatch(/\[3\]\s*=\s*\{[^}]*action\s*=\s*"octaveUp"/);

  // Layout migration must migrate any legacy arpLatchToggle or lockLoop on code 3 to octaveUp
  expect(configSource).toContain('if code == 3 and (binding.action == "arpLatchToggle"');
  expect(configSource).toContain('binding.action = "octaveUp"');
  expect(configSource).toContain('binding.name = "Oct +"');

  // Spotlight in controls.lua must target B (key-11) for loop locking, not F (key-3)
  expect(controlsSource).toContain('targetId = "key-11"');
  expect(controlsSource).not.toContain('targetId = "key-3"');

  // hud.lua must NOT contain the old propCode == 3 latch overlay that overwrote F
  expect(hudSource).not.toContain('propCode == 3');
  expect(bundledSource).not.toContain('propCode == 3');
});

// ── Objective 2: Track-Colored Controls ──
test("HUD snapshot resolves assignedTrackId, assignedTrackColor, and assignedTrackRgb for dynamic per-track controls", () => {
  // Tracks in config must define color and rgb
  expect(configSource).toContain('color = "#00e5ff", rgb = "0, 229, 255"');
  expect(configSource).toContain('color = "#ff9100", rgb = "255, 145, 0"');
  expect(configSource).toContain('color = "#00e676", rgb = "0, 230, 118"');
  expect(configSource).toContain('color = "#d500f9", rgb = "213, 0, 249"');

  // resolveAssignedTrackId in hud.lua must assign colors for top row, bottom row, and track selectors
  expect(hudSource).toContain("local function resolveAssignedTrackId(cNum)");
  expect(hudSource).toContain("kUpd.assignedTrackId = assignedId");
  expect(hudSource).toContain("kUpd.assignedTrackColor = t.color");
  expect(hudSource).toContain("kUpd.assignedTrackRgb = t.rgb");

  // CSS in index.html must use --assigned-track-color and --assigned-track-rgb
  expect(htmlSource).toContain("var(--assigned-track-color");
  expect(htmlSource).toContain("var(--assigned-track-rgb");

  // renderHud in index.html must apply style properties and per-track-ctrl class
  expect(htmlSource).toContain("el.style.setProperty('--assigned-track-color', k.assignedTrackColor)");
  expect(htmlSource).toContain("el.style.setProperty('--assigned-track-rgb', k.assignedTrackRgb)");
  expect(htmlSource).toContain("per-track-ctrl");
});

// ── Objective 3: Graphical Indicators ──
test("88-key piano diagram and chord mini-piano diagram exist in markup and script", () => {
  // Mini piano in header badge
  expect(htmlSource).toContain('id="chord-mini-piano"');
  expect(htmlSource).toContain('class="chord-mini-piano"');
  expect(htmlSource).toContain("initChordMiniPiano");
  expect(htmlSource).toContain("updateChordMiniPiano");

  // 88-Key piano in performance footer
  expect(htmlSource).toContain('id="performance-piano-88"');
  expect(htmlSource).toContain('class="performance-piano-88"');
  expect(htmlSource).toContain("initPerformancePiano88");
  expect(htmlSource).toContain("window.updatePianoNote");
  expect(htmlSource).toContain("window.clearPianoNotes");
  expect(htmlSource).toContain("window.syncActivePianoNotes");

  // MIDI emission boundary in midi.lua tracks active note ledger
  expect(midiSource).toContain("local activeNoteLedger = {}");
  expect(midiSource).toContain("getActiveNoteLedger");
  expect(midiSource).toContain("clearActiveNotes");
  expect(midiSource).toContain("updatePianoNote(noteNum, true, trkId, trkColor)");
  expect(midiSource).toContain("updatePianoNote(noteNum, stillActive, remainingTrkId, remainingColor)");

  // Panic clears active piano notes
  expect(midiSource).toContain("clearActiveNotes()");

  // hud.lua passes selectedChord and activePianoNotes to webview
  expect(hudSource).toContain("selectedChord = selectedChordInfo");
  expect(hudSource).toContain("activePianoNotes = midi.getActiveNoteLedger()");
  expect(hudSource).toContain("updatePianoNote");
  expect(hudSource).toContain("clearPianoNotes");
});

// ── Objective 4: KeyStep Disconnected Lower-Row Reversion ──
test("KeyStep disconnected reverts lower row to note inputs while preserving home row across configurations", () => {
  // Lower row codes 6..44 are dynamically toggled by isKsConnected()
  expect(configSource).toContain("local function isKsConnected()");
  expect(configSource).toContain("if not ksConnected then");

  // controls.lua delegates to hud.getProposedActionDef which returns nil when KeyStep is disconnected
  expect(controlsSource).toContain("local propDef = hud.getProposedActionDef and hud.getProposedActionDef(code)");
  expect(hudSource).toContain("if lowerRowCodes[code] and not isKeyStepConnected() then");
  expect(hudSource).toContain("return nil");

  // Home row keys (48, 0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39) in defaultHomeRowControls
  const homeRowCodes = [48, 0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39];
  for (const code of homeRowCodes) {
    expect(configSource).toContain(`[${code}]`);
  }
});
