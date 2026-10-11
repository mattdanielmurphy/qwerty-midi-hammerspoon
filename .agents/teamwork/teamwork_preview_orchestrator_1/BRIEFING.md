# BRIEFING — 2026-10-11T16:40:00Z

## Mission
Deliver comprehensive fix and enhancement suite for qwerty-midi-hammerspoon across R1 through R7 with 100% test verification and zero audit violations.

## 🔒 My Identity
- Archetype: teamwork_preview_orchestrator
- Roles: orchestrator, user_liaison, human_reporter, successor
- Working directory: /Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_orchestrator_1
- Original parent: Sentinel
- Original parent conversation ID: abafe46f-e439-4bbe-ada4-f7ac4ae3b50c

## 🔒 My Workflow
- **Pattern**: Project Pattern (Dual Track: Implementation + E2E Testing)
- **Scope document**: /Users/matt/projects/qwerty-midi-hammerspoon/PROJECT.md
1. **Decompose**: Survey via 3 parallel Explorers, establish PROJECT.md and TEST_INFRA.md, map R1-R7 across modules.
2. **Dispatch & Execute**:
   - Direct iteration loop per milestone: Explorer(s) → Worker → Reviewer(s) → Challenger(s) → Auditor → Gate.
   - Dual track: Implementation track and E2E Testing track.
3. **On failure**:
   - Retry: nudge stuck agent or re-send task
   - Replace: spawn fresh agent with partial progress
   - Skip: proceed without (only if non-critical; auditor is NEVER skipped)
   - Redistribute: split stuck agent's remaining work
   - Redesign: re-partition decomposition
4. **Succession**: At 16 spawns, write handoff.md, cancel timers, spawn successor.
- **Work items**:
  1. Survey & Architecture Mapping [in-progress]
  2. Test Infrastructure & E2E Suites [pending]
  3. Audio & MIDI Engine Milestones (R1, R2, R3, R6, R7) [pending]
  4. HUD & Key Overlay Milestones (R4, R5) [pending]
  5. Final E2E Test Suite & Adversarial Verification [pending]
- **Current phase**: 0 (Survey)
- **Current focus**: Survey codebase and map R1-R7 scope

## 🔒 Key Constraints
- DISPATCH-ONLY orchestrator: NEVER write/modify source code or run build/test commands directly.
- All code changes, testing, and technical investigations must be delegated to subagents.
- Forensic auditor verdict is a BINARY VETO: violation means failure, no exceptions.
- Luac check: `luac -p qwerty_midi.lua` must pass.
- Zero idle event taps & timers invariant: background timers/taps must never run while disarmed.
- Pass ORIGINAL_REQUEST.md path verbatim to all subagents.
- Never reuse a subagent after it has delivered its handoff — always spawn fresh.

## Current Parent
- Conversation ID: abafe46f-e439-4bbe-ada4-f7ac4ae3b50c
- Updated: 2026-10-11T16:38:57Z

## Key Decisions Made
- Initializing Project Pattern with parallel Survey explorers to map codebase and test architecture.

## Team Roster
| Agent | Type | Work Item | Status | Conv ID |
|-------|------|-----------|--------|---------|
| survey_explorer_1 | teamwork_preview_explorer | Survey Audio & MIDI Engine (R1, R2, R3, R6, R7) | in-progress | 54383719-0809-44f2-9824-b1112ddd5833 |
| survey_explorer_2 | teamwork_preview_explorer | Survey HUD & UI Overlay (R4, R5) | in-progress | 70a33529-66a7-4b1f-a1a7-046413d90a7d |
| survey_explorer_3 | teamwork_preview_explorer | Survey Test Infra & Verification | in-progress | ecd948b7-0ad0-43ca-8426-580d0ff71f6e |

## Succession Status
- Succession required: no
- Spawn count: 3 / 16
- Pending subagents: 54383719-0809-44f2-9824-b1112ddd5833, 70a33529-66a7-4b1f-a1a7-046413d90a7d, ecd948b7-0ad0-43ca-8426-580d0ff71f6e
- Predecessor: none
- Successor: not yet spawned

## Active Timers
- Heartbeat cron: d8b964c9-55f5-4610-a971-90f0b67129c3/task-18 (every 10 min)
- Safety timer: none
- On succession: kill all timers before spawning successor
- On context truncation: run manage_task(Action="list") — re-create if missing

## Artifact Index
- /Users/matt/projects/qwerty-midi-hammerspoon/AG_CONTEXT.md — Repository context and domain knowledge
- /Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/ORIGINAL_REQUEST.md — User requirements
- /Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_orchestrator_1/DISPATCH.md — Dispatch log
- /Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_orchestrator_1/progress.md — Liveness and status heartbeat
- /Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_orchestrator_1/plan.md — Project plan
