---
name: scope-and-verification
description: Enforce explicit task boundaries and project-required verification and commits when resuming work from another agent thread.
---

# Scope and Verification

Use this workflow when continuing work from another agent or conversation, or
when the user emphasizes scope, testing, or commit requirements.

1. Read the complete source-thread history and all applicable project
   instructions before changing files. Keep explicit exclusions out of scope.
2. Do not implement a deferred subtask, even if it appears related to the main
   request. Ask only if the requested work cannot proceed without it.
3. Before reporting project code work complete, run the repository's required
   test suite and any project-specific build or syntax checks after the final
   edit.
4. Commit the verified changes when the repository workflow or user requires a
   commit. Never claim completion while a required test or commit is missing.
5. If the user reports a broken app, capture the exact runtime error, repair the
   reported failure, reload the app, and verify the working state directly.
