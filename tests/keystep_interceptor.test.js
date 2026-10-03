import { expect, test } from "bun:test";

const source = await Bun.file(
  new URL("../packages/keystep-interceptor/keystep.lua", import.meta.url),
).text();
const monitorSource = await Bun.file(
  new URL("../packages/keystep-interceptor/keystep_ui.lua", import.meta.url),
).text();
const monitorHtml = await Bun.file(
  new URL("../packages/keystep-interceptor/keystep_ui_html.lua", import.meta.url),
).text();

test("maps sequence marker notes C10 through G10 (120..127) and C8..G8 (108..115) to mode positions 1 through 8", () => {
  expect(source).toContain("[120] = 1, [121] = 2, [122] = 3, [123] = 4");
  expect(source).toContain("[124] = 5, [125] = 6, [126] = 7, [127] = 8");
  expect(source).toContain("[108] = 1, [109] = 2, [110] = 3, [111] = 4");
  expect(source).toContain("[112] = 5, [113] = 6, [114] = 7, [115] = 8");
  expect(source).toContain("local SEQUENCE_MARKER_VELOCITY = 1");
  expect(source).toContain("sendCC(102, mode)");
});

test("accepts Arturia KeyStep product-name suffixes such as KeyStep 32", () => {
  expect(source).toContain('lowered:match("^arturia keystep")');
});

test("derives BPM from median of PPQN clock pulses rejecting host timestamp jitter", () => {
  expect(source).toContain("local CLOCK_PULSES_PER_QUARTER = 24");
  expect(source).toContain("instantBpm = 60 / (CLOCK_PULSES_PER_QUARTER * medianInterval)");
});

test("quantizes straight and triplet note intervals and emits dedicated CCs", () => {
  for (const label of ["1/4", "1/8", "1/16", "1/32", "1/4T", "1/8T", "1/16T", "1/32T"]) {
    expect(source).toContain(`label = "${label}"`);
  }
  expect(source).toContain("sendCC(103, division.ccValue)");
});

test("detects time division by counting 24-PPQN clock pulses between sequence notes", () => {
  expect(source).toContain("nearestDivisionByPulses");
  expect(source).toContain("state.clocksSinceLastNote");
  expect(source).toContain("pulses = 24");
  expect(source).toContain("pulses = 12");
  expect(source).toContain("pulses = 6");
  expect(source).toContain("pulses = 3");
});

test("clears stale timing on transport stop and guards paused streams", () => {
  expect(source).toContain('commandType == "systemStopSequence"');
  expect(source).toContain("delta > CLOCK_RESET_SECONDS");
  expect(source).toContain("noteDelta > NOTE_RESET_SECONDS");
  expect(source).toContain("keyStepController = KeyStep");
});

test("starts a native live monitor and coalesces high-rate clock rendering", () => {
  expect(source).toContain("if options.showMonitor ~= false then");
  expect(source).toContain("function KeyStep.toggleMonitor()");
  expect(source).toContain("hs.timer.doEvery(1, updateMonitor)");
  expect(monitorSource).toContain("0.1 - (nowSeconds() - self.lastRenderAt)");
  expect(monitorHtml).toContain('data-ui="keystep-monitor"');
  expect(monitorHtml).toContain("window.updateKeyStepMonitor");
  expect(monitorHtml).toContain("Last note received");
});

test("swallows marker notes and modal black keys, while forwarding white notes through scale transposer", () => {
  expect(source).toContain("forwardNote(\"noteOn\", {");
  expect(source).toContain("forwardNote(\"noteOff\", {");
  expect(source).toContain("getQwertyOutput()");
  expect(source).toContain("WHITE_KEY_INDEX");
  expect(source).toContain("SHIFT_MODES");
});

test("maps 30..240 BPM linearly to 0..127 Rate CC with ~137 BPM at halfway", () => {
  expect(source).toContain("local function bpmToRate(bpm)");
  expect(source).toContain("local function rateToBpm(rateVal)");
  expect(source).toContain("((b - 30) / (240 - 30)) * 127");
  expect(source).toContain("30 + (r / 127) * (240 - 30)");
  expect(source).toContain("KeyStep.bpmToRate = bpmToRate");
  expect(source).toContain("KeyStep.rateToBpm = rateToBpm");

  const bpmToRate = (b) => Math.round(((Math.max(30, Math.min(240, b)) - 30) / 210) * 127);
  const rateToBpm = (r) => Math.round(30 + (Math.max(0, Math.min(127, r)) / 127) * 210);

  expect(bpmToRate(30)).toBe(0);
  expect(bpmToRate(240)).toBe(127);
  expect(bpmToRate(135)).toBe(64);
  expect(bpmToRate(137)).toBe(65);

  expect(rateToBpm(0)).toBe(30);
  expect(rateToBpm(127)).toBe(240);
  expect(rateToBpm(64)).toBe(136);
});

