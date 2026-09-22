# Modifier-Safe Track Cards and Focused Arp Rate

- Kept Track 1–4 in a persistent `track-card` presentation across modifier layers, with independent code, role, action, and M/S state zones.
- Restored textual mappings to regular controls K, L, and ; while shortening modifier-layer track actions to `MUTE 1` through `MUTE 4`.
- Routed arp-rate changes to the selected track, persisted each track's rate, and recreated only its running arp timer with the new interval.

## Verification

- `bun test` passed: 9 files, 0 failures.
- `bun run bundle` rebuilt the embedded HUD and reloaded Hammerspoon.
- Live HUD review on the Shift layer confirmed readable track actions and mapped K/L/; controls without zone collisions.
