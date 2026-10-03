# Arturia KeyStep 32 Performance Specification & Modal Shift Architecture

This document specifies the live performance architecture for the Arturia KeyStep 32 controller within the `surface-studio-suite` / `qwerty-midi-hammerspoon` ecosystem. It details both the long-term design vision (5 core performance dimensions) and the MVP implementation covering fundamental parameter multiplexing and white-key scale transposition.

---

## 1. Physical Hardware Constraints & Routing Topology

### Hardware Layout & Characteristics
* **Keybed:** 32 slimkeys spanning F2 (note 41) to C5 (note 72). Velocity and channel aftertouch supported.
* **Touch Strips:**
  * **Pitch Strip:** Spring-returns to center value (8192) upon release. Emits standard 14-bit pitch bend.
  * **Mod Strip:** Capacitive touch ribbon with LED ladder. Retains position upon finger release (0..127). Emits standard MIDI CC #1.
* **Rotary Knobs:**
  * **Seq / Arp Mode Knob:** 8 physical detented positions.
  * **Time Div Knob:** 8 physical detented positions (straight and triplet divisions).
  * **Rate Knob:** Continuous smooth potentiometer (30..240 BPM range).
* **Firmware Buttons:** `Shift`, `Hold`, `Oct -`, `Oct +`, `Play`, `Stop`, `Rec`, `Tap`.
  * *Constraint:* Hardware buttons (including physical `Shift`) route internally within the KeyStep MCU and do not emit host-interceptable MIDI packets.

### Routing Topology
* **DAW Configuration (Logic Pro):** Physical `Arturia KeyStep 32` input is disabled in DAW MIDI Input preferences.
* **Virtual Bridge:** The DAW listens exclusively to Hammerspoon's virtual MIDI output (`IAC Driver Bus 1` or virtual source).
* **Hammerspoon Interception:** `hs.midi` captures all KeyStep events with zero latency, providing complete authority to swallow, transpose, reroute, and multiplex physical inputs.

---

## 2. Core Vision: The 5 Performance Dimensions

