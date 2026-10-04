import { expect, test } from "bun:test";

const configSrc = await Bun.file("src/config.lua").text();
const controlsSrc = await Bun.file("src/controls.lua").text();
const hudSrc = await Bun.file("src/hud.lua").text();
const arpSrc = await Bun.file("src/arpeggiator.lua").text();
const quantizerSrc = await Bun.file("packages/music-engine/quantizer.lua").text();

test("hud: attack (key 9: 25) and decay (key 0: 29) resolve to active track for dynamic coloring", () => {
  // resolveAssignedTrackId returns activeTrkId for keys 25 and 29
  expect(hudSrc).toContain("if cNum == 25 or cNum == 29 then");
  expect(hudSrc).toContain("return activeTrkId");

  // In loop over keyUpdates, assignedTrackId, assignedTrackColor, and isPerTrack are populated
  expect(hudSrc).toContain("kUpd.assignedTrackId = assignedId");
  expect(hudSrc).toContain("kUpd.assignedTrackColor = t.color");
  expect(hudSrc).toContain("kUpd.isPerTrack = true");

  // Webview IPC fallback executes control actions if posted
  expect(hudSrc).toContain("controlsModule.executeControlAction(body.type)");
});

test("controls: atkDown/Up and decDown/Up use track color and target key-25/29 spotlights", () => {
  expect(controlsSrc).toContain('targetId = "key-25"');
  expect(controlsSrc).toContain('targetId = "key-29"');
  expect(controlsSrc).toContain('color = trk.color or "#00e676"');
  expect(controlsSrc).toContain('color = trk.color or "#ffd700"');

  // botTrackToggle and topTrackToggle check row tracks accurately
  expect(controlsSrc).toContain('local nextId = (state.bottomRowTrack == 1) and 2 or 1');
  expect(controlsSrc).toContain('local nextId = (state.topRowTrack == 3) and 4 or 3');
});

test("arp direction: tracks independently own and persist arp direction", () => {
  // config initializes per-track arpDirectionIdx from hs.settings
  expect(configSrc).toContain('arpDirectionIdx = getSetting("track1ArpDirectionIdx", getSetting("arpDirectionIdx", 1))');
  expect(configSrc).toContain('arpDirectionIdx = getSetting("track2ArpDirectionIdx", getSetting("arpDirectionIdx", 1))');
  expect(configSrc).toContain('arpDirectionIdx = getSetting("track3ArpDirectionIdx", getSetting("arpDirectionIdx", 1))');
  expect(configSrc).toContain('arpDirectionIdx = getSetting("track4ArpDirectionIdx", getSetting("arpDirectionIdx", 1))');

  // config.saveSettings persists per-track ArpDirectionIdx
  expect(configSrc).toContain('hs.settings.set("qwertyMidi_track" .. i .. "ArpDirectionIdx", trk.arpDirectionIdx or 1)');

  // selectTrack syncs active track arpDirectionIdx
  expect(controlsSrc).toContain('state.arpDirectionIdx = trk.arpDirectionIdx or state.arpDirectionIdx or 1');

  // controls and arpeggiator provide setTrackArpDirection
  expect(controlsSrc).toContain('setActiveArpDirection = setActiveArpDirection');
  expect(arpSrc).toContain('setTrackArpDirection = setTrackArpDirection');

  // hud payload renders active track arpDirectionIdx
  expect(hudSrc).toContain('arpDirectionIdx = (activeTrk and activeTrk.arpDirectionIdx) or state.arpDirectionIdx or 1');
});

test("quantizer: legato sustaining eliminates gaps during grid anticipation delays", () => {
  // Contains soundingNotes registry and legato sustain handling
  expect(quantizerSrc).toContain('local soundingNotes = {}');
  expect(quantizerSrc).toContain('sEntry.heldForPending = eventId');
  expect(quantizerSrc).toContain('snd.heldForPending = pendingOnChannel');

  // Grace timer for recently released notes to connect with incoming quantized notes
  expect(quantizerSrc).toContain('snd.graceTimer = hs.timer.doAfter(graceDuration');

  // Pitch comparison: releases same pitches before triggering new note, and different pitches after
  expect(quantizerSrc).toContain('newPitchSet[p]');
  expect(quantizerSrc).toContain('if hasShared and sEntry.onRelease then');

  // Panic cleans up sounding notes and grace timers
  expect(quantizerSrc).toContain('if snd.graceTimer then');
  expect(quantizerSrc).toContain('soundingNotes = {}');
});
