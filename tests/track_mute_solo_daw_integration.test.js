import { expect, test } from "bun:test";

const midi = await Bun.file("src/midi.lua").text();
const controls = await Bun.file("src/controls.lua").text();
const arp = await Bun.file("src/arpeggiator.lua").text();

test("midi: silenceChannel sends All Sound Off, All Notes Off, Damper release, and releases active voices", () => {
  expect(midi).toContain("local function silenceChannel(channel)");
  expect(midi).toContain("controllerNumber = 120"); // All Sound Off
  expect(midi).toContain("controllerNumber = 123"); // All Notes Off
  expect(midi).toContain("controllerNumber = 64");  // Damper release
  expect(midi).toContain("silenceChannel = silenceChannel");
});

test("controls: syncTrackAudibility mutes DAW audio via CC 7, CC 11, CC 120/123, and dedicated Logic CC 108 & 109", () => {
  // Verifies CC 7 (Volume = 0), CC 11 (Expression = 0), CC 108 (Mute), CC 109 (Solo)
  expect(controls).toContain("midi.sendMidiCC(7, 0, ch)");
  expect(controls).toContain("midi.sendMidiCC(11, 0, ch)");
  expect(controls).toContain("midi.sendMidiCC(108, trk.muted and 127 or 0, ch)");
  expect(controls).toContain("midi.sendMidiCC(109, trk.soloed and 127 or 0, ch)");
  expect(controls).toContain("midi.silenceChannel(ch)");

  // Verifies restoration on unmute
  expect(controls).toContain("midi.sendMidiCC(108, 0, ch)");
  expect(controls).toContain("midi.sendMidiCC(7, volCc, ch)");
  expect(controls).toContain("midi.sendMidiCC(11, 127, ch)");
});

test("controls: arpeggiator notes are registered even while track is muted, and resumed on unmute", () => {
  // In handleKeyDown, arpAddNote is called for isArpNote regardless of isTrackAudible
  expect(controls).toMatch(/if isArpNote then\s+for _, p in ipairs\(chordPitches\) do arpeggiator\.arpAddNote/);

  // In syncTrackAudibility, held arp notes are re-registered and startTrackArp is resumed if needed
  expect(controls).toContain("arpeggiator.arpAddNote(code .. \"_\" .. p, p, trkId)");
  expect(controls).toContain("arpeggiator.startTrackArp(trk, true)");
});

test("arpeggiator: silenceTrack silences gates and calls silenceChannel without destroying heldNotes sequence", () => {
  const match = arp.match(/local function silenceTrack\(trkId\)([\s\S]*?)\nend/);
  expect(match).toBeTruthy();
  const body = match[1];
  expect(body).toContain("midi.silenceChannel(ch)");
  expect(body).toContain("trk.arpIsPlaying = false");
  // silenceTrack does not clear heldNotes or stop timer
  expect(body).not.toContain("trk.heldNotes = {}");
  expect(body).not.toContain("stopTrackArp");
});
