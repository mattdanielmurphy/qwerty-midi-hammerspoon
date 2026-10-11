// tests/harness/contracts.js
// Machine-executable contract specifications, reference formulas, and simulation models
// for qwerty-midi-hammerspoon E2E test suites (R1 through R7).

export const R1_CONTRACT = {
  actions: [
    "trk1VolUp", "trk1VolDown",
    "trk2VolUp", "trk2VolDown",
    "trk3VolUp", "trk3VolDown",
    "trk4VolUp", "trk4VolDown"
  ],
  legacyOrAltActions: [
    "trkVolUp1", "trkVolDown1",
    "trkVolUp2", "trkVolDown2",
    "trkVolUp3", "trkVolDown3",
    "trkVolUp4", "trkVolDown4"
  ],
  cc: 7,
  minVolume: 0,
  maxVolume: 127,
  defaultVolume: 100,
  debounceMs: 300,

  channelForTrack(trackId) {
    const id = Number.isFinite(Number(trackId)) ? Number(trackId) : 1;
    return Math.max(0, Math.min(15, Math.floor(id) - 1));
  },

  adjustVolume(initialVol, delta) {
    const vol = Number(initialVol);
    const d = Number(delta);
    const base = Number.isFinite(vol) ? vol : this.defaultVolume;
    const change = Number.isFinite(d) ? d : 0;
    return Math.max(this.minVolume, Math.min(this.maxVolume, Math.round(base + change)));
  },

  restoreVolumeCC(volume) {
    const vol = Number.isFinite(Number(volume)) ? Number(volume) : this.defaultVolume;
    // Matches src/controls.lua:372: math.floor(math.min(127, math.max(0, vol * 1.27)))
    return Math.floor(Math.min(127, Math.max(0, vol * 1.27)));
  },

  formatSpotlight(trackId, volume, trackColor) {
    const vol = Number.isFinite(Number(volume)) ? Number(volume) : 100;
    const pct = Math.floor((vol / 127) * 100 + 0.5);
    return {
      title: `VOLUME (TRK ${trackId})`,
      value: `${pct}%`,
      color: trackColor
    };
  }
};

export const R2_CONTRACT = {
  legacyDirections: ["UP", "DOWN", "UP-DOWN", "DOWN-UP", "CONVERGE", "DIVERGE", "RANDOM"],
  richPatterns: ["PING-PONG", "OCTAVE-HOP", "CHORD-PULSE", "SWING-16", "CRESCENDO"],
  contours: {
    accentDownbeat: [1.25, 0.85, 1.05, 0.80],
    grooveCurve: [1.10, 0.90, 1.20, 0.75, 1.05, 0.85, 1.15, 0.70]
  },
  gateProfiles: {
    accentDownbeat: [0.95, 0.45, 0.80, 0.40],
    default: [0.80]
  },
  minVelocity: 1,
  maxVelocity: 127,

  computeArpStep(stepIndex, baseVol, contourPattern, swingPercent, bpm, rateFactor) {
    const mults = this.contours[contourPattern] || [1.0];
    const idx = (((stepIndex - 1) % mults.length) + mults.length) % mults.length;
    const mult = mults[idx];
    const base = Number.isFinite(Number(baseVol)) ? Number(baseVol) : 100;
    const vel = Math.max(this.minVelocity, Math.min(this.maxVelocity, Math.floor(base * mult)));

    const currentBpm = Number.isFinite(Number(bpm)) && bpm > 0 ? Number(bpm) : 120.0;
    const currentRate = Number.isFinite(Number(rateFactor)) && rateFactor > 0 ? Number(rateFactor) : 0.25;
    const stepSec = (60.0 / currentBpm) * currentRate;

    const isEvenStep = (Math.abs(stepIndex) % 2 === 0);
    const swing = Number.isFinite(Number(swingPercent)) ? Number(swingPercent) : 50.0;
    const swingOffset = isEvenStep ? ((swing - 50.0) / 100.0) * stepSec : 0;

    return { vel, stepSec, swingOffset };
  },

  computeGateDuration(stepSec, contourPattern = "default", stepIndex = 1) {
    const profile = this.gateProfiles[contourPattern] || this.gateProfiles.default;
    const idx = (((stepIndex - 1) % profile.length) + profile.length) % profile.length;
    const gateRatio = profile[idx];
    return Math.max(0.010, stepSec * gateRatio);
  }
};

export const R3_CONTRACT = {
  defaultAmount: 90.0,
  minAmount: 0.0,
  maxAmount: 100.0,
  anticipationToleranceSec: 0.012,
  catchupToleranceSec: 0.020,
  divisionFactors: { "1/1": 4.0, "1/2": 2.0, "1/4": 1.0, "1/8": 0.5, "1/16": 0.25, "1/32": 0.125 },

  calculateDelay(bpm, mode, amount, elapsedOffset) {
    if (!mode || mode === "Off" || mode === "None") return 0;
    const factor = this.divisionFactors[mode];
    if (!factor) return 0;

    const clampedBpm = Math.max(20.0, Math.min(999.0, Number.isFinite(Number(bpm)) ? Number(bpm) : 120.0));
    const stepDuration = (60.0 / clampedBpm) * factor;

    const offset = Number.isFinite(Number(elapsedOffset)) ? Number(elapsedOffset) : 0;
    const elapsed = ((offset % stepDuration) + stepDuration) % stepDuration;
    const timeToNext = stepDuration - elapsed;

    if (timeToNext <= this.anticipationToleranceSec) return 0;
    if (elapsed <= this.catchupToleranceSec) return 0;

    const parsed = Number(amount);
    const rawAmount = (amount === undefined || amount === null || !Number.isFinite(parsed))
      ? this.defaultAmount
      : parsed;
    const quantAmount = Math.max(0, Math.min(100, rawAmount));
    if (quantAmount <= 0) return 0;

    return timeToNext * (quantAmount / 100.0);
  }
};

