import { expect, test } from 'bun:test';

const arp = await Bun.file(new URL('../src/arpeggiator.lua', import.meta.url)).text();
const controls = await Bun.file(new URL('../src/controls.lua', import.meta.url)).text();
const hud = await Bun.file(new URL('../src/hud.lua', import.meta.url)).text();

test('the active track owns the rate selected by a rate control', () => {
  expect(arp).toContain('local function setTrackArpRate(rateIdx, targetTrackIdx)');
  expect(arp).toContain('trk.arpRateIdx = normalizedRateIdx');
  expect(arp).toContain('setTrackArpRate = setTrackArpRate');
  expect(controls).toContain('arpeggiator.setTrackArpRate');
  expect(hud).toContain('arpeggiator.setTrackArpRate');
});

test('the rate selector follows the currently focused track', () => {
  expect(controls).toContain('state.arpRateIdx = trk.arpRateIdx or state.arpRateIdx');
  expect(hud).toContain('arpRateIdx = (activeTrk and activeTrk.arpRateIdx) or state.arpRateIdx');
});
