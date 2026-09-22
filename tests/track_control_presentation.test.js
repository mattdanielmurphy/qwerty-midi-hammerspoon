import { expect, test } from 'bun:test';

const source = await Bun.file(new URL('../src/web/index.html', import.meta.url)).text();
const hud = await Bun.file(new URL('../src/hud.lua', import.meta.url)).text();

test('only number-row track selectors receive persistent track-card styling', () => {
  expect(source).toContain("const isTrackCard = numCode >= 18 && numCode <= 21;");
  expect(source).toContain("(isTrackCard ? ' track-card' : '')");
  expect(source).toContain('.key-pad.track-card .key-note {');
  expect(source).not.toContain('.key-pad.ctrl-track .key-note {\n    display: none;');
});

test('track selector modifier labels fit inside the card and identify their target', () => {
  expect(hud).toContain('shift           = { name = "Mute 1"');
  expect(hud).toContain('shift           = { name = "Mute 2"');
  expect(hud).toContain('shift           = { name = "Mute 3"');
  expect(hud).toContain('shift           = { name = "Mute 4"');
});
