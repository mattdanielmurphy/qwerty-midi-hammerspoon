# Fail-Closed Agent Completion Gate

Matt identified repeated incomplete handoffs: source edits were described as
done despite no live Hammerspoon activation, no test run, and no scoped commit
or push.

The project now requires agents to capture a Git baseline before edits; activate
and observe the affected runtime; run relevant checks; and commit/push only
task-owned changes. Pre-existing dirt remains protected, but cannot be used as
a reason to skip scoped publication. Missing activation, verification, commit,
or push is a named blocker rather than a completed task.

## Verification evidence

`bun test` was run against the current committed checkout and produced 41
passes and 2 failures. Both failures are in tests that still expect the removed
KeyStep `VOLUME` shift mode (`cc = 7`), while the committed implementation now
uses the ADSR `ENVELOPE` mode (`cc = 24`). The same stale expectation appears in
the KeyStep HUD wiring test. This is an existing feature-verification blocker,
not a reason to weaken the gate or declare the runtime reloaded.
