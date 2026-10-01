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

test("derives BPM from a moving average of 24 PPQN clock pulses", () => {
  expect(source).toContain("local CLOCK_PULSES_PER_QUARTER = 24");
  expect(source).toContain("60 / elapsed");
});

test("quantizes straight and triplet note intervals and emits dedicated CCs", () => {
  for (const label of ["1/4", "1/8", "1/16", "1/32", "1/4T", "1/8T", "1/16T", "1/32T"]) {
    expect(source).toContain(`label = "${label}"`);
  }
  expect(source).toContain("sendCC(103, division.ccValue)");
  expect(source).toContain("sendCC(104, config.rateCcValue(roundedBpm))");
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

test("swallows only marker notes and forwards played notes to the QWERTY output", () => {
  expect(source).toContain("forwardNote(\"noteOn\", metadata)");
  expect(source).toContain("if not MODE_NOTES[metadata.note] then forwardNote(\"noteOff\", metadata) end");
  expect(source).toContain("getQwertyOutput()");
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
  expect(source).toContain("local TARGET_WINDOW_SECONDS = 0.20");
  expect(source).toContain("local MIN_WINDOW_PULSES = 4");
  expect(source).toContain("local MAX_WINDOW_PULSES = 16");
  expect(source).toContain("diff > 8.0");
  expect(source).toContain("alpha = 0.85");
  expect(source).toContain("state.smoothBpm");
});
