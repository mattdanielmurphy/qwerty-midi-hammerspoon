---
name: scope-and-verification
description: Enforce task boundaries and a fail-closed activation, verification, and scoped-publication gate for every project code task.
---

# Scope and Verification

Use this workflow for every project code or documentation task, especially when
continuing another agent's work or when the user emphasizes scope, testing, or
commit requirements. “Implemented” is not “complete.”

## Before editing

1. Read the complete source-thread history and all applicable project
   instructions. Keep explicit exclusions out of scope.
2. Capture a Git baseline: current branch/upstream, `HEAD`, ahead/behind count,
   and staged, unstaged, and untracked paths. Do not clean, reset, or stage the
   baseline.
3. Define the task-owned paths (and hunks if a task overlaps a modified file).
   Do not implement a deferred subtask merely because it appears related.

## Completion gate

Do not report a code task as complete until every applicable item succeeds:

1. **Activate.** For Lua or offline-HUD changes, run
   `bash bin/bundle_and_reload.sh`, run `luac -p qwerty_midi.lua`, and verify
   the intended module loaded in running Hammerspoon. For a Vite-served
   web-only change, verify HMR in the live HUD; also bundle when the deliverable
   is the offline UI.
2. **Verify.** Run the relevant Bun test suite and focused tests after the final
   edit. Record the commands and exit results. Device-dependent behavior needs
   an observed device check when available; otherwise call it unverified, not
   passed.
3. **Publish scoped work.** Compare the final state to the baseline. Stage only
   task-owned clean-baseline paths or reviewed, safely isolated task hunks;
   never use `git add .`. Commit the verified task changes, push to the
   established upstream, then confirm the commit SHA, file list, and push.
   Pre-existing dirty changes must remain intact. They are not a reason to skip
   the task commit or a license to publish someone else's work.

## Fail-closed handoff

If reload, module-load observation, a required check, commit, or push fails—or
if ownership of overlapping same-file changes cannot be safely isolated—stop
and report the exact blocker with evidence and the next safe action. Do not
describe the task as done, verified, active, or committed with any gate item
missing.

Final reports must state: activation evidence, test commands/results, commit
SHA, push result, and any pre-existing changes left untouched.
