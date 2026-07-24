# Agent Log: 2026-07-24 16:23 - Arp Key Light Up State

## Goal
Light up the Arp toggle key (` ~ / key 50) and top/bottom row arp keys (`1` / key 18 and `2` / key 19) in the HUD keyboard grid when enabled, matching the active highlighted appearance of other toggle keys like Sustain (`Tab`) and Latch (`A`).

## User Feedback & Decisions
- The user requested that the Arp key light up when enabled like other toggle keys.

## Changes Made
- `src/hud.lua`: Updated `numberRowControls` key state evaluation to check active toggle status for main Arp (`code 50`), Top Arp (`code 18`), and Bot Arp (`code 19`). Set `sustainActive = isArpActive` on their HUD payload objects so `ui_html.lua` applies the `.sustain-active` highlighted glow styling.

## What Worked
- Re-evaluated number row key states in `hud.lua` so active toggle states for Arp (`~`), Top Arp (`1`), and Bot Arp (`2`) automatically render with highlighted active styling in the HUD grid whenever enabled.

## What Didn't Work / Known Issues
- None.

## Architecture Notes
- In `ui_html.lua`, `.sustain-active` is the active highlight class applied to control pads when active state boolean `sustainActive` is set to true on the key payload object.
