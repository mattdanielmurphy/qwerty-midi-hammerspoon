# Handoff Report — Test Infrastructure, Build Pipeline & Verification Survey

**Agent**: Survey Explorer 3 (Test Infra & Verification)  
**Date**: 2026-10-11  
**Working Directory**: `/Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_explorer_survey_3`  
**Handoff Type**: Hard (Investigation & Architecture Complete)

---

## 1. Observation

1. **Existing Test Suite Execution**:
   - `package.json` contains no `"test"` script entry.
   - Command `bun test` ran 77 tests across 19 test files in `tests/` in 750ms:
     ```
     77 pass
     0 fail
     665 expect() calls
     Ran 77 tests across 19 files. [750.00ms]
     ```
   - All 19 test files use `bun:test` and inspect source code contracts, string patterns, CSS bounding boxes, and JS math models.

2. **Bundle & Reload Pipeline**:
   - `bin/bundle_and_reload.sh` lines 9–18:
     ```bash
     echo "📦 Bundling Hammerspoon modules..."
     python3 "$PROJECT_DIR/bin/hs-bundler" --target qwerty-midi
     if [ $? -eq 0 ]; then
       echo "⚡ Reloading Hammerspoon..."
       if command -v hs >/dev/null 2>&1; then
         hs -c "hs.reload()" >/dev/null 2>&1 &
     ```
     Does **not** run `luac -p qwerty_midi.lua` before reloading Hammerspoon.
   - Running `luac -p qwerty_midi.lua` directly succeeds with exit code 0.
   - In `bin/hs-bundler`, `sync_ui_html` (lines 61-64) wraps `src/web/index.html` in:
     ```python
     lua_module_content = f'local HTML_UI_CONTENT = [[\n{html_content}\n]]\n\nreturn HTML_UI_CONTENT\n'
     ```
     using raw `[[ ... ]]` multiline strings.
   - In `bin/hs-bundler`, `os.walk` (line 91) iterates without sorting (`for root, _, files in os.walk(abs_src_dir)`), causing non-deterministic module ordering and massive git diff churn.

3. **Requirement R1 (Track Volume Control Keys)**:
   - `src/controls.lua:495-512` defines `adjustTrackVolume(trackId, delta)`, sending `midi.sendMidiCC(7, trk.volume, trk.channel)`.
   - Web UI triggers it (`src/ui_html.lua:3715, 3727`), but `src/controls.lua:559-640` and `src/config.lua:388-393` lack dedicated keyboard action bindings for individual tracks (Tracks 1–4). Keyboard only has `volUp`/`volDown` (active track), `topVolUp`/`topVolDown` (top row), `botVolUp`/`botVolDown` (bottom row).

4. **Requirement R2 (Rich Arpeggiator Patterns & Human Feel)**:
   - `src/config.lua:58`: `ARP_DIRECTIONS = { "UP", "DOWN", "UP-DOWN", "DOWN-UP", "CONVERGE", "DIVERGE", "RANDOM" }`.
   - `src/arpeggiator.lua:418-420`: Velocity is statically calculated as `math.floor(math.min(127, (trk.volume or 100) * 1.0))`. Gate length is strictly linear `trackStepSec * gateRatio`. No velocity contours, swing, or microtiming deviations exist.

5. **Requirement R3 (Configurable Quantization Amount 0–100%)**:
   - `packages/music-engine/quantizer.lua:36-64`: `calculateDelay(bpm, mode)` computes `timeToNext = stepDuration - elapsed`.
   - There is no strength parameter; it either delays to the exact grid boundary or plays immediately if mode is `"Off"`. Configurable 0–100% strength defaulting to 90% is missing.

6. **Requirement R4 (Key Overlay Legibility & Label Wrapping)**:
   - `src/web/index.html:737`: `.key-pad .key-note` has `white-space: nowrap;`. Labels longer than ~7 characters overflow the 58px key container.
   - `src/hud.lua:948-970`: Under Cmd hold (`activeLayer == "cmd"` or `"cmdShift"`), all unmapped keys in 0..127 receive `{ name = "Pass Through", class = "shortcut-passthrough" }`, flooding the entire keyboard with redundant "Pass Through" labels.
   - `src/web/index.html:1010`: `.shortcut-passthrough` has `opacity: 0.4 !important;`, causing muddy dimming.

7. **Requirement R5 (Real-Time State Indicators on Keys)**:
   - `src/hud.lua:888-943`: Only Key A (Arp/Latch) and Key Tab (Sustain) dynamically update their display text based on state. Control keys for Attack, Decay, Volume, Octave, Transpose, BPM, and Quantize display static action names without active quantities.

8. **Requirement R6 (Stuck Note Mitigation & Watchdog Loop)**:
   - `src/init.lua:418`: `keyTapWatchdog` only monitors webview heartbeat/pong.
   - No watchdog loop exists to monitor `activeNoteLedger` in `src/midi.lua` or `soundingNotes` in `quantizer.lua` to detect and clear orphaned active MIDI notes.

