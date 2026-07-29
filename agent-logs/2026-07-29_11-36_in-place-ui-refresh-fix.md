# In-Place Manual UI Refresh Fix (Cmd+Alt+R)

## Topic
In-Place Manual UI Refresh Fix (`Cmd+Alt+R`)

## Summary
Replaced window deletion/recreation in `Cmd+Alt+R` (`midiRefreshHotkey`) with `hud.reloadMidiWebview()`. Reads fresh HTML from `src/web/index.html` on disk and injects via `:html(freshHtml)` to perform clean in-place reload without window destruction or cached string lockup.