### Dimension 1: Knob & Touch Strip Multiplexing (Modal Shift Keys via Black Keys)
Instead of requiring external hardware button pages or mouse clicking, the 5 black keys per octave are repurposed as **momentary and latching shift triggers**. Grouped naturally into their physical clusters (**Group of 2:** C#/Db, D#/Eb; **Group of 3:** F#/Gb, G#/Ab, A#/Bb), they provide distinct tactile operating zones.

| Black Key (Pitch Class) | Cluster | Modal Function | Primary Target (Mod Strip / Rate) | Secondary Target (Pitch Strip / Stepped) | Color Theme |
|---|---|---|---|---|---|
| **C# / Db** (1) | Pair (Left) | **Timbre / Filter** | Filter Cutoff (CC #74) | Filter Resonance (CC #71) | Neon Cyan (`#00e5ff`) |
| **D# / Eb** (3) | Pair (Right) | **Space / Reverb** | Reverb Send (CC #91) | Reverb Decay / Size | Vibrant Amber (`#ff9100`) |
| **F# / Gb** (6) | Trio (Left) | **Echo / Delay** | Delay Send (CC #92) | Delay Feedback / Time | Electric Magenta (`#d500f9`) |
| **G# / Ab** (8) | Trio (Center) | **Envelope / Release** | Synth Release Time (CC #72) | Synth Attack Time (CC #73) | Emerald Green (`#00e676`) |
| **A# / Bb** (10) | Trio (Right) | **Master / Volume** | Master Volume (CC #7) | Master Pan / Balance (CC #10) | Gold (`#ffd700`) |

#### Momentary vs. Latching Mechanics
* **Momentary Hold (> 250ms):** Holding a black key temporarily routes the Mod Strip and Rate Knob to that parameter. Releasing the key instantly reverts controls back to default play (Modwheel CC #1 / Rate).
* **Quick Tap / Double-Tap (< 250ms):** Tapping a black key latches the parameter mode. The player can release their left hand completely to play melodies with both hands while occasionally tweaking the knob or ribbon. Tapping the same black key again unlatches back to default.

---

### Dimension 2: Harmonic & Voicing Modifiers (Chord Engine)
Because white keys are locked to the selected musical scale/mode, black keys can act as instant diatonic chord expanders:
* **Db (Triad Modifier):** Holding Db transforms white-key taps into full 3-note diatonic chords (1-3-5 of the active scale).
* **Eb (7th/9th Extension):** Upgrades active chords with diatonic upper extensions (7ths or 9ths).
* **Gb (Inversion / Drop 2):** Drops the lowest chord voice down an octave for open, balanced voicings.
* **Ab (Strum Trigger):** Holding Ab arpeggiates/strums chords based on Mod Strip swipe speed and direction.
* **Bb (Drone / Pedal Point):** Latches the lowest tonic/root note as a continuous background drone while playing lead lines above it.

---

### Dimension 3: Advanced Sequencer & Pattern Control
Real-time pattern manipulation without interrupting playback:
* **Db:** Loop Truncate / Polyrhythm Length adjustment.
* **Eb:** Direction Toggle (Forward → Reverse → Ping-Pong → Random).
* **Gb:** Step Overwrite / Note Inject mode (hold to punch-in steps).
* **Ab:** Pattern Rotate Left (-1 step).
* **Bb:** Pattern Rotate Right (+1 step).
* **Ratcheting / Stutter:** Tapping Db/Eb during playback triggers 1/16th or 1/32nd note rolls.

---

### Dimension 4: Performance & Expression Utilities
* **Scale Inversion / Mirroring:** Pressing Db + Eb together inverts interval direction (ascending keyboard plays descending pitches).
* **Temporary Micro-Ducking (Sidechain):** Tapping Gb sends an instant momentary volume dip curve (simulating 4-on-the-floor kick ducking).
* **Freeze / Sustain Capture:** Holding Bb sustains currently playing voices indefinitely while permitting soloing over top.

---

### Dimension 5: UI/UX & GUI Synergy Strategies
* **Visual Cluster Accents:** The on-screen KeyStep view color-codes the 2-key and 3-key black clusters matching their active assignments.
* **Dynamic Parameter HUD Ring:** Holding or latching a black key activates a high-contrast glowing badge above the touch strips and knobs showing exact parameter names, CC numbers, and real-time values.
* **Latch Status Display:** Prominent `[LATCHED: CUTOFF]` badge prevents mode ambiguity during fast live performance.

---

## 3. MVP Implementation (Monday Jam Core)

For immediate live jam readiness, the MVP delivers the fundamental requirements:

1. **All 7 Core Controls Covered:**
   * **Modwheel:** Touch Strip 2 (CC #1 in default mode).
   * **Pitch:** Touch Strip 1 (14-bit pitch bend in all modes).
   * **Volume:** Master Volume (CC #7 via Bb shift or default Rate).
   * **Reverb:** Reverb Send (CC #91 via Eb shift).
   * **Delay:** Delay Send (CC #92 via Gb shift).
   * **Cutoff:** Filter Cutoff (CC #74 via Db shift).
   * **Release:** Synth Release (CC #72 via Ab shift).

2. **White-Key Scale Quantization & Transposition:**
   * All 19 white keys on KeyStep map dynamically through `harmony.getTransposedPitch()`.
   * KeyStep white keys play 100% in-scale notes matching the selected Root and Scale/Mode (Major, Minor, Dorian, Phrygian, Lydian, Mixolydian, Locrian, etc.).
   * White-key releases are paired with their exact transposed pitch to guarantee zero hung notes.

3. **Black-Key Shift Interceptor:**
   * Black keys do not emit sound.
   * Pressing Db, Eb, Gb, Ab, or Bb activates Cutoff, Reverb, Delay, Release, or Volume mode.
   * Support for both momentary hold and tap-to-latch.
   * Mod Strip and Rate Knob dynamically adjust the active parameter.

4. **HUD Telemetry:**
   * Embedded KeyStep GUI displays real-time mode status, active parameter values, and visual key highlights.