9. **Requirement R7 (Tap Tempo Engine)**:
   - `src/controls.lua:2018-2021`:
     ```lua
     elseif act == "tapTempo" then
       if arpeggiator.tapTempo then
         arpeggiator.tapTempo()
       end
     ```
   - In `src/arpeggiator.lua` and `packages/music-engine/clock.lua`, `tapTempo` is **completely missing / undefined**. Calling tap tempo is a no-op.

10. **Environment Binaries**:
    - `/opt/homebrew/bin/lua` (Lua 5.4.8), `/opt/homebrew/bin/luac`, `/opt/homebrew/bin/luajit`, and `/usr/local/bin/hs` (Hammerspoon CLI) are installed and verified operational.

---

## 2. Logic Chain

1. **Test Infrastructure Readiness**:
   - Based on (1) and (10), Bun executes tests in ~750ms and local Lua binaries are fully available. We can run both JavaScript-based contract/simulation tests and native Lua tests.
   - Based on (1), adding `"test": "bun test"` to `package.json` aligns the workspace with standard Bun workflow.

2. **Pipeline Safety**:
   - Based on (2), `bundle_and_reload.sh` does not run `luac -p qwerty_midi.lua`. A syntax error in any `.lua` file will cause Hammerspoon to reload a broken script. Adding `luac -p` validation before reload is essential for stability.
   - Based on (2), `hs-bundler` emits modules in non-deterministic order. Sorting `files` and `modules.keys()` will make builds 100% deterministic and eliminate unnecessary git churn.
   - Based on (2), wrapping HTML in `[===[ ... ]===]` prevents premature literal closure.

3. **Requirements R1–R7 Test Suite Architecture**:
   - Based on (3)–(9), the core defects in R1–R7 are well-isolated and can be systematically covered by a 4-tier testing hierarchy:
     - **Tier 1 (Feature Contracts)**: Verify the addition of dedicated volume keys (R1), rich arp patterns and velocity contours (R2), quantize strength parameter (R3), CSS label wrapping and pass-through filtering (R4), dynamic key state badges (R5), MIDI watchdog timer creation (R6), and tap tempo math implementation (R7).
     - **Tier 2 (Boundary & Edge Cases)**: Clamping limits (0 vs 127 volume, 0% vs 100% quantize, 30 vs 300 BPM), long label stress testing in 58px keys, single tap vs spaced tap (> 2s), and rapid keypresses (< 10ms).
     - **Tier 3 (Cross-Feature Interactions)**: Volume changes during rapid quantized playing (R1+R6), tap tempo updating active arpeggiators without gate drops (R2+R7), quantize legato sustaining without watchdog interference (R3+R6), and modifier overlay legibility with live state indicators (R4+R5).
     - **Tier 4 (Real-World E2E Scenarios)**: Multi-track live performance simulation and chaos key mashing with panic recovery.

---

## 3. Caveats

1. **Hammerspoon Runtime Execution**: Hammerspoon APIs (`hs.midi`, `hs.timer`, `hs.eventtap`, `hs.webview`) cannot be imported into bare CLI `lua` without a mock environment. Our design includes `tests/harness/hs_mock.lua` to simulate Hammerspoon primitives for headless Lua execution.
2. **Audio Output Verification**: Tests can verify MIDI status bytes, controller numbers, channel numbers, velocity, and timestamp scheduling, but physical CoreMIDI audio synthesizer output (e.g. Logic Pro software instrument audio rendering) requires the external DAW running on the host.

---

## 4. Conclusion

The testing infrastructure is fast (`bun:test` passes in 750ms) but currently limited to contract matching and math simulations. The build pipeline has two immediate vulnerabilities: missing `luac -p` pre-reload validation and non-deterministic bundle ordering. Requirements R1–R7 exhibit specific, identifiable gaps in the codebase (notably, `tapTempo` is missing entirely, `quantizer` has no strength factor, `arpeggiator` lacks velocity contours, and `index.html` forces `white-space: nowrap`). Implementing the 4-tier E2E testing architecture detailed in `analysis.md` will provide complete, verifiable coverage across feature contracts, boundaries, cross-feature interactions, and live performance workflows.

---

## 5. Verification Method

To independently verify all findings:
1. **Run Bun Test Suite**:
   ```bash
   bun test
   ```
   Confirms 77 passing tests across 19 test files.
2. **Verify Bundled Lua Syntax**:
   ```bash
   luac -p qwerty_midi.lua
   ```
   Confirms bundle compiles with zero syntax errors.
3. **Verify Bundler Execution**:
   ```bash
   python3 bin/hs-bundler --target qwerty-midi
   ```
   Confirms bundle generation and UI sync into `src/ui_html.lua`.
4. **Inspect Missing `tapTempo` in Source**:
   ```bash
   grep -n "tapTempo" src/controls.lua src/arpeggiator.lua packages/music-engine/clock.lua
   ```
   Shows `controls.lua:2018` references `arpeggiator.tapTempo()`, but it is nowhere defined in `arpeggiator.lua` or `clock.lua`.
5. **Inspect Nowrap Styling**:
   ```bash
   sed -n '732,740p' src/web/index.html
   ```
   Shows `white-space: nowrap;` on `.key-pad .key-note`.
