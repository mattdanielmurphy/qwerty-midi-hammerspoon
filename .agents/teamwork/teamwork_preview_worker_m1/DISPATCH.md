## 2026-10-11T16:57:37Z

You are a Worker subagent for Milestone M1 of qwerty-midi-hammerspoon.
Your identity: M1 Worker (Test Infrastructure & Build Hardening Implementer)
Your working directory: /Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_worker_m1
Project root: /Users/matt/projects/qwerty-midi-hammerspoon

Authoritative User Request:
Read /Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/ORIGINAL_REQUEST.md
Also read:
- /Users/matt/projects/qwerty-midi-hammerspoon/AG_CONTEXT.md
- /Users/matt/projects/qwerty-midi-hammerspoon/PROJECT.md
- /Users/matt/projects/qwerty-midi-hammerspoon/TEST_INFRA.md
- /Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_explorer_m1_1/handoff.md
- /Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_explorer_m1_2/handoff.md
- /Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_explorer_m1_3/handoff.md
- /Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_explorer_m1_3/build_pipeline_hardening.patch

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Write ownership:
You own exclusively:
- `bin/bundle_and_reload.sh`
- `bin/hs-bundler`
- `package.json`
- Files in `tests/` (new test suites and test harness)
Do NOT modify core production Lua code in `src/` or `packages/` during this milestone — that is reserved for Milestones M2, M3, and M4.

Your mission:
1. Apply the build pipeline hardening specified by M1 Explorer 3:
   - Apply or incorporate `bin/bundle_and_reload.sh` hardening (`luac -p qwerty_midi.lua` validation before reload, abort with exit 1 on failure).
   - Apply or incorporate `bin/hs-bundler` hardening (deterministic module sorting, safe multiline `[===[ ... ]===]` literal fencing).
   - Update `package.json` to include `"test": "bun test"`.
2. Implement the comprehensive test infrastructure and test suites in `tests/` as specified by M1 Explorers 1 and 2:
   - `tests/hud_overlay_wrapping_and_contrast.test.js` (R4 tests)
   - `tests/realtime_state_indicators_and_zls.test.js` (R5 tests)
   - `tests/hud_modifier_and_parameter_scenarios.test.js` (Tier 3 & 4 UI scenarios)
   - `tests/tier1_feature_contracts/` test suites for R1, R2, R3, R6, R7
   - `tests/tier2_boundary_edge_cases/` boundary test suites for R1, R2, R3, R6, R7
   - `tests/tier3_cross_feature_interactions/` cross-feature interaction test suites
   - `tests/tier4_real_world_e2e_scenarios/` real-world live performance test suites
   - `tests/harness/hs_mock.lua` headless Lua mock environment
   Note: Tests should cleanly test contracts, formulas, CSS rules, and boundaries. Where future implementation code is tested, ensure assertions test the required contracts cleanly so they will pass once M2, M3, and M4 implement the features, or structure them to run against the mock/contract definitions.
3. Verify:
   - Run `bun test` and ensure all tests run cleanly without crashes.
   - Run `python3 bin/hs-bundler --target qwerty-midi` and verify bundle generation.
   - Run `luac -p qwerty_midi.lua` and ensure exit code 0.
4. Document all changes, test commands, and exact outputs in `changes.md` and `handoff.md` in your working directory.
When finished, send a message to parent with your summary and verification results.
