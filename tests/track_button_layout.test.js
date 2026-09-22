import { expect, test } from 'bun:test';

const source = await Bun.file(new URL('../src/web/index.html', import.meta.url)).text();

test('track cards reserve independent zones for identity, controls, and status', () => {
  expect(source).toContain("1: { letter: 'B', name: 'Bass' }");
  expect(source).toContain("2: { letter: 'C', name: 'Chords' }");
  expect(source).toContain("3: { letter: 'L', name: 'Lead' }");
  expect(source).toContain("4: { letter: 'A', name: 'Arp' }");
  expect(source).toContain('.key-pad.track-card .key-row-icon {\n    display: none !important;');
  expect(source).toContain('.trk-ms-badges {\n    position: absolute;\n    right: 3px;\n    bottom: 3px;');
  expect(source).toContain('.trk-mode-tags {\n    position: absolute;\n    bottom: 3px;\n    left: 3px;');
  expect(source).toContain('.key-pad.track-card .key-note {\n    display: block;');
});