test("tracks BPM using adaptive sliding-window clock pulses with rapid slew rate", () => {
  expect(source).toContain("local CLOCK_HISTORY_MAX = 24");
  expect(source).toContain("CLOCK_MEDIAN_WINDOW_SECONDS = 0.20");
  expect(source).toContain("MIN_CLOCK_MEDIAN_INTERVALS = 7");
  expect(source).toContain("diff > 8.0");
  expect(source).toContain("alpha = 0.85");
  expect(source).toContain("state.smoothBpm");
});

test("maps Rate knob to CC 107 for Logic learn while synchronizing internal engine volume across full 0..127 range", () => {
  expect(source).toContain("rateCc = 107");
  expect(source).toContain("maxVolumeCc = 127");
  expect(source).toContain("sendRateCc(rateVal)");
  expect(source).toContain("state.topRowVolume = volCcVal");
  expect(source).toContain("state.bottomRowVolume = volCcVal");

  // Verify volume scaling spans full 0..127 MIDI range without 100 CC cap
  const rateToVolumeCc = (rateVal, maxV = 127, minV = 0) => {
    const norm = Math.max(0, Math.min(127, rateVal)) / 127;
    return Math.floor(minV + norm * (maxV - minV) + 0.5);
  };
  expect(rateToVolumeCc(0)).toBe(0);
  expect(rateToVolumeCc(64)).toBe(64);
  expect(rateToVolumeCc(127)).toBe(127);
});

test("provides black-key modal shift mapping across Cutoff, Reverb, Delay, Release, and Volume", () => {
  expect(source).toContain('[1]  = { id = "cutoff",  label = "CUTOFF",  cc = 74');
  expect(source).toContain('[3]  = { id = "reverb",  label = "REVERB",  cc = 91');
  expect(source).toContain('[6]  = { id = "delay",   label = "DELAY",   cc = 92');
  expect(source).toContain('[8]  = { id = "release", label = "RELEASE", cc = 72');
  expect(source).toContain('[10] = { id = "volume",  label = "VOLUME",  cc = 7');
  expect(source).toContain("getActiveShiftModeDef");
  expect(source).toContain("sendShiftModeToHud");
});

test("maps 8-position stepped knobs (Mode and Time Div) across safe unreserved CCs", () => {
  expect(source).toContain("modeCc = 105");
  expect(source).toContain("divCc = 106");
  expect(source).toContain("sendCC(102, mode)");
  expect(source).toContain("sendCC(103, division.ccValue)");
  expect(source).toContain("math.floor(((mode - 1) / 7) * 127 + 0.5)");
  expect(source).toContain("math.floor(((division.ccValue - 1) / 7) * 127 + 0.5)");

  // Verify 8-step mathematical progression
  const calcStep = (idx) => Math.round(((idx - 1) / 7) * 127);
  expect(calcStep(1)).toBe(0);
  expect(calcStep(2)).toBe(18);
  expect(calcStep(3)).toBe(36);
  expect(calcStep(4)).toBe(54);
  expect(calcStep(5)).toBe(73);
  expect(calcStep(6)).toBe(91);
  expect(calcStep(7)).toBe(109);
  expect(calcStep(8)).toBe(127);
});

test("immediately recalls last known knob positions and analyzes sequence to infer changes", () => {
  expect(source).toContain("loadSetting(\"qwertyMidi_ks_mode\"");
  expect(source).toContain("loadSetting(\"qwertyMidi_ks_division\"");
  expect(source).toContain("loadSetting(\"qwertyMidi_ks_rate\"");
  expect(source).toContain("loadSetting(\"qwertyMidi_ks_bpm\"");
  expect(source).toContain("KeyStep.analyzeSequenceAndInferKnobs");
  expect(source).toContain("KeyStep.getFullState");
  expect(source).toContain("KeyStep.syncToHud");
});

test("strictly excludes manual performance keys from sequencer detection, sequence history, and Time Div inference", () => {
  // 1. In noteOn: manual notes must NOT be inserted into sequenceHistory, calculate pulses, or change Time Div
  expect(source).toContain("Manual performance notes: strictly excluded from sequencer detection & Time Div inference");
  expect(source).not.toMatch(/else\s+if state\.playing then\s+local pulses = state\.clocksSinceLastNote/);

  // 2. In noteOff: manual keys (including high playable keys) must NOT be swallowed as marker notes
  expect(source).toContain("state.heldWhiteKeys[metadata.note] == nil and state.activeKeys[metadata.note] == nil");

  // 3. In analyzeSequenceAndInferKnobs: only actual sequence marker notes contribute to pulse intervals
  expect(source).toContain("if item and (item.note >= 120 or (MODE_NOTES[item.note] and item.note >= 108)) then");
});

