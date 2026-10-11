# Orchestration Plan: qwerty-midi-hammerspoon R1-R7 Suite

## 1. Objectives
Execute all requirements R1 through R7:
- R1: Track Volume Control Keys (dedicated key bindings per track)
- R2: Rich Arpeggiator Patterns & Human Feel (velocity contours, gate lengths, microtiming)
- R3: Configurable Quantization Amount (default 90%, range 0-100%)
- R4: Key Overlay Legibility & Label Text Wrapping (wrapping within key boundaries, eliminate pass-through clutter, clear opacity/contrast)
- R5: Real-Time State Indicator on Keys (active state/value displayed directly on key surface)
- R6: Stuck Note Mitigation & Watchdog Loop (rapid consecutive key playback fix + watchdog loop)
- R7: Tap Tempo Functionality (diagnose and repair tap tempo engine)

## 2. Phase 0: Survey
Spawn 3 Explorers in parallel:
- Explorer 1 (Audio Engine): Investigate MIDI, arpeggiator, quantizer, stuck notes, volume controls, tap tempo (`src/midi.lua`, `src/arpeggiator.lua`, `packages/music-engine/quantizer.lua`, `src/controls.lua`, `src/config.lua`).
- Explorer 2 (HUD & UI): Investigate key overlay rendering, text wrapping, modifier handling, pass-through clutter, real-time indicators (`src/hud.lua`, `src/web/index.html`, `src/ui_html.lua`).
- Explorer 3 (Test Infra & Verification): Investigate existing test harness, bun test setup, how tests are executed, how Hammerspoon bundling works (`bin/hs-bundler`, `bin/bundle_and_reload.sh`, `tests/`).

## 3. Phase 1: Architecture, Feature Inventory & Milestones
Merge explorer findings into `PROJECT.md` and `TEST_INFRA.md`. Decompose into well-bounded milestones.

## 4. Phase 2: Dual-Track Implementation & Testing
For each milestone: Explorer -> Worker -> Reviewers -> Challengers -> Auditor -> Gate.

## 5. Phase 3: Final Acceptance & Bundling
Run full E2E test suite, ensure `luac -p qwerty_midi.lua` is valid, verify zero idle event taps/timers, compile completion report for Sentinel.