export const R4_CONTRACT = {
  padWidth: 58,
  padHeight: 44,
  maxInnerWidth: 52,
  maxNoteHeight: 20,
  expectedFontSize: "8.5px",
  expectedLineHeight: "9.5px",

  contrastRatio(rgb1, rgb2) {
    function luminance(rgb) {
      const a = rgb.map(v => {
        const c = v / 255;
        return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
      });
      return 0.2126 * a[0] + 0.7152 * a[1] + 0.0722 * a[2];
    }
    const l1 = luminance(rgb1);
    const l2 = luminance(rgb2);
    const lighter = Math.max(l1, l2);
    const darker = Math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }
};

export const R5_CONTRACT = {
  formatters: {
    volume: (vol) => `Vol -\n${Math.floor((vol / 127) * 100 + 0.5)}%`,
    octave: (oct) => `Oct -\n${oct >= 0 ? "+" + oct : oct}`,
    rate: (rate) => `Rate +\n${rate}`,
    gate: (gate) => `Gate +\n${gate}%`,
    direction: (dir) => `Dir +\n${dir}`,
    attack: (atk) => `Atk -\n${atk}`,
    decay: (dec) => `Dec -\n${dec}`,
    root: (root) => `Root -\n${root}`,
    mode: (mode) => `Mode -\n${mode}`,
    bpm: (bpm) => `BPM -\n${Math.round(bpm)}`
  }
};

export const R6_CONTRACT = {
  maxOrphanAgeSec: 5.0,
  staccatoGateWindowSec: 0.060,

  isVoiceOrphaned(voice, currentTime, maxAgeSec = 5.0, state = {}) {
    const age = currentTime - voice.startTime;
    if (age <= maxAgeSec) return false;
    if (voice.keycode && state.pressedKeys && state.pressedKeys[voice.keycode]) return false;
    if (state.sustainedPitches && state.sustainedPitches[voice.note]) return false;
    if (voice.heldForPending) return false;
    return true;
  },

  generatePanicMessages() {
    const msgs = [];
    for (let ch = 0; ch < 16; ch++) {
      msgs.push({ type: "cc", controller: 64, value: 0, channel: ch });  // Damper / Sustain Off
      msgs.push({ type: "cc", controller: 120, value: 0, channel: ch }); // All Sound Off
      msgs.push({ type: "cc", controller: 123, value: 0, channel: ch }); // All Notes Off
      msgs.push({ type: "cc", controller: 121, value: 0, channel: ch }); // Reset All Controllers
      msgs.push({ type: "pitchWheel", value: 8192, channel: ch });       // Pitch Bend Center
    }
    return msgs;
  }
};

export class TapTempoEngine {
  constructor() {
    this.history = [];
    this.lastTapTime = null;
    this.bpm = 120.0;
  }

  tap(t) {
    if (this.lastTapTime !== null) {
      const delta = t - this.lastTapTime;
      if (delta < 0.050) {
        return this.bpm;
      }
      if (delta > 2.0) {
        this.history = [];
      } else {
        this.history.push(delta);
        if (this.history.length > 5) this.history.shift();
        const avgDelta = this.history.reduce((a, b) => a + b, 0) / this.history.length;
        const rawBpm = 60.0 / avgDelta;
        this.bpm = Math.max(30.0, Math.min(300.0, Math.round(rawBpm * 10) / 10));
      }
    }
    this.lastTapTime = t;
    return this.bpm;
  }
}

export class MidiVoiceTracker {
  constructor() {
    this.activeVoices = new Map();
    this.sentMessages = [];
  }

  noteOn(note, channel = 0, velocity = 100, track = 1, timestamp = 0, keycode = null) {
    const key = `${note}_${channel}`;
    const voice = { note, channel, velocity, track, startTime: timestamp, keycode };
    this.activeVoices.set(key, voice);
    this.sentMessages.push({ type: "noteOn", note, channel, velocity, timestamp });
    return voice;
  }

  noteOff(note, channel = 0, timestamp = 0) {
    const key = `${note}_${channel}`;
    const voice = this.activeVoices.get(key);
    this.activeVoices.delete(key);
    this.sentMessages.push({ type: "noteOff", note, channel, timestamp });
    return voice;
  }

  checkOrphanedVoices(currentTime, maxAgeSec = 5.0, state = {}) {
    const orphans = [];
    for (const [key, voice] of this.activeVoices.entries()) {
      if (R6_CONTRACT.isVoiceOrphaned(voice, currentTime, maxAgeSec, state)) {
        orphans.push(voice);
        this.activeVoices.delete(key);
        this.sentMessages.push({
          type: "noteOff",
          note: voice.note,
          channel: voice.channel,
          timestamp: currentTime,
          reason: "watchdog_orphan"
        });
      }
    }
    return orphans;
  }

  panic() {
    this.activeVoices.clear();
    const panicMsgs = R6_CONTRACT.generatePanicMessages();
    this.sentMessages.push(...panicMsgs);
    return panicMsgs;
  }
}
