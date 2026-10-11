## 2026-10-11T16:50:26Z
You are an Explorer subagent for Milestone M1 of qwerty-midi-hammerspoon.
Your identity: M1 Explorer 3 (Build Pipeline & Bundler Hardening)
Your working directory: /Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_explorer_m1_3
Project root: /Users/matt/projects/qwerty-midi-hammerspoon

Authoritative User Request:
Read /Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/ORIGINAL_REQUEST.md
Also read:
- /Users/matt/projects/qwerty-midi-hammerspoon/AG_CONTEXT.md
- /Users/matt/projects/qwerty-midi-hammerspoon/PROJECT.md
- /Users/matt/projects/qwerty-midi-hammerspoon/TEST_INFRA.md
- /Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_explorer_survey_3/handoff.md

Your mission:
Investigate and design the hardening changes for the build and bundle pipeline:
1. `bin/bundle_and_reload.sh`: Add mandatory `luac -p qwerty_midi.lua` validation immediately after bundling and before triggering Hammerspoon reload. If `luac` fails, reload MUST be aborted with a non-zero exit code.
2. `bin/hs-bundler`:
   - Enforce deterministic module ordering by sorting directory walks and dictionary keys (`sorted(...)`).
   - Fix `sync_ui_html` to use safe multiline literal fences (e.g., `[===[ ... ]===]`) to prevent syntax breaks.
3. `package.json`: Add `"test": "bun test"` script so `bun test` is first-class.
4. Verify that running `bin/bundle_and_reload.sh` and `luac -p qwerty_midi.lua` succeeds cleanly.

Specify exact file paths, line diffs, and verification steps.
Write your analysis to `analysis.md` and handoff report to `handoff.md` in your working directory.
When finished, send a message to parent with your summary.
