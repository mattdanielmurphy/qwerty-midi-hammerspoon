# BRIEFING — 2026-10-11T16:49:00Z

## Mission
Investigate Audio & MIDI Engine in depth for R1 (Track Volume Keys), R2 (Arp Patterns & Human Feel), R3 (Quantization Amount), R6 (Stuck Notes & Watchdog), and R7 (Tap Tempo).

## 🔒 My Identity
- Archetype: explorer
- Roles: Audio & MIDI Engine Survey Explorer
- Working directory: /Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_explorer_survey_1
- Original parent: d8b964c9-55f5-4610-a971-90f0b67129c3
- Milestone: Survey & Investigation (R1, R2, R3, R6, R7)

## 🔒 Key Constraints
- Read-only investigation — do NOT implement
- Write only to working directory: /Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_explorer_survey_1
- No idle event taps & timers while disarmed invariant
- Project root: /Users/matt/projects/qwerty-midi-hammerspoon

## Current Parent
- Conversation ID: d8b964c9-55f5-4610-a971-90f0b67129c3
- Updated: 2026-10-11T16:49:00Z

## Investigation State
- **Explored paths**: `src/config.lua`, `src/controls.lua`, `src/arpeggiator.lua`, `packages/music-engine/quantizer.lua`, `packages/music-engine/clock.lua`, `src/midi.lua`, `src/hud.lua`, `src/init.lua`, `bin/hs-bundler`, `tests/`
- **Key findings**:
  1. R1: No dedicated keys per track; `volUp`/`volDown` only target `state.activeTrack`; lower row volume is lost when KeyStep disconnected; 80ms synchronous `saveSettings` drops note events.
  2. R2: Arpeggiator has only 7 pitch sorting directions, flat static velocity (trk.volume), rigid `hs.timer.doEvery` ticks, zero velocity contours/gate variations/human microtiming.
  3. R3: `quantizer.lua` only supports binary 100% delay or Off; no strength scaling exists; needs `inputQuantizeAmount` (default 90%).
  4. R6: Fatal race in `quantizer.lua` lines 84-88 where retriggering a key halts `ev.gateTimer` before `onRelease` is fired, stranding active MIDI notes; existing `keyTapWatchdog` does not monitor MIDI notes.
  5. R7: `arpeggiator.tapTempo` is missing from `src/arpeggiator.lua`, causing silent no-op in `controls.lua`.
- **Unexplored areas**: None within the Audio & MIDI Engine scope.

## Key Decisions Made
- Confirmed `src/arpeggiator.lua` is the active module bundled into `qwerty_midi.lua`.
- Isolated exact code locations and failure mechanisms across all 5 assigned requirements.
- Formulated concrete implementation strategies for implementer agents.

## Artifact Index
- DISPATCH.md — incoming dispatch message
- BRIEFING.md — persistent working memory
- progress.md — liveness heartbeat
- analysis.md — detailed technical analysis
- handoff.md — 5-component handoff report
