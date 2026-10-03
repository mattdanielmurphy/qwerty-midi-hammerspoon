import { expect, test } from "bun:test";

const controls = await Bun.file(
  new URL("../src/controls.lua", import.meta.url),
).text();
const init = await Bun.file(new URL("../src/init.lua", import.meta.url)).text();
const keystep = await Bun.file(
  new URL("../packages/keystep-interceptor/keystep.lua", import.meta.url),
).text();
const html = await Bun.file(new URL("../src/web/index.html", import.meta.url)).text();

test("KeyStep playable notes enter the normal bottom-row note lifecycle", () => {
  expect(init).toContain("noteOn = controls.handleKeyStepNoteOn");
  expect(init).toContain("noteOff = controls.handleKeyStepNoteOff");
  expect(init).toContain("disconnect = controls.handleKeyStepDisconnect");
  expect(controls).toContain('code:match("^keystep_")');
  expect(keystep).toContain("noteHandler.noteOn(metadata.note");
  expect(keystep).toContain("noteHandler.noteOff(metadata.note");
  expect(controls).toContain('local trkIdx = isTop and (state.topRowTrack or 3) or (state.bottomRowTrack or 1)');
  expect(controls).toContain("transposer.getEffectiveRowVelocity(isTop)");
  expect(controls).toContain("arpeggiator.arpAddNote(code .. \"_\" .. p, p, trkIdx)");
  expect(controls).toContain("arpeggiator.arpRemoveNote(code .. \"_\" .. p, trkId)");
});

test("setup guide is connection scoped, accessible, and uses only physical transport/note events", () => {
  expect(html).toContain('id="ks-setup-guide" role="status" aria-live="polite"');
  expect(html).toContain("Press Play/Pause until Play is solid and Tap blinks.");
  expect(html).toContain("Hold Shift and tap Oct+ (Kbd Play) before playing a note.");
  expect(html).toContain("window.setKeyStepSetupGuide");
  expect(html).toContain("stateObj.setupGuideStep !== undefined");
  expect(html).toContain("window.setKeyStepSetupGuide(stateObj.setupGuideStep)");
  expect(keystep).toContain("state.setupAcknowledged = true");
  expect(keystep).toContain('elseif isStart then');
  expect(keystep).toContain('elseif isStop then');
  expect(keystep).toContain('state.setupGuideStep == "kbd_play"');
});

test("disconnect releases shared notes and clears KeyStep held-pitch and key-highlight state", () => {
  expect(keystep).toContain("if noteHandler and noteHandler.disconnect then pcall(noteHandler.disconnect) end");
  expect(keystep).toContain('sendToHud("key_" .. tostring(note), 0, false, { note = note, disconnected = true })');
  expect(keystep).toContain("state.activeKeys = {}\n  state.heldWhiteKeys = {}");
});
