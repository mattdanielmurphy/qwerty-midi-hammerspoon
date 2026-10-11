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
    return Math.max(0, Math.min(15, trackId - 1));
  },

  adjustVolume(initialVol, delta) {
    const vol = Number(initialVol);
    const d = Number(delta);
    const base = Number.isFinite(vol) ? vol : this.defaultVolume;
    const change = Number.isFinite(d) ? d : 0;
    return Math.max(this.minVolume, Math.min(this.maxVolume, Math.round(base + change)));
  },

  formatSpotlight(trackId, volume, trackColor) {
    const pct = Math.floor((volume / 127) * 100 + 0.5);
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
  minVelocity: 1,
  maxVelocity: 127,

  computeArpStep(stepIndex, baseVol, contourPattern, swingPercent, bpm, rateFactor) {
    const mults = this.contours[contourPattern] || [1.0];
    const mult = mults[(stepIndex - 1) % mults.length];
    const vel = Math.max(this.minVelocity, Math.min(this.maxVelocity, Math.floor(baseVol * mult)));

    const stepSec = (60.0 / bpm) * rateFactor;
    const isEvenStep = (stepIndex % 2 === 0);
    const swingOffset = isEvenStep ? ((swingPercent - 50.0) / 100.0) * stepSec : 0;

    return { vel, stepSec, swingOffset };
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

    const clampedBpm = Math.max(20.0, Math.min(999.0, bpm || 120.0));
    const stepDuration = (60.0 / clampedBpm) * factor;

    const elapsed = elapsedOffset % stepDuration;
    const timeToNext = stepDuration - elapsed;

    if (timeToNext <= this.anticipationToleranceSec) return 0;
    if (elapsed <= this.catchupToleranceSec) return 0;

    const quantAmount = Math.max(0, Math.min(100, amount === undefined || amount === null ? this.defaultAmount : Number(amount)));
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
  staccatoGateWindowSec: 0.060
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
