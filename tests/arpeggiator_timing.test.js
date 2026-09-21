import { expect, test } from "bun:test";

const arp = await Bun.file("src/arpeggiator.lua").text();
const hud = await Bun.file("src/hud.lua").text();

test("a superseded gate callback cannot release a retriggered arp note", () => {
  expect(arp).toContain("gateGeneration = 0");
  expect(arp).toMatch(/local gateGeneration = \(trk\.gateGeneration or 0\) \+ 1/);
  expect(arp).toMatch(/if activeGate and activeGate\.generation == gateGeneration then[\s\S]*?midi\.sendMidiNote\("noteOff", pitchToRelease, 0, releaseCh\)/);
});

test("arp visual updates are coalesced away from the realtime gate callbacks", () => {
  expect(hud).toContain("local arpHudUpdateScheduled = false");
  expect(hud).toContain("local function queueArpHudUpdate()");
  expect(hud).toMatch(/arpHudUpdateScheduled = true[\s\S]*?hs\.timer\.doAfter\(0, function\(\)[\s\S]*?fastUpdateArpNow\(\)/);
});
