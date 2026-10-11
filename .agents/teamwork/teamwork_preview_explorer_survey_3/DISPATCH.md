## 2026-10-11T16:40:33Z
[Message] timestamp=2026-10-11T16:40:33Z sender=d8b964c9-55f5-4610-a971-90f0b67129c3 priority=MESSAGE_PRIORITY_HIGH content=You are an Explorer subagent for the qwerty-midi-hammerspoon project.
Your identity: Survey Explorer 3 (Test Infra & Verification)
Your working directory: /Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_explorer_survey_3
Project root: /Users/matt/projects/qwerty-midi-hammerspoon

Authoritative User Request:
Read /Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/ORIGINAL_REQUEST.md
Also read /Users/matt/projects/qwerty-midi-hammerspoon/AG_CONTEXT.md

Your mission:
Survey and investigate the testing infrastructure, build pipeline, and verification mechanisms:
1. Existing Tests: Inspect `package.json`, any tests in `tests/`, `packages/`, or root. How are tests currently executed (e.g., `bun test`)? What test files exist?
2. Build & Bundle Pipeline: Examine `bin/hs-bundler`, `bin/bundle_and_reload.sh`, `qwerty_midi.lua`, and how `luac -p qwerty_midi.lua` is validated. How does syncing `src/web/index.html` into `src/ui_html.lua` work?
3. Test Architecture for R1-R7: How can we structure a comprehensive 4-tier E2E testing suite (Tier 1: Feature Coverage, Tier 2: Boundary/Edge Cases, Tier 3: Cross-Feature Interactions, Tier 4: Real-World Scenarios) using Bun and Lua tests?
   - How to test MIDI CC 7 track volume adjustments without dropping events (R1)
   - How to test rich arpeggiator patterns, velocity contours, and human microtiming (R2)
   - How to test configurable quantization strength 0-100%, defaulting to 90% (R3)
   - How to test DOM / CSS key overlay wrapping, contrast, and pass-through suppression (R4)
   - How to test real-time state indicators on key surfaces (R5)
   - How to test rapid consecutive keypresses, note-off drops, and watchdog loop cleanup (R6)
   - How to test tap tempo calculation and BPM updates (R7)

Write your findings to `analysis.md` and complete a full `handoff.md` in your working directory (/Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_explorer_survey_3).
When finished, send a message to parent with a summary and the path to your handoff.md.
