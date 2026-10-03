import { expect, test } from "bun:test";

const configSrc = await Bun.file("src/config.lua").text();
const controlsSrc = await Bun.file("src/controls.lua").text();
const hudSrc = await Bun.file("src/hud.lua").text();
const keystepSrc = await Bun.file("packages/keystep-interceptor/keystep.lua").text();
const webSrc = await Bun.file("src/web/index.html").text();

test("config: per-track volume, octaveOffset, attack, and decay exist and persist", () => {
  // state.tracks initialization includes per-track settings
  expect(configSrc).toContain('volume = getSetting("track1Volume", 100)');
  expect(configSrc).toContain('octaveOffset = getSetting("track1OctaveOffset", 0)');
  expect(configSrc).toContain('attack = getSetting("track1Attack", 0)');
  expect(configSrc).toContain('decay = getSetting("track1Decay", 64)');

  expect(configSrc).toContain('volume = getSetting("track2Volume", 100)');
  expect(configSrc).toContain('volume = getSetting("track3Volume", 100)');
  expect(configSrc).toContain('volume = getSetting("track4Volume", 100)');

  // saveSettings persists all 4 tracks
  expect(configSrc).toContain('hs.settings.set("qwertyMidi_track" .. i .. "Volume"');
  expect(configSrc).toContain('hs.settings.set("qwertyMidi_track" .. i .. "OctaveOffset"');
  expect(configSrc).toContain('hs.settings.set("qwertyMidi_track" .. i .. "Attack"');
  expect(configSrc).toContain('hs.settings.set("qwertyMidi_track" .. i .. "Decay"');

  // Keys 9 and 0 mapped to atkDown/atkUp and decDown/decUp
  expect(configSrc).toContain('action = "atkDown"');
  expect(configSrc).toContain('shiftAction = "decDown"');
  expect(configSrc).toContain('action = "atkUp"');
  expect(configSrc).toContain('shiftAction = "decUp"');

  // KeyStep lower row . and / mapped to decDown and decUp
  expect(configSrc).toContain('shiftAction = "decDown"');
  expect(configSrc).toContain('shiftAction = "decUp"');
});

test("controls: atkDown/Up and decDown/Up execute with full-range ADSR CCs and per-track mutation", () => {
  // Attack sends CC 24 and CC 73
  expect(controlsSrc).toContain('elseif act == "atkDown" then');
  expect(controlsSrc).toContain('midi.sendMidiCC(24, trk.attack, ch)');
  expect(controlsSrc).toContain('midi.sendMidiCC(73, trk.attack, ch)');

  // Decay sends CC 25, 26, 27, and 72 (full ADSR range)
  expect(controlsSrc).toContain('elseif act == "decDown" or act == "relDown" or act == "releaseDown" then');
  expect(controlsSrc).toContain('midi.sendMidiCC(25, trk.decay, ch)');
  expect(controlsSrc).toContain('midi.sendMidiCC(26, trk.decay, ch)');
  expect(controlsSrc).toContain('midi.sendMidiCC(27, trk.decay, ch)');
  expect(controlsSrc).toContain('midi.sendMidiCC(72, trk.decay, ch)');

  // Volume changes send CC 7 and update track volume
  expect(controlsSrc).toContain('midi.sendMidiCC(7, state.topRowVolume, trk.channel or 2)');
  expect(controlsSrc).toContain('midi.sendMidiCC(7, state.bottomRowVolume, trk.channel or 0)');

  // Repeating actions include attack and decay
  expect(controlsSrc).toContain('atkUp = true, atkDown = true, decUp = true, decDown = true');
});

test("keystep: driver strictly controls selected bottom track and handles full ADSR Attack & Decay", () => {
  // getFocusedTrack routes to bottomRowTrack
  expect(keystepSrc).toContain('local id = s and (tonumber(s.bottomRowTrack) or 1)');
  expect(keystepSrc).toContain('local trk = s and s.tracks and s.tracks[id or 1]');

  // SHIFT_MODES has attack on black key 8 and decay on black key 10
  expect(keystepSrc).toContain('[8]  = { id = "attack",  label = "ATTACK",  cc = 24');
  expect(keystepSrc).toContain('[10] = { id = "decay",   label = "DECAY",   cc = 25');

  // dispatchShiftCC sends full ADSR CCs
  expect(keystepSrc).toContain('sendCC(25, ccVal, ch)');
  expect(keystepSrc).toContain('sendCC(26, ccVal, ch)');
  expect(keystepSrc).toContain('sendCC(27, ccVal, ch)');
  expect(keystepSrc).toContain('sendCC(72, ccVal, ch)');
  expect(keystepSrc).toContain('sendCC(24, ccVal, ch)');
  expect(keystepSrc).toContain('sendCC(73, ccVal, ch)');

  // No multi-stage envelope cycling on key release
  expect(keystepSrc).not.toContain('state.envelopeStageIdx = (state.envelopeStageIdx % #ENVELOPE_STAGES) + 1');

  // Volume knob updates focused track volume and sends CC 7
  expect(keystepSrc).toContain('trk.volume = volCcVal');
  expect(keystepSrc).toContain('sendCC(7, volCcVal, getOutputChannel())');
});

test("hud & webview: KeyStep displays real-time arpeggiating notes from bottom track", () => {
  // fastUpdateArpNow collects bottom track pitches and passes to updateArpPitches
  expect(hudSrc).toContain('local bottomArpPitches = {}');
  expect(hudSrc).toContain('local botTrkId = state.bottomRowTrack or 1');
  expect(hudSrc).toContain('if currentArpPitches[botTrkId] then');
  expect(hudSrc).toContain('window.updateArpPitches(%s, %s, %s)');

  // web index.html handles bottomArpPitches and illuminates KeyStep keys in 41..72 range
  expect(webSrc).toContain('window.updateArpPitches = function(activeCodes, heldCodes, bottomArpPitches)');
  expect(webSrc).toContain('while (mapped < 41) mapped += 12;');
  expect(webSrc).toContain('while (mapped > 72) mapped -= 12;');
  expect(webSrc).toContain("ksKey.classList.add('active', 'arp-step');");

  // CSS classes for arp-step on white and black KeyStep keys
  expect(webSrc).toContain('.ks-key-w.arp-step');
  expect(webSrc).toContain('.ks-key-b.arp-step');

  // HTML black keys have attack and decay shift modes
  expect(webSrc).toContain('data-shift="attack"');
  expect(webSrc).toContain('data-shift="decay"');
  expect(webSrc).toContain('<span class="ks-key-sub">ATK</span>');
  expect(webSrc).toContain('<span class="ks-key-sub">DEC</span>');
});
