# Ideas

## Plugin version — shelved (Matt, 2026-11-07)
"We can shelve the plugin version of it for now." The app relies on Hammerspoon anyway, so a plugin (`~/projects/qwerty-midi-plugin`) would be a second app without replacing the first.
Take: right call. Revive only if the controller ever has to run without Hammerspoon.

## Piano key-lock + weekly scale (Matt, 2026-11-07) — built
Yamaha P-45 → Hammerspoon → IAC Bus 1 ch 16 → Ableton, out-of-key note-ons dropped, a new scale every Monday 04:00 around the circle of fifths. Code: `packages/piano-lock/piano_lock.lua`, engine `packages/music-engine/scale_lock.lua`.
Take: strong practice tool; the weak spot is that it depends on Ableton running (Local Control off mutes the piano otherwise). Follow-up worth considering: let the QWERTY controller start on the weekly scale too (`require("scale_lock").getState().root`).

- 2026-11-08 · Matt · Piano HUD: when most notes fall outside this week's key, notice which key he's actually playing in and say so, instead of "90% wrong". Take: strong. The "% wrong" figure is misleading when he's playing in another key on purpose. Detection is cheap: score his last ~30 notes against the 24 major/minor keys (Krumhansl profiles). Related bug found the same day: the lock had dropped 831 notes, but Ableton still played them, so Ableton is probably also listening to the piano directly and bypassing the lock.
